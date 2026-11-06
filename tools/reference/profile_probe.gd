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
	var fr := ReferenceCove.frame()
	var hdr := "PROF   z:"
	for z in range(-12, 52, 4):
		hdr += "%5d" % z
	print(hdr)
	for x in range(-4, 44, 2):
		var row := "PROF x=%3d:" % x
		for z in range(-12, 52, 4):
			var p: Vector3 = fr.o + fr.r * x + fr.f * z
			var h := World.height_at(p.x, p.z) - World.sea_level
			var s := World.surface_at(p.x, p.z)
			row += " %4.0f%s" % [h, ["g","d","S","r","f","W","w"][s]]
		print(row)
	print("PROF sea level ", World.sea_level)
	get_tree().quit()
