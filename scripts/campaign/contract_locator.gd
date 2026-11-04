class_name ContractLocator
extends RefCounted
## Phase 7: restrained final-item assist. Finds the nearest remaining
## required item of each kind (standing original tree, stump, undelivered
## timber) and can place a short-lived marker on one. Read-only: it never
## changes contract state.

static func nearest(from: Vector3) -> Dictionary:
	var out := {}
	var trees: TreeService = Game.trees
	var best := INF
	var best_p := Vector3.INF
	for i in World.tree_count():
		var id := int(World.trees.id[i])
		if World.removed_trees.has(id):
			continue
		if trees and trees.records.has(id) and int(trees.records[id].state) >= TreeService.State.FALLING:
			continue
		var p := World.tree_position(i)
		var d := p.distance_squared_to(from)
		if d < best:
			best = d
			best_p = p
	if best_p != Vector3.INF:
		out["tree"] = best_p
	if trees:
		var idx: Dictionary = Game.vegetation.get("tree_index_by_id") if Game.vegetation else {}
		best = INF
		best_p = Vector3.INF
		for id in trees.records:
			if int(trees.records[id].state) == TreeService.State.SECTIONED and idx.has(int(id)):
				var p2 := World.tree_position(int(idx[int(id)]))
				var d2 := p2.distance_squared_to(from)
				if d2 < best:
					best = d2
					best_p = p2
		if best_p != Vector3.INF:
			out["stump"] = best_p
	if Game.timber:
		best = INF
		best_p = Vector3.INF
		for key in Game.timber.bodies:
			var b: Node3D = Game.timber.bodies[key]
			var d3 := b.global_position.distance_squared_to(from)
			if d3 < best:
				best = d3
				best_p = b.global_position
		if best_p != Vector3.INF:
			out["log"] = best_p
	return out


static func describe(from: Vector3, p: Vector3) -> String:
	var d := p - from
	var dist := Vector2(d.x, d.z).length()
	var dirs := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var a := fposmod(atan2(d.x, -d.z), TAU)
	return "%d m %s" % [roundi(dist), dirs[int(round(a / (TAU / 8.0))) % 8]]


## A thin, temporary light column at p (60 s), visible over the canopy.
static func mark(parent: Node, p: Vector3) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.12
	cm.height = 40.0
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = p + Vector3(0, 20.0, 0)
	parent.get_tree().create_timer(60.0, false).timeout.connect(m.queue_free)
