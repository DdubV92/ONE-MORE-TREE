class_name CrewService
extends Node
## The living crew (Phase 4): roster and employment, beds, hiring and firing
## with real boat arrivals/departures, job selection with exclusive claims,
## return-before-night planning, local perception of stimuli, doors, and
## save/restore. Wages stay in Payroll (one ledger); money in Wallet.
##
## Employment states (emp.status): pending_arrival -> active -> departing
## -> departed. Fear states live in WorkerMind (refusing risk / warning /
## quitting). A departed person keeps their identity record forever (later
## phases may imitate them - never revive them).

signal roster_changed()
signal notice(text: String, seconds: float)

const MAX_EMPLOYEES := 5
const BEDS := 6
const SEARCH_RADIUS := 140.0
const BOAT_HOURS := [40.0, 860.0]   # supply skiff runs in daylight only (t)

var nav: CrewNav
var timber: TimberService
var trees: TreeService
var campaign: CampaignService
var payroll: Payroll
var work_config: TreeWorkConfig
var econ: EconomyConfig
var workers := {}            # id -> Worker
var minds := {}              # id -> WorkerMind (also for departed identities)
var claims := {}             # task key -> worker id
var candidates: Array[Dictionary] = []
var enabled := false
var stuck_log: Array[Dictionary] = []
var stats := {}              # id -> {felled, bucked, delivered_mte}
var dock_end := Vector3.ZERO
var dock_shore := Vector3.ZERO
var skiff: Node3D
var skiff_state := "away"    # away / inbound / docked / outbound
var _skiff_t := 0.0
var _skiff_path := [Vector3.ZERO, Vector3.ZERO]
var _cand_counter := 0
var _emp_counter := 2
var _door_open := {}         # door -> time opened by crew
var _rock_hash := {}
var _shared := {}            # "listener|memory" -> true
var _share_t := 0.0
var _last_day_marked := -1
var _unreachable_sids: Array = []
var world_ready := false
var _pending: Array[Callable] = []


## Phase 14 coordination (felling lanes, claim reaper, team carry).
var coord: CrewCoordinator
## Phase 16: conserved merit ledger + persistent profiles/levels/skills.
var merit := MeritLedger.new()
var progression := CrewProgression.new(merit)
var _tr_t := 0.0
## Phase 17: authored crew conversations (one owner per camp).
var talk: ConversationService
var routine: CampRoutine     # Phase 19: day roles, transport plan, midday gathering


func setup(c: CampaignService) -> void:
	campaign = c
	payroll = c.payroll
	timber = Game.timber
	trees = Game.trees
	work_config = load("res://config/tree_work.tres")
	econ = load("res://config/economy.tres")
	nav = CrewNav.new()
	nav.name = "CrewNav"
	add_child(nav)
	coord = CrewCoordinator.new(self)
	talk = ConversationService.new()
	talk.name = "Conversations"
	add_child(talk)
	if trees:
		trees.tree_warning.connect(coord.on_warning)
		trees.tree_felled.connect(coord.on_felled)
	payroll.quit_due_to_arrears.connect(func(eid: String) -> void: start_departure(eid, "unpaid wages"))
	# Phase 21: a worker who has had enough of their pay leaves the same way.
	if c.pay:
		c.pay.quit_over_pay.connect(func(eid: String) -> void: start_departure(eid, "low pay"))
		progression.advanced.connect(c.pay.on_advanced)
	c.clock.day_started.connect(_on_morning)
	c.clock.night_started.connect(_on_night)
	if timber:
		timber.body_settled_hook = _on_log_settled
		timber.delivery_accepted.connect(_merit_on_accepted)
	talk.setup(self)
	routine = CampRoutine.new(self)
	progression.advanced.connect(_on_advanced)


## Builds navigation once the camp's collision exists (deferred by the world).
func build_world() -> void:
	nav.build()
	nav.build_camp()
	_rock_hash = PlacementValidator._rock_hash()
	_build_dock_and_skiff()
	world_ready = true
	for f in _pending:
		f.call()
	_pending.clear()


## Runs `f` now if navigation is ready, otherwise right after it is built.
func when_ready(f: Callable) -> void:
	if world_ready:
		f.call()
	else:
		_pending.append(f)


func now() -> float:
	return float(campaign.clock.day) * 10000.0 + campaign.clock.t


# ----------------------------------------------------------------- roster

func employees() -> Array[Dictionary]:
	return payroll.employees


func emp(id: String) -> Dictionary:
	return payroll.employee(id)


func slots_used() -> int:
	var n := 0
	for e in payroll.employees:
		if str(e.status) in ["pending_arrival", Payroll.ACTIVE, "departing", Payroll.PENDING]:
			n += 1
	return n


func free_bed() -> int:
	var used := {}
	for e in payroll.employees:
		if str(e.status) != "departed" and int(e.get("bed", 0)) > 0:
			used[int(e.bed)] = true
	for b in range(1, BEDS + 1):
		if not used.has(b):
			return b
	return 0


func bed_node(index: int) -> Node3D:
	for m in get_tree().get_nodes_in_group("worker_bed"):
		if int((m as Node).get_meta("bed_index", 0)) == index:
			return m
	return null


## New campaign: the two starting employees arrive with the boss (no fee),
## each with a seed look, traits, a small axe and a bed.
func start_new_campaign() -> void:
	enabled = true
	for e in payroll.employees:
		_activate(e, "starting crew")
	roster_changed.emit()


## Phase 3 saves carry "pending_integration" records: activate the SAME
## identities exactly once (idempotent; no back-charged wages).
func migrate_pending() -> int:
	var n := 0
	for e in payroll.employees:
		if str(e.status) == Payroll.PENDING:
			_activate(e, "joined camp (Phase 4 crew activation)")
			n += 1
	return n


func _activate(e: Dictionary, why: String) -> void:
	if not e.has("look_seed"):
		e["look_seed"] = hash(str(e.id)) & 0x7fffffff
	if str(e.id) == "EMP-01" and (e.traits as Array).size() < 2:
		e.traits = ["hard_working", "sociable"]
	elif str(e.id) == "EMP-02" and (e.traits as Array).size() < 2:
		e.traits = ["stronger", "skeptical"]
	e.status = Payroll.ACTIVE
	e["job"] = str(e.get("job", "automatic"))
	e["worked_days"] = e.get("worked_days", [])
	e["arrival_day"] = campaign.clock.day
	e["note"] = why
	if int(e.get("bed", 0)) <= 0:
		e["bed"] = free_bed()
	if not minds.has(str(e.id)):
		minds[str(e.id)] = WorkerMind.with_traits(e.traits)
	progression.ensure_profile(str(e.id), e.traits)
	_ensure_axe(str(e.id))
	_spawn_at_porch(e)


func _ensure_axe(eid: String) -> void:
	var eq := campaign.equipment
	if eq.owned_by(eid).is_empty():
		eq._add("small", eid, "issued")
		eq.changed.emit()


func equipment_axe_of(eid: String) -> Dictionary:
	var own := campaign.equipment.owned_by(eid)
	var best := {}
	for a in own:
		if best.is_empty() or Equipment.TIERS.find(str(a.tier)) > Equipment.TIERS.find(str(best.tier)):
			best = a
	return best


func _spawn_at_porch(e: Dictionary) -> Worker:
	var spawns := get_tree().get_nodes_in_group("worker_spawn")
	var i := clampi(payroll.employees.find(e), 0, maxi(spawns.size() - 1, 0))
	var at: Vector3 = (spawns[i] as Node3D).global_position if not spawns.is_empty() else World.camp_origin()
	return _spawn(e, at)


func _spawn(e: Dictionary, at: Vector3) -> Worker:
	var eid := str(e.id)
	if workers.has(eid):
		return workers[eid]
	var w := Worker.new()
	add_child(w)
	w.setup(self, e, minds[eid])
	w.global_position = Vector3(at.x, nav.surface_at(at), at.z)
	w.said.connect(_on_said)
	workers[eid] = w
	if not stats.has(eid):
		stats[eid] = {"felled": 0, "bucked": 0, "delivered_mte": 0}
	return w


# ------------------------------------------------------------------ hiring

func refresh_candidates(force := false) -> void:
	if candidates.size() >= 4 and not force:
		return
	var r := RandomNumberGenerator.new()
	const FIRST := ["Ines", "Tomasz", "Wren", "Kofi", "Hollis", "Mara", "Petra", "Ade", "Silas", "June", "Nadia", "Orrin", "Beatriz", "Callum", "Lio", "Yusra"]
	const LAST := ["Vance", "Okafor", "Lindqvist", "Brandt", "Moreau", "Haddad", "Kerr", "Salo", "Ibarra", "Doyle", "Petrov", "Achebe", "Fenn", "Ruiz", "Nakamura", "Quill"]
	while candidates.size() < 4:
		_cand_counter += 1
		r.seed = 9000 + _cand_counter * 7919
		var t1: String = WorkerMind.TRAITS[r.randi() % WorkerMind.TRAITS.size()]
		var t2 := ""
		if r.randf() < 0.6:
			t2 = WorkerMind.TRAITS[r.randi() % WorkerMind.TRAITS.size()]
			if t2 == t1 or ([t1, t2] as Array) in WorkerMind.CLASH or ([t2, t1] as Array) in WorkerMind.CLASH:
				t2 = ""
		var tr: Array = [t1] if t2 == "" else [t1, t2]
		candidates.append({"cid": "CAND-%03d" % _cand_counter, "name": "%s %s" % [FIRST[r.randi() % FIRST.size()], LAST[r.randi() % LAST.size()]], "traits": tr, "look_seed": r.randi() & 0x7fffffff, "fee": econ.hire_fee_cents, "wage": PayMorale.asking_wage("CAND-%03d" % _cand_counter, tr)})


func can_hire() -> Dictionary:
	if Game.hunt and Game.hunt.hunt_active():
		return {"ok": false, "reason": "The company has left the island: no hiring and no boats until the rescue ship."}
	if campaign.contract.is_closed():
		return {"ok": false, "reason": "The company's service has ended with the contract."}
	if slots_used() >= MAX_EMPLOYEES:
		return {"ok": false, "reason": "The crew is full (five). A slot frees when someone has actually left on the boat."}
	if free_bed() == 0:
		return {"ok": false, "reason": "No free bed until someone leaves."}
	return {"ok": true}


## Hires a displayed candidate: pays the fee once, creates a NEW identity
## (never reuses a departed id), assigns a bed and a small company axe;
## they arrive on the next daylight boat.
func hire(cid: String) -> Dictionary:
	var ok := can_hire()
	if not bool(ok.ok):
		return ok
	var cand := {}
	for c in candidates:
		if str(c.cid) == cid:
			cand = c
	if cand.is_empty():
		return {"ok": false, "reason": "That candidate is no longer available."}
	var tx := campaign.wallet.spend(int(cand.fee), "hire", cid, "Hiring fee: %s" % cand.name)
	if tx.is_empty():
		return {"ok": false, "reason": "Not enough cash for the $%s hiring fee." % Money.format_cents(int(cand.fee))}
	_emp_counter = maxi(_emp_counter, payroll.employees.size()) + 1
	var eid := "EMP-%02d" % _emp_counter
	while not payroll.employee(eid).is_empty():
		_emp_counter += 1
		eid = "EMP-%02d" % _emp_counter
	var e := {"id": eid, "name": cand.name, "traits": cand.traits, "status": "pending_arrival", "hired_day": campaign.clock.day, "active_days": [], "worked_days": [], "axe": "", "look_seed": cand.look_seed, "bed": free_bed(), "job": "automatic", "hire_tx": tx.id}
	payroll.employees.append(e)
	minds[eid] = WorkerMind.with_traits(cand.traits)
	_ensure_axe(eid)
	if campaign.pay:
		campaign.pay.on_hired(eid, str(cand.cid), cand.traits)     # starts at their asking wage
	candidates.erase(cand)
	refresh_candidates()
	roster_changed.emit()
	notice.emit("%s hired. They arrive on the next daylight boat at the dock." % cand.name, 6.0)
	return {"ok": true, "id": eid}


# ------------------------------------------------------- firing / quitting

## What firing someone would mean (for the confirmation screen).
func fire_preview(eid: String) -> Dictionary:
	var e := emp(eid)
	var a := equipment_axe_of(eid)
	return {"name": e.get("name", eid), "owed": payroll.owed_for(eid), "due": payroll.due_day_for(eid), "axe": a.get("tier", "none"), "worked_today": campaign.clock.day in (e.get("worked_days", []) as Array), "carrying": timber.load_of(eid).size(), "boat": "next daylight boat" if _boat_running() else "the first boat tomorrow morning", "fee": econ.hire_fee_cents}


func fire(eid: String) -> void:
	start_departure(eid, "fired by the boss")


## Starts a real departure: claims released, load staged on the ground,
## company axe returned to the rack, then a walk to the dock and the boat.
## Earned wages and arrears stay owed.
func start_departure(eid: String, reason: String) -> void:
	var e := emp(eid)
	if e.is_empty() or str(e.status) in ["departing", "departed"]:
		return
	e.status = "departing"
	e["departure_reason"] = reason
	e["departure_day"] = campaign.clock.day
	# Company kit goes back to camp storage (explicit, conserved policy).
	campaign.equipment.return_to_storage(eid)
	var w: Worker = workers.get(eid)
	if w:
		release_claims(w)
		stage_load(w)
		w.refresh_kit_visuals()
		_send_to_dock(w)
		w.say("fired" if reason.begins_with("fired") else ("quit_wages" if reason in ["unpaid wages", "low pay"] else "quit_fear"), true)
	else:
		# Never arrived: the boat simply takes them back.
		_finish_departure(e)
	roster_changed.emit()


## Puts carried logs down at valid spots near the worker (never deletes).
func stage_load(w: Worker) -> void:
	var held: Array = timber.load_of(w.id).duplicate()
	var k := 0
	for sid in held:
		var fwd := -w.global_basis.z
		var p := w.global_position + fwd * (1.0 + 0.35 * k) + w.global_basis.x * 0.3 * k
		var spot := TimberRecovery.find_ground(Vector2(p.x, p.z), 1.6, 0.25, w.get_world_3d(), RID())
		if spot == Vector3.INF:
			spot = Vector3(p.x, World.height_at(p.x, p.z), p.z)
		timber.put_down_for(w.id, sid, spot + Vector3(0, 0.35, 0), w.global_basis.x, true)
		k += 1


func _send_to_dock(w: Worker) -> void:
	w.abandon("departing")
	if not w.go_to(dock_end, "depart_wait", "the dock"):
		w.activity = "depart_wait"     # already there or unreachable: wait in place


func _finish_departure(e: Dictionary) -> void:
	var eid := str(e.id)
	e.status = "departed"
	e["departed_day"] = campaign.clock.day
	e["bed"] = 0
	var w: Worker = workers.get(eid)
	if w:
		release_claims(w)
		workers.erase(eid)
		w.queue_free()
	refresh_candidates()
	roster_changed.emit()
	notice.emit("%s left the island on the boat%s." % [e.name, (" (%s)" % e.get("departure_reason", "")) if e.has("departure_reason") else ""], 6.0)


# ----------------------------------------------------------- the boat/dock

func _build_dock_and_skiff() -> void:
	var ends := get_tree().get_nodes_in_group("ship_boarding")
	if ends.is_empty():
		return
	dock_end = (ends[0] as Node3D).global_position
	dock_end.y = World.sea_level + 0.55
	# Walk inland from the end to the first dry ground: that is the shore end.
	var dir := Vector3(0, 0, -1)
	var p := dock_end
	for i in 200:
		if World.height_at(p.x, p.z) > World.sea_level + 0.2:
			break
		p += dir * 0.5
	dock_shore = Vector3(p.x, World.height_at(p.x, p.z), p.z)
	var dock := Node3D.new()
	dock.name = "ServiceDock"
	add_child(dock)
	var length := Vector2(dock_end.x - dock_shore.x, dock_end.z - dock_shore.z).length() + 1.0
	var mid := (dock_end + dock_shore) * 0.5
	var deck_y := World.sea_level + 0.5
	BuildKit.box(dock, Vector3(2.2, 0.12, length), Vector3(mid.x, deck_y, mid.z + 0.5), "planks", true, 0.0, "Deck")
	var z := 0.0
	while z <= length:
		for sx in [-1.0, 1.0]:
			var post := Vector3(dock_end.x + sx * 1.0, 0.0, dock_end.z - z)
			var bed := World.height_at(post.x, post.z)
			BuildKit.cylinder(dock, 0.1, deck_y - bed + 0.6, Vector3(post.x, (deck_y + bed) * 0.5 + 0.2, post.z), "dark_wood", false, 8)
		z += 2.5
	BuildKit.marker(dock, "DockPickup", dock_end + Vector3(0, -0.5, 0.5), 0.0, "dock_pickup")
	# Phase 23: a shore camera on its own post at the dock's shore end,
	# looking along the beach and the shallows (the only camp camera with
	# the sea in view: wakes, foam, the survey ship, the rescue vessel).
	var res := Game.world_root.find_child("Reservations", true, false) if Game.world_root else null
	if res and res.has_method("_camera"):
		var mount := dock_shore + Vector3(1.6, 0.0, -1.0)
		mount.y = World.height_at(mount.x, mount.z)
		var post := BuildKit.cylinder(dock, 0.045, 2.7, mount + Vector3(0, 1.35, 0), "galvanized", true, 8)
		post.name = "CAM_11_Post"
		var look := dock_shore + Vector3(22.0, 0.0, 16.0)
		look.y = World.sea_level + 0.5
		res.call("_camera", "CAM_11", "dock_shore", mount + Vector3(0, 2.75, 0), look, "post")
	dock.set_meta("note", "Minimal service dock + skiff for crew arrivals/departures (Phase 5 polishes the dock).")
	nav.add_deck(dock_shore, dock_end, deck_y + 0.06)
	# A simple original skiff: hull, gunwales, bench, outboard.
	skiff = Node3D.new()
	skiff.name = "ServiceSkiff"
	add_child(skiff)
	BuildKit.box(skiff, Vector3(1.8, 0.5, 5.2), Vector3(0, 0.15, 0), "camper_paint", false, 0.0, "Hull")
	BuildKit.box(skiff, Vector3(1.4, 0.06, 4.4), Vector3(0, 0.38, 0), "planks", false, 0.0, "Floor")
	BuildKit.box(skiff, Vector3(1.5, 0.08, 0.35), Vector3(0, 0.55, 0.5), "planks", false, 0.0, "Bench")
	BuildKit.box(skiff, Vector3(0.3, 0.7, 0.35), Vector3(0, 0.6, 2.7), "black", false, 0.0, "Outboard")
	for sx in [-0.9, 0.9]:
		BuildKit.box(skiff, Vector3(0.08, 0.18, 5.2), Vector3(sx, 0.45, 0), "camper_stripe", false)
	var out := dock_end + Vector3(0, 0, 160)
	_skiff_path = [out, dock_end + Vector3(2.1, 0, 0)]
	skiff.global_position = Vector3(out.x, World.sea_level, out.z)
	skiff.visible = false


func _boat_running() -> bool:
	var t := campaign.clock.t
	return t >= BOAT_HOURS[0] and t <= BOAT_HOURS[1] and not campaign.contract.is_closed()


func _boat_needed() -> bool:
	for e in payroll.employees:
		if str(e.status) == "pending_arrival":
			return true
		if str(e.status) == "departing":
			var w: Worker = workers.get(str(e.id))
			if w == null or w.activity == "depart_wait":
				return true
	return false


func _update_skiff(delta: float) -> void:
	if skiff == null:
		return
	match skiff_state:
		"away":
			if _boat_running() and _boat_needed():
				skiff_state = "inbound"
				_skiff_t = 0.0
				skiff.visible = true
		"inbound":
			_skiff_t += delta / 25.0
			_place_skiff(_skiff_t)
			if _skiff_t >= 1.0:
				skiff_state = "docked"
				_skiff_t = 0.0
				_skiff_docked()
		"docked":
			_skiff_t += delta
			if _skiff_t > 8.0:
				# Board anyone waiting, then leave.
				for e in payroll.employees:
					if str(e.status) == "departing":
						var w: Worker = workers.get(str(e.id))
						if w == null or (w.activity == "depart_wait" and w.global_position.distance_to(dock_end) < 3.5):
							if w:
								w.activity = "aboard"
								w.reparent(skiff)
							e["boarding"] = true
				skiff_state = "outbound"
				_skiff_t = 1.0
		"outbound":
			_skiff_t -= delta / 25.0
			_place_skiff(maxf(_skiff_t, 0.0))
			if _skiff_t <= 0.0:
				for e in payroll.employees.duplicate():
					if bool(e.get("boarding", false)):
						e.erase("boarding")
						_finish_departure(e)
				skiff_state = "away"
				skiff.visible = false


func _place_skiff(f: float) -> void:
	var a: Vector3 = _skiff_path[0]
	var b: Vector3 = _skiff_path[1]
	var e := 1.0 - pow(1.0 - clampf(f, 0.0, 1.0), 2.0)
	var p := a.lerp(b, e)
	var bob := 0.06 * sin(Game.world_time * 1.7)
	skiff.global_position = Vector3(p.x, World.sea_level + bob - 0.05, p.z)
	skiff.rotation = Vector3(0.02 * sin(Game.world_time * 1.3), 0.0, 0.02 * sin(Game.world_time * 1.1))


func _skiff_docked() -> void:
	for e in payroll.employees:
		if str(e.status) == "pending_arrival":
			if not minds.has(str(e.id)):
				minds[str(e.id)] = WorkerMind.with_traits(e.traits)
			var w := _spawn(e, dock_end)
			e.status = Payroll.ACTIVE
			e["arrival_day"] = campaign.clock.day
			w.say("arrived", true)
			notice.emit("%s stepped off the boat." % e.name, 5.0)
			roster_changed.emit()


# --------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
	if not enabled or get_tree().paused:
		return
	_update_skiff(delta)
	_close_doors()
	coord.tick(delta)
	var c := campaign.clock
	# Wages accrue for each day a person is employed during daylight.
	if c.phase() == WorkdayClock.Phase.DAYLIGHT and _last_day_marked != c.day:
		_last_day_marked = c.day
		for e in payroll.employees:
			if str(e.status) == Payroll.ACTIVE:
				var wd: Array = e.get("worked_days", [])
				if not c.day in wd:
					wd.append(c.day)
				e["worked_days"] = wd
	_share_t -= delta
	if _share_t <= 0.0:
		_share_t = 8.0
		_share_stories()
	for id in workers:
		var w: Worker = workers[id]
		_check_fear_transitions(w)
	merit.day = c.day
	_sample_transport(delta)
	_tick_time_ledger(delta)
	if routine:
		routine.tick()


var _last_fear_state := {}

func _check_fear_transitions(w: Worker) -> void:
	var s := w.mind.state
	var prev := int(_last_fear_state.get(w.id, 0))
	if s == prev:
		return
	_last_fear_state[w.id] = s
	if s > prev:
		match s:
			WorkerMind.Fear.DISTRESSED:
				w.say("concern", false)
			WorkerMind.Fear.REFUSING_RISK:
				w.say("refuse_risk", true)
				if w.activity in ["fell", "buck"] and w.global_position.distance_to(World.camp_origin()) > 70.0:
					w.abandon("refusing risk")
			WorkerMind.Fear.DEPARTURE_WARNING:
				w.say("departure_warning", true)
			WorkerMind.Fear.QUITTING:
				start_departure(w.id, w.mind.quit_reason if w.mind.quit_reason != "" else "fear")


func mind_context(w: Worker) -> Dictionary:
	var near := 0
	for o in workers.values():
		if o != w and (o as Worker).global_position.distance_to(w.global_position) < 12.0:
			near += 1
	var c := campaign.clock
	var inside := nav.in_camp(w.global_position) and w.activity in ["sleep", "sit"]
	return {"daylight": c.phase() == WorkdayClock.Phase.DAYLIGHT, "near_colleagues": near, "safe_inside": inside, "isolated_at_dusk": c.phase() != WorkdayClock.Phase.DAYLIGHT and near == 0 and not nav.in_camp(w.global_position), "arrears": payroll.owed_for(w.id) > 0}


## Colleagues near each other share what they saw (once per memory).
func _share_stories() -> void:
	var t := now()
	for a in workers.values():
		var wa := a as Worker
		var m := wa.mind.strongest_memory()
		if m.is_empty():
			continue
		for b in workers.values():
			var wb := b as Worker
			if wb == wa or wb.global_position.distance_to(wa.global_position) > 8.0:
				continue
			var key := "%s|%s" % [wb.id, str(m.id)]
			if _shared.has(key):
				continue
			var already := false
			for own in wb.mind.memories:
				if str(own.id) == str(m.id):
					already = true
			_shared[key] = true
			if not already:
				wb.mind.hear_coworker(t, m, wa.id)


# ------------------------------------------------------------ job choices

## Central decision for an idle worker (also the late-day safety gate).
## Phase 16 wrapper: after each decision the worker's pending break is
## settled - a break if work was waiting, otherwise the REAL cause (yard
## full, missing tool, blocked route, fear, nothing to do).
func decide(w: Worker) -> void:
	_decide_inner(w)
	if w.activity != "idle":
		w.idle_reason = ""
		progression.settle_pause(w.id, true)
	else:
		var cause := idle_cause(w)
		progression.settle_pause(w.id, false, cause)
		w.idle_reason = cause


func _decide_inner(w: Worker) -> void:
	var e := w.emp
	var c := campaign.clock
	if w.seated:
		return
	apply_pending_equip(w)
	if Game.hunt and Game.hunt.hunt_active():
		Game.hunt.worker_decide(w)
		return
	if Game.vehicles and str(e.status) == Payroll.ACTIVE and Game.vehicles.team_decide(w):
		return
	match str(e.status):
		"departing":
			_send_to_dock(w)
			return
		"departed":
			return
	if campaign.contract.is_closed() or c.phase() == WorkdayClock.Phase.NIGHT:
		send_home(w)
		return
	var left := real_time_left()
	var ret := return_seconds(w)
	var margin := w.mind.return_margin()
	if left < ret + margin:
		if not w._warned.has("return_%d" % c.day):
			w._warned["return_%d" % c.day] = true
			w.say("dusk_return", true)
		send_home(w)
		return
	if left < ret + margin + 60.0 and not w._warned.has("remind_%d" % c.day):
		w._warned["remind_%d" % c.day] = true
		w.say("dusk_reminder", true)
	if w.is_carrying():
		send_to_rack(w)
		return
	var job := str(e.get("job", "automatic"))
	# Phase 13 yard: assigned yard hands always, others when intake is
	# nearly blocked (cradle filling up) or the fire is about to run dry.
	if job == "yard":
		if not try_yard(w):
			w.go_to(CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(0, 0, 4.5)), "idle", "the yard")
		return
	if job == "automatic" and Game.yard and (Game.yard.cradle_free() <= 3 or (Game.yard.pit_free() >= CampLayout.PIT_QUEUE_CAP - 1 and Game.yard.stock_count() > Game.yard.cradle.size())) and try_yard(w):
		return
	match job:
		"ride":
			var t: Truck = Game.vehicles.ride_target() if Game.vehicles else null
			if t == null or t.free_seat() == "" or t.free_seat() == "driver" and t.seats.middle != "" and t.seats.right != "":
				w.activity = "follow"
				return
			var door := t.door_point(1.0)
			if w.global_position.distance_to(door) < 1.3:
				var seat := "middle" if t.seats.middle == "" else ("right" if t.seats.right == "" else "")
				if seat != "":
					Game.vehicles.board(w, t, seat)
			else:
				w.go_to(door, "idle", "the truck")
		"follow":
			w.activity = "follow"
		"home":
			send_home(w)
		"felling":
			_try_fell(w)
		"processing":
			if not _try_buck(w):
				_try_stump(w)
		"hauling":
			_try_haul(w)
		_:
			_auto(w)


## Bottleneck first: loose logs nobody carries, then trunks nobody bucks,
## then new trees - so the crew never fells endlessly while wood piles up.
func _auto(w: Worker) -> void:
	var focus := work_focus(w)
	var loose := _loose_pieces(focus, w).size()
	var trunks := _trunks(focus, w).size()
	# Phase 14 downstream backlog: when the yard is nearly full, moving paid
	# logs to the fire comes before cutting more (no dumping unpaid wood
	# at a full cradle).
	var yard_full := Game.yard != null and Game.yard.cradle_free() == 0 and Game.yard.deck_free_estimate() < 10
	if yard_full and try_yard(w):
		return
	# Phase 19: today's role decides what to try first.
	if routine and routine.try_role_first(w):
		return
	# Stage division: the saw is wasted carrying logs, so saw holders cut
	# while axe hands haul first when anything is waiting.
	var saw := w.axe_tier() == "chainsaw"
	if saw and trunks > 0 and _try_buck(w):
		return
	if (loose >= 3 or (loose > 0 and not saw)) and _try_haul(w):
		return
	if trunks > 0 and axe_ok(w) and _try_buck(w):
		return
	if loose > 0 and _try_haul(w):
		return
	# Phase 7: stumps are contract targets - chop them out before felling more.
	if axe_ok(w) and _try_stump(w):
		return
	# Never fell more while trunks wait to be bucked or logs wait to be
	# carried (the bottleneck rule); only fell into a clear area.
	if trunks == 0 and loose == 0 and not yard_full and axe_ok(w) and _try_fell(w):
		return
	if saw and loose < 3 and trunks == 0 and not yard_full and axe_ok(w) and _try_fell(w):
		return              # a saw keeps felling while axe hands catch up
	w.activity = "idle"
	w._decide_cd = 3.0


## Mid-task safety: if the time left before night no longer covers the
## walk home plus margin, stop now and head back.
func check_time(w: Worker) -> void:
	if str(w.emp.status) != Payroll.ACTIVE or w.seated:
		return
	# Truck teams return together; the team checks its own (longer) margin.
	if Game.vehicles and not Game.vehicles.team_of(w).is_empty():
		return
	var left := real_time_left()
	if campaign.clock.phase() == WorkdayClock.Phase.NIGHT or left < return_seconds(w) + w.mind.return_margin():
		if not w._warned.has("return_%d" % campaign.clock.day):
			w._warned["return_%d" % campaign.clock.day] = true
			w.say("dusk_return", true)
		w.abandon("time to go home")
		send_home(w)


## A target that defeated repeated path attempts is skipped until morning.
func mark_unreachable(w: Worker) -> void:
	if w.target.has("tree"):
		claims["tree:%d" % int(w.target.tree)] = "unreachable"
		claims["trunk:%d" % int(w.target.tree)] = "unreachable"
	for sid in w.target.get("pick", []):
		timber.claims[sid] = "unreachable"
		_unreachable_sids.append(sid)


func axe_ok(w: Worker) -> bool:
	return w.axe_tier() != ""


func work_focus(w: Worker) -> Vector3:
	var f: Array = w.emp.get("focus", [])
	if f.size() == 3:
		return Vector3(f[0], f[1], f[2])
	var o := World.camp_origin()
	return Vector3(o.x, 0, o.z - CampLayout.FENCE_HALF.y - 25.0)


func search_radius(w: Worker) -> float:
	# Refusing risk: only close to camp.
	return 60.0 if w.mind.refuses_risk() else SEARCH_RADIUS


## Phase 14: hands an item from the boss or camp storage to an employee.
## Ownership moves now (one owner, never duplicated); the worker straps it
## on at their next safe boundary (between jobs, nothing in hand), so a cut
## or a carried log is never interrupted or changed halfway.
func issue(item_id: String, eid: String) -> Dictionary:
	var e := emp(eid)
	if e.is_empty() or str(e.status) != Payroll.ACTIVE:
		return {"ok": false, "reason": "Only active employees can be issued gear."}
	var a := campaign.equipment.item(item_id)
	if a.is_empty():
		return {"ok": false, "reason": "No such item."}
	var holder := str(a.owner)
	if holder != "boss" and holder != "storage":
		return {"ok": false, "reason": "%s is %s." % [GearCatalog.display_name(str(a.kind), str(a.tier)), campaign.equipment.where_words(a)]}
	var r := campaign.equipment.transfer(item_id, eid)
	if not bool(r.ok):
		return r
	var pend: Array = e.get("pending_equip", [])
	pend.append(item_id)
	e["pending_equip"] = pend
	var w: Worker = workers.get(eid)
	if w:
		apply_pending_equip(w)
	return {"ok": true, "pending": w == null or not (e.get("pending_equip", []) as Array).is_empty()}


## Takes an item back from an employee into camp storage - refused while
## they are cutting or carrying (no tool vanishes mid-swing).
func recall(item_id: String) -> Dictionary:
	var a := campaign.equipment.item(item_id)
	if a.is_empty():
		return {"ok": false, "reason": "No such item."}
	var w: Worker = workers.get(str(a.owner))
	if w and (w.activity in ["fell", "buck", "stump"] or w.is_carrying()):
		return {"ok": false, "reason": "%s is %s - ask again when they're between jobs." % [w.emp.name, w.activity_words()]}
	var e := emp(str(a.owner))
	if not e.is_empty():
		(e.get("pending_equip", []) as Array).erase(item_id)
	return campaign.equipment.transfer(item_id, "storage")


func apply_pending_equip(w: Worker) -> void:
	var pend: Array = w.emp.get("pending_equip", [])
	if pend.is_empty() or w.activity in ["fell", "buck", "stump", "seated", "sleep", "hidden"] or w.is_carrying():
		return
	for id in pend.duplicate():
		var a := campaign.equipment.item(str(id))
		if not a.is_empty() and str(a.owner) == w.id:
			campaign.equipment.equip(w.id, str(id))
	w.emp["pending_equip"] = []
	w.refresh_kit_visuals()


## Phase 14: a worker's equipped kit (ToolEffects form). Hard-working is
## the trait's single cutting factor.
func kit(w: Worker) -> Dictionary:
	var k: Dictionary = campaign.equipment.kit_of(w.id) if campaign and campaign.equipment else {"tool": "axe", "tier": "small"}
	k["hard_working"] = w.mind != null and w.mind.has("hard_working")
	# Phase 16: the ONE capped skill factor (cutting skill; career level
	# multiplies nothing). Recomputed when a skill level changes.
	k["skill"] = progression.cut_factor(w.id)
	return k


var _fx := {}


func tool_effects(w: Worker) -> Dictionary:
	if campaign and campaign.equipment and not campaign.equipment.changed.is_connected(_on_equipment_changed):
		campaign.equipment.changed.connect(_on_equipment_changed)
	if not _fx.has(w.id):
		_fx[w.id] = ToolEffects.breakdown(kit(w))
	return _fx[w.id]


## Equipment moved: effects are recomputed and each worker shows what they
## actually hold (tool and gear).
func _on_equipment_changed() -> void:
	_fx.clear()
	for w in workers.values():
		(w as Worker).refresh_kit_visuals()


## Axe work per valid contact (0 for no axe; a saw works per tick).
func work_per_contact(w: Worker) -> float:
	var k := kit(w)
	if str(k.tool) != "axe":
		return 0.0
	return float(ToolEffects.breakdown(k).work_per_contact)


func carry_budget(w: Worker) -> int:
	return int(round(TimberService.HAND_BUDGET_MTE * (CampaignRules.STRONGER_CARRY_MULTIPLIER if w.mind.has("stronger") else 1.0)))


func claim(key: String, w: Worker) -> bool:
	if claims.has(key) and claims[key] != w.id:
		return false
	claims[key] = w.id
	return true


func release_claims(w: Worker) -> void:
	for k in claims.keys():
		if claims[k] == w.id:
			claims.erase(k)
	for sid in timber.claims.keys():
		if timber.claims[sid] == w.id and not sid in timber.load_of(w.id):
			timber.claims.erase(sid)


func _try_fell(w: Worker) -> bool:
	var focus := work_focus(w)
	var rad := search_radius(w)
	var best := -1
	var best_d := INF
	var key0 := PlacementValidator._key(focus.x, focus.z, 8.0)
	var rings := int(ceil(rad / 8.0))
	var seen := {}
	for ring in rings + 1:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				for i in nav._tree_hash.get(key0 + Vector2i(dx, dz), []):
					if seen.has(i):
						continue
					seen[i] = true
					var tid: int = World.trees.id[i]
					if World.removed_trees.has(tid) or claims.has("tree:%d" % tid):
						continue
					var st := trees.state_of(tid)
					if st != TreeService.State.STANDING and st != TreeService.State.NOTCHED:
						continue
					var tp := Vector3(World.trees.x[i], 0, World.trees.z[i])
					if nav.in_camp(tp) or Vector2(tp.x - focus.x, tp.z - focus.z).length() > rad:
						continue
					if _someone_felling_near(tp, w):
						continue
					# Phase 14: no tree whose fall line crosses live work.
					if coord.fell_conflict(i, w.global_position, w):
						continue
					var d := Vector2(tp.x - w.global_position.x, tp.z - w.global_position.z).length()
					if d < best_d:
						best_d = d
						best = i
		if best >= 0 and ring >= 2:
			break
	if best < 0:
		return false
	var tid: int = World.trees.id[best]
	var stands := PlacementValidator.cut_stands(best, nav._tree_hash, _rock_hash)
	var base := World.tree_position(best)
	var stand := Vector3.INF
	var sd := INF
	for s in stands:
		if not nav.walkable(s, true):
			continue
		var d := s.distance_to(w.global_position)
		if d < sd:
			sd = d
			stand = s
	if stand == Vector3.INF:
		claims["tree:%d" % tid] = "unreachable"
		return false
	var away := Vector3(stand.x - base.x, 0, stand.z - base.z).normalized()
	var side := Vector3(-away.z, 0, away.x)
	var retreat := stand + away * 4.5 + side * 1.5
	if not nav.walkable(retreat, true):
		retreat = stand + away * 4.5 - side * 1.5
	if not nav.walkable(retreat, true):
		retreat = stand + away * 3.0
	retreat.y = nav.surface_at(retreat)
	if not claim("tree:%d" % tid, w):
		return false
	if coord.fell_conflict(best, stand, w):
		claims.erase("tree:%d" % tid)
		return false
	if not w.start_fell(tid, stand, retreat):
		claims.erase("tree:%d" % tid)
		claims["tree:%d" % tid] = "unreachable"
		return false
	coord.register_lane(tid, w, stand)
	return true


func _someone_felling_near(p: Vector3, me: Worker) -> bool:
	for o in workers.values():
		var w := o as Worker
		if w != me and w.activity in ["fell", "move"] and w.target.has("tree"):
			var tid: int = w.target.tree
			var i: int = Game.vegetation.tree_index_by_id.get(tid, tid)
			# Phase 14: fall lanes handle the danger zone; this only keeps two
			# fellers from crowding the same few trees.
			if Vector2(World.trees.x[i] - p.x, World.trees.z[i] - p.z).length() < 8.0:
				return true
	return false


func _trunks(focus: Vector3, w: Worker) -> Array:
	var out := []
	var rad := search_radius(w)
	for key in timber.bodies:
		var b: TimberBody = timber.bodies[key]
		if b.is_single_piece() or not b.is_resting() or claims.has("trunk:%d" % b.tree_id):
			continue
		if coord.lane_at(b.global_position, w.id) >= 0:
			continue
		if b.global_position.distance_to(focus) > rad + 20.0:
			continue
		out.append(b)
	return out


## Phase 7: stumps left by sectioned trees (required contract targets)
## within reach of the work focus, unclaimed.
func _stumps(focus: Vector3, w: Worker) -> Array:
	var out := []
	var rad := search_radius(w)
	var idx: Dictionary = Game.vegetation.get("tree_index_by_id") if Game.vegetation else {}
	for id in trees.records:
		if int(trees.records[id].state) != TreeService.State.SECTIONED:
			continue
		if claims.has("stump:%d" % int(id)):
			continue
		var i: int = idx.get(int(id), -1)
		if i < 0:
			continue
		var p := World.tree_position(i)
		if p.distance_to(focus) > rad + 20.0:
			continue
		if coord.lane_at(p, w.id) >= 0:
			continue
		out.append(i)
	return out


func _try_stump(w: Worker) -> bool:
	var best := -1
	var best_d := INF
	for i in _stumps(work_focus(w), w):
		var d := World.tree_position(i).distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	var id := int(World.trees.id[best])
	var stands := PlacementValidator.cut_stands(best)
	if stands.is_empty() or not claim("stump:%d" % id, w):
		return false
	var stand := stands[0]
	for s in stands:
		if s.distance_to(w.global_position) < stand.distance_to(w.global_position):
			stand = s
	if not w.start_stump(id, World.tree_position(best), stand):
		claims.erase("stump:%d" % id)
		return false
	return true


## Phase 10: unique contribution hooks for later merit (no XP yet).
var contributions := Contributions.new()


func on_stump_removed(w: Worker, tid := -1) -> void:
	stats[w.id]["stumps"] = int(stats[w.id].get("stumps", 0)) + 1
	if tid >= 0:
		contributions.stage(w.id, "stump", str(tid))


func _try_buck(w: Worker) -> bool:
	var best: TimberBody = null
	var best_d := INF
	for b in _trunks(work_focus(w), w):
		var d := (b as TimberBody).global_position.distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = b
	if best == null:
		return false
	var rec: Dictionary = best.rec
	var y := float(rec.merch_top) if best.crown else float(rec.segments[best.ks.max() - 1].b)
	var at := best.global_transform * Vector3(0, y, 0)
	var stand := stand_beside(at, best.axis_samples(2), w.global_position)
	if stand == Vector3.INF or not claim("trunk:%d" % best.tree_id, w):
		return false
	if not w.start_buck(best, y, stand):
		claims.erase("trunk:%d" % best.tree_id)
		return false
	return true


## The body that currently contains boundary `y` of tree `tid`.
func body_for_cut(tid: int, y: float) -> TimberBody:
	for key in timber.bodies:
		var b: TimberBody = timber.bodies[key]
		if b.tree_id != tid or b.is_single_piece():
			continue
		var sp := b.span()
		if y > sp.x + 0.05 and y < sp.y + 0.6:
			return b
	return null


## A standing spot beside a log at `at`, perpendicular to its axis, on the
## side nearer `from`.
func stand_beside(at: Vector3, samples: Array, from: Vector3) -> Vector3:
	var axis := Vector3.RIGHT
	if samples.size() >= 2:
		axis = ((samples[samples.size() - 1][0] as Vector3) - (samples[0][0] as Vector3))
		axis.y = 0.0
		axis = axis.normalized() if axis.length() > 0.01 else Vector3.RIGHT
	var perp := axis.cross(Vector3.UP).normalized()
	var r := 0.3
	if samples.size() > 0:
		r = float(samples[0][1])
	var best := Vector3.INF
	var bd := INF
	for s in [1.0, -1.0]:
		for off in [r + 0.8, r + 1.2]:
			var p: Vector3 = at + perp * s * float(off)
			if not nav.walkable(p, true):
				continue
			p.y = nav.surface_at(p)
			var d := p.distance_to(from)
			if d < bd:
				bd = d
				best = p
	return best


func _loose_pieces(focus: Vector3, w: Worker) -> Array:
	var out := []
	var rad := search_radius(w)
	for key in timber.bodies:
		var b: TimberBody = timber.bodies[key]
		if not b.is_single_piece() or not b.is_resting():
			continue
		var sid: String = b.sid_list()[0]
		if timber.claims.has(sid):
			continue
		if nav.in_camp(b.global_position):
			# Logs dropped inside camp are fair game too, but not on the rack.
			pass
		if b.global_position.distance_to(focus) > rad + 20.0:
			continue
		if coord.lane_at(b.global_position, w.id) >= 0:
			continue
		out.append(b)
	return out


func _try_haul(w: Worker) -> bool:
	var pieces := _loose_pieces(work_focus(w), w)
	if pieces.is_empty():
		return false
	pieces.sort_custom(func(a: TimberBody, b: TimberBody) -> bool: return a.global_position.distance_to(w.global_position) < b.global_position.distance_to(w.global_position))
	var first: TimberBody = pieces[0]
	var budget := carry_budget(w) - timber.carrier_mte(w.id)
	var pick: Array = []
	var total := 0
	for p in pieces:
		var b := p as TimberBody
		if b.global_position.distance_to(first.global_position) > 10.0:
			continue
		var sid: String = b.sid_list()[0]
		var m := int(timber.segment(sid).mte)
		if total + m > budget + 2 or pick.size() >= 4:
			continue
		if timber.claim(sid, w.id):
			pick.append(sid)
			total += m
	# Phase 13: nothing liftable nearby, but an oversized log (up to two hand
	# loads) can be dragged by one end, alone and slowly.
	if pick.is_empty() and timber.carrier_mte(w.id) == 0:
		for p in pieces:
			var b2 := p as TimberBody
			var sid2: String = b2.sid_list()[0]
			var m2 := int(timber.segment(sid2).mte)
			if m2 > carry_budget(w) and m2 <= carry_budget(w) * 2 + 2 and timber.claim(sid2, w.id):
				pick.append(sid2)
				break
	if pick.is_empty():
		return false
	var drag := timber.carrier_mte(w.id) == 0 and pick.size() == 1 and int(timber.segment(str(pick[0])).mte) > carry_budget(w)
	if not w.start_pick(pick):
		return false
	if drag:
		w.target["drag"] = true
		# Phase 14: ask a free crewmate to take the far end (falls back to a
		# solo drag if nobody comes).
		coord.form_team(w, str(pick[0]))
	return true


# ------------------------------------------------------------ yard (P13)

## A yard move for an idle worker: clear the receiving cradle onto the
## decks first (intake needs free slots), else keep the fire's loading pile
## stocked from the decks. Reservations live in YardService; a worker holds
## at most one yard log and always finishes at a valid place.
func try_yard(w: Worker) -> bool:
	var y: YardService = Game.yard
	if y == null or timber.carrier_mte(w.id) > 0:
		return false
	var held_by_others := 0
	for sid in y.moving:
		if str(y.moving[sid].carrier) != "player":
			held_by_others += 1
	if held_by_others >= 2 and str(w.emp.get("job", "")) != "yard":
		return false
	if not y.cradle.is_empty() and y.nearest_deck(CampLayout.world(CampLayout.DELIVERY_RACK_POS), y.cradle[0]) >= 0:
		if claim("yard:cradle", w):
			if w.go_to(CampLayout.world(CampLayout.DELIVERY_STANDPOINTS[0]), "yard_take", "the receiving cradle"):
				w.target["yard_from"] = "cradle"
				return true
			claims.erase("yard:cradle")
	if y.pit_free() > 0:
		for i in y.decks.size():
			if (y.decks[i] as Array).is_empty() or not claim("yard:deck%d" % i, w):
				continue
			if w.go_to(CampLayout.world(CampLayout.deck_standpoint(i)), "yard_take", "deck %d" % (i + 1)):
				w.target["yard_from"] = "deck:%d" % i
				return true
			claims.erase("yard:deck%d" % i)
	return false


func release_yard_claims(w: Worker) -> void:
	for k in claims.keys():
		if str(k).begins_with("yard:") and claims[k] == w.id:
			claims.erase(k)


## Where a worker takes a yard log it holds (its reserved destination).
func yard_destination_point(sid: String) -> Vector3:
	var y: YardService = Game.yard
	var dest := str(y.moving[sid].dest) if y.moving.has(sid) else "pit"
	if dest.begins_with("deck:"):
		return CampLayout.world(CampLayout.deck_standpoint(int(dest.get_slice(":", 1))))
	return CampLayout.world(CampLayout.PIT_LOAD_POS + Vector3(0, 0, 1.4))


func send_to_rack(w: Worker) -> bool:
	# Phase 13: paid yard logs go to their reserved deck or the fire pile.
	if Game.yard and w.is_carrying() and Game.yard.is_yard_move(str(timber.load_of(w.id)[0])):
		var sid0: String = timber.load_of(w.id)[0]
		if w.go_to(yard_destination_point(sid0), "yard_drop", "the yard"):
			return true
		Game.yard.return_to_origin(sid0)
		return false
	# Phase 13: cradle full -> deliver straight onto a deck with room.
	if Game.yard and Game.yard.cradle_free() <= 0 and w.is_carrying() and not (Game.vehicles and Game.vehicles.haul_target(w)):
		var dk := Game.yard.nearest_deck(w.global_position, str(timber.load_of(w.id)[0]))
		if dk >= 0 and w.go_to(CampLayout.world(CampLayout.deck_standpoint(dk)), "deliver_deck", "deck %d" % (dk + 1)):
			w.target["deck"] = dk
			return true
	# Team members and people riding with the boss load the nearby truck.
	if Game.vehicles:
		var t: Truck = Game.vehicles.haul_target(w)
		if t and w.go_to(t.tailgate_point(), "load_truck", "the truck"):
			return true
	var pts: Array = CampLayout.DELIVERY_STANDPOINTS
	for i in pts.size():
		if claim("rack:%d" % i, w):
			var p := CampLayout.world(pts[i])
			if w.go_to(p, "deliver", "the delivery rack"):
				return true
			claims.erase("rack:%d" % i)
	# All rack places busy: wait nearby in a short queue.
	var q := CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(0, 0, 4.5))
	w.go_to(q, "idle", "the rack queue")
	return true


func release_rack_slot(w: Worker) -> void:
	for i in 3:
		if claims.get("rack:%d" % i, "") == w.id:
			claims.erase("rack:%d" % i)


# ---------------------------------------------------------------- home/bed

## Seconds of real time until night (the review route can speed the clock).
func real_time_left() -> float:
	return campaign.clock.time_until_night() / maxf(campaign.clock.speed, 0.01)


## Conservative return estimate: route length at walking (or carrying)
## speed, plus doors and putting down a load.
func return_seconds(w: Worker) -> float:
	var home := bed_approach(w)
	var dist := w.global_position.distance_to(home) * 1.35
	var cache: Array = w.target.get("ret_cache", [])
	if cache.size() == 2 and now() - float(cache[0]) < 20.0:
		dist = float(cache[1])
	elif dist > 60.0:
		var p := nav.find_path(w.global_position, home)
		if not p.is_empty():
			dist = CrewNav.path_length(p)
			w.target["ret_cache"] = [now(), dist]
	return return_estimate(dist, w.is_carrying())


static func return_estimate(path_len: float, carrying: bool) -> float:
	return path_len / (Worker.CARRY_WALK if carrying else Worker.WALK) + 12.0 + (8.0 if carrying else 0.0)


func bed_approach(w: Worker) -> Vector3:
	var b := bed_node(int(w.emp.get("bed", 0)))
	if b == null:
		return World.camp_origin()
	var bb := b.get_parent() as Node3D
	for side in [1.0, -1.0]:
		var p := bb.global_transform * Vector3(0.85 * side, 0, 0.2)
		if nav.walkable(p):
			return Vector3(p.x, nav.surface_at(p), p.z)
	return bb.global_position


func send_home(w: Worker) -> void:
	if w.activity in ["sleep", "sit", "home_arrived"]:
		return
	if w.is_carrying():
		# On the way home, deliver if the rack is close enough to the route.
		var rack := CampLayout.world(CampLayout.DELIVERY_RACK_POS)
		if w.global_position.distance_to(rack) < 60.0 or nav.in_camp(w.global_position):
			send_to_rack(w)
			return
	release_claims(w)
	if not w.go_to(bed_approach(w), "home_arrived", "the cabin"):
		w.activity = "idle"
		w._decide_cd = 4.0


func on_home(w: Worker) -> void:
	var c := campaign.clock
	if c.phase() == WorkdayClock.Phase.NIGHT or str(w.emp.get("job", "")) != "home" and c.time_until_night() < 120.0:
		var b := bed_node(int(w.emp.get("bed", 0)))
		if b:
			w.lie_down(b)
			return
	# Evening: sit at a free seat until night.
	for s in get_tree().get_nodes_in_group("worker_seat"):
		if claim("seat:%s" % s.name, w):
			w.sit_at(s)
			return
	w.activity = "sit"


func _on_night(_d: int) -> void:
	for e in payroll.employees:
		if str(e.status) == Payroll.ACTIVE and payroll.owed_for(str(e.id)) > 0:
			progression.add_context("owed_wages", str(e.id), "$%s" % Money.format_cents(payroll.owed_for(str(e.id))), [str(e.id)])
	_note_waiting_frustration()
	for w in workers.values():
		var wk := w as Worker
		if wk.activity == "sit":
			release_claims(wk)
			var b := bed_node(int(wk.emp.get("bed", 0)))
			if b:
				wk.get_up(bed_approach(wk))
				wk.lie_down(b)
		elif not wk.activity in ["sleep", "depart_wait", "aboard"]:
			send_home(wk)


func _on_morning(_d: int) -> void:
	if routine:
		routine.plan_day(campaign.clock.day)
	for w in workers.values():
		var wk := w as Worker
		if wk.activity in ["sleep", "sit"]:
			release_claims(wk)
			wk.get_up(bed_approach(wk))
		wk._warned.clear()
	for id in minds:
		var m: WorkerMind = minds[id]
		if m.end_of_day(campaign.clock.day - 1) and workers.has(id):
			start_departure(id, m.quit_reason)
	for k in claims.keys():
		if claims[k] == "unreachable":
			claims.erase(k)
	for sid in _unreachable_sids:
		if timber.claims.get(sid, "") == "unreachable":
			timber.claims.erase(sid)
	_unreachable_sids.clear()


# ------------------------------------------------------------------- doors

func open_doors_near(p: Vector3) -> void:
	for d in get_tree().get_nodes_in_group("doors"):
		var door := d as Door
		if door.global_position.distance_to(p) < 1.8:
			if not door.is_open:
				door.set_open(true)
			_door_open[door] = now()


func _close_doors() -> void:
	for door in _door_open.keys():
		if not is_instance_valid(door):
			_door_open.erase(door)
			continue
		# Only close what the crew opened and is still open: once it's shut
		# (by anyone) or the player opened it themselves, it isn't ours.
		if not (door as Door).is_open or (door as Door).opened_by_player:
			_door_open.erase(door)
			continue
		if now() - float(_door_open[door]) < 4.0:
			continue
		var busy := Game.player != null and (Game.player as Node3D).global_position.distance_to(door.global_position) < 2.5
		for w in workers.values():
			if (w as Worker).global_position.distance_to(door.global_position) < 2.5:
				busy = true
		if not busy:
			(door as Door).set_open(false)
			_door_open.erase(door)


# --------------------------------------------------------------- feedback

func _on_said(w: Worker, text: String, important: bool) -> void:
	TerrorDirector.remember_voice(str(w.emp.name), text, w.global_position)
	var near := Game.player != null and (Game.player as Node3D).global_position.distance_to(w.global_position) < 25.0
	if important or near:
		notice.emit("%s: \"%s\"" % [w.emp.name, text], 5.0 if important else 3.5)


func on_felled(w: Worker, tid: int) -> void:
	stats[w.id].felled = int(stats[w.id].felled) + 1
	contributions.stage(w.id, "felled", str(tid))


func on_bucked(w: Worker) -> void:
	stats[w.id].bucked = int(stats[w.id].bucked) + 1


func on_delivered_to_truck(w: Worker, n: int) -> void:
	stats[w.id]["loaded_to_truck"] = int(stats[w.id].get("loaded_to_truck", 0)) + n


func on_delivered(w: Worker, receipts: Array) -> void:
	for r in receipts:
		stats[w.id].delivered_mte = int(stats[w.id].delivered_mte) + int(r.mte)
		contributions.stage(w.id, "accepted", str(r.get("sid", r.get("id", ""))))


func _on_log_settled(b: TimberBody, delta: int) -> void:
	var pts := []
	for s in b.axis_samples(4):
		pts.append(s[0])
	nav.mark_log(pts, delta)


func log_stuck(w: Worker) -> void:
	stuck_log.append({"worker": w.id, "at": [snappedf(w.global_position.x, 0.1), snappedf(w.global_position.z, 0.1)], "activity": w.activity, "day": campaign.clock.day, "t": snappedf(campaign.clock.t, 0.1)})
	if stuck_log.size() > 60:
		stuck_log.pop_front()


# ------------------------------------------------------------- perception

## A stimulus from the world (later: the Terror director; now: development
## fixtures). Each worker checks it against their own senses: distance,
## line of sight / occlusion, facing for sight, asleep or indoors.
## stim: {id, kind, modality, pos, loudness (sound radius /60 m),
##        severity, ambiguous, ordinary, imitates}
func emit_stimulus(stim: Dictionary) -> Array:
	var who := []
	var pos: Vector3 = stim.pos
	var space := get_viewport().world_3d.direct_space_state
	var night := campaign.clock.phase() != WorkdayClock.Phase.DAYLIGHT
	for w in workers.values():
		var wk := w as Worker
		if str(wk.emp.status) in ["departed"] or wk.activity == "aboard":
			continue
		var head := wk.global_position + Vector3(0, 1.6, 0)
		var d := head.distance_to(pos)
		var asleep := wk.activity == "sleep"
		var blocked := false
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), head, 1)
		q.exclude = [wk.col.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(head) > 0.6:
			blocked = true
		var perceived := false
		var conf := 0.0
		var obs := 1.25 if wk.mind.has("observant") else 1.0
		match str(stim.get("modality", "sound")):
			"sight":
				var facing := -wk.global_basis.z
				var to := (pos - head).normalized()
				var max_d := (22.0 if night else 50.0) * obs
				if not asleep and not blocked and d < max_d and facing.dot(to) > cos(deg_to_rad(70.0)):
					perceived = true
					conf = clampf(1.0 - d / max_d * 0.5, 0.5, 0.95)
			_:
				var radius := 60.0 * float(stim.get("loudness", 1.0)) * obs
				if asleep:
					radius *= 0.4
				if blocked:
					radius *= 0.5
				if d < radius:
					perceived = true
					conf = clampf(0.75 - d / radius * 0.4, 0.3, 0.75)
					if str(stim.get("modality", "")) == "voice":
						conf += 0.1
		if not perceived:
			continue
		var info := {"confidence": conf, "asleep": asleep}
		var imit := str(stim.get("imitates", ""))
		if imit != "" and workers.has(imit):
			info["imitated_is_present"] = (workers[imit] as Worker).global_position.distance_to(wk.global_position) < 5.0
		var mem := wk.mind.perceive(stim, now(), info)
		if not mem.is_empty():
			who.append(wk.id)
			# Phase 17 context: only this worker knows what they perceived.
			progression.add_context("strange_" + str(stim.get("modality", "sound")), wk.id, str(stim.get("kind", "")), [wk.id])
			if wk.mind.severe_while_warning(float(stim.get("severity", 0.0))):
				start_departure(wk.id, wk.mind.quit_reason)
	return who


## The boss tells a worker something happened (rumor unless corroborated).
func boss_report(w: Worker) -> String:
	var corroborated := false
	for o in workers.values():
		if o != w and (o as Worker).mind.firsthand_count() > 0 and (o as Worker).global_position.distance_to(w.global_position) < 15.0:
			corroborated = true
	return w.mind.hear_boss_report(now(), corroborated)


# ------------------------------------------------------------- save/load

func capture() -> Dictionary:
	var ws := {}
	for id in workers:
		ws[id] = (workers[id] as Worker).capture()
	var ms := {}
	for id in minds:
		ms[id] = (minds[id] as WorkerMind).capture()
	return {"version": 1, "enabled": enabled, "workers": ws, "minds": ms, "candidates": candidates.duplicate(true), "cand_counter": _cand_counter, "emp_counter": _emp_counter, "skiff": {"state": skiff_state, "t": _skiff_t}, "stats": stats.duplicate(true), "stuck_log": stuck_log.slice(-20), "contributions": contributions.capture(), "merit": merit.capture(), "progression": progression.capture(), "talk": talk.capture()}


## Restores the crew without duplicating anyone: one Worker per active or
## departing identity; positions repaired to walkable ground if needed.
func restore(d: Dictionary) -> void:
	for w in workers.values():
		(w as Node).queue_free()
	workers.clear()
	claims.clear()
	minds.clear()
	for id in d.get("minds", {}):
		minds[str(id)] = WorkerMind.from_dict(d.minds[id])
	candidates.clear()
	for c in d.get("candidates", []):
		candidates.append(c)
	_cand_counter = int(d.get("cand_counter", 0))
	_emp_counter = int(d.get("emp_counter", 2))
	contributions.restore(d.get("contributions", {}))
	# Phase 16: saved merit/progression restore exactly; a save without them
	# starts every employee at level 1 with no merit (older work had no
	# reliable per-actor attribution, so none is assigned retroactively).
	merit.restore(d.get("merit", {}))
	progression.restore(d.get("progression", {}))
	talk.restore(d.get("talk", {}))
	stats = (d.get("stats", {}) as Dictionary).duplicate(true)
	enabled = true
	var saved: Dictionary = d.get("workers", {})
	for e in payroll.employees:
		var eid := str(e.id)
		if not str(e.status) in [Payroll.ACTIVE, "departing"]:
			continue
		if not minds.has(eid):
			minds[eid] = WorkerMind.with_traits(e.get("traits", []))
		progression.ensure_profile(eid, e.get("traits", []))
		var s: Dictionary = saved.get(eid, {})
		var at := World.camp_origin()
		if s.has("pos"):
			at = Vector3(s.pos[0], s.pos[1], s.pos[2])
		if not at.is_finite() or not nav.walkable(at):
			var spawns := get_tree().get_nodes_in_group("worker_spawn")
			at = (spawns[0] as Node3D).global_position if not spawns.is_empty() else World.camp_origin()
		var w := _spawn(e, at)
		w.rotation.y = float(s.get("yaw", 0.0))
		match str(s.get("activity", "idle")):
			"sleep":
				var b := bed_node(int(e.get("bed", 0)))
				if b:
					w.lie_down(b)
			"depart_wait", "aboard":
				w.activity = "depart_wait"
	var sk: Dictionary = d.get("skiff", {})
	skiff_state = "away" if str(sk.get("state", "away")) != "docked" else "away"
	refresh_candidates()
	roster_changed.emit()


# ------------------------------------------------- Phase 16 merit / time

func _on_advanced(eid: String, what: String, _level: int) -> void:
	_fx.erase(eid)          # no stale cached multipliers after a level-up
	var w: Worker = workers.get(eid)
	if w and what == "career":
		progression.add_context("colleague_progress", eid, "career level %d" % _level, knowers_near(w))


func _actor_of(holder: Node) -> String:
	if holder == null:
		return ""
	if holder == Game.player:
		return MeritLedger.BOSS
	if holder is Worker:
		return (holder as Worker).id
	return ""


## Twice a second: every share someone is moving (player's hands, worker
## loads, team carries, the handcart, trucks being driven) reports its
## distance to the receiving cradle; only new closest approaches earn.
func _sample_transport(delta: float) -> void:
	_tr_t -= delta
	if _tr_t > 0.0 or timber == null:
		return
	_tr_t = 0.5
	var dest := CampLayout.world(CampLayout.DELIVERY_RACK_POS)
	if Game.player and not timber.carried.is_empty():
		_tr_hold(timber.carried, Game.player.global_position, {MeritLedger.BOSS: 1.0}, "hand", dest, false)
	for c in timber.loads:
		var sids: Array = timber.loads[c]
		if sids.is_empty():
			continue
		var cs := str(c)
		if cs.begins_with("truck:"):
			var tr: Truck = null
			if Game.vehicles:
				for t in Game.vehicles.trucks.values():
					if (t as Truck).carrier() == cs:
						tr = t
			if tr == null:
				continue
			var drv := str(tr.seats.driver)
			var who := {} if drv == "" else {(MeritLedger.BOSS if drv == "boss" else drv): 1.0}
			_tr_hold(sids, tr.global_position, who, "truck", dest, true)
		elif cs == TimberCart.CARRIER:
			var cart: TimberCart = Game.cart
			if cart == null:
				continue
			var a := _actor_of(cart.pusher)
			_tr_hold(sids, cart.global_position, {} if a == "" else {a: 1.0}, "hand", dest, true)
		elif workers.has(cs):
			var w: Worker = workers[cs]
			var tid := coord.team_of(w)
			var team: Dictionary = coord.teams.get(tid, {})
			if not team.is_empty() and str(team.get("state", "")) == "carry" and workers.has(str(team.follower)):
				_tr_hold(sids, w.global_position, {cs: 0.5, str(team.follower): 0.5}, "team", dest, false)
			else:
				_tr_hold(sids, w.global_position, {cs: 1.0}, "hand", dest, false)


func _tr_hold(sids: Array, at: Vector3, who: Dictionary, mode: String, dest: Vector3, vehicle: bool) -> void:
	var d := Vector2(at.x - dest.x, at.z - dest.z).length()
	for sid in sids:
		var sg := timber.segment(str(sid))
		if sg.is_empty():
			continue
		var mte := int(sg.mte)
		if vehicle and float(merit.committed.get("trl:" + str(sid), 0.0)) < 1.0:
			var loader := merit.last_mover(str(sid))
			if loader == "":
				loader = who.keys()[0] if not who.is_empty() else ""
			merit.on_loaded(str(sid), mte, loader)
		if who.is_empty():
			continue          # parked truck / unattended cart: no one moving it
		merit.sample_transport(str(sid), mte, d, who, mode)


func _merit_on_accepted(r: Dictionary) -> void:
	var src := str(r.get("source", ""))
	var sid := str(r.get("sid", ""))
	if sid == "" or src == "fixture":
		return
	var actor := ""
	var mode := "hand"
	if src.begins_with("rack:") or src.begins_with("deck:"):
		actor = src.split(":")[1]
		if actor == "player":
			actor = MeritLedger.BOSS
		if str((merit.transport.get(sid, {}) as Dictionary).get("mode", "")) == "team":
			mode = "team"
	elif src == "cart":
		actor = _actor_of(Game.cart.pusher) if Game.cart else ""
		if actor == "":
			actor = merit.last_mover(sid)
	else:
		actor = merit.last_mover(sid)
		mode = "truck"
	merit.on_accepted(sid, int(r.get("mte", 0)), actor, mode)


## Per-worker time ledger with real causes (work hours only).
func _tick_time_ledger(delta: float) -> void:
	if campaign == null or not campaign.active or campaign.clock.phase() == WorkdayClock.Phase.NIGHT:
		return
	if Game.hunt and Game.hunt.hunt_active():
		return
	for id in workers:
		var w: Worker = workers[id]
		if str(w.emp.get("status", "")) != Payroll.ACTIVE:
			continue
		var cat := time_category(w)
		if cat != "":
			progression.add_time(w.id, cat, delta)


func time_category(w: Worker) -> String:
	if routine and (w.activity == "break_sit" or (w.activity == "move" and w._after_move == "break_sit")):
		return "break"
	if w.talking_until > now():
		return "waiting"
	match w.activity:
		"fell", "buck", "stump":
			return "useful"
		"retreat_wait", "pick", "deliver", "deliver_deck", "yard_take", "yard_drop", "load_truck":
			return "travel"
		"team_follow":
			return "useful" if w.is_carrying() or not coord.team_of(w).is_empty() and str((coord.teams.get(coord.team_of(w), {}) as Dictionary).get("state", "")) == "carry" else "waiting"
		"move":
			if w._after_move in ["home_arrived", "depart_wait"]:
				return "dusk"
			return "useful" if w.is_carrying() else "travel"
		"follow", "aboard", "seated", "board", "depart_wait":
			return "waiting"
		"sleep", "sit":
			return "dusk"
		"hidden", "hide_enter", "dead", "departed":
			return ""
		"idle":
			return str(w.idle_reason) if w.idle_reason != "" else "no_task"
	return "travel"


## Why a worker found nothing to do (management/logistics, not misconduct).
func idle_cause(w: Worker) -> String:
	if w.mind.refuses_risk():
		return "fear"
	if Game.yard and Game.yard.cradle_free() == 0 and Game.yard.deck_free_estimate() < 10:
		return "yard_full"
	if not axe_ok(w) and not _trunks(work_focus(w), w).is_empty():
		return "missing_tool"
	for i in range(stuck_log.size() - 1, maxi(stuck_log.size() - 8, 0) - 1, -1):
		var sl: Dictionary = stuck_log[i]
		if str(sl.get("worker", "")) == w.id and int(sl.get("day", -1)) == campaign.clock.day and campaign.clock.t - float(sl.get("t", -999.0)) < 30.0:
			return "blocked"
	return "no_task"


## Phase 17 context: a long day of waiting on logistics (not their fault)
## is remembered by that worker, once per day.
func _note_waiting_frustration() -> void:
	var d := campaign.clock.day
	for e in payroll.employees:
		var eid := str(e.id)
		var t := progression.day_time(eid, d)
		var stuck := float(t.get("yard_full", 0.0)) + float(t.get("blocked", 0.0)) + float(t.get("waiting", 0.0))
		if stuck > 90.0:
			progression.add_context("frustrated_waiting", eid, "%d s waiting on the yard/routes/others" % int(stuck), [eid])


## Colleagues within earshot notice someone's progress (only them).
func knowers_near(w: Worker, r := 25.0) -> Array:
	var out := [w.id]
	for o in workers.values():
		if o != w and (o as Worker).global_position.distance_to(w.global_position) < r:
			out.append((o as Worker).id)
	return out


const SKILL_EFFECT := {
	"cutting": "work per hit / saw cut +%d%%",
	"handling": "lifting & loading %d%% quicker",
	"driving": "corners %d%% smoother (same top speed)",
	"teamwork": "two-person lifts %d%% quicker to start",
}


func skill_effect_text(eid: String, sk: String) -> String:
	var l := progression.skill(eid, sk)
	var pct := 0.0
	match sk:
		"cutting":
			pct = (progression.cut_factor(eid) - 1.0) * 100.0
		"handling":
			pct = (1.0 - progression.handling_time(eid)) * 100.0
		"driving":
			pct = (progression.drive_factor(eid) - 1.0) * 100.0
		"teamwork":
			pct = (1.0 - progression.team_wait(eid)) * 100.0
	var nxt := CrewProgression.skill_threshold(l + 1) if l < CrewProgression.SKILL_MAX else -1
	return "%s %d%s%s" % [sk.capitalize(), l, (": " + (SKILL_EFFECT[sk] % int(round(pct)))) if l > 0 else "", ("  (next at %d)" % nxt) if nxt > 0 else "  (max)"]


## One employee's review for day `d`: a read-only summary (opening it never
## awards, pays or resets anything).
func review(eid: String, d: int) -> Dictionary:
	var e := emp(eid)
	var prof: Dictionary = progression.profiles.get(eid, {})
	var tm := progression.day_time(eid, d)
	var total := 0.0
	for k in tm:
		total += float(tm[k])
	var parts := []
	for k in CrewProgression.CATEGORIES:
		if float(tm.get(k, 0.0)) > 0.0:
			parts.append([k, float(tm[k])])
	parts.sort_custom(func(a, b) -> bool: return float(a[1]) > float(b[1]))
	var split := PackedStringArray()
	for pr in parts.slice(0, 4):
		split.append("%s %d%%" % [CrewProgression.CATEGORY_WORDS[pr[0]], int(round(100.0 * float(pr[1]) / maxf(total, 1.0)))])
	var worst := ""
	var worst_s := 0.0
	for k in ["yard_full", "missing_tool", "blocked", "no_task", "fear", "waiting"]:
		if float(tm.get(k, 0.0)) > worst_s:
			worst_s = float(tm.get(k, 0.0))
			worst = k
	var tip := ""
	if worst != "" and worst_s > maxf(60.0, total * 0.12):
		tip = {"yard_full": "Waited for room in the yard: move logs to the decks or the fire pile, or set someone to Yard.",
			"missing_tool": "Had no usable axe for the work nearby: issue one at the tool rack or the Gear app.",
			"blocked": "Got stuck on a route: try 'Work near me' somewhere easier to reach.",
			"no_task": "Ran out of nearby work they could do: point them somewhere with 'Work near me'.",
			"fear": "Refused risky work after something they experienced: reassurance helps only with real reasons.",
			"waiting": "Spent a while waiting on others (team lifts, truck seats, talking)."}[worst]
	var md := merit.today(eid, d)
	var mt := 0.0
	for k in md:
		mt += float(md[k])
	var nx := progression.next_career(eid)
	var jb: Dictionary = progression.jobs.get(eid, {})
	return {
		"eid": eid, "name": str(e.get("name", eid)), "level": int(nx.level), "merit": merit.total(eid), "next": int(nx.next),
		"merit_today": mt, "merit_by_stage": md, "time_split": ", ".join(split), "tip": tip,
		"ethic": CrewProgression.ethic_word(float(prof.get("ethic", 0.7))), "reliability": CrewProgression.reliability_word(float(prof.get("reliability", 0.7))), "prefers": str(prof.get("prefers", "")),
		"skills": PackedStringArray(MeritLedger.SKILLS.map(func(sk: String) -> String: return skill_effect_text(eid, sk))),
		"jobs": "%d started, %d finished" % [int(jb.get("started", 0)), int(jb.get("finished", 0))],
		"owed": payroll.owed_for(eid),
	}
