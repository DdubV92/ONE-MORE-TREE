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
const FIRST_DAY := 31            # legacy numbering (a failed 30-day contract)
const LAST_DAY := 35
const BOARDING_WINDOW := 480.0
## Phase 25 (owner decision): the hunt follows EVERY contract, won or lost;
## it is how you leave the island. A won contract brings the company ship
## after HUNT_DAYS days. A failed one brings nobody: the hunt has no end
## date ("stranded") until the player repairs the dock beacon (EscapeBeacon)
## or dies. Hunts saved before this change keep their five days.
const HUNT_DAYS := 3
const LEGACY_HUNT_DAYS := 5
const HARD_BOARDING_WINDOW := 240.0

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
var start_day := 30              # contract day the hunt began on
var hunt_days := HUNT_DAYS       # days until the company ship (won contracts)
var contract_won := false
var stranded := false            # nobody is coming unless the beacon calls them
var beacon: EscapeBeacon


func _ready() -> void:
	_rng.seed = 3535
	beacon = EscapeBeacon.new()
	beacon.name = "EscapeBeacon"
	add_child(beacon)


## Dawn on which the company ship arrives (won contracts only).
func rescue_day() -> int:
	return start_day + hunt_days + 1


func boarding_window() -> float:
	return HARD_BOARDING_WINDOW if stranded else BOARDING_WINDOW


func hunt_active() -> bool:
	return mode in ["hunt", "rescue"]


func hiding_enabled() -> bool:
	return hunt_active() or hunt_preview


func hunt_clock() -> float:
	return (hunt_day - start_day) * CYCLE + t


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
	begin_hunt(false)


## Starts the hunt. `won`: the contract was fulfilled, so the company ship
## comes after `hunt_days`; otherwise nobody is coming (stranded).
func begin_hunt(won: bool) -> void:
	if mode != "none" or pending_restore:
		return
	var c: CampaignService = Game.campaign
	contract_won = won
	stranded = not won
	hunt_days = HUNT_DAYS
	start_day = c.clock.day if c and c.clock and won else 30
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
	hunt_day = start_day
	# A failed contract ends at nightfall on its last day; a finished one
	# can end at any hour, so the hunt opens as that evening draws in.
	t = DAYLIGHT + DUSK if not won else DAYLIGHT
	if stranded:
		beacon.activate()
	_spawn_foreman()
	_show_transition_card()
	mode = "hunt"
	mode_changed.emit(mode)


func _show_transition_card() -> void:
	if _info_shown or Game.end_screen == null:
		return
	_info_shown = true
	var c := transition_text()
	Game.end_screen.show_info(c[0], c[1], "I understand")


## [title, body] of the rules card that opens the hunt.
func transition_text() -> Array:
	var rules := "Something tall is out there now, and it is not like the others. It is physical, and it can kill.\n- Lamps, closed doors and the camper NO LONGER keep you safe from it. They only hide or slow you.\n- Hide (" + Keys.label("interact") + ") under beds, in closets, behind the utility shelves, under the dock, in rock recesses, dense thickets, the far field sheds or the dock gear chest. If it saw you go in, it may look; brush will not hide you up close.\n- Break its line of sight and move quietly. It can outrun you for a few seconds, not forever.\n- The days are continuous: lying in a bed does not skip time. Company hiring and boats are closed."
	var dog := "Biscuit is safe at the dock alcove the whole time and boards any ship automatically. Do not go back for the dog.\n\nThe game is paused until you continue."
	if contract_won:
		var head := "The contract is complete. The company radio answered: the ship that takes everyone home reaches the dock at dawn on day %d. %s.\n\nBut the island is not finished with you." % [rescue_day(), _days_word(hunt_days)]
		var board := "- At dawn on day %d get yourself and your crew to the dock; boarding stays open for %d minutes." % [rescue_day(), int(BOARDING_WINDOW / 60.0)]
		return ["The job is done", "\n\n".join([head, rules + "\n" + board, dog])]
	var lost := "Night fell on the last day with the contract not met. The last company boat is gone, and no ship is coming for you."
	var way := "There is one thing on this island that can still reach anyone: the emergency beacon in the dock building. It is dead. Check it to see what it needs."
	return ["The company has left", "\n\n".join([lost, rules, way, dog])]


static func _days_word(n: int) -> String:
	return ["No days", "One day", "Two days", "Three days", "Four days", "Five days", "Six days"][clampi(n, 0, 6)]


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
	_update_objective()


## Phase 19: an intelligible survival objective while the hunt runs (never
## overrides another objective such as finding the dog).
func survival_objective() -> String:
	if mode == "hunt" and stranded and not beacon.calling():
		return beacon.objective()
	if mode == "hunt" and stranded:
		return beacon.objective()
	if mode == "hunt":
		var left := maxi(rescue_day() - hunt_day, 0)
		return "Survive until the rescue ship at dawn on day %d (%d %s to go). Hide where you aren't seen going in; if you're found, use the other way out." % [rescue_day(), left, "dawn" if left == 1 else "dawns"]
	if mode == "rescue":
		return "The rescue ship is at the dock. Get there - everyone who reaches the gangway gets aboard."
	return ""


func _update_objective() -> void:
	var o := survival_objective()
	var cur := str(Game.objective)
	if cur == "" or cur.begins_with("Survive until the rescue ship") or cur.begins_with("The rescue ship is at the dock") or cur.begins_with("No ship is coming") or cur.begins_with("The beacon") or cur.begins_with("You have every part") or cur.begins_with("The ship is at the dock"):
		Game.objective = o


func _on_dawn() -> void:
	# The company ship (won contract), or the ship the beacon called.
	if (not stranded and hunt_day >= rescue_day()) or (stranded and beacon.calling()):
		_rescue_arrives()
		return
	if Game.player:
		if stranded:
			Game.player.show_message("Day %d. No ship is coming." % hunt_day)
		else:
			Game.player.show_message("Day %d. %d day%s until the ship." % [hunt_day, rescue_day() - hunt_day, "" if rescue_day() - hunt_day == 1 else "s"])
	if Game.world_root and not player_dead:
		Game.world_root.save_campaign()
		Game.world_root.save_checkpoint("survival")


## Day tendencies (not cutscenes): later days lean toward observed routes,
## the trucks' road and finally the dock.
func day_bias() -> Vector3:
	# A calling beacon draws it to the dock, whatever the day.
	if beacon and beacon.calling() and Game.crew:
		return Game.crew.dock_shore
	# Stages count back from the ship's dawn (legacy five-day hunts: days
	# 33, 34, 35). A stranded hunt has no last day: it cycles the first two.
	var left := rescue_day() - hunt_day
	if stranded:
		left = 3 if (hunt_day - start_day) % 2 == 1 else 2
	if left == 3:
		if foreman and not foreman.searched.is_empty():
			return foreman.searched[0]
	elif left == 2:
		if truck_use > 0 and Game.vehicles and not Game.vehicles.trucks.is_empty():
			foreman.mark("F-H32")
			return (Game.vehicles.trucks.values()[0] as Truck).global_position
	elif left <= 1:
		if Game.crew:
			return Game.crew.dock_shore
	return Vector3.INF


## How much sharper the Foreman's guesses get the longer you are stranded
## ("a matter of time"): 0 at first, 1 after about five stranded days.
func strand_pressure() -> float:
	if not stranded:
		return 0.0
	return clampf(float(hunt_day - start_day - 1) / 5.0, 0.0, 1.0)


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
	var wrong := rng.randf() < lerpf(0.4, 0.1, strand_pressure())
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
	# Phase 19 fix: judge whether the entry is SEEN before the person counts
	# as hidden (otherwise an indoor hide could never be seen being entered).
	var seen := foreman != null and is_instance_valid(foreman) and foreman.state != "ARRIVAL" and foreman.can_see(who)
	spot.occupant = who
	hidden[who] = spot
	exposed.erase(who)
	if seen:
		seen_entries[spot] = hunt_clock()
		foreman.hear(spot.global_position, 999.0, "seen_entry", spot)
	if spot.kind in ["closet", "shed", "dock_store"]:
		hide_noise[spot] = hunt_clock()
		noise(spot.global_position, 7.0 if spot.kind != "dock_store" else 8.0, spot.kind, "human")
	elif spot.kind == "thicket":
		noise(spot.global_position, 5.0, "brush", "human")


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
		_:
			if spot.kind == "shed" and n != null and spot.has_meta("door_out"):
				out = n.find_path(from, spot.get_meta("door_out"))
				out.append(spot.get_meta("door_in"))
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
	# Phase 20 fix: once extraction is committed (or the hunt is otherwise
	# over), a stale attack callback cannot change the outcome; a worker who
	# already reached the gangway is safe.
	if mode in ["escaped", "stranded", "dead"] or player_dead:
		return
	if who is Worker and escaped.has((who as Worker).id):
		return
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
## Phase 27: "Stay close to me." Only someone who trusts the boss, and is
## not past what they can take, comes along.
const FOLLOW_TRUST := 0.6

func ask_to_follow(w: Worker) -> bool:
	if w == null or w.mind == null or not worker_alive(w):
		return false
	if w.mind.trust < FOLLOW_TRUST or w.mind.refuses_risk():
		return false
	w.emp["hunt_follow"] = true
	return true


func worker_decide(w: Worker) -> void:
	if not worker_alive(w):
		return
	if mode == "rescue" and ship_state == "docked":
		if not hidden.has(w):
			w.go_to(Game.crew.dock_end, "board", "boarding the rescue ship")
		return
	if hidden.has(w):
		return
	# Phase 27: a worker who trusts the boss stays with them (and hides
	# when they hide). Fear can still end it.
	if bool(w.emp.get("hunt_follow", false)):
		if w.mind and w.mind.refuses_risk():
			w.emp.erase("hunt_follow")
		else:
			var p := Game.player
			if p != null and p.get("hiding") != null:
				var free := _nearest_free_spot(w.global_position)
				if free:
					w.go_hide(free)
					return
			if w.activity != "move":
				w.activity = "follow"
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
	if not stranded:
		hunt_day = rescue_day()
	t = 0.0
	if beacon.calling():
		beacon.state = "answered"
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
					Game.player.show_message("The ship is at the dock. Boarding closes in %d minutes. Everyone who reaches the gangway gets aboard." % int(boarding_window() / 60.0))
		"docked":
			for w in Game.crew.workers.values():
				var wk := w as Worker
				if worker_alive(wk) and not escaped.has(wk.id) and wk.global_position.distance_to(end) < 3.5:
					escaped.append(wk.id)
					wk.visible = false
					wk.emp["escaped"] = true
			if ship_t > boarding_window() and not boarded_player:
				ship_state = "departed"
				_ship_left_without_you()


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
		Game.end_screen.confirm("Leave them behind?", "%s %s still on the island. If you board now, the ship leaves and they stay behind.\nBoarding is open for another %s. The game is paused while you decide." % [", ".join(ashore), "is" if ashore.size() == 1 else "are", CampaignService.fmt_time(maxf(boarding_window() - ship_t, 0.0))], "Board and leave without %s" % ", ".join(ashore), func() -> void: _board_player(), "Wait for them", func() -> void: pass)
	else:
		_board_player()


func _board_player() -> void:
	boarded_player = true
	mode = "escaped"
	mode_changed.emit(mode)
	_finish("escaped")


## The ship waited and left. Nobody else is coming: the hunt goes on with
## no end date, and the dock beacon becomes the only way out.
func _ship_left_without_you() -> void:
	if ship and is_instance_valid(ship):
		ship.queue_free()
	ship = null
	if _gang_spot and is_instance_valid(_gang_spot):
		_gang_spot.queue_free()
	_gang_spot = null
	ship_state = "none"
	var was_hard := stranded
	stranded = true
	mode = "hunt"
	mode_changed.emit(mode)
	if was_hard:
		# The beacon's ship came and went: it has to be called again.
		beacon.state = "ready"
		if Game.dock_site:
			Game.dock_site.beacon_state = "standby"
	else:
		beacon.activate()
	if Game.player:
		Game.player.show_message("The ship has gone without you. No one else is coming, unless you call them. The beacon in the dock building is the only way left.")
	if Game.world_root and not player_dead:
		Game.world_root.save_campaign()
		Game.world_root.save_checkpoint("survival")


func _finish(kind: String) -> void:
	var lines := PackedStringArray()
	var c: CampaignService = Game.campaign
	if contract_won and not stranded:
		lines.append("You reached the company ship at dawn on day %d." % rescue_day())
		lines.append("The contract was finished, and you lived through what came after it.")
	elif contract_won:
		lines.append("You finished the contract, missed the ship, and called another with the beacon.")
	else:
		lines.append("Nobody was coming. You repaired the beacon, called a ship and reached it on day %d." % hunt_day)
		lines.append("The contract failed; getting off the island was your own work.")
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
		# The finished job's own figures (trees, money, crew) under the outcome.
		if contract_won and Game.campaign_ui:
			lines.append("")
			for line in Game.campaign_ui.success_summary():
				lines.append(str(line))
		Game.end_screen.show_outcome("Survived" if kind == "escaped" else "Stranded", lines)


# ------------------------------------------------------------ saving

func capture() -> Dictionary:
	return {"mode": mode, "hunt_day": hunt_day, "t": t, "dead_workers": dead_workers.duplicate(), "escaped": escaped.duplicate(), "ship_state": ship_state, "ship_t": ship_t, "truck_use": truck_use, "info_shown": _info_shown, "start_day": start_day, "hunt_days": hunt_days, "contract_won": contract_won, "stranded": stranded, "beacon": beacon.capture(), "foreman": foreman.capture() if foreman and is_instance_valid(foreman) else {}}


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
	# Hunts saved before Phase 25: five days, company ship on day 36.
	start_day = int(d.get("start_day", 30))
	hunt_days = int(d.get("hunt_days", LEGACY_HUNT_DAYS))
	contract_won = bool(d.get("contract_won", false))
	stranded = bool(d.get("stranded", false))
	beacon.restore(d.get("beacon", {}))
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
