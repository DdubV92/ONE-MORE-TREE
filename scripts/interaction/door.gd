class_name Door
extends Node3D
## Hinged door: a pivot at the hinge edge with an animatable panel that keeps
## its collision in sync while swinging. Toggle with the interact key.

@export var width := 0.85
@export var height := 2.0
@export var open_angle := -100.0
@export var material_name := "planks"
var is_open := false
var _panel: AnimatableBody3D
var _tween: Tween


func _ready() -> void:
	add_to_group("doors")
	_panel = AnimatableBody3D.new()
	_panel.sync_to_physics = false
	add_child(_panel)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width - 0.02, height - 0.02, 0.05)
	mi.mesh = bm
	mi.material_override = BuildKit.mat(material_name)
	mi.position = Vector3(width * 0.5, height * 0.5, 0)
	_panel.add_child(mi)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	knob.mesh = sm
	knob.material_override = BuildKit.mat("steel")
	knob.position = Vector3(width - 0.1, 1.0, 0.05)
	_panel.add_child(knob)
	var knob2 := knob.duplicate()
	knob2.position.z = -0.05
	_panel.add_child(knob2)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bm.size
	cs.shape = shape
	cs.position = mi.position
	_panel.add_child(cs)


func get_interact_text() -> String:
	return "Close door" if is_open else "Open door"


func interact(_by: Node) -> void:
	set_open(not is_open)


func set_open(v: bool, instant := false) -> void:
	is_open = v
	var target := deg_to_rad(open_angle if v else 0.0)
	if _tween:
		_tween.kill()
	if instant:
		_panel.rotation.y = target
		return
	_tween = create_tween()
	_tween.tween_property(_panel, "rotation:y", target, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
