class_name TimberBody
extends RigidBody3D
## One physical run of connected trunk segments (or a single free piece).
## Local frame: origin on the trunk axis at the original tree base, +Y along
## the trunk (lengths are meters from the base, as in the timber record).
## Partially cut boundaries show a V groove of fresh wood; cut ends get
## end-grain caps facing outward; uncut boundaries carry a paint mark. The
## crown (non-payable brush) rides with the run holding the top segment
## until it is cut away.
##
## Bodies are frozen (static) while resting: only pieces that were just cut,
## dropped or set down simulate, briefly, and freeze again.

const TIMBER_LAYER := 8

var service: TimberService
var key := ""
var tree_id := -1
var ks: Array[int] = []
var crown := false
var rec: Dictionary
var _seg_nodes := {}            # k -> MeshInstance3D
var _crown_node: MeshInstance3D
var _dynamic := false
var _still := 0.0
var _age := 0.0
var _impact_done := false


func setup(svc: TimberService, body_key: String, tid: int, segs: Array[int], with_crown: bool, pose: Transform3D, dynamic: bool) -> void:
	service = svc
	key = body_key
	tree_id = tid
	ks = segs
	crown = with_crown
	rec = service.records[tid]
	collision_layer = 1 | TIMBER_LAYER
	collision_mask = 1
	continuous_cd = true
	linear_damp = 0.8
	angular_damp = 3.0
	contact_monitor = true
	max_contacts_reported = 2
	set_meta("timber_body", true)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.95
	pm.bounce = 0.02
	physics_material_override = pm
	var mass_total := 0.0
	for k in ks:
		_build_segment(k)
		_add_segment_shape(k)
		var s: Dictionary = rec.segments[k]
		var r := TimberMesh.radius_at(rec, (float(s.a) + float(s.b)) * 0.5)
		mass_total += 520.0 * PI * r * r * (float(s.b) - float(s.a))
	if crown:
		_build_crown()
		mass_total += 120.0
	mass = clampf(mass_total, 15.0, 2500.0)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	global_transform = pose
	set_dynamic(dynamic)
	body_entered.connect(_on_body_entered)


func set_dynamic(on: bool) -> void:
	if on and service:
		service._nav_mark(self, false)
	_dynamic = on
	freeze = not on
	_still = 0.0
	_age = 0.0
	set_physics_process(on)


func is_resting() -> bool:
	return freeze


func is_single_piece() -> bool:
	return ks.size() == 1 and not crown


func sid_list() -> Array[String]:
	var out: Array[String] = []
	for k in ks:
		out.append(str(rec.segments[k].sid))
	return out


## Lengths (from the base) covered by this body: x = low end, y = high end.
func span() -> Vector2:
	var lo: float = rec.segments[ks.min()].a
	var hi: float = rec.segments[ks.max()].b
	return Vector2(lo, hi)


# ------------------------------------------------------------------- visuals

## Visual progress of boundary k (-1 = crown cut), 0 if untouched.
func _cut_progress(k: int) -> float:
	if k == -1:
		return clampf(float(rec.crown.work) / float(rec.crown.required), 0.0, 0.999) if bool(rec.crown.attached) else 0.0
	if k < 0 or k >= rec.bounds.size():
		return 0.0
	var b: Dictionary = rec.bounds[k]
	if bool(b.cut):
		return 0.0
	return clampf(float(b.work) / float(b.required), 0.0, 0.999)


func _build_segment(k: int) -> void:
	var n: int = rec.segments.size()
	var lo_cap := not (k - 1) in ks
	var top := k == n - 1
	var hi_cap := not (k + 1) in ks and not (top and crown)
	var p_lo := 0.0 if lo_cap else _cut_progress(k - 1)
	var p_hi := 0.0
	var mark := false
	if top and crown:
		p_hi = _cut_progress(-1)
		mark = true
	elif not hi_cap:
		p_hi = _cut_progress(k)
		mark = true
	var mesh := TimberMesh.segment_mesh(rec, k, lo_cap, hi_cap, p_lo, p_hi, mark)
	var mi: MeshInstance3D = _seg_nodes.get(k)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Seg%d" % k
		add_child(mi)
		_seg_nodes[k] = mi
	mi.mesh = mesh


func _add_segment_shape(k: int) -> void:
	var s: Dictionary = rec.segments[k]
	var cs := CollisionShape3D.new()
	cs.name = "Shape%d" % k
	var cyl := CylinderShape3D.new()
	var mid := (float(s.a) + float(s.b)) * 0.5
	cyl.radius = maxf(TimberMesh.radius_at(rec, mid), 0.05)
	cyl.height = maxf(float(s.b) - float(s.a) - 0.02, 0.1)
	cs.shape = cyl
	cs.position = Vector3(0, mid, 0)
	add_child(cs)


func _build_crown() -> void:
	var sp := int(rec.species)
	var v := int(rec.variant)
	var mesh: ArrayMesh = Game.vegetation.meshes.near[sp][v]
	_crown_node = MeshInstance3D.new()
	_crown_node.name = "Crown"
	_crown_node.mesh = mesh
	# Tree mesh space -> body space (+Y = trunk axis).
	var fr: Basis = rec.frame
	var bb: Basis = rec.base_basis
	_crown_node.transform = Transform3D(fr.inverse() * bb, Vector3.ZERO)
	var bark := (mesh.surface_get_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
	var leaf := (mesh.surface_get_material(1) as ShaderMaterial).duplicate() as ShaderMaterial
	var idx := int(rec.idx)
	var seed_v: int = World.trees.seed[idx]
	for m: ShaderMaterial in [bark, leaf]:
		m.set_shader_parameter("actor_height", float(World.trees.height[idx]))
		m.set_shader_parameter("actor_tint", float(seed_v & 255) / 255.0)
		m.set_shader_parameter("sway_scale", 0.0)
		m.set_shader_parameter("clip_mode", 1)
		m.set_shader_parameter("clip_y", float(rec.merch_top) / float(rec.ys))
	_crown_node.set_surface_override_material(0, bark)
	_crown_node.set_surface_override_material(1, leaf)
	add_child(_crown_node)
	var cs := CollisionShape3D.new()
	cs.name = "CrownShape"
	var bx := BoxShape3D.new()
	var h: float = World.trees.height[idx]
	var cw := clampf(h * 0.12, 1.0, 2.6)
	var top: float = rec.merch_top
	bx.size = Vector3(cw, maxf(h * 0.95 - top, 1.0), cw * 0.55)
	cs.shape = bx
	cs.position = Vector3(0, top + bx.size.y * 0.5, 0)
	cs.rotation.y = float(seed_v % 180) * 0.01745
	add_child(cs)


## Updates the groove at boundary `k` (-1 = crown cut) without rebuilding
## unrelated segments.
func refresh_cut(k: int) -> void:
	var n: int = rec.segments.size()
	var touched: Array[int] = []
	if k == -1:
		touched.append(n - 1)
	else:
		touched.append_array([k, k + 1])
	for t in touched:
		if t in ks:
			_build_segment(t)


func drop_crown() -> void:
	crown = false
	if _crown_node:
		# Brush residue: stays where it was, then sinks away (non-payable).
		var brush := _crown_node
		var g := brush.global_transform
		remove_child(brush)
		get_parent().add_child(brush)
		brush.global_transform = g
		brush.add_to_group("timber_brush")
		var tw := brush.create_tween()
		tw.tween_interval(25.0)
		tw.tween_property(brush, "position", brush.position - Vector3(0, 2.5, 0), 30.0)
		tw.tween_callback(brush.queue_free)
		_crown_node = null
	var cs := get_node_or_null("CrownShape")
	if cs:
		cs.free()
	_build_segment(ks.max())


# -------------------------------------------------------------- interaction

func get_interact_text() -> String:
	if is_single_piece():
		var s: Dictionary = rec.segments[ks[0]]
		return "Pick up log  (%d%% of a hand load)" % int(round(100.0 * float(s.mte) / TimberService.HAND_BUDGET_MTE))
	return "Trunk: buck it at the orange marks first"


func interact(by: Node) -> void:
	if by.has_method("try_pick_up"):
		by.try_pick_up(self)


## Length along the trunk (m from base) for a world point on this body.
func length_at_point(world_point: Vector3) -> float:
	return (global_transform.affine_inverse() * world_point).y


func piece_world_center(k: int) -> Vector3:
	var s: Dictionary = rec.segments[k]
	return global_transform * Vector3(0, (float(s.a) + float(s.b)) * 0.5, 0)


## Samples along the trunk axis (world): [point, radius] pairs.
func axis_samples(count := 5) -> Array:
	var sp := span()
	var out := []
	for i in count:
		var y := lerpf(sp.x + 0.05, sp.y - 0.05, float(i) / maxf(count - 1, 1))
		out.append([global_transform * Vector3(0, y, 0), TimberMesh.radius_at(rec, y)])
	return out


## True if something solid is directly under the run (terrain, rock, another
## log, a building). Used to wake pieces whose support was removed.
func has_support() -> bool:
	if not is_inside_tree():
		return true
	var space := get_world_3d().direct_space_state
	for sample in axis_samples(5):
		var p: Vector3 = sample[0]
		var r: float = sample[1]
		if p.y - r <= World.height_at(p.x, p.z) + 0.12:
			return true
		var q := PhysicsRayQueryParameters3D.create(p, p - Vector3(0, r + 0.25, 0), 1)
		q.exclude = [get_rid()]
		if not space.intersect_ray(q).is_empty():
			return true
	if crown:
		var top := global_transform * Vector3(0, float(rec.merch_top) + 2.0, 0)
		if top.y - 1.2 <= World.height_at(top.x, top.z) + 0.2:
			return true
	return false


# ------------------------------------------------------------------ settling

func _on_body_entered(_other: Node) -> void:
	if _impact_done or freeze:
		return
	var v := linear_velocity.length()
	if v > 1.2:
		_impact_done = true
		LoggingFX.play(LoggingFX.Sound.CLUNK, global_position, clampf(-14.0 + v * 2.0, -14.0, -4.0))


func _physics_process(delta: float) -> void:
	if not _dynamic:
		return
	_age += delta
	var still := linear_velocity.length() < 0.12 and angular_velocity.length() < 0.15
	_still = _still + delta if still else 0.0
	# Bounded local simulation: settle, or give up rolling after a while.
	if _still > 0.5 or (sleeping and _age > 0.3) or _age > 9.0:
		set_dynamic(false)
		_impact_done = false
		service.on_body_settled(self)
