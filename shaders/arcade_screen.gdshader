shader_type spatial;
render_mode unshaded, cull_back;

// Attract-mode loops for the two cabin arcade cabinets (placeholder art).
// game 0 "Log Roller": a log tumbling over scrolling hills.
// game 1 "Beaver Bonk": bouncing beaver heads in a grid.

#include "res://shaders/include/world_common.gdshaderinc"

uniform int game = 0;

float box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = world_time;
	vec3 col;
	if (game == 0) {
		col = mix(vec3(0.1, 0.15, 0.35), vec3(0.45, 0.65, 0.95), uv.y);
		float hill = 0.3 + 0.08 * sin(uv.x * 9.0 + t * 1.5) + 0.04 * sin(uv.x * 23.0 + t * 3.0);
		col = mix(col, vec3(0.2, 0.55, 0.2), step(uv.y, hill));
		vec2 lp = uv - vec2(0.5, hill + 0.07 + 0.04 * abs(sin(t * 4.0)));
		float a = t * 5.0;
		lp = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * lp;
		col = mix(col, vec3(0.55, 0.32, 0.15), step(box(lp, vec2(0.09, 0.035)), 0.0));
		col = mix(col, vec3(0.85, 0.7, 0.45), step(length(lp - vec2(0.09, 0.0)), 0.03));
	} else {
		col = vec3(0.05, 0.25, 0.1);
		vec2 g = fract(uv * vec2(3.0, 2.0)) - 0.5;
		vec2 id = floor(uv * vec2(3.0, 2.0));
		float up = step(0.6, fract(sin(dot(id, vec2(12.9, 78.2)) + floor(t * 1.5)) * 43758.5));
		col = mix(col, vec3(0.02), step(length(g * vec2(1.0, 1.6)), 0.3));
		float head = step(length((g - vec2(0.0, -0.05 + 0.1 * up)) * vec2(1.0, 1.2)), 0.22 * up);
		col = mix(col, vec3(0.5, 0.3, 0.15), head);
	}
	// Scanlines and a soft vignette
	col *= 0.85 + 0.15 * sin(UV.y * 300.0);
	col *= 1.0 - 0.6 * pow(length(UV - 0.5), 2.0);
	ALBEDO = col * 1.6;
}
