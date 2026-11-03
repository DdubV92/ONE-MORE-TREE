class_name Interactable
extends Node3D
## Base for anything the player can use with the interact key. The player's
## ray hits a collision object; the first ancestor with `interact()` wins.
## Phase 0 placeholders say what later prompts will add.

@export var prompt := "Use"
@export var message := ""
signal used(by: Node)


func get_interact_text() -> String:
	return prompt


func interact(by: Node) -> void:
	used.emit(by)
	if message != "" and Game.player and Game.player.has_method("show_message"):
		Game.player.show_message(message)
