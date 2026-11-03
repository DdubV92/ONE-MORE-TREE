shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// GPU-displaced terrain chunk. Heights come from the same frozen height field
// the CPU elevation service uses (World.height_at), fetched exactly at grid
// vertices, so rendering and physics share one world.

#include "res://shaders/include/world_common.gdshaderinc"

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D masks : filter_linear_mipmap, repeat_disable;
uniform sampler2D water_map : filter_nearest, repeat_disable;
uniform sampler2D water_region_map : filter_nearest, repeat_disable;
uniform vec2 grid_origin;
uniform float cell_size = 2.0;
uniform ivec2 grid_dims;
uniform float lod_step = 1.0;
uniform float skirt_depth = 3.0;

uniform sampler2DArray albedo_array : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_array : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray arm_array : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 0.9;
uniform float caustic_strength = 1.0;

varying vec3 v_wpos;
varying vec3 v_wnormal;

// Layer contract (tools/bake_terrain_arrays.py)
const int L_SAND = 0;
const int L_DAMP = 1;
const int L_GRASS = 2;
const int L_SPARSE = 3;
const int L_NEEDLES = 4;
const int L_LITTER = 5;
const int L_DIRT = 6;
const int L_MOSSROCK = 7;
const int L_ROCK = 8;
const int L_GRAVEL = 9;
const int L_PEBBLES = 10;
const int L_MUD = 11;
const int LAYERS = 12;

float fetch_h(ivec2 c) {
	return texelFetch(heightmap, clamp(c, ivec2(0), grid_dims - 1), 0).r;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ivec2 tc = ivec2(round((wp.xz - grid_origin) / cell_size));
	float h = fetch_h(tc);
	int s = int(lod_step);
	float hl = fetch_h(tc - ivec2(s, 0));
	float hr = fetch_h(tc + ivec2(s, 0));
	float hd = fetch_h(tc - ivec2(0, s));
	float hu = fetch_h(tc + ivec2(0, s));
	vec3 n = normalize(vec3(hl - hr, 2.0 * lod_step * cell_size, hd - hu));
	VERTEX.y = h - COLOR.r * skirt_depth;
	NORMAL = n;
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - n * n.x);
	BINORMAL = normalize(cross(n, TANGENT)) * -1.0;
	v_wnormal = n;
	v_wpos = vec3(wp.x, VERTEX.y, wp.z);
}

float layer_scale(int l) {
	// Texture repeat size in meters per layer.
	if (l == L_SAND || l == L_DAMP) return 3.5;
	if (l == L_GRASS || l == L_SPARSE) return 3.0;
	if (l == L_NEEDLES || l == L_LITTER) return 3.0;
	if (l == L_DIRT) return 3.0;
	if (l == L_MOSSROCK || l == L_ROCK) return 5.0;
	if (l == L_PEBBLES) return 2.0;
	return 3.0;
}

vec3 layer_tint(int l) {
	// Grade photo-scanned layers into one coherent coastal-woodland palette.
	if (l == L_GRASS) return vec3(0.66, 0.84, 0.46);
	if (l == L_SPARSE) return vec3(0.74, 0.84, 0.54);
	if (l == L_NEEDLES) return vec3(0.66, 0.68, 0.52);
	if (l == L_LITTER) return vec3(0.66, 0.6, 0.52);
	if (l == L_DIRT) return vec3(0.92, 0.85, 0.78);
	if (l == L_SAND) return vec3(1.18, 1.12, 1.0);
	if (l == L_DAMP) return vec3(1.0, 0.97, 0.92);
	if (l == L_MOSSROCK) return vec3(0.95, 0.93, 0.86);
	if (l == L_ROCK) return vec3(0.9, 0.86, 0.82);
	return vec3(1.0);
}

float layer_desat(int l) {
	if (l == L_LITTER) return 0.4;
	if (l == L_MOSSROCK) return 0.35;
	if (l == L_NEEDLES) return 0.2;
	return 0.0;
}

void fragment() {
	vec2 xz = v_wpos.xz;
	vec2 guv = (xz - grid_origin) / (cell_size * vec2(grid_dims - 1)) + 0.5 / vec2(grid_dims);
	vec4 m = texture(masks, guv);
	float water_lvl = texture(water_map, guv).r;
	float region = texture(water_region_map, guv).r * 255.0;
	float h = v_wpos.y;
	vec3 wn = normalize(v_wnormal);
	float slope = 1.0 - wn.y;
	float n1 = fbm2(xz * 0.045);
	float n2 = fbm2(xz * 0.21 + 3.0);
	float n3 = vnoise(xz * 0.9);

	float sand = m.r;
	float forest = m.g;
	float dirt = m.b;
	float rock = max(m.a, smoothstep(0.42, 0.62, slope + (n2 - 0.5) * 0.15));
	bool inland_water = region > 0.5;
	float under_water = step(h, water_lvl - 0.02);

	float w[LAYERS];
	for (int i = 0; i < LAYERS; i++) { w[i] = 0.0; }

	float beachiness = sand;
	float wet = 0.0;
	if (!inland_water) {
		wet = swash_wetness(xz, world_time, h, beachiness) * step(h, 1.6);
	}

	float ground = (1.0 - sand) * (1.0 - dirt) * (1.0 - rock);
	float grassy = ground * (1.0 - forest);
	w[L_GRASS] = grassy * smoothstep(0.25, 0.75, n1 + 0.15);
	w[L_SPARSE] = grassy * (1.0 - smoothstep(0.25, 0.75, n1 + 0.15)) + ground * forest * 0.15 * n2;
	float broadleaf = smoothstep(0.45, 0.7, fbm2(xz * 0.012 + 11.0));
	w[L_NEEDLES] = ground * forest * (1.0 - broadleaf);
	w[L_LITTER] = ground * forest * broadleaf;
	w[L_DIRT] = dirt * (1.0 - rock * 0.5);
	float moss = clamp(forest * 1.2 + smoothstep(25.0, 10.0, h) * 0.3, 0.0, 1.0) * smoothstep(0.75, 0.45, slope);
	w[L_MOSSROCK] = rock * mix(0.35, 1.0, moss);
	w[L_ROCK] = rock * (1.0 - mix(0.35, 1.0, moss));
	float coast_rock = m.a * (1.0 - smoothstep(0.5, 3.5, h));
	w[L_GRAVEL] = coast_rock * 1.5 + sand * smoothstep(0.55, 0.8, n2) * (1.0 - smoothstep(-0.5, 1.2, h)) * 0.6;
	w[L_SAND] = sand * (1.0 - wet);
	w[L_DAMP] = sand * wet + (1.0 - sand) * wet * 0.4;
	if (inland_water) {
		float bank = 1.0 - smoothstep(water_lvl + 0.1, water_lvl + 0.7, h);
		if (region < 1.5) {
			w[L_PEBBLES] += bank * 2.0;
		} else {
			w[L_MUD] += bank * 2.0;
		}
		wet = max(wet, (1.0 - smoothstep(water_lvl, water_lvl + 0.35, h)) * 0.8);
	}

	// Height-aware sharpening with per-layer noise; normalise.
	float total = 0.0;
	for (int i = 0; i < LAYERS; i++) {
		w[i] = pow(max(w[i], 0.0) * (0.75 + 0.5 * vnoise(xz * 0.31 + float(i) * 7.3)), 1.6);
		total += w[i];
	}
	if (total < 1e-4) { w[L_SPARSE] = 1.0; total = 1.0; }

	vec3 alb = vec3(0.0);
	vec3 nrm_ts = vec3(0.0);
	vec3 arm = vec3(0.0);
	float rot = n3 * 6.2831;
	mat2 r2 = mat2(vec2(cos(rot), sin(rot)), vec2(-sin(rot), cos(rot)));
	// Distance-aware sampling: close up two blended scales; mid distance a
	// 4x larger scale (kills tiling and moire); far away the layer's average
	// colour (top mip) so distant hills read as calm, varied colour fields.
	float dist = length(v_wpos - CAMERA_POSITION_WORLD);
	float far_k = smoothstep(30.0, 90.0, dist);
	float vfar_k = smoothstep(140.0, 420.0, dist);
	for (int i = 0; i < LAYERS; i++) {
		float wi = w[i] / total;
		if (wi < 0.02) continue;
		float sc = layer_scale(i);
		vec2 uv = xz / sc;
		vec2 dx = dFdx(uv);
		vec2 dy = dFdy(uv);
		vec3 col = vec3(0.0);
		if (vfar_k < 0.999) {
			vec3 a1 = textureGrad(albedo_array, vec3(uv, float(i)), dx, dy).rgb;
			vec2 uv2 = (r2 * uv) * 0.37 + 0.31;
			vec3 a2 = textureGrad(albedo_array, vec3(uv2, float(i)), dx * 0.37, dy * 0.37).rgb;
			col = mix(a1, a2, 0.35);
			if (far_k > 0.001) {
				vec2 uv3 = (r2 * uv) * 0.23 + 0.71;
				vec3 a3 = textureGrad(albedo_array, vec3(uv3, float(i)), dx * 0.23, dy * 0.23).rgb;
				col = mix(col, mix(a2, a3, 0.5), far_k);
			}
		}
		if (vfar_k > 0.001) {
			vec3 avg = textureLod(albedo_array, vec3(0.5, 0.5, float(i)), 12.0).rgb;
			col = mix(col, avg * mix(0.9, 1.1, n2), vfar_k);
		}
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(col, vec3(lum), layer_desat(i));
		alb += col * layer_tint(i) * wi;
		nrm_ts += (textureGrad(normal_array, vec3(uv, float(i)), dx, dy).rgb * 2.0 - 1.0) * wi * (1.0 - vfar_k);
		arm += textureGrad(arm_array, vec3(uv, float(i)), dx, dy).rgb * wi;
	}
	nrm_ts.z += vfar_k;
	// Meadow colour drift: lush green hollows, drier golden rises.
	float meadow = (w[L_GRASS] + w[L_SPARSE]) / total;
	float lush = fbm2(xz * 0.006 + 3.7);
	alb = mix(alb, alb * mix(vec3(1.06, 0.98, 0.82), vec3(0.82, 0.96, 0.8), lush), meadow * 0.55);
	// Macro variation: large-scale tone drift, canopy shade on forest floor.
	alb *= mix(0.86, 1.1, n1);
	alb *= mix(1.0, 0.82, forest * (1.0 - sand));
	// Pale the dry beach sand slightly toward a warm coastal tone.
	alb = mix(alb, alb * vec3(1.12, 1.06, 0.95), w[L_SAND] / total);

	// Wetness: darker, smoother, glossy right after the backwash.
	float fresh = 0.0;
	if (!inland_water && h < 1.2) {
		float lvl_now = swash_level(xz, world_time, beachiness);
		float lvl_prev = swash_level(xz, world_time - 1.2, beachiness);
		fresh = smoothstep(h - 0.01, h + 0.04, lvl_prev) * (1.0 - smoothstep(h - 0.01, h + 0.03, lvl_now));
	}
	alb *= mix(1.0, 0.58, wet);
	float rough = mix(clamp(arm.g, 0.35, 1.0), 0.12, wet * 0.75);
	rough = mix(rough, 0.04, fresh * sand);

	// Caustics on submerged ground (sea, river, ponds), sunlight-scaled.
	float depth = max(water_lvl - h, 0.0);
	vec3 emit = vec3(0.0);
	if (depth > 0.0) {
		float c = caustics(xz * 0.9, world_time) * caustic_strength;
		float att = exp(-depth * 0.32) * smoothstep(0.0, 0.25, depth);
		float sun_up = clamp(sun_dir_world.y * 2.5, 0.0, 1.0);
		emit = alb * c * att * sun_up * daylight * 1.4;
		alb *= mix(1.0, 0.85, smoothstep(0.0, 2.0, depth));
	}

	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = mix(0.4, 0.6, wet);
	AO = clamp(arm.r, 0.4, 1.0);
	AO_LIGHT_AFFECT = 0.3;
	vec3 nts = normalize(vec3(nrm_ts.xy * normal_strength * (1.0 - wet * 0.5), max(nrm_ts.z, 0.2)));
	NORMAL_MAP = nts * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	EMISSION = emit;
}
