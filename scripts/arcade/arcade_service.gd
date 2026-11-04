class_name ArcadeService
extends CanvasLayer
## The two cabinets in the worker cabin (Phase 5). Using a cabinet opens
## its game full-screen and PAUSES the single-player world (clock, workday,
## burning, payroll, crew, trucks and any later horror) - clearly labelled.
## The camera TV, by contrast, is live time; that is deliberate. Leaving
## restores the exact previous pause/mouse state. High scores persist in
## the campaign save (preview keeps them for the session only).

const GAMES := ["Log Stacker", "Flapjack Flip"]

var highs := {"log_stacker": 0, "flapjack_flip": 0}
var active := -1
var _game: ArcadeGame
var _root: Control
var _banner: Label
var _was_paused := false
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var sessions := 0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 10
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 18)
	_banner.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	_root.add_child(_banner)


## Hooks the cabinet interactables built by the camp builder.
func hook_cabinets() -> void:
	for i in GAMES.size():
		var cab := Game.world_root.find_child("ArcadeCabinet_%d" % (i + 1), true, false) if Game.world_root else null
		if cab == null:
			continue
		for c in cab.get_children():
			if c is Interactable:
				var it := c as Interactable
				it.prompt = "Play %s (pauses the world)" % GAMES[i]
				it.message = ""
				var idx := i
				it.used.connect(func(_by: Node) -> void: open(idx))
		var mq := Label3D.new()
		mq.text = GAMES[i].to_upper()
		mq.font_size = 46
		mq.pixel_size = 0.0028
		mq.modulate = Color(0.12, 0.06, 0.02)
		mq.position = Vector3(0, 1.66, 0.362)
		cab.add_child(mq)


func is_open() -> bool:
	return active >= 0


func open(index: int) -> void:
	if active >= 0 or index < 0 or index >= GAMES.size():
		return
	active = index
	sessions += 1
	_was_paused = get_tree().paused
	_was_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_game = LogStacker.new() if index == 0 else FlapjackFlip.new()
	_game.high = int(highs.get(_key(index), 0))
	_game.custom_minimum_size = Vector2(900, 620)
	_game.size = Vector2(900, 620)
	_game.set_anchors_preset(Control.PRESET_CENTER)
	_game.position = -_game.size * 0.5
	_game.finished.connect(_on_finished)
	_root.add_child(_game)
	_root.visible = true
	_banner.text = "ARCADE · %s  —  THE WORLD IS PAUSED while you play (clock, work, fires, crew).  ESC leaves the cabinet." % GAMES[index]


func close() -> void:
	if active < 0:
		return
	if _game:
		_on_finished(_game.score)
		_game.queue_free()
		_game = null
	active = -1
	_root.visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = _was_mouse


func _key(i: int) -> String:
	return "log_stacker" if i == 0 else "flapjack_flip"


func _on_finished(s: int) -> void:
	var k := _key(active)
	if s > int(highs.get(k, 0)):
		highs[k] = s


func _input(event: InputEvent) -> void:
	if active < 0:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var ev := event as InputEventKey
		if ev.physical_keycode == KEY_ESCAPE:
			close()
			return
		_game.key(ev)


## A scene change or load while playing never leaves a phantom pause.
func _exit_tree() -> void:
	if active >= 0:
		get_tree().paused = false
		active = -1


func capture() -> Dictionary:
	return {"highs": highs.duplicate()}


func restore(d: Dictionary) -> void:
	var h: Dictionary = d.get("highs", {})
	for k in highs:
		highs[k] = maxi(int(h.get(k, 0)), 0)
