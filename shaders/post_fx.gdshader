shader_type canvas_item;

// Final-frame grade drawn under the UI: independently adjustable chromatic
// aberration (default 0), vignette, warm/cool grading and optional grain.
// Effects scale toward the frame edges; the screen centre (crosshair, tools,
// interaction targets) is never displaced.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float chromatic = 0.0;
uniform float vignette = 0.22;
uniform float warmth = 0.0;
uniform float grade = 1.0;
uniform float grain = 0.0;
global uniform float world_time;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	vec3 col;
	if (chromatic > 0.001) {
		vec2 off = c * r2 * chromatic * 0.025;
		col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	// Warm / cool split-tone (lifts shadows slightly cool, highlights warm).
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 warm = vec3(1.0 + 0.06 * warmth, 1.0 + 0.01 * warmth, 1.0 - 0.07 * warmth);
	vec3 cool_shadow = vec3(0.985, 1.0, 1.02);
	col *= mix(cool_shadow, warm, smoothstep(0.1, 0.7, lum)) * grade + vec3(1.0) * (1.0 - grade);
	col *= 1.0 - vignette * smoothstep(0.08, 0.55, r2 * 1.6);
	if (grain > 0.001) {
		float n = fract(sin(dot(uv * 1000.0 + world_time, vec2(12.9898, 78.233))) * 43758.5453);
		col += (n - 0.5) * 0.06 * grain;
	}
	COLOR = vec4(col, 1.0);
}
