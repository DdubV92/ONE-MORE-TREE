class_name PlacementValidator
extends RefCounted
## Grounding audit for ordinary scenery (Phase 1 baseline; Prompt 7 owns the
## full-island certification). Checks real support under footprints instead
## of trusting mesh pivots, and reports exact IDs/positions.
##
## Intentional exceptions are tagged, not treated as defects:
##   bridge decks, water surfaces, buoys (buoyant), lamp heads and wall
##   lamps (mounted), roof/porch parts (structural), future VFX.

const SUPPORT_TOLERANCE := 0.03     # max gap between base and lowest ground under it (m)
const MAX_EMBED := 1.4              # deepest acceptable burial of the uphill side (m)
const STAND_DISTANCE := 0.85        # where a person stands to chop (m from trunk surface)

static var exceptions := {
	"bridge": "intentional span over water",
	"buoy": "buoyant, follows the wave model",
	"water_surface": "water region surface",
	"lamp_head": "mounted on a pole",
	"wall_lamp": "mounted on a wall",
	"camera_mount": "mounted on a support (reserved)",
}


static func audit_trees() -> Dictionary:
	var floating := []
	var overburied := []
	var in_water := []
	var on_rock := []
	var no_stand := []
	var rock_hash := _rock_hash()
	var tree_hash := _tree_hash()
	for i in World.tree_count():
		var x: float = World.trees.x[i]
		var z: float = World.trees.z[i]
		var r: float = World.trees.radius[i]
		var base := World.tree_position(i)
		var lowest := INF
		var highest := -INF
		for k in 8:
			var a := TAU * k / 8.0
			var h := World.height_at(x + cos(a) * r * 1.45, z + sin(a) * r * 1.45)
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
		lowest = minf(lowest, World.height_at(x, z))
		if base.y - lowest > SUPPORT_TOLERANCE:
			floating.append({"id": World.trees.id[i], "pos": base, "gap": base.y - lowest})
		if highest - base.y > MAX_EMBED:
			overburied.append({"id": World.trees.id[i], "pos": base, "embed": highest - base.y})
		if World.water_depth_at(x, z) > 0.02:
			in_water.append({"id": World.trees.id[i], "pos": base})
		for ri in rock_hash.get(_key(x, z, 8.0), []):
			if Vector2(x, z).distance_to(Vector2(World.rocks.x[ri], World.rocks.z[ri])) < World.rock_radius(ri) + r:
				on_rock.append({"id": World.trees.id[i], "rock": ri})
		if cut_stands(i, tree_hash, rock_hash).is_empty():
			no_stand.append({"id": World.trees.id[i], "pos": base})
	return {"checked": World.tree_count(), "floating": floating, "overburied": overburied, "in_water": in_water, "on_rock": on_rock, "no_cut_stand": no_stand}


static func audit_rocks() -> Dictionary:
	var floating := []
	for i in (World.rocks.x as PackedFloat32Array).size():
		var p := World.rock_position(i)
		var s: float = World.rocks.scale[i]
		var squash := World.rock_squash(i)
		var bottom := p.y - 0.2 * s * squash
		var lowest := INF
		# Elliptical footprint for stretched slabs (Phase 12 shelves).
		var bs := World.rock_basis(i)
		for k in 12:
			var a := TAU * k / 12.0
			var off := bs * Vector3(cos(a) * 0.38, 0.0, sin(a) * 0.38)
			lowest = minf(lowest, World.height_at(p.x + off.x, p.z + off.z))
		if bottom - lowest > SUPPORT_TOLERANCE:
			floating.append({"index": i, "pos": p, "gap": bottom - lowest})
	return {"checked": (World.rocks.x as PackedFloat32Array).size(), "floating": floating}


## Positions where a person can stand to chop this tree: around the trunk at
## arm's reach, on walkable ground, not inside another trunk or rock and not
## in water. Shared by the player hint and future worker job planning.
static func cut_stands(i: int, tree_hash: Dictionary = {}, rock_hash: Dictionary = {}) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x: float = World.trees.x[i]
	var z: float = World.trees.z[i]
	var r: float = World.trees.radius[i]
	var d := r + STAND_DISTANCE
	for k in 8:
		var a := TAU * k / 8.0
		var p := Vector2(x + cos(a) * d, z + sin(a) * d)
		if World.water_depth_at(p.x, p.y) > 0.3:
			continue
		if World.normal_at(p.x, p.y).y < 0.72:
			continue
		var blocked := false
		for j in tree_hash.get(_key(p.x, p.y, 8.0), []):
			if j != i and p.distance_to(Vector2(World.trees.x[j], World.trees.z[j])) < float(World.trees.radius[j]) + 0.35:
				blocked = true
		for ri in rock_hash.get(_key(p.x, p.y, 8.0), []):
			if p.distance_to(Vector2(World.rocks.x[ri], World.rocks.z[ri])) < World.rock_radius(ri) * 1.11 + 0.3:
				blocked = true
		if not blocked:
			out.append(Vector3(p.x, World.height_at(p.x, p.y), p.y))
	return out


static func _key(x: float, z: float, cell: float) -> Vector2i:
	return Vector2i(int(floor(x / cell)), int(floor(z / cell)))


static func _tree_hash() -> Dictionary:
	var h := {}
	for i in World.tree_count():
		var x: float = World.trees.x[i]
		var z: float = World.trees.z[i]
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var k := _key(x, z, 8.0) + Vector2i(dx, dz)
				if not h.has(k):
					h[k] = []
				h[k].append(i)
	return h


static func _rock_hash() -> Dictionary:
	var h := {}
	for i in (World.rocks.x as PackedFloat32Array).size():
		var x: float = World.rocks.x[i]
		var z: float = World.rocks.z[i]
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var k := _key(x, z, 8.0) + Vector2i(dx, dz)
				if not h.has(k):
					h[k] = []
				h[k].append(i)
	return h


## Physical check of camp anchors (needs the built world): each grounded
## anchor must have support within 0.35 m below it.
static func audit_anchors(world: Node3D, groups: PackedStringArray) -> Array:
	var bad := []
	var space := world.get_world_3d().direct_space_state
	for g in groups:
		for n in world.get_tree().get_nodes_in_group(g):
			var p: Vector3 = (n as Node3D).global_position
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.4, 0), p - Vector3(0, 0.35, 0))
			var hit := space.intersect_ray(q)
			var ground := World.height_at(p.x, p.z)
			if hit.is_empty() and absf(p.y - ground) > 0.35:
				bad.append({"group": g, "node": str(n.name), "pos": p, "terrain": ground})
	return bad


static func write_report(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
