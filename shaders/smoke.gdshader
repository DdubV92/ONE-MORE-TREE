shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/include/world_common.gdshaderinc"

varying float v_age;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	v_age = INSTANCE_CUSTOM.y;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float n = fbm2(UV * 3.0 + world_time * 0.2 + v_age * 2.0);
	float a = (1.0 - smoothstep(0.3, 1.0, d + (n - 0.5) * 0.5)) * COLOR.a * sin(v_age * 3.14159);
	ALBEDO = mix(vec3(0.35, 0.33, 0.32), vec3(0.6, 0.58, 0.56), n) * (0.25 + 0.75 * daylight);
	ALPHA = a * 0.35;
}
