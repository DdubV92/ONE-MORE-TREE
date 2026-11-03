extends SceneTree
## Offline world generator. Usage (from the project folder):
##   godot --headless --script res://tools/generate_world.gd            # write data/world
##   godot --headless --script res://tools/generate_world.gd -- --check # verify only
##   godot --headless --script res://tools/generate_world.gd -- --map   # also write captures/island_map.png
## --check regenerates in memory and compares content hashes with the
## committed manifest. A mismatch means generation changed: bump
## WorldConfig.generation_version deliberately and regenerate.

const OUT_DIR := "res://data/world"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cfg: WorldConfig = load("res://config/world_config.tres")
	var gen := IslandGenerator.new(cfg)
	gen.generate()
	print("Generated in %d ms" % gen.stats.generation_ms)
	print(JSON.stringify(gen.stats, "  "))
	if "--check" in args:
		var mf := FileAccess.open(OUT_DIR.path_join("manifest.json"), FileAccess.READ)
		if mf == null:
			push_error("No committed manifest to check against")
			quit(2)
			return
		var manifest: Dictionary = JSON.parse_string(mf.get_as_text())
		var committed: Dictionary = manifest.content_hashes
		var fresh := gen.content_hashes()
		var ok := true
		for k in fresh:
			if committed.get(k, "") != fresh[k]:
				printerr("MISMATCH %s committed=%s regenerated=%s" % [k, committed.get(k, ""), fresh[k]])
				ok = false
		if int(manifest.generation_version) != cfg.generation_version:
			printerr("generation_version differs: manifest %s config %s" % [manifest.generation_version, cfg.generation_version])
			ok = false
		print("DETERMINISM CHECK: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
		return
	gen.write_to(ProjectSettings.globalize_path(OUT_DIR))
	print("Wrote %s" % OUT_DIR)
	if "--map" in args:
		_write_map(gen)
	quit(0)


func _write_map(gen: IslandGenerator) -> void:
	var img := Image.create(gen.W, gen.H, false, Image.FORMAT_RGB8)
	for j in gen.H:
		for i in gen.W:
			var idx := j * gen.W + i
			var h := gen.height[idx]
			var c: Color
			if gen.water_region[idx] != 0 and gen.water_surface[idx] > h:
				c = Color(0.2, 0.45, 0.9)
			elif h < 0.0:
				c = Color(0.05, 0.25 + 0.5 * clampf(1.0 + h / 6.0, 0, 1), 0.45 + 0.3 * clampf(1.0 + h / 10.0, 0, 1))
			else:
				var sand := gen.masks[idx * 4] / 255.0
				var forest := gen.masks[idx * 4 + 1] / 255.0
				var dirt := gen.masks[idx * 4 + 2] / 255.0
				var rock := gen.masks[idx * 4 + 3] / 255.0
				c = Color(0.45, 0.6, 0.3).lerp(Color(0.12, 0.3, 0.12), forest)
				c = c.lerp(Color(0.85, 0.8, 0.6), sand)
				c = c.lerp(Color(0.5, 0.45, 0.4), rock)
				c = c.lerp(Color(0.55, 0.4, 0.25), dirt)
				c = c.darkened(0.0).lightened(clampf(h / 60.0, 0.0, 0.5))
				# contour lines every 5 m
				if fmod(h, 5.0) < 0.25:
					c = c.darkened(0.25)
			img.set_pixel(i, j, c)
	var tx: PackedFloat32Array = gen.trees.x
	var tz: PackedFloat32Array = gen.trees.z
	for t in range(0, tx.size(), 3):
		var i := int((tx[t] - gen.bmin.x) / gen.cs)
		var j := int((tz[t] - gen.bmin.y) / gen.cs)
		img.set_pixel(i, j, Color(0.02, 0.12, 0.03))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	img.save_png("res://captures/island_map.png")
	print("Wrote captures/island_map.png")
