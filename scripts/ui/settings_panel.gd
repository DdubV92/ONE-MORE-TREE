class_name SettingsPanel
extends PanelContainer
## Settings UI shared by the title screen and the pause menu. Every value goes
## through the Settings autoload (sanitized, persisted, re-applied).

signal closed


func _ready() -> void:
	theme = UITheme.get_theme()
	custom_minimum_size = Vector2(620, 0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	v.add_child(UITheme.label("Settings", 26, UITheme.ACCENT))
	_section(v, "Controls")
	_slider(v, "Mouse sensitivity", "mouse_sensitivity", 0.02, 1.5, 0.01)
	_toggle(v, "Invert mouse Y", "invert_y")
	_slider(v, "Field of view", "fov", 55, 100, 1)
	_toggle(v, "Head bob (comfort)", "head_bob")
	_toggle(v, "Camera shake on hits (comfort)", "camera_shake")
	_toggle(v, "Hold mouse button to keep chopping", "hold_to_chop")
	_toggle(v, "Show felling direction aid", "felling_aid")
	_section(v, "Graphics")
	_choice(v, "Quality preset", "quality", ["low", "medium", "high", "ultra"])
	_slider(v, "Render scale", "render_scale", 0.5, 1.0, 0.05)
	_toggle(v, "V-Sync", "vsync")
	_toggle(v, "Fullscreen", "fullscreen")
	_section(v, "Cinematic effects (each can be disabled)")
	_choice(v, "Depth of field", "dof_mode", ["off", "subtle", "cinematic"])
	_choice(v, "Upscaler (render scale < 100%)", "upscaler", ["bilinear", "fsr1", "fsr2"])
	_choice(v, "Tonemapper", "tonemapper", ["filmic", "agx"])
	_slider(v, "Chromatic aberration", "chromatic_aberration", 0.0, 1.0, 0.01)
	_slider(v, "Vignette", "vignette", 0.0, 1.0, 0.01)
	_slider(v, "Color grading", "color_grading", 0.0, 1.0, 0.01)
	_slider(v, "Film grain", "film_grain", 0.0, 1.0, 0.01)
	_toggle(v, "Bloom", "bloom")
	_toggle(v, "Heat haze (fire, hot sand)", "heat_haze")
	_section(v, "Audio")
	for b in Settings.BUSES:
		_slider(v, "%s volume" % b, "vol_" + b, 0.0, 1.0, 0.01)
	_section(v, "Camera TV")
	_slider(v, "Seconds per camera swap (0 = frozen)", "tv_interval", 0.0, 40.0, 5.0)
	var row := HBoxContainer.new()
	row.add_child(UITheme.button("Reset to defaults", func() -> void:
		Settings.reset_defaults()
		_rebuild(), 220))
	row.add_child(UITheme.button("Close", func() -> void: closed.emit(), 160))
	v.add_child(row)


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	call_deferred("_ready")


func _section(v: VBoxContainer, text: String) -> void:
	var l := UITheme.label(text, 20, UITheme.ACCENT)
	v.add_child(l)


func _row(v: VBoxContainer, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UITheme.label(text, 17)
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	v.add_child(h)
	return h


func _slider(v: VBoxContainer, text: String, key: String, mn: float, mx: float, step: float) -> void:
	var h := _row(v, text)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := UITheme.label("%.2f" % s.value, 16, UITheme.MUTED)
	val.custom_minimum_size = Vector2(56, 0)
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%.2f" % x
		Settings.set_v(key, x))
	h.add_child(s)
	h.add_child(val)


func _toggle(v: VBoxContainer, text: String, key: String) -> void:
	var h := _row(v, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_v(key))
	c.toggled.connect(func(on: bool) -> void: Settings.set_v(key, on))
	h.add_child(c)


func _choice(v: VBoxContainer, text: String, key: String, options: Array) -> void:
	var h := _row(v, text)
	var o := OptionButton.new()
	for opt in options:
		o.add_item(str(opt).capitalize())
	o.selected = maxi(options.find(Settings.get_v(key)), 0)
	o.item_selected.connect(func(i: int) -> void: Settings.set_v(key, options[i]))
	o.custom_minimum_size = Vector2(200, 36)
	h.add_child(o)
