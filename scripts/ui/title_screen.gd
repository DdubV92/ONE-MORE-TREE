extends Control
## Title / start screen. Explore (campaign), Preview Tour, Character Preview,
## Settings, diagnostics and quit. The painted backdrop is drawn in code
## (sky gradient, sea, layered conifer silhouettes) so the menu is instant.

var _settings: SettingsPanel
var _menu: VBoxContainer
var _status: Label
var _t := 0.0


func _ready() -> void:
	Game.mode = Game.Mode.MENU
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := VBoxContainer.new()
	center.anchor_left = 0.06
	center.anchor_top = 0.04
	center.position = Vector2.ZERO
	add_child(center)
	var title := UITheme.label("ONE MORE TREE", 60, Color(0.98, 0.93, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	title.add_theme_constant_override("outline_size", 10)
	center.add_child(title)
	center.add_child(UITheme.label("Thirty days to clear an island. Keep the crew paid. Be inside by night.", 20, Color(0.9, 0.88, 0.8)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)
	_menu = VBoxContainer.new()
	center.add_child(_menu)
	# Pages sit on a soft dark card so text stays readable over the scenery.
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.04, 0.78)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_card.add_theme_stylebox_override("panel", sb)
	_card.visible = false
	center.add_child(_card)
	_page = VBoxContainer.new()
	_card.add_child(_page)
	_status = UITheme.label("", 16, Color(0.85, 0.9, 0.85))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(620, 0)
	center.add_child(_status)
	_build_menu()
	var footer := UITheme.label("%s  -  Godot %s  -  Forward+" % [Diag.version_string(), Engine.get_version_info().string], 14, Color(0.85, 0.85, 0.8))
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.position = Vector2(20, -34)
	add_child(footer)
	_settings = SettingsPanel.new()
	_settings.anchor_left = 0.5
	_settings.anchor_top = 0.06
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_settings.visible = false
		_menu.visible = true
		_build_menu())
	add_child(_settings)


## Main menu (Phase 9). Every entry works or is disabled with its reason.
var _page: VBoxContainer
var _card: PanelContainer

func _build_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()
	var cont := SaveService.continue_slot()
	var cb := UITheme.button("Continue", func() -> void: _load_slot(cont), 340)
	_menu.add_child(cb)
	if cont < 0:
		cb.disabled = true
		_menu.add_child(_note("Continue: no unfinished campaign saved yet. Start a New Campaign."))
	else:
		var s := SaveService.slot_summary(cont)
		_menu.add_child(_note("Slot %d · %s · saved %s" % [cont, str(s.status), _when(int(s.saved_unix))]))
	_menu.add_child(UITheme.button("New Campaign", _new_campaign, 340))
	_menu.add_child(UITheme.button("Load", _show_slots, 340))
	_menu.add_child(UITheme.button("Settings", func() -> void:
		_settings.visible = true
		_menu.visible = false, 340))
	_menu.add_child(UITheme.button("Help & Controls", _show_help, 340))
	var extra := HFlowContainer.new()
	extra.custom_minimum_size = Vector2(720, 0)
	extra.add_child(UITheme.button("Preview Tour (sandbox)", func() -> void: _go(func() -> void: Game.start_preview("camp")), 230))
	extra.add_child(UITheme.button("Character Preview", func() -> void: _go(func() -> void: Game.open_character_preview()), 200))
	extra.add_child(UITheme.button("Credits", _show_credits, 120))
	extra.add_child(UITheme.button("Diagnostic report", func() -> void:
		_status.text = "Report written: " + Diag.sanitize(Diag.write_report()), 190))
	_menu.add_child(extra)
	_menu.add_child(UITheme.button("Quit", func() -> void: get_tree().quit(), 340))
	if not cb.disabled:
		cb.call_deferred("grab_focus")
	else:
		(_menu.get_child(2) as Control).call_deferred("grab_focus")


func _note(t: String) -> Label:
	var l := UITheme.label(t, 14, Color(0.82, 0.86, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(520, 0)
	return l


static func _when(unix: int) -> String:
	if unix <= 0:
		return "?"
	var d := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]


func _open_page(title: String) -> VBoxContainer:
	_menu.visible = false
	for c in _page.get_children():
		c.queue_free()
	_card.visible = true
	_page.add_child(UITheme.label(title, 26, UITheme.ACCENT))
	return _page


func _back() -> void:
	_card.visible = false
	_menu.visible = true
	_build_menu()


func _back_button(v: VBoxContainer) -> void:
	var b := UITheme.button("Back", _back, 200)
	v.add_child(b)
	b.call_deferred("grab_focus")


func _scroll_text(v: VBoxContainer, text: String, h := 420) -> void:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var l := UITheme.label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(740, 0)
	sc.add_child(l)
	v.add_child(sc)


func _show_help() -> void:
	var v := _open_page("Help & Controls")
	_scroll_text(v, "CONTROLS\n" + HelpText.controls() + "\n\nTHE CONTRACT\n" + HelpText.contract() + "\n\nNIGHTS\n" + HelpText.night() + "\n\nWHAT PAUSES\n" + HelpText.time_rules() + "\n\nCREW GROWTH & YOUR REST\n" + HelpText.growth_and_rest())
	_back_button(v)


func _show_credits() -> void:
	var v := _open_page("Credits")
	_scroll_text(v, "\n".join([
		"One More Tree: an original game made in Godot Engine %s (MIT licence, godotengine.org)." % Engine.get_version_info().string,
		"Textures and a few props: Poly Haven (CC0), see docs/ASSET_PROVENANCE.md for the exact list.",
		"Island, trees, buildings, characters, animation, shaders, sound effects and music: original, procedurally generated by this project's own tools.",
		"Built with Claude Code for the project owner.",
		"No licensed broadcasts, streaming services or third-party characters are used.",
	]), 220)
	_back_button(v)


## New Campaign: a short rules brief, then a slot. An occupied slot always
## asks first (its save becomes a .bak; other slots are untouched).
func _new_campaign() -> void:
	var v := _open_page("New Campaign")
	_scroll_text(v, "\n".join([
		"• Thirty workdays to clear the island: fell every original tree, remove its stump and deliver its logs to camp.",
		"• 10,000 original trees. You start with five employees (six of you in all), small axes and $4,500. $100 per tree, paid as its logs are accepted at camp. Felling alone pays nothing.",
		"• Each employee costs $300 per workday: $1,500 a day for the full crew, settled when you sleep. Unpaid wages lead to departures.",
		"• Get home by night. The camper is always safe during the contract, and night only ends when you sleep.",
		"• Content: night-time horror with sudden sounds and unsettling figures, and a dangerous outcome if the contract fails. Settings → Comfort has horror intensity and flash reduction.",
		"• A short first-day guide teaches the basics with real trees. You can skip it at any time (Journal → Help).",
		"Standard campaign only (the 10,000-tree contract). Older saves keep the rules they were started with (e.g. the legacy 12,000-tree contract).",
	]), 200)
	v.add_child(UITheme.label("Choose a slot:", 18, UITheme.ACCENT))
	var first: Button = null
	for n in range(1, SaveService.SLOTS + 1):
		var s := SaveService.slot_summary(n)
		var occupied := not s.is_empty()
		var desc := "Slot %d: empty" % n if not occupied else "Slot %d: %s" % [n, _summary_text(s)]
		var b := UITheme.button(desc, func() -> void: _confirm_new(n, occupied), 760)
		v.add_child(b)
		if first == null:
			first = b
		if bool(s.get("too_new", false)):
			b.disabled = true
			v.add_child(_note("Slot %d can't be replaced here: it was made by a newer version of the game." % n))
	_back_button(v)
	if first:
		first.call_deferred("grab_focus")


func _summary_text(s: Dictionary) -> String:
	if bool(s.get("corrupt", false)):
		return "unreadable save (kept on disk%s)" % (", a backup exists" if bool(s.get("has_backup", false)) else "")
	if bool(s.get("too_new", false)):
		return str(s.status)
	if bool(s.get("pre_contract", false)):
		return "island save from before the contract rules"
	return "%s · %.1f trees delivered · $%s · saved %s%s" % [str(s.status), float(s.accepted_trees), Money.format_cents(int(s.cash)), _when(int(s.saved_unix)), ("" if (s.checkpoints as Array).is_empty() else " · checkpoints: " + ", ".join(s.checkpoints))]


## Load: every slot with its state; checkpoints load as an explained rollback.
var _slots: VBoxContainer

func _show_slots() -> void:
	var v := _open_page("Load")
	var any := false
	for n in range(1, SaveService.SLOTS + 1):
		var s := SaveService.slot_summary(n)
		var row := VBoxContainer.new()
		row.add_child(UITheme.label("Slot %d: %s" % [n, "empty" if s.is_empty() else _summary_text(s)], 16))
		var h := HBoxContainer.new()
		row.add_child(h)
		if not s.is_empty() and not bool(s.get("too_new", false)):
			var lb := UITheme.button("Load slot %d" % n, func() -> void: _load_slot(n), 200)
			h.add_child(lb)
			if not any:
				lb.call_deferred("grab_focus")
			any = true
			if bool(s.get("finished", false)):
				row.add_child(_note("This run is over (%s). Loading shows its final state; start a New Campaign to play again." % str(s.status)))
			for k in (s.get("checkpoints", []) as Array):
				h.add_child(UITheme.button("Checkpoint: %s" % k, func() -> void: _load_checkpoint(n, str(k)), 200))
		v.add_child(row)
	if not any:
		v.add_child(_note("No saves yet."))
	v.add_child(_note("Loading a checkpoint rolls the slot back to that moment (the newer save is kept once as a .bak file)."))
	_back_button(v)


func _load_slot(n: int) -> void:
	if n < 1:
		return
	SaveService.slot = n
	Game.new_game = false
	_go(func() -> void: Game.start_campaign())


func _load_checkpoint(n: int, kind: String) -> void:
	SaveService.slot = n
	SaveService.restore_checkpoint(kind)
	Game.new_game = false
	_go(func() -> void: Game.start_campaign())


func _confirm_new(n: int, occupied: bool) -> void:
	var start := func() -> void:
		SaveService.slot = n
		Game.new_game = true
		_go(func() -> void: Game.start_campaign())
	if not occupied:
		start.call()
		return
	var v := _open_page("Replace slot %d?" % n)
	v.add_child(_note("Slot %d holds: %s.\nStarting a new campaign there replaces it (the old save is kept once as a .bak file). Other slots are not touched." % [n, _summary_text(SaveService.slot_summary(n))]))
	v.add_child(UITheme.button("Yes, replace slot %d and start" % n, start, 420))
	var c := UITheme.button("Cancel", _new_campaign, 200)
	v.add_child(c)
	c.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _settings.visible:
			return
		if _card.visible:
			_back()
			get_viewport().set_input_as_handled()


func _go(action: Callable) -> void:
	_menu.visible = false
	_card.visible = false
	_status.text = "Building the island..."
	await get_tree().process_frame
	await get_tree().process_frame
	action.call()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	# Sky gradient (late afternoon)
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var c := Color(0.22, 0.36, 0.6).lerp(Color(0.98, 0.72, 0.45), pow(t, 1.6))
		draw_rect(Rect2(0, s.y * 0.62 * t, s.x, s.y * 0.62 / steps + 1), c)
	draw_circle(Vector2(s.x * 0.72, s.y * 0.5), 46, Color(1.0, 0.86, 0.6, 0.9))
	# Sea with glints
	draw_rect(Rect2(0, s.y * 0.6, s.x, s.y * 0.4), Color(0.12, 0.38, 0.45))
	for k in 40:
		var x := fmod(k * 137.0 + _t * 12.0 * (1 + k % 3), s.x)
		var y := s.y * (0.62 + 0.3 * fmod(k * 0.618, 1.0))
		draw_line(Vector2(x, y), Vector2(x + 18 + k % 7 * 3, y), Color(1, 0.9, 0.7, 0.25), 2.0)
	# Island ridge and layered conifers
	_hill(s, 0.58, Color(0.12, 0.2, 0.14), 0.0)
	_trees(s, 0.6, 26.0, Color(0.07, 0.14, 0.09), 11)
	_trees(s, 0.66, 40.0, Color(0.04, 0.08, 0.05), 23)
	draw_rect(Rect2(0, s.y * 0.7, s.x, s.y * 0.3), Color(0.04, 0.06, 0.05, 0.75))


func _hill(s: Vector2, base: float, c: Color, _seed: float) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, s.y))
	for i in 41:
		var x := s.x * i / 40.0
		var y := s.y * (base - 0.05 * sin(i * 0.31) - 0.03 * sin(i * 0.77 + 1.0) - 0.06 * exp(-pow((i - 26) / 6.0, 2.0)))
		pts.append(Vector2(x, y))
	pts.append(Vector2(s.x, s.y))
	draw_colored_polygon(pts, c)


func _trees(s: Vector2, base: float, h: float, c: Color, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var x := -20.0
	while x < s.x + 20:
		var th := h * rng.randf_range(0.7, 1.5) * s.y / 1080.0
		var w := th * 0.32
		var by := s.y * base + rng.randf_range(-6, 10)
		var sway := sin(_t * 0.8 + x * 0.01) * 1.5
		draw_colored_polygon(PackedVector2Array([Vector2(x - w, by), Vector2(x + sway, by - th * 2.2), Vector2(x + w, by)]), c)
		x += rng.randf_range(w * 0.8, w * 1.8)
