extends Node
## Phase 24: checks the sawmill annex fence lines (camp-local polyline) for
## trees, rocks, water and relief on the island variant given by ISLAND.

const LINE := [Vector2(-22.5, 18.5), Vector2(-39.0, 18.5), Vector2(-39.0, -12.5)]


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = OS.get_environment("ISLAND") if OS.has_environment("ISLAND") else "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 4000:
		await get_tree().process_frame
		g += 1
	var o := CampLayout.origin()
	for s in LINE.size() - 1:
		var a: Vector2 = LINE[s]
		var b: Vector2 = LINE[s + 1]
		var n := int(ceil(a.distance_to(b)))
		var trees := []
		var rocks := 0
		var wet := 0
		var hmin := INF
		var hmax := -INF
		for k in n + 1:
			var p: Vector2 = a.lerp(b, float(k) / n)
			var wx := o.x + p.x
			var wz := o.z + p.y
			var h := World.height_at(wx, wz)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
			if World.water_depth_at(wx, wz) > 0.0:
				wet += 1
			for i in World.tree_count():
				if World.removed_trees.has(int(World.trees.id[i])):
					continue
				if Vector2(World.trees.x[i] - wx, World.trees.z[i] - wz).length() < 1.2:
					if not int(World.trees.id[i]) in trees:
						trees.append(int(World.trees.id[i]))
			for r in (World.rocks.x as PackedFloat32Array).size():
				if Vector2(World.rocks.x[r] - wx, World.rocks.z[r] - wz).length() < World.rock_radius(r) + 0.4:
					rocks += 1
		print("ANNEX seg %d %s->%s trees=%s rock_hits=%d wet=%d relief=%.2f (%.2f..%.2f)" % [s, a, b, trees, rocks, wet, hmax - hmin, hmin, hmax])
	# Gate corridor: inside the fence at z=-6 to the rack standpoint.
	for x in range(-23, -29, -1):
		var c := Vector3(o.x + x, 0, o.z - 6.0)
		print("GATE x=%d h=%.2f" % [x, World.height_at(c.x, c.z)])
	get_tree().quit()
