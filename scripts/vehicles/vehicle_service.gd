class_name VehicleService
extends Node
## Logging pickups (Phase 5): purchase and unlock, stable identities, bays,
## the driving introduction, entering/exiting, cargo through the shared
## timber ledger (carrier "truck:<id>", accepted only at the drop-off bay),
## recovery, worker truck teams, and save/restore.
##
## Team cycle (worker driver + up to two loaders): gather -> board ->
## drive out -> park -> disembark -> process/load real timber -> board ->
## drive back -> unload at the drop-off (paid per accepted log, once) ->
## park in a bay -> repeat while the day allows. Every step is physical; a
## missing person, blocked road, full bed or the dusk margin is reported as
## the reason the team is waiting or returning.

signal changed()
signal notice(text: String, seconds: float)

const MAX_TRUCKS := 2
const TUTORIAL := ["enter", "drive", "reverse", "load", "deliver", "park"]
const TUTORIAL_TEXT := {"enter": "Get in at the driver's door (E)", "drive": "Drive: W/S, steer A/D", "reverse": "Stop, then hold S to reverse", "load": "Carry logs to the tailgate and load them (E)", "deliver": "Back up to the delivery bay by the rack and unload (E at the tailgate)", "park": "Park in a bay, stop and get out (E)"}

var crew: CrewService
var campaign: CampaignService
var timber: TimberService
var nav: DriveNav
var trucks := {}               # id -> Truck
var purchases: Array[Dictionary] = []
var tutorial_done := {}        # step -> true
var tutorial_complete := false
var teams := {}                # truck id -> team dict
var dropoff_claim := ""        # truck id currently unloading
var built := false
var _counter := 0
var dev_unlock := false        # development fixture only (never saved)
var _pending: Array[Callable] = []


func when_ready(f: Callable) -> void:
	if built:
		f.call()
	else:
		_pending.append(f)


func setup(c: CampaignService, cs: CrewService) -> void:
	campaign = c
	crew = cs
	timber = Game.timber
	timber.carried_changed.connect(_refresh_all_cargo)


func build_world() -> void:
	nav = DriveNav.new()
	nav.build(crew.nav)
	built = true
	for f in _pending:
		f.call()
	_pending.clear()
	World.tree_removed.connect(func(tid: int) -> void:
		var i: int = Game.vegetation.tree_index_by_id.get(tid, tid)
		nav.refresh_around(Vector2(World.trees.x[i], World.trees.z[i]), 6.0))
	var prev: Callable = timber.body_settled_hook
	timber.body_settled_hook = func(b: TimberBody, d: int) -> void:
		if prev.is_valid():
			prev.call(b, d)
		var pts := []
		for s in b.axis_samples(4):
			pts.append(s[0])
		nav.mark_log(pts, d)


# ----------------------------------------------------------------- unlock

func delivered_tree_eq() -> float:
	return int(timber.totals().accepted_mte) / 1000.0 if timber else 0.0


func unlock_state() -> Dictionary:
	var need: float = campaign.config.truck_unlock_tree_equivalents
	var have := delivered_tree_eq()
	return {"unlocked": have >= need or dev_unlock, "have": have, "need": need, "owned": trucks.size(), "price": campaign.config.truck_price_cents}


func can_buy() -> Dictionary:
	var u := unlock_state()
	if campaign.contract.is_closed():
		return {"ok": false, "reason": "The company's service has ended."}
	if trucks.size() >= MAX_TRUCKS:
		return {"ok": false, "reason": "You already own two pickups (the maximum)."}
	if not bool(u.unlocked):
		return {"ok": false, "reason": "Unlocks after %.0f delivered tree-equivalents (%.2f so far)." % [u.need, u.have]}
	if free_bay() < 0:
		return {"ok": false, "reason": "Both parking bays are blocked. Clear a bay and the truck is delivered there."}
	if not campaign.wallet.can_afford(int(u.price)):
		return {"ok": false, "reason": "You need $%s." % Money.format_cents(int(u.price))}
	return {"ok": true}


## One purchase = one charge = one stable truck identity in a bay.
func buy() -> Dictionary:
	var ok := can_buy()
	if not bool(ok.ok):
		return ok
	var tx := campaign.wallet.spend(int(campaign.config.truck_price_cents), "purchase", "truck", "Bought a logging pickup")
	if tx.is_empty():
		return {"ok": false, "reason": "Payment failed."}
	_counter += 1
	var id := "TRK-%d" % _counter
	while trucks.has(id):
		_counter += 1
		id = "TRK-%d" % _counter
	var bay := free_bay()
	var t := _spawn(id, bay_pose(bay))
	purchases.append({"id": id, "tx": tx.id, "day": campaign.clock.day, "bay": bay})
	notice.emit("Your pickup is parked in bay %d. %s" % [bay + 1, "" if tutorial_complete else "Driving introduction: " + str(TUTORIAL_TEXT[next_tutorial_step()])], 7.0)
	changed.emit()
	return {"ok": true, "id": t.truck_id, "tx": tx.id}


func _spawn(id: String, pose: Transform3D) -> Truck:
	var t := Truck.new()
	add_child(t)
	t.setup(id)
	t.global_transform = pose
	trucks[id] = t
	return t


func bay_pose(i: int) -> Transform3D:
	var b: Dictionary = CampLayout.TRUCK_BAYS[i]
	var p := CampLayout.world(b.center)
	# Bays sit against the north fence: park nose-out into the yard (south).
	return _flat_pose(p, PI)


func _flat_pose(p: Vector3, yaw: float) -> Transform3D:
	var t := Truck.new()
	var pose := Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, Truck.WHEEL_R + 0.02, 0))
	t.free()
	return pose


func free_bay() -> int:
	for i in CampLayout.TRUCK_BAYS.size():
		var p := CampLayout.world(CampLayout.TRUCK_BAYS[i].center)
		var busy := false
		for t in trucks.values():
			if (t as Node3D).global_position.distance_to(p) < 3.5:
				busy = true
		if not busy:
			return i
	return -1


func in_bay(t: Truck) -> bool:
	for b in CampLayout.TRUCK_BAYS:
		if t.global_position.distance_to(CampLayout.world(b.center)) < 3.0:
			return true
	return false


func at_dropoff(t: Truck) -> bool:
	return t.tailgate_point().distance_to(CampLayout.world(CampLayout.TRUCK_DROPOFF)) < 7.0 or t.tailgate_point().distance_to(CampLayout.world(CampLayout.DELIVERY_RACK_POS)) < 6.0


# -------------------------------------------------------------- tutorial

func next_tutorial_step() -> String:
	for s in TUTORIAL:
		if not tutorial_done.has(s):
			return s
	return ""


func tutorial_mark(step: String) -> void:
	if tutorial_complete or tutorial_done.has(step):
		return
	if next_tutorial_step() != step:
		return
	tutorial_done[step] = true
	var nxt := next_tutorial_step()
	if nxt == "":
		tutorial_complete = true
		notice.emit("Driving introduction complete.", 4.0)
	else:
		notice.emit("Truck: %s" % TUTORIAL_TEXT[nxt], 6.0)


# ------------------------------------------------------- player hotspots

func hotspot_text(t: Truck, kind: String) -> String:
	var p := Game.player as Player
	if p == null or p.vehicle != null:
		return ""
	match kind:
		"DriverDoor":
			if t.seats.driver == "":
				return "Drive the pickup (%s)" % t.truck_id
			return "Ride as passenger" if t.free_seat() != "" else "The cab is full"
		"PassengerDoor":
			return "Ride as passenger" if t.free_seat() != "" else "The cab is full"
		"Tailgate":
			var held := timber.carried.size()
			if held > 0:
				return "Load %d log%s into the bed (%.2f / 3.00 tree-eq)" % [held, "" if held == 1 else "s", t.cargo_mte() / 1000.0]
			if t.cargo_mte() > 0:
				if at_dropoff(t):
					return "Unload at the delivery bay (%.2f tree-eq, paid per log)" % [t.cargo_mte() / 1000.0]
				return "Unload here, on the ground (%.2f tree-eq, not paid)" % [t.cargo_mte() / 1000.0]
			return "Cargo bed: empty (holds 3 tree-equivalents)"
	return ""


func hotspot_use(t: Truck, kind: String, by: Node) -> void:
	var p := by as Player
	if p == null:
		return
	match kind:
		"DriverDoor":
			if t.seats.driver == "":
				enter(p, t, "driver")
			elif t.free_seat() != "":
				enter(p, t, t.free_seat())
		"PassengerDoor":
			var s := t.free_seat()
			if s != "" and s != "driver":
				enter(p, t, s)
			elif s == "driver":
				enter(p, t, "driver")
		"Tailgate":
			if not timber.carried.is_empty():
				var n := load_from("player", t)
				p.show_message("Loaded %d log%s. Bed: %.2f / 3.00 tree-eq." % [n, "" if n == 1 else "s", t.cargo_mte() / 1000.0] if n > 0 else "No room for that load in the bed.")
				if n > 0:
					tutorial_mark("load")
			elif t.cargo_mte() > 0:
				if at_dropoff(t):
					var rs := unload_accept(t, "truck:" + t.truck_id)
					p.show_message("Unloaded %d logs at the delivery bay." % rs.size())
					tutorial_mark("deliver")
				else:
					var n := unload_ground(t)
					p.show_message("Unloaded %d logs onto the ground (unpaid until delivered)." % n)


func enter(p: Player, t: Truck, seat: String) -> void:
	if t.seats[seat] != "":
		return
	t.seats[seat] = "boss"
	p.enter_vehicle(t, seat)
	if seat == "driver":
		t.take_control("player")
		tutorial_mark("enter")
	changed.emit()


## Exit through a door with a valid, clear, dry spot; otherwise refuse with
## a reason (never into a wall, water, or a moving wheel).
func try_exit(p: Player) -> String:
	var t := p.vehicle as Truck
	if t == null:
		return ""
	if absf(t.speed()) > 1.0:
		return "Stop the truck first."
	var seat := t.seat_of("boss")
	var sides := [-1.0, 1.0] if seat == "driver" else [1.0, -1.0]
	for side in sides:
		var spot := t.door_point(side)
		if Game.water and Game.water.depth_at(spot.x, spot.z) > 0.4:
			continue
		if not _clear(spot, p):
			continue
		t.seats[seat] = ""
		if seat == "driver":
			if t.mode == "player":
				t.release_control()
			if in_bay(t):
				tutorial_mark("park")
		p.exit_vehicle(spot)
		_passengers_follow_boss_exit(t)
		changed.emit()
		return ""
	return "No clear spot to step out here."


func _clear(spot: Vector3, p: Player) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	q.shape = cap
	q.transform = Transform3D(Basis(), spot + Vector3(0, 0.95, 0))
	q.collision_mask = 1
	q.exclude = [p.get_rid()]
	for h in p.get_world_3d().direct_space_state.intersect_shape(q, 4):
		if not (h.collider is TimberBody):
			return false
	return true


# ------------------------------------------------------------------ cargo

## Moves every piece a carrier holds into the truck while room remains.
## Atomic per piece through the ledger (one owner, no duplicates).
func load_from(carrier: String, t: Truck) -> int:
	var n := 0
	for sid in timber.load_of(carrier).duplicate():
		if timber.transfer(carrier, t.carrier(), sid, Truck.CAPACITY_MTE):
			n += 1
	if n > 0:
		t.refresh_cargo_visual()
	return n


func unload_accept(t: Truck, source: String) -> Array:
	var rs := timber.accept(timber.load_of(t.carrier()).duplicate(), source)
	t.refresh_cargo_visual()
	return rs


func unload_ground(t: Truck) -> int:
	var n := 0
	var base := t.tailgate_point()
	for sid in timber.load_of(t.carrier()).duplicate():
		var p := base + t.global_basis.z * (0.4 * n)
		var spot := TimberRecovery.find_ground(Vector2(p.x, p.z), 2.0, 0.3, t.get_world_3d(), t.get_rid())
		if spot == Vector3.INF:
			continue
		timber.put_down_for(t.carrier(), sid, spot + Vector3(0, 0.4, 0), t.global_basis.x, true)
		n += 1
	t.refresh_cargo_visual()
	return n


func _refresh_all_cargo() -> void:
	for t in trucks.values():
		(t as Truck).refresh_cargo_visual()


## Recovery for a stuck/flipped truck near its position (never "home").
func recover(t: Truck) -> String:
	if campaign.get("hunt_active") == true:
		return "Recovery is not available during a pursuit."
	return "Truck recovered to the nearest drivable ground." if t.recover(nav) else "No drivable ground nearby."


# ---------------------------------------------------------- worker teams

## Assigns a team: driver + up to two loaders, working near `area`.
func dispatch(truck_id: String, driver_id: String, loader_ids: Array, area: Vector3) -> Dictionary:
	var t: Truck = trucks.get(truck_id)
	if t == null:
		return {"ok": false, "reason": "No such truck."}
	if t.seat_of("boss") != "":
		return {"ok": false, "reason": "Get out of the truck first."}
	var r := nav.route(t.global_position, area)
	if r.is_empty():
		return {"ok": false, "reason": "No vehicle access to that area (trees or water in the way)."}
	var members: Array = [driver_id]
	for l in loader_ids.slice(0, 2):
		if l != driver_id:
			members.append(l)
	for m in members:
		var e := crew.emp(m)
		if e.is_empty() or str(e.status) != Payroll.ACTIVE:
			return {"ok": false, "reason": "%s can't join right now." % e.get("name", m)}
		e["team"] = truck_id
	teams[truck_id] = {"truck": truck_id, "driver": driver_id, "members": members, "area": [area.x, area.y, area.z], "state": "gather", "reason": "gathering the crew", "t": 0.0, "cycles": 0}
	notice.emit("%s team dispatched: %s" % [truck_id, ", ".join(PackedStringArray(members.map(func(m: String) -> String: return str(crew.emp(m).get("name", m)))))], 5.0)
	changed.emit()
	return {"ok": true}


func disband(truck_id: String, why := "") -> void:
	var tm: Dictionary = teams.get(truck_id, {})
	if tm.is_empty():
		return
	var t: Truck = trucks.get(truck_id)
	for m in tm.members:
		var e := crew.emp(m)
		if not e.is_empty():
			e.erase("team")
		var w: Worker = crew.workers.get(m)
		if w and w.seated and t:
			disembark(w, t)
	if t and t.mode == "auto":
		t.release_control()
		if t.seats.driver != "" and t.seats.driver != "boss":
			t.seats.driver = ""
	teams.erase(truck_id)
	if why != "":
		notice.emit("%s team stood down: %s" % [truck_id, why], 5.0)
	changed.emit()


func team_of(w: Worker) -> Dictionary:
	var tid := str(w.emp.get("team", ""))
	return teams.get(tid, {})


## Called by CrewService.decide: the team controls its members' moves
## during gathering/boarding. Returns true if it handled the worker.
func team_decide(w: Worker) -> bool:
	var tm := team_of(w)
	if tm.is_empty():
		return false
	var t: Truck = trucks.get(str(tm.truck))
	if t == null:
		return false
	match str(tm.state):
		"gather", "gather_back":
			if w.seated:
				w.activity = "seated"
				return true
			var side := -1.0 if str(tm.driver) == w.id else 1.0
			var door := t.door_point(side)
			if w.global_position.distance_to(door) < 1.2:
				board(w, t, "driver" if str(tm.driver) == w.id else t.free_seat())
			elif w.is_carrying() and str(tm.state) == "gather_back" and t.room_mte() > 0:
				w.go_to(t.tailgate_point(), "load_truck", "the truck")
			else:
				w.go_to(door, "idle", "the truck")
			return true
		"work":
			return false      # ordinary jobs, hauling to the truck
		_:
			if w.seated:
				w.activity = "seated"
			return true


func board(w: Worker, t: Truck, seat: String) -> void:
	if seat == "" or t.seats[seat] != "":
		return
	t.seats[seat] = w.id
	w.board_seat(t.seat_marker(seat))


func disembark(w: Worker, t: Truck) -> void:
	var seat := t.seat_of(w.id)
	if seat == "":
		return
	t.seats[seat] = ""
	var side := -1.0 if seat == "driver" else 1.0
	var spot := t.door_point(side)
	if not crew.nav.walkable(spot, true):
		spot = t.door_point(-side)
	w.leave_seat(spot)


## Where a team member delivers carried logs: their parked team truck if it
## is near and has room, else null (the rack).
func haul_target(w: Worker) -> Truck:
	var tid := str(w.emp.get("team", w.emp.get("haul_truck", "")))
	var t: Truck = trucks.get(tid)
	if t and t.mode == "parked" and t.room_mte() > 120 and t.global_position.distance_to(w.global_position) < 140.0:
		return t
	return null


func _passengers_follow_boss_exit(t: Truck) -> void:
	# Workers riding with the boss get out and work around the truck,
	# carrying to it while it has room.
	for s in Truck.SEATS:
		var o: String = t.seats[s]
		if o == "" or o == "boss":
			continue
		var w: Worker = crew.workers.get(o)
		if w and team_of(w).is_empty():
			disembark(w, t)
			var p := t.global_position
			w.emp["focus"] = [p.x, p.y, p.z]
			w.emp["job"] = "automatic"
			w.emp["haul_truck"] = t.truck_id


## Workers told to ride with the boss board the boss's truck.
func ride_target() -> Truck:
	var p := Game.player as Player
	if p and p.vehicle is Truck:
		return p.vehicle
	var best: Truck = null
	var bd := 60.0
	for t in trucks.values():
		var d := (t as Node3D).global_position.distance_to(Game.player.global_position) if Game.player else INF
		if d < bd and teams.get((t as Truck).truck_id, {}).is_empty():
			bd = d
			best = t
	return best


func _physics_process(delta: float) -> void:
	if get_tree().paused or not built:
		return
	for id in teams.keys():
		_step_team(teams[id], delta)
	_check_passenger_dusk()


func _step_team(tm: Dictionary, delta: float) -> void:
	var t: Truck = trucks.get(str(tm.truck))
	if t == null:
		teams.erase(tm.truck)
		return
	tm.t = float(tm.t) + delta
	var members: Array = tm.members.filter(func(m: String) -> bool: return crew.workers.has(m) and str(crew.emp(m).get("status", "")) == Payroll.ACTIVE)
	if members.is_empty() or not str(tm.driver) in members:
		disband(str(tm.truck), "the driver is no longer available")
		return
	var area := Vector3(tm.area[0], tm.area[1], tm.area[2])
	var back_secs := DriveNav.length(nav.route(t.global_position, CampLayout.world(CampLayout.TRUCK_DROPOFF))) / 5.5 + 90.0
	var time_short := crew.real_time_left() < back_secs + 60.0 or campaign.clock.phase() == WorkdayClock.Phase.NIGHT
	match str(tm.state):
		"gather":
			if time_short:
				tm.reason = "too late to go out today"
				_all_home(tm)
				tm.state = "home"
				return
			var aboard := members.filter(func(m: String) -> bool: return t.seat_of(m) != "")
			tm.reason = "waiting for %d to board" % (members.size() - aboard.size()) if aboard.size() < members.size() else "leaving"
			if aboard.size() == members.size() or (float(tm.t) > 90.0 and t.seat_of(str(tm.driver)) != ""):
				var r := nav.route(t.global_position, area)
				if r.is_empty():
					tm.reason = "no vehicle access to the work area"
					return
				t.take_control("auto")
				t.set_route(r)
				tm.state = "drive_out"
				tm.t = 0.0
		"drive_out":
			tm.reason = t.status_reason if t.status_reason != "" else "driving out"
			if t.blocked_for > 25.0:
				t.set_route(nav.route(t.global_position, area))
			if time_short:
				_head_back(tm, t)
			elif t.arrived():
				t.release_control()
				for m in members:
					var w: Worker = crew.workers[m]
					disembark(w, t)
					w.emp["focus"] = [t.global_position.x, t.global_position.y, t.global_position.z]
					w.abandon("team at work")
				tm.state = "work"
				tm.t = 0.0
		"work":
			tm.reason = "working (%.2f / 3.00 tree-eq loaded)" % (t.cargo_mte() / 1000.0)
			var full := t.room_mte() < 150
			if full or time_short:
				tm.reason = "bed full - heading back" if full else "heading back before dark"
				tm.state = "gather_back"
				tm.t = 0.0
				for m in members:
					(crew.workers[m] as Worker).abandon("back to the truck")
				_board_now_warning(t)
		"gather_back":
			var aboard2 := members.filter(func(m: String) -> bool: return t.seat_of(m) != "")
			tm.reason = "boarding (%d / %d)" % [aboard2.size(), members.size()]
			if aboard2.size() == members.size() or (float(tm.t) > 75.0 and t.seat_of(str(tm.driver)) != ""):
				_head_back(tm, t)
		"drive_back":
			tm.reason = t.status_reason if t.status_reason != "" else "driving back to camp"
			if t.blocked_for > 25.0:
				t.set_route(nav.route(t.global_position, CampLayout.world(CampLayout.TRUCK_DROPOFF)))
			if t.arrived():
				if dropoff_claim != "" and dropoff_claim != t.truck_id:
					tm.reason = "drop-off occupied"
					return
				dropoff_claim = t.truck_id
				var rs := unload_accept(t, "truck:" + t.truck_id)
				dropoff_claim = ""
				tm.cycles = int(tm.cycles) + 1
				tm.reason = "unloaded %d logs" % rs.size()
				var bay := _bay_for(t)
				t.take_control("auto")
				t.set_route(nav.route(t.global_position, bay_pose(bay).origin))
				tm.state = "park"
		"park":
			if t.arrived() or t.blocked_for > 20.0:
				t.release_control()
				for m in members:
					disembark(crew.workers[m], t)
				if not time_short and crew.real_time_left() > 300.0:
					tm.state = "gather"
					tm.t = 0.0
				else:
					tm.state = "home"
					_all_home(tm)
		"home":
			tm.reason = "done for the day"
			if campaign.clock.phase() == WorkdayClock.Phase.DAYLIGHT and campaign.clock.t < 60.0:
				tm.state = "gather"
				tm.t = 0.0


func _head_back(tm: Dictionary, t: Truck) -> void:
	var r := nav.route(t.global_position, CampLayout.world(CampLayout.TRUCK_DROPOFF))
	t.take_control("auto")
	t.set_route(r)
	tm.state = "drive_back"
	tm.t = 0.0


func _bay_for(t: Truck) -> int:
	for i in CampLayout.TRUCK_BAYS.size():
		var p := CampLayout.world(CampLayout.TRUCK_BAYS[i].center)
		var busy := false
		for o in trucks.values():
			if o != t and (o as Node3D).global_position.distance_to(p) < 3.5:
				busy = true
		if not busy:
			return i
	return 0


func _all_home(tm: Dictionary) -> void:
	var t: Truck = trucks.get(str(tm.truck))
	for m in tm.members:
		var w: Worker = crew.workers.get(m)
		if w and t:
			disembark(w, t)
		if w:
			w.abandon("home")


func _board_now_warning(t: Truck) -> void:
	var p := Game.player as Player
	if p and p.vehicle == null and p.global_position.distance_to(t.global_position) < 40.0 and t.free_seat() != "":
		notice.emit("Driver: \"We're heading back now - get in if you're coming.\"", 6.0)


## Passengers in a boss-driven truck speak up at dusk; at a stop with the
## boss outside they get out and walk home if they can.
var _dusk_said := {}
func _check_passenger_dusk() -> void:
	var p := Game.player as Player
	for t in trucks.values():
		var tr := t as Truck
		if not teams.get(tr.truck_id, {}).is_empty():
			continue
		for s in ["middle", "right"]:
			var o: String = tr.seats[s]
			if o == "" or o == "boss":
				continue
			var w: Worker = crew.workers.get(o)
			if w == null:
				continue
			var left := crew.real_time_left()
			var need := tr.global_position.distance_to(CampLayout.world(CampLayout.TRUCK_DROPOFF)) / 5.0 + w.mind.return_margin()
			if left < need + 60.0 and not _dusk_said.has(o + str(campaign.clock.day)):
				_dusk_said[o + str(campaign.clock.day)] = true
				w.say("dusk_reminder", true)
			if left < need and absf(tr.speed()) < 0.5 and (p == null or p.vehicle != tr):
				disembark(w, tr)
				w.emp["job"] = "automatic"
				w.abandon("walking home")


# ------------------------------------------------------------- save/load

func capture() -> Dictionary:
	var ts := []
	for id in trucks:
		ts.append((trucks[id] as Truck).capture())
	var tms := {}
	for id in teams:
		var tm: Dictionary = teams[id].duplicate(true)
		tms[id] = tm
	return {"trucks": ts, "purchases": purchases.duplicate(true), "tutorial_done": tutorial_done.keys(), "tutorial_complete": tutorial_complete, "counter": _counter, "teams": tms}


## Restores trucks parked where they were (stationary, never mid-motion),
## with nobody seated; teams resume from "gather". Cargo is in the ledger.
func restore(d: Dictionary) -> void:
	for t in trucks.values():
		(t as Node).queue_free()
	trucks.clear()
	teams.clear()
	purchases.clear()
	for pch in d.get("purchases", []):
		purchases.append(pch)
	tutorial_done.clear()
	for s in d.get("tutorial_done", []):
		tutorial_done[str(s)] = true
	tutorial_complete = bool(d.get("tutorial_complete", false))
	_counter = int(d.get("counter", 0))
	for td in d.get("trucks", []):
		var pose := TreeService.array_to_xf(td.get("pose", []))
		var t := _spawn(str(td.id), pose)
		if not nav.drivable(pose.origin) and not crew.nav.in_camp(pose.origin):
			t.recover(nav)
		t.headlights = bool(td.get("headlights", false))
		t.odometer = float(td.get("odometer", 0.0))
		t.refresh_cargo_visual()
	for id in d.get("teams", {}):
		var tm: Dictionary = d.teams[id]
		if trucks.has(id):
			tm.state = "gather"
			tm.t = 0.0
			teams[id] = tm
	changed.emit()
