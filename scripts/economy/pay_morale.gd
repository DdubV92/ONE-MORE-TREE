class_name PayMorale
extends Node
## Phase 21 (owner request): negotiated wages, pay satisfaction and quitting.
##
## Wages: every employee has their own daily RATE (minimum $100, in $25
## steps), an optional one-day BONUS and an optional PERFORMANCE bonus (a
## share of the value of the work they really did that day: merit
## tree-equivalents x $100). Settlement (Payroll.settle_day) charges exactly
## planned_for() once per worked day; nothing is paid twice on reload.
##
## Satisfaction (0..1) is each worker's feeling about their pay. Every
## worker has a FAIR WAGE in their own eyes (expected()):
##   $100 + personality demand (0-$120) + $6 per career level above 1
##   + $5 per gear point (better kit -> more productive -> they know it).
## Each settled night it moves with the gap between what they were paid and
## that fair wage, scaled by patience. Long runs at the bare minimum wear it
## down faster, and fair pay recovers it. Below VERGE they are "on the verge
## of quitting" (shown, with a notice) for at least one full day. After
## that, below QUIT_AT or after VERGE_NIGHTS nights on the verge, they leave
## on the boat (CrewService departure).
## Pay satisfaction is also their morale: low morale means longer breaks
## between jobs (CrewProgression.pause_after_job).
##
## Raise requests: better gear (2+ gear points) or a career level-up can
## make a worker ask for a raise (chance by assertiveness, seeded, once per
## trigger). Answer: permanent raise, a one-day bonus instead, or decline.
## Unanswered requests expire after the next settlement (a softer decline).
##
## Personality numbers are made ONCE per employee (seeded) and saved; never
## rerolled. Preview mode never writes saves (the campaign save path).

signal pay_changed()
signal quit_over_pay(eid: String)

const VERSION := 1
const MIN_WAGE := 10000             # $100 per worked day (owner rule)
const STEP := 2500                  # $25 rate / bonus steps
const MAX_RATE := 60000             # $600
const PERF_STEPS := [0, 10, 25, 50] # % of the value of their own work
const START_SAT := 0.65
const VERGE := 0.25
const QUIT_AT := 0.12
const VERGE_NIGHTS := 3
const HISTORY_CAP := 60
const GEAR_POINTS := {"tool": {"small": 0, "medium": 2, "large": 3, "saw": 4}, "boots": {"t1": 1, "t2": 2, "t3": 3}, "gloves": {"t1": 1, "t2": 2, "t3": 3}, "helmet": {"t1": 1, "t2": 2, "t3": 3}}

var payroll: Payroll
var equipment: Equipment
var clock: WorkdayClock
var workers := {}        # eid -> record (see _ensure)
var requests: Array = [] # {id, eid, day, reason, raise, bonus, state}
var nights := {}         # day (str) -> nightly summary (pay report)
var _req_counter := 0


func setup(p: Payroll, eq: Equipment, c: WorkdayClock) -> void:
	payroll = p
	equipment = eq
	clock = c
	if equipment and not equipment.changed.is_connected(_on_gear_changed):
		equipment.changed.connect(_on_gear_changed)


# ------------------------------------------------------------ personality

## Personality from traits and a seed key (the hire candidate's id for
## hires, so the asking wage shown before hiring is the same person).
static func personality(seed_key: String, traits: Array) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("pay:" + seed_key)
	var demand := r.randf_range(0.05, 0.85)
	var patience := r.randf_range(0.25, 0.85)
	var assertive := r.randf_range(0.15, 0.85)
	var values_perf := r.randf_range(0.2, 0.9)
	for t in traits:
		match str(t):
			"hard_working":
				demand += 0.1
				values_perf += 0.2
				patience -= 0.05
			"stronger":
				demand += 0.1
			"skeptical":
				demand += 0.08
				patience -= 0.15
				assertive += 0.1
			"timid":
				demand -= 0.15
				patience += 0.15
				assertive -= 0.25
			"level_headed":
				patience += 0.2
				demand -= 0.05
			"sociable":
				assertive += 0.15
			"observant":
				values_perf += 0.1
			"reliable_driver":
				patience += 0.05
	return {"demand": snappedf(clampf(demand, 0.0, 1.0), 0.01), "patience": snappedf(clampf(patience, 0.05, 0.95), 0.01),
		"assertive": snappedf(clampf(assertive, 0.0, 1.0), 0.01), "values_perf": snappedf(clampf(values_perf, 0.0, 1.0), 0.01)}


## Asking wage of a hire candidate (their fair wage on arrival: no level,
## company hatchet only).
static func asking_wage(seed_key: String, traits: Array) -> int:
	var p := personality(seed_key, traits)
	return _round5(MIN_WAGE + int(round(float(p.demand) * 12000.0)))


static func _round5(cents: int) -> int:
	return int(round(cents / 500.0)) * 500


func _ensure(eid: String, rate := -1, seed_key := "") -> Dictionary:
	if workers.has(eid):
		return workers[eid]
	var e := payroll.employee(eid) if payroll else {}
	var p := personality(seed_key if seed_key != "" else eid, e.get("traits", []))
	var rec := {"rate": rate if rate >= 0 else MIN_WAGE, "bonus": 0, "perf_pct": 0, "sat": START_SAT,
		"demand": p.demand, "patience": p.patience, "assertive": p.assertive, "values_perf": p.values_perf,
		"min_days": 0, "verge_day": -1, "gear_pts": gear_points(eid), "level": _career(eid), "history": [],
		"declined": 0, "boost_day": -1, "seed": seed_key if seed_key != "" else eid}
	workers[eid] = rec
	return rec


## New campaign: every starting employee at the minimum.
func init_new() -> void:
	workers.clear()
	requests.clear()
	nights.clear()
	_req_counter = 0
	for e in payroll.employees:
		_ensure(str(e.id), MIN_WAGE)
	pay_changed.emit()


## A hired candidate starts at their asking wage (what the hire screen said).
func on_hired(eid: String, cid: String, traits: Array) -> void:
	workers.erase(eid)
	_ensure(eid, asking_wage(cid, traits), cid)
	pay_changed.emit()


# ------------------------------------------------------------- the numbers

func rec(eid: String) -> Dictionary:
	return _ensure(eid) if payroll and not payroll.employee(eid).is_empty() else {}


func rate(eid: String) -> int:
	return int(rec(eid).get("rate", MIN_WAGE))


func _career(eid: String) -> int:
	if Game.crew and Game.crew.get("progression") != null:
		return int(Game.crew.progression.career(eid))
	return 1


func gear_points(eid: String) -> int:
	if equipment == null:
		return 0
	var n := 0
	for slot in GEAR_POINTS:
		var it := equipment.equipped_item(eid, str(slot))
		if not it.is_empty():
			n += int((GEAR_POINTS[slot] as Dictionary).get(str(it.get("tier", "")), 0))
	return n


## The fair daily wage in this worker's own eyes (cents).
func expected(eid: String) -> int:
	var r := rec(eid)
	if r.is_empty():
		return MIN_WAGE
	return _round5(MIN_WAGE + int(round(float(r.demand) * 12000.0)) + (maxi(_career(eid), 1) - 1) * 600 + gear_points(eid) * 500)


## What the worker would say if asked: a $25-wide band around it.
func expected_band(eid: String) -> Array:
	var x := expected(eid)
	var lo := int(floor(x / 2500.0)) * 2500
	return [maxi(lo, MIN_WAGE), maxi(lo, MIN_WAGE) + 2500]


## Merit tree-equivalents of real work on day d (1,000 merit = one tree
## fully felled, sectioned, cleared, moved and received).
func tree_eq(eid: String, d: int) -> float:
	if Game.crew == null or Game.crew.get("merit") == null:
		return 0.0
	var md: Dictionary = Game.crew.merit.today(eid, d)
	var s := 0.0
	for k in md:
		s += float(md[k])
	return s / MeritLedger.TREE_MAX


func value_cents(eid: String, d: int) -> int:
	return int(round(tree_eq(eid, d) * CampaignRules.PAY_PER_TREE_CENTS))


## Share of the work day spent on useful work (time ledger), 0..1.
func useful_share(eid: String, d: int) -> float:
	if Game.crew == null or Game.crew.get("progression") == null:
		return 0.0
	var tm: Dictionary = Game.crew.progression.day_time(eid, d)
	var tot := 0.0
	for k in tm:
		tot += float(tm[k])
	return float(tm.get("useful", 0.0)) / tot if tot > 1.0 else 0.0


func perf_bonus(eid: String, d: int) -> int:
	var pct := int(rec(eid).get("perf_pct", 0))
	return _round5(int(round(value_cents(eid, d) * pct / 100.0))) if pct > 0 else 0


## Exactly what tonight's settlement charges for this employee's day d.
func planned_for(eid: String, d: int) -> Dictionary:
	var r := rec(eid)
	var base := int(r.get("rate", MIN_WAGE))
	var bonus := int(r.get("bonus", 0))
	var perf := perf_bonus(eid, d)
	return {"base": base, "bonus": bonus, "perf": perf, "total": base + bonus + perf}


func sat(eid: String) -> float:
	return float(rec(eid).get("sat", START_SAT))


static func status_of(s: float) -> String:
	if s >= 0.7:
		return "Content"
	if s >= 0.45:
		return "Okay"
	if s >= VERGE:
		return "Unhappy"
	return "On the verge of quitting"


func status(eid: String) -> String:
	return status_of(sat(eid))


# ----------------------------------------------------------- player actions

func can_edit() -> Dictionary:
	var cs: CampaignService = Game.campaign
	if cs and cs.contract and cs.contract.is_closed():
		return {"ok": false, "reason": "The contract has closed: no more payroll changes."}
	return {"ok": true}


## Changes the daily rate by `steps` x $25 (never below $100). A raise
## feels good at once (once per day); a cut hurts more than a raise helps.
func change_rate(eid: String, steps: int) -> Dictionary:
	var ok := can_edit()
	if not bool(ok.ok):
		return ok
	var r := rec(eid)
	if r.is_empty():
		return {"ok": false, "reason": "No such employee."}
	var old := int(r.rate)
	var nw := clampi(old + steps * STEP, MIN_WAGE, MAX_RATE)
	if nw == old:
		return {"ok": false, "reason": "The minimum is $100 a day." if steps < 0 else "That is the highest rate the company allows ($600)."}
	r.rate = nw
	var d := clock.day if clock else 0
	if nw < old:
		r.sat = clampf(float(r.sat) - 0.06 * float(old - nw) / STEP, 0.0, 1.0)
	elif int(r.boost_day) != d:
		r.boost_day = d
		var room := clampf(float(expected(eid) - old) / STEP, 0.0, 3.0)
		r.sat = clampf(float(r.sat) + 0.04 * minf(float(nw - old) / STEP, maxf(room, 0.5)), 0.0, 1.0)
	pay_changed.emit()
	return {"ok": true, "rate": nw}


## Today's one-day bonus (added to tonight's pay, then cleared).
func change_bonus(eid: String, steps: int) -> Dictionary:
	var ok := can_edit()
	if not bool(ok.ok):
		return ok
	var r := rec(eid)
	if r.is_empty():
		return {"ok": false, "reason": "No such employee."}
	r.bonus = clampi(int(r.bonus) + steps * STEP, 0, 50000)
	pay_changed.emit()
	return {"ok": true, "bonus": int(r.bonus)}


func cycle_perf(eid: String) -> Dictionary:
	var ok := can_edit()
	if not bool(ok.ok):
		return ok
	var r := rec(eid)
	if r.is_empty():
		return {"ok": false, "reason": "No such employee."}
	var i := PERF_STEPS.find(int(r.perf_pct))
	r.perf_pct = PERF_STEPS[(i + 1) % PERF_STEPS.size()]
	pay_changed.emit()
	return {"ok": true, "perf_pct": int(r.perf_pct)}


# ------------------------------------------------------------ raise requests

func pending_request(eid: String) -> Dictionary:
	for q in requests:
		if str(q.eid) == eid and str(q.state) == "pending":
			return q
	return {}


func _on_gear_changed() -> void:
	if payroll == null:
		return
	for e in payroll.employees:
		var eid := str(e.id)
		if not workers.has(eid) or str(e.status) != Payroll.ACTIVE:
			continue
		var r: Dictionary = workers[eid]
		var g := gear_points(eid)
		if g >= int(r.gear_pts) + 2:
			_consider_request(eid, "better gear", "gear:%d" % g)
		r.gear_pts = maxi(int(r.gear_pts), g)


## CrewProgression.advanced: a career level-up can bring a request.
func on_advanced(eid: String, what: String, level: int) -> void:
	if what != "career" or not workers.has(eid):
		return
	var r: Dictionary = workers[eid]
	if level > int(r.level):
		r.level = level
		_consider_request(eid, "reaching level %d" % level, "level:%d" % level)


func _consider_request(eid: String, reason: String, key: String) -> void:
	var r: Dictionary = workers[eid]
	var gap := expected(eid) - int(r.rate)
	if gap < 1500:
		return
	var g := RandomNumberGenerator.new()
	g.seed = hash("ask:%s:%s" % [r.seed, key])
	if g.randf() > 0.3 + 0.6 * float(r.assertive):
		return
	var old := pending_request(eid)
	if not old.is_empty():
		old.state = "replaced"
	_req_counter += 1
	var ask := _round5(maxi(gap, STEP))
	var q := {"id": "RAISE-%03d" % _req_counter, "eid": eid, "day": clock.day if clock else 0, "reason": reason,
		"raise": ask, "bonus": _round5(int(ask * 1.6)), "state": "pending"}
	requests.append(q)
	var nm := str(payroll.employee(eid).get("name", eid))
	if Game.campaign:
		Game.campaign.notice.emit("%s asks for a raise after %s: +$%s a day, or a $%s bonus today (camper computer -> Payroll)." % [nm, reason, Money.format_cents(int(q.raise)), Money.format_cents(int(q.bonus))], 8.0)
	pay_changed.emit()


## choice: "raise" (permanent), "bonus" (one day), "decline".
func answer(req_id: String, choice: String) -> Dictionary:
	var q := {}
	for x in requests:
		if str(x.id) == req_id:
			q = x
	if q.is_empty() or str(q.state) != "pending":
		return {"ok": false, "reason": "That request is no longer open."}
	var r := rec(str(q.eid))
	match choice:
		"raise":
			var ok := can_edit()
			if not bool(ok.ok):
				return ok
			r.rate = clampi(int(r.rate) + int(q.raise), MIN_WAGE, MAX_RATE)
			r.sat = clampf(float(r.sat) + 0.08, 0.0, 1.0)
		"bonus":
			var ok2 := can_edit()
			if not bool(ok2.ok):
				return ok2
			r.bonus = int(r.bonus) + int(q.bonus)
			r.sat = clampf(float(r.sat) + 0.04, 0.0, 1.0)
		"decline":
			r.sat = clampf(float(r.sat) - (0.05 + 0.1 * float(r.assertive)), 0.0, 1.0)
			r.declined = int(r.declined) + 1
		_:
			return {"ok": false, "reason": "Unknown answer."}
	q.state = {"raise": "accepted", "bonus": "bonus_paid", "decline": "declined"}[choice]
	q["answered_day"] = clock.day if clock else 0
	pay_changed.emit()
	return {"ok": true}


# ------------------------------------------------------------- settlement

## Called by CampaignService.sleep() right after Payroll.settle_day(d):
## satisfaction moves once per worked day, the one-day bonus clears, open
## requests expire, and quitting is decided. Idempotent per day.
func on_settled(d: int) -> Dictionary:
	var key := str(d)
	if nights.has(key):
		return nights[key]
	var lines: Array = []
	var quits: Array = []
	for e in payroll.employees:
		var eid := str(e.id)
		if not workers.has(eid):
			continue
		var r: Dictionary = workers[eid]
		var lid := "WAGE-D%02d-%s" % [d, eid]
		var li := payroll._liability(lid)
		if li.is_empty():
			r.bonus = 0
			continue
		var base := int(li.get("base", li.amount))
		var bonus := int(li.get("bonus", 0))
		var perf := int(li.get("perf", 0))
		var exp_c := expected(eid)
		var before := float(r.sat)
		# Performance pay counts more for people who take pride in output.
		var felt := float(base + bonus) + float(perf) * (0.7 + 0.6 * float(r.values_perf))
		var gap := (felt - exp_c) / float(exp_c)
		var delta := clampf(gap * 0.3, -0.18, 0.12)
		if gap < 0.0:
			delta *= lerpf(1.35, 0.65, float(r.patience))
		else:
			delta = maxf(delta, 0.03)
		if base <= MIN_WAGE:
			r.min_days = int(r.min_days) + 1
			delta -= 0.012 * float(r.min_days) * (1.0 - float(r.patience))
		else:
			r.min_days = 0
		# Wages they were not actually paid are a grievance of their own.
		if int(li.paid) < int(li.amount):
			delta -= 0.05
		r.sat = clampf(before + delta, 0.0, 1.0)
		var s := float(r.sat)
		var st := status_of(s)
		var quit := false
		if s < VERGE:
			if int(r.verge_day) < 0:
				# Always one full day of visible warning before anyone quits.
				r.verge_day = d
				if Game.campaign:
					Game.campaign.notice.emit("%s is on the verge of quitting over pay (Payroll app: they would be happier around $%s a day)." % [str(e.get("name", eid)), Money.format_cents(expected_band(eid)[1])], 8.0)
			elif s < QUIT_AT or d - int(r.verge_day) + 1 >= VERGE_NIGHTS:
				quit = str(e.status) == Payroll.ACTIVE
		else:
			r.verge_day = -1
		var tq := tree_eq(eid, d)
		var line := {"eid": eid, "name": str(e.get("name", eid)), "day": d, "base": base, "bonus": bonus, "perf": perf, "total": int(li.amount), "paid": int(li.paid),
			"expected": exp_c, "tree_eq": snappedf(tq, 0.001), "value": int(round(tq * CampaignRules.PAY_PER_TREE_CENTS)), "useful": snappedf(useful_share(eid, d), 0.01),
			"sat_before": snappedf(before, 0.001), "sat": snappedf(s, 0.001), "status": st, "quit": quit}
		(r.history as Array).append(line)
		while (r.history as Array).size() > HISTORY_CAP:
			(r.history as Array).pop_front()
		lines.append(line)
		r.bonus = 0
		if Game.crew and Game.crew.get("progression") != null:
			Game.crew.progression.morale[eid] = snappedf(s, 0.001)
		if quit:
			quits.append(eid)
	for q in requests:
		if str(q.state) == "pending" and int(q.day) < d:
			q.state = "expired"
			var rr: Dictionary = workers.get(str(q.eid), {})
			if not rr.is_empty():
				rr.sat = clampf(float(rr.sat) - 0.6 * (0.05 + 0.1 * float(rr.assertive)), 0.0, 1.0)
	var tot := {"base": 0, "bonus": 0, "perf": 0, "total": 0, "value": 0}
	for l in lines:
		for k in tot:
			tot[k] = int(tot[k]) + int(l[k])
	var out := {"day": d, "lines": lines, "totals": tot, "quits": quits}
	nights[key] = out
	for eid in quits:
		quit_over_pay.emit(eid)
	pay_changed.emit()
	return out


## Whole-campaign pay report (the end-of-game page): per-worker totals.
func campaign_report() -> Dictionary:
	var per: Array = []
	var all := {"days": 0, "base": 0, "bonus": 0, "perf": 0, "total": 0, "value": 0}
	for e in payroll.employees:
		var eid := str(e.id)
		var r: Dictionary = workers.get(eid, {})
		if r.is_empty():
			continue
		var t := {"eid": eid, "name": str(e.get("name", eid)), "status": str(e.status), "days": 0, "base": 0, "bonus": 0, "perf": 0, "total": 0, "value": 0, "tree_eq": 0.0, "rate": int(r.rate), "sat": float(r.sat), "reason": str(e.get("departure_reason", ""))}
		for h in r.history:
			t.days += 1
			for k in ["base", "bonus", "perf", "total", "value"]:
				t[k] = int(t[k]) + int(h[k])
			t.tree_eq += float(h.tree_eq)
		for k in all:
			all[k] = int(all[k]) + int(t[k])
		per.append(t)
	return {"workers": per, "totals": all}


# ------------------------------------------------------------------- saves

func capture() -> Dictionary:
	return {"version": VERSION, "workers": workers.duplicate(true), "requests": requests.duplicate(true), "nights": nights.duplicate(true), "req_counter": _req_counter}


## Older saves (before Phase 21) had a flat $300 wage: everyone keeps
## exactly that rate, so loading never cuts anybody's pay.
func restore(d: Dictionary, legacy_rate: int) -> void:
	workers = (d.get("workers", {}) as Dictionary).duplicate(true)
	requests = (d.get("requests", []) as Array).duplicate(true)
	nights = (d.get("nights", {}) as Dictionary).duplicate(true)
	_req_counter = int(d.get("req_counter", requests.size()))
	if payroll:
		for e in payroll.employees:
			if not workers.has(str(e.id)):
				_ensure(str(e.id), legacy_rate if d.is_empty() else MIN_WAGE)
	pay_changed.emit()
