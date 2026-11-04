class_name ArcadeGame
extends Control
## Base for the two original cabinet games. Runs while the world is paused
## (PROCESS_MODE_ALWAYS). States: title -> play -> over, with a help page.
## Keys: Space/Enter start, H help, R restart, Esc leaves (handled by the
## overlay). Subclasses implement _reset(), _tick(), _press() and _paint().

signal finished(score: int)

var title := "Game"
var help_lines: PackedStringArray = []
var state := "title"        # title / help / play / over
var score := 0
var high := 0
var new_high := false
var t := 0.0
var rng := RandomNumberGenerator.new()
var _beeps := {}
var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "UI"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	rng.seed = Time.get_ticks_usec()


func start() -> void:
	state = "play"
	score = 0
	new_high = false
	t = 0.0
	_reset()


func key(ev: InputEventKey) -> void:
	var k := ev.physical_keycode
	match state:
		"title", "over":
			if k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_R]:
				start()
			elif k == KEY_H:
				state = "help"
		"help":
			state = "title"
		"play":
			if k == KEY_R:
				start()
			elif k == KEY_H:
				pass
			else:
				_press(k)


func game_over() -> void:
	if state != "play":
		return
	state = "over"
	if score > high:
		high = score
		new_high = true
	beep(180.0, 0.35)
	finished.emit(score)


func _process(delta: float) -> void:
	t += delta
	if state == "play":
		_tick(delta)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.06))
	_paint()
	var f := get_theme_default_font()
	draw_string(f, Vector2(16, 28), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 0.7))
	draw_string(f, Vector2(size.x - 200, 28), "HIGH %d" % high, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 1, 1))
	match state:
		"title":
			_panel(f, [title.to_upper(), "", "SPACE  start", "H  how to play", "ESC  leave the cabinet"])
		"help":
			var lines: Array = [title.to_upper() + " - HOW TO PLAY", ""]
			lines.append_array(help_lines)
			lines.append_array(["", "R restart · ESC leave · any key: back"])
			_panel(f, lines)
		"over":
			_panel(f, ["GAME OVER", "", "Score %d" % score, ("NEW HIGH SCORE!" if new_high else "High score %d" % high), "", "R / SPACE  play again", "H  help · ESC  leave"])


func _panel(f: Font, lines: Array) -> void:
	var h := 34.0 * lines.size() + 30.0
	var r := Rect2(size.x * 0.5 - 300, size.y * 0.5 - h * 0.5, 600, h)
	draw_rect(r, Color(0, 0, 0, 0.78))
	draw_rect(r, Color(1, 0.8, 0.3), false, 3.0)
	for i in lines.size():
		var s := str(lines[i])
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(f, Vector2(size.x * 0.5 - w * 0.5, r.position.y + 42 + i * 34), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.95, 0.8) if i > 0 else Color(1, 0.75, 0.3))


## Tiny square-wave bleep (generated once per pitch).
func beep(freq: float, dur := 0.08) -> void:
	var key_s := "%d_%d" % [int(freq), int(dur * 1000)]
	if not _beeps.has(key_s):
		var rate := 22050
		var n := int(rate * dur)
		var data := PackedByteArray()
		data.resize(n * 2)
		for i in n:
			var env := 1.0 - float(i) / n
			var v := (0.25 if fposmod(i * freq / rate, 1.0) < 0.5 else -0.25) * env
			data.encode_s16(i * 2, int(v * 32767.0))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = rate
		w.data = data
		_beeps[key_s] = w
	_player.stream = _beeps[key_s]
	_player.play()


func _reset() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _press(_k: int) -> void:
	pass


func _paint() -> void:
	pass
