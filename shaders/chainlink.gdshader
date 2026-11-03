shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Galvanized chain-link mesh drawn procedurally on a quad (UV in meters).
// Alpha-scissored wires so the fence casts real lattice shadows.

uniform float cell = 0.06;
uniform float wire = 0.0045;
uniform vec3 color : source_color = vec3(0.62, 0.64, 0.66);

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV;
	// Diamond lattice: two diagonal families of wires.
	vec2 d = vec2(p.x + p.y, p.x - p.y) / (cell * 1.4142);
	vec2 f = abs(fract(d) - 0.5) * cell * 1.4142;
	float w = min(f.x, f.y);
	float aa = fwidth(w) * 0.75;
	float a = 1.0 - smoothstep(wire - aa, wire + aa, w);
	// Fade the lattice to a light veil at distance instead of shimmering.
	float dist = length(v_wpos - CAMERA_POSITION_WORLD);
	a = mix(a, 0.35, smoothstep(12.0, 40.0, dist));
	if (a < 0.5) discard;
	ALBEDO = color;
	METALLIC = 0.85;
	ROUGHNESS = 0.4;
}
