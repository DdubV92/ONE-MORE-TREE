class_name UndergrowthSystem
extends Node3D
## Phase 12: the authored, persistent undergrowth of island r2 (World.shrubs):
## hazel and bramble (forest edges, thickets), juniper (dry open ground),
## bracken (shade and damp), sedge (wet margins) and fallen deadwood. None of
## it is a native tree, harvestable or counted by the contract; it stays
## after logging, so cleared land reads as shrubby ground, not grey earth.
##
## Rendering: 64 m chunks, one MultiMesh per kind, kind-specific visibility
## ranges with fade (no per-plant scripts or colliders). Quality presets thin
## only scattered decorative plants; thicket members (soft concealment the
## AI uses) are never thinned, so a low preset never removes visible cover
## the Foreman still "sees".

const CHUNK := 64.0
const RANGES := [150.0, 140.0, 120.0, 70.0, 60.0, 45.0]
const SHADOWS := [true, true, false, false, false, false]
const NAMES := ["hazel", "juniper", "bramble", "bracken", "sedge", "deadfall"]

var meshes: Array = []
var density := 1.0
var protected := PackedByteArray()     # 1 = thicket member (never thinned)
var _chunks := {}                      # Vector2i -> Array[int] of shrub idx
var _nodes := {}                       # Vector2i -> Node3D
var instance_count := 0


func build() -> void:
	if World.shrubs.is_empty():
		return
	_make_meshes()
	var xs: PackedFloat32Array = World.shrubs.x
	var zs: PackedFloat32Array = World.shrubs.z
	protected.resize(xs.size())
	var thickets: Array = World.cover.get("thickets", [])
	for i in xs.size():
		var p := Vector2(xs[i], zs[i])
		for t in thickets:
			if p.distance_to(Vector2(t.center[0], t.center[1])) <= float(t.radius) + 0.5:
				protected[i] = 1
				break
		var c := Vector2i(int(floor(xs[i] / CHUNK)), int(floor(zs[i] / CHUNK)))
		if not _chunks.has(c):
			_chunks[c] = []
		(_chunks[c] as Array).append(i)
	for c in _chunks:
		_build_chunk(c)


func set_density(d: float) -> void:
	if is_equal_approx(d, density) or World.shrubs.is_empty():
		return
	density = d
	for c in _chunks:
		_build_chunk(c)


func _build_chunk(c: Vector2i) -> void:
	if _nodes.has(c):
		instance_count -= int((_nodes[c] as Node).get_meta("count", 0))
		(_nodes[c] as Node).queue_free()
	var node := Node3D.new()
	node.name = "Undergrowth_%d_%d" % [c.x, c.y]
	node.position = Vector3((c.x + 0.5) * CHUNK, 0.0, (c.y + 0.5) * CHUNK)
	add_child(node)
	_nodes[c] = node
	var by_kind := [[], [], [], [], [], []]
	for i in (_chunks[c] as Array):
		var sd: int = World.shrubs.seed[i]
		if protected[i] == 0 and float(sd % 1000) / 1000.0 >= density:
			continue
		by_kind[int(World.shrubs.kind[i])].append(i)
	var n := 0
	for k in 6:
		var list: Array = by_kind[k]
		if list.is_empty() or meshes[k] == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[k]
		mm.instance_count = list.size()
		for j in list.size():
			var i: int = list[j]
			mm.set_instance_transform(j, shrub_transform(i).translated(-node.position))
			var sd: int = World.shrubs.seed[i]
			mm.set_instance_custom_data(j, Color(float(sd & 255) / 255.0, float((sd >> 8) & 255) / 255.0, 1.6, 0.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = NAMES[k]
		mmi.multimesh = mm
		mmi.visibility_range_end = RANGES[k]
		mmi.visibility_range_end_margin = 12.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if SHADOWS[k] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
		n += list.size()
	node.set_meta("count", n)
	instance_count += n


static func shrub_transform(i: int) -> Transform3D:
	var x: float = World.shrubs.x[i]
	var z: float = World.shrubs.z[i]
	var s: float = World.shrubs.scale[i]
	var k: int = World.shrubs.kind[i]
	var y := World.grounded_base_y(x, z, 0.3 * s, 0.04)
	var basis := Basis(Vector3.UP, World.shrubs.rot[i]).scaled(Vector3(s, s * (0.9 + 0.2 * float(int(World.shrubs.seed[i]) % 7) / 6.0), s))
	if k == 5:
		basis = Basis(Vector3.UP, World.shrubs.rot[i]).scaled(Vector3.ONE * (0.8 + 0.4 * (s - 0.75)))
	return Transform3D(basis, Vector3(x, y, z))


## Visible crown height (m) of a shrub instance (used by soft cover).
static func crown_height(i: int) -> float:
	return [2.3, 1.3, 1.0, 0.9, 1.0, 0.35][int(World.shrubs.kind[i])] * float(World.shrubs.scale[i])


static func crown_radius(i: int) -> float:
	return [1.0, 0.8, 1.2, 0.6, 0.35, 0.6][int(World.shrubs.kind[i])] * float(World.shrubs.scale[i])


# ------------------------------------------------------------------ assets

func _make_meshes() -> void:
	var leaf_shader: Shader = load("res://shaders/tree_foliage.gdshader")
	var mk_leaf := func(card: String, tint: Color, cut: float, flutter: float) -> ShaderMaterial:
		var m := ShaderMaterial.new()
		m.shader = leaf_shader
		m.set_shader_parameter("card_albedo", load("res://assets/generated/foliage/%s.png" % card))
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("alpha_cut", cut)
		m.set_shader_parameter("flutter", flutter)
		return m
	var bark: Material = null
	if Game.vegetation and Game.vegetation.materials.has("bark"):
		bark = Game.vegetation.materials.bark[1]
	var hazel_leaf: ShaderMaterial = mk_leaf.call("birch_card", Color(0.62, 0.78, 0.48), 0.4, 0.06)
	var bramble_leaf: ShaderMaterial = mk_leaf.call("birch_card", Color(0.46, 0.55, 0.34), 0.36, 0.03)
	var juniper_leaf: ShaderMaterial = mk_leaf.call("spruce_card", Color(0.55, 0.72, 0.6), 0.33, 0.02)
	meshes = [
		_shrub_mesh(0, hazel_leaf, bark),
		_shrub_mesh(1, juniper_leaf, bark),
		_shrub_mesh(2, bramble_leaf, bark),
		_scaled_scene_mesh("fern_02", 1.7),
		_sedge_mesh(),
		_scaled_scene_mesh("dry_branches_medium_01", 1.0),
	]


func _shrub_mesh(kind: int, leaf: Material, bark: Material) -> ArrayMesh:
	var b := TreeBuilder.new()
	var stb := SurfaceTool.new()
	stb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stl := SurfaceTool.new()
	stl.begin(Mesh.PRIMITIVE_TRIANGLES)
	b.set("_bark", stb)
	b.set("_leaf", stl)
	var rng: RandomNumberGenerator = b.get("_rng")
	rng.seed = 4400 + kind * 17
	match kind:
		0:
			# Hazel: several slim stems from one root crown, leafy dome.
			b.set("_crown_center", Vector3(0, 1.5, 0))
			for s in 6:
				var a := TAU * s / 6.0 + rng.randf_range(-0.3, 0.3)
				var top := Vector3(cos(a) * rng.randf_range(0.5, 0.9), rng.randf_range(1.9, 2.4), sin(a) * rng.randf_range(0.5, 0.9))
				var pts: Array[Vector3] = [Vector3(cos(a) * 0.05, 0, sin(a) * 0.05), top * Vector3(0.5, 0.55, 0.5), top]
				var rr: Array[float] = [0.035, 0.025, 0.012]
				b.call("_tube", pts, rr, 5, 0.6)
			for k in 11:
				var p := Vector3(rng.randf_range(-0.85, 0.85), rng.randf_range(0.9, 2.1), rng.randf_range(-0.85, 0.85))
				b.call("_ball", p, rng.randf_range(0.8, 1.05), 2)
		1:
			# Juniper: low spreading conifer of upward sprays.
			b.set("_crown_center", Vector3(0, 0.6, 0))
			for k in 14:
				var a := TAU * k / 14.0 + rng.randf_range(-0.2, 0.2)
				var out := Vector3(cos(a), 0, sin(a))
				var along := (out + Vector3.UP * rng.randf_range(0.6, 1.4)).normalized()
				var side := out.cross(Vector3.UP).normalized()
				b.call("_card", out * 0.1, along, side, rng.randf_range(0.9, 1.4), rng.randf_range(0.55, 0.8), 1.0, true)
			for k in 4:
				var p := Vector3(rng.randf_range(-0.3, 0.3), 0.7 + k * 0.12, rng.randf_range(-0.3, 0.3))
				b.call("_ball", p, 0.7, 2)
		_:
			# Bramble: a wide low mound of leaves over arching canes.
			b.set("_crown_center", Vector3(0, 0.4, 0))
			for s in 7:
				var a := TAU * s / 7.0 + rng.randf_range(-0.3, 0.3)
				var out := Vector3(cos(a), 0, sin(a))
				var pts: Array[Vector3] = [out * 0.1, out * 0.6 + Vector3(0, 0.85, 0), out * 1.3 + Vector3(0, 0.2, 0)]
				var rr: Array[float] = [0.014, 0.011, 0.006]
				b.call("_tube", pts, rr, 4, 0.4)
			for k in 12:
				var a := rng.randf() * TAU
				var r := sqrt(rng.randf()) * 1.05
				var p := Vector3(cos(a) * r, rng.randf_range(0.3, 0.75) * (1.0 - r * 0.35), sin(a) * r)
				b.call("_ball", p, rng.randf_range(0.65, 0.85), 2)
	var mesh := ArrayMesh.new()
	var has_bark := kind != 1        # juniper is all foliage sprays
	if has_bark:
		stb.generate_tangents()
		stb.commit(mesh)
		mesh.surface_set_material(0, bark if bark else BuildKit.mat("dark_wood"))
	stl.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, leaf)
	return mesh


func _scaled_scene_mesh(asset: String, s: float) -> Mesh:
	var scene: PackedScene = load("res://assets/polyhaven/models/%s/%s_1k.gltf" % [asset, asset])
	if scene == null:
		return null
	var n := scene.instantiate()
	var src: Mesh = _first_mesh(n)
	n.free()
	if src == null or is_equal_approx(s, 1.0):
		return src
	# Bake the scale into a copy (MultiMesh transforms carry per-plant size).
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for k in v.size():
			v[k] *= s
		arr[Mesh.ARRAY_VERTEX] = v
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, src.surface_get_material(si))
	return out


static func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null


func _sedge_mesh() -> Mesh:
	var gc: GDScript = load("res://scripts/vegetation/ground_cover.gd")
	var m: ArrayMesh = gc.call("_blade_tuft", 16, 1.0, 0.035, 61)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mat.set_shader_parameter("base_color", Color(0.16, 0.2, 0.08))
	mat.set_shader_parameter("tip_color", Color(0.5, 0.5, 0.26))
	mat.set_shader_parameter("sway", 0.16)
	m.surface_set_material(0, mat)
	return m
