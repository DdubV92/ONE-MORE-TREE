shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Phase 24 "drawn world" pass (art direction: docs/art/reference_target.png).
// A full-screen quad in the 3D scene, drawn after the opaque world and
// before water and other transparents. It repaints the lit 3D frame as an
// illustration:
//   1. paint  - an edge-preserving brush filter (Kuwahara) melts texture
//               noise into flat, brush-sized colour fills;
//   2. tones  - light is gathered into a few soft tone steps, shadows lean
//               cool and stay colourful (never grey or black);
//   3. ink    - dark, colour-tinted contour lines where depth or surface
//               direction breaks (silhouettes, creases, object edges),
//               thinning out with distance.
// Pixel-art actors mark themselves with ROUGHNESS = 0 and are left exactly
// as drawn, so sprites stay crisp inside the painted world.

global uniform float daylight;      // 1 by day .. 0 in deep night
global uniform float world_time;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;

uniform float amount = 1.0;            // 0 = untouched frame
// "Drawn" pixel world: the frame is rendered on the art-pixel grid, so the
// pass steps in whole render pixels, lines are one firm pixel, and shadows
// take pencil hatching. The hatch is anchored to the view direction, so it
// turns with the world instead of sticking to the glass.
uniform float pixel_mode = 0.0;
uniform float hatch = 0.0;             // 0..1 strength of shadow hatching
uniform float boil = 0.0;              // 0..1 hand-drawn wobble of the lines
uniform float hatch_shade = 0.1;       // tone below which shade is hatched one way
uniform float hatch_deep = 0.05;       // tone below which it is cross-hatched
uniform int brush_radius = 3;          // 2 (fast) .. 4 (broad strokes)
uniform float brush_px = 1.0;          // brush step in pixels at 720p
uniform float detail = 0.3;            // share of the original surface detail kept under the paint
uniform float tone_steps = 5.0;
uniform float tone_strength = 0.55;
uniform float tone_soft = 0.16;        // width of the blend between steps
uniform float tone_bias = 0.64;        // where a step sits in its band (0.5 centre; higher keeps shadows open)
uniform vec3 shadow_tint : source_color = vec3(0.78, 0.84, 1.0);
uniform float saturation = 1.12;
uniform vec3 shadow_lift = vec3(0.01, 0.011, 0.016);
uniform float ink_strength = 0.85;
uniform float ink_px = 1.25;           // line half-width in pixels at 720p
uniform float ink_depth = 0.045;       // relative depth break that draws a line
uniform float ink_normal = 0.65;       // surface-direction break that draws a line
uniform float ink_far = 170.0;         // metres where lines have faded out

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return min(-p.z / p.w, 6000.0);
}

vec3 squash(vec3 c) {
	return c / (1.0 + c);
}

vec3 unsquash(vec3 c) {
	return c / max(vec3(1.0) - c, vec3(0.02));
}

float foliage(float rough) {
	return step(0.02, rough) * step(rough, 0.065);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Edge-preserving brush: of the four quadrants around the pixel, keep the
// mean of the calmest one. Works in a compressed range so bright sky or
// lamps do not dominate.
vec3 brush(vec2 uv, vec2 px) {
	vec3 m0 = vec3(0.0), m1 = vec3(0.0), m2 = vec3(0.0), m3 = vec3(0.0);
	vec3 s0 = vec3(0.0), s1 = vec3(0.0), s2 = vec3(0.0), s3 = vec3(0.0);
	int r = clamp(brush_radius, 1, 4);
	for (int j = -r; j <= r; j++) {
		for (int i = -r; i <= r; i++) {
			vec3 c = squash(textureLod(screen_tex, uv + vec2(float(i), float(j)) * px, 0.0).rgb);
			vec3 cc = c * c;
			if (i <= 0 && j <= 0) { m0 += c; s0 += cc; }
			if (i >= 0 && j <= 0) { m1 += c; s1 += cc; }
			if (i <= 0 && j >= 0) { m2 += c; s2 += cc; }
			if (i >= 0 && j >= 0) { m3 += c; s3 += cc; }
		}
	}
	float n = float((r + 1) * (r + 1));
	m0 /= n; m1 /= n; m2 /= n; m3 /= n;
	float v0 = luma(abs(s0 / n - m0 * m0));
	float v1 = luma(abs(s1 / n - m1 * m1));
	float v2 = luma(abs(s2 / n - m2 * m2));
	float v3 = luma(abs(s3 / n - m3 * m3));
	vec3 best = m0;
	float bv = v0;
	if (v1 < bv) { bv = v1; best = m1; }
	if (v2 < bv) { bv = v2; best = m2; }
	if (v3 < bv) { bv = v3; best = m3; }
	return best;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 src = textureLod(screen_tex, uv, 0.0).rgb;
	vec4 nr = texture(nr_tex, uv);
	float d_here = lin_depth(uv, INV_PROJECTION_MATRIX);
	// Pixel-art actors (ROUGHNESS 0 marker): leave exactly as drawn.
	bool sprite = nr.a < 0.012 && d_here < 5900.0;
	if (amount < 0.001 || sprite) {
		ALBEDO = src;
	} else {
		bool pix = pixel_mode > 0.5;
		vec2 rsize = vec2(textureSize(depth_tex, 0));
		float k = VIEWPORT_SIZE.y / 720.0;
		vec2 px = pix ? 1.0 / rsize : k / VIEWPORT_SIZE;
		// Pattern grid that turns with the camera (whole art pixels).
		vec3 fwd = -INV_VIEW_MATRIX[2].xyz;
		float focal = PROJECTION_MATRIX[1][1] * 0.5 * rsize.y;
		vec2 cell = floor(uv * rsize) + floor(vec2(atan(fwd.x, -fwd.z), -asin(clamp(fwd.y, -1.0, 1.0))) * focal);
		// 1. Paint.
		vec3 p = mix(brush(uv, px * brush_px), squash(src), detail);
		// 2. Tones (on the compressed 0..1 range).
		float l = max(luma(p), 1e-4);
		float x = l * tone_steps;
		float f = fract(x);
		// Steps sit at band centres (0.5, 1.5, ...) and blend at the band
		// edges, so darks are gathered upward instead of crushed to black.
		float y = x - 0.5;
		float stepped = max(floor(y) + smoothstep(0.5 - tone_soft, 0.5 + tone_soft, fract(y)) + tone_bias, 0.0) / tone_steps;
		stepped = mix(l, stepped, smoothstep(0.0, 0.07, l));   // deep night stays as lit
		bool sky_px = d_here > 5900.0;
		// Night keeps its own darkness (horror nights must not be flattened
		// or lifted): tone steps and the shadow lift follow daylight.
		float day_k = mix(0.25, 1.0, daylight);
		float lq = mix(l, stepped, tone_strength * (sky_px ? 0.35 : 1.0) * day_k);
		p *= lq / l;
		// Readable, colourful shadows (the reference keeps detail in the dark).
		p += shadow_lift * (1.0 - smoothstep(0.0, 0.3, lq)) * (sky_px ? 0.0 : 1.0) * daylight * smoothstep(0.004, 0.03, l);
		// Cool, colourful shadows; a little more chroma overall.
		float sh = 1.0 - smoothstep(0.06, 0.38, lq);
		p *= mix(vec3(1.0), shadow_tint, sh * 0.45);
		p = mix(vec3(luma(p)), p, saturation + 0.1 * sh);
		p = clamp(p, vec3(0.0), vec3(0.985));
		vec3 painted = unsquash(p);
		// 3. Ink: Roberts cross on linear depth and on view normals.
		vec2 o = px * ink_px * mix(1.0, 0.6, smoothstep(25.0, 90.0, d_here));
		if (pix) {
			// One art pixel, nudged a little a few times a second: the line
			// is redrawn, like a pencil test.
			float tick = floor(world_time * 5.0);
			o = px * ink_px * (1.0 + boil * 0.7 * (hash21(cell * 0.37 + tick) - 0.5));
		}
		float d0 = lin_depth(uv - o, INV_PROJECTION_MATRIX);
		float d1 = lin_depth(uv + o, INV_PROJECTION_MATRIX);
		float d2 = lin_depth(uv + vec2(-o.x, o.y), INV_PROJECTION_MATRIX);
		float d3 = lin_depth(uv + vec2(o.x, -o.y), INV_PROJECTION_MATRIX);
		float dmin = min(min(d0, d1), min(d2, d3));
		float dd = sqrt((d1 - d0) * (d1 - d0) + (d3 - d2) * (d3 - d2));
		vec3 n = nr.xyz * 2.0 - 1.0;
		vec4 vp = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
		vec3 vdir = normalize(vp.xyz / vp.w);
		// Surfaces seen edge-on change depth fast without being an edge.
		float graze = 1.0 - clamp(abs(dot(n, -vdir)), 0.0, 1.0);
		vec4 q0 = texture(nr_tex, uv - o);
		vec4 q1 = texture(nr_tex, uv + o);
		vec4 q2 = texture(nr_tex, uv + vec2(-o.x, o.y));
		vec4 q3 = texture(nr_tex, uv + vec2(o.x, -o.y));
		// Foliage marker (ROUGHNESS 0.04): only a silhouette line where the
		// crown stands well clear of what is behind it.
		float soft = max(max(foliage(nr.a), foliage(q0.a)), max(max(foliage(q1.a), foliage(q2.a)), foliage(q3.a)));
		float thr = ink_depth * mix(1.0, 6.0, soft) * dmin * (1.0 + 7.0 * smoothstep(0.55, 1.0, graze));
		float e_depth = smoothstep(thr, thr * 1.8, dd);
		vec3 n0 = q0.xyz;
		vec3 n1 = q1.xyz;
		vec3 n2 = q2.xyz;
		vec3 n3 = q3.xyz;
		float nd = sqrt(dot(n1 - n0, n1 - n0) + dot(n3 - n2, n3 - n2)) * 2.0;
		float e_norm = smoothstep(ink_normal, ink_normal * 1.6, nd) * (1.0 - smoothstep(18.0, 55.0, dmin)) * step(dmin, 5900.0) * (1.0 - soft);
		if (pix) {
			// On the art-pixel grid every plank edge would be a line and near
			// objects would fill with ink: keep creases for close, strong ones.
			e_norm *= smoothstep(ink_normal * 1.5, ink_normal * 2.2, nd) * (1.0 - smoothstep(8.0, 22.0, dmin));
		}
		float edge = max(e_depth, e_norm * 0.8) * (1.0 - smoothstep(ink_far * 0.35, ink_far, dmin));
		// Colour-tinted line (dark version of the paint under it, warm-violet).
		vec3 line = painted * vec3(0.2, 0.15, 0.19) + vec3(0.004, 0.002, 0.004);
		if (pix) {
			// Pencil hatching in the shadows: one direction in shade, crossed
			// in deep shade. Never on the sky, faint at night.
			float hk = hatch * (sky_px ? 0.0 : 1.0) * mix(0.35, 1.0, daylight);
			// Strokes, not a lattice: each line is broken into short pencil
			// marks with gaps.
			float u1 = cell.x + cell.y;
			float v1 = cell.x - cell.y;
			float h1 = step(mod(u1, 5.0), 0.5) * step(0.22, hash21(vec2(floor(u1 / 5.0), floor(v1 / 9.0))));
			float h2 = step(mod(v1, 5.0), 0.5) * step(0.22, hash21(vec2(floor(v1 / 5.0) + 31.0, floor(u1 / 9.0))));
			// In low light everything is dark: the tones that count as shade
			// fall with the daylight, so dusk is not hatched all over.
			float dk = mix(0.25, 1.0, daylight * daylight);
			float in_shade = 1.0 - step(hatch_shade * dk, lq);
			float in_deep = 1.0 - step(hatch_deep * dk, lq);
			float hm = max(h1 * in_shade, h2 * in_deep) * smoothstep(0.01, 0.05, l);
			painted *= 1.0 - 0.34 * hm * hk * (1.0 - smoothstep(60.0, 140.0, d_here));
			edge = step(0.45, edge);                       // a firm line, not a soft one
			line = painted * vec3(0.2, 0.15, 0.21) + vec3(0.003, 0.002, 0.004);
		}
		vec3 outc = mix(painted, line, edge * ink_strength);
		ALBEDO = mix(src, outc, amount);
	}
}
