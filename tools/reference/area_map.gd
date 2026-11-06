extends Node
## Reference tooling: ASCII map around candidate sites.
## SITES="x,z;x,z" R=60 CELL=5. Per cell: '~' sea, '.' sand, ':' wet/low,
## digit = trees in the cell (forest), '-' bare ground, '^' rock.
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
	var r := float(OS.get_environment("R")) if OS.has_environment("R") else 60.0
	var cell := float(OS.get_environment("CELL")) if OS.has_environment("CELL") else 5.0
	for site in OS.get_environment("SITES").split(";"):
		var xz := site.split(",")
		var c := Vector2(float(xz[0]), float(xz[1]))
		var n := int(2.0 * r / cell)
		var counts := {}
		for i in World.tree_count():
			var tp := Vector2(World.trees.x[i], World.trees.z[i]) - c + Vector2(r, r)
			if tp.x >= 0 and tp.y >= 0 and tp.x < 2 * r and tp.y < 2 * r:
				var k := Vector2i(int(tp.x / cell), int(tp.y / cell))
				counts[k] = int(counts.get(k, 0)) + 1
		print("MAP site ", c, " (rows = +z downward, cols = +x rightward)")
		for j in n:
			var row := ""
			for i in n:
				var p := c - Vector2(r, r) + Vector2(i + 0.5, j + 0.5) * cell
				var h := World.height_at(p.x, p.y)
				var s := World.surface_at(p.x, p.y)
				var t := int(counts.get(Vector2i(i, j), 0))
				var ch := "-"
				if h < World.sea_level:
					ch = "~"
				elif t > 0:
					ch = str(mini(t, 9))
				elif s == World.Surface.SAND:
					ch = "." if h > World.sea_level + 0.6 else ":"
				elif s == World.Surface.ROCK:
					ch = "^"
				row += ch
			print("MAP ", row, "  h=%.1f" % (World.height_at(c.x, c.y + (j + 0.5) * cell - r) - World.sea_level))
	get_tree().quit()
