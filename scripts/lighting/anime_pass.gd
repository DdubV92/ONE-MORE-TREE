class_name AnimePass
extends MeshInstance3D
## Phase 24 "drawn world": the full-screen ink-and-paint quad
## (shaders/anime_ink.gdshader). On when Settings.world_style == "anime".
## Lives in the 3D scene so it can read depth and normals; draws before
## water and other transparent things (render priority), so those keep
## their own crisp shading on top of the painted world.

const LAYER := 17                  # own layer: security-camera feeds skip it

## The earlier smooth painted look ("anime").
const SMOOTH := {"pixel_mode": 0.0, "brush_radius": 3, "brush_px": 1.0, "detail": 0.3, "tone_steps": 5.0, "tone_strength": 0.55, "tone_soft": 0.16,
	"ink_strength": 0.85, "ink_px": 1.25, "ink_far": 170.0, "hatch": 0.0, "boil": 0.0, "saturation": 1.12}
## The hand-drawn pixel world ("drawn").
## Sharp first (owner request): the smallest brush, most of the surface
## detail kept under it, no moving lines unless asked for (ANIME_BOIL), and
## hatching only in the very darkest tones.
const DRAWN := {"pixel_mode": 1.0, "brush_radius": 1, "brush_px": 1.0, "detail": 0.45, "tone_steps": 4.0, "tone_strength": 0.9, "tone_soft": 0.035,
	"ink_strength": 1.0, "ink_px": 1.0, "ink_far": 230.0, "hatch": 0.5, "boil": 0.0, "saturation": 1.08}
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
	return str(Settings.get_v("world_style")) in ["anime", "drawn"] and DisplayServer.get_name() != "headless"


func _apply() -> void:
	visible = enabled()
	if not visible:
		return
	var q := str(Settings.get_v("quality"))
	var drawn := str(Settings.get_v("world_style")) == "drawn"
	# "drawn": the frame is rendered on the art-pixel grid, so the pass
	# works in whole art pixels: flat cel tones, firm one-pixel ink lines
	# that boil a little, pencil hatching in the shadows.
	var set := DRAWN if drawn else SMOOTH
	for key in set:
		mat.set_shader_parameter(key, set[key])
	if not drawn:
		mat.set_shader_parameter("brush_radius", 2 if q == "low" else 3)
	if drawn and float(Settings.get_v("shake_strength")) <= 0.001:
		mat.set_shader_parameter("boil", 0.0)      # comfort: no moving lines
	# Tuning overrides for captures (ANIME_<PARAM>=value).
	for key in ["amount", "brush_px", "tone_steps", "tone_strength", "tone_soft", "ink_strength", "ink_px", "ink_depth", "ink_normal", "saturation", "detail", "hatch", "boil", "hatch_shade", "hatch_deep"]:
		var e: String = "ANIME_" + str(key).to_upper()
		if OS.has_environment(e):
			mat.set_shader_parameter(key, float(OS.get_environment(e)))
