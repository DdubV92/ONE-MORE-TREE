class_name TimberMesh
extends RefCounted
## Mesh builders shared by every timber representation (world bodies, the
## carried bundle, the delivery rack and pieces in the pit), so a piece looks
## the same wherever it is. Local frame: the trunk axis is +Y, lengths are
## meters from the original tree base (shifted by `origin_len`).
##
## Surfaces: 0 bark, 1 exposed wood (end grain, cut grooves), 2 boundary
## paint marks. Caps are wound clockwise as seen from outside (Godot front
## faces), so cut ends never face backward.

const SIDES := 14
const GROOVE := 0.07
static var _bark_mats := {}
static var _wood_mat: ShaderMaterial
static var _mark_mat: StandardMaterial3D


static func radius_at(rec: Dictionary, len_from_base: float) -> float:
	return TreeBuilder.trunk_radius_local(int(rec.species), int(rec.variant), len_from_base / float(rec.ys)) * float(rec.xs)


## Basis mapping +Y onto `axis` (right-handed, deterministic).
static func frame_for(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	return Basis(x, y, x.cross(y).normalized())


static func bark_material(sp: int) -> StandardMaterial3D:
	if _bark_mats.has(sp):
		return _bark_mats[sp]
	var m := StandardMaterial3D.new()
	if sp == TreeBuilder.Species.BIRCH:
		m.albedo_texture = _birch_tex()
		m.roughness = 0.75
	else:
		var base := "res://assets/polyhaven/textures/pine_bark/pine_bark" if sp == 0 else "res://assets/polyhaven/textures/bark_brown_02/bark_brown_02"
		m.albedo_texture = load(base + "_diff.jpg")
		m.normal_enabled = true
		m.normal_texture = load(base + "_nor_gl.jpg")
		m.albedo_color = Color(1.0, 0.9, 0.82) if sp == 0 else Color(0.8, 0.72, 0.66)
		m.roughness = 0.9
	_bark_mats[sp] = m
	return m


static func bark_texture(sp: int) -> Texture2D:
	return bark_material(sp).albedo_texture


static var _birch: ImageTexture
static func _birch_tex() -> ImageTexture:
	# White birch bark with dark lenticels (procedural, generated once).
	if _birch:
		return _birch
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	img.fill(Color(0.86, 0.84, 0.79))
	for k in 70:
		var x := rng.randi_range(0, 127)
		var y := rng.randi_range(0, 127)
		var w := rng.randi_range(4, 18)
		for i in w:
			img.set_pixel((x + i) % 128, y, Color(0.18, 0.16, 0.14))
			if rng.randf() < 0.5:
				img.set_pixel((x + i) % 128, (y + 1) % 128, Color(0.3, 0.27, 0.24))
	img.generate_mipmaps()
	_birch = ImageTexture.create_from_image(img)
	return _birch


static func wood_material() -> ShaderMaterial:
	if _wood_mat == null:
		_wood_mat = ShaderMaterial.new()
		_wood_mat.shader = load("res://shaders/end_grain.gdshader")
	return _wood_mat


static func mark_material() -> StandardMaterial3D:
	if _mark_mat == null:
		# Forestry marking paint: where the bucking cuts go.
		_mark_mat = StandardMaterial3D.new()
		_mark_mat.albedo_color = Color(0.95, 0.42, 0.08)
		_mark_mat.roughness = 0.7
	return _mark_mat


## One trunk segment k of record `rec`.
##  lo_cap/hi_cap: draw end-grain caps (cut ends).
##  p_lo/p_hi: partial-cut progress of the boundary at each end (V groove).
##  mark_hi: paint an uncut boundary mark near the top end.
static func segment_mesh(rec: Dictionary, k: int, lo_cap: bool, hi_cap: bool, p_lo: float, p_hi: float, mark_hi: bool, origin_len := 0.0) -> ArrayMesh:
	var s: Dictionary = rec.segments[k]
	var a: float = s.a
	var b: float = s.b
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mark := SurfaceTool.new()
	mark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_wood := 0
	var y0 := a + (GROOVE if p_lo > 0.0 else 0.0)
	var y1 := b - (GROOVE if p_hi > 0.0 else 0.0)
	var circ := TAU * radius_at(rec, a)
	_lathe(bark, y0, radius_at(rec, y0), y1, radius_at(rec, y1), origin_len, circ, -1.0, -1.0)
	if p_lo > 0.0:
		var ri := radius_at(rec, a) * (1.0 - 0.62 * p_lo)
		_lathe(wood, a, ri, y0, radius_at(rec, y0), origin_len, 0.0, (1.0 - 0.62 * p_lo) * 0.92, 0.98)
		n_wood += 1
	if p_hi > 0.0:
		var ri := radius_at(rec, b) * (1.0 - 0.62 * p_hi)
		_lathe(wood, y1, radius_at(rec, y1), b, ri, origin_len, 0.0, 0.98, (1.0 - 0.62 * p_hi) * 0.92)
		n_wood += 1
	if lo_cap:
		_cap(wood, a, radius_at(rec, a) * (1.0 - 0.62 * p_lo), -1.0, origin_len)
		n_wood += 1
	if hi_cap:
		_cap(wood, b, radius_at(rec, b) * (1.0 - 0.62 * p_hi), 1.0, origin_len)
		n_wood += 1
	var n_mark := 0
	if mark_hi and p_hi <= 0.0:
		var m0 := b - 0.06
		_lathe(mark, m0, radius_at(rec, m0) * 1.012, b - 0.015, radius_at(rec, b - 0.015) * 1.012, origin_len, 0.5, -1.0, -1.0)
		n_mark = 1
	var mesh := ArrayMesh.new()
	bark.generate_tangents()
	bark.commit(mesh)
	mesh.surface_set_material(0, bark_material(int(rec.species)))
	if n_wood > 0:
		wood.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, wood_material())
	if n_mark > 0:
		mark.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mark_material())
	return mesh


## Truncated cone between heights y0 and y1. Bark UVs wrap by circumference
## (no stretching); wood UVs are radial (ratio0/ratio1 >= 0).
static func _lathe(st: SurfaceTool, y0: float, r0: float, y1: float, r1: float, origin_len: float, circ: float, ratio0: float, ratio1: float) -> void:
	var slope := (r0 - r1) / maxf(y1 - y0, 0.001)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p := [d0 * r0 + Vector3(0, y0 - origin_len, 0), d0 * r1 + Vector3(0, y1 - origin_len, 0), d1 * r1 + Vector3(0, y1 - origin_len, 0), d1 * r0 + Vector3(0, y0 - origin_len, 0)]
		var nr := [(d0 + Vector3(0, slope, 0)).normalized(), (d0 + Vector3(0, slope, 0)).normalized(), (d1 + Vector3(0, slope, 0)).normalized(), (d1 + Vector3(0, slope, 0)).normalized()]
		var uv: Array
		if ratio0 < 0.0:
			var u0 := float(i) / SIDES * maxf(circ, 0.3)
			var u1 := float(i + 1) / SIDES * maxf(circ, 0.3)
			uv = [Vector2(u0, y0 * 0.5), Vector2(u0, y1 * 0.5), Vector2(u1, y1 * 0.5), Vector2(u1, y0 * 0.5)]
		else:
			var h := Vector2(0.5, 0.5)
			uv = [h + Vector2(d0.x, d0.z) * 0.5 * ratio0, h + Vector2(d0.x, d0.z) * 0.5 * ratio1, h + Vector2(d1.x, d1.z) * 0.5 * ratio1, h + Vector2(d1.x, d1.z) * 0.5 * ratio0]
		for j in [0, 2, 1, 0, 3, 2]:
			st.set_normal(nr[j])
			st.set_uv(uv[j])
			st.add_vertex(p[j])


static func _cap(st: SurfaceTool, y: float, r: float, facing: float, origin_len: float) -> void:
	var c := Vector3(0, y - origin_len, 0)
	var nrm := Vector3(0, facing, 0)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var p0 := Vector3(cos(a0) * r, y - origin_len, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, y - origin_len, sin(a1) * r)
		var u0 := Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)
		var u1 := Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)
		# Clockwise from outside: top cap (+Y) c,p0,p1; bottom cap c,p1,p0.
		var tri := [c, p0, p1] if facing > 0.0 else [c, p1, p0]
		var uvs := [Vector2(0.5, 0.5), u0, u1] if facing > 0.0 else [Vector2(0.5, 0.5), u1, u0]
		for j in 3:
			st.set_normal(nrm)
			st.set_uv(uvs[j])
			st.add_vertex(tri[j])


## Mesh for one free piece centred on its midpoint (carried/rack/pit use).
static func piece_mesh(rec: Dictionary, k: int) -> ArrayMesh:
	var s: Dictionary = rec.segments[k]
	return segment_mesh(rec, k, true, true, 0.0, 0.0, false, (float(s.a) + float(s.b)) * 0.5)


static func piece_length(rec: Dictionary, k: int) -> float:
	var s: Dictionary = rec.segments[k]
	return float(s.b) - float(s.a)


static func piece_radius(rec: Dictionary, k: int) -> float:
	var s: Dictionary = rec.segments[k]
	return radius_at(rec, (float(s.a) + float(s.b)) * 0.5)
