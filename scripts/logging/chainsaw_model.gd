class_name ChainsawModel
extends Node3D
## Phase 14: an original mid-size chainsaw (no brand), built from simple
## parts in the camp's stylized look: orange housing, black handles, a grey
## bar with a dark chain loop and a running/stopped readout (the chain
## scrolls and the housing trembles only while the engine runs).
## Model space: +Y up, bar points to -Z. Markers:
##   RearGrip  - right hand on the rear handle (trigger)
##   FrontGrip - left hand on the wrap-around top handle
##   BarTip, BarRoot - the cutting edge (contact probe uses these)

var chain_mat: StandardMaterial3D
var running := false
var rpm := 0.0
var _housing: Node3D
var _scroll := 0.0
var _shake_t := 0.0


static func create(scale_mult := 1.0) -> ChainsawModel:
	var m := ChainsawModel.new()
	m.name = "Chainsaw"
	m._build()
	m.scale = Vector3.ONE * scale_mult
	return m


static func _m(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, name_ := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	if name_ != "":
		mi.name = name_
	parent.add_child(mi)
	return mi


func _tube(parent: Node3D, r: float, a: Vector3, b: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	var y := (b - a).normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := y.cross(ref).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	parent.add_child(mi)
	return mi


func _build() -> void:
	var orange := _m(Color(0.86, 0.36, 0.08), 0.45)
	var black := _m(Color(0.07, 0.07, 0.07), 0.8)
	var grey := _m(Color(0.62, 0.64, 0.66), 0.35, 0.8)
	var dark := _m(Color(0.16, 0.16, 0.17), 0.5, 0.6)
	_housing = Node3D.new()
	_housing.name = "Housing"
	add_child(_housing)
	# Engine housing and recoil starter side cover.
	_box(_housing, Vector3(0.13, 0.17, 0.32), Vector3(0, 0.1, 0.02), orange, "Body")
	_box(_housing, Vector3(0.14, 0.09, 0.18), Vector3(0, 0.215, 0.05), orange, "TopCover")
	_box(_housing, Vector3(0.02, 0.12, 0.14), Vector3(-0.075, 0.1, 0.04), black, "Starter")
	_box(_housing, Vector3(0.025, 0.012, 0.03), Vector3(-0.09, 0.15, 0.04), black, "Pull")
	# Exhaust/muffler guard at the front right.
	_box(_housing, Vector3(0.05, 0.07, 0.05), Vector3(0.06, 0.08, -0.13), dark, "Muffler")
	# Rear handle: a closed loop behind the body (right hand, trigger).
	_tube(_housing, 0.016, Vector3(0, 0.05, 0.17), Vector3(0, 0.05, 0.33), black)
	_tube(_housing, 0.016, Vector3(0, 0.05, 0.33), Vector3(0, 0.16, 0.30), black)
	_tube(_housing, 0.016, Vector3(0, 0.16, 0.30), Vector3(0, 0.17, 0.17), black)
	_box(_housing, Vector3(0.02, 0.03, 0.03), Vector3(0, 0.035, 0.24), _m(Color(0.75, 0.6, 0.1), 0.5), "Trigger")
	# Wrap-around top handle (left hand) and the chain brake lever.
	_tube(_housing, 0.015, Vector3(-0.09, 0.03, -0.09), Vector3(-0.09, 0.27, -0.09), black)
	_tube(_housing, 0.015, Vector3(-0.09, 0.27, -0.09), Vector3(0.07, 0.27, -0.06), black)
	_tube(_housing, 0.015, Vector3(0.07, 0.27, -0.06), Vector3(0.07, 0.19, -0.04), black)
	_box(_housing, Vector3(0.15, 0.1, 0.012), Vector3(0, 0.23, -0.15), black, "BrakeLever")
	# Guide bar and chain loop (dark outline that scrolls while running).
	var bar_len := 0.5
	_box(self, Vector3(0.008, 0.055, bar_len), Vector3(0, 0.085, -0.14 - bar_len * 0.5), grey, "Bar")
	var tex := _chain_texture()
	chain_mat = _m(Color(0.32, 0.32, 0.34), 0.45, 0.7)
	chain_mat.albedo_texture = tex
	chain_mat.uv1_scale = Vector3(14.0, 1.0, 1.0)
	chain_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for y in [0.05, 0.12]:
		var c := _box(self, Vector3(0.012, 0.012, bar_len), Vector3(0, y, -0.14 - bar_len * 0.5), chain_mat, "Chain")
		c.name = "Chain_%s" % ("lo" if y < 0.1 else "hi")
	var nose := _tube(self, 0.035, Vector3(-0.007, 0.085, -0.14 - bar_len), Vector3(0.007, 0.085, -0.14 - bar_len), chain_mat)
	nose.name = "BarNose"
	_marker("RearGrip", Vector3(0, 0.07, 0.25))
	_marker("FrontGrip", Vector3(-0.01, 0.27, -0.08))
	_marker("BarRoot", Vector3(0, 0.085, -0.16))
	_marker("BarTip", Vector3(0, 0.085, -0.14 - bar_len))
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _marker(n: String, p: Vector3) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = p
	add_child(m)


static func _chain_texture() -> ImageTexture:
	var img := Image.create(8, 2, false, Image.FORMAT_RGB8)
	for x in 8:
		for y in 2:
			var v := 0.85 if x < 3 else (0.35 if x < 6 else 0.6)
			img.set_pixel(x, y, Color(v, v, v * 1.02))
	return ImageTexture.create_from_image(img)


func set_running(on: bool, speed: float) -> void:
	running = on
	rpm = speed


func _process(delta: float) -> void:
	if running and chain_mat:
		_scroll = fmod(_scroll + delta * (2.0 + 22.0 * rpm), 1.0)
		chain_mat.uv1_offset = Vector3(_scroll, 0, 0)
	if _housing:
		# Restrained engine tremble (millimetres), only while running.
		_shake_t += delta
		var a := (0.0008 + 0.0012 * rpm) if running else 0.0
		_housing.position = Vector3(sin(_shake_t * 97.0) * a, cos(_shake_t * 83.0) * a, 0)
