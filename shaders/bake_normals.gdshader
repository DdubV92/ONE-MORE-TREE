shader_type spatial;
render_mode unshaded, cull_back;

// Phase 24 PixelBaker normal pass: view-space normal as colour (x right,
// y up, z toward the orthographic bake camera).
void fragment() {
	ALBEDO = NORMAL * 0.5 + 0.5;
}
