class_name CampaignService
extends Node
## Phase 3 campaign orchestration: owns the authoritative WorkdayClock, the
## Wallet (only payment service), Payroll, Equipment and the Contract; keeps
## per-day statistics; runs the sleep -> settlement -> report -> morning
## transition exactly once per night; drives lighting from the clock; and
## captures/restores the "campaign" and "economy" save blocks.
##
## Preview mode: the clock does not run and money is not tracked, unless the
## Day & Economy Test route enables an isolated in-memory session (never
## written to disk).

signal notice(text: String, seconds: float)
signal report_ready(report: Dictionary)
signal outcome_ready(state: String, outcome_id: String)
signal rules_choice_needed()
signal request_pause()

const RULE_SET := "contract_v1"

var clock: WorkdayClock
var wallet: Wallet
var payroll: Payroll
var equipment: Equipment
var contract: ContractService
var config: EconomyConfig
var rule_set := RULE_SET
## Phase 10: the campaign's versioned ruleset (kept for the campaign's life).
var ruleset: Dictionary = Ruleset.get_def(Ruleset.LEGACY)
var legacy := false
var reports: Array[Dictionary] = []
var day_stats := {}                # current day: opening cash, felled, delivered...
var active := false                # a timed campaign or the test route
var test_route := false
var phase2_migrated := false
var _sleeping := false
var crew: CrewService          # Phase 4 (set by the world)
var vehicles: VehicleService   # Phase 5 (set by the world)
var spawn_crew := true         # tests of the bare economy turn this off


func _ready() -> void:
	config = load("res://config/economy.tres")
	clock = WorkdayClock.new()
	clock.name = "Clock"
	add_child(clock)
	wallet = Wallet.new()
	wallet.name = "Wallet"
	add_child(wallet)
	payroll = Payroll.new()
	payroll.name = "Payroll"
	add_child(payroll)
	equipment = Equipment.new()
	equipment.name = "Equipment"
	add_child(equipment)
	contract = ContractService.new()
	contract.name = "Contract"
	add_child(contract)


## Phase 9 first-day guide (per save).
var onboarding: Onboarding = Onboarding.new()


func setup() -> void:
	if onboarding.get_parent() == null:
		onboarding.name = "Onboarding"
		add_child(onboarding)
	wallet.setup(Game.timber, clock)
	payroll.setup(wallet, config)
	equipment.setup(wallet, config)
	contract.setup(Game.trees, Game.timber, clock)
	clock.warning.connect(_on_warning)
	clock.night_started.connect(func(_d: int) -> void: notice.emit("Night. Camp lamps and the camper are safe; sleep in the camper bed to end the day.", 6.0))
	contract.outcome.connect(func(s: String, oid: String) -> void: outcome_ready.emit(s, oid))
	contract.progress_changed.connect(_check_final_tree)
	wallet.transaction.connect(_on_tx)
	payroll.quit_due_to_arrears.connect(func(eid: String) -> void: notice.emit("%s has quit over unpaid wages (leaves when crew arrive in Phase 4)." % payroll.employee(eid).get("name", eid), 6.0))
	if Game.trees:
		Game.trees.tree_felled.connect(func(_id: int) -> void: _stat_add("felled", 1))
		Game.trees.stump_removed.connect(func(_id: int) -> void: _stat_add("stumps_removed", 1))
	if Game.timber:
		Game.timber.delivery_accepted.connect(func(r: Dictionary) -> void: _stat_add("delivered_mte", int(r.mte)))
	equipment.changed.connect(_sync_axe)
	wallet.enabled = not Game.is_preview()


# ------------------------------------------------------------ campaign life

## Phase 12: set when a loaded save names a different frozen island.
var island_mismatch := false

## Fresh timed campaign (the rules are fixed: 30 days, 15 + 5 minutes).
func new_campaign() -> void:
	ruleset = Ruleset.get_def(Ruleset.for_variant(World.manifest_variant)) if World.manifest_variant != "full" else Ruleset.get_def(Ruleset.STANDARD if Game.mode == Game.Mode.CAMPAIGN else Ruleset.LEGACY)
	rule_set = str(ruleset.id)
	legacy = false
	clock.restore({"day": 1, "t": 0.0, "running": true, "deadline_enabled": true})
	wallet.restore({})
	wallet.grant(int(ruleset.start_cash_cents), "start", "NEW-CAMPAIGN", "Starting cash (%s, provisional)" % str(ruleset.label))
	payroll.restore({})
	payroll.employees = Payroll.starting_crew(int(ruleset.starting_employees))
	var ids := []
	for e in payroll.employees:
		ids.append(e.id)
	equipment.init_new(ids)
	contract.restore({"state": ContractService.ACTIVE})
	if onboarding:
		onboarding.start_new()
	post_contract = false
	reports.clear()
	phase2_migrated = true
	_begin_day_stats()
	active = true
	_sync_axe()
	if crew and spawn_crew:
		crew.when_ready(crew.start_new_campaign)


## Development: isolated in-memory Day & Economy Test session (Preview).
func start_test_route(with_fixtures := true, with_crew := true) -> void:
	spawn_crew = with_crew
	new_campaign()
	test_route = true
	# Development sessions skip the first-day guide (rules count as known).
	if onboarding:
		onboarding.restore({})
	wallet.enabled = true
	if with_fixtures:
		for e in payroll.employees:
			e.status = Payroll.ACTIVE
			e["fixture"] = true
	notice.emit("Day & Economy Test: an isolated session in memory (never saved). Payroll fixtures are active.", 6.0)


func _begin_day_stats() -> void:
	day_stats = {"day": clock.day, "opening_cash": wallet.cash, "felled": 0, "delivered_mte": 0, "stumps_removed": 0, "trees_standing_start": contract.counts().standing}


func _stat_add(k: String, n: int) -> void:
	if active:
		day_stats[k] = int(day_stats.get(k, 0)) + n


func _on_tx(tx: Dictionary) -> void:
	if str(tx.kind) == "delivery" and active:
		notice.emit("+$%s delivery credited" % Money.format_cents(int(tx.amount)), 2.5)


## Once-only milestone: the last original standing tree is down. It is
## NOT completion if stumps or logs remain; the message says what is left.
func _check_final_tree() -> void:
	if not active or test_route or onboarding == null or onboarding.milestones.has("final_tree"):
		return
	var c := contract.counts()
	if int(c.standing) != 0:
		return
	onboarding.milestone("final_tree")
	if contract.complete(c):
		return
	notice.emit("The last standing tree is down! Still to finish the contract: %d stump(s) and %.1f tree-equivalents of logs to deliver. Journal → Contract → Locate the nearest remaining work." % [int(c.stumps), float(c.undelivered_mte) / 1000.0], 10.0)


## Completed contract kept for exploring (Phase 9): no clock, no workdays,
## no wages, no hunt; saved as its own mode.
var post_contract := false


func _on_warning(kind: String, left: float) -> void:
	if kind == "dusk" and onboarding and not test_route:
		onboarding.on_dusk()
	var mins := int(ceil(left / 60.0))
	match kind:
		"dusk":
			notice.emit("Dusk. Head back to camp: night falls in %d minutes." % mins, 7.0)
		"dusk_reminder":
			notice.emit("Reminder: %d minutes of light left." % mins, 5.0)
		"dusk_final":
			notice.emit("Final warning: one minute until night. Get inside the camp lights.", 6.0)


func _sync_axe() -> void:
	var p := Game.player
	if p and p.get("axe") and active:
		p.axe.equip(equipment.equipped_tier())


func _process(_delta: float) -> void:
	if active and clock.running and Game.environment and not test_route_light_override:
		var env: EnvironmentController = Game.environment
		var mp := EnvironmentController.moon_phase_for_day(clock.day)
		if absf(env.moon_phase - mp) > 0.0001:
			env.moon_phase = mp
		env.set_time_of_day(clock.lighting_hour())


var test_route_light_override := false


func _notification(what: int) -> void:
	# Single-player baseline: losing focus pauses (no catch-up on return).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and not Game.is_preview():
		request_pause.emit()


# ---------------------------------------------------------------- sleeping

func can_sleep() -> Dictionary:
	if not active:
		return {"ok": false, "reason": "Sleeping only advances days in the campaign."}
	if Game.hunt and Game.hunt.hunt_active():
		return {"ok": false, "reason": "Survival days are continuous: lying down does not skip time. Rest only matters as a hiding place."}
	if contract.state == ContractService.FULFILLED:
		return {"ok": false, "reason": "The contract is complete: there are no more workdays to sleep through. Explore as long as you like."}
	if contract.is_closed():
		return {"ok": false, "reason": "The contract has ended."}
	if _sleeping:
		return {"ok": false, "reason": ""}
	if Game.dog_rescue and Game.dog_rescue.blocks_sleep():
		var dr: DogRescue = Game.dog_rescue
		var left := maxf(DogRescue.ASSIST_AFTER - dr.t, 0.0) if dr.state == "SEARCH" else -1.0
		return {"ok": false, "reason": "Find your dog first: Biscuit is unhurt, nearby and whining - follow the sound, then walk home together.%s" % ((" If you can't find Biscuit, the dog finds the way home on its own in about %s." % fmt_time(left)) if left >= 0.0 else "")}
	if clock.phase() == WorkdayClock.Phase.DAYLIGHT:
		return {"ok": false, "reason": "Too early to sleep. The workday runs until dusk (%s left)." % fmt_time(clock.time_until_dusk())}
	return {"ok": true}


## Ends the day: settlement, bounded overnight burn, report, next morning.
## Locked so repeated input can never run it twice; settlement itself is
## idempotent per day, so a reload cannot repeat wages or reports.
func sleep() -> Dictionary:
	var ok := can_sleep()
	if not bool(ok.ok):
		return ok
	_sleeping = true
	var d := clock.day
	if clock.is_final_day() and clock.deadline_enabled:
		# Sleeping on day 30 would cross the deadline: close it now.
		clock.t = WorkdayClock.NIGHT_AT
		contract._close_deadline()
		_sleeping = false
		return {"ok": true, "terminal": true}
	var settlement := payroll.settle_day(d)
	if Game.timber:
		Game.timber.advance_burn(TimberService.OVERNIGHT_BURN_SECONDS)
	var report := build_report(d, settlement)
	if reports.is_empty() or int(reports[reports.size() - 1].day) != d:
		reports.append(report)
	clock.start_next_day()
	_begin_day_stats()
	_wake_player()
	if Game.director:
		Game.director.morning_cleanup()
	if Game.threat:
		Game.threat.on_morning()
	if Game.world_root and Game.world_root.has_method("save_campaign"):
		Game.world_root.save_campaign()
		Game.world_root.save_checkpoint("morning")
	report_ready.emit(report)
	_sleeping = false
	return {"ok": true, "report": report}


func _wake_player() -> void:
	var p := Game.player
	if p == null:
		return
	var beds := p.get_tree().get_nodes_in_group("player_bed")
	if beds.is_empty():
		return
	var bed: Node3D = beds[0]
	# Stand beside the bed, inside the camper (never on top of it).
	var side := bed.global_position + bed.global_basis.x * 0.95
	side.y = bed.global_position.y - 0.7
	p.teleport_feet(side, bed.global_rotation.y)


func build_report(d: int, settlement: Dictionary) -> Dictionary:
	var income := 0
	var purchases := 0
	var wages := 0
	var other := 0
	var purchase_lines: Array[String] = []
	for tx in wallet.transactions:
		if int(tx.day) != d:
			continue
		match str(tx.kind):
			"delivery":
				income += int(tx.amount)
			"purchase", "hire":
				purchases += -int(tx.amount)
				purchase_lines.append("%s $%s" % [tx.note, Money.format_cents(-int(tx.amount))])
			"wage":
				wages += -int(tx.amount)
			_:
				other += int(tx.amount)
	var opening := int(day_stats.get("opening_cash", wallet.cash)) if int(day_stats.get("day", d)) == d else wallet.cash
	var c := contract.counts()
	var arrears := []
	for e in payroll.employees:
		var owed := payroll.owed_for(str(e.id))
		arrears.append({"id": e.id, "name": e.name, "status": e.status, "owed": owed, "due_day": payroll.due_day_for(str(e.id))})
	var closing := wallet.cash
	return {
		"day": d, "settlement": settlement.get("settlement", ""),
		"opening_cash": opening, "closing_cash": closing,
		"income": income, "purchases": purchases, "purchase_lines": purchase_lines, "wages_paid": wages, "other": other,
		"reconciles": opening + income - purchases - wages + other == closing,
		"felled": int(day_stats.get("felled", 0)), "stumps_removed": int(day_stats.get("stumps_removed", 0)),
		"trees_remaining": int(c.standing), "delivered_mte": int(day_stats.get("delivered_mte", 0)),
		"new_liabilities": int(settlement.get("new_liabilities", 0)), "arrears": arrears,
		"quits": settlement.get("quits", []),
		"contract_day": d, "days_remaining": WorkdayClock.CONTRACT_DAYS - d,
		"stumps": int(c.stumps), "undelivered_mte": int(c.undelivered_mte), "trunks_to_buck": int(c.trunks_to_buck),
		"next_day_payroll": payroll.todays_estimate(), "owed_total": payroll.owed_total(),
		"legacy": legacy,
	}


# ----------------------------------------------------------------- legacy

## A save from before the timed contract: the player chooses explicitly.
func choose_legacy(continue_untimed: bool) -> void:
	if continue_untimed:
		legacy = true
		rule_set = "legacy_untimed"
		contract.restore({"state": ContractService.LEGACY})
		clock.deadline_enabled = false
		notice.emit("Legacy continuation: days pass, but there is no contract deadline.", 6.0)
	else:
		legacy = false
		rule_set = RULE_SET
		contract.restore({"state": ContractService.ACTIVE})
		clock.restore({"day": 1, "t": 0.0, "running": true, "deadline_enabled": true})
		notice.emit("The 30-day contract starts now (day 1). Your island progress is kept.", 6.0)
	clock.running = true
	active = true
	_begin_day_stats()
	_restore_crew({})
	if Game.world_root and Game.world_root.has_method("save_campaign"):
		Game.world_root.save_campaign()


# ------------------------------------------------------------ persistence

## Phase 4: bring the crew back exactly once. Saves with crew data restore
## it; Phase 3 saves activate their pending starting crew once (marker on
## the economy block), without back-charging wages.
func _restore_crew(data: Dictionary) -> void:
	if crew == null or not spawn_crew:
		return
	crew.when_ready(func() -> void:
		if not data.is_empty():
			crew.restore(data)
		else:
			crew.enabled = true
			var n := crew.migrate_pending()
			if n > 0:
				notice.emit("Your two starting crew members have arrived at camp (Phase 4 crew).", 6.0)
			crew.refresh_candidates()
			crew.roster_changed.emit())


func capture_campaign() -> Dictionary:
	return {"rule_set": rule_set, "phase3": true, "legacy": legacy, "clock": clock.capture(), "contract": contract.capture(), "day_stats": day_stats.duplicate(), "reports": reports.slice(-35), "state": contract.state, "day": clock.day, "crew": crew.capture() if crew and crew.enabled else {}, "vehicles": vehicles.capture() if vehicles and vehicles.built else {}, "onboarding": onboarding.capture() if onboarding else {}, "post_contract": post_contract, "ruleset": ruleset.duplicate(true), "island": World.island_signature()}


func capture_economy() -> Dictionary:
	return {"wallet": wallet.capture(), "payroll": payroll.capture(), "equipment": equipment.capture(), "phase2_migrated": phase2_migrated}


## Restores both blocks. Returns true if the player must choose rules
## (save from before the timed contract).
func restore(campaign: Dictionary, economy: Dictionary) -> bool:
	var pre_phase3 := not bool(campaign.get("phase3", false))
	wallet.restore(economy.get("wallet", {}))
	payroll.restore(economy.get("payroll", {}))
	equipment.restore(economy.get("equipment", {}))
	if payroll.employees.is_empty():
		payroll.employees = Payroll.starting_crew()
	phase2_migrated = bool(economy.get("phase2_migrated", false))
	# Phase 2 tracked delivery entitlements without paying them: credit each
	# genuine accepted receipt exactly once, with a conversion marker.
	if not phase2_migrated:
		var n := wallet.reconcile_receipts("migrated_phase2_delivery")
		phase2_migrated = true
		if n > 0:
			notice.emit("Converted %d earlier delivery receipt(s) into cash (once)." % n, 6.0)
	else:
		# Recoverable write protocol: any genuine receipt saved without its
		# credit is credited now; credited ones are never paid again.
		wallet.reconcile_receipts()
	rule_set = str(campaign.get("rule_set", RULE_SET))
	legacy = bool(campaign.get("legacy", false))
	post_contract = bool(campaign.get("post_contract", false))
	var rid := Ruleset.id_of_save(campaign)
	ruleset = (campaign.get("ruleset", {}) as Dictionary).duplicate(true) if Ruleset.known(rid) and campaign.has("ruleset") else Ruleset.get_def(rid)
	# Phase 12: a save keeps its island for life. The variant was chosen from
	# this save's ruleset before the world was built; a signature mismatch
	# means the frozen data changed underneath it - say so, never re-plan.
	var isl: Dictionary = campaign.get("island", {})
	island_mismatch = not isl.is_empty() and (str(isl.get("revision", "")) != World.island_revision or str(isl.get("trees", "")) != str(World.island_signature().trees))
	if island_mismatch:
		push_warning("Save island %s does not match the loaded island %s" % [str(isl), str(World.island_signature())])
	if onboarding:
		onboarding.restore(campaign.get("onboarding", {}))
	reports.clear()
	for r in campaign.get("reports", []):
		reports.append(r)
	contract.restore(campaign.get("contract", {"state": ContractService.LEGACY if legacy else ContractService.ACTIVE}))
	if pre_phase3:
		clock.restore({"day": 1, "t": 0.0, "running": false})
		if wallet.transactions.is_empty() or wallet.transactions.filter(func(tx: Dictionary) -> bool: return str(tx.kind) == "start").is_empty():
			wallet.grant(config.starting_cash_cents, "start", "MIGRATION", "Starting cash (provisional)")
		if equipment.axes.size() <= 1:
			var ids := []
			for e in payroll.employees:
				ids.append(e.id)
			equipment.init_new(ids)
		active = false
		rules_choice_needed.emit()
		return true
	clock.restore(campaign.get("clock", {}))
	clock.running = not contract.is_closed()
	clock.deadline_enabled = not legacy
	day_stats = (campaign.get("day_stats", {}) as Dictionary).duplicate()
	if day_stats.is_empty():
		_begin_day_stats()
	active = true
	_sync_axe()
	_restore_crew(campaign.get("crew", {}))
	var vd: Dictionary = campaign.get("vehicles", {})
	if vehicles and not vd.is_empty():
		vehicles.when_ready(func() -> void: vehicles.restore(vd))
	if contract.is_closed():
		outcome_ready.emit.call_deferred(contract.state, contract.outcome_id)
	return false


static func fmt_time(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]
