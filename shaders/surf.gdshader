shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Breaking shore waves on ribbons laid along the breaking-depth contour
// (scripts/water/surf_system.gd). Each ribbon row is a point on a 2D
// cross-section spline; poses blend from swell to steep face, pitching lip,
// curling tube, collapse and a whitewater bore that runs up to the beach.
// Timing comes from the shared swash phase, so the run-up on the sand
// follows the wave that just landed.
//
// Vertex data: UV = (t along profile 0..1, s along shore m),
// UV2 = (distance to the waterline m, end taper), CUSTOM0 = (shoreward
// normal xz, beach sand 0..1, swell exposure 0..1).

#include "res://shaders/include/world_common.gdshaderinc"

uniform vec2 poses[54];             // 6 poses x 9 control points (height units)
uniform float surf_height = 1.3;
uniform float stretch = 1.55;
uniform vec2 swell_dir = vec2(0.2, -1.0);
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep_col : source_color = vec3(0.02, 0.2, 0.24);
uniform vec3 thin_col : source_color = vec3(0.16, 0.72, 0.62);

varying float v_foam;
varying float v_thin;
varying float v_alpha;
varying vec3 v_wpos;
varying float v_t;
varying float v_pose;
varying float v_body;
varying float v_s;

vec2 pose_point(int i, float k) {
	int a = int(floor(k));
	int b = min(a + 1, 5);
	float f = smoothstep(0.0, 1.0, k - float(a));
	return mix(poses[a * 9 + i], poses[b * 9 + i], f);
}

// Catmull-Rom through the 9 control points of the blended pose.
void profile(float t, float k, out vec2 p, out vec2 d) {
	float x = clamp(t, 0.0, 1.0) * 8.0;
	int i = min(int(floor(x)), 7);
	float u = x - float(i);
	vec2 p0 = pose_point(max(i - 1, 0), k);
	vec2 p1 = pose_point(i, k);
	vec2 p2 = pose_point(i + 1, k);
	vec2 p3 = pose_point(min(i + 2, 8), k);
	vec2 a = 2.0 * p1;
	vec2 b = p2 - p0;
	vec2 c = 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3;
	vec2 e = -p0 + 3.0 * p1 - 3.0 * p2 + p3;
	p = 0.5 * (a + b * u + c * u * u + e * u * u * u);
	d = 0.5 * (b + 2.0 * c * u + 3.0 * e * u * u);
}

void vertex() {
	float t = UV.x;
	float s = UV.y;
	float dist = UV2.x;
	float taper = UV2.y;
	vec2 n = normalize(CUSTOM0.xy);
	float beach = CUSTOM0.z;
	float exposure = CUSTOM0.w;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 shore = wp.xz + n * dist;

	// Seconds until this wave's swash reaches the waterline, and the bore
	// travel time from the breaker line (shallow-water speed ~ sqrt(g h)).
	float arg = world_time / SWASH_PERIOD + vnoise(shore * 0.011) * 0.7 + shore.x * 0.0012;
	float ph = fract(arg);
	float tau = (1.0 - ph) * SWASH_PERIOD;
	float tb = clamp(dist / 3.4, 1.2, 3.2);
	float u = tau - tb;                 // seconds until the lip lands

	// Sets: every wave a little different; some lines bigger than others.
	float cycle = floor(arg) + 1.0;
	float set_var = 0.6 + 0.75 * vnoise(vec2(cycle * 1.37, s * 0.012));
	float H = surf_height * set_var * mix(0.42, 1.0, exposure) * mix(0.75, 1.0, beach) * taper;

	float k = 0.0;          // pose
	float shift = 0.0;      // shoreward travel of the bore (m)
	float hscale = 1.0;
	float foam = 0.0;
	float body_a = 1.0;
	if (u > 5.0 || u < -tb) {
		k = 0.0;
		shift = -19.0;
	}
	// The wave rolls in from deeper water at shallow-water speed before it
	// breaks on the contour (shift < 0 is seaward).
	if (u > 0.0 && u <= 5.0) {
		shift = -u * 3.8;
	}
	if (u > 5.0 || u < -tb) {
	} else if (u > 3.0) {
		k = mix(1.0, 0.0, (u - 3.0) / 2.0);
	} else if (u > 1.3) {
		k = mix(2.0, 1.0, (u - 1.3) / 1.7);
	} else if (u > 0.5) {
		k = mix(3.0, 2.0, (u - 0.5) / 0.8);
	} else if (u > 0.0) {
		k = mix(4.0, 3.0, u / 0.5);
	} else {
		// Lip has landed: collapse into a whitewater bore that runs shoreward.
		float b = -u / tb;
		k = mix(4.0, 5.0, clamp(b * 4.0, 0.0, 1.0));
		shift = dist * 0.9 * smoothstep(0.0, 1.0, b);
		hscale = mix(1.0, 0.28, b);
		foam = mix(0.8, 0.18, smoothstep(0.15, 1.0, b));
		// As the bore flattens only its foam stays visible over the shallows.
		body_a = 1.0 - smoothstep(0.2, 0.7, b);
	}
	float pitch = smoothstep(2.0, 4.0, k) * step(k, 4.5);
	vec2 p;
	vec2 d;
	profile(t, k, p, d);
	float hx = H * stretch;
	float hy = H * hscale;
	vec2 off = vec2(p.x * hx + shift, p.y * hy);
	wp.xz += n * off.x;
	wp.y = sea_level + off.y + 0.025;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	// Outward normal of the curve (left of the tangent), then into 3D.
	vec2 tg = normalize(vec2(d.x * hx, d.y * hy) + vec2(1e-5, 0.0));
	vec2 n2 = vec2(-tg.y, tg.x);
	// Chunks are translated only, so world and model normals coincide.
	NORMAL = normalize(vec3(n.x * n2.x, n2.y, n.y * n2.x));
	// Thin water: lip and upper face during pitching/curl (backlit green).
	// Upper face and lip are thin enough to glow green-turquoise.
	float upper = smoothstep(0.3, 0.95, p.y) * smoothstep(0.8, 2.0, k);
	v_thin = max(pitch * smoothstep(0.42, 0.55, t) * (1.0 - smoothstep(0.72, 0.85, t)), upper * 0.8);
	// Foam: lip edge feathering while pitching, whitewater after impact.
	float lip = pitch * exp(-pow((t - 0.62) * 9.0, 2.0)) * smoothstep(3.0, 4.0, k);
	// Bore: dense churning front, thinning lace behind it.
	float front = smoothstep(0.42, 0.62, t) * (1.0 - smoothstep(0.84, 0.97, t));
	v_foam = max(foam * mix(0.3, 1.0, front) * smoothstep(0.1, 0.35, t), lip);
	// Flat ends fade into the ocean plane (no double surface).
	v_alpha = smoothstep(0.03, 0.14, off.y) * (H > 0.05 ? 1.0 : 0.0);
	v_wpos = wp;
	v_t = t;
	v_pose = k;
	v_body = body_a;
	v_s = s;
}

void fragment() {
	vec2 xz = v_wpos.xz;
	float t = world_time;
	vec3 dn = texture(detail_normal, xz * 0.09 + vec2(t * 0.03, -t * 0.02)).rgb * 2.0 - 1.0;
	NORMAL_MAP = normalize(vec3(dn.xy * 0.8, 1.0)) * 0.5 + 0.5;
	float fn2 = texture(foam_noise, xz * 0.37 - vec2(t * 0.04, t * 0.07)).r;
	float foam = foam_lace(xz, t, v_foam) * step(0.01, v_foam);
	// Streaks of foam and bubbles drawn up the steep face (along the profile).
	float streak = smoothstep(0.72, 0.95, vnoise(vec2(v_s * 1.7, v_t * 6.0 - t * 0.8))) * smoothstep(1.6, 3.0, v_pose) * smoothstep(0.38, 0.55, v_t) * (1.0 - smoothstep(0.7, 0.8, v_t));
	foam = max(foam, streak * 0.55 + smoothstep(2.5, 4.0, v_pose) * smoothstep(0.7, 0.9, fn2) * smoothstep(0.55, 0.75, v_t) * 0.6);
	vec3 n_view = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = n_view;
	float ndv = clamp(dot(n_view, VIEW), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	// Dark at the base, glowing green-turquoise where the face thins out.
	vec3 body = mix(deep_col * 0.75, thin_col, v_thin) * (0.3 + 0.7 * daylight);
	// Foam is lumpy: shade it with a little noise so it is not paper-white.
	float lump = 0.78 + 0.22 * vnoise(xz * 4.0 + t * 0.6);
	ALBEDO = mix(body * 0.25, vec3(0.9, 0.93, 0.93) * lump, foam);
	EMISSION = body * (1.0 - fres) * (1.0 - foam) * 0.9;
	BACKLIGHT = thin_col * v_thin * (1.0 - foam) * 0.9;
	ROUGHNESS = mix(0.05, 0.85, foam);
	SPECULAR = 0.5 * (1.0 - foam);
	ALPHA = v_alpha * max(v_body * mix(0.93, 0.8, v_thin * (1.0 - foam)), foam);
}
