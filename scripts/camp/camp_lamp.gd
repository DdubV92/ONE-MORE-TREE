class_name CampLamp
extends Node3D
## Exterior camp lamp. Lights at dusk and stays at a stable intensity all
## night. `working` is authoritative for the SafetyService; Phase 0 lamps are
## always working (later prompts may add outages - none are planned now).

@export var safe_radius := 9.0
@export var cast_shadows := false
var working := true
var level := 0.0
var _light: SpotLight3D
var _bulb: MeshInstance3D
var _fill: OmniLight3D


func _ready() -> void:
	add_to_group("camp_lamps")
	BuildKit.cylinder(self, 0.06, 3.6, Vector3(0, 1.8, 0), "dark_wood", true, 8)
	BuildKit.box(self, Vector3(0.5, 0.06, 0.08), Vector3(0.18, 3.5, 0), "dark_wood", false)
	BuildKit.prop(self, "security_light", Vector3(0.35, 3.3, 0), PI * 0.5, 0.9)
	_bulb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.1
	_bulb.mesh = sm
	_bulb.position = Vector3(0.38, 3.28, 0)
	add_child(_bulb)
	_light = SpotLight3D.new()
	_light.position = Vector3(0.38, 3.25, 0)
	_light.rotation_degrees = Vector3(-90, 0, 0)
	_light.spot_range = 16.0
	_light.spot_angle = 62.0
	_light.spot_attenuation = 0.8
	_light.light_color = Color(1.0, 0.8, 0.55)
	_light.shadow_enabled = cast_shadows
	_light.light_size = 0.15
	add_child(_light)
	_fill = OmniLight3D.new()
	_fill.position = Vector3(0.38, 3.0, 0)
	_fill.omni_range = 7.0
	_fill.light_color = Color(1.0, 0.78, 0.5)
	_fill.shadow_enabled = false
	add_child(_fill)
	set_level(0.0)


func set_level(v: float) -> void:
	# Lamps switch on as dusk falls (v>0.05) and then hold a constant output.
	level = v
	var on := working and v > 0.05
	_light.visible = on
	_fill.visible = on
	_light.light_energy = 6.0
	_fill.light_energy = 0.6
	_bulb.material_override = BuildKit.mat("lamp_bulb") if on else BuildKit.mat("white")


func is_lit() -> bool:
	return working and _light.visible
