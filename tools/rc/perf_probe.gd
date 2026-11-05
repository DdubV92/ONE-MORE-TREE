extends Node
## Phase 20 performance probe: builds the real world and measures repeatable
## scenarios. Headless runs measure CPU/game logic (process + physics); a
## run with a renderer (xvfb + lavapipe here) adds a software-rendering
## upper bound that is NOT representative of a real GPU.
##   godot --headless res://tools/rc/perf_probe.tscn
##   godot res://tools/rc/perf_probe.tscn            (with a renderer)
## Writes user://perf_probe.json and prints PERF lines.

const FRAMES := 240

var results := {}


func _ready() -> void:
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
	results["world_build_ms"] = world.build_ms.duplicate() if world.get("build_ms") else {}
	var cs: CampaignService = Game.campaign
	cs.start_test_route(true, true)
	for k in 240:
		await get_tree().physics_frame
	var p := Game.player as Player
	# 1 dense woods
	var forest := World.camp_origin() + Vector3(-120, 0, -200)
	forest.y = World.height_at(forest.x, forest.z)
	p.teleport(forest + Vector3(0, 1.65, 0), forest + Vector3(30, 1.5, -30))
	await _measure("dense_woods")
	# 2 busy camp + active logging (crew working, logs on the ground)
	p.teleport(World.camp_origin() + Vector3(0, 1.65, 12), World.camp_origin() + Vector3(0, 1, -20))
	await _measure("busy_camp_crew_working")
	# 3 heavy rain
	Game.weather.set_override("storm", true)
	await _measure("heavy_rain_storm")
	Game.weather.set_override("", true)
	# 4 ship + helicopter
	var off: OffshoreSurvey = Game.offshore
	off.preview_visit(3)
	off.visit.state = "lap"
	off.visit.theta = off.theta_camp
	off.visit.lap = 0.4
	off.visit.launched = true
	off._place_ship()
	off.heli.wps = off.leg_points("camp")
	off.heli.wp_i = 1
	off.heli.set_state("fly")
	off.heli.rotor = 1.0
	off.heli.global_position = World.camp_origin() + Vector3(200, 70, 250)
	p.teleport(Game.crew.dock_shore + Vector3(0, 1.65, 0), off.ship_position())
	await _measure("ship_and_helicopter")
	off.stop_preview()
	# 5 cleared terrain (trees removed around the camera)
	var c2 := World.camp_origin() + Vector3(150, 0, -150)
	var removed := []
	for i in World.tree_count():
		var id := int(World.trees.id[i])
		if not World.removed_trees.has(id) and Vector2(World.trees.x[i] - c2.x, World.trees.z[i] - c2.z).length() < 180.0:
			World.remove_tree(id)
			removed.append(id)
	c2.y = World.height_at(c2.x, c2.z)
	p.teleport(c2 + Vector3(0, 1.65, 0), c2 + Vector3(60, 1, 0))
	await _measure("cleared_terrain")
	results["cleared_trees_removed"] = removed.size()
	# 6 active pursuit (hunt preview with the Foreman roaming near the boss)
	Game.hunt.hunt_preview = true
	Game.hunt._spawn_foreman()
	var fm: Foreman = Game.hunt.foreman
	fm.set_state("ROAM")
	fm.global_position = c2 + Vector3(25, 0, 10)
	fm.global_position.y = World.height_at(fm.global_position.x, fm.global_position.z)
	await _measure("active_pursuit")
	var f := FileAccess.open("user://perf_probe.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, " "))
	f.close()
	print("PERF_JSON ", JSON.stringify(results))
	get_tree().quit()


func _measure(name: String) -> void:
	for k in 20:
		await get_tree().process_frame
	var ft := []
	var proc := []
	var phys := []
	var last := Time.get_ticks_usec()
	for k in FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		last = now
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	ft.sort()
	var sum := 0.0
	for v in ft:
		sum += float(v)
	var r := {"frames": FRAMES, "mean_ms": snappedf(sum / ft.size(), 0.01), "p50_ms": snappedf(float(ft[ft.size() / 2]), 0.01),
		"p95_ms": snappedf(float(ft[int(ft.size() * 0.95)]), 0.01), "max_ms": snappedf(float(ft[ft.size() - 1]), 0.01),
		"mem_static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"sound_voices": SoundService.active_count() if SoundService.instance() else {}}
	results[name] = r
	print("PERF %s %s" % [name, JSON.stringify(r)])


func _avg(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(a.size(), 1)
