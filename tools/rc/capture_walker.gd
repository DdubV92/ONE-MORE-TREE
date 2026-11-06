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
	var eye := p.global_position + Vector3(0, 1.65, 0)
	p.teleport(eye, a.global_position + Vector3(0, 1.4, 0))
	Engine.time_scale = 2.0
	g = 0
	while w.flash < 0.35 and g < 3000 and is_instance_valid(a):
		await get_tree().process_frame
		g += 1
		if w.flash > 0.02 or not w._flashes_live.is_empty():
			Engine.time_scale = 0.03
		elif Engine.time_scale < 1.0:
			Engine.time_scale = 2.0
		if g % 40 == 0:
			p.teleport(eye, a.global_position + Vector3(0, 1.4, 0))
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
