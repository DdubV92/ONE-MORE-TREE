class_name EndScreen
extends CanvasLayer
## Full-screen result card used for the ordinary night catch, the boss's
## death during the hunt, and the rescue/survival outcome. It pauses the
## world, blocks every save while shown (a dead or caught state is never
## written), and offers explicit, explained recovery options.

var _panel: PanelContainer
var _box: VBoxContainer
var showing := ""


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _build(title: String, body: String, tint: Color) -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = tint
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -320
	_panel.offset_right = 320
	_panel.offset_top = -200
	_panel.offset_bottom = 200
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)
	_box.add_child(UITheme.label(title, 30, UITheme.ACCENT))
	var l := UITheme.label(body, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(600, 0)
	_box.add_child(l)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _button(text: String, f: Callable) -> void:
	_box.add_child(UITheme.button(text, f, 600))


## Ordinary contract-night catch (abstract, indistinct attacker).
func show_caught() -> void:
	showing = "caught"
	Game.block_saves = true
	_build("Taken in the dark", "You stayed out too long after nightfall. Something you never clearly saw closed the distance.\n\nThe camper, an occupied cabin and the lamp-lit camp are safe at night.", Color(0.0, 0.0, 0.0, 0.92))
	_offer_reload("morning", "Load this morning's checkpoint (today's progress since you woke is lost)")


## The boss is killed by the Foreman during the hunt.
func show_player_dead(day: int) -> void:
	showing = "dead"
	Game.block_saves = true
	_build("You did not survive day %d" % day, "The Foreman caught you. This attempt is over; nobody escaped with you.\n\nHiding, breaking line of sight and moving quietly can keep you alive.", Color(0.05, 0.0, 0.0, 0.94))
	_offer_reload("survival", "Load the last survival checkpoint (this hunt day's dawn)")


func _offer_reload(kind: String, text: String) -> void:
	if Game.mode == Game.Mode.CAMPAIGN:
		if SaveService.has_checkpoint(kind):
			_button(text, func() -> void:
				SaveService.restore_checkpoint(kind)
				Game.start_campaign())
		_button("Load the last manual/auto save", func() -> void: Game.start_campaign())
	else:
		_button("Preview: return to camp and keep reviewing", func() -> void:
			visible = false
			Game.block_saves = false
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			if Game.world_root:
				Game.world_root.teleport_to("camper"))
	_button("Back to the title screen", func() -> void:
		Game.return_to_menu())


## Information card that resumes play (e.g. the abandonment rules).
func show_info(title: String, body: String, button := "Continue") -> void:
	showing = "info"
	_build(title, body, Color(0.0, 0.0, 0.0, 0.85))
	_panel.offset_top = -280
	_panel.offset_bottom = 280
	_button(button, func() -> void: _resume())


## Two-choice confirmation (e.g. boarding with crew still ashore).
func confirm(title: String, body: String, yes: String, on_yes: Callable, no: String, on_no: Callable) -> void:
	showing = "confirm"
	_build(title, body, Color(0.0, 0.0, 0.0, 0.7))
	_button(yes, func() -> void:
		_resume()
		on_yes.call())
	_button(no, func() -> void:
		_resume()
		on_no.call())


func _resume() -> void:
	visible = false
	showing = ""
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Survival outcome after the rescue ship (or the contract success summary).
func show_outcome(title: String, lines: PackedStringArray) -> void:
	showing = "outcome"
	_build(title, "\n".join(lines), Color(0.02, 0.03, 0.05, 0.94))
	_button("Back to the title screen", func() -> void:
		Game.block_saves = false
		Game.return_to_menu())
