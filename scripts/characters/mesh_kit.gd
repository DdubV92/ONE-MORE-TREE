class_name CharMeshKit
extends RefCounted
## Reusable, cached meshes and materials for the procedural characters.
## Limbs are tapered capsules whose rounded ends overlap at the joints, so
## rotating a joint never opens a gap (rigid-part articulation, not skinning).

static var _mesh_cache := {}
static var _mat_cache := {}


## Capsule from y=0 (top sphere center, radius r0) to y=-length (bottom
## sphere center, radius r1). Smooth normals.
static func tapered_capsule(r0: float, r1: float, length: float, seg := 14, cap_rings := 5) -> ArrayMesh:
	var key := "cap_%.3f_%.3f_%.3f_%d" % [r0, r1, length, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	# Profile: (radius, y, normal_y) from top pole to bottom pole.
	var prof: Array = []
	var slope := atan2(r0 - r1, length)   # cone side tilt
	for i in cap_rings + 1:
		var a := lerpf(PI * 0.5, slope, float(i) / cap_rings)
		prof.append([cos(a) * r0, sin(a) * r0, Vector2(cos(a), sin(a))])
	for i in cap_rings + 1:
		var a := lerpf(slope, -PI * 0.5, float(i) / cap_rings)
		prof.append([cos(a) * r1, sin(a) * r1 - length, Vector2(cos(a), sin(a))])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in prof.size() - 1:
		var p0: Array = prof[i]
		var p1: Array = prof[i + 1]
		for s in seg:
			var a0 := TAU * s / seg
			var a1 := TAU * (s + 1) / seg
			var v := func(p: Array, a: float) -> Array:
				var n2: Vector2 = p[2]
				return [Vector3(cos(a) * p[0], p[1], sin(a) * p[0]), Vector3(cos(a) * n2.x, n2.y, sin(a) * n2.x).normalized()]
			var q := [v.call(p0, a0), v.call(p1, a0), v.call(p1, a1), v.call(p0, a1)]
			# Clockwise seen from outside (Godot front faces).
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[idx][1])
				st.add_vertex(q[idx][0])
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func sphere(radius := 0.5, seg := 18, rings := 10) -> SphereMesh:
	var key := "sph_%d_%d" % [seg, rings]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = seg
	s.rings = rings
	_mesh_cache[key] = s
	return s


## Phase 11 character style: "clean" or "pixel" (subtle attached pixel
## texture as a multiply next-pass; geometry, lighting and shadows intact).
static var style := "clean"
static var _pixel_pass: ShaderMaterial


static func pixel_pass() -> ShaderMaterial:
	if _pixel_pass == null:
		_pixel_pass = ShaderMaterial.new()
		_pixel_pass.shader = load("res://shaders/char_pixel.gdshader")
	_pixel_pass.set_shader_parameter("strength", float(Settings.get_v("character_style_strength")) if Settings.values.has("character_style_strength") else 0.7)
	return _pixel_pass


static func _styled(m: StandardMaterial3D) -> StandardMaterial3D:
	if style == "pixel":
		m.next_pass = pixel_pass()
		# Restrained texture filtering for the pixel look.
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	else:
		m.next_pass = null
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## Switches every character material in place (no rebuild, so carried
## logs, grips and animation state are untouched).
static func apply_style(s: String) -> void:
	if s == style and _pixel_pass != null:
		pixel_pass()
		return
	style = s
	for m in _mat_cache.values():
		if m is StandardMaterial3D:
			_styled(m)


static func mat(color: Color, rough := 0.75, sss := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(), rough, sss]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if sss > 0.0:
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = sss
		m.subsurf_scatter_skin_mode = true
	_styled(m)
	_mat_cache[key] = m
	return m


static func fabric(color: Color, texture: String = "denim_fabric") -> StandardMaterial3D:
	var key := "fab_%s_%s" % [color.to_html(), texture]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var base := "res://assets/polyhaven/textures/%s/%s" % [texture, texture]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base + "_diff.jpg")
	# Desaturate the denim scan toward the requested garment colour.
	m.albedo_color = color * 1.6
	m.normal_enabled = true
	m.normal_texture = load(base + "_nor_gl.jpg")
	m.normal_scale = 0.6
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 3.0
	_styled(m)
	_mat_cache[key] = m
	return m


## Adds a mesh part under `parent`. Ellipsoids use the cached unit sphere
## scaled by `size` (full extents in meters).
static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, size := Vector3.ONE, rot := Vector3.ZERO, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = size
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func blob(parent: Node3D, material: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO, name := "") -> MeshInstance3D:
	return part(parent, sphere(), material, pos, size, rot, name)


static func limb(parent: Node3D, material: Material, r0: float, r1: float, length: float, name := "") -> MeshInstance3D:
	return part(parent, tapered_capsule(r0, r1, length), material, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, name)
