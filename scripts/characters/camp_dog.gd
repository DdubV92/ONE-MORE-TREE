class_name CampDog
extends Node3D
## Biscuit, the boss's dog (Phase 5). One persistent, friendly, unharmable
## companion with an articulated body (DogCharacter).
##
## Ordinary life ("camp" routine): by day wanders the fenced camp on the
## crew's camp grid, sniffs, sits, naps and now and then comes over to the
## boss. Avoids the burn pit, moving trucks and blocked spots. At dusk it
## walks home on its own - across the yard, up the camper ramp and in
## through the dog flap in the camper door (or the open door) - and sleeps
## on its bed; after dawn it gets up and goes out the same way. Never
## teleports in routine play.
##
## Survival interface ("refuge" / "boarded" routines, used by Phase 6): the
## same dog can be sent to the dry alcove at the utility building and kept
## there; board_ship() hands it to the rescue boat exactly once. These are
## separate saved states of the same identity, not a second dog.
##
## Reactions: real nearby sounds (SoundEvents) and sound replayed by the
## TV make it prick its ears and look; big crashes nearby make it alert or
## retreat. Cooldowns keep it calm. No hunger, no meters, no damage.

signal boarded

enum State { IDLE, WANDER, SIT, NAP, APPROACH, PET, ALERT, RETREAT, GO_HOME, SLEEP, WAKE, TO_REFUGE, REFUGE, BOARDING, BOARDED }

const DOG_ID := "dog_biscuit"
const DOG_NAME := "Biscuit"
const DUSK_HOUR := 19.0
const WAKE_HOUR := 6.4

var dog: DogCharacter
var state := State.IDLE
var routine := "camp"          # camp / refuge / boarded
var boarded_once := false
var speed := 0.0
var want_speed := 0.0
var timer := 1.5
var path: Array[Vector3] = []
var authored: Array[bool] = []  # per path point: true = explicit height (ramp/interior)
var events: Array[String] = []  # flap/door passages, for tests
var flap_uses := 0
var _pi := 0
var _rng := RandomNumberGenerator.new()
var _alert_cd := 0.0
var _approach_cd := 45.0
var _whine_cd := 0.0
var _check_t := 0.0
var _stuck_t := 0.0
var _last_p := Vector3.ZERO
var _after := State.IDLE
var _face := Vector3.INF
var _rest_clip := "idle"
var _flap_points := {}          # path index -> outward(bool)
var _pet_t := 0.0
var voice: AudioStreamPlayer3D
var hotspot: Hotspot
var _streams := {}


func _ready() -> void:
	_rng.seed = 314
	add_to_group("camp_dog")
	dog = DogCharacter.new()
	add_child(dog)
	_build_collar()
	voice = AudioStreamPlayer3D.new()
	voice.bus = "Characters"
	voice.unit_size = 4.0
	voice.position = Vector3(0, 0.6, -0.35)
	add_child(voice)
	hotspot = Hotspot.make(self, "PetSpot", Vector3(0.45, 0.7, 0.95), Vector3(0, 0.45, 0), _pet_text, pet)
	global_position = _camp_point(Vector3(-1, 0, 3))
	SoundEvents.listen(hear)


func _exit_tree() -> void:
	SoundEvents.unlisten(hear)


## Red collar with a brass tag: the dog's visible identity.
func _build_collar() -> void:
	var neck: Node3D = dog.bones.get("Neck")
	if neck == null:
		return
	var collar := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.075
	tm.outer_radius = 0.095
	collar.mesh = tm
	collar.material_override = CharMeshKit.mat(Color(0.75, 0.12, 0.1), 0.5)
	collar.position = Vector3(0, 0.03, -0.02)
	collar.rotation.x = -0.9
	neck.add_child(collar)
	var tag := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 0.005
	tag.mesh = cm
	var brass := CharMeshKit.mat(Color(0.85, 0.68, 0.3), 0.3)
	brass.metallic = 0.8
	tag.material_override = brass
	tag.position = Vector3(0, -0.06, -0.09)
	tag.rotation.x = PI * 0.5
	neck.add_child(tag)


# ------------------------------------------------------------ geometry

func _camp_point(local: Vector3) -> Vector3:
	var p := CampLayout.world(local)
	p.y = _surface(p)
	return p


func _nav() -> CrewNav:
	return Game.crew.nav if Game.crew and Game.crew.nav and Game.crew.nav.built else null


func _surface(p: Vector3) -> float:
	var n := _nav()
	return n.surface_at(p) if n else World.height_at(p.x, p.z)


func _camper() -> Node3D:
	return Game.world_root.find_child("Camper", true, false) as Node3D if Game.world_root else null


func _camper_door() -> Door:
	var c := _camper()
	return c.find_child("CamperDoor", false, false) as Door if c else null


## Authored camper access route, from the yard (ramp foot) to the dog bed:
## ramp foot -> ramp top -> door threshold (flap) -> inside -> bed.
func _camper_route() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var c := _camper()
	if c == null:
		return out
	var W := CampLayout.CAMPER_SIZE.x * 0.5
	var F := CampLayout.CAMPER_FLOOR
	var t := 0.08
	var foot := c.global_transform * Vector3(W + 1.75, 0, 1.85)
	foot.y = _surface(foot)
	out.append(foot)
	out.append(c.global_transform * Vector3(W + t + 0.15, F, 1.85))
	out.append(c.global_transform * Vector3(W + t * 0.5, F, 1.85))
	out.append(c.global_transform * Vector3(W - 0.55, F, 1.85))
	var beds := get_tree().get_nodes_in_group("dog_bed")
	var bed := (beds[0] as Node3D).global_position if not beds.is_empty() else c.global_transform * Vector3(0.85, F, 0.8)
	bed.y = c.global_position.y + F
	out.append(bed)
	return out


func inside_camper() -> bool:
	var c := _camper()
	if c == null:
		return false
	var l := c.global_transform.affine_inverse() * global_position
	return absf(l.x) < CampLayout.CAMPER_SIZE.x * 0.5 + 0.06 and absf(l.z) < CampLayout.CAMPER_SIZE.z * 0.5 and l.y > CampLayout.CAMPER_FLOOR - 0.2


func _fire_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in get_tree().get_nodes_in_group("interactable_fire"):
		out.append((f as Node3D).global_position)
	return out


func _good_spot(p: Vector3) -> bool:
	var n := _nav()
	if n and (not n.in_camp(p) or not n.walkable(p)):
		return false
	if World.water_depth_at(p.x, p.z) > 0.0:
		return false
	for f in _fire_points():
		if Vector2(f.x - p.x, f.z - p.z).length() < 3.6:
			return false
	return true


# ------------------------------------------------------------- planning

## Plans a walk over the camp/island grid. Points get the walking surface
## height. Returns false when there is no route.
func _plan(to: Vector3, after: State, spd: float) -> bool:
	var n := _nav()
	var pts: Array[Vector3] = []
	if n:
		pts = n.find_path(global_position, to)
		if pts.is_empty():
			return false
		pts.append(to)
	else:
		pts = [to]
	for f in _fire_points():
		for p in pts:
			if Vector2(f.x - p.x, f.z - p.z).length() < 2.6:
				return false
	path = pts
	authored.clear()
	for p in pts:
		authored.append(false)
	_flap_points.clear()
	_pi = 0
	_after = after
	want_speed = spd
	return true


## Appends the authored camper route (reversed when leaving).
func _append_camper(inbound: bool) -> void:
	var r := _camper_route()
	if r.is_empty():
		return
	if not inbound:
		r.reverse()
	for i in r.size():
		path.append(r[i])
		authored.append(true)
		# The threshold point is where the flap (or open door) is crossed.
		if (inbound and i == 2) or (not inbound and i == 2):
			_flap_points[path.size() - 1] = not inbound


func go_home() -> void:
	if routine != "camp":
		return
	if inside_camper():
		var r := _camper_route()
		path = [r[r.size() - 1]]
		authored = [true]
		_flap_points.clear()
		_pi = 0
		_after = State.SLEEP
		want_speed = DogCharacter.WALK_NOMINAL_SPEED
		state = State.GO_HOME
		return
	var r2 := _camper_route()
	if r2.is_empty() or not _plan(r2[0], State.SLEEP, 1.9):
		# Direct fallback across the yard (never through walls: the camp
		# grid has no route only if the dog is already at the ramp).
		path = []
		authored = []
		_flap_points.clear()
		_pi = 0
		_after = State.SLEEP
	_append_camper(true)
	want_speed = 1.9
	state = State.GO_HOME
	events.append("go_home")


func _leave_camper() -> void:
	var r := _camper_route()
	path = []
	authored = []
	_flap_points.clear()
	_pi = 0
	_append_camper(false)
	var out := _camp_point(Vector3(4, 0, 2))
	path.append(out)
	authored.append(false)
	_after = State.IDLE
	want_speed = DogCharacter.WALK_NOMINAL_SPEED
	state = State.WAKE
	events.append("leave_camper")
	if r.is_empty():
		state = State.IDLE


# --------------------------------------------------------------- update

func _process(delta: float) -> void:
	if state == State.BOARDED:
		return
	_alert_cd = maxf(_alert_cd - delta, 0.0)
	_approach_cd = maxf(_approach_cd - delta, 0.0)
	_whine_cd = maxf(_whine_cd - delta, 0.0)
	var hour: float = Game.environment.hour if Game.environment else 12.0
	var night := hour >= DUSK_HOUR or hour < WAKE_HOUR
	if routine == "camp":
		if night and not state in [State.GO_HOME, State.SLEEP]:
			go_home()
		elif not night and state == State.SLEEP:
			_leave_camper()
	match state:
		State.WANDER, State.APPROACH, State.RETREAT, State.GO_HOME, State.WAKE, State.TO_REFUGE, State.BOARDING:
			_follow(delta)
			_check_t -= delta
			if _check_t <= 0.0 and state in [State.WANDER, State.APPROACH]:
				_check_t = 0.4
				_avoid_vehicles()
		State.IDLE:
			_brake(delta)
			timer -= delta
			if timer <= 0.0:
				_decide()
		State.SIT, State.NAP, State.ALERT:
			_brake(delta)
			if _face != Vector3.INF:
				_turn_toward(_face, delta)
			timer -= delta
			if timer <= 0.0:
				dog.look_weight = 0.0
				dog.ear_perk = 0.0
				state = State.IDLE
				timer = _rng.randf_range(0.5, 2.0)
		State.PET:
			_brake(delta)
			_pet_t -= delta
			var p := Game.player
			if p:
				_turn_toward(p.global_position, delta)
				dog.look_target = (p as Node3D).global_position + Vector3(0, 1.0, 0)
			if _pet_t <= 0.0 or p == null or p.global_position.distance_to(global_position) > 2.6:
				state = State.IDLE
				timer = 1.0
				dog.look_weight = 0.0
		State.SLEEP, State.REFUGE:
			speed = 0.0
	match state:
		State.SIT, State.APPROACH:
			_rest_clip = "sit"
		State.NAP, State.SLEEP:
			_rest_clip = "lie"
		State.REFUGE:
			_rest_clip = "lie"
		State.ALERT:
			_rest_clip = "alert"
		State.PET:
			_rest_clip = "pet"
		_:
			_rest_clip = "idle"
	dog.set_locomotion(speed, _rest_clip)


func _brake(delta: float) -> void:
	speed = move_toward(speed, 0.0, delta * 3.0)


func _decide() -> void:
	var p := Game.player as Node3D
	var n := _nav()
	if p and _approach_cd <= 0.0 and n and n.in_camp(p.global_position) and p.get("vehicle") == null and p.global_position.distance_to(global_position) < 28.0 and _rng.randf() < 0.35:
		var to := p.global_position + (global_position - p.global_position).normalized() * 1.3
		to.y = _surface(to)
		if _good_spot(to) and _plan(to, State.SIT, 1.9):
			state = State.APPROACH
			_approach_cd = _rng.randf_range(70.0, 140.0)
			_face = p.global_position
			return
	var r := _rng.randf()
	if r < 0.18:
		state = State.SIT
		timer = _rng.randf_range(4.0, 9.0)
		_face = Vector3.INF
		return
	if r < 0.26:
		state = State.NAP
		timer = _rng.randf_range(14.0, 30.0)
		_face = Vector3.INF
		return
	for attempt in 14:
		var cand := _random_spot()
		if cand != Vector3.INF and _plan(cand, State.IDLE, DogCharacter.WALK_NOMINAL_SPEED * _rng.randf_range(0.8, 1.15)):
			state = State.WANDER
			timer = _rng.randf_range(2.0, 6.0)
			return
	timer = 1.5


func _random_spot() -> Vector3:
	var n := _nav()
	if n == null:
		return Vector3.INF
	var r := n.camp_rect.grow(-2.0)
	for k in 10:
		var c := Vector3(_rng.randf_range(r.position.x, r.end.x), 0, _rng.randf_range(r.position.y, r.end.y))
		if c.distance_to(Vector3(global_position.x, 0, global_position.z)) > 22.0:
			continue
		c.y = _surface(c)
		if _good_spot(c):
			return c
	return Vector3.INF


func _follow(delta: float) -> void:
	if _pi >= path.size():
		_arrive()
		return
	var target := path[_pi]
	var to := target - global_position
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() < 0.25:
		if _flap_points.has(_pi):
			_pass_door(bool(_flap_points[_pi]))
		_pi += 1
		return
	speed = move_toward(speed, want_speed, delta * 2.5)
	var dir := flat.normalized()
	var step := minf(speed * delta, flat.length())
	var next := global_position + dir * step
	if authored[_pi]:
		# Explicit heights: ramp slope and camper floor.
		var prev := path[_pi - 1] if _pi > 0 else global_position
		var seg := Vector2(target.x - prev.x, target.z - prev.z).length()
		var done := 1.0 - Vector2(target.x - next.x, target.z - next.z).length() / maxf(seg, 0.01)
		next.y = lerpf(prev.y if _pi > 0 else global_position.y, target.y, clampf(done, 0.0, 1.0))
	else:
		next.y = _surface(next)
	global_position = next
	_turn_toward(target, delta)
	# Stuck guard: re-plan instead of sliding through anything.
	_stuck_t += delta
	if _stuck_t > 2.0:
		if global_position.distance_to(_last_p) < 0.3 and not authored[_pi]:
			_pi = path.size()
		_last_p = global_position
		_stuck_t = 0.0


func _turn_toward(p: Vector3, delta: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.05:
		return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * 5.0, 0.0, 1.0))


func _arrive() -> void:
	path.clear()
	authored.clear()
	match _after:
		State.SLEEP:
			state = State.SLEEP
			rotation.y = (_camper().global_rotation.y + 0.6) if _camper() else 0.6
			events.append("in_bed")
		State.SIT:
			state = State.SIT
			timer = _rng.randf_range(5.0, 8.0)
			if Game.player:
				dog.look_target = Game.player.global_position + Vector3(0, 1.4, 0)
				dog.look_weight = 0.8
		State.REFUGE:
			state = State.REFUGE
			events.append("in_refuge")
		State.BOARDED:
			state = State.BOARDED
			visible = false
			hotspot.collision_layer = 0
			events.append("boarded")
			boarded.emit()
		_:
			state = State.IDLE
			timer = _rng.randf_range(1.0, 4.0)


func _pass_door(outward: bool) -> void:
	var d := _camper_door()
	if d == null:
		return
	if d.is_open:
		events.append("door_open_" + ("out" if outward else "in"))
	else:
		d.swing_flap(outward)
		flap_uses += 1
		events.append("flap_" + ("out" if outward else "in"))
		_play("dog_flap", -12.0)


## Moving trucks nearby: give way, move off to the side.
func _avoid_vehicles() -> void:
	if Game.vehicles == null:
		return
	for t in Game.vehicles.trucks.values():
		var tr := t as Truck
		if tr.mode == "parked" or absf(tr.speed()) < 0.8:
			continue
		var d := tr.global_position - global_position
		if Vector2(d.x, d.z).length() < 9.0:
			var away := -Vector3(d.x, 0, d.z).normalized()
			for k in 6:
				var cand := global_position + away.rotated(Vector3.UP, (k - 2.5) * 0.4) * 6.0
				cand.y = _surface(cand)
				if _good_spot(cand) and _plan(cand, State.SIT, 2.3):
					state = State.RETREAT
					events.append("avoid_vehicle")
					return


# ------------------------------------------------------------ reactions

## A real sound in the world (or replayed by the TV, category "tv").
## Ears/head turn toward it; big crashes close by cause an alert or a
## retreat. Calm cooldowns; it does not bark at every noise.
func hear(_stream: AudioStream, pos: Vector3, _volume_db: float, category := "world", label := "") -> void:
	if state in [State.SLEEP, State.BOARDED, State.PET, State.GO_HOME, State.WAKE, State.BOARDING]:
		return
	var d := pos.distance_to(global_position)
	var crash := label in ["a tree falling", "trunk cracking"]
	var reach := 45.0 if crash else (8.0 if category == "tv" else 22.0)
	if d > reach or _alert_cd > 0.0:
		return
	if category == "steps":
		return    # the boss walking around is normal
	if routine != "camp" or state in [State.TO_REFUGE, State.REFUGE]:
		# In the refuge it only listens; it never wanders off.
		dog.look_target = pos + Vector3(0, 0.5, 0)
		dog.look_weight = 0.7
		dog.ear_perk = 1.0
		_alert_cd = 6.0
		return
	_alert_cd = 6.0 if not crash else 12.0
	dog.look_target = pos + Vector3(0, 0.5, 0)
	dog.look_weight = 0.9
	dog.ear_perk = 1.0
	if crash and d < 16.0 and routine == "camp" and state != State.REFUGE:
		var safe := _camp_point(Vector3(3.5, 0, 1.0))
		if _plan(safe, State.SIT, 2.4):
			state = State.RETREAT
			events.append("retreat")
			if _whine_cd <= 0.0:
				_whine_cd = 30.0
				_play("dog_whine_%d" % (_rng.randi() % 2), -10.0)
			return
	if state in [State.IDLE, State.SIT, State.NAP, State.WANDER]:
		state = State.ALERT
		timer = 3.0 if crash else 1.8
		_face = pos
		events.append("alert")
	if category == "tv" and crash and _whine_cd <= 0.0:
		_whine_cd = 60.0
		_play("dog_whine_0", -14.0)


## Phase 6 hook: a genuine threat cue nearby (not used by ordinary life).
func react_threat(pos: Vector3) -> void:
	dog.look_target = pos + Vector3(0, 0.6, 0)
	dog.look_weight = 1.0
	dog.ear_perk = 1.0
	_face = pos
	state = State.ALERT
	timer = 4.0
	_play("dog_growl", -8.0)
	events.append("growl")


func _play(name: String, db: float) -> void:
	if not _streams.has(name):
		var path_s := "res://audio/generated/%s.wav" % name
		_streams[name] = load(path_s) if ResourceLoader.exists(path_s) else null
	var s: AudioStream = _streams[name]
	if s == null:
		return
	voice.stream = s
	voice.volume_db = db
	voice.play()
	SoundEvents.emit(s, voice.global_position, db, "dog", "the dog")


# -------------------------------------------------------------- petting

func _pet_text() -> String:
	if state == State.BOARDED:
		return ""
	if state == State.SLEEP:
		return "Gently pet %s (asleep)" % DOG_NAME
	return "Pet %s" % DOG_NAME


## Short, optional, cancellable (walk away to end it).
func pet(by: Node) -> void:
	if state == State.BOARDED:
		return
	if state == State.SLEEP or state == State.REFUGE:
		if by and by.has_method("show_message"):
			by.show_message("%s's tail thumps on the bed." % DOG_NAME)
		return
	path.clear()
	authored.clear()
	state = State.PET
	_pet_t = 3.5
	dog.look_weight = 1.0
	_play("dog_pant", -16.0)
	events.append("petted")
	if by and by.has_method("show_message"):
		by.show_message("Good dog, %s." % DOG_NAME)


# ---------------------------------------------- survival interface (P6)

## Sends the dog to the dry dock-side alcove and keeps it there.
func enter_refuge() -> bool:
	var anchors := get_tree().get_nodes_in_group("dog_refuge")
	if anchors.is_empty() or routine == "boarded":
		return false
	routine = "refuge"
	var a := (anchors[0] as Node3D).global_position
	# Walk to the ground in front of the alcove, then up its little ramp.
	var app := get_tree().get_nodes_in_group("dog_refuge_approach")
	var near := (app[0] as Node3D).global_position if not app.is_empty() else a
	if inside_camper():
		_leave_camper()
		var n := _nav()
		if n:
			var leg := n.find_path(path[path.size() - 1], near)
			if leg.is_empty():
				return false
			for q in leg:
				path.append(q)
				authored.append(false)
		path.append(near)
		authored.append(false)
	elif not _plan(near, State.REFUGE, 2.0):
		return false
	_after = State.REFUGE
	want_speed = 2.0
	path.append(a)
	authored.append(true)
	state = State.TO_REFUGE
	events.append("to_refuge")
	return true


func leave_refuge() -> void:
	if routine == "refuge":
		routine = "camp"
		state = State.IDLE
		timer = 1.0


## Hands the dog to the rescue boat exactly once (Phase 6 calls this).
func board_ship() -> bool:
	if boarded_once or routine != "refuge":
		return false
	var anchors := get_tree().get_nodes_in_group("ship_boarding")
	if anchors.is_empty():
		return false
	boarded_once = true
	routine = "boarded"
	var a := (anchors[0] as Node3D).global_position
	path = [a]
	authored = [true]
	_flap_points.clear()
	_pi = 0
	_after = State.BOARDED
	want_speed = 1.6
	state = State.BOARDING
	events.append("boarding")
	return true


## Reserved (Phase 6): the once-only wind-door escape needs its full route,
## grace, checkpoint and recovery logic first. Never triggered in Phase 5.
func reserve_wind_door_escape() -> bool:
	return false


# ----------------------------------------------------------- persistence

func capture() -> Dictionary:
	return {"id": DOG_ID, "name": DOG_NAME, "routine": routine, "state": State.keys()[state], "pos": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y, "boarded_once": boarded_once}


## Restores a valid pose: mid-route states resolve to the nearest legal one
## (in bed if it was inside at night, in the yard by day, at the refuge).
func restore(d: Dictionary) -> void:
	routine = str(d.get("routine", "camp"))
	if not routine in ["camp", "refuge", "boarded"]:
		routine = "camp"
	boarded_once = bool(d.get("boarded_once", false))
	var pa: Array = d.get("pos", [])
	if pa.size() == 3:
		global_position = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
	rotation.y = float(d.get("yaw", 0.0))
	path.clear()
	authored.clear()
	var s := str(d.get("state", "IDLE"))
	match routine:
		"boarded":
			state = State.BOARDED
			visible = false
			hotspot.collision_layer = 0
			return
		"refuge":
			var anchors := get_tree().get_nodes_in_group("dog_refuge")
			if not anchors.is_empty() and s != "TO_REFUGE":
				global_position = (anchors[0] as Node3D).global_position
			state = State.REFUGE
			if s == "TO_REFUGE":
				routine = "camp"
				enter_refuge()
			return
	visible = true
	if s in ["SLEEP", "GO_HOME"] and inside_camper():
		var r := _camper_route()
		if not r.is_empty():
			global_position = r[r.size() - 1]
		state = State.SLEEP
	elif inside_camper():
		_leave_camper()
	else:
		var n := _nav()
		if n and not n.walkable(global_position):
			global_position = _camp_point(Vector3(-1, 0, 3))
		global_position.y = _surface(global_position)
		state = State.IDLE
		timer = 1.0
