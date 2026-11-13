class_name LotMarks
extends MultiMeshInstance3D
## Phase 25: the company's paint. Every contract-lot tree wears a band of
## paint at chest height in its lot's colour (orange, blue, yellow), so the
## contract can be read in the forest. A band goes when its tree falls.

const COLORS := [Color(0.95, 0.42, 0.08), Color(0.12, 0.5, 0.92), Color(0.96, 0.82, 0.12), Color(0.85, 0.2, 0.55)]
var _slot := {}           # tree id -> instance index
var _lots: ContractLots


func _ready() -> void:
	name = "LotMarks"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if Game.campaign:
		Game.campaign.lots_changed.connect(rebuild)
	if Game.trees:
		Game.trees.tree_state_changed.connect(_on_tree)
	rebuild()


func rebuild() -> void:
	_slot.clear()
	_lots = Game.campaign.contract.lots if Game.campaign and Game.campaign.contract else null
	multimesh = null
	if _lots == null or _lots.total() == 0 or Game.vegetation == null:
		return
	var idx: Dictionary = Game.vegetation.get("tree_index_by_id")
	var band := CylinderMesh.new()
	band.top_radius = 1.0
	band.bottom_radius = 1.0
	band.height = 0.28
	band.radial_segments = 14
	band.cap_top = false
	band.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	band.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = band
	mm.instance_count = _lots.total()
	var n := 0
	for k in _lots.lots.size():
		for id in (_lots.lots[k].trees as PackedInt32Array):
			if not idx.has(id):
				continue
			var i := int(idx[id])
			var r := float(World.trees.radius[i]) * 1.08 + 0.05
			var p := World.tree_position(i) + Vector3(0, 1.3, 0)
			var gone := Game.trees != null and Game.trees.state_of(id) >= TreeService.State.FALLING
			mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(r, 1.0, r) if not gone else Vector3.ZERO), p))
			mm.set_instance_color(n, COLORS[k % COLORS.size()])
			_slot[id] = n
			n += 1
	mm.visible_instance_count = n
	multimesh = mm
	custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 400, 8000))


func _on_tree(tree_id: int, state: int) -> void:
	if multimesh == null or not _slot.has(tree_id) or state < TreeService.State.FALLING:
		return
	var n := int(_slot[tree_id])
	var t := multimesh.get_instance_transform(n)
	multimesh.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ZERO), t.origin))
