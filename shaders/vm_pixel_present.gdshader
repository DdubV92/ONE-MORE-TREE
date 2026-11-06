shader_type canvas_item;
// Phase 24: presents the low-resolution first-person viewmodel render as
// crisp pixel art: nearest texels, a one-texel dark outline around the
// silhouette (like the painted sprites), and a gentle colour posterise.

uniform vec4 outline : source_color = vec4(0.11, 0.07, 0.05, 1.0);
uniform float levels = 22.0;
uniform float lift = 0.05;        // keeps backlit tools readable at golden hour

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		float a = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		COLOR = a > 0.5 ? outline : vec4(0.0);
	} else {
		vec3 rgb = c.rgb / max(c.a, 0.001);
		rgb = rgb * (1.0 - lift) + lift * vec3(1.0, 0.86, 0.7) * (1.0 - rgb);
		COLOR = vec4(floor(rgb * levels + 0.5) / levels, 1.0);
	}
}
