// Coherent wind for trees and plants. Sway grows with height above the
// instance origin; gusts travel across the island in world space so
// neighbouring trees move together, not in lockstep.

float gust_at(vec2 xz, float t) {
	vec2 wd = normalize(wind_dir);
	float travel = dot(xz, wd) * 0.035 - t * 0.55;
	return 0.55 + 0.45 * sin(travel) * sin(travel * 0.37 + 1.3);
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
