class_name IslandGenerator
extends RefCounted
## Deterministic island generator. Turns a WorldConfig into the frozen world
## data (height field, masks, water surfaces, rivers, ponds, rocks, trees).
## Run offline with tools/generate_world.gd; the runtime only loads the
## result. Same config + same generator version => byte-identical output.

const GENERATOR_REVISION := 1

var cfg: WorldConfig
var W: int
var H: int
var cs: float
var bmin: Vector2

# Output arrays (row-major, index = j * W + i)
var height := PackedFloat32Array()
var masks := PackedByteArray()          # RGBA8: sand, forest floor, dirt/trail, rock
var water_surface := PackedFloat32Array()
var water_region := PackedByteArray()   # 0 ocean/none, 1 river, 2+ pond index + 2

# Intermediate fields
var _dist_in := PackedFloat32Array()   # approx meters inland (negative at sea)
var _beach := PackedFloat32Array()
var _rocky := PackedFloat32Array()
var _river_d := PackedFloat32Array()   # distance to river centerline
var _river_s := PackedFloat32Array()   # arc length of nearest centerline point
var _trail_d := PackedFloat32Array()

var river: Dictionary = {}   # dense samples
var ponds: Array = []
var bridges: Array = []
var rocks: Dictionary = {}
var trees: Dictionary = {}
var shore_points := PackedVector2Array()
var stats: Dictionary = {}

var _n_warp := FastNoiseLite.new()
var _n_shore := FastNoiseLite.new()
var _n_hills := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()
var _n_ridge := FastNoiseLite.new()
var _n_forest := FastNoiseLite.new()
var _n_species := FastNoiseLite.new()


func _init(config: WorldConfig) -> void:
	cfg = config
	var gs := cfg.grid_size()
	W = gs.x
	H = gs.y
	cs = cfg.cell_size
	bmin = cfg.bounds_min
	_setup_noise()


func _setup_noise() -> void:
	var s := cfg.world_seed
	_n_warp.seed = s + 11
	_n_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_warp.frequency = 1.0 / 330.0
	_n_warp.fractal_type = FastNoiseLite.FRACTAL_FBM
	_n_warp.fractal_octaves = 2
	_n_shore.seed = s + 23
	_n_shore.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_shore.frequency = 1.0 / 120.0
	_n_shore.fractal_octaves = 3
	_n_hills.seed = s + 37
	_n_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_hills.frequency = 1.0 / 400.0
	_n_hills.fractal_octaves = 4
	_n_hills.fractal_gain = 0.45
	_n_detail.seed = s + 41
	_n_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_detail.frequency = 1.0 / 46.0
	_n_detail.fractal_octaves = 2
	_n_ridge.seed = s + 53
	_n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_ridge.frequency = 1.0 / 95.0
	_n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_n_ridge.fractal_octaves = 3
	_n_forest.seed = s + 67
	_n_forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_forest.frequency = 1.0 / 130.0
	_n_forest.fractal_octaves = 3
	_n_species.seed = s + 79
	_n_species.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_species.frequency = 1.0 / 240.0
	_n_species.fractal_octaves = 2


# ---------------------------------------------------------------- helpers

static func smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


static func smax(a: float, b: float, k: float) -> float:
	return -smin(-a, -b, k)


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	## Returns (distance, t along segment).
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)


static func hash_u32(a: int, b: int, c: int) -> int:
	var h: int = (a * 374761393 + b * 668265263 + c * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0xFFFFFFFF


static func hash01(a: int, b: int, c: int) -> float:
	return float(hash_u32(a, b, c)) / 4294967295.0


func world_xz(i: int, j: int) -> Vector2:
	return Vector2(bmin.x + i * cs, bmin.y + j * cs)


func sample_grid(arr: PackedFloat32Array, p: Vector2) -> float:
	var fx := clampf((p.x - bmin.x) / cs, 0.0, W - 1.001)
	var fz := clampf((p.y - bmin.y) / cs, 0.0, H - 1.001)
	var i := int(fx)
	var j := int(fz)
	fx -= i
	fz -= j
	var a := arr[j * W + i]
	var b := arr[j * W + i + 1]
	var c := arr[(j + 1) * W + i]
	var d := arr[(j + 1) * W + i + 1]
	if fx > fz:
		return a + (b - a) * fx + (d - b) * fz
	return a + (c - a) * fz + (d - c) * fx


func camp_sd(p: Vector2) -> float:
	## Signed distance to the camp clearing (rounded rectangle).
	var half := cfg.camp_size * 0.5
	var q := (p - cfg.camp_center).abs() - (half - Vector2(6, 6))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 6.0


# ------------------------------------------------------------- base relief

func _island_field(p: Vector2) -> float:
	var q := p + Vector2(_n_warp.get_noise_2d(p.x, p.y), _n_warp.get_noise_2d(p.x + 913.0, p.y - 377.0)) * 75.0
	var e := (q / cfg.island_half_extents).length()
	for bay in cfg.bays:
		var d := p.distance_to(Vector2(bay.x, bay.y)) / bay.z
		e += bay.w * exp(-d * d * 2.2)
	e += _n_shore.get_noise_2d(p.x, p.y) * 0.055
	return 1.0 - e


func _beach_factor(p: Vector2) -> float:
	var b := 0.0
	for be in cfg.beaches:
		var d := p.distance_to(Vector2(be.x, be.y))
		b = maxf(b, 1.0 - smoothstep(be.z * 0.55, be.z, d))
	return b


func _inland_height(p: Vector2, river_d: float, river_s: float) -> float:
	var hills := _n_hills.get_noise_2d(p.x, p.y)
	var low_d := p.distance_to(Vector2(cfg.lowland.x, cfg.lowland.y))
	var low := 1.0 - smoothstep(cfg.lowland.z * 0.35, cfg.lowland.z, low_d)
	var h := cfg.inland_base_height + cfg.hill_amplitude * (hills * 0.85 + 0.25) * (1.0 - 0.65 * low)
	h -= 4.5 * low
	# Rocky ridge
	var rs := seg_dist(p, cfg.ridge_start, cfg.ridge_end)
	var taper := pow(sin(PI * clampf(rs.y * 0.9 + 0.05, 0.0, 1.0)), 0.7)
	var bump := exp(-pow(rs.x / cfg.ridge_half_width, 2.0) * 2.6) * taper
	var ridged := _n_ridge.get_noise_2d(p.x, p.y) * 0.5 + 0.5
	h += cfg.ridge_height * bump * (0.75 + 0.35 * ridged)
	h += _n_detail.get_noise_2d(p.x, p.y) * 1.3
	# River valley: the floor follows the authored design grade so the river
	# always has somewhere downhill to go (raises low ground, cuts high ground).
	var floor_h := river_design_level(river_s) + 1.3 + river_d * 0.06
	h = lerpf(h, floor_h, exp(-pow(river_d / 48.0, 2.0)))
	return h


func river_design_level(s: float) -> float:
	var total: float = river.length
	return cfg.river_source_level * pow(clampf(1.0 - s / total, 0.0, 1.0), 1.15)


# ------------------------------------------------------------- generation

func generate() -> void:
	var t0 := Time.get_ticks_msec()
	var n := W * H
	height.resize(n)
	_dist_in.resize(n)
	_beach.resize(n)
	_rocky.resize(n)
	_build_river_centerline()
	_raster_polyline_fields()
	# Pass 1: base relief
	for j in H:
		for i in W:
			var idx := j * W + i
			var p := world_xz(i, j)
			var di := _island_field(p) * 640.0
			var b := _beach_factor(p)
			_dist_in[idx] = di
			_beach[idx] = b
			var slope := lerpf(0.17, 0.045, b) if di < 0.0 else lerpf(0.21, 0.034, b)
			var h_shore := di * slope
			var h_in := _inland_height(p, _river_d[idx], _river_s[idx])
			var h := smin(h_shore, h_in, 5.0)
			# Rough rocky coast detail
			var coast := (1.0 - b) * (1.0 - smoothstep(0.0, 30.0, absf(di)))
			_rocky[idx] = coast
			h += coast * (_n_detail.get_noise_2d(p.x * 3.1, p.y * 3.1) * 0.9 + 0.3)
			h = smax(h, -cfg.max_sea_depth, 4.0)
			# Camp clearing
			var sd := camp_sd(p)
			if sd < 26.0:
				var w := 1.0 - smoothstep(0.0, 26.0, sd)
				h = lerpf(h, cfg.camp_height + _n_detail.get_noise_2d(p.x * 4.0, p.y * 4.0) * 0.06, w)
			height[idx] = h
	_carve_ponds()
	_carve_river()
	for idx in n:
		height[idx] = snappedf(height[idx], 0.01)
	_build_water_maps()
	_place_bridges()
	_place_rocks()
	_place_trees()
	_build_masks()
	_collect_shore_points()
	_compute_stats()
	stats["generation_ms"] = Time.get_ticks_msec() - t0


func _build_river_centerline() -> void:
	# Densify control points (Catmull-Rom) to ~2 m spacing.
	var pts := cfg.river_points
	var dense := PackedVector2Array()
	for k in pts.size() - 1:
		var p0 := pts[maxi(k - 1, 0)]
		var p1 := pts[k]
		var p2 := pts[k + 1]
		var p3 := pts[mini(k + 2, pts.size() - 1)]
		var seg_len := p1.distance_to(p2)
		var steps := maxi(2, int(seg_len / 2.0))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(pts[pts.size() - 1])
	var arc := PackedFloat32Array()
	arc.resize(dense.size())
	var acc := 0.0
	for k in dense.size():
		if k > 0:
			acc += dense[k].distance_to(dense[k - 1])
		arc[k] = acc
	river = {"points": dense, "arc": arc, "length": acc}


func _raster_polyline_fields() -> void:
	var n := W * H
	_river_d.resize(n)
	_river_s.resize(n)
	_trail_d.resize(n)
	_river_d.fill(1e6)
	_river_s.fill(0.0)
	_trail_d.fill(1e6)
	_raster_polyline(river.points, river.arc, 150.0, _river_d, _river_s)
	for trail in cfg.trails:
		var dense := PackedVector2Array()
		for k in trail.size() - 1:
			var steps := maxi(1, int(trail[k].distance_to(trail[k + 1]) / 4.0))
			for s in steps:
				dense.append(trail[k].lerp(trail[k + 1], float(s) / steps))
		dense.append(trail[trail.size() - 1])
		var dummy := PackedFloat32Array()
		dummy.resize(dense.size())
		_raster_polyline(dense, dummy, 12.0, _trail_d, PackedFloat32Array())


func _raster_polyline(pts: PackedVector2Array, arc: PackedFloat32Array, radius: float, dist: PackedFloat32Array, sfield: PackedFloat32Array) -> void:
	var write_s := sfield.size() > 0
	var rc := int(ceil(radius / cs))
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var c := (a + b) * 0.5
		var ci := int(round((c.x - bmin.x) / cs))
		var cj := int(round((c.y - bmin.y) / cs))
		var ext := rc + int(ceil(a.distance_to(b) / cs))
		for j in range(maxi(cj - ext, 0), mini(cj + ext + 1, H)):
			for i in range(maxi(ci - ext, 0), mini(ci + ext + 1, W)):
				var p := world_xz(i, j)
				var r := seg_dist(p, a, b)
				var idx := j * W + i
				if r.x < dist[idx]:
					dist[idx] = r.x
					if write_s:
						sfield[idx] = lerpf(arc[k], arc[k + 1], r.y)


func _carve_ponds() -> void:
	ponds.clear()
	for pi in cfg.ponds.size():
		var pd: Vector4 = cfg.ponds[pi]
		var c := Vector2(pd.x, pd.y)
		var r := pd.z
		# Level: just below the lowest point of a ring around the basin.
		var ring_min := 1e6
		for k in 48:
			var a := TAU * k / 48.0
			ring_min = minf(ring_min, sample_grid(height, c + Vector2(cos(a), sin(a)) * (r + 10.0)))
		var level := snappedf(maxf(ring_min - 0.7, 1.5), 0.01)
		var bank_w := 16.0
		var ext := int(ceil((r + bank_w) / cs)) + 1
		var ci := int(round((c.x - bmin.x) / cs))
		var cj := int(round((c.y - bmin.y) / cs))
		for j in range(maxi(cj - ext, 0), mini(cj + ext + 1, H)):
			for i in range(maxi(ci - ext, 0), mini(ci + ext + 1, W)):
				var p := world_xz(i, j)
				# Slightly irregular outline
				var ang := atan2(p.y - c.y, p.x - c.x)
				var rr := r * (1.0 + 0.09 * sin(ang * 3.0 + pi) + 0.05 * sin(ang * 5.0 + 1.7 * pi))
				var d := p.distance_to(c)
				var idx := j * W + i
				var base := height[idx]
				if d < rr:
					var u := d / rr
					height[idx] = level - 0.05 - pd.w * pow(1.0 - u * u, 0.8)
				elif d < rr + bank_w:
					var t := (d - rr) / bank_w
					var bank := level + 0.05 + (d - rr) * 0.16
					height[idx] = maxf(lerpf(bank, maxf(base, level + 0.35), smoothstep(0.0, 1.0, t)), level + 0.05)
		ponds.append({"center": c, "radius": r, "level": level, "depth": pd.w, "index": pi})


func _carve_river() -> void:
	var pts: PackedVector2Array = river.points
	var arc: PackedFloat32Array = river.arc
	var count := pts.size()
	var levels := PackedFloat32Array()
	levels.resize(count)
	# Water level: running minimum of (ground - 1.05 m) with a minimum grade,
	# plus authored riffle steps. Always non-increasing downstream.
	var prev := 1e6
	var step_prev := 0.0
	for k in count:
		var base := sample_grid(height, pts[k])
		var step_cum := 0.0
		for st in cfg.river_steps:
			step_cum += cfg.river_step_drop * smoothstep(st - 6.0, st + 6.0, arc[k])
		var ds := arc[k] - arc[k - 1] if k > 0 else 0.0
		var lvl := minf(prev - 0.0025 * ds - (step_cum - step_prev), base - 1.05)
		step_prev = step_cum
		lvl = maxf(lvl, cfg.sea_level + 0.04)
		if k > 0:
			lvl = minf(lvl, prev)
		levels[k] = lvl
		prev = lvl
	var widths := PackedFloat32Array()
	var rapid := PackedFloat32Array()
	widths.resize(count)
	rapid.resize(count)
	var total: float = river.length
	for k in count:
		widths[k] = lerpf(cfg.river_width_source, cfg.river_width_mouth, pow(arc[k] / total, 0.8))
		var k0 := maxi(k - 4, 0)
		var k1 := mini(k + 4, count - 1)
		var grade := (levels[k0] - levels[k1]) / maxf(arc[k1] - arc[k0], 0.1)
		rapid[k] = clampf((grade - 0.012) / 0.05, 0.0, 1.0)
	river["levels"] = levels
	river["widths"] = widths
	river["rapid"] = rapid
	# Carve channel + banks
	for idx in W * H:
		var d := _river_d[idx]
		if d > 40.0 or height[idx] < cfg.sea_level - 0.2:
			continue
		var s := _river_s[idx]
		var k := _arc_index(s)
		var lvl := levels[k]
		var half := widths[k] * 0.5
		var base := height[idx]
		if d < half:
			var u := d / half
			height[idx] = minf(base, lvl - 0.08 - cfg.river_depth * pow(1.0 - u * u, 0.65))
		else:
			var bank_w := clampf(5.0 + (base - lvl) * 1.6, 5.0, 26.0)
			if d < half + bank_w:
				var t := (d - half) / bank_w
				var bank := lvl + 0.04 + (d - half) * 0.22
				var target := lerpf(bank, maxf(base, lvl + 0.3), smoothstep(0.0, 1.0, t))
				# Only cut down (never build levees above natural ground far from water)
				height[idx] = maxf(minf(base, target) if base > lvl + 0.3 else target, lvl + 0.04)


func _arc_index(s: float) -> int:
	var arc: PackedFloat32Array = river.arc
	var k := arc.bsearch(s)
	return clampi(k, 0, arc.size() - 1)


func _build_water_maps() -> void:
	var n := W * H
	water_surface.resize(n)
	water_region.resize(n)
	water_surface.fill(cfg.sea_level)
	water_region.fill(0)
	var levels: PackedFloat32Array = river.levels
	var widths: PackedFloat32Array = river.widths
	for idx in n:
		var d := _river_d[idx]
		if d < 20.0:
			var k := _arc_index(_river_s[idx])
			if d < widths[k] * 0.5 + 1.5 and levels[k] > cfg.sea_level + 0.05 and height[idx] < levels[k] + 0.3:
				water_surface[idx] = levels[k]
				water_region[idx] = 1
	for pd in ponds:
		var c: Vector2 = pd.center
		var r: float = pd.radius * 1.2 + 2.0
		var ext := int(ceil(r / cs)) + 1
		var ci := int(round((c.x - bmin.x) / cs))
		var cj := int(round((c.y - bmin.y) / cs))
		for j in range(maxi(cj - ext, 0), mini(cj + ext + 1, H)):
			for i in range(maxi(ci - ext, 0), mini(ci + ext + 1, W)):
				var idx := j * W + i
				if world_xz(i, j).distance_to(c) < r and height[idx] < pd.level + 0.3:
					water_surface[idx] = pd.level
					water_region[idx] = 2 + int(pd.index)


func _place_bridges() -> void:
	bridges.clear()
	var pts: PackedVector2Array = river.points
	for f in cfg.bridge_sites:
		var k := _arc_index(f * float(river.length))
		var k0 := maxi(k - 3, 0)
		var k1 := mini(k + 3, pts.size() - 1)
		var tangent := (pts[k1] - pts[k0]).normalized()
		var across := Vector2(-tangent.y, tangent.x)
		var half_span: float = river.widths[k] * 0.5 + 5.0
		var a := pts[k] - across * half_span
		var b := pts[k] + across * half_span
		var deck := maxf(sample_grid(height, a), sample_grid(height, b))
		deck = maxf(deck, float(river.levels[k]) + 0.9)
		bridges.append({"center": pts[k], "across": across, "half_span": half_span, "deck": snappedf(deck + 0.15, 0.01), "arc": river.arc[k]})


func _excluded_for_props(p: Vector2, idx: int, margin: float) -> bool:
	if camp_sd(p) < cfg.camp_tree_clearance + margin:
		return true
	if _trail_d[idx] < 2.5 + margin:
		return true
	for br in bridges:
		if p.distance_to(br.center) < float(br.half_span) + 6.0 + margin:
			return true
	for pd in ponds:
		if p.distance_to(pd.center) < float(pd.radius) * 1.15 + 3.0 + margin:
			return true
	return false


func _grid_index(p: Vector2) -> int:
	var i := clampi(int(round((p.x - bmin.x) / cs)), 0, W - 1)
	var j := clampi(int(round((p.y - bmin.y) / cs)), 0, H - 1)
	return j * W + i


func _slope_at(p: Vector2) -> float:
	var e := cs
	var dx := sample_grid(height, p + Vector2(e, 0)) - sample_grid(height, p - Vector2(e, 0))
	var dz := sample_grid(height, p + Vector2(0, e)) - sample_grid(height, p - Vector2(0, e))
	return Vector2(dx, dz).length() / (2.0 * e)


func _place_rocks() -> void:
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var sc := PackedFloat32Array()
	var rot := PackedFloat32Array()
	var kind := PackedByteArray()
	var seedv := PackedInt32Array()
	var add := func(p: Vector2, s: float, k: int, r: float, sd: int) -> void:
		xs.append(p.x); zs.append(p.y)
		ys.append(sample_grid(height, p) - s * 0.28)
		sc.append(s); kind.append(k); rot.append(r); seedv.append(sd)
	var s := cfg.world_seed
	# Ridge outcrops
	var placed := 0
	var tries := 0
	while placed < cfg.ridge_rock_count and tries < 20000:
		tries += 1
		var t := hash01(s, tries, 1)
		var off := (hash01(s, tries, 2) * 2.0 - 1.0) * cfg.ridge_half_width * 0.75
		var axis := cfg.ridge_end - cfg.ridge_start
		var nrm := Vector2(-axis.y, axis.x).normalized()
		var p := cfg.ridge_start + axis * t + nrm * off
		var idx := _grid_index(p)
		if height[idx] < 8.0 or _excluded_for_props(p, idx, 0.0) or _river_d[idx] < 12.0:
			continue
		add.call(p, lerpf(1.4, 4.8, pow(hash01(s, tries, 3), 1.6)), 0, hash01(s, tries, 4) * TAU, int(hash_u32(s, tries, 5) & 0xFFFF))
		placed += 1
	# Forest boulders
	placed = 0
	tries = 0
	while placed < cfg.forest_boulder_count and tries < 40000:
		tries += 1
		var p := Vector2(lerpf(-800, 800, hash01(s, tries, 11)), lerpf(-600, 600, hash01(s, tries, 12)))
		var idx := _grid_index(p)
		if height[idx] < 3.0 or _beach[idx] > 0.4 or _excluded_for_props(p, idx, 2.0) or _river_d[idx] < 10.0:
			continue
		add.call(p, lerpf(0.7, 2.6, pow(hash01(s, tries, 13), 2.0)), 1, hash01(s, tries, 14) * TAU, int(hash_u32(s, tries, 15) & 0xFFFF))
		placed += 1
	# Tide-worn shore stones (mostly on rocky coast, a few on beaches)
	placed = 0
	tries = 0
	while placed < cfg.shore_stone_count and tries < 80000:
		tries += 1
		var p := Vector2(lerpf(-1000, 1000, hash01(s, tries, 21)), lerpf(-800, 800, hash01(s, tries, 22)))
		var idx := _grid_index(p)
		var di := _dist_in[idx]
		if di < -14.0 or di > 9.0 or height[idx] < -1.6:
			continue
		var beachy := _beach[idx]
		if beachy > 0.5 and hash01(s, tries, 23) > 0.08:
			continue
		if _excluded_for_props(p, idx, 0.0) or _river_d[idx] < 14.0:
			continue
		add.call(p, lerpf(0.5, 2.2, pow(hash01(s, tries, 24), 1.8)), 2, hash01(s, tries, 25) * TAU, int(hash_u32(s, tries, 26) & 0xFFFF))
		placed += 1
	# River rocks at grade changes
	var pts: PackedVector2Array = river.points
	for k in pts.size():
		if float(river.rapid[k]) < 0.35 or k % 3 != 0:
			continue
		var k1 := mini(k + 1, pts.size() - 1)
		var tangent := (pts[k1] - pts[maxi(k - 1, 0)]).normalized()
		var across := Vector2(-tangent.y, tangent.x)
		for m in 2:
			var off := (hash01(s, k, 30 + m) * 2.0 - 1.0) * float(river.widths[k]) * 0.55
			var p := pts[k] + across * off
			add.call(p, lerpf(0.4, 1.0, hash01(s, k, 40 + m)), 3, hash01(s, k, 50 + m) * TAU, int(hash_u32(s, k, 60 + m) & 0xFFFF))
	rocks = {"x": xs, "z": zs, "y": ys, "scale": sc, "rot": rot, "kind": kind, "seed": seedv}


func _place_trees() -> void:
	var s := cfg.world_seed
	var step := cfg.tree_candidate_spacing
	var cand_x := PackedFloat32Array()
	var cand_z := PackedFloat32Array()
	var cand_key := PackedFloat32Array()
	var cand_sp := PackedByteArray()
	# Rock spatial hash
	var rock_hash := {}
	var rxs: PackedFloat32Array = rocks.x
	var rzs: PackedFloat32Array = rocks.z
	var rsc: PackedFloat32Array = rocks.scale
	for r in rxs.size():
		var key := Vector2i(int(floor(rxs[r] / 8.0)), int(floor(rzs[r] / 8.0)))
		if not rock_hash.has(key):
			rock_hash[key] = []
		rock_hash[key].append(r)
	var gi := 0
	var z := -620.0
	while z < 620.0:
		var x := -820.0
		while x < 820.0:
			gi += 1
			var p := Vector2(x + (hash01(s, gi, 101) - 0.5) * step * 0.95, z + (hash01(s, gi, 102) - 0.5) * step * 0.95)
			x += step
			var idx := _grid_index(p)
			var h := height[idx]
			if h < 1.7 or water_region[idx] != 0 or _beach[idx] * (1.0 - smoothstep(2.5, 6.5, h)) > 0.3:
				continue
			if _river_d[idx] < float(river.widths[_arc_index(_river_s[idx])]) * 0.5 + 3.0:
				continue
			if _excluded_for_props(p, idx, 0.0):
				continue
			var slope := _slope_at(p)
			if slope > 0.62:
				continue
			var blocked := false
			var rk := Vector2i(int(floor(p.x / 8.0)), int(floor(p.y / 8.0)))
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					for r in rock_hash.get(rk + Vector2i(dx, dz), []):
						if p.distance_to(Vector2(rxs[r], rzs[r])) < rsc[r] * 0.9 + 1.0:
							blocked = true
			if blocked:
				continue
			var cluster := _n_forest.get_noise_2d(p.x, p.y)
			var prob := smoothstep(-0.45, 0.2, cluster)
			prob *= smoothstep(1.7, 4.5, h)
			prob *= 1.0 - 0.5 * smoothstep(0.35, 0.62, slope)
			var ridge := seg_dist(p, cfg.ridge_start, cfg.ridge_end).x
			if ridge < cfg.ridge_half_width * 0.5 and h > 30.0:
				prob *= 0.55
			if prob < 0.02:
				continue
			# Species from ecology fields
			var low_d := p.distance_to(Vector2(cfg.lowland.x, cfg.lowland.y))
			var wet := maxf(1.0 - smoothstep(cfg.lowland.z * 0.3, cfg.lowland.z, low_d), exp(-pow(_river_d[idx] / 30.0, 2.0)))
			var sn := _n_species.get_noise_2d(p.x, p.y)
			var w_birch := 0.25 + 1.4 * wet + maxf(sn, 0.0) * 0.8
			var w_spruce := 0.45 + smoothstep(10.0, 30.0, h) * 0.9 + maxf(-sn, 0.0) * 0.9
			var w_pine := 0.9 + (1.0 - smoothstep(4.0, 12.0, h)) * 0.8 + _beach[idx] * 0.8 + smoothstep(25.0, 45.0, h) * 0.6
			var tot := w_birch + w_spruce + w_pine
			var r01 := hash01(s, gi, 103) * tot
			var sp := 0 if r01 < w_pine else (1 if r01 < w_pine + w_spruce else 2)
			cand_x.append(p.x)
			cand_z.append(p.y)
			cand_sp.append(sp)
			# Weighted sampling key (Efraimidis-Spirakis)
			cand_key.append(pow(maxf(hash01(s, gi, 104), 1e-9), 1.0 / prob))
		z += step
	# Order candidates by key (desc) and accept with min spacing.
	var order := range(cand_x.size())
	order.sort_custom(func(a: int, b: int) -> bool: return cand_key[a] > cand_key[b] if cand_key[a] != cand_key[b] else a < b)
	var spacing_hash := {}
	var sel: Array[int] = []
	var minsp := cfg.min_trunk_spacing
	for c in order:
		if sel.size() >= cfg.tree_target:
			break
		var p := Vector2(cand_x[c], cand_z[c])
		var key := Vector2i(int(floor(p.x / minsp)), int(floor(p.y / minsp)))
		var ok := true
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for o in spacing_hash.get(key + Vector2i(dx, dz), []):
					if p.distance_squared_to(Vector2(cand_x[o], cand_z[o])) < minsp * minsp:
						ok = false
		if not ok:
			continue
		if not spacing_hash.has(key):
			spacing_hash[key] = []
		spacing_hash[key].append(c)
		sel.append(c)
	# Build records, sorted by (vegetation chunk, z, x) for stable IDs.
	var vcs := cfg.vegetation_chunk_size
	var vcw := int(ceil((cfg.bounds_max.x - cfg.bounds_min.x) / vcs))
	var chunk_of := func(c: int) -> int:
		return int(floor((cand_z[c] - bmin.y) / vcs)) * vcw + int(floor((cand_x[c] - bmin.x) / vcs))
	sel.sort_custom(func(a: int, b: int) -> bool:
		var ca: int = chunk_of.call(a)
		var cb: int = chunk_of.call(b)
		if ca != cb:
			return ca < cb
		if cand_z[a] != cand_z[b]:
			return cand_z[a] < cand_z[b]
		return cand_x[a] < cand_x[b])
	var ids := PackedInt32Array()
	var species := PackedByteArray()
	var variant := PackedByteArray()
	var chunk := PackedInt32Array()
	var tx := PackedFloat32Array()
	var tz := PackedFloat32Array()
	var trot := PackedFloat32Array()
	var theight := PackedFloat32Array()
	var tradius := PackedFloat32Array()
	var tlean_x := PackedFloat32Array()
	var tlean_z := PackedFloat32Array()
	var tlogs := PackedByteArray()
	var tseed := PackedInt32Array()
	var ranges := [Vector2(15.0, 24.0), Vector2(12.0, 21.0), Vector2(9.0, 16.0)]
	for n in sel.size():
		var c := sel[n]
		var sp := cand_sp[c]
		var hs := hash_u32(s, int(cand_x[c] * 100.0), int(cand_z[c] * 100.0))
		var r1 := float(hs & 0xFFFF) / 65535.0
		var r2 := float((hs >> 16) & 0xFFFF) / 65535.0
		var r3 := hash01(hs, 7, 3)
		var r4 := hash01(hs, 9, 5)
		var hrange: Vector2 = ranges[sp]
		var th := lerpf(hrange.x, hrange.y, pow(r1, 0.8))
		var rad := th * (0.016 if sp == 2 else 0.019) * lerpf(0.85, 1.2, r2)
		ids.append(n)
		species.append(sp)
		variant.append(int(r3 * 2.999))
		chunk.append(chunk_of.call(c))
		tx.append(snappedf(cand_x[c], 0.001))
		tz.append(snappedf(cand_z[c], 0.001))
		trot.append(snappedf(r4 * TAU, 0.0001))
		theight.append(snappedf(th, 0.01))
		tradius.append(snappedf(rad, 0.001))
		var lean_amt := deg_to_rad(lerpf(0.0, 4.0 if sp != 1 else 2.0, hash01(hs, 11, 1)))
		var lean_dir := hash01(hs, 13, 2) * TAU
		tlean_x.append(snappedf(cos(lean_dir) * lean_amt, 0.0001))
		tlean_z.append(snappedf(sin(lean_dir) * lean_amt, 0.0001))
		tlogs.append(clampi(int(th / 4.5), 2, 5))
		tseed.append(int(hs & 0x7FFFFFFF))
	trees = {
		"id": ids, "species": species, "variant": variant, "chunk": chunk,
		"x": tx, "z": tz, "rot": trot, "height": theight, "radius": tradius,
		"lean_x": tlean_x, "lean_z": tlean_z, "logs": tlogs, "seed": tseed,
	}


func _build_masks() -> void:
	var n := W * H
	masks.resize(n * 4)
	# Forest density raster from final trees (8 m cells, blurred)
	var fcs := 8.0
	var fw := int(ceil((cfg.bounds_max.x - bmin.x) / fcs)) + 1
	var fh := int(ceil((cfg.bounds_max.y - bmin.y) / fcs)) + 1
	var dens := PackedFloat32Array()
	dens.resize(fw * fh)
	var tx: PackedFloat32Array = trees.x
	var tz: PackedFloat32Array = trees.z
	for t in tx.size():
		var fi := int((tx[t] - bmin.x) / fcs)
		var fj := int((tz[t] - bmin.y) / fcs)
		for dj in range(-2, 3):
			for di in range(-2, 3):
				var ii := clampi(fi + di, 0, fw - 1)
				var jj := clampi(fj + dj, 0, fh - 1)
				dens[jj * fw + ii] += 1.0 / (1.0 + float(di * di + dj * dj))
	for j in H:
		for i in W:
			var idx := j * W + i
			var p := world_xz(i, j)
			var h := height[idx]
			var b := _beach[idx]
			var sand := 0.0
			if h < 0.0:
				sand = 1.0 - _rocky[idx] * 0.7
			else:
				sand = b * (1.0 - smoothstep(2.6, 5.0, h))
			if water_region[idx] != 0:
				sand = maxf(sand, 0.35)
			var fx := clampf((p.x - bmin.x) / fcs - 0.5, 0.0, fw - 1.001)
			var fz := clampf((p.y - bmin.y) / fcs - 0.5, 0.0, fh - 1.001)
			var ii := int(fx)
			var jj := int(fz)
			fx -= ii
			fz -= jj
			var fd := lerpf(lerpf(dens[jj * fw + ii], dens[jj * fw + ii + 1], fx), lerpf(dens[(jj + 1) * fw + ii], dens[(jj + 1) * fw + ii + 1], fx), fz)
			var forest := clampf(fd / 2.2, 0.0, 1.0)
			var dirt := 0.0
			var sd := camp_sd(p)
			dirt = maxf(dirt, 1.0 - smoothstep(-1.0, 3.0, sd))
			dirt = maxf(dirt, (1.0 - smoothstep(0.8, 2.6, _trail_d[idx])) * 0.85)
			for br in bridges:
				var bd := seg_dist(p, br.center - br.across * (br.half_span + 4.0), br.center + br.across * (br.half_span + 4.0)).x
				dirt = maxf(dirt, (1.0 - smoothstep(1.0, 2.5, bd)) * 0.9)
			var rock := _rocky[idx] * smoothstep(-1.0, 1.5, h)
			var rs := seg_dist(p, cfg.ridge_start, cfg.ridge_end).x
			rock = maxf(rock, (1.0 - smoothstep(cfg.ridge_half_width * 0.25, cfg.ridge_half_width * 0.7, rs)) * smoothstep(22.0, 34.0, h))
			masks[idx * 4 + 0] = int(clampf(sand, 0.0, 1.0) * 255.0)
			masks[idx * 4 + 1] = int(forest * 255.0)
			masks[idx * 4 + 2] = int(clampf(dirt, 0.0, 1.0) * 255.0)
			masks[idx * 4 + 3] = int(clampf(rock, 0.0, 1.0) * 255.0)


func _collect_shore_points() -> void:
	# Coarse samples where land meets sea, for ambient audio emitters.
	shore_points.clear()
	var step := 10
	for j in range(0, H - step, step):
		for i in range(0, W - step, step):
			var a := height[j * W + i]
			var b := height[j * W + i + step]
			var c := height[(j + step) * W + i]
			if (a > 0.0) != (b > 0.0) or (a > 0.0) != (c > 0.0):
				shore_points.append(world_xz(i + step / 2, j + step / 2))


func _compute_stats() -> void:
	var land := 0
	var minp := Vector2(1e9, 1e9)
	var maxp := Vector2(-1e9, -1e9)
	var max_h := -1e9
	for j in H:
		for i in W:
			var h := height[j * W + i]
			if h > cfg.sea_level:
				land += 1
				var p := world_xz(i, j)
				minp = Vector2(minf(minp.x, p.x), minf(minp.y, p.y))
				maxp = Vector2(maxf(maxp.x, p.x), maxf(maxp.y, p.y))
				max_h = maxf(max_h, h)
	var sp_counts := [0, 0, 0]
	var spa: PackedByteArray = trees.species
	for v in spa:
		sp_counts[v] += 1
	var kinds := [0, 0, 0, 0]
	for v in (rocks.kind as PackedByteArray):
		kinds[v] += 1
	var land_km2 := land * cs * cs / 1.0e6
	stats = {
		"land_area_km2": snappedf(land_km2, 0.001),
		"land_extent_m": [snappedf(maxp.x - minp.x, 1.0), snappedf(maxp.y - minp.y, 1.0)],
		"land_bounds": [minp.x, minp.y, maxp.x, maxp.y],
		"max_height_m": snappedf(max_h, 0.01),
		"tree_count": (trees.id as PackedInt32Array).size(),
		"trees_per_species": {"pine": sp_counts[0], "spruce": sp_counts[1], "birch": sp_counts[2]},
		"trees_per_km2": snappedf((trees.id as PackedInt32Array).size() / maxf(land_km2, 0.001), 1.0),
		"rocks_per_kind": {"ridge": kinds[0], "boulder": kinds[1], "shore": kinds[2], "river": kinds[3]},
		"river_length_m": snappedf(float(river.length), 0.1),
		"river_source_level_m": snappedf(float(river.levels[0]), 0.01),
		"river_mouth_level_m": snappedf(float(river.levels[(river.levels as PackedFloat32Array).size() - 1]), 0.01),
		"ponds": ponds.map(func(p: Dictionary) -> Dictionary: return {"x": p.center.x, "z": p.center.y, "radius": p.radius, "level": p.level}),
		"bridges": bridges.size(),
		"shore_audio_points": shore_points.size(),
		"long_axis_walk_minutes_at_4_2mps": snappedf((maxp.x - minp.x) / 4.2 / 60.0, 0.1),
	}


# ------------------------------------------------------------------ output

func river_as_json() -> Dictionary:
	var pts: PackedVector2Array = river.points
	var out := []
	for k in pts.size():
		out.append([snappedf(pts[k].x, 0.001), snappedf(pts[k].y, 0.001), snappedf(river.levels[k], 0.001), snappedf(river.widths[k], 0.001), snappedf(river.rapid[k], 0.001), snappedf(river.arc[k], 0.001)])
	return {"samples": out, "length": snappedf(float(river.length), 0.001)}


func layout_json() -> Dictionary:
	var br := []
	for b in bridges:
		br.append({"x": b.center.x, "z": b.center.y, "ax": b.across.x, "az": b.across.y, "half_span": b.half_span, "deck": b.deck, "arc": b.arc})
	var pd := []
	for p in ponds:
		pd.append({"x": p.center.x, "z": p.center.y, "radius": p.radius, "level": p.level, "depth": p.depth})
	var sp := []
	for p in shore_points:
		sp.append([p.x, p.y])
	return {"river": river_as_json(), "ponds": pd, "bridges": br, "shore_points": sp}


func write_to(dir_path: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var files := {}
	files["heightmap.bin"] = height.to_byte_array()
	files["masks.bin"] = masks
	files["water_surface.bin"] = water_surface.to_byte_array()
	files["water_region.bin"] = water_region
	files["trees.bin"] = var_to_bytes(trees)
	files["rocks.bin"] = var_to_bytes(rocks)
	files["layout.json"] = JSON.stringify(layout_json(), "\t", false).to_utf8_buffer()
	var hashes := {}
	for fname in files:
		var bytes: PackedByteArray = files[fname]
		hashes[fname] = _md5(bytes)
		var f := FileAccess.open_compressed(dir_path.path_join(fname + ".zst"), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD) if fname.ends_with(".bin") else FileAccess.open(dir_path.path_join(fname), FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
	var manifest := {
		"format": 1,
		"world_seed": cfg.world_seed,
		"generation_version": cfg.generation_version,
		"generator_revision": GENERATOR_REVISION,
		"config_fingerprint": cfg.config_fingerprint(),
		"grid": {"width": W, "height": H, "cell_size": cs, "origin": [bmin.x, bmin.y]},
		"sea_level": cfg.sea_level,
		"content_hashes": hashes,
		"stats": stats,
	}
	var mf := FileAccess.open(dir_path.path_join("manifest.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest, "\t", false))
	mf.close()
	return manifest


func content_hashes() -> Dictionary:
	return {
		"heightmap.bin": _md5(height.to_byte_array()),
		"masks.bin": _md5(masks),
		"water_surface.bin": _md5(water_surface.to_byte_array()),
		"water_region.bin": _md5(water_region),
		"trees.bin": _md5(var_to_bytes(trees)),
		"rocks.bin": _md5(var_to_bytes(rocks)),
	}


static func _md5(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
