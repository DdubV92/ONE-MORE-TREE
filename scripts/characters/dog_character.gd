class_name DogCharacter
extends Node3D
## Friendly medium-sized scruffy dog (rigid-part articulation, faces -Z).
## Pivots: Body > Chest > Neck > Head > EarL/EarR, Body > Pelvis > TailBase >
## TailTip, four two-segment legs with paws. Clips: idle (wag, ear twitch,
## planted feet), walk (lateral-sequence gait, IK-baked paw contact), lie
## (lying down and sleeping; blend from idle shows the lie-down motion).
## The dog cannot be harmed: it has no health and no damage interface.

const WALK_NOMINAL_SPEED := 1.1
const TROT_NOMINAL_SPEED := 2.3
const TROT_PERIOD := 0.42
const WALK_PERIOD := 0.62
const STANCE := 0.6

@export var fur := Color(0.64, 0.5, 0.33)
@export var saddle := Color(0.38, 0.28, 0.19)
@export var cream := Color(0.92, 0.87, 0.78)

var rig: Node3D
var bones := {}
var rest := {}
var anim: AnimationPlayer
var playback_scale := 1.0
var current := ""
var body_y := 0.48
var upper_f := 0.22
var lower_f := 0.22
var upper_h := 0.22
var lower_h := 0.24
var paw_h := 0.035
## Runtime overlays (Phase 5): head/neck turn toward a world point and
## pricked ears, blended over whatever clip plays.
var look_target := Vector3.INF
var look_weight := 0.0
var ear_perk := 0.0
var _look_w := 0.0


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	bones.clear()
	_build_rig()
	_build_animations()
	play("idle", 0.0)


func _bone(name: String, parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	bones[name] = n
	rest[name] = n.transform
	return n


func _build_rig() -> void:
	var f := CharMeshKit.mat(fur, 0.95)
	var dk := CharMeshKit.mat(saddle, 0.95)
	var cr := CharMeshKit.mat(cream, 0.95)
	var black := CharMeshKit.mat(Color(0.05, 0.04, 0.04), 0.35)
	var eye := CharMeshKit.mat(Color(0.12, 0.07, 0.04), 0.15)
	var glint := CharMeshKit.mat(Color(1, 1, 1), 0.1)
	var tongue := CharMeshKit.mat(Color(0.8, 0.4, 0.42), 0.5)
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	var body := _bone("Body", rig, Vector3(0, body_y, 0))
	CharMeshKit.blob(body, f, Vector3(0, 0.0, 0.0), Vector3(0.25, 0.25, 0.6), Vector3.ZERO, "Torso")
	CharMeshKit.blob(body, dk, Vector3(0, 0.07, 0.02), Vector3(0.22, 0.13, 0.5), Vector3.ZERO, "Saddle")
	CharMeshKit.blob(body, cr, Vector3(0, -0.07, -0.06), Vector3(0.18, 0.12, 0.4), Vector3.ZERO, "Belly")
	# Scruffy tufts (deterministic)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in 22:
		var a := rng.randf_range(-1.2, 1.2)
		var z := rng.randf_range(-0.26, 0.26)
		var p := Vector3(sin(a) * 0.12, cos(a) * 0.12, z)
		CharMeshKit.blob(body, dk if a > -0.5 and a < 0.5 else f, p, Vector3(0.07, 0.045, 0.09) * rng.randf_range(0.7, 1.2), Vector3(rng.randf_range(-0.5, 0.5), 0, a), "Tuft")
	var chest := _bone("Chest", body, Vector3(0, 0.02, -0.2))
	CharMeshKit.blob(chest, f, Vector3(0, 0.0, 0.0), Vector3(0.27, 0.3, 0.28), Vector3.ZERO, "ChestMass")
	CharMeshKit.blob(chest, cr, Vector3(0, -0.04, -0.1), Vector3(0.17, 0.22, 0.12), Vector3.ZERO, "Bib")
	var pelvis := _bone("Pelvis", body, Vector3(0, 0.0, 0.21))
	CharMeshKit.blob(pelvis, f, Vector3(0, 0.0, 0.02), Vector3(0.24, 0.25, 0.25), Vector3.ZERO, "Rump")
	var neck := _bone("Neck", chest, Vector3(0, 0.1, -0.1))
	CharMeshKit.blob(neck, f, Vector3(0, 0.05, -0.04), Vector3(0.15, 0.22, 0.15), Vector3(-0.55, 0, 0), "NeckMass")
	CharMeshKit.blob(neck, dk, Vector3(0, 0.09, 0.0), Vector3(0.13, 0.12, 0.12), Vector3(-0.55, 0, 0), "Scruff")
	var head := _bone("Head", neck, Vector3(0, 0.14, -0.09))
	CharMeshKit.blob(head, f, Vector3(0, 0.03, 0.0), Vector3(0.17, 0.15, 0.18), Vector3.ZERO, "Skull")
	CharMeshKit.blob(head, cr, Vector3(0, -0.005, -0.115), Vector3(0.1, 0.085, 0.16), Vector3(0.1, 0, 0), "Muzzle")
	CharMeshKit.blob(head, black, Vector3(0, 0.022, -0.198), Vector3(0.045, 0.035, 0.035), Vector3.ZERO, "Nose")
	CharMeshKit.blob(head, cr, Vector3(0, -0.035, -0.12), Vector3(0.08, 0.04, 0.12), Vector3.ZERO, "Chin")
	CharMeshKit.blob(head, tongue, Vector3(0, -0.05, -0.15), Vector3(0.035, 0.012, 0.05), Vector3(0.25, 0, 0), "Tongue")
	for k in 6:
		CharMeshKit.blob(head, cr, Vector3(rng.randf_range(-0.04, 0.04), -0.045, -0.09 - k * 0.012), Vector3(0.03, 0.04, 0.025), Vector3.ZERO, "Whisker")
	for s in [-1.0, 1.0]:
		var sn := "L" if s < 0 else "R"
		var e := _bone("Eye" + sn, head, Vector3(s * 0.045, 0.06, -0.083))
		CharMeshKit.blob(e, eye, Vector3.ZERO, Vector3(0.03, 0.032, 0.025))
		CharMeshKit.blob(e, glint, Vector3(0.006, 0.008, -0.012), Vector3.ONE * 0.007)
		CharMeshKit.blob(head, dk, Vector3(s * 0.045, 0.085, -0.08), Vector3(0.035, 0.012, 0.02), Vector3(0, 0, -s * 0.25), "Brow" + sn)
		var ear := _bone("Ear" + sn, head, Vector3(s * 0.065, 0.085, 0.01), Vector3(0, 0, s * 0.35))
		CharMeshKit.blob(ear, dk, Vector3(s * 0.01, -0.06, 0.0), Vector3(0.035, 0.13, 0.085), Vector3(0, 0, 0), "EarFlap")
	var tail := _bone("TailBase", pelvis, Vector3(0, 0.08, 0.13), Vector3(-2.2, 0, 0))
	CharMeshKit.limb(tail, f, 0.032, 0.026, 0.15)
	var tip := _bone("TailTip", tail, Vector3(0, -0.15, 0), Vector3(0.4, 0, 0))
	CharMeshKit.limb(tip, dk, 0.026, 0.014, 0.13)
	CharMeshKit.blob(tip, cr, Vector3(0, -0.14, 0), Vector3(0.04, 0.06, 0.04), Vector3.ZERO, "TailTuft")
	for s in [-1.0, 1.0]:
		var sn := "L" if s < 0 else "R"
		var fu := _bone("FrontUpper" + sn, chest, Vector3(s * 0.085, -0.04, -0.02))
		CharMeshKit.limb(fu, f, 0.05, 0.036, upper_f)
		var fl := _bone("FrontLower" + sn, fu, Vector3(0, -upper_f, 0))
		CharMeshKit.limb(fl, cr if s > 0 else f, 0.034, 0.03, lower_f)
		var fp := _bone("FrontPaw" + sn, fl, Vector3(0, -lower_f, 0))
		CharMeshKit.blob(fp, cr, Vector3(0, -paw_h * 0.5, -0.025), Vector3(0.065, 0.045, 0.09), Vector3.ZERO, "Paw")
		var hu := _bone("HindUpper" + sn, pelvis, Vector3(s * 0.085, -0.04, 0.03))
		CharMeshKit.blob(hu, f, Vector3(0, -0.06, -0.01), Vector3(0.11, 0.2, 0.15), Vector3.ZERO, "Haunch")
		CharMeshKit.limb(hu, f, 0.05, 0.036, upper_h)
		var hl := _bone("HindLower" + sn, hu, Vector3(0, -upper_h, 0))
		CharMeshKit.limb(hl, f, 0.034, 0.028, lower_h)
		var hp := _bone("HindPaw" + sn, hl, Vector3(0, -lower_h, 0))
		CharMeshKit.blob(hp, cr, Vector3(0, -paw_h * 0.5, -0.025), Vector3(0.065, 0.045, 0.09), Vector3.ZERO, "Paw")


# ------------------------------------------------------------- animation

func _track(an: Animation, bone: String, type := Animation.TYPE_ROTATION_3D) -> int:
	var t := an.add_track(type)
	an.track_set_path(t, NodePath("Rig/" + str(rig.get_path_to(bones[bone]))))
	return t


static func _q(x: float, y := 0.0, z := 0.0) -> Quaternion:
	return Basis.from_euler(Vector3(x, y, z)).get_rotation_quaternion()


func _build_animations() -> void:
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(anim)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_idle())
	lib.add_animation("walk", _make_walk())
	lib.add_animation("lie", _make_lie())
	lib.add_animation("trot", _make_trot())
	lib.add_animation("sit", _make_sit(false))
	lib.add_animation("pet", _make_sit(true))
	lib.add_animation("alert", _make_alert())
	anim.add_animation_library("", lib)


## Leg joint (shoulder/hip) in rig space for a given body position.
func _leg_root(front: bool, side: float, body_pos: Vector3) -> Vector3:
	if front:
		return body_pos + Vector3(0, 0.02, -0.2) + Vector3(side * 0.085, -0.04, -0.02)
	return body_pos + Vector3(0, 0.0, 0.21) + Vector3(side * 0.085, -0.04, 0.03)


func _leg_keys(an: Animation, tr: Dictionary, t: float, front: bool, side: float, body_pos: Vector3, paw: Vector3, pitch := 0.0) -> void:
	var root := _leg_root(front, side, body_pos)
	var d := paw + Vector3(0, paw_h, 0) - root
	var sn := ("Front" if front else "Hind")
	var lr := "L" if side < 0 else "R"
	var ang := LimbIK.solve_planar(d.y, d.z, upper_f if front else upper_h, lower_f if front else lower_h, not front)
	an.rotation_track_insert_key(tr[sn + "Upper" + lr], t, _q(ang.x))
	an.rotation_track_insert_key(tr[sn + "Lower" + lr], t, _q(ang.y))
	an.rotation_track_insert_key(tr[sn + "Paw" + lr], t, _q(-(ang.x + ang.y) + pitch))


func _leg_tracks(an: Animation) -> Dictionary:
	var tr := {}
	for sn in ["Front", "Hind"]:
		for lr in ["L", "R"]:
			for seg in ["Upper", "Lower", "Paw"]:
				tr[sn + seg + lr] = _track(an, sn + seg + lr)
	return tr


func _make_idle() -> Animation:
	var an := Animation.new()
	var T := 3.0
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tr := _leg_tracks(an)
	var body_p := _track(an, "Body", Animation.TYPE_POSITION_3D)
	var chest := _track(an, "Chest")
	var neck := _track(an, "Neck")
	var head := _track(an, "Head")
	var tail := _track(an, "TailBase")
	var tip := _track(an, "TailTip")
	var ear_l := _track(an, "EarL")
	var ear_r := _track(an, "EarR")
	var n := 30
	for k in n + 1:
		var t := T * k / n
		var ph := TAU * t / T
		var bp: Vector3 = rest["Body"].origin + Vector3(0.006 * sin(ph), -0.012 + 0.006 * sin(ph * 2.0), 0)
		an.position_track_insert_key(body_p, t, bp)
		an.rotation_track_insert_key(chest, t, _q(0.015 * sin(ph * 2.0)))
		an.rotation_track_insert_key(neck, t, _q(0.05 * sin(ph * 0.5), 0.12 * sin(ph * 0.5 + 0.5), 0))
		an.rotation_track_insert_key(head, t, _q(0.0, 0.25 * sin(ph * 0.5), 0.12 * sin(ph * 0.5 + 1.0)))
		# Happy wag (about 2.7 Hz), loose tip follows.
		an.rotation_track_insert_key(tail, t, _q(-2.1, 0.55 * sin(ph * 8.0), 0))
		an.rotation_track_insert_key(tip, t, _q(0.35, 0.4 * sin(ph * 8.0 - 0.9), 0))
		var twitch := 0.35 if (t > 1.6 and t < 1.8) else 0.0
		an.rotation_track_insert_key(ear_l, t, _q(0.0, 0, -0.35 - twitch))
		an.rotation_track_insert_key(ear_r, t, _q(0.0, 0, 0.35))
		for side in [-1.0, 1.0]:
			_leg_keys(an, tr, t, true, side, bp, Vector3(side * 0.09, 0, -0.21))
			_leg_keys(an, tr, t, false, side, bp, Vector3(side * 0.09, 0, 0.26))
	return an


func _make_walk() -> Animation:
	var an := Animation.new()
	var T := WALK_PERIOD
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tr := _leg_tracks(an)
	var body_p := _track(an, "Body", Animation.TYPE_POSITION_3D)
	var body_r := _track(an, "Body")
	var neck := _track(an, "Neck")
	var tail := _track(an, "TailBase")
	var ear_l := _track(an, "EarL")
	var ear_r := _track(an, "EarR")
	var S := WALK_NOMINAL_SPEED * STANCE * T
	# Lateral-sequence walk: LH, LF, RH, RF a quarter cycle apart.
	var offsets := {"HL": 0.0, "FL": 0.25, "HR": 0.5, "FR": 0.75}
	var n := 32
	for k in n + 1:
		var t := T * k / n
		var u := t / T
		var bp: Vector3 = rest["Body"].origin + Vector3(0.008 * sin(TAU * u), -0.01 + 0.012 * cos(2.0 * TAU * u), 0)
		an.position_track_insert_key(body_p, t, bp)
		an.rotation_track_insert_key(body_r, t, _q(0.0, 0.04 * sin(TAU * u), 0.03 * sin(TAU * u)))
		an.rotation_track_insert_key(neck, t, _q(0.04 * cos(2.0 * TAU * u), 0, 0))
		an.rotation_track_insert_key(tail, t, _q(-2.0, 0.35 * sin(TAU * u * 2.0), 0))
		an.rotation_track_insert_key(ear_l, t, _q(0.1 * sin(TAU * u * 2.0), 0, -0.35))
		an.rotation_track_insert_key(ear_r, t, _q(0.1 * sin(TAU * u * 2.0 + 1.0), 0, 0.35))
		for key in offsets:
			var front: bool = key.begins_with("F")
			var side := -1.0 if key.ends_with("L") else 1.0
			var ph := fposmod(u + float(offsets[key]), 1.0)
			var base_z := -0.21 if front else 0.26
			var z: float
			var y := 0.0
			var pitch := 0.0
			if ph < STANCE:
				z = base_z - S * 0.5 + (ph / STANCE) * S
			else:
				var w := (ph - STANCE) / (1.0 - STANCE)
				z = base_z + S * 0.5 - S * smoothstep(0.0, 1.0, w)
				y = 0.07 * sin(PI * w)
				pitch = 0.6 * sin(PI * w)
			_leg_keys(an, tr, t, front, side, bp, Vector3(side * 0.09, y, z), pitch)
	return an


func _make_lie() -> Animation:
	var an := Animation.new()
	var T := 4.0
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tr := _leg_tracks(an)
	var body_p := _track(an, "Body", Animation.TYPE_POSITION_3D)
	var body_r := _track(an, "Body")
	var neck := _track(an, "Neck")
	var head := _track(an, "Head")
	var tail := _track(an, "TailBase")
	var tip := _track(an, "TailTip")
	var ear_l := _track(an, "EarL")
	var ear_r := _track(an, "EarR")
	var eyes := [_track(an, "EyeL", Animation.TYPE_SCALE_3D), _track(an, "EyeR", Animation.TYPE_SCALE_3D)]
	var n := 16
	for k in n + 1:
		var t := T * k / n
		var ph := TAU * t / T
		var breath := 0.008 * sin(ph)
		var bp := Vector3(0.0, 0.17 + breath, 0.04)
		an.position_track_insert_key(body_p, t, bp)
		an.rotation_track_insert_key(body_r, t, _q(0.0, 0.0, 0.12))
		an.rotation_track_insert_key(neck, t, _q(-0.55, 0.25, 0.0))
		an.rotation_track_insert_key(head, t, _q(-0.25, 0.15, 0.1))
		an.rotation_track_insert_key(tail, t, _q(-1.7, 1.3, 0.0))
		an.rotation_track_insert_key(tip, t, _q(0.6, 0.5, 0.0))
		an.rotation_track_insert_key(ear_l, t, _q(0.4, 0, -0.9))
		an.rotation_track_insert_key(ear_r, t, _q(0.4, 0, 0.9))
		for e in eyes:
			an.scale_track_insert_key(e, t, Vector3(1, 0.15, 1))
		for side in [-1.0, 1.0]:
			var lr := "L" if side < 0 else "R"
			# Front legs stretched forward along the ground, paws together.
			an.rotation_track_insert_key(tr["FrontUpper" + lr], t, _q(1.35, 0, -side * 0.05))
			an.rotation_track_insert_key(tr["FrontLower" + lr], t, _q(0.2))
			an.rotation_track_insert_key(tr["FrontPaw" + lr], t, _q(-1.4))
			# Hind legs folded under the body.
			an.rotation_track_insert_key(tr["HindUpper" + lr], t, _q(1.25, 0, side * 0.35))
			an.rotation_track_insert_key(tr["HindLower" + lr], t, _q(-2.6))
			an.rotation_track_insert_key(tr["HindPaw" + lr], t, _q(1.0))
	return an


## Diagonal trot: LH+RF and RH+LF in pairs, short flight phase.
func _make_trot() -> Animation:
	var an := Animation.new()
	var T := TROT_PERIOD
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tr := _leg_tracks(an)
	var body_p := _track(an, "Body", Animation.TYPE_POSITION_3D)
	var body_r := _track(an, "Body")
	var neck := _track(an, "Neck")
	var tail := _track(an, "TailBase")
	var ear_l := _track(an, "EarL")
	var ear_r := _track(an, "EarR")
	var st := 0.45
	var S := TROT_NOMINAL_SPEED * st * T
	var offsets := {"HL": 0.0, "FR": 0.0, "HR": 0.5, "FL": 0.5}
	var n := 24
	for k in n + 1:
		var t := T * k / n
		var u := t / T
		var bp: Vector3 = rest["Body"].origin + Vector3(0, 0.005 + 0.016 * cos(2.0 * TAU * u), 0)
		an.position_track_insert_key(body_p, t, bp)
		an.rotation_track_insert_key(body_r, t, _q(0.02 * sin(2.0 * TAU * u), 0, 0.02 * sin(TAU * u)))
		an.rotation_track_insert_key(neck, t, _q(-0.08 + 0.05 * cos(2.0 * TAU * u), 0, 0))
		an.rotation_track_insert_key(tail, t, _q(-1.85, 0.5 * sin(TAU * u * 2.0), 0))
		an.rotation_track_insert_key(ear_l, t, _q(0.25 + 0.12 * sin(TAU * u * 2.0), 0, -0.35))
		an.rotation_track_insert_key(ear_r, t, _q(0.25 + 0.12 * sin(TAU * u * 2.0 + 0.8), 0, 0.35))
		for key in offsets:
			var front: bool = key.begins_with("F")
			var side := -1.0 if key.ends_with("L") else 1.0
			var ph := fposmod(u + float(offsets[key]), 1.0)
			var base_z := -0.21 if front else 0.26
			var z: float
			var y := 0.0
			var pitch := 0.0
			if ph < st:
				z = base_z - S * 0.5 + (ph / st) * S
			else:
				var w := (ph - st) / (1.0 - st)
				z = base_z + S * 0.5 - S * smoothstep(0.0, 1.0, w)
				y = 0.09 * sin(PI * w)
				pitch = 0.8 * sin(PI * w)
			_leg_keys(an, tr, t, front, side, bp, Vector3(side * 0.09, y, z), pitch)
	return an


## Sitting upright on the haunches; `pet` tilts the head up into the hand,
## half-closes the eyes and sweeps the tail on the ground.
func _make_sit(pet: bool) -> Animation:
	var an := Animation.new()
	var T := 2.0
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tr := _leg_tracks(an)
	var body_p := _track(an, "Body", Animation.TYPE_POSITION_3D)
	var body_r := _track(an, "Body")
	var neck := _track(an, "Neck")
	var head := _track(an, "Head")
	var tail := _track(an, "TailBase")
	var tip := _track(an, "TailTip")
	var ear_l := _track(an, "EarL")
	var ear_r := _track(an, "EarR")
	var eyes := [_track(an, "EyeL", Animation.TYPE_SCALE_3D), _track(an, "EyeR", Animation.TYPE_SCALE_3D)]
	var pitch := 0.75
	var n := 20
	for k in n + 1:
		var t := T * k / n
		var ph := TAU * t / T
		var breath := 0.006 * sin(ph * 1.5)
		an.position_track_insert_key(body_p, t, Vector3(0, 0.385 + breath, 0.08))
		an.rotation_track_insert_key(body_r, t, _q(pitch))
		an.rotation_track_insert_key(neck, t, _q(-0.45 + (0.25 if pet else 0.0), 0.0 if pet else 0.1 * sin(ph * 0.5), 0))
		an.rotation_track_insert_key(head, t, _q(-0.3 + (0.35 if pet else 0.0), 0.0, (0.18 * sin(ph) if pet else 0.0)))
		var wag := (0.7 if pet else 0.3) * sin(ph * (8.0 if pet else 4.0))
		an.rotation_track_insert_key(tail, t, _q(-1.15, wag, 0))
		an.rotation_track_insert_key(tip, t, _q(0.3, wag * 0.6, 0))
		an.rotation_track_insert_key(ear_l, t, _q(-0.2 if pet else 0.0, 0, -0.6 if pet else -0.35))
		an.rotation_track_insert_key(ear_r, t, _q(-0.2 if pet else 0.0, 0, 0.6 if pet else 0.35))
		for e in eyes:
			an.scale_track_insert_key(e, t, Vector3(1, 0.35 if pet else 1.0, 1))
		for side in [-1.0, 1.0]:
			var lr := "L" if side < 0 else "R"
			an.rotation_track_insert_key(tr["FrontUpper" + lr], t, _q(-pitch + 0.05))
			an.rotation_track_insert_key(tr["FrontLower" + lr], t, _q(0.0))
			an.rotation_track_insert_key(tr["FrontPaw" + lr], t, _q(0.0))
			an.rotation_track_insert_key(tr["HindUpper" + lr], t, _q(0.6, 0, side * 0.25))
			an.rotation_track_insert_key(tr["HindLower" + lr], t, _q(-2.5))
			an.rotation_track_insert_key(tr["HindPaw" + lr], t, _q(1.9 - pitch))
	return an


## Standing alert: head up, ears pricked, tail high and still, weight forward.
func _make_alert() -> Animation:
	var an := Animation.new()
	var T := 2.0
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tr := _leg_tracks(an)
	var body_p := _track(an, "Body", Animation.TYPE_POSITION_3D)
	var neck := _track(an, "Neck")
	var head := _track(an, "Head")
	var tail := _track(an, "TailBase")
	var tip := _track(an, "TailTip")
	var ear_l := _track(an, "EarL")
	var ear_r := _track(an, "EarR")
	var n := 10
	for k in n + 1:
		var t := T * k / n
		var bp: Vector3 = rest["Body"].origin + Vector3(0, 0.005, -0.015)
		an.position_track_insert_key(body_p, t, bp)
		an.rotation_track_insert_key(neck, t, _q(0.25))
		an.rotation_track_insert_key(head, t, _q(0.05, 0.05 * sin(TAU * t / T), 0))
		an.rotation_track_insert_key(tail, t, _q(-2.55, 0.03 * sin(TAU * t / T), 0))
		an.rotation_track_insert_key(tip, t, _q(0.1))
		an.rotation_track_insert_key(ear_l, t, _q(-0.25, 0, -0.08))
		an.rotation_track_insert_key(ear_r, t, _q(-0.25, 0, 0.08))
		for side in [-1.0, 1.0]:
			_leg_keys(an, tr, t, true, side, bp, Vector3(side * 0.09, 0, -0.23))
			_leg_keys(an, tr, t, false, side, bp, Vector3(side * 0.09, 0, 0.27))
	return an


# --------------------------------------------------------------- runtime

func play(name: String, blend := 0.3) -> void:
	if current == name:
		return
	current = name
	anim.play(name, blend if name != "lie" else maxf(blend, 1.0))


func set_locomotion(speed: float, rest_clip := "idle") -> void:
	if speed < 0.12:
		play(rest_clip)
		playback_scale = 1.0
	elif speed < 1.7:
		play("walk")
		playback_scale = clampf(speed / WALK_NOMINAL_SPEED, 0.6, 1.6)
	else:
		play("trot", 0.2)
		playback_scale = clampf(speed / TROT_NOMINAL_SPEED, 0.75, 1.5)


func _process(delta: float) -> void:
	# Undo last frame's overlays first: bones the clip does not key would
	# otherwise accumulate them; keyed bones are simply overwritten.
	for b in _ov:
		var n := bones[b] as Node3D
		n.basis = n.basis * (_ov[b] as Basis).inverse()
	_ov.clear()
	if anim:
		anim.advance(delta * playback_scale)
	_look_w = move_toward(_look_w, look_weight if look_target != Vector3.INF else 0.0, delta * 3.0)
	if _look_w > 0.001 and look_target != Vector3.INF:
		var local := global_transform.affine_inverse() * look_target
		var yaw := clampf(atan2(-local.x, -local.z), -1.2, 1.2) * _look_w
		var up := clampf(atan2(local.y - 0.6, Vector2(local.x, local.z).length()), -0.4, 0.5) * _look_w
		_overlay("Neck", Basis(Vector3.UP, yaw * 0.45))
		_overlay("Head", Basis(Vector3.UP, yaw * 0.55) * Basis(Vector3.RIGHT, up))
	if ear_perk > 0.01:
		_overlay("EarL", Basis(Vector3.FORWARD, -0.3 * ear_perk) * Basis(Vector3.RIGHT, -0.3 * ear_perk))
		_overlay("EarR", Basis(Vector3.FORWARD, 0.3 * ear_perk) * Basis(Vector3.RIGHT, -0.3 * ear_perk))


var _ov := {}


func _overlay(bone: String, b: Basis) -> void:
	var n := bones[bone] as Node3D
	n.basis = n.basis * b
	_ov[bone] = b


func paw_positions() -> Array[Vector3]:
	return [bones["FrontPawL"].global_position, bones["FrontPawR"].global_position, bones["HindPawL"].global_position, bones["HindPawR"].global_position]
