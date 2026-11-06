extends Node
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
	for vpn in ["beach", "shallows", "coast_day", "camp"]:
		var vp: Dictionary = Viewpoints.all()[vpn]
		world.ground_cover.force_build_around(vp.pos)
	var counts := {}
	for cell in world.ground_cover.get_children():
		for mmi in cell.get_children():
			if mmi is MultiMeshInstance3D:
				var k := str(mmi.name).rstrip("0123456789")
				counts[k] = int(counts.get(k, 0)) + (mmi as MultiMeshInstance3D).multimesh.instance_count
	print("PROBE ", counts)
	get_tree().quit()
