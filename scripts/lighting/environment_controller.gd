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
## Moon phase 0..1 (0 = new, 0.5 = full). The campaign sets it from the day
## (a 29.5-day cycle); Preview sets it from the time panel. Moonlight,
## night ambient, how far you can see through the night mist, and the stars
## all follow it: a new-moon night is nearly black beyond the camp lamps, a
## full moon lets you read silhouettes at a distance.
var moon_phase := 0.3
var _ground_fog_y := 0.0
var overcast := 0.0
var interior := 0.0          # 0 outside .. 1 deep inside camper/cabin
var _interior_target := 0.0
var lamp_level := 0.0        # 0..1 exterior lamp intensity factor
var current := LightingPreset.new()
## Phase 8 weather inputs (WeatherService decides, this node applies).
var weather_cloud := 0.0
var weather_rain := 0.0
var weather_wind := 1.0
var weather_wind_dir := Vector2(0.8, 0.6)
var weather_wetness := 0.0
var weather_flash := 0.0
## Effective wind strength actually written to the shared shader globals
## (trees, grass, water detail, rain and the wind-in-leaves audio read it).
var wind_now := 0.5

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
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 96.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_sky_affect = 0.25
	env.volumetric_fog_ambient_inject = 0.5
	env.volumetric_fog_temporal_reprojection_enabled = true
	world_env = WorldEnvironment.new()
	world_env.environment = env
	cam_attr = CameraAttributesPractical.new()
	cam_attr.auto_exposure_enabled = false
	world_env.camera_attributes = cam_attr
	add_child(world_env)
	set_time_of_day(hour)
	Settings.changed.connect(apply_quality)
	apply_quality()


func moon_illumination() -> float:
	return 0.5 * (1.0 - cos(TAU * moon_phase))


func set_moon_phase(v: float) -> void:
	moon_phase = fposmod(v, 1.0)
	_apply()


## Moon phase for a campaign day: full moon on day 4, new moon around day 19.
static func moon_phase_for_day(day: int) -> float:
	return fposmod(0.398 + float(day - 1) / 29.53, 1.0)


func describe() -> String:
	return "%02d:%02d, overcast %.2f (weather %.2f, rain %.2f), moon %.0f%% lit, interior %.2f, preset near '%s'" % [int(hour), int(fmod(hour, 1.0) * 60.0), overcast, weather_cloud, weather_rain, moon_illumination() * 100.0, interior, current.label]


## Named review presets used by the Preview Tour.
func apply_named(preset: String) -> void:
	match preset:
		"day": overcast = 0.0; set_time_of_day(12.5)
		"sunset": overcast = 0.0; set_time_of_day(19.2)
		"night": overcast = 0.0; set_time_of_day(23.5)
		"night_new": overcast = 0.0; moon_phase = 0.02; set_time_of_day(23.5)
		"night_full": overcast = 0.0; moon_phase = 0.5; set_time_of_day(23.5)
		"dawn": overcast = 0.0; set_time_of_day(6.4)
		"overcast": overcast = 1.0; set_time_of_day(12.5)


func set_overcast(v: float) -> void:
	overcast = clampf(v, 0.0, 1.0)
	set_time_of_day(hour)


## Called by WeatherService (throttled). `force` re-applies immediately.
func set_weather(cloud: float, rain: float, wind_mult: float, wind_dir: Vector2, wetness: float, flash: float, force := false) -> void:
	var changed := absf(cloud - weather_cloud) > 0.002 or absf(rain - weather_rain) > 0.002 or absf(wetness - weather_wetness) > 0.002 \
		or absf(wind_mult - weather_wind) > 0.002 or wind_dir.distance_to(weather_wind_dir) > 0.002 or absf(flash - weather_flash) > 0.0005
	weather_cloud = clampf(cloud, 0.0, 1.0)
	weather_rain = clampf(rain, 0.0, 1.0)
	weather_wind = maxf(wind_mult, 0.0)
	weather_wind_dir = wind_dir.normalized() if wind_dir.length() > 0.01 else Vector2(0.8, 0.6)
	weather_wetness = clampf(wetness, 0.0, 1.0)
	weather_flash = clampf(flash, 0.0, 1.0)
	if changed or force:
		_blend_presets()
		_apply()


func effective_overcast() -> float:
	return maxf(overcast, weather_cloud)


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
	var oc := effective_overcast() * (1.0 - _night_factor() * 0.7)
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
	var illum := moon_illumination()
	var nf := _night_factor()
	moon.light_color = p.moon_color
	# Moonlight scales with the visible fraction of the disc (new moon ~10 %).
	moon.light_energy = p.moon_energy * moon_up * (1.0 - sun_up) * lerpf(1.0, 0.22 + 0.78 * illum, nf)
	moon.visible = moon.light_energy > 0.01
	moon.shadow_enabled = moon.visible and quality != "low"
	sky_mat.set_shader_parameter("zenith_color", p.sky_zenith)
	sky_mat.set_shader_parameter("horizon_color", p.sky_horizon)
	sky_mat.set_shader_parameter("ground_color", p.sky_ground)
	sky_mat.set_shader_parameter("halo_color", p.sun_halo)
	sky_mat.set_shader_parameter("stars", p.stars * lerpf(1.0, 1.25 - 0.75 * illum, nf))
	sky_mat.set_shader_parameter("moon_phase", moon_phase)
	sky_mat.set_shader_parameter("cloud_cover", p.cloud_cover)
	sky_mat.set_shader_parameter("sun_dir", sd)
	sky_mat.set_shader_parameter("moon_dir", md)
	sky_mat.set_shader_parameter("cloud_offset", _cloud_offset)
	var interior_k := interior
	# Night ambient follows the moon: on a dark night only lamps, fire and
	# the moon's silhouette light remain.
	# Lightning (distant storm) briefly lifts sky and ambient only; never
	# lamps or anything SafetyService reads. Level already follows the
	# flash-reduction comfort setting.
	var fl := weather_flash * (1.0 - interior_k * 0.6)
	env.ambient_light_energy = p.ambient_energy * lerpf(1.0, 0.6 + 0.4 * illum, nf) * lerpf(1.0, 0.35, interior_k) * (1.0 + fl * 2.0 * nf + fl * 0.4)
	env.background_energy_multiplier = 1.0 + fl * (0.6 + 2.4 * nf)
	env.ambient_light_sky_contribution = 1.0
	env.fog_light_color = p.fog_color
	# Night mist: thicker and darker on moonless nights so the forest fades
	# to black within a few dozen metres; a full moon thins it.
	env.fog_density = p.fog_density * lerpf(1.0, lerpf(1.6, 0.55, illum), nf) * (1.0 + weather_rain * 0.35)
	env.fog_height = _ground_fog_y + 2.5
	env.fog_height_density = lerpf(p.fog_height_density, 0.05, nf)
	env.volumetric_fog_enabled = quality in ["high", "ultra"] and p.volumetric > 0.0005
	env.volumetric_fog_density = p.volumetric * (1.0 if quality == "ultra" else 0.8) * lerpf(1.0, lerpf(1.3, 0.7, illum), nf)
	env.volumetric_fog_albedo = p.fog_color.lerp(Color(1, 1, 1), 0.4)
	sun.light_volumetric_fog_energy = 1.6
	moon.light_volumetric_fog_energy = 0.8
	env.glow_intensity = p.glow_intensity * (1.0 if Settings.get_v("bloom") else 0.0)
	env.glow_enabled = Settings.get_v("bloom")
	var grade: float = Settings.get_v("color_grading")
	# AgX keeps hues in bright light but reads flatter: compensate a little.
	var agx: bool = Settings.get_v("tonemapper") == "agx"
	env.tonemap_mode = Environment.TONE_MAPPER_AGX if agx else Environment.TONE_MAPPER_FILMIC
	env.adjustment_saturation = lerpf(1.0, p.saturation, grade) * (1.14 if agx else 1.0)
	env.adjustment_contrast = lerpf(1.0, p.contrast, grade) * (1.12 if agx else 1.0)
	env.tonemap_exposure = p.exposure * lerpf(1.0, 1.35, interior_k) * (1.12 if agx else 1.0)
	RenderingServer.global_shader_parameter_set("sun_dir_world", sd if sd.y > -0.1 else md)
	RenderingServer.global_shader_parameter_set("daylight", clampf(sun_up * clampf(p.sun_energy, 0.0, 1.4) / 1.4 + 0.15 * moon_up * (1.0 - sun_up), 0.0, 1.0))
	# One shared wind field: prevailing direction and strength from the
	# weather, local variation comes from the gust function in the shaders.
	wind_now = p.wind * weather_wind
	RenderingServer.global_shader_parameter_set("wind_dir", weather_wind_dir)
	RenderingServer.global_shader_parameter_set("wind_strength", wind_now)
	RenderingServer.global_shader_parameter_set("wetness", weather_wetness)
	RenderingServer.global_shader_parameter_set("rain_amount", weather_rain)
	RenderingServer.global_shader_parameter_set("sun_clarity", clampf(1.0 - effective_overcast() * 0.85, 0.0, 1.0))
	# Heat shimmer only over sunny dry sand: cloud, rain and wet ground calm it.
	var haze_k := (1.0 - effective_overcast()) * (1.0 - weather_wetness) * (1.0 - weather_rain)
	RenderingServer.global_shader_parameter_set("haze_strength", p.heat_haze * haze_k * (1.0 if Settings.get_v("heat_haze") else 0.0))
	lamp_level = p.lamps
	get_tree().call_group("camp_lamps", "set_level", lamp_level)
	get_tree().call_group("post_fx", "set_grade", p.warmth, grade)


func _orient(light: DirectionalLight3D, dir: Vector3) -> void:
	# A DirectionalLight3D shines along its -Z; point it away from `dir`.
	var target := -dir
	var up := Vector3.UP if absf(target.y) < 0.98 else Vector3.FORWARD
	light.global_transform = Transform3D(Basis.looking_at(target, up), Vector3.ZERO)


func _process(delta: float) -> void:
	# Ground mist follows the terrain under the camera (fog height is world
	# space, so it is re-centred as you move; cheap, only when it matters).
	var cam := get_viewport().get_camera_3d()
	if cam and _night_factor() > 0.01:
		var gy := World.height_at(cam.global_position.x, cam.global_position.z)
		if absf(gy - _ground_fog_y) > 0.5:
			_ground_fog_y = gy
			env.fog_height = _ground_fog_y + 2.5
	if absf(interior - _interior_target) > 0.001:
		interior = move_toward(interior, _interior_target, delta * 1.5)
		_apply()
	_cloud_timer += delta
	if _cloud_timer > 3.0:
		_cloud_timer = 0.0
		_cloud_offset += 0.02 * (0.3 + wind_now)
		sky_mat.set_shader_parameter("cloud_offset", _cloud_offset)


func apply_quality() -> void:
	quality = Settings.get_v("quality")
	_apply()
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
