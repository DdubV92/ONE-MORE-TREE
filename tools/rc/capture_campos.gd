extends Node
## Phase 22 screenshot tool: the CampOS desktop with overlapping program
## windows, the taskbar, the start menu and the on-screen pointer; plus the
## boot screen. Saves captures/p22_*.png.
##   xvfb-run godot --rendering-driver vulkan res://tools/rc/capture_campos.tscn


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = "island_r2"
	Game.pending_teleport = "camp"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	var g := 0
	while (Game.crew == null or not world.systems_ready or Game.desk == null) and g < 4000:
		await get_tree().process_frame
		g += 1
	Game.campaign.start_test_route(true, true)
	for k in 60:
		await get_tree().physics_frame
	var desk: DeskComputer = Game.desk
	desk.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	for a in ["Cameras", "Mail", "Payroll"]:
		desk.open_app(a)
	(desk.windows["Cameras"] as CampWindow).position = Vector2(660, 40)
	(desk.windows["Cameras"] as CampWindow).size = Vector2(600, 400)
	(desk.windows["Mail"] as CampWindow).position = Vector2(150, 70)
	(desk.windows["Mail"] as CampWindow).size = Vector2(700, 470)
	(desk.windows["Payroll"] as CampWindow).position = Vector2(230, 190)
	(desk.windows["Payroll"] as CampWindow).size = Vector2(1000, 440)
	desk.minimize_app("Payroll")
	desk.focus(desk.windows["Mail"])
	desk.pointer_to(Vector2(560, 300))
	await _frames(30)
	_save(desk, "p22_desktop_windows")
	desk.open_app("Payroll")
	desk.pointer_to(Vector2(700, 420))
	await _frames(12)
	_save(desk, "p22_desktop_payroll_front")
	for a in desk.windows.keys():
		desk.minimize_app(str(a))
	desk._start_menu.visible = true
	desk.pointer_to(Vector2(120, 470))
	await _frames(12)
	_save(desk, "p22_desktop_start_menu")
	desk._start_menu.visible = false
	desk.set_power(false)
	desk.set_power(true)
	desk._tick_boot(1.6)
	await _frames(6)
	_save(desk, "p22_boot")
	get_tree().quit()


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _save(desk: DeskComputer, name: String) -> void:
	desk.vp.get_texture().get_image().save_png("res://captures/%s.png" % name)
	print("CAPTURE ", name)
