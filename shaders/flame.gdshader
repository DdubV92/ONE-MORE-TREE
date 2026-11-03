shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

// Procedural flame tongue on a camera-facing particle quad. Particle COLOR
// carries the lifetime ramp; INSTANCE_CUSTOM.y is the particle's age 0..1.

#include "res://shaders/include/world_common.gdshaderinc"

uniform float intensity = 2.2;
varying float v_age;
varying float v_seed;

void vertex() {
	// Cylindrical billboard (stays upright).
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
	vec3 right = normalize(cross(up, to_cam));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 wp = MODEL_MATRIX[3].xyz + right * VERTEX.x * sx + up * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	v_age = INSTANCE_CUSTOM.y;
	v_seed = fract(MODEL_MATRIX[3].x * 3.7 + MODEL_MATRIX[3].z * 5.1 + INSTANCE_CUSTOM.x);
}

void fragment() {
	vec2 uv = UV;
	float t = world_time * 2.2 + v_seed * 10.0;
	float n = fbm2(vec2(uv.x * 3.0 + v_seed * 7.0, uv.y * 2.5 + t));
	vec2 p = vec2((uv.x - 0.5) * 2.0 + (n - 0.5) * 0.7 * (1.0 - uv.y), uv.y);
	// Teardrop: wide at the base (uv.y=1), narrow tip at the top.
	float width = mix(0.08, 0.85, pow(uv.y, 0.8));
	float shape = 1.0 - smoothstep(width * 0.55, width, abs(p.x));
	shape *= smoothstep(0.0, 0.35, uv.y) * smoothstep(1.0, 0.85, uv.y);
	shape *= smoothstep(0.15, 0.55, n + uv.y * 0.6);
	float core = shape * smoothstep(0.45, 0.95, uv.y) * (1.0 - smoothstep(0.0, 0.3, abs(p.x)));
	vec3 col = mix(vec3(1.0, 0.25, 0.05), vec3(1.0, 0.6, 0.15), shape);
	col = mix(col, vec3(1.0, 0.92, 0.6), core);
	float a = shape * COLOR.a * (1.0 - smoothstep(0.6, 1.0, v_age));
	ALBEDO = col * a * intensity * COLOR.rgb;
}
