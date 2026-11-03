shader_type spatial;
render_mode diffuse_burley;

// Bark of a log in the burn pit: darkens to char, then cracks into glowing
// ember seams as the logical fuel is consumed (driven by TimberService).
uniform sampler2D bark_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 bark_tint : source_color = vec3(1.0);
uniform float char_amount = 0.0;   // 0 fresh .. 1 fully charred
uniform float glow = 0.0;          // 0..1 ember seams
uniform float time_offset = 0.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 bark = texture(bark_tex, UV).rgb * bark_tint;
	float n = vnoise(UV * vec2(9.0, 5.0));
	float c = smoothstep(0.0, 1.0, char_amount * 1.3 - n * 0.3);
	vec3 charred = vec3(0.035, 0.03, 0.028) + vec3(0.03) * n;
	ALBEDO = mix(bark, charred, c);
	ROUGHNESS = mix(0.9, 0.97, c);
	// Ember seams: crack network from ridged noise, flickering slowly.
	float cr = 1.0 - abs(vnoise(UV * vec2(14.0, 7.0)) * 2.0 - 1.0);
	float seam = smoothstep(0.86, 0.97, cr) * c;
	float flick = 0.75 + 0.25 * sin(TIME * 2.3 + time_offset + n * 6.0);
	EMISSION = vec3(1.0, 0.33, 0.07) * seam * glow * flick * 4.0;
}
