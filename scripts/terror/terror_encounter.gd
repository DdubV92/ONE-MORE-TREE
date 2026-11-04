class_name TerrorEncounter
extends Node3D
## Runs ONE authored event (or startle) as a real-time conditional plan:
## reserve a grounded place -> establish a cue -> hold while it reacts to
## attention -> optional peak (only if the director granted the shared peak
## budget) -> withdraw through reserved cover -> aftermath -> cleanup.
## Every primitive acts on the shared world (spatial sound that the TV
## microphones, dog and workers can genuinely perceive; bodies at one world
## position that direct view and feeds see identically). Cancelling at any
## moment cleans up everything it created.

signal ended(result: String)

const STAGES := ["reserve", "establish", "hold", "peak", "withdraw", "aftermath", "done"]

var ev: Dictionary = {}
var family := 0
var context := "woods"
var stage := "reserve"
var result := ""
var allow_peak := false
var reduced := false
var actor: TerrorActor
var spot := Vector3.INF
var cam: Node3D             # displayed camera used for feed-context cues
var _t := 0.0
var _hold := 8.0
var _stare := 0.0
var _start_dist := 0.0
var _created: Array[Node] = []
var _audio: Array[AudioStreamPlayer3D] = []
var _warm_restore := {}
var _rng := RandomNumberGenerator.new()
var _support_done := false
var log := PackedStringArray()


func setup(event: Dictionary, ctx: String, peak_ok: bool, seed_v: int) -> void:
	ev = event
	family = int(ev.get("family", 1))
	context = ctx
	allow_peak = peak_ok
	_rng.seed = seed_v
	reduced = bool(Settings.get_v("reduced_startles")) if Settings.values.has("reduced_startles") else false


func steps() -> Array:
	return ev.get("steps", [])


func has_step(p: String) -> bool:
	for s in steps():
		if str(s.p) == p:
			return true
	return false


func step_kind(p: String) -> String:
	for s in steps():
		if str(s.p) == p:
			return str(s.get("k", ""))
	return ""


# ------------------------------------------------------------- reserve

## Finds a valid place for this event's cues. Returns false (quiet outcome)
## when no grounded, safe-respecting place with a withdrawal exists.
func reserve(viewer: Node3D) -> bool:
	var eye := viewer.global_position + Vector3(0, 1.6, 0)
	var look := -viewer.global_basis.z
	if context == "cameras" or (has_step("feed") and Game.tv and Game.tv.powered and Game.tv._active):
		var tv: CameraWall = Game.tv
		if tv and not tv.cams.is_empty():
			var shown := tv.shown_cameras()
			cam = tv.cams[shown[_rng.randi() % shown.size()]]
			spot = TerrorPlacement.in_camera_view(cam, _rng)
	if spot == Vector3.INF:
		match context:
			"woods":
				spot = TerrorPlacement.treeline_point(viewer.global_position, look, 22.0, 60.0, 1.1, _rng)
			"camp":
				spot = TerrorPlacement.beyond_fence(viewer.global_position, look, _rng)
			"cabin":
				spot = TerrorPlacement.outside_building(viewer, "cabin", _rng)
			"camper":
				spot = TerrorPlacement.outside_building(viewer, "camper", _rng)
			_:
				spot = TerrorPlacement.treeline_point(viewer.global_position, look, 25.0, 60.0, 1.2, _rng)
	if family == 11:
		var sh := TerrorPlacement.shoreline(viewer.global_position, 120.0, _rng)
		if sh != Vector3.INF:
			spot = sh
	if family == 3 and spot != Vector3.INF:
		spot.y += 9.0 + _rng.randf() * 6.0     # tagged airborne exception
	if family == 14 and spot != Vector3.INF:
		spot.y += 4.5                           # hangs in a crown (tagged exception)
	if spot == Vector3.INF:
		return false
	_start_dist = spot.distance_to(eye)
	log.append("reserve %s at %.0f m (%s)" % [str(ev.id), _start_dist, context])
	return true


# ------------------------------------------------------------- running

func begin(viewer: Node3D) -> void:
	stage = "establish"
	_t = 0.0
	_hold = _rng.randf_range(6.0, 14.0)
	var look_at := viewer.global_position + Vector3(0, 1.4, 0)
	if cam:
		look_at = cam.global_position
	# Visual body (one world position).
	if has_step("figure") or has_step("shadow") or (has_step("peak") and _figure_kind() != ""):
		var k := _figure_kind()
		if k != "":
			actor = TerrorActor.make(k)
			add_child(actor)
			# Never pop in while watched: if the spot is in direct view, it
			# emerges slowly from darkness at distance; otherwise it is simply
			# there when first noticed.
			var watched := _in_view(viewer, spot)
			actor.present(spot, look_at, 3.0 if watched else 0.0)
			if has_step("shadow"):
				actor.scale = Vector3.ONE * 1.12
	if has_step("lights"):
		_procession(viewer)
	if has_step("sky"):
		_sky_patch(viewer)
	var pk := step_kind("prop")
	if pk != "":
		_prop(pk, viewer)
	if has_step("warmth"):
		_warmth(true)
	var sk := step_kind("sound")
	if sk != "":
		_sound(sk, spot)
	elif family == 10:
		_sound("bark", spot)
	if has_step("voice"):
		_voice(spot)
	if has_step("feed") and Game.tv and step_kind("feed") == "lie":
		Game.tv.anomaly(["freeze", "static", "label", "phantom"][_rng.randi() % 4], 1.6)
	if has_step("dog_react") and Game.dog:
		Game.dog.hear(null, spot, -10.0, "terror", "")
	if has_step("witness") or has_step("figure"):
		_witness()


func _process(delta: float) -> void:
	var viewer := Game.player as Node3D
	if viewer == null or stage == "done" or get_tree().paused:
		return
	_t += delta
	match stage:
		"establish":
			if _t > 1.0:
				stage = "hold"
				_t = 0.0
		"hold":
			# React to attention: a sustained direct look or an approach.
			if actor and actor.visible:
				if _in_view(viewer, actor.global_position + Vector3(0, 1.2, 0), 0.97):
					_stare += delta
				else:
					_stare = maxf(_stare - delta * 0.5, 0.0)
				var d := viewer.global_position.distance_to(actor.global_position)
				if _stare > 1.4 or d < _start_dist * 0.6:
					_react(viewer)
					return
			if not _support_done and _t > _hold * 0.5 and has_step("sound") and has_step("figure"):
				_support_done = true
			if _t >= _hold:
				if allow_peak and has_step("peak"):
					_peak(viewer)
				else:
					_withdraw(viewer, 1.3)
		"peak":
			if _t > 1.4:
				_withdraw(viewer, 4.5)
		"withdraw":
			if actor == null or actor.state == "gone" or _t > 25.0:
				stage = "aftermath"
				_t = 0.0
		"aftermath":
			if _t > 2.5:
				finish("completed" if result == "" else result)


func _react(viewer: Node3D) -> void:
	log.append("reacted to attention")
	if allow_peak and has_step("peak"):
		_peak(viewer)
	else:
		_withdraw(viewer, 2.2)


## Sharp but bounded: a quick move behind real cover with one dull hit.
func _peak(viewer: Node3D) -> void:
	stage = "peak"
	_t = 0.0
	result = "peak"
	log.append("peak")
	if actor:
		actor.withdraw(TerrorPlacement.withdrawal(actor.global_position, viewer.global_position), 3.0 if reduced else 7.5)
	_play("t_stinger" if not reduced else "t_breath", spot, -4.0 if not reduced else -14.0)


func _withdraw(viewer: Node3D, spd: float) -> void:
	stage = "withdraw"
	_t = 0.0
	if actor and actor.state != "gone" and actor.state != "withdraw":
		actor.withdraw(TerrorPlacement.withdrawal(actor.global_position, viewer.global_position), spd)


## Ends now; removes every temporary body, light, sound and grading change
## (props stay until morning by design and are owned by the director).
func finish(r: String) -> void:
	if stage == "done":
		return
	stage = "done"
	result = r
	if _warm_restore.size() > 0:
		_warmth(false)
	for a in _audio:
		if is_instance_valid(a):
			a.queue_free()
	if actor and is_instance_valid(actor):
		actor.queue_free()
	for n in _created:
		if is_instance_valid(n) and not n.is_in_group("terror_prop"):
			n.queue_free()
	ended.emit(r)
	queue_free.call_deferred()


func cancel() -> void:
	finish("cancelled")


# ----------------------------------------------------------- primitives

func _figure_kind() -> String:
	match family:
		1: return "tall_woman"
		3: return "winged"
		4: return "low_white"
		5, 7, 13, 15, 24, 25: return "thin_man"
		6, 18: return "worker_like"
		9: return "backward"
		10: return "fake_dog"
		11: return "drowned"
		14: return "hanging"
		20: return "afterimage"
		21: return "extra"
	return ""


func _in_view(viewer: Node3D, p: Vector3, cos_limit := 0.82) -> bool:
	var cam3 := viewer.get_viewport().get_camera_3d() if viewer.is_inside_tree() else null
	if cam3 == null:
		return false
	var to := (p - cam3.global_position).normalized()
	if (-cam3.global_basis.z).dot(to) < cos_limit:
		return false
	return TerrorPlacement.visible_from(cam3.global_position, p, get_world_3d().direct_space_state)


const SOUNDS := {
	"call": ["t_call"], "scrape": ["t_scrape", "t_fabric"], "knock": ["t_knock_0", "t_knock_1", "t_knock_2"],
	"wing": ["t_wing"], "chop": ["chop_0", "chop_2", "chop_4"], "water": ["t_drip"],
	"bark": ["dog_bark_0", "dog_bark_1", "dog_whine_1"], "steps": ["step_dirt_1", "step_dirt_3"],
	"breath": ["t_breath"], "creak": ["creak_wood_0", "creak_wood_1"], "bell": ["t_bell_0", "t_bell_1"],
	"choir": ["t_choir"], "lantern": ["t_lantern"],
}
const CAPTIONS := {
	"call": "a soft three-note call", "scrape": "something dragging", "knock": "knocking", "wing": "heavy wingbeats",
	"chop": "an axe, somewhere it shouldn't be", "water": "dripping", "bark": "a dog, not quite right",
	"steps": "footsteps", "breath": "a breath", "creak": "a creak", "bell": "a small bell", "choir": "voices in the wind",
	"lantern": "metal clinking",
}


func _sound(kind: String, at: Vector3) -> void:
	var names: Array = SOUNDS.get(kind, ["creak_wood_0"])
	var n: String = names[_rng.randi() % names.size()]
	var pitch := 0.82 if (kind == "bark" and family == 10) else 1.0
	_play(n, at, -6.0, pitch)
	TerrorDirector.caption(CAPTIONS.get(kind, "a sound"), at)


func _play(n: String, at: Vector3, db: float, pitch := 1.0) -> void:
	var path := "res://audio/generated/%s.wav" % n
	if not ResourceLoader.exists(path):
		return
	var s: AudioStream = load(path)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "Horror"
	p.unit_size = 9.0
	p.max_distance = 160.0
	p.pitch_scale = pitch
	p.volume_db = db
	add_child(p)
	p.global_position = at + Vector3(0, 1.2, 0)
	p.play()
	_audio.append(p)
	# Real world sound: TV microphones, workers and the dog can perceive it.
	SoundEvents.emit(s, p.global_position, db, "terror", "")


func _voice(at: Vector3) -> void:
	var mem := TerrorDirector.voice_memory_pick(_rng)
	_play("t_voice_%d" % (_rng.randi() % 4), at, -9.0, 0.92 + _rng.randf() * 0.12)
	if mem.is_empty():
		TerrorDirector.caption("a familiar-sounding voice, words unclear", at)
	else:
		var words := str(mem.text).split(" ")
		var frag := " ".join(words.slice(0, maxi(2, words.size() / 2)))
		TerrorDirector.caption("a voice like %s's: \"%s...\"" % [str(mem.speaker), frag], at)


func _witness() -> void:
	if Game.crew == null:
		return
	var modality := "sight" if actor != null else "sound"
	Game.crew.emit_stimulus({"id": "%s@%d" % [str(ev.id), Time.get_ticks_msec()], "kind": "T%02d" % family, "modality": modality, "pos": spot, "loudness": 0.6, "severity": 0.15 + 0.1 * float(ev.get("intensity", 1)), "ambiguous": modality != "sight"})


func _procession(viewer: Node3D) -> void:
	var a := TerrorPlacement.treeline_point(viewer.global_position, -viewer.global_basis.z, 45.0, 90.0, 0.9, _rng)
	if a == Vector3.INF:
		a = spot
	var side := (-viewer.global_basis.z).cross(Vector3.UP).normalized()
	for i in 5:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.35)
		l.light_energy = 0.6
		l.omni_range = 3.5
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		bulb.mesh = sm
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.35)
		m.emission_energy_multiplier = 3.0
		bulb.material_override = m
		l.add_child(bulb)
		add_child(l)
		var start := a + side * (i * 2.4 - 5.0)
		l.global_position = start + Vector3(0, 1.1, 0)
		var tw := create_tween()
		tw.tween_property(l, "global_position", start + side * 14.0 + Vector3(0, 1.1, 0), 22.0)
		_created.append(l)
	_play("t_lantern", a, -10.0)


func _sky_patch(viewer: Node3D) -> void:
	var d := -viewer.global_basis.z
	d.y = 0.0
	d = d.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(90, 70)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = viewer.global_position + d * 700.0 + Vector3(0, 300.0, 0)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.92, 8.0)
	tw.tween_interval(20.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 8.0)
	_created.append(m)


func _prop(kind: String, viewer: Node3D) -> void:
	var root := Node3D.new()
	root.add_to_group("terror_prop")
	get_parent().add_child(root)     # owned by the director: stays until morning
	var at := spot if spot != Vector3.INF else viewer.global_position
	at.y = World.height_at(at.x, at.z)
	root.global_position = at
	match kind:
		"thread":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.7, 0.05, 0.05)
			for i in 3:
				var seg := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.006
				cm.bottom_radius = 0.006
				cm.height = 1.6
				seg.mesh = cm
				seg.material_override = m
				seg.position = Vector3(i * 0.5, 1.2 - i * 0.15, 0)
				seg.rotation.z = PI * 0.5 + _rng.randf_range(-0.3, 0.3)
				root.add_child(seg)
		"prints":
			var m2 := StandardMaterial3D.new()
			m2.albedo_color = Color(0.12, 0.1, 0.08)
			for i in 7:
				var fp := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.11, 0.01, 0.27)
				fp.mesh = bm
				fp.material_override = m2
				var off := Vector3((i % 2) * 0.25 - 0.12, 0, -i * 0.7)
				fp.position = off
				root.add_child(fp)
				fp.global_position.y = World.height_at(fp.global_position.x, fp.global_position.z) + 0.006
		"stakes":
			var m3 := StandardMaterial3D.new()
			m3.albedo_color = Color(0.55, 0.4, 0.25)
			var tape := StandardMaterial3D.new()
			tape.albedo_color = Color(0.95, 0.4, 0.1)
			for i in 3:
				var st := MeshInstance3D.new()
				var bm2 := BoxMesh.new()
				bm2.size = Vector3(0.05, 1.1, 0.05)
				st.mesh = bm2
				st.material_override = m3
				st.position = Vector3(i * 1.6, 0.55, 0)
				root.add_child(st)
				var tp := MeshInstance3D.new()
				var bm3 := BoxMesh.new()
				bm3.size = Vector3(0.02, 0.3, 0.06)
				tp.mesh = bm3
				tp.material_override = tape
				tp.position = Vector3(i * 1.6 + 0.04, 1.0, 0)
				root.add_child(tp)


## The room loses its warmth: interior light colour cools and dims a little,
## then returns. Never switches a light off; camp lamps are never touched.
func _warmth(on: bool) -> void:
	var lights: Array[Node] = []
	lights.append_array(get_tree().get_nodes_in_group("camper_light"))
	if on:
		for l in lights:
			var li := l as Light3D
			_warm_restore[li] = [li.light_color, li.light_energy]
			var tw := create_tween()
			tw.tween_property(li, "light_color", Color(0.75, 0.82, 1.0), 6.0)
			tw.parallel().tween_property(li, "light_energy", li.light_energy * 0.7, 6.0)
	else:
		for li in _warm_restore:
			if is_instance_valid(li):
				var v: Array = _warm_restore[li]
				var tw2 := (li as Node).create_tween()
				tw2.tween_property(li, "light_color", v[0], 4.0)
				tw2.parallel().tween_property(li, "light_energy", v[1], 4.0)
		_warm_restore.clear()
