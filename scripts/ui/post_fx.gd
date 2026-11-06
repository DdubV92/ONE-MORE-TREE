class_name PostFX
extends CanvasLayer
## Screen-space grade layer (below all UI). Reads Settings and the lighting
## preset's warmth. Skips drawing entirely when every effect is neutral.

var rect: ColorRect
var mat: ShaderMaterial
var _warmth := 0.0
var _grade := 1.0


func _ready() -> void:
	layer = 0
	add_to_group("post_fx")
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/post_fx.gdshader")
	rect.material = mat
	add_child(rect)
	Settings.changed.connect(_apply)
	get_viewport().size_changed.connect(_apply)
	_apply()


func set_grade(warmth: float, grade: float) -> void:
	_warmth = warmth
	_grade = grade
	_apply()


func _apply() -> void:
	mat.set_shader_parameter("chromatic", Settings.get_v("chromatic_aberration"))
	mat.set_shader_parameter("vignette", Settings.get_v("vignette"))
	mat.set_shader_parameter("grain", Settings.get_v("film_grain"))
	mat.set_shader_parameter("warmth", _warmth)
	mat.set_shader_parameter("grade", Settings.get_v("color_grading"))
	# Phase 24 HD-2D world: ~320 art pixels tall at any resolution.
	var hd2d := str(Settings.get_v("world_style")) == "hd2d"
	var vh := float(get_viewport().get_visible_rect().size.y) if is_inside_tree() else 1080.0
	mat.set_shader_parameter("pixel_px", maxf(round(vh / float(Settings.get_v("world_pixel_rows"))), 2.0) if hd2d else 0.0)
	var neutral: bool = not hd2d and Settings.get_v("chromatic_aberration") < 0.001 and Settings.get_v("vignette") < 0.001 and Settings.get_v("film_grain") < 0.001 and (absf(_warmth) < 0.001 or Settings.get_v("color_grading") < 0.001)
	rect.visible = not neutral
