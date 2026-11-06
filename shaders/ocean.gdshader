shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Sheltered-coast ocean: vertex-displaced Gerstner waves (amplitudes fade
// with water depth), swash run-up across beaches, broken shoreline foam,
// depth absorption, guarded refraction and restrained glints.
// Phase 24: stylized optics (crystal shallows, contact foam, cel foam,
// crest translucency, sparkles) from water_shading.gdshaderinc.

#include "res://shaders/include/world_common.gdshaderinc"
#include "res://shaders/include/water_shading.gdshaderinc"

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D masks : filter_linear, repeat_disable;
uniform sampler2D water_region_map : filter_nearest, repeat_disable;
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
uniform vec3 crest_glow : source_color = vec3(0.16, 0.78, 0.66);   // sunlit wave translucency

varying vec3 v_wpos;
varying float v_ground;
varying float v_beach;
varying float v_rock;
varying float v_crest;
varying float v_swash_edge;
varying float v_dist;
varying float v_jac;
uniform float shoal_depth = 9.0;
uniform float shoal_min = 0.05;

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
	float amp = wave_scale * (1.0 + 0.9 * sea_state) * clamp(depth / shoal_depth, shoal_min, 1.0) * (1.0 - smoothstep(700.0, 1400.0, dist));
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 disp = vec3(0.0);
	for (int i = 0; i < 5; i++) {
		disp += gerstner(waves[i], xz, world_time, amp, tangent, binormal);
	}
	float y = sea_level + disp.y;
	// Swash sheet: water runs up the beach and withdraws (shared with terrain wetness).
	float sw = swash_level(xz, world_time, beach);
	// Soft blend into the swash sheet (a hard switch shows as a seam).
	float edge = smoothstep(-0.03, 0.05, sw - y) * (1.0 - smoothstep(1.1, 1.5, depth));
	y = mix(y, max(y, sw), edge);
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
	v_crest = clamp(disp.y / max(1.1 * wave_scale, 0.01), 0.0, 1.0);
	// Jacobian of the horizontal Gerstner mapping: < 1 where crests bunch up.
	v_jac = tangent.x * binormal.z - tangent.z * binormal.x;
	v_swash_edge = edge;
	v_dist = dist;
}

void fragment() {
	vec2 xz = v_wpos.xz;
	// Inland water regions (river, ponds) have their own surfaces; the sea
	// plane never shows through low inland ground.
	vec2 ruv = (xz - grid_origin) / (cell_size * vec2(grid_dims - 1)) + 0.5 / vec2(grid_dims);
	if (all(greaterThanEqual(ruv, vec2(0.0))) && all(lessThanEqual(ruv, vec2(1.0))) && texture(water_region_map, ruv).r > 0.002) discard;
	float depth_here = max(v_wpos.y - v_ground, 0.0);
	float t = world_time;

	// Detail normals: two scrolling layers following the wind.
	vec2 wd = (length(wind_dir) > 1e-4 ? normalize(wind_dir) : vec2(0.8, 0.6));
	vec3 na = texture(detail_normal_a, xz * 0.055 + wd * t * 0.018).rgb * 2.0 - 1.0;
	vec3 nb = texture(detail_normal_b, xz * 0.13 - wd.yx * t * 0.026).rgb * 2.0 - 1.0;
	vec2 slope = (na.xy + nb.xy * 0.6) * detail_strength * (0.5 + 0.5 * wind_strength);
	slope *= 1.0 - smoothstep(150.0, 600.0, v_dist) * 0.7;
	slope += ripple_slope(xz, t);
	slope += rain_ripples(xz, t) * 0.5;
	vec3 nmap = normalize(vec3(slope.x, slope.y, 1.0));
	NORMAL_MAP = nmap * 0.5 + 0.5;

	// --- Foam -------------------------------------------------------------
	float fn = texture(foam_noise, xz * 0.09 + vec2(t * 0.012, -t * 0.008)).r;
	float fn2 = texture(foam_noise, xz * 0.31 - vec2(t * 0.02, t * 0.015)).r;
	float broken = smoothstep(0.42, 0.75, fn * 0.65 + fn2 * 0.5);
	float ground_depth = sea_level - v_ground;
	// Swash leading edge: thin water over sand.
	float thin = v_wpos.y - v_ground;
	float edge_foam = (1.0 - smoothstep(0.0, 0.022, thin)) * smoothstep(-0.015, 0.004, thin) * v_beach * (0.25 + 0.6 * foam_lace(xz * 1.6, t, 0.55));
	// Breaking band: a crest rolling in where the swash phase starts.
	float ph = swash_phase(xz, t);
	float band_pos = mix(1.3, 0.0, smoothstep(0.0, 0.28, ph));
	float breaking = exp(-pow((ground_depth - band_pos) * 3.0, 2.0)) * (1.0 - smoothstep(0.2, 0.35, ph)) * smoothstep(-0.3, 0.2, ground_depth) * v_beach;
	// Lingering wash lace during backwash.
	// Phase 24: a drifting Voronoi bubble network (thin cell borders) broken
	// up by large-scale noise, instead of ridge noise (which filled in as
	// solid scraps wherever the noise flattened out).
	vec2 lp = xz * 3.4;
	// Two warp octaves: the coarse one drifts the net, the fine one bends
	// each cell border into a wobbly bubble line.
	vec2 lw = vec2(vnoise(lp * 0.55 + t * 0.2), vnoise(lp * 0.55 - t * 0.17 + 3.3)) * 0.85
		+ vec2(vnoise(lp * 1.9 + 7.1), vnoise(lp * 1.9 - 2.6)) * 0.32;
	float net = 1.0 - smoothstep(0.015, 0.06, voronoi_edge(lp + lw));
	float breakup = smoothstep(0.42, 0.68, vnoise(xz * 1.6 + vec2(t * 0.1, 0.0))) * smoothstep(0.4, 0.66, fbm2(xz * 0.28 + t * 0.02));
	float lace = v_swash_edge * smoothstep(0.3, 0.9, ph) * net * breakup * v_beach * 0.7 * (1.0 - smoothstep(25.0, 60.0, v_dist));
	// Impact foam around rocky coast, pulsing with the swash.
	float rock_foam = v_rock * (1.0 - smoothstep(0.0, 1.6, ground_depth)) * (0.4 + 0.6 * swash_env(fract(ph + 0.15))) * smoothstep(0.35, 0.7, fn);
	// Occasional open-water crest flecks: lace on the highest crests, more
	// of it as the wind and sea get up (none on a glassy calm).
	float wind_sea = clamp(0.25 + wind_strength * 0.6 + sea_state, 0.0, 1.0);
	float flecks = smoothstep(0.7, 1.0, v_crest) * foam_lace(xz * 0.7, t, 0.15 + 0.45 * wind_sea) * wind_sea * 0.7 * (1.0 - smoothstep(200.0, 500.0, v_dist));
	// Whitecaps where the swell crests compress (Jacobian foam).
	float whitecap = (1.0 - smoothstep(0.62 + 0.22 * sea_state, 0.8 + 0.15 * sea_state, v_jac)) * smoothstep(0.35 - 0.2 * sea_state, 0.7, fn * 0.7 + fn2 * 0.5) * (1.0 - smoothstep(300.0, 900.0, v_dist));
	flecks = max(flecks, whitecap);
	float shore_lace = foam_lace(xz, t, 0.35) * breaking * 0.85;
	// Contact foam where the sea meets rocks, the dock posts or a hull (from
	// the depth buffer; beaches keep their swash foam above instead).
	float contact = 0.0;
	float contact_shadow = 0.0;
	vec3 under = scene_world_at(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float vthick0 = v_wpos.y - under.y;
	if (vthick0 < contact_foam_width && v_dist < 160.0) {
		float cw = contact_foam_width * (1.0 - 0.75 * v_beach);
		contact = contact_foam_at(xz, t, vthick0, cw) * contact_foam_amount * (1.0 - smoothstep(90.0, 160.0, v_dist));
		vec2 so = (length(sun_dir_world.xz) > 1e-3 ? normalize(sun_dir_world.xz) : vec2(0.0, 1.0)) * 0.09;
		contact_shadow = max(contact_foam_at(xz + so, t, vthick0, cw) * contact_foam_amount - contact, 0.0);
	}
	float foam = clamp(edge_foam * 1.2 + shore_lace + lace * 0.8 + rock_foam + flecks, 0.0, 1.0);
	foam = foam_cel(max(foam, contact));

	// --- Optics -----------------------------------------------------------
	vec3 n_view = normalize(mix(NORMAL, normalize(TANGENT * nmap.x + BINORMAL * nmap.y + NORMAL * nmap.z), 1.0));
	vec2 uv_seen;
	vec4 refr = refracted_scene(SCREEN_UV, VERTEX, n_view, INV_PROJECTION_MATRIX, 1.0, uv_seen);
	float vthick = v_wpos.y - scene_world_at(uv_seen, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX).y;
	vec3 body = stylized_body(refr.rgb, refr.a, vthick);
	// Darker rim just outside foam (foam edge shadow on the water body).
	body *= 1.0 - 0.35 * contact_shadow;
	float ndv = clamp(dot(n_view, VIEW), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	vec3 foam_col = vec3(0.92, 0.95, 0.95);
	// Crest translucency: looking toward the sun through a raised wave.
	vec3 sun_v = normalize((VIEW_MATRIX * vec4(sun_dir_world, 0.0)).xyz);
	float back = pow(clamp(dot(-VIEW, sun_v), 0.0, 1.0), 4.0);
	float crest_lit = back * smoothstep(0.25, 0.9, v_crest) * daylight * sun_clarity * (1.0 - smoothstep(250.0, 700.0, v_dist));
	float spark = sun_sparkle(n_view, VIEW, VIEW_MATRIX, xz, t) * (1.0 - smoothstep(60.0, 220.0, v_dist));

	ALBEDO = mix(scatter_color * 0.15, foam_col, foam);
	EMISSION = (body * (1.0 - fres) + crest_glow * crest_lit * 0.55) * (1.0 - foam) + vec3(spark * 3.0);
	ROUGHNESS = mix(glint_roughness, 0.85, foam);
	// Stylized: a little less mirror so the turquoise body reads (HD-2D water).
	SPECULAR = 0.4 * (1.0 - foam);
	METALLIC = 0.0;
	// Soft contact where water meets sand/rock: no hard intersection line.
	ALPHA = clamp(refr.a * 30.0 + foam, 0.0, 1.0) * smoothstep(0.0, 0.015, thin + 0.01);
}
