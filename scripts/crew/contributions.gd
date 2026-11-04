class_name Contributions
extends RefCounted
## Phase 10 hook for Phase 16 merit: records USEFUL, unique contributions
## per worker. Nothing here awards XP, levels or money yet.
##  - "work": cutting work actually applied by an accepted contact (summed);
##  - stage events ("felled", "bucked", "stump", "loaded", "accepted") are
##    keyed by item + stage and count ONCE, so picking up / dropping /
##    re-loading the same piece never earns repeated credit;
##  - "accepted" is per accepted segment id (a receipt can only exist once).

var work := {}          # worker id -> float work units applied
var stages := {}        # "stage:item" -> worker id (first legitimate claimant)
var per_worker := {}    # worker id -> {stage: count}
var rejected_repeats := 0


func add_work(wid: String, amount: float) -> void:
	if amount > 0.0:
		work[wid] = float(work.get(wid, 0.0)) + amount


## Returns true when this is the first time this item reached this stage.
func stage(wid: String, kind: String, item: String) -> bool:
	var key := "%s:%s" % [kind, item]
	if stages.has(key):
		rejected_repeats += 1
		return false
	stages[key] = wid
	if not per_worker.has(wid):
		per_worker[wid] = {}
	per_worker[wid][kind] = int(per_worker[wid].get(kind, 0)) + 1
	return true


func capture() -> Dictionary:
	return {"work": work.duplicate(), "stages": stages.duplicate(), "per_worker": per_worker.duplicate(true), "version": 1}


func restore(d: Dictionary) -> void:
	work = (d.get("work", {}) as Dictionary).duplicate()
	stages = (d.get("stages", {}) as Dictionary).duplicate()
	per_worker = (d.get("per_worker", {}) as Dictionary).duplicate(true)
