class_name BreakerBox
extends StaticBody3D
## Phase 26: the camp breaker, on a post beside the lockers. When the pole
## lamps fail on a disturbed night, E here brings them back.

var kit: NightKit
var _lamp: MeshInstance3D
var _ok: StandardMaterial3D
var _bad: StandardMaterial3D


func setup(k: NightKit, at: Vector3) -> void:
	kit = k
	name = "BreakerBox"
	position = at
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.5, 0.52, 0.5)
	grey.roughness = 0.6
	BuildKit.cylinder(self, 0.05, 1.7, Vector3(0, 0.85, 0), "dark_wood", false, 8)
	BuildKit.box(self, Vector3(0.42, 0.56, 0.16), Vector3(0, 1.32, -0.1), grey, false, 0.0, "Box")
	_ok = StandardMaterial3D.new()
	_ok.albedo_color = Color(0.2, 0.9, 0.3)
	_ok.emission_enabled = true
	_ok.emission = Color(0.2, 0.9, 0.3)
	_ok.emission_energy_multiplier = 1.5
	_bad = StandardMaterial3D.new()
	_bad.albedo_color = Color(0.95, 0.15, 0.1)
	_bad.emission_enabled = true
	_bad.emission = Color(0.95, 0.15, 0.1)
	_bad.emission_energy_multiplier = 3.0
	_lamp = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	_lamp.mesh = sm
	_lamp.position = Vector3(0.12, 1.5, -0.19)
	add_child(_lamp)
	var sign := Label3D.new()
	sign.text = "CAMP LAMPS\nBREAKER"
	sign.font_size = 28
	sign.pixel_size = 0.003
	sign.position = Vector3(-0.04, 1.3, -0.19)
	sign.rotation.y = PI
	sign.modulate = Color(0.1, 0.1, 0.1)
	add_child(sign)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.5, 1.7, 0.3)
	cs.shape = bx
	cs.position = Vector3(0, 0.85, -0.05)
	add_child(cs)
	kit.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_lamp.material_override = _bad if kit.breaker_tripped else _ok


func get_interact_text() -> String:
	return kit.breaker_prompt() if kit else ""


func interact(by: Node) -> void:
	if kit:
		kit.reset_breaker(by)
