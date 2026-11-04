class_name TerrainSystem
extends Node3D
## Chunked terrain: shared flat grid meshes displaced on the GPU from the
## frozen height field, three distance LODs with skirts, and chunked
## HeightMapShape3D collision built from the very same samples.

const LOD_STEPS := [1, 2, 8]          # vertex spacing in cells
const LOD_RANGES := [0.0, 220.0, 520.0, 0.0]
const SKIP_BELOW := -11.0             # chunks entirely deeper than this are never visible

var chunk_cells := 32
var materials: Array[ShaderMaterial] = []
var meshes: Array[ArrayMesh] = []
var chunk_count := 0
var collision_shapes := 0
var lod_range_scale := 1.0


func build() -> void:
	World.ensure_loaded()
	chunk_cells = World.config.chunk_cells
	var shader: Shader = load("res://shaders/terrain.gdshader")
	var alb: Texture = load("res://assets/generated/terrain/terrain_albedo.jpg")
	var nrm: Texture = load("res://assets/generated/terrain/terrain_normal.jpg")
	var arm: Texture = load("res://assets/generated/terrain/terrain_arm.jpg")
	var region_tex := ImageTexture.create_from_image(Image.create_from_data(World.W, World.H, false, Image.FORMAT_R8, World.water_region))
	for lod in LOD_STEPS.size():
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("heightmap", World.height_texture)
		mat.set_shader_parameter("masks", World.mask_texture)
		mat.set_shader_parameter("water_map", World.water_texture)
		mat.set_shader_parameter("water_region_map", region_tex)
		mat.set_shader_parameter("grid_origin", World.origin)
		mat.set_shader_parameter("cell_size", World.cs)
		mat.set_shader_parameter("grid_dims", Vector2i(World.W, World.H))
		mat.set_shader_parameter("lod_step", float(LOD_STEPS[lod]))
		mat.set_shader_parameter("skirt_depth", 1.0 + lod * 2.5)
		mat.set_shader_parameter("albedo_array", alb)
		mat.set_shader_parameter("normal_array", nrm)
		mat.set_shader_parameter("arm_array", arm)
		materials.append(mat)
		meshes.append(_make_grid_mesh(chunk_cells, LOD_STEPS[lod], World.cs))
	_spawn_chunks()


func set_lod_scale(s: float) -> void:
	lod_range_scale = s
	for c in get_children():
		if c is MeshInstance3D:
			var lod: int = c.get_meta("lod")
			_apply_range(c, lod)


func _apply_range(mi: MeshInstance3D, lod: int) -> void:
	# Adjacent LODs overlap by a few meters so no chunk is ever missing.
	mi.visibility_range_begin = maxf(LOD_RANGES[lod] * lod_range_scale - 6.0, 0.0) if lod > 0 else 0.0
	mi.visibility_range_end = LOD_RANGES[lod + 1] * lod_range_scale + 6.0 if LOD_RANGES[lod + 1] > 0.0 else 0.0
	mi.visibility_range_begin_margin = 0.0
	mi.visibility_range_end_margin = 0.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func _spawn_chunks() -> void:
	var cw := int(ceil(float(World.W - 1) / chunk_cells))
	var ch := int(ceil(float(World.H - 1) / chunk_cells))
	var size := chunk_cells * World.cs
	var collision_root := StaticBody3D.new()
	collision_root.name = "TerrainCollision"
	collision_root.set_meta("surface", "terrain")
	collision_root.set_meta("acoustic", "terrain")
	add_child(collision_root)
	for cj in ch:
		for ci in cw:
			var i0 := ci * chunk_cells
			var j0 := cj * chunk_cells
			var hmin := INF
			var hmax := -INF
			for j in range(j0, mini(j0 + chunk_cells, World.H - 1) + 1):
				for i in range(i0, mini(i0 + chunk_cells, World.W - 1) + 1):
					var h := World.height[j * World.W + i]
					hmin = minf(hmin, h)
					hmax = maxf(hmax, h)
			if hmax < SKIP_BELOW:
				continue
			var origin := Vector3(World.origin.x + i0 * World.cs, 0.0, World.origin.y + j0 * World.cs)
			for lod in LOD_STEPS.size():
				var mi := MeshInstance3D.new()
				mi.mesh = meshes[lod]
				mi.material_override = materials[lod]
				mi.position = origin
				mi.custom_aabb = AABB(Vector3(-1.0, hmin - 12.0, -1.0), Vector3(size + 2.0, hmax - hmin + 14.0, size + 2.0))
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.set_meta("lod", lod)
				_apply_range(mi, lod)
				add_child(mi)
			chunk_count += 1
			if hmax > -2.0:
				_add_collision(collision_root, i0, j0)


func _add_collision(body: StaticBody3D, i0: int, j0: int) -> void:
	# HeightMapShape3D samples are 1 unit apart: scale the shape node by the
	# cell size (uniform) and store heights divided by it.
	var n := chunk_cells + 1
	var data := PackedFloat32Array()
	data.resize(n * n)
	for j in n:
		for i in n:
			var gi := mini(i0 + i, World.W - 1)
			var gj := mini(j0 + j, World.H - 1)
			data[j * n + i] = World.height[gj * World.W + gi] / World.cs
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var half := chunk_cells * 0.5 * World.cs
	cs.position = Vector3(World.origin.x + i0 * World.cs + half, 0.0, World.origin.y + j0 * World.cs + half)
	cs.scale = Vector3.ONE * World.cs
	body.add_child(cs)
	collision_shapes += 1


static func _make_grid_mesh(cells: int, step: int, cell: float) -> ArrayMesh:
	# Flat grid with an outer skirt ring (COLOR.r = 1 marks skirt vertices).
	var n := cells / step + 1
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			verts.append(Vector3(i * step * cell, 0.0, j * step * cell))
			colors.append(Color(0, 0, 0))
			uvs.append(Vector2(float(i) / (n - 1), float(j) / (n - 1)))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			# Diagonal a-d matches World.height_at triangulation.
			idx.append_array([a, b, d, a, d, c])
	# Skirts along the four edges
	var edges := [[], [], [], []]
	for k in n:
		edges[0].append(k)                 # z = 0
		edges[1].append((n - 1) * n + k)   # z = max
		edges[2].append(k * n)             # x = 0
		edges[3].append(k * n + n - 1)     # x = max
	for e in 4:
		var base := verts.size()
		for v in edges[e]:
			verts.append(verts[v])
			colors.append(Color(1, 0, 0))
			uvs.append(uvs[v])
		for k in n - 1:
			var t0: int = edges[e][k]
			var t1: int = edges[e][k + 1]
			var s0 := base + k
			var s1 := base + k + 1
			# Emit both windings; skirts are hidden below ground anyway.
			idx.append_array([t0, s0, t1, t1, s0, s1, t0, t1, s0, t1, s1, s0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
