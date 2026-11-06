// Shared optical model for ocean, river and ponds: depth-based absorption,
// guarded screen-space refraction, fresnel-weighted transmission and ripple
// normals. Reflections come from the engine (sky radiance / reflection probes).
//
// Phase 24 stylized pass (techniques after the gameidea.org stylized water
// tutorial, own implementation - see docs/research/STYLIZED_WATER.md):
// vertical thickness from the reconstructed scene position, crystalline
// turquoise shallows (tint + mid-depth inscatter ramp on top of Beer-Lambert),
// contact foam that dissolves through a warped Voronoi network wherever water
// meets rock, posts or hulls (with a darker foam edge), cel-banded foam for
// the pixel-art direction, crest translucency and small sun sparkles.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 absorption = vec3(0.55, 0.12, 0.09);   // per meter, R G B
uniform vec3 scatter_color : source_color = vec3(0.02, 0.26, 0.3);
uniform float refraction_strength = 0.035;
uniform vec4 ripples[16];      // x, z, start time, strength
uniform int ripple_count = 0;
uniform vec3 shallow_tint : source_color = vec3(0.5, 0.96, 0.86);    // crystal shallows
uniform vec3 shallow_scatter : source_color = vec3(0.09, 0.5, 0.46); // aqua inscatter (shallow)
uniform float shallow_depth = 1.8;      // metres over which the shallows take the tint
uniform float scatter_ramp_depth = 9.0; // metres from aqua to deep scatter_color
uniform float contact_foam_width = 0.22;   // metres of water depth that foam at contacts
uniform float contact_foam_amount = 0.9;
uniform float foam_bands = 3.0;            // 0 = smooth foam; 3 = cel bands
uniform float sparkle_amount = 1.0;
uniform vec3 aqua_glow : source_color = vec3(0.06, 0.62, 0.56);  // reference-art turquoise glow
uniform float aqua_glow_amount = 0.55;

float view_depth_at(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return p.z / p.w;
}

// Returns the screen color seen through the water and the water path length.
vec4 refracted_scene(vec2 screen_uv, vec3 frag_view, vec3 n_view, mat4 inv_proj, float strength_scale, out vec2 uv_used) {
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
	uv_used = uv_r;
	vec3 col = textureLod(screen_tex, uv_r, 0.0).rgb;
	return vec4(col, path);
}

vec3 apply_absorption(vec3 scene, float path, float vertical_bias) {
	vec3 tr = exp(-absorption * path * vertical_bias);
	return scene * tr + scatter_color * (1.0 - tr) * (0.35 + 0.65 * daylight);
}

// World position of whatever the depth buffer holds at uv (seabed, rock,
// post, hull). Used for the vertical water thickness above it.
vec3 scene_world_at(vec2 uv, mat4 inv_proj, mat4 inv_view) {
	float d = texture(depth_tex, uv).r;
	vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return (inv_view * vec4(p.xyz / p.w, 1.0)).xyz;
}

// Stylized Beer-Lambert: the floor is seen through a turquoise tint that
// settles in over the first metres (crystal shallows); light scattered back
// out of the water ramps from aqua (shallow) to the deep scatter colour.
vec3 stylized_body(vec3 scene, float path, float vthick) {
	float vt = max(vthick, 0.0);
	vec3 tr = exp(-absorption * path);
	float sh = 1.0 - exp(-vt / max(shallow_depth, 0.01));
	vec3 seen = scene * mix(vec3(1.0), shallow_tint, sh);
	vec3 sc = mix(shallow_scatter, scatter_color, smoothstep(0.4, scatter_ramp_depth, vt));
	// Reference-art stylisation: shallows glow turquoise of their own accord
	// (light added, not a tint of the floor), strongest from ankle to waist
	// depth, fading into the deep teal; the floor reads a little through it.
	float glow_k = smoothstep(0.03, 0.7, vt) * (1.0 - smoothstep(2.5, 9.0, vt)) * aqua_glow_amount;
	vec3 lit = vec3(0.35 + 0.65 * daylight);
	return seen * tr * (1.0 - 0.35 * glow_k) + sc * (1.0 - tr) * (0.3 + 0.7 * daylight) + aqua_glow * glow_k * lit;
}

// Cel bands: foam reads as a few flat tones (hand-placed clusters) instead
// of a smooth gradient. Soft 0.04 steps keep the bands from aliasing.
float foam_cel(float f) {
	if (foam_bands < 1.5) return f;
	return smoothstep(0.24, 0.28, f) * 0.55 + smoothstep(0.58, 0.62, f) * 0.45;
}

// Contact foam: 1 at the line where water meets something solid, dissolving
// through a drifting Voronoi network as the water deepens (the threshold
// rises with depth, so it breaks into lace rather than fading as a band).
float contact_foam_at(vec2 xz, float t, float vthick, float width) {
	float r = clamp(vthick / max(width, 0.001), 0.0, 1.0);
	if (r >= 1.0 || vthick < -0.05) return 0.0;
	vec2 w = vec2(vnoise(xz * 0.8 + t * 0.22), vnoise(xz * 0.8 - t * 0.19 + 4.1)) * 0.7;
	float e = voronoi_edge(xz * 2.6 + w + vec2(t * 0.05, -t * 0.04));
	float n = (1.0 - smoothstep(0.0, 0.38, e)) * 0.7 + vnoise(xz * 3.1 - t * 0.3) * 0.3;
	float pulse = 0.08 * sin(t * 1.4 + vnoise(xz * 0.35) * 6.2831);
	return smoothstep(r - 0.06, r + 0.06, n + 0.12 - r * 0.25 + pulse);
}

// Small stylized sun sparkles where the rippled surface mirrors the sun.
float sun_sparkle(vec3 n_view, vec3 view, mat4 view_mat, vec2 xz, float t) {
	vec3 sun_v = normalize((view_mat * vec4(sun_dir_world, 0.0)).xyz);
	float a = clamp(dot(reflect(-view, n_view), sun_v), 0.0, 1.0);
	float g = pow(a, 900.0) * step(0.72, hash12(floor(xz * 7.0) + floor(t * 6.0)));
	return g * sparkle_amount * daylight * sun_clarity * clamp(sun_dir_world.y * 3.0, 0.0, 1.0);
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
