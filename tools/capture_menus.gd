extends Node
## Phase 9: captures the title menu pages and the in-campaign Journal Help
## tab + first-day guide line to captures/ (needs a real renderer).

func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://captures/%s.png" % name)
	print("captured ", name)


func _ready() -> void:
	var title: Control = load("res://scenes/main.tscn").instantiate()
	add_child(title)
	await _shot("p9_title")
	title.call("_new_campaign")
	await _shot("p9_new_campaign")
	title.call("_show_help")
	await _shot("p9_help")
	title.queue_free()
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 600:
		await get_tree().process_frame
		g += 1
	world.campaign.start_test_route(false)
	world.campaign.onboarding.start_new()
	world.campaign.onboarding.replaying = false
	world.campaign.test_route = false
	world.campaign.onboarding._emit_hint()
	await _shot("p9_guide")
	world.hud.campaign_ui.toggle_journal(6 if world.crew and world.crew.enabled else 5)
	await _shot("p9_journal_help")
	get_tree().quit()
