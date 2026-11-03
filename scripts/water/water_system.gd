class_name WaterSystem
extends Node3D
## Ocean, river and ponds as separate water regions with documented levels
## (data/world/layout.json). Owns the shared wave definition (GPU + CPU
## mirror), the pooled ripple emitters and the wading query.

## Gerstner waves: dir.x, dir.z, wavelength (m), steepness. Sheltered coast.
const WAVES := [
	Vector4(0.15, 1.0, 17.0, 0.055),
	Vector4(-0.35, 1.0, 11.0, 0.05),
	Vector4(0.6, 0.8, 7.3, 0.045),
	Vector4(-0.1, 1.0, 4.6, 0.04),
	Vector4(0.45, 0.9, 3.1, 0.03),
]
const MAX_RIPPLES := 16

var ocean: MeshInstance3D
var ocean_material: ShaderMaterial
var inland_materials: Array[ShaderMaterial] = []
var pond_meshes: Array[MeshInstance3D] = []
var river_mesh: MeshInstance3D
var ripples: Array[Vector4] = []
var _ripple_cooldown := {}
var ocean_grid := 320
var wave_scale := 1.0

var _detail_a: NoiseTexture2D
var _detail_b: NoiseTexture2D
var _foam: NoiseTexture2D


func build(grid_resolution: int = 320) -> void:
	World.ensure_loaded()
	ocean_grid = grid_resolution
	_make_noise_textures()
	_build_ocean()
	_build_ponds()
	_build_river()
	_build_buoys()


func _make_noise_textures() -> void:
	_detail_a = _noise_tex(512, 0.012, 3, true, 3.0, 101)
	_detail_b = _noise_tex(256, 0.03, 2, true, 2.0, 202)
	_foam = _noise_tex(256, 0.025, 4, false, 0.0, 303)


static func _noise_tex(size: int, freq: float, octaves: int, normal: bool, bump: float, seed_v: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	return t


func _common_params(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("detail_normal_a", _detail_a)
	mat.set_shader_parameter("detail_normal_b", _detail_b)
	mat.set_shader_parameter("foam_noise", _foam)
	mat.set_shader_parameter("ripple_count", 0)


func _build_ocean() -> void:
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = load("res://shaders/ocean.gdshader")
	_common_params(ocean_material)
	ocean_material.set_shader_parameter("heightmap", World.height_texture)
	ocean_material.set_shader_parameter("masks", World.mask_texture)
	ocean_material.set_shader_parameter("water_region_map", ImageTexture.create_from_image(Image.create_from_data(World.W, World.H, false, Image.FORMAT_R8, World.water_region)))
	ocean_material.set_shader_parameter("grid_origin", World.origin)
	ocean_material.set_shader_parameter("cell_size", World.cs)
	ocean_material.set_shader_parameter("grid_dims", Vector2i(World.W, World.H))
	var w := PackedVector4Array()
	for v in WAVES:
		w.append(v)
	ocean_material.set_shader_parameter("waves", w)
	ocean_material.set_shader_parameter("wave_scale", wave_scale)
	ocean = MeshInstance3D.new()
	ocean.name = "Ocean"
	ocean.mesh = _make_ocean_mesh(ocean_grid)
	ocean.material_override = ocean_material
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean.extra_cull_margin = 4.0
	ocean.custom_aabb = AABB(Vector3(-30000, -3, -30000), Vector3(60000, 6, 60000))
	add_child(ocean)


static func _ocean_r(u: float) -> float:
	# Dense near the camera, coarse further out, final ring at the horizon.
	var a := absf(u)
	if a >= 0.9999:
		return signf(u) * 30000.0
	return signf(u) * 1300.0 * (0.11 * a + 0.89 * a * a * a)


static func _make_ocean_mesh(n: int) -> ArrayMesh:
	var st := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in n + 1:
		var z := _ocean_r(-1.0 + 2.0 * j / n)
		for i in n + 1:
			st.append(Vector3(_ocean_r(-1.0 + 2.0 * i / n), 0.0, z))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			idx.append_array([a, b, d, a, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = st
	var nrm := PackedVector3Array()
	nrm.resize(st.size())
	nrm.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _build_ponds() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/inland_water.gdshader")
	_common_params(mat)
	mat.set_shader_parameter("is_river", false)
	mat.set_shader_parameter("absorption", Vector3(1.9, 1.2, 1.1))
	mat.set_shader_parameter("scatter_color", Color(0.06, 0.13, 0.1))
	inland_materials.append(mat)
	for pd in World.ponds():
		var mi := MeshInstance3D.new()
		mi.name = "Pond_%d" % int(pd.x)
		var disc := _disc_mesh(float(pd.radius) * 1.32 + 3.0, 64, 10)
		mi.mesh = disc
		mi.material_override = mat
		mi.position = Vector3(pd.x, pd.level, pd.z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		pond_meshes.append(mi)


static func _disc_mesh(radius: float, seg: int, rings: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	v.append(Vector3.ZERO)
	uv.append(Vector2.ZERO)
	for r in range(1, rings + 1):
		var rr := radius * float(r) / rings
		for s in seg:
			var a := TAU * s / seg
			v.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
			uv.append(Vector2(cos(a) * rr, sin(a) * rr))
	# Clockwise when seen from above (Godot front faces), so the disc faces up.
	for s in seg:
		idx.append_array([0, 1 + s, 1 + (s + 1) % seg])
	for r in range(1, rings):
		var b0 := 1 + (r - 1) * seg
		var b1 := 1 + r * seg
		for s in seg:
			var s1 := (s + 1) % seg
			idx.append_array([b0 + s, b1 + s1, b0 + s1, b0 + s, b1 + s, b1 + s1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var nrm := PackedVector3Array()
	nrm.resize(v.size())
	nrm.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = nrm
	var tan := PackedFloat32Array()
	for k in v.size():
		tan.append_array([1.0, 0.0, 0.0, 1.0])
	arrays[Mesh.ARRAY_TANGENT] = tan
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _build_river() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/inland_water.gdshader")
	_common_params(mat)
	mat.set_shader_parameter("is_river", true)
	mat.set_shader_parameter("absorption", Vector3(0.75, 0.38, 0.36))
	mat.set_shader_parameter("scatter_color", Color(0.05, 0.14, 0.12))
	inland_materials.append(mat)
	var pts := World.river_points
	var count := pts.size()
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var nrm := PackedVector3Array()
	var tan := PackedFloat32Array()
	var idx := PackedInt32Array()
	const ACROSS := 9
	var last := count - 1
	for k in count:
		# Stop where the river has merged into the sea.
		if World.river_levels[k] <= World.sea_level + 0.06 and World.height_at(pts[k].x, pts[k].y) < World.sea_level - 0.3:
			last = k
			break
	for k in last + 1:
		var k0 := maxi(k - 2, 0)
		var k1 := mini(k + 2, count - 1)
		var tang := (pts[k1] - pts[k0]).normalized()
		var across := Vector2(-tang.y, tang.x)
		var half := World.river_widths[k] * 0.5 + 1.4
		for a in ACROSS:
			var f := -1.0 + 2.0 * a / (ACROSS - 1)
			var p := pts[k] + across * half * f
			v.append(Vector3(p.x, World.river_levels[k], p.y))
			uv.append(Vector2(World.river_arc[k], f * half))
			col.append(Color(World.river_rapid[k], absf(f), 0.0))
			nrm.append(Vector3.UP)
			tan.append_array([tang.x, 0.0, tang.y, 1.0])
	for k in last:
		for a in ACROSS - 1:
			var p0 := k * ACROSS + a
			var p1 := p0 + 1
			var q0 := p0 + ACROSS
			var q1 := q0 + 1
			idx.append_array([p0, q0, q1, p0, q1, p1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TANGENT] = tan
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	river_mesh = MeshInstance3D.new()
	river_mesh.name = "River"
	river_mesh.mesh = m
	river_mesh.material_override = mat
	river_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river_mesh)


func _build_buoys() -> void:
	# Visible wading limit off the landing beach: a short buoy line along the
	# 0.9 m depth contour (the actual limit is enforced everywhere by depth).
	var buoy_scene: PackedScene = load("res://assets/polyhaven/models/ocean_buoy/ocean_buoy_1k.gltf")
	if buoy_scene == null:
		return
	var c := World.config.camp_center
	var placed := 0
	for k in 21:
		var x := c.x - 150.0 + k * 15.0
		var z := c.y + 60.0
		while z < c.y + 400.0 and World.water_depth_at(x, z) < World.config.wade_depth_limit + 0.6:
			z += 1.5
		if z >= c.y + 400.0 or World.water_region_at(x, z) != 0:
			continue
		if k % 3 != 0:
			continue
		var b: Node3D = buoy_scene.instantiate()
		b.name = "WadingBuoy_%d" % k
		b.position = Vector3(x, World.sea_level - 0.3, z)
		b.scale = Vector3.ONE * 0.55
		b.set_script(load("res://scripts/water/bobbing.gd"))
		add_child(b)
		placed += 1


# ------------------------------------------------------------- per frame

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and ocean:
		var p := cam.global_position
		var snap := 4.0
		ocean.global_position = Vector3(snappedf(p.x, snap), 0.0, snappedf(p.z, snap))
	_update_ripples()


func _update_ripples() -> void:
	var t := Game.world_time
	var keep: Array[Vector4] = []
	for r in ripples:
		if t - r.z < 4.0:
			keep.append(r)
	ripples = keep
	var arr := PackedVector4Array()
	for r in ripples:
		arr.append(r)
	arr.resize(MAX_RIPPLES)
	for mat in [ocean_material] + inland_materials:
		mat.set_shader_parameter("ripples", arr)
		mat.set_shader_parameter("ripple_count", ripples.size())


## Pooled, rate-limited ripple emitter. `source` keys the rate limit.
func emit_ripple(pos: Vector3, strength: float = 1.0, source: Variant = null, min_interval: float = 0.35) -> void:
	var t := Game.world_time
	if source != null:
		if t - float(_ripple_cooldown.get(source, -99.0)) < min_interval:
			return
		_ripple_cooldown[source] = t
	if ripples.size() >= MAX_RIPPLES:
		ripples.pop_front()
	ripples.append(Vector4(pos.x, pos.z, t, clampf(strength, 0.0, 2.0)))


# ---------------------------------------------------------- CPU queries

## CPU mirror of the GPU Gerstner sum (vertical displacement only). Used for
## shore effects, audio and the future timber-recovery service.
func ocean_height_at(x: float, z: float, t: float = -1.0) -> float:
	if t < 0.0:
		t = Game.world_time
	var depth := World.sea_level - World.height_at(x, z)
	var amp := wave_scale * clampf(depth / 4.0, 0.12, 1.0)
	var y := 0.0
	for wv in WAVES:
		var w: Vector4 = wv
		var k := TAU / w.z
		var c := sqrt(9.81 / k)
		var d := Vector2(w.x, w.y).normalized()
		var f := k * (d.dot(Vector2(x, z)) - c * t)
		y += (w.w / k) * amp * sin(f)
	return World.sea_level + y


## Water surface height at a point for whichever region contains it.
func surface_height_at(x: float, z: float) -> float:
	var region := World.water_region_at(x, z)
	if region == 0:
		return ocean_height_at(x, z)
	return World.water_level_at(x, z)


func depth_at(x: float, z: float) -> float:
	return maxf(surface_height_at(x, z) - World.height_at(x, z), 0.0)
