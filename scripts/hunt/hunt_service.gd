class_name HuntService
extends Node
## Phase 6 failure mode. Owns the campaign states after an unmet day-30
## deadline: ABANDONMENT_TRANSITION -> HUNT_ACTIVE (continuous days 31-35)
## -> RESCUE_AVAILABLE (dawn of day 36) -> ESCAPED / PLAYER_DEAD / STRANDED.
## A fulfilled contract never reaches this code: the Foreman cannot appear
## in a successful campaign, whatever is still burning in the pit.
##
## Hunt clock: 900 s daylight + 300 s dusk + a tunable 300 s survival night
## per day (25 minutes, ~125 minutes for five days), continuous, no sleep,
## pause stops it. Rescue only after five complete persisted cycles.
## Shelters conceal/delay but no longer grant immunity from the physical
## Foreman - the transition card says so before it can kill anyone.

signal mode_changed(mode: String)

const DAYLIGHT := 900.0
const DUSK := 300.0
const NIGHT := 300.0
const CYCLE := DAYLIGHT + DUSK + NIGHT
const FIRST_DAY := 31
const LAST_DAY := 35
const BOARDING_WINDOW := 480.0

var mode := "none"           # none / transition / hunt / rescue / escaped / dead / stranded
var hunt_day := 30
var t := DAYLIGHT + DUSK     # starts in day 30's night
var player_dead := false
var dead_workers: Array[String] = []
var escaped: Array[String] = []
var boarded_player := false
var foreman: Foreman
var ship: Node3D
var ship_state := "none"     # none / approaching / docked / departed
var ship_t := 0.0
var hidden := {}             # Node -> HideSpot
var seen_entries := {}       # HideSpot -> hunt clock when an entry was seen
var exposed := {}            # Node -> true (found in a probe)
var hide_noise := {}         # HideSpot -> clock of last noise from it
var truck_use := 0           # times trucks were driven during the hunt
var hunt_preview := false
var spots_built := false
var _rng := RandomNumberGenerator.new()
var _info_shown := false
var pending_restore := false     # a saved hunt is about to be restored


func _ready() -> void:
	_rng.seed = 3535


func hunt_active() -> bool:
	return mode in ["hunt", "rescue"]


func hiding_enabled() -> bool:
	return hunt_active() or hunt_preview


func hunt_clock() -> float:
	return (hunt_day - 30) * CYCLE + t


func phase_name() -> String:
	if t < DAYLIGHT:
		return "day"
	if t < DAYLIGHT + DUSK:
		return "dusk"
	return "night"


func lighting_hour() -> float:
	if t < DAYLIGHT:
		return lerpf(WorkdayClock.HOUR_DAY_START, WorkdayClock.HOUR_DUSK_START, t / DAYLIGHT)
	if t < DAYLIGHT + DUSK:
		return lerpf(WorkdayClock.HOUR_DUSK_START, WorkdayClock.HOUR_NIGHT, (t - DAYLIGHT) / DUSK)
	var u := (t - DAYLIGHT - DUSK) / NIGHT
	return fposmod(lerpf(WorkdayClock.HOUR_NIGHT, 24.0 + WorkdayClock.HOUR_DAY_START, u), 24.0)


# --------------------------------------------------------- transition

## Called once when the deadline commits ABANDONMENT (never on success).
func begin_abandonment() -> void:
	if mode != "none" or pending_restore:
		return
	var c: CampaignService = Game.campaign
	if c and c.contract.state == ContractService.FULFILLED:
		return
	mode = "transition"
	mode_changed.emit(mode)
	build_hide_spots()
	# Freeze company services; whoever is still on the island stays.
	if Game.crew:
		for e in c.payroll.employees if c else []:
			if str(e.status) == "departing":
				e.status = Payroll.ACTIVE
				e.erase("departure_reason")
		for w in Game.crew.workers.values():
			(w as Worker).abandon("abandoned")
	if Game.vehicles:
		for id in Game.vehicles.teams.keys():
			Game.vehicles.disband(id, "the company has left")
	# Beacon acknowledged through the real utility building radio.
	if Game.dock_site:
		Game.dock_site.request_rescue(30)
	# The same dog goes to its dry dock refuge (verified anchor if needed).
	if Game.dog and not Game.dog.enter_refuge():
		var a := get_tree().get_nodes_in_group("dog_refuge")
		if not a.is_empty():
			Game.dog.global_position = (a[0] as Node3D).global_position
			Game.dog.routine = "refuge"
			Game.dog.state = CampDog.State.REFUGE
	hunt_day = 30
	t = DAYLIGHT + DUSK
	_spawn_foreman()
	_show_transition_card()
	mode = "hunt"
	mode_changed.emit(mode)


func _show_transition_card() -> void:
	if _info_shown or Game.end_screen == null:
		return
	_info_shown = true
	Game.end_screen.show_info("The company has left", "Night fell on day 30 with the island not cleared. The last company boat is gone.\n\nThe emergency radio in the utility building answered: a rescue ship will reach the dock at dawn on day 36. Five days.\n\nSomething tall is out there now, and it is not like the others. It is physical, and it can kill.\n- Lamps, closed doors and the camper NO LONGER keep you safe from it. They only hide or slow you.\n- Hide (" + Keys.label("interact") + ") under beds, in closets, behind the utility shelves or under the dock. If it saw you go in, it may look.\n- Break its line of sight and move quietly. It can outrun you for a few seconds, not forever.\n- The five days are continuous: lying in a bed does not skip time. Company hiring and boats are closed.\n- At dawn on day 36 get yourself and your surviving crew to the dock; boarding stays open for %d minutes.\n\nBiscuit is safe at the dock alcove the whole time and boards the ship automatically. Do not go back for the dog.\n\nThe game is paused until you continue." % int(BOARDING_WINDOW / 60.0), "I understand")


func _spawn_foreman() -> void:
	if foreman and is_instance_valid(foreman):
		return
	foreman = Foreman.new()
	foreman.name = "Foreman"
	get_parent().add_child(foreman)
	foreman.killed.connect(func(_w: Node) -> void: pass)
	var p := Game.player as Node3D
	var from := p.global_position if p else World.camp_origin()
	# First reveal: beside a distant survey marker, 110-150 m away, in view.
	var at := Vector3.INF
	for i in 30:
		var look := -p.global_basis.z if p else Vector3.FORWARD
		var c := TerrorPlacement.treeline_point(from, look, 110.0, 150.0, 0.8, _rng)
		if c != Vector3.INF:
			at = c
			break
	if at == Vector3.INF:
		at = roam_points()[0]
	foreman.global_position = at
	if p:
		var d := p.global_position - at
		foreman.rotation.y = atan2(-d.x, -d.z)
	var stake := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 1.3, 0.06)
	stake.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.45, 0.1)
	stake.material_override = m
	get_parent().add_child(stake)
	stake.global_position = at + Vector3(0.9, 0.65, 0.2)
	stake.name = "SurveyMarker"


# --------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if get_tree().paused or not hunt_active():
		return
	t += delta
	if t >= CYCLE:
		t -= CYCLE
		hunt_day += 1
		_on_dawn()
	if Game.environment:
		Game.environment.set_time_of_day(lighting_hour())
	if mode == "rescue":
		_ship_step(delta)
	_worker_awareness(delta)


func _on_dawn() -> void:
	if hunt_day > LAST_DAY:
		_rescue_arrives()
		return
	if Game.player:
		Game.player.show_message("Day %d. %d day%s until the ship." % [hunt_day, 36 - hunt_day, "" if 36 - hunt_day == 1 else "s"])
	if Game.world_root and not player_dead:
		Game.world_root.save_campaign()
		Game.world_root.save_checkpoint("survival")


## Day tendencies (not cutscenes): later days lean toward observed routes,
## the trucks' road and finally the dock.
func day_bias() -> Vector3:
	match hunt_day:
		33:
			if foreman and not foreman.searched.is_empty():
				return foreman.searched[0]
		34:
			if truck_use > 0 and Game.vehicles and not Game.vehicles.trucks.is_empty():
				foreman.mark("F-H32")
				return (Game.vehicles.trucks.values()[0] as Truck).global_position
		35, 36:
			if Game.crew:
				return Game.crew.dock_shore
	return Vector3.INF


func roam_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var o := World.camp_origin()
	var half := CampLayout.FENCE_HALF
	for a in 8:
		var ang := TAU * a / 8.0
		var p := Vector3(o.x + sin(ang) * (half.x + 9.0), 0, o.z + cos(ang) * (half.y + 9.0))
		p.y = World.height_at(p.x, p.z)
		if World.water_depth_at(p.x, p.z) <= 0.0:
			out.append(p)
	for k in [Vector3(-10, 0, -8), Vector3(10, 0, 8), Vector3(0, 0, 0), Vector3(-15, 0, 10)]:
		var q := CampLayout.world(k)
		q.y = World.height_at(q.x, q.z)
		out.append(q)
	if Game.crew and Game.crew.dock_shore != Vector3.ZERO:
		out.append(Game.crew.dock_shore + Vector3(-3, 0, -3))
	if Game.dock_site and Game.dock_site.building:
		out.append(Game.dock_site.building.global_position + Vector3(-4.5, 0, -2.0))
	return out


## Broad sector hypothesis; ~40 % of the time it points the wrong way.
func sector_hint(rng: RandomNumberGenerator) -> Dictionary:
	var o := World.camp_origin()
	var p := Game.player as Node3D
	var right := p.global_position if p else o
	var wrong := rng.randf() < 0.4
	var c := right
	if wrong:
		c = o + (o - right).normalized() * 30.0
	c += Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
	c.y = World.height_at(c.x, c.z)
	return {"pos": c, "wrong": wrong}


# ----------------------------------------------------- noise & hiding

## Human-made noise (doors, engines, voices, hide doors). The Foreman also
## hears SoundEvents directly.
func noise(pos: Vector3, radius: float, kind: String, who: String) -> void:
	if not hunt_active() or foreman == null or who == "foreman":
		return
	foreman.hear(pos, radius, kind)


func build_hide_spots() -> void:
	if spots_built:
		return
	spots_built = true
	for m in WorldGroups.of(self, "hiding_spot"):
		var mk := m as Node3D
		var kind := str(mk.get_meta("hide_kind", "under_bed"))
		match kind:
			"under_bed", "closet", "under_desk", "behind_shelves", "under_dock":
				pass
			"utility_closet_reserved":
				continue
			_:
				continue
		var b := ""
		if mk.name.contains("Camper"):
			b = "camper"
		elif mk.name.begins_with("Utility"):
			b = "utility"
		elif mk.name.begins_with("Dock"):
			b = "dock"
		elif mk.name.contains("Worker"):
			b = "cabin"
		HideSpot.make(mk, kind, b)


func is_hidden(who: Node) -> bool:
	return hidden.has(who)


func is_exposed(who: Node) -> bool:
	return exposed.has(who)


func expose(spot: HideSpot) -> void:
	if spot.occupant:
		exposed[spot.occupant] = true


## Someone enters a hiding place. If the Foreman can see them right now,
## that is evidence about this exact spot.
func on_enter_hide(who: Node3D, spot: HideSpot) -> void:
	spot.occupant = who
	hidden[who] = spot
	exposed.erase(who)
	if foreman and foreman.can_see(who):
		seen_entries[spot] = hunt_clock()
		foreman.hear(spot.global_position, 999.0, "seen_entry", spot)
	if spot.kind == "closet":
		hide_noise[spot] = hunt_clock()
		noise(spot.global_position, 7.0, "closet", "human")


func on_exit_hide(who: Node3D, spot: HideSpot) -> void:
	spot.occupant = null
	hidden.erase(who)
	exposed.erase(who)
	hide_noise[spot] = hunt_clock()
	noise(spot.global_position, 6.0, "hide_exit", "human")


func seen_entry_bonus(spot: HideSpot) -> float:
	if not seen_entries.has(spot):
		return 0.0
	return 0.6 if hunt_clock() - float(seen_entries[spot]) < 240.0 else 0.25


func recent_noise_from(spot: HideSpot) -> bool:
	return hide_noise.has(spot) and hunt_clock() - float(hide_noise[spot]) < 8.0


func player_hidden_near(p: Vector3, r: float) -> bool:
	var pl := Game.player as Node3D
	return pl != null and hidden.has(pl) and (hidden[pl] as HideSpot).global_position.distance_to(p) < r


## Authored entry for buildings the camp grid keeps private (camper,
## utility): door outside -> threshold (fold) -> spot approach.
func route_to_spot(spot: HideSpot, from: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := Game.crew.nav if Game.crew else null
	match spot.building:
		"camper":
			var c := Game.world_root.find_child("Camper", true, false) as Node3D
			if c == null or n == null:
				return out
			var W := CampLayout.CAMPER_SIZE.x * 0.5
			var F := CampLayout.CAMPER_FLOOR
			var foot := c.global_transform * Vector3(W + 1.9, 0, 1.85)
			foot.y = World.height_at(foot.x, foot.z)
			out = n.find_path(from, foot)
			out.append(c.global_transform * Vector3(W + 0.2, F, 1.85))
			out.append(c.global_transform * Vector3(W - 0.6, F, 1.85))
			var ap := spot.approach
			ap.y = c.global_position.y + F
			out.append(ap)
		"utility":
			var b := Game.dock_site.building if Game.dock_site else null
			if b == null or n == null:
				return out
			var door := b.global_transform * Vector3(-DockSite.BW - 1.3, 0, -0.75)
			door.y = World.height_at(door.x, door.z)
			out = n.find_path(from, door)
			out.append(b.global_transform * Vector3(-DockSite.BW + 0.3, 0, -0.75))
			out.append(spot.approach)
	return out


# ------------------------------------------------------ people & kills

func worker_alive(w: Node) -> bool:
	return w != null and is_instance_valid(w) and not dead_workers.has(str(w.get("id")))


func in_vehicle(who: Node) -> bool:
	if who == Game.player:
		return (who as Player).vehicle != null
	return bool(who.get("seated"))


func vehicle_speed(who: Node) -> float:
	if who == Game.player and (who as Player).vehicle is Truck:
		return absf(((who as Player).vehicle as Truck).speed())
	return 0.0


func speaker_gone(name_: String) -> bool:
	if Game.campaign == null:
		return false
	for e in Game.campaign.payroll.employees:
		if str(e.name) == name_:
			return str(e.status) in ["departed", "dead"]
	return false


func on_kill(who: Node) -> void:
	if who == Game.player:
		player_dead = true
		mode = "dead"
		mode_changed.emit(mode)
		if Game.end_screen:
			Game.end_screen.show_player_dead(hunt_day)
		return
	var w := who as Worker
	if w == null:
		return
	var id := w.id
	if dead_workers.has(id):
		return
	dead_workers.append(id)
	w.emp.status = "dead"
	w.emp["death_day"] = hunt_day
	if hidden.has(w):
		(hidden[w] as HideSpot).occupant = null
		hidden.erase(w)
	w.die()
	if Game.player:
		var near := (Game.player as Node3D).global_position.distance_to(w.global_position) < 40.0
		Game.player.show_message("%s is dead." % w.emp.name if near else "A scream from far off, then nothing.")


## Hunt behaviour for workers (replaces normal jobs while hunting): stay in
## the cabin; flee to a free hiding place when they see or hear it; come
## out after it has been quiet; regroup at the dock when the ship comes.
func worker_decide(w: Worker) -> void:
	if not worker_alive(w):
		return
	if mode == "rescue" and ship_state == "docked":
		if not hidden.has(w):
			w.go_to(Game.crew.dock_end, "board", "boarding the rescue ship")
		return
	if hidden.has(w):
		return
	if w.activity == "move":
		return
	var cabin := Game.crew.nav.surface_at(CampLayout.world(CampLayout.CABIN_POS))
	var home := CampLayout.world(CampLayout.CABIN_POS)
	home.y = cabin
	if w.global_position.distance_to(home) > 6.0:
		w.go_to(home, "idle", "staying in the cabin")


var _aware_t := 0.0


func _worker_awareness(delta: float) -> void:
	_aware_t -= delta
	if _aware_t > 0.0 or Game.crew == null or foreman == null:
		return
	_aware_t = 0.5
	for w in Game.crew.workers.values():
		var wk := w as Worker
		if not worker_alive(wk):
			continue
		var d := wk.global_position.distance_to(foreman.global_position)
		var spot: HideSpot = hidden.get(wk)
		if spot:
			# Calm for a while and it is far: come out quietly.
			if d > 45.0 and _rng.randf() < 0.05:
				on_exit_hide(wk, spot)
				wk.leave_hide(spot.exit_point)
			continue
		var sees := d < 26.0 and _clear(wk.global_position + Vector3(0, 1.6, 0), foreman.global_position + Vector3(0, 2.0, 0))
		if sees or d < 9.0:
			if wk.mind:
				wk.mind.perceive({"id": "FOREMAN-%d" % hunt_day, "kind": "foreman", "modality": "sight", "pos": foreman.global_position, "severity": 0.9, "ambiguous": false}, Game.crew.now(), {"confidence": 0.95})
			if d < 30.0:
				wk.say("hunt_warning", true)
				foreman.mark("F-H24")
				noise(wk.global_position, 20.0, "voice", wk.id)
			var free := _nearest_free_spot(wk.global_position)
			if free:
				wk.go_hide(free)
				foreman.mark("F-H23")


func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty()


func _nearest_free_spot(p: Vector3) -> HideSpot:
	var best: HideSpot = null
	var bd := 60.0
	for s in get_tree().get_nodes_in_group("hide_spot"):
		var h := s as HideSpot
		if h.occupant != null or h.building == "camper" or h.get_meta("claimed", "") != "":
			continue
		var d := h.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = h
	return best


# ---------------------------------------------------------- the ship

func _rescue_arrives() -> void:
	mode = "rescue"
	ship_state = "approaching"
	ship_t = 0.0
	hunt_day = 36
	t = 0.0
	mode_changed.emit(mode)
	_build_ship()
	if Game.player:
		Game.player.show_message("A ship's horn from the sea. The rescue ship is coming in to the dock. Get there.")
	if Game.world_root:
		Game.world_root.save_checkpoint("survival")
	if foreman:
		foreman.mark("F-H36")
		foreman.hear(Game.crew.dock_end, 999.0, "ship", null)


func _build_ship() -> void:
	ship = Node3D.new()
	ship.name = "RescueShip"
	get_parent().add_child(ship)
	BuildKit.box(ship, Vector3(7.0, 2.6, 22.0), Vector3(0, 0.6, 0), "white", false, 0.0, "Hull")
	BuildKit.box(ship, Vector3(7.2, 0.5, 22.2), Vector3(0, -0.6, 0), "camper_stripe", false)
	BuildKit.box(ship, Vector3(4.5, 2.6, 6.0), Vector3(0, 3.2, 3.0), "white", false, 0.0, "Bridge")
	BuildKit.box(ship, Vector3(0.4, 3.0, 0.4), Vector3(0, 5.5, 3.0), "steel", false, 0.0, "Mast")
	var light := OmniLight3D.new()
	light.position = Vector3(0, 7.2, 3.0)
	light.omni_range = 30.0
	light.light_energy = 1.6
	ship.add_child(light)
	var gang := Node3D.new()
	gang.name = "Gangway"
	ship.add_child(gang)
	var end := Game.crew.dock_end
	ship.global_position = Vector3(end.x + 6.5, World.sea_level, end.z + 260.0)
	_horn()


func _horn() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = load("res://audio/generated/ship_horn.wav")
	p.bus = "Horror"
	p.unit_size = 60.0
	p.max_distance = 2000.0
	ship.add_child(p)
	p.play()
	SoundEvents.emit(p.stream, ship.global_position, 6.0, "ship", "")


var _gang_spot: Hotspot


func _ship_step(delta: float) -> void:
	ship_t += delta
	var end := Game.crew.dock_end
	match ship_state:
		"approaching":
			var target := Vector3(end.x + 6.0, World.sea_level, end.z + 6.0)
			ship.global_position = ship.global_position.move_toward(target, delta * 4.5)
			if ship.global_position.distance_to(target) < 0.5:
				ship_state = "docked"
				ship_t = 0.0
				_horn()
				_gang_spot = Hotspot.make(Game.crew.get_node("ServiceDock"), "GangwaySpot", Vector3(2.0, 1.6, 2.0), end + Vector3(0, 0.6, 0) - Game.crew.get_node("ServiceDock").global_position, func() -> String: return "Board the rescue ship", func(by: Node) -> void: request_board(by))
				if Game.dog and not Game.dog.boarded_once:
					Game.dog.board_ship()
				for w in Game.crew.workers.values():
					var wk := w as Worker
					if worker_alive(wk) and hidden.has(wk):
						on_exit_hide(wk, hidden[wk])
						wk.leave_hide((hidden.get(wk, null) as HideSpot).exit_point if hidden.has(wk) else wk.global_position)
				if Game.player:
					Game.player.show_message("The ship is at the dock. Boarding closes in %d minutes. Everyone who reaches the gangway gets aboard." % int(BOARDING_WINDOW / 60.0))
		"docked":
			for w in Game.crew.workers.values():
				var wk := w as Worker
				if worker_alive(wk) and not escaped.has(wk.id) and wk.global_position.distance_to(end) < 3.5:
					escaped.append(wk.id)
					wk.visible = false
					wk.emp["escaped"] = true
			if ship_t > BOARDING_WINDOW and not boarded_player:
				ship_state = "departed"
				_finish("stranded")


## The boss boards; confirms if living workers are still ashore.
func request_board(_by: Node) -> void:
	if ship_state != "docked" or boarded_player:
		return
	var ashore: Array[String] = []
	for w in Game.crew.workers.values():
		var wk := w as Worker
		if worker_alive(wk) and not escaped.has(wk.id):
			ashore.append(str(wk.emp.name))
	if not ashore.is_empty() and Game.end_screen:
		Game.end_screen.confirm("Leave them behind?", "%s %s still on the island. If you board now, the ship leaves and they stay behind.\nBoarding is open for another %s. The game is paused while you decide." % [", ".join(ashore), "is" if ashore.size() == 1 else "are", CampaignService.fmt_time(maxf(BOARDING_WINDOW - ship_t, 0.0))], "Board and leave without %s" % ", ".join(ashore), func() -> void: _board_player(), "Wait for them", func() -> void: pass)
	else:
		_board_player()


func _board_player() -> void:
	boarded_player = true
	mode = "escaped"
	mode_changed.emit(mode)
	_finish("escaped")


func _finish(kind: String) -> void:
	var lines := PackedStringArray()
	var c: CampaignService = Game.campaign
	if kind == "escaped":
		lines.append("You reached the rescue ship at dawn on day 36.")
	else:
		lines.append("The ship waited, then left without you.")
	lines.append("The contract failed on day 30; these five days were survival, not a finished job.")
	lines.append("")
	if Game.dog and Game.dog.boarded_once:
		lines.append("Biscuit: aboard, safe.")
	if c:
		for e in c.payroll.employees:
			var st := str(e.status)
			var id := str(e.id)
			if st == "dead":
				lines.append("%s: died on day %d." % [e.name, int(e.get("death_day", 0))])
			elif escaped.has(id):
				lines.append("%s: escaped with you." % e.name)
			elif st == "departed":
				lines.append("%s: left the island earlier." % e.name)
			elif st == Payroll.ACTIVE:
				lines.append("%s: left behind on the island." % e.name)
	if Game.end_screen:
		Game.end_screen.show_outcome("Survived" if kind == "escaped" else "Stranded", lines)


# ------------------------------------------------------------ saving

func capture() -> Dictionary:
	return {"mode": mode, "hunt_day": hunt_day, "t": t, "dead_workers": dead_workers.duplicate(), "escaped": escaped.duplicate(), "ship_state": ship_state, "ship_t": ship_t, "truck_use": truck_use, "info_shown": _info_shown, "foreman": foreman.capture() if foreman and is_instance_valid(foreman) else {}}


func restore(d: Dictionary) -> void:
	pending_restore = false
	mode = str(d.get("mode", "none"))
	if mode == "transition":
		mode = "hunt"
	hunt_day = int(d.get("hunt_day", 30))
	t = float(d.get("t", DAYLIGHT + DUSK))
	dead_workers.clear()
	for x in d.get("dead_workers", []):
		dead_workers.append(str(x))
	escaped.clear()
	for x in d.get("escaped", []):
		escaped.append(str(x))
	truck_use = int(d.get("truck_use", 0))
	_info_shown = bool(d.get("info_shown", true))
	if not hunt_active():
		return
	build_hide_spots()
	if Game.crew:
		for id in dead_workers:
			var w: Worker = Game.crew.workers.get(id)
			if w:
				w.die()
	var fd: Dictionary = d.get("foreman", {})
	_spawn_foreman()
	if not fd.is_empty():
		foreman.restore(fd)
	if Game.dog and Game.dog.routine != "boarded":
		Game.dog.routine = "refuge"
		var a := get_tree().get_nodes_in_group("dog_refuge")
		if not a.is_empty():
			Game.dog.global_position = (a[0] as Node3D).global_position
			Game.dog.state = CampDog.State.REFUGE
	ship_state = str(d.get("ship_state", "none"))
	if mode == "rescue":
		_build_ship()
		ship_state = "approaching"   # re-approach from sea: never spawns docked mid-boarding
		ship_t = 0.0
