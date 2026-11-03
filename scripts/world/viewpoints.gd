class_name Viewpoints
extends RefCounted
## Review viewpoints for the Preview Tour and the screenshot tool. Positions
## are derived from world data so they stay valid if the layout is edited.

static var _cache := {}


static func all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var co := World.camp_origin()
	var c := Vector3(co.x, 0.0, co.z)   # heights come from the terrain in _v()
	var eye := 1.65
	var vp := {}
	vp["camp"] = _v(c + Vector3(-3, 0, 14), c + Vector3(2, 0, -8), eye, "Camp: clearing, fire pit, fence and entrance")
	vp["camp_sunset"] = _v(c + Vector3(-20, 0, 15), c + Vector3(4, 0, -6), eye, "Camp at sunset", "sunset")
	var camper := c + CampLayout.CAMPER_POS
	vp["camper"] = _v(camper + Vector3(0.2, CampLayout.CAMPER_FLOOR, 2.6), camper + Vector3(0.0, CampLayout.CAMPER_FLOOR, -3.0), eye, "Camper interior (kitchen toward bedroom)")
	vp["camper_night"] = _v(camper + Vector3(0.9, CampLayout.CAMPER_FLOOR, -2.0), camper + Vector3(-1.5, CampLayout.CAMPER_FLOOR + 0.1, -3.2), eye, "Camper bedroom at night: window to the woods", "night")
	var cabin := c + CampLayout.CABIN_POS
	vp["cabin"] = _v(cabin + Vector3(-2.6, CampLayout.CABIN_FLOOR, 3.8), cabin + Vector3(1.0, CampLayout.CABIN_FLOOR, -3.0), eye, "Worker cabin: four beds and arcade corner")
	# Beach: walk south from camp until the sand is ~0.25 m above sea.
	var bx := c.x - 30.0
	var bz := c.z
	while bz < c.z + 400.0 and World.height_at(bx, bz) > 0.35:
		bz += 1.0
	vp["beach"] = _v(Vector3(bx - 6.0, 0.0, bz - 9.0), Vector3(bx + 25.0, 0.0, bz + 6.0), eye, "Beach: foam, swash, wet sand")
	vp["shallows"] = _v(Vector3(bx + 4.0, 0.0, bz + 4.0), Vector3(bx + 10.0, -2.0, bz + 20.0), eye, "Clear shallows: refraction and caustics")
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
	vp["high_overview"] = _v(Vector3(420.0, 0.0, -170.0), Vector3(-150.0, 0.0, 300.0), 22.0, "High view from the ridge over the island")
	var fire := c + CampLayout.BURN_PIT_POS
	vp["fire_close"] = _v(fire + Vector3(0.0, 0.0, 4.2), fire + Vector3(0.0, 0.6, 0.0), 0.2, "Campfire close-up", "night")
	_cache = vp
	return vp


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
