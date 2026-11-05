class_name SurvivalCover
extends Node
## Phase 19: more real places to hide during the five-night hunt, chosen
## from the frozen island data (deterministic; nothing is hand-placed in
## data/world). Every place is ordinary concealment, never immunity:
##
##   thicket     the densest persistent thickets (Phase 12 cover data):
##               crouched inside; concealment is GEOMETRIC (the Foreman's
##               ray through the brush uses the same soft-cover rule as
##               everywhere - and foliage never hides within 4 m). 2-3
##               real ways out through the brush.
##   shed        two small field work sheds in far logging areas, each with
##               a door and a back hatch (a real second way out); hiding
##               behind the bench is concealment by walls; the door creaks.
##   dock_store  the gear chest on the service dock: lying inside, lid
##               noise; the dock dog is never a target.
## Placement keeps hides sparse and varied (no "locker every 30 m", no
## rows of identical boxes) and validates clearance for the occupant
## pose (no clipping into trunks, rocks or walls). `audit()` reports hide
## and escape opportunity by region, travel routes and cleared land.

const THICKET_MIN_GAP := 70.0
const THICKET_MAX := 36
const SHED_SIZE := Vector3(3.4, 2.3, 2.8)

var hides: Array[HideSpot] = []
var sheds: Array[Node3D] = []
var rejected := {}           # reason -> count
var built := false


func build(root: Node3D) -> void:
	if built or World.island_revision != "r2" or Game.cover == null:
		return
	built = true
	var holder := Node3D.new()
	holder.name = "SurvivalCover"
	root.add_child(holder)
	_build_thickets(holder)
	_build_sheds(holder)


## Called once the dock exists (crew world ready).
func build_dock_store(root: Node3D) -> void:
	if Game.crew == null or root.find_child("DockGearChest", true, false) != null:
		return
	var shore := Game.crew.dock_shore
	var end := Game.crew.dock_end
	var along := Vector3(end.x - shore.x, 0, end.z - shore.z).normalized()
	var side := along.cross(Vector3.UP).normalized()
	# On the landing at the shore end of the dock (the deck itself is only
	# 2.2 m wide): try a few spots on dry, level ground beside the path.
	for k in [2.5, 4.0, 5.5]:
		for sx in [2.4, -2.4, 3.2, -3.2]:
			var p: Vector3 = shore - along * k + side * sx
			p.y = World.height_at(p.x, p.z)
			if p.y < World.sea_level + 0.4 or World.normal_at(p.x, p.z).y < 0.94 or _trunk_or_rock_near(p, 1.4):
				continue
			var spot := _make_chest(root, p, side if sx > 0.0 else -side)
			if spot and _clear(spot):
				return
			if spot:
				spot.marker.get_parent().queue_free()
				hides.erase(spot)
	rejected["dock_store"] = int(rejected.get("dock_store", 0)) + 1


# ------------------------------------------------------------- thickets

func _build_thickets(holder: Node3D) -> void:
	var tks: Array = World.cover.get("thickets", [])
	var cands := []
	for t in tks:
		var c := Vector3(float(t.center[0]), 0, float(t.center[1]))
		var dens: Vector2 = Game.cover.soft_at(c)
		if float(t.radius) < 3.0 or int(t.members) < 10 or dens.x < 0.8 or dens.y < 1.3:
			rejected["thicket_thin"] = int(rejected.get("thicket_thin", 0)) + 1
			continue
		if CampLayout.inside_fence(c) or c.distance_to(World.camp_origin()) < 45.0:
			rejected["thicket_camp"] = int(rejected.get("thicket_camp", 0)) + 1
			continue
		cands.append([dens.x * float(t.radius), t])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1].id) < int(b[1].id)))
	var placed: Array[Vector3] = []
	for cd in cands:
		if placed.size() >= THICKET_MAX:
			break
		var t: Dictionary = cd[1]
		var c := Vector3(float(t.center[0]), 0, float(t.center[1]))
		if placed.any(func(q: Vector3) -> bool: return Vector2(q.x - c.x, q.z - c.z).length() < THICKET_MIN_GAP):
			rejected["thicket_spacing"] = int(rejected.get("thicket_spacing", 0)) + 1
			continue
		var pos := _clear_spot_near(c, float(t.radius) * 0.5)
		if pos == Vector3.INF:
			rejected["thicket_clearance"] = int(rejected.get("thicket_clearance", 0)) + 1
			continue
		var exits := _thicket_exits(pos, float(t.radius))
		if exits.size() < 2:
			rejected["thicket_exits"] = int(rejected.get("thicket_exits", 0)) + 1
			continue
		var m := Marker3D.new()
		m.name = "Thicket_%d" % int(t.id)
		holder.add_child(m)
		m.global_position = pos
		var facing := (exits[0] - pos)
		facing.y = 0
		m.look_at(pos + facing.normalized(), Vector3.UP)
		var spot := HideSpot.make(m, "thicket", "")
		spot.configure_rock(pos, facing.normalized(), 0.85, exits, exits[0], false)
		spot.set_meta("thicket_id", int(t.id))
		hides.append(spot)
		placed.append(pos)


## A point near c with room for a crouched person (no trunk, no rock).
func _clear_spot_near(c: Vector3, r: float) -> Vector3:
	for k in 9:
		var p := c
		if k > 0:
			var a := TAU * k / 8.0
			p = c + Vector3(cos(a), 0, sin(a)) * minf(r, 1.6)
		p.y = World.height_at(p.x, p.z)
		if p.y < World.sea_level + 0.8:
			continue
		if _trunk_or_rock_near(p, 0.75):
			continue
		return p
	return Vector3.INF


func _trunk_or_rock_near(p: Vector3, r: float) -> bool:
	var off: OffshoreSurvey = Game.offshore
	if off:
		off._ensure_tree_grid()
		var cell := Vector2i(int(floor(p.x / 16.0)), int(floor(p.z / 16.0)))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for i in (off._tree_grid.get(cell + Vector2i(dx, dz), PackedInt32Array()) as PackedInt32Array):
					if not World.is_native(int(World.trees.id[i])):
						continue
					if Vector2(World.trees.x[i] - p.x, World.trees.z[i] - p.z).length() < r + float(World.trees.radius[i]):
						return true
	var rx: PackedFloat32Array = World.rocks.x
	for i in rx.size():
		if Vector2(World.rocks.x[i] - p.x, World.rocks.z[i] - p.z).length() < r + World.rock_radius(i):
			return true
	return false


## Ways out through the brush: points just outside the thicket edge in
## spread directions, on walkable ground, clear of trunks and rocks.
func _thicket_exits(pos: Vector3, radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var nav := Game.crew.nav if Game.crew else null
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var e := pos + Vector3(cos(a), 0, sin(a)) * (radius + 1.2)
		e.y = World.height_at(e.x, e.z)
		if e.y < World.sea_level + 0.5 or _trunk_or_rock_near(e, 0.5):
			continue
		if nav and not nav.walkable(e):
			continue
		if out.any(func(q: Vector3) -> bool: return q.distance_to(e) < radius):
			continue
		out.append(e)
		if out.size() >= 3:
			break
	return out


# ---------------------------------------------------------------- sheds

## Two far sites: flat walkable ground with no trees or rocks in the
## footprint, far from camp, preferably beside a trail.
func shed_sites() -> Array[Vector3]:
	var camp := World.camp_origin()
	var cands := []
	var x := -700.0
	while x <= 700.0:
		var z := -520.0
		while z <= 520.0:
			var p := Vector3(x, World.height_at(x, z), z)
			z += 20.0
			if p.y < 2.5 or p.distance_to(camp) < 330.0:
				continue
			if World.normal_at(p.x, p.z).y < 0.975:
				continue
			if _trunk_or_rock_near(p, 4.5):
				continue
			if Game.crew and Game.crew.nav and not Game.crew.nav.walkable(p + Vector3(0, 0, -SHED_SIZE.z * 0.5 - 1.4)):
				continue
			cands.append([p.distance_to(camp) + (60.0 if _near_trail(p, 30.0) else 0.0), p])
		x += 20.0
	if cands.is_empty():
		return []
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var a_site: Vector3 = cands[0][1]
	var best := -1.0
	var b_site := Vector3.INF
	for c in cands:
		var p: Vector3 = c[1]
		var s := minf(p.distance_to(a_site), p.distance_to(camp))
		if s > best:
			best = s
			b_site = p
	var out: Array[Vector3] = [a_site]
	if b_site != Vector3.INF and b_site.distance_to(a_site) > 300.0:
		out.append(b_site)
	return out


func _near_trail(p: Vector3, r: float) -> bool:
	for tr in World.config.trails:
		var pts: PackedVector2Array = tr
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)
			if q.distance_to(Vector2(p.x, p.z)) < r:
				return true
	return false


func _build_sheds(holder: Node3D) -> void:
	var i := 0
	for site in shed_sites():
		var shed := Node3D.new()
		shed.name = "FieldShed_%d" % i
		holder.add_child(shed)
		shed.global_position = site
		var face := (World.camp_origin() - site)
		face.y = 0
		shed.look_at(site + face.normalized(), Vector3.UP)   # door (-Z) faces camp
		_shed_geometry(shed)
		var m := Marker3D.new()
		m.name = "ShedHide_%d" % i
		shed.add_child(m)
		m.position = Vector3(SHED_SIZE.x * 0.5 - 0.55, 0.05, SHED_SIZE.z * 0.5 - 0.55)
		m.rotation.y = PI
		var spot := HideSpot.make(m, "shed", "shed_%d" % i)
		var gt := shed.global_transform
		var inside_door := gt * Vector3(-0.5, 0.05, -SHED_SIZE.z * 0.5 + 0.6)
		var hatch_out := gt * Vector3(SHED_SIZE.x * 0.5 + 0.9, 0.0, -0.1)
		hatch_out.y = World.height_at(hatch_out.x, hatch_out.z)
		var pos := gt * m.position
		var exits: Array[Vector3] = [inside_door, hatch_out]
		spot.configure_rock(pos, (inside_door - pos).normalized(), 0.95, exits, gt * Vector3(-0.2, 0.05, 0.2), false)
		spot._rock = false
		spot.set_meta("door_out", gt * Vector3(-0.5, 0.0, -SHED_SIZE.z * 0.5 - 1.3))
		spot.set_meta("door_in", inside_door)
		if _clear(spot):
			hides.append(spot)
			sheds.append(shed)
		else:
			rejected["shed_clearance"] = int(rejected.get("shed_clearance", 0)) + 1
			shed.queue_free()
		i += 1


func _shed_geometry(shed: Node3D) -> void:
	var W := SHED_SIZE.x
	var H := SHED_SIZE.y
	var D := SHED_SIZE.z
	var T := 0.1
	BuildKit.box(shed, Vector3(W, 0.12, D), Vector3(0, 0.06, 0), "planks", true, 0.0, "Floor")
	# Front wall with a door opening (x -1.1..-0.1), back wall solid,
	# right wall with a low crawl hatch, left wall solid.
	BuildKit.wall(shed, Vector3(-W * 0.5, 0.12, -D * 0.5), 0.0, W, H, T, [[0.6, 1.5, 0.0, 1.95]], "siding")
	BuildKit.wall(shed, Vector3(W * 0.5, 0.12, D * 0.5), PI, W, H, T, [], "siding")
	BuildKit.wall(shed, Vector3(-W * 0.5, 0.12, D * 0.5), PI * 0.5, D, H, T, [], "siding")
	BuildKit.wall(shed, Vector3(W * 0.5, 0.12, -D * 0.5), -PI * 0.5, D, H, T, [[0.9, 1.75, 0.3, 1.0]], "siding")
	BuildKit.box(shed, Vector3(W + 0.5, 0.1, D + 0.5), Vector3(0, H + 0.2, 0), "roof", true, 0.0, "Roof")
	# Bench along the back wall, with tools and sacks (the hide is behind it).
	BuildKit.box(shed, Vector3(1.6, 0.08, 0.6), Vector3(-0.4, 0.9, D * 0.5 - 0.4), "dark_wood", true, 0.0, "Bench")
	for sx in [-1.1, 0.3]:
		BuildKit.box(shed, Vector3(0.08, 0.85, 0.5), Vector3(sx, 0.5, D * 0.5 - 0.4), "dark_wood", true)
	BuildKit.box(shed, Vector3(0.7, 0.55, 0.45), Vector3(W * 0.5 - 1.05, 0.4, D * 0.5 - 1.15), "upholstery", true, 0.0, "Sacks")
	BuildKit.cylinder(shed, 0.28, 0.85, Vector3(-W * 0.5 + 0.45, 0.55, -D * 0.5 + 0.45), "steel", true, 10)


# ---------------------------------------------------------- dock chest

func _make_chest(root: Node3D, p: Vector3, along: Vector3) -> HideSpot:
	var c := Node3D.new()
	c.name = "DockGearChest"
	root.add_child(c)
	c.global_position = p
	c.look_at(p + along, Vector3.UP)
	var L := 2.0
	var Wd := 0.95
	var Ht := 0.8
	BuildKit.box(c, Vector3(Wd, 0.06, L), Vector3(0, 0.03, 0), "planks", true, 0.0, "ChestFloor")
	for sx in [-1.0, 1.0]:
		BuildKit.box(c, Vector3(0.06, Ht, L), Vector3(sx * Wd * 0.5, Ht * 0.5, 0), "dark_wood", true)
		BuildKit.box(c, Vector3(Wd, Ht, 0.06), Vector3(0, Ht * 0.5, sx * L * 0.5), "dark_wood", true)
	BuildKit.box(c, Vector3(Wd + 0.08, 0.06, L + 0.08), Vector3(0, Ht + 0.03, 0), "dark_wood", true, 0.0, "Lid")
	var m := Marker3D.new()
	m.name = "ChestHide"
	c.add_child(m)
	m.position = Vector3(0, 0.08, 0)
	var spot := HideSpot.make(m, "dock_store", "dock")
	var gt := c.global_transform
	var side := gt.basis.x.normalized()
	var e1 := gt * Vector3(Wd * 0.5 + 0.7, 0, 0.2)
	var e2 := gt * Vector3(-Wd * 0.5 - 0.7, 0, -0.2)
	e1.y = p.y
	e2.y = p.y
	var exits: Array[Vector3] = [e1, e2]
	spot.configure_rock(gt * Vector3(0, 0.08, 0), side, 0.32, exits, e1, false)
	spot._rock = false
	spot.set_meta("lie_axis", gt.basis.z.normalized())
	hides.append(spot)
	return spot


# ---------------------------------------------------------- validation

## The occupant pose fits: no static collider overlaps a capsule at the
## hide (crouched or lying), and the trunk/rock data agrees.
func _clear(spot: HideSpot) -> bool:
	return clearance(spot).is_empty()


func clearance(spot: HideSpot) -> String:
	var lying := spot.kind in ["dock_store", "under_bed", "under_dock"]
	var base := spot.eye - Vector3(0, spot.eye.y - (spot.marker.global_position.y if spot.marker else spot.eye.y), 0)
	if spot.kind in ["thicket", "shed"] and _trunk_or_rock_near(base, 0.4):
		return "trunk or rock"
	var vp := get_viewport() if is_inside_tree() else null
	if vp == null or vp.world_3d == null:
		return ""
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.22
	cap.height = 0.8 if lying else 1.0
	q.shape = cap
	var b := Basis.IDENTITY
	if lying:
		var axis: Vector3 = spot.get_meta("lie_axis", spot.look_dir.cross(Vector3.UP))
		axis.y = 0.0
		b = Basis(Quaternion(Vector3.UP, axis.normalized()))
	q.transform = Transform3D(b, base + Vector3(0, 0.32 if lying else 0.62, 0))
	q.collision_mask = 1
	var hits := vp.world_3d.direct_space_state.intersect_shape(q, 4)
	return "" if hits.is_empty() else "overlaps %s" % str((hits[0].collider as Node).name)


# --------------------------------------------------------------- audit

## Hide and escape opportunity by region. "Nearest" is straight-line to
## any usable hide (rock, thicket, shed, buildings, dock); alternate
## escape = at least two different hides within 150 m.
func audit() -> Dictionary:
	var all: Array = get_tree().get_nodes_in_group("hide_spot")
	var pts := []
	for h in all:
		if is_instance_valid(h):
			pts.append((h as HideSpot).global_position)
	var kinds := {}
	for h in all:
		kinds[(h as HideSpot).kind] = int(kinds.get((h as HideSpot).kind, 0)) + 1
	var camp := World.camp_origin()
	var regions: Array = World.cover.get("regions", [])
	var res := {}
	var add := func(region: String, p: Vector3) -> void:
		if not res.has(region):
			res[region] = {"samples": 0, "d": [], "within30": 0, "within150": 0, "alt": 0}
		var r: Dictionary = res[region]
		var best := INF
		var n150 := 0
		for q in pts:
			var d := Vector2((q as Vector3).x - p.x, (q as Vector3).z - p.z).length()
			best = minf(best, d)
			if d < 150.0:
				n150 += 1
		r.samples = int(r.samples) + 1
		(r.d as Array).append(best)
		if best < 30.0:
			r.within30 = int(r.within30) + 1
		if best < 150.0:
			r.within150 = int(r.within150) + 1
		if n150 >= 2:
			r.alt = int(r.alt) + 1
	# Land samples (named regions; far logging = beyond 350 m of camp).
	var x := -720.0
	while x <= 720.0:
		var z := -520.0
		while z <= 520.0:
			var p := Vector3(x, World.height_at(x, z), z)
			z += 40.0
			if p.y < 1.5:
				continue
			var rn := "island"
			var bd := INF
			for rg in regions:
				var s := Vector2(float(rg.seed[0]), float(rg.seed[1]))
				var d := s.distance_to(Vector2(p.x, p.z))
				if d < bd:
					bd = d
					rn = str(rg.name)
			add.call(rn, p)
			if p.distance_to(camp) > 350.0:
				add.call("far logging (>350 m from camp)", p)
		x += 40.0
	# Travel routes (trails), every 25 m.
	for tr in World.config.trails:
		var tp: PackedVector2Array = tr
		for i in tp.size() - 1:
			var seg := tp[i + 1] - tp[i]
			var n := maxi(int(seg.length() / 25.0), 1)
			for k in n:
				var q2 := tp[i] + seg * float(k) / n
				add.call("travel routes (trails)", Vector3(q2.x, World.height_at(q2.x, q2.y), q2.y))
	var out := {}
	for k in res:
		var r: Dictionary = res[k]
		var ds: Array = r.d
		ds.sort()
		var n2 := maxi(int(r.samples), 1)
		out[k] = {"samples": r.samples, "median_m": snappedf(float(ds[ds.size() / 2]), 1.0), "p90_m": snappedf(float(ds[int(ds.size() * 0.9)]), 1.0),
			"hide_within_30m": snappedf(float(r.within30) / n2, 0.01), "hide_within_150m": snappedf(float(r.within150) / n2, 0.01), "two_or_more_within_150m": snappedf(float(r.alt) / n2, 0.01)}
	var total := 0
	var top := 0
	for k2 in kinds:
		total += int(kinds[k2])
		top = maxi(top, int(kinds[k2]))
	return {"regions": out, "kinds": kinds, "hides": total, "largest_kind_share": snappedf(float(top) / maxf(total, 1), 0.01),
		"cleared_land": "every hide is rock, brush, a structure or the dock: none depends on standing trees, so the fully cleared island keeps all of them (soft cover from undergrowth persists after logging)",
		"rejected": rejected.duplicate()}
