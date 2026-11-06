extends Node
## Phase 24 reference fixture: find a coastline stretch that can host the
## owner's reference composition (flat clearing a few metres inland of a
## sand beach, dense forest behind, rocks at the waterline, open sea).

func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = OS.get_environment("ISLAND") if OS.has_environment("ISLAND") else "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	world.build_player = false
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 4000:
		await get_tree().process_frame
		g += 1
	var camp := World.camp_origin()
	var dock := CampLayout.world(Vector3(4, 0, 112))
	var rows := []
	var shore := World.shore_points()
	for si in range(0, shore.size(), 2):
		var s: Vector2 = shore[si]
		if s.distance_to(Vector2(camp.x, camp.z)) < 90.0 or s.distance_to(Vector2(dock.x, dock.z)) < 70.0:
			continue
		var hs := World.height_at(s.x, s.y)
		var n := Vector2.ZERO
		for k in 16:
			var d := Vector2.from_angle(TAU * k / 16.0)
			n += d * (World.height_at(s.x + d.x * 8.0, s.y + d.y * 8.0) - hs)
		if n.length() < 0.01:
			continue
		n = n.normalized()
		if World.water_depth_at(s.x - n.x * 10.0, s.y - n.y * 10.0) < 0.3:
			continue
		var setback := float(OS.get_environment("SETBACK")) if OS.has_environment("SETBACK") else 12.0
		var crad := float(OS.get_environment("CRAD")) if OS.has_environment("CRAD") else 6.0
		var c := s + n * setback
		var hmin := INF
		var hmax := -INF
		for k in 24:
			var d := Vector2.from_angle(TAU * k / 24.0) * (crad if k % 2 == 0 else crad * 0.5)
			var h := World.height_at(c.x + d.x, c.y + d.y)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
		if hmin < World.sea_level + 0.5 or hmax - hmin > 2.8:
			continue
		# A walkable beach (not a cliff): the clearing sits low above the sea
		# and the ground falls gently to the waterline.
		var above := (hmin + hmax) * 0.5 - World.sea_level
		if OS.has_environment("LOW_BEACH") and above > float(OS.get_environment("LOW_BEACH")):
			continue
		var sand_run := 0
		for k in range(0, int(setback) + 1):
			var q := s + n * float(k)
			if World.surface_at(q.x, q.y) == World.Surface.SAND:
				sand_run += 1
		var clear_trees := 0
		var forest := 0
		var side := Vector2(-n.y, n.x)
		for i in World.tree_count():
			var tp := Vector2(World.trees.x[i], World.trees.z[i])
			var rel := tp - c
			if rel.length() < crad + 0.5:
				clear_trees += 1
			var along := rel.dot(n)
			if along > crad + 1.0 and along < 35.0 and absf(rel.dot(side)) < 22.0:
				forest += 1
		if clear_trees > 2:
			continue
		var rocks := 0
		for r in (World.rocks.x as PackedFloat32Array).size():
			var rp := Vector2(World.rocks.x[r], World.rocks.z[r])
			if rp.distance_to(s) < 28.0:
				rocks += 1
		var sand := World.surface_at(s.x + n.x * 3.0, s.y + n.y * 3.0) == World.Surface.SAND
		var score := forest + rocks * 3 - clear_trees * 8 - int((hmax - hmin) * 6.0) + (10 if sand else 0) + sand_run * 3 - int(above * 4.0)
		rows.append({"c": [snappedf(c.x, 0.1), snappedf(c.y, 0.1)], "score": score, "s": [snappedf(s.x, 0.1), snappedf(s.y, 0.1)], "n": [snappedf(n.x, 0.01), snappedf(n.y, 0.01)], "forest": forest, "rocks": rocks, "clear_trees": clear_trees, "relief": snappedf(hmax - hmin, 0.01), "sand": sand, "sand_run": sand_run, "above": snappedf(above, 0.1)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
	for r in rows.slice(0, 12):
		print("COVE ", JSON.stringify(r))
	print("COVE candidates=%d" % rows.size())
	get_tree().quit()
