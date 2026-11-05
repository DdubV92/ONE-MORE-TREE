class_name MeritLedger
extends RefCounted
## Phase 16: merit is a CONSERVED ledger of useful contribution, separate
## from cash and from contract delivery (it never pays money or changes
## wages). Each original tree carries at most 1,000 merit, split into stage
## budgets; every award commits a FRACTION of one stage of one source and
## the committed fraction only ever grows, so nothing can be earned twice:
##
##   fell      300 / tree   by accepted notch progress (work/required)
##   section   200 / tree   across that tree's cuts, by each cut's required
##                          work, by accepted cut progress
##   stump     100 / tree   by accepted stump-removal progress
##   transport 300 / tree   per merchantable share (its mte/1000): 85 % for
##                          bringing it to a NEW closest distance to the
##                          receiving cradle (detours, circles and shuffles
##                          earn nothing), 15 % once for loading it into a
##                          truck/cart; whatever remains goes to whoever
##                          delivers it
##   receive   100 / tree   per share: 50 % the first yard move onto a deck,
##                          the rest when it goes onto the fire pile
##
## A saw does more work per second than an axe, not more total merit per
## tree. Shared work splits by participation (team carry 50/50). The boss's
## share goes to the separate "boss" bucket (never employee merit); work by
## nobody (automatic burning) stays unallocated. Transaction ids are
## sequential; the committed table is saved in the same snapshot as the
## world, so a save/load or checkpoint rollback restores both together.

const VERSION := 1
const BUDGET := {"fell": 300.0, "section": 200.0, "stump": 100.0, "transport": 300.0, "receive": 100.0}
const TREE_MAX := 1000.0
const LOAD_SHARE := 0.15
const RACK_SHARE := 0.5
const BOSS := "boss"
const SKILLS := ["cutting", "handling", "driving", "teamwork"]
const RECENT_CAP := 80
const DAYS_KEPT := 4

signal awarded(actor: String, stage: String, amount: float, source: String)

var committed := {}       # source key -> committed fraction [0, 1]
var totals := {}          # actor -> merit (float)
var by_stage := {}        # actor -> {stage: merit}
var skills := {}          # actor -> {skill: points}
var days := {}            # "day" -> {actor: {stage: merit}}
var recent: Array = []    # last transactions (newest last)
var transport := {}       # sid -> {"d0", "best", "last", "mode"}
var tx := 0
var rejected := 0         # attempts that found the budget already committed
var day := 1              # set by the crew from the campaign clock
var unallocated := 0.0    # stage budget consumed by nobody (e.g. none)
var per_tree := {}        # tree id -> merit committed for it (<= TREE_MAX)


## The live campaign ledger (null outside a crew-enabled world).
static func active() -> MeritLedger:
	if Game.crew == null:
		return null
	var m: Variant = Game.crew.get("merit")
	return m as MeritLedger


# ------------------------------------------------------------- core award

## Commits `source` up to `frac_to` and splits the new part among
## `who` (actor -> weight). Returns the merit awarded (0 if nothing new).
func commit(source: String, stage: String, budget: float, frac_to: float, who: Dictionary, skill_w: Dictionary) -> float:
	var f := clampf(frac_to, 0.0, 1.0)
	var before := float(committed.get(source, 0.0))
	var delta := f - before
	if delta <= 1e-7:
		rejected += 1
		return 0.0
	committed[source] = f
	var amount := budget * delta
	var tid := tree_of(source)
	per_tree[tid] = float(per_tree.get(tid, 0.0)) + amount
	var wsum := 0.0
	for a in who:
		wsum += maxf(float(who[a]), 0.0)
	if wsum <= 0.0:
		unallocated += amount
		return amount
	for a in who:
		var part := amount * maxf(float(who[a]), 0.0) / wsum
		if part > 0.0:
			_credit(str(a), stage, part, source, skill_w)
	return amount


func _credit(actor: String, stage: String, amount: float, source: String, skill_w: Dictionary) -> void:
	if actor == "":
		unallocated += amount
		return
	tx += 1
	totals[actor] = float(totals.get(actor, 0.0)) + amount
	if not by_stage.has(actor):
		by_stage[actor] = {}
	by_stage[actor][stage] = float(by_stage[actor].get(stage, 0.0)) + amount
	if actor != BOSS:
		if not skills.has(actor):
			skills[actor] = {"cutting": 0.0, "handling": 0.0, "driving": 0.0, "teamwork": 0.0}
		var sw := 0.0
		for s in skill_w:
			sw += float(skill_w[s])
		for s in skill_w:
			skills[actor][s] = float(skills[actor].get(s, 0.0)) + amount * float(skill_w[s]) / maxf(sw, 0.0001)
	var dk := str(day)
	if not days.has(dk):
		days[dk] = {}
		_prune_days()
	if not days[dk].has(actor):
		days[dk][actor] = {}
	days[dk][actor][stage] = float(days[dk][actor].get(stage, 0.0)) + amount
	recent.append({"tx": tx, "day": day, "actor": actor, "stage": stage, "source": source, "amount": amount})
	if recent.size() > RECENT_CAP:
		recent.pop_front()
	awarded.emit(actor, stage, amount, source)


func _prune_days() -> void:
	var ks := days.keys()
	ks.sort_custom(func(a, b) -> bool: return int(a) < int(b))
	while ks.size() > DAYS_KEPT:
		days.erase(ks.pop_front())


# ----------------------------------------------------------- stage hooks

func on_fell(tid: int, progress_after: float, actor: String) -> float:
	return commit("fell:%d" % tid, "fell", BUDGET.fell, progress_after, {actor: 1.0}, {"cutting": 1.0})


## `share`: this cut's fraction of the tree's total sectioning work.
func on_section(tid: int, cut: String, share: float, progress_after: float, actor: String) -> float:
	return commit("sect:%d:%s" % [tid, cut], "section", BUDGET.section * clampf(share, 0.0, 1.0), progress_after, {actor: 1.0}, {"cutting": 1.0})


func on_stump(tid: int, progress_after: float, actor: String) -> float:
	return commit("stump:%d" % tid, "stump", BUDGET.stump, progress_after, {actor: 1.0}, {"cutting": 1.0})


static func transport_skills(mode: String) -> Dictionary:
	match mode:
		"truck":
			return {"driving": 1.0}
		"team":
			return {"handling": 0.5, "teamwork": 0.5}
	return {"handling": 1.0}


## A transport sample: `sid` (a merchantable share of `mte`) is being moved
## by `who` and is now `dist` m from the receiving cradle. Only a new
## closest approach earns (bounded by the distance when it first moved).
func sample_transport(sid: String, mte: int, dist: float, who: Dictionary, mode: String) -> float:
	if float(committed.get("trd:" + sid, 0.0)) >= 1.0:
		return 0.0
	var t: Dictionary = transport.get(sid, {})
	if t.is_empty():
		transport[sid] = {"d0": maxf(dist, 1.0), "best": dist, "last": who.keys()[0] if not who.is_empty() else "", "mode": mode}
		return 0.0
	t.last = who.keys()[0] if not who.is_empty() else ""
	t.mode = mode
	if dist >= float(t.best) - 0.05:
		return 0.0
	t.best = maxf(dist, 0.0)
	var frac := (float(t.d0) - float(t.best)) / float(t.d0)
	return commit("trd:" + sid, "transport", BUDGET.transport * mte / 1000.0 * (1.0 - LOAD_SHARE), frac, who, transport_skills(mode))


## First time this share goes into a truck bed or onto the cart.
func on_loaded(sid: String, mte: int, actor: String) -> float:
	return commit("trl:" + sid, "transport", BUDGET.transport * mte / 1000.0 * LOAD_SHARE, 1.0, {actor: 1.0}, {"handling": 1.0})


## Accepted at camp: whatever transport merit is left goes to the deliverer
## (usually a small remainder: the rest was earned on the way).
func on_accepted(sid: String, mte: int, actor: String, mode: String) -> float:
	var a := commit("trd:" + sid, "transport", BUDGET.transport * mte / 1000.0 * (1.0 - LOAD_SHARE), 1.0, {actor: 1.0}, transport_skills(mode))
	a += commit("trl:" + sid, "transport", BUDGET.transport * mte / 1000.0 * LOAD_SHARE, 1.0, {actor: 1.0}, {"handling": 1.0})
	transport.erase(sid)
	return a


## Yard handling of an accepted share: "racked" (first move onto a deck)
## or "fed" (onto the fire pile, the rest of the receiving budget).
func on_receive(sid: String, mte: int, actor: String, kind: String) -> float:
	var to := RACK_SHARE if kind == "racked" else 1.0
	return commit("rcv:" + sid, "receive", BUDGET.receive * mte / 1000.0, to, {actor: 1.0}, {"handling": 1.0})


func last_mover(sid: String) -> String:
	return str((transport.get(sid, {}) as Dictionary).get("last", ""))


# ---------------------------------------------------------------- queries

func total(actor: String) -> float:
	return float(totals.get(actor, 0.0))


func skill_points(actor: String, skill: String) -> float:
	return float((skills.get(actor, {}) as Dictionary).get(skill, 0.0))


func today(actor: String, d: int) -> Dictionary:
	return ((days.get(str(d), {}) as Dictionary).get(actor, {}) as Dictionary).duplicate()


## Total merit committed (awarded + unallocated) for one original tree.
func tree_total(tid: int) -> float:
	return float(per_tree.get(tid, 0.0))


static func tree_of(source: String) -> int:
	var rest := source.substr(source.find(":") + 1)
	if rest.begins_with("T"):
		return int(rest.substr(1).split("_S")[0])
	return int(rest.split(":")[0])


func capture() -> Dictionary:
	return {"version": VERSION, "committed": committed.duplicate(), "totals": totals.duplicate(), "by_stage": by_stage.duplicate(true), "skills": skills.duplicate(true), "days": days.duplicate(true), "recent": recent.duplicate(true), "transport": transport.duplicate(true), "tx": tx, "rejected": rejected, "unallocated": unallocated, "per_tree": per_tree.duplicate()}


func restore(d: Dictionary) -> void:
	committed = (d.get("committed", {}) as Dictionary).duplicate()
	totals = (d.get("totals", {}) as Dictionary).duplicate()
	by_stage = (d.get("by_stage", {}) as Dictionary).duplicate(true)
	skills = (d.get("skills", {}) as Dictionary).duplicate(true)
	days = (d.get("days", {}) as Dictionary).duplicate(true)
	recent = (d.get("recent", []) as Array).duplicate(true)
	transport = (d.get("transport", {}) as Dictionary).duplicate(true)
	tx = int(d.get("tx", 0))
	rejected = int(d.get("rejected", 0))
	unallocated = float(d.get("unallocated", 0.0))
	per_tree = {}
	for k in (d.get("per_tree", {}) as Dictionary):
		per_tree[int(k)] = float(d.per_tree[k])
