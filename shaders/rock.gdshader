shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Rocks: triplanar CC0 rock scans (terrain array layers 7/8) with a moss
// cap on upward faces, wet darkening and caustics when submerged.

#include "res://shaders/include/world_common.gdshaderinc"

uniform sampler2DArray albedo_array : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_array : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray arm_array : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 v_wpos;
varying vec3 v_wn;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri(sampler2DArray tex, vec3 p, vec3 w, float layer) {
	return texture(tex, vec3(p.zy * 0.3, layer)).rgb * w.x
		+ texture(tex, vec3(p.xz * 0.3, layer)).rgb * w.y
		+ texture(tex, vec3(p.xy * 0.3, layer)).rgb * w.z;
}

void fragment() {
	vec3 w = pow(abs(v_wn), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float layer_rock = 8.0;
	float moss = smoothstep(0.45, 0.85, v_wn.y + (vnoise(v_wpos.xz * 0.7) - 0.5) * 0.4) * smoothstep(0.6, 2.5, v_wpos.y);
	vec3 a_rock = tri(albedo_array, v_wpos, w, 7.0) * vec3(0.85, 0.85, 0.82);
	vec3 a_alt = tri(albedo_array, v_wpos, w, layer_rock) * vec3(0.7, 0.68, 0.66);
	float mixv = vnoise(v_wpos.xz * 0.05 + v_wpos.y * 0.1);
	vec3 alb = mix(mix(a_rock, a_alt, mixv * 0.6), a_rock * vec3(0.8, 1.0, 0.7), moss * 0.5);
	vec3 arm = tri(arm_array, v_wpos, w, 7.0);
	// Wet near the sea
	float wet = 1.0 - smoothstep(sea_level + 0.1, sea_level + 0.9, v_wpos.y);
	alb *= mix(1.0, 0.6, wet);
	ALBEDO = alb;
	ROUGHNESS = mix(clamp(arm.g, 0.5, 1.0), 0.25, wet);
	AO = arm.r;
	if (v_wpos.y < sea_level) {
		float c = caustics(v_wpos.xz * 0.9, world_time);
		EMISSION = alb * c * exp(-(sea_level - v_wpos.y) * 0.35) * daylight * clamp(sun_dir_world.y * 2.5, 0.0, 1.0) * 1.2;
	}
}
