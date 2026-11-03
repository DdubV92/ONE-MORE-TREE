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
	var p: Node = Game.player
	if p:
		p.interact_target_changed.connect(func(t: String) -> void: prompt_label.text = ("[E] " + t) if t != "" else "")
		p.message.connect(show_message)
	if Game.is_preview():
		tour_panel.visible = true
		show_message("Preview Tour: Tab toggles the tour panel, F1 shows controls")
	else:
		show_message("Welcome to the island. F1 for controls.")


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


func _apply_preset(p: String) -> void:
	if Game.environment:
		Game.environment.apply_named(p)
		_time_slider.set_value_no_signal(Game.environment.hour)
		_overcast_slider.set_value_no_signal(Game.environment.overcast)
		_update_time_label()


func _update_time_label() -> void:
	if Game.environment:
		_time_label.text = "Time %s" % Game.environment.describe()


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
	var v := VBoxContainer.new()
	tour_panel.add_child(v)
	v.add_child(UITheme.label("Preview Tour", 22, UITheme.ACCENT))
	v.add_child(UITheme.label("Locations", 16, UITheme.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	var spots := [["Camp", "camp"], ["Camper", "camper"], ["Cabin", "cabin"], ["Beach", "beach"], ["Shallows", "shallows"], ["Forest", "forest"], ["River", "river"], ["Rapids", "rapids"], ["Pond", "pond"], ["Pond 2", "pond2"], ["Ridge", "ridge"], ["Coast", "coast_day"]]
	for s in spots:
		grid.add_child(UITheme.button(s[0], func() -> void: _goto(s[1]), 130))
	v.add_child(grid)
	v.add_child(UITheme.label("Lighting", 16, UITheme.MUTED))
	var lrow := HBoxContainer.new()
	for p in ["day", "sunset", "night"]:
		lrow.add_child(UITheme.button(p.capitalize(), func() -> void: _apply_preset(p), 84))
	v.add_child(lrow)
	v.add_child(UITheme.button("Character Preview", func() -> void: Game.open_character_preview(), 268))
	v.add_child(UITheme.button("Run 60 s benchmark route", _start_benchmark, 268))
	v.add_child(UITheme.button("Back to title", func() -> void: Game.return_to_menu(), 268))
	v.add_child(UITheme.label("Preview mode never writes saves.", 14, UITheme.MUTED))


func _goto(spot: String) -> void:
	if Game.world_root:
		Game.world_root.teleport_to(spot)
		var vp: Dictionary = Viewpoints.all().get(spot, {})
		show_message(vp.get("label", spot))
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


func show_message(text: String, seconds := 4.0) -> void:
	message_label.text = text
	_msg_t = seconds


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
	elif event.is_action_pressed("inspect_tree"):
		_inspect_tree()
	elif event.is_action_pressed("ripple_test"):
		if Game.water and Game.player:
			var p: Vector3 = Game.player.global_position - Game.player.global_basis.z * 3.0
			Game.water.emit_ripple(p, 1.5)
			show_message("Ripple test emitted 3 m ahead")
	elif event.is_action_pressed("write_diagnostics"):
		_write_diag()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused and not tour_panel.visible and not time_panel.visible:
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
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			message_label.text = ""
	var p: Node = Game.player
	if p:
		if p.too_deep:
			hint_label.text = "Too deep to wade - the water pushes you back toward the shore"
		elif p.wading_depth > 0.3:
			hint_label.text = "Wading (%.1f m)" % p.wading_depth
		else:
			hint_label.text = ""
	if debug_label.visible:
		debug_label.text = _debug_text()


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
	lines.append("Quality %s  Mode %s  %s" % [Settings.get_v("quality"), Game.Mode.keys()[Game.mode], Diag.version_string()])
	return "\n".join(lines)
