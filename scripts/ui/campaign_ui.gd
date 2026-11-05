class_name CampaignUI
extends Control
## Phase 3 campaign interface, kept small on screen:
##  - top centre: day, phase and countdown in words (never colour alone), cash
##  - J: journal (contract progress, payroll and arrears, ledger, reports)
##  - axe shop at the tool rack, daily report after sleep, rule choice for
##    pre-contract saves, contract outcome screens.
## Every panel pauses the simulation while open (explicit pause policy) and
## owns the mouse; closing it restores play. Buttons need a deliberate click;
## dismissing a notice can never press a buy button (separate panels).

var hud: Node
var svc: CampaignService
var clock_label: Label
var cash_label: Label
var panel: PanelContainer          # the one open modal panel (or null)
var _last_report := {}
var _last_cash := -1


func setup(h: Node, s: CampaignService) -> void:
	hud = h
	svc = s
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_label = UITheme.label("", 19)
	clock_label.anchor_left = 0.5
	clock_label.anchor_right = 0.5
	clock_label.offset_left = -320
	clock_label.offset_right = 320
	clock_label.offset_top = 10
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.add_theme_color_override("font_outline_color", Color.BLACK)
	clock_label.add_theme_constant_override("outline_size", 5)
	add_child(clock_label)
	cash_label = UITheme.label("", 17, Color(0.85, 0.95, 0.8))
	cash_label.anchor_left = 0.5
	cash_label.anchor_right = 0.5
	cash_label.offset_left = -320
	cash_label.offset_right = 320
	cash_label.offset_top = 36
	cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cash_label.add_theme_constant_override("outline_size", 4)
	add_child(cash_label)
	svc.report_ready.connect(func(r: Dictionary) -> void:
		_last_report = r
		show_report(r))
	svc.outcome_ready.connect(show_outcome)
	svc.rules_choice_needed.connect(show_rules_choice)


func _process(_delta: float) -> void:
	if svc == null:
		return
	_process_talk()
	clock_label.visible = svc.active
	cash_label.visible = svc.active
	if not svc.active:
		return
	var c := svc.clock
	var txt := ""
	# Phase 9: the status line tells the truth about the current mode.
	var hunt: HuntService = Game.hunt
	if hunt and hunt.hunt_active():
		var ph := hunt.phase_name()
		txt = "Survival day %d of 35  ·  %s  ·  rescue ship at dawn on day 36  ·  Biscuit: safe in the dock alcove" % [hunt.hunt_day if hunt.hunt_day > 30 else 31, ph.capitalize()]
		if hunt.ship_state == "approaching":
			txt = "Day 36 dawn  ·  the rescue ship is coming in to the dock"
		elif hunt.ship_state == "docked":
			txt = "RESCUE SHIP AT THE DOCK  ·  boarding closes in %s  ·  Biscuit boards automatically" % CampaignService.fmt_time(maxf(HuntService.BOARDING_WINDOW - hunt.ship_t, 0.0))
		if Game.rest:
			txt += "  ·  rest %d%s" % [int(round(Game.rest.rest)), "  (resting)" if Game.rest.resting else ""]
		clock_label.text = txt
		cash_label.text = "Company services closed: no hiring, boats or wages until rescue."
		return
	if svc.contract.state == ContractService.FULFILLED:
		clock_label.text = "Contract complete (day %d)  ·  exploring: no clock, no wages, no night" % int(svc.contract.outcome_at.get("day", c.day))
		cash_label.text = "$%s" % Money.format_cents(svc.wallet.cash)
		return
	match c.phase():
		WorkdayClock.Phase.DAYLIGHT:
			txt = "Day %d of %d  ·  Daylight  ·  dusk in %s" % [c.day, WorkdayClock.CONTRACT_DAYS, CampaignService.fmt_time(c.time_until_dusk())]
		WorkdayClock.Phase.DUSK:
			txt = "Day %d of %d  ·  DUSK  ·  night in %s  ·  head to camp" % [c.day, WorkdayClock.CONTRACT_DAYS, CampaignService.fmt_time(c.time_until_night())]
		_:
			txt = "Day %d of %d  ·  NIGHT  ·  sleep in the camper bed" % [c.day, WorkdayClock.CONTRACT_DAYS]
	if svc.legacy:
		txt = txt.replace(" of %d" % WorkdayClock.CONTRACT_DAYS, " (legacy, no deadline)")
	if c.is_final_day() and not svc.legacy:
		txt += "  ·  FINAL DAY: contract closes at nightfall"
	if svc.test_route:
		txt += "  ·  TEST x%d" % int(c.speed)
	# Phase 16: restedness appears only once it matters (text, not colour).
	if Game.rest and Game.rest.rest < 70.0:
		txt += "  ·  %s (rest %d)" % [RestService.band_of(Game.rest.rest), int(round(Game.rest.rest))]
	clock_label.text = txt
	if svc.wallet.cash != _last_cash:
		_last_cash = svc.wallet.cash
	var owed := svc.payroll.owed_total()
	cash_label.text = "$%s%s" % [Money.format_cents(svc.wallet.cash), ("   ·   wages owed $%s" % Money.format_cents(owed)) if owed > 0 else ""]


# ----------------------------------------------------------------- modals

func _open(p: PanelContainer) -> void:
	close_panel()
	panel = p
	add_child(p)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _talk_worker and is_instance_valid(_talk_worker):
		_talk_worker.talking_until = 0.0
	_talk_worker = null


func is_open() -> bool:
	return panel != null


func _frame(title: String, width := 620) -> Array:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_top = 0.5
	p.anchor_right = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -width * 0.5
	p.offset_right = width * 0.5
	p.offset_top = -300
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UITheme.label(title, 24, UITheme.ACCENT))
	return [p, v]


func _text(v: VBoxContainer, s: String, size := 16, color := UITheme.TEXT) -> Label:
	var l := UITheme.label(s, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(560, 0)
	v.add_child(l)
	return l


# ------------------------------------------------------------------ journal

func toggle_journal(tab := 0) -> void:
	if svc and svc.onboarding:
		svc.onboarding.journal_opened += 1
	if is_open():
		close_panel()
		return
	var f := _frame("Journal  (%s)" % Keys.label("toggle_journal"), 700)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(660, 430)
	v.add_child(tabs)
	if Game.crew and Game.crew.enabled:
		tabs.add_child(_journal_crew())
	tabs.add_child(_journal_contract())
	tabs.add_child(_journal_payroll())
	tabs.add_child(_journal_ledger())
	tabs.add_child(_journal_reports())
	if Game.rest and svc and svc.active:
		tabs.add_child(_journal_rest())
	tabs.add_child(_journal_help())
	tabs.current_tab = tab
	v.add_child(UITheme.button("Close", close_panel, 200))
	_open(p)


func _scroll(name: String) -> Array:
	var sc := ScrollContainer.new()
	sc.name = name
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return [sc, v]


func _journal_contract() -> Control:
	var s := _scroll("Contract")
	var v: VBoxContainer = s[1]
	var c := svc.contract.counts()
	var clk := svc.clock
	_text(v, "Rules: %s." % str(svc.ruleset.get("label", "?")), 14, UITheme.MUTED)
	_text(v, "Island clearance for the theme park. %s" % ("LEGACY continuation: no deadline." if svc.legacy else "Day %d of %d. The contract closes at the END of day 30's dusk (when night falls on day 30). Sleep is not required for it to close." % [clk.day, WorkdayClock.CONTRACT_DAYS]))
	_text(v, "State: %s%s" % [svc.contract.state.replace("_", " ").to_lower(), ("  (" + svc.contract.outcome_id + ")") if svc.contract.outcome_id != "" else ""])
	_text(v, "Original trees standing: %d of %d\nFelled trunks still to buck: %d\nStumps to remove: %d\nTimber not yet delivered: %.2f tree-equivalents\nDelivered and accepted: %.2f tree-equivalents (paid; stocked in the yard: %.2f, on the fire's loading pile: %.2f)\nFinal ash cleanup: %s (not required for the contract)" % [c.standing, c.total_trees, c.trunks_to_buck, c.stumps, c.undelivered_mte / 1000.0, c.accepted_mte / 1000.0, (Game.yard.stock_mte() / 1000.0) if Game.yard and is_instance_valid(Game.yard) else 0.0, c.backlog_mte / 1000.0, "clean" if c.ash_clean else "yard stock and fire still to burn"])
	var where := _log_whereabouts()
	_text(v, "Undelivered logs: %d on the ground · %d in hands (yours or crew) · %d loaded in trucks. Burning now in the pit: %d (already paid)." % [where.world, where.carried, where.truck, where.burning])
	if svc.contract.state == ContractService.FULFILLED:
		_text(v, "CONTRACT COMPLETE", 18, UITheme.ACCENT)
		for line in success_summary():
			_text(v, line, 15)
	if svc.onboarding and svc.onboarding.milestones.has("final_tree"):
		_text(v, "Every original tree is down. What is left is cleanup: the stumps and logs above.", 15, UITheme.ACCENT)
	_text(v, "Pay: exactly $100 per original tree, split across its logs and credited when each log is accepted at the camp yard (receiving cradle or a log deck; the yard must have room). Felling alone pays nothing.", 15, UITheme.MUTED)
	v.add_child(UITheme.button("Locate the nearest remaining work", func() -> void:
		var from: Vector3 = Game.player.global_position
		var near := ContractLocator.nearest(from)
		var lines := PackedStringArray()
		var names := {"tree": "standing tree", "stump": "stump to chop out", "log": "undelivered log"}
		var best := Vector3.INF
		for k in ["log", "stump", "tree"]:
			if near.has(k):
				lines.append("Nearest %s: %s" % [names[k], ContractLocator.describe(from, near[k])])
				if best == Vector3.INF:
					best = near[k]
		if best != Vector3.INF and Game.world_root:
			ContractLocator.mark(Game.world_root, best)
		hud.show_message("\n".join(lines) if not lines.is_empty() else "Nothing left to do for the contract.", 8.0)
		close_panel(), 320))
	_text(v, "To finish on time you need about %.0f trees a day from here. The island has %d trees. If night falls on day 30 with the job unfinished, the company leaves you behind." % [svc.contract.required_per_day(), c.total_trees], 15, UITheme.MUTED)
	return s[0]


func _log_whereabouts() -> Dictionary:
	var out := {"world": 0, "carried": 0, "truck": 0, "burning": 0}
	if Game.timber == null:
		return out
	for id in Game.timber.records:
		for sg in Game.timber.records[id].segments:
			match int(sg.state):
				TimberService.Seg.WORLD: out.world += 1
				TimberService.Seg.CARRIED: out.carried += 1
				TimberService.Seg.VEHICLE_RESERVED: out.truck += 1
				TimberService.Seg.BURNING: out.burning += 1
	return out


## Phase 9: guide controls, rules, pause semantics and the message log.
func _journal_help() -> Control:
	var s := _scroll("Help & log")
	var v: VBoxContainer = s[1]
	var ob := svc.onboarding
	if ob:
		var cur := ob.current()
		_text(v, "First-day guide: %s" % ("finished" if cur == "" else ("skipped" if ob.skipped else "step %d of %d" % [ob.step_index() + 1, Onboarding.STEPS.size()])), 17, UITheme.ACCENT)
		if ob.active():
			_text(v, Onboarding.fill(str(Onboarding.STEPS[ob.step_index()][1])), 15)
		var row := HBoxContainer.new()
		if ob.active():
			row.add_child(UITheme.button("Skip this step", func() -> void:
				close_panel()
				ob.skip_step(), 180))
			row.add_child(UITheme.button("Skip the guide", func() -> void:
				close_panel()
				ob.skip_all(), 180))
		else:
			row.add_child(UITheme.button("Replay the guide's hints", func() -> void:
				close_panel()
				ob.replay(), 240))
		row.add_child(UITheme.button("Show the night rules", func() -> void:
			close_panel()
			ob.show_night_rules(), 220))
		v.add_child(row)
		_text(v, "Optional: " + "  ".join(Onboarding.OPTIONAL), 14, UITheme.MUTED)
	if Game.hunt and Game.hunt.hunt_active():
		_text(v, "SURVIVAL\n" + HelpText.hunt(), 15)
	_text(v, "CONTROLS\n" + HelpText.controls(), 14)
	_text(v, "THE CONTRACT\n" + HelpText.contract(), 14)
	_text(v, "NIGHTS\n" + HelpText.night(), 14)
	_text(v, "WHAT PAUSES\n" + HelpText.time_rules(), 14)
	_text(v, "CREW GROWTH & YOUR REST\n" + HelpText.growth_and_rest(), 14)
	_text(v, "CREW TALK & THE COMPUTER\n" + HelpText.talk_and_computer(), 14)
	_text(v, "RECENT MESSAGES", 16, UITheme.ACCENT)
	var notes: Notifications = hud.get("notes") if hud else null
	if notes:
		var rec := notes.recent(30)
		rec.reverse()
		for e in rec:
			_text(v, "%sDay %d, %s into the day: %s%s" % [Notifications.TAGS[int(e.p)], int(e.day), CampaignService.fmt_time(float(e.t)), str(e.text), (" (x%d)" % int(e.count)) if int(e.count) > 1 else ""], 13)
	return s[0]


## Phase 16: restedness, the bedtime forecast and recent nights.
func _journal_rest() -> Control:
	var s := _scroll("Rest")
	var v: VBoxContainer = s[1]
	var rs: RestService = Game.rest
	_text(v, rs.describe_forecast(), 16)
	var fx: Dictionary = Game.player.axe.effects() if Game.player and Game.player.get("axe") else {}
	if not fx.is_empty():
		_text(v, "Right now: walking x%.2f, cutting work per hit x%.2f (tiredness only; boots and tools are separate)." % [rs.walk_factor(), rs.cut_factor()], 15, UITheme.MUTED)
	_text(v, "How it works: a workday costs about 30-40 rest. After nightfall every awake minute costs about 5 more and lowers tonight's sleep quality (down to 25%% after 8 minutes). Sleeping before nightfall fully restores a normal day. Below 70 rest you walk up to 15%% slower and cut up to 20%% weaker at 0. Being tired never hurts you, never stops you saving and never makes the camper unsafe. Pausing stops the clock; the computer and TV are live time.", 14, UITheme.MUTED)
	if Game.hunt and Game.hunt.hunt_active():
		_text(v, "Survival days: no sleeping through to morning. Sitting still on the couch or staying hidden recovers about 4 rest a minute up to 70 while time keeps running - it is never safe and never skips anything.", 14, UITheme.ACCENT)
	if not rs.history.is_empty():
		_text(v, "Recent nights:", 15, UITheme.ACCENT)
		for h in rs.history.slice(-5):
			_text(v, "  Day %d: bed at %d, %s -> woke at %d" % [int(h.day), int(round(float(h.bed))), ("%.0f min late, quality %d%%" % [float(h.late_min), int(round(float(h.q) * 100.0))]) if float(h.late_min) > 0.05 else "early", int(round(float(h.morning)))], 14)
	return s[0]


func _journal_payroll() -> Control:
	var s := _scroll("Payroll")
	var v: VBoxContainer = s[1]
	_text(v, "Wages: $300 per employee per active working day, settled when you sleep. Unpaid wages must be cleared by the end of the following workday (including that day's wage) or the employee quits. Cash never goes negative; unpaid wages stay owed.", 15, UITheme.MUTED)
	_text(v, "Example: %d working employees cost $%s a day. Delivering %d whole trees that day earns $%s - the break-even. Every employee needs to deliver more than three trees' worth of logs a day to pay for themselves." % [svc.payroll.active_employees().size(), Money.format_cents(svc.payroll.active_employees().size() * 30000), svc.payroll.active_employees().size() * 3, Money.format_cents(svc.payroll.active_employees().size() * 30000)], 14, UITheme.MUTED)
	_text(v, "Cash $%s  ·  tonight's payroll $%s  ·  owed now $%s" % [Money.format_cents(svc.wallet.cash), Money.format_cents(svc.payroll.todays_estimate()), Money.format_cents(svc.payroll.owed_total())])
	for e in svc.payroll.employees:
		var status := str(e.status)
		var note := ""
		match status:
			Payroll.PENDING:
				note = "on the way by boat - not working yet, no wages yet"
			Payroll.ACTIVE:
				note = "working" + ("  (development fixture)" if e.get("fixture", false) else "")
			Payroll.QUIT_REQUESTED:
				note = "QUIT over unpaid wages: leaves on the next boat; still owed what they earned"
			_:
				note = status
		var owed := svc.payroll.owed_for(str(e.id))
		var due := svc.payroll.due_day_for(str(e.id))
		_text(v, "%s  (%s)  -  %s%s" % [e.name, ", ".join(PackedStringArray(e.traits)).replace("_", " "), note, ("\n    owes $%s, due by the end of day %d" % [Money.format_cents(owed), due]) if owed > 0 else ""])
		if owed > 0:
			var eid := str(e.id)
			v.add_child(UITheme.button("Pay %s now" % e.name, func() -> void:
				var paid := svc.payroll.pay_employee(eid)
				hud.show_message("Paid $%s" % Money.format_cents(paid) if paid > 0 else "Not enough cash.")
				close_panel()
				toggle_journal(1), 260))
	return s[0]


func _journal_ledger() -> Control:
	var s := _scroll("Ledger")
	var v: VBoxContainer = s[1]
	var txs := svc.wallet.transactions
	if txs.is_empty():
		_text(v, "No transactions yet.")
	for i in range(txs.size() - 1, maxi(txs.size() - 40, 0) - 1, -1):
		var tx: Dictionary = txs[i]
		var amt := int(tx.amount)
		_text(v, "Day %d  %s  %s$%s   %s   (balance $%s)" % [int(tx.day), tx.id, "+" if amt >= 0 else "-", Money.format_cents(absi(amt)), tx.note, Money.format_cents(int(tx.balance))], 14)
	return s[0]


func _journal_reports() -> Control:
	var s := _scroll("Reports")
	var v: VBoxContainer = s[1]
	if svc.reports.is_empty():
		_text(v, "Daily reports appear here after you sleep.")
	for i in range(svc.reports.size() - 1, -1, -1):
		var r: Dictionary = svc.reports[i]
		v.add_child(UITheme.button("Day %d report" % int(r.day), func() -> void: show_report(r), 220))
	return s[0]


# --------------------------------------------------------------------- shop

func open_shop() -> void:
	if not svc.active:
		hud.show_message("The tool rack is your camp storage in the campaign. (Preview: 1/2/3 axes, %s chainsaw.)" % Keys.label("tool_saw"))
		return
	var f := _frame("Tool rack: your gear and camp storage", 980)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	_text(v, "New tools and gear are ordered on the camper computer (Supplier app) and arrive by supply boat at the parcel locker. Cash $%s · tonight's payroll $%s · wages owed $%s." % [Money.format_cents(svc.wallet.cash), Money.format_cents(svc.payroll.todays_estimate()), Money.format_cents(svc.payroll.owed_total())], 15)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(940, 380)
	v.add_child(sc)
	var gv := VBoxContainer.new()
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(gv)
	var st := UITheme.label("", 14, UITheme.ACCENT)
	var rebuild := [Callable()]
	rebuild[0] = func() -> void:
		for c in gv.get_children():
			c.queue_free()
		GearPanel.build_gear(gv, func(t: String) -> void: st.text = t, rebuild[0])
	rebuild[0].call()
	v.add_child(st)
	var te := 0.0
	if Game.timber:
		te = int(Game.timber.totals().accepted_mte) / 1000.0
	_text(v, "Hiring: Journal (%s) -> Crew." % Keys.label("toggle_journal"), 14, UITheme.MUTED)
	if Game.vehicles:
		var vs: VehicleService = Game.vehicles
		var u := vs.unlock_state()
		var row := HBoxContainer.new()
		var l := UITheme.label("Logging pickup  -  $%s  ·  seats 3, bed holds 3 tree-equivalents  ·  owned %d / %d\nUnlock: %.0f delivered tree-equivalents (you have %.2f)%s" % [Money.format_cents(int(u.price)), int(u.owned), VehicleService.MAX_TRUCKS, float(u.need), float(u.have), "  ·  UNLOCKED" if bool(u.unlocked) else ""], 15)
		l.custom_minimum_size = Vector2(430, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(l)
		var ok := vs.can_buy()
		if bool(ok.ok):
			row.add_child(UITheme.button("Buy", func() -> void:
				var r := vs.buy()
				hud.show_message("Bought pickup %s (%s). It's in the parking bays by the north gate." % [r.id, r.tx] if bool(r.ok) else str(r.reason))
				close_panel(), 120))
		else:
			var why := UITheme.label(str(ok.reason), 13, UITheme.MUTED)
			why.custom_minimum_size = Vector2(160, 0)
			why.autowrap_mode = TextServer.AUTOWRAP_WORD
			row.add_child(why)
		v.add_child(row)
	v.add_child(UITheme.button("Close", close_panel, 200))
	_open(p)


# ------------------------------------------------------------------- report

func show_report(r: Dictionary) -> void:
	var f := _frame("End of day %d" % int(r.day), 640)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	_text(v, "Cash: opened $%s, closed $%s%s" % [Money.format_cents(int(r.opening_cash)), Money.format_cents(int(r.closing_cash)), "" if bool(r.reconciles) else "  (MISMATCH - please report)"])
	_text(v, "  + deliveries credited during the day  $%s\n  - purchases  $%s%s\n  - wages paid tonight  $%s" % [Money.format_cents(int(r.income)), Money.format_cents(int(r.purchases)), ("  (" + ", ".join(PackedStringArray(r.purchase_lines)) + ")") if not (r.purchase_lines as Array).is_empty() else "", Money.format_cents(int(r.wages_paid))], 15)
	_text(v, "Trees felled today: %d  ·  stumps removed: %d  ·  original trees remaining: %d\nDelivered today: %.2f tree-equivalents" % [int(r.felled), int(r.stumps_removed), int(r.trees_remaining), int(r.delivered_mte) / 1000.0])
	if r.has("processed"):
		var y: Dictionary = r.get("yard", {})
		var wood := "Trees processed into logs: %d  ·  logs accepted: %d (%.2f tree-eq: by hand %.2f, handcart %.2f, truck %.2f)\nFire burned %.2f tree-eq  ·  yard moves: %d logs stacked on decks, %d loaded onto the fire pile" % [int(r.processed), int(r.delivered_pieces), int(r.delivered_mte) / 1000.0, int(r.hand_mte) / 1000.0, int(r.cart_mte) / 1000.0, int(r.truck_mte) / 1000.0, int(r.burned_mte) / 1000.0, int(r.yard_racked), int(r.yard_fed)]
		if not y.is_empty():
			wood += "\nYard stock (paid, waiting to burn): %.2f tree-eq  ·  cradle %d/%d  ·  decks %d logs (room for about %d more)  ·  fire pile %d/%d" % [int(y.stock_mte) / 1000.0, int(y.cradle), int(y.cradle_cap), int(y.deck_pieces), int(y.deck_free), int(y.pile), int(y.pile_cap)]
		_text(v, wood, 15)
	var lines: PackedStringArray = []
	for a in r.arrears:
		if str(a.status) == Payroll.PENDING:
			lines.append("%s: arrives in Phase 4 (no wages)" % a.name)
		elif int(a.owed) > 0:
			lines.append("%s: owed $%s, due by the end of day %d" % [a.name, Money.format_cents(int(a.owed)), int(a.due_day)])
		else:
			lines.append("%s: paid up" % a.name)
	_text(v, "Payroll: %d new wage liabilit%s.\n%s%s" % [int(r.new_liabilities), "y" if int(r.new_liabilities) == 1 else "ies", "\n".join(lines), ("\nQUIT over arrears: " + ", ".join(PackedStringArray(r.quits))) if not (r.quits as Array).is_empty() else ""], 15)
	_text(v, "Contract: %s  ·  stumps left %d  ·  undelivered %.2f tree-eq  ·  tomorrow's payroll $%s" % [("legacy, no deadline" if bool(r.legacy) else "%d days remaining" % int(r.days_remaining)), int(r.stumps), int(r.undelivered_mte) / 1000.0, Money.format_cents(int(r.next_day_payroll))], 15)
	if r.has("rest"):
		var rn: Dictionary = r.rest
		_text(v, "Your rest: went to bed at %d, %s -> woke at %d (%s)." % [int(round(float(rn.bed))), ("%.0f min after nightfall, sleep quality %d%%" % [float(rn.late_min), int(round(float(rn.q) * 100.0))]) if float(rn.late_min) > 0.05 else "before nightfall (full recovery)", int(round(float(rn.morning))), RestService.band_of(float(rn.morning))], 15)
	for rv in r.get("crew_review", []):
		_text(v, "%s  ·  level %d  ·  +%d merit today (%s)
  %s%s" % [rv.name, int(rv.level), int(round(float(rv.merit_today))), ", ".join(PackedStringArray((rv.merit_by_stage as Dictionary).keys().map(func(k) -> String: return "%s %d" % [k, int(round(float(rv.merit_by_stage[k])))]))) if not (rv.merit_by_stage as Dictionary).is_empty() else "no stage completed", str(rv.time_split) if str(rv.time_split) != "" else "no time logged", ("\n  Note: " + str(rv.tip)) if str(rv.tip) != "" else ""], 14, UITheme.MUTED)
	v.add_child(UITheme.button("Start the day", close_panel, 220))
	_open(p)


# --------------------------------------------------------- rules / outcome

func show_rules_choice() -> void:
	var f := _frame("This save is from before the contract rules", 640)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	_text(v, "This island save was made before the 30-day clearance contract (timed days, pay per delivered log, wages) existed. A backup of the original file was kept. Choose how to continue - nothing is decided until you pick:")
	v.add_child(UITheme.button("Start the 30-day contract now (day 1, island kept)", func() -> void:
		close_panel()
		svc.choose_legacy(false), 560))
	v.add_child(UITheme.button("Continue as legacy (days pass, no deadline)", func() -> void:
		close_panel()
		svc.choose_legacy(true), 560))
	_open(p)


func show_outcome(state: String, outcome_id: String) -> void:
	if state == ContractService.ABANDONMENT and Game.hunt and Game.mode == Game.Mode.CAMPAIGN and not svc.legacy:
		# Phase 6: the failure becomes the survival hunt (rules card shown there).
		if Game.hunt.mode == "none":
			Game.hunt.begin_abandonment()
		return
	if state == ContractService.FULFILLED and svc.post_contract:
		hud.show_message("Contract complete. You are exploring the cleared island (Journal → Contract shows the summary).", 6.0)
		return
	var f := _frame("Contract fulfilled" if state == ContractService.FULFILLED else "The contract has ended", 680)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	if state == ContractService.FULFILLED:
		_text(v, "The island is clear. Every original tree is down, every stump is out and every log is delivered. (%s)\nThe camp is quiet; the fire can finish the backlog in its own time." % outcome_id)
		for line in success_summary():
			_text(v, line, 15)
	else:
		_text(v, "Night fell on day 30 with the island not cleared. (%s)\nIn the finished game the boats leave you behind: days 31-35 become a survival hunt and rescue comes at dawn on day 36, while the dog waits safely at the dock refuge.\n\nDevelopment build: that survival mode arrives in Phase 6. Your save is kept at this outcome; nothing has been lost or changed." % outcome_id)
	v.add_child(UITheme.button("Back to the title screen (the completed save is kept)", func() -> void:
		close_panel()
		Game.return_to_menu(), 460))
	v.add_child(UITheme.button("Keep exploring the cleared island (no clock, wages or night)", func() -> void:
		svc.post_contract = true
		close_panel()
		if Game.world_root and Game.world_root.has_method("save_campaign"):
			Game.world_root.save_campaign(), 460))
	_open(p)


## Real numbers only (ledger, payroll, contract, crew, trucks).
func success_summary() -> PackedStringArray:
	var out := PackedStringArray()
	var c := svc.contract.counts()
	var earned := 0
	var wages := 0
	var spent := 0
	for tx in svc.wallet.transactions:
		var a := int(tx.amount)
		match str(tx.kind):
			"delivery": earned += a
			"wage": wages += -a
		if a < 0 and str(tx.kind) != "wage":
			spent += -a
	var day := int(svc.contract.outcome_at.get("day", svc.clock.day))
	out.append("Finished on day %d of 30 (%d day%s to spare)." % [day, 30 - day, "" if 30 - day == 1 else "s"])
	out.append("Trees cleared: %d original trees · %.1f tree-equivalents of logs accepted at camp." % [int(c.total_trees), float(c.accepted_mte) / 1000.0])
	out.append("Earned from deliveries: $%s · wages paid: $%s · other spending (axes, trucks, hires): $%s · cash now: $%s" % [Money.format_cents(earned), Money.format_cents(wages), Money.format_cents(spent), Money.format_cents(svc.wallet.cash)])
	var active: Array = []
	var gone: Array = []
	for e in svc.payroll.employees:
		if str(e.status) == Payroll.ACTIVE:
			active.append(str(e.name))
		elif str(e.status) in [Payroll.DEPARTED, Payroll.QUIT_REQUESTED]:
			gone.append(str(e.name))
	out.append("Crew at the finish: %s.%s" % [", ".join(active) if not active.is_empty() else "nobody", ("  Left during the contract: " + ", ".join(gone) + ".") if not gone.is_empty() else ""])
	if Game.vehicles:
		out.append("Trucks owned: %d." % Game.vehicles.trucks.size())
	var owed := svc.payroll.owed_total()
	if owed > 0:
		out.append("Wages still owed: $%s (the contract does not cancel them)." % Money.format_cents(owed))
	out.append("Biscuit is home, asleep by the camper door.")
	return out



# ------------------------------------------------------------------ crew

func _journal_crew() -> Control:
	var s := _scroll("Crew")
	var v: VBoxContainer = s[1]
	var crew: CrewService = Game.crew
	_text(v, "Crew %d / %d  ·  beds in use %d / %d  ·  wages $300 per person per day worked." % [crew.slots_used(), CrewService.MAX_EMPLOYEES, CrewService.BEDS - _free_beds(crew), CrewService.BEDS], 15, UITheme.MUTED)
	for e in svc.payroll.employees:
		var eid := str(e.id)
		var st := str(e.status)
		if st == "departed":
			continue
		var w: Worker = crew.workers.get(eid)
		var m: WorkerMind = crew.minds.get(eid)
		var axe := crew.equipment_axe_of(eid)
		var owed := svc.payroll.owed_for(eid)
		var lines := "%s  ·  %s\n%s · %s · bed %d · %s axe%s" % [e.name, ", ".join(PackedStringArray(e.traits)).replace("_", " "), {"active": "working", "pending_arrival": "arriving on the next daylight boat", "departing": "leaving (%s)" % e.get("departure_reason", ""), "pending_integration": "arriving"}.get(st, st), (w.activity_words() if w else "-"), int(e.get("bed", 0)), str(axe.get("tier", "no")), ("  ·  owed $%s by day %d" % [Money.format_cents(owed), svc.payroll.due_day_for(eid)]) if owed > 0 else ""]
		if m:
			lines += "\nMood: %s  ·  %s" % [m.state_word(), m.belief_word()]
		if st == Payroll.ACTIVE:
			var rv := crew.review(eid, svc.clock.day)
			lines += "\nLevel %d  ·  merit %d%s  ·  %s, %s; prefers %s" % [int(rv.level), int(round(float(rv.merit))), (" / %d for next" % int(rv.next)) if int(rv.next) > 0 else " (top level)", rv.ethic, rv.reliability, rv.prefers]
			lines += "\n" + "  ·  ".join(rv.skills)
			if str(rv.time_split) != "":
				lines += "\nToday: " + str(rv.time_split)
			if str(rv.tip) != "":
				lines += "\nSuggestion: " + str(rv.tip)
		_text(v, lines, 15)
		if st == Payroll.ACTIVE:
			var ops := crew.progression.opportunities(eid)
			if not ops.is_empty():
				var prow := HBoxContainer.new()
				for op in ops.slice(-2):
					var key := str(op.key)
					prow.add_child(UITheme.button("Thank them: " + str(op.what), func() -> void:
						var res := crew.progression.praise(eid, key, m)
						hud.show_message(("You thanked %s for: %s." % [e.name, str(res.what)]) if bool(res.ok) else str(res.reason))
						close_panel()
						toggle_journal(0), 300))
				v.add_child(prow)
		if st == Payroll.ACTIVE and w:
			var row := HBoxContainer.new()
			for j in [["Auto", "automatic"], ["Fell", "felling"], ["Buck", "processing"], ["Haul", "hauling"], ["Yard", "yard"], ["Follow", "follow"], ["Home", "home"]]:
				var job: String = j[1]
				var b := UITheme.button(j[0] + (" *" if str(e.get("job", "automatic")) == job else ""), func() -> void:
					order_job(w, job)
					close_panel()
					toggle_journal(0), 74)
				row.add_child(b)
			v.add_child(row)
			var row2 := HBoxContainer.new()
			row2.add_child(UITheme.button("Work near me", func() -> void:
				order_focus(w)
				close_panel(), 150))
			row2.add_child(UITheme.button("Fire...", func() -> void: confirm_fire(eid), 100))
			if Game.vehicles and not Game.vehicles.trucks.is_empty():
				row2.add_child(UITheme.button("Ride with me" + (" *" if str(e.get("job", "")) == "ride" else ""), func() -> void:
					order_job(w, "ride")
					close_panel(), 150))
			v.add_child(row2)
	_trucks_section(v, crew)
	# Hiring
	_text(v, "")
	_text(v, "Hire (fee $%s, wage $300/day; arrives by the daylight boat)" % Money.format_cents(crew.econ.hire_fee_cents), 17, UITheme.ACCENT)
	var ok := crew.can_hire()
	if not bool(ok.ok):
		_text(v, str(ok.reason), 15, UITheme.MUTED)
	crew.refresh_candidates()
	for c in crew.candidates:
		var row := HBoxContainer.new()
		var l := UITheme.label("%s  ·  %s" % [c.name, ", ".join(PackedStringArray(c.traits)).replace("_", " ")], 15)
		l.custom_minimum_size = Vector2(430, 0)
		row.add_child(l)
		var cid := str(c.cid)
		if bool(ok.ok):
			row.add_child(UITheme.button("Hire ($%s)" % Money.format_cents(int(c.fee)), func() -> void:
				var r := crew.hire(cid)
				hud.show_message(str(r.get("reason", "Hired.")) if not bool(r.ok) else "Hired. They arrive on the next daylight boat.")
				close_panel()
				toggle_journal(0), 150))
		v.add_child(row)
	var gone := svc.payroll.employees.filter(func(e: Dictionary) -> bool: return str(e.status) == "departed")
	if not gone.is_empty():
		_text(v, "Former crew: " + ", ".join(PackedStringArray(gone.map(func(e: Dictionary) -> String: return "%s (%s)" % [e.name, e.get("departure_reason", "left")]))), 14, UITheme.MUTED)
	return s[0]


## Phase 5: owned pickups, their state/reason, team dispatch and recovery.
func _trucks_section(v: VBoxContainer, crew: CrewService) -> void:
	var vs: VehicleService = Game.vehicles
	if vs == null or vs.trucks.is_empty():
		return
	_text(v, "")
	_text(v, "Pickups", 17, UITheme.ACCENT)
	for id in vs.trucks:
		var t: Truck = vs.trucks[id]
		var tm: Dictionary = vs.teams.get(id, {})
		var who := []
		for m in tm.get("members", []):
			who.append(str(crew.emp(m).get("name", m)))
		var line := "%s  ·  %s  ·  cargo %.2f / 3.00 tree-eq  ·  %.0f m driven" % [id, ("team: %s (%s)" % [", ".join(PackedStringArray(who)), str(tm.get("reason", tm.get("state", "")))]) if not tm.is_empty() else ("you are driving" if t.seat_of("boss") == "driver" else ("parked" if t.mode == "parked" else t.mode)), t.cargo_mte() / 1000.0, t.odometer]
		if t.is_flipped():
			line += "  ·  ON ITS SIDE"
		_text(v, line, 15)
		var row := HBoxContainer.new()
		if tm.is_empty():
			var free := []
			for e in svc.payroll.employees:
				if str(e.status) == Payroll.ACTIVE and str(e.get("team", "")) == "" and crew.workers.has(str(e.id)):
					free.append(str(e.id))
			if free.is_empty():
				row.add_child(UITheme.label("No free crew to send.", 14, UITheme.MUTED))
			else:
				var tid := str(id)
				row.add_child(UITheme.button("Send a team to log near me (%d)" % mini(free.size(), 3), func() -> void:
					var r := vs.dispatch(tid, free[0], free.slice(1, 3), Game.player.global_position)
					hud.show_message("Team on its way." if bool(r.ok) else str(r.reason))
					close_panel(), 300))
		else:
			var tid2 := str(id)
			row.add_child(UITheme.button("Call the team home", func() -> void:
				vs.disband(tid2, "called home by the boss")
				close_panel(), 200))
		var tid3 := str(id)
		row.add_child(UITheme.button("Recover", func() -> void:
			hud.show_message(vs.recover(vs.trucks[tid3]))
			close_panel(), 110))
		v.add_child(row)


func _free_beds(crew: CrewService) -> int:
	var used := 0
	for e in svc.payroll.employees:
		if str(e.status) != "departed" and int(e.get("bed", 0)) > 0:
			used += 1
	return CrewService.BEDS - used


func order_job(w: Worker, job: String) -> void:
	var crew: CrewService = Game.crew
	var outward := job in ["felling", "processing", "hauling", "automatic", "follow"]
	if outward and crew.real_time_left() < crew.return_seconds(w) + w.mind.return_margin() + 30.0:
		hud.show_message("%s: \"%s\"" % [w.emp.name, w.say("dusk_refuse")], 4.0)
		return
	if outward and w.mind.refuses_risk() and job in ["felling", "follow"]:
		hud.show_message("%s: \"%s\"" % [w.emp.name, w.say("refuse_risk")], 4.0)
		w.emp["job"] = "automatic"
		return
	w.emp["job"] = job
	w.abandon("new orders")
	hud.show_message("%s: \"%s\"" % [w.emp.name, w.say("follow_ack" if job == "follow" else "job_ack")], 3.0)


func order_focus(w: Worker) -> void:
	var p := Game.player.global_position
	w.emp["focus"] = [p.x, p.y, p.z]
	w.emp["job"] = "automatic"
	w.abandon("new area")
	hud.show_message("%s will work around here." % w.emp.name, 3.0)


func confirm_fire(eid: String) -> void:
	var crew: CrewService = Game.crew
	var pv := crew.fire_preview(eid)
	var f := _frame("Fire %s?" % pv.name, 560)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	_text(v, "• Wages already earned stay owed: $%s%s.\n• %s\n• Their %s axe goes back to the company rack.\n• Logs they carry (%d) are set down; their jobs are cancelled.\n• They walk to the dock and leave on %s. Their bed frees when they have left.\n• A replacement costs $%s to hire." % [Money.format_cents(int(pv.owed)), (" (due end of day %d)" % int(pv.due)) if int(pv.owed) > 0 else "", "Today counts as a day worked: tonight's $300 is still earned." if bool(pv.worked_today) else "They have not worked today, so no wage for today.", pv.axe, int(pv.carrying), pv.boat, Money.format_cents(int(pv.fee))], 15)
	var row := HBoxContainer.new()
	row.add_child(UITheme.button("Fire them", func() -> void:
		crew.fire(eid)
		close_panel(), 200))
	row.add_child(UITheme.button("Cancel", close_panel, 140))
	v.add_child(row)
	_open(p)


# ------------------------------------------------------------- talking

var _talk_worker: Worker

## Conversation with a worker. Live (the world keeps running, briefly); the
## worker stops to face you. Walking away or Esc ends it.
func open_talk(w: Worker) -> void:
	_talk_worker = w
	w.talking_until = Game.crew.now() + 30.0
	var f := _frame(w.emp.name, 600)
	var p: PanelContainer = f[0]
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = f[1]
	var talk: ConversationService = Game.crew.talk
	var authored := func(ask: String, fallback: Callable) -> String:
		var t := talk.boss_reply(w, ask) if talk else ""
		return t if t != "" else str(fallback.call())
	var reply := _text(v, "\"%s\"" % authored.call("greet", func() -> String: return w.say("greet")), 17)
	var m := w.mind
	_text(v, "%s · %s · %s" % [w.activity_words(), m.state_word(), ", ".join(PackedStringArray(m.traits)).replace("_", " ")], 14, UITheme.MUTED)
	var opts := GridContainer.new()
	opts.columns = 2
	v.add_child(opts)
	var answer := func(t: String) -> void:
		reply.text = "\"%s\"" % t
		w.talking_until = Game.crew.now() + 20.0
	var add := func(label: String, cb: Callable) -> void:
		opts.add_child(UITheme.button(label, cb, 270))
	add.call("What are you working on?", func() -> void:
		var topic: String = {"fell": "work_felling", "buck": "work_processing", "pick": "work_hauling", "deliver": "work_hauling", "deliver_deck": "work_hauling", "yard_take": "work_hauling", "yard_drop": "work_hauling", "home": "work_home", "follow": "work_follow"}.get(w.activity, "work_idle")
		answer.call(authored.call("work", func() -> String: return w.say(topic, false, {"target": "this one"}))))
	add.call("Anything holding you up?", func() -> void:
		var cause := w.idle_reason if w.idle_reason not in ["", "pause"] else Game.crew.idle_cause(w)
		var fb: String = {"yard_full": "The yard's full. Somebody needs to move logs onto the decks or the fire.", "missing_tool": "I've got no axe I can use for this.", "blocked": "Couldn't find a way through over there.", "fear": "I'm not going out there right now.", "no_task": "Nothing near me I can do. Point me somewhere?"}.get(cause, "No, all good.")
		answer.call(authored.call("blocker", func() -> String: return fb)))
	add.call("Good work today", func() -> void:
		var ops := Game.crew.progression.opportunities(w.id)
		if ops.is_empty():
			answer.call(authored.call("chat", func() -> String: return w.say("greet")))
			hud.show_message("Nothing specific to thank them for yet (thanks are for a real piece of work).", 4.0)
			return
		var res := Game.crew.progression.praise(w.id, str(ops[ops.size() - 1].key), w.mind)
		answer.call(authored.call("thanks", func() -> String: return "Thanks, boss. Appreciate it."))
		hud.show_message("You thanked %s for: %s." % [w.emp.name, str(res.get("what", ""))] if bool(res.ok) else str(res.reason), 4.0))
	add.call("How's your axe?", func() -> void:
		var tier := w.axe_tier()
		answer.call(w.say("equipment_small" if tier == "small" else "equipment", false, {"axe": tier if tier != "" else "no"})))
	add.call("About your wages", func() -> void:
		var owed := svc.payroll.owed_for(w.id)
		answer.call(authored.call("wages", func() -> String: return w.say("wages_owed" if owed > 0 else "wages_ok", false, {"owed": Money.format_cents(owed), "due": svc.payroll.due_day_for(w.id)}))))
	add.call("Noticed anything strange?", func() -> void:
		var mem := m.strongest_memory()
		var where := "the trees"
		if not mem.is_empty() and (mem.pos as Array).size() == 2:
			where = _where(Vector3(mem.pos[0], 0, mem.pos[1]))
		# Phase 17: an authored line that fits what THIS worker knows
		# (firsthand / told / nothing); the older line names the place.
		var legacy := func() -> String:
			if mem.is_empty():
				return w.say("strange_none")
			elif str(mem.modality) == "voice":
				return w.say("strange_voice", false, {"name": str(mem.get("imitated_name", "someone"))})
			elif str(mem.status) == "confirmed":
				return w.say("strange_confirmed", false, {"where": where})
			return w.say("strange_uncertain", false, {"where": where})
		var t: String = authored.call("strange", legacy) if mem.is_empty() or _roll_half() else str(legacy.call())
		answer.call(t))
	add.call("I saw something out there.", func() -> void:
		var r := Game.crew.boss_report(w)
		if r == "corroborated":
			answer.call(w.say("report_corroborated"))
		elif m.has("skeptical"):
			answer.call(w.say("report_skeptic_rumor"))
		else:
			answer.call(w.say("report_rumor")))
	add.call("It's alright. We're safe here.", func() -> void:
		var credible := Game.crew.nav.in_camp(w.global_position) or svc.clock.phase() == WorkdayClock.Phase.DAYLIGHT
		var r := m.reassure(Game.crew.now(), credible)
		answer.call(w.say("reassure_" + r)))
	add.call("Forget it. It was nothing.", func() -> void:
		m.dismissed(Game.crew.now())
		answer.call(w.say("dismiss_hurt" if m.firsthand_count() > 0 else "strange_none")))
	add.call("Stick with me.", func() -> void:
		order_job(w, "follow")
		answer.call(w.say("follow_ack")))
	add.call("Back to work (automatic).", func() -> void:
		order_job(w, "automatic"))
	add.call("Work around here.", func() -> void:
		order_focus(w))
	add.call("Head back to camp.", func() -> void:
		order_job(w, "home"))
	var spare := _spare_axe_for(w)
	if not spare.is_empty():
		add.call("Take my %s axe." % spare.tier, func() -> void:
			spare.owner = w.id
			svc.equipment.changed.emit()
			w.body_char.set_axe_tier(w.axe_tier())
			answer.call(w.say("job_ack")))
	if svc.payroll.owed_for(w.id) > 0:
		add.call("Here are your wages.", func() -> void:
			var paid := svc.payroll.pay_employee(w.id)
			answer.call("Thanks, boss." if paid > 0 else "...You don't have it, do you."))
	add.call("You're fired.", func() -> void:
		close_panel()
		confirm_fire(w.id))
	add.call("That's all.", close_panel)
	panel = p
	add_child(p)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spare_axe_for(w: Worker) -> Dictionary:
	# A company axe the boss owns but is not holding, better than the
	# worker's; handing it over is an explicit equipment transaction.
	var mine := w.axe_tier()
	for a in svc.equipment.owned_by("storage") + svc.equipment.owned_by("boss"):
		if str(a.id) == svc.equipment.equipped:
			continue
		if Equipment.TIERS.find(str(a.tier)) > Equipment.TIERS.find(mine):
			return a
	return {}


var _half := false


func _roll_half() -> bool:
	_half = not _half
	return _half


func _where(p: Vector3) -> String:
	var o := World.camp_origin()
	var d := Vector2(p.x - o.x, p.z - o.z)
	if d.length() < 30.0:
		return "the camp"
	var ang := rad_to_deg(atan2(d.x, -d.y))
	const DIRS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return "the %s trees" % DIRS[int(round(fposmod(ang, 360.0) / 45.0)) % 8]


func _process_talk() -> void:
	if _talk_worker and panel and is_instance_valid(_talk_worker) and Game.player:
		if Game.player.global_position.distance_to(_talk_worker.global_position) > 6.0:
			close_panel()
