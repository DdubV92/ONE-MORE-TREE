class_name BossBody
extends Node3D
## A body for the boss that ONLY the security cameras render (layer 19; the
## first-person camera excludes it). It follows the real player: walking,
## standing, or seated in a truck / on the couch. No shadow, so it never
## shows up indirectly in the first-person view.

const LAYER := 19

var hc: HumanCharacter


static func build() -> BossBody:
	return BossBody.new()


func _ready() -> void:
	hc = HumanCharacter.new()
	var a := HumanAppearance.new()
	a.label = "The boss"
	a.height = 1.8
	a.hair_style = 3
	a.beard = 1
	a.jacket = Color(0.2, 0.32, 0.22)
	a.pants = Color(0.22, 0.24, 0.3)
	hc.appearance = a
	add_child(hc)
	_tag(hc)


func _tag(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = 1 << (LAYER - 1)
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_tag(c)


func _process(_delta: float) -> void:
	var p := get_parent()
	if p == null or hc == null:
		return
	var seated: bool = p.get("vehicle") != null or p.get("couch") != null
	if p.get("hiding") != null:
		# Endgame hiding: the camera-only body crouches small and still.
		hc.play("hide", 0.3)
		position = Vector3.ZERO
	elif seated:
		hc.play("drive" if p.get("vehicle") != null and str(p.get("vehicle_seat")) == "driver" else "sit")
		position = Vector3(0, Player.EYE - 1.18, 0.1)
	else:
		var v: Vector3 = p.get("velocity")
		hc.set_locomotion(Vector2(v.x, v.z).length())
		position = Vector3.ZERO
