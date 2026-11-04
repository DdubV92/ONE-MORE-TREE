extends Node
## Screenshot tool: builds the world (no player/UI), visits viewpoints and
## saves PNGs to captures/. Run with a real renderer (not --headless):
##   godot res://tools/capture_views.tscn -- camp beach night:camp ...
## Each arg is [lighting:]viewpoint. Default: the Prompt 0 review set.

const DEFAULT := ["day:coast_day", "day:shallows", "day:beach", "day:river", "day:forest", "sunset:camp_sunset", "night:camper_night", "day:pond", "day:camp", "day:camper", "day:cabin"]


func _ready() -> void:
	if OS.has_environment("TONEMAP"):
		Settings.values.tonemapper = OS.get_environment("TONEMAP")
	var args := OS.get_cmdline_user_args()
	var shots: Array = DEFAULT if args.is_empty() else args
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: IslandWorld = world_scene.instantiate()
	world.build_player = false
	world.build_ui = false
	add_child(world)
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
		if vp_name == "tv_wall" and world.tv:
			world.tv.force_active = true
			if tv_mode in ["focus", "entertainment"]:
				world.tv.focus_index = 7
				world.tv.set_mode(tv_mode)
			else:
				world.tv.set_mode("quad")
		elif world.tv:
			world.tv.force_active = false
		if not vps.has(vp_name):
			push_warning("unknown viewpoint " + vp_name)
			continue
		var vp: Dictionary = vps[vp_name]
		world.environment.apply_named(lighting)
		if lighting == "night":
			world.environment.set_moon_phase(0.25)
		cam.global_position = vp.pos
		cam.look_at(vp.look)
		world.vegetation.update_collision_around(vp.pos)
		if world.ground_cover and world.ground_cover.has_method("force_build_around"):
			world.ground_cover.force_build_around(vp.pos)
		for i in (40 if vp_name == "tv_wall" else 12):
			if at >= 0.0:
				Game.world_time = at
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var out := "res://captures/%s_%s%s.png" % [(vp_name + ("_" + tv_mode if tv_mode != "" else "")), lighting, ("_t%.1f" % at) if at >= 0.0 else ""]
		img.save_png(out)
		print("captured ", out, " | draw calls %d, primitives %dk, objects %d, VRAM %.0f MB, tree colliders %d, physics active %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, world.vegetation.active_tree_collision_count(), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	get_tree().quit()
