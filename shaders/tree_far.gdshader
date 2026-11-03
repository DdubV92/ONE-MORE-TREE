shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

// Distant tree silhouettes: solid low-poly volumes with crown colour (no
// alpha, no shimmer). Vertex COLOR carries the albedo.

#include "res://shaders/include/world_common.gdshaderinc"

varying vec3 v_col;

void vertex() {
	v_col = COLOR.rgb * mix(0.85, 1.12, INSTANCE_CUSTOM.r);
	float h = max(INSTANCE_CUSTOM.b, 1.0);
	float hn = clamp(VERTEX.y / max(h / max(length(MODEL_MATRIX[1].xyz), 0.01), 1.0), 0.0, 1.0);
	vec2 wd = normalize(wind_dir);
	VERTEX.xz += wd * hn * hn * 0.25 * wind_strength * sin(world_time * 0.9 + INSTANCE_CUSTOM.g * 6.28);
}

void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = v_col * 0.3;
}
