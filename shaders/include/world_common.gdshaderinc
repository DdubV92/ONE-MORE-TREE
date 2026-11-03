// Shared world facts for every outdoor shader: wind, time, sea level, sun,
// shoreline swash and caustics. Keep CPU mirrors in scripts/water/water_service.gd
// in sync with the swash functions below.

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float world_time;
global uniform float sea_level;
global uniform vec3 sun_dir_world;
global uniform float daylight;
global uniform float haze_strength;

float global_haze_level() {
	return haze_strength;
}

const float SWASH_PERIOD = 9.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
	return vnoise(p) * 0.6 + vnoise(p * 2.13 + 7.1) * 0.3 + vnoise(p * 4.37 - 3.3) * 0.1;
}

// Swash phase in [0,1): 0 = wave arrives, ~0.28 = maximum run-up, then backwash.
float swash_phase(vec2 xz, float t) {
	return fract(t / SWASH_PERIOD + vnoise(xz * 0.011) * 0.7 + xz.x * 0.0012);
}

float swash_env(float ph) {
	float up = smoothstep(0.0, 0.28, ph);
	float down = 1.0 - smoothstep(0.28, 0.95, ph);
	return up * down;
}

// Water level reached by the swash at this point (world meters).
float swash_level(vec2 xz, float t, float beach) {
	float runup = mix(0.14, 0.66, beach);
	return sea_level - 0.06 + runup * swash_env(swash_phase(xz, t));
}

// Wetness of terrain at height h: recently washed sand stays wet and dries over ~6 s.
float swash_wetness(vec2 xz, float t, float h, float beach) {
	float wet = 0.0;
	for (int k = 0; k < 5; k++) {
		float lag = float(k) * 1.6;
		float lvl = swash_level(xz, t - lag, beach);
		wet = max(wet, smoothstep(h - 0.02, h + 0.03, lvl) * (1.0 - float(k) * 0.17));
	}
	// Permanently damp band just above the mean water line.
	wet = max(wet, (1.0 - smoothstep(sea_level + 0.05, sea_level + 0.65, h)) * 0.55);
	return wet;
}

// Animated caustic network (two warped cellular layers).
float caustic_layer(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.3));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return pow(clamp(1.0 - (d2 - d1) * 2.2, 0.0, 1.0), 6.0);
}

float caustics(vec2 xz, float t) {
	vec2 w = vec2(vnoise(xz * 0.35 + t * 0.15), vnoise(xz * 0.35 - t * 0.12 + 5.0)) * 0.9;
	float a = caustic_layer(xz * 0.85 + w + vec2(t * 0.11, t * 0.07));
	float b = caustic_layer(xz * 1.13 - w + vec2(-t * 0.09, t * 0.12) + 3.7);
	return min(a, b) * 1.6 + (a + b) * 0.12;
}

// Distance between the nearest two cell points (0 on cell borders).
float voronoi_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.3));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

// Sea foam: wandering ridged-noise bubble lines plus soft patches (organic,
// never a regular mosaic). coverage 0..1 (1 = fresh whitewater, small =
// lace left behind).
float ridge(vec2 p) {
	return 1.0 - abs(vnoise(p) * 2.0 - 1.0);
}

float foam_lace(vec2 xz, float t, float coverage) {
	vec2 w = vec2(fbm2(xz * 0.18 + t * 0.04), fbm2(xz * 0.18 + 9.0 - t * 0.035)) * 4.0;
	vec2 q = xz * 1.1 + w;
	float r = ridge(q) * 0.6 + ridge(q * 2.1 + 3.7) * 0.3 + ridge(q * 4.3 - 1.9) * 0.1;
	float thr = mix(0.93, 0.72, coverage);
	float web = smoothstep(thr, thr + 0.05, r);
	float mask = smoothstep(0.55 - coverage * 0.5, 0.8 - coverage * 0.4, fbm2(xz * 0.4 + w * 0.3));
	float patch = smoothstep(1.02 - coverage, 1.32 - coverage, fbm2(xz * 0.65 - w * 0.25) + 0.12 * vnoise(xz * 3.3));
	return clamp(max(web * mask, patch), 0.0, 1.0);
}
