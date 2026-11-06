class_name SurfSystem
extends Node3D
## Breaking shore waves. At startup the coastline is traced at the breaking
## depth (marching squares over the frozen height grid; derived at runtime,
## the frozen world data is untouched), chained, resampled and smoothed into
## polylines. Each polyline gets ribbon meshes whose cross-section is
## animated in `surf.gdshader`: swell -> steepening -> lip pitching forward
## -> curling tube -> collapse -> whitewater bore running up to the swash.
## A heightfield cannot overhang; these ribbons can, because the profile is
## a 2D spline evaluated per vertex.
##
## Timing is shared with the swash (world_common.gdshaderinc swash_phase), so
## the run-up on the sand follows each wave that lands.

const BREAK_DEPTH := 2.2        # m below sea level where waves break
const STRIDE := 2               # grid cells per marching-squares cell
const SPACING := 2.0            # m between ribbon columns
const ROWS := 40                # vertices across the profile
const CHUNK_COLS := 48
const MIN_CHAIN := 24.0         # m; shorter contours (tiny shoals) skipped
const VIS_END := 650.0

## Profile keyframes: 9 control points per pose, in wave-height units
## (x is later stretched by `stretch`). Order along the curve: seaward
## flat, back, back, crest, lip top, lip tip, lip underside, face, front flat.
const POSES := [
	[Vector2(-6, 0), Vector2(-4, 0), Vector2(-2, 0), Vector2(0, 0), Vector2(0.7, 0), Vector2(1.3, 0), Vector2(1.9, 0), Vector2(2.6, 0), Vector2(4.5, 0)],
	[Vector2(-6, 0), Vector2(-3.5, 0.15), Vector2(-1.6, 0.6), Vector2(0, 0.8), Vector2(0.7, 0.66), Vector2(1.3, 0.42), Vector2(1.9, 0.2), Vector2(2.6, 0.06), Vector2(4.5, 0)],
	[Vector2(-6, 0), Vector2(-3.5, 0.15), Vector2(-1.5, 0.62), Vector2(-0.1, 1.0), Vector2(0.4, 1.0), Vector2(0.72, 0.82), Vector2(0.8, 0.52), Vector2(0.95, 0.16), Vector2(4.5, 0)],
	[Vector2(-6, 0), Vector2(-3.4, 0.15), Vector2(-1.4, 0.66), Vector2(-0.1, 1.12), Vector2(0.6, 1.18), Vector2(1.25, 0.92), Vector2(0.95, 0.8), Vector2(0.3, 0.2), Vector2(4.5, 0)],
	[Vector2(-6, 0), Vector2(-3.4, 0.12), Vector2(-1.3, 0.62), Vector2(0.0, 1.1), Vector2(1.0, 1.14), Vector2(1.75, 0.28), Vector2(1.2, 0.84), Vector2(0.2, 0.14), Vector2(4.5, 0)],
	[Vector2(-6, 0), Vector2(-3.5, 0.05), Vector2(-1.3, 0.25), Vector2(0.2, 0.5), Vector2(0.9, 0.56), Vector2(1.5, 0.46), Vector2(2.0, 0.3), Vector2(2.6, 0.12), Vector2(4.5, 0)],
]

@export var surf_height := 1.75          # breaker face height on an exposed beach (m)
@export var stretch := 1.25             # horizontal scale of the profile
var swell_dir := Vector2(0.2, -1.0).normalized()   # direction the swell travels
var material: ShaderMaterial
var chains: Array = []                   # Array of Dictionary {pts, normals, dist, beach, s}
var chunks: Array[MeshInstance3D] = []


func build(water: WaterSystem) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/surf.gdshader")
	material.render_priority = 1         # after the ocean plane (both transparent)
	var pts := PackedVector2Array()
	for pose in POSES:
		for p in pose:
			pts.append(p)
	material.set_shader_parameter("poses", pts)
	material.set_shader_parameter("surf_height", surf_height)
	material.set_shader_parameter("stretch", stretch)
	material.set_shader_parameter("swell_dir", swell_dir)
	material.set_shader_parameter("foam_noise", water.foam_texture())
	material.set_shader_parameter("detail_normal", water.detail_texture())
	var t0 := Time.get_ticks_msec()
	var raw := _trace(-BREAK_DEPTH)
	for c in raw:
		var ch := _prepare(c)
		if not ch.is_empty():
			chains.append(ch)
	for ch in chains:
		_build_chunks(ch)
	print("SURF: %d breaker lines, %d chunks, %.1f km of surf, %d ms" % [chains.size(), chunks.size(), _total_len() / 1000.0, Time.get_ticks_msec() - t0])


## Re-traces the breaker lines after an in-memory terrain edit (the Phase 24
## reference cove's beach shelf), so surf breaks on the new depth contour.
func rebuild(water: WaterSystem) -> void:
	for c in chunks:
		if is_instance_valid(c):
			c.queue_free()
	chunks.clear()
	chains.clear()
	build(water)


func set_surf_height(h: float) -> void:
	surf_height = h
	if material:
		material.set_shader_parameter("surf_height", h)


func _total_len() -> float:
	var t := 0.0
	for ch in chains:
		t += float(ch.length)
	return t


# ------------------------------------------------------------ contour trace

func _trace(level: float) -> Array:
	var W := World.W
	var H := World.H
	var hgt := World.height
	var reg := World.water_region
	var nw := (W - 1) / STRIDE
	var nh := (H - 1) / STRIDE
	var pos := {}      # edge id -> Vector2 (world xz)
	var adj := {}      # edge id -> Array[int]
	for cj in nh:
		var j := cj * STRIDE
		for ci in nw:
			var i := ci * STRIDE
			var r0 := j * W + i
			var r1 := (j + STRIDE) * W + i
			var a := hgt[r0] - level
			var b := hgt[r0 + STRIDE] - level
			var c := hgt[r1] - level
			var d := hgt[r1 + STRIDE] - level
			var code := (1 if a > 0.0 else 0) | (2 if b > 0.0 else 0) | (4 if d > 0.0 else 0) | (8 if c > 0.0 else 0)
			if code == 0 or code == 15:
				continue
			# Only the open sea: skip river mouths / ponds and the grid rim.
			if reg[r0] != 0 or ci == 0 or cj == 0 or ci >= nw - 1 or cj >= nh - 1:
				continue
			# Edge ids: bottom (a-b), right (b-d), top (c-d), left (a-c).
			var e_b := (cj * (nw + 1) + ci) * 2
			var e_l := e_b + 1
			var e_t := ((cj + 1) * (nw + 1) + ci) * 2
			var e_r := (cj * (nw + 1) + ci + 1) * 2 + 1
			var segs: Array = []
			match code:
				1, 14: segs = [[e_b, e_l]]
				2, 13: segs = [[e_b, e_r]]
				3, 12: segs = [[e_l, e_r]]
				4, 11: segs = [[e_r, e_t]]
				6, 9: segs = [[e_b, e_t]]
				7, 8: segs = [[e_l, e_t]]
				5: segs = [[e_b, e_l], [e_r, e_t]]
				10: segs = [[e_b, e_r], [e_l, e_t]]
			var x0 := World.origin.x + i * World.cs
			var z0 := World.origin.y + j * World.cs
			var sz := World.cs * STRIDE
			for s in segs:
				for e in s:
					if not pos.has(e):
						pos[e] = _edge_point(e, e_b, e_l, e_t, e_r, x0, z0, sz, a, b, c, d)
				_link(adj, s[0], s[1])
				_link(adj, s[1], s[0])
	# Chain: open polylines from endpoints first, then closed loops.
	var seen := {}
	var out: Array = []
	for start in adj:
		if seen.has(start) or (adj[start] as Array).size() != 1:
			continue
		out.append(_walk(start, adj, pos, seen))
	for start in adj:
		if not seen.has(start):
			out.append(_walk(start, adj, pos, seen))
	return out


static func _edge_point(e: int, e_b: int, e_l: int, e_t: int, e_r: int, x0: float, z0: float, sz: float, a: float, b: float, c: float, d: float) -> Vector2:
	var f := func(u: float, v: float) -> float: return clampf(u / (u - v), 0.0, 1.0) if absf(u - v) > 1e-6 else 0.5
	if e == e_b:
		return Vector2(x0 + sz * f.call(a, b), z0)
	if e == e_t:
		return Vector2(x0 + sz * f.call(c, d), z0 + sz)
	if e == e_l:
		return Vector2(x0, z0 + sz * f.call(a, c))
	return Vector2(x0 + sz, z0 + sz * f.call(b, d))


static func _link(adj: Dictionary, a: int, b: int) -> void:
	if not adj.has(a):
		adj[a] = []
	if not b in adj[a]:
		(adj[a] as Array).append(b)


static func _walk(start: int, adj: Dictionary, pos: Dictionary, seen: Dictionary) -> PackedVector2Array:
	var line := PackedVector2Array()
	var cur := start
	var prev := -1
	while true:
		seen[cur] = true
		line.append(pos[cur])
		var nxt := -1
		for n in adj[cur]:
			if n != prev and not seen.has(n):
				nxt = n
				break
		if nxt < 0:
			# Closed loop: repeat the first point to close it.
			if line.size() > 2 and start in adj[cur] and prev != start:
				line.append(pos[start])
			break
		prev = cur
		cur = nxt
	return line


# ----------------------------------------------------------- polyline prep

func _prepare(line: PackedVector2Array) -> Dictionary:
	if line.size() < 4:
		return {}
	var length := 0.0
	for k in line.size() - 1:
		length += line[k].distance_to(line[k + 1])
	if length < MIN_CHAIN:
		return {}
	var closed := line[0].distance_to(line[line.size() - 1]) < 0.01
	# Resample by arc length.
	var n := maxi(int(length / SPACING), 3)
	var res := PackedVector2Array()
	var seg := 0
	var acc := 0.0
	var seg_len := line[0].distance_to(line[1])
	for q in n + 1:
		var target := length * q / n
		while seg < line.size() - 2 and acc + seg_len < target:
			acc += seg_len
			seg += 1
			seg_len = line[seg].distance_to(line[seg + 1])
		var f := clampf((target - acc) / maxf(seg_len, 1e-4), 0.0, 1.0)
		res.append(line[seg].lerp(line[seg + 1], f))
	# Smooth (keeps endpoints of open lines).
	for _pass in 4:
		var sm := res.duplicate()
		for k in res.size():
			if not closed and (k == 0 or k == res.size() - 1):
				continue
			var a := res[(k - 1 + res.size()) % res.size()]
			var b := res[(k + 1) % res.size()]
			sm[k] = res[k] * 0.5 + (a + b) * 0.25
		res = sm
	var normals := PackedVector2Array()
	var dist := PackedFloat32Array()
	var beach := PackedFloat32Array()
	var s := PackedFloat32Array()
	var run := 0.0
	for k in res.size():
		var a := res[maxi(k - 1, 0)] if not closed else res[(k - 1 + res.size()) % res.size()]
		var b := res[mini(k + 1, res.size() - 1)] if not closed else res[(k + 1) % res.size()]
		var tg := (b - a).normalized()
		var nrm := Vector2(-tg.y, tg.x)
		# Shoreward = toward shallower ground.
		var p := res[k]
		if World.height_at(p.x + nrm.x * 4.0, p.y + nrm.y * 4.0) < World.height_at(p.x - nrm.x * 4.0, p.y - nrm.y * 4.0):
			nrm = -nrm
		normals.append(nrm)
		var d := 60.0
		for step in 80:
			var q := p + nrm * float(step + 1)
			if World.height_at(q.x, q.y) >= World.sea_level:
				d = float(step + 1)
				break
		dist.append(d)
		var sh := p + nrm * d
		beach.append(World.masks_at(sh.x, sh.y).x)
		if k > 0:
			run += res[k].distance_to(res[k - 1])
		s.append(run)
	# Normals vary smoothly (avoid fans on tight bends).
	for _pass in 3:
		var sm := normals.duplicate()
		for k in range(1, normals.size() - 1):
			sm[k] = (normals[k - 1] + normals[k] * 2.0 + normals[k + 1]).normalized()
		normals = sm
	return {"pts": res, "normals": normals, "dist": dist, "beach": beach, "s": s, "length": length, "closed": closed}


# ------------------------------------------------------------------- meshes

func _build_chunks(ch: Dictionary) -> void:
	var pts: PackedVector2Array = ch.pts
	var count := pts.size()
	var start := 0
	while start < count - 1:
		var end := mini(start + CHUNK_COLS, count - 1)
		_chunk(ch, start, end)
		start = end


func _chunk(ch: Dictionary, c0: int, c1: int) -> void:
	var pts: PackedVector2Array = ch.pts
	var nrm: PackedVector2Array = ch.normals
	var total: float = ch.length
	var centre := Vector2.ZERO
	for c in range(c0, c1 + 1):
		centre += pts[c]
	centre /= float(c1 - c0 + 1)
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom := PackedFloat32Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in range(c0, c1 + 1):
		var s: float = ch.s[c]
		# Taper towards open ends so a breaker never ends in a cliff.
		var taper := 1.0 if ch.closed else clampf(minf(s, total - s) / 18.0, 0.0, 1.0)
		var exposure := clampf(nrm[c].dot(swell_dir), 0.0, 1.0)
		for r in ROWS + 1:
			var p := pts[c] - centre
			verts.append(Vector3(p.x, 0.0, p.y))
			uv.append(Vector2(float(r) / ROWS, s))
			uv2.append(Vector2(ch.dist[c], taper))
			custom.append_array([nrm[c].x, nrm[c].y, ch.beach[c], exposure])
		lo = Vector2(minf(lo.x, pts[c].x), minf(lo.y, pts[c].y))
		hi = Vector2(maxf(hi.x, pts[c].x), maxf(hi.y, pts[c].y))
	var idx := PackedInt32Array()
	var cols := c1 - c0 + 1
	for c in cols - 1:
		# Rest pose is flat: wind every quad so its front (clockwise) faces up.
		var a0 := Vector3(pts[c0 + c].x, 0, pts[c0 + c].y)
		var b0 := Vector3(pts[c0 + c + 1].x, 0, pts[c0 + c + 1].y)
		var n0 := Vector3(nrm[c0 + c].x, 0, nrm[c0 + c].y)
		var flip := (b0 - a0).cross(n0).y > 0.0
		for r in ROWS:
			var a := c * (ROWS + 1) + r
			var b := a + 1
			var cc := a + ROWS + 1
			var d := cc + 1
			if flip:
				idx.append_array([a, b, d, a, d, cc])
			else:
				idx.append_array([a, d, b, a, cc, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var mi := MeshInstance3D.new()
	mi.name = "Surf%d" % chunks.size()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(centre.x, 0.0, centre.y)
	var reach := 40.0 + surf_height * stretch * 8.0
	mi.custom_aabb = AABB(Vector3(lo.x - centre.x - reach, -3.0, lo.y - centre.y - reach), Vector3(hi.x - lo.x + reach * 2.0, 3.0 + surf_height * 2.5, hi.y - lo.y + reach * 2.0))
	mi.visibility_range_end = VIS_END
	mi.visibility_range_end_margin = 60.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)
	chunks.append(mi)
