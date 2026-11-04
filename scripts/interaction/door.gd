class_name Door
extends Node3D
## Hinged door: a pivot at the hinge edge with an animatable panel that keeps
## its collision in sync while swinging. Toggle with the interact key.

@export var width := 0.85
@export var height := 2.0
@export var open_angle := -100.0
@export var material_name := "planks"
## Phase 5: a pet flap in the bottom of the panel (the dog's own door).
@export var dog_flap := false
var is_open := false
var flap: Node3D
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
	if dog_flap:
		_build_flap()
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
	if v != is_open and not instant and Game.hunt:
		Game.hunt.noise(global_position, 18.0, "door", "door")
	is_open = v
	var target := deg_to_rad(open_angle if v else 0.0)
	if _tween:
		_tween.kill()
	if instant:
		_panel.rotation.y = target
		return
	_tween = create_tween()
	_tween.tween_property(_panel, "rotation:y", target, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_flap() -> void:
	var fw := 0.32
	var fh := 0.38
	var cx := width * 0.5
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, fh + 0.04, 0.07)
		mi.mesh = bm
		mi.material_override = BuildKit.mat("black")
		mi.position = Vector3(cx + side * (fw * 0.5 + 0.015), 0.06 + fh * 0.5, 0)
		_panel.add_child(mi)
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(fw + 0.06, 0.03, 0.07)
	top.mesh = tb
	top.material_override = BuildKit.mat("black")
	top.position = Vector3(cx, 0.06 + fh + 0.015, 0)
	_panel.add_child(top)
	flap = Node3D.new()
	flap.name = "DogFlap"
	flap.position = Vector3(cx, 0.06 + fh, 0)
	_panel.add_child(flap)
	var leaf := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(fw, fh, 0.012)
	leaf.mesh = lb
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.22, 0.2, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.3
	leaf.material_override = m
	leaf.position = Vector3(0, -fh * 0.5, 0)
	flap.add_child(leaf)


## The dog pushes through: the flap swings the way it is going and back.
func swing_flap(outward: bool) -> void:
	if flap == null:
		return
	var tw := create_tween()
	tw.tween_property(flap, "rotation:x", (-1.0 if outward else 1.0) * 1.1, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flap, "rotation:x", (0.35 if outward else -0.35), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flap, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
