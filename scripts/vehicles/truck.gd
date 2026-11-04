class_name Truck
extends RigidBody3D
## An owned logging pickup (Phase 5). One stable identity (`truck_id`), a
## three-seat bench (driver + two), and a cargo bed holding at most three
## source-tree-equivalents (3000 mTE) through the shared timber ledger
## (carrier "truck:<id>"; pieces are VEHICLE_RESERVED, one owner each).
##
## Player driving: rigid body on four spring-damper raycast wheels with
## lateral tire grip, all-wheel drive, brakes, reverse, a parking brake and
## a low centre of mass (rollover resistance). Worker driving: the same
## truck follows a DriveNav route kinematically at conservative speed,
## conforming to the ground under its wheels and stopping for people.
## Parked with nobody driving, the truck freezes in place (no creeping).

signal cargo_changed()

const CAPACITY_MTE := 3000
const MAX_SPEED := 13.0           # m/s (~47 km/h) on island tracks
const CAMP_SPEED := 4.0
const REVERSE_SPEED := 4.0
const WHEEL_R := 0.42
const REST := 0.36                # mount-to-wheel-centre at rest
const TRAVEL := 0.28
const SPRING := 42000.0
const DAMP := 5200.0
const ENGINE := 9200.0
const BRAKE := 14000.0
const GRIP := 0.75
const SEATS := ["driver", "middle", "right"]
const WHEELS := [Vector3(-0.92, 0.0, -1.72), Vector3(0.92, 0.0, -1.72), Vector3(-0.92, 0.0, 1.72), Vector3(0.92, 0.0, 1.72)]

var truck_id := ""
var seats := {"driver": "", "middle": "", "right": ""}   # occupant: "boss" or employee id
var throttle := 0.0
var steer := 0.0
var brake := 0.0
var handbrake := true
var headlights := false
var mode := "parked"               # parked / player / auto
var route: Array[Vector3] = []
var _ri := 0
var _auto_speed := 0.0
var blocked_for := 0.0
var status_reason := ""
var odometer := 0.0
var _wheels: Array[Node3D] = []
var _wheel_spin := 0.0
var _compress := [0.0, 0.0, 0.0, 0.0]
var _head_l: SpotLight3D
var _head_r: SpotLight3D
var _brake_mat: StandardMaterial3D
var _cargo_root: Node3D
var _engine: TruckAudio
var _flip_t := 0.0
var steer_visual := 0.0


func setup(id: String) -> void:
	truck_id = id
	name = "Truck_" + id
	mass = 2100.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.05, 0.1)
	linear_damp = 0.05
	angular_damp = 0.8
	continuous_cd = true
	collision_layer = 1
	collision_mask = 1
	can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	physics_material_override = pm
	set_meta("vehicle_id", id)
	add_to_group("trucks")
	_build_body()
	_build_hotspots()
	_engine = TruckAudio.new()
	_engine.name = "EngineAudio"
	add_child(_engine)
	_park()


# ------------------------------------------------------------------- model

func _build_body() -> void:
	var paint := StandardMaterial3D.new()
	var seed_c: Array = [Color(0.55, 0.12, 0.1), Color(0.16, 0.3, 0.42), Color(0.22, 0.34, 0.2)]
	paint.albedo_color = seed_c[abs(hash(truck_id)) % 3]
	paint.metallic = 0.35
	paint.roughness = 0.42
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.4
	var dark := BuildKit.mat("black")
	var steel := BuildKit.mat("steel")
	var glass := BuildKit.mat("glass")
	var m := Node3D.new()
	m.name = "Model"
	add_child(m)
	# Frame, cab, hood, fenders, bumpers
	BuildKit.box(m, Vector3(1.7, 0.22, 5.2), Vector3(0, 0.28, 0), dark, false, 0.0, "Frame")
	BuildKit.box(m, Vector3(1.96, 0.62, 1.95), Vector3(0, 0.82, -0.72), paint, false, 0.0, "CabLower")
	BuildKit.box(m, Vector3(1.86, 0.62, 1.7), Vector3(0, 1.43, -0.62), paint, false, 0.0, "CabUpper")
	BuildKit.box(m, Vector3(1.82, 0.05, 1.62), Vector3(0, 1.76, -0.62), paint, false, 0.0, "Roof")
	# Windows (glass panels slightly proud of the cab)
	BuildKit.box(m, Vector3(1.7, 0.5, 0.04), Vector3(0, 1.45, -1.48), glass, false, 0.0, "Windscreen").rotation.x = deg_to_rad(-14)
	BuildKit.box(m, Vector3(1.6, 0.4, 0.04), Vector3(0, 1.45, 0.24), glass, false, 0.0, "RearWindow")
	for sx in [-1.0, 1.0]:
		BuildKit.box(m, Vector3(0.04, 0.42, 1.25), Vector3(sx * 0.935, 1.45, -0.68), glass, false, 0.0, "SideWindow")
		# Mirrors
		BuildKit.box(m, Vector3(0.05, 0.18, 0.12), Vector3(sx * 1.1, 1.38, -1.3), dark, false)
		BuildKit.box(m, Vector3(0.18, 0.03, 0.03), Vector3(sx * 1.02, 1.36, -1.3), dark, false)
		# Wheel arches / fenders
		for z in [-1.72, 1.72]:
			BuildKit.box(m, Vector3(0.28, 0.12, 1.1), Vector3(sx * 0.96, 0.98 if z < 0 else 0.98, z), paint if z < 0 else dark, false)
		# Door handles
		BuildKit.box(m, Vector3(0.03, 0.04, 0.16), Vector3(sx * 0.99, 1.02, -0.45), steel, false)
	BuildKit.box(m, Vector3(1.9, 0.55, 1.25), Vector3(0, 0.78, -2.25), paint, false, 0.0, "Hood")
	BuildKit.box(m, Vector3(1.6, 0.36, 0.06), Vector3(0, 0.72, -2.9), dark, false, 0.0, "Grille")
	BuildKit.box(m, Vector3(2.0, 0.18, 0.2), Vector3(0, 0.42, -2.98), steel, false, 0.0, "FrontBumper")
	BuildKit.box(m, Vector3(2.0, 0.16, 0.18), Vector3(0, 0.42, 2.78), steel, false, 0.0, "RearBumper")
	# Bed: floor, sides, headboard, tailgate
	BuildKit.box(m, Vector3(1.86, 0.08, 2.5), Vector3(0, 0.62, 1.4), dark, false, 0.0, "BedFloor")
	for sx in [-1.0, 1.0]:
		BuildKit.box(m, Vector3(0.07, 0.55, 2.5), Vector3(sx * 0.93, 0.92, 1.4), paint, false, 0.0, "BedSide")
	BuildKit.box(m, Vector3(1.86, 0.62, 0.07), Vector3(0, 0.95, 0.16), paint, false, 0.0, "Headboard")
	BuildKit.box(m, Vector3(1.86, 0.55, 0.07), Vector3(0, 0.92, 2.66), paint, false, 0.0, "Tailgate")
	# Interior: bench seat, dash, steering wheel
	BuildKit.box(m, Vector3(1.6, 0.14, 0.55), Vector3(0, 0.98, -0.4), BuildKit.mat("leather"), false, 0.0, "Bench")
	BuildKit.box(m, Vector3(1.6, 0.55, 0.12), Vector3(0, 1.3, -0.12), BuildKit.mat("leather"), false, 0.0, "BenchBack")
	BuildKit.box(m, Vector3(1.75, 0.2, 0.4), Vector3(0, 1.18, -1.32), dark, false, 0.0, "Dash")
	var wheel := MeshInstance3D.new()
	wheel.name = "SteeringWheel"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.18
	wheel.mesh = tm
	wheel.material_override = dark
	wheel.position = Vector3(-0.45, 1.28, -1.12)
	wheel.rotation.x = deg_to_rad(65)
	m.add_child(wheel)
	# Lamps: headlights (spot lights) and brake lights (emissive)
	var lamp_glow := BuildKit.mat("lamp_bulb")
	for sx in [-1.0, 1.0]:
		BuildKit.box(m, Vector3(0.26, 0.14, 0.04), Vector3(sx * 0.68, 0.84, -2.92), lamp_glow, false, 0.0, "Headlamp")
	_brake_mat = StandardMaterial3D.new()
	_brake_mat.albedo_color = Color(0.35, 0.03, 0.02)
	_brake_mat.emission_enabled = true
	_brake_mat.emission = Color(1.0, 0.08, 0.04)
	_brake_mat.emission_energy_multiplier = 0.2
	for sx in [-1.0, 1.0]:
		BuildKit.box(m, Vector3(0.12, 0.28, 0.04), Vector3(sx * 0.9, 0.92, 2.7), _brake_mat, false, 0.0, "BrakeLamp")
	_head_l = _headlight(Vector3(-0.68, 0.84, -2.95))
	_head_r = _headlight(Vector3(0.68, 0.84, -2.95))
	# Plate
	var plate := Label3D.new()
	plate.text = "OMT-%s" % truck_id.trim_prefix("TRK-")
	plate.font_size = 40
	plate.pixel_size = 0.004
	plate.modulate = Color(0.1, 0.1, 0.1)
	plate.position = Vector3(0, 0.45, 2.88)
	plate.rotation.y = PI
	m.add_child(plate)
	# Wheels (visual; physics uses raycasts)
	for i in 4:
		var wp: Vector3 = WHEELS[i]
		var w := Node3D.new()
		w.name = "Wheel%d" % i
		w.position = wp
		add_child(w)
		var tire := BuildKit.cylinder(w, WHEEL_R, 0.3, Vector3.ZERO, dark, false, 18)
		tire.rotation.z = PI * 0.5
		var hub := BuildKit.cylinder(w, 0.2, 0.32, Vector3.ZERO, steel, false, 10)
		hub.rotation.z = PI * 0.5
		_wheels.append(w)
	# Collision: chassis, cab, hood, bed sides (compound boxes)
	_shape(Vector3(1.95, 0.55, 5.4), Vector3(0, 0.55, 0))
	_shape(Vector3(1.9, 0.95, 1.9), Vector3(0, 1.3, -0.7))
	for sx in [-1.0, 1.0]:
		_shape(Vector3(0.1, 0.55, 2.5), Vector3(sx * 0.93, 1.0, 1.4))
	_cargo_root = Node3D.new()
	_cargo_root.name = "Cargo"
	_cargo_root.position = Vector3(0, 0.66, 1.4)
	add_child(_cargo_root)
	for s in SEATS:
		var mk := Marker3D.new()
		mk.name = "Seat_" + s
		mk.position = Vector3({"driver": -0.45, "middle": 0.0, "right": 0.45}[s], 0.95, -0.45)
		add_child(mk)


func _headlight(at: Vector3) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = at
	l.spot_range = 38.0
	l.spot_angle = 32.0
	l.light_energy = 3.0
	l.light_color = Color(1.0, 0.95, 0.85)
	l.shadow_enabled = false
	l.visible = false
	add_child(l)
	return l


func _shape(size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = at
	add_child(cs)


func _build_hotspots() -> void:
	for spec in [["DriverDoor", Vector3(-1.05, 1.1, -0.6), Vector3(0.25, 1.1, 1.0)], ["PassengerDoor", Vector3(1.05, 1.1, -0.6), Vector3(0.25, 1.1, 1.0)], ["Tailgate", Vector3(0, 0.95, 2.78), Vector3(1.9, 0.7, 0.3)]]:
		var h := TruckHotspot.new()
		h.name = spec[0]
		h.truck = self
		h.kind = str(spec[0])
		h.collision_layer = 16
		h.collision_mask = 0
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = spec[2]
		cs.shape = b
		h.add_child(cs)
		h.position = spec[1]
		add_child(h)


func seat_marker(seat: String) -> Marker3D:
	return get_node("Seat_" + seat)


## Standing point outside a door (world), on the given side.
func door_point(side: float) -> Vector3:
	var p := global_transform * Vector3(side * 1.65, 0.0, -0.6)
	p.y = World.height_at(p.x, p.z)
	return p


func tailgate_point() -> Vector3:
	var p := global_transform * Vector3(0, 0.0, 3.6)
	p.y = World.height_at(p.x, p.z)
	return p


func speed() -> float:
	return linear_velocity.dot(-global_basis.z) if mode != "auto" else _auto_speed


# --------------------------------------------------------------- physics

func _park() -> void:
	mode = "parked"
	throttle = 0.0
	brake = 1.0
	handbrake = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true


func take_control(by: String) -> void:
	brake = 0.0
	throttle = 0.0
	if by == "player":
		mode = "player"
		freeze = false
		handbrake = false
		sleeping = false
	else:
		mode = "auto"
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true


func release_control() -> void:
	route.clear()
	_park()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	match mode:
		"player":
			_drive_physics(delta)
		"auto":
			_drive_auto(delta)
		_:
			_engine.set_state(0.0, 0.0, false)
	_update_visuals(delta)


func _drive_physics(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var up := global_basis.y
	var fwd := -global_basis.z
	var right := global_basis.x
	var v_fwd := linear_velocity.dot(fwd)
	var in_camp := Game.crew != null and Game.crew.nav.in_camp(global_position)
	var limit := CAMP_SPEED if in_camp else MAX_SPEED
	var max_steer := 0.55 * (1.0 - clampf(absf(v_fwd) / 18.0, 0.0, 0.6))
	steer_visual = move_toward(steer_visual, steer * max_steer, delta * 2.5)
	var contacts := 0
	for i in 4:
		var mount := global_transform * ((WHEELS[i] as Vector3) + Vector3(0, REST, 0))
		var q := PhysicsRayQueryParameters3D.create(mount, mount - up * (REST + WHEEL_R + TRAVEL), 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			_compress[i] = 0.0
			continue
		contacts += 1
		var dist: float = mount.distance_to(hit.position) - WHEEL_R
		var comp := clampf(REST - dist + TRAVEL * 0.3, 0.0, TRAVEL + 0.2)
		_compress[i] = comp
		var at: Vector3 = hit.position
		var rel := at - global_position
		var vel := linear_velocity + angular_velocity.cross(rel)
		var n: Vector3 = hit.normal
		var spring := SPRING * comp - DAMP * vel.dot(up)
		spring = maxf(spring, 0.0)
		apply_force(up * spring, rel)
		# Wheel heading (front wheels steer), projected on the ground.
		var wf := fwd
		if i < 2:
			wf = fwd.rotated(up, -steer_visual)
		wf = (wf - n * wf.dot(n)).normalized()
		var wr := wf.cross(n).normalized()
		var lat := vel.dot(wr)
		var load := maxf(spring, 0.0)
		var grip_f := clampf(-lat * mass * 0.25 * GRIP / maxf(delta, 0.001), -load * 1.1, load * 1.1)
		apply_force(wr * grip_f, rel)
		# Drive / brake / rolling resistance
		var drive := 0.0
		if not handbrake:
			if throttle > 0.0 and v_fwd < limit:
				drive = ENGINE * 0.25 * throttle
			elif throttle < 0.0 and v_fwd > -REVERSE_SPEED:
				drive = ENGINE * 0.18 * throttle
		var along := vel.dot(wf)
		var br := brake if not handbrake else 1.0
		var brake_f := -signf(along) * minf(BRAKE * 0.25 * br, absf(along) * mass * 0.25 / maxf(delta, 0.001))
		var roll := -along * 60.0
		apply_force(wf * (drive + brake_f + roll), rel)
	# Keep the truck upright-ish (strong anti-roll when tilted, no flips at
	# ordinary speeds on ordinary tracks).
	var tilt := up.cross(Vector3.UP)
	apply_torque(tilt * mass * 6.0)
	if Game.crew and contacts > 0 and v_fwd > limit + 1.0:
		apply_central_force(-fwd * mass * 2.0)
	odometer += absf(v_fwd) * delta
	_engine.set_state(absf(v_fwd) / MAX_SPEED, absf(throttle), true)
	_flip_t = _flip_t + delta if global_basis.y.y < 0.35 else 0.0


## Worker driving: follow the route at conservative speed, stop for people,
## conform to the ground. Kinematic (no tunnelling through physics).
func _drive_auto(delta: float) -> void:
	if _ri >= route.size():
		_auto_speed = move_toward(_auto_speed, 0.0, delta * 4.0)
		_engine.set_state(0.0, 0.0, true)
		return
	var p := global_position
	var target := route[_ri]
	var to := Vector3(target.x - p.x, 0, target.z - p.z)
	if to.length() < 2.0:
		_ri += 1
		return
	var dir := to.normalized()
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var turn := fwd.signed_angle_to(dir, Vector3.UP)
	var in_camp := Game.crew != null and Game.crew.nav.in_camp(p)
	var want := (CAMP_SPEED if in_camp else 6.5) * clampf(1.0 - absf(turn) / 1.6, 0.25, 1.0)
	if _ri >= route.size() - 1:
		want = minf(want, maxf(to.length() * 0.8, 1.0))
	if _obstacle_ahead(fwd):
		want = 0.0
		blocked_for += delta
		status_reason = "waiting: something in the road"
	else:
		blocked_for = 0.0
		status_reason = ""
	_auto_speed = move_toward(_auto_speed, want, delta * (3.0 if want > _auto_speed else 6.0))
	var yaw_rate := clampf(turn, -1.0, 1.0) * clampf(_auto_speed / 3.0, 0.3, 1.0) * 1.1
	var yaw := global_rotation.y + yaw_rate * delta
	var np := p + Vector3(-sin(yaw), 0, -cos(yaw)) * _auto_speed * delta
	global_transform = _ground_pose(np, yaw)
	steer_visual = clampf(turn, -0.5, 0.5)
	odometer += _auto_speed * delta
	_engine.set_state(_auto_speed / MAX_SPEED, 0.5 if want > 0.1 else 0.1, true)


## A pose resting on the ground under the four wheels at (p, yaw).
func _ground_pose(p: Vector3, yaw: float) -> Transform3D:
	var b := Basis(Vector3.UP, yaw)
	var pts := []
	for w in WHEELS:
		var wp: Vector3 = p + b * (w as Vector3)
		pts.append(Vector3(wp.x, _ground_y(wp), wp.z))
	var fwd_mid := ((pts[0] as Vector3) + (pts[1] as Vector3)) * 0.5
	var rear_mid := ((pts[2] as Vector3) + (pts[3] as Vector3)) * 0.5
	var left_mid := ((pts[0] as Vector3) + (pts[2] as Vector3)) * 0.5
	var right_mid := ((pts[1] as Vector3) + (pts[3] as Vector3)) * 0.5
	var z := (rear_mid - fwd_mid).normalized()
	var x := (right_mid - left_mid).normalized()
	var y := z.cross(x).normalized()
	x = y.cross(z).normalized()
	var centre := (fwd_mid + rear_mid) * 0.5
	return Transform3D(Basis(x, y, z), centre + y * WHEEL_R)


func _ground_y(p: Vector3) -> float:
	if Game.crew:
		return Game.crew.nav.surface_at(p)
	return World.height_at(p.x, p.z)


func _obstacle_ahead(fwd: Vector3) -> bool:
	var front := global_position + fwd * 3.2
	var people: Array = []
	if Game.player:
		people.append(Game.player.global_position)
	for w in get_tree().get_nodes_in_group("crew_workers"):
		if (w as Worker).activity != "aboard" and (w as Worker).get_parent() is Node3D and not (w as Worker).seated:
			people.append((w as Node3D).global_position)
	for d in get_tree().get_nodes_in_group("camp_dog"):
		people.append((d as Node3D).global_position)
	for t in get_tree().get_nodes_in_group("trucks"):
		if t != self:
			people.append((t as Node3D).global_position)
	for q in people:
		var rel: Vector3 = q - front
		rel.y = 0.0
		if rel.length() < 3.6 and rel.dot(fwd) > -1.5:
			return true
	return false


func set_route(r: Array[Vector3]) -> void:
	route = r
	_ri = 1 if r.size() > 1 else 0
	blocked_for = 0.0


func arrived() -> bool:
	return mode == "auto" and _ri >= route.size() and _auto_speed < 0.2


func is_flipped() -> bool:
	return _flip_t > 3.0


# ----------------------------------------------------------------- visuals

func _update_visuals(delta: float) -> void:
	var v := speed()
	_wheel_spin += v * delta / WHEEL_R
	for i in 4:
		var w := _wheels[i]
		var base: Vector3 = WHEELS[i]
		w.position = base + Vector3(0, _compress[i] * 0.6 - 0.05, 0)
		var steer_r := steer_visual if i < 2 else 0.0
		w.rotation = Vector3(-_wheel_spin, steer_r, 0)
	var braking := (brake > 0.1 or (mode == "player" and throttle < 0.0 and v > 0.5)) and mode != "parked"
	_brake_mat.emission_energy_multiplier = 2.5 if braking else (0.6 if headlights else 0.15)
	var night: bool = Game.environment != null and Game.environment.is_night()
	var want_lights: bool = headlights or (mode == "auto" and night)
	_head_l.visible = want_lights
	_head_r.visible = want_lights
	(get_node("Model/SteeringWheel") as Node3D).rotation.z = -steer_visual * 3.0


# ------------------------------------------------------------------- cargo

func carrier() -> String:
	return "truck:" + truck_id


func cargo_mte() -> int:
	return Game.timber.carrier_mte(carrier()) if Game.timber else 0


func room_mte() -> int:
	return CAPACITY_MTE - cargo_mte()


## Restrained visual stack: pieces lie lengthwise in the bed in rows of
## three, never above the cab roofline; the quantity is always exact.
func refresh_cargo_visual() -> void:
	for c in _cargo_root.get_children():
		c.queue_free()
	if Game.timber == null:
		return
	var i := 0
	for sid in Game.timber.load_of(carrier()):
		var s := Game.timber.segment(sid)
		var rec: Dictionary = Game.timber.records.get(int(str(sid).trim_prefix("T").split("_S")[0]), {})
		if s.is_empty() or rec.is_empty():
			continue
		var r := TimberMesh.piece_radius(rec, int(s.k))
		var L := TimberMesh.piece_length(rec, int(s.k))
		var mi := MeshInstance3D.new()
		mi.mesh = TimberMesh.piece_mesh(rec, int(s.k))
		mi.basis = TimberMesh.frame_for(Vector3(0, 0, 1))
		var col := i % 3
		var row := i / 3
		var x := (float(col) - 1.0) * 0.56 + (0.14 if row % 2 == 1 else 0.0)
		mi.position = Vector3(x, r + float(row) * 0.32, 0.0)
		mi.scale = Vector3.ONE * minf(1.0, 2.3 / maxf(L, 0.1)) if L > 2.3 else Vector3.ONE
		_cargo_root.add_child(mi)
		i += 1
		if row >= 3:
			break
	# Two ratchet straps once anything is loaded.
	if i > 0:
		for z in [-0.6, 0.6]:
			BuildKit.box(_cargo_root, Vector3(1.9, 0.02, 0.06), Vector3(0, 0.95, z), "camper_stripe", false)
	cargo_changed.emit()


# ------------------------------------------------------------------- seats

func free_seat(prefer_driver := false) -> String:
	if prefer_driver and seats.driver == "":
		return "driver"
	for s in ["middle", "right", "driver"]:
		if seats[s] == "":
			return s
	return ""


func seat_of(who: String) -> String:
	for s in SEATS:
		if seats[s] == who:
			return s
	return ""


func occupants() -> Array:
	return SEATS.map(func(s: String) -> String: return seats[s]).filter(func(o: String) -> bool: return o != "")


# --------------------------------------------------------------- recovery

## Puts a stuck or flipped truck on the nearest verified drivable cell,
## upright, stationary. Occupants stay seated and cargo stays in the ledger.
func recover(nav: DriveNav) -> bool:
	var p := nav.nearest_drivable(global_position, 12)
	if p == Vector3.INF:
		return false
	var yaw := atan2(-(-global_basis.z).x, -(-global_basis.z).z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _ground_pose(p, yaw)
	_flip_t = 0.0
	return true


func capture() -> Dictionary:
	var t := global_transform
	return {"id": truck_id, "pose": TreeService._xf_to_array(t), "seats": seats.duplicate(), "headlights": headlights, "odometer": snappedf(odometer, 0.1)}
