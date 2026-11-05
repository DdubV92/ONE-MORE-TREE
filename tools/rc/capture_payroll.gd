extends Node
## Phase 21 screenshot tool: the Payroll app with REAL numbers. A test-route
## campaign (five workers, never saved) works one real day at 6x speed with
## 3D rendering off, sleeps (a real settlement), varies pay, works part of
## the next day, then saves the computer screen for each page to captures/.
##   xvfb-run godot --rendering-driver vulkan res://tools/rc/capture_payroll.tscn


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
	var cs: CampaignService = Game.campaign
	cs.start_test_route(true, true)
	cs.wallet.grant(400000, "test", "CAPTURE", "capture cash")
	_render(false)
	Engine.time_scale = 6.0
	await _work_until(WorkdayClock.NIGHT_AT)     # the clock holds at nightfall
	Engine.time_scale = 1.0
	var r := cs.sleep()
	_dismiss_report()
	print("CAPTURE night 1: ", JSON.stringify((r.get("report", {}) as Dictionary).get("pay", {}).get("totals", {})))
	# Different pay choices, as a player might make them.
	cs.pay.change_rate("EMP-01", 2)            # $150
	cs.pay.change_rate("EMP-03", 1)            # $125
	cs.pay.cycle_perf("EMP-03")                # 10 %
	cs.pay.cycle_perf("EMP-03")                # 25 %
	cs.pay.change_bonus("EMP-05", 2)           # $50 today
	# STAGED for the picture: the least patient worker after a few
	# bare-minimum nights (what the real rules lead to by about night 4).
	var impatient := "EMP-01"
	for e in cs.payroll.employees:
		if float(cs.pay.rec(str(e.id)).patience) < float(cs.pay.rec(impatient).patience) and str(e.id) != "EMP-02":
			impatient = str(e.id)
	var r4 := cs.pay.rec(impatient)
	r4.sat = 0.22
	r4.verge_day = cs.clock.day - 1
	r4.min_days = 4
	print("CAPTURE staged verge: ", impatient)
	# Better boots for Dale -> his fair wage rises (and he may ask).
	var b := cs.equipment.add_item("boots", "t3", "EMP-02", "capture")
	cs.equipment.equip("EMP-02", str(b.id))
	if cs.pay.pending_request("EMP-02").is_empty():
		cs.pay.rec("EMP-02").assertive = 1.0
		cs.pay.on_advanced("EMP-02", "career", 3)
	Engine.time_scale = 6.0
	await _work_until(380.0)
	Engine.time_scale = 1.0
	_render(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var desk: DeskComputer = Game.desk
	desk.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	desk.open_app("Payroll")
	await _frames(6)
	var app := _app(desk)
	for pg in [["Crew", "EMP-02"], ["Crew", impatient], ["Last night", ""], ["Campaign", ""]]:
		app.page = str(pg[0])
		if str(pg[1]) != "":
			app.selected = str(pg[1])
		app.rebuild()
		await _frames(8)
		var name := "p21_payroll_%s%s" % [str(pg[0]).to_lower().replace(" ", "_"), ("_request" if str(pg[1]) == "EMP-02" else "_verge") if str(pg[1]) != "" else ""]
		desk.vp.get_texture().get_image().save_png("res://captures/%s.png" % name)
		print("CAPTURE ", name)
	get_tree().quit()


## "Start the day" on the end-of-day card (it pauses the game until then).
func _dismiss_report() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("show_report") and n.has_method("close_panel"):
			n.close_panel()
	get_tree().paused = false


## Off while the crew works (the camera feeds and TV render their own 3D
## views, which the CPU renderer cannot keep up with); on for the capture.
func _render(on: bool) -> void:
	get_tree().root.disable_3d = not on
	for vp in get_tree().root.find_children("*", "SubViewport", true, false):
		(vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if on else SubViewport.UPDATE_DISABLED


func _app(desk: DeskComputer) -> PayrollApp:
	for c in desk._content.get_children():
		if c is PayrollApp:
			return c
	return null


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _work_until(t: float) -> void:
	var cs: CampaignService = Game.campaign
	var guard := Time.get_ticks_msec()
	while cs.clock.t < t and Time.get_ticks_msec() - guard < 900000:
		await get_tree().physics_frame
