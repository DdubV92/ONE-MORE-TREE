extends Node
## Headless Phase 2 loop on real island trees: fell -> buck at every mark
## (contact-sized work, small axe) -> pieces settle -> carry in hand loads
## -> accept at camp -> burn -> reconcile, plus a save/load round trip in the
## middle (pieces in the world, one bundle in hand, some queued).
##   godot --headless --fixed-fps 60 res://tools/timber_sim.tscn
##   env TIMBER_CASES=camp_edge,large

var results := []


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "logging_test"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	await get_tree().physics_frame
	var cases: Array = OS.get_environment("TIMBER_CASES").split(",") if OS.has_environment("TIMBER_CASES") else ["camp_edge", "slope", "rock", "small", "large"]
	for c in cases:
		await _run_case(world, str(c))
	print("TIMBER_SUMMARY ", JSON.stringify(results))
	get_tree().quit()


func _settle_all(max_s := 12.0) -> float:
	var t := 0.0
	while t < max_s:
		var moving := 0
		for k in Game.timber.bodies:
			if not (Game.timber.bodies[k] as TimberBody).is_resting():
				moving += 1
		if moving == 0:
			return t
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return t


func _run_case(world: IslandWorld, case_name: String) -> void:
	var i := LoggingTest.find(case_name)
	var id: int = World.trees.id[i]
	var base := World.tree_position(i)
	var stands := PlacementValidator.cut_stands(i)
	var p: Player = Game.player
	p.teleport(stands[0] + Vector3(0, 1.65, 0), base + Vector3(0, 1.0, 0))
	world.vegetation.update_collision_around(base)
	await get_tree().physics_frame
	var req := float(Game.trees.record(id).required)
	Game.trees.apply_contact(id, stands[0], req * 0.5)
	Game.trees.apply_contact(id, stands[0], req)
	var t := 0.0
	while Game.trees.state_of(id) < TreeService.State.SECTIONED and t < 30.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	var r := {"case": case_name, "tree": id, "species": int(World.trees.species[i]), "diameter": snappedf(float(World.trees.radius[i]) * 2.0, 0.01), "tree_state": TreeService.State.keys()[Game.trees.state_of(id)]}
	if not Game.timber.has_record(id):
		r["error"] = "no timber record"
		results.append(r)
		print("TIMBER ", JSON.stringify(r))
		return
	var rec: Dictionary = Game.timber.records[id]
	r["segments"] = rec.segments.size()
	var shares := []
	for s in rec.segments:
		shares.append(int(s.cents))
	r["cents"] = shares
	r["piece_len_m"] = snappedf(float(rec.segments[0].b) - float(rec.segments[0].a), 0.01)
	# --- buck every boundary and the crown with small-axe contacts.
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	var work := cfg.work_per_contact("small")
	var contacts := 0
	var rejected_moving := 0
	var guard := 0
	while guard < 400:
		guard += 1
		var target_body: TimberBody = null
		var target_y := 0.0
		for key in Game.timber.bodies:
			var b: TimberBody = Game.timber.bodies[key]
			if b.tree_id != id or b.is_single_piece():
				continue
			target_body = b
			# Cut the crown off first, then from the top down.
			target_y = float(rec.merch_top) if b.crown else float(rec.segments[b.ks.max() - 1].b)
			break
		if target_body == null:
			break
		var res := Game.timber.apply_cut(target_body, target_y, work)
		if str(res.get("reason", "")) == "wait":
			rejected_moving += 1
			await _settle_all(3.0)
			continue
		contacts += 1
		if bool(res.get("separated", false)):
			await _settle_all()
	r["buck_contacts"] = contacts
	r["buck_seconds_small_axe"] = snappedf(contacts * float(cfg.tier_cycle["small"]), 0.1)
	r["cut_while_moving_rejected"] = rejected_moving
	await _settle_all()
	var floating := 0
	var bad := 0
	var lowest := INF
	for key in Game.timber.bodies:
		var b: TimberBody = Game.timber.bodies[key]
		if b.tree_id != id:
			continue
		if not b.has_support():
			floating += 1
		if TimberRecovery.diagnose(b) != "":
			bad += 1
		lowest = minf(lowest, b.global_position.y - World.height_at(b.global_position.x, b.global_position.z))
	r["pieces_in_world"] = Game.timber.bodies.size()
	r["floating"] = floating
	r["inaccessible"] = bad
	r["recoveries"] = Game.timber.recovery_log.size()
	# --- carry: first bundle, then save/load round trip mid-loop.
	var trips := 0
	var picked := 0
	var bundle_full := false
	for key in Game.timber.bodies.keys():
		var b: TimberBody = Game.timber.bodies[key]
		if b.tree_id != id:
			continue
		var res := Game.timber.pick_up(b, TimberService.HAND_BUDGET_MTE)
		if bool(res.ok):
			picked += 1
		else:
			bundle_full = true
			break
	r["first_bundle_pieces"] = picked
	r["first_bundle_mte"] = Game.timber.carried_mte()
	var before := Game.timber.reconcile(id)
	var snap := SaveService.capture_state(world)
	var json_text := JSON.stringify(snap)
	Game.timber.clear_all()
	Game.trees.clear_all()
	await get_tree().physics_frame
	SaveService.apply_state(world, JSON.parse_string(json_text))
	await get_tree().physics_frame
	var after := Game.timber.reconcile(id)
	r["reload_same_by_state"] = JSON.stringify(before.by_state) == JSON.stringify(after.by_state)
	r["reload_carried"] = Game.timber.carried.size()
	r["reload_stumps"] = get_tree().get_nodes_in_group("stumps").size()
	# --- deliver everything in legal hand loads.
	while true:
		if not Game.timber.carried.is_empty():
			Game.timber.accept(Game.timber.carried.duplicate(), "rack:sim")
			trips += 1
		var any := false
		for key in Game.timber.bodies.keys():
			var b: TimberBody = Game.timber.bodies[key]
			if b.tree_id != id or not b.is_single_piece():
				continue
			if bool(Game.timber.pick_up(b, TimberService.HAND_BUDGET_MTE).ok):
				any = true
		if not any and Game.timber.carried.is_empty():
			break
	r["delivery_trips"] = trips
	# Retrying acceptance must not create new receipts.
	var n_receipts := Game.timber.receipts.size()
	var segs: Array = []
	for s in rec.segments:
		segs.append(s.sid)
	Game.timber.accept(segs, "rack:retry")
	r["retry_new_receipts"] = Game.timber.receipts.size() - n_receipts
	r["delivered"] = Game.timber.tree_delivered(id)
	Game.timber.advance_burn(TimberService.OVERNIGHT_BURN_SECONDS * 3.0)
	var fin := Game.timber.reconcile(id)
	r["final_by_state"] = fin.by_state
	r["receipt_cents"] = fin.receipt_cents
	r["reconcile_ok"] = fin.ok and int(fin.receipt_cents) == TimberService.TREE_CENTS
	results.append(r)
	print("TIMBER ", JSON.stringify(r))
