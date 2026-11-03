shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Sheltered-coast ocean: vertex-displaced Gerstner waves (amplitudes fade
// with water depth), swash run-up across beaches, broken shoreline foam,
// depth absorption, guarded refraction and restrained glints.

#include "res://shaders/include/world_common.gdshaderinc"
#include "res://shaders/include/water_shading.gdshaderinc"

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D masks : filter_linear, repeat_disable;
uniform vec2 grid_origin;
uniform float cell_size = 2.0;
uniform ivec2 grid_dims;

uniform vec4 waves[5];          // dir.x, dir.y, wavelength, steepness
uniform float wave_scale = 1.0;
uniform sampler2D detail_normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform float detail_strength = 0.35;
uniform float glint_roughness = 0.035;

varying vec3 v_wpos;
varying float v_ground;
varying float v_beach;
varying float v_rock;
varying float v_crest;
varying float v_swash_edge;
varying float v_dist;

float ground_at(vec2 xz) {
	vec2 f = (xz - grid_origin) / cell_size;
	ivec2 i = ivec2(floor(f));
	vec2 t = fract(f);
	ivec2 mx = grid_dims - 1;
	if (any(lessThan(i, ivec2(0))) || any(greaterThan(i + 1, mx))) return -26.0;
	float a = texelFetch(heightmap, i, 0).r;
	float b = texelFetch(heightmap, i + ivec2(1, 0), 0).r;
	float c = texelFetch(heightmap, i + ivec2(0, 1), 0).r;
	float d = texelFetch(heightmap, i + ivec2(1, 1), 0).r;
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

vec3 gerstner(vec4 w, vec2 p, float t, float amp_scale, inout vec3 tangent, inout vec3 binormal) {
	float k = 6.2831853 / w.z;
	float c = sqrt(9.81 / k);
	vec2 d = normalize(w.xy);
	float f = k * (dot(d, p) - c * t);
	float a = (w.w / k) * amp_scale;
	float st = w.w * amp_scale;
	tangent += vec3(-d.x * d.x * st * sin(f), d.x * st * cos(f), -d.x * d.y * st * sin(f));
	binormal += vec3(-d.x * d.y * st * sin(f), d.y * st * cos(f), -d.y * d.y * st * sin(f));
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 xz = wp.xz;
	float ground = ground_at(xz);
	float depth = sea_level - ground;
	vec2 guv = (xz - grid_origin) / (cell_size * vec2(grid_dims - 1));
	vec4 m = textureLod(masks, guv, 0.0);
	float beach = m.r;
	float dist = length(xz - CAMERA_POSITION_WORLD.xz);
	// Waves calm in shallow water and fade far away (cheap horizon).
	float amp = wave_scale * clamp(depth / 4.0, 0.12, 1.0) * (1.0 - smoothstep(700.0, 1400.0, dist));
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 disp = vec3(0.0);
	for (int i = 0; i < 5; i++) {
		disp += gerstner(waves[i], xz, world_time, amp, tangent, binormal);
	}
	float y = sea_level + disp.y;
	// Swash sheet: water runs up the beach and withdraws (shared with terrain wetness).
	float sw = swash_level(xz, world_time, beach);
	float edge = 0.0;
	if (depth < 1.5 && sw > y) {
		y = sw;
		edge = 1.0;
	}
	wp.xz += disp.xz * (1.0 - edge);
	wp.y = y;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	vec3 n = normalize(cross(binormal, tangent));
	NORMAL = mix(n, vec3(0.0, 1.0, 0.0), edge * 0.7);
	TANGENT = normalize(tangent);
	BINORMAL = normalize(binormal);
	v_wpos = wp;
	v_ground = ground;
	v_beach = beach;
	v_rock = m.a;
	v_crest = clamp(disp.y / max(0.18 * wave_scale, 0.01), 0.0, 1.0);
	v_swash_edge = edge;
	v_dist = dist;
}

void fragment() {
	vec2 xz = v_wpos.xz;
	float depth_here = max(v_wpos.y - v_ground, 0.0);
	float t = world_time;

	// Detail normals: two scrolling layers following the wind.
	vec2 wd = normalize(wind_dir);
	vec3 na = texture(detail_normal_a, xz * 0.055 + wd * t * 0.018).rgb * 2.0 - 1.0;
	vec3 nb = texture(detail_normal_b, xz * 0.13 - wd.yx * t * 0.026).rgb * 2.0 - 1.0;
	vec2 slope = (na.xy + nb.xy * 0.6) * detail_strength * (0.5 + 0.5 * wind_strength);
	slope *= 1.0 - smoothstep(150.0, 600.0, v_dist) * 0.7;
	slope += ripple_slope(xz, t);
	vec3 nmap = normalize(vec3(slope.x, slope.y, 1.0));
	NORMAL_MAP = nmap * 0.5 + 0.5;

	// --- Foam -------------------------------------------------------------
	float fn = texture(foam_noise, xz * 0.09 + vec2(t * 0.012, -t * 0.008)).r;
	float fn2 = texture(foam_noise, xz * 0.31 - vec2(t * 0.02, t * 0.015)).r;
	float broken = smoothstep(0.42, 0.75, fn * 0.65 + fn2 * 0.5);
	float ground_depth = sea_level - v_ground;
	// Swash leading edge: thin water over sand.
	float thin = v_wpos.y - v_ground;
	float edge_foam = (1.0 - smoothstep(0.0, 0.07, thin)) * smoothstep(-0.02, 0.01, thin) * v_beach;
	// Breaking band: a crest rolling in where the swash phase starts.
	float ph = swash_phase(xz, t);
	float band_pos = mix(1.3, 0.0, smoothstep(0.0, 0.28, ph));
	float breaking = exp(-pow((ground_depth - band_pos) * 3.0, 2.0)) * (1.0 - smoothstep(0.2, 0.35, ph)) * smoothstep(-0.3, 0.2, ground_depth) * v_beach;
	// Lingering wash lace during backwash.
	float lace = v_swash_edge * smoothstep(0.3, 0.9, ph) * smoothstep(0.55, 0.8, fn2) * v_beach;
	// Impact foam around rocky coast, pulsing with the swash.
	float rock_foam = v_rock * (1.0 - smoothstep(0.0, 1.6, ground_depth)) * (0.4 + 0.6 * swash_env(fract(ph + 0.15))) * smoothstep(0.35, 0.7, fn);
	// Occasional open-water crest flecks.
	float flecks = smoothstep(0.75, 1.0, v_crest) * smoothstep(0.62, 0.85, fn2) * 0.6 * (1.0 - smoothstep(200.0, 500.0, v_dist));
	float foam = clamp(edge_foam * 1.2 + breaking * broken * 1.3 + lace * 0.8 + rock_foam + flecks, 0.0, 1.0);

	// --- Optics -----------------------------------------------------------
	vec3 n_view = normalize(mix(NORMAL, normalize(TANGENT * nmap.x + BINORMAL * nmap.y + NORMAL * nmap.z), 1.0));
	vec4 refr = refracted_scene(SCREEN_UV, VERTEX, n_view, INV_PROJECTION_MATRIX, 1.0);
	vec3 body = apply_absorption(refr.rgb, refr.a, 1.0);
	float ndv = clamp(dot(n_view, VIEW), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	vec3 foam_col = vec3(0.92, 0.95, 0.95);

	ALBEDO = mix(scatter_color * 0.15, foam_col, foam);
	EMISSION = body * (1.0 - fres) * (1.0 - foam);
	ROUGHNESS = mix(glint_roughness, 0.85, foam);
	SPECULAR = 0.5 * (1.0 - foam);
	METALLIC = 0.0;
	// Soft contact where water meets sand/rock: no hard intersection line.
	ALPHA = clamp(refr.a * 6.0 + foam, 0.0, 1.0) * smoothstep(0.0, 0.015, thin + 0.01);
}
