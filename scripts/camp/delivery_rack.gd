class_name DeliveryRack
extends Node3D
## Phase 13: this is the yard's RECEIVING CRADLE. Delivered logs need a free
## cradle slot (CampLayout.CRADLE_SLOTS) to be accepted; accepted logs lie
## here (paid) until someone carries them to a log deck. The sign and the
## meter show what is really in the cradle; the burn backlog is on the
## fire's loading pile and the decks.
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
		if Game.yard and Game.yard.is_yard_move(str(Game.timber.carried[0])):
			return "Paid logs go on a deck or the fire's loading pile"
		var mte := Game.timber.carried_mte()
		return "Deliver %d log%s to receiving (%.2f tree-equivalent)" % [Game.timber.carried.size(), "" if Game.timber.carried.size() == 1 else "s", mte / 1000.0]
	if Game.yard and not Game.yard.cradle.is_empty():
		return "Carry a log to the decks (%d in the cradle)" % Game.yard.cradle.size()
	return "Receiving cradle: %s" % _status_short()


func interact(by: Node) -> void:
	if by.get("carry") and by.carry.is_carrying():
		if Game.yard and Game.yard.is_yard_move(str(Game.timber.carried[0])):
			if by.has_method("show_message"):
				by.show_message("These logs are already paid for. Stack them on a yard deck (outside the north gate, east) or put them on the fire's loading pile.")
			return
		deliver_from(by)
	elif Game.yard and not Game.yard.cradle.is_empty():
		var budget: int = by.carry.budget() if by.get("carry") else TimberService.HAND_BUDGET_MTE
		var sid := Game.yard.take_from_cradle("player", budget, global_position)
		if by.has_method("show_message"):
			by.show_message(("Take it to deck %s (outside the north gate, east) and press %s there." % [str(Game.yard.moving[sid].dest).get_slice(":", 1).to_int() + 1, Keys.label("interact")]) if sid != "" else Game.yard.last_reason)
	elif by.has_method("show_message"):
		by.show_message("Receiving cradle: %s. Carry cut logs here and press %s." % [_status_short(), Keys.label("interact")])


func deliver_from(by: Node) -> void:
	var t: TimberService = Game.timber
	if t == null or t.carried.is_empty():
		return
	var rs := t.accept(t.carried.duplicate(), "rack:player", global_position)
	var cents := 0
	for r in rs:
		cents += int(r.cents)
	if not rs.is_empty():
		LoggingFX.play(LoggingFX.Sound.CLUNK, global_position + Vector3(0, 0.6, 0), 0.0, {"event": "log.drop.rack"})
	if by.has_method("show_message"):
		if rs.is_empty():
			by.show_message("Not accepted: %s" % t.last_refusal)
		else:
			by.show_message("Delivered %d log%s to receiving. Contract entitlement +$%s.%s" % [rs.size(), "" if rs.size() == 1 else "s", Money.format_cents(cents), (" %d still in hand: %s" % [t.carried.size(), t.last_refusal]) if not t.carried.is_empty() else ""])


func _status_short() -> String:
	var t: TimberService = Game.timber
	if t == null:
		return "empty"
	if Game.yard:
		return "%d/%d slots used, decks %d logs, fire pile %d, burning %d" % [Game.yard.cradle.size(), CampLayout.CRADLE_SLOTS, Game.yard.stock_count() - Game.yard.cradle.size(), t.queue.size(), t.burning.size()]
	return "%d waiting (%.2f tree-eq), %d burning" % [t.queue.size(), t.queue_mte() / 1000.0, t.burning.size()]


# ------------------------------------------------------------------ visuals

func _refresh() -> void:
	var t: TimberService = Game.timber
	if t == null:
		return
	var shown: Array[String] = []
	var src: Array = Game.yard.cradle if Game.yard else t.queue
	for sid in src:
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
	var total := 0
	for sid in src:
		total += int(t.segment(str(sid)).mte)
	var hidden := maxi(src.size() - VISIBLE, 0)
	if Game.yard:
		_sign.text = "RECEIVING\nIn cradle %d/%d  (%.2f tree-eq)%s\nDecks %.2f tree-eq\nAccepted total: %.2f trees" % [src.size(), CampLayout.CRADLE_SLOTS, total / 1000.0, ("\n+%d more not shown" % hidden) if hidden > 0 else "", (Game.yard.stock_mte() - total) / 1000.0, t.totals().accepted_mte / 1000.0]
	else:
		_sign.text = "DELIVERY\nQueued %d  (%.2f tree-eq)%s\nIn the pit: %d\nAccepted total: %.2f trees" % [t.queue.size(), total / 1000.0, ("\n+%d more not shown" % hidden) if hidden > 0 else "", t.burning.size(), t.totals().accepted_mte / 1000.0]
	var f := clampf(total / 1000.0, 0.0, 1.0)
	_meter_fill.scale = Vector3(1, maxf(f, 0.01), 1)
	_meter_fill.position.y = 0.41 + 0.3 * maxf(f, 0.01)
