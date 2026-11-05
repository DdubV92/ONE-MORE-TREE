class_name SoundService
extends Node3D
## Phase 15: the one native sound-event service (Godot positional players,
## buses and Area3D rooms - no middleware). Gameplay asks for stable event
## IDs (SoundBank) at a position or attached to a node; this service owns
## every resulting voice from start to stop.
##
## Origin kinds keep sources honest and loops impossible:
##   WORLD     real physical emission: positional, occluded, heard by the
##             camera microphones (SoundEvents) and recorded for replay;
##   INTERNAL  an authored psychological cue (no position in the world, no
##             microphones, no AI hearing, never recorded);
##   RELAY     camera audio coming out of the desk speakers (a local source
##             at the speakers; never re-captured: hop limit 1);
##   RECORDING replayed historical sound at the desk speakers (no live
##             evidence, no capture, no recorder entry);
##   UI, MUSIC non-positional, never captured.
## Playing a sound never performs work, payment, cargo or merit: callers
## commit their result first, then ask for its sound. A missing or stolen
## voice never cancels the result.
##
## Per-source occlusion (not a whole-bus filter): a few rays from the
## listener to each audible source sum the acoustic loss of what they cross
## (collider meta "acoustic": wood, door, glass, metal, rock, terrain,
## trunk, fabric). The clearest of the rays wins. If the listener and the
## source are on different sides of a zone boundary and an open door gives a
## better path, the sound comes THROUGH the doorway (its emitted position is
## pulled toward the opening, bounded) with a small indirect loss. The loss
## sets a smoothed volume drop and an occlusion tier: the source routes
## itself to "<bus>_O1" (low-pass 2.4 kHz) or "<bus>_O2" (750 Hz), switching
## through a 60 ms dip so nothing zippers. This is a ray/portal
## approximation, not diffraction or a wave solver.
##
## Rooms: the camper/cabin InteriorZones send the sources inside them to
## short reverb buses (RoomCamper/RoomCabin); rocky hollows use RockHollow.
## Distance: per-class unit size / max distance / near-field cap (SoundBank
## CAL). Far transients (> 40 m) arrive after distance / 343 s; the queue
## only advances while the game runs (pause never bursts them out later).

enum Origin { WORLD, INTERNAL, RELAY, RECORDING, UI, MUSIC }
const ORIGIN_NAMES := ["world", "internal", "relay", "recording", "ui", "music"]
const POOL := 40
const MAX_LOOPS := 40
const OCC_PER_FRAME := 8
const OCC_INTERVAL := 0.2
const SPEED_OF_SOUND := 343.0
const DELAY_MIN_DIST := 40.0
const MATERIAL_DB := {"wood": 13.0, "door": 10.0, "glass": 7.0, "metal": 16.0, "rock": 22.0, "terrain": 20.0, "trunk": 4.0, "fabric": 5.0}
const RECORD_RING := 300


class Voice:
	var p: AudioStreamPlayer3D
	var handle := 0
	var event := ""
	var file := ""
	var origin := 0
	var attach: Node3D = null
	var attached := false          # a freed owner compares == null: track it
	var offset := Vector3.ZERO
	var pos := Vector3.ZERO
	var loop := false
	var base_db := 0.0
	var gain_db := 0.0
	var occ_db := 0.0
	var occ_target := 0.0
	var tier := 0
	var tier_want := 0
	var switch_t := -1.0
	var portal := Vector3.INF
	var portal_w := 0.0
	var next_occ := 0.0
	var busy := false
	var base_bus := "Work"
	var priority := 1
	var stopping := false
	var stop_fade := 0.0
	var fade_db := 0.0
	var max_dist := 100.0


static var _inst: SoundService
var voices: Array = []
var loops := {}               # handle -> Voice
var _handle := 0
var _delayed: Array = []      # [seconds_left, event, pos, opts]
var _recent := {}             # event -> [msec, pos]
var _last_file := {}          # event -> file (no immediate repeat)
var _streams := {}
var _occ_i := 0
var _rng := RandomNumberGenerator.new()
var recorder: Array = []
var stats := {"played": 0, "debounced": 0, "delayed": 0, "stolen": 0, "occ_checks": 0, "loops_started": 0, "loops_stopped": 0, "missing": 0, "portal_paths": 0}


func _ready() -> void:
	_inst = self
	name = "SoundService"
	_rng.seed = 1515
	for i in POOL:
		var v := Voice.new()
		v.p = _make_player()
		voices.append(v)


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


static func instance() -> SoundService:
	return _inst if _inst != null and is_instance_valid(_inst) else null


func _make_player() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	p.panning_strength = 1.0
	p.attenuation_filter_cutoff_hz = 9000.0
	p.attenuation_filter_db = -8.0
	p.area_mask = 1 << 19          # interior zones' room response only
	add_child(p)
	return p


# ------------------------------------------------------------------ API

## One-shot. `at`: a world Vector3 or a Node3D to follow. Returns a handle
## (0 if debounced/missing). opts: origin, db, pitch, file, priority,
## no_delay, label, emit (camera mics; default world only), offset.
static func play(event: String, at: Variant, opts := {}) -> int:
	var s := instance()
	return s._play(event, at, opts, false) if s else 0


## Looping source with an explicit lifecycle (loop_set / loop_stop).
static func loop(event: String, at: Variant, opts := {}) -> int:
	var s := instance()
	return s._play(event, at, opts, true) if s else 0


static func loop_set(handle: int, db := 0.0, pitch := -1.0) -> void:
	var s := instance()
	if s == null or not s.loops.has(handle):
		return
	var v: Voice = s.loops[handle]
	v.gain_db = db
	if pitch > 0.0:
		v.p.pitch_scale = pitch


static func loop_stop(handle: int, fade_s := 0.12) -> void:
	var s := instance()
	if s == null or not s.loops.has(handle):
		return
	var v: Voice = s.loops[handle]
	v.stopping = true
	v.stop_fade = maxf(fade_s, 0.01)


static func is_playing(handle: int) -> bool:
	var s := instance()
	if s == null:
		return false
	if s.loops.has(handle):
		return true
	for v in s.voices:
		if (v as Voice).busy and (v as Voice).handle == handle:
			return true
	return false


## Stops every voice attached to `node` (actor removed, tool stowed).
static func stop_attached(node: Node) -> int:
	var s := instance()
	if s == null:
		return 0
	var n := 0
	for h in s.loops.keys():
		var v: Voice = s.loops[h]
		if v.attach == node:
			s._free_loop(h)
			n += 1
	for v in s.voices:
		if (v as Voice).busy and (v as Voice).attach == node:
			s._release(v)
			n += 1
	return n


static func active_count() -> Dictionary:
	var s := instance()
	if s == null:
		return {"oneshots": 0, "loops": 0}
	var n := 0
	for v in s.voices:
		if (v as Voice).busy:
			n += 1
	return {"oneshots": n, "loops": s.loops.size(), "delayed": s._delayed.size()}


# ------------------------------------------------------------- internals

func _stream(path: String, loop_it: bool) -> AudioStream:
	var key := path + ("#L" if loop_it else "")
	if _streams.has(key):
		return _streams[key]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if loop_it:
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV:
			s = s.duplicate()
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	_streams[key] = s
	return s


func _pick_file(event: String, def: Dictionary, force := "") -> String:
	if force != "":
		return force
	var files: Array = def.files
	if files.size() == 1:
		return str(files[0])
	var last := str(_last_file.get(event, ""))
	var f := str(files[_rng.randi() % files.size()])
	var guard := 0
	while f == last and guard < 6:
		f = str(files[_rng.randi() % files.size()])
		guard += 1
	_last_file[event] = f
	return f


func _listener() -> Vector3:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	return cam.global_position if cam else Vector3.ZERO


func _play(event: String, at: Variant, opts: Dictionary, as_loop: bool) -> int:
	var def: Dictionary = SoundBank.EVENTS.get(event, {})
	if def.is_empty():
		stats.missing += 1
		push_warning("SoundService: unknown event %s" % event)
		return 0
	var origin := int(opts.get("origin", Origin.WORLD))
	var pos: Vector3 = (at as Node3D).global_position if at is Node3D else (at if at is Vector3 else _listener())
	# Debounce: one physical event, not a burst over several frames.
	var deb := int(def.get("debounce_ms", 0))
	if deb > 0 and not as_loop:
		var now := Time.get_ticks_msec()
		var r: Array = _recent.get(event, [])
		if not r.is_empty() and now - int(r[0]) < deb and (r[1] as Vector3).distance_to(pos) < 2.0:
			stats.debounced += 1
			return 0
		_recent[event] = [now, pos]
	var cal: Dictionary = SoundBank.CAL.get(str(def.get("cal", "contact")), SoundBank.CAL.contact)
	# Far transients travel: they start after distance / 343 s.
	if not as_loop and origin == Origin.WORLD and bool(cal.get("delay", false)) and not bool(opts.get("no_delay", false)) and not opts.has("_delayed"):
		var d := pos.distance_to(_listener())
		if d > DELAY_MIN_DIST:
			var o2 := opts.duplicate()
			o2["_delayed"] = true
			_delayed.append([d / SPEED_OF_SOUND, event, at if at is Node3D else pos, o2])
			stats.delayed += 1
			return -1
	var file := _pick_file(event, def, str(opts.get("file", "")))
	var path := SoundBank.path_of(file)
	var stream := _stream(path, as_loop or bool(def.get("loop", false)))
	if stream == null:
		stats.missing += 1
		return 0
	var v: Voice
	if as_loop:
		if loops.size() >= MAX_LOOPS:
			return 0
		v = Voice.new()
		v.p = _make_player()
	else:
		v = _free_voice(int(opts.get("priority", 1)), pos)
		if v == null:
			return 0
	_handle += 1
	v.handle = _handle
	v.event = event
	v.file = file
	v.origin = origin
	v.attach = at if at is Node3D else null
	v.attached = at is Node3D
	v.offset = opts.get("offset", Vector3.ZERO)
	v.pos = pos
	v.loop = as_loop
	v.base_db = float(def.get("db", 0.0)) + float(opts.get("db", 0.0))
	v.gain_db = float(opts.get("gain", 0.0))     # loop control level (loop_set)
	v.base_bus = str(opts.get("bus", def.get("bus", "Work")))
	v.priority = int(opts.get("priority", 1))
	v.busy = true
	v.stopping = false
	v.fade_db = -30.0 if as_loop else 0.0
	v.tier = 0
	v.tier_want = 0
	v.switch_t = -1.0
	v.occ_db = 0.0
	v.occ_target = 0.0
	v.portal = Vector3.INF
	v.portal_w = 0.0
	v.max_dist = float(cal.max)
	var p := v.p
	p.stream = stream
	p.bus = v.base_bus
	p.unit_size = float(cal.unit)
	p.max_distance = float(cal.max)
	p.max_db = float(cal.max_db)
	var pr: Array = def.get("pitch", [1.0, 1.0])
	p.pitch_scale = float(opts.get("pitch", _rng.randf_range(float(pr[0]), float(pr[1]))))
	p.global_position = pos + v.offset
	if origin in [Origin.INTERNAL, Origin.UI, Origin.MUSIC]:
		# Non-positional: place at the listener (centred), no occlusion.
		p.global_position = _listener()
		p.panning_strength = 0.0
	else:
		p.panning_strength = 1.0
		_occlude(v)          # first estimate before the first sample plays
		v.occ_db = v.occ_target
		v.tier = v.tier_want
		p.bus = _tier_bus(v.base_bus, v.tier)
	p.volume_db = v.base_db + v.gain_db - v.occ_db + v.fade_db
	p.play(_rng.randf() * maxf(stream.get_length() - 0.2, 0.0) if as_loop else 0.0)
	stats.played += 1
	if as_loop:
		loops[v.handle] = v
		stats.loops_started += 1
	if origin == Origin.WORLD:
		_record(v, def)
		# Environment (surf, wind, rain, thunder, birds) is not evidence: the
		# Foreman/dog/camera registry only hears what something DID, unless an
		# event opts in. Ambience-bus events default to no emit.
		if bool(opts.get("emit", def.get("emit", v.base_bus != "Ambience"))):
			SoundEvents.emit(stream, pos, v.base_db, v.base_bus.to_lower(), str(opts.get("label", def.get("label", ""))), "world")
	return v.handle


func _free_voice(prio: int, pos: Vector3) -> Voice:
	for v in voices:
		if not (v as Voice).busy:
			return v
	# Steal the least important, farthest one-shot.
	var lis := _listener()
	var worst: Voice = null
	var ws := INF
	for v in voices:
		var vv := v as Voice
		var score := float(vv.priority) * 100.0 - vv.p.global_position.distance_to(lis)
		if score < ws:
			ws = score
			worst = vv
	if worst != null and float(worst.priority) * 100.0 - worst.p.global_position.distance_to(lis) <= float(prio) * 100.0 - pos.distance_to(lis):
		stats.stolen += 1
		_release(worst)
		return worst
	return null


func _release(v: Voice) -> void:
	v.p.stop()
	v.busy = false
	v.attach = null
	v.attached = false


func _free_loop(h: int) -> void:
	var v: Voice = loops[h]
	v.p.stop()
	v.p.queue_free()
	loops.erase(h)
	stats.loops_stopped += 1


func _tier_bus(base: String, tier: int) -> String:
	if tier <= 0 or not base in Settings.OCCLUDABLE:
		return base
	return "%s_O%d" % [base, tier]


func _record(v: Voice, def: Dictionary) -> void:
	recorder.append({"t": Game.world_time, "event": v.event, "file": v.file, "pos": [v.pos.x, v.pos.y, v.pos.z], "db": v.base_db, "origin": ORIGIN_NAMES[v.origin]})
	if recorder.size() > RECORD_RING:
		recorder.pop_front()


func _process(delta: float) -> void:
	# Travel-delayed transients (advance only while the game runs).
	for i in range(_delayed.size() - 1, -1, -1):
		var d: Array = _delayed[i]
		d[0] = float(d[0]) - delta
		if float(d[0]) <= 0.0:
			_delayed.remove_at(i)
			var at: Variant = d[2]
			if at is Node3D and not is_instance_valid(at):
				continue
			_play(str(d[1]), at, d[3], false)
	var lis := _listener()
	for v in voices:
		var vv := v as Voice
		if vv.busy:
			if not vv.p.playing:
				_release(vv)
				continue
			_update_voice(vv, delta, lis)
	for h in loops.keys():
		var lv: Voice = loops[h]
		if lv.attached and not is_instance_valid(lv.attach):
			_free_loop(h)          # owner gone: never an orphan loop
			continue
		if lv.stopping:
			lv.fade_db -= delta * 60.0 / lv.stop_fade
			if lv.fade_db <= -60.0:
				_free_loop(h)
				continue
		else:
			lv.fade_db = move_toward(lv.fade_db, 0.0, delta * 200.0)
		_update_voice(lv, delta, lis)
	# Round-robin occlusion updates.
	var all := voices.filter(func(x: Voice) -> bool: return x.busy) + loops.values()
	if all.is_empty():
		return
	var checks := 0
	var now := Time.get_ticks_msec() / 1000.0
	for k in all.size():
		_occ_i = (_occ_i + 1) % all.size()
		var ov: Voice = all[_occ_i]
		if now >= ov.next_occ:
			ov.next_occ = now + OCC_INTERVAL
			_occlude(ov)
			checks += 1
			if checks >= OCC_PER_FRAME:
				break


func _update_voice(v: Voice, delta: float, lis: Vector3) -> void:
	if v.attached and is_instance_valid(v.attach):
		v.pos = v.attach.global_position + v.offset
	if v.origin in [Origin.INTERNAL, Origin.UI, Origin.MUSIC]:
		v.p.global_position = lis
	else:
		var emit_at := v.pos
		if v.portal != Vector3.INF:
			emit_at = v.pos.lerp(v.portal, v.portal_w)
		v.p.global_position = emit_at
	v.occ_db = move_toward(v.occ_db, v.occ_target, delta * 30.0)
	var dip := 0.0
	if v.tier_want != v.tier:
		if v.switch_t < 0.0:
			v.switch_t = 0.0
		v.switch_t += delta
		dip = -36.0 * clampf(v.switch_t / 0.03, 0.0, 1.0)
		if v.switch_t >= 0.03:
			v.tier = v.tier_want
			v.p.bus = _tier_bus(v.base_bus, v.tier)
			v.switch_t = -0.03
	elif v.switch_t < 0.0 and v.switch_t > -1.0:
		v.switch_t = minf(v.switch_t + delta, 0.0)
		dip = -36.0 * clampf(-v.switch_t / 0.03, 0.0, 1.0)
		if v.switch_t >= 0.0:
			v.switch_t = -1.0
	v.p.volume_db = v.base_db + v.gain_db - v.occ_db + v.fade_db + dip


## Occlusion + portal estimate for one voice (sets occ_target/tier_want).
func _occlude(v: Voice) -> void:
	stats.occ_checks += 1
	if v.origin in [Origin.INTERNAL, Origin.UI, Origin.MUSIC]:
		v.occ_target = 0.0
		v.tier_want = 0
		return
	var lis := _listener()
	var src := v.pos
	var d := lis.distance_to(src)
	if d > v.max_dist * 1.1 or d < 0.5:
		v.occ_target = 0.0
		v.tier_want = 0
		v.portal = Vector3.INF
		return
	var direct := path_loss(lis, src)
	var best := direct
	v.portal = Vector3.INF
	v.portal_w = 0.0
	var zl := zone_at(lis)
	var zs := zone_at(src)
	if zl != zs:
		for door in get_tree().get_nodes_in_group("doors"):
			var dr := door as Door
			if dr == null or not dr.is_open:
				continue
			var z: Node = zl if zl != null else zs
			if z == null or (z as Node3D).global_position.distance_to(dr.global_position) > 12.0:
				continue
			var dp := dr.global_position + dr.global_basis.x * dr.width * 0.5 + Vector3(0, 1.0, 0)
			var extra := lis.distance_to(dp) + dp.distance_to(src) - d
			var ind := 3.0 + extra * 0.4 + path_loss(lis, dp, [dr]) + path_loss(dp, src, [dr])
			if ind < best:
				best = ind
				v.portal = dp
				v.portal_w = clampf((direct - ind) / 15.0, 0.0, 0.85)
				stats.portal_paths += 1
	v.occ_target = clampf(best * 0.65, 0.0, 30.0)
	v.tier_want = 0 if best < 4.0 else (1 if best < 13.0 else 2)


## Summed acoustic loss (dB) of the clearest of three rays from a to b.
func path_loss(a: Vector3, b: Vector3, ignore: Array = []) -> float:
	var space := get_world_3d().direct_space_state
	var dir := (b - a)
	var side := dir.cross(Vector3.UP).normalized() * 0.45
	if side.length() < 0.01:
		side = Vector3.RIGHT * 0.45
	var best := INF
	for off in [Vector3.ZERO, Vector3(0, 0.5, 0), side]:
		var loss := 0.0
		var excl: Array[RID] = []
		for n in ignore:
			var body: Object = (n as Door)._panel if n is Door else n
			if body is CollisionObject3D:
				excl.append((body as CollisionObject3D).get_rid())
		var from: Vector3 = a + off
		var to: Vector3 = b + off * 0.5
		for hop in 3:
			var q := PhysicsRayQueryParameters3D.create(from, to, 1)
			q.exclude = excl
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var col: Object = hit.collider
			loss += _material_loss(col)
			if col is CollisionObject3D:
				excl.append((col as CollisionObject3D).get_rid())
		best = minf(best, loss)
		if best <= 0.0:
			break
	return best


func _material_loss(col: Object) -> float:
	var n := col as Node
	if n == null:
		return 12.0
	var m := str(n.get_meta("acoustic", ""))
	if m == "" and n.get_parent() and n.get_parent().has_meta("acoustic"):
		m = str(n.get_parent().get_meta("acoustic"))
	if m == "" and n.has_meta("worker_id"):
		return 1.0                      # a person in the way
	return float(MATERIAL_DB.get(m, 12.0))


## The interior zone containing p (null = outdoors).
func zone_at(p: Vector3) -> Node:
	for z in get_tree().get_nodes_in_group("zones"):
		if z.get("is_interior") and z.has_method("contains_point") and z.contains_point(p):
			return z
	return null


# ------------------------------------------------------------------ speech

## Phase 17/18 interface (reserved, working): a line for a speaker with a
## voice profile. line = {"id", "voice", "text", "priority", "delivery"}.
## Plays res://audio/voice/<voice>/<id>.ogg at the speaker's mouth when the
## file exists (none are produced yet: returns 0 and plays nothing - the
## caller keeps its subtitle). Never a temporary beep standing in for a bank.
static func speak(actor: Node3D, line: Dictionary) -> float:
	var s := instance()
	var path := "res://audio/voice/%s/%s.ogg" % [str(line.get("voice", "")), str(line.get("id", ""))]
	if s == null or actor == null or not ResourceLoader.exists(path):
		return 0.0
	var st: AudioStream = load(path)
	var v := s._free_voice(int(line.get("priority", 2)), actor.global_position)
	if v == null:
		return 0.0
	s._handle += 1
	v.handle = s._handle
	v.event = "voice." + str(line.get("voice", ""))
	v.file = path
	v.origin = Origin.WORLD
	v.attach = actor
	v.attached = true
	v.offset = Vector3(0, 1.6, 0)
	v.pos = actor.global_position + v.offset
	v.loop = false
	v.base_db = float(line.get("db", -4.0))
	v.base_bus = "Characters"
	v.busy = true
	v.max_dist = 70.0
	v.p.stream = st
	v.p.bus = "Characters"
	v.p.unit_size = 4.0
	v.p.max_distance = 70.0
	v.p.global_position = v.pos
	v.p.play()
	SoundEvents.emit(st, v.pos, v.base_db, "speech", str(line.get("text", "")), "world")
	return st.get_length()


## Phase 18: stop whatever `actor` is saying (interrupted turn, actor gone,
## load). Returns how many voices stopped.
static func stop_speech(actor: Node3D) -> int:
	var s := instance()
	if s == null:
		return 0
	var n := 0
	for v in s.voices:
		var vv := v as Voice
		if vv.busy and vv.attach == actor and str(vv.event).begins_with("voice."):
			vv.p.stop()
			s._release(vv)
			n += 1
	return n


## Phase 18: is `actor` speaking right now?
static func speaking(actor: Node3D) -> bool:
	var s := instance()
	if s == null:
		return false
	for v in s.voices:
		var vv := v as Voice
		if vv.busy and vv.attach == actor and str(vv.event).begins_with("voice.") and vv.p.playing:
			return true
	return false


# ------------------------------------------------------------------ replay

## Replays recorded world events through a local speaker (desk monitor):
## RECORDING origin - no live evidence, no capture, no recorder entry, no
## gameplay. `t0` = the record time that maps to "now"; returns voices.
static func replay(records: Array, speaker: Node3D, from_t: float, to_t: float) -> int:
	var s := instance()
	if s == null:
		return 0
	var n := 0
	for r in records:
		var t := float(r.t)
		if t < from_t or t > to_t or n >= 60:
			continue
		if not SoundBank.EVENTS.has(str(r.event)):
			continue
		# Original timing: each event plays at its recorded offset (the queue
		# only advances while the game runs; seeking = calling again).
		s._delayed.append([t - from_t, str(r.event), speaker, {"origin": Origin.RECORDING, "file": str(r.file), "db": -10.0, "bus": "Relay", "emit": false, "_delayed": true}])
		n += 1
	return n
