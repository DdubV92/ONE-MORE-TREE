class_name TreeActor
extends Node3D
## The single live representation of one modified original tree. Created when
## the first valid axe contact lands; the instanced forest stops drawing and
## colliding that tree at the same moment (no ghost canopy/collision).
##
## Phases: NOTCHED (static, visible wedge) -> FALLING (hinge rotation about
## the far edge of the cut, then a tuned rigid body) -> FALLEN (frozen at a
## validated, supported pose). The stump stays at the base as a tracked
## object for later removal.

const HINGE_RELEASE_DEG := 18.0
const SETTLE_TIMEOUT := 14.0
const DENSITY := 520.0              # kg/m3, softwood green-ish
const TIMBER_LAYER := 8

var service: TreeService
var tree_id := -1
var idx := -1
var species := 0
var variant := 0
var base_xf: Transform3D            # grounded instance transform (with scale)
var xs := 1.0
var ys := 1.0
var height := 15.0
var cut_h := 0.75                    # world meters above base
var cut_y_local := 0.75
var radius_cut := 0.3                # world radius at the cut
var fall_dir := Vector3.FORWARD
var notch_dir_local := Vector2(0, 1)

var whole: MeshInstance3D            # standing/falling tree mesh (bark+foliage)
var bark_mat: ShaderMaterial
var leaf_mat: ShaderMaterial
var notch_mesh: MeshInstance3D
var standing_body: StaticBody3D
var stump: Node3D
var trunk_root: Node3D               # pivot-free node that carries the falling trunk visual
var body: RigidBody3D
var _phase := "standing"
var _theta := 0.0
var _omega := 0.0
var _pivot := Vector3.ZERO
var _axis := Vector3.RIGHT
var _still_t := 0.0
var _fall_t := 0.0
var _corrections := 0
var _impacted := false


func setup(svc: TreeService, id: int, index: int) -> void:
	service = svc
	tree_id = id
	idx = index
	species = int(World.trees.species[idx])
	variant = int(World.trees.variant[idx])
	height = float(World.trees.height[idx])
	base_xf = Game.vegetation.tree_transform(idx)
	ys = base_xf.basis.y.length()
	xs = base_xf.basis.x.length()
	var rec := service.record(tree_id)
	cut_h = float(rec.cut_height)
	cut_y_local = cut_h / ys
	radius_cut = TreeBuilder.trunk_radius_local(species, variant, cut_y_local) * xs
	var fd: Array = rec.fall_dir
	fall_dir = Vector3(fd[0], 0, fd[1]).normalized() if Vector2(fd[0], fd[1]).length() > 0.01 else Vector3.FORWARD
	var cd: Array = rec.cut_dir
	var cut_world := Vector3(cd[0], 0, cd[1])
	var local := base_xf.basis.inverse() * cut_world
	notch_dir_local = Vector2(local.x, local.z).normalized() if Vector2(local.x, local.z).length() > 0.001 else Vector2(0, 1)
	_build_whole()
	_build_standing_collision()
	set_notch(service.progress(tree_id))


func _build_whole() -> void:
	var mesh: ArrayMesh = Game.vegetation.meshes.near[species][variant]
	whole = MeshInstance3D.new()
	whole.name = "Tree"
	whole.mesh = mesh
	whole.transform = base_xf
	bark_mat = (mesh.surface_get_material(0) as ShaderMaterial).duplicate()
	leaf_mat = (mesh.surface_get_material(1) as ShaderMaterial).duplicate()
	var seed_v: int = World.trees.seed[idx]
	for m in [bark_mat, leaf_mat]:
		m.set_shader_parameter("actor_height", height)
		m.set_shader_parameter("actor_phase", float((seed_v >> 8) & 255) / 255.0)
		m.set_shader_parameter("actor_tint", float(seed_v & 255) / 255.0)
	whole.set_surface_override_material(0, bark_mat)
	whole.set_surface_override_material(1, leaf_mat)
	add_child(whole)
	notch_mesh = MeshInstance3D.new()
	notch_mesh.name = "NotchWood"
	var nm := ShaderMaterial.new()
	nm.shader = load("res://shaders/cut_face.gdshader")
	nm.set_shader_parameter("radius", TreeBuilder.trunk_radius_local(species, variant, cut_y_local))
	notch_mesh.material_override = nm
	whole.add_child(notch_mesh)


func _build_standing_collision() -> void:
	standing_body = StaticBody3D.new()
	standing_body.name = "StandingCollision"
	standing_body.collision_layer = 1 | 4
	standing_body.set_meta("tree_ids", PackedInt32Array([tree_id]))
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	var h := minf(height * 0.6, 9.0)
	shape.radius = maxf(float(World.trees.radius[idx]) * 0.95, 0.08)
	shape.height = h
	cs.shape = shape
	cs.position = base_xf.origin + Vector3(0, h * 0.5 - 0.2, 0)
	standing_body.add_child(cs)
	add_child(standing_body)


static var _wood: StandardMaterial3D
static func _wood_material() -> StandardMaterial3D:
	if _wood:
		return _wood
	_wood = StandardMaterial3D.new()
	_wood.albedo_texture = load("res://assets/polyhaven/textures/wood_floor_worn/wood_floor_worn_diff.jpg")
	_wood.albedo_color = Color(1.55, 1.35, 1.05)
	_wood.uv1_triplanar = true
	_wood.uv1_scale = Vector3.ONE * 3.0
	_wood.roughness = 0.85
	_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _wood


## Notch depth follows work progress (visible wedge at the real cut side).
func set_notch(p: float) -> void:
	var r_local := TreeBuilder.trunk_radius_local(species, variant, cut_y_local)
	var depth := r_local * 2.0 * service.config.max_notch_depth * clampf(p, 0.0, 1.0)
	bark_mat.set_shader_parameter("notch_enabled", depth > 0.0)
	bark_mat.set_shader_parameter("notch_y", cut_y_local)
	bark_mat.set_shader_parameter("notch_dir", notch_dir_local)
	bark_mat.set_shader_parameter("notch_r", r_local)
	bark_mat.set_shader_parameter("notch_depth", depth)
	bark_mat.set_shader_parameter("notch_open", 0.85)
	notch_mesh.mesh = _notch_faces(r_local, depth, 0.85) if depth > 0.001 else null


func _notch_faces(r: float, depth: float, open: float) -> ArrayMesh:
	# Exposed wood: flat bottom face and rising top face of the wedge.
	var d := notch_dir_local
	var c := r - depth
	var half := acos(clampf(c / r, -1.0, 1.0))
	var base_ang := atan2(d.y, d.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var y0 := cut_y_local
	var pts: Array[Vector2] = []
	for k in n + 1:
		var a := base_ang - half + 2.0 * half * k / n
		pts.append(Vector2(cos(a), sin(a)) * r * 0.985)
	var centre := d * c
	for k in n:
		for face in 2:
			var tri := [centre, pts[k], pts[k + 1]]
			for v2 in tri:
				var u := (v2 as Vector2).dot(d) - c
				var y := y0 + (u * open if face == 1 else 0.0)
				st.set_normal(Vector3.UP if face == 0 else Vector3(-d.x * open, 1.0, -d.y * open).normalized() * -1.0)
				st.add_vertex(Vector3(v2.x, y, v2.y))
	return st.commit()


# ------------------------------------------------------------------ fall

func start_fall() -> void:
	if _phase != "standing":
		return
	_phase = "hinge"
	_build_stump()
	standing_body.queue_free()
	standing_body = null
	# The falling part keeps the whole mesh but clips everything below the cut.
	bark_mat.set_shader_parameter("clip_mode", 1)
	bark_mat.set_shader_parameter("clip_y", cut_y_local)
	trunk_root = Node3D.new()
	trunk_root.name = "Trunk"
	add_child(trunk_root)
	whole.reparent(trunk_root, true)
	_add_cut_cap(trunk_root, base_xf.origin + Vector3(0, cut_h, 0), true)
	var up := Vector3.UP
	_axis = up.cross(fall_dir).normalized()
	_pivot = base_xf.origin + Vector3(0, cut_h, 0) + fall_dir * radius_cut * 0.85
	_theta = deg_to_rad(1.5)
	_omega = 0.02
	_fall_t = 0.0
	LoggingFX.play(LoggingFX.Sound.CRACK, _pivot + Vector3(0, 0.5, 0))
	LoggingFX.play(LoggingFX.Sound.CREAK, _pivot + Vector3(0, 2.0, 0))
	set_physics_process(true)


func _build_stump() -> void:
	stump = Node3D.new()
	stump.name = "Stump"
	stump.position = base_xf.origin
	add_child(stump)
	var r_base := TreeBuilder.trunk_radius_local(species, variant, 0.05) * xs
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius_cut
	cm.bottom_radius = r_base * 1.08
	cm.height = cut_h + 0.15
	cm.radial_segments = 14
	mi.mesh = cm
	mi.position = Vector3(0, (cut_h - 0.15) * 0.5, 0)
	var bark := StandardMaterial3D.new()
	if species == TreeBuilder.Species.BIRCH:
		bark.albedo_color = Color(0.82, 0.8, 0.75)
	else:
		bark.albedo_texture = load("res://assets/polyhaven/textures/pine_bark/pine_bark_diff.jpg" if species == 0 else "res://assets/polyhaven/textures/bark_brown_02/bark_brown_02_diff.jpg")
		bark.albedo_color = Color(0.95, 0.85, 0.78)
		bark.uv1_scale = Vector3(2.0, 1.0, 1.0)
	bark.roughness = 0.9
	mi.material_override = bark
	stump.add_child(mi)
	_add_cut_cap(stump, Vector3(0, cut_h, 0), false)
	var sb := StaticBody3D.new()
	sb.name = "StumpCollision"
	sb.collision_layer = 1
	sb.set_meta("stump_of", tree_id)
	stump.add_to_group("stumps")
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius_cut
	shape.height = cut_h + 0.2
	cs.shape = shape
	cs.position = Vector3(0, (cut_h - 0.2) * 0.5, 0)
	sb.add_child(cs)
	stump.add_child(sb)


func _add_cut_cap(parent: Node3D, world_or_local: Vector3, is_world: bool) -> void:
	# Fresh light wood face with growth rings.
	var cap := MeshInstance3D.new()
	cap.name = "CutFace"
	var cm := CylinderMesh.new()
	cm.top_radius = radius_cut * 0.99
	cm.bottom_radius = radius_cut * 0.99
	cm.height = 0.02
	cm.radial_segments = 16
	cap.mesh = cm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/cut_face.gdshader")
	sm.set_shader_parameter("radius", radius_cut)
	cap.material_override = sm
	parent.add_child(cap)
	if is_world:
		cap.global_position = world_or_local
	else:
		cap.position = world_or_local


func _physics_process(delta: float) -> void:
	match _phase:
		"hinge":
			_hinge(delta)
		"rigid":
			_watch_rigid(delta)


func _hinge(delta: float) -> void:
	# Uniform-rod pivot dynamics about the hinge edge: alpha = 3g/(2L) sin(theta).
	var L := maxf(height - cut_h, 2.0)
	var alpha := 3.0 * 9.81 / (2.0 * L) * sin(_theta) - 0.15 * _omega
	_omega += alpha * delta
	_theta += _omega * delta
	_fall_t += delta
	trunk_root.transform = Transform3D(Basis(_axis, _theta), _pivot - Basis(_axis, _theta) * _pivot)
	if rad_to_deg(_theta) >= HINGE_RELEASE_DEG:
		_to_rigid(_omega)


func _to_rigid(omega: float) -> void:
	_phase = "rigid"
	var world_xf := trunk_root.global_transform
	body = RigidBody3D.new()
	body.name = "FallingTrunk"
	body.collision_layer = TIMBER_LAYER
	body.collision_mask = 1          # terrain, rocks, buildings, standing trees, stumps
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.linear_damp = 0.08
	body.angular_damp = 0.6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.04
	body.physics_material_override = pm
	var L := maxf(height - cut_h, 2.0)
	var r_mid := TreeBuilder.trunk_radius_local(species, variant, cut_y_local + (L * 0.35) / ys) * xs
	body.mass = clampf(DENSITY * PI * radius_cut * radius_cut * L / 2.6, 120.0, 2500.0)
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# Body origin = tree base; the trunk axis runs along +Y in body space.
	body.center_of_mass = Vector3(0, cut_h + L * 0.36, 0)
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = maxf(r_mid, 0.08)
	capsule.height = maxf(L * 0.82, capsule.radius * 2.0 + 0.1)
	cap.shape = capsule
	cap.position = Vector3(0, cut_h + capsule.height * 0.5, 0)
	body.add_child(cap)
	# Crown proxy: a flattened box (branches stop a felled tree from rolling
	# like a bare log; a sphere here would roll down every slope).
	var crown := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	var cw := clampf(height * 0.12, 1.0, 2.6)
	bx.size = Vector3(cw, L * 0.3, cw * 0.55)
	crown.shape = bx
	crown.position = Vector3(0, cut_h + L * 0.72, 0)
	crown.rotation.y = float(int(World.trees.seed[idx]) % 180) * 0.01745
	body.add_child(crown)
	add_child(body)
	# Body frame: rotation of the trunk (no scale), origin at the moved base.
	var rot := trunk_root.global_transform.basis.orthonormalized()
	var base_now := trunk_root.global_transform * base_xf.origin
	body.global_transform = Transform3D(rot, base_now)
	whole.reparent(body, true)
	for c in trunk_root.get_children():
		c.reparent(body, true)
	trunk_root.queue_free()
	trunk_root = null
	if stump:
		body.add_collision_exception_with(stump.get_node("StumpCollision"))
	var w := _axis * omega
	body.angular_velocity = w
	body.linear_velocity = w.cross(base_now - _pivot)
	body.body_entered.connect(_on_body_entered)
	_still_t = 0.0
	_fall_t = 0.0


func _on_body_entered(_other: Node) -> void:
	if _impacted:
		return
	var v := body.linear_velocity.length() + body.angular_velocity.length() * 3.0
	if v > 2.0:
		_impacted = true
		# Bark and branches bite into the ground: damp rolling/sliding so a
		# trunk on a slope settles instead of creeping for seconds.
		body.linear_damp = 0.9
		body.angular_damp = 2.6
		var top := body.global_transform * Vector3(0, cut_h + (height - cut_h) * 0.6, 0)
		LoggingFX.play(LoggingFX.Sound.IMPACT, top)
		LoggingFX.dust(top)
		RenderingServer.global_shader_parameter_set("tree_impact", Vector4(top.x, top.z, Game.world_time, clampf(v / 8.0, 0.3, 1.0)))


func _watch_rigid(delta: float) -> void:
	_fall_t += delta
	var lin := body.linear_velocity.length()
	var ang := body.angular_velocity.length()
	_still_t = _still_t + delta if (lin < 0.25 and ang < 0.2) else 0.0
	if body.sleeping or _still_t > 0.8:
		_settle("rest")
	elif _fall_t > SETTLE_TIMEOUT:
		_settle("timeout(v=%.2f,w=%.2f)" % [lin, ang])


func _settle(reason: String) -> void:
	var r := reason
	var fix := _validate_support()
	if fix != "":
		r = reason + "+" + fix
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.collision_layer = 1 | TIMBER_LAYER
	body.set_meta("fallen_tree", tree_id)
	body.add_to_group("fallen_timber")
	_phase = "fallen"
	set_physics_process(false)
	_push_player_clear()
	service.on_actor_settled(tree_id, body.global_transform, r)


## Bounded recovery: lift a trunk that ended inside the terrain, lower one
## left hanging with nothing beneath it. Returns what was corrected ("" if
## the pose was already supported).
func _validate_support() -> String:
	var xf := body.global_transform
	var L := maxf(height - cut_h, 2.0)
	var worst_pen := 0.0
	var supported := false
	var space := get_world_3d().direct_space_state
	for k in 7:
		var p := xf * Vector3(0, cut_h + L * 0.82 * k / 6.0, 0)
		var r := TreeBuilder.trunk_radius_local(species, variant, cut_y_local + (L * 0.82 * k / 6.0) / ys) * xs
		var ground := World.height_at(p.x, p.z)
		worst_pen = maxf(worst_pen, (ground - (p.y - r)))
		var q := PhysicsRayQueryParameters3D.create(p, p - Vector3(0, r + 0.5, 0), 1)
		q.exclude = [body.get_rid()]
		if not space.intersect_ray(q).is_empty() or p.y - r <= ground + 0.15:
			supported = true
	if worst_pen > 0.35:
		body.global_position += Vector3(0, worst_pen - 0.2, 0)
		return "lifted_from_ground_%.2fm" % worst_pen
	if not supported:
		# Nothing under the trunk: drop it onto the highest ground beneath.
		var drop := INF
		for k in 7:
			var p := xf * Vector3(0, cut_h + L * 0.82 * k / 6.0, 0)
			drop = minf(drop, p.y - World.height_at(p.x, p.z))
		body.global_position -= Vector3(0, maxf(drop - 0.4, 0.0), 0)
		return "lowered_unsupported"
	return ""


func _push_player_clear() -> void:
	var p: Node3D = Game.player
	if p == null:
		return
	var xf := body.global_transform
	var L := maxf(height - cut_h, 2.0)
	var a := xf * Vector3(0, cut_h, 0)
	var b := xf * Vector3(0, cut_h + L * 0.82, 0)
	var pp := p.global_position + Vector3(0, 0.9, 0)
	var ab := b - a
	var t := clampf((pp - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	var closest := a + ab * t
	var d := pp - closest
	d.y = 0.0
	var need := radius_cut + 0.6
	if d.length() < need:
		var dir := d.normalized() if d.length() > 0.01 else xf.basis.x
		p.global_position += dir * (need - d.length() + 0.1)


func report_motion() -> void:
	if body and _phase == "rigid":
		service.on_actor_motion(tree_id, body.global_transform, body.linear_velocity, body.angular_velocity)
	elif _phase == "hinge":
		# Save during the hinge phase: persist the current trunk pose as a
		# rigid start state with the equivalent angular velocity.
		var rot := trunk_root.global_transform.basis.orthonormalized()
		var base_now := trunk_root.global_transform * base_xf.origin
		var w := _axis * _omega
		service.on_actor_motion(tree_id, Transform3D(rot, base_now), w.cross(base_now - _pivot), w)


# ---------------------------------------------------------------- restore

func restore_fallen(pose: Transform3D) -> void:
	_restore_body(pose, Vector3.ZERO, Vector3.ZERO)
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.collision_layer = 1 | TIMBER_LAYER
	body.set_meta("fallen_tree", tree_id)
	body.add_to_group("fallen_timber")
	_phase = "fallen"
	set_physics_process(false)


func restore_falling(pose: Transform3D, lin: Vector3, ang: Vector3) -> void:
	_restore_body(pose, lin, ang)
	_phase = "rigid"
	set_physics_process(true)


func _restore_body(pose: Transform3D, lin: Vector3, ang: Vector3) -> void:
	set_notch(1.0)
	_phase = "hinge"
	_build_stump()
	if standing_body:
		standing_body.queue_free()
		standing_body = null
	bark_mat.set_shader_parameter("clip_mode", 1)
	bark_mat.set_shader_parameter("clip_y", cut_y_local)
	trunk_root = Node3D.new()
	add_child(trunk_root)
	whole.reparent(trunk_root, true)
	_add_cut_cap(trunk_root, base_xf.origin + Vector3(0, cut_h, 0), true)
	_axis = Vector3.UP.cross(fall_dir).normalized()
	_pivot = base_xf.origin
	_to_rigid(0.0)
	body.global_transform = pose
	body.linear_velocity = lin
	body.angular_velocity = ang


func phase() -> String:
	return _phase
