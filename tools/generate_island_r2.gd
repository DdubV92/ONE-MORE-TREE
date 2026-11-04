extends SceneTree
## Phase 12: builds island revision 2 (new standard campaigns) from the
## frozen base world. Usage:
##   godot --headless --script res://tools/generate_island_r2.gd            # write data/world/r2
##   godot --headless --script res://tools/generate_island_r2.gd -- --check # verify only
##   godot --headless --script res://tools/generate_island_r2.gd -- --map   # also captures/island_r2_map.png
## --check regenerates in memory and compares content hashes with the
## committed r2 manifest (CI). Generation fails loudly (exit 3) if the
## planner cannot place exactly the target number of native trees.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var wd := WorldBaseData.new()
	wd.ensure_loaded()
	var gen := IslandR2.new(wd)
	gen.generate()
	print("IslandR2 generated in %d ms" % int(gen.stats.generation_ms))
	print(JSON.stringify(gen.stats, "  "))
	var count: int = (gen.trees.id as PackedInt32Array).size()
	if count != IslandR2.TREE_TARGET:
		printerr("NATIVE TREE COUNT %d != %d" % [count, IslandR2.TREE_TARGET])
		quit(3)
		return
	if "--check" in args:
		var mf := FileAccess.open(IslandR2.OUT_DIR.path_join("manifest.json"), FileAccess.READ)
		if mf == null:
			printerr("No committed r2 manifest")
			quit(2)
			return
		var committed: Dictionary = (JSON.parse_string(mf.get_as_text()) as Dictionary).content_hashes
		var fresh := gen.content_hashes()
		var ok := true
		for k in fresh:
			if committed.get(k, "") != fresh[k]:
				printerr("MISMATCH %s committed=%s regenerated=%s" % [k, committed.get(k, ""), fresh[k]])
				ok = false
		print("R2 DETERMINISM CHECK: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
		return
	gen.write_to(ProjectSettings.globalize_path(IslandR2.OUT_DIR))
	print("Wrote %s" % IslandR2.OUT_DIR)
	if "--map" in args:
		_map(gen)
	quit(0)


func _map(gen: IslandR2) -> void:
	var img := Image.create(gen.W, gen.H, false, Image.FORMAT_RGB8)
	for j in gen.H:
		for i in gen.W:
			var idx := j * gen.W + i
			var h := gen.height[idx]
			var c: Color
			if h < 0.0:
				c = Color(0.1, 0.3, 0.55)
			else:
				var forest := gen.masks[idx * 4 + 1] / 255.0
				var rock := gen.masks[idx * 4 + 3] / 255.0
				c = Color(0.5, 0.62, 0.35).lerp(Color(0.16, 0.32, 0.14), forest).lerp(Color(0.55, 0.52, 0.48), rock)
				c = c.lightened(clampf(h / 70.0, 0.0, 0.4))
				var d := gen.delta[idx]
				if absf(d) > 0.3:
					c = c.lerp(Color(0.9, 0.6, 0.2) if d > 0.0 else Color(0.3, 0.4, 0.9), 0.35)
			img.set_pixel(i, j, c)
	var put := func(p: Vector2, col: Color, r: int) -> void:
		var ci := int((p.x - gen.org.x) / gen.cs)
		var cj := int((p.y - gen.org.y) / gen.cs)
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if ci + di >= 0 and ci + di < gen.W and cj + dj >= 0 and cj + dj < gen.H:
					img.set_pixel(ci + di, cj + dj, col)
	for t in (gen.trees.x as PackedFloat32Array).size():
		put.call(Vector2(gen.trees.x[t], gen.trees.z[t]), Color(0.02, 0.1, 0.03), 0)
	for f in gen.formations:
		put.call(f.center, Color(0.85, 0.85, 0.85), 2)
	for h in gen.hides:
		put.call(h.pos, Color(1.0, 0.15, 0.15), 3)
	for t in gen.thickets:
		put.call(t.center, Color(0.6, 0.2, 0.7), 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	img.save_png("res://captures/island_r2_map.png")
	print("Wrote captures/island_r2_map.png")
