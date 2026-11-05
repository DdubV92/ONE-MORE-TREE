class_name DayTestPanel
extends VBoxContainer
## Preview Tour "Day & Economy Test" controls (Phase 3). Everything here runs
## in an isolated in-memory session: Preview mode never writes a save, the
## real campaign file is untouched, and the island seed/tree count cannot
## change. Time acceleration exists only here; the campaign always runs the
## exact 20 + 5 minute day.

var hud: Node


func setup(h: Node) -> void:
	hud = h
	add_child(UITheme.label("Day & Economy Test", 16, UITheme.MUTED))
	var g := GridContainer.new()
	g.columns = 2
	add_child(g)
	var c: CampaignService = Game.campaign
	var b := func(text: String, cb: Callable) -> void:
		g.add_child(UITheme.button(text, cb, 130))
	b.call("Start session", func() -> void:
		c.start_test_route(true)
		_msg("Test session: day 1, $%s, two payroll fixtures working. Deliveries at the rack pay; sleep in the camper bed at dusk." % Money.format_cents(c.wallet.cash)))
	b.call("Speed x1/x20", func() -> void:
		if _need(c):
			c.clock.speed = 20.0 if c.clock.speed < 2.0 else 1.0
			_msg("Clock speed x%d (test session only)" % int(c.clock.speed)))
	b.call("Jump to dusk", func() -> void:
		if _need(c):
			c.clock.t = WorkdayClock.DAYLIGHT_SECONDS - 3.0
			_msg("3 seconds before dusk"))
	b.call("Jump to night", func() -> void:
		if _need(c):
			c.clock.t = WorkdayClock.NIGHT_AT - 3.0
			_msg("3 seconds before night"))
	b.call("Sleep now", func() -> void:
		if _need(c):
			if c.clock.phase() == WorkdayClock.Phase.DAYLIGHT:
				c.clock.t = WorkdayClock.DAYLIGHT_SECONDS
			var r := c.sleep()
			if not bool(r.get("ok", false)):
				_msg(str(r.get("reason", "")))
			else:
				hud.tour_panel.visible = false)
	b.call("Day 30 dusk", func() -> void:
		if _need(c):
			c.clock.restore({"day": 30, "t": WorkdayClock.NIGHT_AT - 60.0, "running": true})
			_msg("Day 30, one minute before the contract closes"))
	b.call("Prepared win", func() -> void:
		if _need(c):
			# Development fixture: the contract scope is shrunk to the trees
			# already cleared, so the deadline evaluates as fulfilled.
			c.contract.scope_override = maxi(c.contract.counts().felled, 0)
			c.clock.restore({"day": 30, "t": WorkdayClock.NIGHT_AT - 5.0, "running": true})
			_msg("Prepared success: contract scope limited to the trees already cleared (fixture). Wait 5 s."))
	b.call("Prepared loss", func() -> void:
		if _need(c):
			c.contract.scope_override = -1
			c.clock.restore({"day": 30, "t": WorkdayClock.NIGHT_AT - 5.0, "running": true})
			_msg("Prepared failure: day 30, 5 s before the deadline with the island standing."))
	b.call("Unpaid wages", func() -> void:
		if _need(c):
			c.wallet.spend(c.wallet.cash, "test", "FIXTURE", "Fixture: empty the till")
			_msg("Cash emptied (fixture). Sleep twice to see arrears, then a quit request."))
	b.call("Give $5,000", func() -> void:
		if _need(c):
			c.wallet.grant(500000, "test", "FIXTURE", "Fixture cash")
			_msg("+$5,000 fixture cash"))
	b.call("Open shop", func() -> void:
		if _need(c):
			hud.tour_panel.visible = false
			Game.campaign_ui.open_shop())
	b.call("Journal", func() -> void:
		if _need(c):
			hud.tour_panel.visible = false
			Game.campaign_ui.toggle_journal())


func _need(c: CampaignService) -> bool:
	if c == null or not c.test_route:
		_msg("Press 'Start session' first.")
		return false
	return true


func _msg(t: String) -> void:
	hud.show_message(t, 5.0)
