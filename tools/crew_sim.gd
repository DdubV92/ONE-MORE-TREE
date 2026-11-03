extends Node
## Headless crew shift: starts an in-memory campaign session (Preview, never
## saved), optionally hires up to five workers, runs one workday at real
## simulated speed (60 Hz) and reports what the crew physically did:
## trees felled, trunks bucked, tree-equivalents delivered and paid, travel
## versus productive time, stuck events, and whether everyone reached a bed
## before night.
##   godot --headless --fixed-fps 60 res://tools/crew_sim.tscn
##   env CREW=5 SHIFT_SECONDS=1200

var world: IslandWorld


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	world = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	for i in 6:
		await get_tree().physics_frame
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	for i in 3:
		await get_tree().physics_frame
	var crew := world.crew
	var target := int(OS.get_environment("CREW")) if OS.has_environment("CREW") else 2
	cs.wallet.grant(1000000, "test", "SIM", "sim cash")
	crew.refresh_candidates()
	while crew.slots_used() < target:
		var r := crew.hire(crew.candidates[0].cid)
		if not bool(r.ok):
			print("hire failed: ", r.reason)
			break
	var shift := float(OS.get_environment("SHIFT_SECONDS")) if OS.has_environment("SHIFT_SECONDS") else 1210.0
	var t := 0.0
	var next_report := 0.0
	var cash0 := cs.wallet.cash
	while t < shift:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if t >= next_report:
			next_report += 60.0
			var acts := []
			for w in crew.workers.values():
				acts.append("%s:%s" % [(w as Worker).id, (w as Worker).activity])
			print("T+%4ds day %d t=%5.0f  %s" % [int(t), cs.clock.day, cs.clock.t, " ".join(acts)])
	var res := {"workers": crew.workers.size(), "shift_s": int(shift)}
	var travel := 0.0
	var work := 0.0
	var in_bed := 0
	for w in crew.workers.values():
		var wk := w as Worker
		travel += wk.travel_seconds
		work += wk.work_seconds
		if wk.activity == "sleep":
			in_bed += 1
	res["stats"] = crew.stats
	res["travel_s"] = int(travel)
	res["swinging_s"] = int(work)
	res["paid_dollars"] = (cs.wallet.cash - cash0) / 100.0
	res["accepted_tree_eq"] = int(world.timber.totals().accepted_mte) / 1000.0
	res["trees_felled"] = cs.contract.counts().felled
	res["in_bed_at_end"] = in_bed
	res["stuck_events"] = crew.stuck_log.size()
	res["stuck_log"] = crew.stuck_log.slice(0, 6)
	res["owners_ok"] = _owners_ok(world.timber)
	print("CREW_SIM ", JSON.stringify(res))
	get_tree().quit()


func _owners_ok(t: TimberService) -> bool:
	var held := {}
	for key in t.bodies:
		for sid in (t.bodies[key] as TimberBody).sid_list():
			held[sid] = int(held.get(sid, 0)) + 1
	for sid in t.carried:
		held[sid] = int(held.get(sid, 0)) + 1
	for c in t.loads:
		for sid in t.loads[c]:
			held[sid] = int(held.get(sid, 0)) + 1
	for sid in t.queue + t.burning:
		held[sid] = int(held.get(sid, 0)) + 1
	for id in t.records:
		for s in t.records[id].segments:
			var want := 0 if int(s.state) == TimberService.Seg.CONSUMED else 1
			if int(held.get(str(s.sid), 0)) != want:
				return false
	return true
