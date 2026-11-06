// Coherent wind for trees and plants. Sway grows with height above the
// instance origin; gusts travel across the island in world space so
// neighbouring trees move together, not in lockstep.

float gust_at(vec2 xz, float t) {
	vec2 wd = normalize(wind_dir);
	// Phase 23: stronger, faster gust bands in storms (a visible gust
	// front rolling through canopy, brush and grass).
	float travel = dot(xz, wd) * 0.035 - t * (0.55 + 0.6 * storm_gust);
	float base = 0.55 + 0.45 * sin(travel) * sin(travel * 0.37 + 1.3);
	float front = smoothstep(0.25, 0.9, 0.5 + 0.5 * sin(travel * 0.21 + 2.0));
	return base * (1.0 + 1.3 * storm_gust * front);
}

vec3 tree_sway(vec3 local_pos, float tree_height, vec3 inst_origin, float phase, float t) {
	float hn = clamp(local_pos.y / max(tree_height, 1.0), 0.0, 1.5);
	float bend = hn * hn;
	float g = gust_at(inst_origin.xz, t) * wind_strength;
	float sway = sin(t * 0.9 + phase) * 0.35 + sin(t * 1.7 + phase * 1.3) * 0.15;
	vec2 wd = normalize(wind_dir);
	vec2 off = wd * (g * 0.55 + sway * g * 0.4) * bend * min(tree_height * 0.045, 0.9);
	return vec3(off.x, -dot(off, off) * 0.3, off.y);
}

// Neighbour flex after a felled trunk lands: x, z, start time, strength.
global uniform vec4 tree_impact;

vec3 impact_sway(vec3 local_pos, float tree_height, vec3 inst_origin, float t) {
	float age = t - tree_impact.z;
	if (age < 0.0 || age > 5.0 || tree_impact.w <= 0.0) return vec3(0.0);
	vec2 d = inst_origin.xz - tree_impact.xy;
	float dist = length(d);
	if (dist > 14.0 || dist < 0.5) return vec3(0.0);
	float hn = clamp(local_pos.y / max(tree_height, 1.0), 0.0, 1.5);
	float amp = tree_impact.w * (1.0 - dist / 14.0) * exp(-age * 1.3) * sin(age * 5.5);
	vec2 dir = d / dist;
	return vec3(dir.x, 0.0, dir.y) * amp * hn * hn * 0.45;
}
