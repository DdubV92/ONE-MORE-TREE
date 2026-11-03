extends Node
## Renders crew review shots (needs a real renderer). Starts an in-memory
## crew session, poses workers at real positions, and saves PNGs to
## captures/crew_*.png.
##   godot res://tools/capture_crew.tscn

func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	for i in 6:
		await get_tree().physics_frame
	world.environment.apply_named("day")
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	cs.test_route_light_override = true
	await get_tree().process_frame
	var crew := world.crew
	var ws: Array = crew.workers.values()
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	world.add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	# 1) A worker felling a tree near camp, another walking past.
	var i := LoggingTest.find("camp_edge")
	var base := World.tree_position(i)
	var stand: Vector3 = PlacementValidator.cut_stands(i)[0]
	var w1: Worker = ws[0]
	w1.set_physics_process(false)
	w1.global_position = stand
	w1.rotation.y = atan2(-(base.x - stand.x), -(base.z - stand.z))
	w1.body_char.play("swing", 0.0)
	var w2: Worker = ws[1]
	w2.set_physics_process(false)
	w2.global_position = stand + (stand - base).normalized() * 3.0 + Vector3(2.0, 0, 0)
	w2.global_position.y = World.height_at(w2.global_position.x, w2.global_position.z)
	w2.body_char.set_locomotion(1.4)
	var eye := stand + (stand - base).normalized().rotated(Vector3.UP, 0.9) * 5.5 + Vector3(0, 1.7, 0)
	await _shot(cam, eye, w1.global_position + Vector3(0, 1.1, 0), "crew_felling", 0.4)
	await _shot(cam, eye, w1.global_position + Vector3(0, 1.1, 0), "crew_felling_b", 0.75)
	# 2) Both asleep in the extension bedroom (beds 5 and 6).
	for k in 2:
		var w: Worker = ws[k]
		w.lie_down(crew.bed_node(5 + k))
	world.environment.apply_named("night_full")
	var bed5 := crew.bed_node(5).get_parent() as Node3D
	var room_eye := bed5.global_transform * Vector3(0.9, 1.75, 2.6)
	await _shot(cam, room_eye, bed5.global_transform * Vector3(0.8, 0.5, -0.5), "crew_asleep", 0.0)
	# 3) The service dock and skiff.
	world.environment.apply_named("day")
	crew.skiff.visible = true
	crew._place_skiff(1.0)
	await _shot(cam, crew.dock_shore + Vector3(-6, 3.0, -6), crew.dock_end, "crew_dock", 0.0)
	get_tree().quit()


func _shot(cam: Camera3D, eye: Vector3, look: Vector3, name: String, swing_phase: float) -> void:
	cam.global_position = eye
	cam.look_at(look)
	for w in Game.crew.workers.values():
		var wk := w as Worker
		if wk.body_char.current == "swing":
			wk.body_char.anim.seek(1.7 * swing_phase, true)
	for k in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://captures/%s.png" % name)
	print("captured ", name)
