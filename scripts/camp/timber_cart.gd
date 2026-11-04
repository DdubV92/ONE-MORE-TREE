class_name TimberCart
extends Node3D
## Phase 13 early handcart (log trolley). Available from day 1 at the camp
## (CampLayout.CART_PARK); no truck purchase needed.
##   - Load: carry logs to it, or drag an oversized log up to it and roll it
##     on (interact). Its load is a TimberService carrier ("cart:1"), so the
##     pieces stay unpaid, owned and visible on the bed.
##   - Push: interact on the handle; the cart rolls ahead of you on its
##     wheels (terrain-following, bounded turning, cannot pass solids). Let
##     go any time (interact on it, or X); it parks where it stands.
##   - Unload: push it beside the receiving cradle or a yard deck and
##     interact: each log needs a free yard place, and only logs that get
##     one are accepted and paid (the rest stay on the cart, with a reason).
## Limits (provisional, from measured plan-v2 pieces): up to 4 logs and 1.1
## tree-equivalents; logs up to 3.0 m long. Workers do not use the cart.

const CARRIER := "cart:1"
const MAX_PIECES := 4
const BUDGET_MTE := 1100
const MAX_LEN := 3.0
const AHEAD := 1.75             # cart centre ahead of the pusher (m)
const MAX_YAW_RATE := 1.6       # rad/s (bounded turning)
const SNAG_DIST := 3.2          # auto-release if the cart falls this far behind
const SIZE := Vector3(1.15, 0.55, 2.3)

var pusher: Node3D = null
var _body: StaticBody3D
var _logs_root: Node3D
var _log_nodes: Array[Node3D] = []
var yaw := 0.0


func setup(at: Vector3, yaw_: float) -> void:
	add_to_group("timber_cart")
	yaw = yaw_
	_build()
	_place(at, yaw)
	if Game.timber:
		Game.timber.carried_changed.connect(_refresh_logs)


func _build() -> void:
	var wood := BuildKit.mat("planks")
	var metal := BuildKit.mat("steel")
	# Bed with low side rails; wheels on one axle; a pull handle.
	BuildKit.box(self, Vector3(SIZE.x, 0.06, SIZE.z), Vector3(0, 0.52, 0), wood, false, 0.0, "Bed")
	for sx in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.05, 0.16, SIZE.z), Vector3(sx * SIZE.x * 0.5, 0.62, 0), wood, false, 0.0, "Rail")
		var wheel := BuildKit.cylinder(self, 0.34, 0.09, Vector3(sx * (SIZE.x * 0.5 + 0.07), 0.34, 0.15), "rubber", false, 16)
		wheel.rotation.z = PI * 0.5
		var hub := BuildKit.cylinder(self, 0.09, 0.11, Vector3(sx * (SIZE.x * 0.5 + 0.07), 0.34, 0.15), metal, false, 10)
		hub.rotation.z = PI * 0.5
	BuildKit.box(self, Vector3(SIZE.x + 0.1, 0.05, 0.05), Vector3(0, 0.34, 0.15), metal, false, 0.0, "Axle")
	# Rear stand legs (rest on the ground when parked).
	for sx in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.05, 0.5, 0.05), Vector3(sx * SIZE.x * 0.4, 0.27, -SIZE.z * 0.45), metal, false)
	# Handle toward +Z (the pusher's side).
	for sx in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.04, 0.04, 0.9), Vector3(sx * 0.35, 0.72, SIZE.z * 0.5 + 0.42), metal, false)
	BuildKit.box(self, Vector3(0.74, 0.05, 0.05), Vector3(0, 0.74, SIZE.z * 0.5 + 0.86), metal, false, 0.0, "Grip")
	_body = StaticBody3D.new()
	_body.name = "CartBody"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(SIZE.x + 0.2, 0.75, SIZE.z + 0.9)
	cs.shape = bx
	cs.position = Vector3(0, 0.45, 0.3)
	_body.add_child(cs)
	add_child(_body)
	_logs_root = Node3D.new()
	_logs_root.name = "Load"
	add_child(_logs_root)


## Grounded pose: wheel contact and stand legs on the terrain/floor.
func _place(at: Vector3, y_: float) -> void:
	var fwd := Vector3(sin(y_), 0, cos(y_))
	var g_front := _ground(at + fwd * 0.15)
	var g_back := _ground(at - fwd * SIZE.z * 0.45)
	var pitch := atan2(g_front - g_back, SIZE.z * 0.6)
	global_transform = Transform3D(Basis(Vector3.UP, y_) * Basis(Vector3.RIGHT, -pitch), Vector3(at.x, (g_front + g_back) * 0.5, at.z))


func _ground(p: Vector3) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.0, 0), p - Vector3(0, 3.0, 0), 1)
		q.exclude = [_body.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return (hit.position as Vector3).y
	return World.height_at(p.x, p.z)


# ----------------------------------------------------------- interaction

func load_sids() -> Array:
	return Game.timber.load_of(CARRIER) if Game.timber else []


func load_mte() -> int:
	return Game.timber.carrier_mte(CARRIER) if Game.timber else 0


func _near_receiving() -> String:
	var p := global_position
	var rack := CampLayout.world(CampLayout.DELIVERY_RACK_POS)
	if Vector2(p.x - rack.x, p.z - rack.z).length() < 6.0:
		return "cradle"
	for i in CampLayout.YARD_DECKS.size():
		var d := CampLayout.world(CampLayout.YARD_DECKS[i].center)
		if Vector2(p.x - d.x, p.z - d.z).length() < 5.5:
			return "deck %d" % (i + 1)
	return ""


func get_interact_text() -> String:
	var t: TimberService = Game.timber
	if t == null:
		return ""
	if pusher != null:
		var where := _near_receiving()
		if where != "" and not load_sids().is_empty():
			return "Unload %d log%s into %s" % [load_sids().size(), "" if load_sids().size() == 1 else "s", "the receiving cradle" if where == "cradle" else where]
		return "Let go of the cart"
	if not t.carried.is_empty():
		if Game.yard and Game.yard.is_yard_move(str(t.carried[0])):
			return "Paid logs go on a deck or the fire, not the cart"
		return "%s onto the cart (%d/%d)" % ["Roll the log" if t.is_dragging("player", _budget()) else "Load %d log%s" % [t.carried.size(), "" if t.carried.size() == 1 else "s"], load_sids().size(), MAX_PIECES]
	if not load_sids().is_empty():
		return "Push the cart (%d log%s, %.2f tree-eq)" % [load_sids().size(), "" if load_sids().size() == 1 else "s", load_mte() / 1000.0]
	return "Push the cart (empty)"


func _budget() -> int:
	var p := Game.player
	return p.carry.budget() if p and p.get("carry") else TimberService.HAND_BUDGET_MTE


func interact(by: Node) -> void:
	var t: TimberService = Game.timber
	if t == null:
		return
	var msg := ""
	if pusher != null:
		var where := _near_receiving()
		if where != "" and not load_sids().is_empty():
			var rs := t.accept(load_sids().duplicate(), "cart", global_position)
			var cents := 0
			for r in rs:
				cents += int(r.cents)
			_refresh_logs()
			msg = "Unloaded %d log%s, accepted: +$%s." % [rs.size(), "" if rs.size() == 1 else "s", Money.format_cents(cents)] if not rs.is_empty() else t.last_refusal
			if not load_sids().is_empty() and not rs.is_empty():
				msg += " %d left on the cart: %s" % [load_sids().size(), t.last_refusal]
			if not rs.is_empty():
				LoggingFX.play(LoggingFX.Sound.CLUNK, global_position + Vector3(0, 0.6, 0), 0.0, {"event": "log.drop.rack"})
		else:
			release()
			msg = "Cart parked."
	elif not t.carried.is_empty():
		if Game.yard and Game.yard.is_yard_move(str(t.carried[0])):
			msg = "These logs are already paid for: stack them on a deck or take them to the fire."
		else:
			var n := 0
			for sid in t.carried.duplicate():
				var s := t.segment(str(sid))
				if load_sids().size() >= MAX_PIECES:
					msg = "The cart is full (%d logs)." % MAX_PIECES
					break
				var rec: Dictionary = t.records[int(str(sid).trim_prefix("T").split("_S")[0])]
				if TimberMesh.piece_length(rec, int(s.k)) > MAX_LEN:
					msg = "That log is too long for the cart."
					continue
				if t.transfer("player", CARRIER, str(sid), BUDGET_MTE):
					n += 1
				else:
					msg = "Too heavy for the cart (%.2f of %.2f tree-eq)." % [load_mte() / 1000.0, BUDGET_MTE / 1000.0]
			if n > 0:
				msg = "Loaded %d log%s onto the cart (%d/%d)." % [n, "" if n == 1 else "s", load_sids().size(), MAX_PIECES] + ((" " + msg) if msg != "" else "")
				LoggingFX.play(LoggingFX.Sound.CLUNK, global_position + Vector3(0, 0.6, 0), 0.0, {"event": "log.drop.cart"})
	else:
		grab(by as Node3D)
		msg = "Pushing the cart. %s at the cradle or a deck unloads it; %s or %s again lets go." % [Keys.label("interact"), Keys.label("interact"), Keys.label("drop")]
	if msg != "" and by.has_method("show_message"):
		by.show_message(msg)


func grab(by: Node3D) -> void:
	if by == null:
		return
	pusher = by
	if by.get("pushing_cart") != null:
		by.set("pushing_cart", self)


func release() -> void:
	if pusher and pusher.get("pushing_cart") != null:
		pusher.set("pushing_cart", null)
	pusher = null


# -------------------------------------------------------------- pushing

var _roll_h := 0
var _roll_kind := ""


## Phase 15: wheels on the real ground (dirt vs boards), louder with
## speed; a squeak now and then; silent when parked.
func _roll_audio(speed: float) -> void:
	if SoundService.instance() == null:
		return
	var p := global_position
	var kind := "cart.roll.wood" if p.y > World.height_at(p.x, p.z) + 0.2 else "cart.roll.dirt"
	if speed < 0.15 or kind != _roll_kind:
		if _roll_h != 0:
			SoundService.loop_stop(_roll_h, 0.2)
			_roll_h = 0
		_roll_kind = kind
		if speed < 0.15:
			return
	if _roll_h == 0 or not SoundService.is_playing(_roll_h):
		_roll_h = SoundService.loop(kind, self, {"gain": -20.0})
	SoundService.loop_set(_roll_h, linear_to_db(clampf(speed / 2.0, 0.05, 1.0)), 0.8 + 0.3 * clampf(speed / 2.0, 0.0, 1.0))
	if randf() < 0.004:
		SoundService.play("cart.squeak", self, {"emit": false})


func _physics_process(delta: float) -> void:
	if pusher == null or not is_instance_valid(pusher):
		pusher = null
		_roll_audio(0.0)
		return
	var fwd := -pusher.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return
	fwd = fwd.normalized()
	# Bounded turning toward the pusher's heading (cart faces away from them).
	var want_yaw := atan2(fwd.x, fwd.z) + PI
	var dy := wrapf(want_yaw - yaw, -PI, PI)
	yaw += clampf(dy, -MAX_YAW_RATE * delta, MAX_YAW_RATE * delta)
	var cart_fwd := -Vector3(sin(yaw), 0, cos(yaw))       # direction the bed leads
	var target := pusher.global_position + cart_fwd * AHEAD
	var cur := global_position
	var step := Vector3(target.x - cur.x, 0, target.z - cur.z)
	if step.length() > 6.0 * delta:
		step = step.normalized() * 6.0 * delta
	var nxt := cur + step
	if _blocked(nxt, yaw):
		nxt = cur
	_roll_audio(Vector2(nxt.x - cur.x, nxt.z - cur.z).length() / maxf(delta, 0.0001))
	_place(nxt, yaw)
	if Vector2(pusher.global_position.x - global_position.x, pusher.global_position.z - global_position.z).length() > SNAG_DIST + AHEAD:
		var p := pusher
		release()
		if p.has_method("show_message"):
			p.show_message("The cart caught on something; you let go. Push it from another side.")


func _blocked(at: Vector3, y_: float) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(SIZE.x + 0.1, 0.5, SIZE.z)
	q.shape = bx
	q.transform = Transform3D(Basis(Vector3.UP, y_), Vector3(at.x, _ground(at) + 0.7, at.z))
	q.collision_mask = 1 | 2
	var ex: Array[RID] = [_body.get_rid()]
	if pusher is CollisionObject3D:
		ex.append((pusher as CollisionObject3D).get_rid())
	q.exclude = ex
	for hit in space.intersect_shape(q, 4):
		var n: Node = hit.collider
		if n and str(n.name) == "TerrainCollision":
			continue
		return true
	return false


# -------------------------------------------------------------- visuals

func _refresh_logs() -> void:
	for n in _log_nodes:
		n.queue_free()
	_log_nodes.clear()
	var t: TimberService = Game.timber
	if t == null:
		return
	var x := -SIZE.x * 0.5 + 0.05
	var y := 0.55
	var row_h := 0.0
	for sid in load_sids():
		var s := t.segment(str(sid))
		var rec: Dictionary = t.records[int(str(sid).trim_prefix("T").split("_S")[0])]
		var r := TimberMesh.piece_radius(rec, int(s.k))
		if x + r * 2.0 > SIZE.x * 0.5 + 0.2:
			x = -SIZE.x * 0.5 + 0.05
			y += row_h * 0.9
			row_h = 0.0
		var mi := MeshInstance3D.new()
		mi.mesh = TimberMesh.piece_mesh(rec, int(s.k))
		# piece_mesh is already centred on the piece's middle.
		mi.transform = Transform3D(TimberMesh.frame_for(Vector3.FORWARD), Vector3(x + r, y + r, -0.1))
		_logs_root.add_child(mi)
		_log_nodes.append(mi)
		x += r * 2.0 + 0.02
		row_h = maxf(row_h, r * 2.0)


func capture() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": yaw}


func restore(d: Dictionary) -> void:
	if d.has("pos"):
		var a: Array = d.pos
		yaw = float(d.get("yaw", 0.0))
		_place(Vector3(float(a[0]), float(a[1]), float(a[2])), yaw)
	_refresh_logs()
