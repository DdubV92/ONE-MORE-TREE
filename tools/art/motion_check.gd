extends Node
## Motion check for the world art style (needs a real renderer): holds the
## camera still, then pans and walks, saving every frame. Used to judge
## shimmer and flicker, which stills cannot show.
##   godot --fixed-fps 20 res://tools/art/motion_check.tscn -- <view> [still_frames] [move_frames]
## COMPARE_OLD=1 records the plain 3D render for comparison.
## Frames go to captures/motion/<style>_NNN.png.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var view := str(args[0]) if args.size() > 0 else "forest"
	var still := int(args[1]) if args.size() > 1 else 12
	var move := int(args[2]) if args.size() > 2 else 48
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_player = false
	world.build_ui = false
	add_child(world)
	Settings.compare_old = OS.has_environment("COMPARE_OLD")
	Settings.apply()
	add_child(PostFX.new())
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 6000.0
	world.add_child(cam)
	cam.make_current()
	for i in 8:
		await get_tree().physics_frame
	world.environment.apply_named("day")
	var vp: Dictionary = Viewpoints.all()[view]
	var pos: Vector3 = vp.pos
	var look: Vector3 = vp.look
	cam.global_position = pos
	cam.look_at(look)
	world.vegetation.update_collision_around(pos)
	for i in 30:
		await get_tree().process_frame
	var style := "3d" if Settings.compare_old else str(Settings.get_v("world_style"))
	if OS.has_environment("TAG"):
		style = OS.get_environment("TAG")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/motion"))
	var fwd := (look - pos)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var yaw0 := cam.rotation.y
	for f in still + move:
		if f >= still:
			var k := float(f - still + 1) / float(move)
			var p := pos + fwd * 5.0 * k
			p.y = World.height_at(p.x, p.z) + 1.65
			cam.global_position = p
			cam.rotation.y = yaw0 - deg_to_rad(35.0) * k
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/motion/%s_%03d.png" % [style, f])
	print("MOTION done %s %d frames" % [style, still + move])
	get_tree().quit()
