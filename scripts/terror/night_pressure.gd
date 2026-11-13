class_name NightPressure
extends RefCounted
## Phase 26: how disturbed the island is. Nights start quiet and grow with
## the days and, more, with what has been cut. It is a pure function of the
## campaign (the day, the trees already down, and where you are standing),
## so nothing here is saved.
##
## The ordinary night director asks three things of it:
##   which Terror families are awake yet       (family_open)
##   how sharp an encounter may be             (max_intensity)
##   how long the quiet between them is        (gap_scale)
## It decides nothing about safety: SafetyService stays the only authority.

const LOCAL_RADIUS := 45.0          # metres around the player
const LOCAL_FULL := 14              # trees down within it for full local pressure
const LOCAL_WEIGHT := 0.3           # what cleared ground nearby can add
const DAY_WEIGHT := 0.45
const CUT_WEIGHT := 0.55
const DAYS_TO_FULL := 20.0          # the day share is complete by day 21
const LEGACY_TREES_TO_FULL := 150.0 # whole-island campaigns: trees down for the full cut share

## Level at which each tier of families wakes.
const TIER_AT := [0.0, 0.18, 0.42, 0.68]
const NAMES := ["quiet", "uneasy", "disturbed", "hostile"]

## Family (T01..T25) -> tier. Tier 0 is sound and atmosphere, heard from
## the first night. Tier 1 is distant shapes. Tier 2 comes close or wears
## something familiar. Tier 3 is the feed that lies. T26 (the night the dog
## runs) is the once-only rescue and is not gated here.
const TIERS := {
	8: 0, 13: 0, 16: 0, 17: 0, 18: 0, 19: 0, 22: 0,
	1: 1, 3: 1, 5: 1, 6: 1, 12: 1, 20: 1, 23: 1, 24: 1,
	2: 2, 4: 2, 7: 2, 9: 2, 10: 2, 11: 2, 14: 2, 15: 2, 21: 2,
	25: 3,
}

## Tests and fixtures can pin the level (< 0 = computed).
static var override_level := -1.0


## 0..1 from the calendar and the cutting, the same everywhere on the island.
static func campaign_level() -> float:
	var c: CampaignService = Game.campaign
	if c == null or not c.active:
		return 1.0          # previews and fixtures show everything
	var day_part := clampf(float(c.clock.day - 1) / DAYS_TO_FULL, 0.0, 1.0)
	return clampf(DAY_WEIGHT * day_part + CUT_WEIGHT * cut_share(), 0.0, 1.0)


## Share of the contract's trees that are no longer standing (lots), or a
## capped count for campaigns that signed for the whole island.
static func cut_share() -> float:
	var c: CampaignService = Game.campaign
	if c == null or c.contract == null:
		return 0.0
	var n: Dictionary = c.contract.counts()
	var total := int(n.get("total_trees", 0))
	var down := total - int(n.get("standing", total))
	if c.contract.lots != null:
		return clampf(float(down) / float(maxi(total, 1)), 0.0, 1.0)
	return clampf(float(down) / LEGACY_TREES_TO_FULL, 0.0, 1.0)


## 0..1: how much has been cut around `at`. Cleared ground is where the
## nights are worst.
static func local_level(at: Vector3) -> float:
	var ts: TreeService = Game.trees
	if ts == null or at == Vector3.INF or World.trees == null:
		return 0.0
	var n := 0
	var r2 := LOCAL_RADIUS * LOCAL_RADIUS
	for id in ts.records:
		if int(ts.records[id].state) < TreeService.State.FALLING:
			continue
		var i := ts.index_of(int(id))
		if i < 0:
			continue
		var dx: float = World.trees.x[i] - at.x
		var dz: float = World.trees.z[i] - at.z
		if dx * dx + dz * dz <= r2:
			n += 1
			if n >= LOCAL_FULL:
				return 1.0
	return float(n) / float(LOCAL_FULL)


## The level the night uses at a place (the player's, by default).
static func level(at := Vector3.INF) -> float:
	if override_level >= 0.0:
		return clampf(override_level, 0.0, 1.0)
	var base := campaign_level()
	if at == Vector3.INF and Game.player != null:
		at = (Game.player as Node3D).global_position
	return clampf(base + LOCAL_WEIGHT * local_level(at), 0.0, 1.0)


static func tier(lvl: float) -> int:
	var t := 0
	for k in TIER_AT.size():
		if lvl >= float(TIER_AT[k]):
			t = k
	return t


static func family_open(family: int, lvl: float) -> bool:
	return int(TIERS.get(family, 0)) <= tier(lvl)


## Sharp beats wait until the island is properly stirred up.
static func max_intensity(lvl: float) -> int:
	if lvl < 0.3:
		return 1
	return 2 if lvl < 0.55 else 3


## Multiplier on the quiet gap between encounters: long early, short late.
static func gap_scale(lvl: float) -> float:
	return lerpf(1.4, 0.65, clampf(lvl, 0.0, 1.0))


## Multiplier on the chance that an opportunity is a startle.
static func startle_scale(lvl: float) -> float:
	return lerpf(0.4, 1.4, clampf(lvl, 0.0, 1.0))


static func name_of(lvl: float) -> String:
	return str(NAMES[tier(lvl)])


## One line for the Journal: how the island feels, and why.
static func describe() -> String:
	var lvl := level()
	var why := ""
	var c: CampaignService = Game.campaign
	if c != null and c.active:
		var loc := local_level((Game.player as Node3D).global_position) if Game.player != null else 0.0
		why = "  Day %d; %d%% of the contract's trees are down%s." % [c.clock.day, int(round(cut_share() * 100.0)), "; this ground has been cut" if loc >= 0.5 else ""]
	return "The island at night: %s.%s" % [name_of(lvl), why]
