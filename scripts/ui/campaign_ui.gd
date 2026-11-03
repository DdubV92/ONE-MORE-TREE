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
	clock_label.visible = svc.active
	cash_label.visible = svc.active
	if not svc.active:
		return
	var c := svc.clock
	var txt := ""
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
	if is_open():
		close_panel()
		return
	var f := _frame("Journal  (J)", 700)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(660, 430)
	v.add_child(tabs)
	tabs.add_child(_journal_contract())
	tabs.add_child(_journal_payroll())
	tabs.add_child(_journal_ledger())
	tabs.add_child(_journal_reports())
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
	_text(v, "Island clearance for the theme park. %s" % ("LEGACY continuation: no deadline." if svc.legacy else "Day %d of %d. The contract closes at the END of day 30's dusk (when night falls on day 30). Sleep is not required for it to close." % [clk.day, WorkdayClock.CONTRACT_DAYS]))
	_text(v, "State: %s%s" % [svc.contract.state.replace("_", " ").to_lower(), ("  (" + svc.contract.outcome_id + ")") if svc.contract.outcome_id != "" else ""])
	_text(v, "Original trees standing: %d of %d\nFelled trunks still to buck: %d\nStumps to remove: %d\nTimber not yet delivered: %.2f tree-equivalents\nDelivered and accepted: %.2f tree-equivalents (waiting in the pit queue: %.2f)\nFinal ash cleanup: %s (not required for the contract)" % [c.standing, c.total_trees, c.trunks_to_buck, c.stumps, c.undelivered_mte / 1000.0, c.accepted_mte / 1000.0, c.backlog_mte / 1000.0, "clean" if c.ash_clean else "fire still burning"])
	_text(v, "Pay: exactly $100 per original tree, split across its logs and credited when each log is accepted at the camp rack. Felling alone pays nothing.", 15, UITheme.MUTED)
	_text(v, "To finish on time you would need about %.0f trees a day from here. The island has %d trees (a provisional count); one person cannot clear it alone. The crew (Phase 4) and trucks (Phase 5) are what make it possible." % [svc.contract.required_per_day(), c.total_trees], 15, UITheme.MUTED)
	return s[0]


func _journal_payroll() -> Control:
	var s := _scroll("Payroll")
	var v: VBoxContainer = s[1]
	_text(v, "Wages: $300 per employee per active working day, settled when you sleep. Unpaid wages must be cleared by the end of the following workday (including that day's wage) or the employee quits. Cash never goes negative; unpaid wages stay owed.", 15, UITheme.MUTED)
	_text(v, "Cash $%s  ·  tonight's payroll $%s  ·  owed now $%s" % [Money.format_cents(svc.wallet.cash), Money.format_cents(svc.payroll.todays_estimate()), Money.format_cents(svc.payroll.owed_total())])
	for e in svc.payroll.employees:
		var status := str(e.status)
		var note := ""
		match status:
			Payroll.PENDING:
				note = "arrives with the crew in Phase 4 - not working, no wages yet"
			Payroll.ACTIVE:
				note = "working" + ("  (development fixture)" if e.get("fixture", false) else "")
			Payroll.QUIT_REQUESTED:
				note = "QUIT over unpaid wages (leaves in Phase 4); still owed what they earned"
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
		hud.show_message("The axe shop opens in the campaign. (Preview: use 1/2/3 to try tiers.)")
		return
	var f := _frame("Tool rack: axes")
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	_text(v, "Cash $%s. Tonight's payroll $%s, wages owed $%s." % [Money.format_cents(svc.wallet.cash), Money.format_cents(svc.payroll.todays_estimate()), Money.format_cents(svc.payroll.owed_total())], 16)
	const DESC := {"small": "Hatchet. x1.00 cutting rate.", "medium": "Felling axe. x1.40 rate: +40% work per swing (a cut takes about 29% less time).", "large": "Heavy felling axe. x1.96 rate: +40% over the medium (a cut takes about half the time of the hatchet)."}
	for tier in Equipment.TIERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var owned := svc.equipment.boss_has(tier)
		var price := svc.equipment.price(tier)
		var l := UITheme.label("%s  -  %s\n%s" % [tier.capitalize(), ("owned" + ("  ·  EQUIPPED" if svc.equipment.equipped_tier() == tier else "")) if owned else "$" + Money.format_cents(price), DESC[tier]], 15)
		l.custom_minimum_size = Vector2(400, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(l)
		if owned:
			if svc.equipment.equipped_tier() != tier:
				row.add_child(UITheme.button("Equip", func() -> void:
					svc.equipment.equip_tier(tier)
					hud.show_message("Equipped the %s axe." % tier)
					close_panel(), 120))
		else:
			row.add_child(UITheme.button("Buy", func() -> void: _confirm_buy(tier), 120))
		v.add_child(row)
	var te := 0.0
	if Game.timber:
		te = int(Game.timber.totals().accepted_mte) / 1000.0
	_text(v, "Hire a worker ($%s) - coming in Phase 4 (crew).\nPickup truck - coming in Phase 5: unlocks after %.0f delivered tree-equivalents (you have %.2f); at most %d trucks." % [Money.format_cents(svc.config.hire_fee_cents), svc.config.truck_unlock_tree_equivalents, te, svc.config.max_trucks], 14, UITheme.MUTED)
	v.add_child(UITheme.button("Close", close_panel, 200))
	_open(p)


func _confirm_buy(tier: String) -> void:
	var price := svc.equipment.price(tier)
	var f := _frame("Buy the %s axe?" % tier, 520)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	var after := svc.wallet.cash - price
	var need := svc.payroll.todays_estimate() + svc.payroll.owed_total()
	if price > svc.wallet.cash:
		_text(v, "You need $%s; you have $%s." % [Money.format_cents(price), Money.format_cents(svc.wallet.cash)])
		v.add_child(UITheme.button("Back", open_shop, 200))
		_open(p)
		return
	_text(v, "Price $%s. Cash after: $%s." % [Money.format_cents(price), Money.format_cents(after)])
	if after < need:
		_text(v, "Warning: that leaves less than tonight's payroll and wages owed ($%s). Unpaid wages must be cleared by the end of the next workday." % Money.format_cents(need), 15, Color(1.0, 0.75, 0.45))
	var row := HBoxContainer.new()
	row.add_child(UITheme.button("Confirm purchase", func() -> void:
		var res := svc.equipment.buy(tier)
		if bool(res.ok):
			svc.equipment.equip_tier(tier)
			hud.show_message("Bought and equipped the %s axe (%s)." % [tier, res.tx])
		else:
			hud.show_message(str(res.reason))
		close_panel(), 220))
	row.add_child(UITheme.button("Cancel", open_shop, 140))
	v.add_child(row)
	_open(p)


# ------------------------------------------------------------------- report

func show_report(r: Dictionary) -> void:
	var f := _frame("End of day %d" % int(r.day), 640)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	_text(v, "Cash: opened $%s, closed $%s%s" % [Money.format_cents(int(r.opening_cash)), Money.format_cents(int(r.closing_cash)), "" if bool(r.reconciles) else "  (MISMATCH - please report)"])
	_text(v, "  + deliveries credited during the day  $%s\n  - purchases  $%s%s\n  - wages paid tonight  $%s" % [Money.format_cents(int(r.income)), Money.format_cents(int(r.purchases)), ("  (" + ", ".join(PackedStringArray(r.purchase_lines)) + ")") if not (r.purchase_lines as Array).is_empty() else "", Money.format_cents(int(r.wages_paid))], 15)
	_text(v, "Trees felled today: %d  ·  stumps removed: %d  ·  original trees remaining: %d\nDelivered today: %.2f tree-equivalents" % [int(r.felled), int(r.stumps_removed), int(r.trees_remaining), int(r.delivered_mte) / 1000.0])
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
	var f := _frame("Contract fulfilled" if state == ContractService.FULFILLED else "The contract has ended", 640)
	var p: PanelContainer = f[0]
	var v: VBoxContainer = f[1]
	if state == ContractService.FULFILLED:
		_text(v, "Every original tree is down, every stump is out and every log was delivered before the deadline. (%s)\nThe fire may keep burning the backlog - that is not part of the contract." % outcome_id)
	else:
		_text(v, "Night fell on day 30 with the island not cleared. (%s)\nIn the finished game the boats leave you behind: days 31-35 become a survival hunt and rescue comes at dawn on day 36, while the dog waits safely at the dock refuge.\n\nDevelopment build: that survival mode arrives in Phase 6. Your save is kept at this outcome; nothing has been lost or changed." % outcome_id)
	v.add_child(UITheme.button("Back to the title screen", func() -> void:
		close_panel()
		Game.return_to_menu(), 300))
	v.add_child(UITheme.button("Keep looking around (no more workdays)", close_panel, 300))
	_open(p)
