class_name Player
extends CharacterBody3D
## First-person exploration controller: mouse look, walk/sprint/crouch/jump,
## slopes and small steps, gentle deep-water restriction (no invisible walls
## on dry land), footsteps by surface, interaction ray, and debug helpers
## (reset to safe position, tree inspector, preview fly mode).
##
## Dimensions (meters): capsule 1.80 x r0.32, eye 1.65, crouch 1.20/1.05.
## Fits 2.0 m doors; leaves headroom for later axe swings.

const HEIGHT := 1.8
const RADIUS := 0.32
const EYE := 1.65
const CROUCH_HEIGHT := 1.2
const CROUCH_EYE := 1.05
const WALK_SPEED := 4.2
const SPRINT_SPEED := 6.8
const CROUCH_SPEED := 2.0
const JUMP_VELOCITY := 4.6
const GRAVITY := 15.0
const STEP_HEIGHT := 0.32
const INTERACT_RANGE := 2.6

signal interact_target_changed(text: String)
signal message(text: String)

var head: Node3D
var camera: Camera3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _yaw := 0.0
var _pitch := 0.0
var _crouching := false
var _eye_current := EYE
var _bob_t := 0.0
var _step_accum := 0.0
var _interact_target: Node = null
var fly_mode := false
var wading_depth := 0.0
var too_deep := false
var surface_name := "grass"
var _last_safe := Vector3.ZERO
var axe: AxeController
var carry: CarryController
var vehicle: Node3D = null          # Phase 5: the truck we sit in
var couch: Node3D = null            # Phase 5: couch seat marker while seated
var hiding: HideSpot = null         # Phase 6: hiding place while hidden
var _hide_blend := 1.0
var _hide_from := Vector3.ZERO
var _hide_yaw := 0.0
var _couch_yaw := 0.0
var _sit_blend := 1.0
var _sit_from := Vector3.ZERO
var vehicle_seat := ""
var _veh_yaw := 0.0
var _shake := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.4
	safe_margin = 0.02
	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = HEIGHT * 0.5
	add_child(_shape)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.05
	camera.far = 6000.0
	camera.current = true
	head.add_child(camera)
	var listener := AudioListener3D.new()
	listener.name = "Listener"
	camera.add_child(listener)
	listener.make_current()
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	axe = AxeController.new()
	axe.name = "Axe"
	add_child(axe)
	axe.setup(self)
	carry = CarryController.new()
	carry.name = "Carry"
	add_child(carry)
	carry.setup(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_settings() -> void:
	camera.fov = Settings.get_v("fov")


func get_yaw() -> float:
	return _yaw


## Places the eye at `eye_pos` looking toward `look_at`.
func teleport(eye_pos: Vector3, look_at: Vector3) -> void:
	var feet := eye_pos - Vector3(0, EYE, 0)
	feet.y = maxf(feet.y, World.height_at(feet.x, feet.z))
	var d := look_at - eye_pos
	_yaw = atan2(-d.x, -d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.3, 1.3)
	_set_transform(feet)


func teleport_feet(feet: Vector3, yaw: float) -> void:
	_yaw = yaw
	_pitch = 0.0
	_set_transform(feet)


func _set_transform(feet: Vector3) -> void:
	global_position = feet + Vector3(0, 0.05, 0)
	velocity = Vector3.ZERO
	_apply_look()
	_last_safe = global_position


func _apply_look() -> void:
	rotation = Vector3(0, _yaw, 0)
	head.rotation = Vector3(_pitch, 0, 0)


func show_message(text: String) -> void:
	message.emit(text)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if vehicle != null:
		_vehicle_input(event)
		return
	if couch != null:
		_couch_input(event)
		return
	if hiding != null:
		_hide_input(event)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Settings.get_v("mouse_sensitivity") * 0.01
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		_yaw -= event.relative.x * s
		_pitch = clampf(_pitch - event.relative.y * s * inv, deg_to_rad(-88.0), deg_to_rad(88.0))
		_apply_look()
	elif event.is_action_pressed("set_down") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		carry.set_down_one()
	elif event.is_action_pressed("drop_load") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		carry.drop_all()
	elif event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Only unhandled clicks reach here: a click consumed by a UI button
		# can never also strike wood.
		axe.try_swing()
	elif event.is_action_pressed("tool_small"):
		_select_tier("small")
	elif event.is_action_pressed("tool_medium"):
		_select_tier("medium")
	elif event.is_action_pressed("tool_large"):
		_select_tier("large")
	elif event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _interact_target and _interact_target.has_method("interact"):
			_interact_target.interact(self)
	elif event.is_action_pressed("reset_safe"):
		reset_to_safe()
	elif event.is_action_pressed("toggle_fly") and Game.is_preview():
		fly_mode = not fly_mode
		show_message("Fly mode %s (preview only)" % ("ON" if fly_mode else "OFF"))


## Campaign: only owned axes (bought at the tool rack). Preview: any tier
## for review. Selecting never costs money.
func _select_tier(tier: String) -> void:
	var c: CampaignService = Game.campaign
	const RATE := {"small": "1.00x", "medium": "1.40x", "large": "1.96x"}
	if c and c.active and not Game.is_preview():
		if not c.equipment.equip_tier(tier):
			show_message("You don't own a %s axe yet. Buy one at the tool rack." % tier)
		else:
			show_message("%s axe (%s)" % [tier.capitalize(), RATE[tier]])
		return
	axe.equip(tier)
	show_message("%s axe (%s) - preview tier" % [tier.capitalize(), RATE[tier]])


# ---------------------------------------------------------------- vehicle

func enter_vehicle(t: Node3D, seat: String) -> void:
	vehicle = t
	vehicle_seat = seat
	_veh_yaw = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if _crouching:
		_crouching = false
	_interact_target = null
	interact_target_changed.emit("")
	var ik := Keys.label("interact")
	show_message(("Driving: %s/%s throttle and brake/reverse, %s/%s steer, %s parking brake, %s lights, %s get out." % [Keys.label("move_forward"), Keys.label("move_back"), Keys.label("move_left"), Keys.label("move_right"), Keys.label("jump"), Keys.label("headlights"), ik]) if seat == "driver" else "Riding as a passenger. %s to get out when the truck has stopped." % ik)


func exit_vehicle(at: Vector3) -> void:
	var yaw := vehicle.global_rotation.y + _veh_yaw if vehicle else _yaw
	vehicle = null
	vehicle_seat = ""
	collision_layer = 2
	collision_mask = 1
	_yaw = yaw
	teleport_feet(at, yaw)


func _vehicle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Settings.get_v("mouse_sensitivity") * 0.01
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		_veh_yaw = clampf(_veh_yaw - event.relative.x * s, deg_to_rad(-120.0), deg_to_rad(120.0))
		_pitch = clampf(_pitch - event.relative.y * s * inv, deg_to_rad(-60.0), deg_to_rad(50.0))
	elif event.is_action_pressed("interact"):
		var why: String = Game.vehicles.try_exit(self) if Game.vehicles else ""
		if why != "":
			show_message(why)
	elif event.is_action_pressed("headlights") and vehicle_seat == "driver":
		vehicle.headlights = not vehicle.headlights


func _vehicle_process(_delta: float) -> void:
	var t := vehicle as Truck
	if t == null:
		vehicle = null
		return
	if vehicle_seat == "driver" and t.mode == "player":
		var fwd := Input.get_action_strength("move_forward")
		var back := Input.get_action_strength("move_back")
		var v := t.speed()
		t.steer = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		t.brake = 0.0
		if fwd > 0.0:
			t.throttle = fwd if v > -0.5 else 0.0
			t.brake = 1.0 if v < -0.5 else 0.0
		elif back > 0.0:
			if v > 0.6:
				t.throttle = 0.0
				t.brake = back
			else:
				t.throttle = -back
				if v < -1.0 and Game.vehicles:
					Game.vehicles.tutorial_mark("reverse")
		else:
			t.throttle = 0.0
			t.brake = 0.15
		t.handbrake = Input.is_action_pressed("jump")
		if absf(v) > 3.0 and Game.vehicles:
			Game.vehicles.tutorial_mark("drive")
	var seat := t.seat_marker(vehicle_seat)
	var eye := seat.global_transform * Vector3(0, 0.72, 0.05)
	global_position = eye - Vector3(0, head.position.y, 0)
	rotation = Vector3(0, t.global_rotation.y + _veh_yaw, 0)
	head.rotation = Vector3(_pitch, 0, 0)
	velocity = Vector3.ZERO


# ------------------------------------------------------------------ couch

## Sits on a couch seat marker (faces the TV). Looking around stays free;
## the stand-up point is verified clear before leaving.
func sit_on_couch(marker: Node3D) -> void:
	if vehicle != null or couch != null or carry.is_carrying():
		if carry.is_carrying():
			show_message("Put the wood down first.")
		return
	couch = marker
	_couch_yaw = 0.0
	_pitch = deg_to_rad(-4.0)
	_sit_blend = 0.0
	_sit_from = global_position + Vector3(0, head.position.y, 0)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if _crouching:
		_crouching = false
	_interact_target = null
	interact_target_changed.emit("")
	show_message("On the couch: click a camera tile to focus it, right-click back to the wall, %s/%s or wheel switch camera in focus, C channel, [ ] swap speed / freeze, M mute cameras, -/+ volume, P TV power, %s or %s stand up. The TV is live: time keeps running." % [Keys.label("move_left"), Keys.label("move_right"), Keys.label("interact"), Keys.label("jump")])


func stand_from_couch() -> void:
	if couch == null:
		return
	var fwd := -couch.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := couch.global_basis.x
	var base := couch.global_position
	var spot := Vector3.INF
	for off in [0.6, 0.45, 0.8]:
		for lat in [0.0, 0.3, -0.3]:
			var c: Vector3 = base + fwd * float(off) + side * float(lat)
			c.y = couch.global_position.y - 0.55
			if _stand_clear(c):
				spot = c
				break
		if spot != Vector3.INF:
			break
	if spot == Vector3.INF:
		show_message("No room to stand here.")
		return
	var yaw := couch.global_rotation.y + _couch_yaw
	couch = null
	collision_layer = 2
	collision_mask = 1
	_yaw = yaw
	teleport_feet(spot, yaw)


func _stand_clear(feet: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _capsule
	q.transform = Transform3D(Basis(), feet + Vector3(0, HEIGHT * 0.5 + 0.05, 0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _couch_input(event: InputEvent) -> void:
	var tv: CameraWall = Game.tv
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Settings.get_v("mouse_sensitivity") * 0.01
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		_couch_yaw = clampf(_couch_yaw - event.relative.x * s, deg_to_rad(-110.0), deg_to_rad(110.0))
		_pitch = clampf(_pitch - event.relative.y * s * inv, deg_to_rad(-55.0), deg_to_rad(60.0))
	elif event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		stand_from_couch()
	elif tv == null:
		return
	elif event.is_action_pressed("attack"):
		if tv.mode == "quad":
			var tile := tv.tile_under_ray(camera.global_position, -camera.global_basis.z)
			if tile >= 0:
				tv.focus_tile(tile)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and tv.mode == "focus":
			tv.back_to_quad()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and tv.mode == "focus":
			tv.focus_step(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and tv.mode == "focus":
			tv.focus_step(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		match k:
			KEY_A, KEY_LEFT:
				if tv.mode == "focus":
					tv.focus_step(-1)
			KEY_D, KEY_RIGHT:
				if tv.mode == "focus":
					tv.focus_step(1)
			KEY_BACKSPACE:
				if tv.mode == "focus":
					tv.back_to_quad()
			KEY_C:
				tv.cycle_mode()
			KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				# Accessibility: slower swaps or freeze (0 = frozen); saved in Settings.
				var steps := [0.0, 5.0, 10.0, 20.0, 40.0]
				var i := maxi(steps.find(tv.interval), 1)
				i = clampi(i + (1 if k == KEY_BRACKETRIGHT else -1), 0, steps.size() - 1)
				tv.set_interval(steps[i])
				Settings.set_v("tv_interval", steps[i])
				show_message("Camera wall: " + ("frozen (no automatic swaps)" if steps[i] == 0.0 else "one tile every %d s" % int(steps[i])))
			KEY_M:
				tv.set_mic_muted(not tv.mic_muted)
				show_message("Camera microphones %s (the room still sounds normal)." % ("muted" if tv.mic_muted else "on"))
			KEY_MINUS, KEY_KP_SUBTRACT:
				tv.set_volume(tv.tv_volume - 0.1)
				show_message("TV volume %d%%" % roundi(tv.tv_volume * 100.0))
			KEY_EQUAL, KEY_KP_ADD:
				tv.set_volume(tv.tv_volume + 0.1)
				show_message("TV volume %d%%" % roundi(tv.tv_volume * 100.0))
			KEY_P:
				tv.set_power(not tv.powered)
			KEY_1, KEY_2, KEY_3, KEY_4:
				if tv.mode == "quad":
					tv.focus_tile(k - KEY_1)


func _couch_process(delta: float) -> void:
	_sit_blend = minf(_sit_blend + delta / 0.45, 1.0)
	var eye := couch.global_transform * Vector3(0, 0.62, 0.12)
	var e := smoothstep(0.0, 1.0, _sit_blend)
	global_position = _sit_from.lerp(eye, e) - Vector3(0, head.position.y, 0)
	rotation = Vector3(0, couch.global_rotation.y + _couch_yaw, 0)
	head.rotation = Vector3(_pitch, 0, 0)
	velocity = Vector3.ZERO


# ----------------------------------------------------------- hiding (P6)

## Gets into a hiding place: a short readable move, then a low/limited
## view from inside. Concealment only - see HuntService.
func hide_in(spot: HideSpot) -> void:
	if vehicle != null or couch != null or hiding != null:
		return
	if carry.is_carrying():
		show_message("Drop what you're carrying first (X).")
		return
	hiding = spot
	_hide_blend = 0.0
	_hide_from = global_position + Vector3(0, head.position.y, 0)
	_hide_yaw = 0.0
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_interact_target = null
	interact_target_changed.emit("")
	if Game.hunt:
		Game.hunt.on_enter_hide(self, spot)
	show_message("Hidden (%s). Stay still. %s to get out. Hiding is not invulnerability: a place you were seen entering can be searched." % [spot.kind.replace("_", " "), Keys.label("interact")])


func leave_hide() -> void:
	if hiding == null:
		return
	var spot := hiding
	var out := Vector3.INF
	var fwd := spot.look_dir
	for c in [spot.exit_point, spot.exit_point + fwd.cross(Vector3.UP) * 0.5, spot.exit_point - fwd.cross(Vector3.UP) * 0.5, spot.marker.global_position - fwd * 0.9]:
		if _stand_clear(c):
			out = c
			break
	if out == Vector3.INF:
		show_message("No room to get out here yet.")
		return
	hiding = null
	collision_layer = 2
	collision_mask = 1
	if Game.hunt:
		Game.hunt.on_exit_hide(self, spot)
	teleport_feet(out, atan2(-fwd.x, -fwd.z))


func _hide_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Settings.get_v("mouse_sensitivity") * 0.01
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		_hide_yaw = clampf(_hide_yaw - event.relative.x * s, deg_to_rad(-70.0), deg_to_rad(70.0))
		_pitch = clampf(_pitch - event.relative.y * s * inv, deg_to_rad(-25.0), deg_to_rad(30.0))
	elif event.is_action_pressed("interact"):
		leave_hide()


func _hide_process(delta: float) -> void:
	_hide_blend = minf(_hide_blend + delta / 0.7, 1.0)
	var e := smoothstep(0.0, 1.0, _hide_blend)
	global_position = _hide_from.lerp(hiding.eye, e) - Vector3(0, head.position.y, 0)
	var dir := hiding.look_dir
	rotation = Vector3(0, atan2(-dir.x, -dir.z) + _hide_yaw, 0)
	head.rotation = Vector3(_pitch, 0, 0)
	velocity = Vector3.ZERO


func refresh_interaction() -> void:
	_interact_target = null


func try_pick_up(body: TimberBody) -> void:
	carry.try_pick_up(body)


func reset_to_safe() -> void:
	var markers := get_tree().get_nodes_in_group("safe_reset")
	if markers.size() > 0:
		var m: Node3D = markers[0]
		teleport_feet(m.global_position, m.global_rotation.y)
	else:
		teleport_feet(World.camp_origin(), 0.0)
	show_message("Reset to camp")


func _physics_process(delta: float) -> void:
	if vehicle != null:
		_vehicle_process(delta)
		return
	if couch != null:
		_couch_process(delta)
		return
	if hiding != null:
		_hide_process(delta)
		return
	if fly_mode:
		_fly(delta)
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var want_crouch := Input.is_action_pressed("crouch")
	_update_crouch(want_crouch, delta)
	var speed := WALK_SPEED
	if _crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sprint") and input.y < 0.0:
		speed = SPRINT_SPEED
	speed *= carry.speed_factor()
	# Water: slower with depth, gently pushed back beyond the wading limit.
	var feet := global_position
	# Depth of water above the player's feet (not above the bed), so bridges,
	# decks and stepping stones over water never trigger the push-back.
	wading_depth = 0.0
	if Game.water:
		wading_depth = clampf(minf(Game.water.surface_height_at(feet.x, feet.z) - feet.y, Game.water.depth_at(feet.x, feet.z)), 0.0, 99.0)
	var limit: float = World.config.wade_depth_limit
	speed *= lerpf(1.0, 0.45, clampf(wading_depth / limit, 0.0, 1.0))
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	too_deep = wading_depth > limit
	if Game.water and wading_depth > limit * 0.75:
		var g := _depth_gradient(feet)
		var into := dir.dot(g)
		if into > 0.0:
			dir -= g * into * smoothstep(limit * 0.75, limit, wading_depth)
		if too_deep:
			dir -= g * clampf((wading_depth - limit) * 2.5, 0.0, 1.5)
	var target := dir * speed
	var accel := 10.0 if is_on_floor() else 2.5
	velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0.0, 1.0))
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not _crouching and wading_depth < 0.5 and carry.can_jump():
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	var was_on_floor := is_on_floor()
	var h_before := Vector2(velocity.x, velocity.z)
	_try_step(delta)
	move_and_slide()
	# Never fall through the island: clamp to terrain as a last resort.
	var ground := World.height_at(global_position.x, global_position.z)
	if global_position.y < ground - 0.5:
		global_position.y = ground + 0.05
		velocity.y = 0.0
	if was_on_floor and is_on_floor() and global_position.y > ground - 0.2:
		_last_safe = global_position
	_footsteps(delta, h_before.length())
	_head_bob(delta, Vector2(velocity.x, velocity.z).length())
	_update_interaction()
	axe._physics_process_step(delta)
	if wading_depth > 0.05 and Vector2(velocity.x, velocity.z).length() > 0.5 and Game.water:
		Game.water.emit_ripple(global_position, clampf(wading_depth * 1.5, 0.3, 1.2), self, 0.4)


func _depth_gradient(p: Vector3) -> Vector3:
	var e := 1.0
	var dx := Game.water.depth_at(p.x + e, p.z) - Game.water.depth_at(p.x - e, p.z)
	var dz := Game.water.depth_at(p.x, p.z + e) - Game.water.depth_at(p.x, p.z - e)
	var g := Vector3(dx, 0, dz)
	return g.normalized() if g.length() > 0.0001 else Vector3.ZERO


func _try_step(delta: float) -> void:
	# Climb small steps the capsule would otherwise stop at.
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.001:
		return
	if not test_move(global_transform, motion):
		return
	var up := Transform3D(global_transform.basis, global_position + Vector3(0, STEP_HEIGHT, 0))
	if test_move(global_transform, Vector3(0, STEP_HEIGHT, 0)):
		return
	if test_move(up, motion):
		return
	var col := KinematicCollision3D.new()
	var probe := Transform3D(up.basis, up.origin + motion)
	if test_move(probe, Vector3(0, -STEP_HEIGHT, 0), col):
		var rise := STEP_HEIGHT - col.get_travel().length()
		if rise > 0.02 and col.get_normal().y > 0.7:
			global_position.y += rise + 0.01


func _update_crouch(want: bool, delta: float) -> void:
	if not want and _crouching:
		# Only stand if there is headroom.
		var space := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = RADIUS * 0.9
		cap.height = HEIGHT
		space.shape = cap
		space.transform = Transform3D(Basis(), global_position + Vector3(0, HEIGHT * 0.5 + 0.02, 0))
		space.collision_mask = 1
		if not get_world_3d().direct_space_state.intersect_shape(space, 1).is_empty():
			want = true
	_crouching = want
	var h := CROUCH_HEIGHT if _crouching else HEIGHT
	_capsule.height = h
	_shape.position.y = h * 0.5
	_eye_current = move_toward(_eye_current, CROUCH_EYE if _crouching else EYE, delta * 4.0)


func _head_bob(delta: float, speed: float) -> void:
	var bob := 0.0
	if Settings.get_v("head_bob") and is_on_floor() and speed > 0.5:
		_bob_t += delta * speed * 1.9
		bob = sin(_bob_t * 2.0) * 0.022 * clampf(speed / WALK_SPEED, 0.0, 1.4) * float(Settings.get_v("bob_strength"))
	head.position.y = _eye_current + bob
	# Subtle, decaying hit shake (comfort-toggleable).
	_shake = move_toward(_shake, 0.0, delta * 0.12)
	camera.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake
	carry.process_visual(delta)
	axe._process_visual(delta, speed)


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount * float(Settings.get_v("shake_strength")), 0.04)


func _footsteps(delta: float, speed: float) -> void:
	# Cadence follows a human gait: ~1.8 steps/s strolling, ~2.7 sprinting,
	# slower when crouched or wading. Time-based, not distance-based, so the
	# fast game walk speed doesn't produce a drum roll of steps.
	if not is_on_floor() or speed < 0.8:
		_step_accum = 0.6   # next step lands soon after starting to move
		return
	_step_accum += delta * step_rate(speed, _crouching, wading_depth)
	if _step_accum >= 1.0:
		_step_accum -= 1.0
		surface_name = _surface_under()
		var intensity := 0.55 if _crouching else (1.0 if speed < WALK_SPEED + 0.5 else 1.35)
		get_tree().call_group("footstep_listeners", "play_footstep", surface_name, global_position, intensity)


## Footfalls per second for a given movement state (shared with tests).
static func step_rate(speed: float, crouching: bool, wading: float) -> float:
	var rate := lerpf(1.75, 2.7, clampf((speed - WALK_SPEED) / (SPRINT_SPEED - WALK_SPEED), 0.0, 1.0))
	if crouching:
		rate = 1.4
	if wading > 0.2:
		rate *= 0.8
	return rate


func _surface_under() -> String:
	if wading_depth > 0.05:
		return "water"
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.3, 0), global_position - Vector3(0, 0.4, 0), 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and not (hit.collider is StaticBody3D and hit.collider.name == "TerrainCollision"):
		return "wood"
	match World.surface_at(global_position.x, global_position.z):
		World.Surface.SAND: return "sand"
		World.Surface.DIRT: return "dirt"
		World.Surface.ROCK: return "rock"
		World.Surface.FOREST: return "forest"
	return "grass"


func _update_interaction() -> void:
	var from := camera.global_position
	var to := from - camera.global_basis.z * INTERACT_RANGE
	# Layer 16: interaction-only spots (truck doors and tailgates).
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 16)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target: Node = null
	if hit:
		var n: Node = hit.collider
		while n and not n.has_method("interact"):
			n = n.get_parent()
		target = n
	if target != _interact_target:
		_interact_target = target
		interact_target_changed.emit(target.get_interact_text() if target and target.has_method("get_interact_text") else "")


## Looks for a harvestable tree under the crosshair (or the nearest one in
## front within 6 m). Returns the tree index or -1.
func inspect_tree() -> int:
	var from := camera.global_position
	var to := from - camera.global_basis.z * 30.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var id := VegetationSystem.tree_id_from_hit(hit.collider, hit.shape)
		if id >= 0 and Game.vegetation:
			return Game.vegetation.tree_index_by_id.get(id, -1)
	return -1


func _fly(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var v := camera.global_basis * Vector3(input.x, 0, input.y)
	if Input.is_action_pressed("jump"):
		v.y += 1.0
	if Input.is_action_pressed("crouch"):
		v.y -= 1.0
	var sp := 30.0 if Input.is_action_pressed("sprint") else 10.0
	global_position += v.normalized() * sp * delta if v.length() > 0.01 else Vector3.ZERO
	global_position.y = maxf(global_position.y, World.height_at(global_position.x, global_position.z) + 0.1)
	velocity = Vector3.ZERO
	_update_interaction()
