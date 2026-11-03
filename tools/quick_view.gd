extends Node
## Dev helper: render one view of the terrain to captures/quick.png.
## godot res://tools/quick_view.tscn -- x y z tx ty tz
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	World.ensure_loaded()
	var root3 := Node3D.new()
	add_child(root3)
	var t := TerrainSystem.new()
	root3.add_child(t)
	t.build()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root3.add_child(env)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.far = 4000
	var p := Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 6 else Vector3(-175, 30, 470)
	var tg := Vector3(float(a[3]), float(a[4]), float(a[5])) if a.size() >= 6 else Vector3(-175, 5, 355)
	cam.position = p
	cam.look_at(tg)
	for i in 8:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://captures/quick.png")
	print("saved; chunks=%d collision=%d" % [t.chunk_count, t.collision_shapes])
	get_tree().quit()
