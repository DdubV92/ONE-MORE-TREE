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
## Phase 12: motion-captured clips (the owner's Mixamo FBX files, retargeted
## to this rig by tools/bake_mixamo.gd). Procedural clips remain the
## fallback when the data file is absent.
const MOCAP_PATH := "res://data/anim/mixamo_retarget.json"
const RUN_MIN_SPEED := 2.3
static var _mocap: Dictionary = {}
## Ground speed (m/s) of the walk/run clips at playback 1.0 for THIS body.
var walk_nominal := WALK_NOMINAL_SPEED
var run_nominal := 3.0
var _contacts := {}       # clip -> [[t, side], ...]
var _nominal := {}        # locomotion clip -> m/s at playback 1.0 for this body
var _clip_prev := -1.0

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
	var glove_cuff := CharMeshKit.mat(a.gloves.darkened(0.3), 0.85)
	var knee := CharMeshKit.mat(a.pants.darkened(0.12), 0.95)
	var accent := CharMeshKit.mat(a.accent, 0.6)
	var stitch := CharMeshKit.mat(a.jacket.darkened(0.28), 0.9)
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	var hips := _bone("Hips", rig, Vector3(0, hip_y + 0.02 * H, 0))
	CharMeshKit.blob(hips, pants, Vector3(0, -0.005 * H, 0.004 * H), Vector3(0.21 * H * B, 0.12 * H, 0.14 * H * B), Vector3.ZERO, "Pelvis")
	CharMeshKit.blob(hips, belt, Vector3(0, 0.035 * H, 0), Vector3(0.222 * H * B, 0.028 * H, 0.152 * H * B), Vector3.ZERO, "Belt")
	var spine := _bone("Spine", hips, Vector3(0, 0.05 * H, 0))
	# Phase 11: the trunk is two overlapping tapered capsules (ribcage and
	# waist), flattened front-to-back - one continuous jacket silhouette
	# instead of stacked balloons.
	var waist := Node3D.new()
	# Span: spine +0.13 H (overlapping the ribcage) down to the belt line.
	waist.position = Vector3(0, 0.081 * H, 0.002 * H)
	waist.scale = Vector3(1.0, 0.497, 0.68)
	spine.add_child(waist)
	CharMeshKit.limb(waist, jacket, 0.098 * H * B, 0.094 * H * B, 0.15 * H)
	var chest := _bone("Chest", spine, Vector3(0, 0.11 * H, 0))
	var ribs := Node3D.new()
	# Span: the shoulder line (chest +0.17 H) down to just above the waist.
	ribs.position = Vector3(0, 0.112 * H, 0.004 * H)
	ribs.scale = Vector3(1.0, 0.526, 0.64)
	chest.add_child(ribs)
	CharMeshKit.limb(ribs, jacket, 0.11 * H * B, 0.1 * H * B, 0.17 * H)
	CharMeshKit.blob(chest, shirt, Vector3(0, 0.148 * H, -0.058 * H * B), Vector3(0.05 * H, 0.035 * H, 0.016 * H), Vector3(0.5, 0, 0), "ShirtV")
	CharMeshKit.blob(chest, jacket_dark, Vector3(0, 0.152 * H, 0.004 * H), Vector3(0.115 * H, 0.035 * H, 0.105 * H), Vector3.ZERO, "Collar")
	# Phase 11 workwear read: zip placket, hem over the belt, hi-vis band
	# on the shoulders (restrained accent), shoulder seams.
	CharMeshKit.blob(chest, stitch, Vector3(0, 0.07 * H, -0.071 * H * B), Vector3(0.006 * H, 0.15 * H, 0.006 * H), Vector3.ZERO, "Placket")
	CharMeshKit.blob(spine, jacket, Vector3(0, -0.012 * H, 0.003 * H), Vector3(0.214 * H * B, 0.05 * H, 0.152 * H * B), Vector3.ZERO, "Hem")
	CharMeshKit.blob(spine, jacket_dark, Vector3(0, -0.034 * H, 0.003 * H), Vector3(0.216 * H * B, 0.012 * H, 0.154 * H * B), Vector3.ZERO, "HemBand")
	CharMeshKit.blob(chest, accent, Vector3(0, 0.118 * H, 0.068 * H * B), Vector3(0.2 * H * B, 0.012 * H, 0.012 * H), Vector3.ZERO, "BackBand")
	for s in [-1.0, 1.0]:
		CharMeshKit.blob(chest, jacket, Vector3(s * 0.098 * H * B, 0.13 * H, 0.004 * H), Vector3(0.056 * H * B, 0.04 * H, 0.066 * H * B), Vector3.ZERO, "Shoulder%s" % ("L" if s < 0 else "R"))
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
		_build_hand(hand, gloves, glove_cuff, s)
		var grip := Marker3D.new()
		grip.name = "Grip"
		grip.position = Vector3(0, -0.035 * H, -0.01 * H)
		hand.add_child(grip)
		var thigh := _bone("Thigh" + side, hips, Vector3(s * foot_side, -0.02 * H, 0))
		CharMeshKit.limb(thigh, pants, 0.052 * H * B, 0.039 * H * B, thigh_len)
		var shin := _bone("Shin" + side, thigh, Vector3(0, -thigh_len, 0))
		CharMeshKit.limb(shin, pants, 0.038 * H * B, 0.031 * H * B, shin_len - 0.03 * H)
		CharMeshKit.blob(shin, boots, Vector3(0, -shin_len + 0.035 * H, 0), Vector3(0.075 * H, 0.08 * H, 0.08 * H), Vector3.ZERO, "BootTop")
		CharMeshKit.blob(shin, knee, Vector3(0, -0.012 * H, -0.03 * H * B), Vector3(0.066 * H * B, 0.08 * H, 0.012 * H), Vector3.ZERO, "KneePatch")
		var foot := _bone("Foot" + side, shin, Vector3(0, -shin_len, 0))
		CharMeshKit.blob(foot, boots, Vector3(0, -ankle_h * 0.42, -0.035 * H), Vector3(0.068 * H, ankle_h * 1.15, 0.16 * H), Vector3.ZERO, "Boot")
		CharMeshKit.blob(foot, sole, Vector3(0, -ankle_h * 0.92, -0.035 * H), Vector3(0.072 * H, ankle_h * 0.3, 0.165 * H), Vector3.ZERO, "Sole")
		CharMeshKit.blob(foot, sole, Vector3(0, -ankle_h * 0.35, -0.1 * H), Vector3(0.06 * H, ankle_h * 0.8, 0.05 * H), Vector3.ZERO, "ToeCap")
		CharMeshKit.blob(foot, sole, Vector3(0, ankle_h * 0.05, -0.045 * H), Vector3(0.016 * H, ankle_h * 0.5, 0.05 * H), Vector3(0.45, 0, 0), "Laces")
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
	CharMeshKit.blob(head, skin, Vector3(0, 0.022 * H, -0.016 * H), Vector3(0.098 * H * a.jaw, 0.07 * H, 0.096 * H), Vector3.ZERO, "Jaw")
	# Chin and jaw angle: a readable lower-face silhouette, not an egg.
	CharMeshKit.blob(head, skin, Vector3(0, 0.004 * H, -0.05 * H), Vector3(0.05 * H * a.jaw, 0.03 * H, 0.03 * H), Vector3.ZERO, "Chin")
	for s in [-1.0, 1.0]:
		CharMeshKit.blob(head, skin, Vector3(s * 0.04 * H * a.jaw, 0.018 * H, -0.02 * H), Vector3(0.03 * H, 0.04 * H, 0.06 * H), Vector3(0, 0, s * 0.25), "JawAngle")
	CharMeshKit.blob(head, skin, Vector3(0, 0.05 * H, -0.068 * H), Vector3(0.026 * H * a.nose, 0.038 * H * a.nose, 0.034 * H * a.nose), Vector3(0.25, 0, 0), "Nose")
	CharMeshKit.blob(head, skin, Vector3(0, 0.034 * H, -0.074 * H), Vector3(0.03 * H * a.nose, 0.014 * H, 0.016 * H), Vector3.ZERO, "NoseTip")
	for s in [-1.0, 1.0]:
		CharMeshKit.blob(head, skin, Vector3(s * 0.064 * H, 0.055 * H, 0.004 * H), Vector3(0.016 * H, 0.036 * H, 0.028 * H) * a.ear, Vector3.ZERO, "Ear")
		CharMeshKit.blob(head, skin, Vector3(s * 0.038 * H, 0.038 * H, -0.052 * H), Vector3(0.03 * H, 0.022 * H, 0.02 * H) * a.cheek, Vector3.ZERO, "Cheek")
		# Upper eyelid shelf: gives the eyes a readable gaze/expression.
		CharMeshKit.blob(head, skin, Vector3(s * 0.026 * H, 0.077 * H, -0.056 * H), Vector3(0.028 * H, 0.008 * H, 0.016 * H), Vector3(0.2, 0, s * (-0.08 + a.brow_tilt * 0.5)), "Lid")
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
		4:
			# Curly crop: a cluster of small rounded masses (silhouette, not strands).
			var hr := RandomNumberGenerator.new()
			hr.seed = int(a.height * 1000.0)
			CharMeshKit.blob(head, hair, Vector3(0, 0.094 * H, 0.008 * H), Vector3(0.13 * H, 0.08 * H, 0.136 * H), Vector3(-0.15, 0, 0), "Hair")
			for k in 14:
				var ang := TAU * k / 14.0
				CharMeshKit.blob(head, hair, Vector3(sin(ang) * 0.055 * H, 0.112 * H + 0.01 * H * cos(ang * 2.0), cos(ang) * 0.055 * H + 0.008 * H), Vector3.ONE * 0.04 * H * hr.randf_range(0.85, 1.15), Vector3.ZERO, "Curl")
			var cap2 := CharMeshKit.mat(a.accent.darkened(0.3), 0.8)
			CharMeshKit.blob(head, cap2, Vector3(0, 0.118 * H, 0.004 * H), Vector3(0.12 * H, 0.05 * H, 0.124 * H), Vector3(-0.08, 0, 0), "Cap")
			CharMeshKit.blob(head, cap2, Vector3(0, 0.104 * H, -0.07 * H), Vector3(0.09 * H, 0.008 * H, 0.06 * H), Vector3(-0.1, 0, 0), "Brim")
		5:
			CharMeshKit.blob(head, hair, Vector3(0, 0.095 * H, 0.01 * H), Vector3(0.134 * H, 0.086 * H, 0.142 * H), Vector3(-0.15, 0, 0), "Hair")
			CharMeshKit.blob(head, hair, Vector3(0, 0.05 * H, 0.07 * H), Vector3(0.05 * H, 0.05 * H, 0.04 * H), Vector3.ZERO, "Tie")
			CharMeshKit.limb(head, hair, 0.022 * H, 0.012 * H, 0.1 * H).position = Vector3(0, 0.05 * H, 0.08 * H)
		6:
			CharMeshKit.blob(head, hair, Vector3(0, 0.092 * H, 0.008 * H), Vector3(0.128 * H, 0.074 * H, 0.134 * H), Vector3(-0.15, 0, 0), "Buzz")
			CharMeshKit.blob(head, hair, Vector3(0.03 * H, 0.122 * H, -0.02 * H), Vector3(0.07 * H, 0.02 * H, 0.08 * H), Vector3(0, 0, -0.2), "SidePart")
		3:
			var cap := CharMeshKit.mat(Color(0.75, 0.62, 0.3), 0.8)
			CharMeshKit.blob(head, cap, Vector3(0, 0.103 * H, 0.004 * H), Vector3(0.134 * H, 0.072 * H, 0.138 * H), Vector3(-0.08, 0, 0), "Cap")
			CharMeshKit.blob(head, cap, Vector3(0, 0.092 * H, -0.072 * H), Vector3(0.1 * H, 0.008 * H, 0.07 * H), Vector3(-0.1, 0, 0), "Brim")
	if a.beard == 2:
		CharMeshKit.blob(head, hair, Vector3(0, 0.018 * H, -0.038 * H), Vector3(0.106 * H, 0.072 * H, 0.08 * H), Vector3.ZERO, "Beard")
		CharMeshKit.blob(head, hair, Vector3(0, 0.038 * H, -0.066 * H), Vector3(0.04 * H, 0.01 * H, 0.012 * H), Vector3.ZERO, "Moustache")
	elif a.beard == 3:
		CharMeshKit.blob(head, hair, Vector3(0, 0.038 * H, -0.066 * H), Vector3(0.046 * H, 0.012 * H, 0.014 * H), Vector3.ZERO, "Moustache")
	elif a.beard == 1:
		var stubble := CharMeshKit.mat(a.skin.lerp(a.hair, 0.35), 0.8)
		CharMeshKit.blob(head, stubble, Vector3(0, 0.02 * H, -0.02 * H), Vector3(0.1 * H, 0.066 * H, 0.098 * H), Vector3.ZERO, "Stubble")


## Phase 11 gloved hand: palm, four curled fingers in two pairs, thumb and
## a glove cuff - a real grip silhouette instead of a mitten block. Fingers
## curl toward the palm (-Z) so they wrap a handle at the Grip marker.
func _build_hand(hand: Node3D, gloves: Material, cuff: Material, s: float) -> void:
	CharMeshKit.blob(hand, cuff, Vector3(0, -0.004 * H, 0), Vector3(0.05 * H, 0.022 * H, 0.04 * H), Vector3.ZERO, "GloveCuff")
	CharMeshKit.blob(hand, gloves, Vector3(0, -0.028 * H, -0.002 * H), Vector3(0.048 * H, 0.05 * H, 0.026 * H), Vector3.ZERO, "Palm")
	for k in 4:
		var fx := (-0.018 + 0.012 * k) * H * s
		var f := Node3D.new()
		f.name = "Finger%d" % k
		f.position = Vector3(fx, -0.05 * H, -0.002 * H)
		f.rotation = Vector3(0.75, 0, 0)
		hand.add_child(f)
		var flen := (0.03 if k in [1, 2] else 0.026) * H
		CharMeshKit.limb(f, gloves, 0.0068 * H, 0.0058 * H, flen)
		var tip := Node3D.new()
		tip.position = Vector3(0, -flen, 0)
		tip.rotation = Vector3(0.8, 0, 0)
		f.add_child(tip)
		CharMeshKit.limb(tip, gloves, 0.0058 * H, 0.005 * H, flen * 0.7)
	var th := Node3D.new()
	th.name = "Thumb"
	th.position = Vector3(-s * 0.022 * H, -0.016 * H, -0.012 * H)
	th.rotation = Vector3(0.9, 0, s * 0.55)
	hand.add_child(th)
	CharMeshKit.limb(th, gloves, 0.0085 * H, 0.007 * H, 0.028 * H)


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
	# Phase 8 coverage: work handling, conversation, fear, trait idles,
	# driving and hiding. All share the rig; feet stay planted by IK.
	for k in CLIPS:
		lib.add_animation(k, _make_body_clip(CLIPS[k]))
	# Phase 12: motion capture replaces walk/sit/lie and adds run; the
	# procedural versions stay available as *_proc.
	if has_mocap("walk"):
		for k in ["walk", "sit", "lie"]:
			lib.add_animation(k + "_proc", lib.get_animation(k))
			lib.remove_animation(k)
		for k in ["walk", "run", "sit", "sit_relaxed", "lie"]:
			if has_mocap(k):
				lib.add_animation(k, _make_mocap(k))
		# Brisk working pace from the same captured walk: longer stride, so
		# 1.2-1.6 m/s plays at a natural cadence instead of a sped-up stroll.
		lib.add_animation("walk_brisk", _make_mocap("walk_brisk", "walk", 1.45))
		walk_nominal = float(_nominal.get("walk", walk_nominal))
		run_nominal = float(_nominal.get("run", run_nominal))
		# Driving: mocap seated body, procedural hands on the wheel.
		if has_mocap("sit"):
			var drive := _make_mocap("sit")
			var proc: Animation = lib.get_animation("drive")
			for b in ["UpperArmL", "ForearmL", "UpperArmR", "ForearmR", "HandL", "HandR"]:
				var ti := drive.find_track(NodePath("Rig/" + str(rig.get_path_to(bones[b]))), Animation.TYPE_ROTATION_3D)
				if ti >= 0:
					drive.remove_track(ti)
			for ti in proc.get_track_count():
				var path := str(proc.track_get_path(ti))
				if path.contains("Arm") or path.contains("Forearm"):
					proc.copy_track(ti, drive)
			lib.remove_animation("drive")
			lib.add_animation("drive", drive)
		_layer_mocap_breath(lib.get_animation("idle"))
		for k in ["talk", "listen", "fear"]:
			if lib.has_animation(k):
				_layer_mocap_breath(lib.get_animation(k), 0.6)
	anim.add_animation_library("", lib)


# -------------------------------------------------------- motion capture

static func mocap() -> Dictionary:
	if _mocap.is_empty() and FileAccess.file_exists(MOCAP_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOCAP_PATH))
		_mocap = d if d is Dictionary else {"clips": {}}
	return _mocap


static func has_mocap(name: String) -> bool:
	return (mocap().get("clips", {}) as Dictionary).has(name)


static func _mq(clip: Dictionary, bone: String, f: int) -> Quaternion:
	var a: Array = clip.rot[bone]
	var i := (f % int(clip.frames)) * 4
	return Quaternion(float(a[i]), float(a[i + 1]), float(a[i + 2]), float(a[i + 3])).normalized()


static func _mhips(clip: Dictionary, f: int) -> Vector3:
	var a: Array = clip.hips
	var i := (f % int(clip.frames)) * 3
	return Vector3(float(a[i]), float(a[i + 1]), float(a[i + 2]))


## Builds a clip for THIS body from the retargeted data: hip offsets scaled
## by this character's hip height; locomotion feet re-planted with its own
## thigh/shin lengths; seated clips anchored to the seat height the seats
## were designed for; lying clips body-relative (the bed orients the body).
func _make_mocap(name: String, src := "", stride := 1.0) -> Animation:
	var data := mocap()
	var clip: Dictionary = data.clips[src if src != "" else name]
	var fps: float = data.fps
	var n: int = clip.frames
	var kind := str(clip.kind)
	var loop := bool(clip.loop)
	var an := Animation.new()
	an.length = float(clip.length)
	an.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for b in data.bones:
		tracks[b] = _track_rot(an, b)
	var hips_pos := _track_pos(an, "Hips")
	# Per-frame rotations for this clip, with the clip-level adjustments:
	#  - the captured walk keeps its elbows bent ~90 deg (forearms forward);
	#    relax them halfway for a looser woodcutter's walk;
	#  - `stride` > 1 amplifies leg/arm swing about the clip's average pose
	#    (a longer, brisker stride from the same capture).
	var qs := {}
	for b in data.bones:
		var arr: Array[Quaternion] = []
		for f in n:
			arr.append(_mq(clip, b, f))
		var relax := 0.5 if name.begins_with("walk") and b in ["ForearmL", "ForearmR", "HandL", "HandR"] else 1.0
		var amp := stride if b.begins_with("Thigh") or b.begins_with("Shin") or b.begins_with("Foot") else (1.0 + (stride - 1.0) * 0.6 if b.begins_with("UpperArm") else 1.0)
		if relax != 1.0 or amp != 1.0:
			var acc := Vector4.ZERO
			for q in arr:
				acc += Vector4(q.x, q.y, q.z, q.w)
			var mq := Quaternion(acc.x, acc.y, acc.z, acc.w).normalized()
			for f in n:
				var q: Quaternion = arr[f]
				if amp != 1.0:
					var d := (mq.inverse() * q).normalized()
					var ang := d.get_angle()
					if ang > 0.0001:
						q = mq * Quaternion(d.get_axis().normalized(), ang * amp)
				if relax != 1.0:
					q = Quaternion.IDENTITY.slerp(q, relax)
				arr[f] = q.normalized()
		qs[b] = arr
	var hip_h: float = rest["Hips"].origin.y
	var mean := Vector3.ZERO
	for f in n:
		mean += _mhips(clip, f)
	mean /= float(n)
	var seat_hp: Vector3 = rest["Hips"].origin + Vector3(0, -(thigh_len + ankle_h) * 0.98 + 0.46 - 0.02, 0.06)
	var hps: Array[Vector3] = []
	var dys := PackedFloat32Array()
	for f in n:
		var off := _mhips(clip, f) * hip_h
		var hp: Vector3
		match kind:
			"seated":
				hp = seat_hp + (off - mean * hip_h) * 0.6
			"lying":
				hp = rest["Hips"].origin + (off - mean * hip_h) * 0.3
			_:
				hp = rest["Hips"].origin + off
		hps.append(hp)
		if kind == "locomotion":
			var lo := INF
			for sn in ["L", "R"]:
				lo = minf(lo, _fk_ankle_q(qs, f, hp, sn).y)
			dys.append(ankle_h - lo)
	if kind == "locomotion":
		# Walk: plant the lower foot every frame (smoothed); run keeps its
		# flight phase, so one constant offset puts its lowest step on the ground.
		var run := name == "run"
		var const_dy := -INF
		for d in dys:
			const_dy = maxf(const_dy, d)
		for f in n:
			var d := const_dy if run else (dys[(f - 1 + n) % n] + dys[f] * 2.0 + dys[(f + 1) % n]) * 0.25
			hps[f] = hps[f] + Vector3(0, d, 0)
		# Nominal ground speed for THIS body: how fast the planted foot slides
		# back under the hips in mid-stance (15-75 % of each plant window),
		# measured with its own legs, so playback scale = speed / nominal
		# leaves the stance foot still on the ground (no skating).
		var cs: Array = clip.get("contacts", [])
		var sum := 0.0
		var cnt := 0
		for ci in cs.size():
			var c: Array = cs[ci]
			var nxt: Array = cs[(ci + 1) % cs.size()]
			var span := fposmod(float(nxt[0]) - float(c[0]), float(clip.length))
			var sn := "L" if int(c[1]) == 0 else "R"
			var f0 := int(round((float(c[0]) + span * 0.15) * fps))
			var f1 := int(round((float(c[0]) + span * 0.75) * fps))
			if f1 <= f0:
				continue
			var z0 := _fk_ankle_q(qs, f0 % n, hps[f0 % n], sn).z
			var z1 := _fk_ankle_q(qs, f1 % n, hps[f1 % n], sn).z
			sum += (z1 - z0) / (float(f1 - f0) / fps)
			cnt += 1
		var sp := sum / cnt if cnt > 0 else float(clip.get("speed_norm", 0.0)) * hip_h
		_nominal[name] = maxf(sp, 0.4)
		_contacts[name] = cs
	for f in n + (1 if loop else 0):
		var t := minf(float(f) / fps, an.length)
		an.position_track_insert_key(hips_pos, t, hps[f % n])
		for b in data.bones:
			an.rotation_track_insert_key(tracks[b], t, (qs[b] as Array)[f % n])
	return an


func _fk_ankle_q(qs: Dictionary, f: int, hp: Vector3, sn: String) -> Vector3:
	var rh := Basis((qs["Hips"] as Array)[f])
	var rt := rh * Basis((qs["Thigh" + sn] as Array)[f])
	var rs := rt * Basis((qs["Shin" + sn] as Array)[f])
	var knee: Vector3 = hp + rh * rest["Thigh" + sn].origin + rt * rest["Shin" + sn].origin
	return knee + rs * rest["Foot" + sn].origin


## Ankle (Foot pivot) position in rig space for frame f, using this body's
## own bone offsets and the clip's rotations.
func _fk_ankle(clip: Dictionary, f: int, hp: Vector3, sn: String) -> Vector3:
	var rh := Basis(_mq(clip, "Hips", f))
	var rt := rh * Basis(_mq(clip, "Thigh" + sn, f))
	var rs := rt * Basis(_mq(clip, "Shin" + sn, f))
	var knee: Vector3 = hp + rh * rest["Thigh" + sn].origin + rt * rest["Shin" + sn].origin
	return knee + rs * rest["Foot" + sn].origin


## Adds the captured seated idle's upper-body micro-motion (breathing,
## settling, small head turns) on top of a standing procedural clip, as
## offsets from its own average pose, so idles and talk feel alive.
func _layer_mocap_breath(an: Animation, amount := 1.0) -> void:
	if not has_mocap("sit"):
		return
	var data := mocap()
	var clip: Dictionary = data.clips.sit
	var fps: float = data.fps
	var n: int = clip.frames
	for b in ["Spine", "Chest", "Neck", "Head"]:
		var ti := an.find_track(NodePath("Rig/" + str(rig.get_path_to(bones[b]))), Animation.TYPE_ROTATION_3D)
		if ti < 0:
			continue
		var acc := Vector4.ZERO
		for f in n:
			var q := _mq(clip, b, f)
			acc += Vector4(q.x, q.y, q.z, q.w)
		var mean_q := Quaternion(acc.x, acc.y, acc.z, acc.w).normalized()
		for k in an.track_get_key_count(ti):
			var t := an.track_get_key_time(ti, k)
			var f := int(round(fmod(t, float(clip.length)) * fps)) % n
			var delta := (mean_q.inverse() * _mq(clip, b, f)).normalized()
			delta = Quaternion.IDENTITY.slerp(delta, amount)
			an.track_set_key_value(ti, k, (an.track_get_key_value(ti, k) as Quaternion) * delta)


## Leg pose for a foot target given the hips pivot position (rig space).
func _leg_angles(side: float, hips_pos: Vector3, ankle_target: Vector3) -> Vector2:
	var hip := hips_pos + Vector3(side * foot_side, -0.02 * H, 0)
	var d := ankle_target - hip
	return LimbIK.solve_planar(d.y, d.z, thigh_len, shin_len, true)


## Authored body clips (Phase 8). Each key: t, drop (hip lowering m),
## spine/chest pitch, chest yaw, head pitch/yaw/roll, upper-arm pitch/roll
## and forearm bend per side, and foot forward offsets. Feet are re-solved
## with planar IK at every key so they stay on the ground (no sliding).
const CLIPS := {
	# Bend, reach to a log at shin height, straighten (0.8 s, one-shot).
	"pickup": {"T": 0.8, "loop": false, "keys": [
		{"t": 0.0},
		{"t": 0.35, "drop": 0.28, "spine": 0.55, "chest": 0.35, "head_p": -0.2, "uaL": [1.1, -0.15], "uaR": [1.1, 0.15], "faL": 0.15, "faR": 0.15, "fL": 0.12, "fR": -0.08},
		{"t": 0.5, "drop": 0.26, "spine": 0.5, "chest": 0.3, "head_p": -0.15, "uaL": [0.9, -0.15], "uaR": [0.9, 0.15], "faL": 0.6, "faR": 0.6, "fL": 0.12, "fR": -0.08},
		{"t": 0.8, "uaL": [0.4, -0.1], "uaR": [0.4, 0.1], "faL": 1.2, "faR": 1.2}]},
	# Lower the load to the rack/tailgate and let go (one-shot).
	"setdown": {"T": 0.8, "loop": false, "keys": [
		{"t": 0.0, "uaL": [0.4, -0.1], "uaR": [0.4, 0.1], "faL": 1.2, "faR": 1.2},
		{"t": 0.4, "drop": 0.2, "spine": 0.45, "chest": 0.25, "head_p": -0.15, "uaL": [0.95, -0.12], "uaR": [0.95, 0.12], "faL": 0.4, "faR": 0.4, "fL": 0.1},
		{"t": 0.8}]},
	# Relaxed talk: weight shift, open hand gestures, nods (loop).
	"talk": {"T": 3.2, "loop": true, "keys": [
		{"t": 0.0, "head_y": 0.1, "uaR": [0.25, 0.15], "faR": 0.9},
		{"t": 0.8, "head_p": 0.08, "head_y": -0.05, "uaR": [0.55, 0.25], "faR": 1.3, "chest_y": -0.06},
		{"t": 1.6, "head_p": -0.04, "uaL": [0.4, -0.2], "faL": 1.1, "uaR": [0.2, 0.12], "faR": 0.6, "chest_y": 0.05},
		{"t": 2.4, "head_p": 0.06, "head_y": 0.12, "uaR": [0.45, 0.2], "faR": 1.2},
		{"t": 3.2, "head_y": 0.1, "uaR": [0.25, 0.15], "faR": 0.9}]},
	# Witnessed something: arms folded tight, head low, glances off (loop).
	"talk_shaken": {"T": 4.0, "loop": true, "keys": [
		{"t": 0.0, "spine": 0.12, "chest": 0.06, "head_p": 0.22, "uaL": [0.55, -0.35], "uaR": [0.55, 0.35], "faL": 1.9, "faR": 1.9},
		{"t": 1.5, "spine": 0.12, "chest": 0.06, "head_p": 0.1, "head_y": 0.45, "uaL": [0.55, -0.35], "uaR": [0.55, 0.35], "faL": 1.9, "faR": 1.9},
		{"t": 2.5, "spine": 0.14, "chest": 0.08, "head_p": 0.25, "head_y": -0.1, "uaL": [0.55, -0.35], "uaR": [0.55, 0.35], "faL": 1.9, "faR": 1.9},
		{"t": 4.0, "spine": 0.12, "chest": 0.06, "head_p": 0.22, "uaL": [0.55, -0.35], "uaR": [0.55, 0.35], "faL": 1.9, "faR": 1.9}]},
	# Fear: knees soft, shoulders up, weight back, ready to retreat (loop).
	"fear": {"T": 2.6, "loop": true, "keys": [
		{"t": 0.0, "drop": 0.08, "spine": -0.08, "chest": 0.1, "head_p": 0.05, "head_y": 0.3, "uaL": [0.3, -0.25], "uaR": [0.3, 0.25], "faL": 1.3, "faR": 1.3, "fL": -0.12, "fR": 0.1},
		{"t": 1.3, "drop": 0.1, "spine": -0.06, "chest": 0.12, "head_p": 0.0, "head_y": -0.35, "uaL": [0.35, -0.28], "uaR": [0.35, 0.28], "faL": 1.4, "faR": 1.4, "fL": -0.12, "fR": 0.1},
		{"t": 2.6, "drop": 0.08, "spine": -0.08, "chest": 0.1, "head_p": 0.05, "head_y": 0.3, "uaL": [0.3, -0.25], "uaR": [0.3, 0.25], "faL": 1.3, "faR": 1.3, "fL": -0.12, "fR": 0.1}]},
	# Observant: stops, head cocked toward the trees, very still (2.4 s).
	"listen": {"T": 2.4, "loop": false, "keys": [
		{"t": 0.0},
		{"t": 0.5, "head_y": 0.55, "head_r": 0.18, "head_p": -0.05, "chest_y": 0.12},
		{"t": 1.9, "head_y": 0.6, "head_r": 0.2, "head_p": -0.06, "chest_y": 0.12},
		{"t": 2.4}]},
	# Timid: a quick glance over the shoulder at the treeline (1.6 s).
	"glance": {"T": 1.6, "loop": false, "keys": [
		{"t": 0.0},
		{"t": 0.35, "head_y": -0.95, "chest_y": -0.3, "head_p": 0.05},
		{"t": 0.9, "head_y": -0.9, "chest_y": -0.28},
		{"t": 1.6}]},
	# Hard-working: rolls the shoulders and re-sets the grip (1.8 s).
	"grip": {"T": 1.8, "loop": false, "keys": [
		{"t": 0.0},
		{"t": 0.45, "chest": 0.08, "uaL": [0.35, -0.2], "uaR": [0.35, 0.2], "faL": 1.5, "faR": 1.5, "head_p": 0.15},
		{"t": 1.0, "chest": -0.05, "uaL": [0.2, -0.35], "uaR": [0.2, 0.35], "faL": 1.2, "faR": 1.2},
		{"t": 1.8}]},
	# Driving: seated, both hands forward on the wheel (loop).
	"drive": {"T": 4.0, "loop": true, "seat": true, "keys": [
		{"t": 0.0, "uaL": [1.0, -0.12], "uaR": [1.0, 0.12], "faL": 0.55, "faR": 0.55, "head_p": 0.02},
		{"t": 2.0, "uaL": [1.02, -0.1], "uaR": [0.98, 0.14], "faL": 0.55, "faR": 0.58, "head_y": 0.12},
		{"t": 4.0, "uaL": [1.0, -0.12], "uaR": [1.0, 0.12], "faL": 0.55, "faR": 0.55, "head_p": 0.02}]},
	# Endgame hiding crouch: small, still, breathing (loop).
	"hide": {"T": 3.0, "loop": true, "keys": [
		{"t": 0.0, "drop": 0.55, "spine": 0.6, "chest": 0.3, "head_p": -0.2, "uaL": [0.9, -0.3], "uaR": [0.9, 0.3], "faL": 1.6, "faR": 1.6, "fL": 0.15, "fR": -0.05},
		{"t": 1.5, "drop": 0.56, "spine": 0.62, "chest": 0.32, "head_p": -0.18, "uaL": [0.9, -0.3], "uaR": [0.9, 0.3], "faL": 1.6, "faR": 1.6, "fL": 0.15, "fR": -0.05},
		{"t": 3.0, "drop": 0.55, "spine": 0.6, "chest": 0.3, "head_p": -0.2, "uaL": [0.9, -0.3], "uaR": [0.9, 0.3], "faL": 1.6, "faR": 1.6, "fL": 0.15, "fR": -0.05}]},
}


func _make_body_clip(spec: Dictionary) -> Animation:
	var an := Animation.new()
	var T: float = spec.T
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR if bool(spec.loop) else Animation.LOOP_NONE
	var tracks := {}
	for b in ["Hips", "Spine", "Chest", "Head", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR", "UpperArmL", "ForearmL", "UpperArmR", "ForearmR"]:
		tracks[b] = _track_rot(an, b)
	var hips_pos := _track_pos(an, "Hips")
	var post := appearance.posture
	var seat := bool(spec.get("seat", false))
	for key in spec.keys:
		var k: Dictionary = key
		var t: float = float(k.get("t", 0.0))
		var drop: float = float(k.get("drop", 0.0))
		if seat:
			an.position_track_insert_key(hips_pos, t, rest["Hips"].origin + Vector3(0, -(thigh_len + ankle_h) * 0.98 + 0.46 - 0.02, 0.06))
			for sn in ["L", "R"]:
				an.rotation_track_insert_key(tracks["Thigh" + sn], t, _q(PI * 0.5))
				an.rotation_track_insert_key(tracks["Shin" + sn], t, _q(-PI * 0.5))
				an.rotation_track_insert_key(tracks["Foot" + sn], t, _q(0))
		else:
			var hp: Vector3 = rest["Hips"].origin + Vector3(0, -drop, -drop * 0.25)
			an.position_track_insert_key(hips_pos, t, hp)
			for side in [-1.0, 1.0]:
				var sn := "L" if side < 0 else "R"
				var fwd := float(k.get("f" + sn, 0.0))
				var foot := Vector3(side * foot_side * 1.15, ankle_h, -fwd)
				var hip := hp + Vector3(side * foot_side, -0.02 * H, 0)
				var d := foot - hip
				var ang := LimbIK.solve_planar(d.y, d.z, thigh_len, shin_len, true)
				var roll := atan2(d.x, -d.y) * 0.9
				an.rotation_track_insert_key(tracks["Thigh" + sn], t, _q(ang.x, 0, roll))
				an.rotation_track_insert_key(tracks["Shin" + sn], t, _q(ang.y))
				an.rotation_track_insert_key(tracks["Foot" + sn], t, _q(-(ang.x + ang.y), 0, -roll))
		an.rotation_track_insert_key(tracks["Hips"], t, _q(0))
		an.rotation_track_insert_key(tracks["Spine"], t, _q(float(k.get("spine", 0.0)) + 0.03 - post * 0.05, float(k.get("chest_y", 0.0)) * 0.4, 0))
		an.rotation_track_insert_key(tracks["Chest"], t, _q(float(k.get("chest", 0.0)) - post * 0.03, float(k.get("chest_y", 0.0)) * 0.6, 0))
		# Head yaw is bounded so it never turns through the shoulders.
		an.rotation_track_insert_key(tracks["Head"], t, _q(float(k.get("head_p", 0.0)), clampf(float(k.get("head_y", 0.0)), -1.0, 1.0), float(k.get("head_r", 0.0))))
		for side in [-1.0, 1.0]:
			var sn := "L" if side < 0 else "R"
			var ua: Array = k.get("ua" + sn, [0.06, side * 0.1])
			an.rotation_track_insert_key(tracks["UpperArm" + sn], t, _q(float(ua[0]), 0, float(ua[1])))
			an.rotation_track_insert_key(tracks["Forearm" + sn], t, _q(float(k.get("fa" + sn, 0.22))))
	return an


func _make_idle() -> Animation:
	var an := Animation.new()
	var T := float(mocap().clips.sit.length) if has_mocap("sit") else 4.0
	an.length = T
	an.loop_mode = Animation.LOOP_LINEAR
	var tracks := {}
	for b in ["Hips", "Spine", "Chest", "Neck", "Head", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR", "UpperArmL", "ForearmL", "UpperArmR", "ForearmR", "HandL", "HandR"]:
		tracks[b] = _track_rot(an, b)
	var hips_pos := _track_pos(an, "Hips")
	var post := appearance.posture
	var n := int(T * 6.0)
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

## A short one-shot action (pickup, setdown, listen, glance, grip). It
## returns to `after` when done and is interruptible: locomotion or any
## other play() call cancels it immediately (actions never hold a worker).
var action := ""
var _action_left := 0.0
var _action_after := "idle"
var actions_played := 0


func play_action(name: String, after := "idle") -> void:
	if not anim.has_animation(name):
		return
	play(name, 0.15)
	action = name
	_action_left = anim.get_animation(name).length
	_action_after = after
	actions_played += 1


func play(name: String, blend := 0.25) -> void:
	if action != "" and name != action:
		action = ""
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
	if action != "" and speed < 0.15:
		return      # let a standing action finish
	if speed < 0.15:
		play("idle" if rest_clip == "" else rest_clip)
		playback_scale = 1.0
	elif speed >= RUN_MIN_SPEED and anim.has_animation("run"):
		play("run", 0.2)
		playback_scale = clampf(speed / run_nominal, 0.7, 1.6)
	elif anim.has_animation("walk_brisk") and speed > walk_nominal * 1.35:
		play("walk_brisk", 0.25)
		playback_scale = clampf(speed / float(_nominal.get("walk_brisk", walk_nominal)), 0.7, 1.8)
	else:
		play("walk")
		playback_scale = clampf(speed / walk_nominal, 0.6, 1.8)


## Idle variant while standing (e.g. "fear" when a worker is frightened).
var rest_clip := ""
## Foot plants of the walk cycle (0 and half period): emitted from the
## animation's own phase, so sounds follow the visible stride.
signal step(side: int)
var _walk_prev := -1.0


func _process(delta: float) -> void:
	if action != "":
		_action_left -= delta * playback_scale
		if _action_left <= 0.0:
			var nxt := _action_after
			action = ""
			play(nxt, 0.3)
	if anim:
		anim.advance(delta * playback_scale)
		if _contacts.has(current) and anim.current_animation == current:
			# Footfalls at the clip's real plants (motion capture).
			var pos := anim.current_animation_position
			if _clip_prev >= 0.0:
				for c in _contacts[current]:
					var ct := float(c[0])
					if (_clip_prev < ct and pos >= ct) or (pos < _clip_prev and (ct > _clip_prev or ct <= pos)):
						step.emit(int(c[1]))
			_clip_prev = pos
		elif current == "walk" and anim.current_animation == "walk":
			_clip_prev = -1.0
			var ph := fmod(anim.current_animation_position, WALK_PERIOD) / WALK_PERIOD
			if _walk_prev >= 0.0:
				if ph < _walk_prev:
					step.emit(0)
				elif _walk_prev < 0.5 and ph >= 0.5:
					step.emit(1)
			_walk_prev = ph
		else:
			_walk_prev = -1.0
			_clip_prev = -1.0
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
