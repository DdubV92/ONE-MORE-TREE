class_name UITheme
extends RefCounted
## Shared look for menus and overlays: warm timber accents on a dark forest
## panel, readable sizes, generous hit areas.

const BG := Color(0.07, 0.09, 0.08, 0.86)
const BG_SOLID := Color(0.07, 0.09, 0.08, 0.97)
const ACCENT := Color(0.86, 0.6, 0.3)
const TEXT := Color(0.94, 0.92, 0.86)
const MUTED := Color(0.7, 0.72, 0.66)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	var panel := _box(BG, 10, Color(0.3, 0.26, 0.18, 0.9))
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var normal := _box(Color(0.16, 0.18, 0.15, 0.95), 6, Color(0.32, 0.3, 0.22))
	var hover := _box(Color(0.26, 0.24, 0.17, 0.98), 6, ACCENT)
	var pressed := _box(Color(0.4, 0.3, 0.16, 1.0), 6, ACCENT)
	var disabled := _box(Color(0.12, 0.12, 0.12, 0.8), 6, Color(0.2, 0.2, 0.2))
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), 6, ACCENT))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 0.95, 0.85))
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	var grab := _box(ACCENT, 8, ACCENT)
	t.set_stylebox("grabber_area", "HSlider", _box(Color(0.5, 0.36, 0.2), 4, Color(0, 0, 0, 0)))
	t.set_stylebox("slider", "HSlider", _box(Color(0.2, 0.2, 0.18), 4, Color(0, 0, 0, 0)))
	t.set_icon("grabber", "HSlider", _dot(14, ACCENT))
	t.set_icon("grabber_highlight", "HSlider", _dot(16, Color(1, 0.8, 0.5)))
	_theme = t
	return t


static func _box(c: Color, radius: int, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func _dot(size: int, c: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(c, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, min_w := 260) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 42)
	b.pressed.connect(cb)
	return b
