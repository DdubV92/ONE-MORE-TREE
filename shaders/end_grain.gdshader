shader_type spatial;
render_mode diffuse_burley;

// Freshly cut end grain / exposed wood for timber pieces. UV is radial:
// length(UV - 0.5) * 2 = 0 at the pith, 1 at the bark.
uniform float char_amount = 0.0;      // 0 fresh .. 1 charred (burn pit)
uniform float glow = 0.0;             // ember glow in cracks

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5); }

void fragment() {
	vec2 q = UV - 0.5;
	float r = length(q) * 2.0;
	float wob = sin(atan(q.y, q.x) * 5.0) * 0.012;
	float rings = 0.5 + 0.5 * sin((r + wob) * 55.0);
	vec3 sap = vec3(0.86, 0.72, 0.5);
	vec3 heart = vec3(0.68, 0.48, 0.29);
	vec3 c = mix(heart, sap, smoothstep(0.35, 0.75, r));
	c *= 0.86 + 0.14 * rings;
	c = mix(c, vec3(0.32, 0.22, 0.14), smoothstep(0.93, 1.0, r));
	c *= 0.92 + 0.08 * h(floor(UV * 90.0));
	float n = h(floor(UV * 24.0));
	c = mix(c, vec3(0.04, 0.035, 0.03), smoothstep(0.0, 1.0, char_amount * (0.75 + 0.25 * n)));
	ALBEDO = c;
	ROUGHNESS = 0.85;
	EMISSION = vec3(1.0, 0.3, 0.06) * glow * step(0.72, n) * (0.5 + 0.5 * rings) * 3.0;
}
