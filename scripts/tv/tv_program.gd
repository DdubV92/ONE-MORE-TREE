class_name TVProgram
extends Control
## The entertainment channel: an original procedural cartoon loop
## ("Timber Tales") drawn in code, with a short synthesized music bed that
## CameraWall plays from the TV speaker. No streams, no recordings.

var playing := false:
	set(v):
		playing = v
		set_process(v)
var t := 0.0
const TICKER := "TIMBER TALES  ·  Tonight: Bert the Beaver builds a better dam  ·  Weather: mild, a little wind off the water  ·  Remember: one tree at a time  ·  Stay in after dark  ·  "


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var day := 0.5 + 0.5 * sin(t * 0.21)
	draw_rect(Rect2(0, 0, w, h), Color(0.38, 0.62, 0.86).lerp(Color(0.95, 0.62, 0.42), 1.0 - day))
	var sun := Vector2(w * (0.15 + 0.7 * fposmod(t * 0.02, 1.0)), h * (0.52 - 0.32 * sin(fposmod(t * 0.02, 1.0) * PI)))
	draw_circle(sun, 34.0, Color(1.0, 0.92, 0.55))
	for k in 3:
		var cx := fposmod(t * (8.0 + k * 5.0) + k * 300.0, w + 200.0) - 100.0
		for b in 3:
			draw_circle(Vector2(cx + b * 26.0, 70.0 + k * 28.0 + (6.0 if b == 1 else 0.0)), 20.0 - absf(b - 1) * 5.0, Color(1, 1, 1, 0.85))
	_hills(h * 0.62, 40.0, 0.006, t * 3.0, Color(0.32, 0.52, 0.34))
	_hills(h * 0.72, 30.0, 0.011, t * 7.0, Color(0.22, 0.42, 0.24))
	# Swaying pines
	for i in 9:
		var x := fposmod(i * 131.0 - t * 18.0, w + 120.0) - 60.0
		var base := h * 0.80
		var sway := sin(t * 1.7 + i) * 6.0
		draw_rect(Rect2(x - 5, base - 20, 10, 24), Color(0.36, 0.24, 0.14))
		for tier in 3:
			var ty := base - 20 - tier * 26.0
			var half := 34.0 - tier * 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - half, ty), Vector2(x + half, ty), Vector2(x + sway * (tier + 1) * 0.4, ty - 44.0)]), Color(0.12, 0.34, 0.18))
	draw_rect(Rect2(0, h * 0.82, w, h * 0.18), Color(0.42, 0.32, 0.2))
	_beaver(Vector2(w * 0.5 + sin(t * 0.5) * w * 0.25, h * 0.82))
	# Title card + ticker
	var font := get_theme_default_font()
	var title_a := clampf(1.0 - absf(fposmod(t, 24.0) - 2.5) / 2.5, 0.0, 1.0)
	if title_a > 0.0:
		draw_string(font, Vector2(w * 0.5 - 190, h * 0.3), "TIMBER TALES", HORIZONTAL_ALIGNMENT_LEFT, -1, 58, Color(1, 0.96, 0.85, title_a))
	draw_rect(Rect2(0, h - 34, w, 34), Color(0.08, 0.06, 0.05, 0.9))
	var tw := font.get_string_size(TICKER, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var off := fposmod(t * 70.0, tw)
	for k in 3:
		draw_string(font, Vector2(-off + k * tw, h - 10), TICKER, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.88, 0.5))
	draw_string(font, Vector2(14, 26), "CH 3  ·  ENTERTAINMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))


func _hills(y: float, amp: float, freq: float, scroll: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, size.y))
	var x := 0.0
	while x <= size.x + 20.0:
		pts.append(Vector2(x, y - amp * (0.5 + 0.5 * sin((x + scroll) * freq)) - amp * 0.4 * sin((x + scroll) * freq * 2.7)))
		x += 20.0
	pts.append(Vector2(size.x, size.y))
	draw_colored_polygon(pts, col)


func _beaver(p: Vector2) -> void:
	var bob := absf(sin(t * 6.0)) * 4.0
	var face := 1.0 if cos(t * 0.5) > 0.0 else -1.0
	var body := Color(0.48, 0.3, 0.16)
	draw_colored_polygon(_ellipse(p + Vector2(-face * 34, -10), Vector2(22, 9)), Color(0.3, 0.2, 0.12))  # tail
	draw_colored_polygon(_ellipse(p + Vector2(0, -28 - bob), Vector2(30, 24)), body)
	draw_circle(p + Vector2(face * 26, -48 - bob), 16.0, body)
	draw_circle(p + Vector2(face * 32, -53 - bob), 3.2, Color.BLACK)
	draw_rect(Rect2(p.x + face * 38 - 3, p.y - 42 - bob, 6, 7), Color.WHITE)
	# Log being carried
	draw_rect(Rect2(p.x - 40, p.y - 66 - bob, 80, 14), Color(0.55, 0.38, 0.2))
	draw_circle(p + Vector2(40, -59 - bob), 7.0, Color(0.85, 0.7, 0.45))


func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out


## A 16-second original synthesized jingle (bass + plucked melody), rendered
## once to a looping WAV.
static func make_music() -> AudioStreamWAV:
	const RATE := 22050
	const BPM := 120.0
	var beat := 60.0 / BPM
	var melody := [0, 4, 7, 9, 7, 4, 2, 4, 0, 4, 7, 12, 9, 7, 4, 2, 5, 9, 12, 9, 7, 4, 2, 0, 4, 7, 9, 7, 4, 2, 0, -1]
	var bass := [0, 0, 5, 5, 7, 7, 0, 0]
	var n := int(RATE * beat * 32)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var ts := float(i) / RATE
		var b := int(ts / beat)
		var in_beat := ts - b * beat
		var s := 0.0
		var m: int = melody[b % melody.size()]
		if m >= 0:
			var f := 392.0 * pow(2.0, m / 12.0)
			s += 0.22 * sin(TAU * f * ts) * exp(-in_beat * 5.0) + 0.06 * sin(TAU * f * 2.0 * ts) * exp(-in_beat * 9.0)
		var bi := int(ts / (beat * 4.0))
		var bf := 98.0 * pow(2.0, float(bass[bi % bass.size()]) / 12.0)
		var bin := ts - bi * beat * 4.0
		s += 0.18 * signf(sin(TAU * bf * ts)) * 0.35 * exp(-fposmod(bin, beat) * 3.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
