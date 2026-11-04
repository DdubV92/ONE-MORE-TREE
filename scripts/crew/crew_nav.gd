class_name CrewNav
extends Node
## Pedestrian navigation for the crew (Phase 4).
##
## Two grids, both AStarGrid2D (native A*):
##  - Island grid, 3 m cells, built once from the frozen world: sea and deep
##    pond/river water are solid (bridges walkable), steep ground is solid,
##    moderate slopes cost more, rocks are solid, cells with standing trees
##    cost more (local steering walks around the trunks), resting logs mark
##    their cells solid while they lie there. The camp interior is solid on
##    this grid except at the two gates; inside the fence the camp grid takes
##    over.
##  - Camp grid, 0.5 m cells over the fenced camp, rasterised from the real
##    collision geometry at startup: walls, furniture, beds, the fire pit and
##    the delivery rack are solid; doors are walkable (workers open them);
##    each cell stores its walking surface height (floors, porch, ramps).
##    The boss's camper is never walkable for workers.
## Changes are local: felling or bucking updates a handful of cells, never a
## full-island rebuild.

const CELL := 3.0
const FINE := 0.5
const STEEP_NY := 0.72
const GATE_INSET := 2.0

var origin := Vector2.ZERO          # island grid origin (world xz)
var dims := Vector2i.ZERO
var grid := AStarGrid2D.new()
var tree_count_in_cell := {}        # Vector2i -> count of standing trees
var log_refs := {}                  # Vector2i -> count of resting logs
var camp_origin := Vector2.ZERO     # camp grid origin (world xz)
var camp_dims := Vector2i.ZERO
var camp_grid := AStarGrid2D.new()
var camp_surface := PackedFloat32Array()
var camp_rect := Rect2()            # fence interior (world xz)
var gates: Array[Dictionary] = []   # {inside: Vector3, outside: Vector3}
var built := false
var deck := {}                      # island cell -> deck walking height
var build_ms := 0
var _tree_hash := {}


func build() -> void:
	var t0 := Time.get_ticks_msec()
	_build_island()
	built = true
	build_ms = Time.get_ticks_msec() - t0


## The camp grid needs the camp's collision in the physics space.
func build_camp() -> void:
	_build_camp()
	if World.tree_removed.is_connected(_on_tree_removed):
		return
	World.tree_removed.connect(_on_tree_removed)
	World.tree_restored.connect(_on_tree_restored)


# ------------------------------------------------------------- island grid

func _build_island() -> void:
	# Bounds of land (plus a margin) from the height field.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var step := 4
	for j in range(0, World.H, step):
		for i in range(0, World.W, step):
			if World.height[j * World.W + i] > World.sea_level:
				var p := World.origin + Vector2(i, j) * World.cs
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	origin = lo - Vector2(12, 12)
	dims = Vector2i(int(ceil((hi.x - lo.x + 24) / CELL)), int(ceil((hi.y - lo.y + 24) / CELL)))
	grid.region = Rect2i(Vector2i.ZERO, dims)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for j in dims.y:
		for i in dims.x:
			var c := cell_center(Vector2i(i, j))
			var h := World.height_at(c.x, c.y)
			if h < World.sea_level + 0.15:
				grid.set_point_solid(Vector2i(i, j), true)
				continue
			var solid := World.water_depth_at(c.x, c.y) > 0.55
			if not solid:
				var n := World.normal_at(c.x, c.y)
				if n.y < STEEP_NY:
					solid = true
				else:
					grid.set_point_weight_scale(Vector2i(i, j), 1.0 + (1.0 - n.y) * 6.0)
			grid.set_point_solid(Vector2i(i, j), solid)
	# Bridges are walkable decks across the water.
	# Phase 7: deck/ramp heights are recorded so walkers stay ON the bridge
	# (before, they followed the riverbed height under it).
	for b in World.bridges():
		var across := Vector2(float(b.ax), float(b.az)).normalized()
		var half: float = b.half_span
		var d := -half - BridgeBuilder.ramp_length(b, -1.0)
		var d_end := half + BridgeBuilder.ramp_length(b, 1.0)
		while d <= d_end:
			var p := Vector2(b.x, b.z) + across * d
			var k := to_cell(p)
			if _in_island(k):
				grid.set_point_solid(k, false)
				grid.set_point_weight_scale(k, 1.0)
				var y := BridgeBuilder.surface_at_distance(b, d)
				if y > World.height_at(p.x, p.y) + 0.05:
					deck[k] = maxf(float(deck.get(k, -INF)), y)
			d += 1.0
	# Rocks are solid; trees cost more (steering avoids the trunks).
	for r in (World.rocks.x as PackedFloat32Array).size():
		var rp := Vector2(World.rocks.x[r], World.rocks.z[r])
		var rad := float(World.rocks.scale[r]) * 0.45
		if rad > 0.9:
			_mark_disc(rp, rad, true)
	for i in World.tree_count():
		var tid: int = World.trees.id[i]
		if World.removed_trees.has(tid):
			continue
		var k := to_cell(Vector2(World.trees.x[i], World.trees.z[i]))
		tree_count_in_cell[k] = int(tree_count_in_cell.get(k, 0)) + 1
	for k in tree_count_in_cell:
		_refresh_weight(k)
	_tree_hash = PlacementValidator._tree_hash()


func _mark_disc(p: Vector2, r: float, solid: bool) -> void:
	var a := to_cell(p - Vector2(r, r))
	var b := to_cell(p + Vector2(r, r))
	for j in range(a.y, b.y + 1):
		for i in range(a.x, b.x + 1):
			var k := Vector2i(i, j)
			if _in_island(k) and cell_center(k).distance_to(p) <= r + CELL * 0.5:
				grid.set_point_solid(k, solid)


func _refresh_weight(k: Vector2i) -> void:
	if not _in_island(k) or grid.is_point_solid(k):
		return
	var c := cell_center(k)
	var n := World.normal_at(c.x, c.y)
	var w := 1.0 + (1.0 - n.y) * 6.0 + float(tree_count_in_cell.get(k, 0)) * 0.8
	grid.set_point_weight_scale(k, w)


func _on_tree_removed(tree_id: int) -> void:
	var i: int = Game.vegetation.tree_index_by_id.get(tree_id, tree_id) if Game.vegetation else tree_id
	var k := to_cell(Vector2(World.trees.x[i], World.trees.z[i]))
	tree_count_in_cell[k] = maxi(int(tree_count_in_cell.get(k, 0)) - 1, 0)
	_refresh_weight(k)


func _on_tree_restored(tree_id: int) -> void:
	var i: int = Game.vegetation.tree_index_by_id.get(tree_id, tree_id) if Game.vegetation else tree_id
	var k := to_cell(Vector2(World.trees.x[i], World.trees.z[i]))
	tree_count_in_cell[k] = int(tree_count_in_cell.get(k, 0)) + 1
	_refresh_weight(k)


## Resting logs block their cells (refcounted); call with +1/-1.
func mark_log(points: Array, delta: int) -> void:
	for p in points:
		var k := to_cell(Vector2((p as Vector3).x, (p as Vector3).z))
		if not _in_island(k) or _in_camp_world(cell_center(k)):
			continue
		var n := int(log_refs.get(k, 0)) + delta
		log_refs[k] = maxi(n, 0)
		if n > 0:
			grid.set_point_solid(k, true)
		elif not _base_solid(k):
			grid.set_point_solid(k, false)
			_refresh_weight(k)


func _base_solid(k: Vector2i) -> bool:
	var c := cell_center(k)
	var h := World.height_at(c.x, c.y)
	return h < World.sea_level + 0.15 or World.water_depth_at(c.x, c.y) > 0.55 or World.normal_at(c.x, c.y).y < STEEP_NY


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / CELL)), int(floor((p.y - origin.y) / CELL)))


func cell_center(k: Vector2i) -> Vector2:
	return origin + (Vector2(k) + Vector2(0.5, 0.5)) * CELL


func _in_island(k: Vector2i) -> bool:
	return k.x >= 0 and k.y >= 0 and k.x < dims.x and k.y < dims.y


func walkable(p: Vector3, ignore_logs := false) -> bool:
	if _in_camp_world(Vector2(p.x, p.z)):
		var f := _fine(Vector2(p.x, p.z))
		return _in_camp(f) and not camp_grid.is_point_solid(f)
	var k := to_cell(Vector2(p.x, p.z))
	if not _in_island(k):
		return false
	if not grid.is_point_solid(k):
		return true
	# A 3 m cell holding a log is still standable beside the log.
	return ignore_logs and int(log_refs.get(k, 0)) > 0 and not _base_solid(k)


# --------------------------------------------------------------- camp grid

func _build_camp() -> void:
	var o := World.camp_origin()
	var half := CampLayout.FENCE_HALF
	camp_rect = Rect2(Vector2(o.x - half.x, o.z - half.y), half * 2.0)
	camp_origin = camp_rect.position - Vector2(1, 1)
	camp_dims = Vector2i(int(ceil((camp_rect.size.x + 2) / FINE)), int(ceil((camp_rect.size.y + 2) / FINE)))
	camp_grid.region = Rect2i(Vector2i.ZERO, camp_dims)
	camp_grid.cell_size = Vector2.ONE
	camp_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	camp_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	camp_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	camp_grid.update()
	camp_surface.resize(camp_dims.x * camp_dims.y)
	var space := get_viewport().world_3d.direct_space_state if is_inside_tree() else null
	var floors := _building_floors()
	var q := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.3, 1.25, 0.3)
	q.shape = bx
	q.collision_mask = 1
	for j in camp_dims.y:
		for i in camp_dims.x:
			var c := camp_origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * FINE
			var surface := World.height_at(c.x, c.y)
			var solid := false
			var b := _building_at(c, floors)
			if not b.is_empty():
				surface = float(b.floor)
				solid = bool(b.private)
			elif space:
				var ray := PhysicsRayQueryParameters3D.create(Vector3(c.x, surface + 0.6, c.y), Vector3(c.x, surface - 0.3, c.y), 1)
				var hit := space.intersect_ray(ray)
				if not hit.is_empty() and not _ignored(hit.collider):
					surface = maxf(surface, (hit.position as Vector3).y)
			# Outside the fence (the margin ring) is not camp ground.
			if not camp_rect.has_point(c):
				solid = true
			if not solid and space:
				q.transform = Transform3D(Basis(), Vector3(c.x, surface + 0.35 + 0.625, c.y))
				for hit2 in space.intersect_shape(q, 8):
					if not _ignored(hit2.collider):
						solid = true
						break
			camp_surface[j * camp_dims.x + i] = surface
			camp_grid.set_point_solid(Vector2i(i, j), solid)
	# Gates: north entrance and the beach gate, with points just inside and
	# just outside the fence line.
	gates.clear()
	for g in [[Vector2(0, -half.y), Vector2(0, -1)], [Vector2(0, half.y), Vector2(0, 1)]]:
		var gp: Vector2 = Vector2(o.x, o.z) + (g[0] as Vector2)
		var out_dir: Vector2 = g[1]
		var inside := gp - out_dir * GATE_INSET
		var outside := gp + out_dir * (GATE_INSET + 1.5)
		gates.append({"inside": Vector3(inside.x, surface_at(Vector3(inside.x, 0, inside.y)), inside.y), "outside": Vector3(outside.x, World.height_at(outside.x, outside.y), outside.y)})
		# Keep the gate strip walkable on both grids.
		for d in range(-6, 7):
			var p := gp + out_dir * float(d) * 0.5
			var f := _fine(p)
			if _in_camp(f) and absf(d) <= 4:
				camp_grid.set_point_solid(f, false)
	# On the island grid the camp interior is solid except the gate corridors.
	var r := camp_rect.grow(1.0)
	var ka := to_cell(r.position)
	var kb := to_cell(r.end)
	for j in range(ka.y, kb.y + 1):
		for i in range(ka.x, kb.x + 1):
			var k := Vector2i(i, j)
			if _in_island(k) and r.has_point(cell_center(k)):
				grid.set_point_solid(k, true)
	for g in gates:
		var k := to_cell(Vector2(g.outside.x, g.outside.z))
		grid.set_point_solid(k, false)


## Building footprints (camp-local rects) with their floor heights; the
## camper is private (workers never path through it).
func _building_floors() -> Array:
	var o := World.camp_origin()
	var out := []
	var cr := CampLayout.CABIN_POS
	var cy := World.height_at(o.x + cr.x, o.z + cr.z) + CampLayout.CABIN_FLOOR
	out.append({"rect": Rect2(Vector2(o.x + cr.x - 3.6, o.z + cr.z - 5.2), Vector2(7.2, 10.4)), "floor": cy, "private": false})
	out.append({"rect": Rect2(Vector2(o.x + cr.x - 3.6, o.z + cr.z - 10.36), Vector2(7.2, 5.02)), "floor": cy, "private": false})
	var mp := CampLayout.CAMPER_POS + CampLayout.camper_box_offset()
	var cs := CampLayout.CAMPER_SIZE
	out.append({"rect": Rect2(Vector2(o.x + mp.x - cs.x * 0.5 - 0.2, o.z + mp.z - cs.z * 0.5 - 0.2), Vector2(cs.x + 0.4, cs.z + 0.4)), "floor": World.height_at(o.x + mp.x, o.z + mp.z) + CampLayout.CAMPER_FLOOR, "private": true})
	return out


func _building_at(c: Vector2, floors: Array) -> Dictionary:
	for b in floors:
		if (b.rect as Rect2).has_point(c):
			return b
	return {}


## Doors (workers open them), loose timber and characters never make a cell
## permanently solid.
static func _ignored(collider: Object) -> bool:
	if collider == null:
		return true
	if collider is TimberBody or collider is CharacterBody3D:
		return true
	var n := collider as Node
	while n:
		if n is Door:
			return true
		n = n.get_parent()
	return false


func _fine(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - camp_origin.x) / FINE)), int(floor((p.y - camp_origin.y) / FINE)))


func _fine_center(k: Vector2i) -> Vector2:
	return camp_origin + (Vector2(k) + Vector2(0.5, 0.5)) * FINE


func _in_camp(k: Vector2i) -> bool:
	return k.x >= 0 and k.y >= 0 and k.x < camp_dims.x and k.y < camp_dims.y


func _in_camp_world(p: Vector2) -> bool:
	return camp_rect.size.x > 0.0 and camp_rect.has_point(p)


func in_camp(p: Vector3) -> bool:
	return _in_camp_world(Vector2(p.x, p.z))


## Walkable deck (service dock) from the shore to its end.
func add_deck(a: Vector3, b: Vector3, y: float) -> void:
	var L := Vector2(b.x - a.x, b.z - a.z).length()
	var n := int(ceil(L / 0.5))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		var k := to_cell(Vector2(p.x, p.z))
		if _in_island(k):
			deck[k] = y
			grid.set_point_solid(k, false)
			grid.set_point_weight_scale(k, 1.0)


## Walking surface height at a world point (floors indoors, terrain out).
func surface_at(p: Vector3) -> float:
	if not deck.is_empty():
		var dk := to_cell(Vector2(p.x, p.z))
		if deck.has(dk) and World.height_at(p.x, p.z) < float(deck[dk]):
			return float(deck[dk])
	if _in_camp_world(Vector2(p.x, p.z)) and camp_surface.size() > 0:
		var f := _fine(Vector2(p.x, p.z))
		if _in_camp(f):
			return camp_surface[f.y * camp_dims.x + f.x]
	return World.height_at(p.x, p.z)


# ----------------------------------------------------------------- queries

## World path from a to b (list of Vector3 on the walking surface), [] if
## unreachable. Crosses the fence only at a gate.
func find_path(a: Vector3, b: Vector3) -> Array[Vector3]:
	var a_in := in_camp(a)
	var b_in := in_camp(b)
	if a_in and b_in:
		return _camp_path(a, b)
	if not a_in and not b_in:
		return _island_path(a, b)
	var best: Array[Vector3] = []
	var best_len := INF
	for g in gates:
		var inside: Vector3 = g.inside
		var outside: Vector3 = g.outside
		var p1: Array[Vector3]
		var p2: Array[Vector3]
		if a_in:
			p1 = _camp_path(a, inside)
			p2 = _island_path(outside, b)
		else:
			p1 = _island_path(a, outside)
			p2 = _camp_path(inside, b)
		if p1.is_empty() or p2.is_empty():
			continue
		var full: Array[Vector3] = []
		full.append_array(p1)
		full.append_array(p2)
		var L := path_length(full)
		if L < best_len:
			best_len = L
			best = full
	return best


static func path_length(p: Array[Vector3]) -> float:
	var L := 0.0
	for i in range(1, p.size()):
		L += Vector2(p[i].x, p[i].z).distance_to(Vector2(p[i - 1].x, p[i - 1].z))
	return L


func _nearest_open(g: AStarGrid2D, k: Vector2i, inside: Callable, radius := 6) -> Vector2i:
	if inside.call(k) and not g.is_point_solid(k):
		return k
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := k + Vector2i(dx, dy)
				if inside.call(q) and not g.is_point_solid(q):
					return q
	return Vector2i(-1, -1)


func _island_path(a: Vector3, b: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var ka := _nearest_open(grid, to_cell(Vector2(a.x, a.z)), _in_island)
	var kb := _nearest_open(grid, to_cell(Vector2(b.x, b.z)), _in_island)
	if ka.x < 0 or kb.x < 0:
		return out
	var ids := grid.get_id_path(ka, kb)
	if ids.is_empty():
		return out
	var pts: Array[Vector2] = [Vector2(a.x, a.z)]
	for k in _smooth(grid, ids):
		pts.append(cell_center(k))
	pts.append(Vector2(b.x, b.z))
	for p in pts:
		out.append(Vector3(p.x, World.height_at(p.x, p.y), p.y))
	return out


func _camp_path(a: Vector3, b: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var ka := _nearest_open(camp_grid, _fine(Vector2(a.x, a.z)), _in_camp, 4)
	var kb := _nearest_open(camp_grid, _fine(Vector2(b.x, b.z)), _in_camp, 4)
	if ka.x < 0 or kb.x < 0:
		return out
	var ids := camp_grid.get_id_path(ka, kb)
	if ids.is_empty():
		return out
	var pts: Array[Vector2] = [Vector2(a.x, a.z)]
	for k in _smooth(camp_grid, ids):
		pts.append(_fine_center(k))
	pts.append(Vector2(b.x, b.z))
	for p in pts:
		out.append(Vector3(p.x, surface_at(Vector3(p.x, 0, p.y)), p.y))
	return out


## String-pulling: keep a waypoint only where line of sight on the grid
## breaks (fewer zig-zags, still never cuts a solid cell).
func _smooth(g: AStarGrid2D, ids: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if ids.size() <= 2:
		return ids
	var anchor := ids[0]
	out.append(anchor)
	for i in range(2, ids.size()):
		if not _los(g, anchor, ids[i]):
			anchor = ids[i - 1]
			out.append(anchor)
	out.append(ids[ids.size() - 1])
	return out


static func _los(g: AStarGrid2D, a: Vector2i, b: Vector2i) -> bool:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for s in range(1, n):
		var t := float(s) / n
		var k := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if g.is_point_solid(k):
			return false
	return true


## Standing trunks near a segment (for local steering around them).
func trunks_near(p: Vector3, radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var key := PlacementValidator._key(p.x, p.z, 8.0)
	for i in _tree_hash.get(key, []):
		var tid: int = World.trees.id[i]
		if World.removed_trees.has(tid):
			continue
		var tp := Vector3(World.trees.x[i], 0, World.trees.z[i])
		if Vector2(tp.x, tp.z).distance_to(Vector2(p.x, p.z)) < radius:
			tp.y = float(World.trees.radius[i])
			out.append(tp)
	return out
