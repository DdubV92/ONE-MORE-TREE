shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Needle/leaf cards built from CC0 Poly Haven twig scans. Card normals are
// bent outward from the crown so clumps shade as volumes; back-lighting gives
// soft translucency. Alpha scissor keeps it in the opaque pass (cheap shadows).

#include "res://shaders/include/world_common.gdshaderinc"
#include "res://shaders/include/tree_wind.gdshaderinc"

uniform sampler2D card_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 tint_variation : source_color = vec3(0.9, 1.0, 0.85);
uniform float alpha_cut = 0.42;
uniform vec3 translucency : source_color = vec3(0.35, 0.4, 0.15);
uniform float flutter = 0.04;
uniform float actor_height = 0.0;
uniform float actor_phase = 0.0;
uniform float actor_tint = 0.5;
uniform float sway_scale = 1.0;

varying float v_tint;
varying float v_ao;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sy = max(length(MODEL_MATRIX[1].xyz), 0.01);
	bool actor = actor_height > 0.0;
	float h = (actor ? actor_height : max(INSTANCE_CUSTOM.b, 1.0)) / sy;
	float phase = (actor ? actor_phase : INSTANCE_CUSTOM.g) * 6.28;
	vec3 sway = (tree_sway(VERTEX, h, origin, phase, world_time) + impact_sway(VERTEX, h, origin, world_time)) * sway_scale;
	// Small per-card flutter (COLOR.g = card seed).
	float f = sin(world_time * 4.0 + COLOR.g * 40.0 + phase) * flutter * wind_strength * COLOR.r;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(sway, 0.0)).xyz + NORMAL * f;
	v_tint = actor ? actor_tint : INSTANCE_CUSTOM.r;
	v_ao = COLOR.b;
}

void fragment() {
	vec4 c = texture(card_albedo, UV);
	if (c.a < alpha_cut) discard;
	vec3 col = c.rgb * tint * mix(tint_variation, vec3(1.0), v_tint);
	ALBEDO = col * mix(0.55, 1.0, v_ao);
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = translucency * (0.5 + 0.5 * v_ao);
	AO = v_ao;
	AO_LIGHT_AFFECT = 0.4;
}
