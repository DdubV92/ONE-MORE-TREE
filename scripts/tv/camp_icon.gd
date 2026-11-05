class_name CampIcon
extends Control
## Phase 22: CampOS program icons, drawn as simple vector shapes on a
## rounded coloured tile (no image files): camera, crate, hard hat, dollar,
## envelope, newspaper, speech bubbles, folder, record dot.

const COLORS := {
	"Cameras": Color(0.25, 0.45, 0.6), "Supplier": Color(0.62, 0.42, 0.2), "Gear": Color(0.7, 0.55, 0.15),
	"Payroll": Color(0.25, 0.55, 0.32), "Mail": Color(0.35, 0.4, 0.62), "News": Color(0.45, 0.45, 0.45),
	"Forums": Color(0.5, 0.35, 0.58), "Archives": Color(0.48, 0.38, 0.26), "Recordings": Color(0.62, 0.2, 0.2),
}

var app := ""
var tile := Color.GRAY


static func glyph(app_name: String, color := Color(-1, 0, 0), px := 40) -> CampIcon:
	var c := CampIcon.new()
	c.app = app_name
	c.tile = color if color.r >= 0.0 else COLORS.get(app_name, Color(0.4, 0.4, 0.4))
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var r := Rect2(o, Vector2(s, s))
	var box := StyleBoxFlat.new()
	box.bg_color = tile
	box.set_corner_radius_all(int(s * 0.2))
	box.border_color = tile.lightened(0.3)
	box.set_border_width_all(1)
	draw_style_box(box, r)
	var w := Color(0.96, 0.94, 0.88)
	var d := Color(0.1, 0.1, 0.1, 0.85)
	var u := s / 10.0          # one unit of the 10 x 10 icon grid
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x * u, y * u)
	var lw := maxf(1.0, s / 22.0)
	match app:
		"Cameras":
			draw_rect(Rect2(p.call(2, 3.5), Vector2(5 * u, 3.4 * u)), w)
			draw_colored_polygon(PackedVector2Array([p.call(7, 4.4), p.call(8.6, 3.6), p.call(8.6, 7.2), p.call(7, 6.4)]), w)
			draw_circle(p.call(4.5, 5.2), 1.0 * u, d)
		"Supplier":
			draw_rect(Rect2(p.call(2.2, 3.4), Vector2(5.6 * u, 4.6 * u)), w)
			draw_line(p.call(2.2, 4.8), p.call(7.8, 4.8), d, lw)
			draw_line(p.call(5, 3.4), p.call(5, 8), d, lw)
		"Gear":
			draw_colored_polygon(PackedVector2Array([p.call(2.2, 6.6), p.call(2.8, 4.4), p.call(4.2, 3.1), p.call(5.8, 3.1), p.call(7.2, 4.4), p.call(7.8, 6.6)]), w)
			draw_rect(Rect2(p.call(1.6, 6.5), Vector2(6.8 * u, 0.9 * u)), w)
			draw_line(p.call(5, 3.2), p.call(5, 6.4), d, lw)
		"Payroll":
			draw_circle(p.call(5, 5), 3.2 * u, w)
			var f := ThemeDB.fallback_font
			draw_string(f, p.call(3.6, 6.7), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(4.6 * u), tile.darkened(0.3))
		"Mail":
			draw_rect(Rect2(p.call(1.8, 3), Vector2(6.4 * u, 4.4 * u)), w)
			draw_polyline(PackedVector2Array([p.call(1.8, 3), p.call(5, 5.6), p.call(8.2, 3)]), d, lw)
		"News":
			draw_rect(Rect2(p.call(2, 2.2), Vector2(6 * u, 5.8 * u)), w)
			draw_rect(Rect2(p.call(2.8, 3), Vector2(4.4 * u, 1.2 * u)), d)
			for k in 3:
				draw_line(p.call(2.8, 5 + k * 0.9), p.call(7.2, 5 + k * 0.9), d, lw)
		"Forums":
			draw_rect(Rect2(p.call(1.6, 2.2), Vector2(4.6 * u, 3.2 * u)), w)
			draw_colored_polygon(PackedVector2Array([p.call(2.4, 5.3), p.call(3.6, 5.3), p.call(2.2, 6.6)]), w)
			draw_rect(Rect2(p.call(4.2, 4.6), Vector2(4.2 * u, 2.9 * u)), w.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([p.call(7.4, 7.4), p.call(6.4, 7.4), p.call(7.8, 8.6)]), w.darkened(0.15))
		"Archives":
			draw_colored_polygon(PackedVector2Array([p.call(1.8, 3), p.call(4.2, 3), p.call(4.8, 3.8), p.call(8.2, 3.8), p.call(8.2, 7.6), p.call(1.8, 7.6)]), w)
			draw_line(p.call(1.8, 4.6), p.call(8.2, 4.6), d, lw)
		"Recordings":
			draw_rect(Rect2(p.call(1.8, 3), Vector2(6.4 * u, 4.4 * u)), w)
			draw_circle(p.call(5, 5.2), 1.3 * u, Color(0.85, 0.12, 0.1))
		_:
			draw_circle(p.call(5, 5), 2.5 * u, w)
