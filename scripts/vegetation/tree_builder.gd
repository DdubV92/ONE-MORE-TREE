class_name TreeBuilder
extends RefCounted
## Builds the reusable tree meshes once (deterministic): three species x three
## variants x two detail levels, plus a solid far-distance silhouette per
## species. Surface 0 = bark, surface 1 = foliage cards.
##
## Botanical set (coastal woodland): Scots-type pine, Norway-type spruce,
## silver-type birch.

enum Species { PINE, SPRUCE, BIRCH }
const SPECIES_NAMES := ["pine", "spruce", "birch"]
## Reference heights/radii of the built meshes. Instances scale to the
## per-tree record (World.trees.height / radius).
const REF_HEIGHT := [20.0, 18.0, 13.0]
const REF_RADIUS := [0.38, 0.33, 0.19]
const FAR_COLORS := [Color(0.16, 0.24, 0.1), Color(0.1, 0.18, 0.1), Color(0.28, 0.38, 0.14)]

var _bark: SurfaceTool
var _leaf: SurfaceTool
var _rng := RandomNumberGenerator.new()
var _crown_center := Vector3.ZERO


static func build_all() -> Dictionary:
	## Returns {"near": [[mesh x3] x3 species], "mid": [...], "far": [mesh x3]}
	var b := TreeBuilder.new()
	var near := []
	var mid := []
	var far := []
	for sp in 3:
		var near_v := []
		var mid_v := []
		for v in 3:
			near_v.append(b.build(sp, v, true))
			mid_v.append(b.build(sp, v, false))
		near.append(near_v)
		mid.append(mid_v)
		far.append(b.build_far(sp))
	return {"near": near, "mid": mid, "far": far}


func build(species: int, variant: int, detailed: bool) -> ArrayMesh:
	_rng.seed = 1000 + species * 31 + variant * 7 + (0 if detailed else 500)
	_bark = SurfaceTool.new()
	_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	_leaf = SurfaceTool.new()
	_leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	match species:
		Species.PINE: _build_pine(variant, detailed)
		Species.SPRUCE: _build_spruce(variant, detailed)
		Species.BIRCH: _build_birch(variant, detailed)
	var mesh := ArrayMesh.new()
	_bark.generate_tangents()
	_bark.commit(mesh)
	_leaf.commit(mesh)
	return mesh


# ------------------------------------------------------------ primitives

func _tube(points: Array[Vector3], radii: Array[float], sides: int, uv_u_scale: float = 1.0) -> void:
	var rings := points.size()
	var v_acc := 0.0
	var prev_ring: Array = []
	for r in rings:
		var p: Vector3 = points[r]
		var dir: Vector3
		if r == 0:
			dir = (points[1] - points[0]).normalized()
		elif r == rings - 1:
			dir = (points[r] - points[r - 1]).normalized()
		else:
			dir = (points[r + 1] - points[r - 1]).normalized()
		if r > 0:
			v_acc += points[r].distance_to(points[r - 1])
		var side := dir.cross(Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP).normalized()
		var up := side.cross(dir).normalized()
		var ring: Array = []
		for s in sides + 1:
			var a := TAU * s / sides
			var n := (side * cos(a) + up * sin(a)).normalized()
			ring.append([p + n * radii[r], n, Vector2(float(s) / sides * uv_u_scale, v_acc)])
		if r > 0:
			for s in sides:
				var a0: Array = prev_ring[s]
				var a1: Array = prev_ring[s + 1]
				var b0: Array = ring[s]
				var b1: Array = ring[s + 1]
				for vtx in [a0, b0, b1, a0, b1, a1]:
					_bark.set_normal(vtx[1])
					_bark.set_uv(vtx[2])
					_bark.add_vertex(vtx[0])
		prev_ring = ring


func _card(base: Vector3, along: Vector3, side: Vector3, length: float, width: float, uv_base_y: float = 1.0, flip_v: bool = false) -> void:
	## A quad from `base` extending `length` along `along`, `width` across `side`.
	## Card textures grow from their bottom edge (v=1) toward the top (v=0).
	var a := along.normalized()
	var s := side.normalized()
	var p0 := base - s * width * 0.5
	var p1 := base + s * width * 0.5
	var p2 := p1 + a * length
	var p3 := p0 + a * length
	var center := base + a * length * 0.5
	var n_out := (center - _crown_center)
	n_out.y *= 0.6
	n_out = (n_out.normalized() + Vector3.UP * 0.35).normalized()
	var dist := clampf(center.distance_to(_crown_center) / 4.0, 0.0, 1.0)
	var ao := clampf(0.45 + 0.4 * dist + 0.25 * clampf((center.y - _crown_center.y) / 6.0, -1.0, 1.0), 0.25, 1.0)
	var seed_v := _rng.randf()
	var col := Color(clampf(dist + 0.2, 0.0, 1.0), seed_v, ao)
	var uv0 := Vector2(0, uv_base_y)
	var uv1 := Vector2(1, uv_base_y)
	var uv2 := Vector2(1, 0)
	var uv3 := Vector2(0, 0)
	if flip_v:
		uv0 = Vector2(0, 0); uv1 = Vector2(0, 1); uv2 = Vector2(1, 1); uv3 = Vector2(1, 0)
	for pair in [[p0, uv0], [p1, uv1], [p2, uv2], [p0, uv0], [p2, uv2], [p3, uv3]]:
		_leaf.set_color(col)
		_leaf.set_normal(n_out)
		_leaf.set_uv(pair[1])
		_leaf.add_vertex(pair[0])


func _clump(center: Vector3, outward: Vector3, size: float, cards: int, pad := false) -> void:
	## Crossed cards radiating from `center` along `outward` (pine/birch tufts).
	## `pad` adds a near-horizontal card so pine crowns read as layered,
	## cloud-like needle pads rather than round leafy balls.
	var o := outward.normalized()
	var ref := Vector3.UP if absf(o.y) < 0.9 else Vector3.RIGHT
	var s0 := o.cross(ref).normalized()
	for k in cards:
		var ang := PI * k / cards + _rng.randf_range(-0.2, 0.2)
		var side := s0.rotated(o, ang)
		_card(center - o * size * 0.25, o, side, size, size * _rng.randf_range(0.85, 1.05))
	if pad:
		var flat := Vector3(o.x, 0.0, o.z)
		flat = flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
		var tilt := (flat + Vector3.UP * 0.18).normalized()
		var side2 := tilt.cross(Vector3.UP).normalized()
		_card(center - tilt * size * 0.45, tilt, side2, size * 1.15, size * 1.25)


func _ball(center: Vector3, size: float, cards: int) -> void:
	## Leaf cluster: cards facing assorted directions (birch).
	for k in cards:
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.8), _rng.randf_range(-1, 1)).normalized()
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized().rotated(dir, _rng.randf() * TAU)
		var up := side.cross(dir).normalized()
		_card(center - up * size * 0.5, up, side, size, size)


func _wobble_path(from: Vector3, to: Vector3, segments: int, wobble: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for k in segments + 1:
		var t := float(k) / segments
		var p := from.lerp(to, t)
		if k > 0 and k < segments:
			p += Vector3(_rng.randf_range(-wobble, wobble), 0.0, _rng.randf_range(-wobble, wobble)) * sin(t * PI)
		pts.append(p)
	return pts


# --------------------------------------------------------------- species

func _build_pine(variant: int, detailed: bool) -> void:
	var H: float = REF_HEIGHT[0] * [1.0, 0.95, 1.04][variant]
	var R: float = REF_RADIUS[0]
	var sides := 10 if detailed else 6
	var segs := 10 if detailed else 5
	var trunk := _wobble_path(Vector3.ZERO, Vector3(_rng.randf_range(-0.6, 0.6), H, _rng.randf_range(-0.6, 0.6)), segs, 0.35)
	var radii: Array[float] = []
	for k in trunk.size():
		var t := float(k) / (trunk.size() - 1)
		radii.append(R * (1.0 - t * 0.78) * (1.0 + 0.35 * exp(-t * 18.0)))
	_tube(trunk, radii, sides, 2.0)
	var crown_lo: float = H * [0.6, 0.66, 0.56][variant]
	_crown_center = Vector3(trunk[trunk.size() - 1].x * 0.8, (crown_lo + H) * 0.5, trunk[trunk.size() - 1].z * 0.8)
	var branches := (17 if detailed else 8) + variant
	for b in branches:
		var t := float(b) / branches
		var y := lerpf(crown_lo, H * 0.97, t)
		var base := _trunk_point(trunk, y / H)
		var az := _rng.randf() * TAU + b * 2.4
		var rise := deg_to_rad(_rng.randf_range(18.0, 48.0) + t * 20.0)
		var length := lerpf(4.4, 1.4, t) * _rng.randf_range(0.8, 1.15)
		var dir := Vector3(cos(az) * cos(rise), sin(rise), sin(az) * cos(rise))
		var mid := base + dir * length * 0.55 + Vector3(0, 0.25, 0)
		var tip := base + dir * length + Vector3(0, length * 0.18, 0)
		if detailed:
			var r0 := R * (1.0 - t * 0.6) * 0.32
			var pts: Array[Vector3] = [base, mid, tip]
			var rr: Array[float] = [r0, r0 * 0.6, r0 * 0.25]
			_tube(pts, rr, 5, 0.5)
		var csize := lerpf(2.3, 1.6, t) * (1.0 if detailed else 1.35)
		_clump(tip, (dir + Vector3.UP * 0.7).normalized(), csize, 2 if detailed else 2, true)
		if detailed and length > 1.8:
			_clump(mid, (dir + Vector3.UP * 0.4).normalized(), csize * 0.8, 2, true)
	_clump(trunk[trunk.size() - 1] + Vector3(0, -0.4, 0), Vector3.UP, 2.4 * (1.0 if detailed else 1.3), 3)
	if detailed:
		# Dead stubs on the lower trunk
		for k in 6:
			var y := _rng.randf_range(2.5, crown_lo - 1.0)
			var base := _trunk_point(trunk, y / H)
			var az := _rng.randf() * TAU
			var d := Vector3(cos(az), -0.15, sin(az))
			var pts: Array[Vector3] = [base, base + d * _rng.randf_range(0.3, 0.8)]
			var rr: Array[float] = [0.045, 0.015]
			_tube(pts, rr, 4, 0.3)


func _build_spruce(variant: int, detailed: bool) -> void:
	var H: float = REF_HEIGHT[1] * [1.0, 1.06, 0.93][variant]
	var R: float = REF_RADIUS[1]
	var sides := 9 if detailed else 6
	var trunk := _wobble_path(Vector3.ZERO, Vector3(_rng.randf_range(-0.15, 0.15), H, _rng.randf_range(-0.15, 0.15)), 8 if detailed else 4, 0.08)
	var radii: Array[float] = []
	for k in trunk.size():
		var t := float(k) / (trunk.size() - 1)
		radii.append(R * (1.0 - t * 0.9) * (1.0 + 0.3 * exp(-t * 20.0)))
	_tube(trunk, radii, sides, 2.0)
	var lowest: float = H * [0.12, 0.08, 0.16][variant]
	_crown_center = Vector3(0, H * 0.45, 0)
	var step := 0.62 if detailed else 1.25
	var y := lowest
	var whorl := 0
	while y < H - 0.6:
		var t := (y - lowest) / (H - lowest)
		var base := _trunk_point(trunk, y / H)
		var length := (pow(1.0 - t, 0.85) * 3.6 + 0.35) * _rng.randf_range(0.88, 1.1)
		var count := (5 if detailed else 4)
		var az0 := whorl * 0.7 + _rng.randf() * 0.5
		for k in count:
			var az := az0 + TAU * k / count + _rng.randf_range(-0.25, 0.25)
			var droop := deg_to_rad(lerpf(-22.0, 8.0, t) + _rng.randf_range(-6.0, 6.0))
			var dir := Vector3(cos(az) * cos(droop), sin(droop), sin(az) * cos(droop))
			var side := Vector3(-sin(az), 0, cos(az))
			# Spray card: stem along +U from the trunk outward (flip_v maps u->along).
			var up_tilt := side.cross(dir).normalized()
			_card(base + dir * 0.05, dir, up_tilt.lerp(side, 0.85).normalized(), length, length * 0.62, 1.0, true)
			if detailed:
				_card(base + dir * 0.05, dir, up_tilt.lerp(side, 0.15).normalized(), length * 0.92, length * 0.45, 1.0, true)
		y += step * _rng.randf_range(0.85, 1.15) * (1.0 - t * 0.35)
		whorl += 1
	# Leader
	var top := trunk[trunk.size() - 1]
	for k in 3:
		var side := Vector3(cos(k * PI / 3.0), 0, sin(k * PI / 3.0))
		_card(top + Vector3(0, -1.6, 0), Vector3.UP, side, 2.0, 0.9, 1.0, true)


func _build_birch(variant: int, detailed: bool) -> void:
	var H: float = REF_HEIGHT[2] * [1.0, 0.92, 1.08][variant]
	var R: float = REF_RADIUS[2]
	var sides := 9 if detailed else 6
	var lean := Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8))
	var fork_y: float = H * [0.45, 0.5, 0.4][variant]
	var trunk := _wobble_path(Vector3.ZERO, Vector3(lean.x * 0.5, fork_y, lean.z * 0.5), 5 if detailed else 3, 0.12)
	var radii: Array[float] = []
	for k in trunk.size():
		var t := float(k) / (trunk.size() - 1)
		radii.append(R * (1.0 - t * 0.3) * (1.0 + 0.25 * exp(-t * 14.0)))
	_tube(trunk, radii, sides, 1.0)
	_crown_center = Vector3(lean.x, H * 0.68, lean.z)
	var limbs := 3 if variant != 1 else 2
	var fork := trunk[trunk.size() - 1]
	for l in limbs:
		var az := TAU * l / limbs + _rng.randf_range(-0.4, 0.4)
		var spread := _rng.randf_range(0.8, 1.6)
		var top := Vector3(lean.x + cos(az) * spread, H * _rng.randf_range(0.9, 1.0), lean.z + sin(az) * spread)
		var path := _wobble_path(fork, top, 4 if detailed else 2, 0.25)
		var rr: Array[float] = []
		for k in path.size():
			rr.append(R * 0.7 * (1.0 - float(k) / path.size() * 0.85))
		_tube(path, rr, 6 if detailed else 4, 1.0)
	var clusters := 26 if detailed else 11
	for k in clusters:
		var u := _rng.randf()
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf())
		var p := _crown_center + Vector3(cos(a) * r * 2.7, (u - 0.45) * 2.0 * H * 0.24, sin(a) * r * 2.7)
		_ball(p, _rng.randf_range(1.5, 2.1) * (1.0 if detailed else 1.4), 3 if detailed else 2)


func _trunk_point(trunk: Array[Vector3], t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (trunk.size() - 1)
	var i := mini(int(f), trunk.size() - 2)
	return trunk[i].lerp(trunk[i + 1], f - i)


# ------------------------------------------------------------- far LOD

func build_far(species: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var H: float = REF_HEIGHT[species]
	var trunk_col := Color(0.32, 0.24, 0.18) if species != Species.BIRCH else Color(0.75, 0.73, 0.68)
	_far_cone(st, Vector3.ZERO, REF_RADIUS[species], 0.05, H * 0.75, 5, trunk_col)
	var leaf: Color = FAR_COLORS[species]
	match species:
		Species.PINE:
			_far_blob(st, Vector3(0, H * 0.8, 0), Vector3(3.6, H * 0.2, 3.6), leaf)
		Species.SPRUCE:
			_far_cone(st, Vector3(0, H * 0.1, 0), 3.4, 0.0, H * 0.92, 7, leaf)
		Species.BIRCH:
			_far_blob(st, Vector3(0, H * 0.68, 0), Vector3(3.0, H * 0.3, 3.0), leaf)
	st.generate_normals()
	return st.commit()


func _far_cone(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, sides: int, col: Color) -> void:
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var b0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var t1 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		for p in [b0, t0, t1, b0, t1, b1]:
			st.set_color(col)
			st.add_vertex(p)


func _far_blob(st: SurfaceTool, c: Vector3, r: Vector3, col: Color) -> void:
	var lat := 4
	var lon := 7
	for i in lat:
		var t0 := PI * i / lat
		var t1 := PI * (i + 1) / lat
		for j in lon:
			var p0 := TAU * j / lon
			var p1 := TAU * (j + 1) / lon
			var v := func(t: float, p: float) -> Vector3:
				var w := 1.0 + 0.12 * sin(p * 3.0 + t * 2.0)
				return c + Vector3(sin(t) * cos(p) * r.x * w, cos(t) * r.y, sin(t) * sin(p) * r.z * w)
			var a: Vector3 = v.call(t0, p0)
			var b: Vector3 = v.call(t1, p0)
			var cc: Vector3 = v.call(t1, p1)
			var d: Vector3 = v.call(t0, p1)
			for p in [a, b, cc, a, cc, d]:
				st.set_color(col)
				st.add_vertex(p)


## Trunk radius (mesh-local units) at mesh-local height y, matching the
## profiles used by the builders above. Used by notches, stumps, caps and
## physics proxies so cuts line up with the visible bark.
static func trunk_radius_local(species: int, variant: int, y: float) -> float:
	match species:
		Species.PINE:
			var h: float = REF_HEIGHT[0] * [1.0, 0.95, 1.04][variant]
			var t := clampf(y / h, 0.0, 1.0)
			return REF_RADIUS[0] * (1.0 - t * 0.78) * (1.0 + 0.35 * exp(-t * 18.0))
		Species.SPRUCE:
			var h: float = REF_HEIGHT[1] * [1.0, 1.06, 0.93][variant]
			var t := clampf(y / h, 0.0, 1.0)
			return REF_RADIUS[1] * (1.0 - t * 0.9) * (1.0 + 0.3 * exp(-t * 20.0))
		_:
			var h: float = REF_HEIGHT[2] * [1.0, 0.92, 1.08][variant]
			var fork: float = h * [0.45, 0.5, 0.4][variant]
			var t := clampf(y / fork, 0.0, 1.0)
			return REF_RADIUS[2] * (1.0 - t * 0.3) * (1.0 + 0.25 * exp(-t * 14.0))


static func mesh_height(species: int, variant: int) -> float:
	return REF_HEIGHT[species] * [[1.0, 0.95, 1.04], [1.0, 1.06, 0.93], [1.0, 0.92, 1.08]][species][variant]
