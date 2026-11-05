class_name DeskComputer
extends Node
## Phase 11: the camper desk computer. Phase 22 made it a windowed desktop
## OS (see "desktop shell" below: icons, windows, taskbar, start menu,
## on-screen pointer, boot). An original, offline, fictional
## desktop ("CampOS") rendered into one SubViewport that is both the
## in-world monitor image and - while you sit at the desk - a readable
## overlay on the left of the screen, so the window to your right stays in
## view. Apps:
##   Cameras  - the existing live surveillance wall (CameraWall), rehosted:
##              quad, click a tile to focus, previous/next, back, swap
##              interval, microphones, volume, monitor power.
##   Supplier - Phase 14: the camp supplier (real Supplier/Equipment/Wallet:
##              catalog with exact benefits, cart, quote with payroll
##              warnings, idempotent prepaid orders, delivery status) and
##              the truck order (real VehicleService).
##   Gear     - Phase 14: your kit breakdown, camp storage, issuing gear to
##              the crew (the same screen as the tool rack).
##   Mail     - Phase 17: the boss's inbox from the authored bank, plus the
##              live supplier order status from the real order records.
##   News, Forums, Archives - Phase 17: the fictional internet published by
##              the campaign clock (FeedService / FeedReader).
##   Payroll  - Phase 21: per-worker pay, pay mood, productivity, raise
##              requests and the nightly / campaign pay reports (PayrollApp).
##   Recordings - Phase 20: the missed-night recording archive (NightRecorder
##              clips): list, play/pause, seek, previous/next incident,
##              volume; playback is an isolated reconstruction
##              (RecordingPlayer), labelled PLAYBACK - never a live view.
## A small quad inset keeps the cameras at the edge of attention in other
## apps (same four-feed budget: it is the same composite texture).
## Live: time keeps running while you use it; the real pause menu pauses.

signal app_changed(app: String)

const SIZE := Vector2i(1280, 720)       # Phase 22: was 1024 x 576
const APPS := ["Cameras", "Supplier", "Gear", "Payroll", "Mail", "News", "Forums", "Archives", "Recordings"]
const LATER := {}

var monitor: Node3D
var screen: MeshInstance3D
var vp: SubViewport
var overlay: CanvasLayer
var view: TextureRect
var forwarded := 0
var mat: ShaderMaterial
var app := "Cameras"
var powered := true
var seated := false
var glancing := false
var _shell: Control
var _inset: TextureRect
var _feed: TextureRect
var _clock: Label
var cart: Array = []                # Supplier cart lines {"key", "qty"}
var _req := [""]                    # current order request id (idempotency)
var clicks := 0                # tile clicks handled (tests)
var flagged := {}               # Phase 20: recording ids not yet viewed
var player: RecordingPlayer     # Phase 20: playback (only while the app is open)
var rec_index := -1
var _rec_view: TextureRect
var _rec_label: Label
var _rec_seek: HSlider
var _rec_time: Label


func setup() -> void:
	var root := get_parent()
	var mons := get_tree().get_nodes_in_group("camper_monitor").filter(func(n: Node) -> bool: return root == null or root.is_ancestor_of(n))
	if mons.is_empty():
		return
	monitor = mons[0]
	screen = monitor.get_node("Screen")
	screen.layers = 1 << (CameraWall.LAYER_TV - 1)
	overlay = CanvasLayer.new()
	overlay.layer = 40
	overlay.visible = false
	add_child(overlay)
	# The desktop viewport is NOT inside a container (a hidden container
	# would stop it rendering on the in-world monitor). The seated overlay
	# shows its texture and forwards mouse input into it.
	vp = SubViewport.new()
	vp.size = SIZE
	vp.disable_3d = true
	vp.handle_input_locally = true
	vp.gui_embed_subwindows = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	view = TextureRect.new()
	view.texture = vp.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	view.anchor_left = 0.02
	view.anchor_top = 0.06
	view.anchor_right = 0.72
	view.anchor_bottom = 0.86
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(_forward_input)
	# Over the screen, the screen's own pointer replaces the real cursor.
	view.mouse_entered.connect(func() -> void:
		if seated and not glancing:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN)
	view.mouse_exited.connect(func() -> void:
		if seated and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	overlay.add_child(view)
	_build_shell()
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/tv_screen.gdshader")
	mat.set_shader_parameter("feed", vp.get_texture())
	mat.set_shader_parameter("gain", 0.5)
	mat.set_shader_parameter("powered", 1.0)
	screen.material_override = mat
	open_app("Cameras")


## Overlay -> desktop: mouse events are re-expressed in desktop pixels.
func _forward_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouse):
		return
	var e := ev.duplicate() as InputEventMouse
	e.position = to_desktop(e.position, view.size)
	e.global_position = e.position
	if e is InputEventMouseMotion:
		# Drags and resizes move by desktop pixels, not overlay pixels.
		(e as InputEventMouseMotion).relative *= desktop_scale(view.size)
	pointer_to(e.position)
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and monitor and SoundService.instance() != null:
		# Phase 15: the real mouse on the desk (quiet, local, never relayed).
		SoundService.play("ui.click", monitor.global_position + Vector3(0.25, -0.35, 0.2), {"emit": false})
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		press_at(e.position)
	vp.push_input(e, true)
	forwarded += 1
	view.accept_event()


## Desktop pixels per overlay pixel (aspect-kept letterbox).
static func desktop_scale(rect: Vector2) -> float:
	var ar := float(SIZE.x) / float(SIZE.y)
	return float(SIZE.x) / maxf(minf(rect.x, rect.y * ar), 1.0)


## Moves the screen's pointer (part of the desktop image).
func pointer_to(p: Vector2) -> void:
	cursor_pos = p.clamp(Vector2.ZERO, Vector2(SIZE) - Vector2(2, 2))
	if _cursor:
		_cursor.position = cursor_pos


## Before a click reaches the desktop: the window under it comes to the
## front (as on a real desktop), and an open start menu closes when the
## click lands elsewhere.
func press_at(p: Vector2) -> void:
	if _start_menu and _start_menu.visible and not Rect2(_start_menu.position, _start_menu.size).has_point(p) and p.y < SIZE.y - TASKBAR_H:
		_start_menu.visible = false
	var w := window_at(p)
	if w and w != _focused:
		focus(w)


## Point in the overlay rect -> desktop pixel (aspect-kept letterbox).
static func to_desktop(p: Vector2, rect: Vector2) -> Vector2:
	var ar := float(SIZE.x) / float(SIZE.y)
	var w := minf(rect.x, rect.y * ar)
	var h := w / ar
	var o := (rect - Vector2(w, h)) * 0.5
	return (p - o) / Vector2(w, h) * Vector2(SIZE)


# ------------------------------------------------------------ desktop shell
# Phase 22 (owner request): CampOS runs like a real desktop OS. Wallpaper
# with program icons (double-click to open), overlapping program windows
# (drag by the title bar, resize from the corner, minimize / maximize /
# close; clicking a window raises it), a taskbar with the CampOS start
# menu, one button per open program and a tray (unread mail, flagged
# recordings, the camp clock), a drawn mouse pointer that is part of the
# screen image (so it also shows on the monitor in the room), and a short
# boot screen whenever the monitor is switched on.

const TASKBAR_H := 40.0
const WORKSPACE := Rect2(0, 0, 1280, 680)
## Default window rectangles (desktop pixels).
const DEFAULT_RECTS := {
	"Cameras": Rect2(330, 36, 900, 580), "Supplier": Rect2(250, 24, 880, 630), "Gear": Rect2(290, 44, 880, 610),
	"Payroll": Rect2(30, 16, 1220, 650), "Mail": Rect2(200, 28, 920, 620), "News": Rect2(230, 40, 920, 610),
	"Forums": Rect2(260, 52, 920, 600), "Archives": Rect2(290, 64, 900, 590), "Recordings": Rect2(120, 24, 1040, 630),
}
const TITLES := {"Cameras": "Cameras - live camp feeds", "Supplier": "Camp Supply - orders", "Gear": "Gear & storage", "Payroll": "Payroll",
	"Mail": "Mail", "News": "News", "Forums": "Forums", "Archives": "Archives", "Recordings": "Recordings - camera bookmarks"}

var windows := {}                    # app -> CampWindow (one window per program)
var booting := false
var boot_t := 0.0
var cursor_pos := Vector2(640, 360)
var _desktop: Control
var _win_layer: Control
var _taskbar_box: HBoxContainer
var _task_buttons := {}
var _start_menu: PanelContainer
var _icons := {}                     # app -> desktop icon Control
var _badges := {}                    # app -> badge Label
var _tray_mail: Label
var _tray_rec: Label
var _cursor: _Pointer
var _boot: Control
var _boot_bar: ColorRect
var _boot_lines: Label
var _selected_icon := ""
var _shop_boxes := {}                # Supplier / Gear -> their VBox
var _focused: CampWindow

## The focused program window's content and status line (older callers).
var _content: Control:
	get:
		return _focused.content if _focused and is_instance_valid(_focused) else _desktop
var _status: Label:
	get:
		return _focused.status if _focused and is_instance_valid(_focused) else null


func _build_shell() -> void:
	_shell = Panel.new()
	_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shell.theme = UITheme.get_theme()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.07)
	_shell.add_theme_stylebox_override("panel", sb)
	vp.add_child(_shell)
	# Desktop: wallpaper, icons and the small live-camera widget.
	_desktop = Control.new()
	_desktop.name = "Desktop"
	_desktop.position = WORKSPACE.position
	_desktop.size = WORKSPACE.size
	_desktop.mouse_filter = Control.MOUSE_FILTER_STOP
	_desktop.gui_input.connect(_desktop_input)
	_shell.add_child(_desktop)
	var wall_paper := _Wallpaper.new()
	wall_paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop.add_child(wall_paper)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(16, 14)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_desktop.add_child(grid)
	for a in APPS:
		grid.add_child(_desktop_icon(a))
	# Desktop widget: the four live feeds (the Phase 11 "edge of attention").
	_inset = TextureRect.new()
	_inset.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inset.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_inset.position = Vector2(WORKSPACE.size.x - 300, 16)
	_inset.size = Vector2(284, 160)
	_inset.mouse_filter = Control.MOUSE_FILTER_STOP
	_inset.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).double_click:
			open_app("Cameras"))
	_desktop.add_child(_inset)
	var cap := UITheme.label("Camp cameras (double-click to open)", 11, UITheme.MUTED)
	cap.position = Vector2(WORKSPACE.size.x - 300, 178)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop.add_child(cap)
	# Windows sit above the desktop, below the taskbar and menus.
	_win_layer = Control.new()
	_win_layer.name = "Windows"
	_win_layer.position = WORKSPACE.position
	_win_layer.size = WORKSPACE.size
	_win_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(_win_layer)
	_build_taskbar()
	_build_start_menu()
	_build_boot()
	_cursor = _Pointer.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.size = Vector2(20, 24)
	_cursor.position = cursor_pos
	_shell.add_child(_cursor)


func _desktop_icon(a: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(86, 78)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(86, 46)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := CampIcon.glyph(a, Color(-1, 0, 0), 44)
	ic.position = Vector2(21, 0)
	ic.size = Vector2(44, 44)
	holder.add_child(ic)
	var badge := UITheme.label("", 11, Color.WHITE)
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color(0.8, 0.2, 0.15)
	bb.set_corner_radius_all(8)
	bb.content_margin_left = 4
	bb.content_margin_right = 4
	badge.add_theme_stylebox_override("normal", bb)
	badge.position = Vector2(56, -4)
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	_badges[a] = badge
	box.add_child(holder)
	var l := UITheme.label(a, 13, UITheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.86, 0.6, 0.3, 0.22)
	sel.border_color = Color(0.86, 0.6, 0.3, 0.6)
	sel.set_border_width_all(1)
	sel.set_corner_radius_all(4)
	box.set_meta("sel", sel)
	box.draw.connect(func() -> void:
		if _selected_icon == a:
			box.draw_style_box(sel, Rect2(Vector2.ZERO, box.size)))
	box.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_select_icon(a)
			if (ev as InputEventMouseButton).double_click:
				open_app(a)
			box.accept_event())
	_icons[a] = box
	return box


func _select_icon(a: String) -> void:
	var old := _selected_icon
	_selected_icon = a
	for k in [old, a]:
		if _icons.has(k):
			(_icons[k] as Control).queue_redraw()


func _desktop_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		_select_icon("")


func _build_taskbar() -> void:
	var bar := PanelContainer.new()
	bar.name = "Taskbar"
	bar.position = Vector2(0, SIZE.y - TASKBAR_H)
	bar.size = Vector2(SIZE.x, TASKBAR_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.065, 0.97)
	sb.border_color = Color(0.3, 0.27, 0.19)
	sb.border_width_top = 1
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", sb)
	_shell.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	bar.add_child(row)
	var start := _bar_button("CampOS", func() -> void:
		_start_menu.visible = not _start_menu.visible)
	start.add_theme_color_override("font_color", UITheme.ACCENT)
	start.name = "Start"
	row.add_child(start)
	_taskbar_box = HBoxContainer.new()
	_taskbar_box.add_theme_constant_override("separation", 4)
	_taskbar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_taskbar_box)
	_tray_rec = UITheme.label("", 13, Color(1.0, 0.45, 0.35))
	_tray_rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tray_rec)
	_tray_mail = UITheme.label("", 13, UITheme.TEXT)
	_tray_mail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tray_mail)
	_clock = UITheme.label("", 13, UITheme.MUTED)
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_clock)
	row.add_child(_bar_button("Stand up", func() -> void:
		if Game.player and Game.player.has_method("stand_from_couch"):
			Game.player.stand_from_couch()))


func _build_start_menu() -> void:
	_start_menu = PanelContainer.new()
	_start_menu.name = "StartMenu"
	_start_menu.visible = false
	var msb := StyleBoxFlat.new()
	msb.bg_color = UITheme.BG_SOLID
	msb.border_color = Color(0.36, 0.31, 0.2)
	msb.set_border_width_all(1)
	msb.set_corner_radius_all(6)
	msb.set_content_margin_all(10)
	_start_menu.add_theme_stylebox_override("panel", msb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_start_menu.add_child(v)
	v.add_child(UITheme.label("CampOS", 16, UITheme.ACCENT))
	v.add_child(UITheme.label("Camp operations workstation", 11, UITheme.MUTED))
	for a in APPS:
		var row := HBoxContainer.new()
		row.add_child(CampIcon.glyph(a, Color(-1, 0, 0), 22))
		var b := Button.new()
		b.text = TITLES.get(a, a)
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(230, 26)
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			_start_menu.visible = false
			open_app(a))
		row.add_child(b)
		v.add_child(row)
	v.add_child(HSeparator.new())
	var off := Button.new()
	off.text = "Turn off the screen"
	off.flat = true
	off.alignment = HORIZONTAL_ALIGNMENT_LEFT
	off.add_theme_font_size_override("font_size", 14)
	off.focus_mode = Control.FOCUS_NONE
	off.pressed.connect(func() -> void:
		_start_menu.visible = false
		set_power(false))
	v.add_child(off)
	_shell.add_child(_start_menu)
	_start_menu.reset_size()
	_start_menu.position = Vector2(4, SIZE.y - TASKBAR_H - _start_menu.size.y - 2)


func _build_boot() -> void:
	_boot = ColorRect.new()
	_boot.name = "Boot"
	(_boot as ColorRect).color = Color(0.02, 0.025, 0.025)
	_boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot.mouse_filter = Control.MOUSE_FILTER_STOP
	_boot.visible = false
	_shell.add_child(_boot)
	var logo := UITheme.label("CampOS", 44, UITheme.ACCENT)
	logo.position = Vector2(SIZE.x * 0.5 - 90, SIZE.y * 0.36)
	_boot.add_child(logo)
	var sub := UITheme.label("Camp operations workstation", 15, UITheme.MUTED)
	sub.position = Vector2(SIZE.x * 0.5 - 110, SIZE.y * 0.36 + 62)
	_boot.add_child(sub)
	var back := ColorRect.new()
	back.color = Color(0.15, 0.15, 0.13)
	back.position = Vector2(SIZE.x * 0.5 - 160, SIZE.y * 0.6)
	back.size = Vector2(320, 6)
	_boot.add_child(back)
	_boot_bar = ColorRect.new()
	_boot_bar.color = UITheme.ACCENT
	_boot_bar.position = back.position
	_boot_bar.size = Vector2(0, 6)
	_boot.add_child(_boot_bar)
	_boot_lines = UITheme.label("", 13, UITheme.MUTED)
	_boot_lines.position = Vector2(SIZE.x * 0.5 - 160, SIZE.y * 0.6 + 16)
	_boot.add_child(_boot_lines)


const BOOT_SECONDS := 3.0
const BOOT_STEPS := ["Checking disk...", "Starting camp network...", "Connecting camp cameras...", "Loading mail and news...", "Ready."]


func start_boot() -> void:
	booting = true
	boot_t = 0.0
	_start_menu.visible = false
	_boot.visible = true
	_tick_boot(0.0)


func _tick_boot(dt: float) -> void:
	if not booting:
		return
	boot_t += dt
	var k := clampf(boot_t / BOOT_SECONDS, 0.0, 1.0)
	_boot_bar.size.x = 320.0 * k
	_boot_lines.text = BOOT_STEPS[mini(int(k * BOOT_STEPS.size()), BOOT_STEPS.size() - 1)]
	if k >= 1.0:
		booting = false
		_boot.visible = false
		if monitor and SoundService.instance() != null:
			SoundService.play("ui.chime", monitor.global_position, {"emit": false})


# ------------------------------------------------------------ windows

## Opens a program (or brings its window back and to the front).
func open_app(a: String) -> void:
	if not APPS.has(a):
		return
	var w: CampWindow = windows.get(a)
	if w == null or not is_instance_valid(w):
		w = CampWindow.make(a, str(TITLES.get(a, a)), CampIcon.COLORS.get(a, Color.GRAY), _place(a), Rect2(Vector2.ZERO, WORKSPACE.size))
		w.close_requested.connect(func(win: CampWindow) -> void: close_app(win.app))
		w.minimize_requested.connect(func(win: CampWindow) -> void: minimize_app(win.app))
		_win_layer.add_child(w)
		windows[a] = w
		_build_app(a, w)
		var tb := _bar_button(a, func() -> void: _task_click(a))
		tb.custom_minimum_size = Vector2(96, 0)
		_taskbar_box.add_child(tb)
		_task_buttons[a] = tb
	w.minimized = false
	w.visible = true
	focus(w)
	app_changed.emit(a)


## Builds (or rebuilds) a program's content inside its window.
func _build_app(a: String, w: CampWindow) -> void:
	for c in w.content.get_children():
		c.queue_free()
	w.status.text = ""
	match a:
		"Cameras":
			_build_cameras(w.content)
		"Supplier", "Gear":
			_build_shop(w.content, a)
		"Mail", "News", "Forums", "Archives":
			FeedReader.build(w.content, a, self)
		"Recordings":
			_build_recordings(w.content)
		"Payroll":
			w.content.add_child(PayrollApp.create(func(t: String) -> void:
				if is_instance_valid(w):
					w.status.text = t))
			w.status.text = "Click a worker for details. Pay changes apply to tonight's settlement; a raise feels good at once, a cut hurts more."


## Rebuilds an open program's content (reading apps after navigation).
func refresh_app(a: String) -> void:
	var w: CampWindow = windows.get(a)
	if w and is_instance_valid(w):
		_build_app(a, w)
	else:
		open_app(a)


func window_content(a: String) -> Control:
	var w: CampWindow = windows.get(a)
	return w.content if w and is_instance_valid(w) else null


func is_open(a: String) -> bool:
	var w: CampWindow = windows.get(a)
	return w != null and is_instance_valid(w) and not w.minimized


func focus(w: CampWindow) -> void:
	if w == null or not is_instance_valid(w):
		return
	_win_layer.move_child(w, -1)
	if _focused and is_instance_valid(_focused) and _focused != w:
		_focused.set_active(false)
	_focused = w
	w.set_active(true)
	app = w.app
	for k in _task_buttons:
		(_task_buttons[k] as Button).modulate = Color(1.25, 1.12, 0.75) if k == app else Color.WHITE


func close_app(a: String) -> void:
	var w: CampWindow = windows.get(a)
	if a == "Recordings" and player:
		player.queue_free()          # no hidden 3D render when not watching
		player = null
	_shop_boxes.erase(a)
	if a == "Cameras":
		_feed = null
	if w and is_instance_valid(w):
		w.queue_free()
	windows.erase(a)
	if _task_buttons.has(a):
		(_task_buttons[a] as Node).queue_free()
		_task_buttons.erase(a)
	if _focused == w:
		_focused = null
		_focus_top()


func minimize_app(a: String) -> void:
	var w: CampWindow = windows.get(a)
	if w == null:
		return
	w.minimized = true
	w.visible = false
	if a == "Recordings" and player and player.playing:
		player.pause()
	if _focused == w:
		w.set_active(false)
		_focused = null
		_focus_top()


func _focus_top() -> void:
	for i in range(_win_layer.get_child_count() - 1, -1, -1):
		var c := _win_layer.get_child(i)
		if c is CampWindow and (c as CampWindow).visible and not c.is_queued_for_deletion():
			focus(c)
			return
	app = ""
	for k in _task_buttons:
		(_task_buttons[k] as Button).modulate = Color.WHITE


func _task_click(a: String) -> void:
	var w: CampWindow = windows.get(a)
	if w and w.visible and w == _focused:
		minimize_app(a)
	else:
		open_app(a)


## A new window opens at its default place, nudged so it never lands
## exactly on top of another open window.
func _place(a: String) -> Rect2:
	var r: Rect2 = DEFAULT_RECTS.get(a, Rect2(200, 40, 800, 560))
	var taken := true
	var n := 0
	while taken and n < 8:
		taken = false
		for k in windows:
			var o: CampWindow = windows[k]
			if is_instance_valid(o) and o.visible and o.position.distance_to(r.position) < 8.0:
				taken = true
		if taken:
			r.position += Vector2(26, 26)
			n += 1
	return r


## Topmost visible window under a desktop point (for click-to-raise).
func window_at(p: Vector2) -> CampWindow:
	for i in range(_win_layer.get_child_count() - 1, -1, -1):
		var c := _win_layer.get_child(i)
		if c is CampWindow and (c as CampWindow).visible and Rect2(c.position + _win_layer.position, c.size).has_point(p):
			return c
	return null


## Compact taskbar / app button.
func _bar_button(text: String, cb: Callable) -> Button:
	var b := UITheme.button(text, cb, 0)
	b.custom_minimum_size = Vector2(0, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := (UITheme.get_theme().get_stylebox(st, "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		b.add_theme_stylebox_override(st, sb)
	return b


## The screen's own mouse pointer (drawn into the desktop image).
class _Pointer extends Control:
	var busy := false
	func _draw() -> void:
		if busy:
			draw_arc(Vector2(10, 10), 7.0, 0.0, TAU * 0.75, 16, Color(0.95, 0.95, 0.9), 2.5)
			return
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 17), Vector2(4.5, 13), Vector2(7.5, 20), Vector2(10, 19), Vector2(7, 12), Vector2(12.5, 12)])
		draw_colored_polygon(pts, Color(0.97, 0.97, 0.94))
		draw_polyline(pts + PackedVector2Array([Vector2(0, 0)]), Color(0.05, 0.05, 0.05), 1.2)


## CampOS wallpaper: dusk sky over layered pine ridges.
class _Wallpaper extends Control:
	func _draw() -> void:
		var h := size.y
		for i in 24:
			var k := float(i) / 23.0
			draw_rect(Rect2(0, h * k, size.x, h / 23.0 + 1.0), Color(0.08, 0.11, 0.13).lerp(Color(0.26, 0.2, 0.17), k))
		draw_circle(Vector2(size.x * 0.72, h * 0.5), 40.0, Color(0.95, 0.72, 0.42, 0.12))
		var layers := [[0.62, Color(0.1, 0.13, 0.12), 34.0], [0.72, Color(0.07, 0.1, 0.09), 46.0], [0.84, Color(0.045, 0.065, 0.06), 62.0]]
		for li in layers.size():
			var base: float = h * float(layers[li][0])
			var col: Color = layers[li][1]
			var tall: float = layers[li][2]
			draw_rect(Rect2(0, base, size.x, h - base), col)
			var x := -20.0 + li * 17.0
			var n := 0
			while x < size.x + 40.0:
				var th := tall * (0.7 + 0.6 * fposmod(sin(x * 0.37 + li * 11.0) * 43758.5, 1.0))
				draw_colored_polygon(PackedVector2Array([Vector2(x - th * 0.32, base + 1), Vector2(x, base - th), Vector2(x + th * 0.32, base + 1)]), col)
				x += th * 0.55 + 6.0
				n += 1
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 170, h - 18), "CampOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.86, 0.6, 0.3, 0.25))


# ------------------------------------------------- Phase 20 recordings

func flag_recording(id: String) -> void:
	flagged[id] = true
	var p := monitor.global_position if monitor else NightAnchors.point("desk")
	if p != Vector3.INF:
		SoundService.play("desk.cam.alert", p, {"priority": 2})


func _clips() -> Array:
	var cl: Array = Game.night_recorder.clips.duplicate() if Game.night_recorder else []
	cl.reverse()            # newest first
	return cl


func _build_recordings(parent: Control) -> void:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(h)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(300, 0)
	h.add_child(list)
	list.add_child(UITheme.label("Recordings (motion and sound bookmarks)", 16))
	var clips := _clips()
	if clips.is_empty():
		var l := UITheme.label("No recordings yet. When a camp camera flags something on a night you slept through, it is kept here.", 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		list.add_child(l)
	for i in clips.size():
		var c: Dictionary = clips[i]
		var txt := "%sNight of day %d  %s  %s (%s)" % ["* " if flagged.has(str(c.id)) else "", int(c.day), str(c.clock), str(c.camera), str(c.bookmark)]
		list.add_child(UITheme.button(txt, func() -> void: _rec_open(i), 290))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_rec_label = UITheme.label("PLAYBACK - pick a recording", 14)
	_rec_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	right.add_child(_rec_label)
	_rec_view = TextureRect.new()
	_rec_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rec_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rec_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sh := ShaderMaterial.new()
	sh.shader = Shader.new()
	sh.shader.code = "shader_type canvas_item;\nuniform float tm = 0.0;\nfloat h(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); float g = dot(c.rgb, vec3(0.3,0.59,0.11)); g = pow(g, 0.8) * 1.5; g += (h(UV * 640.0 + tm) - 0.5) * 0.08; float v = smoothstep(0.85, 0.35, distance(UV, vec2(0.5))); COLOR = vec4(vec3(g * 0.85, g, g * 0.85) * v, 1.0); }"
	_rec_view.material = sh
	right.add_child(_rec_view)
	_rec_seek = HSlider.new()
	_rec_seek.step = 0.1
	_rec_seek.value_changed.connect(func(v: float) -> void:
		if player and absf(v - player.t) > 0.25:
			player.seek(v))
	right.add_child(_rec_seek)
	var row := HBoxContainer.new()
	right.add_child(row)
	row.add_child(UITheme.button("|< Prev", func() -> void: _rec_open(rec_index + 1), 0))
	row.add_child(UITheme.button("Play / Pause", _rec_toggle, 0))
	row.add_child(UITheme.button("Next >|", func() -> void: _rec_open(rec_index - 1), 0))
	row.add_child(UITheme.button("Vol -", func() -> void: _rec_vol(-3.0), 0))
	row.add_child(UITheme.button("Vol +", func() -> void: _rec_vol(3.0), 0))
	_rec_time = UITheme.label("", 14)
	row.add_child(_rec_time)
	if not clips.is_empty():
		_rec_open(0)


func _rec_open(i: int) -> void:
	var clips := _clips()
	if clips.is_empty():
		return
	rec_index = clampi(i, 0, clips.size() - 1)
	var c: Dictionary = clips[rec_index]
	flagged.erase(str(c.id))
	if player == null:
		player = RecordingPlayer.new()
		add_child(player)
	player.speaker = monitor if monitor else null
	player.load_clip(c)
	if _rec_view:
		_rec_view.texture = player.texture()
	if _rec_seek:
		_rec_seek.max_value = player.duration
		_rec_seek.value = 0.0
	if _rec_label:
		_rec_label.text = "PLAYBACK (recorded)  %s %s  -  night of day %d, %s  -  %s" % [str(c.camera), str(c.category).replace("_", " "), int(c.day), str(c.clock), str(c.bookmark)]


func _rec_toggle() -> void:
	if player == null:
		return
	if player.playing:
		player.pause()
	else:
		player.play()


func _rec_vol(d: float) -> void:
	var i := AudioServer.get_bus_index("Relay")
	if i >= 0:
		AudioServer.set_bus_volume_db(i, clampf(AudioServer.get_bus_volume_db(i) + d, -40.0, 6.0))


func _rec_tick() -> void:
	if player == null or not is_open("Recordings"):
		return
	if _rec_seek and absf(_rec_seek.value - player.t) > 0.05:
		_rec_seek.set_value_no_signal(player.t)
	if _rec_time:
		var c := player.clip
		var hour := float(c.get("hour", 0.0)) + player.t / 3600.0
		_rec_time.text = "%s:%02d  (%.1f / %.1f s)" % [NightAnchors.hhmm(hour), int(fposmod(player.t, 60.0)), player.t, player.duration]
	if _rec_view and _rec_view.material:
		(_rec_view.material as ShaderMaterial).set_shader_parameter("tm", Time.get_ticks_msec() * 0.001)


func _build_cameras(parent: Control) -> void:
	var wall: CameraWall = Game.tv
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(v)
	_feed = TextureRect.new()
	_feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_feed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed.texture = wall.composite.get_texture() if wall and wall.composite else null
	_feed.gui_input.connect(_feed_input)
	v.add_child(_feed)
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(UITheme.button("Wall (4)", _wall_back, 0))
	row.add_child(UITheme.button("< Prev", func() -> void: _step(-1), 0))
	row.add_child(UITheme.button("Next >", func() -> void: _step(1), 0))
	row.add_child(UITheme.button("Swap speed", func() -> void: _cycle_interval(), 0))
	row.add_child(UITheme.button("Mics on/off", _toggle_mics, 0))
	row.add_child(UITheme.button("Vol -", func() -> void: _vol(-0.1), 0))
	row.add_child(UITheme.button("Vol +", func() -> void: _vol(0.1), 0))
	row.add_child(UITheme.button("Feeds on/off", _toggle_feeds, 0))


func _wall_back() -> void:
	if Game.tv:
		Game.tv.back_to_quad()


func _toggle_mics() -> void:
	if Game.tv:
		Game.tv.set_mic_muted(not Game.tv.mic_muted)


func _vol(d: float) -> void:
	if Game.tv:
		Game.tv.set_volume(Game.tv.tv_volume + d)


func _toggle_feeds() -> void:
	if Game.tv:
		Game.tv.set_power(not Game.tv.powered)
		_inset.visible = Game.tv.powered


func _step(d: int) -> void:
	var wall: CameraWall = Game.tv
	if wall == null:
		return
	if wall.mode != "focus":
		wall.focus_index = wall.tiles[0]
		wall.set_mode("focus")
	wall.focus_step(d)


func _cycle_interval() -> void:
	var wall: CameraWall = Game.tv
	if wall == null:
		return
	var steps := [0.0, 5.0, 10.0, 20.0, 40.0]
	var i := maxi(steps.find(wall.interval), 1)
	i = (i + 1) % steps.size()
	wall.set_interval(steps[i])
	Settings.set_v("tv_interval", steps[i])


## Click on the feed: in the wall, the tile actually shown under the cursor
## right now becomes the focus (labels, texture and mic follow together);
## right-click in focus returns to the wall.
func _feed_input(ev: InputEvent) -> void:
	var wall: CameraWall = Game.tv
	if wall == null or not (ev is InputEventMouseButton) or not (ev as InputEventMouseButton).pressed:
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and wall.mode == "focus":
		wall.back_to_quad()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT or wall.mode != "quad":
		return
	var t := tile_at(mb.position, _feed.size)
	if t >= 0:
		clicks += 1
		wall.focus_tile(t)


## Which quad tile is under a point of a feed rect of `rect_size` (the 16:9
## composite is letterboxed to keep its aspect).
static func tile_at(pos: Vector2, rect_size: Vector2) -> int:
	var ar := 16.0 / 9.0
	var w := minf(rect_size.x, rect_size.y * ar)
	var h := w / ar
	var o := (rect_size - Vector2(w, h)) * 0.5
	var u := (pos - o) / Vector2(w, h)
	if u.x < 0.0 or u.y < 0.0 or u.x > 1.0 or u.y > 1.0:
		return -1
	return (1 if u.x >= 0.5 else 0) + (2 if u.y >= 0.5 else 0)


func _build_shop(parent: Control, a: String) -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	_shop_boxes[a] = box
	_refresh_shop(a)


## Rebuilds the Supplier and/or Gear window ("" = every open one).
func _refresh_shop(a := "") -> void:
	for k in (_shop_boxes.keys() if a == "" else [a]):
		var box: VBoxContainer = _shop_boxes.get(k)
		if box == null or not is_instance_valid(box):
			continue
		for c in box.get_children():
			c.queue_free()
		var w: CampWindow = windows.get(k)
		var st := func(t: String) -> void:
			if w and is_instance_valid(w):
				w.status.text = t
		var again := func() -> void: _refresh_shop(str(k))
		match str(k):
			"Supplier":
				GearPanel.build_supplier(box, cart, _req, st, again)
			"Gear":
				GearPanel.build_gear(box, st, again)


# ------------------------------------------------------------ seat + glance

func sit(on: bool) -> void:
	seated = on
	glancing = false
	_update_overlay()
	if on:
		_refresh_shop()
		for a in ["Mail", "News", "Forums", "Archives"]:
			if windows.has(a):
				refresh_app(a)


func set_glance(g: bool) -> void:
	glancing = g
	_update_overlay()


func _update_overlay() -> void:
	if overlay == null:
		return
	var show := seated and not glancing and powered
	overlay.visible = show
	if seated:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED


func set_power(on: bool) -> void:
	if on and not powered and _boot:
		start_boot()               # switching the screen on boots CampOS
	powered = on
	if mat:
		mat.set_shader_parameter("powered", 1.0 if on else 0.0)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if Game.tv:
		Game.tv.set_power(on)
	_update_overlay()


var _unread_t := 0.0


func _process(_delta: float) -> void:
	if monitor == null:
		return
	_tick_boot(_delta)
	if _cursor:
		_cursor.visible = powered
		if _cursor.busy != booting:
			_cursor.busy = booting
			_cursor.queue_redraw()
	_rec_tick()
	# Seated: the real mouse is free; over the screen it is hidden and the
	# screen's own pointer takes over (view.mouse_entered / exited).
	if seated and not glancing and powered and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cs: CampaignService = Game.campaign
	if _clock and cs and cs.active:
		_clock.text = "Day %d · %s" % [cs.clock.day, NightAnchors.hhmm(cs.clock.lighting_hour())]
	# Unread counts as icon badges and in the tray (twice a second).
	_unread_t -= _delta
	if _unread_t <= 0.0:
		_unread_t = 0.5
		var mail := 0
		for a2 in ["Mail", "News", "Forums", "Archives"]:
			var n: int = Game.feed.unread(a2) if Game.feed else 0
			if a2 == "Mail":
				mail = n
			_badge(a2, n)
		_badge("Recordings", flagged.size())
		var asks := 0
		if cs and cs.pay:
			for e in cs.payroll.employees:
				if not cs.pay.pending_request(str(e.id)).is_empty():
					asks += 1
		_badge("Payroll", asks)
		if _tray_mail:
			_tray_mail.text = ("Mail %d" % mail) if mail > 0 else ""
		if _tray_rec:
			_tray_rec.text = ("REC %d" % flagged.size()) if not flagged.is_empty() else ""
	var wall: CameraWall = Game.tv
	if _inset and wall:
		# The desktop camera widget shows the same four-feed composite.
		if _inset.texture == null and wall.composite:
			_inset.texture = wall.composite.get_texture()
		_inset.visible = wall.powered
	var wc: CampWindow = windows.get("Cameras")
	if wc and is_instance_valid(wc) and wall:
		wc.status.text = ("Focus: %s %s · LIVE · right-click or Wall (4) to go back" % [wall.cam_id(wall.focus_index), wall.cam_name(wall.focus_index)]) if wall.mode == "focus" else "Wall: four live cameras, one swaps every %s · click a feed to focus it%s" % ["(frozen)" if wall.interval <= 0.0 else "%d s" % int(wall.interval), " · mics muted" if wall.mic_muted else ""]
	var wr: CampWindow = windows.get("Recordings")
	if wr and is_instance_valid(wr):
		wr.status.text = "Saved camera bookmarks from nights you slept through · PLAYBACK, not live · %d saved" % (Game.night_recorder.clips.size() if Game.night_recorder else 0)


func _badge(a: String, n: int) -> void:
	var b: Label = _badges.get(a)
	if b == null:
		return
	b.visible = n > 0
	b.text = str(n) if n < 100 else "99+"


## Saved: which programs are open, where, and which one is in front.
func capture() -> Dictionary:
	var ws := []
	for i in _win_layer.get_child_count():
		var c := _win_layer.get_child(i)
		if c is CampWindow and not c.is_queued_for_deletion():
			ws.append((c as CampWindow).capture())
	return {"app": app, "windows": ws, "powered": powered, "flagged": flagged.keys()}


func restore(d: Dictionary) -> void:
	flagged.clear()
	for k in d.get("flagged", []):
		flagged[str(k)] = true
	for a in windows.keys():
		close_app(str(a))
	var ws: Array = d.get("windows", [])
	if ws.is_empty():
		# Before Phase 22 one app filled the screen: open just that one.
		var a := str(d.get("app", "Cameras"))
		if a == "Shop":
			a = "Supplier"          # Phase 11-13 saves
		open_app(a if APPS.has(a) else "Cameras")
	else:
		for wd in ws:
			var a2 := str((wd as Dictionary).get("app", ""))
			if not APPS.has(a2):
				continue
			open_app(a2)
			var w: CampWindow = windows[a2]
			var r: Array = wd.get("rect", [])
			if r.size() == 4:
				w.position = Vector2(r[0], r[1])
				w.size = Vector2(r[2], r[3])
				w._clamp()
			if bool(wd.get("max", false)):
				w.toggle_maximize()
			if bool(wd.get("min", false)):
				minimize_app(a2)
		if windows.has(str(d.get("app", ""))) and not (windows[str(d.app)] as CampWindow).minimized:
			focus(windows[str(d.app)])
	if bool(d.get("powered", true)) != powered:
		set_power(bool(d.get("powered", true)))
		booting = false               # a loaded game is not a fresh switch-on
		if _boot:
			_boot.visible = false
