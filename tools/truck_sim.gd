extends Node
## Headless pickup checks (Preview, in memory):
##  1. physics drive: accelerate, stay upright, steer, brake, reverse;
##  2. a worker team (driver + loader) runs real cycles: board, drive out,
##     work, load the bed, drive back, unload at the drop-off, park.
##   godot --headless --fixed-fps 60 res://tools/truck_sim.tscn

func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	for i in 8:
		await get_tree().physics_frame
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	cs.wallet.grant(2000000, "test", "SIM", "sim cash")
	var vs: VehicleService = world.vehicles
	vs.dev_unlock = true
	var r1 := vs.buy()
	var r2 := vs.buy()
	var r3 := vs.buy()
	print("BUY ", r1.ok, " ", r2.ok, " third refused: ", not bool(r3.ok), " (", r3.get("reason", ""), ")")
	var t: Truck = vs.trucks[r1.id]
	# --- 1. physics drive in the open yard / out the north gate
	t.take_control("player")
	var p0 := t.global_position
	t.throttle = 1.0
	var max_v := 0.0
	var yaw0 := t.global_rotation.y
	for i in 360:
		if i == 150:
			t.steer = 1.0
		if i == 260:
			t.steer = 0.0
		await get_tree().physics_frame
		max_v = maxf(max_v, t.speed())
	print("TURNED_DEG ", snappedf(rad_to_deg(angle_difference(yaw0, t.global_rotation.y)), 1.0))
	var after_acc := t.global_position.distance_to(p0)
	t.throttle = 0.0
	t.brake = 1.0
	for i in 180:
		await get_tree().physics_frame
	var stop_v := t.speed()
	t.brake = 0.0
	t.throttle = -1.0
	for i in 180:
		await get_tree().physics_frame
	var rev_v := t.speed()
	t.throttle = 0.0
	t.brake = 1.0
	for i in 120:
		await get_tree().physics_frame
	print("DRIVE ", JSON.stringify({"moved_m": snappedf(after_acc, 0.1), "max_speed": snappedf(max_v, 0.1), "after_brake": snappedf(stop_v, 0.1), "reverse_speed": snappedf(rev_v, 0.1), "upright": t.global_basis.y.y > 0.8, "up_y": snappedf(t.global_basis.y.y, 0.01)}))
	t.release_control()
	t.global_transform = vs.bay_pose(0)
	# --- 2. worker team cycle
	var area := World.camp_origin() + Vector3(0, 0, -70)
	var d := vs.dispatch(t.truck_id, "EMP-01", ["EMP-02"], area)
	print("DISPATCH ", d)
	var shift := float(OS.get_environment("SHIFT_SECONDS")) if OS.has_environment("SHIFT_SECONDS") else 1150.0
	var last := ""
	var tt := 0.0
	var cash0 := cs.wallet.cash
	while tt < shift:
		await get_tree().physics_frame
		tt += 1.0 / 60.0
		var tm: Dictionary = vs.teams.get(t.truck_id, {})
		var line := "%s | %s" % [tm.get("state", "-"), tm.get("reason", "")]
		if line != last:
			last = line
			print("T+%5.0f  %s  cargo %.2f  truck %s" % [tt, line, t.cargo_mte() / 1000.0, t.mode])
	var truck_receipts := world.timber.receipts.filter(func(r: Dictionary) -> bool: return str(r.source).begins_with("truck:"))
	var mte := 0
	for r in truck_receipts:
		mte += int(r.mte)
	print("TRUCK_SIM ", JSON.stringify({"cycles": vs.teams.get(t.truck_id, {}).get("cycles", 0), "truck_receipts": truck_receipts.size(), "truck_tree_eq": mte / 1000.0, "paid": (cs.wallet.cash - cash0) / 100.0, "odometer_m": snappedf(t.odometer, 1.0), "final_state": vs.teams.get(t.truck_id, {}).get("state", "-"), "stuck": world.crew.stuck_log.size()}))
	get_tree().quit()
