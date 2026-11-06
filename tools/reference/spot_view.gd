extends Node
## Renders a ring of eye-height views around SPOT=x,z (golden hour) so a
## candidate site can be judged. Output: captures/spot_<heading>.png
func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	world.build_player = false
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 4000:
		await get_tree().process_frame
		g += 1
	add_child(PostFX.new())
	var sp := OS.get_environment("SPOT").split(",")
	var p := Vector3(float(sp[0]), 0, float(sp[1]))
	var up := float(OS.get_environment("UP")) if OS.has_environment("UP") else 1.65
	p.y = World.height_at(p.x, p.z) + up
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 6000.0
	world.add_child(cam)
	cam.make_current()
	world.environment.apply_named(OS.get_environment("LIGHT") if OS.has_environment("LIGHT") else "golden")
	if world.weather:
		world.weather.set_override("clear", true)
	world.vegetation.update_collision_around(p)
	if world.ground_cover and world.ground_cover.has_method("force_build_around"):
		world.ground_cover.force_build_around(p)
	var heads := OS.get_environment("HEADS").split(",") if OS.has_environment("HEADS") else PackedStringArray(["0", "90", "180", "270"])
	for h in heads:
		var a := deg_to_rad(float(h))
		cam.global_position = p
		cam.look_at(p + Vector3(sin(a), -0.12, cos(a)))
		for i in 14:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://captures/spot_%s.png" % h)
	get_tree().quit()
