extends Node3D
## Streams non-harvestable ground cover (grass tufts, ferns, bushes, reeds,
## dune grass, beach pebbles) in 32 m cells around the camera, a few cells per
## frame. Density follows terrain masks, canopy shade, trails and dampness.
## Nothing here is a harvestable tree; trees live only in VegetationSystem.

const CELL := 32.0
const RADIUS := 3          # cells (~96 m)
const BUILD_PER_FRAME := 1

var density := 1.0
var _cells := {}           # Vector2i -> Node3D
var _queue: Array[Vector2i] = []
var _meshes := {}
var _materials := {}
var _tree_hash := {}       # 8 m buckets of tree positions for shade/clearance
var _last_center := Vector2i(999999, 999999)


func _ready() -> void:
	World.ensure_loaded()
	_make_assets()
	_hash_trees()


func set_density(d: float) -> void:
	if is_equal_approx(d, density):
		return
	density = d
	for c in _cells.values():
		(c as Node).queue_free()
	_cells.clear()
	_last_center = Vector2i(999999, 999999)


func _hash_trees() -> void:
	var xs: PackedFloat32Array = World.trees.x
	var zs: PackedFloat32Array = World.trees.z
	for i in xs.size():
		var k := Vector2i(int(floor(xs[i] / 8.0)), int(floor(zs[i] / 8.0)))
		if not _tree_hash.has(k):
			_tree_hash[k] = []
		(_tree_hash[k] as Array).append(i)


func _shade_and_clear(x: float, z: float) -> Vector2:
	## Returns (canopy shade 0..1, distance to nearest trunk).
	var k := Vector2i(int(floor(x / 8.0)), int(floor(z / 8.0)))
	var shade := 0.0
	var nearest := 99.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var list: Variant = _tree_hash.get(k + Vector2i(dx, dz))
			if list == null:
				continue
			for i in (list as Array):
				if World.removed_trees.has(int(World.trees.id[i])):
					continue
				var d := Vector2(x - World.trees.x[i], z - World.trees.z[i]).length()
				nearest = minf(nearest, d)
				shade += clampf(1.0 - d / 6.0, 0.0, 1.0) * 0.5
	return Vector2(clampf(shade, 0.0, 1.0), nearest)


# ---------------------------------------------------------------- assets

func _make_assets() -> void:
	var grass_shader: Shader = load("res://shaders/grass.gdshader")
	var mk := func(col_base: Color, col_tip: Color, sway: float) -> ShaderMaterial:
		var m := ShaderMaterial.new()
		m.shader = grass_shader
		m.set_shader_parameter("base_color", col_base)
		m.set_shader_parameter("tip_color", col_tip)
		m.set_shader_parameter("sway", sway)
		return m
	_materials["grass"] = mk.call(Color(0.2, 0.23, 0.09), Color(0.44, 0.5, 0.22), 0.12)
	_materials["dune"] = mk.call(Color(0.32, 0.33, 0.18), Color(0.72, 0.68, 0.45), 0.2)
	_materials["reed"] = mk.call(Color(0.17, 0.22, 0.09), Color(0.55, 0.52, 0.3), 0.18)
	_meshes["grass"] = _blade_tuft(14, 0.45, 0.07, 11)
	_meshes["dune"] = _blade_tuft(10, 0.7, 0.05, 23)
	_meshes["reed"] = _blade_tuft(9, 1.7, 0.04, 37)
	# Fern: CC0 Poly Haven fern_02 model (uses its own textures)
	var fern_scene: PackedScene = load("res://assets/polyhaven/models/fern_02/fern_02_1k.gltf")
	_meshes["fern"] = _first_mesh(fern_scene.instantiate()) if fern_scene else null
	# Bush: birch-leaf card clusters (cheap, matches tree foliage)
	_meshes["bush"] = _bush_mesh()
	var leaf := ShaderMaterial.new()
	leaf.shader = load("res://shaders/tree_foliage.gdshader")
	leaf.set_shader_parameter("card_albedo", load("res://assets/generated/foliage/birch_card.png"))
	leaf.set_shader_parameter("tint", Color(0.75, 0.85, 0.6))
	leaf.set_shader_parameter("flutter", 0.03)
	(_meshes["bush"] as ArrayMesh).surface_set_material(0, leaf)
	var rocks := RockBuilder.build_variants(2)
	_meshes["pebble"] = rocks[0]
	(_meshes["pebble"] as ArrayMesh).surface_set_material(0, RockBuilder.material())


static func _first_mesh(n: Node) -> Mesh:
	var found: Mesh = null
	if n is MeshInstance3D:
		found = (n as MeshInstance3D).mesh
	else:
		for c in n.get_children():
			found = _first_mesh(c)
			if found:
				break
	return found


static func _blade_tuft(blades: int, height: float, width: float, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in blades:
		var a := rng.randf() * TAU
		var r := rng.randf() * 0.12
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var h := height * rng.randf_range(0.6, 1.15)
		var lean := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.05, 0.35) * h
		var side := Vector3(-sin(a + 1.3), 0.0, cos(a + 1.3)) * width * rng.randf_range(0.7, 1.2)
		var mid := base + lean * 0.35 + Vector3(0, h * 0.55, 0)
		var tip := base + lean + Vector3(0, h, 0)
		var n := side.cross(tip - base).normalized()
		if n.y < 0.0:
			n = -n
		n = (n + Vector3.UP * 0.8).normalized()
		var verts := [[base - side, 0.0], [base + side, 0.0], [mid + side * 0.6, 0.55], [mid - side * 0.6, 0.55], [tip, 1.0]]
		var tris := [[0, 1, 2], [0, 2, 3], [3, 2, 4]]
		for t in tris:
			for vi in t:
				var v: Array = verts[vi]
				st.set_normal(n)
				st.set_color(Color(v[1], rng.randf(), 0.0))
				st.set_uv(Vector2(0.5, 1.0 - v[1]))
				st.add_vertex(v[0])
	return st.commit()


func _bush_mesh() -> ArrayMesh:
	var b := TreeBuilder.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	b.set("_leaf", st)
	b.set("_crown_center", Vector3(0, 0.6, 0))
	var rng: RandomNumberGenerator = b.get("_rng")
	rng.seed = 77
	for k in 7:
		var p := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.35, 1.0), rng.randf_range(-0.6, 0.6))
		b.call("_ball", p, rng.randf_range(0.8, 1.1), 2)
	return st.commit()


# -------------------------------------------------------------- streaming

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var center := Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))
	if center != _last_center:
		_last_center = center
		_refresh(center)
	var n := 0
	while n < BUILD_PER_FRAME and not _queue.is_empty():
		var c: Vector2i = _queue.pop_front()
		if not _cells.has(c) and (c - _last_center).length() <= RADIUS + 0.5:
			_cells[c] = _build_cell(c)
		n += 1


func force_build_around(p: Vector3) -> void:
	var center := Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))
	_last_center = center
	_refresh(center)
	while not _queue.is_empty():
		var c: Vector2i = _queue.pop_front()
		if not _cells.has(c):
			_cells[c] = _build_cell(c)


func _refresh(center: Vector2i) -> void:
	for c in _cells.keys():
		if (c - center).length() > RADIUS + 1.5:
			(_cells[c] as Node).queue_free()
			_cells.erase(c)
	var want: Array[Vector2i] = []
	for dz in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var c := center + Vector2i(dx, dz)
			if Vector2(dx, dz).length() <= RADIUS + 0.5 and not _cells.has(c):
				want.append(c)
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - center).length_squared() < (b - center).length_squared())
	_queue = want


func _build_cell(c: Vector2i) -> Node3D:
	var node := Node3D.new()
	node.name = "Cover_%d_%d" % [c.x, c.y]
	node.position = Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, 991))
	var lists := {"grass": [], "dune": [], "reed": [], "fern": [], "bush": [], "pebble": []}
	var x0 := c.x * CELL
	var z0 := c.y * CELL
	var samples := int(520 * density)
	for s in samples:
		var x := x0 + rng.randf() * CELL
		var z := z0 + rng.randf() * CELL
		if not World.in_bounds(Vector2(x, z)):
			continue
		var h := World.height_at(x, z)
		var wl := World.water_level_at(x, z)
		var region := World.water_region_at(x, z)
		var m := World.masks_at(x, z)
		var r := rng.randf()
		# Reeds at inland water edges
		if region != 0 and h > wl - 0.35 and h < wl + 0.5:
			if r < 0.7:
				lists.reed.append(_xf(rng, x, h - 0.05, z, 0.8, 1.2))
			continue
		if h < wl + 0.05:
			continue
		if h < World.sea_level + 1.4:
			if m.x > 0.5 and r < 0.06:
				lists.pebble.append(_xf(rng, x, h - 0.03, z, 0.05, 0.14))
			continue
		if m.z > 0.45 or m.w > 0.6:
			continue
		var n := World.normal_at(x, z)
		if n.y < 0.75:
			continue
		var sc := _shade_and_clear(x, z)
		if sc.y < 0.45:
			continue
		if m.x > 0.4:
			# Upper beach: sparse dune grass
			if h > 1.8 and r < 0.35 * (m.x):
				lists.dune.append(_xf(rng, x, h, z, 0.8, 1.3))
			continue
		var shade := sc.x
		var damp := clampf(1.0 - (h - wl) / 3.0, 0.0, 1.0) if region != 0 else 0.0
		var p_grass := (1.0 - shade * 0.85) * (1.0 - m.y * 0.6) + damp * 0.3
		var p_fern := (m.y * 0.25 + shade * 0.25 + damp * 0.4) * (1.0 if h < 30.0 else 0.3)
		# Bushes gather at forest edges and under thin canopy, not mid-meadow.
		var p_bush := 0.004 + m.y * 0.035 * (1.0 - shade * 0.5)
		var t := rng.randf() * (p_grass + p_fern + p_bush + 0.6)
		if t < p_grass:
			# A small clump of tufts per accepted sample (dense but cheap).
			for k in 1 + int(rng.randf() * 4.0 * (1.0 - shade)):
				var gx := x + rng.randf_range(-0.7, 0.7)
				var gz := z + rng.randf_range(-0.7, 0.7)
				lists.grass.append(_xf(rng, gx, World.height_at(gx, gz), gz, 0.7, 1.3))
		elif t < p_grass + p_fern * 0.35:
			lists.fern.append(_xf(rng, x, h, z, 0.55, 1.0))
		elif t < p_grass + p_fern * 0.35 + p_bush:
			lists.bush.append(_xf(rng, x, h - 0.1, z, 0.8, 1.4))
	for kind in lists:
		var arr: Array = lists[kind]
		if arr.is_empty() or _meshes.get(kind) == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[kind]
		mm.use_custom_data = kind == "bush"
		mm.instance_count = arr.size()
		for k in arr.size():
			mm.set_instance_transform(k, (arr[k] as Transform3D).translated(-node.position))
			if kind == "bush":
				mm.set_instance_custom_data(k, Color(rng.randf(), rng.randf(), 1.2, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if kind in ["grass", "dune", "reed"]:
			mmi.material_override = _materials[kind]
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			# Low cover: shadows only for bushes (they read as volumes).
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind == "bush" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = {"grass": 48.0, "dune": 60.0, "reed": 90.0, "fern": 50.0, "bush": 110.0, "pebble": 35.0}[kind]
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(mmi)
	return node


static func _xf(rng: RandomNumberGenerator, x: float, y: float, z: float, smin: float, smax: float) -> Transform3D:
	var s := rng.randf_range(smin, smax)
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.15), s))
	return Transform3D(b, Vector3(x, y, z))


func cell_count() -> int:
	return _cells.size()
