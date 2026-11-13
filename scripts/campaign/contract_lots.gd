class_name ContractLots
extends RefCounted
## Phase 25: contract lots. The company marks blocks of forest ("lots")
## outward from the camp's forest entrance. The contract is the lots, not
## the whole island: it is fulfilled when every lot tree is down, its stump
## is out and its logs are accepted. Each lot pays a milestone when it is
## finished and a bonus when that happens by its due day.
##
## The plan is a pure function of the frozen island and the ruleset, so it
## is never saved; only what happened (which lots finished, and when) is.
## Trees outside the lots still pay as wood at the mill; they just do not
## count toward the contract.

const VERSION := 1

var lots: Array = []             # [{trees: PackedInt32Array, due_day, milestone_cents, bonus_cents}]
var member := {}                 # tree id -> lot index
var done := {}                   # lot index -> {"day": int, "on_time": bool}
var advanced := {}               # lot index -> true (its advance was paid)
var focus := Vector3.ZERO        # the forest entrance the lots grow out from


## Builds the plan from a ruleset's "lots" block:
##   {"sizes": [..], "due": [..], "milestone_cents": [..], "bonus_cents": [..]}
static func plan(def: Dictionary) -> ContractLots:
	var cl := ContractLots.new()
	var o := World.camp_origin()
	cl.focus = Vector3(o.x, 0.0, o.z - CampLayout.FENCE_HALF.y - 25.0)
	var sizes: Array = def.get("sizes", [])
	var need := 0
	for n in sizes:
		need += int(n)
	# Nearest original trees to the entrance, outside the camp fence.
	var cand: Array = []
	var half := CampLayout.FENCE_HALF
	for i in World.tree_count():
		var id := int(World.trees.id[i])
		if World.excluded_trees.has(id) or World.removed_trees.has(id):
			continue
		var x: float = World.trees.x[i]
		var z: float = World.trees.z[i]
		if absf(x - o.x) < half.x + 3.0 and absf(z - o.z) < half.y + 3.0:
			continue
		var d := Vector2(x - cl.focus.x, z - cl.focus.z).length_squared()
		if d > 260.0 * 260.0:
			continue
		cand.append([d, id])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var at := 0
	for k in sizes.size():
		var ids := PackedInt32Array()
		for j in int(sizes[k]):
			if at >= cand.size():
				break
			ids.append(int(cand[at][1]))
			cl.member[int(cand[at][1])] = k
			at += 1
		cl.lots.append({
			"trees": ids,
			"due_day": int((def.get("due", []) as Array)[k]) if k < (def.get("due", []) as Array).size() else WorkdayClock.CONTRACT_DAYS,
			"milestone_cents": int((def.get("milestone_cents", []) as Array)[k]) if k < (def.get("milestone_cents", []) as Array).size() else 0,
			"bonus_cents": int((def.get("bonus_cents", []) as Array)[k]) if k < (def.get("bonus_cents", []) as Array).size() else 0,
			"advance_cents": int((def.get("advance_cents", []) as Array)[k]) if k < (def.get("advance_cents", []) as Array).size() else 0,
		})
	return cl


func total() -> int:
	return member.size()


func has(tree_id: int) -> bool:
	return member.has(tree_id)


func lot_of(tree_id: int) -> int:
	return int(member.get(tree_id, -1))


## Per-lot progress from the authoritative tree and timber records.
func lot_counts(k: int, trees: TreeService, timber: TimberService) -> Dictionary:
	var standing := 0
	var stumps := 0
	var undelivered := 0
	for id in (lots[k].trees as PackedInt32Array):
		var st := int(trees.records[id].state) if trees and trees.records.has(id) else TreeService.State.STANDING
		if st < TreeService.State.FALLING:
			standing += 1
			continue
		if st < TreeService.State.DISPOSED:
			stumps += 1
		if st == TreeService.State.FALLING or st == TreeService.State.FALLEN:
			undelivered += TimberService.TREE_MTE
		elif timber and timber.records.has(id):
			for s in timber.records[id].segments:
				if int(s.state) < TimberService.Seg.ACCEPTED_QUEUED:
					undelivered += int(s.mte)
	return {"trees": (lots[k].trees as PackedInt32Array).size(), "standing": standing, "stumps": stumps, "undelivered_mte": undelivered}


func lot_complete(k: int, trees: TreeService, timber: TimberService) -> bool:
	var c := lot_counts(k, trees, timber)
	return int(c.standing) == 0 and int(c.stumps) == 0 and int(c.undelivered_mte) == 0


## The lot the crew should be felling: the first with a tree still standing
## (-1 when every lot tree is down).
func felling_lot(trees: TreeService) -> int:
	for k in lots.size():
		for id in (lots[k].trees as PackedInt32Array):
			var st := int(trees.records[id].state) if trees and trees.records.has(id) else TreeService.State.STANDING
			if st < TreeService.State.FALLING:
				return k
	return -1


## The lot being worked on overall: the first not yet finished.
func current_lot() -> int:
	for k in lots.size():
		if not done.has(k):
			return k
	return -1


## Middle of what is still standing in a lot (where the crew heads).
func standing_centre(k: int, trees: TreeService) -> Vector3:
	var idx: Dictionary = Game.vegetation.get("tree_index_by_id") if Game.vegetation else {}
	var sum := Vector3.ZERO
	var n := 0
	for id in (lots[k].trees as PackedInt32Array):
		var st := int(trees.records[id].state) if trees and trees.records.has(id) else TreeService.State.STANDING
		if st < TreeService.State.FALLING and idx.has(id):
			var i := int(idx[id])
			sum += Vector3(World.trees.x[i], 0.0, World.trees.z[i])
			n += 1
	return sum / float(n) if n > 0 else focus


func capture() -> Dictionary:
	var d := {}
	for k in done:
		d[str(k)] = (done[k] as Dictionary).duplicate()
	var adv: Array = []
	for k in advanced:
		adv.append(int(k))
	return {"version": VERSION, "done": d, "advanced": adv}


func restore(data: Dictionary) -> void:
	done.clear()
	advanced.clear()
	for k in data.get("advanced", []):
		advanced[int(k)] = true
	var d: Dictionary = data.get("done", {})
	for k in d:
		var i := int(str(k))
		if i >= 0 and i < lots.size():
			done[i] = {"day": int((d[k] as Dictionary).get("day", 0)), "on_time": bool((d[k] as Dictionary).get("on_time", false))}
