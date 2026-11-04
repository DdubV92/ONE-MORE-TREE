extends Node3D
## Spatial ambience: a small pool of emitters that follow the listener to the
## nearest meaningful sources (shore, river, ponds), intermittent birds in
## nearby trees, camp fire/creaks/room tone, wind in the leaves, footsteps,
## and interior zone filtering. This is a raycast-free zone/filter/reverb
## system, not acoustic simulation.

const OCEAN_EMITTERS := 3
const BIRD_POOL := 4
const STEP_POOL := 4

var _ocean: Array[AudioStreamPlayer3D] = []
var _river: Array[AudioStreamPlayer3D] = []
var _ponds: Array[AudioStreamPlayer3D] = []
var _birds: Array[AudioStreamPlayer3D] = []
var _steps: Array[AudioStreamPlayer] = []
var _last_step := -1
## Relative loudness per surface (files are peak-normalized).
const STEP_DB := {"grass": -25.0, "forest": -23.0, "dirt": -24.0, "sand": -26.0, "rock": -22.0, "wood": -21.0, "water": -21.0}
var _step_i := 0
var _wind: AudioStreamPlayer
var _fire: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _room: Array[AudioStreamPlayer3D] = []
var _shore := PackedVector2Array()
var _streams := {}
var _t_update := 0.0
var _t_bird := 2.0
var _t_creak := 12.0
var _interior := false
var _lp_cutoff := 20000.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("audio_listeners")
	add_to_group("footstep_listeners")
	_rng.seed = 99
	_shore = World.shore_points()
	for k in OCEAN_EMITTERS:
		_ocean.append(_emitter("ocean_surf", "Ambience", 0.0, 30.0, true))
	for k in 2:
		_river.append(_emitter("river", "Ambience", -4.0, 9.0, true))
	for pd in World.ponds():
		var p := _emitter("pond_lap", "Ambience", -6.0, 6.0, true)
		p.position = Vector3(pd.x, float(pd.level) + 0.3, pd.z)
		_ponds.append(p)
	for k in BIRD_POOL:
		_birds.append(_emitter("bird_0", "Ambience", -2.0, 14.0, false))
	# The player's own footsteps are non-positional (centered under the
	# listener, like real footfalls), quiet and varied.
	for k in STEP_POOL:
		var sp := AudioStreamPlayer.new()
		sp.bus = "Characters"
		add_child(sp)
		_steps.append(sp)
	_wind = AudioStreamPlayer.new()
	_wind.stream = _stream("wind_leaves", true)
	_wind.bus = "Ambience"
	_wind.volume_db = -14.0
	add_child(_wind)
	_wind.play()
	var fires := get_tree().get_nodes_in_group("interactable_fire")
	if fires.size() > 0:
		_fire = _emitter("fire_crackle", "Ambience", -1.0, 4.0, true)
		_fire.global_position = (fires[0] as Node3D).global_position + Vector3(0, 0.6, 0)
	_creak = _emitter("metal_creak", "Ambience", -12.0, 5.0, false)
	for z in get_tree().get_nodes_in_group("zones"):
		if z.is_interior:
			var r := _emitter("room_tone", "Ambience", -22.0, 1.5, true)
			r.global_position = (z as Node3D).global_position
			r.max_distance = 7.0
			_room.append(r)


func _stream(name: String, loop: bool) -> AudioStream:
	var key := name + str(loop)
	if _streams.has(key):
		return _streams[key]
	var s: AudioStreamWAV = load("res://audio/generated/%s.wav" % name)
	if s == null:
		push_warning("Missing generated audio %s" % name)
		return null
	if loop:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_streams[key] = s
	return s


func _emitter(stream: String, bus: String, db: float, unit: float, autoplay: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(stream, autoplay)
	p.bus = bus
	p.volume_db = db
	p.unit_size = unit
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.max_distance = unit * 12.0
	p.panning_strength = 1.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(p)
	if autoplay:
		p.play(_rng.randf() * maxf(p.stream.get_length() - 0.1, 0.0) if p.stream else 0.0)
	return p


func _listener_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


## Crackle follows the actual fuel in the pit (quiet coals when empty).
func _update_fire() -> void:
	if _fire == null:
		return
	var fires := get_tree().get_nodes_in_group("interactable_fire")
	if fires.is_empty():
		return
	var lvl: float = fires[0].get("level")
	_fire.volume_db = -1.0 + linear_to_db(clampf(0.12 + 0.75 * lvl, 0.05, 1.3))


func _process(delta: float) -> void:
	var lp := _listener_pos()
	_t_update -= delta
	if _t_update <= 0.0:
		_t_update = 0.4
		_place_ocean(lp)
		_place_river(lp)
		_update_wind(lp)
		_update_fire()
	_t_bird -= delta
	if _t_bird <= 0.0:
		_t_bird = _rng.randf_range(1.5, 7.0)
		_chirp(lp)
	_t_creak -= delta
	if _t_creak <= 0.0:
		_t_creak = _rng.randf_range(18.0, 45.0)
		_creak_somewhere()
	# Interior zone filtering (smoothed): muffled, quieter outdoor ambience.
	var target := 900.0 if _interior else 20000.0
	_lp_cutoff = lerpf(_lp_cutoff, target, clampf(delta * 3.0, 0.0, 1.0))
	var amb := AudioServer.get_bus_index("Ambience")
	var lpf := AudioServer.get_bus_effect(amb, 0) as AudioEffectLowPassFilter
	if lpf:
		lpf.cutoff_hz = _lp_cutoff
	var chars := AudioServer.get_bus_index("Characters")
	var rv := AudioServer.get_bus_effect(chars, 0) as AudioEffectReverb
	if rv:
		rv.wet = lerpf(rv.wet, 0.18 if _interior else 0.0, clampf(delta * 3.0, 0.0, 1.0))


func set_interior(inside: bool, _zone: String) -> void:
	_interior = inside


func _place_ocean(lp: Vector3) -> void:
	# Nearest shore samples, spread apart so the surf comes from a coastline.
	var best: Array = []
	for p in _shore:
		var d := Vector2(lp.x, lp.z).distance_squared_to(p)
		best.append([d, p])
	best.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var chosen: Array[Vector2] = []
	for b in best:
		var p: Vector2 = b[1]
		var ok := true
		for c in chosen:
			if c.distance_to(p) < 40.0:
				ok = false
		if ok:
			chosen.append(p)
		if chosen.size() >= OCEAN_EMITTERS:
			break
	for k in _ocean.size():
		if k < chosen.size():
			_ocean[k].global_position = Vector3(chosen[k].x, 0.5, chosen[k].y)


func _place_river(lp: Vector3) -> void:
	var k := World.nearest_river_index(Vector2(lp.x, lp.z))
	var p := World.river_points[k]
	_river[0].global_position = Vector3(p.x, World.river_levels[k] + 0.3, p.y)
	# Second emitter on the loudest nearby riffle.
	var best := k
	for j in range(maxi(k - 40, 0), mini(k + 40, World.river_points.size())):
		if World.river_rapid[j] > World.river_rapid[best]:
			best = j
	var q := World.river_points[best]
	_river[1].global_position = Vector3(q.x, World.river_levels[best] + 0.3, q.y)
	_river[1].volume_db = lerpf(-14.0, 0.0, World.river_rapid[best])


func _update_wind(lp: Vector3) -> void:
	var ws: float = Game.environment.wind_now if Game.environment else 0.5
	# Leaf noise follows the trees actually left standing nearby, re-counted
	# every update (cleared ground keeps only open-air wind).
	var standing := 0
	var veg: Node = Game.vegetation
	if veg and veg.has_method("standing_trees_near"):
		standing = (veg.call("standing_trees_near", lp, 22.0, 24) as PackedInt32Array).size()
	var forest := clampf(float(standing) / 18.0, 0.15, 1.0)
	_wind.volume_db = linear_to_db(maxf(0.05 + ws * 0.6 * forest, 0.001)) - 8.0


func _chirp(lp: Vector3) -> void:
	if Game.environment and (Game.environment.is_night() or Game.environment.hour < 5.5):
		return
	if _rng.randf() < 0.25:
		return   # leave occasional silence
	# Birds perch only in trees that are still standing (no phantom song
	# from a cleared hillside). Rain keeps most of them quiet.
	if Game.weather and float(Game.weather.get("rain")) > 0.3 and _rng.randf() < 0.8:
		return
	var veg: Node = Game.vegetation
	if veg == null or not veg.has_method("standing_trees_near"):
		return
	var near: PackedInt32Array = veg.call("standing_trees_near", lp, 45.0, 48)
	if near.is_empty():
		return
	for attempt in 1:
		var i: int = near[_rng.randi() % near.size()]
		if true:
			var b: AudioStreamPlayer3D = _birds.pop_front()
			_birds.append(b)
			b.stream = _stream("bird_%d" % (_rng.randi() % 5), false)
			b.pitch_scale = _rng.randf_range(0.9, 1.15)
			b.global_position = World.tree_position(i) + Vector3(0, float(World.trees.height[i]) * 0.75, 0)
			b.play()
			return


func _creak_somewhere() -> void:
	var c := World.camp_origin()
	if Vector2(_listener_pos().x - c.x, _listener_pos().z - c.z).length() > 60.0:
		return
	# A fence post or the camper settling somewhere along the perimeter.
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	_creak.global_position = c + Vector3(_rng.randf_range(-20.0, 20.0), 1.5, 18.5 * side)
	_creak.pitch_scale = _rng.randf_range(0.8, 1.2)
	_creak.play()


func play_footstep(surface: String, pos: Vector3, intensity: float) -> void:
	var p := _steps[_step_i]
	_step_i = (_step_i + 1) % _steps.size()
	var v := _rng.randi() % 5
	if v == _last_step:
		v = (v + 1 + _rng.randi() % 4) % 5   # never the same sample twice in a row
	_last_step = v
	p.stream = _stream("step_%s_%d" % [surface, v], false)
	p.pitch_scale = _rng.randf_range(0.93, 1.07)
	p.volume_db = float(STEP_DB.get(surface, -24.0)) + linear_to_db(intensity) + _rng.randf_range(-1.5, 1.5)
	p.play()
	SoundEvents.emit(p.stream, pos, p.volume_db + 10.0, "steps", "footsteps")
