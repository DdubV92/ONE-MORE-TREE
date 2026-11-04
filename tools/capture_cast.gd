extends Node3D
## Phase 11: the full cast at true scale (five employees + dog), front and
## side, in the clean and the subtle-pixel character style with the same
## camera, light and pose; plus close-ups of faces, hands and the dog.
## Needs a real renderer:
##   godot res://tools/capture_cast.tscn

var cam: Camera3D
var env: EnvironmentController
var cast: Array[HumanCharacter] = []
var dog: DogCharacter


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	env = EnvironmentController.new()
	add_child(env)
	env.build()
	env.apply_named("day")
	env.set_time_of_day(15.5)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.33, 0.26)
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)
	for k in 5:
		var h := HumanCharacter.new()
		h.appearance = HumanAppearance.for_employee("EMP-0%d" % (k + 1), k)
		h.position = Vector3(-3.2 + k * 1.3, 0, 0)
		h.rotation.y = PI
		add_child(h)
		cast.append(h)
	dog = DogCharacter.new()
	dog.position = Vector3(3.6, 0, 0.3)
	dog.rotation.y = PI * 0.62
	add_child(dog)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	await _shots("clean")
	CharMeshKit.apply_style("pixel")
	await _shots("pixel")
	CharMeshKit.apply_style("clean")
	get_tree().quit()


func _snap(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://captures/cast_%s.png" % name)
	print("captured cast_", name)


func _shots(style: String) -> void:
	cam.global_position = Vector3(0.2, 1.2, 9.5)
	cam.look_at(Vector3(0.2, 0.9, 0))
	await _snap("lineup_" + style)
	cam.global_position = Vector3(-1.95, 1.62, 1.6)
	cam.look_at(Vector3(-1.95, 1.58, 0))
	await _snap("faces_" + style)
	cast[2].play("pickup", 0.0)
	cast[2].anim.seek(0.35, true)
	cam.global_position = Vector3(-0.3, 1.0, 1.7)
	cam.look_at(Vector3(-0.6, 0.65, 0))
	await _snap("hands_" + style)
	cast[2].play("idle", 0.0)
	cam.global_position = Vector3(3.6 + 1.6, 0.55, 0.3 + 0.6)
	cam.look_at(Vector3(3.6, 0.42, 0.3))
	await _snap("dog_" + style)
