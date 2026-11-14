extends Node
## Phase 26/28: captures the Journal's Map and Field notes tabs to
## captures/ (needs a real renderer). A new campaign on island r2 with a
## little history staged in memory: a walk out to lot 1 and down to the
## dock, a few lot trees felled, a work lamp set down, sample notes.

func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://captures/%s.png" % name)
	print("captured ", name)


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 900:
		await get_tree().process_frame
		g += 1
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	for i in 10:
		await get_tree().process_frame
	var map: IslandMap = Game.island_map
	var lots: ContractLots = cs.contract.lots
	var o := World.camp_origin()
	if lots:
		for t in 12:
			map.reveal(o.lerp(lots.focus + (lots.focus - o).normalized() * 90.0, t / 11.0), IslandMap.REVEAL_RADIUS)
		var ids: PackedInt32Array = lots.lots[0].trees
		for j in 11:
			world.trees.record(ids[j]).state = TreeService.State.DISPOSED
	if Game.crew and Game.crew.dock_shore != Vector3.ZERO:
		for t in 10:
			map.reveal(o.lerp(Game.crew.dock_shore, t / 9.0), IslandMap.REVEAL_RADIUS)
	if Game.night_kit and lots:
		Game.night_kit._spawn(lots.focus + (lots.focus - o).normalized() * 30.0, NightKit.BATTERY_S)
	Game.director.notes.restore({"notes": {"22": {"seen": 1, "answered": 0, "first_day": 1}, "18": {"seen": 3, "answered": 0, "first_day": 2}, "5": {"seen": 2, "answered": 1, "first_day": 4}, "1": {"seen": 4, "answered": 2, "first_day": 6}}})
	if world.hud.get("tour_panel"):
		world.hud.tour_panel.visible = false
	world.hud.campaign_ui.toggle_journal(99)
	for i in 4:
		await get_tree().process_frame
	var pn: Control = world.hud.campaign_ui.panel
	var par: Node = world.hud.campaign_ui.get_parent()
	print("JOURNAL parent ", par.get_class(), " ", par.name, " psize ", par.get("size"), " win ", get_window().size, " anchors ", world.hud.campaign_ui.anchor_right, " ", world.hud.campaign_ui.anchor_bottom)
	print("JOURNAL ui size ", world.hud.campaign_ui.size, " panel pos ", pn.global_position, " size ", pn.size, " viewport ", get_viewport().get_visible_rect().size)
	await _shot("journal_map")
	for mvn in world.hud.campaign_ui.find_children("*", "MapView", true, false):
		(mvn as MapView).toggle_zoom()
	await _shot("journal_map_near")
	for tc in world.hud.campaign_ui.find_children("*", "TabContainer", true, false):
		var tabs := tc as TabContainer
		for i in tabs.get_tab_count():
			if tabs.get_tab_title(i) == "Field notes":
				tabs.current_tab = i
	await _shot("journal_field_notes")
	get_tree().quit()
