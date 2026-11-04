class_name CoverOverlay
extends Node3D
## Phase 12 developer overlay (Preview Tour only, hidden in ordinary play).
## Separate layers around the player, cycled by `next_layer()`:
##   soft    green cells = soft concealment density (brush/thickets)
##   hard    grey pillars = rocks tall enough to break a sightline
##   hides   magenta = hide pocket, cyan = verified exits, yellow = the
##           hunter's search approach; label says dead end or two-way
##   nav     blue = crew-walkable cells, orange = truck-drivable cells
##   support red = placement problems found live (tree/rock/shrub)
## Bounded (40 m), rebuilt every 2 s.

const RADIUS := 40.0
const LAYERS := ["all", "soft", "hard", "hides", "nav", "support"]
var layer := 0
var _t := 0.0
var _mm := {}
var _labels: Node3D


func _ready() -> void:
	_mm.soft = _make(Color(0.2, 0.9, 0.3, 0.45), true, 1.0)
	_mm.hard = _make(Color(0.75, 0.75, 0.78), false, 0.18)
	_mm.hide = _make(Color(1.0, 0.2, 0.9), false, 0.22)
	_mm.exit = _make(Color(0.2, 1.0, 1.0), false, 0.16)
	_mm.approach = _make(Color(1.0, 0.9, 0.2), false, 0.14)
	_mm.walk = _make(Color(0.25, 0.5, 1.0, 0.45), true, 0.6)
	_mm.drive = _make(Color(1.0, 0.6, 0.1, 0.5), true, 0.8)
	_mm.bad = _make(Color(1.0, 0.1, 0.1), false, 0.25)
	_labels = Node3D.new()
	add_child(_labels)


func next_layer() -> String:
	layer = (layer + 1) % LAYERS.size()
	_t = 0.0
	return LAYERS[layer]


func _make(c: Color, flat: bool, size: float) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if flat:
		var q := PlaneMesh.new()
		q.size = Vector2(size * 1.9, size * 1.9)
		mm.mesh = q
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = size
		cm.bottom_radius = size
		cm.height = 1.0
		mm.mesh = cm
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = not flat
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _on(name: String) -> bool:
	return LAYERS[layer] == "all" or LAYERS[layer] == name


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or Game.player == null:
		return
	_t = 2.0
	var p := (Game.player as Node3D).global_position
	for c in _labels.get_children():
		c.queue_free()
	var lists := {}
	for k in _mm:
		lists[k] = []
	if _on("soft") and Game.cover:
		var c0 := Vector2i(int(floor(p.x / CoverService.CELL)), int(floor(p.z / CoverService.CELL)))
		var span := int(RADIUS / CoverService.CELL)
		for dz in range(-span, span + 1):
			for dx in range(-span, span + 1):
				var c := c0 + Vector2i(dx, dz)
				var cp := Vector3((c.x + 0.5) * CoverService.CELL, 0, (c.y + 0.5) * CoverService.CELL)
				var s: Vector2 = Game.cover.soft_at(cp)
				if s.x > 0.2:
					cp.y = World.height_at(cp.x, cp.z) + 0.08
					lists.soft.append(Transform3D(Basis().scaled(Vector3.ONE * s.x), cp))
	if _on("hard"):
		for i in (World.rocks.x as PackedFloat32Array).size():
			var rp := Vector3(World.rocks.x[i], 0, World.rocks.z[i])
			if absf(rp.x - p.x) > RADIUS or absf(rp.z - p.z) > RADIUS:
				continue
			var vis := 0.7 * float(World.rocks.scale[i]) * World.rock_squash(i)
			if vis >= 1.25:
				rp.y = World.height_at(rp.x, rp.z)
				lists.hard.append(Transform3D(Basis().scaled(Vector3(1, vis + 1.0, 1)), rp + Vector3(0, (vis + 1.0) * 0.5, 0)))
	if _on("hides") and Game.cover:
		for h in Game.cover.hides:
			var hp := h.marker.global_position
			if hp.distance_to(p) > RADIUS:
				continue
			lists.hide.append(Transform3D(Basis().scaled(Vector3(1, 1.2, 1)), hp + Vector3(0, 0.6, 0)))
			for e in h.exits:
				lists.exit.append(Transform3D(Basis().scaled(Vector3(1, 1.8, 1)), e + Vector3(0, 0.9, 0)))
			lists.approach.append(Transform3D(Basis().scaled(Vector3(1, 2.6, 1)), h.approach + Vector3(0, 1.3, 0)))
			_label(hp + Vector3(0, 1.6, 0), "%s - %s" % [h.kind.replace("_", " "), "one way out" if h.dead_end else "%d exits" % h.exits.size()])
	if _on("nav") and Game.crew and Game.crew.nav and Game.crew.nav.built:
		var nav := Game.crew.nav
		var k0 := nav.to_cell(Vector2(p.x, p.z))
		for dz in range(-12, 13):
			for dx in range(-12, 13):
				var k := k0 + Vector2i(dx, dz)
				if nav._in_island(k) and not nav.grid.is_point_solid(k):
					var cc := nav.cell_center(k)
					lists.walk.append(Transform3D(Basis().scaled(Vector3.ONE * 2.2), Vector3(cc.x, nav.surface_at(Vector3(cc.x, 0, cc.y)) + 0.06, cc.y)))
		if Game.vehicles and Game.vehicles.nav:
			var dn := Game.vehicles.nav
			var d0 := dn.to_cell(Vector2(p.x, p.z))
			for dz in range(-8, 9):
				for dx in range(-8, 9):
					var k2 := d0 + Vector2i(dx, dz)
					if dn.in_grid(k2) and not dn.grid.is_point_solid(k2):
						var c2 := dn.center(k2)
						lists.drive.append(Transform3D(Basis().scaled(Vector3.ONE * 2.0), Vector3(c2.x, World.height_at(c2.x, c2.y) + 0.1, c2.y)))
	if _on("support"):
		for i in World.tree_count():
			var x: float = World.trees.x[i]
			var z: float = World.trees.z[i]
			if absf(x - p.x) > RADIUS or absf(z - p.z) > RADIUS or World.removed_trees.has(int(World.trees.id[i])):
				continue
			var base := World.tree_position(i)
			var lowest := INF
			for k in 8:
				var a := TAU * k / 8.0
				lowest = minf(lowest, World.height_at(x + cos(a) * float(World.trees.radius[i]) * 1.45, z + sin(a) * float(World.trees.radius[i]) * 1.45))
			if base.y - lowest > PlacementValidator.SUPPORT_TOLERANCE:
				lists.bad.append(Transform3D(Basis(), base + Vector3(0, 0.5, 0)))
				_label(base + Vector3(0, 1.4, 0), "tree %d floats %.2f m" % [int(World.trees.id[i]), base.y - lowest])
	for k in _mm:
		var mmi: MultiMeshInstance3D = _mm[k]
		var arr: Array = lists[k]
		mmi.multimesh.instance_count = arr.size()
		for i in arr.size():
			mmi.multimesh.set_instance_transform(i, arr[i])


func _label(at: Vector3, text: String) -> void:
	if _labels.get_child_count() > 30:
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = 28
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	_labels.add_child(l)
	l.global_position = at
