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
	_run("save v2 -> v3 migration keeps trees, adds timber", _t_save_v3)
	await _run_async("timber ledger: buck, carry limits, one owner, receipts once, burn, recovery, reload", _t_timber_ledger)
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
	var needs := {"worker_bed": 4, "worker_seat": 4, "worker_spawn": 4, "arcade_spot": 2, "player_bed": 1, "dog_bed": 1, "shop_counter": 1, "payroll_anchor": 1, "burn_pit_load_point": 1, "safe_reset": 1}
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
	if int(m.get("schema", 0)) != 3:
		return "v2 save not upgraded"
	if not m.trees.has("5") or int(m.trees["5"].state) != 3:
		return "tree states lost in migration"
	if not (m.timber as Dictionary).is_empty():
		return "placeholder timber block kept"
	var v1 := SaveService.migrate({"schema": 1, "felled_trees": [9], "player": {"position": [0, 0, 0]}})
	if int(v1.schema) != 3 or not bool(v1.campaign.legacy):
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
