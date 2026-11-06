shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// Phase 23: window glass that beads up in rain. Readable both ways (low
// alpha, low reflectance, as the Phase 4 glass); with rain on the world,
// static beads gather and a few run down the pane. World-aligned so the
// pattern stays put on the glass when you move.
#include "res://shaders/include/world_common.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.75, 0.85, 0.88, 0.12);

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// Static beads: one per 1.6 cm cell where the hash allows.
vec3 beads(vec2 uv, float amount) {
	vec2 c = floor(uv * 62.0);
	vec2 f = fract(uv * 62.0) - 0.5;
	float r = h21(c);
	if (r > amount) return vec3(0.0);
	vec2 o = vec2(h21(c + 3.1), h21(c + 7.7)) - 0.5;
	float d = length(f - o * 0.5);
	float rad = 0.18 + 0.2 * h21(c + 1.7);
	float m = smoothstep(rad, rad * 0.55, d);
	return vec3((f - o * 0.5) * m * 2.0, m);
}

// Runnels: a few drops sliding down with a short trail.
float runnel(vec2 uv, float t) {
	float col = floor(uv.x * 9.0);
	float sp = 0.06 + 0.08 * h21(vec2(col, 1.0));
	float y = fract(uv.y * 0.8 + t * sp + h21(vec2(col, 2.0)));
	float x = fract(uv.x * 9.0) - 0.5 + 0.08 * sin(uv.y * 30.0 + col);
	float head = smoothstep(0.06, 0.0, length(vec2(x * 1.4, (y - 0.5) * 4.0)));
	float trail = smoothstep(0.03, 0.0, abs(x)) * smoothstep(0.5, 0.9, y) * 0.35;
	return max(head, trail) * step(0.55, h21(vec2(col, 3.0)));
}

void fragment() {
	// Plane-aligned coordinates on the pane (works for any wall direction).
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 uv = abs(n.x) > abs(n.z) ? vec2(v_wpos.z, v_wpos.y) : vec2(v_wpos.x, v_wpos.y);
	float amount = clamp(wetness * 0.55 + rain_amount * 0.25, 0.0, 0.7);
	vec3 b = beads(uv, amount);
	float run = rain_amount > 0.3 ? runnel(uv, world_time) * rain_amount : 0.0;
	float m = max(b.z, run);
	ALBEDO = tint.rgb;
	ALPHA = tint.a + m * 0.28;
	ROUGHNESS = mix(0.06, 0.02, m);
	SPECULAR = 0.25 + m * 0.4;
	NORMAL_MAP = normalize(vec3(b.xy * 1.6, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = m;
}
