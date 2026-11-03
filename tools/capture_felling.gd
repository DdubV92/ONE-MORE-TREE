extends Node
## Renders the Phase 1 chop/fell sequence on a real island tree:
## viewmodel at rest / wind-up / contact, the notch, mid-fall, and settled
## trunk + stump (third-person view). Output: captures/fell_*.png

func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "logging_test"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	world.hud.visible = false
	for n in get_tree().get_nodes_in_group("post_fx"):
		n.visible = false
	await get_tree().process_frame
	var case_name := OS.get_environment("FELL_CASE") if OS.has_environment("FELL_CASE") else "neighbour"
	var i := LoggingTest.find(case_name)
	var id: int = World.trees.id[i]
	var base := World.tree_position(i)
	var stand := PlacementValidator.cut_stands(i)[0]
	var p: Player = Game.player
	p.teleport(stand + Vector3(0, 1.65, 0), base + Vector3(0, 0.95, 0))
	world.vegetation.update_collision_around(base)
	Game.environment.apply_named("day")
	for k in 20:
		await get_tree().process_frame
	_shot("fell_1_ready")
	# Wind-up and contact poses of the swing
	p.axe.view.pose_at(0.3)
	await get_tree().process_frame
	_shot("fell_2_windup")
	p.axe.view.pose_at(0.46)
	await get_tree().process_frame
	_shot("fell_3_contact")
	# Chop to ~60 % and look at the notch from the side
	while Game.trees.progress(id) < 0.6:
		Game.trees.apply_contact(id, p.global_position, p.axe.config.work_per_contact("small"))
	await get_tree().process_frame
	var cam := Camera3D.new()
	world.add_child(cam)
	var side := (stand - base).normalized()
	var perp := side.cross(Vector3.UP)
	cam.global_position = base + side * 1.4 + perp * 1.3 + Vector3(0, 1.2, 0)
	cam.look_at(base + Vector3(0, 0.75, 0))
	cam.make_current()
	for k in 6:
		await get_tree().process_frame
	_shot("fell_4_notch")
	# Finish the cut and watch the fall from further away
	var fd: Array = Game.trees.records[id].fall_dir
	var fall := Vector3(fd[0], 0, fd[1])
	cam.global_position = base - fall * 6.0 + perp * 16.0 + Vector3(0, 4.0, 0)
	cam.look_at(base + fall * 8.0 + Vector3(0, 4.0, 0))
	while Game.trees.state_of(id) == TreeService.State.NOTCHED:
		Game.trees.apply_contact(id, p.global_position, 1.0)
	var t := 0.0
	var mid_done := false
	while Game.trees.state_of(id) == TreeService.State.FALLING and t < 20.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if not mid_done and t > 2.6:
			mid_done = true
			await get_tree().process_frame
			_shot("fell_5_falling")
	for k in 10:
		await get_tree().process_frame
	_shot("fell_6_fallen")
	cam.global_position = base + side * 2.2 + perp * 0.8 + Vector3(0, 1.4, 0)
	cam.look_at(base + Vector3(0, 0.5, 0))
	for k in 6:
		await get_tree().process_frame
	_shot("fell_7_stump")
	print("settle: ", Game.trees.records[id].settle_reason)
	get_tree().quit()


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://captures/%s.png" % name)
	print("captured ", name)
