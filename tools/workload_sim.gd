extends Node
## Phase 7 workload measurement through the REAL task rules (worker AI,
## navigation, felling physics, bucking, hauling, truck teams, rack
## acceptance) at 60 Hz simulated time, one full workday per run. Preview,
## in memory, never saved. Scenario via env SCEN:
##   hand2   - two starters, small axes, hand hauling (early game)
##   mixed3  - three workers, medium axes, one truck team (driver + loader)
##             + one hand worker (first truck)
##   full5   - five workers, large axes, two truck teams (3 + 2)
##   far5    - full5 sent to a distant region (late cleanup)
##   godot --headless --fixed-fps 60 res://tools/workload_sim.tscn
## Prints WORKLOAD {...}.

var world: IslandWorld


func _ready() -> void:
	var scen := OS.get_environment("SCEN") if OS.has_environment("SCEN") else "hand2"
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	world = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 900:
		await get_tree().physics_frame
		g += 1
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	var crew := world.crew
	cs.wallet.grant(5000000, "test", "SIM", "sim cash")
	var n: int = {"hand2": 2, "mixed3": 3, "full5": 5, "far5": 5}.get(scen, 2)
	crew.refresh_candidates()
	while crew.slots_used() < n:
		var r := crew.hire(crew.candidates[0].cid)
		if not bool(r.ok):
			break
	# Hires arrive by boat; for a workload measurement they step off the
	# skiff at the dock now (the real arrival path) and walk to work.
	crew._skiff_docked()
	await get_tree().physics_frame
	var tier: String = {"hand2": "small", "mixed3": "medium", "full5": "large", "far5": "large"}[scen]
	for id in crew.workers:
		_give_axe(cs, str(id), tier)
	var ids: Array = crew.workers.keys()
	if ids.size() < n:
		print("WORKLOAD_ERROR only %d workers" % ids.size())
		get_tree().quit(1)
		return
	var vs: VehicleService = world.vehicles
	vs.dev_unlock = true
	var area := World.camp_origin() + Vector3(0, 0, -70)
	if scen == "far5":
		area = World.camp_origin() + Vector3(-60, 0, -260)
	if scen in ["mixed3", "full5", "far5"]:
		var t1 := vs.buy()
		vs.dispatch(t1.id, ids[0], [ids[1]], area)
	if scen in ["full5", "far5"]:
		var t2 := vs.buy()
		vs.dispatch(t2.id, ids[2], [ids[3], ids[4]], area + Vector3(25, 0, 0))
	if scen == "mixed3":
		crew.emp(ids[2])["focus"] = [area.x, area.y, area.z]
	var cash0 := cs.wallet.cash
	var t := 0.0
	var shift := float(OS.get_environment("SHIFT")) if OS.has_environment("SHIFT") else 1260.0
	var next_log := 0.0
	while t < shift:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if t >= next_log:
			next_log += 120.0 if t < 900.0 else 30.0
			var acts := []
			for w in crew.workers.values():
				var wk := w as Worker
				acts.append("%s:%s@%.0fm" % [wk.id, wk.activity, wk.global_position.distance_to(World.camp_origin())])
			var tms := []
			for tid in vs.teams:
				tms.append("%s:%s(%s)" % [tid, vs.teams[tid].state, vs.teams[tid].reason])
			print("T+%4d clock %4.0f  %s  |  %s" % [int(t), cs.clock.t, " ".join(acts), " ".join(tms)])
	var c := cs.contract.counts()
	var travel := 0.0
	var work := 0.0
	var stumps := 0
	for w in crew.workers.values():
		travel += (w as Worker).travel_seconds
		work += (w as Worker).work_seconds
	for id in crew.stats:
		stumps += int(crew.stats[id].get("stumps", 0))
	var truck_te := 0.0
	for r in world.timber.receipts:
		if str(r.source).begins_with("truck:"):
			truck_te += int(r.mte) / 1000.0
	var res := {"scenario": scen, "workers": crew.workers.size(), "axe": tier, "trucks": vs.trucks.size(), "trees_felled": int(c.felled), "stumps_removed": stumps, "accepted_tree_eq": int(world.timber.totals().accepted_mte) / 1000.0, "by_truck_tree_eq": snappedf(truck_te, 0.01), "paid_dollars": (cs.wallet.cash - cash0) / 100.0, "wages_dollars": 300 * crew.workers.size(), "walking_s": int(travel), "swinging_s": int(work), "stuck_events": crew.stuck_log.size(), "in_bed": crew.workers.values().filter(func(w: Worker) -> bool: return w.activity == "sleep").size()}
	print("WORKLOAD ", JSON.stringify(res))
	get_tree().quit()


func _give_axe(cs: CampaignService, eid: String, tier: String) -> void:
	for a in cs.equipment.axes:
		if str(a.owner) == eid:
			a.tier = tier
			return
