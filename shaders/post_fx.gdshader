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
// Phase 24 HD-2D world pass (0 = off): the 3D frame is snapped to a pixel
// grid of `pixel_px` screen pixels per art pixel (each art pixel is the
// average of its block), lightly palette-clustered with an ordered dither
// on the block grid, given a 1-pixel contour where neighbouring art pixels
// differ strongly, and a small saturation lift. UI sits above and stays crisp.
uniform float pixel_px = 0.0;
uniform float palette_levels = 32.0;
uniform float dither = 0.0;          // clean flat palette steps (no noise)
uniform float outline_strength = 0.45;
uniform float saturation = 1.08;
global uniform float world_time;

vec3 block_col(vec2 cell, vec2 res) {
	vec2 uv = (cell + 0.5) * pixel_px / res;
	// The 3D frame is rendered at exactly 1/pixel_px resolution, so a block
	// centre lands on a rendered texel centre: point-exact, crisp.
	return textureLod(screen_tex, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).rgb;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	vec3 col;
	if (pixel_px >= 1.5) {
		vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
		vec2 cell = floor(uv * res / pixel_px);
		vec3 c0 = block_col(cell, res);
		// Contour: darken this art pixel where a neighbour is much brighter
		// (the darker side of an edge carries the line, like hand pixel art).
		float l0 = luma(c0);
		float edge = 0.0;
		for (int k = 0; k < 4; k++) {
			vec2 d = k == 0 ? vec2(1.0, 0.0) : (k == 1 ? vec2(-1.0, 0.0) : (k == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));
			float ln = luma(block_col(cell + d, res));
			edge = max(edge, smoothstep(0.08, 0.22, ln - l0));
		}
		c0 *= 1.0 - edge * outline_strength;
		// Saturation lift, then clustered levels with a 4x4 ordered dither.
		c0 = mix(vec3(luma(c0)), c0, saturation);
		int bx = int(mod(cell.x, 4.0));
		int by = int(mod(cell.y, 4.0));
		int bi = bx + by * 4;
		float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		float dth = (bayer[bi] / 16.0 - 0.47) / palette_levels * dither;
		vec3 enc = sqrt(max(c0, vec3(0.0)));              // cluster in a perceptual space
		enc = floor((enc + dth) * palette_levels + 0.5) / palette_levels;
		col = enc * enc;
		uv = (cell + 0.5) * pixel_px / res;               // grade/vignette per art pixel
		c = uv - 0.5;
		r2 = dot(c, c);
	} else if (chromatic > 0.001) {
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
