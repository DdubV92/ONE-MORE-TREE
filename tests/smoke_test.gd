extends Node
## Bounded startup smoke test (headless): boots the title, enters the world
## in Preview mode with the player and HUD, visits every review viewpoint,
## cycles lighting presets, opens the character preview, then exits.
## Fails on any script error captured by the diagnostics logger.
##   godot --headless res://tests/smoke_test.tscn

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var title: Node = load("res://scenes/main.tscn").instantiate()
	add_child(title)
	for i in 5:
		await get_tree().process_frame
	title.queue_free()
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for vp in Viewpoints.all().keys():
		world.teleport_to(vp)
		for i in 6:
			await get_tree().physics_frame
	for preset in ["dawn", "day", "sunset", "night", "overcast"]:
		Game.environment.apply_named(preset)
		for i in 3:
			await get_tree().process_frame
	world.queue_free()
	await get_tree().process_frame
	var cp: Node = load("res://scenes/character_preview.tscn").instantiate()
	add_child(cp)
	for clip in ["walk", "swing", "idle"]:
		cp.human.play(clip)
		for i in 20:
			await get_tree().process_frame
	cp.dog.play("lie")
	for i in 20:
		await get_tree().process_frame
	var report := Diag.write_report({"smoke_test_ms": Time.get_ticks_msec() - t0})
	var errs := Diag.errors.filter(func(e: String) -> bool: return not e.contains("leaked") and not e.contains("resources still in use"))
	print("SMOKE: %d errors, %d warnings, %d ms. Report: %s" % [errs.size(), Diag.warnings.size(), Time.get_ticks_msec() - t0, report])
	for e in errs:
		print("  ", e)
	get_tree().quit(1 if errs.size() > 0 else 0)
