class_name HumanCharacter
extends Node3D
## Stylized adult built from a pivot hierarchy (rigid-part articulation; no
## skinning). Joints sit at anatomical positions and limb shapes overlap at
## the joints so rotation never opens gaps. Faces -Z.
##
## Animation: original clips generated in code into an AnimationLibrary and
## played by an AnimationPlayer advanced manually each frame (frame-rate
## independent). Walk/idle legs are solved with analytic IK while baking, so
## stance feet stay planted; the axe-swing preview moves an axe along a
## designed arc and solves both arms to its grips at runtime.
##
## Conventions: in-place clips (no root motion). The mover translates the
## character at WALK_NOMINAL_SPEED * playback scale; `set_locomotion(speed)`
## sets the scale so stride matches speed. Attachment markers: HandR/Grip
## (axe), HandL/Grip, LogCarry (two-hand carry point), Head/LookAt.

const WALK_NOMINAL_SPEED := 1.35
const WALK_PERIOD := 1.0
const STANCE := 0.62

@export var appearance: HumanAppearance

var H := 1.78
var B := 1.0
var hip_y := 0.0
var ankle_h := 0.075
var thigh_len := 0.0
var shin_len := 0.0
var upper_arm_len := 0.0
var forearm_len := 0.0
var foot_side := 0.0

var rig: Node3D
var bones := {}            # name -> Node3D pivot
var rest := {}             # name -> Transform3D (rest local transform)
var anim: AnimationPlayer
var axe_rig: Node3D
var arm_ik := false
var playback_scale := 1.0
var current := ""
## Phase 4: world-space grip targets for a carried load (left, right); when
## set, the arms are solved onto them instead of the clip's arm pose.
var carry_grips: Array = []
var axe_tier := "large"


func _ready() -> void:
	if appearance == null:
		appearance = HumanAppearance.presets()[0]
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	bones.clear()
	H = appearance.height
	B = appearance.build
	thigh_len = (0.51 * H - ankle_h) * 0.5
	shin_len = thigh_len
	hip_y = 0.51 * H
	upper_arm_len = 0.165 * H
	forearm_len = 0.145 * H
	foot_side = 0.055 * H * sqrt(B)
	_build_rig()
	_build_axe()
	_build_animations()
	play("idle", 0.0)


# ------------------------------------------------------------------- rig

func _bone(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	bones[name] = n
	rest[name] = n.transform
	return n


func _build_rig() -> void:
	var a := appearance
	var skin := CharMeshKit.mat(a.skin, 0.55, 0.25)
	var jacket := CharMeshKit.fabric(a.jacket, a.jacket_texture)
	var jacket_dark := CharMeshKit.mat(a.jacket.darkened(0.35), 0.85)
	var shirt := CharMeshKit.mat(a.shirt, 0.9)
	var pants := CharMeshKit.fabric(a.pants)
	var boots := CharMeshKit.mat(a.boots, 0.6)
	var sole := CharMeshKit.mat(Color(0.08, 0.07, 0.06), 0.9)
	var gloves := CharMeshKit.mat(a.gloves, 0.8)
	var hair := CharMeshKit.mat(a.hair, 0.7)
	var belt := CharMeshKit.mat(Color(0.18, 0.12, 0.08), 0.5)
	var eye_white := CharMeshKit.mat(Color(0.95, 0.94, 0.9), 0.3)
	var iris := CharMeshKit.mat(Color(0.12, 0.09, 0.07), 0.2)
	var lip := CharMeshKit.mat(a.skin.darkened(0.35).lerp(Color(0.5, 0.2, 0.2), 0.3), 0.6)
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	var hips := _bone("Hips", rig, Vector3(0, hip_y + 0.02 * H, 0))
	CharMeshKit.blob(hips, pants, Vector3(0, -0.005 * H, 0.004 * H), Vector3(0.21 * H * B, 0.12 * H, 0.14 * H * B), Vector3.ZERO, "Pelvis")
	CharMeshKit.blob(hips, belt, Vector3(0, 0.035 * H, 0), Vector3(0.222 * H * B, 0.028 * H, 0.152 * H * B), Vector3.ZERO, "Belt")
	var spine := _bone("Spine", hips, Vector3(0, 0.05 * H, 0))
	CharMeshKit.blob(spine, jacket, Vector3(0, 0.055 * H, 0.002 * H), Vector3(0.205 * H * B, 0.16 * H, 0.145 * H * B), Vector3.ZERO, "Abdomen")
	var chest := _bone("Chest", spine, Vector3(0, 0.11 * H, 0))
	CharMeshKit.blob(chest, jacket, Vector3(0, 0.07 * H, 0.004 * H), Vector3(0.235 * H * B, 0.2 * H, 0.15 * H * B), Vector3.ZERO, "Torso")
	CharMeshKit.blob(chest, shirt, Vector3(0, 0.148 * H, -0.058 * H * B), Vector3(0.05 * H, 0.035 * H, 0.016 * H), Vector3(0.5, 0, 0), "ShirtV")
	CharMeshKit.blob(chest, jacket_dark, Vector3(0, 0.152 * H, 0.004 * H), Vector3(0.115 * H, 0.035 * H, 0.105 * H), Vector3.ZERO, "Collar")
	for s in [-1.0, 1.0]:
		CharMeshKit.blob(chest, jacket, Vector3(s * 0.098 * H * B, 0.128 * H, 0.004 * H), Vector3(0.068 * H * B, 0.05 * H, 0.078 * H * B), Vector3.ZERO, "Shoulder%s" % ("L" if s < 0 else "R"))
		# Pocket flaps for a workwear read
		CharMeshKit.blob(chest, jacket_dark, Vector3(s * 0.055 * H * B, 0.085 * H, -0.076 * H * B), Vector3(0.05 * H, 0.012 * H, 0.012 * H), Vector3.ZERO)
	var neck := _bone("Neck", chest, Vector3(0, 0.155 * H, 0))
	CharMeshKit.limb(neck, skin, 0.03 * H, 0.03 * H, 0.0).position = Vector3(0, 0.03 * H, 0)
	var head := _bone("Head", neck, Vector3(0, 0.035 * H, 0))
	_build_head(head, skin, hair, eye_white, iris, lip)
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		var shoulder := _bone("UpperArm" + side, chest, Vector3(s * 0.112 * H * B, 0.128 * H, 0.004 * H))
		CharMeshKit.limb(shoulder, jacket, 0.037 * H * B, 0.031 * H * B, upper_arm_len)
		var fore := _bone("Forearm" + side, shoulder, Vector3(0, -upper_arm_len, 0))
		CharMeshKit.limb(fore, jacket, 0.031 * H * B, 0.026 * H * B, forearm_len - 0.01 * H)
		CharMeshKit.blob(fore, jacket_dark, Vector3(0, -forearm_len + 0.012 * H, 0), Vector3(0.062 * H * B, 0.03 * H, 0.062 * H * B), Vector3.ZERO, "Cuff")
		var hand := _bone("Hand" + side, fore, Vector3(0, -forearm_len, 0))
		CharMeshKit.blob(hand, gloves, Vector3(0, -0.032 * H, -0.004 * H), Vector3(0.05 * H, 0.068 * H, 0.032 * H), Vector3.ZERO, "Mitten")
		var thumb := CharMeshKit.limb(hand, gloves, 0.011 * H, 0.009 * H, 0.03 * H)
		thumb.position = Vector3(-s * -0.018 * H, -0.012 * H, -0.016 * H)
		thumb.rotation = Vector3(0.6, 0, s * 0.5)
		var grip := Marker3D.new()
		grip.name = "Grip"
		grip.position = Vector3(0, -0.035 * H, -0.01 * H)
		hand.add_child(grip)
		var thigh := _bone("Thigh" + side, hips, Vector3(s * foot_side, -0.02 * H, 0))
		CharMeshKit.limb(thigh, pants, 0.052 * H * B, 0.039 * H * B, thigh_len)
		var shin := _bone("Shin" + side, thigh, Vector3(0, -thigh_len, 0))
		CharMeshKit.limb(shin, pants, 0.038 * H * B, 0.031 * H * B, shin_len - 0.03 * H)
		CharMeshKit.blob(shin, boots, Vector3(0, -shin_len + 0.035 * H, 0), Vector3(0.075 * H, 0.08 * H, 0.08 * H), Vector3.ZERO, "BootTop")
		var foot := _bone("Foot" + side, shin, Vector3(0, -shin_len, 0))
		CharMeshKit.blob(foot, boots, Vector3(0, -ankle_h * 0.42, -0.035 * H), Vector3(0.068 * H, ankle_h * 1.15, 0.16 * H), Vector3.ZERO, "Boot")
		CharMeshKit.blob(foot, sole, Vector3(0, -ankle_h * 0.92, -0.035 * H), Vector3(0.072 * H, ankle_h * 0.3, 0.165 * H), Vector3.ZERO, "Sole")
	var carry := Marker3D.new()
	carry.name = "LogCarry"
	carry.position = Vector3(0, 0.1 * H, -0.18 * H)
	chest.add_child(carry)
	var look := Marker3D.new()
	look.name = "LookAt"
	look.position = Vector3(0, 0.06 * H, -0.2)
	head.add_child(look)


func _build_head(head: Node3D, skin: Material, hair: Material, eye_white: Material, iris: Material, lip: Material) -> void:
	var a := appearance
	CharMeshKit.blob(head, skin, Vector3(0, 0.058 * H, 0), Vector3(0.125 * H, 0.135 * H, 0.13 * H), Vector3.ZERO, "Skull")
	CharMeshKit.blob(head, skin, Vector3(0, 0.022 * H, -0.016 * H), Vector3(0.098 * H, 0.07 * H, 0.096 * H), Vector3.ZERO, "Jaw")
	CharMeshKit.blob(head, skin, Vector3(0, 0.05 * H, -0.068 * H), Vector3(0.026 * H, 0.038 * H, 0.034 * H), Vector3(0.25, 0, 0), "Nose")
	for s in [-1.0, 1.0]:
		CharMeshKit.blob(head, skin, Vector3(s * 0.064 * H, 0.055 * H, 0.004 * H), Vector3(0.016 * H, 0.036 * H, 0.028 * H), Vector3.ZERO, "Ear")
		CharMeshKit.blob(head, skin, Vector3(s * 0.038 * H, 0.038 * H, -0.052 * H), Vector3(0.03 * H, 0.022 * H, 0.02 * H), Vector3.ZERO, "Cheek")
		var eye := Node3D.new()
		eye.name = "Eye" + ("L" if s < 0 else "R")
		eye.position = Vector3(s * 0.026 * H, 0.068 * H, -0.054 * H)
		head.add_child(eye)
		bones[eye.name] = eye
		rest[eye.name] = eye.transform
		CharMeshKit.blob(eye, eye_white, Vector3.ZERO, Vector3.ONE * 0.024 * H)
		CharMeshKit.blob(eye, iris, Vector3(0, 0, -0.009 * H), Vector3(0.013 * H, 0.014 * H, 0.008 * H))
		var brow := CharMeshKit.blob(head, hair, Vector3(s * 0.028 * H, 0.087 * H, -0.06 * H), Vector3(0.034 * H, 0.008 * H, 0.012 * H), Vector3(0, 0, s * (-0.15 + a.brow_tilt)), "Brow")
		brow.name = "Brow" + ("L" if s < 0 else "R")
	CharMeshKit.blob(head, lip, Vector3(0, 0.028 * H, -0.064 * H), Vector3(0.032 * H, 0.007 * H, 0.012 * H), Vector3.ZERO, "Mouth")
	match a.hair_style:
		0:
			CharMeshKit.blob(head, hair, Vector3(0, 0.095 * H, 0.008 * H), Vector3(0.132 * H, 0.085 * H, 0.138 * H), Vector3(-0.15, 0, 0), "Hair")
		1:
			var beanie := CharMeshKit.mat(a.jacket.lerp(Color(0.15, 0.15, 0.15), 0.4), 0.95)
			CharMeshKit.blob(head, beanie, Vector3(0, 0.102 * H, 0.006 * H), Vector3(0.138 * H, 0.095 * H, 0.142 * H), Vector3(-0.12, 0, 0), "Beanie")
			CharMeshKit.blob(head, beanie, Vector3(0, 0.083 * H, 0.004 * H), Vector3(0.142 * H, 0.03 * H, 0.146 * H), Vector3(-0.12, 0, 0), "BeanieRim")
		2:
			CharMeshKit.blob(head, hair, Vector3(0, 0.094 * H, 0.008 * H), Vector3(0.134 * H, 0.084 * H, 0.14 * H), Vector3(-0.15, 0, 0), "Hair")
			CharMeshKit.blob(head, hair, Vector3(0, 0.122 * H, 0.055 * H), Vector3.ONE * 0.052 * H, Vector3.ZERO, "Bun")
		3:
			var cap := CharMeshKit.mat(Color(0.75, 0.62, 0.3), 0.8)
			CharMeshKit.blob(head, cap, Vector3(0, 0.103 * H, 0.004 * H), Vector3(0.134 * H, 0.072 * H, 0.138 * H), Vector3(-0.08, 0, 0), "Cap")
			CharMeshKit.blob(head, cap, Vector3(0, 0.092 * H, -0.072 * H), Vector3(0.1 * H, 0.008 * H, 0.07 * H), Vector3(-0.1, 0, 0), "Brim")
	if a.beard == 2:
		CharMeshKit.blob(head, hair, Vector3(0, 0.018 * H, -0.038 * H), Vector3(0.106 * H, 0.072 * H, 0.08 * H), Vector3.ZERO, "Beard")
		CharMeshKit.blob(head, hair, Vector3(0, 0.038 * H, -0.066 * H), Vector3(0.04 * H, 0.01 * H, 0.012 * H), Vector3.ZERO, "Moustache")
	elif a.beard == 1:
		var stubble := CharMeshKit.mat(a.skin.lerp(a.hair, 0.35), 0.8)
		CharMeshKit.blob(head, stubble, Vector3(0, 0.02 * H, -0.02 * H), Vector3(0.1 * H, 0.066 * H, 0.098 * H), Vector3.ZERO, "Stubble")


func _build_axe() -> void:
	axe_rig = Node3D.new()
	axe_rig.name = "AxeRig"
	axe_rig.visible = false
	add_child(axe_rig)
	var scene: PackedScene = load("res://assets/polyhaven/models/wooden_axe_02/wooden_axe_02_1k.gltf")
	if scene:
		var axe: Node3D = scene.instantiate()
		axe.name = "Axe"
		axe.scale = Vector3.ONE * 1.15
		# Grip center (between both hands) at the rig origin.
		axe.position = Vector3(0, 0.2, 0)
		axe_rig.add_child(axe)
	var gr := Marker3D.new()
	gr.name = "RightGrip"
	gr.position = Vector3(0, 0.1, 0)
	axe_rig.add_child(gr)
	var gl := Marker3D.new()
	gl.name = "LeftGrip"
	gl.position = Vector3(0, -0.11, 0)
	axe_rig.add_child(gl)


# ------------------------------------------------------------ animation

func _track_rot(an: Animation, bone: String) -> int:
	var t := an.add_track(Animation.TYPE_ROTATION_3D)
	an.track_set_path(t, NodePath("Rig/" + str(rig.get_path_to(bones[bone]))))
	return t


func _track_pos(an: Animation, bone: String) -> int:
	var t := an.add_track(Animation.TYPE_POSITION_3D)
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
	lib.add_animation("swing", _make_swing())
	lib.add_animation("sit", _make_static_pose("sit"))
	lib.add_animation("lie", _make_static_pose("lie"))
	anim.add_animation_library("", lib)


## Leg pose for a foot target given the hips pivot position (rig space).
func _leg_angles(side: float, hips_pos: Vector3, ankle_target: Vector3) -> Vector2:
	var hip := hips_pos + Vector3(side * foot_side, -0.02 * H, 0)
	var d := ankle_target - hip
	return LimbIK.solve_planar(d.y, d.z, thigh_len, shin_len, true)


func _make_idle() -> Animation:
	var an := Animation.new()
	var T := 4.0
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tracks := {}
	for b in ["Hips", "Spine", "Chest", "Neck", "Head", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR", "UpperArmL", "ForearmL", "UpperArmR", "ForearmR", "HandL", "HandR"]:
		tracks[b] = _track_rot(an, b)
	var hips_pos := _track_pos(an, "Hips")
	var post := appearance.posture
	var n := 24
	for k in n + 1:
		var t := T * k / n
		var ph := TAU * t / T
		var hp: Vector3 = rest["Hips"].origin + Vector3(0.012 * sin(ph), -0.012 + 0.004 * sin(ph * 2.0), 0)
		an.position_track_insert_key(hips_pos, t, hp)
		an.rotation_track_insert_key(tracks["Hips"], t, _q(0, 0, -0.02 * sin(ph)))
		an.rotation_track_insert_key(tracks["Spine"], t, _q(0.03 - post * 0.05, 0, 0.015 * sin(ph)))
		an.rotation_track_insert_key(tracks["Chest"], t, _q(0.02 * sin(ph * 3.0) - post * 0.03, 0, 0))
		an.rotation_track_insert_key(tracks["Neck"], t, _q(0.02, 0.0, 0))
		an.rotation_track_insert_key(tracks["Head"], t, _q(0.03 * sin(ph * 0.5 + 1.0), 0.18 * sin(ph * 0.5), 0.02 * sin(ph)))
		for side in [-1.0, 1.0]:
			var sn := "L" if side < 0 else "R"
			var foot := Vector3(side * foot_side * 1.15, ankle_h, -0.01 * side)
			# Feet stay planted while the hips sway: re-solve per sample.
			var hip_world := hp
			var hip := hip_world + Vector3(side * foot_side, -0.02 * H, 0)
			var d := foot - hip
			var ang := LimbIK.solve_planar(d.y, d.z, thigh_len, shin_len, true)
			var roll := atan2(d.x, -d.y) * 0.9
			an.rotation_track_insert_key(tracks["Thigh" + sn], t, _q(ang.x, 0, roll))
			an.rotation_track_insert_key(tracks["Shin" + sn], t, _q(ang.y))
			an.rotation_track_insert_key(tracks["Foot" + sn], t, _q(-(ang.x + ang.y), 0, -roll))
			an.rotation_track_insert_key(tracks["UpperArm" + sn], t, _q(0.06 + 0.02 * sin(ph + side), 0, side * (0.1 + 0.015 * sin(ph * 3.0))))
			an.rotation_track_insert_key(tracks["Forearm" + sn], t, _q(0.22, 0, 0))
			an.rotation_track_insert_key(tracks["Hand" + sn], t, _q(0.1, side * 0.2, 0))
	# Blink: quick squash of both eyes once per loop.
	for e in ["EyeL", "EyeR"]:
		var st := an.add_track(Animation.TYPE_SCALE_3D)
		an.track_set_path(st, NodePath("Rig/" + str(rig.get_path_to(bones[e]))))
		for key in [[0.0, 1.0], [2.4, 1.0], [2.47, 0.1], [2.55, 1.0], [T, 1.0]]:
			an.scale_track_insert_key(st, key[0], Vector3(1, key[1], 1))
	return an


func _make_walk() -> Animation:
	var an := Animation.new()
	var T := WALK_PERIOD
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tracks := {}
	for b in ["Hips", "Spine", "Chest", "Head", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR", "UpperArmL", "ForearmL", "UpperArmR", "ForearmR"]:
		tracks[b] = _track_rot(an, b)
	var hips_pos := _track_pos(an, "Hips")
	var S := WALK_NOMINAL_SPEED * STANCE * T
	var n := 32
	for k in n + 1:
		var t := T * k / n
		var u := t / T
		var hp: Vector3 = rest["Hips"].origin + Vector3(0.008 * sin(TAU * (u - 0.31)), -0.03 + 0.016 * cos(2.0 * TAU * (u - 0.31)), 0)
		an.position_track_insert_key(hips_pos, t, hp)
		an.rotation_track_insert_key(tracks["Hips"], t, _q(0, 0.04 * cos(TAU * u), 0))
		an.rotation_track_insert_key(tracks["Spine"], t, _q(0.05, 0, 0))
		an.rotation_track_insert_key(tracks["Chest"], t, _q(0.0, -0.1 * cos(TAU * u), 0))
		an.rotation_track_insert_key(tracks["Head"], t, _q(-0.02, 0.06 * cos(TAU * u), 0))
		for side in [-1.0, 1.0]:
			var sn := "L" if side < 0 else "R"
			var ph := fposmod(u + (0.0 if side < 0 else 0.5), 1.0)
			var fz: float
			var fy := 0.0
			var pitch := 0.0
			if ph < STANCE:
				fz = -S * 0.5 + (ph / STANCE) * S
				# Heel rise at the end of stance
				pitch = -0.35 * smoothstep(0.75, 1.0, ph / STANCE)
				fy = 0.03 * smoothstep(0.8, 1.0, ph / STANCE)
			else:
				var w := (ph - STANCE) / (1.0 - STANCE)
				fz = S * 0.5 - S * smoothstep(0.0, 1.0, w)
				fy = 0.11 * pow(sin(PI * w), 0.8)
				pitch = 0.25 * sin(PI * w) - 0.35 * (1.0 - smoothstep(0.0, 0.3, w))
			var ankle := Vector3(side * foot_side, ankle_h + fy, fz)
			var ang := _leg_angles(side, hp, ankle)
			an.rotation_track_insert_key(tracks["Thigh" + sn], t, _q(ang.x))
			an.rotation_track_insert_key(tracks["Shin" + sn], t, _q(ang.y))
			an.rotation_track_insert_key(tracks["Foot" + sn], t, _q(-(ang.x + ang.y) + pitch))
			# Arms counter-swing with the opposite leg.
			var opp := fposmod(u + (0.5 if side < 0 else 0.0), 1.0)
			var arm := 0.3 * cos(TAU * opp)
			an.rotation_track_insert_key(tracks["UpperArm" + sn], t, _q(arm, 0, side * 0.1))
			an.rotation_track_insert_key(tracks["Forearm" + sn], t, _q(0.3 + 0.25 * maxf(arm, 0.0) / 0.3))
	return an


func _make_swing() -> Animation:
	var an := Animation.new()
	an.length = 1.7
	an.loop_mode = Animation.LOOP_LINEAR
	var tracks := {}
	for b in ["Hips", "Spine", "Chest", "Head", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR"]:
		tracks[b] = _track_rot(an, b)
	var hips_pos := _track_pos(an, "Hips")
	var axe_pos := an.add_track(Animation.TYPE_POSITION_3D)
	an.track_set_path(axe_pos, NodePath("AxeRig"))
	an.track_set_interpolation_type(axe_pos, Animation.INTERPOLATION_CUBIC)
	var axe_rot := an.add_track(Animation.TYPE_ROTATION_3D)
	an.track_set_path(axe_rot, NodePath("AxeRig"))
	# Swing arc: [time, grip centre, handle dir (bottom->head), travel dir, hips yaw, chest yaw, chest pitch]
	var hs := H / 1.78
	var keys := [
		[0.0, Vector3(0.12, 0.98, -0.32), Vector3(-0.35, 0.55, -0.75), Vector3(0, 1, 0), 0.0, 0.1, 0.05],
		[0.5, Vector3(0.34, 1.38, 0.06), Vector3(0.45, 0.6, 0.66), Vector3(-0.3, -0.2, -0.9), -0.25, -0.6, -0.06],
		[0.66, Vector3(0.32, 1.17, -0.36), Vector3(0.55, 0.15, -0.8), Vector3(-0.85, -0.1, -0.5), -0.08, -0.18, 0.06],
		[0.76, Vector3(0.03, 1.03, -0.56), Vector3(-0.6, 0.02, -0.8), Vector3(-0.8, 0.0, 0.6), 0.15, 0.35, 0.14],
		[0.9, Vector3(-0.2, 0.99, -0.42), Vector3(-0.95, -0.05, -0.2), Vector3(-0.2, 0.0, 0.95), 0.25, 0.55, 0.1],
		[1.35, Vector3(0.12, 0.98, -0.32), Vector3(-0.35, 0.55, -0.75), Vector3(0, 1, 0), 0.0, 0.1, 0.05],
		[1.7, Vector3(0.12, 0.98, -0.32), Vector3(-0.35, 0.55, -0.75), Vector3(0, 1, 0), 0.0, 0.1, 0.05],
	]
	for kk in keys:
		var t: float = kk[0]
		var y: Vector3 = (kk[2] as Vector3).normalized()
		var z: Vector3 = (kk[3] as Vector3)
		z = (z - y * z.dot(y)).normalized()
		var x := y.cross(z)
		an.position_track_insert_key(axe_pos, t, (kk[1] as Vector3) * hs)
		an.rotation_track_insert_key(axe_rot, t, Basis(x, y, z).get_rotation_quaternion())
		var hp: Vector3 = rest["Hips"].origin + Vector3(0, -0.05, 0)
		an.position_track_insert_key(hips_pos, t, hp)
		an.rotation_track_insert_key(tracks["Hips"], t, _q(0.0, kk[4], 0))
		an.rotation_track_insert_key(tracks["Spine"], t, _q(kk[6] * 0.5, kk[5] * 0.4, 0))
		an.rotation_track_insert_key(tracks["Chest"], t, _q(kk[6], kk[5] * 0.6, 0))
		an.rotation_track_insert_key(tracks["Head"], t, _q(-kk[6] * 0.6, -(kk[4] + kk[5]) * 0.7, 0))
		# Wide planted stance (left foot forward), re-solved for the hip height.
		for side in [-1.0, 1.0]:
			var sn := "L" if side < 0 else "R"
			var foot := Vector3(side * foot_side * 1.9, ankle_h, -0.16 if side < 0 else 0.12)
			var hip := hp + Vector3(side * foot_side, -0.02 * H, 0)
			var d := foot - hip
			var ang := LimbIK.solve_planar(d.y, d.z, thigh_len, shin_len, true)
			var roll := atan2(d.x, -d.y)
			an.rotation_track_insert_key(tracks["Thigh" + sn], t, _q(ang.x, 0, roll))
			an.rotation_track_insert_key(tracks["Shin" + sn], t, _q(ang.y))
			an.rotation_track_insert_key(tracks["Foot" + sn], t, _q(-(ang.x + ang.y), 0, -roll))
	return an


## Sitting (chairs/bench) and lying (bed, on the back) poses with slow
## breathing. The mover places/rotates the character; these only pose limbs.
func _make_static_pose(kind: String) -> Animation:
	var an := Animation.new()
	var T := 4.0
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tr := {}
	for b in ["Hips", "Spine", "Chest", "Head", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR", "UpperArmL", "ForearmL", "UpperArmR", "ForearmR"]:
		tr[b] = _track_rot(an, b)
	var hips_pos := _track_pos(an, "Hips")
	for k in 9:
		var t := T * k / 8.0
		var br := 0.015 * sin(TAU * t / T)
		if kind == "sit":
			an.position_track_insert_key(hips_pos, t, rest["Hips"].origin + Vector3(0, -(thigh_len + ankle_h) * 0.98 + 0.46 - 0.02, 0.06))
			an.rotation_track_insert_key(tr["Hips"], t, _q(0))
			an.rotation_track_insert_key(tr["Spine"], t, _q(0.05 + br))
			an.rotation_track_insert_key(tr["Chest"], t, _q(0.04 + br))
			an.rotation_track_insert_key(tr["Head"], t, _q(0.05, 0.15 * sin(TAU * t / T), 0))
			for sn in ["L", "R"]:
				an.rotation_track_insert_key(tr["Thigh" + sn], t, _q(PI * 0.5))
				an.rotation_track_insert_key(tr["Shin" + sn], t, _q(-PI * 0.5))
				an.rotation_track_insert_key(tr["Foot" + sn], t, _q(0))
				an.rotation_track_insert_key(tr["UpperArm" + sn], t, _q(0.35, 0, (0.1 if sn == "R" else -0.1)))
				an.rotation_track_insert_key(tr["Forearm" + sn], t, _q(0.9))
		else:
			an.position_track_insert_key(hips_pos, t, rest["Hips"].origin)
			an.rotation_track_insert_key(tr["Hips"], t, _q(0))
			an.rotation_track_insert_key(tr["Spine"], t, _q(br * 0.5))
			an.rotation_track_insert_key(tr["Chest"], t, _q(-br))
			an.rotation_track_insert_key(tr["Head"], t, _q(-0.1, 0.25, 0))
			for sn in ["L", "R"]:
				var s := -1.0 if sn == "L" else 1.0
				an.rotation_track_insert_key(tr["Thigh" + sn], t, _q(0.05, 0, s * 0.05))
				an.rotation_track_insert_key(tr["Shin" + sn], t, _q(-0.08))
				an.rotation_track_insert_key(tr["Foot" + sn], t, _q(-0.6))
				an.rotation_track_insert_key(tr["UpperArm" + sn], t, _q(0.0, 0, s * 0.18))
				an.rotation_track_insert_key(tr["Forearm" + sn], t, _q(0.35))
	return an


## Shows the assigned axe tier (same models as the first-person axes).
func set_axe_tier(tier: String) -> void:
	if tier == axe_tier and axe_rig.get_node_or_null("Axe"):
		return
	axe_tier = tier
	var old := axe_rig.get_node_or_null("Axe")
	if old:
		old.free()
	var spec: Dictionary = ViewModel.AXES.get(tier, ViewModel.AXES["small"])
	var scene: PackedScene = load("res://assets/polyhaven/models/%s/%s_1k.gltf" % [spec.asset, spec.asset])
	if scene:
		var axe: Node3D = scene.instantiate()
		axe.name = "Axe"
		axe.scale = Vector3.ONE * float(spec.scale) * 0.82
		axe.position = Vector3(0, 0.2 if tier != "small" else 0.1, 0)
		axe_rig.add_child(axe)


# ---------------------------------------------------------------- runtime

func play(name: String, blend := 0.25) -> void:
	if current == name:
		return
	current = name
	arm_ik = name == "swing"
	axe_rig.visible = name == "swing"
	if not arm_ik:
		# Restore FK arm rest so the next clip blends from a sane pose.
		for b in ["UpperArmL", "ForearmL", "UpperArmR", "ForearmR", "HandL", "HandR"]:
			bones[b].transform = rest[b]
	anim.play(name, blend)


## Locomotion helper: picks idle/walk and scales walk playback so the stride
## matches `speed` (m/s).
func set_locomotion(speed: float) -> void:
	if speed < 0.15:
		play("idle")
		playback_scale = 1.0
	else:
		play("walk")
		playback_scale = clampf(speed / WALK_NOMINAL_SPEED, 0.6, 1.7)


func _process(delta: float) -> void:
	if anim:
		anim.advance(delta * playback_scale)
	if arm_ik and axe_rig.visible:
		_solve_arms()
	elif carry_grips.size() == 2:
		_solve_carry()


## Both gloves onto the carried load (shoulder carry), elbows down and out.
func _solve_carry() -> void:
	var back := global_basis.z
	var right := global_basis.x
	var hand_len := 0.035 * H
	var ur: Node3D = bones["UpperArmR"]
	var ul: Node3D = bones["UpperArmL"]
	var tl: Vector3 = (carry_grips[0] as Node3D).global_position if carry_grips[0] is Node3D else carry_grips[0]
	var tr: Vector3 = (carry_grips[1] as Node3D).global_position if carry_grips[1] is Node3D else carry_grips[1]
	LimbIK.solve_nodes(ur, bones["ForearmR"], forearm_len + hand_len, tr, ur.global_position + right * 0.5 - global_basis.y * 0.5 + back * 0.1)
	LimbIK.solve_nodes(ul, bones["ForearmL"], forearm_len + hand_len, tl, ul.global_position - right * 0.5 - global_basis.y * 0.5 + back * 0.1)


func _solve_arms() -> void:
	var rg: Node3D = axe_rig.get_node("RightGrip")
	var lg: Node3D = axe_rig.get_node("LeftGrip")
	var back := global_basis.z
	var right := global_basis.x
	var hand_len := 0.035 * H
	var ur: Node3D = bones["UpperArmR"]
	var ul: Node3D = bones["UpperArmL"]
	LimbIK.solve_nodes(ur, bones["ForearmR"], forearm_len + hand_len, rg.global_position, ur.global_position + right * 0.4 - global_basis.y * 0.6 + back * 0.2)
	LimbIK.solve_nodes(ul, bones["ForearmL"], forearm_len + hand_len, lg.global_position, ul.global_position - right * 0.3 - global_basis.y * 0.6 + back * 0.2)
	# Hands wrap the handle: palms face it, fingers across it.
	var handle := axe_rig.global_basis.y
	for side in ["L", "R"]:
		var hand: Node3D = bones["Hand" + side]
		var down := -(hand.global_basis.y)
		var x := handle.normalized()
		var y := -(down - x * down.dot(x)).normalized()
		hand.global_basis = Basis(x, y, x.cross(y).normalized())


func attachment(name: String) -> Node3D:
	match name:
		"hand_r": return bones["HandR"].get_node("Grip")
		"hand_l": return bones["HandL"].get_node("Grip")
		"log": return bones["Chest"].get_node("LogCarry")
		"look": return bones["Head"].get_node("LookAt")
	return null


## World-space ankle positions (for tests and foot-contact debug).
func ankle_positions() -> Array[Vector3]:
	return [bones["FootL"].global_position, bones["FootR"].global_position]
