extends Node
## Headless felling simulation: the real player controller chops real island
## trees (one per test case) with contact-timed swings until they fall and
## settle. Prints timings, settle reasons, pose checks. Used by tests and for
## the Phase 1 report.
##   godot --headless --fixed-fps 60 res://tools/fell_sim.tscn

var results := []

func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "logging_test"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	await get_tree().physics_frame
	var cases: Array = OS.get_environment("FELL_CASES").split(",") if OS.has_environment("FELL_CASES") else LoggingTest.CASES
	for c in cases:
		await _fell_case(world, c)
	print("FELL_SUMMARY ", JSON.stringify(results))
	get_tree().quit()


func _fell_case(world: IslandWorld, case_name: String) -> void:
	var i := LoggingTest.find(case_name)
	var id: int = World.trees.id[i]
	var stands := PlacementValidator.cut_stands(i)
	var base := World.tree_position(i)
	var p: Player = Game.player
	p.teleport(stands[0] + Vector3(0, 1.65, 0), base + Vector3(0, 1.0, 0))
	world.vegetation.update_collision_around(base)
	for k in 5:
		await get_tree().physics_frame
	var t := 0.0
	var swings := 0
	while Game.trees.state_of(id) <= TreeService.State.NOTCHED and t < 120.0:
		# Face the trunk and keep swinging (same legal cadence as hold-to-chop).
		var d := base - p.global_position
		p.set("_yaw", atan2(-d.x, -d.z))
		p.set("_pitch", -0.25)
		p.call("_apply_look")
		if not p.axe.swinging:
			p.axe.swinging = true
			p.axe.set("_u", 0.0)
			p.axe.set("_contact_done", false)
			swings += 1
		await get_tree().physics_frame
		t += 1.0 / 60.0
	var chop_time := t
	var fall_t := 0.0
	while Game.trees.state_of(id) == TreeService.State.FALLING and fall_t < 30.0:
		await get_tree().physics_frame
		fall_t += 1.0 / 60.0
	var rec: Dictionary = Game.trees.records.get(id, {})
	var actor: TreeActor = Game.trees.actors.get(id)
	var pose := TreeService.array_to_xf(rec.get("pose", []))
	var tilt := rad_to_deg(pose.basis.y.angle_to(Vector3.UP)) if not rec.get("pose", []).is_empty() else 0.0
	var pen := 0.0
	if actor:
		var L: float = actor.height - actor.cut_h
		for k in 7:
			var pt := pose * Vector3(0, actor.cut_h + L * 0.82 * k / 6.0, 0)
			pen = maxf(pen, World.height_at(pt.x, pt.z) - pt.y)
	var r := {"case": case_name, "id": id, "species": int(World.trees.species[i]), "diameter": snappedf(float(World.trees.radius[i]) * 2.0, 0.01), "required_units": snappedf(float(rec.get("required", 0)), 0.1), "swings": swings, "chop_seconds": snappedf(chop_time, 0.1), "fall_seconds": snappedf(fall_t, 0.1), "state": TreeService.State.keys()[Game.trees.state_of(id)], "settle": rec.get("settle_reason", ""), "tilt_deg": snappedf(tilt, 0.1), "axis_center_below_ground_m": snappedf(pen, 0.01), "felled_events": Game.trees.felled_log.count(id), "stumps": get_tree().get_nodes_in_group("stumps").size(), "player_pos_ok": p.global_position.y >= World.height_at(p.global_position.x, p.global_position.z) - 0.3}
	results.append(r)
	print("FELL ", JSON.stringify(r))
