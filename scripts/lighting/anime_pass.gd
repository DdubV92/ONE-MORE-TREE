class_name AnimePass
extends MeshInstance3D
## Phase 24 "drawn world": the full-screen ink-and-paint quad
## (shaders/anime_ink.gdshader). On when Settings.world_style == "anime".
## Lives in the 3D scene so it can read depth and normals; draws before
## water and other transparent things (render priority), so those keep
## their own crisp shading on top of the painted world.

const LAYER := 17                  # own layer: security-camera feeds skip it
var mat: ShaderMaterial


func _ready() -> void:
	name = "AnimePass"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mesh = q
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/anime_ink.gdshader")
	mat.render_priority = -100
	material_override = mat
	layers = 1 << (LAYER - 1)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	Settings.changed.connect(_apply)
	_apply()


static func enabled() -> bool:
	return str(Settings.get_v("world_style")) == "anime" and DisplayServer.get_name() != "headless"


func _apply() -> void:
	visible = enabled()
	if not visible:
		return
	var q := str(Settings.get_v("quality"))
	mat.set_shader_parameter("brush_radius", 2 if q == "low" else 3)
	# Tuning overrides for captures (ANIME_<PARAM>=value).
	for key in ["amount", "brush_px", "tone_steps", "tone_strength", "ink_strength", "ink_px", "ink_depth", "ink_normal", "saturation", "detail"]:
		var e: String = "ANIME_" + str(key).to_upper()
		if OS.has_environment(e):
			mat.set_shader_parameter(key, float(OS.get_environment(e)))
