class_name ContractService
extends Node
## The thirty-day clearance contract (Phase 3).
##
## Close: the END of day 30's dusk (workday counter reaches nightfall). Sleep
## is not required; refusing to sleep cannot keep the contract open.
## Fulfilled when, from the stable manifest (not a scene count):
##   - zero original standing trees (a notched tree still stands),
##   - zero stumps left (every felled tree's stump removed),
##   - all merchantable timber accepted at camp (no world/carried/vehicle
##     pieces and no fallen trunk still waiting to be bucked),
##   - no orphaned/irreconcilable timber records.
## Accepted fuel still burning does NOT block success; ash is separate.
##
## Ordering at the deadline: the clock reports the deadline during a physics
## step; final evaluation is deferred to the end of that frame, so any
## acceptance committed in the same frame (timestamped at the deadline)
## counts. After the outcome commits, TimberService refuses new acceptance
## (`accepting()`), so nothing can sneak into a closed contract. Outcomes are
## persisted with a transaction id and never change afterwards.

signal outcome(state: String, outcome_id: String)
signal progress_changed()
## Phase 25: a contract lot was finished (every tree down, stump out, logs
## accepted). Emitted once per lot; the campaign pays the milestone.
signal lot_completed(lot: int, on_time: bool)

const ACTIVE := "CONTRACT_ACTIVE"
const FULFILLED := "CONTRACT_FULFILLED"
const ABANDONMENT := "ABANDONMENT_PENDING"
const LEGACY := "LEGACY_UNTIMED"

var state := ACTIVE
var outcome_id := ""
var outcome_at := {}
var trees: TreeService
var timber: TimberService
var clock: WorkdayClock
var _closing := false
## Development fixture only (tests / Day & Economy Test): limits the
## contract to this many original trees. -1 = the whole manifest. Never saved.
var scope_override := -1
## Phase 25: the lots this contract covers (null = the whole island, as in
## campaigns started before lots existed).
var lots: ContractLots = null


func setup(tr: TreeService, tm: TimberService, c: WorkdayClock) -> void:
	trees = tr
	timber = tm
	clock = c
	if trees:
		trees.tree_state_changed.connect(func(_id: int, _s: int) -> void: evaluate())
	if timber:
		timber.delivery_accepted.connect(func(_r: Dictionary) -> void: evaluate())
		timber.accept_gate = accepting
	if clock:
		clock.deadline_reached.connect(func() -> void: _close_deadline.call_deferred())


func accepting() -> bool:
	return state == ACTIVE or state == LEGACY


func is_closed() -> bool:
	return state == FULFILLED or state == ABANDONMENT


## Progress counters (cheap: only modified trees and timber are walked).
func counts() -> Dictionary:
	var total := World.native_total() if scope_override < 0 else scope_override
	var lot_scope := lots != null and scope_override < 0
	if lot_scope:
		total = lots.total()
	var not_standing := 0
	var trunks := 0
	var stumps := 0
	var unbucked_mte := 0
	if trees:
		for id in trees.records:
			if lot_scope and not lots.has(int(id)):
				continue          # wood from outside the lots pays, but is not the contract
			var st := int(trees.records[id].state)
			if st >= TreeService.State.FALLING:
				not_standing += 1
			if st == TreeService.State.FALLING or st == TreeService.State.FALLEN:
				trunks += 1
				unbucked_mte += TimberService.TREE_MTE
			if st >= TreeService.State.FALLING and st < TreeService.State.DISPOSED:
				stumps += 1
	var undelivered := unbucked_mte
	var orphans := 0
	var accepted := 0
	var backlog := 0
	if timber:
		for id in timber.records:
			if lot_scope and not lots.has(int(id)):
				continue
			for s in timber.records[id].segments:
				if int(s.state) < TimberService.Seg.ACCEPTED_QUEUED:
					undelivered += int(s.mte)
			if not bool(timber.reconcile(int(id)).ok):
				orphans += 1
		accepted = int(timber.totals().accepted_mte)
		backlog = timber.queue_mte()
	return {
		"total_trees": total, "standing": maxi(total - not_standing, 0), "felled": not_standing,
		"trunks_to_buck": trunks, "stumps": stumps, "undelivered_mte": undelivered,
		"accepted_mte": accepted, "backlog_mte": backlog, "orphans": orphans,
		"ash_clean": timber.ash_clean() if timber else true,
	}


func complete(c: Dictionary) -> bool:
	return int(c.standing) == 0 and int(c.stumps) == 0 and int(c.undelivered_mte) == 0 and int(c.orphans) == 0


## Re-evaluates after an authoritative transition (felling, stump removal,
## acceptance) - never per frame.
func evaluate() -> void:
	progress_changed.emit()
	if not accepting():
		return
	_check_lots()
	if complete(counts()):
		_commit(FULFILLED)


func _check_lots() -> void:
	if lots == null or scope_override >= 0:
		return
	for k in lots.lots.size():
		if lots.done.has(k) or not lots.lot_complete(k, trees, timber):
			continue
		var day := clock.day if clock else 0
		var on_time := day <= int(lots.lots[k].due_day)
		lots.done[k] = {"day": day, "on_time": on_time}
		lot_completed.emit(k, on_time)


func _close_deadline() -> void:
	if _closing or is_closed() or state == LEGACY:
		return
	_closing = true
	_commit(FULFILLED if complete(counts()) else ABANDONMENT)


func _commit(to: String) -> void:
	if is_closed():
		return
	state = to
	outcome_id = "OUT-%s-D%02d" % ["FULFILLED" if to == FULFILLED else "ABANDON", clock.day if clock else 0]
	outcome_at = {"day": clock.day if clock else 0, "t": clock.t if clock else 0.0}
	if clock:
		clock.running = false      # no further workdays after the outcome
	outcome.emit(state, outcome_id)


## Feasibility note for reports/UI (the 12,000-tree count is provisional).
func required_per_day() -> float:
	var c := counts()
	var days := maxi((clock.days_remaining() + 1) if clock else 30, 1)
	return float(c.standing + c.trunks_to_buck) / float(days)


func capture() -> Dictionary:
	var d := {"state": state, "outcome_id": outcome_id, "outcome_at": outcome_at}
	if lots:
		d["lots"] = lots.capture()
	return d


func restore(d: Dictionary) -> void:
	state = str(d.get("state", ACTIVE))
	if not state in [ACTIVE, FULFILLED, ABANDONMENT, LEGACY]:
		state = ACTIVE
	outcome_id = str(d.get("outcome_id", ""))
	outcome_at = d.get("outcome_at", {})
	_closing = is_closed()
	if lots:
		lots.restore(d.get("lots", {}))
