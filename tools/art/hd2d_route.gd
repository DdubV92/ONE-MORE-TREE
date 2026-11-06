extends Node
## Phase 24 HD-2D comparison fixture: the real camp with the crew, matched
## camera and exposure, old (3D "clean") vs new (HD-2D sprites), under noon,
## late warm daylight and blue dusk.
## Usage: godot --rendering-driver vulkan res://tools/art/hd2d_route.tscn
## Output: captures/p24_route_<shot>_<light>_<style>.png

const LIGHTS := {"noon": "day", "late": 17.6, "dusk": 20.25}
## Staged crew in the open camp clearing (camp-local), with a clip each.
const STAGE := [[Vector3(-2.2, 0, 1.2), 0.4, "idle"], [Vector3(0.2, 0, 2.6), -2.4, "walk"], [Vector3(2.4, 0, 0.6), 1.9, "swing"], [Vector3(-0.6, 0, -1.2), 3.0, "talk"], [Vector3(3.6, 0, 3.0), -1.0, "idle"]]


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while (Game.crew == null or not world.systems_ready) and g < 4000:
		await get_tree().physics_frame
		g += 1
	Game.campaign.start_test_route(true, true)
	for k in 90:
		await get_tree().physics_frame
	var post := PostFX.new()
	add_child(post)
	var cam := Camera3D.new()
	cam.fov = 70.0
	world.add_child(cam)
	cam.make_current()
	if world.weather:
		world.weather.set_override("clear", true)
	var workers: Array = Game.crew.workers.values() if Game.crew.workers is Dictionary else Game.crew.workers
	print("ROUTE workers=%d" % workers.size())
	if workers.is_empty():
		get_tree().quit(1)
		return
	# Freeze the crew where they stand (matched frames for both styles).
	for w in workers:
		(w as Node).process_mode = Node.PROCESS_MODE_DISABLED
		var ch: HumanCharacter = w.get("body_char")
		ch.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in mini(workers.size(), STAGE.size()):
		var w: Node3D = workers[i]
		var at := CampLayout.world(STAGE[i][0])
		at.y = World.height_at(at.x, at.z)
		w.global_position = at
		w.rotation.y = float(STAGE[i][1])
		var ch: HumanCharacter = w.get("body_char")
		ch.play(str(STAGE[i][2]), 0.0)
	var dogs := get_tree().get_nodes_in_group("camp_dog")
	if not dogs.is_empty():
		var d: Node3D = dogs[0]
		d.process_mode = Node.PROCESS_MODE_DISABLED
		var dch: Node = d.get("dog")
		dch.process_mode = Node.PROCESS_MODE_ALWAYS
		var dp := CampLayout.world(Vector3(1.2, 0, 4.4))
		dp.y = World.height_at(dp.x, dp.z)
		d.global_position = dp
		d.rotation.y = 2.2
	var c0 := CampLayout.world(Vector3(0.4, 0, 1.6))
	var shots := {
		"crew_close": [c0 + Vector3(0.4, 1.65, 5.6), c0 + Vector3(0, 0.95, 0)],
		"crew_wide": [c0 + Vector3(-3.0, 1.65, 11.0), c0 + Vector3(0, 0.8, 0)],
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	for light in LIGHTS:
		if LIGHTS[light] is String:
			world.environment.apply_named(str(LIGHTS[light]))
		else:
			world.environment.apply_named("day")
			world.environment.set_time_of_day(float(LIGHTS[light]))
		for shot in shots:
			cam.global_position = shots[shot][0]
			cam.look_at(shots[shot][1])
			world.vegetation.update_collision_around(cam.global_position)
			for style in ["clean", "hd2d"]:
				Settings.values.character_style = style
				Settings.values.world_style = "hd2d" if style == "hd2d" else "3d"
				post.call("_apply")
				world.environment.apply_quality()
				# Let every visible worker's current clip bake.
				var wait := 0
				while wait < 900:
					await get_tree().process_frame
					wait += 1
					var b := PixelBaker._inst
					if style == "clean" or (wait > 20 and (b == null or b.pending() == 0)):
						break
				for f in 6:
					await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.save_png("res://captures/p24_route_%s_%s_%s.png" % [shot, light, style])
	var b2 := PixelBaker._inst
	print("ROUTE done baked=%d" % (b2.baked_clips if b2 else 0))
	get_tree().quit()
