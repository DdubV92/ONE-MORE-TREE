extends Node
## Phase 24 soundscape audit: walks the listener along the reported route
## (shore -> inland trail -> thick brush -> camper), lets the ambience settle
## and prints every playing player: what, bus, level, distance and the
## estimated level at the ear (file RMS is added by tools/audio/ambience_rms.py).
## Usage: godot --headless res://tools/audio/ambience_audit.tscn  (AUDIT_OUT=path.json)

var _cam: Camera3D


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	world.build_player = false
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 4000:
		await get_tree().process_frame
		g += 1
	_cam = Camera3D.new()
	world.add_child(_cam)
	_cam.make_current()
	var vps := Viewpoints.all()
	var route := []
	for n in ["beach", "p12_grove", "p12_thicket", "camper"]:
		if vps.has(n):
			route.append([n, vps[n]])
	# Inland trail: halfway between the camp and the forest viewpoint.
	if vps.has("forest"):
		route.insert(1, ["forest", vps.forest])
	var out := {}
	for r in route:
		var vp: Dictionary = r[1]
		_cam.global_position = vp.pos
		_cam.look_at(vp.look)
		for z in get_tree().get_nodes_in_group("audio_listeners"):
			if z.has_method("set_interior"):
				pass
		for f in 240:
			await get_tree().process_frame
		out[r[0]] = _snapshot()
		print("AUDIT ", r[0], " ", JSON.stringify(out[r[0]]))
	var bus := {}
	for i in AudioServer.bus_count:
		bus[AudioServer.get_bus_name(i)] = AudioServer.get_bus_volume_db(i)
	out["_buses"] = bus
	var path := OS.get_environment("AUDIT_OUT") if OS.has_environment("AUDIT_OUT") else "user://ambience_audit.json"
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "  "))
	fa.close()
	print("AUDIT written ", path)
	get_tree().quit()


func _snapshot() -> Array:
	var rows := []
	var lis := _cam.global_position
	for p in _all_players(get_tree().root):
		if not p.playing:
			continue
		var st: AudioStream = p.stream
		var res := st.resource_path if st else ""
		var row := {"node": str(p.get_path()).get_file(), "file": res.get_file(), "bus": p.bus, "vol_db": snappedf(p.volume_db, 0.1)}
		if p is AudioStreamPlayer3D:
			var p3 := p as AudioStreamPlayer3D
			var d := p3.global_position.distance_to(lis)
			var att := 0.0
			if p3.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE:
				att = minf(linear_to_db(p3.unit_size / maxf(d, 0.01)), p3.max_db)
			elif p3.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE:
				att = minf(linear_to_db(pow(p3.unit_size / maxf(d, 0.01), 2.0)), p3.max_db)
			if p3.max_distance > 0.0 and d > p3.max_distance:
				att = -80.0
			row["dist"] = snappedf(d, 0.1)
			row["att_db"] = snappedf(att, 0.1)
			row["ear_db"] = snappedf(p3.volume_db + att + AudioServer.get_bus_volume_db(AudioServer.get_bus_index(p3.bus)), 0.1)
		else:
			row["ear_db"] = snappedf(p.volume_db + AudioServer.get_bus_volume_db(AudioServer.get_bus_index(p.bus)), 0.1)
		var sv := SoundService.instance()
		if sv:
			for v in sv.voices + sv.loops.values():
				if v.p == p:
					row["event"] = v.event
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.ear_db) > float(b.ear_db))
	return rows


func _all_players(n: Node) -> Array:
	var out := []
	if n is AudioStreamPlayer or n is AudioStreamPlayer3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_players(c))
	return out
