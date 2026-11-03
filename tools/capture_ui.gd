extends Node
## Captures the title screen and the in-world Preview Tour HUD to captures/.

func _ready() -> void:
	var title: Control = load("res://scenes/main.tscn").instantiate()
	add_child(title)
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://captures/ui_title.png")
	print("captured ui_title")
	title.queue_free()
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for i in 14:
		await get_tree().process_frame
	var hud: Node = world.hud
	hud.help_panel.visible = true
	hud.debug_label.visible = true
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://captures/ui_preview_tour.png")
	print("captured ui_preview_tour")
	get_tree().quit()
