shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Freshly cut wood: pale sapwood, darker heartwood, growth rings and a
// little saw/axe texture. Object-space radial coordinate.

uniform float radius = 0.3;
varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5); }

void fragment() {
	float r = length(v_local.xz) / max(radius, 0.01);
	float wob = sin(atan(v_local.z, v_local.x) * 5.0) * 0.012;
	float rings = 0.5 + 0.5 * sin((r + wob) * 70.0);
	vec3 sap = vec3(0.86, 0.72, 0.5);
	vec3 heart = vec3(0.7, 0.5, 0.3);
	vec3 c = mix(heart, sap, smoothstep(0.35, 0.75, r));
	c *= 0.88 + 0.12 * rings;
	c = mix(c, vec3(0.32, 0.22, 0.14), smoothstep(0.93, 1.0, r));   // bark rim
	c *= 0.92 + 0.08 * h(floor(v_local.xz * 120.0));
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
