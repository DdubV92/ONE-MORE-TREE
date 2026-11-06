extends Node
## Phase 24: trees/relief in named rectangles (mill pad, truck lane) on both
## island variants.

const RECTS := {
	"mill_pad": [Vector2(-34.0, 3.0), Vector2(18.0, 14.0)],
	"lane_nw": [Vector2(-31.0, -21.0), Vector2(8.0, 8.0)],
	"lane_w": [Vector2(-29.0, -9.0), Vector2(6.0, 18.0)],
	"north_band": [Vector2(-16.0, -23.0), Vector2(20.0, 6.0)],
	"mill_full": [Vector2(-31.5, 6.0), Vector2(13.0, 22.0)],
	"mill_bay": [Vector2(-31.5, 0.5), Vector2(11.0, 9.0)],
	"lumber_yard": [Vector2(-31.5, 11.5), Vector2(13.0, 10.0)],
}


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
	for k in RECTS:
		var c: Vector2 = RECTS[k][0]
		var s: Vector2 = RECTS[k][1]
		var trees := []
		for i in World.tree_count():
			var dx: float = World.trees.x[i] - (o.x + c.x)
			var dz: float = World.trees.z[i] - (o.z + c.y)
			if absf(dx) < s.x * 0.5 + 1.0 and absf(dz) < s.y * 0.5 + 1.0:
				trees.append([snappedf(dx + c.x, 0.1), snappedf(dz + c.y, 0.1)])
		var hmin := INF
		var hmax := -INF
		var x := -s.x * 0.5
		while x <= s.x * 0.5:
			var z := -s.y * 0.5
			while z <= s.y * 0.5:
				var h := World.height_at(o.x + c.x + x, o.z + c.y + z)
				hmin = minf(hmin, h)
				hmax = maxf(hmax, h)
				z += 2.0
			x += 2.0
		print("RECT %s %s trees=%d relief=%.2f hmin=%.2f %s" % [Game.preview_variant, k, trees.size(), hmax - hmin, hmin, str(trees.slice(0, 8))])
	print("CAMP_ORIGIN_H %.2f" % World.height_at(o.x, o.z))
	get_tree().quit()
