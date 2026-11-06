extends Node
## Phase 24: log-volume survey of the frozen island (calibrates the sawmill
## pallet recipe against the $100-per-tree baseline).
##   godot --headless res://tools/mill/volume_stats.tscn


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while (Game.timber == null or not world.systems_ready) and g < 4000:
		await get_tree().process_frame
		g += 1
	var t: TimberService = Game.timber
	var vols: Array = []
	var pieces: Array = []
	var by_sp := {}
	for i in World.tree_count():
		var id := int(World.trees.id[i])
		var rec := t._build_record(id, i, {})
		var tv := 0
		for s in rec.segments:
			var l := TimberService.segment_litres(rec, int(s.k))
			tv += l
			pieces.append(l)
		vols.append(tv)
		var sp := int(rec.species)
		var e: Array = by_sp.get(sp, [0, 0])
		e[0] += tv
		e[1] += 1
		by_sp[sp] = e
	vols.sort()
	pieces.sort()
	var sum := 0
	for v in vols:
		sum += int(v)
	var n := vols.size()
	var out := {"trees": n, "mean_litres": sum / n, "p10": vols[n / 10], "p50": vols[n / 2], "p90": vols[n * 9 / 10], "max": vols[n - 1], "min": vols[0],
		"piece_p10": pieces[pieces.size() / 10], "piece_p50": pieces[pieces.size() / 2], "piece_p90": pieces[pieces.size() * 9 / 10], "pieces": pieces.size()}
	var sp_out := {}
	for sp in by_sp:
		sp_out[str(sp)] = int(by_sp[sp][0]) / maxi(int(by_sp[sp][1]), 1)
	out["mean_by_species"] = sp_out
	print("MILL_VOLUME ", JSON.stringify(out))
	get_tree().quit()
