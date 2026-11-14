class_name MapView
extends Control
## Phase 28: draws the boss's map in the Journal (IslandMap supplies the
## picture; this adds the marks). Real state only, nothing that hunts.

const LOT_COLORS := [Color(0.95, 0.42, 0.08), Color(0.12, 0.5, 0.92), Color(0.96, 0.82, 0.12)]

const ZOOM_NEAR := 5.0              # "around you" magnification

var map: IslandMap
var zoom := 1.0                     # 1 = the whole island
var _tex: ImageTexture


func setup(m: IslandMap) -> void:
	map = m
	custom_minimum_size = Vector2(640, 330)
	clip_contents = true
	if map:
		_tex = ImageTexture.create_from_image(map.compose())
	queue_redraw()


func toggle_zoom() -> void:
	zoom = ZOOM_NEAR if zoom == 1.0 else 1.0
	queue_redraw()


## Where the whole picture sits in this control (larger than the control
## when zoomed in, and shifted so the boss is in the middle).
func _rect() -> Rect2:
	if _tex == null:
		return Rect2(Vector2.ZERO, size)
	var ts := _tex.get_size()
	var k := minf(size.x / ts.x, size.y / ts.y) * zoom
	var s := ts * k
	var r := Rect2((size - s) * 0.5, s)
	if zoom > 1.0 and Game.player:
		var p := Game.player as Node3D
		var at := IslandMap.to_px(p.global_position.x, p.global_position.z, s)
		r.position = size * 0.5 - at
		r.position.x = clampf(r.position.x, size.x - s.x, 0.0)
		r.position.y = clampf(r.position.y, size.y - s.y, 0.0)
	return r


func _pt(x: float, z: float, r: Rect2) -> Vector2:
	return r.position + IslandMap.to_px(x, z, r.size)


## Everything the map marks, as data (also used by tests).
func marks() -> Array:
	var out: Array = []
	var o := World.camp_origin()
	out.append({"kind": "camp", "x": o.x, "z": o.z, "label": "Camp"})
	if Game.mill:
		var m := CampLayout.world(CampLayout.MILL_SAW_POS)
		out.append({"kind": "mill", "x": m.x, "z": m.z, "label": "Sawmill"})
	if Game.crew and Game.crew.dock_shore != Vector3.ZERO:
		out.append({"kind": "dock", "x": Game.crew.dock_shore.x, "z": Game.crew.dock_shore.z, "label": "Dock"})
	var cs: CampaignService = Game.campaign
	var lots: ContractLots = cs.contract.lots if cs and cs.contract else null
	if lots and Game.vegetation and Game.trees:
		var idx: Dictionary = Game.vegetation.get("tree_index_by_id")
		for k in lots.lots.size():
			for id in (lots.lots[k].trees as PackedInt32Array):
				if not idx.has(id):
					continue
				var i := int(idx[id])
				out.append({"kind": "lot_tree", "lot": k, "x": World.trees.x[i], "z": World.trees.z[i], "standing": Game.trees.state_of(id) < TreeService.State.FALLING})
	if lots and str(lots.one_more.state) == "accepted" and Game.vegetation:
		var oidx: Dictionary = Game.vegetation.get("tree_index_by_id")
		if oidx.has(int(lots.one_more.tree)):
			var oi := int(oidx[int(lots.one_more.tree)])
			out.append({"kind": "one_more", "x": World.trees.x[oi], "z": World.trees.z[oi], "label": "One more tree"})
	if Game.night_kit:
		for l in Game.night_kit.lamps:
			out.append({"kind": "lamp", "x": l.global_position.x, "z": l.global_position.z, "label": "Work lamp"})
	if Game.crew and Game.crew.missing.active() and Game.crew.missing.state != "found":
		# Where they were last working, not where they are.
		var w: Worker = Game.crew.workers.get(Game.crew.missing.id)
		if w:
			var f := Game.crew.work_focus(w)
			out.append({"kind": "last_seen", "x": f.x, "z": f.z, "label": "%s last seen working here" % str(w.emp.name)})
	if Game.hunt and Game.hunt.hunt_active() and Game.hunt.beacon and Game.hunt.beacon.active:
		var b: EscapeBeacon = Game.hunt.beacon
		for part in EscapeBeacon.PARTS:
			# Only once the beacon has been checked (it lists where the spares are).
			if b.where.has(part) and b.sites.has(part) and str(b.part_state.get(part, "")) == "missing":
				var s: Vector3 = b.sites[part]
				out.append({"kind": "part", "x": s.x, "z": s.z, "label": str(EscapeBeacon.LABEL[part]).capitalize()})
	if Game.player:
		var p := Game.player as Node3D
		var fw := -p.global_basis.z
		out.append({"kind": "you", "x": p.global_position.x, "z": p.global_position.z, "yaw": atan2(fw.x, fw.z)})
	return out


func _draw() -> void:
	var r := _rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.1))
	if _tex:
		draw_texture_rect(_tex, r, false)
	var font := ThemeDB.fallback_font
	var dot := 1.0 if zoom == 1.0 else 2.0
	for m in marks():
		var at := _pt(float(m.x), float(m.z), r)
		match str(m.kind):
			"lot_tree":
				var c: Color = LOT_COLORS[int(m.lot) % LOT_COLORS.size()]
				if bool(m.standing):
					draw_circle(at, 2.2 * dot, c)
				else:
					draw_circle(at, 1.4 * dot, c.darkened(0.55))
			"camp":
				draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), Color(0.95, 0.92, 0.85))
				draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), Color(0.1, 0.1, 0.1), false, 1.5)
				draw_string(font, at + Vector2(8, 4), "Camp", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.08, 0.08, 0.08))
			"mill":
				draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(0.1, 0.1, 0.1))
				draw_string(font, at + Vector2(-56, -4), str(m.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.08, 0.08, 0.08))
			"dock":
				draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(0.1, 0.1, 0.1))
				draw_string(font, at + Vector2(6, 12), str(m.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.08, 0.08, 0.08))
			"one_more":
				draw_circle(at, 5.0, Color(0.97, 0.97, 0.95))
				draw_arc(at, 5.0, 0.0, TAU, 16, Color(0.1, 0.1, 0.1), 1.5)
				draw_string(font, at + Vector2(8, 4), str(m.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.08, 0.08, 0.08))
			"lamp":
				draw_circle(at, 4.0, Color(1.0, 0.95, 0.5))
				draw_arc(at, 6.0, 0.0, TAU, 16, Color(0.2, 0.18, 0.1), 1.0)
			"last_seen":
				draw_arc(at, 9.0, 0.0, TAU, 20, Color(0.75, 0.1, 0.1), 2.0)
				draw_string(font, at + Vector2(-3, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.1, 0.1))
			"part":
				draw_line(at - Vector2(5, 5), at + Vector2(5, 5), Color(0.75, 0.1, 0.1), 2.0)
				draw_line(at - Vector2(5, -5), at + Vector2(5, -5), Color(0.75, 0.1, 0.1), 2.0)
				draw_string(font, at + Vector2(7, 4), str(m.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.05, 0.05))
			"you":
				var yaw := float(m.yaw)
				var f := Vector2(sin(yaw), cos(yaw))
				var s := Vector2(f.y, -f.x)
				draw_colored_polygon(PackedVector2Array([at + f * 9.0, at - f * 5.0 + s * 5.0, at - f * 5.0 - s * 5.0]), Color(0.85, 0.12, 0.1))
	# North and scale (fixed to the view, not the picture).
	var v0 := Vector2(maxf(r.position.x, 0.0), maxf(r.position.y, 0.0))
	var v1 := Vector2(minf(r.end.x, size.x), minf(r.end.y, size.y))
	draw_rect(Rect2(v0, v1 - v0), Color(0.2, 0.18, 0.15), false, 2.0)
	draw_string(font, v0 + Vector2(8, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.1))
	draw_line(v0 + Vector2(13, 22), v0 + Vector2(13, 40), Color(0.1, 0.1, 0.1), 2.0)
	var per_px := IslandMap.bounds().size.x / maxf(r.size.x, 1.0)
	var metres := 100.0 if zoom == 1.0 else 20.0
	var bar := metres / per_px
	var b0 := Vector2(v0.x + 10, v1.y - 12)
	draw_line(b0, b0 + Vector2(bar, 0), Color(0.1, 0.1, 0.1), 2.0)
	draw_string(font, b0 + Vector2(bar + 6, 4), "%d m" % int(metres), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.1, 0.1))
