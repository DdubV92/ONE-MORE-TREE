extends Node
## Phase 23: screenshot of the Thunder Walker revealed by a flash, taken from
## the prepared save (made by tools/rc/make_fixture_saves.gd, ONLY_FX=
## storm_walker): the encounter is already running there, so a software
## renderer does not have to simulate its approach. Writes nothing back
## (works on a temporary copy, deleted after).
##   xvfb-run godot --rendering-driver vulkan res://tools/rc/capture_walker.tscn

const SRC := "user://fixtures/slot_2_storm_walker.json"
const TMP := "user://fixtures/capture_walker_tmp.json"


func _ready() -> void:
	if not FileAccess.file_exists(SRC):
		print("CAPTURE thunder_walker: no fixture save (run make_fixture_saves first)")
		get_tree().quit(1)
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(SRC), ProjectSettings.globalize_path(TMP))
	SaveService.path_override = TMP
	Game.mode = Game.Mode.CAMPAIGN
	Game.new_game = false
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	var g := 0
	while (Game.crew == null or not world.systems_ready or Game.player == null or Game.storm_terrors == null) and g < 4000:
		await get_tree().process_frame
		g += 1
	Settings.set_v("flash_reduction", "full")
	var st: StormTerrors = Game.storm_terrors
	var w: WeatherService = Game.weather
	var p := Game.player as Player
	for k in 20:
		await get_tree().process_frame
	var a: TerrorActor = null
	for r in st.runs:
		if st._actors.has(r.id):
			a = st._actors[r.id]
	if a == null:
		print("CAPTURE thunder_walker: no figure in the save")
		_done(1)
		return
	# Hold the encounter where the save has it (a software renderer is far
	# too slow to wait for the scheduled strikes), then one near strike from
	# the storm's direction lights the treeline for the shot.
	st.process_mode = Node.PROCESS_MODE_DISABLED
	a.visible = true
	# The nearest standing spot (within 10 m) with a clear view of the
	# figure's head: from where the save stood, camp props can be in the way.
	var head := a.global_position + Vector3(0, 1.6, 0)
	var eye := p.global_position + Vector3(0, 1.65, 0)
	var space := p.get_world_3d().direct_space_state
	var best := eye
	var found := false
	for ring in [0.0, 2.5, 5.0, 7.5, 10.0]:
		for k in (1 if ring == 0.0 else 12):
			var ang := TAU * float(k) / 12.0
			var cand := eye + Vector3(cos(ang), 0, sin(ang)) * float(ring)
			cand.y = World.height_at(cand.x, cand.z) + 1.65
			var q := PhysicsRayQueryParameters3D.create(cand, head)
			var ex: Array[RID] = [p.get_rid()]
			q.exclude = ex
			var hit := space.intersect_ray(q)
			var tries := 0
			# The chain-link fence is see-through (as TerrorPlacement treats it).
			while not hit.is_empty() and (hit.collider as Node).is_in_group("see_through") and tries < 6:
				ex.append((hit.collider as CollisionObject3D).get_rid())
				q.exclude = ex
				hit = space.intersect_ray(q)
				tries += 1
			if hit.is_empty() or (hit.collider as Node).is_ancestor_of(a) or hit.collider == a or a.is_ancestor_of(hit.collider as Node) or (hit.position as Vector3).distance_to(head) < 1.5:
				best = cand
				found = true
				break
		if found:
			break
	eye = best
	print("walker view: clear line of sight %s from %s" % [found, str(eye)])
	p.teleport(eye, head)
	# Peering at the treeline: a narrower view so the figure is not a few
	# pixels at 40 m (the in-game view is wider).
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.fov = 24.0
	for k in 30:
		await get_tree().process_frame
	var off := a.global_position - World.camp_origin()
	var strike := {"id": "CAP-W", "visit": w.visit_id, "day": w.weather_day, "t": w.weather_t, "kind": "near", "off": [off.x * 1.6, off.z * 1.6], "dist": Vector2(off.x, off.z).length() * 1.6, "power": 1.0, "strokes": 3, "seed": 3}
	Engine.time_scale = 0.03
	w.fire(strike)
	g = 0
	while w.flash < 0.5 and g < 400:
		await get_tree().process_frame
		g += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	get_viewport().get_texture().get_image().save_png("res://captures/p23_thunder_walker.png")
	print("CAPTURE thunder_walker %s (flash %.2f, figure %.0f m away, visible %s)" % ["ok" if w.flash >= 0.35 else "no-flash", w.flash, eye.distance_to(a.global_position) if is_instance_valid(a) else -1.0, a.visible if is_instance_valid(a) else false])
	_done(0)


func _done(code: int) -> void:
	Engine.time_scale = 1.0
	SaveService.path_override = ""
	for f in [TMP, TMP + ".bak", TMP + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	get_tree().quit(code)
