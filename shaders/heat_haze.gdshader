shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

// Localized heat shimmer on an upright billboard quad: bounded screen-space
// distortion that fades at the quad edges and with distance. Never applied
// to the whole frame. `strength` 0 disables it (comfort setting).

#include "res://shaders/include/world_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float strength = 0.006;
uniform bool use_global_haze = false;   // true for sun-driven sand haze
uniform float max_distance = 60.0;

varying float v_fade;

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
	vec3 right = normalize(cross(up, to_cam));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 wp = MODEL_MATRIX[3].xyz + right * VERTEX.x * sx + up * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	float dist = length(CAMERA_POSITION_WORLD - wp);
	v_fade = 1.0 - smoothstep(max_distance * 0.6, max_distance, dist);
}

void fragment() {
	float g = use_global_haze ? global_haze_level() : 1.0;
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x) * smoothstep(0.0, 0.3, 1.0 - UV.y) * smoothstep(0.0, 0.2, UV.y);
	float t = world_time;
	vec2 n = vec2(vnoise(UV * vec2(6.0, 9.0) + vec2(0.0, t * 2.4)), vnoise(UV * vec2(7.0, 11.0) + vec2(3.1, t * 3.1))) - 0.5;
	vec2 off = n * strength * edge * v_fade * g;
	ALBEDO = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	ALPHA = step(0.0001, edge * v_fade * g);
}
