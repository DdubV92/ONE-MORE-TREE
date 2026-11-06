extends Node
## Phase 23 screenshot tool: severe storm at the shore, wet camp ground
## (puddles + rain rings), rain on the camper glass, a near lightning flash
## at night and the Thunder Walker revealed by a flash. Needs a renderer:
##   xvfb-run godot --rendering-driver vulkan res://tools/rc/capture_storm.tscn
## Writes res://captures/p23_*.png.


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = "island_r2"
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while (Game.crew == null or not world.systems_ready or Game.storm_terrors == null) and g < 4000:
		await get_tree().process_frame
		g += 1
	var cs: CampaignService = Game.campaign
	cs.start_test_route(true, true)
	Game.director.next_in = 99999.0
	for k in 120:
		await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var only := OS.get_cmdline_user_args()
	var p := Game.player as Player
	var w: WeatherService = Game.weather
	Settings.set_v("flash_reduction", "full")   # capture the real flash (the default is reduced)
	var shots := ["severe_shore", "puddles", "wet_glass", "night_flash", "thunder_walker"]
	for s in shots:
		if not only.is_empty() and not s in only:
			continue
		match s:
			"severe_shore":
				_clock(cs, 2, 700.0)
				w.set_override("severe_coastal", true)
				var shore := Game.crew.dock_shore
				p.teleport(shore + Vector3(-6, 2.2, -10), shore + Vector3(10, 0.5, 60.0))
				await _settle(150)
			"puddles":
				_clock(cs, 2, 650.0)
				w.set_override("steady_rain", true)
				w.wetness = 1.0
				var c := CampLayout.world(Vector3(4, 0, 6))
				p.teleport(c + Vector3(0, 1.65, 0), c + Vector3(3, 0.0, 9.0))
				await _settle(120)
			"wet_glass":
				_clock(cs, 2, 800.0)
				w.set_override("thunderstorm", true)
				w.wetness = 1.0
				var cam := NightAnchors.camper().global_position
				var win := _camper_window()
				var from := win + (Vector3(cam.x, win.y, cam.z) - win).normalized() * 0.9
				p.teleport(from, win + (win - from) * 4.0)
				await _settle(150)
			"night_flash":
				_clock(cs, 3, WorkdayClock.NIGHT_AT + 60.0)
				w.set_override("thunderstorm", true)
				var c2 := CampLayout.world(Vector3(0, 0, 0))
				p.teleport(c2 + Vector3(0, 1.65, 0), c2 + Vector3(-30, 6, -80))
				await _settle(120)
				var near := {"id": "CAP-N", "visit": "capture", "day": 3, "t": w.weather_t, "kind": "near", "off": [-90.0, -220.0], "dist": 236.0, "power": 1.0, "strokes": 3, "seed": 7}
				w.fire(near)
				var g2 := 0
				while w.flash < 0.6 and g2 < 120:
					await get_tree().process_frame
					g2 += 1
			"thunder_walker":
				if not await _walker(cs, p, w):
					print("CAPTURE thunder_walker could not be staged")
					continue
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://captures/p23_%s.png" % s)
		print("CAPTURE %s ok (%s %s rain %.2f vis %.2f flash %.2f)" % [s, w.profile_name, w.phase_name, w.rain, w.visibility, w.flash])
	w.set_override("", true)
	get_tree().quit()


func _clock(cs: CampaignService, day: int, t: float) -> void:
	cs.clock.restore({"day": day, "t": minf(t, WorkdayClock.NIGHT_AT), "night_exposure": maxf(t - WorkdayClock.NIGHT_AT, 0.0), "running": true})


func _settle(n: int) -> void:
	for k in n:
		await get_tree().process_frame


## The nearest pane using the rain glass material to the camper anchor.
func _camper_window() -> Vector3:
	var cam := NightAnchors.camper().global_position
	var glass := BuildKit.mat("glass")
	var best := Vector3.INF
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).material_override == glass:
			var q := (n as MeshInstance3D).global_position
			if q.distance_to(cam) > 0.8 and q.distance_to(cam) < best.distance_to(cam):
				best = q
	return best if best != Vector3.INF else cam + Vector3(2, 1.3, 0)


## The real encounter: a night storm from the schedule, the beat staged
## through the director, the shot taken while a flash reveals the figure.
func _walker(cs: CampaignService, p: Player, w: WeatherService) -> bool:
	var sch := w._sched()
	var tv := {}
	var day := 0
	for d in range(2, 31):
		for v in sch.days[d].visits:
			if v.profile in ["thunderstorm", "severe_coastal"] and sch.strikes(d, v).size() > 8:
				tv = v
				day = d
				break
		if day > 0:
			break
	if day == 0:
		return false
	w.set_override("", true)
	var peak_t: float = float(tv.start) + float(tv.durs[0]) + float(tv.durs[1]) + float(tv.durs[2]) + 15.0
	_clock(cs, day, maxf(peak_t, WorkdayClock.NIGHT_AT + 1.0))
	var c := CampLayout.world(Vector3(0, 0, 0))
	p.teleport(c + Vector3(0, 1.65, 0), c + Vector3(0, 1.0, 30.0))
	await _settle(30)
	var st: StormTerrors = Game.storm_terrors
	Game.director.last_end_t = -99999.0
	Game.director.family_cooldown.clear()
	st.forced = "sb02"
	var r := st.start("sb02")
	st.forced = ""
	if r.is_empty():
		print("walker: ", st.records.back() if not st.records.is_empty() else {})
		return false
	var a: TerrorActor = st._actors.get(r.id)
	Engine.time_scale = 2.0
	var g := 0
	while st.runs.has(r) and (r.presented as Array).is_empty() and g < 8000:
		await get_tree().process_frame
		g += 1
	Engine.time_scale = 1.0
	if not st.runs.has(r) or not is_instance_valid(a):
		return false
	# Wait for the next flash with the figure in view.
	var eye := p.global_position + Vector3(0, 1.65, 0)
	p.teleport(eye, a.global_position + Vector3(0, 1.3, 0))
	g = 0
	while w.flash < 0.35 and g < 6000:
		await get_tree().process_frame
		g += 1
		if g % 60 == 0 and is_instance_valid(a):
			p.teleport(eye, a.global_position + Vector3(0, 1.3, 0))
	return w.flash >= 0.35
