class_name SandHaze
extends Node3D
## Localized heat shimmer over hot dry sand: a handful of low billboard quads
## on the beaches whose strength follows the lighting preset's `heat_haze`
## (midday, clear weather only) and the comfort toggle. Bounded distortion,
## never full-frame.


func build() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/heat_haze.gdshader")
	mat.set_shader_parameter("strength", 0.0035)
	mat.set_shader_parameter("use_global_haze", true)
	mat.set_shader_parameter("max_distance", 70.0)
	mat.render_priority = 1
	var quad := QuadMesh.new()
	quad.size = Vector2(9.0, 1.3)
	quad.center_offset = Vector3(0, 0.65, 0)
	quad.material = mat
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var placed := 0
	for be in World.config.beaches:
		for k in 40:
			if placed >= 24:
				break
			var a := rng.randf() * TAU
			var r := rng.randf() * be.z * 0.6
			var x: float = be.x + cos(a) * r
			var z: float = be.y + sin(a) * r
			var h := World.height_at(x, z)
			var m := World.masks_at(x, z)
			if m.x < 0.6 or h < 1.2 or h > 4.0 or World.water_region_at(x, z) != 0:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.position = Vector3(x, h + 0.05, z)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 75.0
			add_child(mi)
			placed += 1
