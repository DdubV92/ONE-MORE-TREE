extends Node3D
## Spatial ambience: a small pool of emitters that follow the listener to the
## nearest meaningful sources (shore, river, ponds), intermittent birds in
## nearby standing trees, the fire by its real fuel, wind keyed to the
## vegetation actually standing around you, night insects/frogs/owls, the
## camper's domestic hum and footsteps.
## Phase 15: every emitter is a SoundService voice with its own occlusion
## (walls, doors, glass, rock, terrain) - there is no longer a shared
## "interior" low-pass on the whole Ambience bus, so indoor sounds stay
## clear while the surf outside is muffled by the actual camper walls.

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
		_ocean_m.append(_marker("Surf%d" % k))
	for k in 2:
		_river_m.append(_marker("River%d" % k))
	for pd in World.ponds():
		var pm := _marker("Pond")
		pm.position = Vector3(pd.x, float(pd.level) + 0.3, pd.z)
		_pond_m.append(pm)
	for k in 2:
		_wind_m.append(_marker("Wind%d" % k))
	_bed_m = _marker("AirBed")
	# The player's own footsteps are non-positional (centered under the
	# listener, like real footfalls), quiet and varied.
	for k in STEP_POOL:
		var sp := AudioStreamPlayer.new()
		sp.bus = "Characters"
		add_child(sp)
		_steps.append(sp)
	var fires := get_tree().get_nodes_in_group("interactable_fire")
	if fires.size() > 0:
		_fire_m = _marker("Fire")
		_fire_m.global_position = (fires[0] as Node3D).global_position + Vector3(0, 0.6, 0)
	# Domestic hum at the camper kitchen (fridge) and desk (computer fan).
	for z in get_tree().get_nodes_in_group("zones"):
		if z.is_interior and str(z.zone_name).begins_with("camper"):
			var fm := _marker("Fridge")
			fm.global_position = (z as Node3D).global_position + Vector3(0.9, -0.3, -1.5)
			_loop("home.fridge", fm, 0.0)
			var dk := get_tree().get_nodes_in_group("camper_monitor")
			if not dk.is_empty():
				var fan := _marker("PCFan")
				fan.global_position = (dk[0] as Node3D).global_position + Vector3(0, -0.4, 0)
				_loop("home.fan", fan, 0.0)


# ------------------------------------------------- Phase 15 emitters

var _ocean_m: Array[Marker3D] = []
var _river_m: Array[Marker3D] = []
var _pond_m: Array[Marker3D] = []
var _wind_m: Array[Marker3D] = []
var _bed_m: Marker3D
var _fire_m: Marker3D
var _loops := {}            # key -> handle
var _wind_kind := ""
var _night_t := 6.0


func _marker(n: String) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	add_child(m)
	return m


## Ensures a named loop runs (or is stopped when lin <= 0).
func _layer(key: String, event: String, at: Node3D, db: float, on := true) -> void:
	var h := int(_loops.get(key, 0))
	if not on:
		if h != 0:
			SoundService.loop_stop(h, 0.8)
			_loops.erase(key)
		return
	if h == 0 or not SoundService.is_playing(h):
		h = SoundService.loop(event, at, {"gain": db})
		_loops[key] = h
	SoundService.loop_set(h, db)


func _loop(event: String, at: Node3D, db: float) -> void:
	_layer(event + str(at.get_instance_id()), event, at, db)


func _update_emitters(lp: Vector3) -> void:
	if SoundService.instance() == null:
		return
	var night: bool = Game.environment != null and Game.environment.is_night()
	# Surf on the nearest stretches of real coastline.
	for k in _ocean_m.size():
		_layer("surf%d" % k, "amb.surf.near", _ocean_m[k], 0.0, _ocean_m[k].position != Vector3.ZERO)
	# Rivers: the nearest reach (slow) and the loudest nearby riffle (fast).
	if _river_m.size() == 2 and World.river_points.size() > 0:
		_layer("river0", "amb.river.slow", _river_m[0], 0.0)
		_layer("river1", "amb.river.fast", _river_m[1], _river_db)
	# Ponds; frogs at the water's edge after dark.
	for k in _pond_m.size():
		var near := _pond_m[k].global_position.distance_to(lp) < 160.0
		_layer("pond%d" % k, "amb.pond", _pond_m[k], 0.0, near)
		_layer("frogs%d" % k, "amb.frogs", _pond_m[k], -2.0, near and night)
	# Wind in what is actually standing around you.
	var standing := 0
	var birch := 0
	var veg: Node = Game.vegetation
	if veg and veg.has_method("standing_trees_near"):
		var near_t: PackedInt32Array = veg.call("standing_trees_near", lp, 22.0, 24)
		standing = near_t.size()
		for i in near_t:
			if int(World.trees.species[i]) == 2:
				birch += 1
	var kind := "amb.wind.cleared" if standing < 4 else ("amb.wind.birch" if birch * 2 > standing else "amb.wind.pines")
	var ws: float = Game.environment.wind_now if Game.environment else 0.5
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var right := cam.global_basis.x if cam else Vector3.RIGHT
	right.y = 0.0
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	_wind_m[0].global_position = lp + right * 9.0 + Vector3(0, 4.0, 0)
	_wind_m[1].global_position = lp - right * 9.0 + Vector3(0, 4.0, 0)
	if kind != _wind_kind:
		for k in 2:
			_layer("wind%d" % k, "", null, 0.0, false)
		_wind_kind = kind
	var wdb := linear_to_db(maxf(0.08 + ws * 0.7, 0.001))
	for k in 2:
		_layer("wind%d" % k, kind, _wind_m[k], wdb)
	# A quiet air bed: forest room tone under canopy, open-field air when cleared.
	_bed_m.global_position = lp + Vector3(0, 2.0, 0)
	_layer("bed_forest", "amb.forest.air", _bed_m, 0.0, standing >= 4)
	_layer("bed_field", "amb.field.air", _bed_m, 0.0, standing < 4)
	# Day insects in good weather; crickets at night (not in rain).
	var raining: bool = Game.weather != null and float(Game.weather.get("rain")) > 0.3
	_layer("insects", "amb.insects.day", _bed_m, -4.0, not night and not raining and standing >= 2)
	_layer("crickets", "amb.crickets", _bed_m, -2.0, night and not raining)
	_update_fire_v2()


var _river_db := 0.0


func _update_fire_v2() -> void:
	if _fire_m == null:
		return
	var fires := get_tree().get_nodes_in_group("interactable_fire")
	if fires.is_empty():
		return
	var lvl: float = fires[0].get("level")
	# Fuel decides the voice: embers only, a small bed or a big one.
	_layer("fire_small", "fire.bed.small", _fire_m, linear_to_db(clampf(lvl * 2.0, 0.0, 1.0)), lvl > 0.02)
	_layer("fire_large", "fire.bed.large", _fire_m, linear_to_db(clampf((lvl - 0.6) * 1.5, 0.0, 1.0)), lvl > 0.6)
	if lvl > 0.05 and _rng.randf() < 0.04 + 0.12 * lvl:
		SoundService.play("fire.pop", _fire_m.global_position + Vector3(_rng.randf_range(-0.4, 0.4), 0.1, _rng.randf_range(-0.4, 0.4)), {"emit": false})


func _night_detail(lp: Vector3) -> void:
	var env: EnvironmentController = Game.environment
	if env == null or not env.is_night():
		return
	var veg: Node = Game.vegetation
	if veg == null or not veg.has_method("standing_trees_near"):
		return
	var near: PackedInt32Array = veg.call("standing_trees_near", lp, 70.0, 48)
	if near.is_empty():
		return
	var i: int = near[_rng.randi() % near.size()]
	var at := World.tree_position(i) + Vector3(0, float(World.trees.height[i]) * 0.7, 0)
	if _rng.randf() < 0.55:
		SoundService.play("amb.owl", at)
	else:
		SoundService.play("amb.branch.far", at)


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


# ------------------------------------------------------------ music
## Sparse original daytime phrases (synthesized plucks): one every few
## minutes in good daylight, never at night, during the hunt or in heavy
## rain; one soft dusk pad eases the day out (it does not announce danger).
var _music: AudioStreamPlayer
var _t_music := 75.0
var _dusk_played_hour := -1.0
var music_plays := 0


func _update_music(delta: float) -> void:
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = "Music"
		add_child(_music)
	var env: EnvironmentController = Game.environment
	if env == null:
		return
	var hunting: bool = Game.hunt != null and bool(Game.hunt.call("hunt_active"))
	var raining: bool = Game.weather != null and float(Game.weather.get("rain")) > 0.4
	var on: bool = bool(Settings.get_v("music")) and not hunting
	var h := env.hour
	if not on or env.is_night():
		if _music.playing:
			_music.volume_db = move_toward(_music.volume_db, -60.0, delta * 12.0)
			if _music.volume_db <= -59.0:
				_music.stop()
		return
	# Dusk: once, as the light turns.
	if h >= 18.1 and h < 19.5:
		if _dusk_played_hour < 0.0 and not _music.playing:
			_dusk_played_hour = h
			_music.stream = _stream("music_dusk", false)
			_music.volume_db = -16.0
			_music.play()
			music_plays += 1
		return
	if h < 18.0:
		_dusk_played_hour = -1.0
	if h < 7.0 or raining:
		return
	_t_music -= delta
	if _t_music <= 0.0 and not _music.playing:
		_t_music = _rng.randf_range(150.0, 320.0)
		_music.stream = _stream("music_day_%d" % (_rng.randi() % 3), false)
		_music.volume_db = -13.0
		_music.play()
		music_plays += 1


func _process(delta: float) -> void:
	_update_music(delta)
	var lp := _listener_pos()
	_t_update -= delta
	if _t_update <= 0.0:
		_t_update = 0.4
		_place_ocean(lp)
		_place_river(lp)
		_update_emitters(lp)
		_update_hollow(lp)
	_night_t -= delta
	if _night_t <= 0.0:
		_night_t = _rng.randf_range(25.0, 70.0)      # long quiet intervals
		_night_detail(lp)
	_t_bird -= delta
	if _t_bird <= 0.0:
		_t_bird = _rng.randf_range(1.5, 7.0)
		_chirp(lp)
	_t_creak -= delta
	if _t_creak <= 0.0:
		_t_creak = _rng.randf_range(18.0, 45.0)
		_creak_somewhere()
	# Phase 15: no whole-bus interior filter any more (per-source occlusion
	# does it); the bus effects stay neutral.
	var target := 20000.0
	_lp_cutoff = lerpf(_lp_cutoff, target, clampf(delta * 3.0, 0.0, 1.0))
	var amb := AudioServer.get_bus_index("Ambience")
	var lpf := AudioServer.get_bus_effect(amb, 0) as AudioEffectLowPassFilter
	if lpf:
		lpf.cutoff_hz = _lp_cutoff
	var chars := AudioServer.get_bus_index("Characters")
	var rv := AudioServer.get_bus_effect(chars, 0) as AudioEffectReverb
	if rv:
		# Modest room response indoors (camper small, cabin larger), a
		# restrained echo only in an enclosed rocky hollow, dry woodland and
		# shore everywhere else. A zone/filter model, not simulated acoustics.
		# Rooms now come from the zones' own reverb buses (only the sources
		# inside them); only the rocky hollow keeps this restrained echo.
		var want_wet := 0.0
		var want_room := 0.25
		if _hollow > 0.5 and not _interior:
			want_wet = 0.07
			want_room = 0.62
		var k := clampf(delta * 3.0, 0.0, 1.0)
		rv.wet = lerpf(rv.wet, want_wet, k)
		rv.room_size = lerpf(rv.room_size, want_room, k)


var _zone_name := ""
var _hollow := 0.0


## 1 when the listener stands in a rocky, enclosed hollow (terrain rising
## > 3 m on most sides within 14 m), sampled with the slow update.
func _update_hollow(lp: Vector3) -> void:
	var h0 := World.height_at(lp.x, lp.z)
	var rising := 0
	for k in 8:
		var a := TAU * k / 8.0
		if World.height_at(lp.x + cos(a) * 14.0, lp.z + sin(a) * 14.0) - h0 > 3.0:
			rising += 1
	var rocky := World.surface_at(lp.x, lp.z) == World.Surface.ROCK
	_hollow = 1.0 if rising >= 6 and rocky else 0.0


func set_interior(inside: bool, zone: String) -> void:
	_interior = inside
	_zone_name = zone


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
	for k in _ocean_m.size():
		if k < chosen.size():
			_ocean_m[k].global_position = Vector3(chosen[k].x, 0.5, chosen[k].y)


func _place_river(lp: Vector3) -> void:
	var k := World.nearest_river_index(Vector2(lp.x, lp.z))
	var p := World.river_points[k]
	_river_m[0].global_position = Vector3(p.x, World.river_levels[k] + 0.3, p.y)
	# Second emitter on the loudest nearby riffle.
	var best := k
	for j in range(maxi(k - 40, 0), mini(k + 40, World.river_points.size())):
		if World.river_rapid[j] > World.river_rapid[best]:
			best = j
	var q := World.river_points[best]
	_river_m[1].global_position = Vector3(q.x, World.river_levels[best] + 0.3, q.y)
	_river_db = lerpf(-14.0, 0.0, World.river_rapid[best])


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
			var at := World.tree_position(i) + Vector3(0, float(World.trees.height[i]) * 0.75, 0)
			SoundService.play("amb.bird.day", at, {"emit": false})
			return


func _creak_somewhere() -> void:
	var c := World.camp_origin()
	if Vector2(_listener_pos().x - c.x, _listener_pos().z - c.z).length() > 60.0:
		return
	# A fence post or the camper settling somewhere along the perimeter.
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	SoundService.play("camp.fence.rattle", c + Vector3(_rng.randf_range(-20.0, 20.0), 1.0, 18.5 * side), {"db": -8.0, "emit": false})


## Other people's footsteps (workers): positional, quieter than your own,
## a bounded pool of 6 voices, culled beyond 28 m so a busy camp never
## becomes a wall of steps and distant crews stay silent.
const CROWD_POOL := 6
const CROWD_RANGE := 28.0
var _crowd: Array[AudioStreamPlayer3D] = []
var _crowd_i := 0
var crowd_steps := 0


func play_crowd_step(pos: Vector3, speed: float) -> void:
	if pos.distance_to(_listener_pos()) > CROWD_RANGE:
		return
	if _crowd.is_empty():
		for k in CROWD_POOL:
			var e := AudioStreamPlayer3D.new()
			e.bus = "Characters"
			e.unit_size = 2.5
			e.max_distance = CROWD_RANGE + 4.0
			e.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			add_child(e)
			_crowd.append(e)
	var surf := "grass"
	match World.surface_at(pos.x, pos.z):
		World.Surface.SAND: surf = "sand"
		World.Surface.DIRT: surf = "dirt"
		World.Surface.ROCK: surf = "rock"
		World.Surface.FOREST: surf = "forest"
		World.Surface.WATER: surf = "water"
	# On decks, floors and bridges (well above the terrain) it is wood.
	if pos.y > World.height_at(pos.x, pos.z) + 0.25:
		surf = "wood"
	var p := _crowd[_crowd_i]
	_crowd_i = (_crowd_i + 1) % _crowd.size()
	p.stream = _stream("step_%s_%d" % [surf, _rng.randi() % 5], false)
	p.global_position = pos + Vector3(0, 0.05, 0)
	p.volume_db = float(STEP_DB.get(surf, -24.0)) + 10.0 + (2.0 if speed > 2.0 else 0.0)
	p.pitch_scale = _rng.randf_range(0.9, 1.06)
	p.play()
	crowd_steps += 1


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
