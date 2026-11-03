extends Node
## Screenshot tool: builds the world (no player/UI), visits viewpoints and
## saves PNGs to captures/. Run with a real renderer (not --headless):
##   godot res://tools/capture_views.tscn -- camp beach night:camp ...
## Each arg is [lighting:]viewpoint. Default: the Prompt 0 review set.

const DEFAULT := ["day:coast_day", "day:shallows", "day:beach", "day:river", "day:forest", "sunset:camp_sunset", "night:camper_night", "day:pond", "day:camp", "day:camper", "day:cabin"]


func _ready() -> void:
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
		var vps := Viewpoints.all()
		if not vps.has(vp_name):
			push_warning("unknown viewpoint " + vp_name)
			continue
		var vp: Dictionary = vps[vp_name]
		world.environment.apply_named(lighting)
		cam.global_position = vp.pos
		cam.look_at(vp.look)
		world.vegetation.update_collision_around(vp.pos)
		if world.ground_cover and world.ground_cover.has_method("force_build_around"):
			world.ground_cover.force_build_around(vp.pos)
		for i in 12:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var out := "res://captures/%s_%s.png" % [vp_name, lighting]
		img.save_png(out)
		print("captured ", out, " | draw calls %d, primitives %dk, objects %d, VRAM %.0f MB, tree colliders %d, physics active %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, world.vegetation.active_tree_collision_count(), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	get_tree().quit()
