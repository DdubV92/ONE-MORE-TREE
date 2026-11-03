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
	# Glowing coal bed between the logs.
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color(0.08, 0.05, 0.04)
	coal.emission_enabled = true
	coal.emission = Color(1.0, 0.32, 0.08)
	coal.emission_energy_multiplier = 2.5
	coal.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	for k in 14:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.42
		var mi := MeshInstance3D.new()
		mi.mesh = CharMeshKit.sphere()
		mi.material_override = coal if k % 3 != 0 else BuildKit.mat("char")
		mi.position = Vector3(cos(a) * r, 0.14, sin(a) * r)
		mi.scale = Vector3(rng.randf_range(0.08, 0.16), rng.randf_range(0.05, 0.08), rng.randf_range(0.08, 0.16))
		add_child(mi)
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


static var _tex_cache := {}


## Procedural sprite textures (generated once): a licking flame tongue with
## a hot core, and a soft wispy smoke puff.
static func _sprite(kind: String) -> ImageTexture:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var w := 64
	var h := 128 if kind == "flame" else 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 9 if kind == "flame" else 21
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := (y + 0.5) / h
			var c := Color(0, 0, 0, 0)
			if kind == "flame":
				# v=0 top (tip), v=1 bottom (base). Teardrop with noisy edge.
				var n := noise.get_noise_2d(x * 1.0, y * 0.6) * 0.5 + 0.5
				var width := lerpf(0.04, 0.42, pow(v, 0.7)) * (0.8 + 0.4 * n)
				var dx := absf(u - 0.5)
				var body := clampf(1.0 - dx / maxf(width, 0.001), 0.0, 1.0)
				body *= smoothstep(0.0, 0.25, v) * smoothstep(1.0, 0.82, v)
				var core := pow(body, 2.0) * smoothstep(0.35, 0.9, v)
				var a := pow(body, 0.8)
				c = Color(1.0, lerpf(0.55, 0.95, core), lerpf(0.2, 0.75, core), a)
			else:
				var d := Vector2(u - 0.5, v - 0.5).length() * 2.0
				var n := noise.get_noise_2d(x * 1.5, y * 1.5) * 0.5 + 0.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = pow(a, 1.6) * (0.55 + 0.45 * n)
				c = Color(1, 1, 1, a)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[kind] = t
	return t


static func _billboard_mat(tex: Texture2D, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.25
	m.disable_receive_shadows = true
	return m


func _make_flames() -> GPUParticles3D:
	# Many small, short-lived tongues licking up from the logs.
	var p := GPUParticles3D.new()
	p.name = "Flames"
	p.amount = 56
	p.lifetime = 0.85
	p.randomness = 0.4
	p.position = Vector3(0, 0.22, 0)
	p.visibility_aabb = AABB(Vector3(-1.5, -0.2, -1.5), Vector3(3, 3, 3))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.32
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 1.2, 0)
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.angle_min = -12.0
	pm.angle_max = 12.0
	pm.scale_min = 0.55
	pm.scale_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.12
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(1.0, 0.15))
	curve.curve = c
	pm.scale_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.85, 0.55, 0.0), Color(1.0, 0.75, 0.4, 0.9), Color(1.0, 0.42, 0.12, 0.6), Color(0.6, 0.12, 0.04, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.95)
	quad.center_offset = Vector3(0, 0.38, 0)
	quad.material = _billboard_mat(_sprite("flame"), true)
	(quad.material as StandardMaterial3D).albedo_color = Color(1.6, 1.3, 1.0)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	# A soft glow at the heart of the fire (single slowly pulsing sprite).
	var glow := GPUParticles3D.new()
	glow.name = "CoreGlow"
	glow.amount = 3
	glow.lifetime = 1.4
	glow.position = Vector3(0, 0.35, 0)
	var gm := ParticleProcessMaterial.new()
	gm.direction = Vector3.UP
	gm.spread = 0.0
	gm.initial_velocity_min = 0.05
	gm.initial_velocity_max = 0.1
	gm.gravity = Vector3.ZERO
	gm.scale_min = 0.9
	gm.scale_max = 1.2
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gg.colors = PackedColorArray([Color(1, 0.5, 0.15, 0.0), Color(1, 0.5, 0.15, 0.35), Color(1, 0.5, 0.15, 0.0)])
	var ggt := GradientTexture1D.new()
	ggt.gradient = gg
	gm.color_ramp = ggt
	glow.process_material = gm
	var gq := QuadMesh.new()
	gq.size = Vector2(1.4, 1.0)
	gq.material = _billboard_mat(_sprite("smoke"), true)
	glow.draw_pass_1 = gq
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	return p


func _make_embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Embers"
	p.amount = 18
	p.lifetime = 2.4
	p.randomness = 0.6
	p.position = Vector3(0, 0.45, 0)
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, 0.15, 0)
	pm.damping_min = 0.3
	pm.damping_max = 0.6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.0
	pm.turbulence_noise_scale = 1.5
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.25
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(1, 0.75, 0.35, 1), Color(1, 0.4, 0.1, 0.8), Color(0.6, 0.15, 0.05, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	var m := _billboard_mat(_sprite("smoke"), true)
	m.albedo_color = Color(3.0, 2.0, 1.2)
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 18
	p.lifetime = 6.0
	p.randomness = 0.5
	p.position = Vector3(0, 1.0, 0)
	p.visibility_aabb = AABB(Vector3(-5, -0.5, -5), Vector3(10, 12, 10))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.45
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0.18, 0.05, 0.1)
	pm.damping_min = 0.05
	pm.damping_max = 0.15
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -15.0
	pm.angular_velocity_max = 15.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.08
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.3))
	c.add_point(Vector2(1.0, 1.0))
	curve.curve = c
	pm.scale_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(0.3, 0.29, 0.28, 0.0), Color(0.32, 0.31, 0.3, 0.18), Color(0.45, 0.44, 0.43, 0.1), Color(0.5, 0.5, 0.5, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.5)
	var m := _billboard_mat(_sprite("smoke"), false)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_haze() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "HeatHaze"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.8)
	quad.center_offset = Vector3(0, 0.9, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/heat_haze.gdshader")
	mat.set_shader_parameter("strength", 0.005)
	mat.set_shader_parameter("max_distance", 25.0)
	mat.render_priority = 1
	quad.material = mat
	mi.mesh = quad
	mi.position = Vector3(0, 1.05, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
