extends Node3D
## Animation audit (needs a real renderer): renders every clip of the
## human, the dog and the Foreman as rows of frames, from the side and from
## three-quarter front, with the 3D rig shown (not the pixel sprite), so a
## movement can be judged frame by frame.
##   godot res://tools/anim_sheet.tscn -- [human|dog|foreman|all] [clip ...]
## Frames go to captures/anim/<actor>__<clip>__<view>_<i>.png

const FRAMES := 8
const SIZE := Vector2i(300, 380)

var cam: Camera3D


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Settings.values.character_style = "clean"
	get_window().size = SIZE
	var env := EnvironmentController.new()
	add_child(env)
	env.build()
	env.apply_named("day")
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/preview_floor.gdshader")
	floor_mi.material_override = sm
	add_child(floor_mi)
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.02
	add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/anim"))
	var args := OS.get_cmdline_user_args()
	var who := str(args[0]) if args.size() > 0 else "all"
	var only: Array = args.slice(1) if args.size() > 1 else []
	for i in 6:
		await get_tree().process_frame
	if who in ["human", "all"]:
		await _human(only)
	if who in ["dog", "all"]:
		await _dog(only)
	if who in ["foreman", "all"]:
		await _foreman(only)
	print("ANIM_SHEET done")
	get_tree().quit()


func _views(focus: Vector3, dist: float) -> Dictionary:
	return {"side": [focus + Vector3(dist, 0.15, 0.0), focus], "front": [focus + Vector3(dist * 0.55, 0.25, -dist * 0.85), focus]}


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/anim/%s.png" % tag)


func _human(only: Array) -> void:
	var h := HumanCharacter.new()
	h.appearance = HumanAppearance.for_employee("EMP-01", 1)
	add_child(h)
	await get_tree().process_frame
	var views := _views(Vector3(0, 0.95, 0), 5.6)
	var names: Array = Array(h.anim.get_animation_list())
	names.sort()
	for n in names:
		if not only.is_empty() and not str(n) in only:
			continue
		var an: Animation = h.anim.get_animation(str(n))
		for v in views:
			cam.global_position = views[v][0]
			cam.look_at(views[v][1])
			for i in FRAMES:
				var t := an.length * float(i) / float(FRAMES if an.loop_mode != Animation.LOOP_NONE else FRAMES - 1)
				h.current = ""
				h.action = ""
				h.play(str(n), 0.0)
				h.anim.seek(minf(t, an.length - 0.001), true)
				h._process(0.0)
				h.anim.seek(minf(t, an.length - 0.001), true)
				h._process(0.0)
				await _shot("human__%s__%s_%d" % [n, v, i])
		print("SHEET human %s %.2fs loop=%d" % [n, an.length, an.loop_mode])
	h.queue_free()
	await get_tree().process_frame


func _dog(only: Array) -> void:
	var d := DogCharacter.new()
	add_child(d)
	await get_tree().process_frame
	var views := _views(Vector3(0, 0.35, 0), 3.4)
	var names: Array = Array(d.anim.get_animation_list())
	names.sort()
	for n in names:
		if not only.is_empty() and not str(n) in only:
			continue
		var an: Animation = d.anim.get_animation(str(n))
		for v in views:
			cam.global_position = views[v][0]
			cam.look_at(views[v][1])
			for i in FRAMES:
				var t := an.length * float(i) / float(FRAMES)
				d.current = ""
				d.play(str(n), 0.0)
				d.anim.seek(minf(t, an.length - 0.001), true)
				d._process(0.0)
				await _shot("dog__%s__%s_%d" % [n, v, i])
		print("SHEET dog %s %.2fs" % [n, an.length])
	d.queue_free()
	await get_tree().process_frame


func _foreman(only: Array) -> void:
	var f := ForemanBody.new()
	add_child(f)
	await get_tree().process_frame
	var views := _views(Vector3(0, 1.5, 0), 9.5)
	for pose in ["idle", "walk", "sprint", "listen", "search", "fold", "reach"]:
		if not only.is_empty() and not pose in only:
			continue
		f.pose = pose
		f.speed = 1.7 if pose == "walk" else (6.5 if pose == "sprint" else 0.0)
		for k in 40:                      # let the pose blend in
			f._process(0.05)
		for v in views:
			cam.global_position = views[v][0]
			cam.look_at(views[v][1])
			for i in FRAMES:
				f._process(0.11)
				await _shot("foreman__%s__%s_%d" % [pose, v, i])
		print("SHEET foreman %s" % pose)
	f.queue_free()
