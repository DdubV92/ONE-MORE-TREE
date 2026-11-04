class_name VegetationSystem
extends Node3D
## Harvestable trees (12k, stable IDs) and rocks.
## - Rendering: per 128 m chunk MultiMeshes, one per species/variant, with
##   near (detailed cards) / mid (fewer cards) / far (solid silhouette) LODs
##   cross-faded by visibility ranges. No scripts per tree.
## - Collision: trunk cylinders exist only in 32 m cells near the player.
## - Removal by ID rebuilds just the owning chunk (Phase 1 felling hook).

const COLLISION_CELL := 32.0
const COLLISION_RADIUS_CELLS := 2

var meshes: Dictionary
var materials := {}
var chunk_nodes := {}          # chunk id -> Node3D
var chunk_trees := {}          # chunk id -> PackedInt32Array of tree indices
var tree_index_by_id := {}     # tree id -> index (identity today, kept explicit)
var _collision_cells := {}     # Vector2i -> StaticBody3D
var _tree_cells := {}          # Vector2i -> PackedInt32Array
var _last_cell := Vector2i(999999, 999999)
var near_range := 170.0
var mid_range := 560.0
var rock_bodies := 0
var shadows_mid := false


func build() -> void:
	World.ensure_loaded()
	meshes = TreeBuilder.build_all()
	_make_materials()
	_assign_materials()
	_index_trees()
	for chunk in chunk_trees:
		_build_chunk(chunk)
	World.tree_removed.connect(_on_tree_removed)
	World.tree_restored.connect(_on_tree_removed)
	_build_rocks()


func _make_materials() -> void:
	var bark_shader: Shader = load("res://shaders/tree_bark.gdshader")
	var leaf_shader: Shader = load("res://shaders/tree_foliage.gdshader")
	var far_shader: Shader = load("res://shaders/tree_far.gdshader")
	var pine_bark := ShaderMaterial.new()
	pine_bark.shader = bark_shader
	pine_bark.set_shader_parameter("bark_albedo", load("res://assets/polyhaven/textures/pine_bark/pine_bark_diff.jpg"))
	pine_bark.set_shader_parameter("bark_normal", load("res://assets/polyhaven/textures/pine_bark/pine_bark_nor_gl.jpg"))
	pine_bark.set_shader_parameter("bark_arm", load("res://assets/polyhaven/textures/pine_bark/pine_bark_arm.jpg"))
	pine_bark.set_shader_parameter("tint", Color(1.0, 0.9, 0.82))
	var spruce_bark := ShaderMaterial.new()
	spruce_bark.shader = bark_shader
	spruce_bark.set_shader_parameter("bark_albedo", load("res://assets/polyhaven/textures/bark_brown_02/bark_brown_02_diff.jpg"))
	spruce_bark.set_shader_parameter("bark_normal", load("res://assets/polyhaven/textures/bark_brown_02/bark_brown_02_nor_gl.jpg"))
	spruce_bark.set_shader_parameter("bark_arm", load("res://assets/polyhaven/textures/bark_brown_02/bark_brown_02_arm.jpg"))
	spruce_bark.set_shader_parameter("tint", Color(0.8, 0.72, 0.66))
	var birch_bark := ShaderMaterial.new()
	birch_bark.shader = bark_shader
	birch_bark.set_shader_parameter("birch", true)
	var cards := ["pine_card", "spruce_card", "birch_card"]
	var tints := [Color(0.82, 0.92, 0.7), Color(0.8, 0.95, 0.85), Color(0.92, 1.0, 0.72)]
	var leaf_mats := []
	for i in 3:
		var m := ShaderMaterial.new()
		m.shader = leaf_shader
		m.set_shader_parameter("card_albedo", load("res://assets/generated/foliage/%s.png" % cards[i]))
		m.set_shader_parameter("tint", tints[i])
		m.set_shader_parameter("alpha_cut", 0.38 if i != 1 else 0.33)
		m.set_shader_parameter("flutter", 0.03 if i != 2 else 0.07)
		leaf_mats.append(m)
	var far_mat := ShaderMaterial.new()
	far_mat.shader = far_shader
	materials = {"bark": [pine_bark, spruce_bark, birch_bark], "leaf": leaf_mats, "far": far_mat}


func _assign_materials() -> void:
	for sp in 3:
		for lod in ["near", "mid"]:
			for v in TreeBuilder.VARIANTS:
				var m: ArrayMesh = meshes[lod][sp][v]
				m.surface_set_material(0, materials.bark[sp])
				m.surface_set_material(1, materials.leaf[sp])
		(meshes.far[sp] as ArrayMesh).surface_set_material(0, materials.far)


func _index_trees() -> void:
	var ids: PackedInt32Array = World.trees.id
	var chunks: PackedInt32Array = World.trees.chunk
	var tmp := {}
	for i in ids.size():
		tree_index_by_id[ids[i]] = i
		var c := chunks[i]
		if not tmp.has(c):
			tmp[c] = []
		(tmp[c] as Array).append(i)
		var cell := _cell_of(World.trees.x[i], World.trees.z[i])
		if not _tree_cells.has(cell):
			_tree_cells[cell] = []
		(_tree_cells[cell] as Array).append(i)
	chunk_trees = tmp


## Original trees still standing within `radius` of p (removed trees are
## excluded). Presentation uses it so cleared ground stops sounding and
## looking like forest (wind in leaves, bird perches, ambience).
func standing_trees_near(p: Vector3, radius: float, limit := 64) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c0 := _cell_of(p.x - radius, p.z - radius)
	var c1 := _cell_of(p.x + radius, p.z + radius)
	var r2 := radius * radius
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var cell := Vector2i(cx, cz)
			if not _tree_cells.has(cell):
				continue
			for i in (_tree_cells[cell] as Array):
				var dx: float = World.trees.x[i] - p.x
				var dz: float = World.trees.z[i] - p.z
				if dx * dx + dz * dz <= r2 and not World.removed_trees.has(int(World.trees.id[i])):
					out.append(i)
					if out.size() >= limit:
						return out
	return out


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / COLLISION_CELL)), int(floor(z / COLLISION_CELL)))


func tree_transform(i: int) -> Transform3D:
	var sp: int = World.trees.species[i]
	var h: float = World.trees.height[i]
	var r: float = World.trees.radius[i]
	var ys := h / float(TreeBuilder.REF_HEIGHT[sp])
	var xs := ys * sqrt(clampf((r / maxf(h, 1.0)) / (float(TreeBuilder.REF_RADIUS[sp]) / float(TreeBuilder.REF_HEIGHT[sp])), 0.6, 1.6))
	var basis := Basis(Vector3.UP, World.trees.rot[i])
	basis = Basis(Vector3.RIGHT, World.trees.lean_z[i]) * Basis(Vector3.BACK, -World.trees.lean_x[i]) * basis
	basis = basis.scaled_local(Vector3(xs, ys, xs))
	var pos := World.tree_position(i)
	return Transform3D(basis, pos)


func _build_chunk(chunk: int) -> void:
	if chunk_nodes.has(chunk):
		(chunk_nodes[chunk] as Node3D).queue_free()
	var node := Node3D.new()
	node.name = "TreeChunk_%d" % chunk
	# Chunk node sits at the chunk center: visibility ranges are measured
	# from the instance origin, so instances are stored relative to it.
	var vcs := World.config.vegetation_chunk_size
	var vcw := int(ceil((World.config.bounds_max.x - World.config.bounds_min.x) / vcs))
	node.position = Vector3(World.origin.x + (chunk % vcw + 0.5) * vcs, 0.0, World.origin.y + (chunk / vcw + 0.5) * vcs)
	add_child(node)
	chunk_nodes[chunk] = node
	var groups := {}
	var all_by_species := [[], [], []]
	for i in (chunk_trees[chunk] as Array):
		if World.removed_trees.has(int(World.trees.id[i])):
			continue
		var key := int(World.trees.species[i]) * TreeBuilder.VARIANTS + int(World.trees.variant[i])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
		all_by_species[World.trees.species[i]].append(i)
	for key in groups:
		var sp: int = key / TreeBuilder.VARIANTS
		var v: int = key % TreeBuilder.VARIANTS
		_add_mmi(node, meshes.near[sp][v], groups[key], 0.0, near_range, true)
		_add_mmi(node, meshes.mid[sp][v], groups[key], near_range, mid_range, shadows_mid)
	for sp in 3:
		if all_by_species[sp].size() > 0:
			_add_mmi(node, meshes.far[sp], all_by_species[sp], mid_range, 0.0, false)


func _add_mmi(parent: Node3D, mesh: Mesh, indices: Array, begin: float, end: float, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = indices.size()
	for k in indices.size():
		var i: int = indices[k]
		mm.set_instance_transform(k, tree_transform(i).translated(-parent.position))
		var seed_v: int = World.trees.seed[i]
		mm.set_instance_custom_data(k, Color(float(seed_v & 255) / 255.0, float((seed_v >> 8) & 255) / 255.0, float(World.trees.height[i]), 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	mmi.visibility_range_begin_margin = 20.0 if begin > 0.0 else 0.0
	mmi.visibility_range_end_margin = 20.0 if end > 0.0 else 0.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


func set_ranges(near: float, mid: float, mid_shadows: bool) -> void:
	near_range = near
	mid_range = mid
	shadows_mid = mid_shadows
	for chunk in chunk_trees:
		_build_chunk(chunk)


func _on_tree_removed(tree_id: int) -> void:
	var i: int = tree_index_by_id.get(tree_id, -1)
	if i < 0:
		return
	_build_chunk(World.trees.chunk[i])
	var cell := _cell_of(World.trees.x[i], World.trees.z[i])
	if _collision_cells.has(cell):
		(_collision_cells[cell] as Node).queue_free()
		_collision_cells.erase(cell)
		_last_cell = Vector2i(999999, 999999)


# ------------------------------------------------------- tree collision

func _physics_process(_delta: float) -> void:
	var focus := _focus_position()
	var cell := _cell_of(focus.x, focus.z)
	if cell == _last_cell:
		return
	_last_cell = cell
	update_collision_around(focus)


func _focus_position() -> Vector3:
	if Game.player:
		return Game.player.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


func update_collision_around(p: Vector3) -> void:
	var cell := _cell_of(p.x, p.z)
	var want := {}
	for dz in range(-COLLISION_RADIUS_CELLS, COLLISION_RADIUS_CELLS + 1):
		for dx in range(-COLLISION_RADIUS_CELLS, COLLISION_RADIUS_CELLS + 1):
			want[cell + Vector2i(dx, dz)] = true
	for c in _collision_cells.keys():
		if not want.has(c) and (c - cell).length() > COLLISION_RADIUS_CELLS + 1.5:
			(_collision_cells[c] as Node).queue_free()
			_collision_cells.erase(c)
	for c in want:
		if not _collision_cells.has(c) and _tree_cells.has(c):
			_collision_cells[c] = _make_cell_body(c)


func _make_cell_body(cell: Vector2i) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TreeCollision_%d_%d" % [cell.x, cell.y]
	body.set_meta("acoustic", "trunk")
	body.collision_layer = 1 | 4    # world + harvestable trees
	var ids := PackedInt32Array()
	for i in (_tree_cells[cell] as Array):
		if World.removed_trees.has(int(World.trees.id[i])):
			continue
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		var h := minf(float(World.trees.height[i]) * 0.6, 9.0)
		shape.radius = maxf(float(World.trees.radius[i]) * 0.95, 0.08)
		shape.height = h
		cs.shape = shape
		cs.position = World.tree_position(i) + Vector3(0, h * 0.5 - 0.2, 0)
		body.add_child(cs)
		ids.append(int(World.trees.id[i]))
	body.set_meta("tree_ids", ids)
	add_child(body)
	return body


func active_tree_collision_count() -> int:
	var n := 0
	for c in _collision_cells:
		n += (_collision_cells[c] as Node).get_child_count()
	return n


## Resolves a physics hit (body + shape index) to a tree id, or -1.
static func tree_id_from_hit(collider: Object, shape_idx: int) -> int:
	if collider == null or not collider.has_meta("tree_ids"):
		return -1
	var ids: PackedInt32Array = collider.get_meta("tree_ids")
	return ids[shape_idx] if shape_idx >= 0 and shape_idx < ids.size() else -1


# ----------------------------------------------------------------- rocks

func _build_rocks() -> void:
	var rock_meshes := RockBuilder.build_variants(6)
	var mat := RockBuilder.material()
	for m in rock_meshes:
		(m as ArrayMesh).surface_set_material(0, mat)
	var xs: PackedFloat32Array = World.rocks.x
	var by_variant := {}
	for i in xs.size():
		var v: int = int(World.rocks.seed[i]) % rock_meshes.size()
		if not by_variant.has(v):
			by_variant[v] = []
		by_variant[v].append(i)
	var body := StaticBody3D.new()
	body.name = "RockCollision"
	body.set_meta("acoustic", "rock")
	add_child(body)
	for v in by_variant:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = rock_meshes[v]
		var list: Array = by_variant[v]
		mm.instance_count = list.size()
		var convex: Shape3D = (rock_meshes[v] as ArrayMesh).create_convex_shape(true, true)
		for k in list.size():
			var i: int = list[k]
			var s: float = World.rocks.scale[i]
			var b := World.rock_basis(i)
			var t := Transform3D(b, World.rock_position(i))
			mm.set_instance_transform(k, t)
			if s > 0.6:
				var cs := CollisionShape3D.new()
				cs.shape = convex
				cs.transform = t
				body.add_child(cs)
				rock_bodies += 1
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 900.0
		add_child(mmi)
