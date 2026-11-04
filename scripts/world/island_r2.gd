class_name IslandR2
extends RefCounted
## Phase 12: island revision 2 ("island_r2"), the layout for NEW standard
## campaigns. Derived deterministically from the frozen base world
## (data/world, revision 1, which legacy and existing saves keep using) and
## frozen in data/world/r2 by tools/generate_island_r2.gd.
##
## Order of work (each step validates against everything placed before it):
##   1. Landforms: hummocks, small ridges and shallow gullies, blended into
##      the base terrain with an eligibility mask that is exactly zero near
##      water, beaches, camp, trails, bridges and trail cameras.
##   2. Persistent cover: hide formations (rock recess / rock gap with an
##      entry, a crouched pose and exits), then boulder clusters and rock
##      shelves placed greedily where work areas are farthest from any hard
##      sightline break. None of this is a native tree.
##   3. Exactly 10,000 native trees: regions get quotas by usable area x an
##      intentional density weight (largest remainder); groves and gaps
##      shape intensity; every accepted tree passes support, slope, spacing,
##      rock and a two-sided work-approach check that later trees may not
##      take away. Finite candidates; a shortfall is a visible error.
##   4. Undergrowth (non-native, non-harvestable): tall shrubs, juniper,
##      bramble, bracken and damp-edge sedge, plus thickets (soft cover).
##   5. Masks: forest floor from the new trees, exposed rock at formations
##      and landform crowns, damp soil in gullies.

const REVISION := 1
const TREE_TARGET := 10000
const OUT_DIR := "res://data/world/r2"
const RC := 4.0                 # raster cell for distance fields (m)
const WORK_CELL := 8.0          # coverage analysis cell (m)
const HARD_BREAK_TARGET := 46.0 # max distance from work ground to hard cover (m)
const HIDE_TARGET := 115.0      # max distance from work ground to a hide (m)
const MAX_FORMATIONS := 250
const MAX_HIDES := 62

const SPECIES := ["pine", "spruce", "birch"]
const COHORTS := ["young", "mature", "veteran"]
## Named regions (Voronoi seeds) with intentional density weights.
const REGIONS := [
	["Camp woods", Vector2(-190.0, 230.0), 1.0],
	["Lowland fern basin", Vector2(-430.0, -40.0), 1.18],
	["South-west shore woods", Vector2(-540.0, 210.0), 0.85],
	["North-west inlet woods", Vector2(-560.0, -260.0), 0.95],
	["Far west point", Vector2(-700.0, 20.0), 0.9],
	["Central woods", Vector2(-170.0, -170.0), 1.05],
	["North bight woods", Vector2(90.0, -480.0), 0.95],
	["River valley", Vector2(160.0, 110.0), 1.05],
	["Ridge slopes", Vector2(340.0, -250.0), 0.7],
	["East plateau", Vector2(520.0, -20.0), 1.0],
	["South-east cove woods", Vector2(430.0, 330.0), 0.9],
]
## Undergrowth kinds (data contract with UndergrowthSystem / CoverService).
enum Shrub { HAZEL, JUNIPER, BRAMBLE, BRACKEN, SEDGE, DEADFALL }
const SHRUB_NAMES := ["hazel", "juniper", "bramble", "bracken", "sedge", "deadfall"]
## Rock kinds: 0..3 base (ridge, boulder, shore, river); 4.. Phase 12.
enum RockKind { CLUSTER = 4, SHELF = 5, HIDE_STONE = 6 }

var wd                           # base WorldData (revision 1, loaded)
var cfg: WorldConfig
var W := 0
var H := 0
var cs := 2.0
var org := Vector2.ZERO
var seed_v := 0
var base_h := PackedFloat32Array()
var height := PackedFloat32Array()
var delta := PackedFloat32Array()
var elig := PackedFloat32Array()
var masks := PackedByteArray()

var rw := 0
var rh := 0
var river_d := PackedFloat32Array()    # distance from the river bank (m)
var trail_d := PackedFloat32Array()    # distance from a trail centreline (m)

var cameras: Array = []                # [{pos: Vector2, look: Vector2}]
var landforms: Array = []
var formations: Array = []
var hides: Array = []
var thickets: Array = []
var regions_out: Array = []
var rejections := {}

var trees: Dictionary = {}
var rocks: Dictionary = {}
var shrubs: Dictionary = {}
var stats: Dictionary = {}

var _rock_radius_v: Array = []         # per RockBuilder variant: unit XZ bound radius
var _rock_hash := {}                   # Vector2i(8 m) -> [rock idx]
var _tree_hash := {}                   # Vector2i(4 m) -> [accepted tree record idx]
var _acc: Array = []                   # accepted tree records (Dictionary)
var _nav_solid := {}                   # Vector2i -> true: CrewNav cells rocks/steepness block
var _nav_origin := Vector2.ZERO
var _nav_comp := {}                    # Vector2i -> true: connected to the camp gate
var _n_cluster := FastNoiseLite.new()
var _n_gap := FastNoiseLite.new()
var _n_species := FastNoiseLite.new()
var _n_shrub := FastNoiseLite.new()


func _init(base_world) -> void:
	wd = base_world
	cfg = wd.config
	W = wd.W
	H = wd.H
	cs = wd.cs
	org = wd.origin
	seed_v = cfg.world_seed * 7 + 1201
	base_h = wd.height
	for n in [_n_cluster, _n_gap, _n_species, _n_shrub]:
		(n as FastNoiseLite).noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_cluster.seed = seed_v + 3
	_n_cluster.frequency = 1.0 / 95.0
	_n_cluster.fractal_octaves = 3
	_n_gap.seed = seed_v + 5
	_n_gap.frequency = 1.0 / 42.0
	_n_gap.fractal_octaves = 2
	_n_species.seed = seed_v + 7
	_n_species.frequency = 1.0 / 210.0
	_n_species.fractal_octaves = 2
	_n_shrub.seed = seed_v + 11
	_n_shrub.frequency = 1.0 / 28.0
	_n_shrub.fractal_octaves = 2


# =============================================================== helpers

static func h01(a: int, b: int, c: int) -> float:
	return IslandGenerator.hash01(a, b, c)


static func sm(e0: float, e1: float, x: float) -> float:
	return smoothstep(e0, e1, x)


func hgt(x: float, z: float) -> float:
	var fx := clampf((x - org.x) / cs, 0.0, W - 1.0001)
	var fz := clampf((z - org.y) / cs, 0.0, H - 1.0001)
	var i := int(fx)
	var j := int(fz)
	fx -= i
	fz -= j
	var row := j * W + i
	var a := height[row]
	var b := height[row + 1]
	var c := height[row + W]
	var d := height[row + W + 1]
	if fx > fz:
		return a + (b - a) * fx + (d - b) * fz
	return a + (c - a) * fz + (d - c) * fx


func slope(p: Vector2) -> float:
	var dx := hgt(p.x + cs, p.y) - hgt(p.x - cs, p.y)
	var dz := hgt(p.x, p.y + cs) - hgt(p.x, p.y - cs)
	return Vector2(dx, dz).length() / (2.0 * cs)


func _texel(p: Vector2) -> int:
	var i := clampi(int(round((p.x - org.x) / cs)), 0, W - 1)
	var j := clampi(int(round((p.y - org.y) / cs)), 0, H - 1)
	return j * W + i


func sand(p: Vector2) -> float:
	return float(wd.masks[_texel(p) * 4]) / 255.0


func water(p: Vector2) -> bool:
	var t := _texel(p)
	return int(wd.water_region[t]) != 0 and float(wd.water_surface[t]) > hgt(p.x, p.y) - 0.05


func camp_sd(p: Vector2) -> float:
	var half := cfg.camp_size * 0.5
	var q := (p - cfg.camp_center).abs() - (half - Vector2(6, 6))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 6.0


func pond_d(p: Vector2) -> float:
	var best := 1e9
	for pd in wd.ponds():
		best = minf(best, p.distance_to(Vector2(pd.x, pd.z)) - float(pd.radius) * 1.15)
	return best


func bridge_d(p: Vector2) -> float:
	var best := 1e9
	for br in wd.bridges():
		best = minf(best, p.distance_to(Vector2(float(br.x), float(br.z))) - float(br.half_span))
	return best


func cam_d(p: Vector2) -> float:
	var best := 1e9
	for c in cameras:
		best = minf(best, p.distance_to(c.pos))
		# Lens corridor: the first 22 m along the view direction.
		var seg := IslandGenerator.seg_dist(p, c.pos, c.pos + (c.look - c.pos).normalized() * 22.0)
		best = minf(best, seg.x + 2.5)
	return best


func _ri(p: Vector2) -> int:
	var i := clampi(int((p.x - org.x) / RC), 0, rw - 1)
	var j := clampi(int((p.y - org.y) / RC), 0, rh - 1)
	return j * rw + i


func rd(p: Vector2) -> float:
	return river_d[_ri(p)]


func td(p: Vector2) -> float:
	return trail_d[_ri(p)]


# =============================================================== run

func generate() -> void:
	var t0 := Time.get_ticks_msec()
	height = base_h.duplicate()
	_rock_bounds()
	_cameras()
	_distance_rasters()
	_eligibility()
	_landforms()
	_apply_landforms()
	_base_rocks()
	_place_hides()
	_place_cover()
	_nav_solid_build()
	_nav_component()
	_place_trees()
	_place_undergrowth()
	_build_masks()
	_compute_stats(Time.get_ticks_msec() - t0)


func _rock_bounds() -> void:
	# Exact unit XZ bounding radius of each RockBuilder variant (the same
	# meshes the game instances), so clearances are true, not guessed.
	for m in RockBuilder.build_variants(6):
		var arr: Array = (m as ArrayMesh).surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var r := 0.0
		for v in verts:
			r = maxf(r, Vector2(v.x, v.z).length())
		_rock_radius_v.append(r)


## Radius (m) of a rock's footprint: unit bound x scale x horizontal stretch.
func rock_bound(seed_i: int, s: float, stretch: float) -> float:
	return float(_rock_radius_v[seed_i % _rock_radius_v.size()]) * s * maxf(stretch, 1.0)


func _cameras() -> void:
	# The three trail cameras sit on rocks beside the trails (CampReservations).
	for spec in [[0, 2], [1, 3], [0, 4]]:
		var trail: PackedVector2Array = cfg.trails[spec[0]]
		var a: Vector2 = trail[mini(spec[1] - 1, trail.size() - 2)]
		var b: Vector2 = trail[mini(spec[1], trail.size() - 1)]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x)
		cameras.append({"pos": a.lerp(b, 0.5) + side * 3.2, "look": b + along * 15.0})


func _distance_rasters() -> void:
	rw = int(ceil((W - 1) * cs / RC)) + 1
	rh = int(ceil((H - 1) * cs / RC)) + 1
	river_d.resize(rw * rh)
	trail_d.resize(rw * rh)
	river_d.fill(1e6)
	trail_d.fill(1e6)
	var pts: PackedVector2Array = wd.river_points
	var wid: PackedFloat32Array = wd.river_widths
	for k in pts.size():
		_stamp(river_d, pts[k], 48.0, float(wid[k]) * 0.5)
	for trail in cfg.trails:
		var tp: PackedVector2Array = trail
		for s in tp.size() - 1:
			var a: Vector2 = tp[s]
			var b: Vector2 = tp[s + 1]
			var n := int(ceil(a.distance_to(b) / 2.0))
			for k in n + 1:
				_stamp(trail_d, a.lerp(b, float(k) / n), 30.0, 0.0)


func _stamp(arr: PackedFloat32Array, c: Vector2, radius: float, offset: float) -> void:
	var i0 := maxi(int((c.x - radius - org.x) / RC), 0)
	var i1 := mini(int((c.x + radius - org.x) / RC) + 1, rw - 1)
	var j0 := maxi(int((c.y - radius - org.y) / RC), 0)
	var j1 := mini(int((c.y + radius - org.y) / RC) + 1, rh - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := org + Vector2(i * RC, j * RC)
			var d := p.distance_to(c) - offset
			if d < arr[j * rw + i]:
				arr[j * rw + i] = d


## 0..1 weight of where landform edits may change the ground. Exactly zero
## at water, beaches, camp, trails, bridges and cameras (so shorelines,
## crossings, roads, the camp and every mount keep their ground).
func _elig_at(p: Vector2) -> float:
	var h0: float = wd.height_at(p.x, p.y)
	if h0 < 3.5:
		return 0.0
	var w := sm(4.0, 7.5, h0)
	w *= sm(16.0, 32.0, rd(p))
	w *= sm(14.0, 30.0, pond_d(p))
	w *= sm(30.0, 52.0, camp_sd(p))
	w *= sm(9.0, 20.0, td(p))
	w *= sm(26.0, 42.0, bridge_d(p))
	w *= 1.0 - sm(0.15, 0.4, sand(p))
	if w <= 0.0:
		return 0.0
	for c in cameras:
		w *= sm(9.0, 16.0, p.distance_to(c.pos))
	return w


func _eligibility() -> void:
	elig.resize(W * H)
	elig.fill(0.0)
	for j in H:
		for i in W:
			var p := org + Vector2(i * cs, j * cs)
			if base_h[j * W + i] < 3.5:
				continue
			elig[j * W + i] = _elig_at(p)


# ======================================================== 1. landforms

func _landforms() -> void:
	var specs := [["hummock", 84, 1], ["ridge", 28, 2], ["gully", 14, 3]]
	for spec in specs:
		var kind: String = spec[0]
		var want: int = spec[1]
		var placed := 0
		var tries := 0
		while placed < want and tries < want * 400:
			tries += 1
			var p := Vector2(lerpf(-780.0, 780.0, h01(seed_v, tries, 100 + spec[2])), lerpf(-560.0, 560.0, h01(seed_v, tries, 200 + spec[2])))
			var t := _texel(p)
			if elig[t] < 0.85:
				continue
			if kind == "gully" and (base_h[t] < 8.0 or rd(p) < 45.0):
				continue
			var r: float
			var hgt_m: float
			var length := 0.0
			var dir := Vector2.RIGHT.rotated(h01(seed_v, tries, 300) * TAU)
			match kind:
				"hummock":
					r = lerpf(7.0, 15.0, h01(seed_v, tries, 301))
					hgt_m = lerpf(0.9, 2.5, pow(h01(seed_v, tries, 302), 0.8))
					hgt_m = minf(hgt_m, r * 0.2)
				"ridge":
					r = lerpf(7.5, 12.0, h01(seed_v, tries, 303))
					length = lerpf(30.0, 68.0, h01(seed_v, tries, 304))
					hgt_m = lerpf(1.4, 3.0, h01(seed_v, tries, 305))
					hgt_m = minf(hgt_m, r * 0.26)
				_:
					r = lerpf(3.5, 5.5, h01(seed_v, tries, 306))
					length = lerpf(24.0, 48.0, h01(seed_v, tries, 307))
					hgt_m = -lerpf(0.6, 1.3, h01(seed_v, tries, 308))
			var reach := r * 2.4 + length * 0.5
			var ok := true
			for lf in landforms:
				if p.distance_to(lf.center) < (reach + float(lf.reach)) * 0.55:
					ok = false
					break
			if not ok:
				continue
			# The whole footprint must be editable ground.
			for k in 8:
				var q := p + Vector2.RIGHT.rotated(TAU * k / 8.0) * reach * 0.8
				if _elig_at(q) < 0.25:
					ok = false
					break
			if not ok:
				continue
			landforms.append({"id": landforms.size(), "kind": kind, "center": p, "radius": r, "height": hgt_m, "length": length, "dir": dir, "reach": reach})
			placed += 1


func _landform_value(lf: Dictionary, p: Vector2) -> float:
	var d := p - (lf.center as Vector2)
	var r: float = lf.radius
	match str(lf.kind):
		"hummock":
			return float(lf.height) * exp(-d.length_squared() / (r * r))
		_:
			var dir: Vector2 = lf.dir
			var along := d.dot(dir)
			var perp := d.dot(Vector2(-dir.y, dir.x))
			var half: float = float(lf.length) * 0.5
			var taper := 1.0 - sm(half * 0.55, half + r, absf(along))
			if str(lf.kind) == "gully":
				# Flat-bottomed shallow channel.
				return float(lf.height) * taper * (1.0 - sm(r * 0.35, r * 1.4, absf(perp)))
			return float(lf.height) * taper * exp(-perp * perp / (r * r))


func _apply_landforms() -> void:
	delta.resize(W * H)
	delta.fill(0.0)
	for lf in landforms:
		var reach: float = lf.reach
		var c: Vector2 = lf.center
		var i0 := maxi(int((c.x - reach - org.x) / cs), 0)
		var i1 := mini(int((c.x + reach - org.x) / cs) + 1, W - 1)
		var j0 := maxi(int((c.y - reach - org.y) / cs), 0)
		var j1 := mini(int((c.y + reach - org.y) / cs) + 1, H - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var idx := j * W + i
				if elig[idx] <= 0.0:
					continue
				delta[idx] += _landform_value(lf, org + Vector2(i * cs, j * cs)) * elig[idx]
	for idx in W * H:
		delta[idx] = snappedf(delta[idx], 0.001)
		height[idx] = base_h[idx] + delta[idx]


# ========================================================== 2. rocks/cover

func _base_rocks() -> void:
	var b: Dictionary = wd.rocks
	rocks = {
		"x": (b.x as PackedFloat32Array).duplicate(), "z": (b.z as PackedFloat32Array).duplicate(),
		"y": (b.y as PackedFloat32Array).duplicate(), "scale": (b.scale as PackedFloat32Array).duplicate(),
		"rot": (b.rot as PackedFloat32Array).duplicate(), "kind": (b.kind as PackedByteArray).duplicate(),
		"seed": (b.seed as PackedInt32Array).duplicate(),
	}
	var n: int = (rocks.x as PackedFloat32Array).size()
	var squash := PackedFloat32Array()
	var stretch := PackedFloat32Array()
	var formation := PackedInt32Array()
	for i in n:
		squash.append([0.75, 0.85, 0.55, 0.6][int(rocks.kind[i])])
		stretch.append(1.0)
		formation.append(-1)
	rocks["squash"] = squash
	rocks["stretch"] = stretch
	rocks["formation"] = formation
	for i in n:
		_hash_rock(i)


func _hash_rock(i: int) -> void:
	var k := Vector2i(int(floor(float(rocks.x[i]) / 8.0)), int(floor(float(rocks.z[i]) / 8.0)))
	if not _rock_hash.has(k):
		_rock_hash[k] = []
	(_rock_hash[k] as Array).append(i)


## Distance from p to the nearest rock footprint edge (negative = inside).
func rock_clear(p: Vector2, search := 2) -> float:
	var k := Vector2i(int(floor(p.x / 8.0)), int(floor(p.y / 8.0)))
	var best := 1e6
	for dz in range(-search, search + 1):
		for dx in range(-search, search + 1):
			for i in _rock_hash.get(k + Vector2i(dx, dz), []):
				var c := Vector2(rocks.x[i], rocks.z[i])
				best = minf(best, p.distance_to(c) - rock_bound(int(rocks.seed[i]), float(rocks.scale[i]), float(rocks.stretch[i])))
	return best


func _add_rock(p: Vector2, s: float, kind: int, rot: float, sd: int, squash: float, stretch: float, formation_id: int) -> int:
	rocks.x.append(snappedf(p.x, 0.001))
	rocks.z.append(snappedf(p.y, 0.001))
	rocks.y.append(snappedf(hgt(p.x, p.y), 0.001))
	rocks.scale.append(snappedf(s, 0.001))
	rocks.rot.append(snappedf(rot, 0.0001))
	rocks.kind.append(kind)
	rocks.seed.append(sd)
	rocks.squash.append(snappedf(squash, 0.001))
	rocks.stretch.append(snappedf(stretch, 0.001))
	rocks.formation.append(formation_id)
	var i: int = (rocks.x as PackedFloat32Array).size() - 1
	_hash_rock(i)
	return i


## Ground under a whole footprint: land, gentle, clear of everything that
## must keep its ground. Returns "" when valid, else the rejection reason.
func _site_reason(p: Vector2, radius: float, max_grade := 0.36) -> String:
	if not Rect2(-850, -620, 1700, 1240).has_point(p):
		return "bounds"
	if camp_sd(p) < radius + 14.0:
		return "camp"
	if td(p) < radius + 5.0:
		return "trail"
	if rd(p) < radius + 7.0:
		return "river"
	if pond_d(p) < radius + 8.0:
		return "pond"
	if bridge_d(p) < radius + 16.0:
		return "bridge"
	if cam_d(p) < radius + 6.0:
		return "camera"
	var lo := 1e9
	var hi := -1e9
	for k in 9:
		var q := p if k == 8 else p + Vector2.RIGHT.rotated(TAU * k / 8.0) * radius
		var hq := hgt(q.x, q.y)
		if hq < 2.6 or water(q) or sand(q) > 0.35:
			return "shore"
		lo = minf(lo, hq)
		hi = maxf(hi, hq)
	if (hi - lo) / maxf(radius * 2.0, 1.0) > max_grade or slope(p) > 0.4:
		return "slope"
	if rock_clear(p, 2) < radius * 0.6:
		return "rock"
	for f in formations:
		if p.distance_to(f.center) < radius + float(f.radius) + 7.0:
			return "formation_spacing"
	return ""


func _work_cells() -> Array:
	# Ground where people work or travel: tree-capable land plus trail
	# corridors (dusk return paths).
	var cells: Array = []
	var y := -620.0
	while y <= 620.0:
		var x := -850.0
		while x <= 850.0:
			var p := Vector2(x, y)
			x += WORK_CELL
			var h0 := hgt(p.x, p.y)
			if h0 < 1.7 or water(p) or camp_sd(p) < 0.0:
				continue
			if td(p) > 8.0 and (sand(p) > 0.4 or slope(p) > 0.6 or rd(p) < 2.0):
				continue
			cells.append(p)
		y += WORK_CELL
	return cells


func _place_hides() -> void:
	var cells := _work_cells()
	var dist := PackedFloat32Array()
	dist.resize(cells.size())
	# Existing hiding places (camp buildings, utility building, dock) cover
	# the camp/dock ground already.
	var camp_c := cfg.camp_center
	for k in cells.size():
		dist[k] = maxf((cells[k] as Vector2).distance_to(camp_c) - 30.0, 0.0)
	var attempt := 0
	while hides.size() < MAX_HIDES:
		var worst := -1
		var wv := 0.0
		for k in cells.size():
			if dist[k] > wv:
				wv = dist[k]
				worst = k
		if worst < 0 or wv <= HIDE_TARGET:
			break
		attempt += 1
		var site := _find_site(cells[worst], 30.0, 4.6, attempt * 977, 0.13)
		if site == Vector2.INF:
			dist[worst] = 0.0       # nowhere valid nearby; documented in stats
			rejections["hide_site_unavailable"] = int(rejections.get("hide_site_unavailable", 0)) + 1
			continue
		var kind := "rock_recess" if h01(seed_v, attempt, 900) < 0.6 else "rock_gap"
		if not _build_hide(site, kind, attempt):
			_bump("hide_geometry")
			dist[worst] = minf(dist[worst], HIDE_TARGET)   # try the next gap
			continue
		for k in cells.size():
			dist[k] = minf(dist[k], (cells[k] as Vector2).distance_to(site))
	stats["hide_max_gap_m"] = snappedf(_max_of(dist), 0.1)


func _max_of(arr: PackedFloat32Array) -> float:
	var m := 0.0
	for v in arr:
		m = maxf(m, v)
	return m


func _bump(reason: String) -> void:
	rejections[reason] = int(rejections.get(reason, 0)) + 1


func _find_site(around: Vector2, search: float, radius: float, salt: int, max_grade := 0.36) -> Vector2:
	# Deterministic ring search; prefers geologically plausible ground (a
	# little higher / steeper than surroundings, near existing rock).
	var best := Vector2.INF
	var bscore := -1e9
	for k in 40:
		var a := h01(seed_v, salt, k * 2) * TAU
		var r := sqrt(h01(seed_v, salt, k * 2 + 1)) * search
		var p := around + Vector2.RIGHT.rotated(a) * r
		var why := _site_reason(p, radius, max_grade)
		if why != "":
			continue
		var score := hgt(p.x, p.y) * 0.02 + slope(p) * 2.0 - r * 0.02 - maxf(rock_clear(p, 3), 0.0) * 0.01
		if score > bscore:
			bscore = score
			best = p
	return best


func _build_hide(p: Vector2, kind: String, salt: int) -> bool:
	# Opening faces the gentlest downhill/side direction that has a clear exit.
	var fid := formations.size()
	var best_dir := Vector2.ZERO
	var best_s := 1e9
	for k in 8:
		var o := Vector2.RIGHT.rotated(TAU * k / 8.0 + h01(seed_v, salt, 3) * 0.3)
		var e := p + o * 1.6
		var s := absf(hgt(e.x, e.y) - hgt(p.x, p.y)) + h01(seed_v, salt, 10 + k) * 0.2
		if kind == "rock_gap":
			var e2 := p - o * 1.6
			s += absf(hgt(e2.x, e2.y) - hgt(p.x, p.y))
		if s < best_s:
			best_s = s
			best_dir = o
	var o := best_dir
	var perp := Vector2(-o.y, o.x)
	var rp := 0.55
	var specs: Array = []     # [pos, s, squash, seed]
	if kind == "rock_recess":
		var sdB := int(IslandGenerator.hash_u32(seed_v, salt, 21) & 0xFFFF)
		var sB := lerpf(3.0, 3.5, h01(seed_v, salt, 22))
		var rB := rock_bound(sdB, sB, 1.0)
		specs.append([p - o * (rp + rB * 0.92), sB, 0.95, sdB])
		for side in [-1.0, 1.0]:
			var sdS := int(IslandGenerator.hash_u32(seed_v, salt, 30 + int(side)) & 0xFFFF)
			var sS := lerpf(2.4, 2.9, h01(seed_v, salt, 32 + int(side)))
			var rS := rock_bound(sdS, sS, 1.0)
			specs.append([p + perp * side * (rp + rS * 0.92) - o * 0.35, sS, 0.9, sdS])
	else:
		for side in [-1.0, 1.0]:
			var sd := int(IslandGenerator.hash_u32(seed_v, salt, 40 + int(side)) & 0xFFFF)
			var s := lerpf(3.0, 3.6, h01(seed_v, salt, 42 + int(side)))
			var r := rock_bound(sd, s, 1.0)
			specs.append([p + perp * side * (rp + r * 0.92), s, 0.92, sd])
	# Exits must be free ground beside no rock.
	var exits: Array = [p + o * (rp + 1.0)]
	if kind == "rock_gap":
		exits.append(p - o * (rp + 1.0))
	for e in exits:
		if water(e) or slope(e) > 0.45 or rock_clear(e, 2) < 0.5 or absf(hgt(e.x, e.y) - hgt(p.x, p.y)) > 0.6:
			return false
		for sp in specs:
			if (e as Vector2).distance_to(sp[0]) < rock_bound(int(sp[3]), float(sp[1]), 1.0) + 0.45:
				return false
	var ids: Array = []
	for sp in specs:
		ids.append(_add_rock(sp[0], sp[1], RockKind.HIDE_STONE, h01(seed_v, salt, 60 + ids.size()) * TAU, sp[3], sp[2], 1.0, fid))
	var radius := 0.0
	for sp in specs:
		radius = maxf(radius, p.distance_to(sp[0]) + rock_bound(int(sp[3]), float(sp[1]), 1.0))
	formations.append({"id": fid, "kind": kind, "center": p, "radius": radius, "rocks": ids, "class": "hard"})
	var hide := {
		"id": hides.size(), "formation": fid, "kind": kind, "pos": p, "facing": o,
		"exits": exits, "approach": p + o * (rp + 1.8), "eye_h": 0.75,
		"dead_end": kind == "rock_recess",
	}
	if kind == "rock_gap":
		hide["approach_b"] = p - o * (rp + 1.8)
	hides.append(hide)
	return true


func _place_cover() -> void:
	var cells := _work_cells()
	var breaks: Array = []
	for i in (rocks.x as PackedFloat32Array).size():
		var vis := 0.7 * float(rocks.scale[i]) * float(rocks.squash[i])
		if vis >= 1.25:
			breaks.append(Vector2(rocks.x[i], rocks.z[i]))
	for lf in landforms:
		if float(lf.height) >= 2.0:
			breaks.append(lf.center)
	var dist := PackedFloat32Array()
	dist.resize(cells.size())
	var bh := {}
	for b in breaks:
		var k := Vector2i(int(floor(b.x / 64.0)), int(floor(b.y / 64.0)))
		if not bh.has(k):
			bh[k] = []
		(bh[k] as Array).append(b)
	for k in cells.size():
		var c: Vector2 = cells[k]
		var best := maxf(c.distance_to(cfg.camp_center) - 30.0, 0.0)
		var kk := Vector2i(int(floor(c.x / 64.0)), int(floor(c.y / 64.0)))
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				for b in bh.get(kk + Vector2i(dx, dz), []):
					best = minf(best, c.distance_to(b))
		dist[k] = minf(best, 200.0)
	stats["hard_cover_gap_before_m"] = snappedf(_max_of(dist), 0.1)
	var attempt := 0
	while formations.size() < MAX_FORMATIONS:
		var worst := -1
		var wv := 0.0
		for k in cells.size():
			if dist[k] > wv:
				wv = dist[k]
				worst = k
		if worst < 0 or wv <= HARD_BREAK_TARGET:
			break
		attempt += 1
		var shelf := false
		for lf in landforms:
			if str(lf.kind) == "ridge" and (cells[worst] as Vector2).distance_to(lf.center) < float(lf.length) * 0.5 + 18.0:
				shelf = true
				break
		if not shelf and h01(seed_v, attempt, 700) < 0.22:
			shelf = true
		var radius := 5.0 if shelf else 3.6
		var site := _find_site(cells[worst], 22.0, radius, 50000 + attempt * 131)
		if site == Vector2.INF:
			dist[worst] = HARD_BREAK_TARGET
			_bump("cover_site_unavailable")
			continue
		if shelf:
			_build_shelf(site, attempt)
		else:
			_build_cluster(site, attempt)
		for k in cells.size():
			dist[k] = minf(dist[k], (cells[k] as Vector2).distance_to(site))
	for h in hides:
		breaks.append(h.pos)
	stats["hard_cover_gap_after_m"] = snappedf(_max_of(dist), 0.1)
	stats["work_cells"] = cells.size()


func _build_cluster(p: Vector2, salt: int) -> void:
	var fid := formations.size()
	var n := 3 + int(h01(seed_v, salt, 1) * 2.999)
	var ids: Array = []
	var radius := 0.0
	for k in n:
		var sd := int(IslandGenerator.hash_u32(seed_v, salt, 100 + k) & 0xFFFF)
		var s := lerpf(2.4, 3.4, h01(seed_v, salt, 120 + k)) if k == 0 else lerpf(1.2, 2.3, h01(seed_v, salt, 140 + k))
		var q := p
		if k > 0:
			var placed := false
			for t in 6:
				var a := h01(seed_v, salt, 160 + k * 7 + t) * TAU
				var r := lerpf(1.6, 3.4, h01(seed_v, salt, 180 + k * 7 + t))
				var cand := p + Vector2.RIGHT.rotated(a) * r
				if water(cand) or slope(cand) > 0.45:
					continue
				var overl := false
				for i in ids:
					var ci := Vector2(rocks.x[i], rocks.z[i])
					# Members may touch (a cluster), not fully interpenetrate.
					if cand.distance_to(ci) < (rock_bound(sd, s, 1.0) + rock_bound(int(rocks.seed[i]), float(rocks.scale[i]), 1.0)) * 0.55:
						overl = true
				if not overl:
					q = cand
					placed = true
					break
			if not placed:
				continue
		ids.append(_add_rock(q, s, RockKind.CLUSTER, h01(seed_v, salt, 200 + k) * TAU, sd, lerpf(0.72, 0.95, h01(seed_v, salt, 220 + k)), 1.0, fid))
		radius = maxf(radius, p.distance_to(q) + rock_bound(sd, s, 1.0))
	formations.append({"id": fid, "kind": "boulder_cluster", "center": p, "radius": radius, "rocks": ids, "class": "hard"})


func _build_shelf(p: Vector2, salt: int) -> void:
	var fid := formations.size()
	var ids: Array = []
	var sd := int(IslandGenerator.hash_u32(seed_v, salt, 300) & 0xFFFF)
	var s := lerpf(4.6, 6.6, h01(seed_v, salt, 301))
	var stretch := lerpf(1.35, 1.7, h01(seed_v, salt, 302))
	var rot := h01(seed_v, salt, 303) * TAU
	ids.append(_add_rock(p, s, RockKind.SHELF, rot, sd, lerpf(0.34, 0.42, h01(seed_v, salt, 304)), stretch, fid))
	var radius := rock_bound(sd, s, stretch)
	# One or two loose boulders at the shelf's foot.
	var extra := 1 + int(h01(seed_v, salt, 305) * 1.999)
	for k in extra:
		var a := rot + PI * 0.5 + (k * PI) + (h01(seed_v, salt, 306 + k) - 0.5)
		var sd2 := int(IslandGenerator.hash_u32(seed_v, salt, 320 + k) & 0xFFFF)
		var s2 := lerpf(1.3, 2.2, h01(seed_v, salt, 330 + k))
		var q := p + Vector2.RIGHT.rotated(a) * (radius * 0.75 + rock_bound(sd2, s2, 1.0) * 0.6)
		if water(q) or slope(q) > 0.45:
			continue
		ids.append(_add_rock(q, s2, RockKind.CLUSTER, h01(seed_v, salt, 340 + k) * TAU, sd2, 0.8, 1.0, fid))
		radius = maxf(radius, p.distance_to(q) + rock_bound(sd2, s2, 1.0))
	formations.append({"id": fid, "kind": "rock_shelf", "center": p, "radius": radius, "rocks": ids, "class": "hard"})


# ============================================================ 3. trees

## Cheap static validity for a tree candidate ("" = valid).
func _tree_reason(p: Vector2) -> String:
	var h0 := hgt(p.x, p.y)
	if h0 < 1.7 or water(p):
		return "water"
	if sand(p) * (1.0 - sm(2.5, 6.5, h0)) > 0.3:
		return "beach"
	if rd(p) < 3.0:
		return "river"
	if pond_d(p) < 3.0:
		return "pond"
	if camp_sd(p) < cfg.camp_tree_clearance:
		return "camp"
	if td(p) < 2.5:
		return "trail"
	if bridge_d(p) < 6.0:
		return "bridge"
	if cam_d(p) < 4.0:
		return "camera"
	if slope(p) > 0.55:
		return "slope"
	if rock_clear(p, 1) < 0.9:
		return "rock"
	for h in hides:
		for e in h.exits:
			if p.distance_to(e) < 1.6:
				return "hide_exit"
		if p.distance_to(h.approach) < 1.4:
			return "hide_exit"
	return ""


func _intensity(p: Vector2, region_w: float, groves: Array) -> float:
	# Strong contrast: dense groves and copses, thinner woodland between,
	# open glades and meadows. A fixed 10,000 trees then read as dense
	# woods where they stand instead of evenly spaced parkland.
	var v := sm(-0.2, 0.45, _n_cluster.get_noise_2d(p.x, p.y))
	var g := 0.0
	for gr in groves:
		var d := p.distance_to(gr[0])
		if d < float(gr[1]) * 2.0:
			g = maxf(g, exp(-d * d / (float(gr[1]) * float(gr[1]))))
	v = pow(clampf(v * 0.6 + g * 0.9, 0.0, 1.5), 1.8)
	var gap := _n_gap.get_noise_2d(p.x, p.y)
	if gap < -0.22:
		v *= 0.04                     # glades and meadows
	elif gap < -0.1:
		v *= 0.35                     # thin edges around them
	var h0 := hgt(p.x, p.y)
	v *= sm(1.7, 4.5, h0)
	v *= 1.0 - 0.45 * sm(0.3, 0.55, slope(p))
	return clampf(v * region_w, 0.0, 2.5)


func _region_of(p: Vector2) -> int:
	var best := 0
	var bd := 1e18
	for r in REGIONS.size():
		var d := p.distance_squared_to(REGIONS[r][1])
		if d < bd:
			bd = d
			best = r
	return best


func _approach_points(p: Vector2, trunk_r: float) -> Array:
	var out: Array = []
	for k in 8:
		# PlacementValidator.STAND_DISTANCE (0.85 m): the same stands the game and audit use.
		out.append(p + Vector2.RIGHT.rotated(TAU * k / 8.0) * (trunk_r + 0.85))
	return out


## Mirrors CrewNav's island grid (3 m cells, rocks marked solid on an
## inflated disc, steep cells solid) so no tree is accepted whose cutting
## stands the crew's navigation cannot use.
func _nav_solid_build() -> void:
	var lo := Vector2(INF, INF)
	for j in range(0, H, 4):
		for i in range(0, W, 4):
			if height[j * W + i] > cfg.sea_level:
				var p := org + Vector2(i, j) * cs
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
	_nav_origin = lo - Vector2(12, 12)
	for r in (rocks.x as PackedFloat32Array).size():
		var rad := float(rocks.scale[r]) * 0.45 * maxf(float(rocks.stretch[r]), 1.0)
		if rad <= 0.9:
			continue
		var rp := Vector2(rocks.x[r], rocks.z[r])
		var a := _nav_cell(rp - Vector2(rad, rad))
		var b := _nav_cell(rp + Vector2(rad, rad))
		for j in range(a.y, b.y + 1):
			for i in range(a.x, b.x + 1):
				var k := Vector2i(i, j)
				if (_nav_origin + (Vector2(k) + Vector2(0.5, 0.5)) * 3.0).distance_to(rp) <= rad + 1.5:
					_nav_solid[k] = true


## Cells connected to the camp's north gate on the mirrored grid (bridges
## walkable), so every accepted tree's stand and retreat are reachable.
func _nav_component() -> void:
	var bridge_cells := {}
	for br in wd.bridges():
		var across := Vector2(float(br.ax), float(br.az)).normalized()
		var c := Vector2(float(br.x), float(br.z))
		var half := float(br.half_span) + 7.0
		var d := -half
		while d <= half:
			bridge_cells[_nav_cell(c + across * d)] = true
			d += 1.0
	var start := _nav_cell(cfg.camp_center + Vector2(0, -(18.5 + 3.5)))
	_nav_comp = {start: true}
	var q: Array[Vector2i] = [start]
	var head := 0
	var passable := func(k: Vector2i) -> bool:
		if bridge_cells.has(k):
			return true
		var cc := _nav_origin + (Vector2(k) + Vector2(0.5, 0.5)) * 3.0
		if not Rect2(-1000, -800, 2000, 1600).has_point(cc):
			return false
		var h0 := hgt(cc.x, cc.y)
		if h0 < cfg.sea_level + 0.15:
			return false
		var t := _texel(cc)
		if int(wd.water_region[t]) != 0 and float(wd.water_surface[t]) - h0 > 0.55:
			return false
		return _nav_ok(cc, 0.72)
	while head < q.size():
		var k := q[head]
		head += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var nk: Vector2i = k + dd
			if _nav_comp.has(nk) or not passable.call(nk):
				continue
			if dd.x != 0 and dd.y != 0 and (not passable.call(Vector2i(k.x + dd.x, k.y)) or not passable.call(Vector2i(k.x, k.y + dd.y))):
				continue
			_nav_comp[nk] = true
			q.append(nk)
	stats["nav_component_cells"] = _nav_comp.size()


func _stand_reachable(a: Vector2) -> bool:
	var k := _nav_cell(a)
	if not _nav_comp.has(k):
		return false
	# A retreat cell 2-3 cells away must be reachable too (felling safety).
	for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3)]:
		if _nav_comp.has(k + d):
			return true
	return false


func _nav_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - _nav_origin.x) / 3.0)), int(floor((p.y - _nav_origin.y) / 3.0)))


func _nav_ok(p: Vector2, min_ny := 0.74) -> bool:
	var k := _nav_cell(p)
	if _nav_solid.has(k):
		return false
	var c := _nav_origin + (Vector2(k) + Vector2(0.5, 0.5)) * 3.0
	var dx := hgt(c.x + cs, c.y) - hgt(c.x - cs, c.y)
	var dz := hgt(c.x, c.y + cs) - hgt(c.x, c.y - cs)
	var ny := Vector3(-dx, 2.0 * cs, -dz).normalized().y
	return ny >= min_ny     # CrewNav.STEEP_NY 0.72 (stands: slightly stricter)


## Bitmask of usable work-approach directions for a trunk at p.
func _approach_mask(p: Vector2, trunk_r: float, ignore := -1) -> int:
	var base := hgt(p.x, p.y)
	var m := 0
	var pts := _approach_points(p, trunk_r)
	for k in 8:
		var a: Vector2 = pts[k]
		if water(a) or slope(a) > 0.6 or absf(hgt(a.x, a.y) - base) > 0.6 or rock_clear(a, 1) < 0.35 or not _nav_ok(a) or not _stand_reachable(a):
			continue
		if _trunk_near(a, 0.45, ignore):
			continue
		m |= 1 << k
	return m


func _trunk_near(a: Vector2, clear: float, ignore := -1) -> bool:
	var k := Vector2i(int(floor(a.x / 4.0)), int(floor(a.y / 4.0)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for t in _tree_hash.get(k + Vector2i(dx, dz), []):
				if t == ignore:
					continue
				var rec: Dictionary = _acc[t]
				if a.distance_to(rec.p) < float(rec.r) + clear:
					return true
	return false


static func _bits(m: int) -> int:
	var n := 0
	for k in 8:
		if m & (1 << k):
			n += 1
	return n


func _place_trees() -> void:
	# --- candidates (finite, jittered 2.1 m grid) ---------------------
	var step := 2.1
	var cand_p: Array = []
	var cand_reg := PackedInt32Array()
	var usable := PackedInt32Array()
	usable.resize(REGIONS.size())
	var gi := 0
	var z := -620.0
	while z < 620.0:
		var x := -840.0
		while x < 840.0:
			gi += 1
			var p := Vector2(x + (h01(seed_v, gi, 1) - 0.5) * step * 0.9, z + (h01(seed_v, gi, 2) - 0.5) * step * 0.9)
			x += step
			var why := _tree_reason(p)
			if why != "":
				_bump("tree_" + why)
				continue
			var r := _region_of(p)
			cand_p.append(p)
			cand_reg.append(r)
			usable[r] += 1
		z += step
	_cand_ref = cand_p
	# --- quotas: usable area x density weight, largest remainder ----------
	var weights := PackedFloat32Array()
	var wsum := 0.0
	for r in REGIONS.size():
		weights.append(float(usable[r]) * float(REGIONS[r][2]))
		wsum += weights[r]
	var quota := PackedInt32Array()
	quota.resize(REGIONS.size())
	var rema: Array = []
	var given := 0
	for r in REGIONS.size():
		var exact := TREE_TARGET * weights[r] / maxf(wsum, 1.0)
		quota[r] = int(floor(exact))
		given += quota[r]
		rema.append([exact - floor(exact), r])
	rema.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	for k in TREE_TARGET - given:
		quota[int(rema[k % rema.size()][1])] += 1
	# --- groves: deterministic centres per region -----------------------
	var groves_by_r: Array = []
	for r in REGIONS.size():
		var list: Array = []
		var want := int(float(usable[r]) * step * step / 2200.0)
		var t := 0
		while list.size() < want and t < want * 30 + 30:
			t += 1
			var c := cand_p[int(h01(seed_v, r * 7919 + t, 5) * (cand_p.size() - 1))] as Vector2
			if _region_of(c) != r:
				continue
			list.append([c, lerpf(12.0, 34.0, h01(seed_v, r * 7919 + t, 6))])
		groves_by_r.append(list)
	# --- weighted order per region (Efraimidis-Spirakis keys) -----------
	var order_by_r: Array = []
	for r in REGIONS.size():
		order_by_r.append([])
	for c in cand_p.size():
		var r := cand_reg[c]
		var inten := _intensity(cand_p[c], float(REGIONS[r][2]), groves_by_r[r])
		if inten < 0.015:
			_bump("tree_low_intensity")
			continue
		var key := pow(maxf(h01(seed_v, c, 9), 1e-9), 1.0 / inten)
		(order_by_r[r] as Array).append([key, c, inten])
	for r in REGIONS.size():
		(order_by_r[r] as Array).sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	# --- accept per region; deficits flow to regions with spare ground ----
	var placed := PackedInt32Array()
	placed.resize(REGIONS.size())
	var cursor := PackedInt32Array()
	cursor.resize(REGIONS.size())
	var deficit := 0
	for r in REGIONS.size():
		_fill_region(r, quota[r], order_by_r[r], cursor, placed, groves_by_r[r])
		deficit += quota[r] - placed[r]
	var spill_rounds := 0
	while deficit > 0 and spill_rounds < 20:
		spill_rounds += 1
		var moved := 0
		for r in REGIONS.size():
			if deficit <= 0:
				break
			var before := placed[r]
			_fill_region(r, placed[r] + deficit, order_by_r[r], cursor, placed, groves_by_r[r])
			var got := placed[r] - before
			deficit -= got
			moved += got
		if moved == 0:
			break
	stats["tree_spill_rounds"] = spill_rounds
	for r in REGIONS.size():
		regions_out.append({"id": r, "name": REGIONS[r][0], "seed": [REGIONS[r][1].x, REGIONS[r][1].y], "density_weight": REGIONS[r][2],
			"usable_m2": int(usable[r] * step * step), "quota": quota[r], "placed": placed[r], "groves": (groves_by_r[r] as Array).size()})
	if _acc.size() != TREE_TARGET:
		push_error("IslandR2: placed %d native trees, target %d. Fix placement rules; do not ship a short manifest." % [_acc.size(), TREE_TARGET])
	_write_tree_records()


func _fill_region(r: int, target: int, order: Array, cursor: PackedInt32Array, placed: PackedInt32Array, groves: Array) -> void:
	while placed[r] < target and cursor[r] < order.size():
		var item: Array = order[cursor[r]]
		cursor[r] += 1
		var p: Vector2 = Vector2(0, 0)
		p = _cand_cache_get(item[1])
		var rec := _make_tree(p, int(item[1]), r, groves)
		var why := _accept(rec)
		if why != "":
			_bump("tree_" + why)
			continue
		placed[r] += 1


var _cand_ref: Array = []
func _cand_cache_get(c: int) -> Vector2:
	return _cand_ref[c]


func _make_tree(p: Vector2, c: int, region: int, groves: Array) -> Dictionary:
	var hs := IslandGenerator.hash_u32(seed_v, int(p.x * 100.0), int(p.y * 100.0))
	var low_d := p.distance_to(Vector2(cfg.lowland.x, cfg.lowland.y))
	var wet := maxf(1.0 - sm(cfg.lowland.z * 0.3, cfg.lowland.z, low_d), exp(-pow(rd(p) / 30.0, 2.0)))
	var h0 := hgt(p.x, p.y)
	var sn := _n_species.get_noise_2d(p.x, p.y)
	var w_birch := 0.25 + 1.4 * wet + maxf(sn, 0.0) * 0.8
	var w_spruce := 0.45 + sm(10.0, 30.0, h0) * 0.9 + maxf(-sn, 0.0) * 0.9
	var w_pine := 0.9 + (1.0 - sm(4.0, 12.0, h0)) * 0.8 + sand(p) * 0.8 + sm(25.0, 45.0, h0) * 0.6
	var tot := w_birch + w_spruce + w_pine
	var r01 := h01(hs, 1, 1) * tot
	var sp := 0 if r01 < w_pine else (1 if r01 < w_pine + w_spruce else 2)
	# Cohort: grove cores grow veterans, edges and gaps young trees.
	var core := 0.0
	for gr in groves:
		var d := p.distance_to(gr[0])
		core = maxf(core, exp(-d * d / (float(gr[1]) * float(gr[1]) * 0.35)))
	var roll := h01(hs, 2, 2)
	var cohort := 1
	if roll < 0.12 + core * 0.35:
		cohort = 2
	elif roll > 0.72 - core * 0.3:
		cohort = 0
	var ranges := [
		[Vector2(9.0, 13.0), Vector2(14.0, 21.0), Vector2(20.0, 27.0)],
		[Vector2(8.0, 12.0), Vector2(12.0, 19.0), Vector2(18.0, 25.0)],
		[Vector2(7.0, 10.5), Vector2(10.0, 15.0), Vector2(14.0, 19.0)],
	]
	var hr: Vector2 = ranges[sp][cohort]
	var th := lerpf(hr.x, hr.y, pow(h01(hs, 3, 3), 0.85))
	var rad := th * (0.016 if sp == 2 else 0.019) * lerpf(0.85, 1.2, h01(hs, 4, 4)) * (1.15 if cohort == 2 else 1.0)
	var variant := int(h01(hs, 5, 5) * 2.999)
	# Low thick boughs: most veterans, some open-grown edge trees.
	if (cohort == 2 and h01(hs, 6, 6) < 0.6) or (cohort == 1 and core < 0.15 and h01(hs, 7, 7) < 0.3):
		variant = 3
	var lean_max := 5.0 if cohort == 0 else 3.0
	if sp == 1:
		lean_max = 2.0
	var lean_amt := deg_to_rad(lerpf(0.0, lean_max, h01(hs, 8, 8)))
	var lean_dir := h01(hs, 9, 9) * TAU
	var spacing: float = [2.1, 2.55, 3.3][cohort]
	return {"p": p, "c": c, "region": region, "sp": sp, "cohort": cohort, "h": th, "r": rad, "variant": variant,
		"lean": Vector2(cos(lean_dir), sin(lean_dir)) * lean_amt, "rot": h01(hs, 10, 10) * TAU, "seed": int(hs & 0x7FFFFFFF),
		"spacing": spacing, "grove_core": core}


func _accept(rec: Dictionary) -> String:
	var p: Vector2 = rec.p
	var k := Vector2i(int(floor(p.x / 4.0)), int(floor(p.y / 4.0)))
	var neigh: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for t in _tree_hash.get(k + Vector2i(dx, dz), []):
				var o: Dictionary = _acc[t]
				var need := maxf(float(rec.spacing), float(o.spacing)) * (0.85 if int(rec.cohort) == 0 or int(o.cohort) == 0 else 1.0)
				var d := p.distance_to(o.p)
				if d < need:
					return "spacing"
				if d < 4.2:
					neigh.append(t)
	# Support: flared footprint must sit on ground without a big step.
	var fr := float(rec.r) * 1.45
	var lo := 1e9
	var hi := -1e9
	for a in 8:
		var q := p + Vector2.RIGHT.rotated(TAU * a / 8.0) * fr
		var hq := hgt(q.x, q.y)
		lo = minf(lo, hq)
		hi = maxf(hi, hq)
	if hi - lo > 0.45 + fr * 0.6:
		return "support"
	var mask := _approach_mask(p, float(rec.r))
	if _bits(mask) < 2:
		return "approach"
	# A new trunk may not take the last approaches away from a neighbour.
	for t in neigh:
		var o: Dictionary = _acc[t]
		var om := int(o.approach)
		var pts := _approach_points(o.p, float(o.r))
		var nm := om
		for b in 8:
			if om & (1 << b) and (pts[b] as Vector2).distance_to(p) < float(rec.r) + 0.45:
				nm &= ~(1 << b)
		if _bits(nm) < 2:
			return "neighbor_approach"
	for t in neigh:
		var o: Dictionary = _acc[t]
		var pts := _approach_points(o.p, float(o.r))
		for b in 8:
			if int(o.approach) & (1 << b) and (pts[b] as Vector2).distance_to(p) < float(rec.r) + 0.45:
				o.approach = int(o.approach) & ~(1 << b)
	rec["approach"] = mask
	_acc.append(rec)
	if not _tree_hash.has(k):
		_tree_hash[k] = []
	(_tree_hash[k] as Array).append(_acc.size() - 1)
	return ""


func _write_tree_records() -> void:
	var vcs := cfg.vegetation_chunk_size
	var vcw := int(ceil((cfg.bounds_max.x - cfg.bounds_min.x) / vcs))
	var bmin := cfg.bounds_min
	for rec in _acc:
		var p: Vector2 = rec.p
		rec["chunk"] = int(floor((p.y - bmin.y) / vcs)) * vcw + int(floor((p.x - bmin.x) / vcs))
	var idx := range(_acc.size())
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ra: Dictionary = _acc[a]
		var rb: Dictionary = _acc[b]
		if int(ra.chunk) != int(rb.chunk):
			return int(ra.chunk) < int(rb.chunk)
		if ra.p.y != rb.p.y:
			return ra.p.y < rb.p.y
		return ra.p.x < rb.p.x)
	trees = {
		"id": PackedInt32Array(), "species": PackedByteArray(), "variant": PackedByteArray(), "chunk": PackedInt32Array(),
		"x": PackedFloat32Array(), "z": PackedFloat32Array(), "rot": PackedFloat32Array(), "height": PackedFloat32Array(),
		"radius": PackedFloat32Array(), "lean_x": PackedFloat32Array(), "lean_z": PackedFloat32Array(), "logs": PackedByteArray(),
		"seed": PackedInt32Array(), "cohort": PackedByteArray(), "region": PackedByteArray(), "approach": PackedByteArray(),
	}
	for n in idx.size():
		var rec: Dictionary = _acc[idx[n]]
		trees.id.append(n)
		trees.species.append(int(rec.sp))
		trees.variant.append(int(rec.variant))
		trees.chunk.append(int(rec.chunk))
		trees.x.append(snappedf(rec.p.x, 0.001))
		trees.z.append(snappedf(rec.p.y, 0.001))
		trees.rot.append(snappedf(float(rec.rot), 0.0001))
		trees.height.append(snappedf(float(rec.h), 0.01))
		trees.radius.append(snappedf(float(rec.r), 0.001))
		trees.lean_x.append(snappedf(rec.lean.x, 0.0001))
		trees.lean_z.append(snappedf(rec.lean.y, 0.0001))
		trees.logs.append(clampi(int(float(rec.h) / 4.5), 2, 5))
		trees.seed.append(int(rec.seed))
		trees.cohort.append(int(rec.cohort))
		trees.region.append(int(rec.region))
		trees.approach.append(int(rec.approach))


# ======================================================= 4. undergrowth

func _place_undergrowth() -> void:
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	var kind := PackedByteArray()
	var scl := PackedFloat32Array()
	var rot := PackedFloat32Array()
	var sdv := PackedInt32Array()
	var add := func(p: Vector2, k: int, s: float, sd: int) -> void:
		xs.append(snappedf(p.x, 0.001))
		zs.append(snappedf(p.y, 0.001))
		kind.append(k)
		scl.append(snappedf(s, 0.001))
		rot.append(snappedf(h01(sd, 1, 1) * TAU, 0.0001))
		sdv.append(sd & 0x7FFFFFFF)
	# Thickets first: persistent soft concealment (bramble + hazel).
	var want_thickets := 150
	var t := 0
	while thickets.size() < want_thickets and t < 9000:
		t += 1
		var p := Vector2(lerpf(-800.0, 800.0, h01(seed_v, t, 1001)), lerpf(-580.0, 580.0, h01(seed_v, t, 1002)))
		var why := _shrub_reason(p, 2.5)
		if why != "":
			continue
		var shade := _tree_density(p, 10.0)
		if shade > 0.9 or _n_shrub.get_noise_2d(p.x, p.y) < -0.1:
			continue
		var ok := true
		for th in thickets:
			if p.distance_to(th.center) < 34.0:
				ok = false
				break
		if not ok:
			continue
		var r := lerpf(3.0, 6.5, h01(seed_v, t, 1003))
		var members := 0
		for m in int(r * r * 0.9):
			var a := h01(seed_v, t * 131 + m, 1) * TAU
			var rr := sqrt(h01(seed_v, t * 131 + m, 2)) * r
			var q := p + Vector2.RIGHT.rotated(a) * rr
			if _shrub_reason(q, 1.2) != "":
				continue
			var k := Shrub.BRAMBLE if h01(seed_v, t * 131 + m, 3) < 0.55 else Shrub.HAZEL
			add.call(q, k, lerpf(0.8, 1.25, h01(seed_v, t * 131 + m, 4)), int(IslandGenerator.hash_u32(seed_v, t * 131 + m, 5)))
			members += 1
		if members >= 6:
			thickets.append({"id": thickets.size(), "center": p, "radius": r, "members": members})
	# Scattered undergrowth by habitat on a jittered grid.
	var step := 2.6
	var gi := 0
	var z := -600.0
	while z < 600.0:
		var x := -830.0
		while x < 830.0:
			gi += 1
			var p := Vector2(x + (h01(seed_v, gi, 21) - 0.5) * step, z + (h01(seed_v, gi, 22) - 0.5) * step)
			x += step
			var roll := h01(seed_v, gi, 23)
			if roll > 0.42:
				continue
			if _shrub_reason(p, 0.9) != "":
				continue
			var h0 := hgt(p.x, p.y)
			var shade := _tree_density(p, 8.0)
			var damp := maxf(exp(-pow(rd(p) / 18.0, 2.0)), exp(-pow(maxf(pond_d(p), 0.0) / 14.0, 2.0)))
			damp = maxf(damp, 1.0 - sm(cfg.lowland.z * 0.35, cfg.lowland.z, p.distance_to(Vector2(cfg.lowland.x, cfg.lowland.y))))
			var clump := sm(-0.25, 0.45, _n_shrub.get_noise_2d(p.x, p.y))
			var edge := shade * (1.0 - shade) * 4.0      # forest edges are shrubby
			# Habitat weights per family; one weighted pick per grid point.
			var wts := [
				edge * 0.55 + (1.0 - shade) * 0.08,                 # hazel
				sm(10.0, 26.0, h0) * (1.0 - shade) * 0.7,           # juniper (dry, open, higher)
				edge * 0.45 + (1.0 - shade) * 0.18,                 # bramble
				shade * 0.75 + damp * 0.35,                         # bracken
				damp * 0.9,                                         # sedge
				shade * 0.22,                                       # deadfall
			]
			var wtot := 0.0
			for wv in wts:
				wtot += float(wv)
			if wtot <= 0.0:
				continue
			var pickr := h01(seed_v, gi, 24) * wtot
			var pick := 0
			while pick < 5 and pickr > float(wts[pick]):
				pickr -= float(wts[pick])
				pick += 1
			var w := clampf(wtot, 0.0, 1.2) * (0.45 + clump * 0.75)
			if roll > 0.42 * w:
				continue
			# Tall woody shrubs keep off trails; nothing tall at camera lenses.
			if pick in [Shrub.HAZEL, Shrub.JUNIPER] and (td(p) < 3.5 or cam_d(p) < 7.0):
				continue
			add.call(p, pick, lerpf(0.75, 1.3, h01(seed_v, gi, 25)), int(IslandGenerator.hash_u32(seed_v, gi, 26)))
		z += step
	shrubs = {"x": xs, "z": zs, "kind": kind, "scale": scl, "rot": rot, "seed": sdv}


## "" when an undergrowth plant may stand at p (keeps every native trunk's
## cut zone, hide pockets/exits, trails, camp and water clear).
func _shrub_reason(p: Vector2, clear: float) -> String:
	var h0 := hgt(p.x, p.y)
	if h0 < 1.4 or water(p):
		return "water"
	if sand(p) > 0.45:
		return "beach"
	if camp_sd(p) < 6.0:
		return "camp"
	if td(p) < 1.6 + clear * 0.5:
		return "trail"
	if bridge_d(p) < 5.0:
		return "bridge"
	if cam_d(p) < 3.0:
		return "camera"
	if rock_clear(p, 1) < 0.25:
		return "rock"
	if slope(p) > 0.75:
		return "slope"
	for h in hides:
		if p.distance_to(h.pos) < 1.4:
			return "hide"
		for e in h.exits:
			if p.distance_to(e) < 1.3:
				return "hide"
	if _trunk_near(p, 1.25):
		return "cut_zone"
	return ""


func _tree_density(p: Vector2, radius: float) -> float:
	var k := Vector2i(int(floor(p.x / 4.0)), int(floor(p.y / 4.0)))
	var n := 0.0
	var span := int(ceil(radius / 4.0))
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			for t in _tree_hash.get(k + Vector2i(dx, dz), []):
				var d := p.distance_to((_acc[t] as Dictionary).p)
				if d < radius:
					n += 1.0 - d / radius
	return clampf(n / 4.0, 0.0, 1.0)


# ============================================================ 5. masks

func _build_masks() -> void:
	masks = (wd.masks as PackedByteArray).duplicate()
	var fcs := 8.0
	var fw := int(ceil((cfg.bounds_max.x - org.x) / fcs)) + 1
	var fh := int(ceil((cfg.bounds_max.y - org.y) / fcs)) + 1
	var dens := PackedFloat32Array()
	dens.resize(fw * fh)
	for t in (trees.x as PackedFloat32Array).size():
		var fi := int((float(trees.x[t]) - org.x) / fcs)
		var fj := int((float(trees.z[t]) - org.y) / fcs)
		for dj in range(-2, 3):
			for di in range(-2, 3):
				var ii := clampi(fi + di, 0, fw - 1)
				var jj := clampi(fj + dj, 0, fh - 1)
				dens[jj * fw + ii] += 1.0 / (1.0 + float(di * di + dj * dj))
	for j in H:
		for i in W:
			var idx := j * W + i
			if base_h[idx] < 0.5:
				continue
			var fx := clampf(float(i) * cs / fcs - 0.5, 0.0, fw - 1.001)
			var fz := clampf(float(j) * cs / fcs - 0.5, 0.0, fh - 1.001)
			var ii := int(fx)
			var jj := int(fz)
			fx -= ii
			fz -= jj
			var fd := lerpf(lerpf(dens[jj * fw + ii], dens[jj * fw + ii + 1], fx), lerpf(dens[(jj + 1) * fw + ii], dens[(jj + 1) * fw + ii + 1], fx), fz)
			masks[idx * 4 + 1] = int(clampf(fd / 2.0, 0.0, 1.0) * 255.0)
			var dlt := delta[idx]
			if dlt > 1.4:
				masks[idx * 4 + 3] = maxi(masks[idx * 4 + 3], int(clampf((dlt - 1.4) * 0.35, 0.0, 0.45) * 255.0))
			elif dlt < -0.3:
				masks[idx * 4 + 2] = maxi(masks[idx * 4 + 2], int(clampf(-dlt * 0.35, 0.0, 0.4) * 255.0))
	# Exposed rock and gravel around formations.
	for f in formations:
		var c: Vector2 = f.center
		var r := float(f.radius) + 2.0
		var i0 := maxi(int((c.x - r - org.x) / cs), 0)
		var i1 := mini(int((c.x + r - org.x) / cs) + 1, W - 1)
		var j0 := maxi(int((c.y - r - org.y) / cs), 0)
		var j1 := mini(int((c.y + r - org.y) / cs) + 1, H - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var d := (org + Vector2(i * cs, j * cs)).distance_to(c)
				var v := (1.0 - sm(r * 0.45, r, d)) * 0.6
				var idx := (j * W + i) * 4 + 3
				masks[idx] = maxi(masks[idx], int(v * 255.0))


# ============================================================ stats/output

func _compute_stats(ms: int) -> void:
	stats["generation_ms"] = ms
	stats["tree_count"] = (trees.id as PackedInt32Array).size()
	var per_sp := {"pine": 0, "spruce": 0, "birch": 0}
	var per_co := {"young": 0, "mature": 0, "veteran": 0}
	var low_boughs := 0
	var hmin := 1e9
	var hmax := 0.0
	for i in stats.tree_count:
		per_sp[SPECIES[int(trees.species[i])]] += 1
		per_co[COHORTS[int(trees.cohort[i])]] += 1
		if int(trees.variant[i]) == 3:
			low_boughs += 1
		hmin = minf(hmin, float(trees.height[i]))
		hmax = maxf(hmax, float(trees.height[i]))
	stats["trees_per_species"] = per_sp
	stats["trees_per_cohort"] = per_co
	stats["trees_with_low_boughs"] = low_boughs
	stats["tree_height_range_m"] = [hmin, hmax]
	stats["regions"] = regions_out
	stats["rejections"] = rejections
	var lk := {}
	for lf in landforms:
		lk[lf.kind] = int(lk.get(lf.kind, 0)) + 1
	stats["landforms"] = lk
	var max_d := 0.0
	var max_slope := 0.0
	for idx in W * H:
		max_d = maxf(max_d, absf(delta[idx]))
	stats["max_landform_delta_m"] = snappedf(max_d, 0.01)
	var fk := {}
	for f in formations:
		fk[f.kind] = int(fk.get(f.kind, 0)) + 1
	stats["formations"] = fk
	stats["hides"] = hides.size()
	stats["thickets"] = thickets.size()
	stats["rocks_total"] = (rocks.x as PackedFloat32Array).size()
	stats["rocks_new"] = (rocks.x as PackedFloat32Array).size() - (wd.rocks.x as PackedFloat32Array).size()
	var sk := {}
	for k in (shrubs.kind as PackedByteArray):
		sk[SHRUB_NAMES[k]] = int(sk.get(SHRUB_NAMES[k], 0)) + 1
	stats["undergrowth"] = sk
	stats["undergrowth_total"] = (shrubs.x as PackedFloat32Array).size()
	stats["max_slope_unused"] = max_slope


func cover_json() -> Dictionary:
	var v2 := func(v: Vector2) -> Array: return [snappedf(v.x, 0.001), snappedf(v.y, 0.001)]
	var lfs: Array = []
	for lf in landforms:
		lfs.append({"id": lf.id, "kind": lf.kind, "center": v2.call(lf.center), "radius": snappedf(lf.radius, 0.01), "height": snappedf(lf.height, 0.01), "length": snappedf(lf.length, 0.01), "dir": v2.call(lf.dir)})
	var fms: Array = []
	for f in formations:
		fms.append({"id": f.id, "kind": f.kind, "class": f["class"], "center": v2.call(f.center), "radius": snappedf(f.radius, 0.01), "rocks": f.rocks})
	var hds: Array = []
	for h in hides:
		var ex: Array = []
		for e in h.exits:
			ex.append(v2.call(e))
		var d := {"id": h.id, "formation": h.formation, "kind": h.kind, "pos": v2.call(h.pos), "facing": v2.call(h.facing), "exits": ex, "approach": v2.call(h.approach), "eye_h": h.eye_h, "dead_end": h.dead_end}
		if h.has("approach_b"):
			d["approach_b"] = v2.call(h.approach_b)
		hds.append(d)
	var tks: Array = []
	for t in thickets:
		tks.append({"id": t.id, "center": v2.call(t.center), "radius": snappedf(t.radius, 0.01), "members": t.members})
	return {"revision": REVISION, "landforms": lfs, "formations": fms, "hides": hds, "thickets": tks, "regions": regions_out, "cameras": cameras.map(func(c: Dictionary) -> Array: return v2.call(c.pos))}


func files() -> Dictionary:
	return {
		"height_delta.bin": delta.to_byte_array(),
		"masks.bin": masks,
		"trees.bin": var_to_bytes(trees),
		"rocks.bin": var_to_bytes(rocks),
		"shrubs.bin": var_to_bytes(shrubs),
		"cover.json": JSON.stringify(cover_json(), "\t", false).to_utf8_buffer(),
	}


func content_hashes() -> Dictionary:
	var out := {}
	var f := files()
	for k in f:
		out[k] = IslandGenerator._md5(f[k])
	return out


func write_to(dir_path: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var f := files()
	var hashes := {}
	for fname in f:
		var bytes: PackedByteArray = f[fname]
		hashes[fname] = IslandGenerator._md5(bytes)
		var fa := FileAccess.open_compressed(dir_path.path_join(fname + ".zst"), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD) if fname.ends_with(".bin") else FileAccess.open(dir_path.path_join(fname), FileAccess.WRITE)
		fa.store_buffer(bytes)
		fa.close()
	var manifest := {
		"format": 1,
		"island_revision": "r2",
		"planner_revision": REVISION,
		"tree_target": TREE_TARGET,
		"base_world": {"generation_version": wd.manifest.get("generation_version"), "content_hashes": wd.manifest.get("content_hashes")},
		"content_hashes": hashes,
		"stats": stats,
	}
	var mf := FileAccess.open(dir_path.path_join("manifest.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest, "\t", false))
	mf.close()
	return manifest
