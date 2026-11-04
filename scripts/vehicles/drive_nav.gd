class_name DriveNav
extends RefCounted
## Drivable route graph for pickups (Phase 5), separate from pedestrian
## navigation. 4 m cells; a cell is drivable when the ground is gentle
## (<= ~19 deg), dry (or a bridge deck), and no standing trunk or rock lies
## within the truck's half-width clearance. Inside the camp fence only the
## open yard is drivable (never through buildings); the fence is crossed at
## the north entrance. Felling a tree re-checks the cells around it, so
## legitimate logging opens corridors; resting logs block their cells.
## Nothing here deletes or ignores trees.

const CELL := 4.0
const CLEAR := 2.4          # trunk/rock clearance from the cell centre (m)
const MAX_SLOPE_NY := 0.945

var origin := Vector2.ZERO
var dims := Vector2i.ZERO
var grid := AStarGrid2D.new()
var crew_nav: CrewNav
var log_refs := {}
var _tree_hash := {}
var _rock_hash := {}


func build(cn: CrewNav) -> void:
	crew_nav = cn
	origin = cn.origin
	dims = Vector2i(int(ceil(cn.dims.x * CrewNav.CELL / CELL)), int(ceil(cn.dims.y * CrewNav.CELL / CELL)))
	grid.region = Rect2i(Vector2i.ZERO, dims)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	_tree_hash = cn._tree_hash
	_rock_hash = PlacementValidator._rock_hash()
	for j in dims.y:
		for i in dims.x:
			_eval(Vector2i(i, j))


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / CELL)), int(floor((p.y - origin.y) / CELL)))


func center(k: Vector2i) -> Vector2:
	return origin + (Vector2(k) + Vector2(0.5, 0.5)) * CELL


func in_grid(k: Vector2i) -> bool:
	return k.x >= 0 and k.y >= 0 and k.x < dims.x and k.y < dims.y


## Re-evaluates one cell from the current world (trees, logs, ground).
func _eval(k: Vector2i) -> void:
	var c := center(k)
	var solid := not _drivable_point(c)
	grid.set_point_solid(k, solid)
	if not solid:
		var n := World.normal_at(c.x, c.y)
		grid.set_point_weight_scale(k, 1.0 + (1.0 - n.y) * 20.0)


func _drivable_point(c: Vector2) -> bool:
	var h := World.height_at(c.x, c.y)
	if h < World.sea_level + 0.3:
		return false
	var p3 := Vector3(c.x, h, c.y)
	if crew_nav.in_camp(p3):
		# Open yard only: every pedestrian fine cell within 1.6 m is open.
		for dz in [-1.6, 0.0, 1.6]:
			for dx in [-1.6, 0.0, 1.6]:
				if not crew_nav.walkable(p3 + Vector3(dx, 0, dz)):
					return false
		return true
	if World.water_depth_at(c.x, c.y) > 0.25:
		return _on_bridge(c)
	if World.normal_at(c.x, c.y).y < MAX_SLOPE_NY:
		return false
	var key := PlacementValidator._key(c.x, c.y, 8.0)
	for i in _tree_hash.get(key, []):
		if World.removed_trees.has(int(World.trees.id[i])):
			continue
		if c.distance_to(Vector2(World.trees.x[i], World.trees.z[i])) < CLEAR + float(World.trees.radius[i]):
			return false
	for r in _rock_hash.get(key, []):
		if c.distance_to(Vector2(World.rocks.x[r], World.rocks.z[r])) < CLEAR * 0.6 + float(World.rocks.scale[r]) * 0.45:
			return false
	if int(log_refs.get(to_cell(c), 0)) > 0:
		return false
	# Pedestrian-blocked (fence line outside the gate, rock clusters).
	var ck := crew_nav.to_cell(c)
	if crew_nav._in_island(ck) and crew_nav.grid.is_point_solid(ck) and int(crew_nav.log_refs.get(ck, 0)) == 0 and not _near_gate(c):
		return false
	return true


func _near_gate(c: Vector2) -> bool:
	for g in crew_nav.gates:
		if Vector2((g.outside as Vector3).x, (g.outside as Vector3).z).distance_to(c) < 7.0:
			return true
	return false


func _on_bridge(c: Vector2) -> bool:
	for b in World.bridges():
		var across := Vector2(float(b.ax), float(b.az)).normalized()
		var rel := c - Vector2(b.x, b.z)
		var along := rel.dot(across)
		var side := absf(rel.dot(Vector2(-across.y, across.x)))
		if absf(along) <= float(b.half_span) + 2.0 and side < 1.8:
			return true
	return false


## Felling, settling logs, picking them up: refresh the nearby cells.
func refresh_around(p: Vector2, radius := 6.0) -> void:
	var a := to_cell(p - Vector2(radius, radius))
	var b := to_cell(p + Vector2(radius, radius))
	for j in range(a.y, b.y + 1):
		for i in range(a.x, b.x + 1):
			var k := Vector2i(i, j)
			if in_grid(k):
				_eval(k)


func mark_log(points: Array, delta: int) -> void:
	for p in points:
		var v := p as Vector3
		var k := to_cell(Vector2(v.x, v.z))
		log_refs[k] = maxi(int(log_refs.get(k, 0)) + delta, 0)
		if in_grid(k):
			_eval(k)


func drivable(p: Vector3) -> bool:
	var k := to_cell(Vector2(p.x, p.z))
	return in_grid(k) and not grid.is_point_solid(k)


## Nearest drivable cell centre to p (search radius in cells), or INF.
func nearest_drivable(p: Vector3, radius := 12) -> Vector3:
	var k0 := to_cell(Vector2(p.x, p.z))
	for r in radius + 1:
		var best := Vector3.INF
		var bd := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var k := k0 + Vector2i(dx, dy)
				if in_grid(k) and not grid.is_point_solid(k):
					var c := center(k)
					var d := c.distance_to(Vector2(p.x, p.z))
					if d < bd:
						bd = d
						best = Vector3(c.x, World.height_at(c.x, c.y), c.y)
		if best != Vector3.INF:
			return best
	return Vector3.INF


## Route from a to b (both snapped to drivable cells). [] = no vehicle access.
func route(a: Vector3, b: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var sa := nearest_drivable(a, 4)
	var sb := nearest_drivable(b, 6)
	if sa == Vector3.INF or sb == Vector3.INF:
		return out
	var ids := grid.get_id_path(to_cell(Vector2(sa.x, sa.z)), to_cell(Vector2(sb.x, sb.z)))
	if ids.is_empty():
		return out
	var pts: Array[Vector2] = []
	# Keep corners only where line of sight on the grid breaks.
	var anchor := ids[0]
	pts.append(center(anchor))
	for i in range(2, ids.size()):
		if not CrewNav._los(grid, anchor, ids[i]):
			anchor = ids[i - 1]
			pts.append(center(anchor))
	pts.append(center(ids[ids.size() - 1]))
	for p in pts:
		out.append(Vector3(p.x, World.height_at(p.x, p.y), p.y))
	return out


static func length(r: Array[Vector3]) -> float:
	return CrewNav.path_length(r)
