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
	# LOT_AUDIT=1: can the crew fell every lot tree? (Phase 25)
	if OS.has_environment("LOT_AUDIT") and cs.contract.lots:
		for i in 30:
			await get_tree().physics_frame
		var bad := []
		var o := World.camp_origin()
		for k in cs.contract.lots.lots.size():
			for tid in (cs.contract.lots.lots[k].trees as PackedInt32Array):
				var ti: int = world.trees.index_of(tid)
				var tp := Vector3(World.trees.x[ti], 0, World.trees.z[ti])
				var ok_stands := 0
				for st in PlacementValidator.cut_stands(ti, crew.nav._tree_hash, crew._rock_hash):
					if crew.nav.walkable(st, true):
						ok_stands += 1
				if crew.nav.in_camp(tp) or ok_stands == 0:
					bad.append({"lot": k + 1, "tree": tid, "in_camp": crew.nav.in_camp(tp), "stands": ok_stands, "local": [snappedf(tp.x - o.x, 0.1), snappedf(tp.z - o.z, 0.1)]})
		print("LOT_AUDIT ", JSON.stringify({"trees": cs.contract.lots.total(), "not_fellable": bad}))
		get_tree().quit()
		return
	# LOT_KEEP=n: start with only the n farthest trees of lot 1 standing
	# (the rest already cleared), to watch the crew finish a lot.
	if OS.has_environment("LOT_KEEP") and cs.contract.lots:
		var keep_n := int(OS.get_environment("LOT_KEEP"))
		var ids: PackedInt32Array = cs.contract.lots.lots[0].trees
		for j in maxi(ids.size() - keep_n, 0):
			world.trees.record(ids[j]).state = TreeService.State.DISPOSED
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
				if OS.has_environment("LOT_WHY"):
					_why_not_felled(cs, crew)
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
			var per := []
			for lk in cs.contract.lots.lots.size():
				var lc: Dictionary = cs.contract.lots.lot_counts(lk, world.trees, world.timber)
				per.append([int(lc.standing), int(lc.stumps), int(lc.undelivered_mte)])
			day["lots"] = per      # [standing, stumps, undelivered mte] per lot
			# What is holding the current lot open (first few items).
			var cur: int = cs.contract.lots.current_lot()
			var held := []
			if cur >= 0:
				var o := World.camp_origin()
				for tid in (cs.contract.lots.lots[cur].trees as PackedInt32Array):
					var st := int(world.trees.records[tid].state) if world.trees.records.has(tid) else 0
					if st < TreeService.State.FALLING:
						continue
					var segs := []
					if world.timber.records.has(tid):
						for sg in world.timber.records[tid].segments:
							if int(sg.state) < TimberService.Seg.ACCEPTED_QUEUED:
								segs.append("%s:%d:%s" % [str(sg.sid).get_slice("_", 1), int(sg.state), str(world.timber.claims.get(str(sg.sid), ""))])
					if st < TreeService.State.DISPOSED or not segs.is_empty():
						var ti: int = world.trees.index_of(tid)
						held.append({"tree": tid, "state": st, "dist": int(Vector2(World.trees.x[ti] - o.x, World.trees.z[ti] - o.z).length()), "segs": segs})
			day["held"] = held.slice(0, 8)
			day["held_n"] = held.size()
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


## For each tree still standing in the felling lot: what stops each worker
## from choosing it (the same checks as CrewService._try_fell).
func _why_not_felled(cs: CampaignService, crew: CrewService) -> void:
	var lots: ContractLots = cs.contract.lots
	var k := lots.felling_lot(world.trees)
	if k < 0:
		print("   no lot tree left standing")
		return
	for tid in (lots.lots[k].trees as PackedInt32Array):
		var st := world.trees.state_of(tid)
		if st != TreeService.State.STANDING and st != TreeService.State.NOTCHED:
			continue
		var ti: int = world.trees.index_of(tid)
		var tp := Vector3(World.trees.x[ti], 0, World.trees.z[ti])
		var why := []
		for w in crew.workers.values():
			var wk := w as Worker
			var r := "ok"
			var focus := crew.work_focus(wk)
			if crew.claims.has("tree:%d" % tid):
				r = "claimed by %s" % str(crew.claims["tree:%d" % tid])
			elif Vector2(tp.x - focus.x, tp.z - focus.z).length() > crew.search_radius(wk):
				r = "outside search radius (%.0f m from focus)" % Vector2(tp.x - focus.x, tp.z - focus.z).length()
			elif crew._someone_felling_near(tp, wk):
				r = "someone felling near"
			elif crew.coord.fell_conflict(ti, wk.global_position, wk):
				r = "fall-lane conflict"
			why.append("%s[%s/%s]=%s" % [wk.id, str(wk.emp.get("job", "")), wk.activity, r])
		print("   tree %d state %d: %s" % [tid, st, "  ".join(why)])


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
