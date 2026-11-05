class_name CampWindow
extends Panel
## Phase 22: one program window on the CampOS desktop (owner request: "run
## like a real OS"). A title bar with the program's icon and name that
## drags the window, minimize / maximize / close buttons, the program's
## content area, a status line and a resize grip in the bottom-right
## corner. The desktop (DeskComputer) owns z-order and focus: clicking
## anywhere on a window raises it before the click is delivered.

signal close_requested(w: CampWindow)
signal minimize_requested(w: CampWindow)

const TITLE_H := 30.0
const STATUS_H := 22.0
const MIN_SIZE := Vector2(380, 240)
const ACTIVE_TITLE := Color(0.22, 0.17, 0.1)
const IDLE_TITLE := Color(0.12, 0.13, 0.12)

var app := ""
var content: Control
var status: Label
var title_label: Label
var maximized := false
var minimized := false
var active := false
var workspace := Rect2(0, 0, 1280, 682)     # where windows may live
var _restore := Rect2()
var _title: Panel
var _title_box: StyleBoxFlat
var _body_box: StyleBoxFlat
var _dragging := false
var _resizing := false


static func make(app_name: String, title: String, color: Color, rect: Rect2, ws: Rect2) -> CampWindow:
	var w := CampWindow.new()
	w.app = app_name
	w.workspace = ws
	w.name = "Window_" + app_name
	w._build(title, color)
	w.position = rect.position
	w.size = rect.size
	w._clamp()
	return w


func _build(title: String, color: Color) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_body_box = StyleBoxFlat.new()
	_body_box.bg_color = Color(0.075, 0.085, 0.08, 0.985)
	_body_box.border_color = Color(0.32, 0.29, 0.2)
	_body_box.set_border_width_all(1)
	_body_box.set_corner_radius_all(6)
	_body_box.shadow_color = Color(0, 0, 0, 0.45)
	_body_box.shadow_size = 10
	_body_box.shadow_offset = Vector2(2, 4)
	add_theme_stylebox_override("panel", _body_box)
	# Title bar: drag to move, double-click to maximize.
	_title = Panel.new()
	_title.name = "TitleBar"
	_title.anchor_right = 1.0
	_title.offset_bottom = TITLE_H
	_title_box = StyleBoxFlat.new()
	_title_box.bg_color = IDLE_TITLE
	_title_box.corner_radius_top_left = 6
	_title_box.corner_radius_top_right = 6
	_title.add_theme_stylebox_override("panel", _title_box)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.gui_input.connect(_title_input)
	add_child(_title)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -4
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(row)
	var icon := CampIcon.glyph(app, color, 18)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	title_label = UITheme.label(title, 14, UITheme.TEXT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title_label)
	row.add_child(_caption_button("_", "Minimize", func() -> void: minimize_requested.emit(self)))
	row.add_child(_caption_button("[ ]", "Maximize", toggle_maximize))
	var x := _caption_button("X", "Close", func() -> void: close_requested.emit(self))
	x.add_theme_color_override("font_hover_color", Color(1, 0.55, 0.5))
	row.add_child(x)
	content = Control.new()
	content.name = "Content"
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.offset_left = 8
	content.offset_top = TITLE_H + 6
	content.offset_right = -8
	content.offset_bottom = -STATUS_H - 2
	content.clip_contents = true
	add_child(content)
	status = UITheme.label("", 12, UITheme.MUTED)
	status.anchor_top = 1.0
	status.anchor_right = 1.0
	status.anchor_bottom = 1.0
	status.offset_left = 10
	status.offset_top = -STATUS_H
	status.offset_right = -24
	status.clip_text = true
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	var grip := _Grip.new()
	grip.anchor_left = 1.0
	grip.anchor_top = 1.0
	grip.anchor_right = 1.0
	grip.anchor_bottom = 1.0
	grip.offset_left = -16
	grip.offset_top = -16
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.gui_input.connect(_grip_input)
	add_child(grip)


func _caption_button(t: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(30, 24)
	b.add_theme_font_size_override("font_size", 13)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


func set_active(on: bool) -> void:
	active = on
	_title_box.bg_color = ACTIVE_TITLE if on else IDLE_TITLE
	_body_box.border_color = UITheme.ACCENT if on else Color(0.32, 0.29, 0.2)
	title_label.add_theme_color_override("font_color", UITheme.TEXT if on else UITheme.MUTED)


func toggle_maximize() -> void:
	if maximized:
		maximized = false
		position = _restore.position
		size = _restore.size
	else:
		_restore = Rect2(position, size)
		maximized = true
		position = workspace.position
		size = workspace.size
	_clamp()


func _title_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.double_click:
			toggle_maximize()
			_dragging = false
		else:
			_dragging = mb.pressed and not maximized
		_title.accept_event()
	elif ev is InputEventMouseMotion and _dragging:
		position += (ev as InputEventMouseMotion).relative
		_clamp()
		_title.accept_event()


func _grip_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_resizing = (ev as InputEventMouseButton).pressed and not maximized
	elif ev is InputEventMouseMotion and _resizing:
		size = (size + (ev as InputEventMouseMotion).relative).max(MIN_SIZE)
		_clamp()


## Keep the title bar reachable and the window no larger than the desktop.
func _clamp() -> void:
	size = size.min(workspace.size).max(MIN_SIZE.min(workspace.size))
	position.x = clampf(position.x, workspace.position.x - size.x + 120.0, workspace.end.x - 120.0)
	position.y = clampf(position.y, workspace.position.y, workspace.end.y - TITLE_H)


func capture() -> Dictionary:
	var r := _restore if maximized else Rect2(position, size)
	return {"app": app, "rect": [r.position.x, r.position.y, r.size.x, r.size.y], "max": maximized, "min": minimized}


class _Grip extends Control:
	func _draw() -> void:
		for k in 3:
			var o := 4.0 + k * 4.0
			draw_line(Vector2(size.x - 2, o), Vector2(o, size.y - 2), Color(0.6, 0.55, 0.42, 0.8), 1.0)
