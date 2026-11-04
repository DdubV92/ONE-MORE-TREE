class_name AuditOverlay
extends Node3D
## Phase 7 development overlay (Preview Tour only, off by default): around
## the player it shows each tree's support samples (green = supported,
## red = gap > tolerance), anchors with their measured support gap, and the
## crew/truck navigation cells (blue walkable, orange drivable) so a
## reviewer can see what the audit measured. Rebuilt every 2 s, bounded.

const RADIUS := 30.0
var _t := 0.0
var _mm_ok: MultiMeshInstance3D
var _mm_bad: MultiMeshInstance3D
var _mm_walk: MultiMeshInstance3D
var _mm_drive: MultiMeshInstance3D
var _labels: Node3D


func _ready() -> void:
	_mm_ok = _make(Color(0.2, 1.0, 0.3), 0.06)
	_mm_bad = _make(Color(1.0, 0.15, 0.1), 0.12)
	_mm_walk = _make(Color(0.25, 0.5, 1.0, 0.5), 0.12, true)
	_mm_drive = _make(Color(1.0, 0.6, 0.1, 0.6), 0.2, true)
	_labels = Node3D.new()
	add_child(_labels)


func _make(c: Color, size: float, flat := false) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh: Mesh
	if flat:
		var q := PlaneMesh.new()
		q.size = Vector2(size * 5.0, size * 5.0)
		mesh = q
	else:
		var sm := SphereMesh.new()
		sm.radius = size
		sm.height = size * 2.0
		mesh = sm
	mm.mesh = mesh
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = not flat
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or Game.player == null:
		return
	_t = 2.0
	var p := (Game.player as Node3D).global_position
	var ok: Array[Transform3D] = []
	var bad: Array[Transform3D] = []
	for c in _labels.get_children():
		c.queue_free()
	for i in World.tree_count():
		var x: float = World.trees.x[i]
		var z: float = World.trees.z[i]
		if absf(x - p.x) > RADIUS or absf(z - p.z) > RADIUS or World.removed_trees.has(int(World.trees.id[i])):
			continue
		var base := World.tree_position(i)
		var r: float = World.trees.radius[i]
		var lowest := INF
		for k in 8:
			var a := TAU * k / 8.0
			var sp := Vector3(x + cos(a) * r * 1.45, 0, z + sin(a) * r * 1.45)
			sp.y = World.height_at(sp.x, sp.z)
			lowest = minf(lowest, sp.y)
			ok.append(Transform3D(Basis(), sp + Vector3(0, 0.03, 0)))
		var gap := base.y - lowest
		if gap > PlacementValidator.SUPPORT_TOLERANCE:
			bad.append(Transform3D(Basis(), base + Vector3(0, 0.3, 0)))
			_label(base + Vector3(0, 1.2, 0), "tree %d gap %.2f m" % [int(World.trees.id[i]), gap])
	var space := get_world_3d().direct_space_state
	for g in ["worker_bed", "player_bed", "hiding_spot", "dog_bed", "dog_refuge", "couch_seat", "arcade_spot"]:
		for n in get_tree().get_nodes_in_group(g):
			var ap: Vector3 = (n as Node3D).global_position
			if ap.distance_to(p) > RADIUS:
				continue
			var q := PhysicsRayQueryParameters3D.create(ap + Vector3(0, 0.3, 0), ap - Vector3(0, 2.5, 0), 1)
			var hit := space.intersect_ray(q)
			var below := (ap - (hit.position as Vector3)).y if not hit.is_empty() else 9.9
			(ok if below < 1.0 else bad).append(Transform3D(Basis(), ap))
			_label(ap + Vector3(0, 0.4, 0), "%s %s: %.2f m" % [g, n.name, below])
	_fill(_mm_ok, ok)
	_fill(_mm_bad, bad)
	var walk: Array[Transform3D] = []
	var drive: Array[Transform3D] = []
	if Game.crew and Game.crew.nav and Game.crew.nav.built:
		var nav := Game.crew.nav
		var k0 := nav.to_cell(Vector2(p.x, p.z))
		for dz in range(-8, 9):
			for dx in range(-8, 9):
				var k := k0 + Vector2i(dx, dz)
				if nav._in_island(k) and not nav.grid.is_point_solid(k):
					var cc := nav.cell_center(k)
					walk.append(Transform3D(Basis(), Vector3(cc.x, nav.surface_at(Vector3(cc.x, 0, cc.y)) + 0.05, cc.y)))
	if Game.vehicles and Game.vehicles.nav:
		var dn := Game.vehicles.nav
		var d0 := dn.to_cell(Vector2(p.x, p.z))
		for dz in range(-6, 7):
			for dx in range(-6, 7):
				var k2 := d0 + Vector2i(dx, dz)
				if dn.in_grid(k2) and not dn.grid.is_point_solid(k2):
					var c2 := dn.center(k2)
					drive.append(Transform3D(Basis(), Vector3(c2.x, World.height_at(c2.x, c2.y) + 0.08, c2.y)))
	_fill(_mm_walk, walk)
	_fill(_mm_drive, drive)


func _fill(mmi: MultiMeshInstance3D, xs: Array[Transform3D]) -> void:
	mmi.multimesh.instance_count = xs.size()
	for i in xs.size():
		mmi.multimesh.set_instance_transform(i, xs[i])


func _label(at: Vector3, text: String) -> void:
	if _labels.get_child_count() > 40:
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = 28
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(1, 1, 0.7)
	_labels.add_child(l)
	l.global_position = at
