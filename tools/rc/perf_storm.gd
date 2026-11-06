extends "res://tools/rc/perf_probe.gd"
## Phase 23 storm performance comparison: the same locations measured under
## clear weather and under a severe coastal storm (preview override: rain,
## gust fronts, sea state, synthetic strikes with flashes, thunder and the
## near-strike light). Headless = CPU/game logic only; with a renderer
## (xvfb + lavapipe here) it is a software-rendering upper bound.
##   godot --headless res://tools/rc/perf_storm.tscn
## Writes user://perf_storm[_rendered].json and prints PERF lines.


func _ready() -> void:
	if OS.has_environment("FRAMES"):
		FRAMES = int(OS.get_environment("FRAMES"))
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = "island_r2"
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while (Game.crew == null or not world.systems_ready) and g < 3000:
		await get_tree().process_frame
		g += 1
	for k in 30:
		await get_tree().physics_frame
	results["renderer"] = RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_video_adapter_vendor()
	results["headless"] = DisplayServer.get_name() == "headless"
	results["resolution"] = str(get_viewport().get_visible_rect().size)
	var cs: CampaignService = Game.campaign
	cs.start_test_route(true, true)
	Game.director.next_in = 99999.0
	for k in 120:
		await get_tree().physics_frame
	var p := Game.player as Player
	var w: WeatherService = Game.weather
	var spots := {}
	var forest := World.camp_origin() + Vector3(-120, 0, -200)
	forest.y = World.height_at(forest.x, forest.z)
	spots["dense_forest"] = [forest + Vector3(0, 1.65, 0), forest + Vector3(30, 1.5, -30)]
	var c2 := World.camp_origin() + Vector3(150, 0, -150)
	for i in World.tree_count():
		var id := int(World.trees.id[i])
		if not World.removed_trees.has(id) and Vector2(World.trees.x[i] - c2.x, World.trees.z[i] - c2.z).length() < 180.0:
			World.remove_tree(id)
	c2.y = World.height_at(c2.x, c2.z)
	spots["cleared_land"] = [c2 + Vector3(0, 1.65, 0), c2 + Vector3(60, 1, 0)]
	var shore := Game.crew.dock_shore
	spots["shore"] = [shore + Vector3(0, 1.65, 0), shore + Vector3(0, 1.0, 40.0)]
	var cam := NightAnchors.camper().global_position
	spots["camper_interior"] = [cam + Vector3(0, 1.2, 0), cam + Vector3(0, 1.2, 3)]
	spots["quad_surveillance"] = spots["camper_interior"]
	var wall: CameraWall = Game.tv
	for name in spots:
		var at: Array = spots[name]
		if name == "quad_surveillance":
			wall.force_active = true
			wall.set_power(true)
			wall.set_mode("quad")
		for wx in ["clear", "severe_coastal"]:
			w.set_override(wx, true)
			p.teleport(at[0], at[1])
			for k in 90:
				await get_tree().physics_frame
			var th0 := w.thunders
			var f0 := w.strikes_fired
			await _measure("%s__%s" % [name, wx])
			var r: Dictionary = results["%s__%s" % [name, wx]]
			r["thunders"] = w.thunders - th0
			r["strikes"] = w.strikes_fired - f0
			r["rain"] = snappedf(w.rain, 0.01)
			r["visibility"] = snappedf(w.visibility, 0.01)
			r["layer"] = w.listening_layer()
		if name == "quad_surveillance":
			wall.set_mode("off")
			wall.force_active = false
	w.set_override("", true)
	# Summary: severe minus clear per location.
	var cmp := {}
	for name in spots:
		var a: Dictionary = results["%s__clear" % name]
		var b: Dictionary = results["%s__severe_coastal" % name]
		cmp[name] = {"mean_ms": [a.mean_ms, b.mean_ms], "p95_ms": [a.p95_ms, b.p95_ms], "max_ms": [a.max_ms, b.max_ms],
			"voices_peak": [_voices(a), _voices(b)], "thunders_in_window": b.thunders}
	results["comparison"] = cmp
	var f := FileAccess.open("user://perf_storm%s.json" % ("" if results.headless else "_rendered"), FileAccess.WRITE)
	f.store_string(JSON.stringify(results, " "))
	f.close()
	print("PERF_COMPARE ", JSON.stringify(cmp))
	World.removed_trees.clear()
	get_tree().quit()


func _voices(r: Dictionary) -> int:
	return int(r.get("voices_peak", 0))
