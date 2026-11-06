class_name Woodcutting
extends RefCounted
## Phase 24: the shared Woodcutting skill. The boss and every worker use the
## same award path and the same curve; nothing here touches merit, wages,
## career level or traits (those stay in MeritLedger / PayMorale /
## CrewProgression).
##
##   Level 0 on day 1 (new players and every worker).
##   +5 XP once per confirmed, eligible wood-damaging hit, to the actor who
##   landed it (not the tool's owner, not whoever claimed the tree).
##   Next level from L costs 50 + 25 x L XP (L = 0..49); leftover XP carries
##   over; progression clamps at level 50 (33,125 XP, 6,625 valid hits).
##   Each level: +1 % base woodcutting damage AND +1 % base cutting speed
##   (cap +50 % each). Speed is an action rate: x1.5 means the swing
##   interval is divided by 1.5 (ToolEffects applies both, once).
##
## Eligible hits: an ACCEPTED axe contact on a standing/notched tree, an
## accepted bucking cut on a log, an accepted stump-grubbing hit. The
## chainsaw has no swings, so one "strike" is STRIKE_S seconds of accepted,
## loaded cutting (the axe's swing cycle); partial strikes carry over.
## Rejected hits (dead wood with no work left, a tree that just fell, a
## cut someone else finished), empty swings, physics frames, animation
## duplicates, cleanup and milling award nothing - the services only call
## `on_hit` after accepting real work.
## Hit identity: the services number accepted hits per target (tree hits,
## timber cut counters), so a hit is keyed "<actor>|<target>|<n>" and a
## repeated key is ignored (save/load at an action boundary cannot grant
## twice; the key set is bounded and saved).

const VERSION := 1
const XP_PER_HIT := 5
const MAX_LEVEL := 50
const BONUS_PER_LEVEL := 0.01
const STRIKE_S := 0.95          # = ToolEffects.AXE_CYCLE
const KEY_MEMORY := 4096

signal leveled(actor: String, level: int)
signal xp_awarded(actor: String, xp: int, level: int)

var xp := {}           # actor -> total XP (int, clamped at the cap)
var hits := {}         # actor -> valid hits credited (telemetry)
var by_tool := {}      # actor -> {"axe": hits, "saw": strikes}
var saw_carry := {}    # actor -> accumulated accepted saw seconds < STRIKE_S
var _seen := {}        # hit key -> true (bounded)
var _seen_order: Array = []


static func active() -> Woodcutting:
	if Game.crew == null:
		return null
	return Game.crew.get("woodcutting") as Woodcutting


## XP needed to go from level L to L+1.
static func cost(level: int) -> int:
	return 50 + 25 * level


## Total XP to reach `level` from 0.
static func total_to(level: int) -> int:
	var l := clampi(level, 0, MAX_LEVEL)
	return 50 * l + 25 * l * (l - 1) / 2


static func cap_xp() -> int:
	return total_to(MAX_LEVEL)


## {"level", "into" (XP into this level), "need" (cost of next, 0 at cap)}
static func progress_for(total: int) -> Dictionary:
	var t := clampi(total, 0, cap_xp())
	var level := 0
	while level < MAX_LEVEL and t >= total_to(level + 1):
		level += 1
	if level >= MAX_LEVEL:
		return {"level": MAX_LEVEL, "into": 0, "need": 0, "total": t}
	return {"level": level, "into": t - total_to(level), "need": cost(level), "total": t}


static func damage_factor(level: int) -> float:
	return 1.0 + BONUS_PER_LEVEL * clampi(level, 0, MAX_LEVEL)


static func speed_factor(level: int) -> float:
	return 1.0 + BONUS_PER_LEVEL * clampi(level, 0, MAX_LEVEL)


func level_of(actor: String) -> int:
	return int(progress_for(int(xp.get(actor, 0))).level)


func progress(actor: String) -> Dictionary:
	return progress_for(int(xp.get(actor, 0)))


## The ONE award entry point (called by TreeService / TimberService after a
## hit was accepted). `tool` "axe" or "saw"; `seconds` = accepted saw
## cutting time for this tick. `key` identifies the accepted hit.
func on_hit(actor: String, tool: String, key: String, seconds := 0.0) -> int:
	if actor == "":
		return 0
	if key != "":
		if _seen.has(key):
			return 0
		_seen[key] = true
		_seen_order.append(key)
		if _seen_order.size() > KEY_MEMORY:
			_seen.erase(_seen_order.pop_front())
	var strikes := 1
	if tool == "saw":
		var acc := float(saw_carry.get(actor, 0.0)) + maxf(seconds, 0.0)
		strikes = int(floor(acc / STRIKE_S + 1e-6))
		saw_carry[actor] = acc - strikes * STRIKE_S
		if strikes <= 0:
			return 0
	var tb: Dictionary = by_tool.get(actor, {"axe": 0, "saw": 0})
	tb[tool] = int(tb.get(tool, 0)) + strikes
	by_tool[actor] = tb
	hits[actor] = int(hits.get(actor, 0)) + strikes
	var before := level_of(actor)
	var t := mini(int(xp.get(actor, 0)) + XP_PER_HIT * strikes, cap_xp())
	var gained := t - int(xp.get(actor, 0))
	xp[actor] = t
	var after := level_of(actor)
	if gained > 0:
		xp_awarded.emit(actor, gained, after)
	if after > before:
		leveled.emit(actor, after)
	return gained


func reset_actor(actor: String) -> void:
	xp.erase(actor)
	hits.erase(actor)
	by_tool.erase(actor)
	saw_carry.erase(actor)


func capture() -> Dictionary:
	var sc := {}
	for a in saw_carry:
		sc[a] = snappedf(float(saw_carry[a]), 0.001)
	return {"version": VERSION, "xp": xp.duplicate(), "hits": hits.duplicate(), "by_tool": by_tool.duplicate(true), "saw_carry": sc, "seen": _seen_order.slice(-512)}


## Saves without the block (before Phase 24) start everyone at level 0:
## no authoritative per-hit history exists to migrate (merit is not hits).
func restore(d: Dictionary) -> void:
	xp.clear()
	hits.clear()
	by_tool.clear()
	saw_carry.clear()
	_seen.clear()
	_seen_order.clear()
	for a in d.get("xp", {}):
		xp[str(a)] = clampi(int(d.xp[a]), 0, cap_xp())
	for a in d.get("hits", {}):
		hits[str(a)] = int(d.hits[a])
	for a in d.get("by_tool", {}):
		by_tool[str(a)] = (d.by_tool[a] as Dictionary).duplicate()
	for a in d.get("saw_carry", {}):
		saw_carry[str(a)] = clampf(float(d.saw_carry[a]), 0.0, STRIKE_S)
	for k in d.get("seen", []):
		_seen[str(k)] = true
		_seen_order.append(str(k))
