class_name BuildKit
extends RefCounted
## Small helpers for constructing buildings and props in code: boxes with
## matching collision, walls with door/window openings, cylinders, shared
## materials and Poly Haven prop instancing. Materials are cached and shared.

static var _mats := {}
const PH := "res://assets/polyhaven/models/%s/%s_1k.gltf"


static func mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m: Material
	match name:
		"planks": m = _tex_mat("weathered_planks", Color(1, 0.95, 0.9), 0.6)
		"siding": m = _tex_mat("weathered_plank_siding", Color(0.95, 0.9, 0.85), 0.5)
		"floor": m = _tex_mat("wood_floor_worn", Color(1, 0.95, 0.9), 0.5)
		"panel": m = _tex_mat("wood_floor_worn", Color(1.1, 1.0, 0.88), 0.7)
		"dark_wood": m = _tex_mat("weathered_planks", Color(0.55, 0.45, 0.38), 0.6)
		"denim": m = _tex_mat("denim_fabric", Color(1, 1, 1), 1.5)
		"leather": m = _tex_mat("fabric_leather_01", Color(1, 1, 1), 1.0)
		"bark": m = _tex_mat_path("res://assets/polyhaven/textures/pine_bark/pine_bark", Color(0.9, 0.85, 0.8), 0.8)
		"camper_paint": m = _plain(Color(0.88, 0.85, 0.76), 0.35, 0.15)
		"camper_stripe": m = _plain(Color(0.16, 0.45, 0.45), 0.35, 0.15)
		"camper_trim": m = _plain(Color(0.75, 0.76, 0.78), 0.3, 0.8)
		"steel": m = _plain(Color(0.42, 0.44, 0.46), 0.45, 0.85)
		"galvanized": m = _plain(Color(0.62, 0.64, 0.66), 0.4, 0.9)
		"black": m = _plain(Color(0.05, 0.05, 0.05), 0.6, 0.0)
		"rubber": m = _plain(Color(0.06, 0.06, 0.06), 0.9, 0.0)
		"white": m = _plain(Color(0.9, 0.9, 0.88), 0.4, 0.0)
		"ceramic": m = _plain(Color(0.95, 0.95, 0.93), 0.12, 0.0)
		"counter": m = _plain(Color(0.55, 0.6, 0.55), 0.35, 0.0)
		"wall_white": m = _plain(Color(0.86, 0.83, 0.76), 0.7, 0.0)
		"mattress": m = _plain(Color(0.86, 0.84, 0.78), 0.9, 0.0)
		"blanket_red": m = _tex_mat("denim_fabric", Color(1.4, 0.35, 0.3), 1.2)
		"blanket_green": m = _tex_mat("denim_fabric", Color(0.5, 0.9, 0.5), 1.2)
		"blanket_ochre": m = _tex_mat("denim_fabric", Color(1.5, 1.1, 0.4), 1.2)
		"blanket_blue": m = _tex_mat("denim_fabric", Color(0.8, 0.9, 1.2), 1.2)
		"dog_bed": m = _tex_mat("denim_fabric", Color(1.3, 0.75, 0.45), 2.0)
		"roof": m = _plain(Color(0.22, 0.24, 0.23), 0.7, 0.3)
		"stone": m = _plain(Color(0.45, 0.43, 0.4), 0.85, 0.0)
		"ash": m = _plain(Color(0.16, 0.15, 0.14), 1.0, 0.0)
		"char": m = _plain(Color(0.06, 0.05, 0.04), 0.9, 0.0)
		"glass": m = _glass()
		"chainlink": m = _chainlink()
		"lamp_bulb": m = _emissive(Color(1.0, 0.82, 0.55), 6.0)
		"screen": m = _plain(Color(0.02, 0.02, 0.03), 0.2, 0.0)
		_: m = _plain(Color(1, 0, 1), 0.5, 0.0)
	_mats[name] = m
	return m


static func _plain(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func _tex_mat(tex: String, tint: Color, scale: float) -> StandardMaterial3D:
	return _tex_mat_path("res://assets/polyhaven/textures/%s/%s" % [tex, tex], tint, scale)


static func _tex_mat_path(base: String, tint: Color, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base + "_diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "_nor_gl.jpg")
	m.roughness_texture = load(base + "_arm.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.ao_enabled = true
	m.ao_texture = load(base + "_arm.jpg")
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _glass() -> StandardMaterial3D:
	# Readable both ways: low alpha, low reflectance, no mirror at night.
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.85, 0.88, 0.12)
	m.roughness = 0.06
	m.metallic_specular = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _chainlink() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/chainlink.gdshader")
	return m


# ------------------------------------------------------------ geometry

static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Variant, collide := true, rot_y := 0.0, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(material) if material is String else material
	mi.position = pos
	mi.rotation.y = rot_y
	if name != "":
		mi.name = name
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Variant, collide := true, sides := 12, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(material) if material is String else material
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = maxf(radius, cm.top_radius)
		shape.height = height
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Wall along local +X from `origin`, length L, with rectangular openings
## [x0, x1, y0, y1] (doors start at y0 = 0). Built from solid segments.
static func wall(parent: Node3D, origin: Vector3, rot_y: float, length: float, height: float, thickness: float, openings: Array, material: Variant, collide := true) -> Node3D:
	var w := Node3D.new()
	w.position = origin
	w.rotation.y = rot_y
	parent.add_child(w)
	var xs: Array = [0.0, length]
	for o in openings:
		xs.append(o[0])
		xs.append(o[1])
	xs.sort()
	# Vertical strips between consecutive x stops; inside an opening only
	# the parts above/below it are solid.
	for k in xs.size() - 1:
		var a: float = xs[k]
		var b: float = xs[k + 1]
		if b - a < 0.001:
			continue
		var mid := (a + b) * 0.5
		var hole: Array = []
		for o in openings:
			if mid > o[0] and mid < o[1]:
				hole = o
		if hole.is_empty():
			box(w, Vector3(b - a, height, thickness), Vector3(mid, height * 0.5, 0), material, collide)
		else:
			if hole[2] > 0.001:
				box(w, Vector3(b - a, hole[2], thickness), Vector3(mid, hole[2] * 0.5, 0), material, collide)
			if hole[3] < height - 0.001:
				box(w, Vector3(b - a, height - hole[3], thickness), Vector3(mid, (hole[3] + height) * 0.5, 0), material, collide)
	return w


static func window_glass(parent: Node3D, origin: Vector3, rot_y: float, opening: Array, thickness: float) -> void:
	var g := Node3D.new()
	g.position = origin
	g.rotation.y = rot_y
	parent.add_child(g)
	var w: float = opening[1] - opening[0]
	var h: float = opening[3] - opening[2]
	box(g, Vector3(w, h, 0.01), Vector3((opening[0] + opening[1]) * 0.5, (opening[2] + opening[3]) * 0.5, 0), "glass", true)
	# Frame
	var fr := 0.04
	box(g, Vector3(w + fr * 2, fr, thickness + 0.02), Vector3((opening[0] + opening[1]) * 0.5, opening[2] - fr * 0.5, 0), "dark_wood", false)
	box(g, Vector3(w + fr * 2, fr, thickness + 0.02), Vector3((opening[0] + opening[1]) * 0.5, opening[3] + fr * 0.5, 0), "dark_wood", false)
	box(g, Vector3(fr, h, thickness + 0.02), Vector3(opening[0] - fr * 0.5, (opening[2] + opening[3]) * 0.5, 0), "dark_wood", false)
	box(g, Vector3(fr, h, thickness + 0.02), Vector3(opening[1] + fr * 0.5, (opening[2] + opening[3]) * 0.5, 0), "dark_wood", false)
	box(g, Vector3(fr * 0.6, h, 0.03), Vector3((opening[0] + opening[1]) * 0.5, (opening[2] + opening[3]) * 0.5, 0), "dark_wood", false)


## Invisible ramp collision (for steps the CharacterBody can climb).
static func ramp(parent: Node3D, from: Vector3, to: Vector3, width: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var d := to - from
	var length := d.length()
	shape.size = Vector3(width, 0.1, length)
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	var mid := (from + to) * 0.5 - Vector3(0, 0.05, 0)
	body.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), mid)


## Instances a CC0 Poly Haven glTF prop. Returns null (with a visible
## substitute box) if the asset is missing.
static func prop(parent: Node3D, asset: String, pos: Vector3, rot_y := 0.0, scale := 1.0, collide_box := Vector3.ZERO, name := "") -> Node3D:
	var path := PH % [asset, asset]
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	var n: Node3D
	if scene:
		n = scene.instantiate()
	else:
		n = Node3D.new()
		box(n, Vector3(0.4, 0.4, 0.4), Vector3(0, 0.2, 0), "camper_stripe", false)
		push_warning("Missing prop asset %s (substitute shown)" % asset)
	n.name = name if name != "" else asset
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	if collide_box != Vector3.ZERO:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = collide_box / scale
		cs.shape = shape
		cs.position = Vector3(0, collide_box.y * 0.5 / scale, 0)
		body.add_child(cs)
		n.add_child(body)
	return n


static func marker(parent: Node3D, name: String, pos: Vector3, rot_y := 0.0, group := "") -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	m.rotation.y = rot_y
	parent.add_child(m)
	if group != "":
		m.add_to_group(group)
	return m
