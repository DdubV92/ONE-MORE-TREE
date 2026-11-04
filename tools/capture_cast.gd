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
	if "gear" in OS.get_cmdline_user_args():
		await _gear()
		get_tree().quit()
		return
	if "motion" in OS.get_cmdline_user_args():
		await _motion()
		get_tree().quit()
		return
	await _shots("clean")
	CharMeshKit.apply_style("pixel")
	await _shots("pixel")
	CharMeshKit.apply_style("clean")
	await _motion()
	get_tree().quit()


## Phase 12: the retargeted motion-capture clips side by side (side view):
## walk and run mid-stride, upright and relaxed sitting, driving, lying.
func _motion() -> void:
	var clips := [["walk", 0.45], ["run", 0.3], ["sit", 2.0], ["sit_relaxed", 0.5], ["drive", 1.0]]
	for k in 5:
		var h := cast[k]
		h.rotation.y = -PI * 0.5      # face +X: walking across the frame
		h.play(clips[k][0], 0.0)
		h.anim.seek(float(clips[k][1]), true)
		h.playback_scale = 0.0
	cam.global_position = Vector3(0.0, 1.1, 8.0)
	cam.look_at(Vector3(0.0, 0.8, 0))
	await _snap("motion_clean")
	# Lying on the back like a worker in bed (root turned, clip body-relative).
	var h0 := cast[0]
	h0.play("lie", 0.0)
	# Body up-axis along -X, face (-Z) to the sky, like Worker.lie_down().
	h0.global_transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)), Vector3(-3.2, 0.3, 0))
	cam.global_position = Vector3(-3.2, 2.2, 2.6)
	cam.look_at(Vector3(-3.6, 0.3, 0))
	await _snap("lie_clean")


## Phase 14: gear tiers and tools on the cast, the saw up close and in
## first person.
func _gear() -> void:
	var kit := [["t1", "t1", "t1", "small", "swing"], ["t2", "t2", "t2", "chainsaw", "saw"], ["t3", "t3", "t3", "large", "swing"], ["", "", "", "medium", "idle"], ["t3", "t3", "", "chainsaw", "saw"]]
	for k in 5:
		var h := cast[k]
		h.set_gear(kit[k][0], kit[k][1], kit[k][2])
		h.set_axe_tier(kit[k][3])
		h.play(kit[k][4], 0.0)
		h.anim.seek(0.6, true)
		h.playback_scale = 0.0
	cam.global_position = Vector3(0.2, 1.25, 7.5)
	cam.look_at(Vector3(0.2, 0.95, 0))
	await _snap("gear_lineup")
	cam.global_position = Vector3(-1.6, 1.25, 2.4)
	cam.look_at(Vector3(-1.9, 1.0, 0))
	await _snap("gear_saw_worker")
	for k in 5:
		cast[k].visible = k == 1
	cam.global_position = Vector3(-1.9 + 2.6, 1.2, -0.6)
	cam.look_at(Vector3(-1.9, 0.95, -0.2))
	await _snap("gear_saw_side")
	for k in 5:
		cast[k].visible = true
	cam.global_position = Vector3(0.6, 1.7, 1.7)
	cam.look_at(Vector3(0.6, 1.5, 0))
	await _snap("gear_helmets")
	# The saw itself.
	for h in cast:
		h.visible = false
	dog.visible = false
	var saw := ChainsawModel.create(1.0)
	saw.position = Vector3(0, 1.0, 0)
	saw.rotation.y = PI * 0.62
	add_child(saw)
	cam.global_position = Vector3(0.0, 1.35, 1.1)
	cam.look_at(Vector3(0.0, 1.05, 0))
	await _snap("saw_closeup")
	saw.queue_free()
	# First person: hands on the saw.
	var vm := ViewModel.new()
	cam.add_child(vm)
	cam.fov = 75.0
	cam.global_position = Vector3(0, 1.65, 3.0)
	cam.look_at(Vector3(0, 1.0, 0))
	await get_tree().process_frame
	vm.set_gloves("t2")
	vm.equip_saw()
	for i in 6:
		vm.pose_saw(0.9, true, 0.0)
		await get_tree().process_frame
	await _snap("saw_first_person")


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
