class_name LogStacker
extends ArcadeGame
## LOG STACKER (original). A log slides back and forth above the pile;
## SPACE drops it. Whatever hangs past the log below is sawn off and falls
## away, so the stack narrows. Miss completely and the pile topples.
## Perfect drops score double; three perfect in a row widen the log again.

const ROW_H := 26.0
const BASE_W := 220.0

var stack: Array[Vector2] = []     # (x_left, width) per row, bottom first
var cur_x := 0.0
var cur_w := BASE_W
var dir := 1.0
var spd := 170.0
var streak := 0
var falling: Array[Dictionary] = []
var scroll := 0.0
var _msg := ""
var _msg_t := 0.0


func _init() -> void:
	title = "Log Stacker"
	help_lines = PackedStringArray([
		"A log slides back and forth above the pile.",
		"SPACE drops it onto the stack.",
		"Any overhang gets sawn off and falls away,",
		"so line it up! Miss the pile and it's over.",
		"Perfect drop = 2 points. Three perfects in a row",
		"and the log grows back a little.",
	])


func _reset() -> void:
	stack.clear()
	stack.append(Vector2(size.x * 0.5 - BASE_W * 0.5, BASE_W))
	cur_w = BASE_W
	cur_x = 40.0
	dir = 1.0
	spd = 170.0
	streak = 0
	falling.clear()
	scroll = 0.0


func _tick(delta: float) -> void:
	cur_x += dir * spd * delta
	var lo := 30.0
	var hi := size.x - 30.0 - cur_w
	if cur_x < lo:
		cur_x = lo
		dir = 1.0
	elif cur_x > hi:
		cur_x = hi
		dir = -1.0
	for f in falling:
		f.vy = float(f.vy) + 900.0 * delta
		f.y = float(f.y) + float(f.vy) * delta
		f.rot = float(f.rot) + float(f.spin) * delta
	falling = falling.filter(func(f: Dictionary) -> bool: return float(f.y) < size.y + 200.0)
	var want := maxf(0.0, (stack.size() - 9) * ROW_H)
	scroll = move_toward(scroll, want, delta * 120.0)
	_msg_t = maxf(_msg_t - delta, 0.0)


func _press(k: int) -> void:
	if not k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_DOWN, KEY_S]:
		return
	var top: Vector2 = stack[stack.size() - 1]
	var left := maxf(cur_x, top.x)
	var right := minf(cur_x + cur_w, top.x + top.y)
	var y := _row_y(stack.size())
	if right - left <= 2.0:
		falling.append({"x": cur_x, "w": cur_w, "y": y, "vy": 0.0, "rot": 0.0, "spin": 2.0 * dir})
		game_over()
		return
	var perfect := absf(cur_x - top.x) < 4.0
	if perfect:
		left = top.x
		right = top.x + top.y
		streak += 1
		score += 2
		beep(880.0, 0.1)
		_msg = "PERFECT!"
		_msg_t = 0.8
		if streak >= 3:
			streak = 0
			var grow := minf(24.0, BASE_W - (right - left))
			left -= grow * 0.5
			right += grow * 0.5
			_msg = "PERFECT x3 - LOG GROWS!"
	else:
		streak = 0
		score += 1
		beep(520.0, 0.07)
		# The sawn-off piece falls away.
		if cur_x < left:
			falling.append({"x": cur_x, "w": left - cur_x, "y": y, "vy": 0.0, "rot": 0.0, "spin": -1.5})
		if cur_x + cur_w > right:
			falling.append({"x": right, "w": cur_x + cur_w - right, "y": y, "vy": 0.0, "rot": 0.0, "spin": 1.5})
	stack.append(Vector2(left, right - left))
	cur_w = right - left
	cur_x = 30.0 if dir < 0.0 else size.x - 30.0 - cur_w
	spd = minf(170.0 + stack.size() * 9.0, 520.0)


func _row_y(i: int) -> float:
	return size.y - 40.0 - (i + 1) * ROW_H + scroll


func _log(x: float, y: float, w: float, rot := 0.0) -> void:
	var c := Vector2(x + w * 0.5, y + ROW_H * 0.5)
	draw_set_transform(c, rot, Vector2.ONE)
	draw_rect(Rect2(-w * 0.5, -ROW_H * 0.5 + 2, w, ROW_H - 4), Color(0.55, 0.36, 0.18))
	draw_rect(Rect2(-w * 0.5, -ROW_H * 0.5 + 2, w, 4), Color(0.68, 0.47, 0.25))
	for gx in range(int(-w * 0.5) + 14, int(w * 0.5) - 6, 22):
		draw_line(Vector2(gx, -6), Vector2(gx + 10, -6), Color(0.4, 0.25, 0.12), 2.0)
	draw_circle(Vector2(w * 0.5 - 2, 0), ROW_H * 0.42, Color(0.86, 0.7, 0.45))
	draw_arc(Vector2(w * 0.5 - 2, 0), ROW_H * 0.25, 0, TAU, 14, Color(0.6, 0.42, 0.22), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint() -> void:
	# Sky, distant hills, ground.
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.1, 0.14, 0.26))
	for i in 6:
		draw_circle(Vector2(fposmod(i * 173.0 + t * 6.0, size.x + 80.0) - 40.0, 90.0 + (i % 3) * 30.0), 2.0, Color(1, 1, 0.9, 0.7))
	draw_rect(Rect2(0, size.y - 40 + scroll, size.x, 40 + 400), Color(0.2, 0.32, 0.16))
	for i in stack.size():
		_log(stack[i].x, _row_y(i), stack[i].y)
	if state == "play":
		_log(cur_x, _row_y(stack.size()) - 34.0, cur_w)
		draw_line(Vector2(cur_x + cur_w * 0.5, 40), Vector2(cur_x + cur_w * 0.5, _row_y(stack.size()) - 34.0), Color(0.8, 0.8, 0.8, 0.6), 2.0)
	for f in falling:
		_log(float(f.x), float(f.y), float(f.w), float(f.rot))
	if _msg_t > 0.0:
		var font := get_theme_default_font()
		draw_string(font, Vector2(size.x * 0.5 - 120, 80), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.9, 0.3, minf(_msg_t * 2.0, 1.0)))
