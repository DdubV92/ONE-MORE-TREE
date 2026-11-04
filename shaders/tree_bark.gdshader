shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Tree trunks/branches. Pine and spruce use CC0 Poly Haven bark scans;
// birch uses a procedural white bark with dark lenticels and a dark base.
// INSTANCE_CUSTOM: r = tint variation, g = wind phase, b = tree height.

#include "res://shaders/include/world_common.gdshaderinc"
#include "res://shaders/include/tree_wind.gdshaderinc"

uniform bool birch = false;
uniform sampler2D bark_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_arm : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float uv_scale_v = 0.5;
// Active-tree (TreeActor) parameters; instanced trees leave these at 0.
uniform float actor_height = 0.0;     // >0: not instanced, use these values
uniform float actor_phase = 0.0;
uniform float actor_tint = 0.5;
uniform float sway_scale = 1.0;
uniform bool notch_enabled = false;
uniform float notch_y = 0.0;          // mesh-local cut height
uniform vec2 notch_dir = vec2(0.0, 1.0); // mesh-local XZ toward the notched face
uniform float notch_r = 0.3;          // mesh-local trunk radius at the cut
uniform float notch_depth = 0.0;      // mesh-local depth from the bark surface
uniform float notch_open = 0.8;       // tan of the top face angle
uniform int clip_mode = 0;            // 0 none, 1 keep above clip_y, 2 keep below
uniform float clip_y = 0.0;

varying float v_tint;
varying float v_height;
varying vec3 v_local;

varying vec3 v_rest;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	bool actor = actor_height > 0.0;
	float h = actor ? actor_height : max(INSTANCE_CUSTOM.b, 1.0);
	float phase = actor ? actor_phase : INSTANCE_CUSTOM.g;
	float sy = max(length(MODEL_MATRIX[1].xyz), 0.01);
	v_rest = VERTEX;
	vec3 sway = tree_sway(VERTEX, h / sy, origin, phase * 6.28, world_time) + impact_sway(VERTEX, h / sy, origin, world_time);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(sway * sway_scale, 0.0)).xyz;
	v_tint = actor ? actor_tint : INSTANCE_CUSTOM.r;
	v_height = h;
	v_local = VERTEX;
}

void fragment() {
	if (clip_mode == 1 && v_rest.y < clip_y) discard;
	if (clip_mode == 2 && v_rest.y > clip_y) discard;
	if (notch_enabled && notch_depth > 0.0) {
		// Wedge removed from the notched face: bottom face flat at notch_y,
		// top face rising outward. Bark inside the wedge is not drawn; the
		// TreeActor supplies the exposed wood faces.
		float u = dot(v_rest.xz, notch_dir) - (notch_r - notch_depth);
		if (u > 0.0 && v_rest.y > notch_y && v_rest.y < notch_y + u * notch_open) discard;
	}
	vec2 uv = vec2(UV.x, UV.y * uv_scale_v);
	if (birch) {
		float y = v_local.y;
		float ring = vnoise(vec2(UV.x * 18.0, y * 9.0));
		float lent = smoothstep(0.78, 0.86, vnoise(vec2(UV.x * 6.0, y * 14.0))) * smoothstep(0.4, 0.6, ring);
		float base_dark = 1.0 - smoothstep(0.4, 2.2 + ring, y);
		vec3 white = mix(vec3(0.86, 0.85, 0.8), vec3(0.75, 0.73, 0.68), vnoise(vec2(UV.x * 30.0, y * 3.0)));
		vec3 c = mix(white, vec3(0.12, 0.1, 0.09), max(lent, base_dark * 0.85));
		ALBEDO = c * mix(0.92, 1.05, v_tint);
		ROUGHNESS = 0.75;
		NORMAL_MAP = vec3(0.5 + (ring - 0.5) * 0.15, 0.5, 1.0);
	} else {
		vec3 a = texture(bark_albedo, uv).rgb;
		ALBEDO = a * tint * mix(0.85, 1.12, v_tint);
		vec3 arm = texture(bark_arm, uv).rgb;
		AO = arm.r;
		ROUGHNESS = clamp(arm.g, 0.6, 1.0);
		NORMAL_MAP = texture(bark_normal, uv).rgb;
		NORMAL_MAP_DEPTH = 1.4;
	}
	// Rain darkens bark (streaking more on the windward side) and makes it
	// a little glossier; canopy keeps the lower trunk drier.
	float bw = wetness * mix(0.55, 0.9, clamp(v_local.y / 6.0, 0.0, 1.0));
	ALBEDO *= mix(1.0, 0.62, bw);
	ROUGHNESS = mix(ROUGHNESS, 0.35, bw * 0.7);
}
