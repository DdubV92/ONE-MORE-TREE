class_name FlapjackFlip
extends ArcadeGame
## FLAPJACK FLIP (original). Three griddles (keys 1/2/3 or J/K/L). Batter
## cooks from pale to GOLDEN to burnt. Flip each pancake while it is golden
## (the ring fills); the second side cooks and it is served automatically.
## Flip too early = raw, too late = burnt: both are strikes. Three strikes
## and the camp cook quits. It gets faster as you go.

const PANS := 3

var pans: Array[Dictionary] = []
var strikes := 0
var speed := 1.0
var pops: Array[Dictionary] = []


func _init() -> void:
	title = "Flapjack Flip"
	help_lines = PackedStringArray([
		"Three griddles. Press 1, 2 or 3 (or J K L) to flip.",
		"Flip while the pancake is GOLDEN (ring full and",
		"green). Too early is raw, too late is burnt:",
		"both are strikes. Three strikes and you're out.",
		"Perfect timing in the middle of golden = 2 points.",
		"The second side cooks itself, then it's served.",
	])


func _reset() -> void:
	pans.clear()
	strikes = 0
	speed = 1.0
	pops.clear()
	for i in PANS:
		pans.append(_fresh(rng.randf_range(0.0, 1.6)))


func _fresh(delay: float) -> Dictionary:
	return {"phase": "wait", "cook": 0.0, "delay": delay, "air": 0.0, "side": 1, "rate": rng.randf_range(0.18, 0.26)}


## Cook 0..1: pale < 0.55, golden 0.55..0.8, burnt > 1.0 (0.8..1.0 = dark).
func _tick(delta: float) -> void:
	speed = 1.0 + score * 0.035
	for i in PANS:
		var p := pans[i]
		match str(p.phase):
			"wait":
				p.delay = float(p.delay) - delta
				if float(p.delay) <= 0.0:
					p.phase = "cook"
					p.cook = 0.0
			"cook":
				p.cook = float(p.cook) + float(p.rate) * speed * delta
				if float(p.cook) > 1.0:
					_strike(i, "BURNT!")
			"air":
				p.air = float(p.air) + delta
				if float(p.air) > 0.6:
					p.phase = "second"
					p.cook = 0.0
			"second":
				p.cook = float(p.cook) + 0.9 * delta
				if float(p.cook) >= 1.0:
					p.phase = "served"
					p.air = 0.0
			"served":
				p.air = float(p.air) + delta
				if float(p.air) > 0.5:
					pans[i] = _fresh(rng.randf_range(0.2, 1.2) / speed)
	for pp in pops:
		pp.t = float(pp.t) + delta
	pops = pops.filter(func(pp: Dictionary) -> bool: return float(pp.t) < 1.0)


func _strike(i: int, why: String) -> void:
	strikes += 1
	beep(150.0, 0.25)
	pops.append({"x": _pan_x(i), "text": why, "t": 0.0, "col": Color(1, 0.35, 0.3)})
	pans[i] = _fresh(rng.randf_range(0.6, 1.4))
	if strikes >= 3:
		game_over()


func _press(k: int) -> void:
	var idx := -1
	match k:
		KEY_1, KEY_KP_1, KEY_J: idx = 0
		KEY_2, KEY_KP_2, KEY_K: idx = 1
		KEY_3, KEY_KP_3, KEY_L: idx = 2
	if idx < 0:
		return
	var p := pans[idx]
	if str(p.phase) != "cook":
		return
	var c := float(p.cook)
	if c < 0.55:
		_strike(idx, "RAW!")
		return
	if c > 0.8:
		_strike(idx, "TOO DARK!")
		return
	var perfect := absf(c - 0.675) < 0.05
	score += 2 if perfect else 1
	beep(1040.0 if perfect else 700.0, 0.09)
	pops.append({"x": _pan_x(idx), "text": "PERFECT!" if perfect else "FLIP!", "t": 0.0, "col": Color(1, 0.9, 0.4)})
	p.phase = "air"
	p.air = 0.0


func _pan_x(i: int) -> float:
	return size.x * (0.2 + 0.3 * i)


func _cake_color(c: float) -> Color:
	if c < 0.55:
		return Color(0.98, 0.92, 0.7).lerp(Color(0.95, 0.75, 0.38), c / 0.55)
	if c < 0.8:
		return Color(0.95, 0.75, 0.38).lerp(Color(0.8, 0.5, 0.2), (c - 0.55) / 0.25)
	return Color(0.8, 0.5, 0.2).lerp(Color(0.15, 0.08, 0.04), clampf((c - 0.8) / 0.2, 0.0, 1.0))


func _paint() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.26, 0.17, 0.12))
	for i in 8:
		draw_rect(Rect2(i * size.x / 8.0, 0, size.x / 16.0, size.y * 0.55), Color(0.3, 0.2, 0.14))
	draw_rect(Rect2(0, size.y * 0.62, size.x, size.y * 0.38), Color(0.18, 0.18, 0.2))
	var font := get_theme_default_font()
	for i in PANS:
		var x := _pan_x(i)
		var y := size.y * 0.68
		draw_circle(Vector2(x, y + 6), 82.0, Color(0.05, 0.05, 0.06))
		draw_circle(Vector2(x, y), 78.0, Color(0.12, 0.12, 0.14))
		draw_rect(Rect2(x + 70, y - 8, 70, 16), Color(0.1, 0.07, 0.05))
		draw_string(font, Vector2(x - 8, y + 118), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.7))
		if state != "play":
			continue
		var p := pans[i]
		var ph := str(p.phase)
		if ph == "cook" or ph == "second":
			var c := float(p.cook) if ph == "cook" else 0.7
			var r := 52.0 + (6.0 * sin(t * 3.0 + i) if ph == "cook" else 0.0) * 0.2
			draw_circle(Vector2(x, y), r, _cake_color(c))
			for b in 5:
				var a := float(b) * 1.3 + i
				draw_circle(Vector2(x + cos(a) * 24, y + sin(a) * 18), 3.0, _cake_color(c).darkened(0.15))
			if ph == "cook":
				var golden := c >= 0.55 and c <= 0.8
				var col := Color(0.4, 1.0, 0.4) if golden else (Color(1, 0.4, 0.3) if c > 0.8 else Color(0.9, 0.9, 0.9))
				draw_arc(Vector2(x, y - 120), 22.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(c, 0.0, 1.0), 24, col, 6.0)
				if c > 0.85:
					for s in 3:
						draw_circle(Vector2(x - 20 + s * 20, y - 60 - fposmod(t * 40 + s * 17, 50)), 6.0, Color(0.3, 0.3, 0.3, 0.5))
		elif ph == "air":
			var u := float(p.air) / 0.6
			var hy := y - sin(u * PI) * 140.0
			var squash := absf(cos(u * PI * 2.0))
			draw_set_transform(Vector2(x, hy), 0.0, Vector2(1.0, maxf(squash, 0.15)))
			draw_circle(Vector2.ZERO, 52.0, Color(0.95, 0.75, 0.38))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif ph == "served":
			var u2 := float(p.air) / 0.5
			draw_circle(Vector2(x + u2 * 300.0, y - u2 * 60.0), 52.0 * (1.0 - u2 * 0.5), Color(0.9, 0.66, 0.3))
	for pp in pops:
		draw_string(font, Vector2(float(pp.x) - 60, size.y * 0.4 - float(pp.t) * 50.0), str(pp.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(pp.col.r, pp.col.g, pp.col.b, 1.0 - float(pp.t)))
	if state == "play":
		draw_string(font, Vector2(size.x * 0.5 - 70, 28), "STRIKES " + "X".repeat(strikes) + "-".repeat(3 - strikes), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.5, 0.4))
