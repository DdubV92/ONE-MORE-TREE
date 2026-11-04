shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Rain streak for RainView particles: a fixed-Y billboard (stays vertical,
// faces the camera), brightness follows daylight so drops never glow in the
// dark, soft tapered ends, faded right next to the lens.

global uniform float daylight;
uniform vec3 tint : source_color = vec3(0.78, 0.82, 0.88);
uniform float opacity = 0.32;

varying float v_fade;

void vertex() {
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	mat4 bb = mat4(vec4(right * sx, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_fade = smoothstep(0.4, 2.0, -vp.z) * (1.0 - smoothstep(18.0, 26.0, -vp.z));
}

void fragment() {
	float taper = sin(UV.y * 3.14159) * (1.0 - abs(UV.x * 2.0 - 1.0));
	ALBEDO = tint * (0.06 + 0.75 * daylight);
	ALPHA = opacity * taper * v_fade;
}
