shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Phase 11 subtle pixel-textured character treatment, applied as a
// multiply next-pass on the character's normal PBR materials (so lighting,
// shadows, fog and SSS stay intact). Everything is computed in the PART'S
// OWN metric space, so the pattern is attached to the body (no screen-space
// crawl): coarse colour cells (hand-painted variation), and a 3-band light
// ramp with ordered-dither edges taken from the shared sun direction.
// strength 0 = clean (pass is not attached at all in the clean style).

global uniform vec3 sun_dir_world;
uniform float strength = 0.7;
uniform float cell = 0.016;      // texel size in metres on the body

varying vec3 v_obj;
varying vec3 v_wn;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_obj = VERTEX * sc;
	v_wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 c = floor(v_obj / cell);
	float h = hash3(c);
	float h2 = hash3(c + 17.0);
	float var_ = 1.0 + (h - 0.5) * 0.12 * strength;
	float q = clamp(dot(normalize(v_wn), normalize(sun_dir_world)) * 0.5 + 0.5, 0.0, 1.0);
	// 2x2 ordered dither from the cell index (attached, stable).
	float bayer = mod(c.x + 2.0 * mod(c.y + c.z, 2.0), 4.0) / 4.0 - 0.375;
	float qd = floor(q * 3.0 + bayer * 0.7 + (h2 - 0.5) * 0.2) / 3.0;
	float smooth_ = 0.78 + 0.32 * q;
	float banded = 0.78 + 0.32 * clamp(qd, 0.0, 1.0);
	float f = mix(1.0, banded / smooth_, strength);
	ALBEDO = vec3(var_ * f);
}
