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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Settings.get_v("mouse_sensitivity") * 0.01
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		_yaw -= event.relative.x * s
		_pitch = clampf(_pitch - event.relative.y * s * inv, deg_to_rad(-88.0), deg_to_rad(88.0))
		_apply_look()
	elif event.is_action_pressed("interact"):
		if _interact_target and _interact_target.has_method("interact"):
			_interact_target.interact(self)
	elif event.is_action_pressed("reset_safe"):
		reset_to_safe()
	elif event.is_action_pressed("toggle_fly") and Game.is_preview():
		fly_mode = not fly_mode
		show_message("Fly mode %s (preview only)" % ("ON" if fly_mode else "OFF"))


func reset_to_safe() -> void:
	var markers := get_tree().get_nodes_in_group("safe_reset")
	if markers.size() > 0:
		var m: Node3D = markers[0]
		teleport_feet(m.global_position, m.global_rotation.y)
	else:
		teleport_feet(World.camp_origin(), 0.0)
	show_message("Reset to camp")


func _physics_process(delta: float) -> void:
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
		if Input.is_action_just_pressed("jump") and not _crouching and wading_depth < 0.5:
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
		bob = sin(_bob_t * 2.0) * 0.022 * clampf(speed / WALK_SPEED, 0.0, 1.4)
	head.position.y = _eye_current + bob


func _footsteps(delta: float, speed: float) -> void:
	if not is_on_floor() or speed < 0.6:
		return
	_step_accum += speed * delta
	var stride := 0.72 if speed < 5.0 else 0.95
	if _step_accum >= stride:
		_step_accum = 0.0
		surface_name = _surface_under()
		get_tree().call_group("footstep_listeners", "play_footstep", surface_name, global_position, speed)


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
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
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
