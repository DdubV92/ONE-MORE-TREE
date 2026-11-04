class_name LoggingFX
extends Node3D
## Pooled spatial one-shots and particles for logging (Work bus). Sounds
## originate at the contact point / trunk and use the existing 3D audio
## setup, so turning the camera changes their direction and indoor zones
## damp them like other outdoor sound.

enum Sound { CHOP, CLUNK, MISS, CREAK, CRACK, IMPACT, RUSTLE }

const POOL := 6
static var _inst: LoggingFX

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _streams := {}
var _chips: Array[GPUParticles3D] = []
var _chip_i := 0
var _dust: GPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_inst = self
	_rng.seed = 77
	for k in POOL:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Work"
		p.unit_size = 6.0
		p.max_distance = 140.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players.append(p)
	for k in 3:
		_chips.append(_make_chips())
	_dust = _make_dust()


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


static func _names(s: int) -> Array:
	match s:
		Sound.CHOP: return ["chop_0", "chop_1", "chop_2", "chop_3", "chop_4"]
		Sound.CLUNK: return ["clunk_0", "clunk_1", "clunk_2"]
		Sound.MISS: return ["axe_miss_0", "axe_miss_1"]
		Sound.CREAK: return ["creak_wood_0", "creak_wood_1", "creak_wood_2"]
		Sound.CRACK: return ["tree_crack"]
		Sound.IMPACT: return ["tree_impact_0", "tree_impact_1"]
		Sound.RUSTLE: return ["tree_rustle"]
	return []


static func play(s: int, at: Vector3, volume_db := 0.0) -> void:
	if _inst:
		_inst._play(s, at, volume_db)


func _play(s: int, at: Vector3, volume_db: float) -> void:
	var names := _names(s)
	if names.is_empty():
		return
	var n: String = names[_rng.randi() % names.size()]
	if not _streams.has(n):
		_streams[n] = load("res://audio/generated/%s.wav" % n)
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[n]
	p.global_position = at
	p.pitch_scale = _rng.randf_range(0.92, 1.08)
	var base_db: float = {Sound.CHOP: -6.0, Sound.CLUNK: -8.0, Sound.MISS: -18.0, Sound.CREAK: -4.0, Sound.CRACK: 0.0, Sound.IMPACT: 2.0, Sound.RUSTLE: -6.0}[s]
	p.volume_db = base_db + volume_db + _rng.randf_range(-1.5, 1.5)
	p.unit_size = 14.0 if s in [Sound.CRACK, Sound.IMPACT] else 6.0
	p.play()
	SoundEvents.emit(p.stream, at, p.volume_db, "work", ["chopping", "wood knock", "axe swish", "wood creaking", "trunk cracking", "a tree falling", "branches rustling"][s])


static func chips(at: Vector3, normal: Vector3, bark_color: Color) -> void:
	if _inst:
		_inst._emit_chips(at, normal, bark_color)


func _emit_chips(at: Vector3, normal: Vector3, bark: Color) -> void:
	var c := _chips[_chip_i]
	_chip_i = (_chip_i + 1) % _chips.size()
	c.global_position = at + normal * 0.03
	var pm := c.process_material as ParticleProcessMaterial
	pm.direction = (normal + Vector3.UP * 0.4).normalized()
	pm.color = bark.lerp(Color(0.86, 0.72, 0.5), 0.6)
	c.restart()
	c.emitting = true


static func dust(at: Vector3) -> void:
	if _inst:
		_inst._dust.global_position = at
		_inst._dust.restart()
		_inst._dust.emitting = true


func _make_chips() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var pm := ParticleProcessMaterial.new()
	pm.spread = 40.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -9.8, 0)
	pm.angular_velocity_min = -720.0
	pm.angular_velocity_max = 720.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.008, 0.02)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	mesh.material = m
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_dust() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 2.4
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 8, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.0
	pm.spread = 80.0
	pm.direction = Vector3.UP
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -0.3, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.2
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.55, 0.5, 0.42, 0.35), Color(0.6, 0.56, 0.5, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	quad.material = FirePit._billboard_mat(FirePit._sprite("smoke"), false)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p
