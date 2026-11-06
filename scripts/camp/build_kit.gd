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
		"denim": m = _fabric("denim_fabric", Color(0.25, 0.33, 0.5), 1.5)
		# Phase 12: proper soft furnishings (Poly Haven CC0 scans, neutral-grey
		# versions tinted per use; see tools/bake_fabrics.py).
		"upholstery": m = _fabric("poly_wool_herringbone", Color(0.36, 0.38, 0.33), 0.6)
		"chair_vinyl": m = _fabric("fabric_leather_02", Color(0.13, 0.13, 0.14), 0.5, 0.45)
		"sheet": m = _fabric("stretch_poplin", Color(0.86, 0.85, 0.8), 0.5)
		"pillow": m = _fabric("stretch_poplin", Color(0.9, 0.88, 0.82), 0.4)
		"curtain_linen": m = _fabric("rough_linen", Color(0.74, 0.68, 0.56), 0.7)
		"shower_vinyl": m = _vinyl(Color(0.78, 0.86, 0.88, 0.9))
		"towel": m = _fabric("knitted_fleece", Color(0.82, 0.8, 0.74), 0.35)
		"picnic_check": m = _tex_mat("gingham_check", Color(1, 1, 1), 0.6)
		"mug_enamel": m = _plain(Color(0.86, 0.85, 0.8), 0.25, 0.0)
		"mug_blue": m = _plain(Color(0.2, 0.34, 0.5), 0.25, 0.0)
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
		"blanket_red": m = _fabric("caban", Color(0.5, 0.13, 0.11), 1.0)
		"blanket_green": m = _fabric("caban", Color(0.2, 0.3, 0.2), 1.0)
		"blanket_ochre": m = _fabric("caban", Color(0.6, 0.45, 0.2), 1.0)
		"blanket_blue": m = _fabric("caban", Color(0.2, 0.27, 0.4), 1.0)
		"dog_bed": m = _fabric("polar_fleece", Color(0.55, 0.4, 0.28), 0.6)
		"roof": m = _plain(Color(0.22, 0.24, 0.23), 0.7, 0.3)
		"stone": m = _plain(Color(0.45, 0.43, 0.4), 0.85, 0.0)
		"ash": m = _plain(Color(0.16, 0.15, 0.14), 1.0, 0.0)
		"char": m = _plain(Color(0.06, 0.05, 0.04), 0.9, 0.0)
		"glass": m = _glass()
		"glass_dry": m = _glass_dry()
		"chainlink": m = _chainlink()
		"lamp_bulb": m = _emissive(Color(1.0, 0.82, 0.55), 6.0)
		"screen": m = _plain(Color(0.02, 0.02, 0.03), 0.2, 0.0)
		_: m = _plain(Color(1, 0, 1), 0.5, 0.0)
	_mats[name] = m
	return m


## Neutral-grey Poly Haven fabric scan tinted to `col` (mean albedo = col),
## with the scan's own normal and AO/roughness maps.
static func _fabric(tex: String, col: Color, scale: float, rough_mult := 1.0) -> StandardMaterial3D:
	var base := "res://assets/polyhaven/textures/%s/%s" % [tex, tex]
	var m := _tex_mat_path(base, Color(1, 1, 1), scale)
	m.albedo_texture = load("res://assets/generated/fabrics/%s_grey.jpg" % tex)
	m.albedo_color = Color(minf(col.r * 2.0, 2.0), minf(col.g * 2.0, 2.0), minf(col.b * 2.0, 2.0))
	if rough_mult != 1.0:
		m.roughness = rough_mult
	return m


## Thin vinyl (shower curtain): soft sheen, faintly translucent, two-sided.
static func _vinyl(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.32
	m.metallic_specular = 0.45
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.backlight_enabled = true
	m.backlight = Color(0.25, 0.28, 0.3)
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


static func _glass() -> Material:
	# Readable both ways: low alpha, low reflectance, no mirror at night.
	# Phase 23: the same glass beads up and runs in rain (glass_rain shader).
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/glass_rain.gdshader")
	m.set_shader_parameter("tint", Color(0.75, 0.85, 0.88, 0.12))
	return m


## Phase 23: exterior camp materials soak in rain: darker, glossier (logs,
## siding, decking, roofs, paint, galvanized metal). Interior materials are
## never touched. Called by WeatherService a few times a second at most.
const WET_MATS := ["siding", "planks", "dark_wood", "bark", "roof", "camper_paint", "camper_stripe", "galvanized"]
static var _wet_base := {}
static var wet_applied := 0.0

static func apply_wetness(w: float) -> void:
	if absf(w - wet_applied) < 0.02:
		return
	wet_applied = w
	for n in WET_MATS:
		var m := _mats.get(n) as StandardMaterial3D
		if m == null:
			continue
		if not _wet_base.has(n):
			_wet_base[n] = [m.albedo_color, m.roughness]
		var b: Array = _wet_base[n]
		m.albedo_color = (b[0] as Color).darkened(0.32 * w)
		m.roughness = lerpf(float(b[1]), minf(float(b[1]), 0.28), w)


## Interior glass (mirrors, shower screen, a cup): never rained on.
static func _glass_dry() -> StandardMaterial3D:
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
		# Phase 15: acoustic class of what this part is made of (occlusion).
		body.set_meta("acoustic", acoustic_of(material))
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Phase 15: build material -> acoustic class for SoundService occlusion.
static func acoustic_of(material: Variant) -> String:
	var n := str(material) if material is String else ""
	if n.contains("glass") or n.contains("window"):
		return "glass"
	if n.contains("steel") or n.contains("metal") or n.contains("camper_paint") or n.contains("chrome") or n.contains("fence"):
		return "metal"
	if n.contains("rock") or n.contains("stone") or n.contains("concrete"):
		return "rock"
	if n.contains("fabric") or n.contains("canvas") or n.contains("curtain") or n.contains("blanket"):
		return "fabric"
	return "wood"


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


## Merges static primitive meshes under `root` into one mesh per material to
## cut draw calls. Collision bodies stay on the original nodes (their mesh is
## cleared, the node and its StaticBody remain). Moving parts (doors, anything
## under an AnimatableBody3D) and non-primitive meshes are left untouched.
static func batch_static(root: Node3D) -> int:
	var groups := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Door or n is AnimatableBody3D or n is GPUParticles3D or n.has_meta("no_batch"):
			continue
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var m := mi.mesh
			if m and mi.material_override and (m is BoxMesh or m is CylinderMesh or m is QuadMesh or m is TorusMesh) and mi.visible:
				var key := mi.material_override.get_rid()
				if not groups.has(key):
					groups[key] = {"mat": mi.material_override, "items": [], "shadow": mi.cast_shadow}
				groups[key].items.append(mi)
		for c in n.get_children():
			stack.append(c)
	var merged := 0
	var inv := root.global_transform.affine_inverse()
	for key in groups:
		var g: Dictionary = groups[key]
		if g.items.size() < 2:
			continue
		var st := SurfaceTool.new()
		for mi in g.items:
			st.append_from((mi as MeshInstance3D).mesh, 0, inv * (mi as MeshInstance3D).global_transform)
		var out := MeshInstance3D.new()
		out.name = "Batched_%d" % merged
		out.mesh = st.commit()
		out.material_override = g.mat
		out.cast_shadow = g.shadow
		root.add_child(out)
		for mi in g.items:
			(mi as MeshInstance3D).mesh = null
		merged += g.items.size()
	return merged
