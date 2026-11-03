class_name TimberRecovery
extends RefCounted
## Repairs genuinely inaccessible timber (never ordinary distant wood).
## Reason codes (inspectable, logged with positions so terrain/generation
## faults can be fixed at the source):
##   invalid_pose    non-finite or degenerate transform (e.g. bad migration)
##   out_of_bounds   outside the island grid or far below sea level
##   below_terrain   the trunk axis is buried in the ground
##   deep_water      resting where the water is deeper than wading depth
## Recovery moves the piece to the nearest validated dry, gentle ground
## (searching outward), or to the camp recovery point if none is found.
## It keeps ID, quantity, share, receipts and ownership and never pays.
## Carried, vehicle-reserved, accepted or burning pieces are never touched
## (they have no TimberBody). The player, trucks and crew are never moved.

const MAX_SEARCH := 60.0


static func diagnose(b: TimberBody) -> String:
	var xf := b.global_transform
	if not xf.origin.is_finite() or not xf.basis.x.is_finite() or absf(xf.basis.determinant()) < 0.5:
		return "invalid_pose"
	var c := b.global_transform * Vector3(0, (b.span().x + b.span().y) * 0.5, 0)
	if not World.in_bounds(Vector2(c.x, c.z)) or c.y < World.sea_level - 30.0:
		return "out_of_bounds"
	var buried := 0
	var samples := b.axis_samples(5)
	for s in samples:
		var p: Vector3 = s[0]
		var r: float = s[1]
		if p.y + r * 0.5 < World.height_at(p.x, p.z) - 0.05:
			buried += 1
	if buried >= 3:
		return "below_terrain"
	if Game.water:
		var deep := 0
		for s in samples:
			var p: Vector3 = s[0]
			if Game.water.depth_at(p.x, p.z) > World.config.wade_depth_limit:
				deep += 1
		if deep >= 3:
			return "deep_water"
	return ""


## Moves the body to a validated spot; returns a description of the target.
static func recover(b: TimberBody) -> String:
	var xf := b.global_transform
	var start := Vector3.ZERO
	if xf.origin.is_finite():
		start = xf * Vector3(0, (b.span().x + b.span().y) * 0.5, 0)
	else:
		start = World.camp_origin()
	var length := b.span().y - b.span().x
	var radius := TimberMesh.radius_at(b.rec, b.span().x)
	var spot := find_ground(Vector2(start.x, start.z), length, radius, b.get_world_3d() if b.is_inside_tree() else null, b.get_rid())
	var target := "bank"
	if spot == Vector3.INF:
		spot = CampLayout.world(CampLayout.RECOVERY_POINT)
		target = "camp_recovery_point"
	place_lying(b, spot, Vector3.RIGHT.rotated(Vector3.UP, b.global_basis.get_euler().y), radius)
	return "%s(%.1f,%.1f)" % [target, spot.x, spot.z]


## Nearest dry, gentle, unobstructed ground point (spiral search) or INF.
static func find_ground(from: Vector2, length: float, radius: float, world: World3D, exclude: RID) -> Vector3:
	var r := 0.0
	while r <= MAX_SEARCH:
		var n := 1 if r == 0.0 else int(ceil(TAU * r / 2.5))
		for i in n:
			var a := TAU * float(i) / n
			var p := from + Vector2(cos(a), sin(a)) * r
			if not World.in_bounds(p):
				continue
			var h := World.height_at(p.x, p.y)
			if h < World.sea_level + 0.25 or World.water_depth_at(p.x, p.y) > 0.05:
				continue
			if World.normal_at(p.x, p.y).y < 0.88:
				continue
			if CampLayout.inside_fence(Vector3(p.x, 0, p.y)):
				continue
			if world and not _clear(world, Vector3(p.x, h + radius + 0.08, p.y), length, radius, exclude):
				continue
			return Vector3(p.x, h, p.y)
		r += 2.0
	return Vector3.INF


static func _clear(world: World3D, centre: Vector3, length: float, radius: float, exclude: RID) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = maxf(length, 0.2)
	q.shape = cyl
	q.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), centre)
	q.collision_mask = 1 | 2
	q.exclude = [exclude]
	return world.direct_space_state.intersect_shape(q, 1).is_empty()


## Lays the body horizontally with its span centred over `ground` and lets it
## settle briefly.
static func place_lying(b: TimberBody, ground: Vector3, dir: Vector3, radius: float) -> void:
	var y_axis := Vector3(dir.x, 0, dir.z).normalized()
	if y_axis.length() < 0.5:
		y_axis = Vector3.RIGHT
	var basis := TimberMesh.frame_for(y_axis)
	var mid := (b.span().x + b.span().y) * 0.5
	var centre := ground + Vector3(0, radius + 0.06, 0)
	b.global_transform = Transform3D(basis, centre - basis.y * mid)
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.set_dynamic(true)
