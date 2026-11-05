extends Node
## Phase 20: prepared fixture saves for testers (labelled fixtures, not real
## play). Each starts a real new standard campaign, moves it to the fixture
## point and writes a normal save file:
##   slot_2_terminal_day30.json   day 30, 50 s before the 1,200 s cutoff
##   slot_2_offshore_day3.json    day 3, just before the first offshore visit,
##                                standing on the shore by the dock
##   slot_2_extraction_day35.json hunt night 35, about a minute before the
##                                day 36 dawn rescue, near the dock
##   godot --headless res://tools/rc/make_fixture_saves.tscn
## Output: user://fixtures/ (CI copies them into the test build).

const OUT := "user://fixtures"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var bad := 0
	var only := OS.get_environment("ONLY_FX")
	for fx in ["terminal_day30", "offshore_day3", "extraction_day35"]:
		if only != "" and fx != only:
			continue
		var ok := await _make(fx)
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
	var path := "%s/slot_2_%s.json" % [OUT, fx]
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
	Engine.time_scale = 8.0
	var res := "timeout"
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
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
		if res != "timeout":
			break
	Engine.time_scale = 1.0
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
			cs.clock.t = 25.0
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
	await get_tree().physics_frame
	var state := SaveService.capture_state(world)
	state["fixture"] = {"name": fx, "note": "Phase 20 prepared fixture save (not real play)", "made_by": "tools/rc/make_fixture_saves.gd"}
	var ok := SaveService.write_file(path, state)
	SaveService.path_override = ""
	world.queue_free()
	for k in 5:
		await get_tree().process_frame
	World.removed_trees.clear()
	return ok and FileAccess.file_exists(path)
