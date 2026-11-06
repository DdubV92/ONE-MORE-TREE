shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Ponds and river. Ponds are calm with soft breeze normals; the river uses a
// two-phase flow map along its ribbon (UV.x = meters downstream) with
// whitewater only where the vertex data marks a grade change (COLOR.r).

#include "res://shaders/include/world_common.gdshaderinc"
#include "res://shaders/include/water_shading.gdshaderinc"

uniform bool is_river = false;
uniform sampler2D detail_normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform float flow_speed = 0.9;

varying vec3 v_wpos;
varying float v_rapid;
varying float v_edge;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_rapid = COLOR.r;
	v_edge = COLOR.g;
	if (is_river) {
		// Standing waves in riffles: a chevron train that stays in place
		// (the water moves through it), strongest mid-channel.
		float s = UV.x;
		float mid = 1.0 - v_edge * v_edge;
		float chevron = s * 2.2 - abs(UV.y) * 1.4;
		VERTEX.y += v_rapid * mid * 0.07 * sin(chevron) * (0.8 + 0.2 * sin(world_time * 2.5 + s * 0.7));
	}
}

void fragment() {
	float t = world_time;
	vec2 xz = v_wpos.xz;
	vec2 slope;
	float foam = 0.0;
	if (is_river) {
		vec2 uv = UV;   // x: downstream meters, y: across meters
		float mid = 1.0 - v_edge * v_edge;
		// Slower near the banks, faster mid-channel and over riffles.
		float speed = flow_speed * (0.45 + 0.55 * mid) * (1.0 + v_rapid * 1.8);
		float p0 = fract(t * 0.3);
		float p1 = fract(t * 0.3 + 0.5);
		float wgt = abs(p0 - 0.5) * 2.0;
		// Surface detail is stretched along the flow (long streaks, not glitter).
		vec2 sc = vec2(0.07, 0.3);
		vec2 uva = uv * sc - vec2(p0 * speed * 0.35, 0.0);
		vec2 uvb = uv * sc - vec2(p1 * speed * 0.35, 0.0) + 0.37;
		vec3 na = texture(detail_normal_a, uva).rgb * 2.0 - 1.0;
		vec3 nb = texture(detail_normal_a, uvb).rgb * 2.0 - 1.0;
		vec3 nc = texture(detail_normal_b, uv * vec2(0.2, 0.5) - vec2(t * speed * 0.25, 0.0)).rgb * 2.0 - 1.0;
		slope = mix(na.xy, nb.xy, wgt) * (0.1 + v_rapid * 0.28) + nc.xy * (0.04 + v_rapid * 0.1);
		// Whitewater: elongated, broken streaks advected with the current,
		// concentrated in the fast centre of the riffle; none in calm water.
		float fa = texture(foam_noise, uv * vec2(0.09, 0.55) - vec2(t * speed * 0.45, 0.0)).r;
		float fb = texture(foam_noise, uv * vec2(0.3, 1.4) - vec2(t * speed * 0.8, 0.0) + 0.5).r;
		float streak = smoothstep(0.5, 0.78, fa * 0.65 + fb * 0.5);
		float riffle = smoothstep(0.3, 0.85, v_rapid) * (0.35 + 0.65 * mid);
		foam = riffle * streak * 0.9;
		// Thin bubble lines trailing downstream of a riffle, and faint bank scum.
		foam += smoothstep(0.1, 0.4, v_rapid) * smoothstep(0.72, 0.9, fb) * 0.25;
		foam += smoothstep(0.85, 1.0, v_edge) * smoothstep(0.65, 0.85, fa) * 0.18;
	} else {
		vec2 wd = (length(wind_dir) > 1e-4 ? normalize(wind_dir) : vec2(0.8, 0.6));
		vec3 na = texture(detail_normal_a, xz * 0.09 + wd * t * 0.01).rgb * 2.0 - 1.0;
		vec3 nb = texture(detail_normal_b, xz * 0.21 - wd.yx * t * 0.013).rgb * 2.0 - 1.0;
		slope = (na.xy + nb.xy * 0.5) * 0.12 * (0.3 + wind_strength);
	}
	slope += ripple_slope(xz, t);
	// Rain rings: clear on ponds, mostly swept away on the moving river.
	slope += rain_ripples(xz, t) * (is_river ? 0.35 : 1.0);
	vec3 nmap = normalize(vec3(slope, 1.0));
	NORMAL_MAP = nmap * 0.5 + 0.5;
	vec3 n_view = normalize(TANGENT * nmap.x + BINORMAL * nmap.y + NORMAL * nmap.z);
	vec4 refr = refracted_scene(SCREEN_UV, VERTEX, n_view, INV_PROJECTION_MATRIX, is_river ? 1.2 : 0.7);
	vec3 body = apply_absorption(refr.rgb, refr.a, 1.0);
	float ndv = clamp(dot(n_view, VIEW), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	foam = clamp(foam, 0.0, 1.0);
	ALBEDO = mix(scatter_color * 0.12, vec3(0.9, 0.93, 0.92), foam);
	EMISSION = body * (1.0 - fres) * (1.0 - foam);
	ROUGHNESS = mix(is_river ? mix(0.13, 0.28, v_rapid) : 0.04, 0.8, foam);
	SPECULAR = (is_river ? 0.35 : 0.5) * (1.0 - foam);
	// Only the last few centimetres fade out (soft contact line).
	ALPHA = clamp(refr.a * 30.0 + foam, 0.0, 1.0);
}
