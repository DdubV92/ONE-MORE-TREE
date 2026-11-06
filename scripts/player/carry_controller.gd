class_name CarryController
extends Node
## The player's hand load. Ownership lives in TimberService.carried (this
## node only presents it): pick up (E on a free log), add to the bundle (E on
## another log while there is room), set down (G, validated spot), drop the
## whole load (X), deliver (E on the camp delivery rack). The axe is stowed
## while carrying; clicks do nothing.
##
## Presentation: logs ride on the right shoulder, front end visible at the
## right of view, gloved hands holding them; the bundle pulls back from
## walls instead of clipping through them. No physics body is carried, so a
## load can never push the player or launch anything.

const SET_DOWN_DIST := [1.25, 0.95, 1.6]
const SIDE_OFFSETS := [0.0, 0.55, -0.55]

var player: Player
var rig: Node3D
var _visuals: Array[MeshInstance3D] = []
var _pull := 0.0
var stronger := false          # trait hook (workers in Phase 4)


func setup(p: Player) -> void:
	player = p
	rig = Node3D.new()
	rig.name = "CarryRig"
	player.add_child(rig)
	if Game.timber:
		Game.timber.carried_changed.connect(_rebuild)
	_rebuild()


func budget() -> int:
	return CampaignRules.hand_budget_mte(stronger)


func is_carrying() -> bool:
	return Game.timber != null and not Game.timber.carried.is_empty()


func load_mte() -> int:
	return Game.timber.carried_mte() if Game.timber else 0


func load_fraction() -> float:
	return float(load_mte()) / float(budget())


## Bounded movement penalty: up to 25 % slower with a full load; dragging
## an oversized log (Phase 13) is half speed.
func speed_factor() -> float:
	if is_dragging():
		return 0.5
	return 1.0 - 0.25 * clampf(load_fraction(), 0.0, 1.0) if is_carrying() else 1.0


func is_dragging() -> bool:
	return Game.timber != null and Game.timber.is_dragging("player", budget())


func can_jump() -> bool:
	return load_fraction() < 0.5 and not is_dragging()


func load_text() -> String:
	if not is_carrying():
		return ""
	var paid := Game.yard != null and Game.yard.is_yard_move(str(Game.timber.carried[0]))
	if is_dragging():
		return "Dragging a heavy log (%d%% of a hand load, slow)   [G] set down  [X] drop" % int(round(load_fraction() * 100.0))
	if paid:
		return "Carrying %d paid log%s to a deck or the fire   [G] at a deck/the pit" % [Game.timber.carried.size(), "" if Game.timber.carried.size() == 1 else "s"]
	return "Carrying %d log%s · %d%% of a hand load   [G] set down  [X] drop all" % [Game.timber.carried.size(), "" if Game.timber.carried.size() == 1 else "s", int(round(load_fraction() * 100.0))]


# ------------------------------------------------------------------ actions

func try_pick_up(body: TimberBody) -> void:
	if Game.timber == null or not is_instance_valid(body):
		return
	if not body.is_single_piece():
		player.show_message("This trunk is too big to lift. Cut it at the orange marks.")
		return
	if not body.is_resting():
		player.show_message("Let it settle first.")
		return
	if player.axe.swinging:
		return
	if player.get("pushing_cart") != null:
		player.show_message("Let go of the cart first (%s)." % Keys.label("drop"))
		return
	var res := Game.timber.pick_up(body, budget())
	if not bool(res.ok) and not is_carrying():
		# Phase 13: a log up to two hand loads can be dragged by one end.
		res = Game.timber.pick_up_for("player", body, budget(), true)
		if bool(res.ok):
			player.show_message("Too heavy to lift, so you drag it by one end (slow). Take it to the cart or straight to the receiving cradle.")
			return
	if not bool(res.ok):
		player.show_message(str(res.reason))
		return
	player.show_message(load_text().get_slice("   ", 0))


func set_down_one() -> void:
	if not is_carrying():
		return
	# Phase 13: paid yard logs go on a deck or the fire's loading pile.
	if Game.yard and Game.yard.is_yard_move(str(Game.timber.carried[0])):
		var sid: String = Game.timber.carried[Game.timber.carried.size() - 1]
		var deck := CampLayout.on_deck(player.global_position, 3.6)
		var pit := CampLayout.world(CampLayout.BURN_PIT_POS)
		if deck >= 0:
			if not Game.yard.place_on_deck("player", sid, deck):
				player.show_message(Game.yard.last_reason)
		elif Vector2(player.global_position.x - pit.x, player.global_position.z - pit.z).length() < 4.6:
			if not Game.yard.load_pit("player", sid):
				player.show_message(Game.yard.last_reason)
		else:
			player.show_message("Paid logs go on a yard deck (outside the north gate, east) or the fire's loading pile.")
		return
	var rack := _rack_in_reach()
	if rack:
		rack.deliver_from(player)
		return
	var sid: String = Game.timber.carried[Game.timber.carried.size() - 1]
	var spot := find_spot(sid)
	if spot.is_empty():
		player.show_message("No clear, level spot in front of you. Face open ground.")
		return
	Game.timber.put_down(sid, spot.centre, spot.dir, true)
	LoggingFX.play(LoggingFX.Sound.CLUNK, spot.centre, -4.0, {"event": "log.drop.ground"})


func drop_all() -> void:
	if player.get("pushing_cart") != null:
		(player.pushing_cart as TimberCart).release()
		player.show_message("Cart parked.")
		return
	if not is_carrying():
		return
	if Game.yard and Game.yard.is_yard_move(str(Game.timber.carried[0])):
		player.show_message("These logs are paid for: stack them on a deck or load them on the fire's pile (G there).")
		return
	var dropped := 0
	for sid in Game.timber.carried.duplicate():
		var spot := find_spot(sid)
		if spot.is_empty():
			continue
		Game.timber.put_down(sid, spot.centre + Vector3(0, 0.15, 0), spot.dir, true)
		dropped += 1
	if dropped == 0:
		player.show_message("No room to drop the load here.")
	else:
		LoggingFX.play(LoggingFX.Sound.CLUNK, player.global_position, 0.0, {"event": "log.drop.ground"})


## Finds a validated resting spot in front of the player for piece `sid`:
## reachable, visible from the eye, dry or shallow, not too steep, outside
## the fire's hot zone, clear of the player and other solids. Returns
## {"centre", "dir"} or {} if none.
func find_spot(sid: String) -> Dictionary:
	var s := Game.timber.segment(sid)
	var rec: Dictionary = Game.timber.records[int(sid.trim_prefix("T").split("_S")[0])]
	var length := float(s.b) - float(s.a)
	var radius := TimberMesh.radius_at(rec, (float(s.a) + float(s.b)) * 0.5)
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var across := fwd.cross(Vector3.UP).normalized()
	var space := player.get_world_3d().direct_space_state
	var eye := player.camera.global_position
	var pit := CampLayout.world(CampLayout.BURN_PIT_POS)
	for dist in SET_DOWN_DIST:
		for side in SIDE_OFFSETS:
			var base := player.global_position + fwd * (float(dist) + radius) + across * float(side)
			var q := PhysicsRayQueryParameters3D.create(base + Vector3(0, 1.6, 0), base - Vector3(0, 2.5, 0), 1)
			q.exclude = [player.get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty() or (hit.normal as Vector3).y < 0.72:
				continue
			var ground: Vector3 = hit.position
			if Game.water and Game.water.depth_at(ground.x, ground.z) > 0.45:
				continue
			if Vector2(ground.x - pit.x, ground.z - pit.z).length() < CampLayout.FIRE_HOT_RADIUS + length * 0.5:
				continue
			var centre := ground + Vector3(0, radius + 0.04, 0)
			# Line of sight from the eye (no placing through walls).
			var los := PhysicsRayQueryParameters3D.create(eye, centre, 1)
			los.exclude = [player.get_rid()]
			var blk := space.intersect_ray(los)
			if not blk.is_empty() and (blk.position as Vector3).distance_to(centre) > radius + 0.3:
				continue
			if not _clear(space, centre, across, length, radius):
				continue
			return {"centre": centre, "dir": across}
	return {}


func _clear(space: PhysicsDirectSpaceState3D, centre: Vector3, dir: Vector3, length: float, radius: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 0.97
	cyl.height = length
	q.shape = cyl
	q.transform = Transform3D(TimberMesh.frame_for(dir), centre + Vector3(0, 0.03, 0))
	q.collision_mask = 1 | 2          # world solids and characters
	return space.intersect_shape(q, 1).is_empty()


func _rack_in_reach() -> Node:
	for r in player.get_tree().get_nodes_in_group("delivery_rack"):
		var n: Node3D = r
		if n.global_position.distance_to(player.global_position) < 3.2:
			return n
	return null


# ------------------------------------------------------------- presentation

func _rebuild() -> void:
	for v in _visuals:
		v.queue_free()
	_visuals.clear()
	if Game.timber == null:
		return
	var i := 0
	for sid in Game.timber.carried:
		var s := Game.timber.segment(sid)
		var tid := int(sid.trim_prefix("T").split("_S")[0])
		var rec: Dictionary = Game.timber.records[tid]
		var mi := MeshInstance3D.new()
		mi.name = "Carried_%s" % sid
		mi.mesh = TimberMesh.piece_mesh(rec, int(s.k))
		mi.set_meta("length", TimberMesh.piece_length(rec, int(s.k)))
		mi.set_meta("radius", TimberMesh.piece_radius(rec, int(s.k)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rig.add_child(mi)
		_visuals.append(mi)
		i += 1
	_layout()


func _layout() -> void:
	if is_dragging() and _visuals.size() == 1:
		# Dragged by the front end: held low at the right hand, trailing
		# behind on the ground (mostly out of view in first person).
		var mi := _visuals[0]
		var length: float = mi.get_meta("length")
		var b := TimberMesh.frame_for(Vector3(0.08, -0.32, 1.0).normalized())
		mi.transform = Transform3D(b, Vector3(0.32, -0.95, -0.25) + b.y * (length * 0.5))
		_place_rig(0.0)
		return
	# Stack: first log on the shoulder, the next beside it, then on top.
	var x := 0.0
	var y := 0.0
	for i in _visuals.size():
		var mi := _visuals[i]
		var length: float = mi.get_meta("length")
		var r: float = mi.get_meta("radius")
		var slot := Vector3(x, y, 0.0)
		if i == 0:
			x = r
		elif i % 2 == 1:
			slot = Vector3(x + r, 0.0, 0.0)
			x += r * 2.0
		else:
			slot = Vector3(x * 0.5, y + r * 1.7, 0.0)
			y += r * 1.7
		# Trunk axis points forward (-Z) with a slight inward yaw and droop.
		var basis := Basis(Vector3.UP, deg_to_rad(8.0)) * Basis(Vector3.RIGHT, deg_to_rad(-90.0 - 5.0))
		var front := 0.55
		# Front end sits `front` m ahead of the shoulder slot.
		mi.transform = Transform3D(basis, Vector3(0.3 + r * 0.6, 0.0, 0.0) + slot + basis.y * (front - length * 0.5))
	_place_rig(0.0)


func _place_rig(delta: float) -> void:
	var eye_y := player.head.position.y
	var pitch := player.head.rotation.x
	# Follow half the view pitch so looking down shows the load without the
	# log swinging into the middle of the screen.
	var b := Basis(Vector3.RIGHT, pitch * 0.5)
	# Pull the load back toward the body near walls (no deep clipping).
	var want := 0.0
	if is_carrying() and player.is_inside_tree():
		var from := player.camera.global_position
		var dir := -player.camera.global_basis.z
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 0.9, 1)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			want = clampf(0.9 - from.distance_to(hit.position), 0.0, 0.5)
	_pull = want if delta <= 0.0 else move_toward(_pull, want, delta * 3.0)
	rig.transform = Transform3D(b, Vector3(0, eye_y - 0.24, _pull))


## Grip points (world) for the view-model hands, or [] when not carrying.
func grips() -> Array:
	if _visuals.is_empty():
		return []
	var mi := _visuals[0]
	var length: float = mi.get_meta("length")
	var r: float = mi.get_meta("radius")
	var xf := mi.global_transform
	var right := xf * Vector3(r * 0.35, length * 0.5 - 0.42, r * 0.9)
	var left := xf * Vector3(-r * 0.95, length * 0.5 - 0.62, 0.0)
	return [left, right]


func process_visual(delta: float) -> void:
	_place_rig(delta)
	if rig:
		rig.visible = is_carrying()
