extends Node
## Headless crew shift: starts an in-memory campaign session (Preview, never
## saved), optionally hires up to five workers, runs one workday at real
## simulated speed (60 Hz) and reports what the crew physically did:
## trees felled, trunks bucked, tree-equivalents delivered and paid, travel
## versus productive time, stuck events, and whether everyone reached a bed
## before night.
##   godot --headless --fixed-fps 60 res://tools/crew_sim.tscn
##   env CREW=5 SHIFT_SECONDS=1500
## DAYS=n (Phase 25) sleeps through each night and runs n workdays in a
## row, printing one CREW_DAY line per day: lot progress, wood, lumber
## pay, lot pay, wages and cash. PAY=fair raises each worker to the wage
## they think is fair every morning (a boss who keeps the crew; at the
## $100 minimum people quit within a week, by design).

var world: IslandWorld


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	# Phase 14: ISLAND=island_r2 runs on the new-campaign island.
	if OS.has_environment("ISLAND"):
		Game.preview_variant = OS.get_environment("ISLAND")
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
	# Phase 14: TOOL=saw|large|medium|small issues that tool to every worker
	# (real item records, equipped at the start).
	var tool_env := OS.get_environment("TOOL") if OS.has_environment("TOOL") else ""
	if tool_env != "":
		for e in cs.payroll.employees:
			var item := cs.equipment.add_item("chainsaw" if tool_env == "saw" else "axe", "saw" if tool_env == "saw" else tool_env, str(e.id), "sim")
			cs.equipment.equip(str(e.id), str(item.id))
	var shift := float(OS.get_environment("SHIFT_SECONDS")) if OS.has_environment("SHIFT_SECONDS") else WorkdayClock.NIGHT_AT + 10.0
	var t := 0.0
	var next_report := 0.0
	var cash0 := cs.wallet.cash
	var days := int(OS.get_environment("DAYS")) if OS.has_environment("DAYS") else 1
	var quiet := days > 1
	var prev := {"mte": 0, "felled": 0, "cash": cash0, "mill": 0}
	var fair := OS.get_environment("PAY") == "fair"
	for dn in days:
		t = 0.0
		next_report = 0.0
		if fair and cs.pay:
			for e in cs.payroll.employees:
				var eid := str(e.id)
				var gap := cs.pay.expected(eid) - cs.pay.rate(eid)
				if gap > 0:
					cs.pay.change_rate(eid, int(ceil(float(gap) / float(PayMorale.STEP))))
		while t < shift:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if t >= next_report:
				next_report += 60.0
				if quiet:
					continue
				var acts := []
				for w in crew.workers.values():
					acts.append("%s:%s" % [(w as Worker).id, (w as Worker).activity])
				print("T+%4ds day %d t=%5.0f  %s" % [int(t), cs.clock.day, cs.clock.t, " ".join(acts)])
		if days <= 1:
			break
		# The day's line, then sleep into the next morning.
		var cnt: Dictionary = cs.contract.counts()
		var mte := int(world.timber.totals().accepted_mte)
		var day := {"day": cs.clock.day, "workers": crew.workers.size(), "accepted_te": snappedf((mte - int(prev.mte)) / 1000.0, 0.01), "felled": int(cnt.felled) - int(prev.felled),
			"standing": int(cnt.standing), "stumps": int(cnt.stumps), "mill_paid": (world.timber.mill.earnings_total - int(prev.mill)) / 100.0,
			"yard_te": Game.yard.stock_mte() / 1000.0 if Game.yard else 0.0, "rack": world.timber.mill.rack.size(), "stuck": crew.stuck_log.size()}
		if cs.contract.lots:
			day["lots_done"] = cs.contract.lots.done.size()
			day["lot"] = cs.contract.lots.current_lot() + 1
		var in_bed_n := 0
		for w in crew.workers.values():
			if (w as Worker).activity == "sleep":
				in_bed_n += 1
		day["in_bed"] = in_bed_n
		var g := 0
		var sl := cs.sleep()
		while not bool(sl.ok) and g < 1800:
			await get_tree().physics_frame
			g += 1
			if g % 120 == 0:
				sl = cs.sleep()
		day["slept"] = bool(sl.ok)
		var wages := 0
		for e in cs.payroll.employees:
			if cs.pay:
				wages += cs.pay.rate(str(e.id))
		day["rates"] = wages / 100.0
		day["cash"] = cs.wallet.cash / 100.0
		day["cash_change"] = (cs.wallet.cash - int(prev.cash)) / 100.0
		if not bool(sl.ok):
			day["sleep_refused"] = str(sl.get("reason", ""))
		print("CREW_DAY ", JSON.stringify(day))
		prev = {"mte": mte, "felled": int(cnt.felled), "cash": cs.wallet.cash, "mill": world.timber.mill.earnings_total}
		if not bool(sl.ok) or bool(sl.get("terminal", false)) or cs.contract.is_closed():
			break
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
	res["tool"] = tool_env if tool_env != "" else "small (default)"
	res["coord"] = crew.coord.stats
	if Game.yard:
		res["yard_stock_te"] = Game.yard.stock_mte() / 1000.0
		res["yard_cradle"] = Game.yard.cradle.size()
	var ml: MillLedger = world.timber.mill
	res["mill"] = {"pallets": ml.pallets_total, "accepted_l": ml.accepted_l, "processed_l": ml.processed_l, "rack": ml.rack.size(), "open_pallet_l": ml.open_fill(), "paid_dollars": ml.earnings_total / 100.0}
	# Phase 16: merit per worker, levels, time split and conservation.
	var mer := {}
	for w in crew.workers.values():
		var wk2 := w as Worker
		var tm := crew.progression.day_time(wk2.id, cs.clock.day)
		var tm_i := {}
		for k in tm:
			tm_i[k] = int(tm[k])
		mer[wk2.id] = {"merit": int(crew.merit.total(wk2.id)), "level": crew.progression.career(wk2.id), "stages": crew.merit.by_stage.get(wk2.id, {}), "skills": crew.merit.skills.get(wk2.id, {}), "time": tm_i}
	res["merit"] = mer
	var over := 0
	for tid in crew.merit.per_tree:
		if float(crew.merit.per_tree[tid]) > MeritLedger.TREE_MAX + 0.01:
			over += 1
	res["merit_trees"] = crew.merit.per_tree.size()
	res["merit_trees_over_cap"] = over
	res["merit_rejected_repeats"] = crew.merit.rejected
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
	if Game.yard:
		for sid in Game.yard.all_yard_sids():
			if not Game.yard.is_yard_move(str(sid)):
				held[sid] = int(held.get(sid, 0)) + 1
	# Phase 24: the sawmill's feed rack and the log in the saw.
	for r in t.mill.rack:
		held[str(r.sid)] = int(held.get(str(r.sid), 0)) + 1
	if not t.mill.job.is_empty():
		held[str(t.mill.job.sid)] = int(held.get(str(t.mill.job.sid), 0)) + 1
	for id in t.records:
		for s in t.records[id].segments:
			var want := 0 if int(s.state) in [TimberService.Seg.CONSUMED, TimberService.Seg.MILLED] else 1
			if int(held.get(str(s.sid), 0)) != want:
				return false
	return true
