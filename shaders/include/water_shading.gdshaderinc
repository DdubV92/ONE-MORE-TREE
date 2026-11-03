// Shared optical model for ocean, river and ponds: depth-based absorption,
// guarded screen-space refraction, fresnel-weighted transmission and ripple
// normals. Reflections come from the engine (sky radiance / reflection probes).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 absorption = vec3(0.55, 0.12, 0.09);   // per meter, R G B
uniform vec3 scatter_color : source_color = vec3(0.02, 0.26, 0.3);
uniform float refraction_strength = 0.035;
uniform vec4 ripples[16];      // x, z, start time, strength
uniform int ripple_count = 0;

float view_depth_at(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return p.z / p.w;
}

// Returns the screen color seen through the water and the water path length.
vec4 refracted_scene(vec2 screen_uv, vec3 frag_view, vec3 n_view, mat4 inv_proj, float strength_scale) {
	float scene_z = view_depth_at(screen_uv, inv_proj);
	float thick = max(frag_view.z - scene_z, 0.0);
	vec2 off = n_view.xy * refraction_strength * strength_scale * clamp(thick * 0.7, 0.0, 1.0);
	vec2 uv_r = clamp(screen_uv + off, vec2(0.002), vec2(0.998));
	float scene_r = view_depth_at(uv_r, inv_proj);
	// Reject samples of objects in front of the water surface (no bending
	// of the camper or the player's tools through the water).
	if (scene_r > frag_view.z - 0.02) {
		uv_r = screen_uv;
		scene_r = scene_z;
	}
	float path = max(frag_view.z - scene_r, 0.0);
	vec3 col = textureLod(screen_tex, uv_r, 0.0).rgb;
	return vec4(col, path);
}

vec3 apply_absorption(vec3 scene, float path, float vertical_bias) {
	vec3 tr = exp(-absorption * path * vertical_bias);
	return scene * tr + scatter_color * (1.0 - tr) * (0.35 + 0.65 * daylight);
}

// Expanding ripple rings: returns XZ slope contribution.
vec2 ripple_slope(vec2 xz, float t) {
	vec2 s = vec2(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= ripple_count) break;
		vec4 r = ripples[i];
		float age = t - r.z;
		if (age < 0.0 || age > 4.0) continue;
		vec2 d = xz - r.xy;
		float dist = length(d) + 1e-4;
		float front = age * 1.4;
		float x = dist - front;
		float env = exp(-x * x * 6.0) * exp(-age * 1.1) * r.w;
		s += (d / dist) * cos(x * 14.0) * env * 0.6;
	}
	return s;
}
