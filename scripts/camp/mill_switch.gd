extends Node3D
## Phase 26: the sawmill's night-shift switch, on the yard board's post.
## In daylight the line runs by itself. At night it only runs if the boss
## switches it on here and stays at the mill; pallets cut then pay the
## rush rate.


func get_interact_text() -> String:
	var m: Sawmill = Game.mill
	return m.switch_prompt() if m else ""


func interact(by: Node) -> void:
	var m: Sawmill = Game.mill
	if m == null:
		return
	var msg := m.toggle_night_shift()
	if msg != "" and by.has_method("show_message"):
		by.show_message(msg)
