class_name EnvironmentController
extends Node3D
## The single owner of sun, moon, sky, ambient, fog, exposure, wind and
## camera post settings. Phase 0 drives it from a debug time slider; Prompt 3
## plugs the real game clock into `set_time_of_day`.
##
## Indirect light strategy: sky ambient + SSAO + SSIL by default (fully
## dynamic: nothing baked, so felled forest and night never keep stale light).
## SDFGI is available on the Ultra preset only. No lightmaps.

signal time_changed(hour: float)

const KEYFRAME_FILES := ["night", "dawn", "day", "golden", "sunset", "dusk"]

var keyframes: Array[LightingPreset] = []
var overcast_preset: LightingPreset
var hour := 13.0
var overcast := 0.0
var interior := 0.0          # 0 outside .. 1 deep inside camper/cabin
var _interior_target := 0.0
var lamp_level := 0.0        # 0..1 exterior lamp intensity factor
var current := LightingPreset.new()

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world_env: WorldEnvironment
var env: Environment
var sky_mat: ShaderMaterial
var cam_attr: CameraAttributesPractical
var _cloud_offset := 0.0
var _cloud_timer := 0.0
var quality := "high"


func build() -> void:
	for n in KEYFRAME_FILES:
		keyframes.append(load("res://config/lighting/%s.tres" % n))
	keyframes.sort_custom(func(a: LightingPreset, b: LightingPreset) -> bool: return a.hour < b.hour)
	overcast_preset = load("res://config/lighting/overcast.tres")
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.5
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = false
	moon.directional_shadow_max_distance = 90.0
	moon.light_angular_distance = 0.4
	moon.light_specular = 0.6
	add_child(moon)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.15
	env.fog_height = 0.0
	env.adjustment_enabled = true
	world_env = WorldEnvironment.new()
	world_env.environment = env
	cam_attr = CameraAttributesPractical.new()
	cam_attr.auto_exposure_enabled = false
	world_env.camera_attributes = cam_attr
	add_child(world_env)
	set_time_of_day(hour)
	Settings.changed.connect(apply_quality)
	apply_quality()


func describe() -> String:
	return "%02d:%02d, overcast %.2f, interior %.2f, preset near '%s'" % [int(hour), int(fmod(hour, 1.0) * 60.0), overcast, interior, current.label]


## Named review presets used by the Preview Tour.
func apply_named(preset: String) -> void:
	match preset:
		"day": overcast = 0.0; set_time_of_day(12.5)
		"sunset": overcast = 0.0; set_time_of_day(19.2)
		"night": overcast = 0.0; set_time_of_day(23.5)
		"dawn": overcast = 0.0; set_time_of_day(6.4)
		"overcast": overcast = 1.0; set_time_of_day(12.5)


func set_overcast(v: float) -> void:
	overcast = clampf(v, 0.0, 1.0)
	set_time_of_day(hour)


func set_interior_target(v: float) -> void:
	_interior_target = clampf(v, 0.0, 1.0)


func set_time_of_day(h: float) -> void:
	hour = fposmod(h, 24.0)
	_blend_presets()
	_apply()
	time_changed.emit(hour)


func is_night() -> bool:
	return hour >= 20.5 or hour < 5.8


func _blend_presets() -> void:
	var n := keyframes.size()
	var a: LightingPreset = keyframes[n - 1]
	var b: LightingPreset = keyframes[0]
	for i in n:
		if keyframes[i].hour > hour:
			b = keyframes[i]
			a = keyframes[(i - 1 + n) % n]
			break
		a = keyframes[i]
		b = keyframes[(i + 1) % n]
	var ha := a.hour
	var hb := b.hour if b.hour > ha else b.hour + 24.0
	var hh := hour if hour >= ha else hour + 24.0
	var t := clampf((hh - ha) / maxf(hb - ha, 0.001), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var mixed := _lerp_preset(a, b, t)
	var oc := overcast * (1.0 - _night_factor() * 0.7)
	current = _lerp_preset(mixed, _overcast_at(mixed), oc)
	current.label = a.label if t < 0.5 else b.label


func _night_factor() -> float:
	var e := _sun_direction().y
	return 1.0 - smoothstep(-0.2, 0.05, e)


func _overcast_at(base: LightingPreset) -> LightingPreset:
	# Overcast keeps the time-of-day brightness but flattens color and sun.
	var o := _lerp_preset(base, overcast_preset, 1.0)
	var bright := clampf(base.sun_energy / 1.45, 0.05, 1.0)
	o.sun_energy = overcast_preset.sun_energy * bright
	o.ambient_energy = lerpf(base.ambient_energy, overcast_preset.ambient_energy, bright)
	o.sky_zenith = overcast_preset.sky_zenith * (0.15 + 0.85 * bright)
	o.sky_horizon = overcast_preset.sky_horizon * (0.15 + 0.85 * bright)
	o.fog_color = overcast_preset.fog_color * (0.15 + 0.85 * bright)
	o.stars = 0.0
	o.lamps = base.lamps
	o.moon_energy = base.moon_energy * 0.3
	o.exposure = base.exposure
	return o


static func _lerp_preset(a: LightingPreset, b: LightingPreset, t: float) -> LightingPreset:
	var p := LightingPreset.new()
	for prop in p.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var va: Variant = a.get(prop.name)
		var vb: Variant = b.get(prop.name)
		if va is float:
			p.set(prop.name, lerpf(va, vb, t))
		elif va is Color:
			p.set(prop.name, (va as Color).lerp(vb, t))
		else:
			p.set(prop.name, va if t < 0.5 else vb)
	return p


func _sun_direction() -> Vector3:
	# Sun rises in the east (+X), sets in the west, culminating to the south (+Z).
	var day_angle := (hour - 6.0) / 24.0 * TAU   # 0 at 06:00
	var elev := sin(day_angle) * deg_to_rad(58.0)
	var az := day_angle                           # 0 east -> PI west
	var horiz := cos(elev)
	return Vector3(cos(az) * horiz, sin(elev), sin(az) * horiz * 0.55 + 0.35 * horiz).normalized()


func _moon_direction() -> Vector3:
	var day_angle := (hour - 18.5) / 24.0 * TAU
	var elev := sin(day_angle) * deg_to_rad(48.0)
	return Vector3(cos(day_angle) * cos(elev), sin(elev), -0.3 + 0.4 * cos(elev)).normalized()


func _apply() -> void:
	var p := current
	var sd := _sun_direction()
	var md := _moon_direction()
	_orient(sun, sd)
	_orient(moon, md)
	var sun_up := smoothstep(-0.04, 0.08, sd.y)
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy * sun_up
	sun.visible = sun.light_energy > 0.01
	sun.shadow_enabled = sun.visible
	var moon_up := smoothstep(-0.02, 0.15, md.y)
	moon.light_color = p.moon_color
	moon.light_energy = p.moon_energy * moon_up * (1.0 - sun_up)
	moon.visible = moon.light_energy > 0.01
	moon.shadow_enabled = moon.visible and quality != "low"
	sky_mat.set_shader_parameter("zenith_color", p.sky_zenith)
	sky_mat.set_shader_parameter("horizon_color", p.sky_horizon)
	sky_mat.set_shader_parameter("ground_color", p.sky_ground)
	sky_mat.set_shader_parameter("halo_color", p.sun_halo)
	sky_mat.set_shader_parameter("stars", p.stars)
	sky_mat.set_shader_parameter("cloud_cover", p.cloud_cover)
	sky_mat.set_shader_parameter("sun_dir", sd)
	sky_mat.set_shader_parameter("moon_dir", md)
	sky_mat.set_shader_parameter("cloud_offset", _cloud_offset)
	var interior_k := interior
	env.ambient_light_energy = p.ambient_energy * lerpf(1.0, 0.35, interior_k)
	env.ambient_light_sky_contribution = 1.0
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.fog_height_density = p.fog_height_density
	env.glow_intensity = p.glow_intensity * (1.0 if Settings.get_v("bloom") else 0.0)
	env.glow_enabled = Settings.get_v("bloom")
	var grade: float = Settings.get_v("color_grading")
	env.adjustment_saturation = lerpf(1.0, p.saturation, grade)
	env.adjustment_contrast = lerpf(1.0, p.contrast, grade)
	env.tonemap_exposure = p.exposure * lerpf(1.0, 1.35, interior_k)
	RenderingServer.global_shader_parameter_set("sun_dir_world", sd if sd.y > -0.1 else md)
	RenderingServer.global_shader_parameter_set("daylight", clampf(sun_up * clampf(p.sun_energy, 0.0, 1.4) / 1.4 + 0.15 * moon_up * (1.0 - sun_up), 0.0, 1.0))
	var wd := Vector2(0.8, 0.6)
	RenderingServer.global_shader_parameter_set("wind_dir", wd)
	RenderingServer.global_shader_parameter_set("wind_strength", p.wind)
	RenderingServer.global_shader_parameter_set("haze_strength", p.heat_haze * (1.0 if Settings.get_v("heat_haze") else 0.0))
	lamp_level = p.lamps
	get_tree().call_group("camp_lamps", "set_level", lamp_level)
	get_tree().call_group("post_fx", "set_grade", p.warmth, grade)


func _orient(light: DirectionalLight3D, dir: Vector3) -> void:
	# A DirectionalLight3D shines along its -Z; point it away from `dir`.
	var target := -dir
	var up := Vector3.UP if absf(target.y) < 0.98 else Vector3.FORWARD
	light.global_transform = Transform3D(Basis.looking_at(target, up), Vector3.ZERO)


func _process(delta: float) -> void:
	if absf(interior - _interior_target) > 0.001:
		interior = move_toward(interior, _interior_target, delta * 1.5)
		_apply()
	_cloud_timer += delta
	if _cloud_timer > 3.0:
		_cloud_timer = 0.0
		_cloud_offset += 0.02 * (0.3 + current.wind)
		sky_mat.set_shader_parameter("cloud_offset", _cloud_offset)


func apply_quality() -> void:
	quality = Settings.get_v("quality")
	match quality:
		"low":
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.sdfgi_enabled = false
			sun.directional_shadow_max_distance = 80.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		"medium":
			env.ssao_enabled = true
			env.ssil_enabled = false
			env.sdfgi_enabled = false
			sun.directional_shadow_max_distance = 120.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		"high":
			env.ssao_enabled = true
			env.ssil_enabled = true
			env.sdfgi_enabled = false
			sun.directional_shadow_max_distance = 160.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		"ultra":
			env.ssao_enabled = true
			env.ssil_enabled = true
			env.sdfgi_enabled = true
			env.sdfgi_cascades = 4
			env.sdfgi_use_occlusion = true
			sun.directional_shadow_max_distance = 220.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	# Depth of field (never on by default; gameplay stays sharp)
	match Settings.get_v("dof_mode"):
		"off":
			cam_attr.dof_blur_far_enabled = false
			cam_attr.dof_blur_near_enabled = false
		"subtle":
			cam_attr.dof_blur_far_enabled = true
			cam_attr.dof_blur_far_distance = 450.0
			cam_attr.dof_blur_far_transition = 300.0
			cam_attr.dof_blur_near_enabled = false
			cam_attr.dof_blur_amount = 0.03
		"cinematic":
			cam_attr.dof_blur_far_enabled = true
			cam_attr.dof_blur_far_distance = 60.0
			cam_attr.dof_blur_far_transition = 80.0
			cam_attr.dof_blur_near_enabled = true
			cam_attr.dof_blur_near_distance = 0.6
			cam_attr.dof_blur_near_transition = 0.5
			cam_attr.dof_blur_amount = 0.09
	if sun:
		_apply()
