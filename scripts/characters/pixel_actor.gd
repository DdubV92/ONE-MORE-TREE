class_name PixelActor
extends MeshInstance3D
## Phase 24 HD-2D: shows a HumanCharacter as a lit, outlined, directional
## pixel sprite. The 3D rig keeps running (anchors, carry IK, footsteps,
## speech, hunt sightlines) and stays as a shadow-only proxy, so the sprite
## is grounded by the real body's shadow. Each animation clip is baked from
## this actor's own model on first use (PixelBaker); until then the 3D model
## is shown, so nothing ever disappears.
##
## Style: Settings.character_style == "hd2d" (default). "clean"/"pixel" keep
## the old 3D presentation for comparison.

var character: Node3D          # HumanCharacter or DogCharacter
var _clips := {}              # key -> {albedo, normal, frames, loop, length}
var _requested := {}
var _mat: ShaderMaterial
var _showing := false
var _cur_key := ""
var shown_frames := 0


static func enabled() -> bool:
	# Baking needs a real renderer (headless test runs keep the 3D body).
	return str(Settings.get_v("character_style")) == "hd2d" and DisplayServer.get_name() != "headless"


static func attach(ch: Node3D) -> PixelActor:
	var pa := PixelActor.new()
	pa.name = "PixelActor"
	pa.character = ch
	ch.add_child(pa)
	return pa


func _ready() -> void:
	mesh = _quad()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/pixel_actor.gdshader")
	var cell := PixelBaker.cell_for(character)
	var csz := PixelBaker.cell_size_m(cell)
	_mat.set_shader_parameter("cell_px", Vector2(cell))
	_mat.set_shader_parameter("quad_size", csz)
	_mat.set_shader_parameter("foot_margin", PixelBaker.FOOT_MARGIN)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 2.0
	visible = false
	process_priority = 10          # after the rig advanced its animation


static func _quad() -> ArrayMesh:
	# x in [-0.5, 0.5], y in [0, 1]; the shader billboards it.
	var v := PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	var n := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-1.5, -0.2, -1.5), Vector3(3, 3.2, 3))
	return m


func _anim() -> AnimationPlayer:
	return character.get("anim")


func _key() -> Array:
	var clip := str(character.get("current"))
	if clip == "" or not _anim().has_animation(clip):
		clip = "idle"
	var carry: Array = []
	var hc := character as HumanCharacter
	if hc != null and hc.carry_grips.size() == 2 and not hc.arm_ik:
		for g in hc.carry_grips:
			var gp: Vector3 = (g as Node3D).global_position if g is Node3D else g
			var lp := character.to_local(gp)
			carry.append(Vector3(snappedf(lp.x, 0.1), snappedf(lp.y, 0.1), snappedf(lp.z, 0.1)))
	var key := clip + ("|carry%s" % str(carry) if not carry.is_empty() else "")
	return [key, clip, carry]


func _process(_delta: float) -> void:
	if character == null or not is_instance_valid(character):
		return
	var want := enabled() and character.is_visible_in_tree()
	if not want:
		_show(false)
		return
	var k := _key()
	var key: String = k[0]
	if not _clips.has(key):
		if not _requested.has(key):
			_requested[key] = true
			var b := PixelBaker.instance()
			if b != null:
				b.request(self, key, k[1], k[2])
		# Keep the previous sprite clip only if it is the same clip family;
		# otherwise show the 3D body until this clip is baked.
		if _cur_key == "" or _cur_key.get_slice("|", 0) != str(k[1]):
			_show(false)
			return
		key = _cur_key
	var c: Dictionary = _clips[key]
	if key != _cur_key:
		_cur_key = key
		_mat.set_shader_parameter("albedo_atlas", c.albedo)
		_mat.set_shader_parameter("normal_atlas", c.normal)
		_mat.set_shader_parameter("atlas_cells", Vector2(PixelBaker.DIRS, int(c.frames)))
	var t := _anim().current_animation_position if _anim().current_animation != "" else 0.0
	var n := int(c.frames)
	var f := 0
	if bool(c.loop):
		f = int(floor(t / maxf(float(c.length), 0.001) * n)) % n
	else:
		f = clampi(int(round(t / maxf(float(c.length), 0.001) * (n - 1))), 0, n - 1)
	_mat.set_shader_parameter("frame", float(f))
	shown_frames += 1
	_show(true)


func _show(on: bool) -> void:
	if on == _showing:
		return
	_showing = on
	visible = on
	_set_body_shadow_only(character, on)


func _set_body_shadow_only(n: Node, on: bool) -> void:
	for c in n.get_children():
		if c == self:
			continue
		if c is GeometryInstance3D:
			var g := c as GeometryInstance3D
			if on:
				if not g.has_meta("p24_cast"):
					g.set_meta("p24_cast", g.cast_shadow)
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			elif g.has_meta("p24_cast"):
				g.cast_shadow = g.get_meta("p24_cast")
				g.remove_meta("p24_cast")
		_set_body_shadow_only(c, on)


func bake_done(key: String, albedo: Texture2D, normal: Texture2D, frames: int, looped: bool, length: float) -> void:
	_clips[key] = {"albedo": albedo, "normal": normal, "frames": frames, "loop": looped, "length": length}
	# Bounded memory: keep the most recent clips only.
	if _clips.size() > 14:
		for old in _clips.keys():
			if old != key and old != _cur_key:
				_clips.erase(old)
				_requested.erase(old)
				break


func _exit_tree() -> void:
	var b := PixelBaker._inst
	if b != null and is_instance_valid(b):
		b.release(self)


func bake_failed(key: String) -> void:
	_requested.erase(key)


func is_showing() -> bool:
	return _showing
