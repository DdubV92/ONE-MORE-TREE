class_name Curtain
extends Node3D
## A pair of fabric panels on the inside of a window opening (wall-local
## frame, like BuildKit.window_glass). Closed hides the view; open bunches
## the panels at the sides. Cosmetic only: never safety, never muting.

var closed := false
var _panels: Array[MeshInstance3D] = []
var _w := 1.0
var _target := 0.0
var _blend := 0.0


static func make(parent: Node3D, origin: Vector3, rot_y: float, opening: Array, inner_z: float) -> Curtain:
	var c := Curtain.new()
	c.position = origin
	c.rotation.y = rot_y
	parent.add_child(c)
	c._build(opening, inner_z)
	c.add_to_group("camper_curtain")
	return c


func _build(o: Array, inner_z: float) -> void:
	_w = float(o[1]) - float(o[0])
	var h := float(o[3]) - float(o[2]) + 0.16
	var mid := (float(o[0]) + float(o[1])) * 0.5
	var cy := (float(o[2]) + float(o[3])) * 0.5 - 0.02
	var mat := BuildKit.mat("blanket_blue").duplicate() as StandardMaterial3D
	mat.albedo_color = Color(0.72, 0.6, 0.42)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rod := BuildKit.cylinder(self, 0.012, _w + 0.2, Vector3(mid, float(o[3]) + 0.07, inner_z), "steel", false, 6)
	rod.rotation.z = PI * 0.5
	for side in [-1.0, 1.0]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, h, 0.02)
		m.mesh = bm
		m.material_override = mat
		m.set_meta("side", side)
		m.set_meta("mid", mid)
		m.position = Vector3(mid, cy, inner_z)
		add_child(m)
		_panels.append(m)
	_apply(0.0)


func set_closed(v: bool) -> void:
	closed = v
	_target = 1.0 if v else 0.0
	set_process(true)


func snap(v: bool) -> void:
	closed = v
	_target = 1.0 if v else 0.0
	_blend = _target
	_apply(_blend)


func _process(delta: float) -> void:
	_blend = move_toward(_blend, _target, delta * 2.5)
	_apply(_blend)
	if is_equal_approx(_blend, _target):
		set_process(false)


## 0 = open (each panel ~18% of the width at its edge), 1 = closed.
func _apply(b: float) -> void:
	var half := _w * 0.5 + 0.06
	for m in _panels:
		var side: float = m.get_meta("side")
		var width := lerpf(_w * 0.18, half, b)
		m.scale = Vector3(width, 1.0, 1.0)
		m.position.x = float(m.get_meta("mid")) + side * (half + 0.04 - width * 0.5)
