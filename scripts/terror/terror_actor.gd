class_name TerrorActor
extends Node3D
## A pooled, physically placed apparition body for the ordinary Terror
## families. It exists at ONE world position (seen identically in direct
## view and on every security feed), never collides, never touches anyone,
## and always leaves through a reserved withdrawal (cover or a bounded
## dissolve). Bodies are original procedural silhouettes, built to read at
## night distance; they are not close-up inspection models (art gap noted).
##
## Kinds: tall_woman, thin_man, worker_like, low_white, winged, backward,
## fake_dog, drowned, hanging, afterimage, extra, procession.

signal finished

var kind := ""
var state := "idle"          # idle / present / hold / withdraw / gone
                             # Phase 23: stand (frozen) / stride (moved by its encounter)
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _dur := 1.0
var _fade := 1.0
var _mats: Array[StandardMaterial3D] = []
var _anim_t := 0.0
var body: Node3D
var hc: HumanCharacter
var dog: DogCharacter
var face_target := Vector3.INF
var speed := 0.0


static func make(kind_: String) -> TerrorActor:
	var a := TerrorActor.new()
	a.kind = kind_
	a.name = "Terror_" + kind_
	return a


func _ready() -> void:
	add_to_group("terror_actor")
	body = Node3D.new()
	add_child(body)
	match kind:
		"tall_woman": _tall_woman()
		"thin_man": _thin_figure(2.35, Color(0.07, 0.07, 0.08))
		"low_white": _low_white()
		"winged": _winged()
		"hanging": _hanging()
		"fake_dog": _fake_dog()
		"procession": pass
		_: _human_like()
	_collect(body)
	visible = false


# -------------------------------------------------------------- bodies

func _m(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := CharMeshKit.mat(c, rough)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	return m


func _tall_woman() -> void:
	var dress := _m(Color(0.78, 0.76, 0.72))
	var dark := _m(Color(0.04, 0.04, 0.05))
	var h := 3.4
	CharMeshKit.part(body, CharMeshKit.tapered_capsule(0.32, 0.14, h * 0.62), dress, Vector3(0, h * 0.62, 0), Vector3.ONE, Vector3.ZERO, "Dress")
	CharMeshKit.part(body, CharMeshKit.tapered_capsule(0.14, 0.11, h * 0.22), dress, Vector3(0, h * 0.86, 0), Vector3.ONE, Vector3.ZERO, "Torso")
	for s in [-1.0, 1.0]:
		var arm := CharMeshKit.part(body, CharMeshKit.tapered_capsule(0.05, 0.035, h * 0.42), dress, Vector3(s * 0.17, h * 0.84, 0), Vector3.ONE, Vector3(0, 0, s * 0.06), "Sleeve")
		arm.name = "Sleeve"
	CharMeshKit.blob(body, _m(Color(0.86, 0.85, 0.82)), Vector3(0, h * 0.93, 0), Vector3(0.17, 0.22, 0.17), Vector3.ZERO, "Head")
	var brim := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 0.03
	brim.mesh = cm
	brim.material_override = dark
	brim.position = Vector3(0, h * 0.97, 0)
	body.add_child(brim)
	CharMeshKit.blob(body, dark, Vector3(0, h * 0.99, 0), Vector3(0.2, 0.12, 0.2), Vector3.ZERO, "Crown")


func _thin_figure(h: float, c: Color) -> void:
	var m := _m(c)
	CharMeshKit.part(body, CharMeshKit.tapered_capsule(0.09, 0.13, h * 0.52), m, Vector3(0, h * 0.52, 0), Vector3.ONE, Vector3.ZERO, "Legs")
	CharMeshKit.part(body, CharMeshKit.tapered_capsule(0.13, 0.17, h * 0.33), m, Vector3(0, h * 0.86, 0), Vector3.ONE, Vector3.ZERO, "Torso")
	for s in [-1.0, 1.0]:
		CharMeshKit.part(body, CharMeshKit.tapered_capsule(0.04, 0.03, h * 0.4), m, Vector3(s * 0.2, h * 0.84, 0), Vector3.ONE, Vector3(0, 0, s * 0.05), "Arm")
	CharMeshKit.blob(body, m, Vector3(0, h * 0.93, 0), Vector3(0.12, 0.15, 0.12), Vector3.ZERO, "Head")


func _human_like() -> void:
	hc = HumanCharacter.new()
	var a := HumanAppearance.new()
	a.label = "unknown"
	match kind:
		"worker_like":
			a.jacket = Color(0.55, 0.22, 0.16)
		"drowned":
			a.jacket = Color(0.12, 0.16, 0.17)
			a.skin = Color(0.62, 0.66, 0.66)
			a.hair = Color(0.05, 0.06, 0.06)
		"afterimage":
			a.jacket = Color(0.8, 0.82, 0.86)
			a.skin = Color(0.85, 0.86, 0.88)
		_:
			a.jacket = Color(0.1, 0.1, 0.11)
			a.skin = Color(0.45, 0.44, 0.42)
	hc.appearance = a
	body.add_child(hc)
	if kind == "backward":
		hc.rotation.y = PI    # walks facing away from its travel direction


func _low_white() -> void:
	var m := _m(Color(0.86, 0.85, 0.8), 0.6)
	CharMeshKit.blob(body, m, Vector3(0, 0.28, 0), Vector3(0.32, 0.22, 0.95), Vector3.ZERO, "Back")
	CharMeshKit.blob(body, m, Vector3(0, 0.26, -0.6), Vector3(0.18, 0.15, 0.22), Vector3.ZERO, "Head")
	for i in 6:
		var z := -0.45 + i * 0.18
		for s in [-1.0, 1.0]:
			var leg := CharMeshKit.part(body, CharMeshKit.tapered_capsule(0.03, 0.02, 0.42), m, Vector3(s * 0.22, 0.32, z), Vector3.ONE, Vector3(0, 0, s * 1.0), "Limb")
			leg.set_meta("phase", float(i) * 0.9 + (0.0 if s > 0 else PI))


func _winged() -> void:
	var m := _m(Color(0.05, 0.05, 0.06))
	CharMeshKit.blob(body, m, Vector3.ZERO, Vector3(0.45, 0.45, 1.1), Vector3.ZERO, "Body")
	for s in [-1.0, 1.0]:
		var w := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(3.2, 0.05, 1.6)
		w.mesh = pm
		w.material_override = m
		w.position = Vector3(s * 1.7, 0.1, 0.2)
		w.name = "Wing"
		w.set_meta("side", s)
		body.add_child(w)
		for k in 3:
			CharMeshKit.part(body, CharMeshKit.tapered_capsule(0.03, 0.01, 0.55 - k * 0.1), m, Vector3(s * (0.12 + k * 0.08), 0.35 + k * 0.12, -0.75), Vector3.ONE, Vector3(-0.4, 0, s * (0.6 + k * 0.25)), "Antler")


func _hanging() -> void:
	var m := _m(Color(0.04, 0.04, 0.045))
	for i in 3:
		var n := Node3D.new()
		n.position = Vector3((i - 1) * 1.4, 0, (i % 2) * 0.6)
		n.set_meta("phase", i * 1.3)
		n.name = "Hang_%d" % i
		body.add_child(n)
		CharMeshKit.part(n, CharMeshKit.tapered_capsule(0.01, 0.01, 1.2), m, Vector3(0, 0, 0), Vector3.ONE, Vector3.ZERO, "Line")
		CharMeshKit.part(n, CharMeshKit.tapered_capsule(0.14, 0.07, 1.5), m, Vector3(0, -1.2, 0), Vector3.ONE, Vector3.ZERO, "Shape")


func _fake_dog() -> void:
	dog = DogCharacter.new()
	dog.fur = Color(0.2, 0.18, 0.16)
	dog.saddle = Color(0.1, 0.09, 0.08)
	dog.cream = Color(0.35, 0.33, 0.3)
	body.add_child(dog)
	dog.scale = Vector3(1.0, 1.18, 1.12)   # subtly wrong proportions


func _collect(n: Node) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mi := n as MeshInstance3D
		if mi and mi.material_override is StandardMaterial3D:
			var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mi.material_override = m
			_mats.append(m)
	for c in n.get_children():
		_collect(c)


func _set_alpha(a: float) -> void:
	for m in _mats:
		m.albedo_color.a = a
	if hc or dog:
		# Character rigs keep their own materials; scale-in instead of alpha.
		body.scale = Vector3.ONE * maxf(a, 0.001) if kind == "afterimage" else Vector3.ONE


# ----------------------------------------------------------- lifecycle

## Appears at `at` (already validated: outside safety, on support, behind
## partial cover), facing `look`. Fades in over `fade_in` (0 = already there
## when first seen, i.e. it was placed out of view).
func present(at: Vector3, look: Vector3, fade_in := 1.2) -> void:
	global_position = at
	face_target = look
	_face(look)
	visible = true
	state = "present"
	_t = 0.0
	_dur = maxf(fade_in, 0.01)
	_fade = 0.0 if fade_in > 0.0 else 1.0
	_set_alpha(_fade)


func hold() -> void:
	state = "hold"


## Phase 23 (storm encounters): appears already there (no fade) and stands
## perfectly still; it does not even turn its head.
func stand_at(at: Vector3, look: Vector3) -> void:
	global_position = at
	face_target = look
	_face(look)
	visible = true
	_fade = 1.0
	_set_alpha(1.0)
	state = "stand"
	speed = 0.0


func stand() -> void:
	if state in ["stride", "hold", "present"]:
		state = "stand"
	speed = 0.0


## Moved by its encounter (along a real nav path, grounded every frame);
## this only drives the walk animation and facing.
func stride_to(p: Vector3, spd: float) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 0.35)
	p.y = _ground(p)
	global_position = p
	state = "stride"
	speed = spd


## Reduced-flash accessibility cue: a soft, steady rim instead of a strobe,
## so the silhouette still reads (presentation only; 0 = off).
func set_cue(k: float) -> void:
	for m in _mats:
		m.emission_enabled = k > 0.001
		m.emission = Color(0.55, 0.6, 0.7)
		m.emission_energy_multiplier = 0.35 * k


## Leaves along a real route to `to` (cover), optionally dissolving at the end.
func withdraw(to: Vector3, spd := 1.4) -> void:
	_from = global_position
	_to = to
	speed = spd
	_t = 0.0
	_dur = maxf(_from.distance_to(to) / maxf(spd, 0.1), 0.6)
	state = "withdraw"


func dissolve(sec := 1.5) -> void:
	_t = 0.0
	_dur = sec
	state = "dissolve"


func _face(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.05:
		rotation.y = atan2(-d.x, -d.z)


func _process(delta: float) -> void:
	if not visible:
		return
	_anim_t += delta
	match state:
		"present":
			_t += delta
			_fade = clampf(_t / _dur, 0.0, 1.0)
			_set_alpha(_fade)
			if _t >= _dur:
				state = "hold"
		"hold":
			if face_target != Vector3.INF and kind != "backward":
				var want := atan2(-(face_target.x - global_position.x), -(face_target.z - global_position.z))
				rotation.y = lerp_angle(rotation.y, want, delta * 0.4)
		"withdraw":
			_t += delta
			var u := clampf(_t / _dur, 0.0, 1.0)
			var p := _from.lerp(_to, u)
			p.y = _ground(p) if kind != "winged" and kind != "hanging" else lerpf(_from.y, _to.y, u)
			var dir := _to - _from
			if dir.length() > 0.1 and kind != "winged":
				rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 4.0)
			global_position = p
			if u >= 1.0:
				dissolve(0.8)
		"dissolve":
			_t += delta
			_set_alpha(1.0 - clampf(_t / _dur, 0.0, 1.0))
			if _t >= _dur:
				state = "gone"
				visible = false
				finished.emit()
	_animate(delta)


func _ground(p: Vector3) -> float:
	var n := Game.crew.nav if Game.crew and Game.crew.nav and Game.crew.nav.built else null
	return n.surface_at(p) if n else World.height_at(p.x, p.z)


func _animate(_delta: float) -> void:
	var moving := state == "withdraw" or state == "stride"
	if hc:
		hc.set_locomotion(speed if moving else 0.0)
	if dog:
		dog.set_locomotion(speed if moving else 0.0, "alert")
	match kind:
		"low_white":
			for c in body.get_children():
				if c.has_meta("phase"):
					(c as Node3D).rotation.x = sin(_anim_t * (7.0 if moving else 1.0) + float(c.get_meta("phase"))) * 0.5
		"winged":
			for c in body.get_children():
				if c.name.begins_with("Wing"):
					(c as Node3D).rotation.z = float(c.get_meta("side")) * sin(_anim_t * 2.2) * 0.35
		"hanging":
			for c in body.get_children():
				if c.has_meta("phase"):
					(c as Node3D).rotation.z = sin(_anim_t * 0.6 + float(c.get_meta("phase"))) * 0.08
		"tall_woman":
			body.rotation.x = 0.02 * sin(_anim_t * 0.3)
