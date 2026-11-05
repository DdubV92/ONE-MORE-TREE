class_name CampRoutine
extends RefCounted
## Phase 19: the shape of a crew day (contract days only; never in the hunt).
##
## Morning   each active worker on "automatic" gets a ROLE for the day from
##           real inputs - their kit (a chainsaw makes a sawyer), traits
##           (stronger hauls, level-headed/observant keep the yard), and the
##           backlog (yard stock, loose logs, trunks waiting). The role only
##           decides what they try FIRST; the Phase 14 bottleneck rules still
##           apply, and the player's explicit job assignment always wins.
## Transport a plan for the day from where the work actually is (distance
##           from camp), trucks owned and whether a reliable driver is
##           employed: carry / handcart / truck runs (a recommendation shown
##           in the day's notes - the player still drives the trucks).
## Midday    a gathering break: workers between jobs within reach of camp
##           walk to the fire seats / picnic table, sit, and talk (ordinary
##           Phase 17 conversation: act:rest, where:camp lines). Far crews
##           take their break where they are. Break time is its own time
##           category ("break"), never counted as idleness.
## Dog       someone at the gathering calls Biscuit over and pets her.
## Awareness at the gathering, each attendee hears what the others actually
##           did today (merit ledger) - a real colleague_progress context
##           with exactly those knowers.

const BREAK_T0 := 430.0       # daylight seconds (midday)
const BREAK_LEN := 55.0       # seconds once started (walking in is part of it)
const GATHER_R := 170.0       # within this of camp: walk in for the break
const SEATS := [-0.6, 1.0, 2.2, 3.6]   # fire seat angles (CampLayout.BURN_PIT_POS, r 3.6)

var crew: CrewService
var day := 0
var roles := {}               # eid -> role
var plan := {}                # transport plan for the day
var brk := {"day": -1, "state": "none", "attendees": [], "field": [], "seats": {}, "petted": "", "shared": false}
var notes: Array = []         # day notes (shown in the daily review / tests)


func _init(c: CrewService) -> void:
	crew = c


func _active() -> Array:
	var out := []
	for w in crew.workers.values():
		var wk := w as Worker
		if str(wk.emp.get("status", "")) == Payroll.ACTIVE:
			out.append(wk)
	return out


func _contract_day() -> bool:
	if crew.campaign == null or crew.campaign.contract == null or crew.campaign.contract.is_closed():
		return false
	return Game.hunt == null or not Game.hunt.hunt_active()


# ---------------------------------------------------------------- morning

func plan_day(d: int) -> void:
	day = d
	roles.clear()
	if not _contract_day():
		return
	var ws := _active()
	var yard_stock := Game.yard.stock_count() if Game.yard else 0
	var focus := World.camp_origin()
	var loose := 0
	var trunks := 0
	if not ws.is_empty():
		focus = crew.work_focus(ws[0])
		loose = crew._loose_pieces(focus, ws[0]).size()
		trunks = crew._trunks(focus, ws[0]).size()
	var yard_slots := 0
	if yard_stock >= 12:
		yard_slots = 2
	elif yard_stock >= 5:
		yard_slots = 1
	# Deterministic order: by id.
	ws.sort_custom(func(a: Worker, b: Worker) -> bool: return a.id < b.id)
	for w in ws:
		if str(w.emp.get("job", "automatic")) != "automatic":
			roles[w.id] = "assigned:" + str(w.emp.get("job", ""))
			continue
		var role := "feller"
		if w.axe_tier() == "chainsaw" and trunks > 0:
			role = "sawyer"
		elif yard_slots > 0 and (w.mind.has("level_headed") or w.mind.has("observant")):
			role = "yard"
			yard_slots -= 1
		elif w.mind.has("stronger") or (loose >= 4 and not roles.values().has("hauler")):
			role = "hauler"
		elif w.axe_tier() == "chainsaw":
			role = "sawyer"
		roles[w.id] = role
	# Still a yard backlog and nobody suited took it: the least-busy hand.
	if yard_slots > 0:
		for w in ws:
			if roles.get(w.id, "") == "feller":
				roles[w.id] = "yard"
				break
	plan = transport_plan(focus)
	notes.append({"day": d, "roles": roles.duplicate(), "plan": plan.duplicate(), "inputs": {"yard_stock": yard_stock, "loose": loose, "trunks": trunks}})
	if notes.size() > 10:
		notes.pop_front()


func transport_plan(focus: Vector3) -> Dictionary:
	var dist := Vector2(focus.x, focus.z).distance_to(Vector2(World.camp_origin().x, World.camp_origin().z))
	var trucks := (Game.vehicles.trucks as Dictionary).size() if Game.vehicles else 0
	var driver := ""
	for w in _active():
		if (w as Worker).mind.has("reliable_driver"):
			driver = (w as Worker).id
	var mode := "carry"
	var why := "the work is close to the yard (%d m)" % int(dist)
	if dist >= 260.0 and trucks > 0 and driver != "":
		mode = "truck"
		why = "the work is %d m out: truck runs, %s drives" % [int(dist), str(crew.emp(driver).get("name", driver)).split(" ")[0]]
	elif dist >= 120.0 and Game.cart != null:
		mode = "cart"
		why = "the work is %d m out: the handcart saves walking" % int(dist)
	elif dist >= 260.0:
		why = "the work is %d m out and there is no truck%s" % [int(dist), "" if trucks > 0 else ""]
	return {"mode": mode, "distance": int(dist), "trucks": trucks, "driver": driver, "why": why}


func role_of(w: Worker) -> String:
	return str(roles.get(w.id, ""))


## Role-first preference inside CrewService._auto (returns true if the
## role's first choice found work).
func try_role_first(w: Worker) -> bool:
	match role_of(w):
		"yard":
			return crew.try_yard(w)
		"hauler":
			return crew._try_haul(w)
		"sawyer":
			return crew._try_buck(w)
	return false


# ------------------------------------------------------------------ break

func break_window(t: float) -> bool:
	return t >= BREAK_T0 and t < BREAK_T0 + BREAK_LEN


## Called every crew tick: starts/ends the midday gathering.
func tick() -> void:
	if crew.campaign == null or not _contract_day():
		return
	var c := crew.campaign.clock
	if c.phase() != WorkdayClock.Phase.DAYLIGHT:
		return
	if day != c.day and not _active().is_empty():
		plan_day(c.day)       # day 1 / after a load: plan on the first tick
	if break_window(c.t) and int(brk.day) != c.day:
		start_break(c.day)
	elif str(brk.state) == "on" and crew.now() >= float(brk.get("until", 0.0)):
		end_break()
	if str(brk.state) == "on":
		_settle_attendees()


func start_break(d: int) -> void:
	brk = {"day": d, "state": "on", "attendees": [], "field": [], "seats": {}, "petted": "", "shared": false, "until": crew.now() + BREAK_LEN}
	var camp := World.camp_origin()
	var seat_i := 0
	for w in _active():
		var wk := w as Worker
		if wk.is_carrying() or wk.team != "" or wk.activity in ["aboard", "seated", "sleep", "fell", "retreat_wait"]:
			continue
		if wk.global_position.distance_to(camp) < GATHER_R:
			var seat := _seat_point(seat_i)
			seat_i += 1
			brk.seats[wk.id] = [seat.x, seat.y, seat.z]
			(brk.attendees as Array).append(wk.id)
			crew.release_claims(wk)
			var pit := CampLayout.world(CampLayout.BURN_PIT_POS)
			var front := seat + (pit - seat).normalized() * 0.7
			front.y = World.height_at(front.x, front.z)
			if not wk.go_to(front, "break_sit", "the fire"):
				wk.go_to(seat, "break_sit", "the fire")
		else:
			(brk.field as Array).append(wk.id)
			crew.release_claims(wk)
			wk.path.clear()
			wk.activity = "break_sit"
			wk.body_char.play("sit", 0.3)
	_call_dog()


## Fire seats first (real stools / the rocking chair), then standing
## places around the picnic table.
func _seat_point(i: int) -> Vector3:
	if i < SEATS.size():
		var a: float = SEATS[i]
		return CampLayout.world(CampLayout.BURN_PIT_POS + Vector3(cos(a) * 3.6, 0, sin(a) * 3.6))
	var k := i - SEATS.size()
	return CampLayout.world(CampLayout.PICNIC_POS + Vector3(-1.5 + 1.0 * k, 0, 1.4))


func _settle_attendees() -> void:
	var pit := CampLayout.world(CampLayout.BURN_PIT_POS)
	for eid in brk.attendees:
		var w: Worker = crew.workers.get(eid)
		if w == null or w.activity != "break_sit" or w.body_char.current == "sit" or w.body_char.current == "idle" and w.get_meta("break_stand", false):
			continue
		var to := pit - w.global_position
		to.y = 0
		w.rotation.y = atan2(-to.x, -to.z)
		var seat: Array = brk.seats.get(eid, [])
		var seated := (brk.attendees as Array).find(eid) < SEATS.size()
		if seated:
			if seat.size() == 3:
				w.global_position = Vector3(seat[0], seat[1], seat[2])
			w.body_char.play("sit", 0.3)
		else:
			w.set_meta("break_stand", true)
			w.body_char.play("idle", 0.3)
	# Colleague awareness once most of the gathering has arrived.
	if not bool(brk.shared):
		var here := (brk.attendees as Array).filter(func(e: String) -> bool: return crew.workers.has(e) and (crew.workers[e] as Worker).activity == "break_sit")
		if here.size() >= 2:
			share_progress(here)
	# Biscuit: the nearest attendee pets her once.
	if str(brk.petted) == "" and Game.dog and is_instance_valid(Game.dog):
		for eid in brk.attendees:
			var w2: Worker = crew.workers.get(eid)
			if w2 and w2.activity == "break_sit" and (Game.dog as Node3D).global_position.distance_to(w2.global_position) < 3.5:
				Game.dog.pet(w2)
				brk.petted = eid
				crew.progression.add_context("dog", eid, "petted Biscuit", (brk.attendees as Array).duplicate())
				break


## Each attendee hears what the others actually did today.
func share_progress(here: Array) -> void:
	brk.shared = true
	var d := crew.campaign.clock.day if crew.campaign else day
	for eid in here:
		var t: Dictionary = crew.merit.today(eid, d)
		var total := 0.0
		for k in t:
			total += float(t[k])
		if total > 0.0:
			var best := ""
			var bv := 0.0
			for k in t:
				if float(t[k]) > bv:
					bv = float(t[k])
					best = str(k)
			crew.progression.add_context("colleague_progress", eid, best, here.duplicate())


func _call_dog() -> void:
	var dog := Game.dog
	if dog == null or not is_instance_valid(dog) or (brk.attendees as Array).is_empty():
		return
	if dog.state in [CampDog.State.IDLE, CampDog.State.WANDER, CampDog.State.SIT, CampDog.State.NAP]:
		var p := _seat_point(0) + Vector3(0.9, 0, 0.6)
		dog._plan(p, CampDog.State.SIT, 1.6)


func end_break() -> void:
	brk.state = "done"
	for eid in (brk.attendees as Array) + (brk.field as Array):
		var w: Worker = crew.workers.get(eid)
		if w == null:
			continue
		if w.has_meta("break_stand"):
			w.remove_meta("break_stand")
		if w.activity == "break_sit" or (w.activity == "move" and w._after_move == "break_sit"):
			w._after_move = ""
			w.path.clear()
			w.activity = "idle"
			w.body_char.play("idle", 0.3)
			w._decide_cd = 0.2


## Break seconds count as "break" (not idleness).
func on_tick_time(w: Worker, dt: float) -> bool:
	if w.activity == "break_sit" or (w.activity == "move" and w._after_move == "break_sit"):
		crew.progression._add(w.id, "break", dt)
		return true
	return false


func capture() -> Dictionary:
	return {"day": day, "roles": roles.duplicate(), "plan": plan.duplicate(), "brk": brk.duplicate(true), "notes": notes.duplicate(true)}


func restore(d: Dictionary) -> void:
	day = int(d.get("day", 0))
	roles = (d.get("roles", {}) as Dictionary).duplicate()
	plan = (d.get("plan", {}) as Dictionary).duplicate()
	brk = (d.get("brk", brk) as Dictionary).duplicate(true)
	notes = (d.get("notes", []) as Array).duplicate(true)
	# A break in progress resumes as finished (workers restore standing).
	if str(brk.get("state", "")) == "on":
		brk.state = "done"
