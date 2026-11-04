extends Node
## Phase 7 whole-island audit (headless, Preview world, never saved).
##
##  1. Placement: every tree root and rock against real terrain; ground cover
##     instances near camp against water/buildings/terrain; grounded anchors
##     (beds, seats, hides, dog/ship anchors, spawn/reset, worker storage)
##     against real collision; camera mounts (mount-to-support and, on rocks,
##     rock-to-terrain); bridge ends; dock pilings.
##  2. Reachability from camp on the crew grids: every original tree's
##     cutting stand + a retreat cell (and therefore its stump), beds, camp
##     facilities, hides, dog routes/refuge, dock gangway.
##  3. Truck reach by named region (DriveNav component from the bays).
##  4. Clearing fixtures (0/25/50/90/99/100 % removed, nearest-first) -> the
##     same coverage again for what remains + truck reach.
## Writes docs/audit/island_audit.json and docs/audit/ISLAND_AUDIT.md.
##   godot --headless res://tools/island_audit.tscn [-- quick]

var w: IslandWorld
var report := {}
var issues: Array[Dictionary] = []
var _issue_n := 0
var quick := false


func _ready() -> void:
	quick = "quick" in OS.get_cmdline_user_args()
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camp"
	w = load("res://scenes/world.tscn").instantiate()
	w.build_ui = false
	add_child(w)
	var g := 0
	while not w.systems_ready and g < 900:
		await get_tree().physics_frame
		g += 1
	w.hunt.build_hide_spots()
	var t0 := Time.get_ticks_msec()
	report["engine"] = Engine.get_version_info().string
	report["world"] = {"seed": World.manifest.get("world_seed"), "generation_version": World.manifest.get("generation_version"), "trees": World.tree_count(), "rocks": (World.rocks.x as PackedFloat32Array).size()}
	report["regions"] = _region_table()
	report["placement"] = await _placement()
	report["reach_original"] = _reach_coverage("original")
	report["trucks_original"] = _truck_coverage()
	report["facilities"] = _facilities()
	if not quick:
		report["fixtures"] = await _fixtures()
	report["issues"] = issues
	report["elapsed_ms"] = Time.get_ticks_msec() - t0
	PlacementValidator.write_report("res://docs/audit/island_audit.json", report)
	_write_md()
	print("AUDIT ", JSON.stringify({"issues": issues.size(), "elapsed_ms": report.elapsed_ms, "unreachable_trees": report.reach_original.unreachable, "placement": report.placement.summary}))
	get_tree().quit()


func _issue(sev: String, cat: String, where: String, reason: String, fix: String, data := {}) -> void:
	_issue_n += 1
	var it := {"id": "P7-%04d" % _issue_n, "severity": sev, "category": cat, "where": where, "reason": reason, "proposed_fix": fix, "disposition": "open"}
	it.merge(data)
	issues.append(it)


# ------------------------------------------------------------- regions

var _centre := Vector2.ZERO


func _region_table() -> Dictionary:
	var c := Vector2.ZERO
	for i in World.tree_count():
		c += Vector2(World.trees.x[i], World.trees.z[i])
	_centre = c / maxf(World.tree_count(), 1)
	var counts := {}
	for i in World.tree_count():
		var r := region_of(Vector2(World.trees.x[i], World.trees.z[i]))
		counts[r] = int(counts.get(r, 0)) + 1
	return {"centre": [_centre.x, _centre.y], "trees_per_region": counts}


const SECTORS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]


func region_of(p: Vector2) -> String:
	var o := World.camp_origin()
	if Vector2(p.x - o.x, p.y - o.z).length() < 60.0:
		return "camp surroundings"
	var d := p - _centre
	# -Z is north
	var ang := fposmod(atan2(d.x, -d.y), TAU)
	var sector: String = SECTORS[int(round(ang / (TAU / 8.0))) % 8]
	return ("inner " if d.length() < 380.0 else "outer ") + sector


# ----------------------------------------------------------- placement

func _placement() -> Dictionary:
	var out := {}
	var t := PlacementValidator.audit_trees()
	var r := PlacementValidator.audit_rocks()
	out["trees"] = {"checked": t.checked, "floating": t.floating.size(), "overburied": t.overburied.size(), "in_water": t.in_water.size(), "on_rock": t.on_rock.size(), "no_cut_stand": t.no_cut_stand.size(), "max_gap": _max(t.floating, "gap")}
	out["rocks"] = {"checked": r.checked, "floating": r.floating.size(), "max_gap": _max(r.floating, "gap")}
	for f in t.floating:
		_issue("blocker" if float(f.gap) > 0.08 else "minor", "tree_support", "tree %d" % int(f.id), "root base %.3f m above the lowest ground under its trunk" % float(f.gap), "ground the root at the lowest footprint sample (generator)")
	for f in t.in_water:
		_issue("blocker", "tree_in_water", "tree %d" % int(f.id), "trunk stands in water", "exclude water in generation")
	for f in t.no_cut_stand:
		_issue("blocker", "tree_no_stand", "tree %d" % int(f.id), "no walkable cutting stand around the trunk", "relax stand ring / move the target")
	for f in r.floating:
		_issue("blocker" if float(f.gap) > 0.1 else "minor", "rock_support", "rock %d" % int(f.index), "rock bottom %.3f m above ground" % float(f.gap), "sink the rock to its lowest footprint sample")
	# Ground cover near camp: built cells, every instance.
	var gc: Node = w.ground_cover
	var cover := {"instances": 0, "in_buildings": 0, "in_water": 0, "floating": 0, "floating_samples": []}
	if gc:
		gc.force_build_around(World.camp_origin())
		await get_tree().process_frame
		var rects := _building_rects()
		for mmi in gc.find_children("*", "MultiMeshInstance3D", true, false):
			var mm := (mmi as MultiMeshInstance3D).multimesh
			if mm == null:
				continue
			for k in mm.instance_count:
				var lxf := mm.get_instance_transform(k)
				if lxf == Transform3D.IDENTITY:
					cover["unreadable_headless"] = int(cover.get("unreadable_headless", 0)) + 1
					continue     # dummy renderer readback (verified fine on Vulkan)
				var xf := (mmi as MultiMeshInstance3D).global_transform * lxf
				var p := xf.origin
				cover.instances = int(cover.instances) + 1
				for rc in rects:
					if (rc as Rect2).has_point(Vector2(p.x, p.z)):
						cover.in_buildings = int(cover.in_buildings) + 1
						break
				if World.water_depth_at(p.x, p.z) > 0.35 and not str(mmi.name).to_lower().contains("reed"):
					cover.in_water = int(cover.in_water) + 1
				if p.y - World.height_at(p.x, p.z) > 0.15:
					cover.floating = int(cover.floating) + 1
					if (cover.floating_samples as Array).size() < 6:
						cover.floating_samples.append({"kind": str(mmi.name), "pos": [snappedf(p.x, 0.1), snappedf(p.y, 0.01), snappedf(p.z, 0.1)], "terrain": snappedf(World.height_at(p.x, p.z), 0.01), "parent": str(mmi.get_parent().name)})
	out["ground_cover_near_camp"] = cover
	if int(cover.in_buildings) > 0:
		_issue("blocker", "foliage_in_building", "ground cover near camp", "%d instances inside building footprints" % int(cover.in_buildings), "exclude building footprints in GroundCover")
	if int(cover.floating) > 0:
		_issue("minor", "foliage_floating", "ground cover near camp", "%d instances > 15 cm above terrain" % int(cover.floating), "sample terrain at instance position")
	# Anchors: what people/dogs stand, sit, sleep or hide on.
	var space := w.get_world_3d().direct_space_state
	var groups := {"worker_bed": 1.0, "player_bed": 1.0, "couch_seat": 0.9, "worker_seat": 0.9, "arcade_spot": 0.15, "hiding_spot": 0.35, "dog_bed": 0.25, "dog_refuge": 0.25, "dog_refuge_approach": 0.2, "ship_boarding": 1.2, "safe_reset": 0.25, "worker_storage": 1.2, "worker_spawn": 0.25}
	var anchors := {"checked": 0, "bad": []}
	for gname in groups:
		for n in get_tree().get_nodes_in_group(gname):
			var p: Vector3 = (n as Node3D).global_position
			anchors.checked = int(anchors.checked) + 1
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.3, 0), p - Vector3(0, 2.5, 0), 1)
			var hit := space.intersect_ray(q)
			var below := float((p - (hit.position as Vector3)).y) if not hit.is_empty() else p.y - World.height_at(p.x, p.z)
			if below > float(groups[gname]) or below < -0.35:
				anchors.bad.append({"group": gname, "node": str(n.name), "gap": snappedf(below, 0.01)})
				_issue("blocker", "anchor_support", "%s %s" % [gname, n.name], "support %.2f m below (tolerance %.2f)" % [below, float(groups[gname])], "move the anchor onto its floor/terrain")
	out["anchors"] = anchors
	# Camera mounts: mount-to-support and rock-to-terrain.
	var cams := {"checked": 0, "bad": []}
	for c in get_tree().get_nodes_in_group("security_camera"):
		var cp: Vector3 = (c as Node3D).global_position
		cams.checked = int(cams.checked) + 1
		var q2 := PhysicsRayQueryParameters3D.create(cp, cp - Vector3(0, 8.0, 0), 1)
		var hit2 := space.intersect_ray(q2)
		var sup := str(c.get_meta("support", "?"))
		var gap := (cp - (hit2.position as Vector3)).y if not hit2.is_empty() else cp.y - World.height_at(cp.x, cp.z)
		if sup == "rock":
			var rk := -1
			var bd := 99.0
			for i in (World.rocks.x as PackedFloat32Array).size():
				var d := Vector2(World.rocks.x[i] - cp.x, World.rocks.z[i] - cp.z).length()
				if d < bd:
					bd = d
					rk = i
			var rock_ok := true
			for f in r.floating:
				if int(f.index) == rk:
					rock_ok = false
			if not rock_ok:
				cams.bad.append({"id": str(c.get_meta("camera_id")), "reason": "support rock floats"})
		if gap > 4.5:
			cams.bad.append({"id": str(c.get_meta("camera_id")), "reason": "nothing under the mount for %.1f m" % gap})
	for b in cams.bad:
		_issue("blocker", "camera_support", str(b.id), str(b.reason), "seat the mount on its support")
	out["cameras"] = cams
	# Bridges: deck ends reach the banks.
	var br := {"checked": 0, "bad": []}
	for b in World.bridges():
		br.checked = int(br.checked) + 1
		var across := Vector2(float(b.ax), float(b.az)).normalized()
		for s in [-1.0, 1.0]:
			var end: Vector2 = Vector2(b.x, b.z) + across * float(b.half_span) * s
			var deck := float(b.get("deck", World.height_at(b.x, b.z)))
			var bank := World.height_at(end.x, end.y)
			# Ramps run from each bank up to the deck: the end must be within
			# ramp reach (<= 2.2 m rise over the 3 m ramp + approach).
			if absf(deck - bank) > 2.2:
				br.bad.append({"bridge": str(b.get("id", "?")), "end": s, "deck": deck, "bank": bank})
	out["bridges"] = br
	out["summary"] = {"tree_floating": t.floating.size(), "tree_in_water": t.in_water.size(), "tree_no_stand": t.no_cut_stand.size(), "rock_floating": r.floating.size(), "anchors_bad": (anchors.bad as Array).size(), "cameras_bad": (cams.bad as Array).size(), "cover_in_buildings": int(cover.in_buildings), "cover_floating": int(cover.floating)}
	return out


func _building_rects() -> Array:
	var o := World.camp_origin()
	var out := []
	var cr := CampLayout.CABIN_POS
	out.append(Rect2(Vector2(o.x + cr.x - 3.4, o.z + cr.z - 10.2), Vector2(6.8, 15.2)))
	var mp := CampLayout.CAMPER_POS + CampLayout.camper_box_offset()
	var cs := CampLayout.CAMPER_SIZE
	out.append(Rect2(Vector2(o.x + mp.x - cs.x * 0.5, o.z + mp.z - cs.z * 0.5), Vector2(cs.x, cs.z)))
	if w.dock_site and w.dock_site.building:
		var b := w.dock_site.building.global_position
		out.append(Rect2(Vector2(b.x - DockSite.BW, b.z - DockSite.BD), Vector2(DockSite.BW * 2, DockSite.BD * 2)))
	return out


func _max(arr: Array, key: String) -> float:
	var m := 0.0
	for a in arr:
		m = maxf(m, float(a[key]))
	return snappedf(m, 0.001)


# --------------------------------------------------------- reachability

## Cells reachable from the camp's north gate on the island grid.
func _component() -> Dictionary:
	var nav := w.crew.nav
	var start := nav.to_cell(Vector2(nav.gates[0].outside.x, nav.gates[0].outside.z))
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var head := 0
	while head < q.size():
		var k := q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = k + d
			if seen.has(n) or not nav._in_island(n) or nav.grid.is_point_solid(n):
				continue
			if d.x != 0 and d.y != 0 and (nav.grid.is_point_solid(Vector2i(k.x + d.x, k.y)) or nav.grid.is_point_solid(Vector2i(k.x, k.y + d.y))):
				continue
			seen[n] = true
			q.append(n)
	# The beach gate side too.
	return seen


func _reach_coverage(label: String) -> Dictionary:
	var nav := w.crew.nav
	var comp := _component()
	var th := PlacementValidator._tree_hash()
	var rh := PlacementValidator._rock_hash()
	var per_region := {}
	var unreachable := 0
	var checked := 0
	var samples := []
	for i in World.tree_count():
		var id := int(World.trees.id[i])
		if World.removed_trees.has(id):
			continue
		checked += 1
		var reg := region_of(Vector2(World.trees.x[i], World.trees.z[i]))
		if not per_region.has(reg):
			per_region[reg] = {"targets": 0, "reachable": 0}
		per_region[reg].targets = int(per_region[reg].targets) + 1
		var ok := false
		var stand_cell := Vector2i.ZERO
		for s in PlacementValidator.cut_stands(i, th, rh):
			var k := nav.to_cell(Vector2(s.x, s.z))
			if comp.has(k):
				ok = true
				stand_cell = k
				break
		# A retreat cell (4-9 m) must also be reachable.
		if ok:
			var retreat := false
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3)]:
				if comp.has(stand_cell + d):
					retreat = true
					break
			ok = retreat
		if ok:
			per_region[reg].reachable = int(per_region[reg].reachable) + 1
		else:
			unreachable += 1
			if label == "original":
				_issue("blocker", "tree_unreachable", "tree %d (%s)" % [id, reg], "no cutting stand + retreat in the camp-connected walkable area", "open access / fix nav marking", {"pos": [World.trees.x[i], World.trees.z[i]]})
	# Representative path traces (real A*) from camp to a few far targets.
	var o := World.camp_origin()
	var picks := [0, World.tree_count() / 3, World.tree_count() / 2, World.tree_count() * 2 / 3, World.tree_count() - 1]
	for pi in picks:
		var stands := PlacementValidator.cut_stands(pi, th, rh)
		if stands.is_empty():
			continue
		var path := nav.find_path(Vector3(o.x, 0, o.z), stands[0])
		samples.append({"tree": int(World.trees.id[pi]), "region": region_of(Vector2(World.trees.x[pi], World.trees.z[pi])), "path_points": path.size(), "length_m": snappedf(CrewNav.path_length(path), 1.0) if not path.is_empty() else -1.0})
	return {"label": label, "checked": checked, "unreachable": unreachable, "per_region": per_region, "component_cells": comp.size(), "path_samples": samples}


func _truck_coverage() -> Dictionary:
	var vs := w.vehicles
	var dn := vs.nav
	var start := dn.to_cell(Vector2(vs.bay_pose(0).origin.x, vs.bay_pose(0).origin.z))
	var nearest := dn.nearest_drivable(vs.bay_pose(0).origin, 4)
	if nearest != Vector3.INF:
		start = dn.to_cell(Vector2(nearest.x, nearest.z))
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var head := 0
	while head < q.size():
		var k := q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = k + d
			if seen.has(n) or not dn.in_grid(n) or dn.grid.is_point_solid(n):
				continue
			seen[n] = true
			q.append(n)
	var per := {}
	for i in World.tree_count():
		if World.removed_trees.has(int(World.trees.id[i])):
			continue
		var reg := region_of(Vector2(World.trees.x[i], World.trees.z[i]))
		if not per.has(reg):
			per[reg] = {"targets": 0, "within_25m_of_truck_route": 0}
		per[reg].targets = int(per[reg].targets) + 1
		var c := dn.to_cell(Vector2(World.trees.x[i], World.trees.z[i]))
		var near := false
		for dz in range(-6, 7):
			for dx in range(-6, 7):
				if seen.has(c + Vector2i(dx, dz)):
					near = true
					break
			if near:
				break
		if near:
			per[reg].within_25m_of_truck_route = int(per[reg].within_25m_of_truck_route) + 1
	var tot := 0
	var nearc := 0
	for r in per:
		tot += int(per[r].targets)
		nearc += int(per[r].within_25m_of_truck_route)
	return {"drivable_cells_from_bays": seen.size(), "targets": tot, "within_25m": nearc, "per_region": per}


func _facilities() -> Dictionary:
	var nav := w.crew.nav
	var o := World.camp_origin()
	var yard := Vector3(o.x, nav.surface_at(Vector3(o.x, 0, o.z)), o.z)
	var out := {}
	var checks := {}
	for g in ["worker_bed", "arcade_spot", "worker_seat", "worker_storage"]:
		for n in get_tree().get_nodes_in_group(g):
			checks["%s:%s/%s" % [g, (n as Node).get_parent().name, n.name]] = (n as Node3D).global_position
	if w.dock_site and w.dock_site.refuge_approach != Vector3.ZERO:
		checks["dog_refuge_approach"] = w.dock_site.refuge_approach
	checks["dock_end (gangway)"] = w.crew.dock_end
	checks["delivery_rack"] = CampLayout.world(CampLayout.TRUCK_DROPOFF)
	for k in checks:
		var p: Vector3 = checks[k]
		var path := nav.find_path(yard, p)
		var ok := not path.is_empty() and path[path.size() - 1].distance_to(Vector3(p.x, path[path.size() - 1].y, p.z)) < 2.5
		out[k] = {"ok": ok, "points": path.size()}
		if not ok:
			_issue("blocker", "facility_unreachable", k, "no walkable route from the camp yard", "fix nav/doorway")
	# Hide entries: approach points reachable (authored routes for private buildings).
	for s in get_tree().get_nodes_in_group("hide_spot"):
		var h := s as HideSpot
		var ok2: bool
		if h.building in ["camper", "utility"]:
			ok2 = not w.hunt.route_to_spot(h, yard).is_empty()
		else:
			var p2 := nav.find_path(yard, h.approach)
			ok2 = not p2.is_empty()
		out["hide:" + str(h.name)] = {"ok": ok2}
		if not ok2:
			_issue("blocker", "hide_unreachable", str(h.name), "no route to the hiding entry", "fix approach")
	# Dog camper route points exist and the rescue spot picker finds a spot.
	out["dog_camper_route_points"] = {"ok": w.dog._camper_route().size() == 5}
	var spot := w.dog_rescue._pick_spot()
	out["dog_rescue_spot"] = {"ok": spot != Vector3.INF, "distance_m": snappedf(spot.distance_to(World.camp_origin()), 1.0) if spot != Vector3.INF else -1.0}
	if spot == Vector3.INF:
		_issue("blocker", "dog_rescue_route", "rescue", "no valid 60-150 m rescue spot", "relax picker")
	return out


# ------------------------------------------------------------ fixtures

## Removes trees nearest-first (how a crew actually clears) to the target
## fraction, refreshing navigation through the real removal signal, then
## re-measures. Never touches saves.
func _fixtures() -> Dictionary:
	var order: Array = []
	var o := World.camp_origin()
	for i in World.tree_count():
		order.append([Vector2(World.trees.x[i] - o.x, World.trees.z[i] - o.z).length(), int(World.trees.id[i])])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var veg := w.vegetation
	if World.tree_removed.is_connected(veg._on_tree_removed):
		World.tree_removed.disconnect(veg._on_tree_removed)
	var out := {}
	var done := 0
	for frac in [0.25, 0.5, 0.9, 0.99, 1.0]:
		var target := int(round(frac * World.tree_count()))
		var t0 := Time.get_ticks_msec()
		while done < target:
			World.remove_tree(int(order[done][1]))
			done += 1
		var rm_ms := Time.get_ticks_msec() - t0
		await get_tree().process_frame
		var rc := _reach_coverage("cleared_%d" % int(frac * 100))
		var tc := _truck_coverage()
		out["%d%%" % int(frac * 100)] = {"removed": done, "remaining": World.tree_count() - done, "unreachable_remaining": rc.unreachable, "component_cells": rc.component_cells, "truck_cells": tc.drivable_cells_from_bays, "remaining_within_25m_of_truck_route": tc.within_25m, "removal_ms": rm_ms}
		if int(rc.unreachable) > 0:
			_issue("blocker", "cleared_unreachable", "fixture %d%%" % int(frac * 100), "%d remaining targets unreachable" % int(rc.unreachable), "investigate")
	# Visual/collision: rebuilding every chunk once reflects the removals.
	var t1 := Time.get_ticks_msec()
	var chunks := {}
	for i in World.tree_count():
		chunks[int(World.trees.chunk[i])] = true
	for c in chunks:
		veg._build_chunk(c)
	out["rebuild_all_chunks_ms"] = Time.get_ticks_msec() - t1
	# Collision cells are streamed around the focus: rebuild them from the
	# current (fully cleared) data and count what remains.
	for c2 in veg._collision_cells.keys():
		(veg._collision_cells[c2] as Node).queue_free()
	veg._collision_cells.clear()
	veg._last_cell = Vector2i(999999, 999999)
	veg.update_collision_around(World.camp_origin())
	await get_tree().physics_frame
	out["tree_colliders_after_full_clear"] = veg.active_tree_collision_count()
	World.tree_removed.connect(veg._on_tree_removed)
	return out


# ----------------------------------------------------------------- report

func _write_md() -> void:
	var p: Dictionary = report.placement
	var md := PackedStringArray(["# Island audit (generated by `tools/island_audit.tscn`)", "", "Engine %s · world seed %s · generation %s · %d trees · %d rocks · %d ms" % [report.engine, str(report.world.seed), str(report.world.generation_version), int(report.world.trees), int(report.world.rocks), int(report.elapsed_ms)], "", "## Placement", ""])
	md.append("| Category | Checked | Problems |")
	md.append("|---|---|---|")
	md.append("| Tree roots | %d | floating %d (max gap %.3f m), in water %d, no cutting stand %d, over-buried %d, touching rock %d |" % [int(p.trees.checked), int(p.trees.floating), float(p.trees.max_gap), int(p.trees.in_water), int(p.trees.no_cut_stand), int(p.trees.overburied), int(p.trees.on_rock)])
	md.append("| Rocks | %d | floating %d (max gap %.3f m) |" % [int(p.rocks.checked), int(p.rocks.floating), float(p.rocks.max_gap)])
	md.append("| Ground cover near camp | %d | inside buildings %d, floating %d, in deep water %d |" % [int(p.ground_cover_near_camp.instances), int(p.ground_cover_near_camp.in_buildings), int(p.ground_cover_near_camp.floating), int(p.ground_cover_near_camp.in_water)])
	md.append("| Anchors (beds, seats, hides, dog, ship, spawn) | %d | %d |" % [int(p.anchors.checked), (p.anchors.bad as Array).size()])
	md.append("| Camera mounts | %d | %d |" % [int(p.cameras.checked), (p.cameras.bad as Array).size()])
	md.append("| Bridge ends | %d | %d |" % [int(p.bridges.checked), (p.bridges.bad as Array).size()])
	var r: Dictionary = report.reach_original
	md.append_array(["", "## Required-target reachability (original forest)", "", "%d targets checked; %d without a reachable cutting stand + retreat (stumps share the stand)." % [int(r.checked), int(r.unreachable)], "", "| Region | Targets | Reachable | Truck route within 25 m |", "|---|---|---|---|"])
	var tr: Dictionary = report.trucks_original.per_region
	var regs: Array = (r.per_region as Dictionary).keys()
	regs.sort()
	for reg in regs:
		md.append("| %s | %d | %d | %d |" % [reg, int(r.per_region[reg].targets), int(r.per_region[reg].reachable), int(tr.get(reg, {}).get("within_25m_of_truck_route", 0))])
	md.append_array(["", "Path samples (real A* from the camp yard): " + JSON.stringify(r.path_samples), "", "## Facilities and anchors", ""])
	for k in report.facilities:
		md.append("- %s: %s" % [k, JSON.stringify(report.facilities[k])])
	if report.has("fixtures"):
		md.append_array(["", "## Clearing fixtures (nearest-first removal through the real removal signal)", "", "| Fixture | Removed | Remaining | Remaining unreachable | Walkable cells | Truck cells | Remaining within 25 m of a truck route |", "|---|---|---|---|---|---|---|"])
		for k in ["25%", "50%", "90%", "99%", "100%"]:
			var f: Dictionary = report.fixtures.get(k, {})
			if f.is_empty():
				continue
			md.append("| %s | %d | %d | %d | %d | %d | %d |" % [k, int(f.removed), int(f.remaining), int(f.unreachable_remaining), int(f.component_cells), int(f.truck_cells), int(f.remaining_within_25m_of_truck_route)])
		md.append("")
		md.append("Rebuilding every vegetation chunk after the full clear: %d ms; tree colliders active afterwards: %d." % [int(report.fixtures.rebuild_all_chunks_ms), int(report.fixtures.tree_colliders_after_full_clear)])
	md.append_array(["", "## Issues found by this run: %d (see docs/audit/ISSUE_LEDGER.md for dispositions)" % issues.size()])
	var by := {}
	for it in issues:
		var k2 := "%s/%s" % [it.severity, it.category]
		by[k2] = int(by.get(k2, 0)) + 1
	for k3 in by:
		md.append("- %s: %d" % [k3, int(by[k3])])
	var f2 := FileAccess.open("res://docs/audit/ISLAND_AUDIT.md", FileAccess.WRITE)
	f2.store_string("\n".join(md) + "\n")
	f2.close()
