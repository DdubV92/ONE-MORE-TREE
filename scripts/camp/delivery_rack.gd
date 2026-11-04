class_name DeliveryRack
extends Node3D
## Accepted-delivery rack beside the burn pit (Phase 2). Carrying logs here
## and pressing E (or G while standing at the rack) commits one acceptance
## transaction per piece through TimberService.accept() - the ONLY place a
## delivery receipt (the $100-per-tree entitlement share) is created.
## Accepted pieces stack on the cradle in queue order; the pit takes the
## oldest three. The stack shows at most VISIBLE pieces; the meter and the
## sign always report the full backlog honestly.
##
## Future hooks (no behaviour yet): worker standpoints (group
## "delivery_standpoint"), truck drop-off anchor ("truck_dropoff"); workers
## and trucks call TimberService.accept(sids, source) directly - no player
## or camera ray is involved.

const VISIBLE := 12

var _stack_root: Node3D
var _stack_nodes := {}          # sid -> MeshInstance3D
var _sign: Label3D
var _meter_fill: MeshInstance3D


func _ready() -> void:
	add_to_group("delivery_rack")
	_build_frame()
	_stack_root = Node3D.new()
	_stack_root.name = "Stack"
	add_child(_stack_root)
	var o := CampLayout.DELIVERY_RACK_POS
	for i in CampLayout.DELIVERY_STANDPOINTS.size():
		var sp: Vector3 = CampLayout.DELIVERY_STANDPOINTS[i]
		BuildKit.marker(self, "Standpoint%d" % i, sp - o, PI, "delivery_standpoint")
	BuildKit.marker(self, "TruckDropoff", CampLayout.TRUCK_DROPOFF - o, 0.0, "truck_dropoff")
	BuildKit.marker(self, "RecoveryPoint", CampLayout.RECOVERY_POINT - o, 0.0, "timber_recovery_point")
	if Game.timber:
		Game.timber.queue_changed.connect(_refresh)
	_refresh.call_deferred()


func _build_frame() -> void:
	var size := CampLayout.DELIVERY_RACK_SIZE
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	# Two H-shaped log cradles with uprights that keep the stack in place.
	for sx in [-hx + 0.3, hx - 0.3]:
		BuildKit.box(self, Vector3(0.16, 0.16, size.z), Vector3(sx, 0.08, 0), "dark_wood", false)
		BuildKit.box(self, Vector3(0.14, 0.12, size.z - 0.1), Vector3(sx, 0.36, 0), "dark_wood", false)
		for sz in [-hz + 0.08, hz - 0.08]:
			BuildKit.box(self, Vector3(0.12, size.y, 0.12), Vector3(sx, size.y * 0.5, sz), "dark_wood", false)
	# Ground boards under the stack.
	for i in 5:
		BuildKit.box(self, Vector3(size.x, 0.04, 0.22), Vector3(0, 0.02, -hz + 0.2 + i * (size.z - 0.4) / 4.0), "planks", false)
	# Sign post + meter facing the camp (+Z).
	BuildKit.box(self, Vector3(0.1, 1.6, 0.1), Vector3(hx + 0.35, 0.8, hz - 0.1), "dark_wood", false)
	BuildKit.box(self, Vector3(0.9, 0.5, 0.04), Vector3(hx + 0.35, 1.45, hz - 0.05), "planks", false)
	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.position = Vector3(hx + 0.35, 1.48, hz - 0.02)
	_sign.pixel_size = 0.0022
	_sign.font_size = 32
	_sign.outline_size = 0
	_sign.modulate = Color(0.12, 0.08, 0.05)
	_sign.width = 380.0
	_sign.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_sign)
	# Queue meter: a vertical gauge (full = one tree-equivalent waiting).
	BuildKit.box(self, Vector3(0.08, 0.62, 0.03), Vector3(hx + 0.35 + 0.52, 1.0, hz - 0.04), "black", false)
	_meter_fill = BuildKit.box(self, Vector3(0.05, 0.6, 0.02), Vector3(hx + 0.35 + 0.52, 0.71, hz - 0.01), "lamp_bulb", false)
	set_meta("no_batch", true)
	# One collision box: the stack area is solid, you deliver from beside it.
	var body := StaticBody3D.new()
	body.name = "RackBody"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(size.x, size.y, size.z)
	cs.shape = bx
	cs.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(cs)
	add_child(body)


# -------------------------------------------------------------- interaction

func get_interact_text() -> String:
	var p := Game.player
	if p and p.get("carry") and p.carry.is_carrying():
		var mte := Game.timber.carried_mte()
		return "Deliver %d log%s (%.2f tree-equivalent)" % [Game.timber.carried.size(), "" if Game.timber.carried.size() == 1 else "s", mte / 1000.0]
	return "Delivery rack: %s" % _status_short()


func interact(by: Node) -> void:
	if by.get("carry") and by.carry.is_carrying():
		deliver_from(by)
	elif by.has_method("show_message"):
		by.show_message("Delivery rack: %s. Carry cut logs here and press %s." % [_status_short(), Keys.label("interact")])


func deliver_from(by: Node) -> void:
	var t: TimberService = Game.timber
	if t == null or t.carried.is_empty():
		return
	var rs := t.accept(t.carried.duplicate(), "rack:player")
	var cents := 0
	for r in rs:
		cents += int(r.cents)
	LoggingFX.play(LoggingFX.Sound.CLUNK, global_position + Vector3(0, 0.6, 0), -6.0)
	if by.has_method("show_message"):
		by.show_message("Delivered %d log%s. Contract entitlement +$%s." % [rs.size(), "" if rs.size() == 1 else "s", Money.format_cents(cents)])


func _status_short() -> String:
	var t: TimberService = Game.timber
	if t == null:
		return "empty"
	return "%d waiting (%.2f tree-eq), %d burning" % [t.queue.size(), t.queue_mte() / 1000.0, t.burning.size()]


# ------------------------------------------------------------------ visuals

func _refresh() -> void:
	var t: TimberService = Game.timber
	if t == null:
		return
	var shown: Array[String] = []
	for sid in t.queue:
		if shown.size() >= VISIBLE:
			break
		shown.append(sid)
	for sid in _stack_nodes.keys():
		if not sid in shown:
			(_stack_nodes[sid] as Node).queue_free()
			_stack_nodes.erase(sid)
	# Stack from the far end in rows of three, newest on top.
	var size := CampLayout.DELIVERY_RACK_SIZE
	for i in shown.size():
		var sid := shown[shown.size() - 1 - i]
		var mi: MeshInstance3D = _stack_nodes.get(sid)
		var s := t.segment(sid)
		var rec: Dictionary = t.records[int(sid.trim_prefix("T").split("_S")[0])]
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = "Q_%s" % sid
			mi.mesh = TimberMesh.piece_mesh(rec, int(s.k))
			_stack_root.add_child(mi)
			_stack_nodes[sid] = mi
		var r := TimberMesh.piece_radius(rec, int(s.k))
		var row := i / 3
		var col := i % 3
		var z := (float(col) - 1.0) * (size.z - 0.4) / 3.0 + (0.12 if row % 2 == 1 else 0.0)
		mi.basis = TimberMesh.frame_for(Vector3.RIGHT)
		mi.position = Vector3(0, 0.42 + r + float(row) * r * 1.75, z)
	var total := t.queue_mte()
	var hidden := maxi(t.queue.size() - VISIBLE, 0)
	_sign.text = "DELIVERY\nQueued %d  (%.2f tree-eq)%s\nIn the pit: %d\nAccepted total: %.2f trees" % [t.queue.size(), total / 1000.0, ("\n+%d more not shown" % hidden) if hidden > 0 else "", t.burning.size(), t.totals().accepted_mte / 1000.0]
	var f := clampf(total / 1000.0, 0.0, 1.0)
	_meter_fill.scale = Vector3(1, maxf(f, 0.01), 1)
	_meter_fill.position.y = 0.41 + 0.3 * maxf(f, 0.01)
