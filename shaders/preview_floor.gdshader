shader_type spatial;

// Neutral stage floor with a 1 m / 10 cm grid for judging scale and stride.
varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p, float w) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
	return 1.0 - min(min(g.x, g.y) / w, 1.0);
}

void fragment() {
	float major = grid(v_wpos.xz, 1.2);
	float minor = grid(v_wpos.xz * 10.0, 0.8) * 0.35;
	float fade = 1.0 - smoothstep(4.0, 12.0, length(v_wpos.xz));
	ALBEDO = mix(vec3(0.42, 0.4, 0.36), vec3(0.2, 0.19, 0.17), max(major, minor) * fade);
	ROUGHNESS = 0.9;
}
