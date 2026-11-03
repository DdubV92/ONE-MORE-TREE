class_name FirePit
extends Node3D
## The camp burn pit: CC0 stone fire pit model, ash bed, a few burning logs,
## layered particle fire (flames, embers, smoke), flickering warm light and
## bounded heat haze. Phase 0: always burning, placeholder interaction.
## Prompt 2 adds real fuel via `add_fuel()` (interface reserved below).

signal fuel_changed(amount: float)

@export var radius := 1.7
var fuel := 1.0                 # 0..1 visual intensity (Prompt 2 drives this)
var _light: OmniLight3D
var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _smoke: GPUParticles3D
var _haze: MeshInstance3D
var _base_energy := 3.2
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable_fire")
	var pit := BuildKit.prop(self, "stone_fire_pit", Vector3.ZERO, 0.0, radius / 0.72)
	pit.name = "Stones"
	# Ash bed and charred logs
	var ash := BuildKit.cylinder(self, radius * 0.78, 0.06, Vector3(0, 0.1, 0), "ash", false, 24)
	ash.name = "Ash"
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		# Teepee: each log leans from the rim toward a point above the center.
		var base := Vector3(cos(a) * 0.62, 0.08, sin(a) * 0.62)
		var top := Vector3(cos(a) * 0.05, 0.78, sin(a) * 0.05)
		var log := BuildKit.cylinder(self, 0.11, base.distance_to(top), (base + top) * 0.5, "bark", false, 8)
		var y_axis := (top - base).normalized()
		var x_axis := y_axis.cross(Vector3(-sin(a), 0, cos(a))).normalized()
		log.basis = Basis(x_axis, y_axis, x_axis.cross(y_axis))
	for k in 7:
		var a := TAU * k / 7.0
		BuildKit.cylinder(self, 0.05, 0.25, Vector3(cos(a) * 0.55, 0.13, sin(a) * 0.55), "char", false, 6)
	# Collision: keeps the player out of the flames; the stones are walkable around.
	var body := StaticBody3D.new()
	body.name = "FireBody"
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.95
	shape.height = 1.0
	cs.shape = shape
	cs.position = Vector3(0, 0.5, 0)
	body.add_child(cs)
	body.set_script(load("res://scripts/interaction/interactable.gd"))
	body.set("prompt", "Warm your hands")
	body.set("message", "The fire crackles. (Burning timber arrives in Prompt 2.)")
	add_child(body)
	BuildKit.marker(self, "LoadPoint", Vector3(0, 0, radius + 1.4), 0.0, "burn_pit_load_point")
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.9, 0)
	_light.omni_range = 11.0
	_light.omni_attenuation = 1.3
	_light.light_color = Color(1.0, 0.58, 0.28)
	_light.light_energy = _base_energy
	_light.shadow_enabled = true
	_light.light_size = 0.4
	add_child(_light)
	_flames = _make_flames()
	_embers = _make_embers()
	_smoke = _make_smoke()
	_haze = _make_haze()
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	var on: bool = Settings.get_v("heat_haze")
	_haze.visible = on
	_light.shadow_enabled = Settings.get_v("quality") != "low"


func add_fuel(_amount: float) -> void:
	## Reserved for Prompt 2 (timber disposal). Intentionally inert now.
	pass


func _process(delta: float) -> void:
	_t += delta
	var flicker := 0.82 + 0.1 * sin(_t * 13.0) + 0.06 * sin(_t * 23.7 + 1.3) + 0.05 * sin(_t * 5.1)
	_light.light_energy = _base_energy * flicker * fuel
	_light.position = Vector3(0.05 * sin(_t * 7.0), 0.9 + 0.05 * sin(_t * 11.0), 0.05 * cos(_t * 6.0))


func _make_flames() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Flames"
	p.amount = 28
	p.lifetime = 0.9
	p.position = Vector3(0, 0.15, 0)
	p.visibility_aabb = AABB(Vector3(-1.5, 0, -1.5), Vector3(3, 3, 3))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.38
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.3))
	curve.curve = c
	pm.scale_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.9, 0.7, 1))
	grad.set_color(1, Color(1, 0.4, 0.2, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.75, 1.3)
	quad.center_offset = Vector3(0, 0.55, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/flame.gdshader")
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Embers"
	p.amount = 24
	p.lifetime = 2.2
	p.position = Vector3(0, 0.4, 0)
	p.visibility_aabb = AABB(Vector3(-2, 0, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.25, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.7, 0.3, 1))
	grad.set_color(1, Color(1, 0.3, 0.1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 4
	mesh.rings = 2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(4.0, 2.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 14
	p.lifetime = 5.0
	p.position = Vector3(0, 1.2, 0)
	p.visibility_aabb = AABB(Vector3(-4, 0, -4), Vector3(8, 10, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.25, 0.1, 0.15)
	pm.scale_min = 0.8
	pm.scale_max = 1.4
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.0))
	curve.curve = c
	pm.scale_curve = curve
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/smoke.gdshader")
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_haze() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "HeatHaze"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.8, 2.2)
	quad.center_offset = Vector3(0, 1.1, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/heat_haze.gdshader")
	mat.set_shader_parameter("strength", 0.008)
	mat.set_shader_parameter("max_distance", 25.0)
	mat.render_priority = 1
	quad.material = mat
	mi.mesh = quad
	mi.position = Vector3(0, 0.9, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
