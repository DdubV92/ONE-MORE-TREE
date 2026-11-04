extends Node
## Headless automated checks for Phase 0 invariants. Run:
##   godot --headless res://tests/test_runner.tscn
## Exit code 0 = all passed. Each test prints PASS/FAIL with details.
## These verify data, rules and logic only. They do NOT verify shader
## compilation, visual quality, audio quality or frame rate.

var failures := 0
var passes := 0
var _log: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame
	World.ensure_loaded()
	if OS.has_environment("ONLY_P9"):
		_run("phase 9 units", _t_phase9_units)
		await _run_async("phase 9 world", _t_phase9_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P8"):
		await _run_async("phase 8 presentation", _t_phase8_presentation)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P5"):
		# Dev shortcut: just the Phase 5 checks.
		_run("save v5 -> v6 migration adds the Phase 5 block", _t_save_v6)
		_run("arcade games: score, failure, restart, high score", _t_arcade_logic)
		await _run_async("phase 5 world", _t_phase5_world)
		_run("phase 6 bank", _t_terror_bank)
		await _run_async("phase 6 world", _t_phase6_world)
		await _run_async("phase 7 world", _t_phase7_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	_run("world data matches manifest", _t_manifest)
	_run("tree count and stable unique IDs", _t_tree_ids)
	_run("trees respect exclusion zones", _t_tree_exclusions)
	_run("minimum trunk spacing", _t_spacing)
	_run("island size near target", _t_island_size)
	_run("elevation sampling matches height field", _t_elevation)
	_run("terrain continuous across chunk edges", _t_chunk_edges)
	_run("river flows downhill to the sea", _t_river)
	_run("ponds have closed rims", _t_ponds)
	_run("bridges span the river", _t_bridges)
	_run("save round trip and migration", _t_save)
	_run("preview mode never writes campaign saves", _t_preview_save)
	_run("settings sanitize and audio buses exist", _t_settings)
	_run("diagnostics strip user paths", _t_diag)
	_run("footstep cadence and loudness are natural", _t_footsteps)
	_run("axe tier rates and trait composition", _t_axe_rates)
	_run("chopping work is frame-rate independent", _t_frame_independence)
	_run("grounding audit: no floating trees or rocks", _t_grounding)
	_run("corrupt save falls back to backup without deleting", _t_save_backup)
	await _run_async("diagnostics logger captures engine errors", _t_logger)
	await _run_async("camp built: interiors, anchors, safety rules", _t_camp)
	await _run_async("human walk keeps stance foot planted", _t_human_walk)
	await _run_async("dog walk keeps stance paws planted", _t_dog_walk)
	await _run_async("tree removal by ID updates render and collision", _t_tree_removal)
	await _run_async("water and terrain surfaces face upward", _t_winding)
	await _run_async("tree lifecycle: legal states, one TreeFelled, no ghosts, save/restore", _t_tree_lifecycle)
	_run("timber shares: exact cents and quantities for every tree", _t_timber_shares)
	_run("save v2 -> current migration keeps trees, adds timber", _t_save_v3)
	await _run_async("timber ledger: buck, carry limits, one owner, receipts once, burn, recovery, reload", _t_timber_ledger)
	_run("clock: boundaries, one event each at any frame rate, bounded night, deadline once", _t_clock)
	await _run_async("clock stops while paused", _t_clock_pause)
	_run("payroll: day 7/8 arrears example, partial pay keeps due date, no duplicates", _t_payroll)
	_run("axes: ownership, affordability, receipts, rates, no softlock", _t_equipment)
	_run("save v3 -> v4: pre-contract saves flagged, wallet credits once, slots separate", _t_save_v4)
	await _run_async("contract: pay once on delivery, final-frame delivery wins, late cannot reopen, reload", _t_campaign_world)
	await _run_async("sleep: one settlement, reconciled report, morning, day 30 closes", _t_sleep_report)
	_run("crew minds: firsthand vs rumour, fear/belief separate, hysteresis, cooldowns, warning before quitting", _t_mind)
	_run("crew dialogue: 48+ original lines, no back-to-back repeats", _t_dialogue)
	_run("crew return planning: distance, load, doors, timid margin", _t_return_plan)
	await _run_async("crew: two starters once, six beds, rates, hire to five, firing keeps wages and slot until departure, reload", _t_crew_world)
	await _run_async("crew claims: worker/worker/player contest, delivery pays once, loads persist", _t_crew_claims)
	_run("save v5 -> v6 migration adds the Phase 5 block", _t_save_v6)
	_run("arcade games: score, failure, restart, high score", _t_arcade_logic)
	await _run_async("phase 5: trucks, seats, cargo once, TV rotation/focus/pool, mics, arcade pause, dog door route, refuge, couch, saves", _t_phase5_world)
	_run("phase 6 bank: 26 families, 1300 events, 312 startles, 36 Foreman patterns, valid executors", _t_terror_bank)
	await _run_async("phase 7: bridge decks for walkers and trucks, east truck route, worker stump removal, locator", _t_phase7_world)
	await _run_async("phase 8: deterministic weather + save, rain shelter/remote views, safety unchanged by weather/lightning, winding, presentation", _t_phase8_presentation)
	_run("phase 9 units: notification priority/coalescing, key rebinding swap/reset/labels, save summaries (completed/hunt/too new/legacy), help text uses live keys", _t_phase9_units)
	await _run_async("phase 9 world: guide detects real results, night-rules gate, legacy saves skip the guide, final-tree milestone once, success summary from ledger, truthful sleep/hire reasons, true pause freezes timers", _t_phase9_world)
	await _run_async("phase 6: exposure/catch arbitration, director pacing/cleanup, success never hunts, abandonment, hunt clock, Foreman rules, save v7", _t_phase6_world)
	print("\n==== %d passed, %d failed ====" % [passes, failures])
	DirAccess.make_dir_recursive_absolute("user://test_reports")
	var f := FileAccess.open("user://test_reports/last_run.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_log))
	get_tree().quit(1 if failures > 0 else 0)


func _run(name: String, f: Callable) -> void:
	var err: String = f.call()
	_report(name, err)


func _run_async(name: String, f: Callable) -> void:
	var err: String = await f.call()
	_report(name, err)


func _report(name: String, err: String) -> void:
	if err == "":
		passes += 1
		_log.append("PASS " + name)
		print("PASS  ", name)
	else:
		failures += 1
		_log.append("FAIL " + name + ": " + err)
		print("FAIL  ", name, "\n      ", err)


# ------------------------------------------------------------------ world

func _t_manifest() -> String:
	var m := World.manifest
	if m.get("fallback", false):
		return "world data missing; runtime regenerated it"
	if int(m.generation_version) != World.config.generation_version:
		return "generation_version mismatch"
	if int(m.world_seed) != World.config.world_seed:
		return "seed mismatch"
	var h := IslandGenerator._md5(World.height.to_byte_array())
	if h != m.content_hashes["heightmap.bin"]:
		return "heightmap hash differs from manifest"
	if IslandGenerator._md5(var_to_bytes(World.trees)) != m.content_hashes["trees.bin"]:
		return "tree data hash differs from manifest"
	return ""


func _t_tree_ids() -> String:
	var ids: PackedInt32Array = World.trees.id
	var n := ids.size()
	if absi(n - World.config.tree_target) > World.config.tree_target * 0.02:
		return "tree count %d far from target %d" % [n, World.config.tree_target]
	for i in n:
		if ids[i] != i:
			return "IDs not sequential/stable at %d" % i
	var chunks: PackedInt32Array = World.trees.chunk
	for i in range(1, n):
		if chunks[i] < chunks[i - 1]:
			return "records not sorted by chunk at %d" % i
	return ""


func _t_tree_exclusions() -> String:
	var cfg := World.config
	var gen := IslandGenerator.new(cfg)
	for i in World.tree_count():
		var p := Vector2(World.trees.x[i], World.trees.z[i])
		if gen.camp_sd(p) < cfg.camp_tree_clearance - 0.01:
			return "tree %d inside camp clearance" % i
		if World.water_region_at(p.x, p.y) != 0:
			return "tree %d inside inland water" % i
		if World.height_at(p.x, p.y) < 1.5:
			return "tree %d on the shoreline (h=%.2f)" % [i, World.height_at(p.x, p.y)]
		for b in World.bridges():
			if p.distance_to(Vector2(b.x, b.z)) < float(b.half_span) + 5.0:
				return "tree %d blocks bridge site" % i
	return ""


func _t_spacing() -> String:
	var cs := World.config.min_trunk_spacing - 0.01
	var hashg := {}
	for i in World.tree_count():
		var p := Vector2(World.trees.x[i], World.trees.z[i])
		var k := Vector2i(int(floor(p.x / 4.0)), int(floor(p.y / 4.0)))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for j in hashg.get(k + Vector2i(dx, dz), []):
					if p.distance_to(Vector2(World.trees.x[j], World.trees.z[j])) < cs:
						return "trees %d and %d closer than %.2f m" % [i, j, cs]
		if not hashg.has(k):
			hashg[k] = []
		hashg[k].append(i)
	return ""


func _t_island_size() -> String:
	var s: Dictionary = World.manifest.stats
	var area: float = s.land_area_km2
	if area < 0.9 or area > 1.25:
		return "land area %.3f km2 outside 0.9-1.25" % area
	var ext: Array = s.land_extent_m
	if ext[0] > 1700 or ext[1] > 1300:
		return "footprint %s exceeds ~1600x1200" % str(ext)
	return ""


func _t_elevation() -> String:
	for k in 200:
		var i := (k * 7919) % World.W
		var j := (k * 104729) % World.H
		var x := World.origin.x + i * World.cs
		var z := World.origin.y + j * World.cs
		if absf(World.height_at(x, z) - World.height[j * World.W + i]) > 0.001:
			return "height_at disagrees with grid at (%d,%d)" % [i, j]
	return ""


func _t_chunk_edges() -> String:
	var step := World.config.chunk_cells * World.cs
	var worst := 0.0
	for k in 60:
		var x := World.origin.x + (k % 30 + 1) * step
		var z := -300.0 + (k * 37) % 600
		var a := World.height_at(x - 0.001, z)
		var b := World.height_at(x + 0.001, z)
		worst = maxf(worst, absf(a - b))
	return "" if worst < 0.02 else "discontinuity %.3f m at chunk edge" % worst


func _t_river() -> String:
	var lv := World.river_levels
	for k in range(1, lv.size()):
		if lv[k] > lv[k - 1] + 0.0001:
			return "river level rises at sample %d" % k
	if lv[lv.size() - 1] > World.sea_level + 0.1:
		return "river does not reach the sea"
	# Water surface stays below its banks (no flat sea plane through valleys).
	for k in range(0, World.river_points.size(), 10):
		if lv[k] <= World.sea_level + 0.06:
			continue
		var p := World.river_points[k]
		var t0 := World.river_points[mini(k + 1, World.river_points.size() - 1)] - World.river_points[maxi(k - 1, 0)]
		var across := Vector2(-t0.y, t0.x).normalized() * (World.river_widths[k] * 0.5 + 3.0)
		for s in [-1.0, 1.0]:
			var q: Vector2 = p + across * s
			if World.height_at(q.x, q.y) < lv[k]:
				return "bank below water at sample %d" % k
	var rapids := 0
	for r in World.river_rapid:
		if r > 0.3:
			rapids += 1
	return "" if rapids > 0 else "no grade changes found for whitewater"


func _t_ponds() -> String:
	for pd in World.ponds():
		for k in 64:
			var a := TAU * k / 64.0
			var r: float = float(pd.radius) * 1.25 + 4.0
			var p := Vector2(pd.x, pd.z) + Vector2(cos(a), sin(a)) * r
			if World.height_at(p.x, p.y) < float(pd.level) + 0.02:
				return "pond at (%d,%d) leaks at angle %d" % [pd.x, pd.z, k]
	return ""


func _t_bridges() -> String:
	if World.bridges().size() < 2:
		return "expected 2 bridge sites"
	for b in World.bridges():
		if float(b.deck) < World.water_level_at(b.x, b.z) + 0.5:
			return "bridge deck too low"
	return ""


# ------------------------------------------------------------------- save

func _t_save() -> String:
	var path := "user://test_reports/test_save.json"
	var state := {"schema": SaveService.SCHEMA_VERSION, "world": {"seed": 1}, "player": {"position": [1.0, 2.0, 3.0], "yaw": 0.5}, "time_of_day": 9.5, "felled_trees": [3, 7], "economy": {"funds": 0, "axe_tier": "small", "workers": []}, "timber": {"logs": [], "burned": 0}, "horror": {"exposure": 0.0}}
	if not SaveService.write_file(path, state):
		return "write failed"
	var back := SaveService.read_file(path)
	if back.get("felled_trees") != [3.0, 7.0] and back.get("felled_trees") != [3, 7]:
		return "felled trees did not round-trip: %s" % str(back.get("felled_trees"))
	if absf(float(back.time_of_day) - 9.5) > 0.0001:
		return "time did not round-trip"
	var old := SaveService.migrate({"position": [5, 6, 7]})
	if int(old.schema) != SaveService.SCHEMA_VERSION or old.player.position != [5, 6, 7]:
		return "v0 migration failed"
	if not SaveService.migrate({"schema": 999}).is_empty():
		return "future schema was not rejected"
	return ""


func _t_preview_save() -> String:
	var prev := Game.mode
	SaveService.path_override = "user://test_reports/should_not_exist.json"
	if FileAccess.file_exists(SaveService.save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.save_path()))
	Game.mode = Game.Mode.PREVIEW
	var wrote := SaveService.save_campaign({"schema": 1})
	Game.mode = prev
	var exists := FileAccess.file_exists(SaveService.save_path())
	SaveService.path_override = ""
	if wrote or exists:
		return "preview mode wrote a campaign save"
	return ""


func _t_settings() -> String:
	var old: Dictionary = Settings.values.duplicate()
	Settings.values.mouse_sensitivity = 99.0
	Settings.values.quality = "potato"
	Settings.values.chromatic_aberration = -3.0
	Settings.sanitize()
	var ok: bool = Settings.values.mouse_sensitivity <= 1.5 and Settings.values.quality == "high" and Settings.values.chromatic_aberration == 0.0
	Settings.values = old
	if not ok:
		return "sanitize failed"
	if float(Settings.defaults.chromatic_aberration) != 0.0 or Settings.defaults.dof_mode != "off":
		return "comfort effects must default off"
	for b in Settings.BUSES:
		if AudioServer.get_bus_index(b) < 0:
			return "missing audio bus " + b
	return ""


func _t_diag() -> String:
	var s := Diag.sanitize("C:\\Users\\Dominic\\AppData\\x /home/someone/project " + OS.get_user_data_dir() + "/a.txt")
	if s.contains("Dominic") or s.contains("someone") or s.contains(OS.get_user_data_dir()):
		return "path not stripped: " + s
	var r := Diag.build_report()
	if not r.contains("Engine: Godot 4.5"):
		return "report missing engine version"
	return ""


func _t_footsteps() -> String:
	var walk := Player.step_rate(Player.WALK_SPEED, false, 0.0)
	var sprint := Player.step_rate(Player.SPRINT_SPEED, false, 0.0)
	var crouch := Player.step_rate(Player.CROUCH_SPEED, true, 0.0)
	if walk < 1.5 or walk > 2.1:
		return "walk cadence %.2f steps/s outside 1.5-2.1" % walk
	if sprint < 2.3 or sprint > 3.0:
		return "sprint cadence %.2f steps/s outside 2.3-3.0" % sprint
	if crouch >= walk:
		return "crouching should be slower than walking"
	var audio_script: GDScript = load("res://scripts/audio/ambient_audio.gd")
	var db: Dictionary = audio_script.get_script_constant_map()["STEP_DB"]
	for surf in db:
		if float(db[surf]) > -18.0:
			return "footstep level for %s too loud (%.1f dB)" % [surf, db[surf]]
		for v in 5:
			if not ResourceLoader.exists("res://audio/generated/step_%s_%d.wav" % [surf, v]):
				return "missing footstep variant %s_%d" % [surf, v]
	return ""


# ------------------------------------------------------------ scene tests

func _t_logger() -> String:
	var probe := "diagnostics-probe-%d" % Time.get_ticks_usec()
	push_error(probe)
	for i in 4:
		await get_tree().process_frame
	for e in Diag.errors:
		if e.contains(probe):
			return ""
	return "logger did not capture push_error"


func _t_camp() -> String:
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_player = false
	world.build_ui = false
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var err := ""
	var needs := {"worker_bed": 6, "worker_seat": 4, "worker_spawn": 4, "arcade_spot": 2, "player_bed": 1, "dog_bed": 1, "shop_counter": 1, "payroll_anchor": 1, "burn_pit_load_point": 1, "safe_reset": 1}
	for g in needs:
		var n := get_tree().get_nodes_in_group(g).size()
		if n != needs[g]:
			err = "group %s has %d nodes, expected %d" % [g, n, needs[g]]
	# Bridges are walkable: a downward ray at each bridge center hits the deck.
	for b in World.bridges():
		var top := Vector3(b.x, float(b.deck) + 2.0, b.z)
		var hitb := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 4.0, 0)))
		if err == "" and (hitb.is_empty() or absf(hitb.position.y - float(b.deck)) > 0.1):
			err = "no walkable deck at bridge (%d, %d)" % [b.x, b.z]
	var safety: SafetyService = world.safety
	var camper := CampLayout.world(CampLayout.CAMPER_POS + Vector3(0, CampLayout.CAMPER_FLOOR + 1.0, -3.0))
	var q := safety.query(camper)
	if err == "" and not (q.safe and q.reason == SafetyService.Reason.CAMPER_INTERIOR):
		err = "camper interior not safe"
	# Camper safety must not depend on lamps.
	for l in get_tree().get_nodes_in_group("camp_lamps"):
		l.working = false
	if err == "" and not safety.is_point_safe(camper):
		err = "camper unsafe when lamps are off"
	var yard := CampLayout.world(Vector3(0, 1.0, 1.0))
	if err == "" and safety.is_point_safe(yard):
		err = "yard safe with every lamp broken"
	for l in get_tree().get_nodes_in_group("camp_lamps"):
		l.working = true
	if err == "" and not safety.is_point_safe(yard):
		err = "yard near the central lamp not safe"
	var outside := CampLayout.world(Vector3(0, 1.0, -40.0))
	if err == "" and safety.is_point_safe(outside):
		err = "forest outside the fence counted as safe"
	# Next to the fire (bright) but far from lamps and outside: unsafe.
	var beach := Viewpoints.all()["beach"].pos as Vector3
	if err == "" and safety.is_point_safe(beach):
		err = "beach counted as safe"
	# Interiors are physically enterable: a ray through the camper doorway is clear.
	var door_out := CampLayout.world(CampLayout.CAMPER_POS + Vector3(2.4, CampLayout.CAMPER_FLOOR + 1.2, 1.85))
	var door_in := CampLayout.world(CampLayout.CAMPER_POS + Vector3(0.0, CampLayout.CAMPER_FLOOR + 1.2, 1.85))
	for d in get_tree().get_nodes_in_group("doors"):
		d.set_open(true, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(door_out, door_in))
	if err == "" and not hit.is_empty():
		err = "camper doorway blocked by %s" % str(hit.collider)
	world.queue_free()
	await get_tree().process_frame
	return err


func _t_human_walk() -> String:
	var h := HumanCharacter.new()
	add_child(h)
	await get_tree().process_frame
	h.play("walk", 0.0)
	var T := HumanCharacter.WALK_PERIOD
	var worst := 0.0
	var worst_speed := 0.0
	var prev := Vector3.ZERO
	var n := 40
	for k in n:
		var t := T * k / n
		h.anim.seek(t, true)
		var ph := fposmod(t / T, 1.0)
		var foot: Vector3 = h.bones["FootL"].global_position
		if ph > 0.05 and ph < HumanCharacter.STANCE * 0.7:
			worst = maxf(worst, absf(foot.y - h.ankle_h))
			if k > 0 and prev != Vector3.ZERO:
				var v := (foot.z - prev.z) / (T / n)
				worst_speed = maxf(worst_speed, absf(v - HumanCharacter.WALK_NOMINAL_SPEED))
			prev = foot
		else:
			prev = Vector3.ZERO
	h.queue_free()
	if worst > 0.025:
		return "stance foot height error %.3f m" % worst
	if worst_speed > 0.2:
		return "stance foot speed error %.2f m/s (stride/speed mismatch)" % worst_speed
	return ""


func _t_dog_walk() -> String:
	var d := DogCharacter.new()
	add_child(d)
	await get_tree().process_frame
	d.play("walk", 0.0)
	var T := DogCharacter.WALK_PERIOD
	var worst := 0.0
	var n := 32
	for k in n:
		var t := T * k / n
		d.anim.seek(t, true)
		# Hind-left paw: stance while phase in (0, STANCE)
		var ph := fposmod(t / T, 1.0)
		if ph > 0.05 and ph < DogCharacter.STANCE * 0.8:
			var paw: Vector3 = d.bones["HindPawL"].global_position
			worst = maxf(worst, absf(paw.y - d.paw_h))
	d.queue_free()
	return "" if worst < 0.03 else "stance paw height error %.3f m" % worst


func _t_tree_removal() -> String:
	var veg := VegetationSystem.new()
	add_child(veg)
	veg.build()
	var idx := 500
	var id: int = World.trees.id[idx]
	var p := World.tree_position(idx)
	veg.update_collision_around(p)
	await get_tree().physics_frame
	var before := veg.active_tree_collision_count()
	var chunk: int = World.trees.chunk[idx]
	var count_instances := func() -> int:
		var total := 0
		for mmi in (veg.chunk_nodes[chunk] as Node).get_children():
			if (mmi as MultiMeshInstance3D).multimesh.mesh.get_surface_count() == 1:
				total += (mmi as MultiMeshInstance3D).multimesh.instance_count
		return total
	var inst_before: int = count_instances.call()
	World.remove_tree(id)
	await get_tree().process_frame
	veg.update_collision_around(p)
	await get_tree().physics_frame
	var after := veg.active_tree_collision_count()
	var inst_after: int = count_instances.call()
	World.removed_trees.erase(id)
	veg.queue_free()
	if after != before - 1:
		return "collision count %d -> %d (expected -1)" % [before, after]
	if inst_after != inst_before - 1:
		return "far-LOD instances %d -> %d (expected -1)" % [inst_before, inst_after]
	return ""


func _t_winding() -> String:
	# Godot front faces are clockwise seen from the viewer; for an upward
	# facing triangle the right-hand cross product points down (-Y).
	var w := WaterSystem.new()
	add_child(w)
	w.build(64)
	var meshes := {"pond": w.pond_meshes[0].mesh, "river": w.river_mesh.mesh, "terrain": TerrainSystem._make_grid_mesh(4, 1, 2.0), "ocean": w.ocean.mesh}
	var err := ""
	for k in meshes:
		var arr: Array = (meshes[k] as ArrayMesh).surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var tris := 16 if k == "terrain" else idx.size() / 3
		for t in mini(tris, 400):
			var a := v[idx[t * 3]]
			var b := v[idx[t * 3 + 1]]
			var c := v[idx[t * 3 + 2]]
			var n := (b - a).cross(c - a)
			if n.length() > 1e-6 and n.y >= 0.0:
				err = "%s triangle %d faces down" % [k, t]
				break
	w.queue_free()
	await get_tree().process_frame
	return err


func _t_axe_rates() -> String:
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	var small := cfg.work_per_second("small")
	for t in [["medium", 1.4], ["large", 1.96]]:
		var r := cfg.work_per_second(t[0]) / small
		if absf(r - float(t[1])) > 0.001:
			return "%s rate %.3f, expected %.2f" % [t[0], r, t[1]]
	# A fixed target takes baseline / 1.40 and baseline / 1.96.
	var target := 40.0
	for t in [["medium", 1.4], ["large", 1.96]]:
		var ratio := (target / cfg.work_per_second("small")) / (target / cfg.work_per_second(t[0]))
		if absf(ratio - float(t[1])) > 0.001:
			return "duration ratio wrong for %s" % t[0]
	var hw := [CampaignRules.cut_rate("small", true), CampaignRules.cut_rate("medium", true), CampaignRules.cut_rate("large", true)]
	if absf(hw[0] - 1.25) > 0.001 or absf(hw[1] - 1.75) > 0.001 or absf(hw[2] - 2.45) > 0.001:
		return "hard-working rates %s, expected 1.25/1.75/2.45" % str(hw)
	if absf(cfg.work_per_second("large", true) / small - 2.45) > 0.001:
		return "config hard-working composition is not multiplicative-once"
	if absf(CampaignRules.cut_rate("medium", false) - 1.8) < 0.01:
		return "additive stacking detected"
	return ""


func _t_frame_independence() -> String:
	var counts := []
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0, 1.0 / 23.0]:
		var ax := AxeController.new()
		ax.config = load("res://config/tree_work.tres")
		ax.set("_cycle", float(ax.config.tier_cycle["small"]))
		var contacts := 0
		var t := 0.0
		while t < 30.0:
			if not ax.swinging:
				ax.begin_swing_for_test()
			if ax.advance_swing(dt):
				contacts += 1
			t += dt
		counts.append(contacts)
		ax.free()
	if counts.max() - counts.min() > 1:
		return "contacts over 30 s differ by frame step: %s" % str(counts)
	return ""


func _t_grounding() -> String:
	var r := PlacementValidator.audit_trees()
	var rr := PlacementValidator.audit_rocks()
	PlacementValidator.write_report("user://reports/placement_report.json", {"trees": r, "rocks": rr})
	var bad: int = r.floating.size() + r.in_water.size() + r.on_rock.size() + rr.floating.size()
	if bad > 0:
		return "floating/invalid: trees %d, water %d, rock overlap %d, rocks %d (first: %s)" % [r.floating.size(), r.in_water.size(), r.on_rock.size(), rr.floating.size(), JSON.stringify((r.floating + rr.floating).slice(0, 2))]
	if r.no_cut_stand.size() > 0:
		return "%d trees have no reachable cutting stand (first id %s)" % [r.no_cut_stand.size(), str(r.no_cut_stand[0].id)]
	return ""


func _t_save_backup() -> String:
	var path := "user://test_reports/backup_test.json"
	SaveService.write_file(path, {"schema": SaveService.SCHEMA_VERSION, "trees": {}, "marker": "good"})
	SaveService.write_file(path, {"schema": SaveService.SCHEMA_VERSION, "trees": {}, "marker": "newer"})
	if str(SaveService.read_file(path + ".bak").get("marker")) != "good":
		return "previous good save was not kept as .bak"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	SaveService.path_override = path
	var loaded := SaveService.load_campaign()
	SaveService.path_override = ""
	if str(loaded.get("marker")) != "good":
		return "corrupt main save did not fall back to the backup"
	if not FileAccess.file_exists(path):
		return "corrupt main save was deleted"
	if not SaveService.migrate({"schema": 99}).is_empty():
		return "unknown future schema accepted"
	var legacy := SaveService.migrate({"schema": 1, "felled_trees": [5], "player": {"position": [0, 0, 0]}})
	if not legacy.campaign.legacy or int(legacy.trees["5"].state) != TreeService.State.FALLEN:
		return "Phase 0 save not migrated to a labeled legacy campaign"
	return ""


func _t_tree_lifecycle() -> String:
	Game.mode = Game.Mode.PREVIEW
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	await get_tree().process_frame
	var err := ""
	var svc: TreeService = world.trees
	var i := LoggingTest.find("flat")
	var id: int = World.trees.id[i]
	var base := World.tree_position(i)
	var stand := PlacementValidator.cut_stands(i)[0]
	world.vegetation.update_collision_around(base)
	await get_tree().physics_frame
	var felled_signals := [0]
	svc.tree_felled.connect(func(_id: int) -> void: felled_signals[0] += 1)
	if svc._transition(id, TreeService.State.FALLEN):
		err = "illegal STANDING -> FALLEN accepted"
	svc.records.erase(id)
	svc.apply_contact(id, stand, 1.0)
	await get_tree().process_frame
	# Exactly one representation: no instance left at the base, one actor.
	var inst := 0
	for mmi in world.vegetation.chunk_nodes[int(World.trees.chunk[i])].get_children():
		var mm: MultiMesh = mmi.multimesh
		for k in mm.instance_count:
			if (mmi.global_transform * mm.get_instance_transform(k).origin).distance_to(base) < 0.05:
				inst += 1
	if err == "" and (inst != 0 or svc.actors.size() != 1):
		err = "after notch: %d instances at base, %d actors" % [inst, svc.actors.size()]
	if err == "" and svc.state_of(id) != TreeService.State.NOTCHED:
		err = "first contact did not notch"
	# Save mid-notch and restore into a fresh service.
	var notch_snapshot := svc.capture()
	while svc.state_of(id) == TreeService.State.NOTCHED:
		svc.apply_contact(id, stand, 3.0)
	var extra := svc.apply_contact(id, stand, 3.0)
	if err == "" and bool(extra.accepted):
		err = "contact accepted after felling"
	var t := 0.0
	while svc.state_of(id) == TreeService.State.FALLING and t < 25.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	# Phase 2: a settled trunk is handed to the timber ledger at once.
	if err == "" and (svc.state_of(id) != TreeService.State.SECTIONED or not world.timber.has_record(id)):
		err = "tree did not settle into the timber ledger (state %d)" % svc.state_of(id)
	if err == "" and (felled_signals[0] != 1 or svc.felled_log.count(id) != 1):
		err = "TreeFelled emitted %d times" % felled_signals[0]
	if err == "" and get_tree().get_nodes_in_group("stumps").size() != 1:
		err = "expected exactly one stump"
	# Settled pose must lie down and not sit inside the terrain.
	var pose := TreeService.array_to_xf(svc.records[id].pose)
	if err == "" and rad_to_deg(pose.basis.y.angle_to(Vector3.UP)) < 45.0:
		err = "fallen trunk still upright"
	# Restore round trip into a new service.
	var fallen_snapshot := svc.capture()
	svc.clear_all()
	await get_tree().process_frame
	if err == "" and (svc.actors.size() != 0 or World.removed_trees.has(id)):
		err = "clear_all left actors or a removed instance"
	svc.restore(notch_snapshot)
	await get_tree().process_frame
	if err == "" and (svc.state_of(id) != TreeService.State.NOTCHED or svc.actors.size() != 1 or not World.removed_trees.has(id)):
		err = "notched state not restored"
	svc.clear_all()
	await get_tree().process_frame
	svc.restore(fallen_snapshot)
	await get_tree().process_frame
	await get_tree().physics_frame
	if err == "" and (svc.state_of(id) != TreeService.State.SECTIONED or get_tree().get_nodes_in_group("stumps").size() != 1):
		err = "sectioned state/stump not restored exactly once (%d stumps)" % get_tree().get_nodes_in_group("stumps").size()
	if err == "" and felled_signals[0] != 1:
		err = "restore re-emitted TreeFelled"
	var restored_pose := TreeService.array_to_xf(svc.records[id].pose)
	if err == "" and restored_pose.origin.distance_to(pose.origin) > 0.01:
		err = "restored pose moved"
	svc.clear_all()
	world.timber.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


# ------------------------------------------------------------------ Phase 2

func _t_timber_shares() -> String:
	var eq3 := TimberService.allocate(PackedFloat64Array([1.0, 1.0, 1.0]), 10000)
	if Array(eq3) != [3333, 3333, 3334]:
		return "three equal shares gave %s" % str(eq3)
	var eq9 := TimberService.allocate(PackedFloat64Array([1, 1, 1, 1, 1, 1, 1, 1, 1]), 10000)
	var sum9 := 0
	for q in eq9:
		sum9 += q
	if sum9 != 10000 or eq9[0] != 1111 or eq9[8] != 1112:
		return "nine equal shares gave %s" % str(eq9)
	var uneq := TimberService.allocate(PackedFloat64Array([0.7, 0.2, 0.1]), 10000)
	if uneq[0] + uneq[1] + uneq[2] != 10000:
		return "unequal shares do not sum"
	# Every 37th tree on the island (covers species, sizes, variants).
	var over := 0
	for i in range(0, World.tree_count(), 37):
		var p := TimberService.partition(i)
		var m := 0
		var c := 0
		var mx := 0
		for q in p.mte:
			m += q
			mx = maxi(mx, q)
		for q in p.cents:
			c += q
		if m != TimberService.TREE_MTE or c != TimberService.TREE_CENTS:
			return "tree %d: %d mTE / %d cents" % [i, m, c]
		if int(p.n) < TimberService.MIN_SEGMENTS or int(p.n) > TimberService.MAX_SEGMENTS:
			return "tree %d: %d segments" % [i, int(p.n)]
		if mx > TimberService.HAND_BUDGET_MTE:
			over += 1
		# Deterministic: same tree, same partition.
		if JSON.stringify(TimberService.partition(i).cents) != JSON.stringify(p.cents):
			return "partition not deterministic for tree %d" % i
	if over > 0:
		return "%d sampled trees have a piece over one hand load" % over
	return ""


func _t_save_v3() -> String:
	var v2 := {"schema": 2, "trees": {"5": {"id": 5, "state": 3, "felled_committed": true, "pose": []}}, "timber": {"segments": [], "accepted_shares": []}, "campaign": {"legacy": false}}
	var m := SaveService.migrate(v2)
	if int(m.get("schema", 0)) != SaveService.SCHEMA_VERSION:
		return "v2 save not upgraded"
	if not m.trees.has("5") or int(m.trees["5"].state) != 3:
		return "tree states lost in migration"
	if not (m.timber as Dictionary).is_empty():
		return "placeholder timber block kept"
	var v1 := SaveService.migrate({"schema": 1, "felled_trees": [9], "player": {"position": [0, 0, 0]}})
	if int(v1.schema) != SaveService.SCHEMA_VERSION or not bool(v1.campaign.legacy):
		return "v1 chain migration failed"
	return ""


## Ownership invariant: each unconsumed segment has exactly one container.
func _owners_ok(t: TimberService) -> String:
	var held := {}
	for key in t.bodies:
		var b: TimberBody = t.bodies[key]
		for sid in b.sid_list():
			held[sid] = int(held.get(sid, 0)) + 1
	for sid in t.carried:
		held[sid] = int(held.get(sid, 0)) + 1
	for c in t.loads:
		for sid in t.loads[c]:
			held[sid] = int(held.get(sid, 0)) + 1
	for sid in t.queue:
		held[sid] = int(held.get(sid, 0)) + 1
	for sid in t.burning:
		held[sid] = int(held.get(sid, 0)) + 1
	for id in t.records:
		for s in t.records[id].segments:
			var n := int(held.get(str(s.sid), 0))
			var want := 0 if int(s.state) == TimberService.Seg.CONSUMED else 1
			if n != want:
				return "%s (state %s) has %d owners" % [s.sid, TimberService.Seg.keys()[int(s.state)], n]
	return ""


func _t_timber_ledger() -> String:
	Game.mode = Game.Mode.PREVIEW
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	await get_tree().process_frame
	var t: TimberService = world.timber
	var i := LoggingTest.find("camp_edge")
	var id: int = World.trees.id[i]
	var stand := PlacementValidator.cut_stands(i)[0]
	world.vegetation.update_collision_around(stand)
	await get_tree().physics_frame
	var req := float(world.trees.record(id).required)
	world.trees.apply_contact(id, stand, req + 1.0)
	var w := 0.0
	while world.trees.state_of(id) < TreeService.State.SECTIONED and w < 30.0:
		await get_tree().physics_frame
		w += 1.0 / 60.0
	var err := ""
	if not t.has_record(id):
		err = "no timber record after felling"
	var rec: Dictionary = t.records.get(id, {})
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	var work := cfg.work_per_contact("small")
	if err == "":
		err = _owners_ok(t)
	# Partial cut persists through save/load; no reset, no duplicate.
	if err == "":
		var b: TimberBody = t.bodies.values()[0]
		var k := 0   # thick butt boundary: one contact is a partial cut
		t.apply_cut(b, float(rec.segments[k].b), work)
		var partial := float(rec.bounds[k].work)
		var snap: Dictionary = JSON.parse_string(JSON.stringify(t.capture()))
		t.restore(snap)
		await get_tree().physics_frame
		rec = t.records[id]
		if absf(float(rec.bounds[k].work) - partial) > 0.001 or partial <= 0.0:
			err = "partial cut not restored (%.2f vs %.2f)" % [float(rec.bounds[k].work), partial]
		elif t.bodies.size() != 1:
			err = "restore duplicated the trunk (%d bodies)" % t.bodies.size()
	# Buck everything (crown first, then top down), waiting for settling.
	var guard := 0
	while err == "" and guard < 600:
		guard += 1
		var tb: TimberBody = null
		for key in t.bodies:
			if not (t.bodies[key] as TimberBody).is_single_piece():
				tb = t.bodies[key]
				break
		if tb == null:
			break
		var y := float(rec.merch_top) if tb.crown else float(rec.segments[tb.ks.max() - 1].b)
		var res := t.apply_cut(tb, y, work)
		if str(res.get("reason", "")) == "wait" or bool(res.get("separated", false)):
			for f in 30:
				await get_tree().physics_frame
	if err == "" and t.bodies.size() != rec.segments.size():
		err = "bucking left %d bodies for %d segments" % [t.bodies.size(), rec.segments.size()]
	for f in 240:
		await get_tree().physics_frame
	if err == "":
		err = _owners_ok(t)
	# Carry limit: baseline one-third; Stronger budget is larger; trucks unchanged.
	if err == "":
		var picked := 0
		var refused := false
		for key in t.bodies.keys():
			var res := t.pick_up(t.bodies[key], TimberService.HAND_BUDGET_MTE)
			if bool(res.ok):
				picked += 1
			else:
				refused = true
		if t.carried_mte() > TimberService.HAND_BUDGET_MTE + 2 or not refused:
			err = "hand budget not enforced (%d mTE, refused %s)" % [t.carried_mte(), str(refused)]
		var stronger := int(round(TimberService.HAND_BUDGET_MTE * CampaignRules.STRONGER_CARRY_MULTIPLIER))
		var extra := 0
		for key in t.bodies.keys():
			if bool(t.pick_up(t.bodies[key], stronger).ok):
				extra += 1
		if err == "" and (extra == 0 or t.carried_mte() > stronger + 2):
			err = "Stronger budget not applied (%d mTE)" % t.carried_mte()
		if err == "" and absf(CampaignRules.TRUCK_CAPACITY_TREE_EQUIVALENTS - 3.0) > 0.001:
			err = "truck capacity changed"
	if err == "":
		err = _owners_ok(t)
	# Save with a bundle in hand: restores once, in the hands.
	if err == "":
		var held := t.carried.duplicate()
		var data: Dictionary = JSON.parse_string(JSON.stringify(t.capture()))
		t.restore(data)
		await get_tree().physics_frame
		if t.carried != held:
			err = "carried bundle not restored exactly"
		elif _owners_ok(t) != "":
			err = "after reload: " + _owners_ok(t)
	# Acceptance creates receipts once; retries and reloads never repeat.
	if err == "":
		var rs := t.accept(t.carried.duplicate(), "rack:test")
		var n := t.receipts.size()
		t.accept(rs.map(func(r: Dictionary) -> String: return str(r.sid)), "rack:retry")
		if t.receipts.size() != n or n == 0:
			err = "retry created receipts (%d -> %d)" % [n, t.receipts.size()]
		if err == "" and (t.tree_delivered(id) or t.ash_clean()):
			err = "partial delivery reported complete"
	# Recovery: a buried piece is moved, keeps identity, never pays.
	if err == "" and not t.bodies.is_empty():
		var b: TimberBody = t.bodies.values()[0]
		var sid: String = b.sid_list()[0]
		var cents_before := int(t.totals().entitlement_cents)
		b.global_position.y -= 6.0
		if TimberRecovery.diagnose(b) != "below_terrain":
			err = "buried piece diagnosed as '%s'" % TimberRecovery.diagnose(b)
		else:
			t.run_recovery()
			await get_tree().physics_frame
			var nb := t.body_of(sid)
			if nb == null or TimberRecovery.diagnose(nb) != "" or int(t.totals().entitlement_cents) != cents_before or str(t.segment(sid).receipt) != "":
				err = "recovery changed identity or money"
	# Deliver the rest; then burning: pause stops it, overnight advance is bounded.
	if err == "":
		for key in t.bodies.keys():
			t.pick_up(t.bodies[key], 100000)
		t.accept(t.carried.duplicate(), "rack:test")
		if not t.tree_delivered(id):
			err = "full delivery not recognised"
		elif t.ash_clean():
			err = "ash reported clean before burning"
		var before := JSON.stringify(t.capture().records)
		get_tree().paused = true
		for f in 30:
			await get_tree().process_frame
		get_tree().paused = false
		if err == "" and JSON.stringify(t.capture().records) != before:
			err = "fuel burned while paused"
		t.advance_burn(TimberService.OVERNIGHT_BURN_SECONDS * 4.0)
		var r := t.reconcile(id)
		if err == "" and (not r.ok or int(r.receipt_cents) != TimberService.TREE_CENTS or int(r.by_state.get("CONSUMED", 0)) != TimberService.TREE_MTE or not t.ash_clean()):
			err = "after burning: %s" % JSON.stringify(r)
		# A consumed piece stays consumed after reload.
		var data2: Dictionary = JSON.parse_string(JSON.stringify(t.capture()))
		t.restore(data2)
		if err == "" and (t.bodies.size() != 0 or int(t.reconcile(id).by_state.get("CONSUMED", 0)) != TimberService.TREE_MTE):
			err = "consumed wood came back after reload"
	if err == "":
		err = _owners_ok(t)
	t.clear_all()
	world.trees.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


# ------------------------------------------------------------------ Phase 3

func _t_clock() -> String:
	var c := WorkdayClock.new()
	var phases := []
	var warns := []
	c.phase_changed.connect(func(p: int) -> void: phases.append(p))
	c.warning.connect(func(k: String, _l: float) -> void: warns.append(k))
	if WorkdayClock.phase_at(899.9) != WorkdayClock.Phase.DAYLIGHT or WorkdayClock.phase_at(900.0) != WorkdayClock.Phase.DUSK:
		return "daylight/dusk boundary wrong"
	if WorkdayClock.phase_at(1199.9) != WorkdayClock.Phase.DUSK or WorkdayClock.phase_at(1200.0) != WorkdayClock.Phase.NIGHT:
		return "dusk/night boundary wrong"
	# Frame-rate independence: same boundaries with very different steps.
	for step in [1.0 / 23.0, 1.0 / 60.0, 1.0 / 144.0, 7.3]:
		c.restore({"day": 3, "t": 0.0})
		phases.clear()
		warns.clear()
		var guard := 0
		while c.t < 1300.0 and guard < 200000 and c.phase() != WorkdayClock.Phase.NIGHT:
			c.advance(step)
			guard += 1
		if phases != [WorkdayClock.Phase.DUSK, WorkdayClock.Phase.NIGHT]:
			return "phase events with step %.4f: %s" % [step, str(phases)]
		if warns != ["dusk", "dusk_reminder", "dusk_final"]:
			return "warnings with step %.4f: %s" % [step, str(warns)]
	# Night is bounded and never makes morning by itself.
	c.advance(10000.0)
	if c.day != 3 or c.t != WorkdayClock.NIGHT_AT or c.night_exposure < 9999.0:
		return "night not bounded (day %d t %.1f exposure %.0f)" % [c.day, c.t, c.night_exposure]
	if absf(c.lighting_hour() - 23.6) > 0.01:
		return "night lighting not bounded"
	# Deadline: exactly once, only at the end of day 30's dusk.
	var dl := [0]
	c.deadline_reached.connect(func() -> void: dl[0] += 1)
	c.restore({"day": 29, "t": 1100.0})
	c.advance(500.0)
	if dl[0] != 0:
		return "deadline fired on day 29"
	c.restore({"day": 30, "t": 1199.9})
	c.advance(0.05)
	if dl[0] != 0:
		return "deadline fired early"
	c.advance(0.05)
	c.advance(50.0)
	if dl[0] != 1:
		return "deadline fired %d times" % dl[0]
	c.restore({"day": 30, "t": 1199.0, "deadline_enabled": false})
	c.advance(10.0)
	if dl[0] != 1:
		return "legacy run hit the deadline"
	c.free()
	return ""


func _t_clock_pause() -> String:
	var c := WorkdayClock.new()
	add_child(c)
	c.restore({"day": 1, "t": 100.0, "running": true})
	await get_tree().physics_frame
	await get_tree().physics_frame
	var t0 := c.t
	if t0 <= 100.0:
		c.queue_free()
		return "clock did not run"
	get_tree().paused = true
	for i in 10:
		await get_tree().process_frame
	var t1 := c.t
	get_tree().paused = false
	c.queue_free()
	if absf(t1 - t0) > 0.0001:
		return "clock advanced while paused (%.3f -> %.3f)" % [t0, t1]
	return ""


func _economy_fixture() -> Array:
	# Wallet + payroll + equipment with no world (pure bookkeeping).
	var cfg: EconomyConfig = load("res://config/economy.tres")
	var clock := WorkdayClock.new()
	var w := Wallet.new()
	w.setup(null, clock)
	var p := Payroll.new()
	p.setup(w, cfg)
	var e := Equipment.new()
	e.setup(w, cfg)
	return [w, p, e, clock]


func _free_all(arr: Array) -> void:
	for n in arr:
		(n as Node).free()


func _t_payroll() -> String:
	var f := _economy_fixture()
	var w: Wallet = f[0]
	var p: Payroll = f[1]
	p.employees = Payroll.starting_crew()
	# Pending (not yet arrived) employees are never charged.
	var s0 := p.settle_day(1)
	if int(s0.new_liabilities) != 0 or p.owed_total() != 0:
		_free_all(f)
		return "pending employees were charged"
	p.employees[0].status = Payroll.ACTIVE
	var quits := []
	p.quit_due_to_arrears.connect(func(id: String) -> void: quits.append(id))
	# Day 7: no cash -> $300 owed, due end of day 8.
	p.settle_day(7)
	if p.owed_for("EMP-01") != 30000 or p.due_day_for("EMP-01") != 8 or not quits.is_empty():
		_free_all(f)
		return "day 7 liability wrong (%d due %d)" % [p.owed_for("EMP-01"), p.due_day_for("EMP-01")]
	# A token partial payment does not move the due date.
	w.grant(5000, "test", "T", "token")
	p.pay_oldest()
	if p.owed_for("EMP-01") != 25000 or p.due_day_for("EMP-01") != 8:
		_free_all(f)
		return "partial payment changed the due date"
	# Day 8 with only $300: oldest wage cleared, but day 8's wage is also due
	# tonight (grace) -> exactly one quit request.
	w.grant(25000, "test", "T", "cash")
	p.settle_day(8)
	if quits != ["EMP-01"] or p.owed_for("EMP-01") != 30000:
		_free_all(f)
		return "day 8 arrears: quits %s owed %d" % [str(quits), p.owed_for("EMP-01")]
	# Repeat settlement: no duplicate liability or quit.
	var again := p.settle_day(8)
	if not bool(again.repeat) or quits.size() != 1 or p.liabilities.size() != 2:
		_free_all(f)
		return "repeated settlement duplicated records"
	if w.cash < 0:
		_free_all(f)
		return "cash went negative"
	# Full payment path: second employee active from day 10 with enough cash.
	p.employees[1].status = Payroll.ACTIVE
	w.grant(100000, "test", "T", "cash")
	p.settle_day(10)
	p.settle_day(11)
	if p.owed_for("EMP-02") != 0 or quits.size() != 1:
		_free_all(f)
		return "paid employee flagged or owed"
	_free_all(f)
	return ""


func _t_equipment() -> String:
	var f := _economy_fixture()
	var w: Wallet = f[0]
	var e: Equipment = f[2]
	e.init_new(["EMP-01", "EMP-02"])
	if e.owned_by("boss").size() != 1 or e.owned_by("EMP-01").size() != 1 or e.equipped_tier() != "small":
		_free_all(f)
		return "starting axes wrong"
	if bool(e.buy("medium").ok):
		_free_all(f)
		return "bought with no cash"
	w.grant(160000, "test", "T", "cash")
	var r := e.buy("medium")
	if not bool(r.ok) or w.cash != 10000 or not e.boss_has("medium"):
		_free_all(f)
		return "purchase wrong (cash %d)" % w.cash
	if bool(e.buy("medium").ok):
		_free_all(f)
		return "bought a duplicate"
	if not e.equip_tier("medium") or e.equipped_tier() != "medium" or w.cash != 10000:
		_free_all(f)
		return "equipping cost money or failed"
	# Axe ids are unique and each has one owner.
	var ids := {}
	for a in e.axes:
		if ids.has(a.id):
			_free_all(f)
			return "duplicate axe id"
		ids[a.id] = true
	# Restore never softlocks.
	e.restore({"axes": [], "equipped": ""})
	if not e.boss_has("small"):
		_free_all(f)
		return "small axe lost"
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	# Rates are work per second (bigger axes swing slower but bite deeper).
	if absf(cfg.work_per_second("medium") / cfg.work_per_second("small") - 1.4) > 0.001 or absf(cfg.work_per_second("large") / cfg.work_per_second("small") - 1.96) > 0.001 or absf(cfg.work_per_second("large", true) / cfg.work_per_second("large") - 1.25) > 0.001:
		_free_all(f)
		return "work rates disagree with the tiers"
	_free_all(f)
	return ""


func _t_campaign_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	await get_tree().process_frame
	var err := ""
	var seed0 = World.manifest.get("world_seed")
	var count0 := World.tree_count()
	var cs: CampaignService = world.campaign
	cs.start_test_route(true, false)
	cs.contract.scope_override = 1       # development fixture: one-tree contract
	var t: TimberService = world.timber
	var i := LoggingTest.find("small")
	var id: int = World.trees.id[i]
	var stand := PlacementValidator.cut_stands(i)[0]
	world.vegetation.update_collision_around(stand)
	await get_tree().physics_frame
	var cash0 := cs.wallet.cash
	world.trees.apply_contact(id, stand, float(world.trees.record(id).required) + 1.0)
	var w := 0.0
	while world.trees.state_of(id) < TreeService.State.SECTIONED and w < 30.0:
		await get_tree().physics_frame
		w += 1.0 / 60.0
	if cs.wallet.cash != cash0:
		err = "felling paid money"
	# Buck instantly (large work) and wait for pieces to rest.
	var guard := 0
	while err == "" and guard < 200:
		guard += 1
		var tb: TimberBody = null
		for key in t.bodies:
			if not (t.bodies[key] as TimberBody).is_single_piece():
				tb = t.bodies[key]
				break
		if tb == null:
			break
		var y := float(t.records[id].merch_top) if tb.crown else float(t.records[id].segments[tb.ks.max() - 1].b)
		var res := t.apply_cut(tb, y, 100.0)
		if str(res.get("reason", "")) == "wait" or bool(res.get("separated", false)):
			for k in 20:
				await get_tree().physics_frame
	for k in 120:
		await get_tree().physics_frame
	# Deliver all but one piece: credited exactly once each, immediately.
	var sids: Array = []
	for key in t.bodies.keys():
		var r := t.pick_up(t.bodies[key], 100000)
		if bool(r.ok):
			sids.append(r.sid)
	var last: String = sids.pop_back()
	t.accept(sids, "rack:test")
	var paid := cs.wallet.cash - cash0
	var expect := 0
	for sid in sids:
		expect += int(t.segment(sid).cents)
	if err == "" and paid != expect:
		err = "credited %d, expected %d" % [paid, expect]
	t.accept(sids, "rack:retry")
	cs.wallet.reconcile_receipts()
	if err == "" and cs.wallet.cash - cash0 != expect:
		err = "receipts paid twice"
	# Stump removal is required.
	world.trees.apply_stump_work(id, 1000.0)
	if err == "" and world.trees.state_of(id) != TreeService.State.DISPOSED:
		err = "stump not removed"
	# Save/load round trip (in memory) keeps money, clock and ownership.
	cs.clock.restore({"day": 30, "t": 1199.99, "running": true})
	var snap: Dictionary = JSON.parse_string(JSON.stringify(SaveService.capture_state(world)))
	if err == "" and int(snap.economy.wallet.cash) != cs.wallet.cash:
		err = "save missed the wallet"
	# Final frame: the deadline is reached and, in the same frame, the last
	# piece is accepted (timestamped at the deadline) -> success.
	cs.clock.advance(0.05)
	t.accept([last], "rack:test")
	await get_tree().process_frame
	await get_tree().process_frame
	if err == "" and cs.contract.state != ContractService.FULFILLED:
		err = "on-time final delivery did not fulfil (%s, %s)" % [cs.contract.state, JSON.stringify(cs.contract.counts())]
	var oid := cs.contract.outcome_id
	# Fuel still burning does not undo success.
	if err == "" and (t.ash_clean() or cs.contract.state != ContractService.FULFILLED):
		err = "burning backlog affected the outcome"
	# Late transaction cannot reopen a closed contract.
	if err == "" and not t.accept([last], "late").is_empty():
		err = "closed contract accepted a delivery"
	# Reload the pre-deadline snapshot, let the deadline pass WITHOUT the
	# last delivery -> abandonment; a late delivery cannot turn it around.
	SaveService.apply_state(world, snap)
	cs.contract.scope_override = 1
	await get_tree().process_frame
	cs.clock.advance(0.05)
	await get_tree().process_frame
	await get_tree().process_frame
	if err == "" and cs.contract.state != ContractService.ABANDONMENT:
		err = "missed deadline did not end the contract (%s)" % cs.contract.state
	var late := t.accept([last], "late")
	if err == "" and (not late.is_empty() or cs.contract.state != ContractService.ABANDONMENT):
		err = "late delivery changed the outcome"
	if err == "" and oid == cs.contract.outcome_id:
		err = "outcome ids not distinct per outcome"
	# Preview tools never change the world identity.
	if err == "" and (World.manifest.get("world_seed") != seed0 or World.tree_count() != count0):
		err = "seed/tree count changed"
	t.clear_all()
	world.trees.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


func _t_sleep_report() -> String:
	Game.mode = Game.Mode.PREVIEW
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	await get_tree().process_frame
	var err := ""
	var cs: CampaignService = world.campaign
	cs.start_test_route(true, false)
	cs.wallet.grant(10000, "test", "T", "extra")
	cs.clock.restore({"day": 4, "t": 1000.0, "running": true})
	cs._begin_day_stats()
	var cash0 := cs.wallet.cash
	if bool(cs.can_sleep().ok) == false:
		err = "cannot sleep at dusk"
	var r := cs.sleep()
	var rep: Dictionary = r.get("report", {})
	if err == "" and (cs.clock.day != 5 or cs.clock.t != 0.0):
		err = "morning not reached (day %d)" % cs.clock.day
	if err == "" and not bool(rep.get("reconciles", false)):
		err = "report does not reconcile: %s" % JSON.stringify(rep)
	if err == "" and (int(rep.opening_cash) != cash0 or int(rep.wages_paid) != 60000 or int(rep.closing_cash) != cash0 - 60000):
		err = "report cash wrong: %s" % JSON.stringify(rep)
	# Sleeping again in daylight is refused; the report is reopenable without
	# re-settling.
	var again := cs.sleep()
	if err == "" and bool(again.get("ok", false)):
		err = "slept twice"
	if err == "" and (cs.reports.size() != 1 or cs.payroll.settle_day(4).repeat != true):
		err = "settlement repeated"
	# Day 30: sleeping routes to the outcome instead of a day 31.
	cs.clock.restore({"day": 30, "t": 1000.0, "running": true})
	var fin := cs.sleep()
	await get_tree().process_frame
	if err == "" and (not bool(fin.get("terminal", false)) or cs.clock.day != 30 or not cs.contract.is_closed()):
		err = "day 30 sleep did not close the contract"
	world.timber.clear_all()
	world.trees.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


func _t_save_v4() -> String:
	# v3 (Phase 2) save with an accepted receipt that was never paid.
	var v3 := {"schema": 3, "trees": {}, "timber": {"receipts": [{"id": "RCPT-000001", "sid": "T5_S0", "tree": 5, "mte": 300, "cents": 3000, "settled": false}]}, "campaign": {"rule_set": "contract_v1", "state": "CONTRACT_ACTIVE", "day": 1, "clock_running": false, "legacy": false}, "economy": {"funds_cents": 0, "ledger": [], "workers": [], "trucks": []}}
	var m := SaveService.migrate(v3)
	if int(m.schema) != SaveService.SCHEMA_VERSION:
		return "v3 not upgraded"
	if bool(m.campaign.get("phase3", false)):
		return "pre-contract save marked as contract save"
	if not (m.economy as Dictionary).has("wallet") or int(m.economy.wallet.cash) != 0:
		return "economy block not normalised"
	# Wallet credit idempotence on a receipt list.
	var f := _economy_fixture()
	var w: Wallet = f[0]
	w.credited["RCPT-000009"] = "TX-000001"
	if w.credit_receipt("RCPT-000009") != "TX-000001" or w.cash != 0:
		_free_all(f)
		return "credited receipt paid again"
	_free_all(f)
	# Slots: separate files, new game in one slot never touches another.
	var a := SaveService.slot_path(1)
	var b := SaveService.slot_path(2)
	if a == b or not a.begins_with("user://saves/"):
		return "slot paths not separate"
	return ""


# ------------------------------------------------------------------ Phase 4

func _t_mind() -> String:
	# Firsthand vs rumour; fear and belief separate; hysteresis; cooldowns.
	var sk := WorkerMind.with_traits(["skeptical"])
	if sk.hear_boss_report(10.0, false) != "rumor" or sk.belief > 0.15 or sk.firsthand_count() != 0:
		return "skeptic believed an unsupported report"
	var stim := {"id": "S1", "kind": "figure", "modality": "sight", "pos": Vector3.ZERO, "severity": 0.6, "ambiguous": false}
	var mem := sk.perceive(stim, 20.0, {"confidence": 0.9})
	if mem.is_empty() or not bool(mem.firsthand) or str(mem.status) != "confirmed" or sk.belief < 0.25:
		return "firsthand sight did not change belief (%s, %.2f)" % [str(mem), sk.belief]
	if not sk.perceive(stim, 21.0, {"confidence": 0.9}).is_empty():
		return "same event stored twice"
	# Ordinary sounds never become evidence.
	if not sk.perceive({"id": "S2", "kind": "axe", "modality": "sound", "pos": Vector3.ZERO, "severity": 0.5, "ordinary": true}, 22.0, {"confidence": 0.7}).is_empty():
		return "ordinary work sound became evidence"
	# Diminishing repeats: the same kind of event hits less each time.
	var t := WorkerMind.with_traits(["timid"])
	var gains := []
	for i in 4:
		var f0 := t.fear
		t.perceive({"id": "H%d" % i, "kind": "howl", "modality": "sound", "pos": Vector3.ZERO, "severity": 0.2, "ambiguous": true}, 100.0 + i, {"confidence": 0.6})
		gains.append(t.fear - f0)
	if not (gains[1] < gains[0] and gains[2] < gains[1]):
		return "repeats not diminishing: %s" % str(gains)
	# Timid reacts more than level-headed to the same thing.
	var a := WorkerMind.with_traits(["timid"])
	var b := WorkerMind.with_traits(["level_headed"])
	a.perceive(stim, 5.0, {"confidence": 0.9})
	b.perceive(stim, 5.0, {"confidence": 0.9})
	if a.fear <= b.fear * 2.0:
		return "timid (%.2f) vs level-headed (%.2f) not distinct" % [a.fear, b.fear]
	# Hysteresis: hovering just under the enter threshold does not flip states.
	var h := WorkerMind.with_traits([])
	h.fear = 0.26
	h._update_state(0.0)
	h.fear = 0.2
	h._update_state(0.0)
	if h.state != WorkerMind.Fear.UNEASY:
		return "no hysteresis (state %d)" % h.state
	h.fear = 0.1
	h._update_state(0.0)
	if h.state != WorkerMind.Fear.COMFORTABLE:
		return "did not recover"
	# Reassurance: cooldown and diminishing returns.
	var r := WorkerMind.with_traits([])
	r.fear = 0.6
	r.reassure(1000.0, true)
	var after1 := r.fear
	if r.reassure(1010.0, true) != "cooldown" or r.fear != after1:
		return "reassurance spam not blocked"
	r.reassure(1200.0, true)
	if (0.6 - after1) <= (after1 - r.fear):
		return "reassurance not diminishing"
	# Belief and fear are separate: high belief can sit with low fear.
	var calm := WorkerMind.with_traits(["level_headed"])
	calm.perceive(stim, 1.0, {"confidence": 0.9})
	calm.fear = 0.0
	calm._update_state(2.0)
	if calm.belief < 0.25 or calm.state != WorkerMind.Fear.COMFORTABLE:
		return "belief and fear coupled"
	# Warning first, quitting only after it persists past a night.
	var q := WorkerMind.with_traits(["timid"])
	q.fear = 0.9
	q._update_state(0.0)
	if q.state != WorkerMind.Fear.DEPARTURE_WARNING or q.end_of_day(5):
		return "quit without a warning period"
	if not q.end_of_day(6) or q.state != WorkerMind.Fear.QUITTING:
		return "persistent warning did not lead to quitting"
	# Save round trip.
	var rt := WorkerMind.from_dict(JSON.parse_string(JSON.stringify(sk.capture())))
	if absf(rt.belief - sk.belief) > 0.001 or rt.memories.size() != sk.memories.size():
		return "mind did not round-trip"
	return ""


func _t_dialogue() -> String:
	if CrewDialogue.line_count() < 48:
		return "only %d lines" % CrewDialogue.line_count()
	var last := {}
	var a := CrewDialogue.line("dusk_return", [], last)
	var b := CrewDialogue.line("dusk_return", [], last)
	if a == b:
		return "repeated the same line twice in a row"
	var v := CrewDialogue.line("wages_owed", [], {}, {"owed": "300.00", "due": 8})
	if not "300.00" in v or not "8" in v:
		return "variables not filled: " + v
	return ""


func _t_return_plan() -> String:
	var near := CrewService.return_estimate(40.0, false)
	var far := CrewService.return_estimate(400.0, false)
	var loaded := CrewService.return_estimate(400.0, true)
	if not (far > near and loaded > far):
		return "estimate ignores distance or load (%.0f %.0f %.0f)" % [near, far, loaded]
	if near < 12.0:
		return "estimate ignores doors"
	var timid := WorkerMind.with_traits(["timid"])
	var steady := WorkerMind.with_traits([])
	if timid.return_margin() <= steady.return_margin():
		return "timid workers do not leave earlier"
	return ""


func _t_crew_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	for i in 4:
		await get_tree().physics_frame
	var err := ""
	var cs: CampaignService = world.campaign
	var crew: CrewService = world.crew
	if not crew.world_ready:
		err = "crew navigation not built"
	cs.start_test_route(false)
	await get_tree().physics_frame
	# Exactly two starters, activated once; re-running migration adds nobody.
	if err == "" and (crew.workers.size() != 2 or cs.payroll.employees.size() != 2):
		err = "expected 2 starting workers, got %d" % crew.workers.size()
	if err == "" and crew.migrate_pending() != 0:
		err = "migration re-activated starters"
	# Six beds, unique assignments, never the boss's or dog's bed.
	var idx := {}
	for m in get_tree().get_nodes_in_group("worker_bed"):
		idx[int(m.get_meta("bed_index", 0))] = true
	if err == "" and idx.keys().size() != 6:
		err = "worker beds: %s" % str(idx.keys())
	var beds := {}
	for e in cs.payroll.employees:
		if beds.has(int(e.bed)) or int(e.bed) <= 0:
			err = "bed assignment not unique: %s" % str(e.bed)
		beds[int(e.bed)] = true
	# Workers spawned on walkable ground with their own small axes.
	for w in crew.workers.values():
		var wk := w as Worker
		if err == "" and (not crew.nav.walkable(wk.global_position) and not crew.nav.in_camp(wk.global_position)):
			err = "worker spawned off the walkable map"
		if err == "" and wk.axe_tier() != "small":
			err = "worker without their small axe"
	# Axe ownership: every axe has exactly one owner, nobody shares the boss's.
	var owners := {}
	for a in cs.equipment.axes:
		if owners.has(a.id):
			err = "axe owned twice"
		owners[a.id] = a.owner
	# Rates: Hard-working applied once; Stronger carries 1.5x.
	var hw: Worker = crew.workers["EMP-01"]
	var st: Worker = crew.workers["EMP-02"]
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	if err == "" and absf(crew.work_per_contact(hw) - cfg.work_per_contact("small", true)) > 0.0001:
		err = "hard-working rate wrong"
	if err == "" and absf(crew.work_per_contact(st) - cfg.work_per_contact("small", false)) > 0.0001:
		err = "plain rate wrong"
	if err == "" and (crew.carry_budget(st) != 500 or crew.carry_budget(hw) != 333):
		err = "carry budgets %d / %d" % [crew.carry_budget(st), crew.carry_budget(hw)]
	# Hiring: fee once, five maximum (pending arrivals count), no id reuse.
	cs.wallet.grant(10000000, "test", "T", "cash")
	crew.refresh_candidates()
	var cash0 := cs.wallet.cash
	for i in 3:
		var r := crew.hire(crew.candidates[0].cid)
		if err == "" and not bool(r.ok):
			err = "hire %d refused: %s" % [i, r.reason]
	if err == "" and cash0 - cs.wallet.cash != 3 * crew.econ.hire_fee_cents:
		err = "hire fees wrong"
	if err == "" and bool(crew.can_hire().ok):
		err = "a sixth employee could be hired"
	# Firing keeps the slot until the person has actually left.
	var e1 := cs.payroll.employee("EMP-01")
	(e1.worked_days as Array).append(cs.clock.day)
	crew.fire("EMP-01")
	if err == "" and (str(e1.status) != "departing" or bool(crew.can_hire().ok)):
		err = "fired worker freed the slot before leaving"
	var hw_axe := 0
	for a in cs.equipment.owned_by("EMP-01"):
		hw_axe += 1
	if err == "" and hw_axe != 0:
		err = "fired worker kept the company axe"
	crew._finish_departure(e1)
	if err == "" and (not bool(crew.can_hire().ok) or crew.workers.has("EMP-01")):
		err = "slot not freed after departure"
	var r6 := crew.hire(crew.candidates[0].cid)
	if err == "" and (not bool(r6.ok) or str(r6.id) == "EMP-01"):
		err = "replacement reused an old identity"
	# Wages for the day the fired worker worked are still owed tonight.
	var s := cs.payroll.settle_day(cs.clock.day)
	if err == "" and cs.payroll.liabilities.filter(func(l: Dictionary) -> bool: return str(l.emp) == "EMP-01").is_empty():
		err = "fired worker's worked day was erased"
	# Exclusive task claims.
	var other: Worker = crew.workers["EMP-02"]
	if err == "" and (not crew.claim("tree:1", other) or crew.claims.get("tree:1") != "EMP-02"):
		err = "task claim failed"
	crew.claims["tree:2"] = "EMP-09"
	if err == "" and crew.claim("tree:2", other):
		err = "claimed a tree someone else holds"
	# Save/load: no duplicate people.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(crew.capture()))
	var n0 := crew.workers.size()
	crew.restore(snap)
	await get_tree().physics_frame
	if err == "" and crew.workers.size() != n0:
		err = "reload changed the crew size (%d -> %d)" % [n0, crew.workers.size()]
	# Navigation: from the rack out through a gate to the forest and back to a bed.
	var rack := CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(0, 0, 2))
	var forest := World.camp_origin() + Vector3(10, 0, -60)
	var p := crew.nav.find_path(rack, forest)
	if err == "" and p.is_empty():
		err = "no path from the rack to the forest"
	var bed := crew.bed_approach(crew.workers.values()[0])
	if err == "" and crew.nav.find_path(forest, bed).is_empty():
		err = "no path from the forest to a cabin bed"
	for q in p:
		if err == "" and crew.nav.in_camp(q):
			var f := crew.nav._fine(Vector2(q.x, q.z))
			if crew.nav.camp_grid.is_point_solid(f) and q != p[0]:
				err = "path crosses a solid camp cell"
	world.timber.clear_all()
	world.trees.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


func _t_crew_claims() -> String:
	# Worker vs worker vs player contest on one log, through the real API.
	Game.mode = Game.Mode.PREVIEW
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	for i in 4:
		await get_tree().physics_frame
	var err := ""
	var t: TimberService = world.timber
	var i := LoggingTest.find("small")
	var id: int = World.trees.id[i]
	var stand := PlacementValidator.cut_stands(i)[0]
	world.trees.apply_contact(id, stand, float(world.trees.record(id).required) + 1.0)
	var w := 0.0
	while world.trees.state_of(id) < TreeService.State.SECTIONED and w < 30.0:
		await get_tree().physics_frame
		w += 1.0 / 60.0
	var guard := 0
	while guard < 100:
		guard += 1
		var tb: TimberBody = null
		for key in t.bodies:
			if not (t.bodies[key] as TimberBody).is_single_piece():
				tb = t.bodies[key]
		if tb == null:
			break
		var y := float(t.records[id].merch_top) if tb.crown else float(t.records[id].segments[tb.ks.max() - 1].b)
		t.apply_cut(tb, y, 100.0)
		for f in 20:
			await get_tree().physics_frame
	for f in 120:
		await get_tree().physics_frame
	var b: TimberBody = t.bodies.values()[0]
	var sid: String = b.sid_list()[0]
	if not t.claim(sid, "EMP-01"):
		err = "first claim failed"
	if err == "" and bool(t.pick_up(b).ok):
		err = "player took a piece a worker claimed"
	if err == "" and bool(t.pick_up_for("EMP-02", b, 500).ok):
		err = "second worker took a claimed piece"
	var r := t.pick_up_for("EMP-01", b, 333)
	if err == "" and not bool(r.ok):
		err = "claimant could not pick up: %s" % str(r)
	if err == "" and (t.load_of("EMP-01").size() != 1 or t.body_of(sid) != null):
		err = "worker load not exclusive"
	# Worker delivery pays the existing share once.
	var c0 := world.campaign.wallet.cash
	world.campaign.wallet.enabled = true
	var rs := t.accept(t.load_of("EMP-01").duplicate(), "rack:EMP-01")
	t.accept([sid], "rack:EMP-01")
	if err == "" and (rs.size() != 1 or world.campaign.wallet.cash - c0 != int(t.segment(sid).cents)):
		err = "worker delivery paid %d (expected %d once)" % [world.campaign.wallet.cash - c0, int(t.segment(sid).cents)]
	# Worker loads survive a save/load exactly once.
	var b2: TimberBody = null
	for key in t.bodies:
		b2 = t.bodies[key]
	if b2:
		t.pick_up_for("EMP-02", b2, 500)
		var data: Dictionary = JSON.parse_string(JSON.stringify(t.capture()))
		t.restore(data)
		if err == "" and t.load_of("EMP-02").size() != 1:
			err = "worker load lost or duplicated on reload"
	t.clear_all()
	world.trees.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


# ----------------------------------------------------------------- phase 5

func _t_save_v6() -> String:
	var d := SaveService.migrate({"schema": 5, "player": {"position": [0, 0, 0]}, "campaign": {}, "economy": {}})
	if int(d.get("schema", 0)) != SaveService.SCHEMA_VERSION or SaveService.SCHEMA_VERSION < 6:
		return "schema not 6 after migration"
	if not d.has("phase5"):
		return "phase5 block missing"
	return ""


func _t_arcade_logic() -> String:
	var ls := LogStacker.new()
	ls.size = Vector2(900, 620)
	add_child(ls)
	ls.start()
	# Perfect drop on top of the base log scores 2.
	ls.cur_x = ls.stack[0].x
	ls._press(KEY_SPACE)
	if ls.score != 2 or ls.stack.size() != 2:
		ls.queue_free()
		return "perfect drop scored %d" % ls.score
	# Overhang is sawn off: width shrinks, not grows.
	ls.cur_x = ls.stack[1].x + 60.0
	var w0: float = ls.cur_w
	ls._press(KEY_SPACE)
	if ls.cur_w >= w0 or ls.falling.is_empty():
		ls.queue_free()
		return "overhang not cut"
	# Complete miss ends the game; high score kept; restart resets score.
	ls.cur_x = 2000.0
	ls._press(KEY_SPACE)
	if ls.state != "over" or ls.high != 3:
		ls.queue_free()
		return "miss did not end game (state %s high %d)" % [ls.state, ls.high]
	ls.start()
	if ls.score != 0 or ls.state != "play" or ls.high != 3:
		ls.queue_free()
		return "restart wrong"
	ls.queue_free()
	var ff := FlapjackFlip.new()
	ff.size = Vector2(900, 620)
	add_child(ff)
	ff.start()
	for p in ff.pans:
		p.phase = "cook"
	ff.pans[0].cook = 0.675
	ff._press(KEY_1)
	if ff.score != 2:
		ff.queue_free()
		return "perfect flip scored %d" % ff.score
	ff.pans[1].cook = 0.2
	ff._press(KEY_2)
	ff.pans[2].cook = 0.95
	ff._press(KEY_3)
	ff.pans[0].phase = "cook"
	ff.pans[0].cook = 1.5
	ff._tick(0.01)
	if ff.state != "over" or ff.strikes != 3 or ff.high != 2:
		ff.queue_free()
		return "three strikes did not end the game (%s, %d)" % [ff.state, ff.strikes]
	ff.queue_free()
	return ""


func _t_phase5_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while not world.systems_ready and guard < 600:
		await get_tree().physics_frame
		guard += 1
	var err := ""
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	await get_tree().physics_frame
	var vs: VehicleService = world.vehicles
	# --- purchase: locked without deliveries, two max, charged once each.
	if bool(vs.can_buy().ok):
		err = "pickup purchasable before the unlock"
	cs.wallet.grant(3000000, "test", "P5", "test cash")
	vs.dev_unlock = true
	var cash0 := cs.wallet.cash
	var r1 := vs.buy()
	var r2 := vs.buy()
	var r3 := vs.buy()
	if err == "" and (not bool(r1.ok) or not bool(r2.ok) or bool(r3.ok) or vs.trucks.size() != 2):
		err = "purchase limits wrong: %s %s %s" % [r1.ok, r2.ok, r3.ok]
	if err == "" and cash0 - cs.wallet.cash != 2 * int(vs.unlock_state().price):
		err = "purchase charged %d" % (cash0 - cs.wallet.cash)
	var t1: Truck = vs.trucks[r1.id] if bool(r1.ok) else null
	var t2: Truck = vs.trucks[r2.id] if bool(r2.ok) else null
	# --- seats: driver + two passengers, never one person in two trucks.
	var p: Player = world.player
	if err == "" and t1:
		vs.enter(p, t1, "driver")
		vs.board(world.crew.workers["EMP-01"], t1, "middle")
		vs.board(world.crew.workers["EMP-02"], t1, "right")
		if t1.free_seat() != "" or t1.occupants().size() != 3:
			err = "seats: %s" % str(t1.seats)
		if err == "" and (t2.seat_of("boss") != "" or t2.seat_of("EMP-01") != ""):
			err = "someone seated in two trucks"
		if err == "" and p.couch != null:
			err = "driver also on the couch"
		vs.disembark(world.crew.workers["EMP-01"], t1)
		vs.disembark(world.crew.workers["EMP-02"], t1)
		p.exit_vehicle(t1.door_point(-1.0))
		t1.seats.driver = ""
		t1.release_control()
	# --- cargo: real pieces load into the bed (one owner), pay once on unload.
	var tm: TimberService = world.timber
	var i := LoggingTest.find("small")
	var id: int = World.trees.id[i]
	var stand := PlacementValidator.cut_stands(i)[0]
	world.trees.apply_contact(id, stand, float(world.trees.record(id).required) + 1.0)
	var w := 0.0
	while world.trees.state_of(id) < TreeService.State.SECTIONED and w < 30.0:
		await get_tree().physics_frame
		w += 1.0 / 60.0
	guard = 0
	while guard < 100:
		guard += 1
		var tb: TimberBody = null
		for key in tm.bodies:
			if not (tm.bodies[key] as TimberBody).is_single_piece():
				tb = tm.bodies[key]
		if tb == null:
			break
		var y := float(tm.records[id].merch_top) if tb.crown else float(tm.records[id].segments[tb.ks.max() - 1].b)
		tm.apply_cut(tb, y, 100.0)
		for f in 20:
			await get_tree().physics_frame
	for f in 60:
		await get_tree().physics_frame
	if err == "" and tm.bodies.is_empty():
		err = "no timber pieces to load"
	if err == "":
		var b: TimberBody = tm.bodies.values()[0]
		var sid: String = b.sid_list()[0]
		tm.pick_up_for("player", b, 2000)
		var n := vs.load_from("player", t1)
		var seg := tm.segment(sid)
		if n < 1 or not tm.load_of(t1.carrier()).has(sid) or int(seg.state) != TimberService.Seg.VEHICLE_RESERVED:
			err = "load into the bed failed (%d, state %s)" % [n, str(seg.get("state"))]
		if err == "" and (tm.transfer(t1.carrier(), t2.carrier(), sid, 0) and tm.load_of(t1.carrier()).has(sid)):
			err = "piece owned by two trucks"
		if err == "" and tm.load_of(t2.carrier()).has(sid):
			# move it back so the rest of the test is about t1
			tm.transfer(t2.carrier(), t1.carrier(), sid, Truck.CAPACITY_MTE)
		cs.wallet.enabled = true
		var c1 := cs.wallet.cash
		var rs := vs.unload_accept(t1, "truck:" + t1.truck_id)
		var rs2 := vs.unload_accept(t1, "truck:" + t1.truck_id)
		var cents := 0
		for r in rs:
			cents += int(r.cents)
		if err == "" and (rs.is_empty() or not rs2.is_empty() or cs.wallet.cash - c1 != cents or not tm.load_of(t1.carrier()).is_empty()):
			err = "truck delivery not paid exactly once (%d receipts, %d again, %d cents)" % [rs.size(), rs2.size(), cs.wallet.cash - c1]
	# --- safe stop: dismissing a moving team brakes first.
	if err == "" and t2:
		var area := World.camp_origin() + Vector3(0, 0, -70)
		vs.dispatch(t2.truck_id, "EMP-01", ["EMP-02"], area)
		var tmd: Dictionary = vs.teams[t2.truck_id]
		tmd.state = "drive_back"
		t2.take_control("auto")
		t2.set_route(vs.nav.route(t2.global_position, area))
		t2._auto_speed = 5.0
		vs.disband(t2.truck_id, "test")
		if not vs.teams.has(t2.truck_id) or str(vs.teams[t2.truck_id].state) != "stopping":
			err = "moving team was not brought to a stop first"
		var k := 0
		while err == "" and vs.teams.has(t2.truck_id) and k < 300:
			await get_tree().physics_frame
			k += 1
		if err == "" and (vs.teams.has(t2.truck_id) or t2.mode != "parked"):
			err = "team not stood down after stopping"
	# --- TV: ten cameras, distinct quad, one tile per step, fair bag.
	var tv: CameraWall = world.tv
	tv.force_active = true
	tv.set_power(true)
	tv.set_mode("quad")
	for f in 3:
		await get_tree().process_frame
	if err == "" and tv.cams.size() != 10:
		err = "expected 10 cameras, got %d" % tv.cams.size()
	var seen := {}
	for c in tv.tiles:
		seen[c] = true
	for step in 40:
		var before: Array[int] = tv.tiles.duplicate()
		var expect_tile := tv._next_tile
		tv.rotate_once()
		var changed := 0
		for k2 in 4:
			if before[k2] != tv.tiles[k2]:
				changed += 1
				if k2 != expect_tile:
					err = "tile %d changed, expected %d (round robin)" % [k2, expect_tile]
		var uniq := {}
		for c in tv.tiles:
			uniq[c] = true
			seen[c] = true
		if err == "" and (changed != 1 or uniq.size() != 4):
			err = "rotation step changed %d tiles / %d distinct" % [changed, uniq.size()]
		if err != "":
			break
	if err == "" and seen.size() != 10:
		err = "only %d of 10 cameras shown in 40 steps" % seen.size()
	# Click selects what the tile shows now; focus locks; back gives a set.
	if err == "":
		var shown := tv.tiles[2]
		tv.focus_tile(2)
		if tv.mode != "focus" or tv.focus_index != shown:
			err = "focus did not take the displayed camera"
		tv._process(1.0)
		if err == "" and tv.focus_index != shown:
			err = "focus changed by itself"
		# Pool: in focus no quad render target updates, and vice versa.
		for vp in tv._quad_vps:
			if err == "" and vp.render_target_update_mode != SubViewport.UPDATE_DISABLED and vp.render_target_update_mode != SubViewport.UPDATE_ONCE:
				err = "quad viewport set to continuous update"
		tv._process(0.2)
		var quad_updating := 0
		for vp in tv._quad_vps:
			if vp.render_target_update_mode == SubViewport.UPDATE_ONCE:
				quad_updating += 1
		if err == "" and quad_updating > 0:
			err = "quad feeds render while focused"
		if err == "" and tv._focus_vp.size.x <= tv._quad_vps[0].size.x * 2:
			err = "focus resolution not materially higher"
		tv.back_to_quad()
		var u2 := {}
		for c in tv.tiles:
			u2[c] = true
		if err == "" and (tv.mode != "quad" or u2.size() != 4 or not shown in tv.tiles):
			err = "back to quad gave %s" % str(tv.tiles)
	# No recursive capture: TV screen on its own layer, cameras exclude it.
	if err == "" and (tv.screen.layers != 1 << (CameraWall.LAYER_TV - 1) or (tv._quad_cams[0].cull_mask & (1 << (CameraWall.LAYER_TV - 1))) != 0 or (tv._focus_cam.cull_mask & (1 << (CameraWall.LAYER_TV - 1))) != 0):
		err = "TV screen visible to security cameras"
	# --- remote microphones
	if err == "":
		var trail := -1
		for ci in tv.cams.size():
			if tv.cam_id(ci) == "CAM-08":
				trail = ci
		tv.tiles = [trail, (trail + 1) % 10, (trail + 2) % 10, (trail + 3) % 10]
		tv._apply_tiles()
		tv.set_mode("quad")
		tv._process(0.05)
		tv._gain = 0.25   # settled wall level (the ramp is tested by the focus step)
		var snd: AudioStream = load("res://audio/generated/chop_0.wav")
		var near := tv.cams[trail].global_position + Vector3(4, -2, 4)
		var r0 := tv.relayed
		SoundEvents.emit(snd, near, -6.0, "work", "chopping")
		if tv.relayed != r0 + 1:
			err = "nearby trail sound not relayed"
		var quad_db := float(tv.last_relay.get("volume_db", 0.0))
		SoundEvents.emit(snd, near, -6.0, "work", "chopping")
		if err == "" and tv.relayed != r0 + 1:
			err = "duplicate replay of one sound"
		var dr := tv.dropped_range
		SoundEvents.emit(load("res://audio/generated/chop_1.wav"), tv.cams[trail].global_position + Vector3(300, 0, 0), 0.0, "work", "chopping")
		if err == "" and tv.dropped_range != dr + 1:
			err = "out-of-range sound not dropped"
		tv.set_mic_muted(true)
		var r1b := tv.relayed
		await get_tree().create_timer(0.2).timeout
		SoundEvents.emit(load("res://audio/generated/chop_2.wav"), near, -6.0, "work", "chopping")
		if err == "" and tv.relayed != r1b:
			err = "muted microphones still relayed"
		tv.set_mic_muted(false)
		tv.focus_index = trail
		tv.set_mode("focus")
		tv._gain = 1.0
		await get_tree().create_timer(0.2).timeout
		SoundEvents.emit(load("res://audio/generated/chop_3.wav"), near, -6.0, "work", "chopping")
		if err == "" and float(tv.last_relay.get("volume_db", -99.0)) < quad_db + 6.0:
			err = "focused mic not louder (%.1f vs quad %.1f dB)" % [float(tv.last_relay.get("volume_db", -99.0)), quad_db]
		# TV output is never an event: no feedback loop.
		SoundEvents.recent.clear()
		await get_tree().create_timer(0.3).timeout
		for q in SoundEvents.recent:
			if err == "" and q.distance_to(tv.speaker.global_position) < 1.0:
				err = "TV replay re-entered the sound registry"
		tv.back_to_quad()
	# --- pause: rotation does not advance while paused, no burst on resume
	if err == "":
		var tiles0: Array[int] = tv.tiles.duplicate()
		get_tree().paused = true
		for f in 20:
			await get_tree().process_frame
		get_tree().paused = false
		if tv.tiles != tiles0:
			err = "rotation advanced while paused"
	# --- arcade: pauses the world, restores exactly
	var ar: ArcadeService = world.arcade
	if err == "":
		var clock_t := cs.clock.t
		ar.open(0)
		if not get_tree().paused or not ar.is_open():
			err = "arcade did not pause the world"
		ar._game.start()
		for f in 30:
			await get_tree().process_frame
		if err == "" and absf(cs.clock.t - clock_t) > 0.001:
			err = "campaign clock ran during the arcade"
		if err == "" and ar._game.state != "play":
			err = "arcade game not running while the world is paused"
		ar._game.score = 7
		ar.close()
		if err == "" and (get_tree().paused or ar.is_open() or int(ar.highs.log_stacker) != 7):
			err = "arcade exit did not restore state / keep the high score"
	# --- dog: dusk route through the real camper door flap, no teleport
	var dog: CampDog = world.dog
	if err == "":
		dog.global_position = CampLayout.world(Vector3(0, 0, 6))
		dog.global_position.y = world.crew.nav.surface_at(dog.global_position)
		dog.state = CampDog.State.IDLE
		dog.events.clear()
		dog.go_home()
		var last := dog.global_position
		var max_step := 0.0
		for f in 3000:
			dog._process(1.0 / 30.0)
			max_step = maxf(max_step, dog.global_position.distance_to(last))
			last = dog.global_position
			if dog.state == CampDog.State.SLEEP:
				break
		if dog.state != CampDog.State.SLEEP or not dog.inside_camper():
			err = "dog did not get to bed (%s, events %s)" % [CampDog.State.keys()[dog.state], str(dog.events)]
		elif not ("flap_in" in dog.events or "door_open_in" in dog.events):
			err = "dog did not pass the door/flap: %s" % str(dog.events)
		elif max_step > 0.4:
			err = "dog jumped %.2f m in one step (teleport)" % max_step
	if err == "":
		# Morning: gets up and goes out the same way.
		dog.events.clear()
		dog._leave_camper()
		var last2 := dog.global_position
		var ms2 := 0.0
		for f in 1500:
			dog._process(1.0 / 30.0)
			ms2 = maxf(ms2, dog.global_position.distance_to(last2))
			last2 = dog.global_position
			if dog.state == CampDog.State.IDLE:
				break
		if dog.inside_camper() or not ("flap_out" in dog.events or "door_open_out" in dog.events) or ms2 > 0.4:
			err = "dog morning exit wrong: %s (step %.2f)" % [str(dog.events), ms2]
	# Avoids the burn pit; a petting is optional and cancellable.
	if err == "":
		for fp in dog._fire_points():
			if dog._good_spot(fp + Vector3(1.0, 0, 0)):
				err = "dog would wander into the fire"
		dog.pet(p)
		if err == "" and dog.state != CampDog.State.PET:
			err = "petting did not start"
		p.global_position = dog.global_position + Vector3(6, 0, 0)
		dog._process(0.1)
		if err == "" and dog.state == CampDog.State.PET:
			err = "petting not cancelled by walking away"
	# Refuge + one boarding handoff, distinct saved states, same identity.
	if err == "":
		if not dog.enter_refuge():
			err = "dog could not head for the refuge"
		for f in 6000:
			if dog.state == CampDog.State.REFUGE:
				break
			dog._process(1.0 / 30.0)
		if err == "" and dog.state != CampDog.State.REFUGE:
			err = "dog did not reach the refuge (%s)" % CampDog.State.keys()[dog.state]
		var cap := dog.capture()
		if err == "" and (str(cap.routine) != "refuge" or str(cap.id) != CampDog.DOG_ID):
			err = "refuge state not captured"
		dog.restore(JSON.parse_string(JSON.stringify(cap)))
		if err == "" and dog.state != CampDog.State.REFUGE:
			err = "refuge not restored"
		var b1 := dog.board_ship()
		var b2 := dog.board_ship()
		if err == "" and (not b1 or b2):
			err = "boarding handoff not exactly once"
		dog.boarded_once = false
		dog.routine = "camp"
		dog.visible = true
		dog.state = CampDog.State.IDLE
	# --- couch: sit, look around, verified stand-up
	if err == "":
		var seats := get_tree().get_nodes_in_group("couch_seat")
		p.teleport_feet(Viewpoints.all()["camper"].feet, 0.0)
		await get_tree().physics_frame
		p.sit_on_couch(seats[0])
		for f in 40:
			await get_tree().physics_frame
		if p.couch == null or not p.collision_layer == 0:
			err = "player did not sit"
		var data := SaveService.capture_state(world)
		if err == "" and (str(data.player.seat) != "couch" or not data.has("phase5") or not (data.phase5 as Dictionary).has("tv")):
			err = "couch/phase5 not saved: %s" % str(data.player)
		p.stand_from_couch()
		await get_tree().physics_frame
		if err == "" and (p.couch != null or not p._stand_clear(p.global_position)):
			err = "stand-up not clear"
		# TV state round trip.
		var tvd := tv.capture()
		tv.restore(JSON.parse_string(JSON.stringify(tvd)))
		if err == "" and tv.tiles != tvd.tiles:
			err = "TV quad set not restored"
	world.timber.clear_all()
	world.trees.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


# ----------------------------------------------------------------- phase 6

func _t_terror_bank() -> String:
	var f := FileAccess.open("res://data/terror/bank.json", FileAccess.READ)
	if f == null:
		return "bank.json missing"
	var b: Dictionary = JSON.parse_string(f.get_as_text())
	if (b.families as Array).size() != 26 or (b.events as Array).size() != 1300 or (b.startles as Array).size() != 312 or (b.foreman as Array).size() != 36:
		return "counts %d/%d/%d/%d" % [(b.families as Array).size(), (b.events as Array).size(), (b.startles as Array).size(), (b.foreman as Array).size()]
	var d := TerrorDirector.new()
	d.bank = b
	var v := d.validate()
	d.free()
	if not (v.errors as Array).is_empty():
		return "validation: %s" % str((v.errors as Array).slice(0, 4))
	var per := {}
	for e in b.events:
		var k := "%02d" % int(e.family)
		per[k] = int(per.get(k, 0)) + 1
		if int(e.family) == 26 and not "rescue_beat" in str(e.steps):
			return "T26 event not mapped to the rescue quest: %s" % str(e.id)
		if not str(e.id).begins_with("T%02d-E" % int(e.family)):
			return "bad id %s" % str(e.id)
	for k in per:
		if int(per[k]) != 50:
			return "family %s has %d events" % [k, int(per[k])]
	for fp in b.foreman:
		if str(fp.text) == "":
			return "empty Foreman pattern %s" % str(fp.id)
	return ""


func _t_phase6_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while not world.systems_ready and guard < 600:
		await get_tree().physics_frame
		guard += 1
	var err := ""
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	var p: Player = world.player
	var th: NightThreat = world.threat
	# --- exposure only outside safety at night; same-frame safety wins.
	cs.clock.advance(maxf(WorkdayClock.NIGHT_AT + 1.0 - cs.clock.t, 0.0))
	cs.clock.running = false
	world.teleport_to("forest")
	await get_tree().physics_frame
	th.exposure = 0.0
	th.outside_t = 2.0
	th._process(10.0)
	if th.exposure <= 0.0:
		err = "no exposure outside at night"
	world.teleport_to("camper")
	for i in 3:
		await get_tree().physics_frame
	var e0 := th.exposure
	th._process(10.0)
	if err == "" and th.exposure > e0:
		err = "exposure grew inside the camper"
	var caught := [false]
	th.caught.connect(func() -> void: caught[0] = true)
	th.exposure = 1.0
	th._commit_catch(p)
	if err == "" and caught[0]:
		err = "a stale catch followed the player into the camper"
	world.teleport_to("forest")
	await get_tree().physics_frame
	th.grant_grace(60.0)
	th.exposure = 0.99
	th.outside_t = 5.0
	th._process(1.0)
	if err == "" and caught[0]:
		err = "catch during the protected rescue grace"
	th.grace_until = -1.0
	th._commit_catch(p)
	if err == "" and not caught[0]:
		err = "no catch after full exposure outside"
	if world.end_screen.visible:
		world.end_screen._resume()
	Game.block_saves = false
	# --- director: forced encounter starts, morning cleans up.
	var dir: TerrorDirector = world.director
	world.teleport_to("forest")
	await get_tree().physics_frame
	var id := dir.offer("T01-E001")
	if err == "" and id == "":
		err = "director could not place T01-E001 in the forest"
	dir.morning_cleanup()
	await get_tree().process_frame
	if err == "" and (dir.active != null or not get_tree().get_nodes_in_group("terror_actor").is_empty() and is_instance_valid(get_tree().get_nodes_in_group("terror_actor")[0]) and not get_tree().get_nodes_in_group("terror_actor")[0].is_queued_for_deletion()):
		err = "morning left a night actor behind"
	dir._on_ended("peak", "TEST")
	if err == "" and dir.peak_available():
		err = "peak refractory not applied"
	# --- success never hunts.
	var h: HuntService = world.hunt
	cs.contract.state = ContractService.FULFILLED
	h.begin_abandonment()
	if err == "" and (h.mode != "none" or h.foreman != null):
		err = "a fulfilled contract started the hunt"
	# --- abandonment -> hunt.
	cs.contract.state = ContractService.ABANDONMENT
	world.teleport_to("camp")
	await get_tree().physics_frame
	h.begin_abandonment()
	if world.end_screen.showing == "info":
		world.end_screen._resume()
	await get_tree().physics_frame
	if err == "" and (h.mode != "hunt" or h.foreman == null or get_tree().get_nodes_in_group("foreman").size() != 1):
		err = "hunt did not start with exactly one Foreman"
	if err == "" and h.foreman.global_position.distance_to(p.global_position) < 80.0:
		err = "Foreman revealed too close (%.0f m)" % h.foreman.global_position.distance_to(p.global_position)
	if err == "" and world.dog.routine != "refuge":
		err = "dog not sent to the dock refuge"
	if err == "" and bool(world.crew.can_hire().ok):
		err = "hiring still open after abandonment"
	for x in h.foreman._humans():
		if err == "" and x == world.dog:
			err = "the dog is a Foreman target"
	if err == "" and world.director._is_ordinary_night():
		err = "ordinary director still active during the hunt"
	# --- hidden + unexposed: an attack commit is an evasion, not a kill.
	var spots := get_tree().get_nodes_in_group("hide_spot")
	if err == "" and spots.size() < 8:
		err = "only %d hide spots" % spots.size()
	if err == "":
		var hs: HideSpot = spots[0]
		p.teleport_feet(hs.exit_point, 0.0)
		await get_tree().physics_frame
		p.hide_in(hs)
		h.foreman.global_position = p.global_position + Vector3(1.0, 0, 0)
		h.foreman._begin_attack(p)
		h.foreman.attack_t = 1.0
		h.foreman._attack(0.1)
		if h.player_dead:
			err = "killed while hidden and not found"
		p.leave_hide()
	# --- continuous clock: five cycles before rescue.
	if err == "":
		h.foreman.grace = 9999.0
		var day0 := h.hunt_day
		h.t = HuntService.CYCLE - 0.1
		h._process(0.2)
		if h.hunt_day != day0 + 1:
			err = "dawn did not advance the hunt day"
		h.hunt_day = 34
		h.t = HuntService.CYCLE - 0.1
		h._process(0.2)
		if err == "" and h.mode != "hunt":
			err = "rescue arrived before five cycles"
		h.t = HuntService.CYCLE - 0.1
		h._process(0.2)
		if err == "" and (h.mode != "rescue" or h.hunt_day != 36):
			err = "rescue not available at dawn of day 36 (mode %s day %d)" % [h.mode, h.hunt_day]
	# --- save v7 carries the hunt.
	var data := SaveService.capture_state(world)
	if err == "" and str(((data.get("phase6", {}) as Dictionary).get("hunt", {}) as Dictionary).get("mode", "")) != "rescue":
		err = "hunt not saved"
	if world.end_screen.visible:
		world.end_screen._resume()
	world.timber.clear_all()
	world.trees.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.block_saves = false
	Game.mode = Game.Mode.MENU
	return err


# ----------------------------------------------------------------- phase 7

func _t_phase7_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while not world.systems_ready and guard < 600:
		await get_tree().physics_frame
		guard += 1
	var err := ""
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	# Bridges: walkers stand on the deck, trucks can drive across.
	for b in World.bridges():
		var mid := Vector3(float(b.x), 0, float(b.z))
		var y := world.crew.nav.surface_at(mid)
		if err == "" and absf(y - float(b.deck)) > 0.35:
			err = "walk surface on bridge %.2f vs deck %.2f" % [y, float(b.deck)]
		if err == "" and not world.vehicles.nav.drivable(mid):
			err = "bridge deck not drivable"
		var across := Vector2(float(b.ax), float(b.az)).normalized()
		for sgn in [-1.0, 1.0]:
			var L := BridgeBuilder.ramp_length(b, sgn)
			var foot: Vector2 = Vector2(b.x, b.z) + across * sgn * (float(b.half_span) + L)
			var rise := absf(float(b.deck) - World.height_at(foot.x, foot.y))
			if err == "" and rise / L > BridgeBuilder.MAX_RAMP_SLOPE + 0.01 and L < 16.0:
				err = "ramp too steep (%.2f)" % (rise / L)
	# A truck route crosses each bridge: bays -> the ramp foot on both sides.
	for bb in World.bridges():
		var acr := Vector2(float(bb.ax), float(bb.az)).normalized()
		for sg in [-1.0, 1.0]:
			var ft: Vector2 = Vector2(bb.x, bb.z) + acr * sg * (float(bb.half_span) + BridgeBuilder.ramp_length(bb, sg) + 2.0)
			var r := world.vehicles.nav.route(world.vehicles.bay_pose(0).origin, Vector3(ft.x, World.height_at(ft.x, ft.y), ft.y))
			if err == "" and r.is_empty():
				err = "no truck route to the %s side of a bridge" % ("far" if sg > 0.0 else "near")
	# A worker chops out a real stump through the shared claim.
	if err == "":
		var tm: TimberService = world.timber
		var i := LoggingTest.find("small")
		var id: int = World.trees.id[i]
		var stand := PlacementValidator.cut_stands(i)[0]
		world.trees.apply_contact(id, stand, float(world.trees.record(id).required) + 1.0)
		var w := 0.0
		while world.trees.state_of(id) < TreeService.State.SECTIONED and w < 40.0:
			await get_tree().physics_frame
			w += 1.0 / 60.0
		# Buck it up so only the stump remains.
		var g2 := 0
		while g2 < 100:
			g2 += 1
			var tb: TimberBody = null
			for key in tm.bodies:
				if not (tm.bodies[key] as TimberBody).is_single_piece():
					tb = tm.bodies[key]
			if tb == null:
				break
			var yy := float(tm.records[id].merch_top) if tb.crown else float(tm.records[id].segments[tb.ks.max() - 1].b)
			tm.apply_cut(tb, yy, 100.0)
			for f in 15:
				await get_tree().physics_frame
		if world.trees.state_of(id) != TreeService.State.SECTIONED:
			err = "fixture tree not sectioned (state %d)" % world.trees.state_of(id)
		else:
			var wk: Worker = world.crew.workers.values()[0]
			wk.abandon("test")
			wk.emp["job"] = "processing"
			wk.global_position = stand + Vector3(1.0, 0, 0)
			wk.emp["focus"] = [stand.x, stand.y, stand.z]
			var started := world.crew._try_stump(wk)
			var t := 0.0
			while started and world.trees.state_of(id) != TreeService.State.DISPOSED and t < 240.0:
				await get_tree().physics_frame
				t += 1.0 / 60.0
			if not started:
				err = "worker could not take the stump job"
			elif world.trees.state_of(id) != TreeService.State.DISPOSED:
				err = "worker did not remove the stump (activity %s)" % wk.activity
			elif int(world.crew.stats[wk.id].get("stumps", 0)) != 1:
				err = "stump not counted"
	# The locator finds remaining work.
	if err == "" and not ContractLocator.nearest(world.player.global_position).has("tree"):
		err = "locator found no standing tree"
	world.timber.clear_all()
	world.trees.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


# ---------------------------------------------------------------- Phase 8

func _t_phase8_presentation() -> String:
	var err := ""
	# Face winding: every procedural tree/limb surface is clockwise from
	# outside (cull_back must never hide the near half of a trunk).
	var tb := TreeBuilder.new()
	for sp in 3:
		for m in [tb.build(sp, 0, true), tb.build_far(sp)]:
			var arr := (m as ArrayMesh).surface_get_arrays(0)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in range(0, v.size(), 3):
				var cr := (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
				if cr.length() > 1e-9 and cr.dot(nn[i] + nn[i + 1] + nn[i + 2]) > 0.0:
					return "tree species %d surface wound inside-out" % sp
	var cap := CharMeshKit.tapered_capsule(0.05, 0.04, 0.3)
	var ca := cap.surface_get_arrays(0)
	var cv: PackedVector3Array = ca[Mesh.ARRAY_VERTEX]
	var cn: PackedVector3Array = ca[Mesh.ARRAY_NORMAL]
	if (cv[1] - cv[0]).cross(cv[2] - cv[0]).dot(cn[0] + cn[1] + cn[2]) > 0.0:
		return "character limb capsule wound inside-out"
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while not world.systems_ready and guard < 600:
		await get_tree().physics_frame
		guard += 1
	var w: WeatherService = world.weather
	# Deterministic schedule: same seed/day/time -> same weather, any instance.
	var w2 := WeatherService.new()
	w2.seed_value = w.seed_value
	var rainy := 0
	for day in range(1, 36):
		var a := w.sample(day, 610.0)
		var b := w2.sample(day, 610.0)
		if err == "" and (absf(float(a.rain) - float(b.rain)) > 1e-6 or str(a.name) != str(b.name)):
			err = "weather not deterministic on day %d" % day
		var any_rain := false
		for tt in range(0, 1200, 60):
			if float(w.sample(day, float(tt)).rain) > 0.3:
				any_rain = true
		if any_rain:
			rainy += 1
	w2.free()
	if err == "" and float(w.sample(1, 300.0).rain) > 0.0:
		err = "day 1 should be fair"
	if err == "" and (rainy < 3 or rainy > 18):
		err = "rain days out of a restrained range (%d of 35)" % rainy
	# Continuity: no instant jumps between neighbouring seconds.
	for day in [4, 9, 17]:
		var prev := w.sample(day, 0.0)
		for tt in range(1, 1200, 1):
			var cur := w.sample(day, float(tt))
			if err == "" and absf(float(cur.cloud) - float(prev.cloud)) > 0.05:
				err = "weather jumps on day %d at %d s" % [day, tt]
			prev = cur
	# Campaign clock drives it; save/load reconstructs without a reroll.
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	var target_day := -1
	var target_t := 0.0
	for day in range(2, 30):
		for tt in range(60, 1140, 30):
			if target_day < 0 and float(w.sample(day, float(tt)).rain) > 0.3:
				target_day = day
				target_t = float(tt)
	if err == "" and target_day < 0:
		err = "no rainy day found in the schedule"
	if err == "":
		cs.clock.day = target_day
		cs.clock.t = 0.0
		cs.clock.advance(target_t)
		w.set_override("")
		for i in 30:
			await get_tree().process_frame
		var before := w.sample(cs.clock.day, cs.clock.t)
		if absf(w.rain - float(before.rain)) > 0.02:
			err = "service rain %.2f does not follow the clock (%.2f)" % [w.rain, float(before.rain)]
		var saved := w.capture()
		w.wetness = 0.0
		w.restore(saved)
		if err == "" and absf(w.wetness - float(saved.wetness)) > 0.002:
			err = "wetness not restored"
		if err == "" and absf(w.rain - float(before.rain)) > 0.02:
			err = "weather rerolled on restore"
		var st := SaveService.capture_state(world)
		if err == "" and not (st.get("phase8", {}) as Dictionary).has("weather"):
			err = "save lacks the phase8 weather block"
		var mig := SaveService.migrate({"schema": 7, "phase6": {}, "phase5": {}})
		if err == "" and (int(mig.get("schema", 0)) != 8 or not mig.has("phase8")):
			err = "v7 -> v8 migration missing"
	cs.test_route = false
	# Weather never changes safety: lamp/camper answers identical in a storm,
	# and lightning emits no AI evidence (SoundEvents) and never touches lamps.
	var probes: Array[Vector3] = []
	for lamp in get_tree().get_nodes_in_group("camp_lamps"):
		if world.is_ancestor_of(lamp):
			probes.append((lamp as Node3D).global_position + Vector3(1.0, -1.5, 0.5))
	probes.append(world.camp.global_position + CampLayout.CAMPER_POS + Vector3(0, 1.2, 0))
	probes.append(world.camp.global_position + Vector3(0, 1.0, 60.0))
	w.set_override("clear", true)
	await get_tree().process_frame
	var clear_answers: Array = []
	for p in probes:
		clear_answers.append(world.safety.query(p).safe)
	var lamp_levels: Array = []
	for lamp in get_tree().get_nodes_in_group("camp_lamps"):
		lamp_levels.append(lamp.get("working"))
	Settings.set_v("flash_reduction", "full", false)
	w.set_override("storm", true)
	var events_before := SoundEvents.recent.size()
	w._next_flash = 0.0
	for i in 90:
		await get_tree().process_frame
	w._thunder_due = 0.001
	await get_tree().process_frame
	await get_tree().process_frame
	if err == "" and w.flashes < 1:
		err = "storm produced no lightning"
	if err == "" and SoundEvents.recent.size() != events_before:
		err = "lightning/thunder emitted world sound events (AI evidence)"
	for i in probes.size():
		if err == "" and world.safety.query(probes[i]).safe != clear_answers[i]:
			err = "storm changed safety at probe %d" % i
	var k := 0
	for lamp in get_tree().get_nodes_in_group("camp_lamps"):
		if err == "" and lamp.get("working") != lamp_levels[k]:
			err = "weather changed a lamp's working state"
		k += 1
	# Flash reduction "off": no flash at all.
	Settings.set_v("flash_reduction", "off", false)
	w._flash_t = 0.0
	await get_tree().process_frame
	if err == "" and w.flash > 0.0:
		err = "flash shown with flash reduction off"
	Settings.set_v("flash_reduction", "reduced", false)
	# Shared wind/wetness reach the environment (single writer).
	if err == "" and absf(world.environment.weather_rain - w.rain) > 0.05:
		err = "environment did not receive the weather"
	if err == "" and world.environment.wind_now <= world.environment.current.wind:
		err = "storm wind not applied to the shared wind field"
	# Rain views: player view + one bounded view per rendered remote camera.
	var cams := world.tv.cams
	w.set_remote_views([cams[0], cams[1], cams[2], cams[3]])
	if err == "" and w.views.size() != 5:
		err = "expected 5 rain views, got %d" % w.views.size()
	for v in w.views:
		if err == "" and v != w.player_view and int(v.amount_cap) > RainView.remote_budget(4):
			err = "remote rain over budget"
	w.set_remote_views([cams[5]])
	await get_tree().process_frame
	if err == "" and w.views.size() != 2:
		err = "remote rain views not released (%d)" % w.views.size()
	w.set_remote_views([])
	# Shelter: a ray from inside the camper hits its roof.
	var inside := world.camp.global_position + CampLayout.CAMPER_POS + Vector3(0, CampLayout.CAMPER_FLOOR + 0.5, 0)
	if err == "" and w.shelter_at(inside) < 0.4:
		err = "camper roof does not shelter from rain"
	if err == "" and w.shelter_at(world.camp.global_position + Vector3(0, 0.2, 75.0)) > 0.0:
		err = "open ground reported sheltered"
	# Cleared ground: no standing trees means no leaf/bird presentation.
	var spot := World.tree_position(0)
	var near: PackedInt32Array = world.vegetation.standing_trees_near(spot, 6.0)
	for i in near:
		World.removed_trees[int(World.trees.id[i])] = true
	if err == "" and world.vegetation.standing_trees_near(spot, 6.0).size() != 0:
		err = "removed trees still counted as standing"
	for i in near:
		World.removed_trees.erase(int(World.trees.id[i]))
	w.set_override("")
	# ---- Animation coverage and contact sync (Phase 8)
	if err == "":
		err = _p8_animation(world)
	# ---- Bounded presentation: TV mode toggles and weather changes do not
	# grow nodes/objects (pooled viewports, pooled rain views).
	if err == "":
		var tv := world.tv
		tv.force_active = true
		for i in 5:
			await get_tree().process_frame
		for i in 20:
			tv.set_mode("focus" if i % 2 == 0 else "quad")
			w.set_override(["clear", "light_rain", "storm", "overcast"][i % 4], true)
			await get_tree().process_frame
		var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var objs0 := Performance.get_monitor(Performance.OBJECT_COUNT)
		for i in 200:
			tv.set_mode(["focus", "quad", "entertainment"][i % 3])
			if i % 4 == 0:
				w.set_override(["clear", "light_rain", "storm", "overcast"][(i / 4) % 4], true)
			if i % 10 == 0:
				await get_tree().process_frame
		for i in 10:
			await get_tree().process_frame
		var dn := Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes0
		var dobj := Performance.get_monitor(Performance.OBJECT_COUNT) - objs0
		if dn > 8 or dobj > 200:
			err = "TV/weather toggles grew nodes by %d and objects by %d" % [int(dn), int(dobj)]
		var info := tv.pipeline_info()
		if err == "" and (int(info.focus_px[0]) <= int(info.quad_px[0]) * 2 or float(info.focus_hz) <= float(info.quad_hz)):
			err = "focus is not a real resolution/refresh step up from quad: %s" % str(info)
		tv.set_mode("quad")
		tv.force_active = false
		w.set_override("")
	# ---- Review stations that need no HUD: they apply, write nothing.
	if err == "":
		var saves_before := Game.can_write_campaign_save()
		for st in ["morning", "forest", "river", "beach", "rain_night"]:
			var msg := ReviewStations.go(self, st)
			if msg == "":
				err = "review station %s did nothing" % st
				break
		if err == "" and world.weather.override != "light_rain":
			err = "rain-night station did not set rain"
		if err == "" and (saves_before or Game.can_write_campaign_save()):
			err = "preview stations may write campaign saves"
		var removed := ReviewStations.clear_near_camp(0.9)
		if err == "" and removed < 10000:
			err = "cleared fixture removed only %d trees" % removed
		if err == "" and world.vegetation.standing_trees_near(World.camp_origin(), 60.0).size() != 0:
			err = "cleared fixture left standing trees near camp"
		World.removed_trees.clear()
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


func _p8_animation(world: IslandWorld) -> String:
	var wk: Worker = null
	for x in world.crew.workers.values():
		wk = x
		break
	if wk == null:
		return "no worker body to test animation on"
	var hc := wk.body_char
	for clip in HumanCharacter.CLIPS:
		if not hc.anim.has_animation(clip):
			return "human clip missing: %s" % clip
	# One accepted swing = one contact, however frames are skipped.
	var cyc := wk._swing_cycle()
	wk._swing_t = -1.0
	var hits := 0
	var total := 0.0
	for d in [0.016, 0.016, 0.5, 1.3, 0.016, 0.2, 0.033, 0.9, 2.5, 0.016, 0.4, 0.4, 0.4]:
		var h := 0
		if wk._swing(d):
			h += 1
		hits += h
		total += d
	if hits > int(ceil(total / cyc)) + 1:
		return "swing produced %d contacts in %.2f s (cycle %.2f): duplicated work" % [hits, total, cyc]
	if hits < 3:
		return "swing contacts lost under frame skips (%d)" % hits
	wk._swing_t = -1.0
	hc.play("idle", 0.0)
	# One-shot actions finish back to idle and are interruptible by moving.
	hc.play_action("pickup")
	if hc.action != "pickup" or hc.current != "pickup":
		return "pickup action did not start"
	hc.set_locomotion(0.0)
	if hc.current != "pickup":
		return "standing locomotion cut a short action"
	hc.set_locomotion(1.2)
	if hc.action != "" or hc.current != "walk":
		return "moving did not interrupt an action"
	hc.play_action("listen")
	for i in 200:
		hc._process(0.02)
	if hc.action != "" or hc.current != "idle":
		return "listen action did not return to idle (%s)" % hc.current
	# Planted feet: at the deepest pickup bend the ankles stay at ankle height.
	hc.play("pickup", 0.0)
	hc.anim.seek(0.35, true)
	hc.anim.advance(0.0)
	for a in hc.ankle_positions():
		var local_y := (hc.global_transform.affine_inverse() * (a as Vector3)).y
		if absf(local_y - hc.ankle_h) > 0.06:
			return "pickup lifts/sinks a foot (ankle %.3f vs %.3f)" % [local_y, hc.ankle_h]
	hc.play("idle", 0.0)
	# Head yaw bounded in every authored clip (never through the shoulders).
	for clip in HumanCharacter.CLIPS:
		for k in HumanCharacter.CLIPS[clip].keys:
			if absf(float((k as Dictionary).get("head_y", 0.0))) > 1.0:
				return "clip %s turns the head too far" % clip
	# Dog coverage.
	var dc: DogCharacter = world.dog.dog if world.dog else null
	if dc:
		for clip in ["idle", "walk", "trot", "sit", "lie", "pet", "alert", "sniff", "growl"]:
			if not dc.anim.has_animation(clip):
				return "dog clip missing: %s" % clip
	# Foreman: steps come from foot plants; a listening pause is silent.
	var fb := ForemanBody.new()
	add_child(fb)
	fb.pose = "walk"
	fb.speed = 1.7
	for i in 300:
		fb._process(1.0 / 60.0)
	var walking_contacts := fb.contacts
	fb.pose = "listen"
	fb.speed = 0.0
	for i in 60:
		fb._process(1.0 / 60.0)
	var c0 := fb.contacts
	for i in 240:
		fb._process(1.0 / 60.0)
	var listen_contacts := fb.contacts - c0
	fb.queue_free()
	if walking_contacts < 4:
		return "Foreman walk produced only %d foot contacts in 5 s" % walking_contacts
	if listen_contacts != 0:
		return "Foreman 'stepped' %d times while standing still" % listen_contacts
	return ""


# ---------------------------------------------------------------- Phase 9

func _t_phase9_units() -> String:
	# Notifications: a minor message never replaces a critical one being read.
	var n := Notifications.new()
	n.push("Dusk. Head back to camp: night falls in 5 minutes.", 6.0)
	n.push("Chop!", 1.0, Notifications.P.MINOR)
	var line := n.tick(0.5)
	if not line.contains("Dusk"):
		return "minor message replaced the dusk warning: " + line
	n.push("Dusk. Head back to camp: night falls in 5 minutes.", 6.0)
	if not n.tick(0.1).contains("(x2)"):
		return "repeat not coalesced"
	n.push("Kofi is leaving: unpaid wages", 4.0)
	for i in 80:
		n.tick(0.1)
	if not n.tick(0.1).contains("leaving") and n.log.filter(func(e: Dictionary) -> bool: return str(e.text).contains("leaving")).is_empty():
		return "queued warning lost"
	if n.log.size() < 3:
		return "log missing entries"
	# Key rebinding: swap on conflict, live labels, reset.
	Keys.remember_defaults()
	var jump_before := Keys.label("jump")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	var swapped := Keys.rebind("interact", ev)
	var err := ""
	if Keys.label("interact") != "Space":
		err = "interact label after rebind: %s" % Keys.label("interact")
	elif swapped != "jump" or Keys.label("jump") == "Space":
		err = "conflict not swapped (swapped=%s, jump=%s)" % [swapped, Keys.label("jump")]
	elif not HelpText.controls().contains("Interact / use / pick up / talk: Space"):
		err = "help text does not use the live binding"
	var saved := Keys.capture()
	Keys.reset_defaults()
	if err == "" and (Keys.label("jump") != jump_before or Keys.label("interact") == "Space"):
		err = "reset did not restore defaults"
	Keys.apply_saved(saved)
	if err == "" and Keys.label("interact") != "Space":
		err = "saved bindings not re-applied"
	Keys.reset_defaults()
	if err != "":
		return err
	# Save summaries tell the truth.
	var done := SaveService.summarize({"schema": SaveService.SCHEMA_VERSION, "campaign": {"phase3": true, "state": "FULFILLED", "day": 24, "contract": {"outcome_at": {"day": 24}}, "post_contract": true}, "timber": {"receipts": [{"mte": 1000}, {"mte": 500}]}})
	if not str(done.status).contains("completed on day 24") or absf(float(done.accepted_trees) - 1.5) > 0.001 or not bool(done.post_contract):
		return "completed summary wrong: %s" % str(done)
	var hunt := SaveService.summarize({"schema": SaveService.SCHEMA_VERSION, "campaign": {"phase3": true, "state": "ABANDONMENT_PENDING", "day": 30}, "phase6": {"hunt": {"mode": "hunt", "hunt_day": 33}}})
	if not str(hunt.status).contains("day 33") or bool(hunt.finished):
		return "hunt summary wrong: %s" % str(hunt)
	var esc := SaveService.summarize({"schema": SaveService.SCHEMA_VERSION, "campaign": {"phase3": true}, "phase6": {"hunt": {"mode": "escaped"}}})
	if not bool(esc.finished):
		return "escaped run not marked finished (Continue would offer it)"
	var future := SaveService.summarize({"schema": SaveService.SCHEMA_VERSION + 3})
	if not bool(future.get("too_new", false)) or not str(future.status).contains("newer version"):
		return "future save not reported as too new"
	var legacy := SaveService.summarize({"schema": 7, "campaign": {"phase3": true, "legacy": true, "day": 40, "rule_set": "legacy_untimed"}})
	if not str(legacy.status).begins_with("Legacy"):
		return "legacy summary wrong: %s" % str(legacy.status)
	return ""


func _t_phase9_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while not world.systems_ready and guard < 600:
		await get_tree().physics_frame
		guard += 1
	var err := ""
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	var ob := cs.onboarding
	ob.start_new()
	# Legacy (pre-Phase 9) saves: the guide is already finished and the
	# night rules count as known.
	var probe := Onboarding.new()
	probe.restore({})
	if probe.active() or not probe.night_rules_ack:
		err = "an old save would start the tutorial"
	probe.free()
	# Real-result detection.
	var p: Player = world.player
	if err == "" and ob.current() != "move":
		err = "guide does not start at 'move' (%s)" % ob.current()
	if err == "":
		ob._check("move", cs)
		p.teleport_feet(p.global_position + Vector3(5, 0, 0), 0.0)
		if not ob._check("move", cs):
			err = "walking 5 m not detected"
	if err == "":
		ob._check("journal", cs)
		ob.journal_opened += 1
		if not ob._check("journal", cs):
			err = "journal open not detected"
	if err == "" and ob._check("deliver", cs):
		err = "delivery detected with nothing accepted"
	if err == "" and ob._check("fell", cs):
		err = "felling detected with nothing felled"
	if err == "":
		ob._base.clear()
		ob._check("sleep", cs)
		cs.clock.day += 1
		if not ob._check("sleep", cs):
			err = "a slept night not detected"
		cs.clock.day -= 1
	# Skip a step / replay never touches money or trees.
	var cash0 := cs.wallet.cash
	var felled0 := int(cs.contract.counts().felled)
	ob.done = ["move", "journal"]
	ob.skip_step()
	if err == "" and ob.current() != "rack":
		err = "skip step did not advance (now %s)" % ob.current()
	ob.replay()
	if err == "" and (cs.wallet.cash != cash0 or int(cs.contract.counts().felled) != felled0):
		err = "replaying the guide changed money or trees"
	# Night gate: before the rules are acknowledged no catch builds up.
	var threat: NightThreat = world.threat
	ob.night_rules_ack = false
	cs.clock.advance(maxf(WorkdayClock.NIGHT_AT + 1.0 - cs.clock.t, 0.0))
	p.teleport_feet(world.camp.global_position + Vector3(0, 0, 90.0), 0.0)
	threat.exposure = 0.0
	for i in 240:
		await get_tree().process_frame
	if err == "" and threat.exposure > 0.0:
		err = "night exposure grew before the night rules were acknowledged"
	if world.end_screen.visible:
		world.end_screen._resume()
	ob.night_rules_ack = true
	threat.outside_t = 10.0
	for i in 120:
		await get_tree().process_frame
	if err == "" and threat.exposure <= 0.0:
		err = "night exposure stays off after acknowledgement"
	threat.exposure = 0.0
	# True pause freezes the clock, night escalation and the director.
	var t0 := cs.clock.t
	var nt0 := threat.night_awake_t
	var dir_next: float = world.director.next_in
	get_tree().paused = true
	for i in 30:
		await get_tree().process_frame
	await get_tree().physics_frame
	if err == "" and (cs.clock.t != t0 or threat.night_awake_t != nt0 or float(world.director.next_in) != dir_next):
		err = "pause did not freeze clock/threat/director (%.2f->%.2f, %.2f->%.2f, %.2f->%.2f)" % [t0, cs.clock.t, nt0, threat.night_awake_t, dir_next, float(world.director.next_in)]
	get_tree().paused = false
	# Truthful refusals.
	if err == "" and not str(cs.can_sleep().get("reason", "ok")).is_empty() and cs.can_sleep().ok == false and cs.clock.phase() == WorkdayClock.Phase.NIGHT:
		err = "sleep refused at night: %s" % str(cs.can_sleep().reason)
	# Final-tree milestone once; it is not completion while stumps/logs remain.
	var notices: Array = []
	var cb := func(t: String, _s: float) -> void: notices.append(t)
	cs.notice.connect(cb)
	cs.contract.scope_override = int(cs.contract.counts().felled)
	cs.test_route = false
	cs._check_final_tree()
	cs._check_final_tree()
	cs.test_route = true
	cs.notice.disconnect(cb)
	if err == "" and not ob.milestones.has("final_tree"):
		err = "final-tree milestone not recorded"
	if err == "" and notices.filter(func(t: String) -> bool: return t.contains("last standing tree")).size() > 1:
		err = "final-tree message repeated"
	cs.contract.scope_override = -1
	# Success summary comes from the ledger.
	var lines := world.get_node_or_null("HUD")
	var sum := CampaignUI.new()
	sum.svc = cs
	var out := sum.success_summary()
	sum.free()
	if err == "" and (out.size() < 4 or not str(out[2]).contains("Earned from deliveries")):
		err = "success summary incomplete: %s" % str(out)
	# Contract fulfilled: sleeping explains there are no more workdays.
	var st0 := cs.contract.state
	cs.contract.state = ContractService.FULFILLED
	if err == "" and not str(cs.can_sleep().reason).contains("no more workdays"):
		err = "fulfilled sleep reason: %s" % str(cs.can_sleep().reason)
	cs.contract.state = st0
	cs.test_route = false
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err
