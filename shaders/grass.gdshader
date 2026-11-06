shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Grass / reed / dune-grass blades. COLOR.r = height along blade (0 base,
// 1 tip), COLOR.g = per-blade random. Colour gradient + wind bend.

#include "res://shaders/include/world_common.gdshaderinc"
#include "res://shaders/include/tree_wind.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.16, 0.22, 0.07);
uniform vec3 tip_color : source_color = vec3(0.5, 0.58, 0.24);
uniform float sway = 0.12;

varying float v_h;
varying float v_r;
varying vec3 v_wpos;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = COLOR.r;
	float g = gust_at(origin.xz, world_time) * wind_strength;
	vec2 wd = (length(wind_dir) > 1e-4 ? normalize(wind_dir) : vec2(0.8, 0.6));
	float wob = sin(world_time * 2.3 + origin.x * 0.7 + origin.z * 0.5 + COLOR.g * 6.0);
	vec2 off = (wd * (g * 0.8 + wob * 0.35 * g) + vec2(wob, -wob) * 0.05) * sway * h * h;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off.x, -dot(off, off) * 0.5, off.y, 0.0)).xyz;
	v_h = h;
	v_r = COLOR.g;
	v_wpos = origin;
}

void fragment() {
	float n = vnoise(v_wpos.xz * 0.15);
	vec3 tip = tip_color * mix(0.8, 1.15, n) * mix(0.9, 1.1, v_r);
	vec3 c = mix(base_color, tip, smoothstep(0.0, 1.0, v_h));
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.6;
	AO = mix(0.4, 1.0, v_h);
	AO_LIGHT_AFFECT = 0.5;
}
