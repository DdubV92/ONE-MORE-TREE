class_name Viewpoints
extends RefCounted
## Review viewpoints for the Preview Tour and the screenshot tool. Positions
## are derived from world data so they stay valid if the layout is edited.

static var _cache := {}
static var _cache_rev := ""


static func all() -> Dictionary:
	if not _cache.is_empty() and _cache_rev == World.island_revision:
		return _cache
	var co := World.camp_origin()
	var c := Vector3(co.x, 0.0, co.z)   # heights come from the terrain in _v()
	var eye := 1.65
	var vp := {}
	vp["camp"] = _v(c + Vector3(-3, 0, 14), c + Vector3(2, 0, -8), eye, "Camp: clearing, fire pit, fence and entrance")
	vp["camp_sunset"] = _v(c + Vector3(-20, 0, 15), c + Vector3(4, 0, -6), eye, "Camp at sunset", "sunset")
	var camper := c + CampLayout.CAMPER_POS
	vp["camper"] = _v(camper + Vector3(0.9, CampLayout.CAMPER_FLOOR, 2.0), camper + Vector3(-0.4, CampLayout.CAMPER_FLOOR, -3.0), eye, "Camper interior (kitchen toward bedroom)")
	vp["camper_lounge"] = _v(camper + Vector3(-0.6, CampLayout.CAMPER_FLOOR, 2.9), camper + Vector3(-0.2, CampLayout.CAMPER_FLOOR + 0.4, 6.0), eye, "Camper lounge (Phase 11, +25 % floor): desk station left, couch and TV right")
	vp["camper_night"] = _v(camper + Vector3(0.9, CampLayout.CAMPER_FLOOR, -2.0), camper + Vector3(-1.5, CampLayout.CAMPER_FLOOR + 0.1, -3.2), eye, "Camper bedroom at night: window to the woods", "night")
	var rack := c + CampLayout.DELIVERY_RACK_POS
	vp["delivery"] = _v(rack + Vector3(1.5, 0, 5.5), c + CampLayout.BURN_PIT_POS + Vector3(1.5, 0, 0), eye, "Delivery rack and burn pit")
	var cabin := c + CampLayout.CABIN_POS
	var bedroom := cabin + Vector3(-2.2, CampLayout.CABIN_FLOOR, -6.6)
	vp["cabin_bedroom"] = _v(bedroom, bedroom + Vector3(-0.6, -0.8, -3.0), eye, "Extension bedroom: beds 5 and 6")
	vp["cabin_ext"] = _v(cabin + Vector3(9.0, 0, -15.0), cabin + Vector3(0, 0.5, -6.0), eye, "Cabin extension from outside")
	vp["cabin_ext_in"] = _v(cabin + Vector3(1.6, CampLayout.CABIN_FLOOR, -6.0), cabin + Vector3(-2.2, CampLayout.CABIN_FLOOR - 0.6, -9.6), eye, "Extension: kitchen, bedroom doorway, bathroom door")
	vp["cabin"] = _v(cabin + Vector3(-2.6, CampLayout.CABIN_FLOOR, 3.8), cabin + Vector3(1.0, CampLayout.CABIN_FLOOR, -3.0), eye, "Worker cabin: four beds and arcade corner")
	# Beach: walk south from camp until the sand is ~0.25 m above sea.
	var bx := c.x - 30.0
	var bz := c.z
	while bz < c.z + 400.0 and World.height_at(bx, bz) > 0.35:
		bz += 1.0
	vp["beach"] = _v(Vector3(bx - 6.0, 0.0, bz - 9.0), Vector3(bx + 25.0, 0.0, bz + 6.0), eye, "Beach: foam, swash, wet sand")
	vp["shallows"] = _v(Vector3(bx + 4.0, 0.0, bz + 4.0), Vector3(bx + 10.0, -2.0, bz + 20.0), eye, "Clear shallows: refraction and caustics")
	# Surf: stand at the waterline and look along the breaker line.
	var brz := bz
	while brz < bz + 200.0 and World.height_at(bx, brz) > -SurfSystem.BREAK_DEPTH:
		brz += 1.0
	vp["surf"] = _v(Vector3(bx - 14.0, 0.0, bz - 5.0), Vector3(bx + 30.0, 0.8, brz + 2.0), eye, "Surf: breaking waves curling onto the beach")
	vp["surf_side"] = _v(Vector3(bx + 2.0, 0.0, bz - 2.0), Vector3(bx + 6.0, 0.6, brz + 6.0), eye, "Surf: waves rolling in toward you")
	vp["surf_wade"] = _v(Vector3(bx, 0.0, brz - 11.0), Vector3(bx + 28.0, 1.0, brz - 1.0), eye, "Surf from the shallows: the lip curling over")
	vp["surf_profile"] = _v(Vector3(bx - 16.0, 0.0, brz - 4.0), Vector3(bx + 6.0, 1.2, brz - 4.0), 1.6, "Debug: breaker cross-section seen along the shore")
	vp["coast_day"] = _v(Vector3(bx - 40.0, 0.0, bz - 22.0), Vector3(bx + 120.0, 0.0, bz + 40.0), eye + 1.0, "Daytime coast", "day")
	# Forest: densest tree cell near the western trail.
	vp["forest"] = _v(Vector3(-300.0, 0.0, 110.0), Vector3(-330.0, 0.0, 60.0), eye, "Dense forest")
	var nb: Dictionary = World.bridges()[1] if World.bridges().size() > 1 else {"x": 0.0, "z": 0.0}
	vp["river"] = _v(Vector3(nb.x, 0.0, nb.z) + Vector3(6.0, 0.0, 10.0), Vector3(nb.x, 0.0, nb.z) + Vector3(-25.0, 0.0, -50.0), eye, "River and bridge")
	var rp := _river_rapid_point()
	vp["rapids"] = _v(rp + Vector3(7.0, 0.0, 6.0), rp, eye, "River riffle (whitewater at a grade change)")
	var pd: Dictionary = World.ponds()[0]
	vp["pond"] = _v(Vector3(pd.x, 0.0, pd.z) + Vector3(0.0, 0.0, float(pd.radius) + 7.0), Vector3(pd.x, 0.0, pd.z), eye, "Lowland pond with reeds")
	var pd2: Dictionary = World.ponds()[1]
	vp["pond2"] = _v(Vector3(pd2.x, 0.0, pd2.z) + Vector3(float(pd2.radius) + 7.0, 0.0, 4.0), Vector3(pd2.x, 0.0, pd2.z), eye, "Second pond near the river")
	vp["ridge"] = _v(Vector3(330.0, 0.0, -250.0), Vector3(-200.0, 0.0, 200.0), eye + 1.0, "Rocky ridge overlooking the island")
	# Logging Test starting point: just outside the forest entrance.
	vp["logging_test"] = _v(c + Vector3(0.0, 0.0, -24.0), c + Vector3(0.0, 0.0, -45.0), eye, "Logging Test (use the Tour panel to cycle test trees)")
	vp["high_overview"] = _v(Vector3(420.0, 0.0, -170.0), Vector3(-150.0, 0.0, 300.0), 22.0, "High view from the ridge over the island")
	var fire := c + CampLayout.BURN_PIT_POS
	vp["fire_close"] = _v(fire + Vector3(0.0, 0.0, 4.2), fire + Vector3(0.0, 0.6, 0.0), 0.2, "Campfire close-up", "night")
	# Phase 5: TV from the couch, dock + utility building, dog alcove.
	var F := CampLayout.CAMPER_FLOOR
	var zs := CampLayout.CAMPER_SOUTH_Z
	var W := CampLayout.CAMPER_SIZE.x * 0.5
	# Phase 11: surveillance lives on the desk computer; the TV is entertainment.
	vp["tv_wall"] = _v(camper + Vector3(-W + 0.62, F, zs - 1.07), camper + Vector3(-W + 0.63, F + 0.1, zs), 1.17, "Seated at the desk: monitor with the camera wall")
	vp["desk_window"] = _v(camper + Vector3(-W + 0.62, F, zs - 1.07), camper + Vector3(-W - 3.0, F + 0.2, zs - 1.2), 1.17, "Seated at the desk, glancing right through the window")
	vp["couch_tv"] = _v(camper + Vector3(W - 0.88, F, zs - 2.05), camper + Vector3(W - 0.88, F + 0.32, zs), 1.17, "Couch view of the entertainment TV")
	# Phase 12: soft furnishings review (sheets/blankets, vinyl shower curtain).
	vp["camper_bedroom"] = _v(camper + Vector3(-1.15, F, -1.75), camper + Vector3(0.0, F + 0.35, -3.7), 1.5, "Camper bedroom: sheet, wool blanket, pillows")
	vp["camper_bath"] = _v(camper + Vector3(0.4, F, 0.1), camper + Vector3(0.95, F - 0.35, -1.0), 1.45, "Camper bathroom: vinyl shower curtain")
	vp["dock"] = _v(c + Vector3(-7.0, 0.0, 121.0), c + Vector3(8.0, 0.0, 100.0), eye, "Service dock, utility building and beacon hut")
	vp["dog_alcove"] = _v(c + Vector3(4.6, 0.0, 97.6), c + Vector3(8.8, -0.4, 95.0), 1.3, "The dog's dry alcove beside the utility building")
	vp["utility_inside"] = _v(c + Vector3(10.2, 0.45, 92.6), c + Vector3(12.0, 0.0, 96.2), eye, "Inside the utility building: shelves, panel, radio and beacon")
	vp["dock_end"] = _v(c + Vector3(6.0, 0.0, 112.0), c + Vector3(6.0, -0.6, 126.0), eye, "Along the dock deck to the ladder and lamp")
	# Phase 7: the trail bridges (truck-capable) from their ramp approach.
	var bl: Array = World.bridges()
	for bi in bl.size():
		var b: Dictionary = bl[bi]
		var acr := Vector2(float(b.ax), float(b.az)).normalized()
		var foot := Vector2(b.x, b.z) + acr * (float(b.half_span) + 12.0)
		var far := Vector2(b.x, b.z) - acr * float(b.half_span)
		vp["bridge_%d" % bi] = _v(Vector3(foot.x + acr.y * 3.0, 0.0, foot.y - acr.x * 3.0), Vector3(far.x, 0.0, far.y), 1.65, "Trail bridge %d (3.6 m, truck-capable)" % bi)
	if World.island_revision == "r2":
		_add_r2(vp, c)
	_cache = vp
	_cache_rev = World.island_revision
	return vp


## Phase 12 review views on island r2, chosen from the frozen data so they
## always point at real features (nearest to camp first).
static func _add_r2(vp: Dictionary, c: Vector3) -> void:
	var cc := Vector2(c.x, c.z)
	var eye := 1.65
	# Densest veteran grove at eye level (most standing trunks within 12 m).
	var best := -1
	var best_n := -1
	var xs: PackedFloat32Array = World.trees.x
	var zs: PackedFloat32Array = World.trees.z
	for i in range(0, xs.size(), 7):
		var p := Vector2(xs[i], zs[i])
		if p.distance_to(cc) > 260.0 or int(World.trees.get("cohort", PackedByteArray())[i]) != 2:
			continue
		var n := 0
		for j in range(maxi(i - 60, 0), mini(i + 60, xs.size())):
			if p.distance_to(Vector2(xs[j], zs[j])) < 12.0:
				n += 1
		if n > best_n:
			best_n = n
			best = i
	if best >= 0:
		var t := Vector3(xs[best], 0, zs[best])
		vp["p12_grove"] = _v(t + Vector3(7.0, 0, 6.0), t + Vector3(-6.0, 1.0, -8.0), eye, "Dense veteran grove at eye level (%d trunks within 12 m)" % best_n)
	# Low-bough tree work approach: nearest variant-3 veteran to camp.
	var lb := -1
	var lbd := 1e9
	for i in xs.size():
		if int(World.trees.variant[i]) == 3 and int(World.trees.get("cohort", PackedByteArray())[i]) == 2:
			var d := Vector2(xs[i], zs[i]).distance_to(cc)
			if d < lbd and d > 40.0:
				lbd = d
				lb = i
	if lb >= 0:
		var t := Vector3(xs[lb], 0, zs[lb])
		var dir := (Vector3(c.x, 0, c.z) - t).normalized()
		vp["p12_boughs"] = _v(t + dir * 3.2, t + Vector3(0, 1.4, 0), eye, "Work approach under thick low boughs (tree #%d, %.1f m)" % [int(World.trees.id[lb]), float(World.trees.height[lb])])
	var nearest := func(list: Array, kind: String, key: String) -> Dictionary:
		var out: Dictionary = {}
		var bd := 1e9
		for e in list:
			if kind != "" and str(e.get("kind", "")) != kind:
				continue
			var p := Vector2(float(e[key][0]), float(e[key][1]))
			var d := p.distance_to(cc)
			if d < bd and d > 30.0:
				bd = d
				out = e
		return out
	var th: Dictionary = nearest.call(World.cover.get("thickets", []), "", "center")
	if not th.is_empty():
		var t := Vector3(th.center[0], 0, th.center[1])
		var dir := (Vector3(c.x, 0, c.z) - t).normalized()
		vp["p12_thicket"] = _v(t + dir * (float(th.radius) + 7.0), t, eye, "Undergrowth edge: bramble and hazel thicket (soft cover)")
	var sh: Dictionary = nearest.call(World.cover.get("formations", []), "rock_shelf", "center")
	if not sh.is_empty():
		var t := Vector3(sh.center[0], 0, sh.center[1])
		var dir := (Vector3(c.x, 0, c.z) - t).normalized()
		vp["p12_rocks"] = _v(t + dir * (float(sh.radius) + 9.0), t, eye, "Rock shelf on a landform rise (hard cover)")
	# Nearest rock recess whose opening has a clear view line (no trunk
	# within 1.6 m of the line from the viewpoint to the pocket).
	var hides: Array = World.cover.get("hides", []).duplicate()
	hides.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.pos[0], a.pos[1]).distance_to(cc) < Vector2(b.pos[0], b.pos[1]).distance_to(cc))
	for hd in hides:
		if str(hd.kind) != "rock_recess":
			continue
		var t2 := Vector2(hd.pos[0], hd.pos[1])
		var f2 := Vector2(hd.facing[0], hd.facing[1])
		var from := t2 + f2 * 5.5 + Vector2(f2.y, -f2.x) * 1.5
		var blocked := false
		for i in xs.size():
			var q := Vector2(xs[i], zs[i])
			if q.distance_to(t2) < 9.0 and IslandGenerator.seg_dist(q, from, t2).x < 1.6:
				blocked = true
				break
		if blocked:
			continue
		vp["p12_hide"] = _v(Vector3(from.x, 0, from.y), Vector3(t2.x, -0.4, t2.y), eye, "Rock recess hide: opening, crouch pocket, one way out")
		break
	var rg: Dictionary = nearest.call(World.cover.get("landforms", []), "ridge", "center")
	if not rg.is_empty():
		var t := Vector3(rg.center[0], 0, rg.center[1])
		var d := Vector3(rg.dir[0], 0, rg.dir[1])
		vp["p12_ridge"] = _v(t - d * (float(rg.length) * 0.5 + 6.0) + Vector3(d.z, 0, -d.x) * 14.0, t, eye, "Small landform ridge breaking the sightline")
	vp["p12_high"] = _v(c + Vector3(-60.0, 0.0, -160.0), c + Vector3(80.0, -6.0, -420.0), 9.0, "Over the woods north of camp: canopy, groves and gaps")


static func _v(pos: Vector3, look: Vector3, eye: float, label: String, lighting: String = "") -> Dictionary:
	var p := Vector3(pos.x, maxf(World.height_at(pos.x, pos.z), World.water_level_at(pos.x, pos.z) - 0.5) + pos.y + eye, pos.z)
	var l := Vector3(look.x, World.height_at(look.x, look.z) + look.y + 1.0, look.z)
	var d := {"pos": p, "look": l, "label": label, "feet": p - Vector3(0, eye, 0)}
	if lighting != "":
		d["lighting"] = lighting
	return d


static func _river_rapid_point() -> Vector3:
	var best := 0
	for k in World.river_rapid.size():
		if World.river_rapid[k] > World.river_rapid[best] and World.river_arc[k] < World.river_arc[World.river_arc.size() - 1] * 0.8:
			best = k
	var p := World.river_points[best]
	return Vector3(p.x, 0.0, p.y)
