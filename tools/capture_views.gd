extends Node
## Screenshot tool: builds the world (no player/UI), visits viewpoints and
## saves PNGs to captures/. Run with a real renderer (not --headless):
##   godot res://tools/capture_views.tscn -- camp beach night:camp ...
## Each arg is [lighting:]viewpoint. Default: the Prompt 0 review set.

const DEFAULT := ["day:coast_day", "day:shallows", "day:beach", "day:river", "day:forest", "sunset:camp_sunset", "night:camper_night", "day:pond", "day:camp", "day:camper", "day:cabin"]


func _ready() -> void:
	if OS.has_environment("TERRAIN_DEBUG"):
		RenderingServer.global_shader_parameter_set("terrain_debug", int(OS.get_environment("TERRAIN_DEBUG")))
	if OS.has_environment("TONEMAP"):
		Settings.values.tonemapper = OS.get_environment("TONEMAP")
	var args := OS.get_cmdline_user_args()
	var shots: Array = DEFAULT if args.is_empty() else args
	# Phase 12: captures show the new-campaign island unless ISLAND=full.
	Game.preview_variant = OS.get_environment("ISLAND") if OS.has_environment("ISLAND") else "island_r2"
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: IslandWorld = world_scene.instantiate()
	world.build_player = false
	world.build_ui = false
	add_child(world)
	# Phase 24: the final-frame pass (HD-2D world style lives there) is part
	# of the game image; WORLD_STYLE=3d captures the old look.
	if OS.has_environment("WORLD_STYLE"):
		Settings.values.world_style = OS.get_environment("WORLD_STYLE")
	# COMPARE_OLD=1: the previous look (what F8 shows in the review build).
	Settings.compare_old = OS.has_environment("COMPARE_OLD")
	Settings.apply()
	add_child(PostFX.new())
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 6000.0
	world.add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	for s in shots:
		var parts: PackedStringArray = str(s).split(":")
		var lighting := parts[0] if parts.size() > 1 else "day"
		# Optional weather: "night+light_rain:camp" (Phase 8 preview override).
		var weather := ""
		if "+" in lighting:
			weather = lighting.get_slice("+", 1)
			lighting = lighting.get_slice("+", 0)
		var vp_name := parts[parts.size() - 1]
		# Optional "@seconds" fixes the shared world clock (wave/swash phase).
		var at := -1.0
		if "@" in vp_name:
			at = float(vp_name.get_slice("@", 1))
			vp_name = vp_name.get_slice("@", 0)
		var vps := Viewpoints.all().duplicate()
		var tv_mode := ""
		if vp_name.begins_with("tv_") and vp_name != "tv_wall":
			tv_mode = vp_name.substr(3)
			vp_name = "tv_wall"
		if vp_name == "dog_close" and Game.dog:
			for i in 30:
				await get_tree().process_frame
			Game.dog.path.clear()
			Game.dog.state = CampDog.State.SIT
			Game.dog.timer = 120.0
			var dp: Vector3 = Game.dog.global_position
			var fwd: Vector3 = -Game.dog.global_basis.z
			vps["dog_close"] = {"pos": dp + fwd * 1.5 + fwd.cross(Vector3.UP) * 0.7 + Vector3(0, 0.55, 0), "look": dp + Vector3(0, 0.4, 0)}
		var gw := 0
		while not world.systems_ready and gw < 600:
			await get_tree().process_frame
			gw += 1
		if vp_name == "tv_wall" and world.tv:
			world.tv.force_active = true
			if tv_mode in ["focus", "entertainment"]:
				world.tv.focus_index = 7
				world.tv.set_mode(tv_mode)
			else:
				world.tv.set_mode("quad")
		elif world.tv:
			world.tv.force_active = false
		if Game.tv_set:
			Game.tv_set.force_active = vp_name == "couch_tv"
			Game.tv_set.set_power(vp_name == "couch_tv")
		if vp_name.begins_with("p13_") and Game.yard and Game.yard.stock_count() == 0:
			# Phase 13 views show a working yard: in-memory stock fixture
			# plus three logs on the handcart (the capture tool never saves).
			var was := Game.mode
			Game.mode = Game.Mode.PREVIEW
			ReviewStations.yard_fixture(0.55, 9)
			if ReviewStations._hand_player(3, false) and Game.cart:
				for sid in Game.timber.carried.duplicate():
					Game.timber.transfer("player", TimberCart.CARRIER, str(sid), TimberCart.BUDGET_MTE)
				Game.cart._refresh_logs()
			Game.mode = was
			# A few logs on the fire's loading pile.
			for k in 6:
				var ys := Game.yard.take_from_deck("capture", k % Game.yard.decks.size(), 100000)
				if ys != "":
					Game.yard.load_pit("capture", ys)
			Game.yard.refresh()
		if vp_name.begins_with("p19_") and Game.offshore:
			# Phase 19: the survey ship on the camp-facing arc (and its
			# helicopter over camp), seen at player eye height.
			var off: OffshoreSurvey = Game.offshore
			off.stop_preview()
			off.preview_visit(3)
			off.enabled = false
			off.visit.state = "lap"
			off.visit.theta = off.theta_camp
			off.visit.lap = 0.4
			off._place_ship()
			var sp := off.ship_position() + Vector3(0, 9, 0)
			var shore: Vector3 = Game.crew.dock_shore if Game.crew else World.camp_origin() + Vector3(0, 0, 60)
			match vp_name:
				"p19_ship_shore":
					vps[vp_name] = {"pos": shore + Vector3(0, 1.65, 0), "look": sp}
				"p19_ship_yard":
					var y := CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(0, 0, 6))
					vps[vp_name] = {"pos": y + Vector3(0, 1.65, 0), "look": sp}
				"p19_ship_close":
					var side := off.ship_forward().cross(Vector3.UP).normalized()
					var eye := off.ship_position() + side * 170.0 - off.ship_forward() * 40.0 + Vector3(0, 6, 0)
					vps[vp_name] = {"pos": eye, "look": off.ship_position() + Vector3(0, 8, 0)}
				"p19_heli":
					off.visit.launched = true
					off.heli.set_state("fly")
					off.heli.rotor = 1.0
					off.heli.wps = off.leg_points("camp")
					off.heli.wp_i = 1
					off.heli.global_position = World.camp_origin() + Vector3(40, 62, 60)
					off.heli.yaw = PI * 0.8
					off.heli.bank = deg_to_rad(18.0)
					off.heli.global_basis = Basis.from_euler(Vector3(-0.05, off.heli.yaw, -off.heli.bank), EULER_ORDER_YXZ)
					vps[vp_name] = {"pos": CampLayout.world(Vector3(0, 0, 4)) + Vector3(0, 1.65, 0), "look": off.heli.global_position}
			for k in 3:
				await get_tree().process_frame
		# Phase 25: "lots" = the camp's forest entrance with a new campaign's
		# contract lots painted on the trees.
		if vp_name == "lots":
			if world.campaign.contract.lots == null:
				world.campaign.spawn_crew = false
				world.campaign.new_campaign()
				for k in 4:
					await get_tree().process_frame
			var cl: ContractLots = world.campaign.contract.lots
			var ti: int = world.vegetation.tree_index_by_id[int((cl.lots[0].trees as PackedInt32Array)[0])]
			var tp := World.tree_position(ti)
			var back := (cl.focus - tp)
			back.y = 0.0
			back = back.normalized() if back.length() > 0.5 else Vector3(0, 0, 1)
			var eye := tp + back * 9.0 + Vector3(0, 1.7, 0)
			eye.y = World.height_at(eye.x, eye.z) + 1.7
			vps[vp_name] = {"pos": eye, "look": tp + Vector3(0, 1.4, 0) - back * 12.0}
			print("LOTS marks: ", world.get_node("LotMarks").multimesh.visible_instance_count if world.get_node("LotMarks").multimesh else -1)
		# Phase 26: "worklamp" = a battery work lamp set down outside the
		# forest entrance; "lamplocker" = the lamp locker and the breaker.
		if vp_name == "worklamp" and Game.night_kit:
			var fo := CampLayout.world(Vector3(0.5, 0.0, -CampLayout.FENCE_HALF.y - 7.0))
			fo.y = World.height_at(fo.x, fo.z)
			if Game.night_kit.lamps.is_empty():
				Game.night_kit._spawn(fo, NightKit.BATTERY_S)
			var eye2 := CampLayout.world(Vector3(-1.5, 0.0, -CampLayout.FENCE_HALF.y + 2.5))
			eye2.y = World.height_at(eye2.x, eye2.z) + 1.7
			vps[vp_name] = {"pos": eye2, "look": fo + Vector3(0, 1.0, 0)}
		if vp_name == "lamplocker" and Game.night_kit:
			if Game.night_kit.stock == 0:
				Game.night_kit.stock = 2
				Game.night_kit.changed.emit()
			var lk := CampLayout.world((NightKit.LOCKER_POS + NightKit.BREAKER_POS) * 0.5)
			vps[vp_name] = {"pos": lk + Vector3(-1.2, 1.65, -4.6), "look": lk + Vector3(0.6, 1.1, 0)}
		if not vps.has(vp_name):
			push_warning("unknown viewpoint " + vp_name)
			continue
		var vp: Dictionary = vps[vp_name]
		if vp_name.begins_with("ref_"):
			# Reference views use the shipping character style (directional
			# pixel sprites) whatever a local settings.cfg says.
			if not Settings.compare_old:
				Settings.values.character_style = OS.get_environment("CHAR_STYLE") if OS.has_environment("CHAR_STYLE") else "hd2d"
			ReferenceCove.ensure(world).set_comparison(vp_name == "ref_match")
			# Let the actors' sprite clips bake before the shot.
			for i in 90:
				await get_tree().process_frame
				var pb := PixelBaker._inst
				if i > 20 and (pb == null or pb.pending() == 0):
					break
		world.environment.apply_named(lighting)
		if world.weather:
			world.weather.set_override(weather if weather != "" else "clear", true)
		if lighting == "night":
			world.environment.set_moon_phase(0.25)
		cam.fov = float(vp.get("fov", 70.0))
		cam.global_position = vp.pos
		cam.look_at(vp.look)
		world.vegetation.update_collision_around(vp.pos)
		if world.ground_cover and world.ground_cover.has_method("force_build_around"):
			world.ground_cover.force_build_around(vp.pos)
		for i in (40 if vp_name in ["tv_wall", "couch_tv"] or weather != "" else 12):
			if at >= 0.0:
				Game.world_time = at
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var out := "res://captures/%s_%s%s.png" % [(vp_name + ("_" + tv_mode if tv_mode != "" else "")), lighting + ("_" + weather if weather != "" else ""), ("_t%.1f" % at) if at >= 0.0 else ""]
		img.save_png(out)
		print("captured ", out, " | draw calls %d, primitives %dk, objects %d, VRAM %.0f MB, tree colliders %d, physics active %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, world.vegetation.active_tree_collision_count(), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	get_tree().quit()
