shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled;

// Phase 24 HD-2D actor sprite. The quad is billboarded around the actor's
// vertical axis toward WHICHEVER camera renders it (player view, security
// feeds, recordings), and the facing is chosen per camera from 8 baked
// directions, so every view sees the side of the actor it should.
// Albedo and view-space normals come from the runtime bake (PixelBaker);
// the sprite is lit by the real scene lights through those normals, with
// a 1-texel dark outline and alpha-cut silhouette (crisp pixel edges).

uniform sampler2D albedo_atlas : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_atlas : filter_nearest, repeat_disable;
uniform vec2 cell_px = vec2(48.0, 60.0);     // one frame, one direction
uniform vec2 atlas_cells = vec2(8.0, 1.0);   // directions x frames
uniform float frame = 0.0;                   // row in the atlas
uniform vec2 quad_size = vec2(2.08, 2.6);    // metres
uniform float foot_margin = 0.1;             // metres below the feet in the cell
uniform vec4 outline_color : source_color = vec4(0.07, 0.06, 0.06, 1.0);
uniform float light_wrap = 0.35;

varying float v_dir;
varying vec3 v_view_right;

void vertex() {
	// Actor frame (yaw only): origin at the feet, forward = +Z of the actor.
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 fwd = normalize(vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z) + vec3(1e-5, 0.0, 0.0));
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	to_cam = length(to_cam) > 1e-4 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	// Direction index 0 = camera in front of the actor, increasing clockwise
	// seen from above (matches PixelBaker's copy rotations).
	vec3 right_a = vec3(fwd.z, 0.0, -fwd.x);
	float ang = atan(dot(to_cam, right_a), dot(to_cam, fwd));
	v_dir = mod(round(ang / (PI * 0.25)) + 8.0, 8.0);
	// Cylindrical billboard facing the camera.
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	vec3 local = VERTEX;   // quad in XY: x in [-0.5,0.5], y in [0,1]
	vec3 world = origin + side * local.x * quad_size.x + vec3(0.0, 1.0, 0.0) * (local.y * quad_size.y - foot_margin);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(to_cam, 0.0)).xyz;
	v_view_right = side;
}

vec2 cell_uv(vec2 uv01) {
	vec2 cell = vec2(v_dir, frame);
	return (cell + uv01) / atlas_cells;
}

void fragment() {
	vec2 uv01 = vec2(UV.x, UV.y);
	vec2 tex = 1.0 / (cell_px * atlas_cells);
	vec2 uv = cell_uv(uv01);
	vec4 a = texture(albedo_atlas, uv);
	float alpha = a.a;
	vec3 col = a.rgb;
	// The bake viewport writes sRGB-encoded colour: linearise, then decode.
	vec3 ns = texture(normal_atlas, uv).rgb;
	vec3 nl = mix(ns / 12.92, pow((ns + 0.055) / 1.055, vec3(2.4)), step(0.04045, ns));
	vec3 nrm = nl * 2.0 - 1.0;
	if (alpha < 0.5) {
		// 1-texel outline: any solid neighbour inside this cell.
		float o = 0.0;
		vec2 lo = vec2(v_dir, frame) / atlas_cells + tex * 0.5;
		vec2 hi = (vec2(v_dir, frame) + 1.0) / atlas_cells - tex * 0.5;
		for (int k = 0; k < 4; k++) {
			vec2 d = k == 0 ? vec2(tex.x, 0.0) : (k == 1 ? vec2(-tex.x, 0.0) : (k == 2 ? vec2(0.0, tex.y) : vec2(0.0, -tex.y)));
			vec2 q = clamp(uv + d, lo, hi);
			o = max(o, step(0.5, texture(albedo_atlas, q).a));
		}
		if (o < 0.5) {
			discard;
		}
		col = outline_color.rgb;
		nrm = vec3(0.0, 0.0, 1.0);
	}
	ALBEDO = col;
	// Baked normals are in the bake camera's space (x right, y up, z toward
	// the viewer) - the same frame as this camera-facing quad.
	vec3 n_view = normalize(nrm.x * normalize((VIEW_MATRIX * vec4(v_view_right, 0.0)).xyz) + nrm.y * normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz) + nrm.z * normalize(NORMAL));
	NORMAL = n_view;
	ROUGHNESS = 0.9;
}
