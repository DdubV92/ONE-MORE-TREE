class_name Ruleset
extends RefCounted
## Phase 10: versioned, data-driven campaign rulesets. A campaign stores its
## ruleset (id + parameters) in its save and keeps it for life; new rules
## never rewrite an existing campaign. Fixed terms shared by every ruleset:
## 30 days, 1,200 s daylight + 300 s dusk (900 s daylight before Phase 22), $100 per original tree, 2 pickups
## x 3 seats x 3 tree-equivalents. Wages: Phase 21 (owner request) replaced
## the flat $300 per employee-day with per-worker pay from a $100 minimum
## (PayMorale); campaigns saved before that keep $300 per person.
##
## expanded_v1 (new standard campaigns, revised Phase 10):
##   - exactly 10,000 original native trees: a deterministic subset of the
##     frozen generated island (the 2,000 most isolated trees are not part
##     of this manifest and are never spawned), so clusters stay dense and
##     the island keeps its full extent;
##   - boss + five employees from day 1 (six humans), small axes;
##   - $4,500 starting cash (three full-crew payroll days; tunable);
##   - section length x1.5 and chainsaws are RESERVED here and stay inactive
##     until Phases 13/14 implement their handling (conservation first).
## contract_v1 (legacy): the 12,000-tree / two-employee contract of
## Phases 3-9. Saves made with it keep it.

## expanded_v2 (Phase 12, new standard campaigns): the same terms as
##   expanded_v1 on island revision 2 (data/world/r2): landform terrain,
##   exactly 10,000 planned native trees with size cohorts and low boughs,
##   persistent rock formations, undergrowth and hide anchors. Phase 10
##   saves keep expanded_v1 on the revision-1 island; legacy keeps
##   contract_v1. A save never changes island revision.
## expanded_v3 (Phase 13, new standard campaigns): expanded_v2's island and
##   terms with the Phase 13 handling path ACTIVE: segmentation plan v2
##   (target section length x1.5, fewer and larger pieces per tree, same
##   $100 and tree-equivalent per tree), early handcart and dragging, the
##   receiving yard and log decks. expanded_v2 saves (Phase 12) keep plan v1.
const STANDARD := "expanded_v3"
const PHASE12 := "expanded_v2"
const PHASE10 := "expanded_v1"
const LEGACY := "contract_v1"

const DEFS := {
	"contract_v1": {
		"id": "contract_v1", "label": "Legacy 12,000-tree contract", "native_total": 12000, "variant": "full",
		"starting_employees": 2, "start_cash_cents": 200000, "section_length_mult": 1.0, "section_length_active": true,
		"tool_model": "per_contact_v1", "chainsaw": false, "version": 1,
	},
	"expanded_v3": {
		"id": "expanded_v3", "label": "Standard 10,000-tree contract (island r2, logging yard)", "native_total": 10000, "variant": "island_r2",
		"starting_employees": 5, "start_cash_cents": 450000, "section_length_mult": 1.5, "section_length_active": true, "section_plan": "v2",
		"tool_model": "per_contact_v1", "chainsaw": false, "version": 3,
	},
	"expanded_v2": {
		"id": "expanded_v2", "label": "Standard 10,000-tree contract (island r2)", "native_total": 10000, "variant": "island_r2",
		"starting_employees": 5, "start_cash_cents": 450000, "section_length_mult": 1.5, "section_length_active": false,
		"tool_model": "per_contact_v1", "chainsaw": false, "version": 2,
	},
	"expanded_v1": {
		"id": "expanded_v1", "label": "Standard 10,000-tree contract", "native_total": 10000, "variant": "standard_10k",
		"starting_employees": 5, "start_cash_cents": 450000, "section_length_mult": 1.5, "section_length_active": false,
		"tool_model": "per_contact_v1", "chainsaw": false, "version": 1,
	},
}


## The ruleset a world variant belongs to (Preview fixtures, tests).
static func for_variant(variant: String) -> String:
	if str(DEFS[STANDARD].variant) == variant:
		return STANDARD
	for id in DEFS:
		if str(DEFS[id].variant) == variant:
			return id
	return LEGACY


static func known(id: String) -> bool:
	return DEFS.has(id)


static func get_def(id: String) -> Dictionary:
	return (DEFS.get(id, DEFS[LEGACY]) as Dictionary).duplicate(true)


## The ruleset id stored in a save's campaign block (old saves = legacy).
static func id_of_save(campaign: Dictionary) -> String:
	var r: Variant = campaign.get("ruleset", {})
	if r is Dictionary and (r as Dictionary).has("id"):
		return str((r as Dictionary).id)
	return LEGACY


## Manifest variant the world must build before vegetation exists. New
## campaign -> the standard ruleset; loading -> whatever the save holds;
## Preview -> the full generated island (tests and tools rely on it).
static func variant_for_start() -> String:
	if Game.mode != Game.Mode.CAMPAIGN:
		return str(Game.get("preview_variant")) if str(Game.get("preview_variant")) != "" else "full"
	if Game.new_game:
		return str(DEFS[STANDARD].variant)
	var raw := SaveService.read_file_raw(SaveService.save_path())
	if raw.is_empty():
		return str(DEFS[STANDARD].variant)
	var id := id_of_save(raw.get("campaign", {}))
	return str(get_def(id).variant) if known(id) else "full"


# ------------------------------------------------------------ manifests

static var _excluded_cache := {}


## Tree ids NOT in a variant's native manifest (deterministic, cached).
## standard_10k removes the 2,000 trees with the fewest neighbours within
## 12 m (ties broken by a hash of the id), i.e. thins scattered loners and
## opens clearings while the dense clusters stay dense.
static func excluded_ids(variant: String) -> Dictionary:
	if variant == "full":
		return {}
	if _excluded_cache.has(variant):
		return _excluded_cache[variant]
	var n := World.tree_count()
	var target := n - 10000
	if variant != "standard_10k" or target <= 0:
		return {}
	const CELL := 12.0
	var grid := {}
	var xs: PackedFloat32Array = World.trees.x
	var zs: PackedFloat32Array = World.trees.z
	for i in n:
		var c := Vector2i(int(floor(xs[i] / CELL)), int(floor(zs[i] / CELL)))
		if not grid.has(c):
			grid[c] = PackedInt32Array()
		var arr: PackedInt32Array = grid[c]
		arr.append(i)
		grid[c] = arr
	var scored: Array = []
	for i in n:
		var c := Vector2i(int(floor(xs[i] / CELL)), int(floor(zs[i] / CELL)))
		var cnt := 0
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var cc := c + Vector2i(dx, dz)
				if not grid.has(cc):
					continue
				for j in (grid[cc] as PackedInt32Array):
					if j != i:
						var ddx := xs[j] - xs[i]
						var ddz := zs[j] - zs[i]
						if ddx * ddx + ddz * ddz <= CELL * CELL:
							cnt += 1
		var id := int(World.trees.id[i])
		scored.append([cnt, hash(id) & 0xffff, id])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		return int(a[1]) < int(b[1]))
	var out := {}
	for k in target:
		out[int(scored[k][2])] = true
	_excluded_cache[variant] = out
	return out
