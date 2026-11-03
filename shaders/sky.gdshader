shader_type sky;
render_mode use_debanding;

// Gradient sky with sun disk + halo, moon disk, stars and soft clouds.
// LIGHT0 = sun, LIGHT1 = moon (set by EnvironmentController).

uniform vec3 zenith_color : source_color = vec3(0.2, 0.43, 0.8);
uniform vec3 horizon_color : source_color = vec3(0.66, 0.8, 0.92);
uniform vec3 ground_color : source_color = vec3(0.26, 0.28, 0.25);
uniform vec3 halo_color : source_color = vec3(1.0, 0.9, 0.75);
uniform float stars = 0.0;
uniform float cloud_cover = 0.25;
uniform float cloud_offset = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float sky_energy = 1.0;
uniform float moon_phase = 0.5;   // 0 new, 0.5 full

float h31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h31(vec3(i, 1.0));
	float b = h31(vec3(i + vec2(1, 0), 1.0));
	float c = h31(vec3(i + vec2(0, 1), 1.0));
	float d = h31(vec3(i + vec2(1, 1), 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float clouds(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += n2(p) * a;
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, zenith_color, pow(h, 0.5));
	} else {
		col = mix(horizon_color, ground_color, pow(clamp(-h * 3.0, 0.0, 1.0), 0.6));
	}
	float sd = dot(d, normalize(sun_dir));
	float sun_vis = smoothstep(-0.12, 0.05, sun_dir.y);
	// Forward-scattering halo, strongest near the horizon.
	col += halo_color * pow(max(sd, 0.0), 8.0) * 0.35 * sun_vis;
	col += halo_color * pow(max(sd, 0.0), 64.0) * 0.6 * sun_vis;
	// Clouds (cylindrical projection, thinner toward the horizon).
	if (h > 0.0 && cloud_cover > 0.01) {
		vec2 cp = d.xz / (h + 0.18) * 1.6 + vec2(cloud_offset, cloud_offset * 0.4);
		float c = clouds(cp);
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.35, c) * smoothstep(0.0, 0.25, h);
		vec3 lit = mix(horizon_color * 1.05, vec3(1.0), 0.55 * sun_vis) + halo_color * pow(max(sd, 0.0), 6.0) * 0.4 * sun_vis;
		vec3 cloud_col = mix(lit, zenith_color * 0.6 + horizon_color * 0.3, 0.35 * c);
		col = mix(col, cloud_col, cov * 0.85);
	}
	if (!AT_CUBEMAP_PASS) {
		// Sun disk
		col += halo_color * 30.0 * smoothstep(0.99985, 0.99994, sd) * sun_vis;
		// Moon disk with a hint of shading
		float md = dot(d, normalize(moon_dir));
		vec3 mdn = normalize(moon_dir);
		float moon = smoothstep(0.99955, 0.9997, md) * smoothstep(-0.05, 0.05, moon_dir.y);
		// Phase: lit side grows from the right (waxing) and shrinks to the
		// left (waning); the dark side keeps a faint earthshine.
		vec3 mr = normalize(cross(mdn, vec3(0.0, 1.0, 0.0)));
		float u = dot(d - mdn * md, mr) / 0.0245;
		float ph = fract(moon_phase);
		float illum = 0.5 * (1.0 - cos(6.2831853 * ph));
		float lit = ph < 0.5 ? smoothstep(-0.12, 0.12, u - (1.0 - 2.0 * illum)) : smoothstep(-0.12, 0.12, -u - (1.0 - 2.0 * illum));
		col += vec3(0.85, 0.88, 0.95) * moon * 2.5 * (0.8 + 0.2 * n2(d.xy * 400.0)) * mix(0.025, 1.0, lit);
		col += vec3(0.4, 0.45, 0.6) * pow(max(md, 0.0), 300.0) * 0.15 * smoothstep(-0.05, 0.1, moon_dir.y) * (0.1 + 0.9 * illum);
		// Stars
		if (stars > 0.01 && h > 0.0) {
			vec3 sp = d * 260.0;
			vec3 cell = floor(sp);
			float r = h31(cell);
			float star = step(0.9965, r) * smoothstep(0.42, 0.0, length(fract(sp) - 0.5));
			float tw = 0.7 + 0.3 * fract(r * 91.7);
			col += vec3(0.8, 0.85, 1.0) * star * tw * stars * smoothstep(0.0, 0.2, h) * 1.4;
		}
	}
	COLOR = col * sky_energy;
}
