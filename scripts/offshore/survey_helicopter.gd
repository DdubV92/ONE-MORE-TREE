class_name SurveyHelicopter
extends Node3D
## Phase 19: the survey vessel's helicopter (ambient; no colliders, no
## markings). States:
##   deck      parked on the moving pad (tracks the deck transform exactly)
##   spool     rotor spinning up on the pad
##   lift      rising off the pad in the deck's frame (tracks the ship)
##   fly       free flight along waypoints (steering, banking, clearance)
##   approach  converging on a point astern of and above the moving pad
##   final     descending in the deck frame to touchdown
##   landed    on the pad, rotor spinning down
##   exit      a credible offshore exit (missed recovery): flies out to sea
##             on the ship's departure side and is retired out of view
##   gone      retired
## Heights come from the service's clearance profile (terrain + standing
## canopy). Bank follows the turn: roll = atan(v * yaw_rate / g).

const G := 9.81

var svc: Node                       # OffshoreSurvey
var state := "deck"
var st_t := 0.0                     # seconds in the current state
var vel := Vector3.ZERO
var yaw := 0.0                      # heading (rad), 0 = -Z
var bank := 0.0
var pitch := 0.0
var rotor := 0.0                    # 0..1 rotor speed
var wps: Array = []                 # [[Vector3 xz target, leg label, agl]]
var wp_i := 0
var leg := ""
var local := Vector3.ZERO           # offset in the deck frame (deck/lift/final)
var rotor_handle := 0
var _yaw_rate := 0.0
var _spin := 0.0
var _upd := 0.0
var _body := Node3D.new()
var _main: Node3D
var _disc: MeshInstance3D
var _tail: Node3D


func _ready() -> void:
	name = "SurveyHelicopter"
	_body.name = "Body"
	add_child(_body)
	_build()


func _exit_tree() -> void:
	if rotor_handle > 0:
		SoundService.loop_stop(rotor_handle, 0.3)
		rotor_handle = 0


func _build() -> void:
	var paint := SurveyShip._m(Color(0.62, 0.64, 0.66), 0.45, 0.35)
	var dark := SurveyShip._m(Color(0.07, 0.08, 0.09), 0.2, 0.5)
	var under := SurveyShip._m(Color(0.32, 0.34, 0.36), 0.5, 0.3)
	var cabin := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 1.05
	cm.height = 5.6
	cabin.mesh = cm
	cabin.rotation.x = PI * 0.5
	cabin.position = Vector3(0, 1.6, 0)
	cabin.scale = Vector3(1.0, 1.0, 1.05)
	cabin.material_override = paint
	_body.add_child(cabin)
	BuildKit.box(_body, Vector3(1.9, 0.9, 2.0), Vector3(0, 1.75, -1.7), dark, false, 0.0, "Windscreen")
	BuildKit.box(_body, Vector3(2.12, 0.6, 1.6), Vector3(0, 1.85, 0.2), dark, false, 0.0, "SideWindows")
	BuildKit.box(_body, Vector3(1.6, 0.25, 4.2), Vector3(0, 0.7, 0), under, false, 0.0, "Belly")
	BuildKit.box(_body, Vector3(0.9, 0.7, 2.2), Vector3(0, 2.75, 0.5), paint, false, 0.0, "Engine")
	BuildKit.box(_body, Vector3(0.38, 0.45, 5.8), Vector3(0, 2.1, 5.2), paint, false, 0.0, "TailBoom")
	BuildKit.box(_body, Vector3(0.12, 1.6, 0.9), Vector3(0, 2.8, 7.9), paint, false, 0.0, "Fin")
	BuildKit.box(_body, Vector3(2.0, 0.08, 0.6), Vector3(0, 2.1, 6.6), paint, false, 0.0, "Stabiliser")
	for sx in [-1.0, 1.0]:
		BuildKit.box(_body, Vector3(0.1, 0.1, 3.6), Vector3(sx * 1.05, 0.05, 0.1), dark, false, 0.0, "Skid")
		for zz in [-0.9, 1.0]:
			BuildKit.box(_body, Vector3(0.08, 0.6, 0.08), Vector3(sx * 0.85, 0.35, zz), dark, false)
	BuildKit.cylinder(_body, 0.15, 0.5, Vector3(0, 3.25, 0.2), dark, false, 8)
	_main = Node3D.new()
	_main.name = "MainRotor"
	_main.position = Vector3(0, 3.55, 0.2)
	_body.add_child(_main)
	for k in 4:
		var b := BuildKit.box(_main, Vector3(0.32, 0.05, 5.4), Vector3(0, 0, 2.75), dark, false, 0.0, "Blade%d" % k)
		var pivot := Node3D.new()
		_main.add_child(pivot)
		b.reparent(pivot, false)
		pivot.rotation.y = k * PI * 0.5
	# Motion-blur disc, faded in with rotor speed.
	_disc = MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 5.5
	dm.bottom_radius = 5.5
	dm.height = 0.02
	dm.radial_segments = 24
	_disc.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(0.08, 0.09, 0.1, 0.0)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_disc.material_override = dmat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_main.add_child(_disc)
	_tail = Node3D.new()
	_tail.name = "TailRotor"
	_tail.position = Vector3(0.25, 2.9, 8.0)
	_body.add_child(_tail)
	for k in 2:
		var tb := BuildKit.box(_tail, Vector3(0.05, 1.5, 0.16), Vector3.ZERO, dark, false)
		tb.rotation.x = k * PI * 0.5


func airborne() -> bool:
	return state in ["lift", "fly", "approach", "final", "exit"]


func audible() -> bool:
	return rotor > 0.15 and state != "gone"


## Ground reference: the deck (on the ship) or the frozen route.
func _deck() -> Transform3D:
	return svc.deck_transform()


func _pose_on_deck() -> void:
	var d := _deck()
	global_transform = d * Transform3D(Basis.IDENTITY, local)
	yaw = _yaw_of(global_basis)


static func _yaw_of(b: Basis) -> float:
	var f := -b.z
	return atan2(-f.x, -f.z)


func set_state(s: String) -> void:
	state = s
	st_t = 0.0


func step(dt: float) -> void:
	st_t += dt
	match state:
		"deck":
			local = Vector3.ZERO
			rotor = move_toward(rotor, 0.0, dt / 20.0)
			_pose_on_deck()
		"spool":
			local = Vector3.ZERO
			rotor = move_toward(rotor, 1.0, dt / float(svc.hc("spool_s", 12.0)))
			_pose_on_deck()
			if st_t >= float(svc.hc("spool_s", 12.0)):
				set_state("lift")
		"lift":
			rotor = 1.0
			var T := float(svc.hc("lift_s", 9.0))
			var u := smoothstep(0.0, 1.0, st_t / T)
			local = Vector3(0, u * float(svc.hc("lift_h", 18.0)), u * 6.0)
			_pose_on_deck()
			if st_t >= T:
				# Hand over to free flight with the deck's velocity.
				vel = svc.ship_velocity() + Vector3(0, 2.0, 0)
				set_state("fly")
		"fly":
			rotor = 1.0
			_fly(dt)
		"approach":
			rotor = 1.0
			_approach(dt)
		"final":
			rotor = 1.0
			var T2 := float(svc.hc("final_s", 16.0))
			var from: Vector3 = svc.heli_final_from
			var u2 := smoothstep(0.0, 1.0, st_t / T2)
			local = from.lerp(Vector3.ZERO, u2)
			var d := _deck()
			global_transform = d * Transform3D(Basis.IDENTITY.rotated(Vector3.UP, lerpf(svc.heli_final_yaw, 0.0, u2)), local)
			yaw = _yaw_of(global_basis)
			bank = lerpf(bank, 0.0, clampf(dt * 2.0, 0, 1))
			if st_t >= T2:
				local = Vector3.ZERO
				_pose_on_deck()
				set_state("landed")
				svc.on_heli_landed()
		"landed":
			local = Vector3.ZERO
			rotor = move_toward(rotor, 0.0, dt / float(svc.hc("spin_down_s", 20.0)))
			_pose_on_deck()
		"exit":
			rotor = 1.0
			_steer(svc.heli_exit_point(), dt, float(svc.hc("cruise", 36.0)), 120.0)
			if svc.heli_out_of_view(global_position):
				set_state("gone")
				visible = false
				svc.on_heli_retired()
		"gone":
			rotor = 0.0
	_audio()


## Free flight along the survey waypoints at the clearance profile.
func _fly(dt: float) -> void:
	if wp_i >= wps.size():
		svc.on_heli_route_done()
		return
	var wp: Array = wps[wp_i]
	var tgt: Vector3 = wp[0]
	leg = str(wp[1])
	var spd := float(svc.hc("survey_speed", 28.0)) if leg != "transit" else float(svc.hc("cruise", 36.0))
	var agl := float(wp[2])
	_steer(tgt, dt, spd, agl)
	var flat := Vector2(tgt.x - global_position.x, tgt.z - global_position.z)
	if flat.length() < maxf(40.0, spd * 1.5):
		wp_i += 1
		svc.on_heli_waypoint(wp_i)


## Steering with a turn-rate limit, smooth speed, clearance-based height
## and coordinated banking.
func _steer(tgt: Vector3, dt: float, spd: float, agl: float) -> void:
	var p := global_position
	var to := Vector3(tgt.x - p.x, 0, tgt.z - p.z)
	var want_yaw := atan2(-to.x, -to.z) if to.length() > 1.0 else yaw
	var max_rate := deg_to_rad(float(svc.hc("turn_rate_deg", 14.0)))
	var dyaw := wrapf(want_yaw - yaw, -PI, PI)
	var rate := clampf(dyaw * 0.8, -max_rate, max_rate)
	_yaw_rate = lerpf(_yaw_rate, rate, clampf(dt * 1.5, 0, 1))
	yaw = wrapf(yaw + _yaw_rate * dt, -PI, PI)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var h_speed := Vector2(vel.x, vel.z).length()
	var new_speed := move_toward(h_speed, spd, dt * 3.0)
	var ground: float = svc.clearance_floor(p, fwd, new_speed)
	var want_y := ground + agl
	var vy := clampf((want_y - p.y) * 0.4, -float(svc.hc("climb_rate", 6.0)), float(svc.hc("climb_rate", 6.0)))
	var accel_f := (new_speed - h_speed) / maxf(dt, 0.001)
	vel = fwd * new_speed + Vector3(0, vy, 0)
	global_position = p + vel * dt
	# Hard floor: never below the clearance floor + 20 m in free flight.
	if global_position.y < ground + 20.0:
		global_position.y = ground + 20.0
	var max_bank := deg_to_rad(float(svc.hc("max_bank_deg", 28.0)))
	bank = lerpf(bank, clampf(atan(new_speed * _yaw_rate / G), -max_bank, max_bank), clampf(dt * 2.0, 0, 1))
	pitch = lerpf(pitch, clampf(-new_speed / 400.0 - accel_f / G * 0.5, -0.25, 0.15), clampf(dt * 1.5, 0, 1))
	global_basis = Basis.from_euler(Vector3(pitch, yaw, -bank), EULER_ORDER_YXZ)


## Converge on the moving approach gate (astern of and above the pad),
## matching the ship's velocity on arrival.
func _approach(dt: float) -> void:
	var gate: Vector3 = svc.approach_gate()
	var sv: Vector3 = svc.ship_velocity()
	var p := global_position
	var rel := gate - p
	var dist := rel.length()
	var closing := clampf(dist * 0.12, 0.0, float(svc.hc("cruise", 36.0)))
	var want := sv + rel.normalized() * closing if dist > 0.5 else sv
	vel = vel.lerp(want, clampf(dt * 0.8, 0, 1))
	global_position = p + vel * dt
	var hv := Vector3(vel.x, 0, vel.z)
	if hv.length() > 2.0:
		var want_yaw := atan2(-hv.x, -hv.z)
		var dyaw := wrapf(want_yaw - yaw, -PI, PI)
		_yaw_rate = clampf(dyaw * 0.8, -0.25, 0.25)
		yaw = wrapf(yaw + _yaw_rate * dt, -PI, PI)
	var max_bank := deg_to_rad(float(svc.hc("max_bank_deg", 28.0)))
	bank = lerpf(bank, clampf(atan(hv.length() * _yaw_rate / G), -max_bank, max_bank), clampf(dt * 2.0, 0, 1))
	pitch = lerpf(pitch, -hv.length() / 500.0, clampf(dt, 0, 1))
	global_basis = Basis.from_euler(Vector3(pitch, yaw, -bank), EULER_ORDER_YXZ)
	if dist < 12.0 and (vel - sv).length() < 4.0:
		svc.begin_final(self)


func _audio() -> void:
	if rotor > 0.05 and rotor_handle <= 0 and state != "gone":
		rotor_handle = SoundService.loop("offshore.heli.rotor", self, {"offset": Vector3(0, 3.0, 0)})
	if rotor_handle > 0:
		if rotor <= 0.02 or state == "gone":
			SoundService.loop_stop(rotor_handle, 0.6)
			rotor_handle = 0
		else:
			SoundService.loop_set(rotor_handle, linear_to_db(maxf(rotor, 0.01)) * 0.6, lerpf(0.55, 1.0, rotor))


## Bounded animation: rotor spin and the blur disc update every frame
## within 600 m of the camera, at 10 Hz beyond, and not at all past 3 km.
func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var d := cam.global_position.distance_to(global_position) if cam else 9999.0
	_spin += rotor * delta * 38.0
	if d > 3000.0 or not visible:
		return
	_upd -= delta
	if d > 600.0 and _upd > 0.0:
		return
	_upd = 0.1
	_main.rotation.y = _spin
	_tail.rotation.x = _spin * 5.0
	(_disc.material_override as StandardMaterial3D).albedo_color.a = clampf((rotor - 0.4) * 0.5, 0.0, 0.22)


func capture() -> Dictionary:
	var p := global_position
	return {"state": state, "st_t": st_t, "pos": [p.x, p.y, p.z], "vel": [vel.x, vel.y, vel.z], "yaw": yaw, "rotor": rotor, "wp_i": wp_i, "local": [local.x, local.y, local.z],
		"wps": wps.map(func(w: Array) -> Array: return [(w[0] as Vector3).x, (w[0] as Vector3).y, (w[0] as Vector3).z, w[1], w[2]])}


func restore(d: Dictionary) -> void:
	state = str(d.get("state", "deck"))
	st_t = float(d.get("st_t", 0.0))
	var p: Array = d.get("pos", [0, 0, 0])
	var v: Array = d.get("vel", [0, 0, 0])
	var l: Array = d.get("local", [0, 0, 0])
	vel = Vector3(v[0], v[1], v[2])
	yaw = float(d.get("yaw", 0.0))
	rotor = float(d.get("rotor", 0.0))
	wp_i = int(d.get("wp_i", 0))
	local = Vector3(l[0], l[1], l[2])
	wps.clear()
	for w in d.get("wps", []):
		wps.append([Vector3(w[0], w[1], w[2]), str(w[3]), float(w[4])])
	global_position = Vector3(p[0], p[1], p[2])
	global_basis = Basis.from_euler(Vector3(0, yaw, 0), EULER_ORDER_YXZ)
	visible = state != "gone"
