extends Node
## Phase 6 headless scenario runner (Preview, in memory, never saved):
##  A. once-only dog rescue: wind door -> escape -> search (grace) ->
##     reload mid-search (no door replay) -> reunion -> follow home -> bed.
##  B. day-30 abandonment -> hunt: dog at the dock refuge, Foreman revealed
##     far away, company frozen.
##  C. Foreman perception: open-ground detection/chase/attack vs hidden
##     trials (unseen entry vs seen entry).
##  D. five continuous hunt cycles -> rescue ship -> dog boards once ->
##     worker boards -> player boards -> outcome.
##   godot --headless --fixed-fps 60 res://tools/hunt_sim.tscn

var w: IslandWorld
var out := {}


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	w = load("res://scenes/world.tscn").instantiate()
	w.build_ui = false
	add_child(w)
	var g := 0
	while not w.systems_ready and g < 900:
		await get_tree().physics_frame
		g += 1
	w.campaign.start_test_route(false)
	await _rescue()
	await _abandon()
	await _perception()
	await _cycles()
	print("HUNT_SIM ", JSON.stringify(out))
	get_tree().quit()


func _step(n: int, dt := 1.0 / 60.0) -> void:
	for i in n:
		await get_tree().physics_frame


func _rescue() -> void:
	var r: DogRescue = w.dog_rescue
	var dog: CampDog = w.dog
	var p: Player = w.player
	var cs: CampaignService = w.campaign
	cs.clock.day = 6
	cs.clock.advance(maxf(WorkdayClock.NIGHT_AT + 5.0 - cs.clock.t, 0.0))
	dog.pets = 1
	w.teleport_to("camper")
	# Put the dog to bed through its real route.
	dog.global_position = CampLayout.world(Vector3(0, 0, 6))
	dog.go_home()
	for i in 4000:
		dog._process(1.0 / 30.0)
		if dog.state == CampDog.State.SLEEP:
			break
	r.force_start()
	var states := []
	for i in 2400:
		await get_tree().physics_frame
		if states.is_empty() or states[states.size() - 1] != r.state:
			states.append(r.state)
		if r.state == "SEARCH":
			break
	var spot_d := dog.global_position.distance_to(World.camp_origin())
	out["rescue_states"] = states
	out["rescue_dog_distance_from_camp"] = snappedf(spot_d, 1.0)
	out["rescue_dog_state"] = CampDog.State.keys()[dog.state]
	out["rescue_grace_until"] = w.threat.grace_until
	out["sleep_blocked"] = not bool(cs.can_sleep().ok) and str(cs.can_sleep().reason) == "Find your dog first."
	# Reload mid-search: the door scare must not replay.
	var snap := JSON.parse_string(JSON.stringify(r.capture()))
	var dsnap := JSON.parse_string(JSON.stringify(dog.capture()))
	dog.restore(dsnap)
	r.restore(snap)
	out["reload_state"] = r.state
	# Walk to the dog and pet it.
	p.teleport_feet(dog.global_position + Vector3(1.5, 0, 0), 0.0)
	await _step(5)
	dog.pet(p)
	for i in 200:
		await get_tree().physics_frame
		if r.state == "RETURN_HOME":
			break
	out["after_pet"] = r.state
	# Walk the boss home along the real path; the dog follows.
	var home := CampLayout.world(CampLayout.CAMPER_POS + Vector3(2.4, 0, 1.85))
	var path: Array[Vector3] = w.crew.nav.find_path(p.global_position, home)
	var max_gap := 0.0
	for q in path:
		p.teleport_feet(q, 0.0)
		for k in 25:
			await get_tree().physics_frame
		max_gap = maxf(max_gap, dog.global_position.distance_to(p.global_position))
	w.teleport_to("camper")
	for i in 3600:
		await get_tree().physics_frame
		if r.state == "RESOLVED":
			break
	out["rescue_final"] = r.state
	out["dog_home_state"] = CampDog.State.keys()[dog.state]
	out["dog_inside_camper"] = dog.inside_camper()
	out["follow_max_gap_m"] = snappedf(max_gap, 0.1)
	out["rescue_beats"] = r.beats
	r._check_eligible()
	out["retrigger_blocked"] = r.state == "RESOLVED" and r.trigger_id != ""


func _abandon() -> void:
	var cs: CampaignService = w.campaign
	var h: HuntService = w.hunt
	cs.clock.day = 30
	cs.contract.state = ContractService.ABANDONMENT
	h.begin_abandonment()
	if w.end_screen.showing == "info":
		w.end_screen._resume()
	await _step(30)
	out["hunt_mode"] = h.mode
	out["foreman_distance"] = snappedf(h.foreman.global_position.distance_to(w.player.global_position), 1.0)
	out["dog_routine"] = w.dog.routine
	out["hire_blocked"] = not bool(w.crew.can_hire().ok)
	out["hide_spots"] = get_tree().get_nodes_in_group("hide_spot").size()
	out["sleep_blocked_in_hunt"] = not bool(cs.can_sleep().ok)
	for i in 1800:
		await get_tree().physics_frame
		if w.dog.state == CampDog.State.REFUGE:
			break
	out["dog_reached_refuge"] = w.dog.state == CampDog.State.REFUGE


## Detection in the open, then hidden trials.
func _perception() -> void:
	var h: HuntService = w.hunt
	var f: Foreman = h.foreman
	var p: Player = w.player
	# Open ground at dusk-like light: stand 14 m in front of it.
	h.t = HuntService.DAYLIGHT - 60.0
	f.grace = 0.0
	f.global_position = CampLayout.world(Vector3(0, 0, 40))
	f.global_position.y = World.height_at(f.global_position.x, f.global_position.z)
	f.rotation.y = 0.0
	var front := f.global_position - f.global_basis.z * 14.0
	front.y = World.height_at(front.x, front.z)
	p.teleport_feet(front, 0.0)
	f.set_state("ROAM")
	f.path.clear()
	var seq := []
	for i in 900:
		await get_tree().physics_frame
		if seq.is_empty() or seq[seq.size() - 1] != f.state:
			seq.append(f.state)
		if h.player_dead:
			break
	out["open_ground_states"] = seq
	out["open_ground_killed"] = h.player_dead
	# Recover the preview attempt (end screen preview path).
	if w.end_screen.visible:
		w.end_screen._resume()
	h.player_dead = false
	h.mode = "hunt"
	Game.block_saves = false
	# Hidden trials: probe the player's spot directly N times.
	var spots := get_tree().get_nodes_in_group("hide_spot")
	var bed: HideSpot = null
	for s in spots:
		if (s as HideSpot).kind == "under_bed" and (s as HideSpot).building == "cabin":
			bed = s
			break
	var found_unseen := 0
	var found_seen := 0
	var trials := 20
	for k in 2:
		for i in trials:
			p.teleport_feet(bed.exit_point, 0.0)
			await _step(2)
			p.hide_in(bed)
			if k == 1:
				h.seen_entries[bed] = h.hunt_clock()
			else:
				h.seen_entries.erase(bed)
			f.probe = bed
			f.probe_t = 2.5
			f.set_state("SEARCH")
			var before := h.is_exposed(p)
			f._probe_spot(0.01)
			if h.is_exposed(p) and not before:
				if k == 0:
					found_unseen += 1
				else:
					found_seen += 1
			# end attack without killing (trial only)
			f.set_state("ROAM")
			f.attack_target = null
			h.exposed.clear()
			p.hiding = bed
			p.leave_hide()
			await _step(2)
	out["probe_found_unseen_of_20"] = found_unseen
	out["probe_found_seen_entry_of_20"] = found_seen
	out["dog_targeted"] = false
	for x in f._humans():
		if x == w.dog:
			out["dog_targeted"] = true


## Five full cycles: jump the continuous clock near each dawn.
func _cycles() -> void:
	var h: HuntService = w.hunt
	var p: Player = w.player
	var days := []
	h.foreman.grace = 9999.0      # keep the boss alive during the clock check
	p.teleport_feet(w.crew.dock_end + Vector3(0, 0.6, -3.0), 0.0)
	for i in 6:
		h.t = HuntService.CYCLE - 0.5
		await _step(60)
		days.append([h.hunt_day, h.mode])
	out["cycles"] = days
	# Ship approach and docking.
	for i in 4000:
		await get_tree().physics_frame
		if h.ship_state == "docked":
			break
	out["ship_state"] = h.ship_state
	out["dog_boarded_once"] = w.dog.boarded_once
	var again := w.dog.board_ship()
	out["dog_second_board_refused"] = not again
	# Worker walks to the dock and boards.
	var wk: Worker = w.crew.workers.values()[0]
	wk.global_position = w.crew.dock_end + Vector3(0, 0, -1.0)
	await _step(30)
	out["worker_escaped"] = h.escaped.has(wk.id)
	h._board_player()
	out["final_mode"] = h.mode
	out["outcome_title"] = w.end_screen.showing
	out["patterns_observed"] = h.foreman.observed.keys()
