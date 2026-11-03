extends Node3D
## Fast look-dev scene for the campfire: night + day shots to captures/.

func _ready() -> void:
	World.ensure_loaded()
	var env := EnvironmentController.new()
	add_child(env)
	env.build()
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.24, 0.17)
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)
	var fire := FirePit.new()
	add_child(fire)
	BuildKit.prop(self, "folding_wooden_stool", Vector3(2.8, 0, 1.5), -2.0, 1.0)
	BuildKit.prop(self, "Rockingchair_01", Vector3(-3.0, 0, 1.0), 2.2, 1.0)
	var cam := Camera3D.new()
	cam.fov = 60
	add_child(cam)
	cam.position = Vector3(0, 1.5, 4.6)
	cam.look_at(Vector3(0, 0.75, 0))
	for preset in ["night", "day"]:
		env.apply_named(preset)
		for i in 50:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://captures/fire_test_%s.png" % preset)
		print("captured fire_test_", preset)
	get_tree().quit()
