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
	center.anchor_left = 0.08
	center.anchor_top = 0.2
	center.position = Vector2.ZERO
	add_child(center)
	var title := UITheme.label("ONE MORE TREE", 72, Color(0.98, 0.93, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	title.add_theme_constant_override("outline_size", 10)
	center.add_child(title)
	center.add_child(UITheme.label("Thirty days to clear an island. Keep the crew paid. Be inside by night.", 20, Color(0.9, 0.88, 0.8)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	center.add_child(spacer)
	_menu = VBoxContainer.new()
	center.add_child(_menu)
	_menu.add_child(UITheme.button("Play the contract", _show_slots, 340))
	_menu.add_child(UITheme.button("Preview Tour", func() -> void: _go(func() -> void: Game.start_preview("camp")), 340))
	_menu.add_child(UITheme.button("Character Preview", func() -> void: _go(func() -> void: Game.open_character_preview()), 340))
	_menu.add_child(UITheme.button("Settings", func() -> void:
		_settings.visible = true
		_menu.visible = false, 340))
	_menu.add_child(UITheme.button("Write diagnostic report", func() -> void:
		_status.text = "Report written: " + Diag.sanitize(Diag.write_report()), 340))
	_menu.add_child(UITheme.button("Quit", func() -> void: get_tree().quit(), 340))
	_status = UITheme.label("", 16, Color(0.85, 0.9, 0.85))
	center.add_child(_status)
	var footer := UITheme.label("%s  -  Godot %s  -  Forward+" % [Diag.version_string(), Engine.get_version_info().string], 14, Color(0.85, 0.85, 0.8))
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.position = Vector2(20, -34)
	add_child(footer)
	_settings = SettingsPanel.new()
	_settings.anchor_left = 0.55
	_settings.anchor_top = 0.1
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_settings.visible = false
		_menu.visible = true)
	add_child(_settings)


## Three campaign slots. Continue loads a slot; New contract replaces only
## the chosen slot (after a confirmation; the old file becomes its .bak).
var _slots: VBoxContainer

func _show_slots() -> void:
	_menu.visible = false
	if _slots:
		_slots.queue_free()
	_slots = VBoxContainer.new()
	_menu.get_parent().add_child(_slots)
	_slots.add_child(UITheme.label("Choose a save slot", 26, UITheme.ACCENT))
	for n in range(1, SaveService.SLOTS + 1):
		var info := SaveService.slot_summary(n)
		var row := HBoxContainer.new()
		var desc := "Slot %d: empty" % n
		if info.get("corrupt", false):
			desc = "Slot %d: unreadable (kept on disk; a backup is tried on load)" % n
		elif not info.is_empty():
			if bool(info.pre_contract):
				desc = "Slot %d: island save from before the contract rules%s" % [n, " (old single save)" if bool(info.get("legacy_file", false)) else ""]
			else:
				desc = "Slot %d: day %d, $%s, %s%s" % [n, int(info.day), Money.format_cents(int(info.cash)), "legacy (no deadline)" if str(info.rule_set).begins_with("legacy") else "30-day contract", ("  ·  " + str(info.state).replace("_", " ").to_lower()) if str(info.state) != "CONTRACT_ACTIVE" else ""]
		var l := UITheme.label(desc, 17)
		l.custom_minimum_size = Vector2(520, 0)
		row.add_child(l)
		var slot := n
		if not info.is_empty() and not info.get("corrupt", false):
			row.add_child(UITheme.button("Continue", func() -> void:
				SaveService.slot = slot
				Game.new_game = false
				_go(func() -> void: Game.start_campaign()), 140))
		row.add_child(UITheme.button("New contract", func() -> void: _confirm_new(slot, not info.is_empty()), 160))
		_slots.add_child(row)
	_slots.add_child(UITheme.button("Back", func() -> void:
		_slots.queue_free()
		_slots = null
		_menu.visible = true, 200))


func _confirm_new(n: int, occupied: bool) -> void:
	var start := func() -> void:
		SaveService.slot = n
		Game.new_game = true
		if _slots:
			_slots.visible = false
		_go(func() -> void: Game.start_campaign())
	if not occupied:
		start.call()
		return
	for c in _slots.get_children():
		c.queue_free()
	_slots.add_child(UITheme.label("Start a new contract in slot %d?" % n, 22, UITheme.ACCENT))
	_slots.add_child(UITheme.label("That slot's current save is replaced (kept once as a .bak file). Other slots are not touched.", 16))
	_slots.add_child(UITheme.button("Yes, start a new contract", start, 340))
	_slots.add_child(UITheme.button("Cancel", _show_slots, 200))


func _go(action: Callable) -> void:
	_menu.visible = false
	if _slots:
		_slots.visible = false
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
