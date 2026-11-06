class_name ViewModel
extends Node3D
## First-person hands, forearms and the held axe, parented to the camera.
## The axe follows a designed swing arc (camera space); both arms are solved
## to grips on the handle each frame (two-bone IK), so hands stay on the
## tool through the whole swing. The small hatchet is held one-handed.

const AXES := {
	"small": {"asset": "hatchet", "scale": 1.55, "two_hands": false},
	"medium": {"asset": "wooden_axe_03", "scale": 1.12, "two_hands": true},
	"large": {"asset": "wooden_axe_02", "scale": 1.3, "two_hands": true},
}

## Swing keyframes in camera space: phase (0..1 of cycle), grip centre,
## handle direction (bottom->head), blade direction.
const KEYS := [
	# Rest sits low in the lower-right corner (Phase 24 reference): the head
	# only enters the frame on the wind-up and lands on the crosshair at contact.
	[0.0, Vector3(0.28, -0.41, -0.5), Vector3(-0.26, 0.86, -0.44), Vector3(-0.85, 0.0, -0.5)],
	[0.3, Vector3(0.42, -0.06, -0.16), Vector3(0.28, 0.72, 0.62), Vector3(-0.1, 0.62, -0.78)],
	[0.4, Vector3(0.3, -0.12, -0.46), Vector3(0.08, 0.5, -0.86), Vector3(-0.35, -0.55, -0.75)],
	[0.46, Vector3(0.05, -0.26, -0.7), Vector3(-0.4, 0.12, -0.9), Vector3(-0.62, -0.1, -0.78)],
	[0.56, Vector3(0.12, -0.26, -0.62), Vector3(-0.32, 0.24, -0.9), Vector3(-0.7, 0.05, -0.7)],
	[1.0, Vector3(0.28, -0.41, -0.5), Vector3(-0.26, 0.86, -0.44), Vector3(-0.85, 0.0, -0.5)],
]

var tier := "small"
var axe_pivot: Node3D
var axe_node: Node3D
var grip_r: Marker3D
var grip_l: Marker3D
var head_marker: Marker3D
var bones := {}
var upper_len := 0.29
var fore_len := 0.26
var _two_hands := false
var _bob := 0.0
var _recoil := 0.0
## Phase 14: the chainsaw in first person (two hands: rear handle + top
## handle), and the glove tier shown on the hands.
var saw_model: ChainsawModel
var _push := 0.0
var _vib_t := 0.0
var _glove_mat: StandardMaterial3D
const GLOVE_COLORS := {"": Color(0.78, 0.6, 0.48), "t1": Color(0.6, 0.47, 0.28), "t2": Color(0.36, 0.22, 0.12), "t3": Color(0.12, 0.12, 0.13)}


func _ready() -> void:
	_build_arms()
	axe_pivot = Node3D.new()
	axe_pivot.name = "AxePivot"
	add_child(axe_pivot)
	equip("small")
	pose_at(0.0)


# ------------------------------------------------- Phase 24 pixel viewmodel
## HD-2D style: the first-person arms and tools get a pixel-textured overlay
## (texel cells attached to each part + a 3-band light ramp with ordered
## dither), coarser than on the crew so the hands read as pixel art at arm's
## length. Applied with material_overlay, so shared character materials are
## untouched. Off in "clean"; the Phase 11 "pixel" style keeps its own pass.
static var _vm_pass: ShaderMaterial
var _vm_style := ""
var _vm_t := 0.0


static func vm_pixel_pass() -> ShaderMaterial:
	if _vm_pass == null:
		_vm_pass = ShaderMaterial.new()
		_vm_pass.shader = load("res://shaders/char_pixel.gdshader")
		_vm_pass.set_shader_parameter("strength", 1.0)
		_vm_pass.set_shader_parameter("cell", 0.011)
	return _vm_pass


func _process(delta: float) -> void:
	_follow_pixel_cam()
	_vm_t -= delta
	if _vm_t > 0.0:
		return
	_vm_t = 0.5
	var st := str(Settings.get_v("character_style"))
	if st != _vm_style:
		_vm_style = st
		apply_pixel_style()
	if _px_vp != null:
		_set_layers(self, VM_LAYER)       # newly equipped parts join the pixel layer


func apply_pixel_style() -> void:
	var hd2d := str(Settings.get_v("character_style")) == "hd2d"
	_overlay(self, vm_pixel_pass() if hd2d else null)
	_set_pixel_view(hd2d and DisplayServer.get_name() != "headless")


# ---- Phase 24: true pixel-art first-person axe and hands -------------------
## The arms and tool render on their own layer into a low-resolution
## SubViewport whose camera mirrors the player's (same world, so the same
## sun, lamps and fog light them), then show upscaled with nearest texels
## and a dark one-texel outline, under the grade and HUD. The world itself
## keeps full resolution.
const VM_LAYER := 1 << 19          # layer 20 (CameraWall.LAYER_VIEWMODEL)
const VM_ROWS := 200               # pixel rows across the screen height
var _px_vp: SubViewport
var _px_cam: Camera3D
var _px_canvas: CanvasLayer
var _px_rect: TextureRect


func _set_pixel_view(on: bool) -> void:
	var main_cam := get_parent() as Camera3D
	if main_cam == null:
		return
	if on and _px_vp == null:
		_px_vp = SubViewport.new()
		_px_vp.name = "VMPixelView"
		_px_vp.transparent_bg = true
		_px_vp.msaa_3d = Viewport.MSAA_DISABLED
		_px_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		_px_vp.use_taa = false
		_px_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_px_cam = Camera3D.new()
		_px_cam.cull_mask = VM_LAYER
		_px_cam.near = 0.02
		_px_cam.far = 6.0
		_px_vp.add_child(_px_cam)
		add_child(_px_vp)
		_px_canvas = CanvasLayer.new()
		_px_canvas.name = "VMPixelLayer"
		_px_canvas.layer = -1                     # above the 3D world, below grade and HUD
		_px_rect = TextureRect.new()
		_px_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_px_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_px_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_px_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_px_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/vm_pixel_present.gdshader")
		_px_rect.material = m
		_px_rect.texture = _px_vp.get_texture()
		_px_canvas.add_child(_px_rect)
		add_child(_px_canvas)
		_px_cam.make_current()
	if _px_vp != null:
		_px_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		_px_canvas.visible = on
		_set_layers(self, VM_LAYER if on else 1)
	if on:
		main_cam.cull_mask &= ~VM_LAYER
	else:
		main_cam.cull_mask |= VM_LAYER
	_follow_pixel_cam()


func _follow_pixel_cam() -> void:
	if _px_vp == null or not _px_canvas.visible:
		return
	var main_cam := get_parent() as Camera3D
	if main_cam == null:
		return
	_px_cam.global_transform = main_cam.global_transform
	_px_cam.fov = main_cam.fov
	var vs := get_viewport().get_visible_rect().size
	var want := Vector2i(maxi(int(round(vs.x * VM_ROWS / maxf(vs.y, 1.0))), 16), VM_ROWS)
	if _px_vp.size != want:
		_px_vp.size = want
	# Hidden viewmodel (UI open, vehicle, carrying) hides the pixel layer too.
	_px_rect.visible = is_visible_in_tree()


static func _set_layers(n: Node, layers: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layers
	for c in n.get_children():
		if c is SubViewport or c is CanvasLayer:
			continue
		_set_layers(c, layers)


static func _overlay(n: Node, m: Material) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_overlay = m
	for c in n.get_children():
		_overlay(c, m)


func _build_arms() -> void:
	var jacket := CharMeshKit.fabric(Color(0.42, 0.2, 0.14))
	var cuff := CharMeshKit.mat(Color(0.25, 0.12, 0.08), 0.85)
	var glove := CharMeshKit.mat(Color(0.55, 0.42, 0.25), 0.8).duplicate() as StandardMaterial3D
	_glove_mat = glove
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		var up := Node3D.new()
		up.name = "UpperArm" + side
		up.position = Vector3(s * 0.21, -0.36, 0.14)
		add_child(up)
		var ul := CharMeshKit.limb(up, jacket, 0.058, 0.05, upper_len)
		ul.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fo := Node3D.new()
		fo.name = "Forearm" + side
		fo.position = Vector3(0, -upper_len, 0)
		up.add_child(fo)
		var fl := CharMeshKit.limb(fo, jacket, 0.05, 0.042, fore_len - 0.03)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var c := CharMeshKit.blob(fo, cuff, Vector3(0, -fore_len + 0.03, 0), Vector3(0.1, 0.045, 0.1))
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hand := Node3D.new()
		hand.name = "Hand" + side
		hand.position = Vector3(0, -fore_len, 0)
		fo.add_child(hand)
		var mit := CharMeshKit.blob(hand, glove, Vector3(0, -0.045, 0), Vector3(0.085, 0.11, 0.06))
		mit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var th := CharMeshKit.limb(hand, glove, 0.019, 0.016, 0.05)
		th.position = Vector3(-s * 0.03, -0.02, -0.03)
		th.rotation = Vector3(0.7, 0, s * 0.5)
		th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bones["UpperArm" + side] = up
		bones["Forearm" + side] = fo
		bones["Hand" + side] = hand


func equip(t: String) -> void:
	tier = t if AXES.has(t) else "small"
	saw_model = null
	if axe_node:
		axe_node.queue_free()
	for c in axe_pivot.get_children():
		c.queue_free()
	var spec: Dictionary = AXES[tier]
	_two_hands = spec.two_hands
	var scene: PackedScene = load("res://assets/polyhaven/models/%s/%s_1k.gltf" % [spec.asset, spec.asset])
	axe_node = scene.instantiate() if scene else Node3D.new()
	axe_node.scale = Vector3.ONE * float(spec.scale)
	_disable_shadows(axe_node)
	# Measure the handle so grips sit on it: bottom of the model is the
	# handle end, top is the head.
	var aabb := _aabb(axe_node)
	var bottom := aabb.position.y * float(spec.scale)
	var top := (aabb.position.y + aabb.size.y) * float(spec.scale)
	var length := top - bottom
	var grip_centre := bottom + length * (0.16 if _two_hands else 0.18)
	axe_node.position = Vector3(0, -grip_centre, 0)
	axe_pivot.add_child(axe_node)
	grip_r = Marker3D.new()
	grip_r.position = Vector3(0, (length * (0.3 if _two_hands else 0.18)) + bottom - grip_centre, 0)
	axe_pivot.add_child(grip_r)
	grip_l = Marker3D.new()
	grip_l.position = Vector3(0, (length * 0.06) + bottom - grip_centre, 0)
	axe_pivot.add_child(grip_l)
	head_marker = Marker3D.new()
	head_marker.position = Vector3(0, top - length * 0.08 - grip_centre, 0.04)
	axe_pivot.add_child(head_marker)
	_vm_style = ""          # re-apply the Phase 24 overlay to the new tool


static func _disable_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_disable_shadows(c)


static func _aabb(n: Node, xf := Transform3D()) -> AABB:
	var out := AABB()
	var first := true
	var stack := [[n, Transform3D()]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node != n and node is Node3D:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D:
			var a: AABB = t * (node as MeshInstance3D).get_aabb()
			out = a if first else out.merge(a)
			first = false
		for c in node.get_children():
			stack.append([c, t])
	return out


## Phase 14: hands show the equipped glove tier ("" = bare hands).
func set_gloves(t: String) -> void:
	if _glove_mat:
		_glove_mat.albedo_color = GLOVE_COLORS.get(t, GLOVE_COLORS[""])
		_glove_mat.roughness = 0.55 if t == "" else 0.85


## Phase 14: hold the chainsaw (replaces the axe on the same pivot).
func equip_saw() -> void:
	if axe_node:
		axe_node.queue_free()
	for c in axe_pivot.get_children():
		c.queue_free()
	tier = "chainsaw"
	saw_model = ChainsawModel.create(1.0)
	_two_hands = true
	# Pivot origin = between the hands; the bar points away (-Z).
	axe_pivot.add_child(saw_model)
	axe_node = saw_model
	var rear: Vector3 = (saw_model.get_node("RearGrip") as Node3D).position
	var front: Vector3 = (saw_model.get_node("FrontGrip") as Node3D).position
	saw_model.position = -(rear + front) * 0.5
	grip_r = Marker3D.new()
	grip_r.position = rear + saw_model.position
	axe_pivot.add_child(grip_r)
	grip_l = Marker3D.new()
	grip_l.position = front + saw_model.position
	axe_pivot.add_child(grip_l)
	head_marker = Marker3D.new()
	head_marker.position = (saw_model.get_node("BarTip") as Node3D).position + saw_model.position
	axe_pivot.add_child(head_marker)


## Saw held low in front, bar level and slightly down; it eases forward
## into the cut and trembles a little with engine speed (millimetres, no
## camera shake).
func pose_saw(rpm: float, cutting: bool, walk_bob := 0.0) -> void:
	if saw_model == null:
		return
	var dt := get_process_delta_time()
	_vib_t += dt
	_push = move_toward(_push, 1.0 if cutting else 0.0, dt * 3.0)
	saw_model.set_running(rpm > 0.01, rpm)
	var pos := Vector3(0.27, -0.42, -0.52) + Vector3(-0.02 * _push, 0.03 * _push, -0.07 * _push)
	pos += Vector3(0.006 * sin(walk_bob), 0.008 * absf(cos(walk_bob)), 0.0)
	var a := (0.0015 + 0.002 * rpm) if rpm > 0.01 else 0.0
	pos += Vector3(sin(_vib_t * 91.0) * a, cos(_vib_t * 77.0) * a, 0)
	# Bar angled in toward the aim point so it reads past the housing.
	var basis := Basis(Vector3.UP, 0.42) * Basis(Vector3.RIGHT, 0.04 - 0.08 * _push)
	axe_pivot.transform = Transform3D(basis, pos)
	_solve_arms()


## Places the axe at swing phase `u` (0..1) and solves the arms.
func pose_at(u: float, walk_bob := 0.0) -> void:
	var k := 0
	while k < KEYS.size() - 2 and u > float(KEYS[k + 1][0]):
		k += 1
	var a: Array = KEYS[k]
	var b: Array = KEYS[k + 1]
	var t := clampf((u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
	# Ease: accelerate into contact, decelerate out of it.
	t = t * t * (3.0 - 2.0 * t)
	var pos := (a[1] as Vector3).lerp(b[1], t)
	var ha := Basis.looking_at(-(a[3] as Vector3).normalized(), (a[2] as Vector3).normalized())
	var hb := Basis.looking_at(-(b[3] as Vector3).normalized(), (b[2] as Vector3).normalized())
	var basis := Basis(ha.get_rotation_quaternion().slerp(hb.get_rotation_quaternion(), t))
	pos += Vector3(0.006 * sin(walk_bob), 0.008 * absf(cos(walk_bob)), 0.0)
	axe_pivot.transform = Transform3D(basis, pos)
	_solve_arms()


## Carrying: axe stowed, both gloves on the log at the given world grips.
func pose_carry(grips: Array) -> void:
	axe_pivot.visible = false
	if grips.size() < 2:
		return
	var cam_basis := global_basis
	var right := cam_basis.x
	var down := -cam_basis.y
	var back := cam_basis.z
	var ur: Node3D = bones["UpperArmR"]
	LimbIK.solve_nodes(ur, bones["ForearmR"], fore_len + 0.04, grips[1], ur.global_position + right * 0.5 + down * 0.6 + back * 0.1)
	var ul: Node3D = bones["UpperArmL"]
	LimbIK.solve_nodes(ul, bones["ForearmL"], fore_len + 0.04, grips[0], ul.global_position - right * 0.3 + down * 0.6 + back * 0.1)
	for side in ["L", "R"]:
		var hand: Node3D = bones["Hand" + side]
		var x := -cam_basis.z
		var y := cam_basis.y
		hand.global_basis = Basis(x.cross(y).normalized(), y, -x)


func _solve_arms() -> void:
	axe_pivot.visible = true
	var cam_basis := global_basis
	var right := cam_basis.x
	var down := -cam_basis.y
	var back := cam_basis.z
	var ur: Node3D = bones["UpperArmR"]
	LimbIK.solve_nodes(ur, bones["ForearmR"], fore_len + 0.04, grip_r.global_position, ur.global_position + right * 0.5 + down * 0.6 + back * 0.1)
	var ul: Node3D = bones["UpperArmL"]
	if _two_hands:
		LimbIK.solve_nodes(ul, bones["ForearmL"], fore_len + 0.04, grip_l.global_position, ul.global_position - right * 0.4 + down * 0.6 + back * 0.1)
	else:
		# Free hand rests low at the side, out of the way.
		var rest := global_transform * Vector3(-0.3, -0.62, -0.25)
		LimbIK.solve_nodes(ul, bones["ForearmL"], fore_len + 0.04, rest, ul.global_position - right * 0.5 + down * 0.5)
	var handle := axe_pivot.global_basis.y.normalized() if saw_model == null else axe_pivot.global_basis.x.normalized()
	for side in (["L", "R"] if _two_hands else ["R"]):
		var hand: Node3D = bones["Hand" + side]
		var fdown := -hand.global_basis.y
		var x := handle
		var y := -(fdown - x * fdown.dot(x)).normalized()
		hand.global_basis = Basis(x, y, x.cross(y).normalized())


func head_position() -> Vector3:
	return head_marker.global_position
