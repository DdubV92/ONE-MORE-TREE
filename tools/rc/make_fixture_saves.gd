extends Node
## Phase 20: prepared fixture saves for testers (labelled fixtures, not real
## play). Each starts a real new standard campaign, moves it to the fixture
## point and writes a normal save file:
##   slot_2_terminal_day30.json   day 30, 50 s before the 1,200 s cutoff
##   slot_2_offshore_day3.json    day 3, just before the first offshore visit,
##                                standing on the shore by the dock
##   slot_2_extraction_day35.json hunt night 35, about a minute before the
##                                day 36 dawn rescue, near the dock
## Phase 23 (storms; each uses a visit from that campaign's own seeded
## schedule, so the weather is real scheduled weather, not an override):
##   slot_2_storm_subtle_rain.json  daylight, just before a drizzle/shower onset
##   slot_2_storm_severe.json       just before a thunderstorm builds to peak
##   slot_2_storm_walker.json       night storm, Thunder Walker mid-encounter
## Verify-only: "extraction_storm" loads the day 35 save under a forced severe
## coastal storm and checks the day 36 rescue still arrives in poor visibility.
##   godot --headless res://tools/rc/make_fixture_saves.tscn
## Output: user://fixtures/ (CI copies them into the test build).

const OUT := "user://fixtures"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var bad := 0
	var only := OS.get_environment("ONLY_FX")
	for fx in ["terminal_day30", "offshore_day3", "extraction_day35", "storm_subtle_rain", "storm_severe", "storm_walker", "extraction_storm"]:
		if only != "" and fx != only:
			continue
		var ok := true
		if fx == "extraction_storm":
			if not FileAccess.file_exists("%s/slot_2_extraction_day35.json" % OUT):
				ok = await _make("extraction_day35")
		else:
			ok = await _make(fx)
			print("FIXTURE %s %s" % [fx, "ok" if ok else "FAILED"])
		var v := await _verify(fx)
		print("FIXTURE_VERIFY %s %s" % [fx, v])
		if not ok or not v.begins_with("ok"):
			bad += 1
	get_tree().quit(1 if bad > 0 else 0)


## Loads the fixture through the normal campaign load path and checks that
## it plays out: the cutoff closes into abandonment; the offshore visit
## starts; the rescue ship arrives at dawn of day 36.
func _verify(fx: String) -> String:
	var path := "%s/slot_2_%s.json" % [OUT, "extraction_day35" if fx == "extraction_storm" else fx]
	var copy := "%s/verify_%s.json" % [OUT, fx]
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy))
	SaveService.path_override = copy
	Game.mode = Game.Mode.CAMPAIGN
	Game.new_game = false
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while (Game.crew == null or not world.systems_ready or Game.player == null) and g < 4000:
		await get_tree().process_frame
		g += 1
	var w: WeatherService = Game.weather
	var th0 := w.thunders
	var sf0 := w.strikes_fired
	var min_vis := 1.0
	var walker_seen := false
	if fx == "extraction_storm":
		w.set_override("severe_coastal", true)
	Engine.time_scale = 4.0 if fx == "storm_walker" else 8.0
	var res := "timeout"
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 180000:      # slow CI runners need headroom
		await get_tree().physics_frame
		var cs: CampaignService = Game.campaign
		match fx:
			"terminal_day30":
				if cs.contract.is_closed():
					res = "ok: contract closed at the cutoff (%s)" % cs.contract.state
			"offshore_day3":
				if not Game.offshore.visit.is_empty():
					res = "ok: offshore visit %s started at t=%.0f" % [Game.offshore.visit.id, cs.clock.t]
			"extraction_day35":
				if Game.hunt.mode == "rescue":
					res = "ok: rescue ship %s at dawn of day %d" % [Game.hunt.ship_state, Game.hunt.hunt_day]
			"extraction_storm":
				min_vis = minf(min_vis, w.visibility)
				if Game.hunt.mode == "rescue":
					res = "ok: rescue ship %s at dawn of day %d in a severe storm (visibility %.2f, %d strikes)" % [Game.hunt.ship_state, Game.hunt.hunt_day, min_vis, w.strikes_fired - sf0]
					if min_vis > 0.5:
						res = "visibility never dropped (%.2f)" % min_vis
			"storm_subtle_rain":
				if w.rain > 0.08 and w.lightning < 0.05 and w.visit_id != "":
					res = "ok: %s %s rain %.2f, visibility %.2f, no lightning" % [w.profile_name, w.phase_name, w.rain, w.visibility]
			"storm_severe":
				if w.thunders > th0 + 1 and w.strikes_fired > sf0 + 1:
					res = "ok: %s %s, %d strikes, %d thunders, gust %.2f, visibility %.2f" % [w.profile_name, w.phase_name, w.strikes_fired - sf0, w.thunders - th0, w.gust, w.visibility]
			"storm_walker":
				var st: StormTerrors = Game.storm_terrors
				var live := st.runs.filter(func(r: Dictionary) -> bool: return str(r.beat) == "sb02")
				if not live.is_empty() and st._actors.has(live[0].id):
					walker_seen = true
				elif walker_seen and not st.records.is_empty():
					var last: Dictionary = st.records.back()
					res = "ok: Thunder Walker resumed after load and ended (%s; %d reveals)" % [str(last.get("result", last.get("reason", "?"))), (last.get("presented", []) as Array).size()]
				elif not walker_seen:
					res = "walker not restored from the save"
		if res != "timeout":
			break
	Engine.time_scale = 1.0
	if w:
		w.set_override("")
	SaveService.path_override = ""
	world.queue_free()
	for k in 5:
		await get_tree().process_frame
	for f in [copy, copy + ".bak", copy + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	World.removed_trees.clear()
	return res


func _make(fx: String) -> bool:
	var path := "%s/slot_2_%s.json" % [OUT, fx]
	SaveService.path_override = path
	for f in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	Game.mode = Game.Mode.CAMPAIGN
	Game.new_game = true
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while (Game.crew == null or not world.systems_ready or Game.player == null) and g < 4000:
		await get_tree().process_frame
		g += 1
	for k in 60:
		await get_tree().physics_frame
	var cs: CampaignService = Game.campaign
	var p := Game.player as Player
	match fx:
		"terminal_day30":
			cs.clock.day = 30
			cs.clock.t = WorkdayClock.NIGHT_AT - 50.0
			cs.clock.advance(0.01)
			p.teleport(CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(0, 0, 4)) + Vector3(0, 1.65, 0), CampLayout.world(CampLayout.DELIVERY_RACK_POS))
		"offshore_day3":
			cs.clock.day = 3
			cs.clock.t = 35.0          # 5 s before the visit starts (t = 40)
			cs.clock.advance(0.01)
			var shore := Game.crew.dock_shore
			p.teleport(shore + Vector3(0, 1.65, 0), shore + Vector3(0, 1.0, 40.0))
		"extraction_day35":
			cs.contract._close_deadline()
			for k in 30:
				await get_tree().physics_frame
			var h := Game.hunt
			if h.mode == "none":
				h.begin_abandonment()
			# Acknowledge the transition card exactly as its button does.
			if Game.end_screen and Game.end_screen.has_method("_resume"):
				Game.end_screen._resume()
			get_tree().paused = false
			for k in 30:
				await get_tree().physics_frame
			h.mode = "hunt"
			h.hunt_day = 35
			h.t = HuntService.CYCLE - 60.0
			var dock := Game.crew.dock_shore
			p.teleport(dock + Vector3(2, 1.65, -6), dock + Vector3(0, 1.0, 20.0))
		"storm_subtle_rain", "storm_severe", "storm_walker":
			var why := await _storm_point(fx, cs, p)
			if why != "":
				push_error("fixture %s: %s" % [fx, why])
				return false
	await get_tree().physics_frame
	var state := SaveService.capture_state(world)
	state["fixture"] = {"name": fx, "note": "%s prepared fixture save (not real play)" % ("Phase 23" if fx.begins_with("storm") else "Phase 20"), "made_by": "tools/rc/make_fixture_saves.gd"}
	var ok := SaveService.write_file(path, state)
	SaveService.path_override = ""
	world.queue_free()
	for k in 5:
		await get_tree().process_frame
	World.removed_trees.clear()
	return ok and FileAccess.file_exists(path)


## Finds the storm in this campaign's own schedule and moves the clock to it.
func _storm_point(fx: String, cs: CampaignService, p: Player) -> String:
	var w: WeatherService = Game.weather
	var sch := w._sched()
	var want: Array = ["mist_drizzle", "passing_shower"] if fx == "storm_subtle_rain" else ["thunderstorm", "severe_coastal"]
	var pick := {}
	var pick_day := 0
	for d in range(2, 31):
		for v in sch.days[d].visits:
			if not str(v.profile) in want or bool(v.quiet):
				continue
			var onset := float(v.start) + float(v.durs[0])
			var peak := onset + float(v.durs[1]) + float(v.durs[2])
			match fx:
				"storm_subtle_rain":
					if onset > 60.0 and onset < WorkdayClock.NIGHT_AT - 240.0:
						pick = v
				"storm_severe":
					if sch.strikes(d, v).size() > 8 and onset > 60.0 and peak < WorkdayClock.NIGHT_AT - 60.0:
						pick = v
				"storm_walker":
					# A storm whose peak is after nightfall (walker beats are
					# night-only and the save should be a real night storm).
					if sch.strikes(d, v).size() > 8 and peak > WorkdayClock.NIGHT_AT + 20.0:
						pick = v
			if not pick.is_empty():
				pick_day = d
				break
		if pick_day > 0:
			break
	if pick.is_empty():
		return "no %s visit in this seed" % str(want)
	var d0 := float(pick.start) + float(pick.durs[0])
	var t := d0 - 10.0                                   # subtle: just before onset
	if fx == "storm_severe":
		t = d0 + float(pick.durs[1])                      # start of the build
	elif fx == "storm_walker":
		t = d0 + float(pick.durs[1]) + float(pick.durs[2]) + 15.0

	cs.clock.restore({"day": pick_day, "t": minf(t, WorkdayClock.NIGHT_AT), "night_exposure": maxf(t - WorkdayClock.NIGHT_AT, 0.0), "running": true})
	var camp := CampLayout.world(Vector3(0, 0, 0))
	p.teleport(camp + Vector3(0, 1.65, 0), camp + Vector3(0, 1.0, 30.0))
	for k in 30:
		await get_tree().physics_frame
	if fx != "storm_walker":
		return ""
	if w.visit_id != str(pick.id) and w.profile_name != str(pick.profile):
		return "storm not reached for the walker (%s)" % w.profile_name
	var st: StormTerrors = Game.storm_terrors
	Game.director.next_in = 99999.0
	Game.director.last_end_t = -99999.0
	Game.director.family_cooldown.clear()
	st.forced = "sb02"
	var r := st.start("sb02")
	st.forced = ""
	if r.is_empty():
		return "Thunder Walker not staged: %s" % str(st.records.back() if not st.records.is_empty() else {})
	# Let the first flash reveal it, then save mid-encounter.
	var g := 0
	Engine.time_scale = 3.0
	while st.runs.has(r) and (r.presented as Array).is_empty() and g < 6000:
		await get_tree().physics_frame
		g += 1
	Engine.time_scale = 1.0
	if not st.runs.has(r):
		return "Thunder Walker ended before the save point"
	return ""
