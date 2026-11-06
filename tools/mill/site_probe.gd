extends Node
## Phase 24: finds clear, flat ground for the sawmill bay near the camp fence
## (trees, rocks, slope, water) on the island variant given by ISLAND.


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
	var size := Vector2(18.0, 14.0)
	var rows := []
	for cx in range(-40, 41, 2):
		for cz in range(-44, 30, 2):
			var c := Vector2(cx, cz)
			# Outside the fence (with a 1.5 m gap) and clear of the yard rect.
			var fx := CampLayout.FENCE_HALF.x + 1.5
			var fz := CampLayout.FENCE_HALF.y + 1.5
			if absf(c.x) - size.x * 0.5 < fx and absf(c.y) - size.y * 0.5 < fz:
				continue
			var yc: Vector3 = CampLayout.YARD_RECT.center
			var ys: Vector3 = CampLayout.YARD_RECT.size
			if absf(c.x - yc.x) < (size.x + ys.x) * 0.5 + 2.0 and absf(c.y - yc.z) < (size.y + ys.z) * 0.5 + 2.0:
				continue
			var trees := 0
			for i in World.tree_count():
				if World.removed_trees.has(int(World.trees.id[i])):
					continue
				var dx: float = World.trees.x[i] - (o.x + c.x)
				var dz: float = World.trees.z[i] - (o.z + c.y)
				if absf(dx) < size.x * 0.5 + 2.0 and absf(dz) < size.y * 0.5 + 2.0:
					trees += 1
			var hmin := INF
			var hmax := -INF
			var wet := false
			for sx in range(-9, 10, 3):
				for sz in range(-7, 8, 3):
					var px := o.x + c.x + sx
					var pz := o.z + c.y + sz
					var h := World.height_at(px, pz)
					hmin = minf(hmin, h)
					hmax = maxf(hmax, h)
					if World.water_depth_at(px, pz) > 0.0:
						wet = true
			if wet:
				continue
			var dist := c.length()
			rows.append({"c": [cx, cz], "trees": trees, "relief": snappedf(hmax - hmin, 0.01), "dist": snappedf(dist, 0.1)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return [a.trees, a.relief, a.dist] < [b.trees, b.relief, b.dist])
	for r in rows.slice(0, 25):
		print("SITE ", JSON.stringify(r))
	get_tree().quit()
