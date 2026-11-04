class_name ForemanBody
extends Node3D
## The Foreman's original procedural body (Phase 6). About 3 m unfolded: a
## raised upper-back mass under a heavy stained work coat with faded
## warning-colour seams, a narrow slumped chest, long legs with sudden long
## strides, disproportionately long arms ending in flattened hands with dark
## blunt nails near shin height, a forward head under a rigid weathered
## hood, compressed pale upper-face folds, an off-centre hanging jaw with a
## cramped row of small teeth, and brass-like survey tags at the throat.
## Rigid-part articulation driven in code (walk, sprint, listen, low search,
## doorway fold, reach/attack, head-follows-attention). A stylised
## approximation built without Blender: close-up skin/face quality is an
## acknowledged art gap for Phase 8.
## Faces -Z. Origin at the feet.

const H := 3.0

signal foot_contact(side: int, heavy: bool)

var pose := "idle"            # idle / walk / sprint / listen / search / fold / reach
var _prev_swing := [0.0, 0.0]
var contacts := 0
var speed := 0.0
var head_target := Vector3.INF
var tags_silent := false
var _t := 0.0
var _b := {}
var _fold := 0.0
var _search := 0.0
var _reach := 0.0


func _ready() -> void:
	_build()


func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := CharMeshKit.mat(c, rough)
	m.metallic = metal
	return m


func _pivot(name_: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = pos
	parent.add_child(n)
	_b[name_] = n
	return n


func _build() -> void:
	var coat := _mat(Color(0.42, 0.4, 0.36), 0.95)
	var coat_wet := _mat(Color(0.3, 0.29, 0.27), 0.45)
	var seam := _mat(Color(0.72, 0.62, 0.32), 0.6)
	var skin := _mat(Color(0.74, 0.7, 0.64), 0.55)
	var skin_dark := _mat(Color(0.47, 0.42, 0.38), 0.6)
	var soot := _mat(Color(0.06, 0.055, 0.05), 0.9)
	var nail := _mat(Color(0.09, 0.07, 0.06), 0.3)
	var brass := _mat(Color(0.62, 0.5, 0.28), 0.35, 0.8)
	var teeth := _mat(Color(0.82, 0.78, 0.66), 0.4)
	var hips := _pivot("Hips", self, Vector3(0, 1.45, 0))
	# Legs: long thighs and shins, long flat feet.
	for s in [-1.0, 1.0]:
		var sn := "L" if s < 0 else "R"
		var th := _pivot("Thigh" + sn, hips, Vector3(s * 0.16, 0, 0))
		CharMeshKit.limb(th, coat, 0.11, 0.08, 0.72)
		var sh := _pivot("Shin" + sn, th, Vector3(0, -0.72, 0))
		CharMeshKit.limb(sh, soot, 0.07, 0.05, 0.68)
		var ft := _pivot("Foot" + sn, sh, Vector3(0, -0.68, 0))
		CharMeshKit.blob(ft, soot, Vector3(0, -0.03, -0.1), Vector3(0.11, 0.07, 0.32))
	# Torso: narrow chest, forward slump, raised back mass under the coat.
	var spine := _pivot("Spine", hips, Vector3(0, 0.05, 0))
	spine.rotation.x = 0.32
	CharMeshKit.blob(spine, coat, Vector3(0, 0.45, 0), Vector3(0.28, 0.6, 0.22), Vector3.ZERO, "Chest")
	CharMeshKit.blob(spine, coat_wet, Vector3(0, 0.62, 0.17), Vector3(0.36, 0.46, 0.34), Vector3(0.2, 0, 0), "BackMass")
	CharMeshKit.blob(spine, coat, Vector3(0.06, 0.82, 0.22), Vector3(0.24, 0.26, 0.24), Vector3(0.4, 0, 0.2), "BackMass2")
	# Coat skirt panels hanging to the shins, with faded seams.
	for i in 6:
		var a := TAU * i / 6.0
		var panel := CharMeshKit.blob(hips, coat if i % 2 == 0 else coat_wet, Vector3(sin(a) * 0.2, -0.38, cos(a) * 0.16 + 0.04), Vector3(0.17, 0.62, 0.07), Vector3(0.12 * cos(a), a, 0), "Skirt")
		panel.set_meta("phase", a)
	for k in 3:
		CharMeshKit.blob(spine, seam, Vector3(-0.2 + k * 0.2, 0.3 + k * 0.08, -0.17), Vector3(0.02, 0.32, 0.015), Vector3(0, 0, 0.1 * (k - 1)), "Seam")
	# Neck/head: far forward under a rigid weathered hood.
	var neck := _pivot("Neck", spine, Vector3(0, 0.95, -0.12))
	neck.rotation.x = 0.55
	CharMeshKit.limb(neck, skin_dark, 0.08, 0.07, 0.2)
	var head := _pivot("Head", neck, Vector3(0, 0.22, -0.14))
	CharMeshKit.blob(head, coat_wet, Vector3(0, 0.08, 0.04), Vector3(0.3, 0.3, 0.32), Vector3.ZERO, "Hood")
	CharMeshKit.blob(head, soot, Vector3(0, 0.02, -0.08), Vector3(0.21, 0.24, 0.12), Vector3.ZERO, "Recess")
	# Compressed pale upper-face folds that never line up like a face.
	for k in 4:
		CharMeshKit.blob(head, skin, Vector3(-0.07 + k * 0.045, 0.06 + (k % 2) * 0.03, -0.15), Vector3(0.05, 0.028, 0.03), Vector3(0, 0, 0.3 * (k - 1.5)), "Fold")
	var jaw := _pivot("Jaw", head, Vector3(0.03, -0.08, -0.1))
	jaw.rotation.z = 0.12
	CharMeshKit.blob(jaw, skin_dark, Vector3(0, -0.04, -0.03), Vector3(0.13, 0.05, 0.1), Vector3.ZERO, "JawBone")
	for k in 7:
		CharMeshKit.blob(jaw, teeth, Vector3(-0.045 + k * 0.015, -0.015, -0.085), Vector3(0.008, 0.016, 0.008), Vector3.ZERO, "Tooth")
	# Survey tags at the throat.
	for k in 4:
		CharMeshKit.blob(neck, brass, Vector3(-0.06 + k * 0.04, -0.02, -0.08), Vector3(0.022, 0.03, 0.004), Vector3.ZERO, "Tag")
	# Long arms ending near shin height; flattened hands with dark nails.
	for s in [-1.0, 1.0]:
		var sn := "L" if s < 0 else "R"
		var sh := _pivot("Shoulder" + sn, spine, Vector3(s * 0.2, 0.85, 0.02))
		CharMeshKit.limb(sh, coat, 0.08, 0.06, 0.82)
		var el := _pivot("Elbow" + sn, sh, Vector3(0, -0.82, 0))
		CharMeshKit.limb(el, skin_dark, 0.055, 0.045, 0.78)
		var hand := _pivot("Hand" + sn, el, Vector3(0, -0.78, 0))
		CharMeshKit.blob(hand, skin, Vector3(0, -0.06, 0), Vector3(0.09, 0.14, 0.04), Vector3.ZERO, "Palm")
		for f in 4:
			var fp := _pivot("Finger%s%d" % [sn, f], hand, Vector3(-0.045 + f * 0.03, -0.13, 0))
			CharMeshKit.limb(fp, skin, 0.014, 0.011, 0.16)
			CharMeshKit.blob(fp, nail, Vector3(0, -0.17, 0), Vector3(0.012, 0.025, 0.01), Vector3.ZERO, "Nail")
	for c in find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _process(delta: float) -> void:
	_t += delta
	_fold = move_toward(_fold, 1.0 if pose == "fold" else 0.0, delta * 1.8)
	_search = move_toward(_search, 1.0 if pose == "search" else 0.0, delta * 1.2)
	_reach = move_toward(_reach, 1.0 if pose == "reach" else 0.0, delta * 3.0)
	var moving := pose in ["walk", "sprint"]
	var stride_hz := 0.55 if pose == "walk" else 1.25
	var ph := _t * TAU * stride_hz * clampf(speed / (1.7 if pose == "walk" else 6.5), 0.5, 1.4)
	var amp := (0.55 if pose == "walk" else 0.85) if moving else 0.0
	# Legs: very long sudden steps; torso stays almost level.
	for s in [-1.0, 1.0]:
		var sn := "L" if s < 0 else "R"
		var off := 0.0 if s < 0 else PI
		var thigh: Node3D = _b["Thigh" + sn]
		var shin: Node3D = _b["Shin" + sn]
		var swing := sin(ph + off)
		# Foot plant = the swing crossing from forward to back: the step
		# sound is emitted by the motion itself (no free-running timer).
		var si := 0 if s < 0 else 1
		if moving and amp > 0.0 and float(_prev_swing[si]) > 0.0 and swing <= 0.0:
			contacts += 1
			foot_contact.emit(si, pose == "sprint")
		_prev_swing[si] = swing if moving else 0.0
		thigh.rotation.x = -swing * amp - _search * 1.3 - _fold * 0.9
		shin.rotation.x = maxf(0.0, cos(ph + off)) * amp * 1.2 + _search * 2.0 + _fold * 1.2
	var hips: Node3D = _b["Hips"]
	hips.position.y = 1.45 - _search * 0.75 - _fold * 0.55 + (absf(sin(ph)) * 0.03 if moving else 0.0)
	var spine: Node3D = _b["Spine"]
	spine.rotation.x = 0.32 + _search * 0.75 + _fold * 0.85 + (0.18 if pose == "sprint" else 0.0)
	# Arms hang low; reach brings one forward; search plants a hand.
	for s in [-1.0, 1.0]:
		var sn := "L" if s < 0 else "R"
		var sh: Node3D = _b["Shoulder" + sn]
		var el: Node3D = _b["Elbow" + sn]
		var swing2 := sin(ph + (PI if s < 0 else 0.0)) * (0.3 if moving else 0.0)
		sh.rotation.x = -0.25 + swing2 - (_reach * 1.3 if s > 0 else 0.0) - _search * (0.6 if s < 0 else 0.2)
		sh.rotation.z = s * (0.06 + _fold * 0.25)
		el.rotation.x = -0.15 - _reach * 0.2 - _search * 0.3
	# Coat skirt sways with stride.
	for c in hips.get_children():
		if c.has_meta("phase"):
			(c as Node3D).rotation.x = 0.1 * sin(ph * 2.0 + float(c.get_meta("phase"))) * (1.0 if moving else 0.2)
	# Head keeps attention after the body turns (eases toward the target).
	var head: Node3D = _b["Head"]
	if head_target != Vector3.INF:
		var local := global_transform.affine_inverse() * head_target
		var yaw := clampf(atan2(-local.x, -local.z), -1.1, 1.1)
		head.rotation.y = lerp_angle(head.rotation.y, yaw, delta * (0.8 if pose == "listen" else 2.0))
		head.rotation.z = lerpf(head.rotation.z, 0.35 if pose == "listen" else 0.12, delta)
	else:
		head.rotation.y = lerp_angle(head.rotation.y, 0.0, delta)
	var jaw: Node3D = _b["Jaw"]
	jaw.rotation.x = 0.05 + _reach * 0.5 + (0.02 * sin(_t * 0.7) if pose == "listen" else 0.0)
