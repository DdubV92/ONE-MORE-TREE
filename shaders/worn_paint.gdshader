shader_type spatial;
render_mode cull_back;

// Phase 24 reference fixture: weathered painted sheet metal (the cream and
// rust trailer). Base paint, a rust colour that blooms up from the lower
// edge and around seams, chipped paint flecks and vertical grime streaks -
// all in object space so the wear stays put as the player walks round it.

uniform vec3 paint : source_color = vec3(0.88, 0.82, 0.68);
uniform vec3 rust : source_color = vec3(0.52, 0.2, 0.1);
uniform vec3 grime : source_color = vec3(0.3, 0.24, 0.18);
uniform float wear = 0.5;
uniform float rust_line = 0.35;      // object-space height below which rust blooms
uniform float panel = 0.55;          // vertical panel seam spacing (m)

varying vec3 v_obj;
varying vec3 v_n;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	return vn(p) * 0.5 + vn(p * 2.1) * 0.3 + vn(p * 4.3) * 0.2;
}

void vertex() {
	v_obj = VERTEX;
	v_n = NORMAL;
}

void fragment() {
	vec2 uv = abs(v_n.x) > 0.5 ? v_obj.zy : (abs(v_n.y) > 0.5 ? v_obj.xz : v_obj.xy);
	float n1 = fbm(uv * 3.0);
	float n2 = fbm(uv * 11.0 + 7.0);
	// Panel seams with rust weeping down from rivet lines.
	float seam = 1.0 - smoothstep(0.0, 0.025, abs(fract(uv.x / panel) - 0.5) * panel * 2.0 - panel + 0.05);
	float weep = seam * smoothstep(0.4, 0.9, n2) * 0.6;
	float low = 1.0 - smoothstep(rust_line - 0.25, rust_line + 0.25, v_obj.y + (n1 - 0.5) * 0.5);
	float rusty = clamp(max(low * smoothstep(0.35, 0.65, n1 + wear * 0.3), weep), 0.0, 1.0);
	// Chipped paint flecks and vertical grime streaks.
	float chip = smoothstep(0.86 - wear * 0.08, 0.9 - wear * 0.08, n2) * smoothstep(0.2, 0.8, n1);
	float streak = smoothstep(0.55, 0.9, vn(vec2(uv.x * 9.0, uv.y * 0.6))) * 0.35 * wear;
	vec3 col = paint * (0.95 + 0.07 * n1);
	col = mix(col, grime, streak);
	col = mix(col, rust * (0.8 + 0.4 * n2), max(rusty, chip * 0.8));
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.9, max(rusty, chip));
	METALLIC = mix(0.15, 0.0, rusty);
	SPECULAR = 0.4;
}
