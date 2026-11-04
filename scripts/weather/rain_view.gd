class_name RainView
extends Node3D
## One bounded rain volume for one view: the player's camera, or a remote
## security camera while the TV is actually rendering it. Drops are GPU
## particles in a box just above and in front of the view, falling along
## the shared wind. A GPUParticlesCollisionHeightField3D captured from above
## stops them on roofs, truck cabs, canopies and the ground (the supported
## shelter mask: no rain inside the camper, cabin, porch or a cab).
## Splash flecks spawn at contact on High/Ultra (player view only).
##
## Approximation notes: streaks are camera-facing fixed-Y quads, so the
## wind slant is shown by drop drift, not by tilting each streak.

const FALL_SPEED := 9.5
const BOX := Vector3(26.0, 1.0, 26.0)
const HEIGHT := 11.0

var follow_main_camera := false
var anchor: Node3D            # remote camera (fixed mount)
var amount_cap := -1          # remote budget; -1 = quality default
var drops: GPUParticles3D
var splashes: GPUParticles3D
var roofs: GPUParticlesCollisionHeightField3D
var _pm: ParticleProcessMaterial
var _rain := 0.0
var _wind := Vector2(0.8, 0.6)
var _wind_mult := 1.0
var _placed := false


static func quality_amount() -> int:
	match str(Settings.get_v("quality")):
		"low": return 700
		"medium": return 1400
		"ultra": return 3200
	return 2400


## Remote feeds are cheap: one focused feed gets more drops than a quad tile.
static func remote_budget(count: int) -> int:
	if count <= 1:
		return 700 if str(Settings.get_v("quality")) != "low" else 350
	return 220 if str(Settings.get_v("quality")) != "low" else 120


func _ready() -> void:
	var remote := not follow_main_camera
	var box := BOX * (0.55 if remote else 1.0)
	drops = GPUParticles3D.new()
	drops.name = "Drops"
	drops.amount = amount_cap if amount_cap > 0 else quality_amount()
	drops.lifetime = (HEIGHT + 4.0) / FALL_SPEED
	drops.preprocess = drops.lifetime
	drops.fixed_fps = 30
	drops.interpolate = true
	drops.local_coords = false
	drops.collision_base_size = 0.02
	drops.visibility_aabb = AABB(Vector3(-box.x, -HEIGHT - 8.0, -box.z), Vector3(box.x * 2.0, HEIGHT * 2.0 + 10.0, box.z * 2.0))
	drops.emitting = false
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Spawn through the whole column (not only at the top) so the view is
	# full immediately after a teleport or when rain begins.
	_pm.emission_box_extents = Vector3(box.x * 0.5, HEIGHT * 0.55, box.z * 0.5)
	_pm.direction = Vector3(0, -1, 0)
	_pm.spread = 3.0
	_pm.initial_velocity_min = FALL_SPEED * 0.9
	_pm.initial_velocity_max = FALL_SPEED * 1.1
	_pm.gravity = Vector3(0, -2.0, 0)
	_pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_pm.collision_use_scale = false
	_pm.scale_min = 0.7
	_pm.scale_max = 1.2
	drops.process_material = _pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.6)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rain.gdshader")
	q.material = m
	drops.draw_pass_1 = q
	add_child(drops)
	var hq := str(Settings.get_v("quality")) in ["high", "ultra"]
	if follow_main_camera and hq:
		splashes = GPUParticles3D.new()
		splashes.name = "Splashes"
		splashes.amount = 320
		splashes.lifetime = 0.28
		splashes.emitting = false
		splashes.local_coords = false
		splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sp := ParticleProcessMaterial.new()
		sp.direction = Vector3(0, 1, 0)
		sp.spread = 70.0
		sp.initial_velocity_min = 0.6
		sp.initial_velocity_max = 1.4
		sp.gravity = Vector3(0, -9.8, 0)
		sp.scale_min = 0.6
		sp.scale_max = 1.0
		splashes.process_material = sp
		var sq := QuadMesh.new()
		sq.size = Vector2(0.03, 0.03)
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		smat.billboard_keep_scale = true
		smat.albedo_color = Color(0.7, 0.74, 0.78, 0.3)
		sq.material = smat
		splashes.draw_pass_1 = sq
		add_child(splashes)
		drops.sub_emitter = drops.get_path_to(splashes)
		_pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
		_pm.sub_emitter_amount_at_collision = 1
	roofs = GPUParticlesCollisionHeightField3D.new()
	roofs.name = "RoofMask"
	roofs.size = Vector3(box.x + 6.0, HEIGHT + 16.0, box.z + 6.0)
	roofs.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512 if follow_main_camera else GPUParticlesCollisionHeightField3D.RESOLUTION_256
	roofs.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	roofs.follow_camera_enabled = false
	add_child(roofs)
	if OS.has_environment("RAIN_NOCOLL"):
		roofs.cull_mask = 0     # dev comparison: shelter mask off


func set_rain(r: float, wind: Vector2, wind_mult: float) -> void:
	_rain = r
	_wind = wind
	_wind_mult = wind_mult
	if drops == null:
		return
	var was := drops.emitting
	drops.emitting = r > 0.02
	if drops.emitting and not was:
		drops.restart()   # applies preprocess: the volume is already full
	drops.amount_ratio = clampf(r / 0.85, 0.05, 1.0)
	var push := wind.normalized() * (0.8 + 1.6 * wind_mult)
	_pm.gravity = Vector3(push.x, -2.0, push.y)
	_pm.direction = Vector3(push.x * 0.12, -1.0, push.y * 0.12).normalized()


func _process(_delta: float) -> void:
	if drops == null or not drops.emitting:
		return
	var at := Vector3.ZERO
	var fwd := Vector3.FORWARD
	if follow_main_camera:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		at = cam.global_position
		fwd = -cam.global_basis.z
	elif is_instance_valid(anchor):
		at = anchor.global_position
		fwd = -anchor.global_basis.z
		if _placed:
			return
	else:
		return
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# Upwind offset so drifting drops still cross the view.
	var up_wind := -Vector3(_wind.x, 0, _wind.y).normalized() * 1.5 * _wind_mult
	var center := at + fwd * (4.0 if follow_main_camera else 7.0) + up_wind
	drops.global_position = center + Vector3(0, HEIGHT * 0.5, 0)
	# Heightfield snaps in whole metres so it re-captures only when you move.
	var snap := Vector3(roundf(center.x), roundf(at.y), roundf(center.z))
	if roofs.global_position.distance_to(snap) > 2.0 or not _placed:
		roofs.global_position = snap
	_placed = true
