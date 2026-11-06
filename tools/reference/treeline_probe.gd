extends Node
## How far inland is the first tree, along each shore point's normal?
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
	var grid := {}
	for i in World.tree_count():
		var k := Vector2i(int(floor(World.trees.x[i] / 10.0)), int(floor(World.trees.z[i] / 10.0)))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(i)
	var camp := World.camp_origin()
	var rows := []
	var shore := World.shore_points()
	for si in range(0, shore.size(), 1):
		var s: Vector2 = shore[si]
		if s.distance_to(Vector2(camp.x, camp.z)) < 80.0:
			continue
		var best := INF
		var cnt := 0
		var k0 := Vector2i(int(floor(s.x / 10.0)), int(floor(s.y / 10.0)))
		for dz in range(-6, 7):
			for dx in range(-6, 7):
				for i in grid.get(k0 + Vector2i(dx, dz), []):
					var d := Vector2(World.trees.x[i], World.trees.z[i]).distance_to(s)
					best = minf(best, d)
					if d < 45.0:
						cnt += 1
		rows.append([best, cnt, s])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var hist := {}
	for r in rows:
		var b := int(float(r[0]) / 10.0) * 10
		hist[b] = int(hist.get(b, 0)) + 1
	print("TREELINE hist(first-tree distance m -> shore points) ", JSON.stringify(hist))
	for r in rows.slice(0, 15):
		print("TREELINE near %.1f m, %d trees<45m at %s" % [r[0], r[1], r[2]])
	get_tree().quit()
