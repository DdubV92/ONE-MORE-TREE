extends Node
## Phase 20 screenshot tool: stages real night recordings on the island,
## opens the camper computer's Recordings app and saves the computer screen
## (and the raw reconstruction) to captures/. Needs a renderer:
##   xvfb-run godot --rendering-driver vulkan res://tools/rc/capture_recording.tscn


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
	for k in 120:
		await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var ids := OS.get_cmdline_user_args() if not OS.get_cmdline_user_args().is_empty() else PackedStringArray(["rec15", "rec01", "rec22"])
	for sid in ids:
		var clip := Game.night_recorder.on_night(500 + ids.find(sid), sid)
		if clip.is_empty():
			print("CAPTURE %s could not be staged" % sid)
			continue
	var desk: DeskComputer = Game.desk
	desk.open_app("Recordings")
	for sid in ids:
		var clips := desk._clips()
		var idx := -1
		for i in clips.size():
			if str(clips[i].scenario) == sid:
				idx = i
		if idx < 0:
			continue
		desk._rec_open(idx)
		var p := desk.player
		p.seek(p.duration * 0.45)
		p.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		desk.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for k in 25:
			await get_tree().process_frame
		desk.vp.get_texture().get_image().save_png("res://captures/p20_recordings_app_%s.png" % sid)
		p.vp.get_texture().get_image().save_png("res://captures/p20_reconstruction_%s.png" % sid)
		print("CAPTURE %s ok (%s %s)" % [sid, clips[idx].camera, clips[idx].clock])
	get_tree().quit()
