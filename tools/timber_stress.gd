extends Node
## Phase 2 stress fixture: fells the 50 standing trees nearest camp, bucks
## every trunk into pieces, then measures object counts, sleeping (frozen)
## bodies, physics/process cost and memory with the full pile in the world,
## delivers everything (queue representation), and checks cleanup.
##   godot --headless --fixed-fps 60 res://tools/timber_stress.tscn

const COUNT := 50


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	await get_tree().physics_frame
	var camp := World.camp_origin()
	var order := []
	for i in World.tree_count():
		var d := Vector2(World.trees.x[i], World.trees.z[i]).distance_to(Vector2(camp.x, camp.z))
		if d < 400.0:
			order.append([d, i])
	order.sort()
	var t: TimberService = world.timber
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	var mem0 := OS.get_static_memory_usage()
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var felled := []
	var t0 := Time.get_ticks_msec()
	for n in order.slice(0, COUNT):
		var i: int = n[1]
		var id: int = World.trees.id[i]
		var base := World.tree_position(i)
		world.vegetation.update_collision_around(base)
		var req := float(world.trees.record(id).required)
		world.trees.apply_contact(id, base + Vector3(1.5, 0, 0), req + 1.0)
		felled.append(id)
		if felled.size() % 10 == 0:
			for f in 360:
				await get_tree().physics_frame
	for f in 600:
		await get_tree().physics_frame
	var sectioned := 0
	for id in felled:
		if world.trees.state_of(id) == TreeService.State.SECTIONED:
			sectioned += 1
	# Buck all trunks round-robin.
	var work := cfg.work_per_contact("large") * 10.0
	var guard := 0
	while guard < 5000:
		guard += 1
		var any := false
		for key in t.bodies.keys():
			if not t.bodies.has(key):
				continue
			var b: TimberBody = t.bodies[key]
			if b.is_single_piece() or not b.is_resting():
				continue
			var rec: Dictionary = t.records[b.tree_id]
			var y := float(rec.merch_top) if b.crown else float(rec.segments[b.ks.max() - 1].b)
			t.apply_cut(b, y, work)
			any = true
		await get_tree().physics_frame
		if not any:
			var moving := 0
			for key in t.bodies:
				if not (t.bodies[key] as TimberBody).is_resting():
					moving += 1
			if moving == 0:
				break
	var build_s := (Time.get_ticks_msec() - t0) / 1000.0
	# Measure steady state with every piece lying in the world.
	var phys := 0.0
	var proc := 0.0
	for f in 120:
		await get_tree().physics_frame
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
	var frozen := 0
	var floating := 0
	for key in t.bodies:
		var b: TimberBody = t.bodies[key]
		if b.is_resting():
			frozen += 1
		if not b.has_support():
			floating += 1
	var r := {
		"trees_felled": felled.size(), "sectioned": sectioned, "timber_bodies": t.bodies.size(),
		"frozen_bodies": frozen, "floating": floating, "recoveries": t.recovery_log.size(),
		"physics_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"avg_physics_ms": snappedf(phys / 120.0 * 1000.0, 0.01), "avg_process_ms": snappedf(proc / 120.0 * 1000.0, 0.01),
		"node_delta": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes0),
		"static_mem_delta_mb": snappedf((OS.get_static_memory_usage() - mem0) / 1048576.0, 0.1),
		"build_seconds": snappedf(build_s, 0.1),
	}
	# Deliver everything: the queue meter reports it all, the rack shows 12.
	for key in t.bodies.keys():
		t.pick_up(t.bodies[key], 1000000)
	t.accept(t.carried.duplicate(), "stress")
	r["queued_pieces"] = t.queue.size()
	r["queued_tree_eq"] = snappedf(t.queue_mte() / 1000.0, 0.001)
	var racks := get_tree().get_nodes_in_group("delivery_rack")
	await get_tree().process_frame
	r["rack_visible_pieces"] = (racks[0] as Node).get_node("Stack").get_child_count() if not racks.is_empty() else -1
	var ok := true
	for id in felled:
		if t.has_record(id) and not t.reconcile(id).ok:
			ok = false
	r["all_reconcile"] = ok
	r["entitlement_dollars"] = int(t.totals().entitlement_cents) / 100
	# Cleanup.
	t.clear_all()
	world.trees.clear_all()
	for f in 5:
		await get_tree().process_frame
	r["after_cleanup_bodies"] = t.bodies.size()
	r["after_cleanup_node_delta"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes0)
	print("STRESS ", JSON.stringify(r))
	get_tree().quit()
