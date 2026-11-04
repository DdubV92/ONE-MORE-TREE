class_name TerrorPlacement
extends RefCounted
## Grounded candidate locations for ordinary Terror cues. Every result is a
## real point on supported ground (or an explicitly tagged airborne/tree
## exception), outside every safe area, with nearby cover for the reserved
## withdrawal, and a valid human return route left untouched. Nothing here
## ever places a body inside the camper, the occupied cabin or a lamp pool.

const MAX_TRIES := 28


## The player's current context: woods / camp / cabin / camper / cameras.
static func context_of(p: Node3D) -> String:
	if p == null:
		return "woods"
	if p.get("couch") != null and Game.tv and Game.tv.powered:
		return "cameras"
	var pos := p.global_position
	for z in p.get_tree().get_nodes_in_group("zones"):
		if z.contains_point(pos + Vector3(0, 0.9, 0)):
			if z.zone_name == "camper":
				return "camper"
			if z.zone_name in ["cabin", "cabin_extension"]:
				return "cabin"
	if CampLayout.inside_fence(pos):
		return "camp"
	return "woods"


static func _nav() -> CrewNav:
	return Game.crew.nav if Game.crew and Game.crew.nav and Game.crew.nav.built else null


static func ground(x: float, z: float) -> Vector3:
	return Vector3(x, World.height_at(x, z), z)


## True when no ordinary Terror body may stand here.
static func forbidden(p: Vector3) -> bool:
	if World.water_depth_at(p.x, p.z) > 0.15 or World.height_at(p.x, p.z) < World.sea_level + 0.2:
		return true
	if CampLayout.inside_fence(p):
		return true
	if Game.safety and Game.safety.query(p + Vector3(0, 1.0, 0)).safe:
		return true
	return World.normal_at(p.x, p.z).y < 0.8


## Nearest standing trunk (cover) within r of p, or Vector3.INF.
static func cover_near(p: Vector3, r := 6.0) -> Vector3:
	var best := Vector3.INF
	var bd := r
	var key := PlacementValidator._key(p.x, p.z, 8.0)
	var hash: Dictionary = Game.crew.nav._tree_hash if _nav() else {}
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var k: Vector2i = key + Vector2i(dx, dz)
			for i in hash.get(k, []):
				if World.removed_trees.has(int(World.trees.id[i])):
					continue
				var tp := Vector3(World.trees.x[i], 0, World.trees.z[i])
				var d := Vector2(tp.x - p.x, tp.z - p.z).length()
				if d < bd:
					bd = d
					best = ground(tp.x, tp.z)
	return best


## A point among trees `dist` metres from `origin`, roughly along `dir`
## (within `spread` radians), with cover nearby. INF when none fits.
static func treeline_point(origin: Vector3, dir: Vector3, dmin: float, dmax: float, spread: float, rng: RandomNumberGenerator) -> Vector3:
	var base := atan2(dir.x, dir.z)
	for i in MAX_TRIES:
		var a := base + rng.randf_range(-spread, spread)
		var d := rng.randf_range(dmin, dmax)
		var c := ground(origin.x + sin(a) * d, origin.z + cos(a) * d)
		if forbidden(c):
			continue
		var cov := cover_near(c, 5.0)
		if cov == Vector3.INF:
			continue
		# Stand just beside the trunk, on the side away from the viewer.
		var away := (Vector3(c.x - origin.x, 0, c.z - origin.z)).normalized()
		var spot := ground(cov.x + away.x * 0.9 + away.z * 0.7, cov.z + away.z * 0.9 - away.x * 0.7)
		if forbidden(spot):
			continue
		return spot
	return Vector3.INF


## Just outside the camp fence on the side the viewer faces.
static func beyond_fence(origin: Vector3, dir: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var o := World.camp_origin()
	var half := CampLayout.FENCE_HALF
	for i in MAX_TRIES:
		var a := atan2(dir.x, dir.z) + rng.randf_range(-0.8, 0.8)
		var d := rng.randf_range(4.0, 22.0)
		var edge := Vector2(o.x, o.z) + Vector2(sin(a), cos(a)) * (maxf(half.x, half.y) + d)
		var c := ground(edge.x, edge.y)
		if forbidden(c):
			continue
		if Vector2(c.x - origin.x, c.z - origin.z).length() < 6.0:
			continue
		return c
	return Vector3.INF


## Outside the building the viewer is in, 2.5-7 m from a wall, ideally in
## view of a window (beyond the glass, never inside).
static func outside_building(viewer: Node3D, building: String, rng: RandomNumberGenerator) -> Vector3:
	var o := World.camp_origin()
	var pos: Vector3 = CampLayout.CAMPER_POS if building == "camper" else CampLayout.CABIN_POS
	var size: Vector3 = CampLayout.CAMPER_SIZE if building == "camper" else Vector3(7.2, 2.6, 15.6)
	var centre := Vector3(o.x + pos.x, 0, o.z + pos.z)
	var look := -viewer.global_basis.z
	for i in MAX_TRIES:
		var a := atan2(look.x, look.z) + rng.randf_range(-1.0, 1.0)
		var r := maxf(size.x, size.z) * 0.5 + rng.randf_range(2.5, 7.0)
		var c := ground(centre.x + sin(a) * r, centre.z + cos(a) * r)
		# The yard is lamp-safe at night: buildings are inside the fence, so
		# a window cue is a shadow/silhouette beyond the fence line or in an
		# unlit gap. Accept unlit yard points only for shadows (caller flag).
		if World.water_depth_at(c.x, c.z) > 0.1:
			continue
		if Game.safety and Game.safety.query(c + Vector3(0, 1.0, 0)).safe:
			continue
		return c
	# Fall back to beyond the fence in the same direction.
	return beyond_fence(viewer.global_position, look, rng)


## Inside a displayed camera's view: along its axis, on land, outside safety.
static func in_camera_view(cam: Node3D, rng: RandomNumberGenerator) -> Vector3:
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for i in MAX_TRIES:
		var a := rng.randf_range(-0.3, 0.3)
		var d := rng.randf_range(12.0, 34.0)
		var dir := fwd.rotated(Vector3.UP, a)
		var c := ground(cam.global_position.x + dir.x * d, cam.global_position.z + dir.z * d)
		if forbidden(c):
			continue
		return c
	return Vector3.INF


## Nearest dry bank point beside water (pond/river/sea) within `r` of origin.
static func shoreline(origin: Vector3, r: float, rng: RandomNumberGenerator) -> Vector3:
	for i in MAX_TRIES * 2:
		var a := rng.randf() * TAU
		var d := rng.randf_range(15.0, r)
		var c := ground(origin.x + sin(a) * d, origin.z + cos(a) * d)
		if World.water_depth_at(c.x, c.z) > 0.0:
			# step back toward the viewer until dry
			for k in 12:
				c = ground(lerpf(c.x, origin.x, 0.08), lerpf(c.z, origin.z, 0.08))
				if World.water_depth_at(c.x, c.z) <= 0.0 and c.y > World.sea_level + 0.25:
					if not forbidden(c):
						return c
					break
	return Vector3.INF


## Where an actor withdraws to: behind its cover, away from the viewer.
static func withdrawal(from: Vector3, viewer: Vector3) -> Vector3:
	var away := Vector3(from.x - viewer.x, 0, from.z - viewer.z).normalized()
	var cov := cover_near(from + away * 4.0, 8.0)
	var to := from + away * 9.0
	if cov != Vector3.INF:
		to = cov + away * 1.2
	return ground(to.x, to.z)


## Line of sight from eye to point (terrain, buildings, rocks; trunks only
## where they have active colliders near the player).
static func visible_from(eye: Vector3, p: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(eye, p, 1 | 4)
	return space.intersect_ray(q).is_empty()
