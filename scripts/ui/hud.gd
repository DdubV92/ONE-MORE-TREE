extends CanvasLayer
## In-world UI: crosshair, interaction prompt, messages, wading hint, and the
## review/debug overlays (controls F1, debug F3, time & lighting F4, tree
## inspector F6, preview tour Tab, pause Esc).

var root: Control
var crosshair: Control
var prompt_label: Label
var message_label: Label
var hint_label: Label
var debug_label: Label
var help_panel: PanelContainer
var time_panel: PanelContainer
var tree_panel: PanelContainer
var tree_label: Label
var pause_panel: PanelContainer
var settings_panel: SettingsPanel
var tour_panel: PanelContainer
var bench_label: Label
var _msg_t := 0.0
var _time_slider: HSlider
var _time_label: Label
var _overcast_slider: HSlider
var _bench: Benchmark
var axe_label: Label
var chop_label: Label
var _aid: MeshInstance3D
var _aid_info := {}


var carry_label: Label
var campaign_ui: CampaignUI
var timber_panel: PanelContainer
var timber_label: Label
var _timber_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var post := PostFX.new()
	post.name = "PostFX"
	get_parent().add_child.call_deferred(post)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	_build_crosshair()
	prompt_label = _anchored_label(Vector2(0.5, 0.56), 20)
	message_label = _anchored_label(Vector2(0.5, 0.78), 20)
	hint_label = _anchored_label(Vector2(0.5, 0.86), 18)
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	debug_label = UITheme.label("", 15)
	# Bottom-left, clear of the Tour panel (top-left) and controls (top-right).
	debug_label.anchor_top = 1.0
	debug_label.anchor_bottom = 1.0
	debug_label.offset_left = 14
	debug_label.offset_top = -215
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.add_theme_constant_override("outline_size", 4)
	debug_label.visible = false
	root.add_child(debug_label)
	bench_label = _anchored_label(Vector2(0.5, 0.08), 22)
	_build_help()
	_build_time_panel()
	_build_tree_panel()
	_build_pause()
	_build_tour()
	chop_label = _anchored_label(Vector2(0.5, 0.6), 18)
	axe_label = UITheme.label("", 15, UITheme.MUTED)
	axe_label.anchor_left = 1.0
	axe_label.anchor_right = 1.0
	axe_label.anchor_top = 1.0
	axe_label.anchor_bottom = 1.0
	axe_label.offset_left = -330
	axe_label.offset_top = -40
	root.add_child(axe_label)
	var p: Node = Game.player
	if p:
		p.interact_target_changed.connect(func(t: String) -> void: prompt_label.text = (Keys.tag("interact") + " " + t) if t != "" else "")
		p.message.connect(show_message)
		if p.get("axe"):
			p.axe.target_changed.connect(_on_chop_target)
			p.axe.hit_result.connect(_on_hit_result)
	if Game.trees:
		Game.trees.tree_warning.connect(func(_id: int) -> void: show_message("The trunk is groaning - it's about to go. Stand clear of its fall line.", 3.5))
		Game.trees.tree_felled.connect(func(_id: int) -> void: show_message("Timber!", 2.0))
	carry_label = _anchored_label(Vector2(0.5, 0.92), 17)
	carry_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_build_timber_panel()
	if Game.campaign:
		campaign_ui = CampaignUI.new()
		campaign_ui.name = "CampaignUI"
		root.add_child(campaign_ui)
		campaign_ui.setup(self, Game.campaign)
		Game.campaign_ui = campaign_ui
		Game.campaign.notice.connect(func(t: String, secs: float) -> void: show_message(t, secs))
		_build_guide()
		if Game.crew:
			Game.crew.notice.connect(func(t: String, secs: float) -> void: show_message(t, secs))
		Game.campaign.request_pause.connect(func() -> void:
			if not get_tree().paused:
				_toggle_pause())
	if Game.timber:
		Game.timber.recovered.connect(func(sid: String, reason: String) -> void: show_message("Recovered log %s (%s) to safe ground." % [sid, reason.replace("_", " ")], 3.0))
	_build_aid()
	if Game.is_preview():
		tour_panel.visible = true
		show_message("Preview Tour: Tab toggles the tour panel, F1 shows controls")
	else:
		show_message("Welcome to the island. F1 for controls.")


## Phase 9 first-day guide line (top centre-right, behind a soft panel).
var guide_panel: PanelContainer
var guide_label: Label


func _build_guide() -> void:
	guide_panel = PanelContainer.new()
	guide_panel.anchor_left = 1.0
	guide_panel.anchor_right = 1.0
	guide_panel.offset_left = -470
	guide_panel.offset_right = -16
	guide_panel.offset_top = 64
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.06, 0.72)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	guide_panel.add_theme_stylebox_override("panel", sb)
	guide_label = UITheme.label("", 16, Color(0.92, 0.96, 0.88))
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	guide_label.custom_minimum_size = Vector2(440, 0)
	guide_panel.add_child(guide_label)
	guide_panel.visible = false
	root.add_child(guide_panel)
	var ob: Onboarding = Game.campaign.onboarding
	if ob:
		ob.hint_changed.connect(func(t: String) -> void:
			guide_label.text = t + ("\n(Journal → Help & log: skip or replay)" if t != "" else "")
			guide_panel.visible = t != "")


func _anchored_label(anchor: Vector2, size: int) -> Label:
	var l := UITheme.label("", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = anchor.x
	l.anchor_right = anchor.x
	l.anchor_top = anchor.y
	l.anchor_bottom = anchor.y
	l.offset_left = -400
	l.offset_right = 400
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	root.add_child(l)
	return l


func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(func() -> void:
		crosshair.draw_circle(Vector2.ZERO, 3.0, Color(0, 0, 0, 0.5))
		crosshair.draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, 0.85)))
	root.add_child(crosshair)


func _panel(anchor: Vector2, offset: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = anchor.x
	p.anchor_right = anchor.x
	p.anchor_top = anchor.y
	p.anchor_bottom = anchor.y
	p.position = offset
	p.visible = false
	root.add_child(p)
	return p


func _build_help() -> void:
	help_panel = _panel(Vector2(1, 0), Vector2(-430, 12))
	var v := VBoxContainer.new()
	help_panel.add_child(v)
	v.add_child(UITheme.label("Controls", 22, UITheme.ACCENT))
	var lines := [
		"WASD  move     Mouse  look     Space  jump",
		"Shift  sprint     Ctrl  crouch     E  interact",
		"Esc  pause / settings / release mouse",
		"F1  this help     F3  debug stats",
		"F4  time of day & lighting presets",
		"F6  inspect tree under crosshair",
		"F7  ripple test at your feet / in front",
		"F8  reset to a safe camp position",
		"LMB  swing axe (hold to keep chopping)",
		"1 / 2 / 3  small / medium / large axe (debug)",
		"F9 / F10  quick save / load (campaign)",
		"F12  write diagnostic report",
		"Tab  Preview Tour panel (preview mode)",
		"V  fly mode (preview mode only)",
	]
	for l in lines:
		v.add_child(UITheme.label(l, 16))


func _build_time_panel() -> void:
	time_panel = _panel(Vector2(0, 1), Vector2(12, -230))
	var v := VBoxContainer.new()
	time_panel.add_child(v)
	_time_label = UITheme.label("Time", 18, UITheme.ACCENT)
	v.add_child(_time_label)
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = 24.0
	_time_slider.step = 0.05
	_time_slider.custom_minimum_size = Vector2(420, 24)
	_time_slider.value_changed.connect(func(h: float) -> void:
		if Game.environment:
			Game.environment.set_time_of_day(h)
		_update_time_label())
	v.add_child(_time_slider)
	var row := HBoxContainer.new()
	for p in ["dawn", "day", "sunset", "night", "overcast"]:
		row.add_child(UITheme.button(p.capitalize(), func() -> void: _apply_preset(p), 78))
	v.add_child(row)
	var oc := HBoxContainer.new()
	oc.add_child(UITheme.label("Overcast", 16))
	_overcast_slider = HSlider.new()
	_overcast_slider.max_value = 1.0
	_overcast_slider.step = 0.01
	_overcast_slider.custom_minimum_size = Vector2(300, 24)
	_overcast_slider.value_changed.connect(func(x: float) -> void:
		if Game.environment:
			Game.environment.set_overcast(x))
	oc.add_child(_overcast_slider)
	v.add_child(oc)
	var mo := HBoxContainer.new()
	mo.add_child(UITheme.label("Moon", 16))
	var moon_slider := HSlider.new()
	moon_slider.max_value = 1.0
	moon_slider.step = 0.01
	moon_slider.value = Game.environment.moon_phase if Game.environment else 0.3
	moon_slider.custom_minimum_size = Vector2(200, 24)
	moon_slider.value_changed.connect(func(x: float) -> void:
		if Game.environment:
			Game.environment.set_moon_phase(x)
			_update_time_label())
	mo.add_child(moon_slider)
	mo.add_child(UITheme.button("New", func() -> void: moon_slider.value = 0.0, 60))
	mo.add_child(UITheme.button("Full", func() -> void: moon_slider.value = 0.5, 60))
	v.add_child(mo)
	# Phase 8 weather (preview override; campaigns follow the seeded schedule).
	var wr := HBoxContainer.new()
	wr.add_child(UITheme.label("Weather", 16))
	for st in ["clear", "light_cloud", "overcast", "light_rain", "storm"]:
		wr.add_child(UITheme.button(st.replace("_", " ").capitalize(), func() -> void:
			if Game.weather:
				Game.weather.call("set_override", st)
			_update_time_label(), 82))
	wr.add_child(UITheme.button("Schedule", func() -> void:
		if Game.weather:
			Game.weather.call("set_override", "")
		_update_time_label(), 82))
	v.add_child(wr)


func _apply_preset(p: String) -> void:
	if Game.environment:
		Game.environment.apply_named(p)
		_time_slider.set_value_no_signal(Game.environment.hour)
		_overcast_slider.set_value_no_signal(Game.environment.overcast)
		_update_time_label()


func _update_time_label() -> void:
	if Game.environment:
		_time_label.text = "Time %s" % Game.environment.describe()
		if Game.weather:
			_time_label.text += "\nWeather %s" % Game.weather.call("describe")


func _build_timber_panel() -> void:
	timber_panel = _panel(Vector2(1, 0), Vector2(-470, 60))
	timber_label = UITheme.label("", 15)
	timber_panel.add_child(timber_label)
	timber_panel.visible = false


## F2: the timber ledger (exact units; entitlement in cents).
func _timber_text() -> String:
	var t: TimberService = Game.timber
	if t == null:
		return "No timber service"
	var tot := t.totals()
	var lines: PackedStringArray = ["Timber ledger (F2)",
		"Trees with timber: %d   bodies in world: %d" % [tot.trees, tot.bodies],
		"Carried: %d (%d mTE)   queued: %d (%d mTE)   burning: %d" % [t.carried.size(), t.carried_mte(), tot.queued, tot.queue_mte, tot.burning],
		"Accepted: %d mTE = %.3f trees   receipts: %d" % [tot.accepted_mte, tot.accepted_mte / 1000.0, tot.receipts],
		"Delivery entitlement: $%s" % Money.format_cents(int(tot.entitlement_cents)),
		"Ash clean: %s" % ("yes" if t.ash_clean() else "no (burning continues; not needed for the contract)"), ""]
	var ids := t.records.keys()
	ids.sort()
	for id in ids.slice(-6):
		var r := t.reconcile(int(id))
		var parts: PackedStringArray = []
		for st in r.by_state:
			parts.append("%s %d" % [str(st).to_lower(), int(r.by_state[st])])
		lines.append("Tree %d: %s  | receipts $%s  %s" % [id, ", ".join(parts), Money.format_cents(int(r.receipt_cents)), "OK" if r.ok else "MISMATCH"])
	if not t.recovery_log.is_empty():
		var last: Dictionary = t.recovery_log[t.recovery_log.size() - 1]
		lines.append("Last recovery: %s %s -> %s" % [last.sid, last.reason, last.to])
	return "\n".join(lines)


func _build_tree_panel() -> void:
	tree_panel = _panel(Vector2(1, 1), Vector2(-430, -320))
	tree_label = UITheme.label("", 16)
	tree_panel.add_child(tree_label)


func _build_pause() -> void:
	pause_panel = _panel(Vector2(0.5, 0.5), Vector2(-170, -250))
	var v := VBoxContainer.new()
	pause_panel.add_child(v)
	v.add_child(UITheme.label("Paused", 28, UITheme.ACCENT))
	v.add_child(UITheme.button("Resume", _toggle_pause))
	v.add_child(UITheme.button("Settings", func() -> void:
		pause_panel.visible = false
		settings_panel.visible = true))
	v.add_child(UITheme.button("Write diagnostic report", _write_diag))
	v.add_child(UITheme.button("Open diagnostics folder", func() -> void: Diag.open_report_folder()))
	if Game.mode == Game.Mode.CAMPAIGN:
		v.add_child(UITheme.button("Save", func() -> void:
			Game.world_root.save_campaign()
			show_message("Saved.")))
	v.add_child(UITheme.button("Return to title", func() -> void: Game.return_to_menu()))
	v.add_child(UITheme.button("Quit to desktop", func() -> void:
		if Game.world_root and Game.mode == Game.Mode.CAMPAIGN:
			Game.world_root.save_campaign()
		get_tree().quit()))
	settings_panel = SettingsPanel.new()
	settings_panel.anchor_left = 0.5
	settings_panel.anchor_top = 0.5
	settings_panel.position = Vector2(-310, -300)
	settings_panel.visible = false
	settings_panel.closed.connect(func() -> void:
		settings_panel.visible = false
		pause_panel.visible = true)
	root.add_child(settings_panel)


func _build_tour() -> void:
	tour_panel = _panel(Vector2(0, 0), Vector2(12, 60))
	# Phase 12: the tour outgrew a 720p screen; it scrolls now.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(290, minf(get_viewport().get_visible_rect().size.y - 90.0, 900.0) if get_viewport() else 600.0)
	tour_panel.add_child(scroll)
	var v := VBoxContainer.new()
	scroll.add_child(v)
	v.add_child(UITheme.label("Preview Tour", 22, UITheme.ACCENT))
	v.add_child(UITheme.label("Locations", 16, UITheme.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	var spots := [["Logging Loop", "__loop"], ["Reset logging", "__reset"], ["Snapshot", "__snap"], ["Restore snap", "__restore"], ["Logging Test", "logging_test"], ["Next test tree", "__next_tree"], ["Camp", "camp"], ["Camper", "camper"], ["Cabin", "cabin"], ["Beach", "beach"], ["Shallows", "shallows"], ["Forest", "forest"], ["River", "river"], ["Rapids", "rapids"], ["Pond", "pond"], ["Pond 2", "pond2"], ["Ridge", "ridge"], ["Coast", "coast_day"]]
	for s in spots:
		grid.add_child(UITheme.button(s[0], func() -> void: _goto(s[1]), 130))
	v.add_child(grid)
	v.add_child(UITheme.label("Lighting", 16, UITheme.MUTED))
	var lrow := HBoxContainer.new()
	for p in ["day", "sunset", "night_new", "night_full"]:
		lrow.add_child(UITheme.button({"day": "Day", "sunset": "Sunset", "night_new": "Dark night", "night_full": "Full moon"}[p], func() -> void: _apply_preset(p), 66))
	v.add_child(lrow)
	if Game.campaign:
		var dt := DayTestPanel.new()
		v.add_child(dt)
		dt.setup(self)
	if Game.crew:
		var cd := CrewDemoPanel.new()
		v.add_child(cd)
		cd.setup(self)
	v.add_child(UITheme.label("Phase 5 stops", 16, UITheme.MUTED))
	var p5 := GridContainer.new()
	p5.columns = 2
	for s5 in [["Driving & hauling", "__p5_drive"], ["Dock & dog", "__p5_dock"], ["Surveillance", "__p5_tv"], ["Arcade", "__p5_arcade"], ["Dog: refuge", "__p5_refuge"], ["Dog: home now", "__p5_doghome"]]:
		p5.add_child(UITheme.button(s5[0], func() -> void: _phase5_stop(s5[1]), 130))
	v.add_child(p5)
	v.add_child(UITheme.label("Phase 6 stops (in memory)", 16, UITheme.MUTED))
	var p6 := GridContainer.new()
	p6.columns = 2
	for s6 in [["Night director", "__p6_night"], ["Next family event", "__p6_next"], ["Dog rescue", "__p6_rescue"], ["Abandon -> hunt", "__p6_hunt"], ["Hunt: day 35", "__p6_day35"], ["Hunt: ship", "__p6_ship"]]:
		p6.add_child(UITheme.button(s6[0], func() -> void: _phase6_stop(s6[1]), 130))
	v.add_child(p6)
	v.add_child(UITheme.label("Phase 7 island audit (dev)", 16, UITheme.MUTED))
	var p7 := GridContainer.new()
	p7.columns = 2
	for s7 in [["Audit overlay", "__p7_overlay"], ["East bridge", "__p7_bridge_e"], ["South bridge", "__p7_bridge_s"], ["Truck height", "__p7_truck"], ["Locate work", "__p7_locate"], ["Dock & hides", "__p7_dock"]]:
		p7.add_child(UITheme.button(s7[0], func() -> void: _phase7_stop(s7[1]), 130))
	v.add_child(p7)
	v.add_child(UITheme.label("Phase 8 review stations (preview fixtures)", 16, UITheme.MUTED))
	var p8 := GridContainer.new()
	p8.columns = 2
	for s8 in ReviewStations.STATIONS:
		p8.add_child(UITheme.button(s8[0], func() -> void:
			var msg := ReviewStations.go(self, s8[1])
			if msg != "":
				show_message(msg, 9.0)
			tour_panel.visible = false
			_capture_mouse(), 130))
	v.add_child(p8)
	v.add_child(UITheme.label("Phase 11 cast, dog & camper", 16, UITheme.MUTED))
	var p11 := GridContainer.new()
	p11.columns = 2
	for s11 in ReviewStations.STATIONS11:
		p11.add_child(UITheme.button(s11[0], func() -> void:
			var msg := ReviewStations.go(self, s11[1])
			if msg != "":
				show_message(msg, 9.0)
			tour_panel.visible = false
			_capture_mouse(), 130))
	v.add_child(p11)
	v.add_child(UITheme.label("Phase 12 dense island, cover & motion", 16, UITheme.MUTED))
	var p12 := GridContainer.new()
	p12.columns = 2
	for s12 in ReviewStations.STATIONS12:
		p12.add_child(UITheme.button(s12[0], func() -> void:
			var msg := ReviewStations.go(self, s12[1])
			if msg != "":
				show_message(msg, 9.0)
			tour_panel.visible = false
			_capture_mouse(), 130))
	v.add_child(p12)
	v.add_child(UITheme.label("Phase 13 logging yard, longer logs & cart", 16, UITheme.MUTED))
	var p13 := GridContainer.new()
	p13.columns = 2
	for s13 in ReviewStations.STATIONS13:
		p13.add_child(UITheme.button(s13[0], func() -> void:
			var msg := ReviewStations.go(self, s13[1])
			if msg != "":
				show_message(msg, 9.0)
			tour_panel.visible = false
			_capture_mouse(), 130))
	v.add_child(p13)
	v.add_child(UITheme.label("Phase 14 tools, gear, supplier & teamwork", 16, UITheme.MUTED))
	var p14 := GridContainer.new()
	p14.columns = 2
	for s14 in ReviewStations.STATIONS14:
		p14.add_child(UITheme.button(s14[0], func() -> void:
			var msg := ReviewStations.go(self, s14[1])
			if msg != "":
				show_message(msg, 12.0)
			tour_panel.visible = false
			_capture_mouse(), 130))
	v.add_child(p14)
	v.add_child(UITheme.label("Phase 15 sound audition (headphones recommended)", 16, UITheme.MUTED))
	var p15 := GridContainer.new()
	p15.columns = 2
	for s15 in ReviewStations.STATIONS15:
		p15.add_child(UITheme.button(s15[0], func() -> void:
			var msg := ReviewStations.go(self, s15[1])
			if msg != "":
				show_message(msg, 12.0)
			tour_panel.visible = false
			_capture_mouse(), 130))
	v.add_child(p15)
	v.add_child(UITheme.label("Phase 16 crew growth & restedness", 16, UITheme.MUTED))
	var p16 := GridContainer.new()
	p16.columns = 2
	for s16 in ReviewStations.STATIONS16:
		p16.add_child(UITheme.button(s16[0], func() -> void:
			var msg := ReviewStations.go(self, s16[1])
			if msg != "":
				show_message(msg, 14.0)
			tour_panel.visible = false
			_capture_mouse(), 130))
	v.add_child(p16)
	v.add_child(UITheme.label("Phase 17 crew talk & the camper internet", 16, UITheme.MUTED))
	var p17 := GridContainer.new()
	p17.columns = 2
	for s17 in ReviewStations.STATIONS17:
		p17.add_child(UITheme.button(s17[0], func() -> void:
			var msg := ReviewStations.go(self, s17[1])
			if msg != "":
				show_message(msg, 16.0)
			tour_panel.visible = false
			_capture_mouse(), 130))
	v.add_child(p17)
	v.add_child(UITheme.label("Phase 18 crew voices (headphones recommended)", 16, UITheme.MUTED))
	var p18 := GridContainer.new()
	p18.columns = 3
	for s18 in ReviewStations.STATIONS18:
		p18.add_child(UITheme.button(s18[0], func() -> void:
			var msg := ReviewStations.go(self, s18[1])
			if msg != "":
				show_message(msg, 10.0)
			tour_panel.visible = false
			_capture_mouse(), 110))
	v.add_child(p18)
	v.add_child(UITheme.button("Character Preview", func() -> void: Game.open_character_preview(), 268))
	v.add_child(UITheme.button("Run 60 s benchmark route", _start_benchmark, 268))
	v.add_child(UITheme.button("Back to title", func() -> void: Game.return_to_menu(), 268))
	v.add_child(UITheme.label("Preview mode never writes saves.", 14, UITheme.MUTED))


func _goto(spot: String) -> void:
	match spot:
		"__loop":
			show_message(LoggingTest.loop(Game.world_root), 6.0)
			_capture_mouse()
			return
		"__reset":
			show_message(LoggingTest.reset_state())
			return
		"__snap":
			show_message(LoggingTest.snapshot())
			return
		"__restore":
			show_message(LoggingTest.restore_snapshot())
			_capture_mouse()
			return
	if spot == "__next_tree" or spot == "logging_test":
		var info := LoggingTest.next(Game.world_root, spot == "logging_test")
		show_message(info)
		_capture_mouse()
		return
	if Game.world_root:
		Game.world_root.teleport_to(spot)
		var vp: Dictionary = Viewpoints.all().get(spot, {})
		show_message(vp.get("label", spot))
	_capture_mouse()


## Preview-only review stops (in-memory, never saved).
func _phase5_stop(which: String) -> void:
	var w: IslandWorld = Game.world_root
	if w == null:
		return
	var p: Player = Game.player
	match which:
		"__p5_drive":
			var cs: CampaignService = Game.campaign
			if cs and not cs.active:
				cs.start_test_route(false)
			var vs: VehicleService = Game.vehicles
			vs.dev_unlock = true
			while vs.trucks.size() < VehicleService.MAX_TRUCKS:
				cs.wallet.grant(int(vs.unlock_state().price), "preview", "P5", "preview truck fixture")
				if not bool(vs.buy().ok):
					break
			var t: Truck = vs.trucks.values()[0]
			p.teleport_feet(t.door_point(-1.0), t.global_rotation.y)
			show_message("Two pickups in the bays (preview fixture). " + Keys.label("interact") + " at the driver's door to drive; the Journal (" + Keys.label("toggle_journal") + ") Crew tab sends a team. Load logs at the tailgate, unload at the drop-off by the rack.", 9.0)
		"__p5_dock":
			w.teleport_to("dock")
			show_message("Service dock, utility building (beacon console inside) and Biscuit's alcove.", 6.0)
		"__p5_refuge":
			if Game.dog:
				show_message("Biscuit heads for the dock refuge (Phase 6 survival state test)." if Game.dog.enter_refuge() else "No route to the refuge.")
		"__p5_doghome":
			if Game.dog:
				Game.dog.leave_refuge()
				Game.dog.go_home()
				show_message("Biscuit walks home through the camper door flap.")
		"__p5_tv":
			if w.get_node_or_null("ReviewSubject") == null:
				var rs := ReviewSubject.new()
				rs.name = "ReviewSubject"
				w.add_child(rs)
			var seats := WorldGroups.of(self, "couch_seat")
			w.teleport_to("camper_lounge")
			if not seats.is_empty():
				p.sit_on_couch.call_deferred(seats[0])
			show_message("Surveillance: a preview surveyor in hi-vis walks past CAM-03 and the north fence so you can check the feeds are live.", 8.0)
		"__p5_arcade":
			var spots := WorldGroups.of(self, "arcade_spot")
			if not spots.is_empty():
				var s: Node3D = spots[0]
				p.teleport_feet(s.global_position, s.global_rotation.y)
			show_message("Two original cabinets: Log Stacker and Flapjack Flip. " + Keys.label("interact") + " to play - the world pauses while you do.", 7.0)
	tour_panel.visible = false
	_capture_mouse()


var _p6_family := 0
var _overlay: AuditOverlay


## Phase 7 review route (Preview only; read-only diagnostics).
func _phase7_stop(which: String) -> void:
	var w: IslandWorld = Game.world_root
	var p: Player = Game.player
	if w == null or p == null:
		return
	match which:
		"__p7_overlay":
			if _overlay and is_instance_valid(_overlay):
				_overlay.queue_free()
				_overlay = null
				show_message("Audit overlay off.")
			else:
				_overlay = AuditOverlay.new()
				w.add_child(_overlay)
				show_message("Audit overlay: green = support samples, red = gap above tolerance (with labels), blue = crew walkable cells, orange = truck-drivable cells. Within 30 m of you.", 8.0)
		"__p7_bridge_e", "__p7_bridge_s":
			var b: Dictionary = World.bridges()[0 if which == "__p7_bridge_e" else 1]
			var across := Vector2(float(b.ax), float(b.az)).normalized()
			var foot := Vector2(b.x, b.z) + across * (float(b.half_span) + BridgeBuilder.ramp_length(b, 1.0) + 4.0)
			p.teleport_feet(Vector3(foot.x, World.height_at(foot.x, foot.y), foot.y), atan2(across.x, across.y))
			show_message("Trail bridge (3.6 m, truck-capable). Walk across: you stay on the deck; trucks route over it too.", 6.0)
		"__p7_truck":
			if Game.vehicles and not Game.vehicles.trucks.is_empty():
				var t: Truck = Game.vehicles.trucks.values()[0]
				p.teleport_feet(t.door_point(-1.0), t.global_rotation.y)
				show_message("Get in (%s) for the driving-height view." % Keys.label("interact"))
			else:
				_phase5_stop("__p5_drive")
		"__p7_locate":
			var near := ContractLocator.nearest(p.global_position)
			for k in ["log", "stump", "tree"]:
				if near.has(k):
					ContractLocator.mark(w, near[k])
					show_message("Nearest %s: %s (light column for 60 s)" % [k, ContractLocator.describe(p.global_position, near[k])])
					break
		"__p7_dock":
			w.teleport_to("dock")
	tour_panel.visible = false
	_capture_mouse()


## Preview-only Phase 6 fixtures (never saved; a separate test session).
func _phase6_stop(which: String) -> void:
	var w: IslandWorld = Game.world_root
	var cs: CampaignService = Game.campaign
	if w == null or cs == null:
		return
	if not cs.active:
		cs.start_test_route(false)
	match which:
		"__p6_night":
			cs.clock.advance(maxf(WorkdayClock.NIGHT_AT + 1.0 - cs.clock.t, 0.0))
			cs.test_route_light_override = false
			Game.director.next_in = 4.0
			show_message("Contract night (test session): the director offers its first encounter in a few seconds, then every 45-150 s. Stay outside a lit area too long and the night catches you.", 9.0)
		"__p6_next":
			cs.clock.advance(maxf(WorkdayClock.NIGHT_AT + 1.0 - cs.clock.t, 0.0))
			_p6_family = _p6_family % 25 + 1
			var ctx := TerrorPlacement.context_of(Game.player)
			var pick := ""
			for e in Game.director.events_by_ctx.get(ctx, []):
				if int(e.family) == _p6_family:
					pick = str(e.id)
					break
			if Game.director.active:
				Game.director.active.cancel()
				Game.director.active = null
			var got := Game.director.offer(pick) if pick != "" else ""
			show_message("Family T%02d %s: %s" % [_p6_family, str(Game.director.bank.families[_p6_family - 1].name), (got + " - " + str(Game.director.find(got).text)) if got != "" else "no valid place here (a quiet outcome) - try another spot"], 8.0)
		"__p6_rescue":
			cs.clock.day = maxi(cs.clock.day, 6)
			cs.clock.advance(maxf(WorkdayClock.NIGHT_AT + 1.0 - cs.clock.t, 0.0))
			Game.dog.pets = maxi(Game.dog.pets, 1)
			Game.dog_rescue.trigger_id = ""
			Game.dog_rescue.state = "IDLE"
			w.teleport_to("camper")
			Game.dog.global_position = CampLayout.world(CampLayout.CAMPER_POS + Vector3(2.6, 0, 1.6))
			Game.dog_rescue.force_start()
			show_message("Dog rescue fixture: wait in the camper. When the wind takes the door, follow Biscuit's whining, pet the dog, and walk home together.", 9.0)
		"__p6_hunt":
			cs.clock.day = 30
			cs.contract.state = ContractService.ABANDONMENT
			Game.hunt.begin_abandonment()
		"__p6_day35":
			if not Game.hunt.hunt_active():
				cs.clock.day = 30
				cs.contract.state = ContractService.ABANDONMENT
				Game.hunt.begin_abandonment()
			Game.hunt.hunt_day = 35
			Game.hunt.t = HuntService.DAYLIGHT - 20.0
			show_message("Hunt day 35, just before dusk.")
		"__p6_ship":
			if not Game.hunt.hunt_active():
				cs.clock.day = 30
				cs.contract.state = ContractService.ABANDONMENT
				Game.hunt.begin_abandonment()
			Game.hunt.hunt_day = 35
			Game.hunt.t = HuntService.CYCLE - 2.0
			show_message("Dawn of day 36 in two seconds: the rescue ship comes to the dock.")
	tour_panel.visible = false
	_capture_mouse()


func _start_benchmark() -> void:
	if _bench:
		return
	_bench = Benchmark.new()
	_bench.finished.connect(func(report: String) -> void:
		bench_label.text = ""
		show_message("Benchmark done: " + report.get_slice("\n", 0))
		_bench = null)
	_bench.progress.connect(func(t: String) -> void: bench_label.text = t)
	add_child(_bench)
	tour_panel.visible = false
	_capture_mouse()


func _on_hit_result(kind: String, res: Dictionary) -> void:
	if kind == "stump":
		if bool(res.get("removed", false)):
			show_message("Stump removed.", 1.5)
		elif str(res.get("reason", "")) == "trunk_first":
			show_message("Deal with the fallen trunk first.", 1.5)
		return
	if kind != "timber":
		return
	match str(res.get("reason", "")):
		"wait":
			show_message("Let it settle before cutting.", 1.5)
		"no_boundary":
			show_message("Aim at an orange mark to buck the trunk.", 1.5)
	if bool(res.get("separated", false)):
		show_message("Log cut free.", 1.2)


func _on_chop_target(info: Dictionary) -> void:
	if info.has("stump"):
		_aid_info = {}
		chop_label.text = ("[LMB] Chop out stump   %d%%" % int(float(info.progress) * 100.0)) if bool(info.ready) else "Buck and clear the trunk before removing the stump"
		return
	if info.has("timber"):
		_aid_info = {}
		if not bool(info.resting):
			chop_label.text = "Settling..."
		elif float(info.progress) < 0.0:
			chop_label.text = "" if bool(info.single) else "Aim at an orange mark to buck"
		else:
			chop_label.text = "[LMB] Buck here   cut %d%%" % int(float(info.progress) * 100.0)
		return
	_aid_info = info
	if info.is_empty():
		chop_label.text = ""
		return
	var pr := float(info.get("progress", 0.0))
	var notch := "" if pr <= 0.0 else "   notch %d%%" % int(pr * 100.0)
	chop_label.text = "[LMB] Chop %s  (%.2f m)%s" % [info.species, info.diameter, notch]


func _build_aid() -> void:
	# Subtle optional fall-direction cue: a faint arrow on the ground.
	_aid = MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.12, 0, 0), Vector3(0.12, 0, 0), Vector3(0.12, 0, 2.2), Vector3(-0.12, 0, 0), Vector3(0.12, 0, 2.2), Vector3(-0.12, 0, 2.2), Vector3(-0.4, 0, 2.2), Vector3(0.4, 0, 2.2), Vector3(0, 0, 2.9)]
	for v in pts:
		st.add_vertex(v)
	_aid.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.35)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_aid.material_override = m
	_aid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aid.visible = false
	if Game.world_root:
		Game.world_root.add_child.call_deferred(_aid)


func _update_aid() -> void:
	if _aid == null or not _aid.is_inside_tree():
		return
	var show_it: bool = Settings.get_v("felling_aid") and _aid_info.has("fall_dir") and float(_aid_info.get("progress", 0.0)) > 0.0
	_aid.visible = show_it
	if show_it:
		var i: int = Game.vegetation.tree_index_by_id.get(int(_aid_info.id), int(_aid_info.id))
		var base := World.tree_position(i)
		var fd: Vector3 = _aid_info.fall_dir
		var start := base + fd * (float(World.trees.radius[i]) + 0.6)
		_aid.global_transform = Transform3D(Basis.looking_at(-fd, Vector3.UP), start + Vector3(0, 0.06, 0))
		_aid.global_position.y = World.height_at(start.x, start.z) + 0.06


## Every on-screen message goes through the prioritized queue (Phase 9).
var notes := Notifications.new()


func show_message(text: String, seconds := 4.0, priority := -1) -> void:
	notes.push(text, seconds, priority)
	message_label.text = notes.tick(0.0)
	_msg_t = 0.1


func _write_diag() -> void:
	var path := Diag.write_report()
	show_message("Diagnostic report written:\n" + Diag.sanitize(path), 8.0)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	settings_panel.visible = false
	if p:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_capture_mouse()


func _capture_mouse() -> void:
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if campaign_ui and campaign_ui.is_open():
		# A campaign panel owns input until it is closed (Esc or its button).
		if event.is_action_pressed("pause") or event.is_action_pressed("toggle_journal"):
			campaign_ui.close_panel()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_journal"):
		if Game.campaign and Game.campaign.active and not get_tree().paused:
			campaign_ui.toggle_journal()
		else:
			show_message("The journal tracks a campaign (Preview: Tour → Day & Economy Test).")
		return
	if event.is_action_pressed("pause"):
		if settings_panel.visible:
			settings_panel.visible = false
			pause_panel.visible = true
		else:
			_toggle_pause()
	elif event.is_action_pressed("toggle_help"):
		help_panel.visible = not help_panel.visible
	elif event.is_action_pressed("toggle_debug"):
		debug_label.visible = not debug_label.visible
	elif event.is_action_pressed("toggle_time_panel") and Game.campaign and Game.campaign.active and not Game.is_preview():
		show_message("In the campaign the sun follows the workday clock.")
	elif event.is_action_pressed("toggle_time_panel"):
		time_panel.visible = not time_panel.visible
		if time_panel.visible and Game.environment:
			_time_slider.set_value_no_signal(Game.environment.hour)
			_overcast_slider.set_value_no_signal(Game.environment.overcast)
			_update_time_label()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if time_panel.visible else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("preview_panel") and Game.is_preview():
		tour_panel.visible = not tour_panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if tour_panel.visible else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("toggle_timber"):
		timber_panel.visible = not timber_panel.visible
	elif event.is_action_pressed("inspect_tree"):
		_inspect_tree()
	elif event.is_action_pressed("ripple_test"):
		if Game.water and Game.player:
			var p: Vector3 = Game.player.global_position - Game.player.global_basis.z * 3.0
			Game.water.emit_ripple(p, 1.5)
			show_message("Ripple test emitted 3 m ahead")
	elif event.is_action_pressed("quick_save"):
		if Game.mode == Game.Mode.CAMPAIGN and Game.world_root:
			Game.world_root.save_campaign()
			show_message("Saved (previous save kept as backup).")
		else:
			show_message("Preview mode never writes saves.")
	elif event.is_action_pressed("quick_load"):
		if Game.mode == Game.Mode.CAMPAIGN:
			Game.start_campaign()
		else:
			show_message("Preview mode has no save to load.")
	elif event.is_action_pressed("write_diagnostics"):
		_write_diag()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused and not tour_panel.visible and not time_panel.visible and not (campaign_ui and campaign_ui.is_open()):
		_capture_mouse()


func _inspect_tree() -> void:
	if Game.player == null:
		return
	var idx: int = Game.player.inspect_tree()
	if idx < 0:
		tree_panel.visible = false
		show_message("No harvestable tree under the crosshair")
		return
	var r := World.tree_record(idx)
	var lines: PackedStringArray = ["Tree record (harvestable)"]
	for k in r:
		lines.append("%s: %s" % [k, str(r[k])])
	tree_label.text = "\n".join(lines)
	tree_panel.visible = true


func _process(delta: float) -> void:
	# Notification queue (real time; it keeps showing while paused).
	message_label.text = notes.tick(delta)
	_update_aid()
	var p: Node = Game.player
	if p and p.get("axe"):
		var t: String = p.axe.tier
		var owned_hint := "(1/2/3 debug tiers)" if not (Game.campaign and Game.campaign.active and not Game.campaign.test_route) else "(1/2/3 owned axes · J journal)"
		axe_label.text = "Axe: %s  %.2fx  %s" % [t.capitalize(), float(CampaignRules.AXE_RATES[t]), owned_hint]
	if p and p.get("vehicle") is Truck:
		var tr: Truck = p.vehicle
		var vs: VehicleService = Game.vehicles
		var step := vs.next_tutorial_step() if vs else ""
		hint_label.text = "%s  ·  %s  ·  %d km/h  ·  bed %.2f / 3.00 tree-eq  ·  lights %s%s%s" % [tr.truck_id, p.vehicle_seat, roundi(absf(tr.speed()) * 3.6), tr.cargo_mte() / 1000.0, "on" if tr.headlights else "off (H)", ("  ·  camp limit %d km/h" % roundi(Truck.CAMP_SPEED * 3.6)) if Game.crew and Game.crew.nav.in_camp(tr.global_position) else "", ("\nTutorial: " + str(VehicleService.TUTORIAL_TEXT.get(step, ""))) if step != "" else ""]
	elif p and p.get("couch") != null and Game.tv:
		var tv: CameraWall = Game.tv
		var what: String = {"quad": "camera wall", "focus": "%s %s (focused)" % [tv.cam_id(tv.focus_index), tv.cam_name(tv.focus_index)], "entertainment": "Timber Tales (channel 3)"}.get(tv.mode, tv.mode) if tv.powered else "TV off"
		hint_label.text = "TV: %s  ·  mics %s  ·  vol %d%%  ·  swap every %.0f s  ·  click a tile · RMB back · A/D camera · C channel · M mute · P power · E stand" % [what, "muted" if tv.mic_muted else "on", roundi(tv.tv_volume * 100.0), tv.interval]
	elif p:
		if p.too_deep:
			hint_label.text = "Too deep to wade - the water pushes you back toward the shore"
		elif p.wading_depth > 0.3:
			hint_label.text = "Wading (%.1f m)" % p.wading_depth
		else:
			hint_label.text = ""
	if Game.objective != "":
		hint_label.text = "> " + Game.objective + ("\n" + hint_label.text if hint_label.text != "" else "")
	if debug_label.visible:
		debug_label.text = _debug_text()
	if p and p.get("carry"):
		carry_label.text = p.carry.load_text()
	if timber_panel.visible:
		_timber_t -= delta
		if _timber_t <= 0.0:
			_timber_t = 0.5
			timber_label.text = _timber_text()


func _debug_text() -> String:
	var fs := Diag.frame_stats()
	var p: Node3D = Game.player
	var lines: PackedStringArray = []
	lines.append("FPS %d  (avg %.1f ms, p95 %.1f ms, p99 %.1f ms)" % [Engine.get_frames_per_second(), fs.get("avg_ms", 0.0), fs.get("p95_ms", 0.0), fs.get("p99_ms", 0.0)])
	lines.append("Draw calls %d  Primitives %dk  Objects %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	lines.append("Physics active %d  Tree colliders %d  Cover cells %d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Game.vegetation.active_tree_collision_count() if Game.vegetation else 0, Game.world_root.ground_cover.cell_count() if Game.world_root and Game.world_root.ground_cover else 0])
	lines.append("VRAM %.0f MB  Static %.0f MB" % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	if p:
		var pos := p.global_position
		lines.append("Pos %.1f %.1f %.1f  Surface %s  Water depth %.2f" % [pos.x, pos.y, pos.z, p.surface_name, p.wading_depth])
		if Game.safety:
			var q: Dictionary = Game.safety.query(pos + Vector3(0, 0.9, 0))
			lines.append("Night safety here: %s (%s)" % ["SAFE" if q.safe else "unsafe", SafetyService.Reason.keys()[q.reason]])
	if Game.environment:
		lines.append("Lighting: %s" % Game.environment.describe())
	if Game.weather:
		lines.append("Weather: %s" % Game.weather.call("describe"))
	lines.append("Quality %s  Mode %s  %s" % [Settings.get_v("quality"), Game.Mode.keys()[Game.mode], Diag.version_string()])
	return "\n".join(lines)
