shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// Camper TV: shows the composite of scene-linear remote feeds. The room's
// camera applies the only tone map / bloom / grade (no double tone mapping).
// `gain` makes it read as a dim emissive display, not a hole into daylight.
// The screen is on its own render layer, so feeds never capture it (no
// TV-in-TV recursion), and it is never a light source for SafetyService.

uniform sampler2D feed : source_color, filter_linear_mipmap, repeat_disable;
uniform float gain = 0.42;
uniform float powered = 1.0;

void fragment() {
	vec3 c = texture(feed, UV).rgb;
	vec3 off = vec3(0.008, 0.008, 0.01);
	ALBEDO = mix(off, c * gain, powered);
}
