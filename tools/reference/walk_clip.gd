extends Node
## Phase 24 reference cove: an uncut first-person walk at gameplay settings,
## recorded with Godot's Movie Maker (exact frame pacing at any render speed):
##   godot --write-movie captures/ref_walk.avi --fixed-fps 20 res://tools/reference/walk_clip.tscn
## Route: start by the foreground tree -> past the dog -> up to the worker ->
## chop a real island tree -> out to the wet sand, looking down into the
## shallows while walking along the shore -> turn back toward the forest.

var world: IslandWorld
var p: Player
var steps: Array = []
var log_lines: PackedStringArray = []


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	# Gameplay settings = the shipping defaults (this container's saved
	# settings.cfg was left on "clean" by earlier comparison runs).
	Settings.values.character_style = "hd2d"
	Game.preview_variant = "island_r2"
	Game.pending_teleport = "ref_fp"
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 4000:
		await get_tree().process_frame
		g += 1
	p = Game.player as Player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED     # gameplay input (swings need it)
	print("WALK state fly=%s paused=%s phys=%s vehicle=%s couch=%s hiding=%s pos=%s" % [p.fly_mode, get_tree().paused, p.is_physics_processing(), p.vehicle, p.couch, p.hiding, p.global_position])
	world.teleport_to("ref_fp")
	if world.weather:
		world.weather.set_override("clear", true)
	world.environment.apply_named("golden")
	world.environment.set_process(false)          # hold the golden hour for the clip
	# Let the cove's actor sprites bake before walking.
	for i in 200:
		await get_tree().process_frame
		var pb: PixelBaker = PixelBaker._inst
		if i > 30 and (pb == null or pb.pending() == 0):
			break
	if OS.has_environment("REF_FP_SHOT"):
		# The uncropped first-person screenshot at gameplay settings: the
		# First-Person Shoreline start exactly as the player lands there.
		await _wait(1.0)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
		img.save_png("res://captures/ref_fp_gameplay.png")
		print("WALK shot saved %dx%d" % [img.get_width(), img.get_height()])
		get_tree().quit()
		return
	await _walk_to(ReferenceCove.at(0.4, 3.3), 0.0)              # past the ferns to the fence gap
	await _walk_to(ReferenceCove.at(0.1, 4.6), 0.0)              # through the gap
	await _walk_to(ReferenceCove.at(-0.1, 5.6), -0.15)           # past the dog
	await _look_at(ReferenceCove.at(-1.3, 6.3, 0.4), 1.2)        # glance at the dog
	await _look_at(ReferenceCove.at(0.55, 7.1, 1.3), 1.4)        # the worker at the stump
	await _walk_to(ReferenceCove.at(-0.9, 8.4), 0.0)            # round the stump, behind the worker
	var tree := _nearest_tree(ReferenceCove.at(0.0, 13.0), 12.0)
	if tree >= 0:
		var tp := Vector3(World.trees.x[tree], 0, World.trees.z[tree])
		tp.y = World.height_at(tp.x, tp.z)
		var dir := (p.global_position - tp)
		dir.y = 0.0
		dir = dir.normalized()
		await _walk_to(tp + dir * (1.05 + float(World.trees.radius[tree])), 0.0)
		print("WALK at tree: dist %.2f" % Vector2(p.global_position.x - tp.x, p.global_position.z - tp.z).length())
		await _look_at(tp + Vector3(0, 1.1, 0), 1.0)
		print("WALK chop: mouse=%d target=%d tree id=%d" % [Input.mouse_mode, p.axe.target_tree, int(World.trees.id[tree])])
		for k in 6:
			p.axe.try_swing()
			await _wait(1.25)
		var tid := int(World.trees.id[tree])
		log_lines.append("tree #%d state %d progress %.2f" % [tid, Game.trees.state_of(tid) if Game.trees else -1, Game.trees.progress(tid) if Game.trees else 0.0])
	await _walk_to(ReferenceCove.at(-0.6, 9.4), 0.0)
	await _walk_to(ReferenceCove.at(-0.9, 8.0), 0.0)
	await _walk_to(ReferenceCove.at(0.1, 4.6), 0.0)
	await _walk_to(ReferenceCove.at(0.4, 3.2), 0.0)
	await _walk_to(ReferenceCove.at(6.0, 2.6), 0.0)
	await _walk_to(ReferenceCove.at(15.4, 3.0), -0.25)          # down the beach onto the wet sand
	await _walk_to(ReferenceCove.at(16.8, 13.0), -0.5)          # along the swash, looking into the shallows
	await _look_at(ReferenceCove.at(-2.0, 14.0, 3.0), 2.6)      # turn back toward the forest
	await _wait(2.5)
	print("WALK done frames=%d %s" % [Engine.get_frames_drawn(), log_lines])
	get_tree().quit()


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


func _nearest_tree(at: Vector3, r: float) -> int:
	var best := -1
	var bd := r
	# Keep clear of the fixture's camp props (the woodpile overlaps one tree).
	var props := [ReferenceCove.P_WOODPILE, ReferenceCove.P_STUMP, ReferenceCove.P_WORKER, ReferenceCove.P_CAMPER, ReferenceCove.P_CHAIR]
	for i in World.tree_count():
		if World.removed_trees.has(int(World.trees.id[i])):
			continue
		var blocked := false
		for pp in props:
			var w := ReferenceCove.at((pp as Vector2).x, (pp as Vector2).y)
			if Vector2(World.trees.x[i] - w.x, World.trees.z[i] - w.z).length() < (4.5 if pp == ReferenceCove.P_CAMPER else 2.6):
				blocked = true
		if blocked:
			continue
		var d := Vector2(World.trees.x[i] - at.x, World.trees.z[i] - at.z).length()
		if d < bd:
			bd = d
			best = i
	return best


## Walk with the real movement action, steering the view toward `to`.
func _walk_to(to: Vector3, pitch: float) -> void:
	var guard := 0.0
	var last := p.global_position
	var still := 0.0
	while guard < 25.0:
		# Blocked (prop or character in the way): end the leg rather than
		# walking into it on camera.
		if p.global_position.distance_to(last) < 0.01:
			still += get_process_delta_time()
			if still > 0.6:
				break
		else:
			still = 0.0
		last = p.global_position
		var d := to - p.global_position
		d.y = 0.0
		if d.length() < 0.45:
			break
		var want := atan2(-d.x, -d.z)
		var err := absf(angle_difference(p._yaw, want))
		p._yaw = lerp_angle(p._yaw, want, 0.12 if err < 0.5 else 0.16)
		p._pitch = lerpf(p._pitch, pitch, 0.08)
		p._apply_look()             # what mouse look does each motion event
		# Turn on the spot toward a target that is off to the side or behind
		# (no circling), then walk.
		if err > 0.5:
			Input.action_release("move_forward")
			still = 0.0
		else:
			Input.action_press("move_forward")
		await get_tree().process_frame
		guard += get_process_delta_time()
	Input.action_release("move_forward")
	var left := to - p.global_position
	left.y = 0.0
	print("WALK leg -> %s  %.1fs  %s" % [str(to), guard, "ok" if left.length() < 0.6 else "STUCK %.1f m short" % left.length()])
	await _wait(0.15)


func _look_at(target: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		var d := target - p.camera.global_position
		var want_yaw := atan2(-d.x, -d.z)
		var want_pitch := atan2(d.y, Vector2(d.x, d.z).length())
		p._yaw = lerp_angle(p._yaw, want_yaw, 0.06)
		p._pitch = lerpf(p._pitch, want_pitch, 0.06)
		p._apply_look()
		await get_tree().process_frame
		t += get_process_delta_time()
