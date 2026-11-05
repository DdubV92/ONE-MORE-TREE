class_name PayrollApp
extends Control
## Phase 21: the camper computer's Payroll app (owner request). Three pages:
##   Crew        - one row per employee: pay mood (bar + word), useful work
##                 today, work done today (tree-equivalents) and its value,
##                 daily rate, today's bonus, performance bonus, tonight's
##                 pay. Click a row for the detail panel: fair pay in their
##                 eyes, nights at the minimum, rate/bonus/performance
##                 controls, a pending raise request, recent nights.
##   Last night  - the pay report of the last settled night (per worker and
##                 totals, mood before -> after, who quit).
##   Campaign    - the whole-contract pay report (end-of-game page): per
##                 worker days, base, bonuses, total paid, value of their
##                 work; totals and pay vs value.
## Every number comes from PayMorale / Payroll / the merit and time ledgers;
## the buttons call the same service methods the tests use.

const COLS := [["Employee", 128], ["Pay mood", 132], ["Useful", 46], ["Work", 42], ["Value", 50], ["Rate", 48], ["Bonus", 46], ["Perf", 36], ["Tonight", 56]]
const GOOD := Color(0.45, 0.78, 0.42)
const OKAY := Color(0.86, 0.78, 0.36)
const BAD := Color(0.92, 0.55, 0.25)
const RED := Color(0.95, 0.32, 0.27)

var page := "Crew"
var selected := ""
var status_cb: Callable
var _body: VBoxContainer
var _t := 0.0


static func create(status: Callable) -> PayrollApp:
	var a := PayrollApp.new()
	a.status_cb = status
	a.set_anchors_preset(Control.PRESET_FULL_RECT)
	return a


func _ready() -> void:
	var cs: CampaignService = Game.campaign
	if cs and cs.pay and not cs.pay.pay_changed.is_connected(rebuild):
		cs.pay.pay_changed.connect(rebuild)
	rebuild()


func _exit_tree() -> void:
	var cs: CampaignService = Game.campaign
	if cs and cs.pay and cs.pay.pay_changed.is_connected(rebuild):
		cs.pay.pay_changed.disconnect(rebuild)


## Live numbers (work done today) refresh every few seconds on the Crew page.
func _process(dt: float) -> void:
	_t += dt
	if _t >= 3.0 and page == "Crew" and is_visible_in_tree():
		_t = 0.0
		rebuild()


static func mood_color(s: float) -> Color:
	return GOOD if s >= 0.7 else (OKAY if s >= 0.45 else (BAD if s >= PayMorale.VERGE else RED))


static func money(c: int) -> String:
	return "$" + Money.format_cents(c).trim_suffix(".00")


## Whole dollars for the header line.
static func dollars(c: int) -> String:
	return "$" + Money.format_cents(int(round(c / 100.0)) * 100).trim_suffix(".00")


func _small(text: String, cb: Callable, w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 26)
	b.add_theme_font_size_override("font_size", 13)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := (UITheme.get_theme().get_stylebox(st, "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.content_margin_left = 7
		sb.content_margin_right = 7
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b


func _cell(text: String, w: int, color := UITheme.TEXT, size := 13) -> Label:
	var l := UITheme.label(text, size, color)
	l.custom_minimum_size = Vector2(w, 0)
	l.clip_text = true
	return l


func _bar(s: float, w := 64) -> Control:
	var back := ColorRect.new()
	back.color = Color(0.18, 0.19, 0.17)
	back.custom_minimum_size = Vector2(w, 9)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = mood_color(s)
	fill.size = Vector2(w * clampf(s, 0.0, 1.0), 9)
	back.add_child(fill)
	var mark := ColorRect.new()     # the verge line
	mark.color = Color(1, 1, 1, 0.5)
	mark.size = Vector2(1, 9)
	mark.position = Vector2(w * PayMorale.VERGE, 0)
	back.add_child(mark)
	return back


func _say(t: String) -> void:
	if status_cb.is_valid():
		status_cb.call(t)


func _act(res: Dictionary) -> void:
	if not bool(res.get("ok", false)):
		_say(str(res.get("reason", "Not possible.")))


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var cs: CampaignService = Game.campaign
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	if cs == null or not cs.active or cs.pay == null:
		root.add_child(UITheme.label("Payroll: no campaign running.", 16, UITheme.MUTED))
		return
	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(UITheme.label("Payroll", 20, UITheme.ACCENT))
	for p in ["Crew", "Last night", "Campaign"]:
		var b := _small(p if p != "Campaign" else "Campaign report", func() -> void:
			page = p
			rebuild(), 0)
		b.modulate = Color(1.2, 1.1, 0.7) if p == page else Color.WHITE
		head.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.label("Cash %s · tonight %s · owed %s" % [dollars(cs.wallet.cash), dollars(cs.payroll.todays_estimate()), dollars(cs.payroll.owed_total())], 14, UITheme.MUTED))
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	match page:
		"Crew":
			_crew(cs)
		"Last night":
			_night(cs)
		"Campaign":
			_campaign(cs)


# ---------------------------------------------------------------- crew page

func _crew(cs: CampaignService) -> void:
	var pay := cs.pay
	var d := cs.clock.day
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	h.add_child(left)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 4)
	for c in COLS:
		hdr.add_child(_cell(str(c[0]), int(c[1]), UITheme.MUTED, 12))
	left.add_child(hdr)
	var shown := []
	for e in cs.payroll.employees:
		if str(e.status) in [Payroll.ACTIVE, "departing", "pending_arrival", Payroll.QUIT_REQUESTED]:
			shown.append(e)
	if shown.is_empty():
		left.add_child(UITheme.label("No employees.", 14, UITheme.MUTED))
	if selected == "" or shown.filter(func(x: Dictionary) -> bool: return str(x.id) == selected).is_empty():
		selected = str(shown[0].id) if not shown.is_empty() else ""
	for e in shown:
		var eid := str(e.id)
		var s := pay.sat(eid)
		var pl := pay.planned_for(eid, d)
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.17, 0.1, 0.9) if eid == selected else Color(0.11, 0.13, 0.12, 0.9)
		sb.border_color = UITheme.ACCENT if eid == selected else (RED if s < PayMorale.VERGE else Color(0.22, 0.24, 0.2))
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 4
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				selected = eid
				rebuild())
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
		var nm := str(e.name) + ("" if str(e.status) == Payroll.ACTIVE else " (%s)" % str(e.status).replace("_", " "))
		r.add_child(_cell(("! " if not pay.pending_request(eid).is_empty() else "") + nm, 128))
		var mood := HBoxContainer.new()
		mood.custom_minimum_size = Vector2(132, 0)
		mood.add_theme_constant_override("separation", 4)
		mood.add_child(_bar(s, 44))
		mood.add_child(_cell(PayMorale.status_of(s).replace("On the verge of quitting", "About to quit"), 84, mood_color(s), 12))
		r.add_child(mood)
		r.add_child(_cell("%d%%" % int(round(100.0 * pay.useful_share(eid, d))), 46))
		r.add_child(_cell("%.2f" % pay.tree_eq(eid, d), 42))
		r.add_child(_cell(money(pay.value_cents(eid, d)), 50))
		r.add_child(_cell(money(int(pl.base)), 48, UITheme.TEXT if int(pl.base) > PayMorale.MIN_WAGE else UITheme.MUTED))
		r.add_child(_cell(money(int(pl.bonus)) if int(pl.bonus) > 0 else "-", 46))
		r.add_child(_cell("%d%%" % int(pay.rec(eid).get("perf_pct", 0)) if int(pay.rec(eid).get("perf_pct", 0)) > 0 else "-", 36))
		r.add_child(_cell(money(int(pl.total)), 56, UITheme.ACCENT))
		for c in r.get_children():
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(row)
	var key := UITheme.label("Useful = share of today spent on real work. Work = tree-equivalents done today (1.00 = one tree felled, cut up, cleared and delivered); Value = that work at $100 a tree. Mood bar: the white tick is the quitting line. ! = raise request waiting.", 11, UITheme.MUTED)
	key.autowrap_mode = TextServer.AUTOWRAP_WORD
	key.custom_minimum_size = Vector2(600, 0)
	left.add_child(key)
	if selected != "":
		h.add_child(_detail(cs, selected))


func _detail(cs: CampaignService, eid: String) -> Control:
	var pay := cs.pay
	var d := cs.clock.day
	var e := cs.payroll.employee(eid)
	var r := pay.rec(eid)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	var s := float(r.get("sat", 0.6))
	v.add_child(UITheme.label(str(e.get("name", eid)), 17, UITheme.ACCENT))
	var tr: Array = e.get("traits", [])
	v.add_child(_wrap("%s  ·  %s" % [", ".join(PackedStringArray(tr.map(func(x) -> String: return str(x).replace("_", " ")))), _temper(r)], 12, UITheme.MUTED))
	var m := HBoxContainer.new()
	m.add_child(_bar(s, 120))
	m.add_child(UITheme.label("%s (%d%%)" % [PayMorale.status_of(s), int(round(s * 100.0))], 13, mood_color(s)))
	v.add_child(m)
	var band := pay.expected_band(eid)
	v.add_child(_wrap("Fair pay in their eyes: about %s-%s a day (personality, level %d, gear %d pts)." % [money(int(band[0])), money(int(band[1])), maxi(pay._career(eid), 1), pay.gear_points(eid)], 12))
	if int(r.get("min_days", 0)) > 0:
		v.add_child(_wrap("On the bare minimum %d night%s in a row." % [int(r.min_days), "" if int(r.min_days) == 1 else "s"], 12, BAD))
	if s < PayMorale.VERGE:
		var left := PayMorale.VERGE_NIGHTS - (d - int(r.verge_day)) if int(r.verge_day) >= 0 else PayMorale.VERGE_NIGHTS
		v.add_child(_wrap("On the verge of quitting: unless their pay feels fair, they leave within %d night%s." % [maxi(left, 1), "" if left == 1 else "s"], 12, RED))
	var pl := pay.planned_for(eid, d)
	v.add_child(_row([UITheme.label("Rate %s/day" % money(int(r.rate)), 13), _small("- $25", func() -> void: _act(pay.change_rate(eid, -1))), _small("+ $25", func() -> void: _act(pay.change_rate(eid, 1)))]))
	v.add_child(_row([UITheme.label("Bonus today %s" % money(int(r.bonus)), 13), _small("- $25", func() -> void: _act(pay.change_bonus(eid, -1))), _small("+ $25", func() -> void: _act(pay.change_bonus(eid, 1)))]))
	v.add_child(_row([UITheme.label("Performance %d%%" % int(r.perf_pct), 13), _small("Change", func() -> void: _act(pay.cycle_perf(eid))), UITheme.label("of their work's value", 11, UITheme.MUTED)]))
	v.add_child(_wrap("Tonight: %s rate + %s bonus + %s performance = %s" % [money(int(pl.base)), money(int(pl.bonus)), money(int(pl.perf)), money(int(pl.total))], 12, UITheme.ACCENT))
	var q := pay.pending_request(eid)
	if not q.is_empty():
		v.add_child(_wrap("Raise request (after %s): +%s a day, or a %s bonus today." % [str(q.reason), money(int(q.raise)), money(int(q.bonus))], 13, OKAY))
		v.add_child(_row([_small("Give raise", func() -> void: _act(pay.answer(str(q.id), "raise"))), _small("Bonus today", func() -> void: _act(pay.answer(str(q.id), "bonus"))), _small("Decline", func() -> void: _act(pay.answer(str(q.id), "decline")))]))
	var hist: Array = r.get("history", [])
	if not hist.is_empty():
		v.add_child(UITheme.label("Recent nights", 13, UITheme.MUTED))
		for i in range(hist.size() - 1, maxi(hist.size() - 5, 0) - 1, -1):
			var x: Dictionary = hist[i]
			v.add_child(_wrap("Day %d: paid %s (fair ~%s), work %.2f worth %s, mood %d%% -> %d%%" % [int(x.day), money(int(x.total)), money(int(x.expected)), float(x.tree_eq), money(int(x.value)), int(round(float(x.sat_before) * 100)), int(round(float(x.sat) * 100))], 11, UITheme.MUTED))
	return panel


func _temper(r: Dictionary) -> String:
	var p := float(r.get("patience", 0.5))
	var a := float(r.get("assertive", 0.5))
	var w := "very patient" if p >= 0.7 else ("patient" if p >= 0.5 else ("impatient" if p >= 0.3 else "very impatient"))
	return w + (", speaks up" if a >= 0.6 else (", quiet" if a < 0.3 else "")) + (", proud of output" if float(r.get("values_perf", 0.5)) >= 0.7 else "")


func _row(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for it in items:
		h.add_child(it)
	return h


func _wrap(t: String, size := 13, color := UITheme.TEXT) -> Label:
	var l := UITheme.label(t, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	return l


# ------------------------------------------------------------- report pages

func _table(rows: Array, widths: Array, header: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var hh := HBoxContainer.new()
	for i in header.size():
		hh.add_child(_cell(str(header[i]), int(widths[i]), UITheme.MUTED, 12))
	v.add_child(hh)
	for row in rows:
		var h := HBoxContainer.new()
		for i in (row[0] as Array).size():
			h.add_child(_cell(str(row[0][i]), int(widths[i]), row[1] if i == (row[0] as Array).size() - 1 else UITheme.TEXT, 13))
		v.add_child(h)
	return v


func _night(cs: CampaignService) -> void:
	var keys := cs.pay.nights.keys()
	if keys.is_empty():
		_body.add_child(UITheme.label("No night settled yet. Tonight's pay report appears here after you sleep.", 15, UITheme.MUTED))
		return
	keys.sort_custom(func(a, b) -> bool: return int(a) < int(b))
	var n: Dictionary = cs.pay.nights[keys[keys.size() - 1]]
	_body.add_child(UITheme.label("Pay report: night of day %d" % int(n.day), 16, UITheme.ACCENT))
	var rows := []
	for l in n.lines:
		var col: Color = RED if bool(l.quit) else mood_color(float(l.sat))
		rows.append([[str(l.name), money(int(l.base)), money(int(l.bonus) + int(l.perf)), money(int(l.total)), money(int(l.paid)), money(int(l.expected)), "%.2f" % float(l.tree_eq), money(int(l.value)), "%d -> %d%%" % [int(round(float(l.sat_before) * 100)), int(round(float(l.sat) * 100))], ("QUIT: leaves on the boat" if bool(l.quit) else str(l.status))], col])
	var t: Dictionary = n.totals
	rows.append([["Total", money(int(t.base)), money(int(t.bonus) + int(t.perf)), money(int(t.total)), "", "", "", money(int(t.value)), "", ""], UITheme.ACCENT])
	_body.add_child(_table(rows, [150, 70, 70, 70, 70, 70, 54, 70, 84, 190], ["Employee", "Rate", "Bonuses", "Earned", "Paid", "Fair", "Work", "Value", "Mood", "Status"]))
	_body.add_child(_wrap("Earned is charged at settlement; any part not paid stays owed (Journal). Fair = what that worker thinks a fair day's pay is.", 12, UITheme.MUTED))


func _campaign(cs: CampaignService) -> void:
	var rep := cs.pay.campaign_report()
	var closed := cs.contract and cs.contract.is_closed()
	_body.add_child(UITheme.label("Campaign pay report%s" % (" (final: the contract has closed)" if closed else " (so far, day %d)" % cs.clock.day), 16, UITheme.ACCENT))
	var rows := []
	for w in rep.workers:
		var st := str(w.status)
		var note := ("left: " + str(w.reason)) if st in ["departed", "departing"] else ("%s, %s/day" % [PayMorale.status_of(float(w.sat)), money(int(w.rate))])
		rows.append([[str(w.name), str(int(w.days)), money(int(w.base)), money(int(w.bonus) + int(w.perf)), money(int(w.total)), money(int(int(w.total) / maxi(int(w.days), 1))), "%.2f" % float(w.tree_eq), money(int(w.value)), note], mood_color(float(w.sat)) if not st in ["departed", "departing"] else BAD])
	var t: Dictionary = rep.totals
	rows.append([["All crew", str(int(t.days)), money(int(t.base)), money(int(t.bonus) + int(t.perf)), money(int(t.total)), money(int(int(t.total) / maxi(int(t.days), 1))), "", money(int(t.value)), ""], UITheme.ACCENT])
	_body.add_child(_table(rows, [150, 44, 84, 80, 84, 70, 54, 80, 270], ["Employee", "Days", "Rates", "Bonuses", "Total paid", "Per day", "Work", "Value", "Now"]))
	var ratio := float(t.value) / maxf(float(t.total), 1.0)
	_body.add_child(_wrap("You paid %s in wages for work worth %s at the contract price (%.0f%%)." % [money(int(t.total)), money(int(t.value)), ratio * 100.0], 13))
