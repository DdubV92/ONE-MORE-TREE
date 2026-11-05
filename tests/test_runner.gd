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
	if OS.has_environment("ONLY_P12"):
		await _run_async("human walk keeps stance foot planted", _t_human_walk)
		if not OS.has_environment("WALK_ONLY"):
			await _run_async("phase 12", _t_phase12_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P20"):
		_run("phase 20 units", _t_phase20_units)
		await _run_async("phase 20 night world", _t_phase20_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P19"):
		_run("phase 19 units", _t_phase19_units)
		await _run_async("phase 19 offshore world", _t_phase19_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P18"):
		_run("phase 18 units", _t_phase18_units)
		await _run_async("phase 18 world", _t_phase18_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P17"):
		_run("phase 17 units", _t_phase17_units)
		await _run_async("phase 17 world", _t_phase17_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P16"):
		_run("phase 16 units", _t_phase16_units)
		await _run_async("phase 16 world", _t_phase16_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P15"):
		_run("phase 15 units", _t_phase15_units)
		await _run_async("phase 15 world", _t_phase15_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P14"):
		_run("phase 14 units", _t_phase14_units)
		await _run_async("phase 14 world", _t_phase14_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P13"):
		_run("phase 13 units", _t_phase13_units)
		await _run_async("phase 13 world", _t_phase13_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P11"):
		await _run_async("phase 11", _t_phase11_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	if OS.has_environment("ONLY_P10"):
		_run("phase 10 units", _t_phase10_units)
		await _run_async("phase 10 world", _t_phase10_world)
		print("\n==== %d passed, %d failed ====" % [passes, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
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
	_run("phase 10 units: 10,000-tree manifest deterministic/unique/clustered, ruleset labels + unknown rulesets refused, share conservation incl. future 1.5x sections, contribution dedupe, audio event inventory", _t_phase10_units)
	await _run_async("phase 10 world: standard ruleset = 10,000 natives + 5 employees + $4,500 + $1,500/day once, excluded trees untargetable, legacy load unchanged, deadline race, ruleset saved", _t_phase10_world)
	await _run_async("phase 11: camper +25% area/safety/entrance, desk computer hosts cameras (relay at desk, tile click, sit/glance/stand, save standing), TV entertainment only, five distinct employees with real hands, dog anatomy, in-place pixel style", _t_phase11_world)
	await _run_async("phase 12: island r2 exact 10,000 native records (unique, cohorts, low boughs, hashes), legacy islands untouched, removal clears every LOD, rocks supported, 62 rock hides with exits, geometric hide sight + bounded soft cover, lost contact vs seen entry, save island identity, undergrowth presets keep thickets, mocap clips, proper fabrics", _t_phase12_world)
	_run("phase 13 units: plan v2 conserves $100 and 1 tree-eq per tree with fewer, longer pieces (bounded by two hand loads), old rulesets keep plan v1, save schema 9 + yard summary", _t_phase13_units)
	await _run_async("phase 13 world: cradle intake pays once, full cradle refuses unpaid, deck delivery, yard moves, fire pile cap, mid-move reload, burn, old queue migrates once, cart partial unload + pose, drag", _t_phase13_world)
	_run("phase 14 units: axes 1.00/1.40/1.96 per hit at one cadence (output unchanged), Hard-working x1.25 once, gear factors exact and smaller than a tier step, saw 3-5x with no work in the air or during the start, frame-rate/hitch-proof, legacy axes mapped once, tier replacement, one owner, supplier quote/warnings/idempotent order/schedule/collect once/refund once/stock limit, schema 10", _t_phase14_units)
	await _run_async("phase 14 world: player saw cuts only real wood, sky = zero, hide/axe stop the saw, worker gear changes only between jobs, worker saw start/stop, fall lanes cost routes and release, team break keeps one cargo owner, parcel locker collects once", _t_phase14_world)
	_run("phase 15 units: 200+ original sources all bound (60/25/25/45/20/25), no missing files, routing valid, loops use loop sources, hop rule (world only reaches mics), per-category occlusion + room buses", _t_phase15_units)
	await _run_async("phase 15 world: one listener, one sound per contact, debounce, travel delay frozen by pause, loop lifecycle (owner freed/stop), saw loops end on kill, per-source occlusion indoor vs outdoor, door portal, mute keeps world evidence, replay never becomes live evidence", _t_phase15_world)
	_run("phase 16 units: merit conserved per stage (fell/section/stump/transport/receive <= 1,000 per tree), shared work split, boss bucket, no repeat/circling/shuffle farming, saw = axe merit, levels 1-20 + capped skills, one multiplier order, stable profiles, praise once, rest curves (early/late/repeated/recovery), idempotent sleep, five-cycle hunt rest bounded", _t_phase16_units)
	await _run_async("phase 16 world: worker/boss felling merit split, read-only review, profile survives save/restore, acceptance remainder once, idle causes, rest debuffs reach the real tool/walk effects and leave the camper safe, schema 11 migration", _t_phase16_world)
	_run("phase 17 units: crew bank >= 1,200 lines (>= 100 per category, >= 150 per starting worker, responses resolve), feed bank >= 5,500 units within kind minimums, 80+ accounts, publication: early sleep = live reading by day end, reload/refresh never republish or reroll, nightly cap, replies after visible parents, quotes never spoil, cl01 falls back safely", _t_phase17_units)
	await _run_async("phase 17 world: two workers converse from the bank with turn re-checks, knowledge gates (told vs firsthand), rumor transfer, missing listener / departed / interrupted / chainsaw suppression, boss replies, cooldowns survive save/restore, feed publishes by the real clock and the reader builds", _t_phase17_world)
	_run("phase 18 units: every required line/profile mapping has an imported clip (character lines -> own profile, shared lines -> each selectable profile), sampled clips decode at their manifest length, deliveries valid, replacement voices persistent, internet unvoiced", _t_phase18_units)
	await _run_async("phase 18 world: a voiced turn plays from the speaker's head with synced caption and mouth motion, interruption stops audio + mouth, missing clip keeps text, boss reply voiced, no doubled playback", _t_phase18_world)
	_run("phase 19 units: 120 offshore lines with stable ids, triggers, knowledge, cooldowns; visit schedule every 3 days from day 3", _t_phase19_units)
	await _run_async("phase 19 world: survival cover (thickets, sheds, chest, clearance, region audit, seen/unseen entries, escapes, dog, hunt timing); offshore lap, 2:1 speed, visibility, helicopter launch/clearance/recovery/rotor, save/load, repeat visit, witnesses, fall-warning precedence, Day 36 independence; camp routine and schema 13", _t_phase19_world)
	await _run_async("phase 6: exposure/catch arbitration, director pacing/cleanup, success never hunts, abandonment, hunt clock, Foreman rules, save v7", _t_phase6_world)
	print("\n==== %d passed, %d failed ====" % [passes, failures])
	DirAccess.make_dir_recursive_absolute("user://test_reports")
	var f := FileAccess.open("user://test_reports/last_run.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_log))
	get_tree().quit(1 if failures > 0 else 0)


func _run(name: String, f: Callable) -> void:
	var r: Variant = f.call()
	# A script error aborts the test function and yields null: that is a
	# failure, never a silent pass.
	_report(name, "aborted by a script error (see log)" if r == null else str(r))


func _run_async(name: String, f: Callable) -> void:
	var r: Variant = await f.call()
	_report(name, "aborted by a script error (see log)" if r == null else str(r))
	await get_tree().process_frame
	var left := 0
	for c in get_children():
		if c is IslandWorld and not c.is_queued_for_deletion():
			left += 1
	if left > 0:
		print("WORLD LEAK after '%s': %d world(s) still alive" % [name.substr(0, 40), left])
		for c in get_children():
			if c is IslandWorld:
				print("  LEAKED ", c.name, " id=", c.get_instance_id(), " player=", (c as IslandWorld).build_player, " ui=", (c as IslandWorld).build_ui, " kids=", c.get_child_count(), " first=", c.get_children().slice(0, 6).map(func(x): return str(x.name)))


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
	# Procedural walk (fallback clip): fixed 1 s cycle, stance phase 0..0.62.
	var proc := "walk_proc" if h.anim.has_animation("walk_proc") else "walk"
	h.play(proc, 0.0)
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
	if worst > 0.025:
		h.queue_free()
		return "procedural walk: stance foot height error %.3f m" % worst
	if worst_speed > 0.2:
		h.queue_free()
		return "procedural walk: stance foot speed error %.2f m/s (stride/speed mismatch)" % worst_speed
	# Phase 12 motion-capture walk: stance windows come from the clip's own
	# foot plants; the planted foot stays at ankle height and slides back
	# under the body at this body's nominal walk speed (no foot skating).
	if proc == "walk_proc":
		h.play("walk", 0.0)
		var clip_len := h.anim.get_animation("walk").length
		var cs: Array = h._contacts.get("walk", [])
		var worst_h := 0.0
		var speeds: Array[float] = []
		for ci in cs.size():
			var c: Array = cs[ci]
			var nxt: Array = cs[(ci + 1) % cs.size()]
			var span := fposmod(float(nxt[0]) - float(c[0]), clip_len)
			var foot_name := "FootL" if int(c[1]) == 0 else "FootR"
			var pz := INF
			for k in 8:
				var t := fposmod(float(c[0]) + span * (0.15 + 0.6 * k / 7.0), clip_len)
				h.anim.seek(t, true)
				var fp: Vector3 = h.bones[foot_name].global_position
				worst_h = maxf(worst_h, absf(fp.y - h.ankle_h))
				if pz != INF:
					speeds.append((fp.z - pz) / (span * 0.6 / 7.0))
				pz = fp.z
		var mean := 0.0
		for v in speeds:
			mean += v
		mean /= maxf(speeds.size(), 1)
		if worst_h > 0.06:
			h.queue_free()
			return "mocap walk: stance foot height error %.3f m" % worst_h
		if absf(mean - h.walk_nominal) > 0.3:
			h.queue_free()
			return "mocap walk: stance foot slides at %.2f m/s, nominal %.2f (skating)" % [mean, h.walk_nominal]
	h.queue_free()
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
		# Phase 13: accepted logs wait in the yard; the fire burns only what
		# is carried to its loading pile.
		if Game.yard:
			var g2 := 0
			while not Game.yard.cradle.is_empty() and g2 < 64:
				g2 += 1
				var ys := Game.yard.take_from_cradle("player", 100000)
				if ys == "" or not Game.yard.load_pit("player", ys):
					err = "could not move the yard logs to the fire (%s)" % Game.yard.last_reason
					break
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
	w.grant(e.price("medium") + 10000, "test", "T", "cash")
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
		if err == "" and (int(mig.get("schema", 0)) != SaveService.SCHEMA_VERSION or not mig.has("phase8")):
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
	if hc.action != "" or not hc.current.begins_with("walk"):
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


# ---------------------------------------------------------------- Phase 10

func _t_phase10_units() -> String:
	World.ensure_loaded()
	var ex := Ruleset.excluded_ids("standard_10k")
	if World.tree_count() - ex.size() != 10000:
		return "standard manifest has %d natives" % (World.tree_count() - ex.size())
	var ids := {}
	for i in World.tree_count():
		var id := int(World.trees.id[i])
		if ids.has(id):
			return "duplicate tree id %d" % id
		ids[id] = true
	for id in ex:
		if not ids.has(int(id)):
			return "excluded id %d is not an original tree" % int(id)
	# Deterministic: a fresh computation gives the same set.
	Ruleset._excluded_cache.clear()
	var t0 := Time.get_ticks_msec()
	var ex2 := Ruleset.excluded_ids("standard_10k")
	print("P10: standard 10,000-tree manifest computed in %d ms" % (Time.get_ticks_msec() - t0))
	if ex2.size() != ex.size():
		return "manifest selection not deterministic"
	for id in ex:
		if not ex2.has(id):
			return "manifest selection not deterministic"
	# Clusters stay dense: kept trees have more neighbours on average than removed ones.
	var kept_n := 0.0
	var gone_n := 0.0
	var kc := 0
	var gc := 0
	for i in range(0, World.tree_count(), 7):
		var p := Vector2(World.trees.x[i], World.trees.z[i])
		var c := 0
		for j in range(maxi(i - 400, 0), mini(i + 400, World.tree_count())):
			if j != i and p.distance_to(Vector2(World.trees.x[j], World.trees.z[j])) < 12.0:
				c += 1
		if ex.has(int(World.trees.id[i])):
			gone_n += c
			gc += 1
		else:
			kept_n += c
			kc += 1
	if gc > 0 and kept_n / maxf(kc, 1) <= gone_n / gc:
		return "thinning removed clustered trees instead of loners"
	# Rulesets and labels.
	if not Ruleset.known("expanded_v1") or Ruleset.known("expanded_v99"):
		return "ruleset registry wrong"
	var std := Ruleset.get_def(Ruleset.STANDARD)
	if int(std.native_total) != 10000 or int(std.starting_employees) != 5 or int(std.start_cash_cents) != 450000 or not bool(std.section_length_active) or str(std.get("section_plan", "")) != "v2" or bool(Ruleset.get_def(Ruleset.PHASE10).section_length_active) or bool(Ruleset.get_def(Ruleset.PHASE12).section_length_active):
		return "standard ruleset parameters wrong: %s" % str(std)
	var old := SaveService.summarize({"schema": SaveService.SCHEMA_VERSION, "campaign": {"phase3": true, "day": 7}})
	if not str(old.status).begins_with("Legacy 12,000-tree contract"):
		return "old save not labelled legacy: %s" % str(old.status)
	var future := SaveService.summarize({"schema": SaveService.SCHEMA_VERSION, "campaign": {"phase3": true, "ruleset": {"id": "expanded_v99"}}})
	if not bool(future.get("too_new", false)):
		return "unknown ruleset not refused"
	# Share conservation for many tree sizes, now and with 1.5x sections.
	for n in [1, 2, 3, 4, 5, 7, 9, 12]:
		for mult in [1.0, 1.5]:
			var k := TimberService.section_count_for(n, mult)
			var w := PackedFloat64Array()
			for q in k:
				w.append(1.0 + 0.37 * q + 0.11 * n)
			var cents := TimberService.allocate(w, TimberService.TREE_CENTS)
			var sum := 0
			for c in cents:
				sum += c
			if sum != 10000:
				return "shares for %d pieces (x%.1f) sum to %d cents" % [k, mult, sum]
	if TimberService.section_count_for(3, 1.5) != 2 or TimberService.section_count_for(1, 1.5) != 1:
		return "1.5x section count wrong"
	# Contributions: one credit per item stage, repeated handling earns nothing.
	var cb := Contributions.new()
	cb.stage("EMP-01", "accepted", "T5_S0")
	cb.stage("EMP-02", "accepted", "T5_S0")
	cb.stage("EMP-01", "accepted", "T5_S0")
	if int(cb.per_worker["EMP-01"].accepted) != 1 or cb.per_worker.has("EMP-02") or cb.rejected_repeats != 2:
		return "contribution dedupe failed"
	var inv := AudioEvents.inventory()
	if not (inv.files_missing as Array).is_empty():
		return "audio events reference missing files: %s" % str(inv.files_missing)
	if int(inv.get("missing", 0)) < 5:
		return "reserved (missing) audio events not recorded"
	return ""


func _t_phase10_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "standard_10k"
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
	for i in 30:
		await get_tree().physics_frame
	if World.native_total() != 10000:
		err = "native total %d" % World.native_total()
	var c := cs.contract.counts()
	if err == "" and (int(c.total_trees) != 10000 or int(c.standing) != 10000):
		err = "contract counts %s" % str(c)
	if err == "" and str(cs.ruleset.id) != "expanded_v1":
		err = "new campaign ruleset %s" % str(cs.ruleset.id)
	if err == "" and cs.payroll.employees.size() != 5:
		err = "starting employees %d" % cs.payroll.employees.size()
	var ids := {}
	for e in cs.payroll.employees:
		ids[str(e.id)] = true
	if err == "" and ids.size() != 5:
		err = "starting employees not unique"
	if err == "" and world.crew.workers.size() != 5:
		err = "worker bodies %d" % world.crew.workers.size()
	var beds := {}
	for e in cs.payroll.employees:
		beds[int(e.get("bed", 0))] = true
	if err == "" and (beds.size() != 5 or beds.has(0)):
		err = "beds not unique: %s" % str(beds.keys())
	var cash_tx := cs.wallet.transactions.filter(func(tx: Dictionary) -> bool: return str(tx.kind) == "start")
	if err == "" and (cash_tx.is_empty() or int(cash_tx[0].amount) != 450000):
		err = "starting cash wrong"
	if err == "" and cs.payroll.todays_estimate() != 150000:
		err = "full-crew payroll estimate %d" % cs.payroll.todays_estimate()
	# Wages for five settle once per day, even if settlement is asked twice.
	var w0 := cs.wallet.cash
	cs.payroll.settle_day(cs.clock.day)
	var w1 := cs.wallet.cash
	cs.payroll.settle_day(cs.clock.day)
	if err == "" and (w0 - w1 != mini(150000, w0) or cs.wallet.cash != w1):
		err = "five-worker settlement wrong or repeated (%d -> %d -> %d)" % [w0, w1, cs.wallet.cash]
	# Excluded trees: never rendered/collidable/targeted/located.
	var any_ex := -1
	for id in World.excluded_trees:
		any_ex = int(id)
		break
	if err == "" and not World.removed_trees.has(any_ex):
		err = "excluded tree still present"
	var near := ContractLocator.nearest(world.player.global_position)
	if err == "" and near.has("tree"):
		for i in World.tree_count():
			if World.excluded_trees.has(int(World.trees.id[i])) and World.tree_position(i).distance_to(near.tree) < 0.01:
				err = "locator points at a tree outside the manifest"
				break
	# Ruleset travels with the save.
	var st := SaveService.capture_state(world)
	if err == "" and str((st.campaign as Dictionary).get("ruleset", {}).get("id", "")) != "expanded_v1":
		err = "ruleset not saved"
	# Deadline race: completion at the boundary wins once; close cannot flip it.
	cs.clock.day = 30
	cs.clock.t = WorkdayClock.NIGHT_AT - 0.5
	cs.contract.scope_override = 0
	var outs: Array = []
	var cb := func(s: String, _o: String) -> void: outs.append(s)
	cs.contract.outcome.connect(cb)
	cs.contract.evaluate()
	cs.contract._close_deadline()
	cs.contract.evaluate()
	cs.contract.outcome.disconnect(cb)
	if err == "" and (outs != [ContractService.FULFILLED] or cs.contract.state != ContractService.FULFILLED):
		err = "boundary completion outcomes %s / state %s" % [str(outs), cs.contract.state]
	cs.contract.scope_override = -1
	cs.test_route = false
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.excluded_trees.clear()
	World.manifest_variant = "full"
	Game.mode = Game.Mode.MENU
	return err


# ---------------------------------------------------------------- Phase 11

func _t_phase11_world() -> String:
	var ratio := CampLayout.camper_usable_area() / (CampLayout.CAMPER_V1_SIZE.x * CampLayout.CAMPER_V1_SIZE.z)
	if ratio < 1.22 or ratio > 1.28:
		return "camper area ratio %.3f (want ~1.25)" % ratio
	if DeskComputer.tile_at(Vector2(10, 10), Vector2(1600, 900)) != 0 or DeskComputer.tile_at(Vector2(1590, 890), Vector2(1600, 900)) != 3 or DeskComputer.tile_at(Vector2(5, 450), Vector2(2000, 900)) != -1:
		return "desk tile mapping wrong"
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
	var camper := world.camp.find_child("Camper", false, false) as Node3D
	var F := CampLayout.CAMPER_FLOOR
	# Safety covers the whole new lounge (desk corner included); outside the
	# new front wall it does not come from the camper.
	var desk_pt := camper.global_transform * Vector3(-1.0, F + 1.0, CampLayout.CAMPER_SOUTH_Z - 0.3)
	var q: Dictionary = world.safety.query(desk_pt)
	if not bool(q.safe) or str(q.get("zone", "")) != "camper":
		err = "desk corner not inside the camper safety zone: %s" % str(q)
	var outside := camper.global_transform * Vector3(-1.0, F + 1.0, CampLayout.CAMPER_SOUTH_Z + 0.8)
	if err == "" and str(world.safety.query(outside).get("zone", "")) == "camper":
		err = "camper safety leaks outside the new front wall"
	# Entrance and dog route unchanged: door still at local z 2.3.
	var door := camper.find_child("CamperDoor", false, false) as Node3D
	if err == "" and (door == null or absf(door.position.z - 2.3) > 0.001):
		err = "camper door moved"
	# Desk computer hosts the live cameras; TV is entertainment only.
	var wall := world.tv
	if err == "" and not wall.hosted:
		err = "camera wall still on the TV"
	if err == "" and not wall.speaker.get_parent().is_in_group("camper_monitor"):
		err = "camera relay not at the desk"
	if err == "" and (world.tv_set == null or world.tv_set.screen == null or world.tv_set.screen == wall.screen):
		err = "entertainment TV not separate"
	var desk := world.desk
	if err == "" and (desk == null or desk.monitor == null):
		err = "desk computer missing"
	# Both live displays keep their own quad (static batching must not merge
	# them into a plain mesh, which renders a blank glossy panel).
	if err == "" and (desk.screen.mesh == null or world.tv_set.screen.mesh == null):
		err = "a display quad was batched away (blank screen)"
	if err == "" and not (desk.screen.material_override is ShaderMaterial and world.tv_set.screen.material_override is ShaderMaterial):
		err = "display quad lost its live material"
	# Sit, glance, click a tile, stand behind the chair.
	var p: Player = world.player
	var seat := WorldGroups.of(world, "desk_seat")[0] as Node3D
	p.sit_on_couch(seat)
	for i in 30:
		await get_tree().process_frame
	if err == "" and (not p.at_desk or not desk.seated):
		err = "sitting at the desk failed"
	wall.force_active = true
	wall.set_mode("quad")
	desk.open_app("Cameras")
	for i in 5:
		await get_tree().process_frame
	var want: int = wall.tiles[3]
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	var fs: Vector2 = desk._feed.size
	var fw := minf(fs.x, fs.y * 16.0 / 9.0)
	ev.position = fs * 0.5 + Vector2(fw * 0.25, fw * 9.0 / 16.0 * 0.25)
	desk._feed_input(ev)
	if err == "" and (wall.mode != "focus" or wall.focus_index != want):
		err = "clicking tile 4 focused %s/%d (wanted %d)" % [wall.mode, wall.focus_index, want]
	wall.back_to_quad()
	var g := InputEventAction.new()
	g.action = "move_right"
	g.pressed = true
	p._couch_input(g)
	if err == "" and (not desk.glancing or desk.overlay.visible):
		err = "glance right did not hide the overlay"
	p._couch_input(g)
	var st := SaveService.capture_state(world)
	if err == "" and str(st.player.get("seat", "")) != "":
		err = "desk session not saved as standing"
	p.stand_from_couch()
	await get_tree().physics_frame
	if err == "" and (p.at_desk or desk.seated or p.couch != null):
		err = "standing up from the desk failed"
	var local := camper.global_transform.affine_inverse() * p.global_position
	if err == "" and local.z > CampLayout.CAMPER_SOUTH_Z - 0.7:
		err = "stood up into the desk (z %.2f)" % local.z
	if err == "" and not CampLayout.camper_local_inside(local, 0.0):
		err = "stood up outside the camper"
	wall.force_active = false
	# Five distinct employees with real hands; the dog's canine anatomy.
	var looks := {}
	var hairs := {}
	for k in 5:
		var a := HumanAppearance.for_employee("EMP-0%d" % (k + 1), k)
		looks[a.label] = true
		hairs[a.hair_style] = true
	if err == "" and (looks.size() != 5 or hairs.size() < 4):
		err = "employee looks not distinct (%d labels, %d hair styles)" % [looks.size(), hairs.size()]
	var wk: Worker = world.crew.workers.get("EMP-01") if world.crew.workers.has("EMP-01") else null
	if err == "" and wk and wk.body_char.appearance.label != "Marta Kell":
		err = "EMP-01 does not wear her authored look"
	if wk:
		var hand: Node3D = wk.body_char.bones["HandR"]
		var fingers := 0
		for c in hand.get_children():
			if str(c.name).begins_with("Finger"):
				fingers += 1
		if err == "" and (fingers != 4 or hand.get_node_or_null("Thumb") == null):
			err = "hand has %d fingers / thumb %s" % [fingers, str(hand.get_node_or_null("Thumb") != null)]
	if world.dog:
		var d: DogCharacter = world.dog.dog
		var hl: Node3D = d.bones["HindLowerL"]
		var has_hock := false
		for c in hl.get_children():
			if str(c.name).contains("Hock"):
				has_hock = true
		var toes := 0
		for c in (d.bones["FrontPawL"] as Node3D).get_children():
			if str(c.name).contains("Toe"):
				toes += 1
		if err == "" and (not has_hock or toes != 4):
			err = "dog anatomy: hock %s, toes %d" % [str(has_hock), toes]
	# Style switches in place.
	CharMeshKit.apply_style("pixel")
	var any_mat: StandardMaterial3D = CharMeshKit._mat_cache.values()[0]
	if err == "" and any_mat.next_pass == null:
		err = "pixel style not applied in place"
	CharMeshKit.apply_style("clean")
	if err == "" and any_mat.next_pass != null:
		err = "clean style not restored"
	world.queue_free()
	await get_tree().process_frame
	Game.mode = Game.Mode.MENU
	return err


func _t_phase12_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while not world.systems_ready and guard < 900:
		await get_tree().physics_frame
		guard += 1
	var err := await _p12_checks(world)
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	if err == "" and (World.island_revision != "r1" or World.tree_count() != 12000 or not World.shrubs.is_empty()):
		err = "switching back to the legacy island failed"
	if err == "":
		World.apply_variant("standard_10k")
		if World.native_total() != 10000 or World.island_revision != "r1":
			err = "Phase 10 standard_10k manifest changed (%d natives, %s)" % [World.native_total(), World.island_revision]
		World.removed_trees.clear()
		World.apply_variant("full")
	return err


func _p12_checks(world: IslandWorld) -> String:
	# --- exact manifest -------------------------------------------------
	if World.island_revision != "r2":
		return "preview did not load island r2"
	if World.tree_count() != 10000 or World.native_total() != 10000:
		return "island r2 has %d records / %d natives" % [World.tree_count(), World.native_total()]
	var ids := {}
	for i in World.tree_count():
		ids[int(World.trees.id[i])] = true
	if ids.size() != 10000:
		return "tree ids not unique"
	var cohorts := {}
	var v3 := 0
	var hmin := 99.0
	var hmax := 0.0
	for i in World.tree_count():
		cohorts[int(World.trees.cohort[i])] = true
		if int(World.trees.variant[i]) == 3:
			v3 += 1
		hmin = minf(hmin, float(World.trees.height[i]))
		hmax = maxf(hmax, float(World.trees.height[i]))
	if cohorts.size() != 3 or v3 < 1000 or hmax - hmin < 15.0:
		return "size/branch data too uniform: cohorts %d, low-bough %d, heights %.1f-%.1f" % [cohorts.size(), v3, hmin, hmax]
	var mh: Dictionary = World.r2_manifest.content_hashes
	if str(mh.get("trees.bin", "")) != IslandGenerator._md5(var_to_bytes(World.trees)):
		return "loaded r2 trees differ from the frozen manifest hash"
	if int(World.r2_manifest.stats.tree_count) != 10000 or int(World.r2_manifest.tree_target) != 10000:
		return "r2 manifest stats wrong"
	if Game.campaign.ruleset.is_empty() or true:
		var def := Ruleset.get_def(Ruleset.STANDARD)
		if str(def.variant) != "island_r2" or int(def.native_total) != 10000 or int(def.starting_employees) != 5:
			return "standard ruleset is not the r2 10,000-tree contract: %s" % str(def)
	# --- removal clears every LOD (low boughs belong to the tree) --------
	var veg: VegetationSystem = Game.vegetation
	var vi := -1
	for i in World.tree_count():
		if int(World.trees.variant[i]) == 3:
			vi = i
			break
	var chunk: int = World.trees.chunk[vi]
	var count_chunk := func() -> int:
		var n := 0
		for mmi in (veg.chunk_nodes[chunk] as Node).get_children():
			if mmi is MultiMeshInstance3D:
				n += (mmi as MultiMeshInstance3D).multimesh.instance_count
		return n
	var before: int = count_chunk.call()
	World.remove_tree(int(World.trees.id[vi]))
	await get_tree().process_frame
	var after: int = count_chunk.call()
	if before - after != 3:
		return "removing a low-bough tree changed %d instances (want near+mid+far = 3)" % (before - after)
	World.restore_tree(int(World.trees.id[vi]))
	# --- rocks supported, formations present ----------------------------
	var ra := PlacementValidator.audit_rocks()
	if (ra.floating as Array).size() > 0:
		return "%d r2 rocks float" % (ra.floating as Array).size()
	# --- hides --------------------------------------------------------------
	var cover: CoverService = Game.cover
	if cover == null or cover.hides.size() != (World.cover.hides as Array).size() or cover.hides.size() < 40:
		return "rock hides not built"
	for h in cover.hides:
		if not h.kind.begins_with("rock_") or h.exits.is_empty() or h.dead_end != (h.exits.size() == 1):
			return "hide %s malformed" % h.name
	# --- geometric concealment (real rays against real rock colliders) ---
	var space := world.get_world_3d().direct_space_state
	# Recess: rock behind blocks the view; gap: rock on both flanks blocks
	# the view from the sides. Both stay open along their opening(s).
	var shielded := 0
	var front_seen := 0
	for h in cover.hides:
		var eye := h.eye
		var away := -h.look_dir if h.kind == "rock_recess" else h.look_dir.cross(Vector3.UP).normalized()
		var behind := eye + away * 9.0
		behind.y = World.height_at(behind.x, behind.z) + 2.6
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(behind, eye, 1)).is_empty():
			shielded += 1
		var front := eye + h.look_dir * 6.0
		front.y = World.height_at(front.x, front.z) + 2.6
		var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(front, eye, 1))
		if hit2.is_empty() or (hit2.position as Vector3).distance_to(eye) < 0.6:
			front_seen += 1
	if shielded < cover.hides.size() * 0.9 or front_seen < cover.hides.size() * 0.75:
		return "hide geometry: shielded %d/%d, open through the opening %d/%d" % [shielded, cover.hides.size(), front_seen, cover.hides.size()]
	# --- bounded soft cover -------------------------------------------------
	var th: Dictionary = (World.cover.thickets as Array)[0]
	var c := Vector3(th.center[0], 0, th.center[1])
	c.y = World.height_at(c.x, c.z) + 0.9
	var a := c + Vector3(-10, 0.3, 0)
	if cover.transmittance(a, c) > CoverService.SEEN_T or not cover.soft_hides(a, c, false):
		return "a thicket does not conceal a still person (T=%.2f)" % cover.transmittance(a, c)
	if cover.soft_hides(c + Vector3(-3, 0.3, 0), c, false):
		return "soft cover hides someone within 4 m"
	var open_p := Vector3(World.camp_origin().x, World.camp_origin().y + 1.0, World.camp_origin().z)
	if cover.transmittance(open_p, open_p + Vector3(8, 0, 0)) < 0.99:
		return "soft cover reported in the open camp yard"
	# --- Foreman: hidden in rock, seen through the opening only ------------
	var p: Player = world.player
	var spot: HideSpot = null
	for h in cover.hides:
		if h.kind != "rock_recess":
			continue
		var behind := h.eye - h.look_dir * 9.0
		behind.y = World.height_at(behind.x, behind.z) + 2.6
		var front := h.eye + h.look_dir * 6.0
		front.y = World.height_at(front.x, front.z) + 2.6
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(behind, h.eye, 1)).is_empty() and space.intersect_ray(PhysicsRayQueryParameters3D.create(front, h.eye, 1)).is_empty() and cover.transmittance(front, h.eye) > 0.9:
			spot = h
			break
	if spot == null:
		return "no clean hide for the sight test"
	world.hunt.hunt_preview = true
	p.teleport_feet(spot.exit_point, 0.0)
	await get_tree().physics_frame
	p.hide_in(spot)
	for i in 50:
		await get_tree().physics_frame
	var f := Foreman.new()
	world.add_child(f)
	var put := func(at: Vector3) -> void:
		at.y = World.height_at(at.x, at.z)
		f.global_position = at
		var d := spot.eye - at
		f.rotation.y = atan2(-d.x, -d.z)
	put.call(spot.eye - spot.look_dir * 9.0)
	await get_tree().physics_frame
	var seen_back := f.can_see(p)
	put.call(spot.eye + spot.look_dir * 6.0)
	await get_tree().physics_frame
	var seen_front := f.can_see(p)
	var err := ""
	if seen_back or not seen_front:
		err = "Foreman sight through rock hide wrong (behind %s, front %s)" % [seen_back, seen_front]
	# Lost contact: evidence 40 m away never names this spot; a seen entry does.
	if err == "":
		f._plan_search({"pos": spot.global_position + Vector3(40, 0, 0)})
		for e in f.search_queue:
			if e.get("spot") == spot:
				err = "search named the hiding spot without evidence near it"
		f._plan_search({"pos": spot.global_position, "spot": spot})
		if err == "" and (f.search_queue.is_empty() or f.search_queue[0].get("spot") != spot):
			err = "a seen entry did not put the spot first"
	p.leave_hide()
	world.hunt.hunt_preview = false
	f.queue_free()
	if err != "":
		return err
	if p.hiding != null:
		return "could not leave the rock hide"
	# --- saves keep their island ---------------------------------------------
	var cs: CampaignService = world.campaign
	cs.new_campaign()
	if str(cs.ruleset.id) != Ruleset.STANDARD:
		return "new campaign on r2 got ruleset %s" % str(cs.ruleset.id)
	var cap: Dictionary = cs.capture_campaign()
	if str((cap.get("island", {}) as Dictionary).get("revision", "")) != "r2":
		return "save does not record its island"
	var tampered := cap.duplicate(true)
	tampered.island.trees = "0000"
	cs.restore(tampered, cs.capture_economy())
	if not cs.island_mismatch:
		return "a save naming another island was not flagged"
	cs.restore(cap, cs.capture_economy())
	if cs.island_mismatch:
		return "matching island flagged as mismatch"
	# --- undergrowth presets keep thickets ----------------------------------
	var ug: UndergrowthSystem = world.undergrowth
	var full := ug.instance_count
	var prot := 0
	for v in ug.protected:
		prot += int(v)
	ug.set_density(0.45)
	if ug.instance_count >= full or ug.instance_count < prot:
		return "density preset wrong (%d -> %d, thicket members %d)" % [full, ug.instance_count, prot]
	ug.set_density(1.0)
	if full < 30000:
		return "undergrowth too sparse (%d)" % full
	# --- motion capture --------------------------------------------------------
	var hc := HumanCharacter.new()
	hc.appearance = HumanAppearance.for_employee("EMP-01", 1)
	add_child(hc)
	await get_tree().process_frame
	for k in ["walk", "run", "sit", "sit_relaxed", "lie", "walk_proc"]:
		if not hc.anim.has_animation(k):
			hc.queue_free()
			return "clip %s missing" % k
	var steps := [0]
	hc.step.connect(func(_s: int) -> void: steps[0] += 1)
	hc.set_locomotion(1.3)
	var lo := 9.0
	for i in 180:
		hc._process(1.0 / 60.0)
		for ap in hc.ankle_positions():
			lo = minf(lo, (ap as Vector3).y - hc.global_position.y)
	hc.queue_free()
	if steps[0] < 3 or absf(lo - hc.ankle_h) > 0.02:
		return "mocap walk: %d steps in 3 s, lowest ankle %.3f (want %.3f)" % [steps[0], lo, hc.ankle_h]
	# --- proper fabrics (no denim stand-ins on furniture) ----------------------
	for m in ["blanket_red", "blanket_blue", "dog_bed", "upholstery", "sheet", "curtain_linen"]:
		var mat := BuildKit.mat(m) as StandardMaterial3D
		if mat.albedo_texture and mat.albedo_texture.resource_path.contains("denim"):
			return "%s still uses denim" % m
	if world.camp.find_child("sofa_02", true, false) == null:
		return "camper couch is not the sofa model"
	return ""


# ------------------------------------------------------------------ Phase 13

## Builds a fresh timber record for tree index `idx` with every piece placed
## in `carrier`'s hands (no physics: the ledger is what is under test).
func _p13_record_in_hands(t: TimberService, idx: int, carrier: String) -> Array:
	var id: int = World.trees.id[idx]
	t.records[id] = t._build_record(id, idx, {})
	var out := []
	for sg in t.records[id].segments:
		t.load_of(carrier).append(str(sg.sid))
		t.claims[str(sg.sid)] = carrier
		sg.state = TimberService.Seg.CARRIED
		out.append(str(sg.sid))
	return out


## Every accepted piece is in exactly one yard/fire place; nothing paid is
## in anyone's hands unless it is a recorded yard move; receipts are unique.
func _p13_conservation(t: TimberService) -> String:
	var y: YardService = Game.yard
	var places := {}
	var add := func(sid: String, where: String) -> String:
		if places.has(sid):
			return "%s is in %s and %s" % [sid, places[sid], where]
		places[sid] = where
		return ""
	for sid in y.cradle:
		var e: String = add.call(str(sid), "cradle")
		if e != "":
			return e
	for i in y.decks.size():
		for sid in y.decks[i]:
			var e: String = add.call(str(sid), "deck %d" % i)
			if e != "":
				return e
	for sid in y.moving:
		var e: String = add.call(str(sid), "moving")
		if e != "":
			return e
	for sid in t.queue:
		var e: String = add.call(str(sid), "fire pile")
		if e != "":
			return e
	for sid in t.burning:
		var e: String = add.call(str(sid), "burning")
		if e != "":
			return e
	var seen := {}
	for r in t.receipts:
		if seen.has(str(r.sid)):
			return "two receipts for %s" % str(r.sid)
		seen[str(r.sid)] = true
		var sg := t.segment(str(r.sid))
		if int(sg.state) < TimberService.Seg.ACCEPTED_QUEUED:
			return "receipted %s has unpaid state %d" % [str(r.sid), int(sg.state)]
		if int(sg.state) != TimberService.Seg.CONSUMED and not places.has(str(r.sid)):
			return "accepted %s is nowhere (state %d)" % [str(r.sid), int(sg.state)]
	for sid in places:
		if not seen.has(sid):
			return "%s sits in the yard without a receipt" % sid
	for sid in t.carried:
		if seen.has(str(sid)) and not y.is_yard_move(str(sid)):
			return "paid %s in hands without a yard move" % str(sid)
	return ""


func _t_phase13_units() -> String:
	World.removed_trees.clear()
	World.apply_variant("island_r2")
	var n1 := 0
	var n2 := 0
	var over_hand := 0
	var pieces := 0
	for j in 600:
		var idx := (j * 16) % World.tree_count()
		var a := TimberService.partition(idx, TimberService.PLAN_V1)
		var b := TimberService.partition(idx, TimberService.PLAN_V2)
		var sm := 0
		var sc := 0
		for q in b.mte:
			sm += q
			if q > TimberService.HAND_BUDGET_MTE:
				over_hand += 1
			if q > TimberService.V2_MAX_PIECE_MTE and int(b.n) < TimberService.MAX_SEGMENTS:
				return "tree %d: v2 piece %d mTE over the two-hand bound" % [idx, q]
		for q in b.cents:
			sc += q
		if sm != TimberService.TREE_MTE or sc != TimberService.TREE_CENTS:
			return "tree %d: v2 shares sum to %d mTE / %d cents" % [idx, sm, sc]
		if int(b.n) > int(a.n):
			return "tree %d: v2 has more pieces (%d) than v1 (%d)" % [idx, int(b.n), int(a.n)]
		if absf(float(b.merch_top) - float(a.merch_top)) > 1e-4:
			return "tree %d: v2 changed the merchantable length" % idx
		n1 += int(a.n)
		n2 += int(b.n)
		pieces += int(b.n)
	if float(n2) / float(n1) > 0.85:
		return "v2 not meaningfully fewer pieces (%d vs %d)" % [n2, n1]
	if over_hand == 0 or over_hand > pieces / 4:
		return "oversized pieces %d of %d (expected some, but a minority)" % [over_hand, pieces]
	# Ruleset plan selection: new standard = v2; Phase 10/12/legacy keep v1.
	if str(Ruleset.get_def(Ruleset.STANDARD).get("section_plan", "v1")) != "v2":
		return "standard ruleset does not use plan v2"
	for rid in [Ruleset.PHASE12, Ruleset.PHASE10, Ruleset.LEGACY]:
		if str(Ruleset.get_def(rid).get("section_plan", "v1")) != "v1":
			return "%s changed its plan" % rid
	# Save schema 8 -> 9 adds nothing destructive; summaries count yard stock.
	var old := {"schema": 8, "campaign": {"phase3": true, "day": 4, "ruleset": {"id": "expanded_v2"}}, "timber": {"queue": ["T1_S0"]}}
	var m := SaveService.migrate(old.duplicate(true))
	if int(m.schema) != SaveService.SCHEMA_VERSION or SaveService.SCHEMA_VERSION < 9 or (m.timber.queue as Array).size() != 1:
		return "schema 8 -> 9 migration wrong: %s" % str(m)
	var sum := SaveService.summarize({"schema": 9, "campaign": {"phase3": true, "day": 2, "ruleset": {"id": "expanded_v3"}}, "timber": {"yard": {"cradle": ["a", "b"], "decks": [["c"], [], []]}}})
	if int(sum.get("yard_pieces", -1)) != 3:
		return "save summary yard count wrong: %s" % str(sum)
	World.apply_variant("full")
	return ""


func _t_phase13_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while (Game.yard == null or Game.cart == null) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	for i in 5:
		await get_tree().physics_frame
	var err := await _p13_checks(world)
	if Game.timber:
		Game.timber.clear_all()
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	return err


func _p13_checks(world: IslandWorld) -> String:
	var t: TimberService = world.timber
	var y: YardService = Game.yard
	var cart: TimberCart = Game.cart
	if y == null or cart == null or y.decks.size() != CampLayout.YARD_DECKS.size():
		return "yard or cart not built"
	if TimberService.current_plan() != TimberService.PLAN_V2:
		return "preview of the standard island does not use plan v2"
	t.clear_all()
	var cradle_at := CampLayout.world(CampLayout.DELIVERY_RACK_POS)
	# Tall trees first: they give the oversized (draggable) pieces.
	var order := range(World.tree_count())
	order.sort_custom(func(a: int, b: int) -> bool: return float(World.trees.height[a]) > float(World.trees.height[b]))
	var next := [0]
	var fresh := func(carrier: String) -> Array:
		var sids: Array = _p13_record_in_hands(t, int(order[next[0]]), carrier)
		next[0] += 1
		return sids
	# --- 1. a whole tree delivered at the cradle pays exactly $100 ---------
	var tree1: Array = fresh.call("player")
	var rid := int(str(tree1[0]).trim_prefix("T").split("_S")[0])
	if str(t.records[rid].plan) != "v2":
		return "new record did not take plan v2"
	if tree1.size() > CampLayout.CRADLE_SLOTS:
		return "tree has more pieces (%d) than the cradle holds" % tree1.size()
	var rs := t.accept(tree1.duplicate(), "rack:player", cradle_at)
	var cents := 0
	for r in rs:
		cents += int(r.cents)
	if rs.size() != tree1.size() or cents != 10000 or not t.tree_delivered(rid):
		return "whole tree: %d of %d accepted, %d cents" % [rs.size(), tree1.size(), cents]
	for sid in tree1:
		if int(t.segment(str(sid)).state) != TimberService.Seg.ACCEPTED_STAGED or not str(sid) in y.cradle:
			return "accepted piece %s not staged in the cradle" % str(sid)
	# Idempotent: retries never pay twice.
	var nrec := t.receipts.size()
	t.accept(tree1.duplicate(), "rack:retry", cradle_at)
	if t.receipts.size() != nrec:
		return "retry created receipts"
	var err := _p13_conservation(t)
	if err != "":
		return "after intake: " + err
	# --- 2. cradle full: refused, unpaid, still in hands -------------------
	while y.cradle_free() > 0:
		var more: Array = fresh.call("player")
		t.accept(more.slice(0, mini(more.size(), y.cradle_free())), "rack:player", cradle_at)
		for sid in t.carried.duplicate():
			t.carried.erase(sid)
			t.claims.erase(sid)
			t.segment(str(sid)).state = TimberService.Seg.WORLD
	var paid_before := int(t.totals().entitlement_cents)
	var extra: Array = fresh.call("player")
	var refused := t.accept(extra.duplicate(), "rack:player", cradle_at)
	if not refused.is_empty() or int(t.totals().entitlement_cents) != paid_before or t.last_refusal == "":
		return "full cradle still accepted (%d) or gave no reason" % refused.size()
	for sid in extra:
		if int(t.segment(str(sid)).state) != TimberService.Seg.CARRIED or not str(sid) in t.carried:
			return "refused piece left the hands"
	# --- 3. delivery straight onto a deck ----------------------------------
	var on_deck := t.accept(extra.duplicate(), "deck:player", y.deck_world(0))
	if on_deck.size() != extra.size():
		return "deck delivery accepted %d of %d (%s)" % [on_deck.size(), extra.size(), t.last_refusal]
	for sid in extra:
		if int(t.segment(str(sid)).state) != TimberService.Seg.ACCEPTED_RACKED or not str(sid) in y.decks[0]:
			return "deck delivery not racked"
	err = _p13_conservation(t)
	if err != "":
		return "after deck delivery: " + err
	# --- 4. yard moves: cradle -> deck, deck -> fire pile ------------------
	var sid1 := y.take_from_cradle("player", 1000)
	if sid1 == "" or int(t.segment(sid1).state) != TimberService.Seg.ACCEPTED_MOVING or not sid1 in t.carried:
		return "take from cradle failed (%s)" % y.last_reason
	if t.accept([sid1], "rack:player", cradle_at).size() != 0:
		return "a paid piece in hands was paid again"
	if not y.place_on_deck("player", sid1, 1) or int(t.segment(sid1).state) != TimberService.Seg.ACCEPTED_RACKED or sid1 in t.carried:
		return "place on deck failed (%s)" % y.last_reason
	var sid2 := y.take_from_deck("player", 1, 1000)
	if sid2 == "" or not y.load_pit("player", sid2) or not sid2 in t.queue or int(t.segment(sid2).state) != TimberService.Seg.ACCEPTED_QUEUED:
		return "deck to fire pile failed (%s)" % y.last_reason
	# Pile cap.
	while y.pit_free() > 0:
		var s := y.take_from_cradle("player", 1000)
		if s == "":
			s = y.take_from_deck("player", 0, 1000)
		if s == "" or not y.load_pit("player", s):
			return "could not fill the fire pile (%s)" % y.last_reason
	var s_over := y.take_from_deck("player", 0, 1000)
	if s_over == "":
		s_over = y.take_from_cradle("player", 1000)
	if s_over != "" and y.load_pit("player", s_over):
		return "fire pile exceeded its cap"
	if t.queue.size() > CampLayout.PIT_QUEUE_CAP:
		return "fire pile holds %d" % t.queue.size()
	err = _p13_conservation(t)
	if err != "":
		return "after yard moves: " + err
	# --- 5. save mid-move: the piece goes back, nothing is re-paid --------
	if s_over == "":
		var spare: Array = fresh.call("player")
		t.accept(spare.slice(0, 1), "rack:player", cradle_at)
		for sid in t.carried.duplicate():
			if not y.is_yard_move(str(sid)):
				t.carried.erase(sid)
				t.claims.erase(sid)
				t.segment(str(sid)).state = TimberService.Seg.WORLD
		s_over = y.take_from_cradle("player", 1000)
	if s_over == "":
		return "no piece to hold for the save test (%s)" % y.last_reason
	var paid := int(t.totals().entitlement_cents)
	var recs := t.receipts.size()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(t.capture()))
	t.restore(snap)
	await get_tree().physics_frame
	if int(t.totals().entitlement_cents) != paid or t.receipts.size() != recs:
		return "reload changed payments"
	if s_over in t.carried or not y.moving.is_empty():
		return "mid-move piece restored in hands"
	if int(t.segment(s_over).state) not in [TimberService.Seg.ACCEPTED_STAGED, TimberService.Seg.ACCEPTED_RACKED]:
		return "mid-move piece did not return to the yard (state %d)" % int(t.segment(s_over).state)
	err = _p13_conservation(t)
	if err != "":
		return "after reload: " + err
	# --- 6. burning consumes from the pile only; yard stock blocks "ash clean"
	t.advance_burn(20000.0)
	if y.stock_count() > 0 and t.ash_clean():
		return "ash clean reported with paid logs still in the yard"
	err = _p13_conservation(t)
	if err != "":
		return "after burning: " + err
	if int(t.totals().entitlement_cents) != paid:
		return "burning changed payments"
	# --- 7. old saves: the pit backlog moves to the decks once -------------
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(t.capture()))
	var backlog := []
	for sid in legacy.yard.cradle:
		backlog.append(sid)
	for dk in legacy.yard.decks:
		for sid in dk:
			backlog.append(sid)
	legacy.queue = backlog
	legacy.erase("yard")
	t.restore(legacy)
	await get_tree().physics_frame
	if t.queue.size() > CampLayout.PIT_QUEUE_CAP or not y.migrated_queue:
		return "old queue not moved to the decks (%d left in the pile)" % t.queue.size()
	if int(t.totals().entitlement_cents) != paid or t.receipts.size() != recs:
		return "migration changed payments"
	err = _p13_conservation(t)
	if err != "":
		return "after migration: " + err
	var after_mig: Dictionary = JSON.parse_string(JSON.stringify(t.capture()))
	var q_before := t.queue.size()
	t.restore(after_mig)
	await get_tree().physics_frame
	if t.queue.size() != q_before:
		return "migration ran twice"
	# --- 8. handcart: partial unload keeps the rest on the cart -----------
	t.clear_all()
	var cart_sids: Array = fresh.call(TimberCart.CARRIER)
	while cart_sids.size() > TimberCart.MAX_PIECES:
		var sid := str(cart_sids.pop_back())
		t.load_of(TimberCart.CARRIER).erase(sid)
		t.claims.erase(sid)
		t.segment(sid).state = TimberService.Seg.WORLD
	var filler := 0
	while y.cradle_free() > 2:
		var more: Array = fresh.call("player")
		t.accept(more.slice(0, mini(more.size(), y.cradle_free() - 2)), "rack:player", cradle_at)
		for sid in t.carried.duplicate():
			t.carried.erase(sid)
			t.claims.erase(sid)
			t.segment(str(sid)).state = TimberService.Seg.WORLD
		filler += 1
		if filler > 20:
			return "could not prepare the cradle"
	var n_on := cart.load_sids().size()
	cart.global_position = cradle_at + Vector3(0, 0, 2.0)
	var unloaded := t.accept(cart.load_sids().duplicate(), "cart", cart.global_position)
	if n_on < 3 or unloaded.size() != 2 or cart.load_sids().size() != n_on - 2 or t.last_refusal == "":
		return "cart partial unload: %d on, %d accepted, %d left (%s)" % [n_on, unloaded.size(), cart.load_sids().size(), t.last_refusal]
	for sid in cart.load_sids():
		if int(t.segment(str(sid)).state) != TimberService.Seg.CARRIED or t.segment(str(sid)).receipt != "":
			return "piece left on the cart was paid or changed state"
	# Cart pose persists through the yard block.
	var park := cart.global_position
	var yard_cap: Dictionary = JSON.parse_string(JSON.stringify(t.capture()))
	cart.global_position = park + Vector3(5, 0, 0)
	t.restore(yard_cap)
	var off := Vector2(cart.global_position.x - park.x, cart.global_position.z - park.z).length()
	if off > 0.05:
		return "cart pose not restored (%.2f m off)" % off
	if cart.load_sids().size() != n_on - 2:
		return "cart load not restored"
	# --- 9. dragging: an oversized piece can be dragged, not lifted -------
	t.clear_all()
	var big := ""
	for j in range(0, World.tree_count(), 7):
		var part := TimberService.partition(j, TimberService.PLAN_V2)
		var hit := -1
		for k in (part.mte as PackedInt32Array).size():
			if int(part.mte[k]) > TimberService.HAND_BUDGET_MTE + 2:
				hit = k
				break
		if hit < 0:
			continue
		var sids: Array = _p13_record_in_hands(t, j, "player")
		big = str(sids[hit])
		for sid in sids:
			t.carried.erase(sid)
			t.claims.erase(sid)
			t.segment(str(sid)).state = TimberService.Seg.WORLD
		break
	if big == "":
		return "no oversized piece on the island"
	t.carried.append(big)
	t.claims[big] = "player"
	t.segment(big).state = TimberService.Seg.CARRIED
	var p: Player = world.player
	var at := cradle_at + Vector3(4, 0.6, 4)
	var body := t.put_down(big, at, Vector3.RIGHT, false)
	if body == null:
		return "could not set the big piece down"
	var lift := t.pick_up_for("player", body, TimberService.HAND_BUDGET_MTE, false)
	if bool(lift.ok) or not str(lift.reason).contains("Drag"):
		return "oversized piece lifted or no drag hint: %s" % str(lift)
	var drag := t.pick_up_for("player", body, TimberService.HAND_BUDGET_MTE, true)
	if not bool(drag.ok) or not t.is_dragging("player"):
		return "drag pick-up failed: %s" % str(drag)
	if p == null:
		return "no player"
	err = _p13_conservation(t)
	if err != "":
		return "after drag: " + err
	t.clear_all()
	if not y.cradle.is_empty() or not t.queue.is_empty():
		return "clear_all left yard stock"
	return ""


# ------------------------------------------------------------------ Phase 14

func _t_phase14_units() -> String:
	# --- one tool calculation: axes per contact at one cadence -------------
	var b := {}
	for t in ["small", "medium", "large"]:
		b[t] = ToolEffects.breakdown({"tool": "axe", "tier": t})
	for t in [["medium", 1.4], ["large", 1.96]]:
		if absf(float(b[t[0]].work_per_contact) / float(b.small.work_per_contact) - float(t[1])) > 0.0001:
			return "%s work per contact ratio wrong" % t[0]
		if absf(float(b[t[0]].cycle_s) - float(b.small.cycle_s)) > 0.0001:
			return "axes do not share one legal cadence"
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	for t in ["small", "medium", "large"]:
		if absf(float(b[t].work_per_second) - cfg.work_per_second(t)) > 0.0001:
			return "%s: ToolEffects (%.4f) disagrees with the tree work config (%.4f)" % [t, float(b[t].work_per_second), cfg.work_per_second(t)]
	if absf(float(b.small.work_per_second) - 1.0 / 0.95) > 0.0001:
		return "hatchet output changed from Phases 1-13"
	var hw := ToolEffects.breakdown({"tool": "axe", "tier": "large", "hard_working": true})
	if absf(float(hw.work_per_contact) / float(b.large.work_per_contact) - 1.25) > 0.0001 or absf(float(hw.cycle_s) - float(b.large.cycle_s)) > 0.0001:
		return "Hard-working not applied exactly once (output only)"
	var full := ToolEffects.breakdown({"tool": "axe", "tier": "small", "helmet": "t3", "gloves": "t3", "boots": "t3"})
	if absf(float(full.work_per_contact) - 1.06) > 0.0001 or absf(float(full.cycle_s) - 0.95 / 1.06) > 0.0001 or absf(float(full.walk_mult) - 1.09) > 0.0001:
		return "gear factors wrong: %s" % str(full)
	if float(full.work_per_second) / float(b.small.work_per_second) > float(b.medium.work_per_second) / float(b.small.work_per_second):
		return "full gear outweighs an axe tier step"
	var saw := ToolEffects.breakdown({"tool": "chainsaw"})
	var saw_g := ToolEffects.breakdown({"tool": "chainsaw", "helmet": "t3", "gloves": "t3"})
	if float(saw.vs_hatchet) < 3.0 or float(saw.vs_hatchet) > 5.0:
		return "saw outside the 3-5x band (%.2f)" % float(saw.vs_hatchet)
	if absf(float(saw_g.saw_rate) - float(saw.saw_rate)) > 0.0001 or float(saw_g.start_s) >= float(saw.start_s):
		return "saw gear: helmet/gloves must not raise loaded cutting; gloves shorten the start"
	if absf(float(ToolEffects.breakdown({"tool": "chainsaw", "hard_working": true}).saw_rate) / float(saw.saw_rate) - 1.25) > 0.0001:
		return "Hard-working not applied once to the saw"
	# --- saw engine: no work in the air, frame-rate independent, bounded --
	var m := SawMachine.new()
	m.start()
	var air := 0
	for i in 600:
		air += m.step(1.0 / 60.0, true, false)
	if air != 0 or m.state != SawMachine.S.REVVING:
		return "throttle with no contact produced %d ticks (state %s)" % [air, m.state_name()]
	var counts := []
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0, 1.0 / 20.0]:
		var mm := SawMachine.new()
		mm.start()
		var tt := 0.0
		var n := 0
		while tt < 8.0:
			n += mm.step(dt, tt > 2.0, tt > 2.0)
			tt += dt
		counts.append(n)
	if counts.max() - counts.min() > 3 or int(counts.min()) < 50:
		return "saw ticks depend on frame step: %s" % str(counts)
	var burst := SawMachine.new()
	burst.start()
	for i in 40:
		burst.step(0.05, true, true)
	var before := burst.ticks_total
	burst.step(5.0, true, true)
	if burst.ticks_total - before > 1:
		return "a 5 s hitch released %d ticks at once" % (burst.ticks_total - before)
	burst.kill()
	if burst.state != SawMachine.S.STOPPED or burst.step(0.1, true, true) != 0:
		return "kill did not stop the saw at once"
	var st := SawMachine.new()
	st.start()
	var during := 0
	for i in int(ToolEffects.SAW_START_S * 60.0) - 2:
		during += st.step(1.0 / 60.0, true, true)
	if during != 0:
		return "the start pull cut wood"
	# --- inventory: legacy axes once, one owner, tier replacement ----------
	var f := _economy_fixture()
	var w: Wallet = f[0]
	var e: Equipment = f[2]
	var legacy := {"axes": [{"id": "AXE-0001", "tier": "small", "owner": "boss", "source": "starting", "receipt": ""}, {"id": "AXE-0002", "tier": "small", "owner": "EMP-01", "source": "starting", "receipt": ""}, {"id": "AXE-0003", "tier": "large", "owner": "boss", "source": "purchase", "receipt": "TX-000009"}, {"id": "AXE-0004", "tier": "medium", "owner": "rack", "source": "issued", "receipt": ""}, {"id": "AXE-0003", "tier": "large", "owner": "boss", "source": "purchase", "receipt": "TX-000009"}], "equipped": "AXE-0003", "counter": 4}
	e.restore(legacy)
	var err := ""
	if e.items.size() != 4:
		err = "legacy axes not mapped once (%d items)" % e.items.size()
	elif e.equipped_tier() != "large" or str(e.item("AXE-0004").owner) != "storage" or str(e.kit_of("EMP-01").tier) != "small":
		err = "legacy mapping wrong: %s / %s" % [e.equipped_tier(), str(e.item("AXE-0004"))]
	if err == "":
		e.restore(e.capture())
		if e.items.size() != 4:
			err = "re-restore duplicated items"
	if err == "":
		var b1 := e.add_item("boots", "t1", "boss", "order")
		var b3 := e.add_item("boots", "t3", "boss", "order")
		e.equip("boss", str(b1.id))
		e.equip("boss", str(b3.id))
		if str(e.kit_of("boss").boots) != "t3" or absf(float(ToolEffects.breakdown(e.kit_of("boss")).walk_mult) - 1.09) > 0.0001:
			err = "boots tier did not replace (stacked?)"
		if err == "" and not bool(e.transfer(str(b3.id), "EMP-01").ok):
			err = "transfer refused"
		if err == "" and (str(e.kit_of("boss").boots) != "" or str(b3.owner) != "EMP-01"):
			err = "transfer left the boss wearing the boots"
		if err == "" and e.return_to_storage("EMP-01") != 2:
			err = "departure did not return kit to storage"
		var owners := {}
		for a in e.items:
			if owners.has(a.id):
				err = "duplicate item id %s" % a.id
			owners[a.id] = true
	# --- supplier: idempotent orders, schedule, collect once, refund once --
	if err == "":
		err = _p14_supplier(w, e, f[1], f[3])
	_free_all(f)
	if err != "":
		return err
	var mig := SaveService.migrate({"schema": 9, "economy": {"equipment": {"axes": [], "equipped": ""}}})
	if int(mig.schema) != SaveService.SCHEMA_VERSION or SaveService.SCHEMA_VERSION < 10:
		return "schema 9 -> 10 migration wrong"
	return ""


func _p14_supplier(w: Wallet, e: Equipment, p: Payroll, clock: WorkdayClock) -> String:
	var contract := ContractService.new()
	contract.state = ContractService.ACTIVE
	var sup := Supplier.new()
	sup.setup(e, w, clock, contract, p)
	p.employees = Payroll.starting_crew(5)
	for emp in p.employees:
		emp.status = Payroll.ACTIVE
	clock.restore({"day": 3, "t": 100.0, "running": true, "deadline_enabled": true})
	var err := ""
	var lines := [{"key": "chainsaw:saw", "qty": 1}, {"key": "gloves:t2", "qty": 2}]
	w.grant(GearCatalog.price("chainsaw", "saw") + 2 * GearCatalog.price("gloves", "t2") + 50000 - w.cash, "test", "T", "cash")
	var cash0 := w.cash
	var q := sup.quote(lines)
	var expect := GearCatalog.price("chainsaw", "saw") + 2 * GearCatalog.price("gloves", "t2")
	if not bool(q.ok) or int(q.total) != expect or int(q.eta.day) != 3 or float(q.eta.t) != 300.0:
		err = "quote wrong: %s" % str(q)
	if err == "" and (q.warnings as Array).is_empty():
		err = "no payroll warning when cash after < tonight's payroll (%d < %d)" % [int(q.after), int(q.tonight)]
	var r1 := sup.place(lines, "REQ-A")
	var r2 := sup.place(lines, "REQ-A")
	if err == "" and (not bool(r1.ok) or not bool(r2.get("repeat", false)) or sup.orders.size() != 1 or w.cash != cash0 - expect):
		err = "double confirm charged twice or made two orders (cash %d)" % w.cash
	if err == "":
		for id in r1.order.items:
			if not str(e.item(str(id)).owner).begins_with("order:"):
				err = "ordered item not in transit"
	# Schedule.
	if err == "":
		var a1 := sup.next_arrival(5, 200.0)
		var a2 := sup.next_arrival(5, 700.0)
		var a3 := sup.next_arrival(30, 700.0)
		if float(a1.t) != 660.0 or int(a2.day) != 6 or float(a2.t) != 300.0 or bool(a3.ok):
			err = "schedule wrong: %s %s %s" % [str(a1), str(a2), str(a3)]
	# Arrival, collection once.
	if err == "":
		clock.t = 299.0
		sup.tick()
		if str(r1.order.state) != "dispatched":
			err = "not dispatched before arrival (%s)" % str(r1.order.state)
		clock.t = 301.0
		sup.tick()
		if err == "" and str(r1.order.state) != "arrived":
			err = "not arrived on time"
		var n1 := sup.collect(str(r1.order.id))
		var n2 := sup.collect(str(r1.order.id))
		if err == "" and (n1 != 3 or n2 != 0 or e.items_of("storage").size() < 3):
			err = "collect not exactly once (%d, %d)" % [n1, n2]
	# Refund once at contract close; stock limit.
	if err == "":
		var r3 := sup.place([{"key": "boots:t1", "qty": 1}], "REQ-B")
		var c1 := w.cash
		contract.state = ContractService.ABANDONMENT
		sup.tick()
		sup.refund_undelivered()
		sup.tick()
		if not bool(r3.ok) or str(r3.order.state) != "refunded" or w.cash != c1 + GearCatalog.price("boots", "t1"):
			err = "refund not exactly once (cash %d -> %d, %s)" % [c1, w.cash, str(r3.order.get("state", ""))]
		elif bool(sup.place([{"key": "boots:t1", "qty": 1}], "REQ-C").ok):
			err = "ordered after the contract closed"
		contract.state = ContractService.ACTIVE
		var lim := sup.quote([{"key": "helmet:t1", "qty": GearCatalog.STOCK_LIMIT + 1}])
		if err == "" and bool(lim.ok):
			err = "stock limit not enforced"
	# Save round trip keeps orders/items once.
	if err == "":
		var snap: Dictionary = JSON.parse_string(JSON.stringify({"e": e.capture(), "s": sup.capture()}))
		var n_items := e.items.size()
		e.restore(snap.e)
		sup.restore(snap.s)
		if e.items.size() != n_items or sup.orders.size() != 2 or bool(sup.place([{"key": "chainsaw:saw", "qty": 1}], "REQ-A").get("repeat", false)) == false:
			err = "supplier/equipment did not round-trip idempotently"
	sup.free()
	contract.free()
	return err


func _t_phase14_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while (Game.yard == null or Game.crew == null or Game.campaign == null) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	for i in 10:
		await get_tree().physics_frame
	var err := await _p14_checks(world)
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	return err


func _p14_checks(world: IslandWorld) -> String:
	var p: Player = world.player
	var ax: AxeController = p.axe
	# --- player saw: real contact only -----------------------------------
	var o := World.camp_origin()
	var best := -1
	var bd := INF
	for i in World.tree_count():
		var d := Vector2(World.trees.x[i] - o.x, World.trees.z[i] - o.z).length()
		if d > 45.0 and d < bd and float(World.trees.radius[i]) > 0.12:
			bd = d
			best = i
	var tid: int = World.trees.id[best]
	var stand := PlacementValidator.cut_stands(best)[0]
	var base := World.tree_position(best)
	world.vegetation.update_collision_around(base)
	p.teleport(stand + Vector3(0, 1.65, 0), base + Vector3(0, 0.95, 0))
	for i in 3:
		await get_tree().physics_frame
	ax.equip_saw()
	ax.saw.start()
	for i in 120:
		ax.saw.step(1.0 / 60.0, false, false)
	var pr0 := Game.trees.progress(tid)
	var ticks := 0
	for i in 240:
		var pb := ax.probe(ToolEffects.SAW_REACH)
		var key := ax.saw_contact_key(pb)
		var n := ax.saw.step(1.0 / 60.0, true, key != "")
		for k in n:
			if ax.apply_saw_tick(pb):
				ticks += 1
	var pr1 := Game.trees.progress(tid)
	if ticks == 0 or pr1 <= pr0:
		return "saw in contact did no work (ticks %d, key %s, probe %s)" % [ticks, ax.saw_contact_key(ax.probe(ToolEffects.SAW_REACH)), str(ax.probe(ToolEffects.SAW_REACH).kind)]
	var expect := float(ax.effects().saw_rate) * ToolEffects.SAW_TICK * ticks
	var req := float(Game.trees.record(tid).required)
	if absf((pr1 - pr0) * req - expect) > 0.01 * maxf(expect, 1.0) and pr1 < 1.0:
		return "saw work %.3f vs expected %.3f" % [(pr1 - pr0) * req, expect]
	# Pointing at the sky: zero work.
	p.teleport(stand + Vector3(0, 1.65, 0), stand + Vector3(0, 30, 0))
	await get_tree().physics_frame
	var sky := ax.saw_contact_key(ax.probe(ToolEffects.SAW_REACH))
	if sky != "":
		return "pointing at the sky counted as contact (%s)" % sky
	# Interruption: hiding stops the engine at once.
	ax.saw.start()
	if Game.cover and not Game.cover.hides.is_empty():
		Game.hunt.hunt_preview = true
		var spot: HideSpot = Game.cover.hides[0]
		p.teleport_feet(spot.exit_point, 0.0)
		await get_tree().physics_frame
		p.hide_in(spot)
		if ax.saw.state != SawMachine.S.STOPPED:
			return "hiding left the saw running"
		p.leave_hide()
		Game.hunt.hunt_preview = false
	ax.equip("small")
	if ax.tool != "axe" or ax.saw.state != SawMachine.S.STOPPED:
		return "switching to the axe left the saw running"
	# --- campaign: worker gear issue/recall at safe boundaries -------------
	var cs: CampaignService = Game.campaign
	cs.start_test_route(true, true)
	var g2 := 0
	while Game.crew.workers.size() < 2 and g2 < 600:
		await get_tree().physics_frame
		g2 += 1
	if Game.crew.workers.is_empty():
		return "no crew spawned"
	var wk: Worker = Game.crew.workers.values()[0]
	var saw_item := cs.equipment.add_item("chainsaw", "saw", "storage", "test")
	wk.activity = "fell"
	var r := Game.crew.issue(str(saw_item.id), wk.id)
	if not bool(r.ok) or str(saw_item.owner) != wk.id:
		return "issue failed: %s" % str(r)
	if wk.axe_tier() == "chainsaw":
		return "tool changed mid-cut (issue must wait for a boundary)"
	var rec := Game.crew.recall(str(saw_item.id))
	if bool(rec.ok):
		return "recall allowed mid-cut"
	wk.activity = "idle"
	Game.crew.apply_pending_equip(wk)
	if wk.axe_tier() != "chainsaw" or wk.body_char.axe_rig.get_node_or_null("Axe") == null or not (wk.body_char.axe_rig.get_node("Axe") is ChainsawModel):
		return "worker did not take up the saw at the boundary (%s)" % wk.axe_tier()
	# Worker saw: no work during the start pull, then rate x tick.
	var total := 0.0
	var first_work_t := -1.0
	for i in 300:
		var wv := wk._work_step(1.0 / 60.0)
		if wv > 0.0 and first_work_t < 0.0:
			first_work_t = i / 60.0
		total += wv
	var fx := Game.crew.tool_effects(wk)
	if first_work_t < ToolEffects.SAW_START_S * 0.9 or total <= 0.0:
		return "worker saw worked during the start pull (%.2f s) or never (%.2f)" % [first_work_t, total]
	wk.activity = "move"
	wk._saw_upkeep(0.1)
	for i in 30:
		wk._saw_upkeep(0.05)
	if wk.saw.running():
		return "worker saw kept running after leaving the cut"
	if not bool(Game.crew.recall(str(saw_item.id)).ok) or str(saw_item.owner) != "storage":
		return "recall between jobs failed"
	# --- felling lanes ------------------------------------------------------
	var co: CrewCoordinator = Game.crew.coord
	var lane := co.predict_lane(best, stand)
	var tip: Vector2 = (lane.base as Vector2) + (lane.dir as Vector2) * (float(lane.len) - 1.0)
	if not CrewCoordinator.in_lane(lane, Vector3(tip.x, 0, tip.y)) or CrewCoordinator.in_lane(lane, Vector3(tip.x, 0, tip.y) + Vector3((lane.dir as Vector2).y, 0, -(lane.dir as Vector2).x) * (float(lane.half_w) + 1.0)):
		return "lane geometry wrong"
	co.register_lane(tid, wk, stand)
	if co.lane_at(Vector3(tip.x, 0, tip.y), "other") != tid:
		return "registered lane not found"
	var cell := Game.crew.nav.to_cell(tip)
	if int(Game.crew.nav.lane_refs.get(cell, 0)) <= 0:
		return "lane cells not costed for routing"
	co.clear_lane(tid)
	if int(Game.crew.nav.lane_refs.get(cell, 0)) != 0:
		return "lane cost not released"
	# --- team carry: break keeps the log with its one owner ----------------
	if Game.crew.workers.size() >= 2:
		var lead: Worker = Game.crew.workers.values()[0]
		var fol: Worker = Game.crew.workers.values()[1]
		var tr := Game.timber
		var rid := int(World.trees.id[best])
		if not tr.records.has(rid):
			tr.records[rid] = tr._build_record(rid, best, {})
		var sid := str(tr.records[rid].segments[0].sid)
		tr.load_of(lead.id).append(sid)
		tr.claims[sid] = lead.id
		tr.segment(sid).state = TimberService.Seg.CARRIED
		co.teams["TEAM-T"] = {"leader": lead.id, "follower": fol.id, "sid": sid, "state": "carry", "since": Game.crew.now()}
		lead.team = "TEAM-T"
		fol.start_team_follow("TEAM-T")
		fol.abandon("called away")
		if co.teams.has("TEAM-T") or fol.team != "" or lead.team != "" or fol.activity == "team_follow":
			return "team not broken cleanly"
		if not tr.load_of(lead.id).has(sid) or tr.load_of(fol.id).has(sid):
			return "breaking the team moved or duplicated the log"
		tr.load_of(lead.id).erase(sid)
		tr.claims.erase(sid)
		tr.records.erase(rid)
	# --- parcel locker collects the arrived order once ---------------------
	var lockers := get_tree().get_nodes_in_group("parcel_locker")
	if lockers.is_empty():
		return "no parcel locker in camp"
	cs.wallet.grant(500000, "test", "T", "cash")
	cs.clock.t = 50.0
	var po := cs.supplier.place([{"key": "helmet:t2", "qty": 1}], "REQ-W")
	if not bool(po.ok):
		return "order failed: %s" % str(po.reason)
	cs.clock.t = 305.0
	cs.supplier.tick()
	cs.supplier.tick()
	var lk: ParcelLocker = lockers[0]
	var before := cs.equipment.items_of("storage").size()
	lk.interact(p)
	lk.interact(p)
	if cs.equipment.items_of("storage").size() != before + 1:
		return "locker collected %d items (want 1)" % (cs.equipment.items_of("storage").size() - before)
	return ""


# ------------------------------------------------------------------ Phase 15

func _t_phase15_units() -> String:
	var cov := SoundBank.coverage()
	if not (cov.missing as Array).is_empty():
		return "missing sources: %s" % str(cov.missing)
	if int(cov.library) < 200:
		return "library has %d sources (< 200)" % int(cov.library)
	var lib_used := 0
	var cats := {}
	for k in SoundLibIndex.FILES:
		cats[str(SoundLibIndex.FILES[k][2])] = int(cats.get(str(SoundLibIndex.FILES[k][2]), 0)) + 1
		for id in SoundBank.EVENTS:
			if k in SoundBank.EVENTS[id].files:
				lib_used += 1
				break
	if lib_used != SoundLibIndex.FILES.size():
		return "%d library sources are not bound to any event" % (SoundLibIndex.FILES.size() - lib_used)
	if int(cats.get("work", 0)) < 60 or int(cats.get("vehicle", 0)) < 25 or int(cats.get("movement", 0)) < 25 or int(cats.get("env", 0)) < 45 or int(cats.get("domestic", 0)) < 20 or int(cats.get("horror", 0)) < 25:
		return "category budget not met: %s" % str(cats)
	for id in SoundBank.EVENTS:
		var e: Dictionary = SoundBank.EVENTS[id]
		if not SoundBank.CAL.has(str(e.get("cal", "contact"))) or not str(e.get("bus", "Work")) in Settings.BUSES:
			return "event %s has bad routing" % id
		if bool(e.get("loop", false)):
			for f in e.files:
				if not SoundBank.is_legacy(str(f)) and not bool(SoundLibIndex.FILES[f][1]):
					return "loop event %s uses one-shot %s" % [id, f]
	# Hop rule: only world-origin sounds reach microphones.
	var got := [0]
	var cb := func(_s: AudioStream, _p: Vector3, _d: float, _c: String, _l: String) -> void: got[0] += 1
	SoundEvents.listen(cb)
	var st: AudioStream = load(SoundBank.path_of("mouse_click"))
	SoundEvents.emit(st, Vector3.ZERO, 0.0, "x", "", "relay")
	SoundEvents.emit(st, Vector3.ZERO, 0.0, "x", "", "recording")
	SoundEvents.emit(st, Vector3.ZERO, 0.0, "x", "", "world")
	SoundEvents.unlisten(cb)
	if got[0] != 1:
		return "hop rule: %d deliveries (want 1, world only)" % got[0]
	# Occlusion buses exist per category, each with its own low-pass.
	for b in Settings.OCCLUDABLE:
		for k in 2:
			var i := AudioServer.get_bus_index("%s_O%d" % [b, k + 1])
			if i < 0 or not (AudioServer.get_bus_effect(i, 0) is AudioEffectLowPassFilter) or AudioServer.get_bus_send(i) != b:
				return "occlusion bus %s_O%d missing/miswired" % [b, k + 1]
	for r in Settings.ROOMS:
		if AudioServer.get_bus_index(r) < 0:
			return "room bus %s missing" % r
	return ""


func _t_phase15_world() -> String:
	# Acoustic rays see every collider in the space: a world left behind by an
	# earlier test (same camp, same spot) would put its closed door on every
	# path. Start from one world only.
	for c in get_children():
		if c is IslandWorld:
			c.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while (Game.sound == null or Game.campaign == null) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	for i in 30:
		await get_tree().physics_frame
	var err := await _p15_checks(world)
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	return err


func _p15_checks(world: IslandWorld) -> String:
	var snd: SoundService = Game.sound
	# One authoritative listener.
	var listeners := 0
	for n in get_tree().root.find_children("*", "AudioListener3D", true, false):
		if (n as AudioListener3D).is_current():
			listeners += 1
	if listeners != 1:
		return "%d current 3D listeners (want exactly 1)" % listeners
	var lis := get_viewport().get_camera_3d().global_position
	# One contact = one sound; debounce merges a burst at one spot.
	var p0 := int(snd.stats.played)
	LoggingFX.play(LoggingFX.Sound.CHOP, lis + Vector3(2, 0, 0), 0.0, {"species": 2, "dia": 0.6})
	if int(snd.stats.played) != p0 + 1:
		return "one chop played %d sounds" % (int(snd.stats.played) - p0)
	var h1 := SoundService.play("log.drop.log", lis + Vector3(3, 0, 0))
	var h2 := SoundService.play("log.drop.log", lis + Vector3(3, 0, 0.3))
	if h1 <= 0 or h2 != 0:
		return "debounce wrong (%d, %d)" % [h1, h2]
	# Travel time: a far contact waits distance/343 s; pause freezes it.
	var far := lis + Vector3(110, 0, 0)
	if SoundService.play("work.axe.buck", far) != -1:
		return "far transient not delayed"
	get_tree().paused = true
	for i in 30:
		await get_tree().process_frame
	var still := int(SoundService.active_count().delayed)
	get_tree().paused = false
	if still != 1:
		return "delay advanced while paused (%d queued)" % still
	await get_tree().create_timer(0.6).timeout
	if int(SoundService.active_count().delayed) != 0:
		return "delayed sound never arrived"
	# Loop lifecycle: owner freed -> loop gone; stop -> gone after fade.
	var owner := Node3D.new()
	world.add_child(owner)
	owner.global_position = lis + Vector3(4, 0, 0)
	var lh := SoundService.loop("tool.saw.idle", owner)
	if not SoundService.is_playing(lh):
		return "loop did not start"
	owner.queue_free()
	for i in 3:
		await get_tree().process_frame
	if SoundService.is_playing(lh):
		return "orphan loop survived its owner"
	var lh2 := SoundService.loop("fire.bed.small", lis + Vector3(4, 0, 0))
	SoundService.loop_stop(lh2, 0.05)
	await get_tree().create_timer(0.3).timeout
	if SoundService.is_playing(lh2):
		return "stopped loop still playing"
	# Saw audio: running -> loops; kill -> no loops left.
	var m := SawMachine.new()
	var sa := SawAudio.new()
	world.add_child(sa)
	sa.global_position = lis + Vector3(2, 0, 0)
	m.start()
	for i in 120:
		m.step(1.0 / 60.0, i > 100, false)
		sa.update(m, 1.0 / 60.0)
	var loops_running := snd.loops.size()
	m.kill()
	sa.update(m, 1.0 / 60.0)
	for i in 20:
		await get_tree().process_frame
	var left := 0
	for h in snd.loops:
		if (snd.loops[h] as SoundService.Voice).attach == sa:
			left += 1
	sa.queue_free()
	if loops_running < 3 or left != 0:
		return "saw loops: %d while running, %d after kill" % [loops_running, left]
	# Per-source occlusion inside the camper; door closed vs open.
	world.teleport_to("camper")
	for i in 8:
		await get_tree().physics_frame
	lis = get_viewport().get_camera_3d().global_position
	var door: Door = null
	var outside := World.camp_origin() + CampLayout.CAMPER_POS + Vector3(6.0, 1.2, 0.0)
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(lis, outside, 1))
	if not hit.is_empty() and (hit.collider as Node).get_parent() is Door:
		door = (hit.collider as Node).get_parent()
	if door == null:
		return "camper door not on the test path"
	# Aim the outside source straight through the doorway's centre (not the
	# hinge side, where the opened panel itself stands) so "open" means a
	# genuinely clear line wherever the camera spawned.
	var opening := door.global_position + door.global_basis.x * door.width * 0.5 + Vector3(0, 1.5, 0)
	var flat := Vector3(opening.x - lis.x, 0, opening.z - lis.z)
	outside = opening + flat.normalized() * 3.0 + Vector3(0, (opening.y - lis.y) / maxf(flat.length(), 0.5) * 3.0, 0)
	outside.y = maxf(outside.y, World.height_at(outside.x, outside.z) + 1.0)
	door.set_open(false, true)
	await get_tree().physics_frame
	var out_h := SoundService.loop("terror.drone.low", outside)
	var in_h := SoundService.loop("home.keyboard", lis + Vector3(0.3, -0.3, 0.4))
	for i in 4:
		await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout
	var vo: SoundService.Voice = snd.loops[out_h]
	var vi: SoundService.Voice = snd.loops[in_h]
	if vo.tier < 1 or vi.tier != 0 or vi.p.bus != "UI" or not vo.p.bus.ends_with("_O%d" % vo.tier):
		return "per-source occlusion wrong: outside tier %d (%s), inside tier %d (%s)" % [vo.tier, vo.p.bus, vi.tier, vi.p.bus]
	door.set_open(true, true)
	# Wait on physics steps and wall time (occlusion re-checks every 0.2 s of
	# real time; the panel moves in the physics step), not a frame count:
	# uncapped headless frames can pass 50 frames before either happens.
	for i in 4:
		await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout
	if vo.tier != 0:
		var seen := PackedStringArray()
		var ex: Array[RID] = []
		var cur := get_viewport().get_camera_3d().global_position
		for k in 4:
			var q := PhysicsRayQueryParameters3D.create(cur, outside, 1)
			q.exclude = ex
			var hq := space.intersect_ray(q)
			if hq.is_empty():
				break
			var c2: Node = hq.collider
			seen.append("%s/%s(%s)" % [c2.get_parent().name, c2.name, str(c2.get_meta("acoustic", "-"))])
			ex.append((c2 as CollisionObject3D).get_rid())
		var cds := PackedStringArray()
		for dd in get_tree().get_nodes_in_group("doors"):
			if str((dd as Node).name).contains("Camper"):
				var pd: Door = dd
				var phys: Transform3D = PhysicsServer3D.body_get_state(pd._panel.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
				cds.append("%s open=%s rot=%.0f phys_rot=%.0f body=%s pm=%s" % [pd.get_path(), str(pd.is_open), rad_to_deg(pd._panel.rotation.y), rad_to_deg(phys.basis.get_euler().y), pd._panel.name, str(pd.process_mode)])
		return "open door: outside source still filtered (tier %d, occ %.1f dB, portal %s, listener %s -> %s, hits %s; this door %s; doors: %s; paused %s)" % [vo.tier, vo.occ_target, str(vo.portal), str(cur), str(outside), ", ".join(seen), str(door.get_path()), " | ".join(cds), str(get_tree().paused)]
	# Around the corner from the open door: the direct line hits the wall,
	# the doorway gives the better path (sound arrives from the opening).
	var dp := door.global_position + door.global_basis.x * door.width * 0.5 + Vector3(0, 1.0, 0)
	var outward := Vector3(dp.x - lis.x, 0, dp.z - lis.z).normalized()
	var tangent := outward.cross(Vector3.UP).normalized()
	var corner_h := -1
	for sgn in [1.0, -1.0]:
		var src: Vector3 = dp + outward * 2.0 + tangent * 3.5 * sgn
		if snd.path_loss(lis, src) >= 12.0:
			corner_h = SoundService.loop("terror.drone.beating", src)
			break
	if corner_h <= 0:
		return "no around-the-corner test position (every candidate had a clear direct line)"
	if corner_h > 0:
		await get_tree().create_timer(0.6).timeout
		var vc: SoundService.Voice = snd.loops[corner_h]
		if vc.portal == Vector3.INF or vc.tier > 1:
			return "around-the-corner source not routed through the doorway (tier %d, portal %s)" % [vc.tier, str(vc.portal)]
		SoundService.loop_stop(corner_h, 0.02)
	door.set_open(false, true)
	SoundService.loop_stop(out_h, 0.02)
	SoundService.loop_stop(in_h, 0.02)
	# Muting the mix does not change world evidence (cameras/AI/recorder).
	var master := AudioServer.get_bus_index("Master")
	var was_mute := AudioServer.is_bus_mute(master)
	AudioServer.set_bus_mute(master, true)
	var e0 := SoundEvents.emitted
	var r0 := snd.recorder.size()
	SoundService.play("terror.knock.wood", lis + Vector3(5, 0, 0), {"no_delay": true})
	AudioServer.set_bus_mute(master, was_mute)
	if SoundEvents.emitted != e0 + 1 or snd.recorder.size() != r0 + 1:
		return "muted mix changed world evidence (%d emits, %d records)" % [SoundEvents.emitted - e0, snd.recorder.size() - r0]
	# Replay: desk speaker, RECORDING origin - no capture, no new records.
	var mons := get_tree().get_nodes_in_group("camper_monitor")
	if mons.is_empty():
		return "no desk monitor"
	var e1 := SoundEvents.emitted
	var r1 := snd.recorder.size()
	var t1 := float(snd.recorder[snd.recorder.size() - 1].t)
	var n := SoundService.replay(snd.recorder.duplicate(), mons[0], t1 - 60.0, t1 + 1.0)
	if n <= 0 or SoundEvents.emitted != e1 or snd.recorder.size() != r1:
		return "replay leaked into live evidence (%d played, %d emits, %d records)" % [n, SoundEvents.emitted - e1, snd.recorder.size() - r1]
	return ""



# ------------------------------------------------------------------ Phase 16

func _close(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps


func _t_phase16_units() -> String:
	# --- felling: proportional to accepted progress, never twice ---------
	var m := MeritLedger.new()
	m.on_fell(7, 0.6, "A")
	m.on_fell(7, 1.0, "B")
	if not _close(m.total("A"), 180.0) or not _close(m.total("B"), 120.0):
		return "fell split A %.1f B %.1f (want 180/120)" % [m.total("A"), m.total("B")]
	if m.on_fell(7, 1.0, "A") != 0.0 or m.on_fell(7, 0.5, "C") != 0.0:
		return "a finished felling stage awarded again"
	# A saw (big steps) and an axe (small steps) earn the same total.
	var axe := MeritLedger.new()
	for k in 50:
		axe.on_fell(1, (k + 1) / 50.0, "A")
	var saw := MeritLedger.new()
	for k in 4:
		saw.on_fell(1, (k + 1) / 4.0, "A")
	if not _close(axe.total("A"), 300.0) or not _close(saw.total("A"), 300.0):
		return "axe %.2f vs saw %.2f merit for one tree (both must be 300)" % [axe.total("A"), saw.total("A")]
	# --- sectioning shares, stump -----------------------------------------
	m.on_section(7, "0", 0.6, 1.0, "A")
	m.on_section(7, "crown", 0.4, 0.5, "B")
	m.on_section(7, "crown", 0.4, 1.0, "C")
	m.on_section(7, "crown", 0.4, 1.0, "C")
	m.on_stump(7, 1.0, "C")
	if not _close(m.total("A"), 300.0) or not _close(m.total("B"), 160.0) or not _close(m.total("C"), 140.0):
		return "section/stump split A %.1f B %.1f C %.1f" % [m.total("A"), m.total("B"), m.total("C")]
	# --- transport: only new closest approaches; circles earn nothing ----
	var sid := "T7_S0"
	var mte := 400
	var tb := 300.0 * mte / 1000.0
	m.sample_transport(sid, mte, 100.0, {"A": 1.0}, "hand")      # baseline
	m.sample_transport(sid, mte, 50.0, {"A": 1.0}, "hand")
	var a_tr := float(m.by_stage.A.get("transport", 0.0))
	if not _close(a_tr, tb * 0.85 * 0.5):
		return "half-way transport %.2f (want %.2f)" % [a_tr, tb * 0.85 * 0.5]
	for k in 30:     # walk away and back, over and over
		m.sample_transport(sid, mte, 80.0, {"A": 1.0}, "hand")
		m.sample_transport(sid, mte, 50.0, {"A": 1.0}, "hand")
	if not _close(float(m.by_stage.A.transport), a_tr):
		return "circling earned transport merit (%.2f -> %.2f)" % [a_tr, float(m.by_stage.A.transport)]
	m.sample_transport(sid, mte, 25.0, {"A": 0.5, "B": 0.5}, "team")
	m.on_loaded(sid, mte, "B")
	m.on_loaded(sid, mte, "A")
	var tr_sum := float(m.by_stage.A.transport) + float(m.by_stage.get("B", {}).get("transport", 0.0))
	m.on_accepted(sid, mte, "C", "hand")
	m.on_accepted(sid, mte, "C", "hand")
	var tr_total := 0.0
	for a in ["A", "B", "C"]:
		tr_total += float((m.by_stage.get(a, {}) as Dictionary).get("transport", 0.0))
	if not _close(tr_total, tb):
		return "transport for one share totals %.2f (want exactly %.2f)" % [tr_total, tb]
	if float(m.by_stage.C.transport) > tb * 0.5:
		return "the deliverer took most of the transport credit (%.1f of %.1f)" % [float(m.by_stage.C.transport), tb]
	if m.skill_points("B", "teamwork") <= 0.0 or m.skill_points("A", "teamwork") <= 0.0:
		return "team carry gave no teamwork skill"
	if tr_sum <= 0.0:
		return "no transport credit before delivery"
	# --- receiving: rack once, feed the rest, never twice ----------------
	m.on_receive(sid, mte, "D", "racked")
	m.on_receive(sid, mte, "D", "racked")
	m.on_receive(sid, mte, "E", "fed")
	m.on_receive(sid, mte, "E", "fed")
	if not _close(m.total("D"), 20.0) or not _close(m.total("E"), 20.0):
		return "receive split D %.1f E %.1f (want 20/20)" % [m.total("D"), m.total("E")]
	# --- a whole tree never exceeds 1,000 ---------------------------------
	var full := MeritLedger.new()
	full.on_fell(3, 1.0, "A")
	full.on_section(3, "0", 0.5, 1.0, "A")
	full.on_section(3, "crown", 0.5, 1.0, "B")
	full.on_stump(3, 1.0, "B")
	for k in 3:
		var s3 := "T3_S%d" % k
		var mm: int = [333, 333, 334][k]
		full.sample_transport(s3, mm, 90.0, {"A": 1.0}, "hand")
		full.sample_transport(s3, mm, 10.0, {"A": 1.0}, "hand")
		full.on_accepted(s3, mm, "A", "hand")
		full.on_receive(s3, mm, "B", "racked")
		full.on_receive(s3, mm, "B", "fed")
	if not _close(full.tree_total(3), 1000.0, 0.05):
		return "a fully processed tree committed %.2f merit (want 1000)" % full.tree_total(3)
	# --- the boss is recorded separately, never employee merit -----------
	var bm := MeritLedger.new()
	bm.on_fell(9, 1.0, MeritLedger.BOSS)
	if not _close(bm.total(MeritLedger.BOSS), 300.0) or bm.skills.has(MeritLedger.BOSS):
		return "boss merit not separated"
	# --- save/restore keeps commitments (no fresh budget after reload) ---
	var cp := MeritLedger.new()
	cp.restore(JSON.parse_string(JSON.stringify(m.capture())))
	if cp.on_fell(7, 1.0, "Z") != 0.0 or cp.on_accepted(sid, mte, "Z", "hand") != 0.0 or not _close(cp.total("A"), m.total("A")):
		return "restored ledger re-opened committed budgets"
	# --- levels and skills -------------------------------------------------
	if CrewProgression.career_threshold(1) != 0 or CrewProgression.career_threshold(2) != int(CrewProgression.CAREER_SCALE):
		return "career thresholds start wrong"
	for l in range(2, 21):
		if CrewProgression.career_threshold(l) <= CrewProgression.career_threshold(l - 1):
			return "career thresholds not increasing at %d" % l
		if CrewProgression.level_for(CrewProgression.career_threshold(l)) != l:
			return "level_for(threshold(%d)) wrong" % l
	if CrewProgression.level_for(1e12) != 20:
		return "career level not capped at 20"
	var pg := CrewProgression.new(MeritLedger.new())
	pg.ensure_profile("EMP-X", ["hard_working"])
	pg.merit.skills["EMP-X"] = {"cutting": 1e9, "handling": 1e9, "driving": 1e9, "teamwork": 1e9}
	if pg.cut_factor("EMP-X") > ToolEffects.MAX_SKILL or not _close(pg.cut_factor("EMP-X"), 1.20) or pg.handling_time("EMP-X") < 1.0 / ToolEffects.MAX_SKILL:
		return "skill effects not capped (cut %.2f, handling %.2f)" % [pg.cut_factor("EMP-X"), pg.handling_time("EMP-X")]
	# --- one multiplier calculation, each factor once ---------------------
	var b := ToolEffects.breakdown({"tool": "axe", "tier": "medium", "hard_working": true, "skill": 1.1, "helmet": "t2", "gloves": "t3", "fatigue": 0.9, "rest_walk": 0.9, "boots": "t1"})
	var want_wpc := 1.4 * 1.25 * 1.1 * (1.0 + float(GearCatalog.HELMET_WORK.get("t2", 0.0))) * 0.9
	var want_cyc := ToolEffects.AXE_CYCLE / (1.0 + float(GearCatalog.GLOVES_CADENCE.get("t3", 0.0)))
	if not _close(float(b.work_per_contact), want_wpc, 0.0005) or not _close(float(b.cycle_s), want_cyc, 0.0005):
		return "axe breakdown %.4f/%.4f vs %.4f/%.4f (fatigue must hit work per contact only)" % [float(b.work_per_contact), float(b.cycle_s), want_wpc, want_cyc]
	if not _close(float(b.walk_mult), (1.0 + float(GearCatalog.BOOTS_WALK.get("t1", 0.0))) * 0.9, 0.0005):
		return "walking = boots x rest expected"
	if float(ToolEffects.breakdown({"tool": "axe", "skill": 9.0}).work_per_contact) > ToolEffects.MAX_SKILL + 0.0001:
		return "ToolEffects did not clamp the skill factor"
	var sb := ToolEffects.breakdown({"tool": "chainsaw", "helmet": "t3"})
	var sb0 := ToolEffects.breakdown({"tool": "chainsaw"})
	if not _close(float(sb.saw_rate), float(sb0.saw_rate), 0.0001):
		return "a helmet changed the chainsaw rate"
	# --- profiles: once, stable, distinct ---------------------------------
	var p1 := pg.ensure_profile("EMP-A", ["timid"]).duplicate()
	var p2 := pg.ensure_profile("EMP-A", ["stronger"])
	var pg2 := CrewProgression.new(MeritLedger.new())
	if p1 != p2 or pg2.ensure_profile("EMP-A", ["timid"]) != p1:
		return "profile rerolled"
	var pr2 := CrewProgression.new(MeritLedger.new())
	pr2.restore(JSON.parse_string(JSON.stringify(pg.capture())))
	if JSON.stringify(pr2.profiles.get("EMP-A"), "", true) != JSON.stringify(p1, "", true):
		return "profile changed through save/restore"
	# --- break time: only a "pause" if work was waiting -------------------
	pg.add_time("EMP-A", "pause", 3.0)
	pg.settle_pause("EMP-A", false, "yard_full")
	pg.add_time("EMP-A", "pause", 2.0)
	pg.settle_pause("EMP-A", true)
	var dt := pg.day_time("EMP-A", pg.merit.day)
	if not _close(float(dt.get("yard_full", 0.0)), 3.0) or not _close(float(dt.get("pause", 0.0)), 2.0):
		return "break-time classification %s" % str(dt)
	# --- praise: one specific contribution, once --------------------------
	var mind := WorkerMind.with_traits(["timid"])
	var t0 := mind.trust
	pg.merit.on_fell(11, 1.0, "EMP-A")
	var ops := pg.opportunities("EMP-A")
	if ops.is_empty():
		return "no recognition opportunity after real work"
	var key := str(ops[0].key)
	var r1 := pg.praise("EMP-A", key, mind)
	var r2 := pg.praise("EMP-A", key, mind)
	if not bool(r1.ok) or bool(r2.ok) or not _close(mind.trust - t0, CrewProgression.PRAISE_TRUST, 0.0001):
		return "praise not once-only (%s / %s, trust +%.3f)" % [str(r1), str(r2), mind.trust - t0]
	if pg.merit.total("EMP-A") != 300.0:
		return "praise changed merit"
	return _p16_rest_units()


func _p16_rest_units() -> String:
	var r := RestService.new()
	# A normal workday, early sleep: fully restored.
	r.step(1200.0, false, 0.5)
	var bed := r.rest
	if bed < 55.0 or bed > 72.0:
		return "a normal 20-minute workday cost %.1f rest (want ~30-40)" % (100.0 - bed)
	var f := r.forecast()
	r.on_sleep(1)
	if not _close(r.rest, 100.0, 0.01) or not _close(float(f.morning), 100.0, 0.01):
		return "early sleep did not fully restore (%.1f)" % r.rest
	if not r.on_sleep(1).is_empty() or not _close(r.rest, 100.0):
		return "a second sleep for the same night applied again"
	# Very late (8+ min after nightfall): quality floor, capped morning.
	r.step(1200.0, false, 0.5)
	r.step(9.0 * 60.0, true, 0.0)
	var q := RestService.quality(r.late_s / 60.0)
	var late := r.on_sleep(2)
	if not _close(q, RestService.Q_FLOOR) or float(late.morning) > 70.0 + 0.01 or float(late.morning) > 45.0:
		return "very late night: Q %.2f morning %.1f" % [q, float(late.morning)]
	# Repeated late nights compound, then early nights recover in <= 2.
	var low := r.rest
	r.step(1200.0, false, 0.5)
	r.step(9.0 * 60.0, true, 0.0)
	r.on_sleep(3)
	if r.rest > low:
		return "a second late night did not compound (%.1f -> %.1f)" % [low, r.rest]
	var nights := 0
	while r.rest < 99.0 and nights < 4:
		r.step(1200.0, false, 0.5)
		r.on_sleep(4 + nights)
		nights += 1
	if nights > 2 or r.rest < 99.0:
		return "early nights took %d nights to recover (rest %.1f)" % [nights, r.rest]
	# Worst penalties: exactly 15 % walking, 20 % cutting, never below.
	r.rest = 0.0
	if not _close(r.walk_factor(), 0.85, 0.0001) or not _close(r.cut_factor(), 0.80, 0.0001):
		return "worst penalties walk %.3f cut %.3f" % [r.walk_factor(), r.cut_factor()]
	r.step(3600.0, true, 1.0)
	if r.rest < 0.0:
		return "rest went below zero"
	if r.fear_weight() < 1.0 or r.fear_weight() > 1.0 + RestService.FEAR_WEIGHT + 0.0001:
		return "fear weight out of bounds"
	r.rest = 100.0
	if r.walk_factor() != 1.0 or r.cut_factor() != 1.0:
		return "well rested still penalised"
	# Interruption hook: bounded, applied once with the night.
	var ri := RestService.new()
	ri.step(1200.0, false, 0.5)
	ri.interrupt(1, 40.0)
	ri.interrupt(1, 40.0)
	var ni := ri.on_sleep(1)
	if float(ni.morning) < 100.0 - RestService.INTERRUPT_MAX - 0.01:
		return "an interrupted night cost more than the cap"
	# Five continuous hunt cycles with real rest opportunities.
	var h := RestService.new()
	h.rest = 60.0
	var lowest := 100.0
	for c in 5:
		h.step(600.0, false, 0.6, true, false)      # moving about by day
		h.step(300.0, false, 0.0, true, true)       # sitting still / hidden
		h.step(300.0, false, 0.3, true, false)      # dusk
		h.step(150.0, true, 0.0, true, false)       # night, moving
		h.step(150.0, true, 0.0, true, true)        # night, hidden
		lowest = minf(lowest, h.rest)
		if h.rest > RestService.HUNT_CEILING + 0.001 and h.resting:
			return "hunt rest exceeded its ceiling"
	if lowest <= 0.0 or h.late_s != 0.0:
		return "five hunt cycles: lowest rest %.1f, late %.1f (hunt nights must not count as a bedtime)" % [lowest, h.late_s]
	if RestService.new().forecast().get("morning", 0.0) != 100.0:
		return "fresh service forecast wrong"
	r.free()
	ri.free()
	h.free()
	return ""


func _t_phase16_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	for c in get_children():
		if c is IslandWorld:
			c.queue_free()
	await get_tree().physics_frame
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while (Game.crew == null or Game.campaign == null or Game.rest == null) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	for i in 20:
		await get_tree().physics_frame
	var err := await _p16_checks(world)
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	return err


func _p16_checks(world: IslandWorld) -> String:
	var crew: CrewService = Game.crew
	Game.campaign.start_test_route(true, true)
	var g2 := 0
	while crew.workers.size() < 2 and g2 < 600:
		await get_tree().physics_frame
		g2 += 1
	if crew.workers.is_empty():
		return "no workers in the test route crew"
	var w: Worker = crew.workers.values()[0]
	var ml := crew.merit
	# Felling: a worker's accepted progress and the boss's are kept apart.
	var o := World.camp_origin()
	var best := -1
	var bd := INF
	for i in World.tree_count():
		var d := Vector2(World.trees.x[i] - o.x, World.trees.z[i] - o.z).length()
		if d > 50.0 and d < bd and Game.trees.state_of(int(World.trees.id[i])) == TreeService.State.STANDING:
			bd = d
			best = i
	var tid: int = World.trees.id[best]
	var req := float(Game.trees.record(tid).required)
	var stand := PlacementValidator.cut_stands(best)[0]
	var w0 := ml.total(w.id)
	var b0 := ml.total(MeritLedger.BOSS)
	Game.trees.apply_contact(tid, stand, req * 0.6, w.id)
	Game.trees.apply_contact(tid, stand, req, MeritLedger.BOSS)
	Game.trees.apply_contact(tid, stand, req, w.id)
	if not _close(ml.total(w.id) - w0, 180.0, 0.5) or not _close(ml.total(MeritLedger.BOSS) - b0, 120.0, 0.5):
		return "felling merit worker +%.1f boss +%.1f (want 180/120)" % [ml.total(w.id) - w0, ml.total(MeritLedger.BOSS) - b0]
	# The worker's cutting skill reaches the real tool effects (and nothing
	# else): kit carries the capped skill factor.
	var k := crew.kit(w)
	if not _close(float(k.skill), crew.progression.cut_factor(w.id), 0.0001):
		return "worker kit skill %.3f vs progression %.3f" % [float(k.skill), crew.progression.cut_factor(w.id)]
	# Review is read-only.
	var day := Game.campaign.clock.day
	var r1 := crew.review(w.id, day)
	var r2 := crew.review(w.id, day)
	if str(r1) != str(r2) or not _close(ml.total(w.id) - w0, 180.0, 0.5):
		return "opening the review changed something"
	# Acceptance remainder once (receipt-driven).
	var sid := "T%d_S0" % tid
	var before := ml.total(w.id)
	crew._merit_on_accepted({"sid": sid, "source": "rack:" + w.id, "mte": 300})
	var got := ml.total(w.id) - before
	crew._merit_on_accepted({"sid": sid, "source": "rack:" + w.id, "mte": 300})
	if not _close(got, 90.0, 0.5) or not _close(ml.total(w.id) - before, got, 0.001):
		return "acceptance transport merit %.1f (want 90 once)" % got
	# Save/restore: profile, merit and levels survive exactly.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(crew.capture()))
	var prof := (crew.progression.profiles[w.id] as Dictionary).duplicate()
	var tot := ml.total(w.id)
	crew.merit.restore(snap.merit)
	crew.progression.restore(snap.progression)
	if JSON.stringify(crew.progression.profiles.get(w.id), "", true) != JSON.stringify(prof, "", true) or not _close(crew.merit.total(w.id), tot, 0.001):
		return "merit/profile changed across capture/restore (%s vs %s; %.3f vs %.3f)" % [str(crew.progression.profiles.get(w.id)), str(prof), crew.merit.total(w.id), tot]
	if crew.merit.on_fell(tid, 1.0, "EMP-99") != 0.0:
		return "restored ledger re-awarded a felled tree"
	# Idle causes are logistics, not misconduct.
	var act := w.activity
	w.activity = "idle"
	w.idle_reason = "yard_full"
	var cat := crew.time_category(w)
	w.idle_reason = ""
	w.activity = act
	if cat != "yard_full":
		return "idle in a full yard classified as %s" % cat
	# Rest debuffs reach the player's real tool and walk effects once.
	var ax: AxeController = world.player.axe
	var base := ax.effects().duplicate(true)
	Game.rest.rest = 0.0
	Game.rest._after_change()
	var tired := ax.effects()
	if not _close(float(tired.work_per_contact), float(base.work_per_contact) * 0.8, 0.0005) or not _close(float(tired.cycle_s), float(base.cycle_s), 0.0001) or not _close(float(tired.walk_mult), float(base.walk_mult) * 0.85, 0.0005):
		return "rest 0: wpc %.3f/%.3f cycle %.3f/%.3f walk %.3f/%.3f" % [float(tired.work_per_contact), float(base.work_per_contact), float(tired.cycle_s), float(base.cycle_s), float(tired.walk_mult), float(base.walk_mult)]
	# The camper is still safe at zero rest.
	var camper := CampLayout.world(CampLayout.CAMPER_POS + Vector3(0, CampLayout.CAMPER_FLOOR + 1.0, -3.0))
	if not world.safety.query(camper).safe:
		return "the camper stopped being safe at zero rest"
	Game.rest.rest = 100.0
	Game.rest._after_change()
	if not _close(float(ax.effects().work_per_contact), float(base.work_per_contact), 0.0001):
		return "stale tool effects after resting"
	# A true pause stops drain.
	var rbefore := Game.rest.rest
	get_tree().paused = true
	for i in 10:
		await get_tree().process_frame
	get_tree().paused = false
	if Game.rest.rest != rbefore:
		return "rest drained during a true pause"
	# Saves: phase16 block, v10 -> v11 migration.
	var st := SaveService.capture_state(world)
	if not (st.get("phase16", {}) as Dictionary).has("rest"):
		return "save lacks phase16.rest"
	var mig := SaveService.migrate({"schema": 10, "phase8": {}, "phase6": {}, "phase5": {}})
	if int(mig.get("schema", 0)) != SaveService.SCHEMA_VERSION or not mig.has("phase16"):
		return "v10 -> v11 migration missing"
	return ""



# ------------------------------------------------------------------ Phase 17

func _t_phase17_units() -> String:
	var bank := CrewBank.get_bank()
	if not bank.problems.is_empty():
		return "crew bank problems: %s" % ", ".join(bank.problems.slice(0, 5))
	if bank.lines.size() < 1200:
		return "crew bank has %d lines (< 1,200)" % bank.lines.size()
	var cats := bank.count_by("cat")
	for c in ["cutting", "hauling", "tools", "ethic", "weather", "pair", "group", "boss", "camp", "wages", "dusk", "survival"]:
		if int(cats.get(c, 0)) < 100:
			return "crew category %s has %d lines (< 100)" % [c, int(cats.get(c, 0))]
	var spk := bank.count_by("speaker")
	for e in ["EMP-01", "EMP-02", "EMP-03", "EMP-04", "EMP-05"]:
		if int(spk.get(e, 0)) < 150:
			return "%s has %d character lines (< 150)" % [e, int(spk.get(e, 0))]
	var texts := {}
	for id in bank.lines:
		var k := str(bank.lines[id].text).to_lower().strip_edges()
		if texts.has(k):
			return "duplicate crew text %s = %s" % [id, texts[k]]
		texts[k] = id
	# --- feed bank ---------------------------------------------------------
	FeedService.load_bank()
	if not FeedService.bank_problems().is_empty():
		return "feed bank problems: %s" % ", ".join(FeedService.bank_problems().slice(0, 5))
	var kinds := {}
	for u in FeedService._bank_units:
		kinds[str(u.kind)] = int(kinds.get(str(u.kind), 0)) + 1
	var mins := {"mail": 600, "news": 900, "forum": 3200, "advisory": 400, "archive": 400}
	for k in mins:
		if int(kinds.get(k, 0)) < int(mins[k]):
			return "feed %s has %d units (< %d)" % [k, int(kinds.get(k, 0)), int(mins[k])]
	if FeedService.bank_size() < 5500:
		return "feed has %d units (< 5,500)" % FeedService.bank_size()
	if FeedService._accounts.size() < 80:
		return "only %d accounts" % FeedService._accounts.size()
	# --- publication: early sleep vs live late reading ---------------------
	var early := FeedService.new()
	var live := FeedService.new()
	var reload := FeedService.new()
	for d in range(1, 31):
		early.advance_to(float(d) * 10000.0 + 1199.0)
		early.on_day_end(d)
		for st in [0.0, 300.0, 600.0, 899.0, 1050.0, 1199.0, 1250.0, 1400.0, 1679.0]:
			live.advance_to(float(d) * 10000.0 + st)
			live.advance_to(float(d) * 10000.0 + st)     # refresh: nothing new
			live.clock += 60.0
		live.on_day_end(d)
		if d == 15:
			reload.restore(JSON.parse_string(JSON.stringify(live.capture())))
			var again := reload.advance_to(float(d) * 10000.0 + 1679.0)
			if not again.is_empty():
				return "a reload republished %d units" % again.size()
		if d > 15:
			reload.advance_to(float(d) * 10000.0 + 1199.0)
			reload.on_day_end(d)
	if early.pub.size() != live.pub.size():
		return "early sleep published %d, live reading %d by day 30" % [early.pub.size(), live.pub.size()]
	for id in early.pub:
		if not live.pub.has(id):
			return "%s published early but not live" % id
	if reload.pub.size() != live.pub.size():
		return "save/restore changed the publication (%d vs %d)" % [reload.pub.size(), live.pub.size()]
	for day in live.day_count:
		if int(live.day_count[day]) > FeedService.NIGHT_CAP:
			return "day %s published %d (> cap)" % [day, int(live.day_count[day])]
	for id in live.pub:
		var u := FeedService.unit(str(id))
		var par := str(u.get("parent", ""))
		if par != "" and (not live.pub.has(par) or float(live.pub[par]) > float(live.pub[id])):
			return "%s published before its parent %s" % [id, par]
		var q := str(u.get("quote", ""))
		if q != "" and live.pub.has(id) and not live.pub.has(q):
			return "%s quotes unpublished %s (spoiler)" % [id, q]
	if live.pub.size() < 5000:
		return "only %d units reachable by day 30 on the default path" % live.pub.size()
	# --- cl01: no desk / not night here, so it must fall back -------------
	for u in FeedService._bank_units:
		if str(u.get("hook", "")) == "cl01" and live.pub.has(str(u.id)):
			return "cl01 published without a valid reservation"
	early.free()
	live.free()
	reload.free()
	return ""


func _t_phase17_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	for c in get_children():
		if c is IslandWorld:
			c.queue_free()
	await get_tree().physics_frame
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while (Game.crew == null or Game.campaign == null or Game.feed == null) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	for i in 20:
		await get_tree().physics_frame
	var err := await _p17_checks(world)
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	return err


func _p17_checks(world: IslandWorld) -> String:
	var crew: CrewService = Game.crew
	Game.campaign.start_test_route(true, true)
	var g := 0
	while crew.workers.size() < 3 and g < 900:
		await get_tree().physics_frame
		g += 1
	if crew.workers.size() < 2:
		return "no crew"
	var talk := crew.talk
	var ws: Array = crew.workers.values()
	var a: Worker = ws[0]
	var b: Worker = ws[1]
	# Knowledge gate: a firsthand-only line is ineligible until they saw something.
	var fl := {}
	for id in talk.bank.lines:
		var ln: Dictionary = talk.bank.lines[id]
		if "saw:strange" in (ln.get("needs", []) as Array) and talk.speaker_ok(ln, a) and (ln.get("when", []) as Array).is_empty():
			fl = ln
			break
	if not fl.is_empty() and a.mind.firsthand_count() == 0 and talk.eligible(fl, a) != "needs saw:strange":
		return "a firsthand line was eligible before any evidence (%s)" % talk.eligible(fl, a)
	# Departed workers can't talk.
	var st0 := str(b.emp.status)
	b.emp.status = "departed"
	var dep_ok := talk._can_talk(b)
	b.emp.status = st0
	if dep_ok:
		return "a departed worker was eligible to talk"
	# Put two workers side by side, idle, and let a conversation start.
	var at := World.camp_origin() + Vector3(4, 0, 6)
	at.y = World.height_at(at.x, at.z)
	for w in crew.workers.values():
		(w as Worker).abandon("test")
		(w as Worker).activity = "idle"
		(w as Worker).global_position = at + Vector3(randf_range(20, 40), 0, 0)
	a.global_position = at
	b.global_position = at + Vector3(1.5, 0, 0)
	a._decide_cd = 999.0
	b._decide_cd = 999.0
	var started := false
	for k in 60:
		talk._next_try = 0.0
		talk._try_start()
		if not talk.active.is_empty():
			started = true
			break
		talk.cooldown.clear()
	if not started:
		return "no conversation started between two idle neighbours (openers %d)" % talk.bank.openers.size()
	var lines0 := int(talk.stats.lines)
	for k in 40:
		talk.clock += 3.0
		a.global_position = at
		b.global_position = at + Vector3(1.5, 0, 0)
		talk._advance()
		if talk.active.is_empty():
			break
	if int(talk.stats.lines) <= lines0:
		return "the conversation never spoke a line"
	var h: Dictionary = talk.history[talk.history.size() - 1]
	if not talk.bank.lines.has(str(h.id)):
		return "history line not from the bank"
	# A missing listener: alone, no pair/group conversation can start.
	b.global_position = at + Vector3(60, 0, 0)
	talk.active.clear()
	talk.cooldown.clear()
	var before := int(talk.stats.conversations)
	var spread := 0
	for w in crew.workers.values():
		if w != a:
			spread += 1
			(w as Worker).global_position = at + Vector3(60.0 + 30.0 * spread, 0, 30.0 * spread)
	for k in 10:
		talk._try_start()
	if int(talk.stats.conversations) != before:
		return "a conversation started with nobody nearby"
	# Interruption: start, then the listener walks away -> dropped.
	b.global_position = at + Vector3(1.5, 0, 0)
	for k in 60:
		talk.cooldown.clear()
		talk._try_start()
		if not talk.active.is_empty():
			break
	if not talk.active.is_empty():
		var dropped := int(talk.stats.dropped)
		talk._advance()
		b.global_position = at + Vector3(40, 0, 0)
		talk.clock += 30.0
		for k in 30:
			talk.clock += 2.0
			talk._advance()
		if not talk.active.is_empty() or int(talk.stats.dropped) <= dropped and int(talk.stats.lines) == lines0:
			return "an interrupted conversation carried on"
	# Rumor transfer: a firsthand witness tells a colleague -> told, not seen.
	a.mind.perceive({"id": "p17-test-stim", "kind": "test_figure", "modality": "sight", "pos": a.global_position + Vector3(10, 0, 0), "severity": 0.2, "ambiguous": true}, crew.now(), {"confidence": 0.7})
	if not fl.is_empty() and talk.eligible(fl, a) not in ["", "cooldown", "used once"] and not talk.eligible(fl, a).begins_with("when"):
		return "firsthand line still ineligible after evidence: %s" % talk.eligible(fl, a)
	b.global_position = at + Vector3(1.5, 0, 0)
	var told0 := b.mind.told_count()
	if not fl.is_empty():
		talk._speak(str(fl.id), a, [b])
		if b.mind.told_count() <= told0 or b.mind.firsthand_count() != 0 and b.mind.strongest_memory().get("id", "") == "p17-test-stim":
			return "rumor transfer wrong (told %d, firsthand %d)" % [b.mind.told_count(), b.mind.firsthand_count()]
	# Boss replies come from the bank.
	var rep := talk.boss_reply(a, "greet")
	if rep == "":
		return "no authored greeting for %s" % a.emp.name
	# Cooldowns survive save/restore.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(talk.capture()))
	var cd_n := (snap.cooldown as Dictionary).size()
	talk.restore(snap)
	if talk.cooldown.size() != cd_n or cd_n == 0:
		return "conversation cooldowns lost on restore (%d -> %d)" % [cd_n, talk.cooldown.size()]
	# Feed: the real clock publishes day-1 daytime units; the reader builds.
	var feed: FeedService = Game.feed
	var cs: CampaignService = Game.campaign
	cs.clock.day = 1
	cs.clock.t = 600.0
	feed.advance_to(feed.now_key())
	if feed.pub.is_empty():
		return "nothing published by day 1, 10 min"
	for id in feed.pub:
		if int(FeedService.unit(str(id)).get("day", 99)) > 1:
			return "a future unit (%s) published early" % id
	for app in ["Mail", "News", "Forums", "Archives"]:
		var host := Control.new()
		add_child(host)
		FeedReader.build(host, app, null)
		host.queue_free()
	var th := feed.threads("Forums", 5)
	if not th.is_empty():
		feed.positions["Forums"] = {"view": "thread", "thread": str(th[0].key), "page": 0}
		var host2 := Control.new()
		add_child(host2)
		FeedReader.build(host2, "Forums", null)
		host2.queue_free()
		if feed.unread("Forums") >= feed.pub.size():
			return "opening a thread marked nothing read"
	# Save/restore of the feed keeps publication + read state exactly.
	var fs: Dictionary = JSON.parse_string(JSON.stringify(feed.capture()))
	var npub := feed.pub.size()
	var nread := feed.read.size()
	feed.restore(fs)
	if feed.pub.size() != npub or feed.read.size() != nread:
		return "feed state changed across save/restore"
	if not feed.advance_to(feed.now_key()).is_empty():
		return "a reload republished units"
	var st := SaveService.capture_state(world)
	if not (st.get("phase17", {}) as Dictionary).has("feed"):
		return "save lacks phase17.feed"
	return ""



# ------------------------------------------------------------------ Phase 18

const P18_ROSTER_TRAITS := {"EMP-01": ["hard_working", "sociable"], "EMP-02": ["stronger", "skeptical"], "EMP-03": ["observant", "level_headed"], "EMP-04": ["timid", "reliable_driver"], "EMP-05": ["sociable", "skeptical"]}


func _p18_profiles(ln: Dictionary) -> Array:
	var sp := str(ln.get("speaker", "any"))
	if CrewBank.SPEAKER_VOICE.has(sp):
		return [CrewBank.SPEAKER_VOICE[sp]]
	var out: Array = []
	for e in ["EMP-01", "EMP-02", "EMP-03", "EMP-04", "EMP-05"]:
		if sp == "any" or (sp.begins_with("trait:") and sp.substr(6) in P18_ROSTER_TRAITS[e]):
			out.append(CrewBank.SPEAKER_VOICE[e])
	return out + ["crew_m", "crew_f"]


func _t_phase18_units() -> String:
	var bank := CrewBank.get_bank()
	var required := 0
	var missing: PackedStringArray = []
	for id in bank.lines:
		for prof in _p18_profiles(bank.lines[id]):
			required += 1
			if not VoiceBank.has(prof, str(id)):
				missing.append("%s/%s" % [prof, id])
	if not missing.is_empty():
		return "%d of %d required mappings have no clip (e.g. %s)" % [missing.size(), required, ", ".join(missing.slice(0, 4))]
	if VoiceBank.count() != required:
		return "voice index has %d clips for %d required mappings (stale entries?)" % [VoiceBank.count(), required]
	# Decode a deterministic sample of clips and compare with the manifest.
	var keys: Array = VoiceBank._clips.keys()
	keys.sort()
	var checked := 0
	for k in range(0, keys.size(), 47):
		var parts := str(keys[k]).split("/")
		var st: AudioStream = load(VoiceBank.path(parts[0], parts[1]))
		if st == null:
			return "clip %s did not load" % keys[k]
		var want := float(VoiceBank.info(parts[0], parts[1]).duration)
		if absf(st.get_length() - want) > 0.08 or st.get_length() < 0.3:
			return "clip %s decodes to %.2f s (manifest %.2f)" % [keys[k], st.get_length(), want]
		checked += 1
	if checked < 50:
		return "only %d clips sampled" % checked
	for k in keys:
		var d := str(VoiceBank._clips[k][1])
		if not d in VoiceBank.DB:
			return "clip %s has unknown delivery %s" % [k, d]
	# Replacement hires: persistent, never a roster voice.
	for eid in ["EMP-06", "EMP-07", "EMP-11", "EMP-42"]:
		var v := CrewBank.voice_of(eid)
		if v != CrewBank.voice_of(eid) or not v in ["crew_m", "crew_f"]:
			return "replacement %s got voice %s" % [eid, v]
	# The fictional internet stays text only.
	if DirAccess.dir_exists_absolute("res://audio/voice/feed"):
		return "the internet bank was voiced"
	return ""


func _t_phase18_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	for c in get_children():
		if c is IslandWorld:
			c.queue_free()
	await get_tree().physics_frame
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while (Game.crew == null or Game.campaign == null) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	for i in 20:
		await get_tree().physics_frame
	var err := await _p18_checks(world)
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	return err


func _p18_checks(world: IslandWorld) -> String:
	var crew: CrewService = Game.crew
	Game.campaign.start_test_route(true, true)
	var g := 0
	while crew.workers.size() < 2 and g < 900:
		await get_tree().physics_frame
		g += 1
	if crew.workers.size() < 2:
		return "no crew"
	var talk := crew.talk
	var a: Worker = crew.workers.get("EMP-01", crew.workers.values()[0])
	var b: Worker = crew.workers.values()[1] if crew.workers.values()[0] == a else crew.workers.values()[0]
	var at := World.camp_origin() + Vector3(4, 0, 6)
	at.y = World.height_at(at.x, at.z)
	a.global_position = at
	b.global_position = at + Vector3(1.5, 0, 0)
	Game.player.global_position = at + Vector3(0, 0, 3)
	# A character line with a clip: it plays from the speaker, the mouth moves.
	var line_id := ""
	for id in talk.bank.lines:
		var ln: Dictionary = talk.bank.lines[id]
		if str(ln.speaker) == a.id and VoiceBank.has(CrewBank.voice_of(a.id), str(id)):
			line_id = str(id)
			break
	if line_id == "":
		return "no clip for %s" % a.id
	var voiced0 := int(talk.stats.get("voiced", 0))
	talk.active = {"members": [a, b], "queue": [], "next_at": talk.clock, "gkey": "g:test", "cat": "test", "paused_at": -1.0, "turns": 0}
	talk._speak(line_id, a, [b])
	var clip_s := float(talk.active.get("clip_s", 0.0))
	await get_tree().process_frame
	if int(talk.stats.get("voiced", 0)) != voiced0 + 1:
		return "the voiced line did not play (stats %s)" % str(talk.stats)
	if not SoundService.speaking(a):
		return "no speech source playing for the speaker"
	if not a.body_char.speaking_mouth():
		return "the mouth did not move"
	var playing := 0
	for v in SoundService.instance().voices:
		if (v as SoundService.Voice).busy and str((v as SoundService.Voice).event).begins_with("voice."):
			playing += 1
	if playing != 1:
		return "%d speech voices playing (doubled playback?)" % playing
	if absf(clip_s - float(VoiceBank.info(CrewBank.voice_of(a.id), line_id).duration)) > 0.1:
		return "turn timing did not use the clip length (%.2f)" % clip_s
	talk.active = {"members": [a, b], "queue": [], "next_at": talk.clock + 99.0, "gkey": "g:test", "cat": "test", "paused_at": -1.0, "turns": 0, "speaker": a}
	# Interruption stops audio and mouth at once.
	talk._stop_current()
	await get_tree().process_frame
	if SoundService.speaking(a) or a.body_char.speaking_mouth():
		return "interrupted line kept playing or the mouth kept moving"
	talk.active.clear()
	# A missing clip keeps the text presentation and exits cleanly.
	var other := ""
	for id in talk.bank.lines:
		if str(talk.bank.lines[id].speaker) == b.id:
			other = str(id)
			break
	var miss0 := int(talk.stats.get("voiced", 0))
	if other != "" and not VoiceBank.has(CrewBank.voice_of(a.id), other):
		talk._speak(other, a, [b])          # a's profile has no clip for b's line
		if int(talk.stats.get("voiced", 0)) != miss0 or SoundService.speaking(a):
			return "a missing clip produced audio"
	SoundService.stop_speech(a)
	# Boss reply voiced (when an authored greeting exists with a clip).
	var rep := talk.boss_reply(a, "greet")
	if rep == "":
		return "no greeting"
	await get_tree().process_frame
	SoundService.stop_speech(a)
	a.body_char.stop_mouth()
	return ""


# ---------------------------------------------------------------- Phase 19

func _t_phase19_units() -> String:
	# Offshore lines: exactly the 120 authored rows, stable ids, every row
	# with trigger, knowledge class, speaker, sea: knowledge, cooldown.
	var bank := CrewBank.get_bank()
	var rows := []
	for id in bank.lines:
		var ln: Dictionary = bank.lines[id]
		if str(ln.get("cat", "")) == "offshore":
			rows.append(ln)
	if rows.size() != 120:
		return "offshore lines %d != 120" % rows.size()
	var nums := {}
	for ln in rows:
		nums[int(ln.n)] = true
		if not str(ln.id).begins_with("sea.") or str(ln.get("trigger", "")) == "" or str(ln.get("knowledge", "")) == "" or str(ln.get("rep", "")) == "":
			return "row incomplete: %s" % ln.id
		if not (ln.needs as Array).any(func(n: String) -> bool: return n.begins_with("sea:")):
			return "%s has no sea: knowledge requirement" % ln.id
	if nums.size() != 120:
		return "line numbers not 1..120"
	var trig := 0
	for k in bank.offshore:
		trig += (bank.offshore[k] as Array).size()
	if trig != 120:
		return "trigger index %d" % trig
	# Schedule data: every 3 days from day 3, ids persistent.
	var o := OffshoreSurvey.new()
	o.load_config()
	var days := []
	for d in range(1, 31):
		if o.is_visit_day(d):
			days.append(d)
	o.free()
	if days != [3, 6, 9, 12, 15, 18, 21, 24, 27, 30]:
		return "schedule %s" % str(days)
	return ""


func _t_phase19_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	for c in get_children():
		if c is IslandWorld:
			c.queue_free()
	await get_tree().physics_frame
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while (Game.crew == null or Game.campaign == null) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	for i in 20:
		await get_tree().physics_frame
	var err := await _p19_checks(world)
	if Game.offshore:
		Game.offshore.stop_preview()
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	return err


var p19_report := {}


func _p19_checks(world: IslandWorld) -> String:
	var ce := await _p19_cover()
	print("P19 COVER ", JSON.stringify(p19_report.get("cover", {})))
	if ce != "":
		return ce
	var off: OffshoreSurvey = Game.offshore
	if off == null:
		return "no offshore service"
	off.load_config()
	# --- route clears island, shoals and dock routes
	var rc := off.route_clearance()
	p19_report["route"] = rc
	if int(rc.bad_samples) > 0 or not bool(rc.routes_ok):
		return "route does not clear: %s" % str(rc)
	# --- visibility of the camp-arc silhouette at eye height
	var vis := {}
	off.preview_visit(3)
	off.enabled = false
	off.visit.state = "lap"
	off.visit.theta = off.theta_camp
	off.visit.lap = 0.3
	off._place_ship()
	await get_tree().physics_frame
	var pts := {"yard": CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(0, 0, 6)), "camp_approach": CampLayout.world(Vector3(0, 0, -24)),
		"beach_gate": CampLayout.world(Vector3(0, 0, 18)), "shoreline": Game.crew.dock_shore, "dock_end": Game.crew.dock_end}
	for k in pts:
		var eye: Vector3 = pts[k] + Vector3(0, 1.6, 0)
		eye.y = maxf(eye.y, World.height_at(eye.x, eye.z) + 1.6)
		vis[k] = off.ship_block_reason(eye)
	p19_report["visibility"] = vis
	p19_report["ship_dist_from_camp"] = snappedf(World.camp_origin().distance_to(off.ship_position()), 1.0)
	off.stop_preview()
	# --- a whole visit from logged samples
	off.preview_visit(3)
	off.enabled = false
	off.logging = true
	off.samples.clear()
	off._log_t = -1.0
	var states := {}
	var heli_states := []
	var land_err := -1.0
	var min_clear := INF
	var max_bank := 0.0
	var rotor_ok := false
	var steps := 0
	var cap := {}
	while not off.visit.is_empty() and steps < 4000:
		off.step(1.0)
		steps += 1
		if off.visit.is_empty():
			break
		states[str(off.visit.state)] = true
		var hs := off.heli.state
		if heli_states.is_empty() or heli_states[heli_states.size() - 1] != hs:
			heli_states.append(hs)
		if hs == "fly":
			min_clear = minf(min_clear, off.heli.global_position.y - off.clearance_floor(off.heli.global_position, Vector3.ZERO, 0.0))
			max_bank = maxf(max_bank, absf(off.heli.bank))
			if off.heli.rotor_handle > 0 and SoundService.instance().loops.has(off.heli.rotor_handle):
				var v: SoundService.Voice = SoundService.instance().loops[off.heli.rotor_handle]
				rotor_ok = v.attach == off.heli
		if hs == "landed" and land_err < 0.0:
			land_err = off.heli.global_position.distance_to(off.deck_transform().origin)
		if cap.is_empty() and hs == "fly" and off.heli.wp_i >= 2:
			cap = off.capture()
	var lap := off.samples.filter(func(s: Dictionary) -> bool: return str(s.state) == "lap")
	var max_dev := 0.0
	for s in lap:
		max_dev = maxf(max_dev, absf(Vector2(float(s.x), float(s.z)).distance_to(off.center) - off.R))
	var lap_total := float(lap[lap.size() - 1].lap) if not lap.is_empty() else 0.0
	var open := []
	var slow := []
	for s in lap:
		var k := off.slow_k(float(s.theta))
		if k < 0.001:
			open.append(float(s.speed))
		elif k > 0.999:
			slow.append(float(s.speed))
	open.sort()
	slow.sort()
	var ratio := float(open[open.size() / 2]) / float(slow[slow.size() / 2]) if not open.is_empty() and not slow.is_empty() else 0.0
	var dep := off.samples.filter(func(s: Dictionary) -> bool: return str(s.state) == "departing")
	var arr := off.samples.filter(func(s: Dictionary) -> bool: return str(s.state) == "arriving")
	p19_report["lap"] = {"samples": lap.size(), "max_radius_dev_m": max_dev, "lap_deg": rad_to_deg(lap_total), "lap_s": snappedf(off.lap_seconds(), 0.1),
		"open_median": open[open.size() / 2] if not open.is_empty() else 0.0, "slow_median": slow[slow.size() / 2] if not slow.is_empty() else 0.0, "ratio": snappedf(ratio, 0.001),
		"arrival_samples": arr.size(), "departure_samples": dep.size(), "steps": steps}
	p19_report["heli"] = {"states": heli_states, "land_err_m": land_err, "min_clearance_m": snappedf(min_clear, 0.1), "max_bank_deg": snappedf(rad_to_deg(max_bank), 0.1), "rotor_attached": rotor_ok,
		"outcome": str(off.visits.get("V03", {}).get("heli_outcome", ""))}
	print("P19 REPORT ", JSON.stringify(p19_report))
	if max_dev > 0.01:
		return "lap left the circle by %.3f m" % max_dev
	if absf(lap_total - TAU) > 0.0001:
		return "lap was %.3f deg" % rad_to_deg(lap_total)
	if absf(ratio - 2.0) > 0.02:
		return "speed ratio %.3f" % ratio
	if dep.is_empty() or arr.is_empty():
		return "arrival/departure legs missing"
	for s in dep.slice(int(dep.size() * 0.3)):
		if Vector2(float(s.x), float(s.z)).distance_to(off.center) <= off.R + 1.0:
			return "departure leg is not distinct from the lap"
	if not ("landed" in heli_states and "fly" in heli_states and "spool" in heli_states):
		return "heli did not launch/return: %s" % str(heli_states)
	if land_err < 0.0 or land_err > 0.05:
		return "heli landed %.3f m off the pad" % land_err
	if min_clear < 20.0:
		return "heli clearance %.1f m" % min_clear
	if not rotor_ok:
		return "rotor not a positional source attached to the aircraft"
	var e2 := await _p19_more(off, cap)
	print("P19 REPORT2 ", JSON.stringify(p19_report))
	return e2


func _p19_place(w: Worker, p: Vector3) -> void:
	p.y = World.height_at(p.x, p.z)
	w.global_position = p
	w.activity = "idle"
	w.path.clear()


func _p19_more(off: OffshoreSurvey, cap: Dictionary) -> String:
	# --- save/load mid-flight: same visit, same place, no new visit, no
	# replayed introduction (registered beats survive).
	if cap.is_empty():
		return "no mid-flight capture"
	var vid := str(cap.visit.id)
	var beats_before := (cap.visit.beats as Dictionary).keys()
	off.restore(JSON.parse_string(JSON.stringify(cap)))
	off.enabled = false
	await get_tree().physics_frame
	if off.visit.is_empty() or str(off.visit.id) != vid or off.heli == null or off.heli.state != str(cap.visit.heli.state):
		return "restore lost the visit or aircraft state"
	if (off.visit.beats as Dictionary).keys() != beats_before:
		return "restore changed registered beats"
	var p_cap: Array = cap.visit.heli.pos
	if off.heli.global_position.distance_to(Vector3(p_cap[0], p_cap[1], p_cap[2])) > 0.01:
		return "aircraft restored elsewhere"
	if absf(float(off.visit.theta) - float(cap.visit.theta)) > 1e-6:
		return "ship restored off its bearing"
	var n_before := off.visits.size()
	off._maybe_start()
	if off.visits.size() != n_before or str(off.visit.id) != vid:
		return "reload started another visit"
	# finish this visit, then a repeat visit (day 6) with a different seed
	var g := 0
	while not off.visit.is_empty() and g < 4000:
		off.step(1.0)
		g += 1
	var legs3: Array = off.plan_legs(hash("%d:%s" % [off._seed(), "V03"]))
	var legs6: Array = off.plan_legs(hash("%d:%s" % [off._seed(), "V06"]))
	off.preview_force = true
	off.start_visit(6)
	off.enabled = false
	p19_report["repeat"] = {"visits": off.visits.keys(), "n": off.visit.n, "legs_V03": legs3, "legs_V06": legs6}
	if int(off.visit.n) != 2 or not off.visits.has("V03"):
		return "repeat visit not recorded as the second"
	if legs3 == legs6:
		return "survey order did not vary between visits"
	# --- witnesses
	var crew: CrewService = Game.crew
	Game.campaign.start_test_route(true, true)
	var w8 := 0
	while crew.workers.size() < 4 and w8 < 900:
		await get_tree().physics_frame
		w8 += 1
	if crew.workers.size() < 4:
		return "no crew"
	off.visit.state = "lap"
	off.visit.theta = off.theta_camp
	off.visit.lap = 0.3
	off._place_ship()
	var ws: Array = crew.workers.values()
	var obs: Worker = ws[0]
	var hid: Worker = ws[1]
	var ear: Worker = ws[2]
	var lis: Worker = ws[3]
	_p19_place(obs, Game.crew.dock_shore)
	# Occluded: on the far (north) side of the island, behind the ridge.
	_p19_place(hid, Vector3(300, 0, -330))
	# Hearing only: inside the cabin with the aircraft overhead.
	var cab := CampLayout.world(CampLayout.CABIN_POS + Vector3(-2.2, CampLayout.CABIN_FLOOR, -4.0))
	ear.global_position = cab
	ear.activity = "idle"
	_p19_place(lis, World.camp_origin() + Vector3(3, 0, 2))
	await get_tree().physics_frame
	off.heli.set_state("fly")
	off.heli.rotor = 1.0
	off.heli.global_position = World.camp_origin() + Vector3(20, 90, 10)
	off.heli.visible = true
	await get_tree().physics_frame
	var r_obs := off.eval_worker(obs, 1.0)
	var r_hid := off.eval_worker(hid, 1.0)
	var r_ear := off.eval_worker(ear, 1.0)
	p19_report["witness"] = {"observer": [r_obs.ship, r_obs.get("ship_why", "")], "occluded": [r_hid.ship, r_hid.get("ship_why", "")], "cabin": {"ship": r_ear.ship, "heli": r_ear.heli, "rotor": r_ear.rotor}}
	if not bool(r_obs.ship):
		return "observer on the shore cannot see the hull (%s)" % str(r_obs.get("ship_why", ""))
	if bool(r_hid.ship):
		return "worker behind the ridge saw the hull"
	if not bool(r_ear.rotor) or bool(r_ear.heli):
		return "cabin worker: rotor %s heli %s (want heard, not seen)" % [r_ear.rotor, r_ear.heli]
	var talk := crew.talk
	if not off.knows("sea:saw_ship_now", obs) or off.knows("sea:saw_ship_now", hid):
		return "firsthand knowledge wrong"
	if not off.knows("sea:heard_only", ear):
		return "hearing-only knowledge wrong"
	# Firsthand lines are ineligible for the occluded worker.
	var l1: Dictionary = talk.bank.line("sea.marta.001") if talk.bank.lines.has("sea.marta.001") else {}
	var any_sight := ""
	for id in talk.bank.offshore.get("sight", []):
		if str(talk.bank.lines[id].speaker) == "any":
			any_sight = id
			break
	if any_sight != "" and talk.eligible(talk.bank.lines[any_sight], hid) == "":
		return "occluded worker eligible for a sighting line"
	# Secondhand: the observer tells the listener; the listener can then
	# discuss it as a claim, never as a sighting.
	off.on_line_spoken("sea.any.090", obs, [lis])
	if not off.knows("sea:told", lis) or off.knows("sea:saw_ship_now", lis):
		return "secondhand transfer wrong"
	# --- one beat -> at most one immediate callout, then cooldowns
	off._cd.clear()
	off.visit.beats.clear()
	off._live.erase(obs.id)
	_p19_place(obs, Game.crew.dock_shore)
	var c_before := int(off.stats.callouts)
	off.eval_worker(obs, 1.0)          # first sighting -> beat registered
	off._pending_beats()
	off._pending_beats()
	var spoken := int(off.stats.callouts) - c_before
	p19_report["beat_callouts"] = {"spoken": spoken, "beats": off.visit.beats.keys(), "last": talk.history[talk.history.size() - 1] if not talk.history.is_empty() else {}}
	if spoken != 1:
		return "first sighting produced %d callouts (want exactly 1)" % spoken
	# --- fall warning takes precedence over a callout: the speaker beside
	# a tree that is coming down stays quiet.
	var near_tree := -1
	for i in World.tree_count():
		var tp := World.tree_position(i)
		if not World.removed_trees.has(int(World.trees.id[i])) and World.is_native(int(World.trees.id[i])) and tp.distance_to(Game.crew.dock_shore) < 160.0:
			near_tree = int(World.trees.id[i])
			_p19_place(obs, tp + Vector3(5, 0, 5))
			break
	for o in ws:
		if o != obs:
			_p19_place(o, Vector3(300, 0, -330))     # nobody else to speak
	if near_tree >= 0:
		talk._warn_t[near_tree] = talk.clock
		if talk.suppressed_at(obs) != "tree coming down":
			return "fall warning not active near the speaker"
		off._cd.clear()
		var spoke := off.try_callout("sight")
		talk._warn_t.erase(near_tree)
		if spoke:
			return "offshore callout spoke over a fall warning"
	p19_report["fall_warning_tree"] = near_tree
	# --- fully cleared fixture: canopy reads zero once trees are gone
	var cp := Vector3(150, 0, -100)
	var c0 := off.canopy_at(cp.x, cp.z, 30.0)
	var removed := []
	for i in World.tree_count():
		if Vector2(World.trees.x[i] - cp.x, World.trees.z[i] - cp.z).length() < 45.0 and not World.removed_trees.has(int(World.trees.id[i])):
			removed.append(int(World.trees.id[i]))
			World.removed_trees[int(World.trees.id[i])] = true
	var c1 := off.canopy_at(cp.x, cp.z, 30.0)
	for id in removed:
		World.removed_trees.erase(id)
	p19_report["cleared_canopy"] = [c0, c1]
	if c0 <= 0.0 or c1 != 0.0:
		return "canopy clearance does not follow felling (%s -> %s)" % [c0, c1]
	# --- the Day 36 rescue ship is independent; no visits once the contract ends
	off.stop_preview()
	Game.hunt.mode = "rescue"
	Game.hunt._build_ship()
	var rescue := Game.hunt.ship
	off.enabled = true
	off.visits.erase("V%02d" % Game.campaign.clock.day)
	for k in 5:
		await get_tree().physics_frame
	var surveys := get_tree().root.find_children("SurveyShip*", "", true, false).size()
	var ok36 := rescue != null and not (rescue is SurveyShip) and off.visit.is_empty()
	rescue.queue_free()
	Game.hunt.ship = null
	Game.hunt.mode = "none"
	if not ok36:
		return "rescue ship not independent (survey visit running during the rescue)"
	p19_report["survey_ships_during_rescue"] = surveys
	var re := await _p19_routine()
	if re != "":
		return re
	# --- save format: schema 13 carries phase19; a v12 save migrates.
	var mig := SaveService.migrate({"schema": 12, "phase17": {}})
	if int(mig.get("schema", 0)) != SaveService.SCHEMA_VERSION or not mig.has("phase19"):
		return "v12 -> v13 migration missing phase19"
	var st := SaveService.capture_state(get_tree().root.find_children("*", "IslandWorld", true, false)[0])
	if not st.has("phase19") or not (st.phase19 as Dictionary).has("offshore") or not (st.phase19 as Dictionary).has("routine"):
		return "phase19 block not saved"
	# --- coverage
	var have := 0
	var maps := 0
	for id in talk.bank.offshore.values().reduce(func(a: Array, b: Array) -> Array: return a + b, []):
		var ln: Dictionary = talk.bank.lines[id]
		for prof in ["marta", "dale", "priya", "tomas", "joan", "crew_m", "crew_f"]:
			if VoiceBank.info(prof, id).is_empty():
				continue
			maps += 1
			if VoiceBank.has(prof, id):
				have += 1
	p19_report["voice"] = {"mappings": maps, "recorded": have}
	return ""


func _p19_cover() -> String:
	var sc: SurvivalCover = Game.survival_cover
	if sc == null or not sc.built:
		return "survival cover not built"
	Game.hunt.build_hide_spots()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var kinds := {}
	for h in sc.hides:
		kinds[h.kind] = int(kinds.get(h.kind, 0)) + 1
	var rep := {"new_hides": kinds, "rejected": sc.rejected, "sheds": sc.sheds.size()}
	p19_report["cover"] = rep
	if int(kinds.get("thicket", 0)) < 12 or int(kinds.get("shed", 0)) < 1 or int(kinds.get("dock_store", 0)) != 1:
		return "survival hides missing: %s" % str(kinds)
	# Clearance of the occupant pose (new hides and the rock hides).
	var bad := []
	for h in sc.hides + (Game.cover.hides if Game.cover else []):
		var why := sc.clearance(h)
		if why != "":
			bad.append("%s %s: %s" % [h.kind, h.name, why])
	rep["clearance_failures"] = bad
	for h in sc.hides:
		if h.exits.size() < 2:
			return "%s has no alternate way out" % h.name
	if not bad.is_empty():
		return "hide pose clips: %s" % str(bad.slice(0, 4))
	# Region audit: sparse (no hide guaranteed within 30 m), varied, fair.
	var au := sc.audit()
	rep["audit"] = au
	if float(au.largest_kind_share) > 0.6:
		return "hides dominated by one kind (%.2f)" % float(au.largest_kind_share)
	for rk in au.regions:
		if float(au.regions[rk].hide_within_30m) > 0.5:
			return "region %s has a hide within 30 m of most points" % rk
	var far: Dictionary = au.regions.get("far logging (>350 m from camp)", {})
	var trails: Dictionary = au.regions.get("travel routes (trails)", {})
	if far.is_empty() or trails.is_empty() or float(far.hide_within_150m) < 0.5 or float(trails.hide_within_150m) < 0.5:
		return "far areas / routes lack hide opportunity: far %s trails %s" % [str(far), str(trails)]
	# Evidence-based hides with the real Foreman.
	var hunt := Game.hunt
	hunt.hunt_preview = true
	hunt._spawn_foreman()
	var fm: Foreman = hunt.foreman
	await get_tree().physics_frame
	fm.set_state("ROAM")
	fm.grace = 0.0
	var pl := Game.player as Player
	var T: HideSpot = null
	for h in sc.hides:
		if h.kind == "thicket":
			T = h
			break
	var ex0: Vector3 = T.exits[0]
	pl.global_position = ex0 + Vector3(0, 0.1, 0)
	# (a) unseen entry: the hunter far away facing elsewhere.
	fm.global_position = T.global_position + Vector3(60, 0, 0)
	fm.global_position.y = World.height_at(fm.global_position.x, fm.global_position.z)
	fm.look_at(fm.global_position + Vector3(1, 0, 0), Vector3.UP)
	fm.evidence.clear()
	hunt.seen_entries.clear()
	pl.hide_in(T)
	await get_tree().physics_frame
	var unseen_ok := not hunt.seen_entries.has(T) and hunt.is_hidden(pl)
	var leak := false
	for e in fm.evidence:
		if (e.pos as Vector3).distance_to(T.global_position) < 5.0 or e.get("spot") == T:
			leak = true
	# (b) hunter 10 m away looking straight at the thicket: the brush hides.
	var dir10 := (T.global_position - ex0)
	dir10.y = 0
	var seen_at := {}
	for dist in [10.0, 3.0]:
		var best := false
		for k in 6:
			var a := TAU * k / 6.0
			var fp: Vector3 = T.global_position + Vector3(cos(a), 0, sin(a)) * float(dist)
			fp.y = World.height_at(fp.x, fp.z)
			fm.global_position = fp
			fm.look_at(Vector3(T.eye.x, fp.y, T.eye.z), Vector3.UP)
			if fm.can_see(pl):
				best = true
		seen_at[str(dist)] = best
	rep["thicket_hide"] = {"unseen_entry_ok": unseen_ok, "position_leak": leak, "seen_from_10m_any_side": seen_at["10.0"], "seen_from_3m": seen_at["3.0"], "exits": T.exits.size()}
	if not unseen_ok or leak:
		return "unseen thicket entry leaked or failed"
	if not bool(seen_at["3.0"]):
		return "a hunter at 3 m does not find the thicket hider (cover would be invulnerability)"
	# (c) alternate escape: leave by the way out away from the hunter.
	fm.global_position = T.exits[0] + Vector3(0.5, 0, 0)
	pl.leave_hide()
	await get_tree().physics_frame
	var out_d := pl.global_position.distance_to(fm.global_position)
	rep["escape_exit_dist_from_hunter"] = snappedf(out_d, 0.1)
	if out_d < T.exits[0].distance_to(fm.global_position) + 1.5:
		return "left the thicket toward the hunter (no alternate escape used)"
	# (d) seen entry: the hunter watches; that exact spot becomes evidence.
	var shed: HideSpot = null
	for h in sc.hides:
		if h.kind == "shed":
			shed = h
	var door_in: Vector3 = shed.get_meta("door_in")
	pl.global_position = door_in + Vector3(0, 0.1, 0)
	var door_out: Vector3 = shed.get_meta("door_out")
	var watch := door_out + (door_out - door_in).normalized() * 4.0
	watch.y = World.height_at(watch.x, watch.z)
	fm.global_position = watch
	fm.look_at(Vector3(door_in.x, watch.y, door_in.z), Vector3.UP)
	fm.evidence.clear()
	hunt.seen_entries.clear()
	var vis_before := fm.can_see(pl)
	pl.hide_in(shed)
	await get_tree().physics_frame
	var ev_spot := fm.evidence.any(func(e: Dictionary) -> bool: return e.get("spot") == shed)
	rep["shed_seen_entry"] = {"hunter_saw_entry": vis_before, "seen_entries": hunt.seen_entries.has(shed), "evidence_points_at_spot": ev_spot, "search_bonus": hunt.seen_entry_bonus(shed)}
	pl.leave_hide()
	await get_tree().physics_frame
	if vis_before and (not hunt.seen_entries.has(shed) or not ev_spot):
		return "a seen entry was not recorded as evidence for that spot"
	if not vis_before:
		return "test setup: hunter could not see the shed doorway"
	# Dock dog immunity; unchanged five-day/night extraction; objective.
	if Game.dog and fm._humans().has(Game.dog):
		return "the dog is a hunt target"
	if HuntService.FIRST_DAY != 31 or HuntService.LAST_DAY != 35 or HuntService.CYCLE != 1500.0:
		return "five-day hunt timing changed"
	hunt.mode = "hunt"
	hunt.hunt_day = 33
	Game.objective = ""
	hunt._update_objective()
	rep["objective"] = Game.objective
	hunt.mode = "none"
	Game.objective = ""
	if not str(rep["objective"]).contains("dawn on day 36"):
		return "survival objective unclear"
	fm.queue_free()
	hunt.foreman = null
	hunt.hunt_preview = false
	await get_tree().physics_frame
	return ""


func _p19_routine() -> String:
	var crew: CrewService = Game.crew
	var r: CampRoutine = crew.routine
	if r == null:
		return "no routine"
	var ws: Array = crew.workers.values()
	for w in ws:
		(w as Worker).emp["job"] = "automatic"
	var day := Game.campaign.clock.day
	r.plan_day(day)
	var roles1 := r.roles.duplicate()
	r.plan_day(day)
	if r.roles != roles1 or roles1.size() != ws.size():
		return "day roles not deterministic / not assigned: %s" % str(roles1)
	var near_focus := World.camp_origin() + Vector3(0, 0, -40)
	var far_focus := World.camp_origin() + Vector3(250, 0, -300)
	var p_near := r.transport_plan(near_focus)
	var p_far := r.transport_plan(far_focus)
	var rep := {"roles": roles1, "plan_near": p_near, "plan_far": p_far}
	p19_report["routine"] = rep
	if str(p_near.mode) != "carry" or str(p_far.mode) == "carry" and Game.cart != null:
		return "transport plan ignores distance: %s / %s" % [str(p_near), str(p_far)]
	# Midday gathering: three near camp walk in and sit; one far away
	# takes the break in place.
	var camp := World.camp_origin()
	for i in ws.size():
		var w: Worker = ws[i]
		w.activity = "idle"
		w.path.clear()
		_p19_place(w, camp + Vector3(-6 + i * 3, 0, -14) if i < 3 else Vector3(300, 0, -330))
	if Game.dog:
		Game.dog.global_position = r._seat_point(0) + Vector3(1.2, 0, 1.2)
	var pets0: int = Game.dog.pets if Game.dog else 0
	r.start_break(day)
	var att: Array = r.brk.attendees
	var fld: Array = r.brk.field
	var g := 0
	var d0 := {}
	for e in att:
		var sp: Array = r.brk.seats[e]
		d0[e] = snappedf((crew.workers[e] as Worker).global_position.distance_to(Vector3(sp[0], sp[1], sp[2])), 0.1)
	while g < 3000:
		await get_tree().physics_frame
		r._settle_attendees()
		g += 1
		if att.all(func(e: String) -> bool: return (crew.workers[e] as Worker).activity == "break_sit") and str(r.brk.petted) != "":
			break
	var d1 := {}
	for e in att:
		var sp2: Array = r.brk.seats[e]
		var wk2: Worker = crew.workers[e]
		d1[e] = [snappedf(wk2.global_position.distance_to(Vector3(sp2[0], sp2[1], sp2[2])), 0.1), wk2.activity, wk2.path.size(), wk2._after_move]
	rep["walk"] = {"start_dist": d0, "end": d1}
	var seated := att.filter(func(e: String) -> bool: return (crew.workers[e] as Worker).activity == "break_sit")
	var w0: Worker = crew.workers[att[0]] if not att.is_empty() else ws[0]
	rep["break"] = {"attendees": att, "field": fld, "seated": seated, "frames": g, "petted_by": r.brk.petted, "shared": r.brk.shared,
		"time_category": crew.time_category(w0), "act_rest": crew.talk.holds("act:rest", w0), "dog_pets": (Game.dog.pets if Game.dog else 0) - pets0}
	if att.size() < 3 or fld.size() < 1:
		return "gathering split wrong: %s" % str(rep["break"])
	if seated.size() < 2:
		return "workers did not reach the gathering: %s" % str(rep["break"])
	if crew.time_category(w0) != "break":
		return "break time not counted as a break"
	if not crew.talk.holds("act:rest", w0):
		return "gathering does not open rest conversation"
	if Game.dog and str(r.brk.petted) == "":
		return "nobody petted the dog at the gathering"
	var cap := r.capture()
	r.end_break()
	if (crew.workers[att[0]] as Worker).activity != "idle":
		return "break did not end"
	var r2 := CampRoutine.new(crew)
	r2.restore(JSON.parse_string(JSON.stringify(cap)))
	if r2.roles != r.roles or str(r2.brk.state) != "done":
		return "routine save/restore wrong"
	return ""


# ---------------------------------------------------------------- Phase 20

func _t_phase20_units() -> String:
	var rec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terror/recordings.json"))
	var sc: Array = rec.get("scenarios", [])
	if sc.size() < 36:
		return "recording scenarios %d < 36" % sc.size()
	var beats := {}
	var cams := ["CAM_01", "CAM_02", "CAM_03", "CAM_04", "CAM_05", "CAM_06", "CAM_07", "CAM_08", "CAM_09", "CAM_10"]
	for s in sc:
		for k in ["id", "cameras", "requires", "hour", "duration", "actor", "props", "audio", "consequence", "cooldown", "beat"]:
			if not s.has(k):
				return "%s lacks %s" % [s.get("id", "?"), k]
		beats[str(s.beat)] = true
		for c in s.cameras:
			if not cams.has(str(c)):
				return "%s: unknown camera %s" % [s.id, c]
		for a in s.audio:
			if not SoundBank.EVENTS.has(str(a[1])):
				return "%s: unknown sound %s" % [s.id, a[1]]
	if beats.size() != sc.size():
		return "duplicate dramatic beats"
	var si: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terror/sleep_interruptions.json"))
	var qs: Array = si.get("sequences", [])
	if qs.size() < 24:
		return "sleep interruptions %d < 24" % qs.size()
	for q in qs:
		for st in q.steps:
			if not SoundBank.EVENTS.has(str(st[1])):
				return "%s: unknown sound %s" % [q.id, st[1]]
			if float(st[3]) > 2.0:
				return "%s: unbounded gain" % q.id
		if str(q.caption) == "":
			return "%s: no caption for muted play" % q.id
	return ""


func _t_phase20_world() -> String:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	for c in get_children():
		if c is IslandWorld:
			c.queue_free()
	await get_tree().physics_frame
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var guard := 0
	while (Game.crew == null or Game.campaign == null) and guard < 900:
		await get_tree().physics_frame
		guard += 1
	for i in 20:
		await get_tree().physics_frame
	var err := await _p20_checks(world)
	print("P20 REPORT ", JSON.stringify(p20_report))
	world.queue_free()
	await get_tree().process_frame
	Game.preview_variant = ""
	World.removed_trees.clear()
	World.apply_variant("full")
	return err


var p20_report := {}


func _p20_checks(world: IslandWorld) -> String:
	var cs: CampaignService = Game.campaign
	cs.start_test_route(true, true)
	var g := 0
	while Game.crew.workers.size() < 2 and g < 900:
		await get_tree().physics_frame
		g += 1
	cs.clock.day = 6
	var nr: NightRecorder = Game.night_recorder
	var si: SleepInterrupts = Game.sleep_interrupts
	if nr == null or si == null:
		return "night services missing"
	# Fixture for prerequisites, staged in the real world: a truck in its
	# bay, weather per scenario, and (cleared alternatives) real felling
	# around each camera plus a labelled cleared-percentage override.
	if (Game.vehicles.trucks as Dictionary).is_empty():
		Game.vehicles._spawn("TRUCK_FX", Game.vehicles.bay_pose(0))
	await get_tree().physics_frame
	var wallet0: int = cs.wallet.cash
	var ok := []
	var fail := {}
	for s in nr.scenarios:
		var req: Array = s.requires
		var wx := "clear"
		if req.has("rain"):
			wx = "light_rain"
		elif req.has("wind"):
			wx = "storm"
		Game.weather.set_override(wx, true)
		var removed := []
		if req.has("open_ground"):
			for cid in s.cameras:
				var cam := nr.camera(str(cid))
				if cam == null:
					continue
				var p: Vector3 = cam.global_position + (-cam.global_basis.z) * 45.0
				for i in World.tree_count():
					var id := int(World.trees.id[i])
					if not World.removed_trees.has(id) and Vector2(World.trees.x[i] - p.x, World.trees.z[i] - p.z).length() < 40.0:
						World.removed_trees[id] = true
						removed.append(id)
		nr.set_meta("fixture_cleared", req.has("cleared>=40"))
		var clip := nr.on_night(cs.clock.day, str(s.id))
		for id in removed:
			World.removed_trees.erase(id)
		nr.remove_meta("fixture_cleared")
		if clip.is_empty():
			fail[str(s.id)] = nr.stats.rejected.duplicate()
			nr.stats.rejected.clear()
		else:
			ok.append([str(s.id), str(clip.camera)])
	Game.weather.set_override("", true)
	p20_report["recordings"] = {"captured": ok.size(), "of": nr.scenarios.size(), "failed": fail}
	if not fail.is_empty():
		return "scenarios that could not be staged: %s" % str(fail)
	if cs.wallet.cash != wallet0:
		return "a night incident changed the money"
	# Morning: notice + cosmetic mark, gone by midday.
	var marked := nr.clip_by_id(str(nr.clips[nr.clips.size() - 1].id))
	nr.marks.clear()
	nr.pending_notice.clear()
	var mclip := nr.on_night(cs.clock.day + 3, "rec09")
	cs.clock.day = int(mclip.day) + 1        # as in sleep(): morning after the night
	cs.clock.t = 100.0
	nr.on_morning()
	var marks_morning := get_tree().get_nodes_in_group("night_marks").size()
	cs.clock.t = 500.0
	nr.refresh_marks()
	await get_tree().process_frame
	var marks_noon := get_tree().get_nodes_in_group("night_marks").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()
	p20_report["marks"] = [marks_morning, marks_noon]
	if marks_morning < 1 or marks_noon != 0:
		return "cosmetic marks %d at dawn / %d at noon" % [marks_morning, marks_noon]
	cs.clock.day = 6
	cs.clock.t = 100.0
	# Reconstruction: historic trees, deterministic seek, no side effects.
	var clip: Dictionary = {}
	for c in nr.clips:
		if str(c.actor.kind) == "figure":
			clip = c
			break
	var pl := RecordingPlayer.new()
	add_child(pl)
	var mon := get_tree().get_nodes_in_group("camper_monitor")
	pl.speaker = mon[0] if not mon.is_empty() else null
	pl.load_clip(clip)
	var shown0 := int(pl.get_meta("trees_shown", 0))
	# Fell a tree near that camera AFTER the capture: playback must still
	# show it (it stood that night).
	var cpos := Vector3(clip.xform[0], clip.xform[1], clip.xform[2])
	var fell_id := -1
	for i in World.tree_count():
		var id2 := int(World.trees.id[i])
		if not World.removed_trees.has(id2) and World.is_native(id2) and World.tree_position(i).distance_to(cpos) < 50.0:
			fell_id = id2
			World.removed_trees[id2] = true
			break
	pl.load_clip(clip)
	var shown1 := int(pl.get_meta("trees_shown", 0))
	World.removed_trees.erase(fell_id)
	var a1 := pl.pose(3.0)
	pl.seek(7.0)
	pl.seek(3.0)
	var a2 := pl.pose(3.0)
	pl.play()
	await get_tree().process_frame
	var pending := SoundService.instance()._delayed.filter(func(d: Array) -> bool: return int((d[3] as Dictionary).get("origin", 0)) == SoundService.Origin.RECORDING).size()
	pl.pause()
	var after := SoundService.instance()._delayed.filter(func(d: Array) -> bool: return int((d[3] as Dictionary).get("origin", 0)) == SoundService.Origin.RECORDING).size()
	p20_report["playback"] = {"trees_shown": shown0, "after_later_felling": shown1, "camp_meshes": pl.get_meta("camp_meshes", 0), "seek_same": JSON.stringify(a1) == JSON.stringify(a2), "replay_events": pending, "after_pause": after}
	pl.queue_free()
	if shown1 != shown0:
		return "playback lost a tree felled after the recording (%d -> %d)" % [shown0, shown1]
	if JSON.stringify(a1) != JSON.stringify(a2):
		return "seek is not deterministic"
	if after != 0:
		return "pause left replayed sound pending"
	if cs.wallet.cash != wallet0:
		return "playback changed the money"
	# Save/load: clips and decided nights persist; no re-roll.
	var st := nr.capture_state()
	var n2 := NightRecorder.new()
	add_child(n2)
	n2.restore_state(JSON.parse_string(JSON.stringify(st)))
	var re := n2.on_night(int(mclip.day))
	var same := n2.clips.size() == nr.clips.size() and re.is_empty()
	n2.queue_free()
	if not same:
		return "recordings did not survive a reload or a night re-rolled"
	# ---- sleep interruptions
	var player := Game.player as Node3D
	var home := player.global_position
	var door := Game.world_root.find_child("CamperDoor", true, false)
	var door_open0 = door.get("is_open") if door else null
	cs.clock.day = 9
	cs.clock.t = WorkdayClock.DAYLIGHT_SECONDS + 399.0
	cs.clock.advance(1.0)               # let the clock reach its night phase
	si.rolled.clear()
	si.state = "idle"
	var day0 := cs.clock.day
	var reports0 := cs.reports.size()
	si.start("si01", day0)
	var seen := [si.state]
	var played0 := int(SoundService.instance().stats.played)
	for k in 200:
		si.step(0.1)
		if seen[seen.size() - 1] != si.state:
			seen.append(si.state)
		if si.state == "available":
			break
	var played := int(SoundService.instance().stats.played) - played0
	var can_mid := cs.can_sleep()
	var moved := player.global_position.distance_to(home)
	var door_open1 = door.get("is_open") if door else null
	p20_report["sleep"] = {"states": seen, "sounds": played, "moved_m": snappedf(moved, 0.01), "door_open": [door_open0, door_open1]}
	if seen != ["settling", "interrupted", "resolving", "available"]:
		return "interruption states %s" % str(seen)
	if played < 1:
		return "interruption played no sound"
	if moved > 0.05 or door_open0 != door_open1:
		return "interruption moved the boss or opened the door"
	if not bool(can_mid.ok):
		return "sleep not available after the interruption: %s" % str(can_mid.get("reason", ""))
	# The next sleep request settles once (no second roll that night).
	var consumed := si.intercept(player)
	var res := cs.sleep()
	p20_report["sleep"]["settled"] = [consumed, bool(res.get("ok", false)), cs.reports.size() - reports0, cs.clock.day - day0]
	if consumed or not bool(res.get("ok", false)) or cs.reports.size() - reports0 != 1 or cs.clock.day - day0 != 1:
		return "sleep after an interruption did not settle exactly once"
	# Mid-sequence save resumes as "available" without another interruption.
	cs.clock.t = WorkdayClock.DAYLIGHT_SECONDS + 399.0
	cs.clock.advance(1.0)
	si.start("si05", cs.clock.day)
	si.step(SleepInterrupts.SETTLE_S + 0.1)
	var mid := si.capture_state()
	var s2 := SleepInterrupts.new()
	add_child(s2)
	s2.restore_state(JSON.parse_string(JSON.stringify(mid)))
	var resumed := s2.state
	s2.queue_free()
	si.restore_state(JSON.parse_string(JSON.stringify(mid)))
	var again := si.intercept(player)
	p20_report["sleep"]["restore"] = [str(mid.state), resumed, again]
	if resumed != "available" or again:
		return "interruption save/load did not resume as available"
	si.state = "idle"
	# Pacing over a whole contract: rare, spaced, never early or on day 30.
	var r2 := SleepInterrupts.new()
	add_child(r2)
	var days := []
	var majors := []
	for d in range(1, 31):
		cs.clock.day = d
		var pk := r2.roll(d)
		if pk != "":
			r2.start(pk, d)
			r2.state = "idle"
			days.append(d)
			if bool(r2.by_id[pk].major):
				majors.append(d)
	r2.queue_free()
	p20_report["sleep"]["pacing"] = {"nights": days, "majors": majors}
	for i in range(1, days.size()):
		if int(days[i]) - int(days[i - 1]) < SleepInterrupts.MIN_GAP + 1:
			return "interruptions too close: %s" % str(days)
	for i in range(1, majors.size()):
		if int(majors[i]) - int(majors[i - 1]) < SleepInterrupts.MAJOR_GAP:
			return "major interruptions too close: %s" % str(majors)
	if days.any(func(d: int) -> bool: return d < 4 or d == 30) or days.size() > 8:
		return "interruption pacing wrong: %s" % str(days)
	return ""
