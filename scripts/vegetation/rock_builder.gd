class_name RockBuilder
extends RefCounted
## Procedural rock meshes (noise-displaced, faceted icospheres) shaded with
## the CC0 rock layers of the terrain texture arrays (triplanar + moss cap).


static func build_variants(count: int) -> Array:
	var out := []
	for v in count:
		out.append(_build(v))
	return out


static func _build(variant: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 500 + variant
	noise.frequency = 0.9
	noise.fractal_octaves = 3
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 18
	sphere.rings = 10
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var stretch := Vector3(1.0 + 0.25 * sin(variant * 1.7), 1.0, 1.0 + 0.25 * cos(variant * 2.3))
	for i in verts.size():
		var p := verts[i]
		var n := p.normalized()
		var d := 1.0 + 0.32 * noise.get_noise_3dv(n * 1.3) + 0.1 * noise.get_noise_3dv(n * 4.0)
		# Flatter bottom so rocks sit on the ground.
		var q := n * 0.5 * d * stretch
		if q.y < -0.18:
			q.y = lerpf(q.y, -0.2, 0.7)
		verts[i] = q
	arrays[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.deindex()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rock.gdshader")
	m.set_shader_parameter("albedo_array", load("res://assets/generated/terrain/terrain_albedo.jpg"))
	m.set_shader_parameter("normal_array", load("res://assets/generated/terrain/terrain_normal.jpg"))
	m.set_shader_parameter("arm_array", load("res://assets/generated/terrain/terrain_arm.jpg"))
	return m
