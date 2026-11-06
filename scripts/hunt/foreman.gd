class_name Foreman
extends Node3D
## The single physical hunter of HUNT_ACTIVE (days 31-35). One persistent
## body; no clones, no teleports, no map-wide interception. It moves only
## along real routes (crew navigation grids, authored door folds), senses
## through field of view + distance + light + occlusion and through actual
## in-world noises with uncertainty, and keeps decaying evidence. It never
## reads a hidden person's transform: hidden targets are found only by
## probing a spot it has reason to suspect. Attacks are telegraphed and
## re-checked on the commit frame. The dog is never a target.
##
## States: ARRIVAL, ROAM, LISTEN, NOTICE, INVESTIGATE, CONFIRM, CHASE,
## LOST_CONTACT, SEARCH, SHELTER_PROBE, INSPECT_TRUCK, ATTACK, DISENGAGE,
## RECOVER.

signal pattern(id: String)
signal killed(target: Node)

const WALK := 1.7
const SEARCH_SPEED := 1.3
const SPRINT := 7.3
const SPRINT_MAX := 7.0
const REACH := 1.7
const FOV_COS := 0.5             # 120 degrees
const CONFIRM_NEEDED := 0.9

var state := "ARRIVAL"
var st_t := 0.0
var body: ForemanBody
var path: Array[Vector3] = []
var _pi := 0
var speed := 0.0
var want_speed := WALK
var target: Node3D                # who it is currently pursuing (seen)
var confirm := 0.0
var evidence: Array[Dictionary] = []   # {pos, r, t, w, kind, spot}
var last_seen := {}               # {pos, heading, t, who}
var searched: Array[Vector3] = []
var search_queue: Array[Dictionary] = []
var false_departure_used := false
var grace := 90.0                 # initial separation: no hunting during it
var chase_t := 0.0
var attack_t := 0.0
var attack_target: Node3D
var probe: HideSpot
var probe_t := 0.0
var interior_route: Array[Vector3] = []
var roam_points: Array[Vector3] = []
var hint_cd := 120.0
var listen_cd := 20.0
var voice_cd := 140.0
var observed := {}                # pattern id -> count
var kills := 0
var _rng := RandomNumberGenerator.new()
var _replan_t := 0.0
var _audio: AudioStreamPlayer3D
var _tags: AudioStreamPlayer3D
var _step_t := 0.0
var _steps_hooked := false
var _feet: AudioStreamPlayer3D
var steps_played := 0
var _stuck_t := 0.0
var _stuck_from := Vector3.ZERO


func _ready() -> void:
	add_to_group("foreman")
	_rng.seed = 3131
	body = ForemanBody.new()
	add_child(body)
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = "Horror"
	_audio.unit_size = 7.0
	_audio.position = Vector3(0, 2.2, 0)
	add_child(_audio)
	_tags = AudioStreamPlayer3D.new()
	_tags.bus = "Horror"
	_tags.unit_size = 2.5
	_tags.position = Vector3(0, 2.4, -0.2)
	add_child(_tags)
	SoundEvents.listen(_on_sound)


func _exit_tree() -> void:
	SoundEvents.unlisten(_on_sound)


func mark(id: String) -> void:
	observed[id] = int(observed.get(id, 0)) + 1
	pattern.emit(id)


func _nav() -> CrewNav:
	return Game.crew.nav if Game.crew and Game.crew.nav and Game.crew.nav.built else null


func _surface(p: Vector3) -> float:
	var n := _nav()
	return n.surface_at(p) if n else World.height_at(p.x, p.z)


func set_state(s: String) -> void:
	if s == state:
		return
	state = s
	st_t = 0.0
	match s:
		"CHASE":
			chase_t = 0.0
			_play("f_intake", 0.0)
			mark("F-H31")
		"LISTEN":
			body.tags_silent = true
			body.pose = "listen"
		"SEARCH", "SHELTER_PROBE":
			want_speed = SEARCH_SPEED
		"DISENGAGE":
			want_speed = WALK
	if s != "LISTEN":
		body.tags_silent = false


# -------------------------------------------------------------- moving

func go_to(dest: Vector3, spd: float) -> bool:
	var n := _nav()
	var pts: Array[Vector3] = []
	if n:
		pts = n.find_path(global_position, dest)
	if pts.is_empty():
		pts = [dest]
	path = pts
	_pi = 1 if pts.size() > 1 else 0
	want_speed = spd
	_stuck_t = 0.0
	_stuck_from = global_position
	return true


func _move(delta: float) -> bool:
	if _pi >= path.size():
		speed = move_toward(speed, 0.0, delta * 6.0)
		return true
	var wp := path[_pi]
	var to := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z)
	if to.length() < 0.5:
		_pi += 1
		return _pi >= path.size()
	speed = move_toward(speed, want_speed, delta * (9.0 if want_speed > 3.0 else 3.0))
	var dir := to.normalized()
	var step := minf(speed * delta, to.length())
	var np := global_position + dir * step
	np.y = _surface(np)
	_open_doors(np, dir)
	global_position = np
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, delta * (5.0 if want_speed > 3.0 else 2.4))
	# Displacement-based stuck guard: bounded replan, never a teleport.
	_stuck_t += delta
	if _stuck_t > 3.0:
		if global_position.distance_to(_stuck_from) < 0.4:
			_pi = path.size()
		_stuck_t = 0.0
		_stuck_from = global_position
	return false


## Real doors open (with a warning impact) as it reaches them; it folds
## through the frame.
func _open_doors(p: Vector3, dir: Vector3) -> void:
	for d in get_tree().get_nodes_in_group("doors"):
		var door := d as Door
		if door == null or door.is_open:
			continue
		var mid := door.global_transform * Vector3(door.width * 0.5, 0, 0)
		if Vector2(mid.x - p.x, mid.z - p.z).length() < 1.4 and dir.dot((mid - p).normalized()) > 0.2:
			_play("door_bang", -2.0, door.global_position + Vector3(0, 1, 0))
			door.set_open(true)
			body.pose = "fold"
			mark("F-H04")
			mark("F-H11")
			Game.hunt.noise(door.global_position, 22.0, "door", "foreman")


# ------------------------------------------------------------ senses

func _head() -> Vector3:
	return global_position + Vector3(0, 2.6 - body._fold * 0.8 - body._search * 1.2, 0)


func _sight_range(who: Node3D) -> float:
	var r := 16.0
	match Game.hunt.phase_name():
		"day": r = 45.0
		"dusk": r = 28.0
	if Game.safety:
		var q: Dictionary = Game.safety.query(who.global_position + Vector3(0, 1.0, 0))
		if int(q.get("reason", 0)) == SafetyService.Reason.CAMP_LAMP:
			r = maxf(r, 30.0)      # lamp pools make people easy to see
	# Phase 23: rain and storm haze cut how far it can see (never below
	# half; lamp pools still read). Concealment, not a hidden position.
	if Game.weather:
		r *= lerpf(0.5, 1.0, clampf(Game.weather.visibility, 0.0, 1.0))
	return r


func can_see(who: Node3D) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	var tp := who.global_position + Vector3(0, 1.3, 0)
	if Game.hunt.is_hidden(who):
		# Phase 12: rock hides conceal by geometry - the hunter sees the
		# crouched eye if its ray reaches it (e.g. through the opening).
		var spot: HideSpot = Game.hunt.hidden.get(who)
		if spot == null or not (spot.kind.begins_with("rock_") or spot.kind == "thicket"):
			return false
		tp = spot.eye
	var head := _head()
	var to := tp - head
	if to.length() > _sight_range(who):
		return false
	var fwd := -global_basis.z
	if fwd.dot(to.normalized()) < FOV_COS and to.length() > 3.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(head, tp, 1 | 4)
	var ex: Array[RID] = []
	if who is CollisionObject3D:
		ex.append((who as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not (hit.is_empty() or (hit.position as Vector3).distance_to(tp) < 0.6):
		return false
	# Phase 12 soft cover: dense brush between us thins the view (bounded:
	# never within 4 m, weaker against a moving target).
	if Game.cover:
		var crouched := who is Player and bool(who.get("_crouching"))
		var target := tp - Vector3(0, 0.45 if crouched else 0.0, 0)
		if Game.cover.soft_hides(head, target, _velocity_of(who).length() > 2.2):
			return false
	return true


## Actual sound events in the world (footsteps, work, doors, engines...).
func _on_sound(_s: AudioStream, pos: Vector3, volume_db: float, category := "world", _label := "") -> void:
	# "horror" is its own footsteps (Horror bus): it never hears itself.
	if category in ["terror", "dog", "foreman", "horror"]:
		return
	var radius := 30.0
	match category:
		"steps": radius = clampf(10.0 + (volume_db + 20.0) * 0.9, 6.0, 26.0)
		"work": radius = 45.0
		"steps_other": radius = 14.0
	hear(pos, radius, category)


## Phase 23: thunder and heavy rain at the Foreman's own ears shorten how
## far it hears (the same masking model as players, cameras and workers).
func masked_radius(radius: float) -> float:
	if Game.weather == null:
		return radius
	var excess := maxf(Game.weather.masking_db(global_position + Vector3(0, 1.8, 0)) - 40.0, 0.0)
	return radius * clampf(pow(10.0, -excess / 20.0), 0.15, 1.0)


func hear(pos: Vector3, radius: float, kind: String, spot: HideSpot = null) -> void:
	radius = masked_radius(radius)
	if state == "ARRIVAL" or Game.hunt == null:
		return
	var d := pos.distance_to(global_position)
	if d > radius:
		return
	var unc := 1.0 + d * 0.18
	var guess := pos + Vector3(_rng.randf_range(-unc, unc), 0, _rng.randf_range(-unc, unc))
	evidence.append({"pos": guess, "r": unc, "t": Game.hunt.hunt_clock(), "w": 1.0 - d / radius, "kind": kind, "spot": spot})
	if evidence.size() > 12:
		evidence.pop_front()
	if kind == "engine":
		mark("F-H26")
	if state in ["ROAM", "LISTEN", "DISENGAGE", "LOST_CONTACT"] and grace <= 0.0:
		body.head_target = guess + Vector3(0, 1.5, 0)
		set_state("NOTICE")


func _best_evidence() -> Dictionary:
	var best: Dictionary = {}
	var bs := 0.0
	var now := Game.hunt.hunt_clock()
	for e in evidence:
		var age := now - float(e.t)
		var s := float(e.w) * exp(-age / 60.0)
		if s > bs:
			bs = s
			best = e
	return best if bs > 0.08 else {}


func _humans() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if Game.player and not Game.hunt.player_dead:
		out.append(Game.player)
	if Game.crew:
		for w in Game.crew.workers.values():
			if Game.hunt.worker_alive(w):
				out.append(w)
	return out


# ------------------------------------------------------------ thinking

func _process(delta: float) -> void:
	if get_tree().paused or Game.hunt == null or not Game.hunt.hunt_active():
		return
	st_t += delta
	grace = maxf(grace - delta, 0.0)
	hint_cd -= delta
	listen_cd -= delta
	voice_cd -= delta
	body.speed = speed
	_sounds(delta)
	# Vision sweep (cheap: a few humans).
	var seen: Node3D = null
	if grace <= 0.0 and state != "ATTACK":
		for h in _humans():
			if can_see(h):
				seen = h
				break
	if seen:
		last_seen = {"pos": seen.global_position, "heading": _velocity_of(seen), "t": Game.hunt.hunt_clock(), "who": seen}
		if not state in ["CONFIRM", "CHASE", "ATTACK", "INSPECT_TRUCK"]:
			target = seen
			confirm = 0.0
			body.head_target = seen.global_position + Vector3(0, 1.5, 0)
			set_state("CONFIRM")
			if Game.hunt.phase_name() == "day":
				mark("F-H28")
	match state:
		"ARRIVAL":
			body.pose = "idle"
			if st_t > 6.0:
				go_to(_cover_from_player(), WALK * 1.6)
				set_state("ROAM")
		"ROAM":
			body.pose = "walk"
			if _move(delta):
				if listen_cd <= 0.0 and _rng.randf() < 0.5:
					listen_cd = _rng.randf_range(25.0, 60.0)
					set_state("LISTEN")
				else:
					go_to(_roam_point(), WALK)
			_maybe_hint()
		"LISTEN":
			speed = 0.0
			if st_t > _rng.randf_range(2.5, 5.5):
				var e := _best_evidence()
				set_state("INVESTIGATE" if not e.is_empty() else "ROAM")
				if not e.is_empty():
					go_to(e.pos, WALK)
				else:
					go_to(_roam_point(), WALK)
		"NOTICE":
			body.pose = "listen"
			speed = move_toward(speed, 0.0, delta * 4.0)
			if st_t > 1.2:
				var e2 := _best_evidence()
				if e2.is_empty():
					set_state("ROAM")
				else:
					go_to(e2.pos, WALK * 1.2)
					set_state("INVESTIGATE")
		"INVESTIGATE":
			body.pose = "walk"
			if _move(delta):
				_plan_search(_best_evidence())
		"CONFIRM":
			body.pose = "listen"
			speed = move_toward(speed, 0.0, delta * 3.0)
			if target and can_see(target):
				var d := target.global_position.distance_to(global_position)
				var moving := _velocity_of(target).length() > 2.5
				confirm += delta * (1.6 if moving else 1.0) * (2.0 if d < 8.0 else 1.0)
				rotation.y = lerp_angle(rotation.y, atan2(-(target.global_position.x - global_position.x), -(target.global_position.z - global_position.z)), delta * 3.0)
				if confirm >= CONFIRM_NEEDED:
					set_state("CHASE")
			else:
				confirm -= delta * 0.5
				if confirm <= 0.0 or st_t > 4.0:
					set_state("LOST_CONTACT")
		"CHASE":
			body.pose = "sprint"
			chase_t += delta
			if target and is_instance_valid(target) and can_see(target):
				if _replan_t <= 0.0:
					_replan_t = 0.35
					go_to(target.global_position, SPRINT)
				_replan_t -= delta
				_move(delta)
				var d2 := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
				if d2 < REACH * 1.25:
					_begin_attack(target)
				elif Game.hunt.in_vehicle(target) and Game.hunt.vehicle_speed(target) > 3.0:
					mark("F-H05")
			else:
				# Sight broken: run to where it last saw them, a little beyond.
				var ls: Vector3 = last_seen.get("pos", global_position)
				var hd: Vector3 = last_seen.get("heading", Vector3.ZERO)
				go_to(ls + hd.normalized() * 4.0 if hd.length() > 0.5 else ls, SPRINT * 0.8)
				set_state("LOST_CONTACT")
				mark("F-H13")
			if chase_t > SPRINT_MAX:
				# Commitment ends: readable recovery, then search.
				set_state("RECOVER")
		"RECOVER":
			body.pose = "listen"
			speed = move_toward(speed, 0.0, delta * 5.0)
			if st_t > 2.5:
				_plan_search({"pos": last_seen.get("pos", global_position), "r": 6.0})
		"LOST_CONTACT":
			body.pose = "walk"
			if _move(delta):
				_plan_search({"pos": last_seen.get("pos", global_position), "r": 5.0})
				mark("F-H12")
		"SEARCH":
			body.pose = "search" if probe != null else "walk"
			_search(delta)
		"SHELTER_PROBE":
			_shelter_probe(delta)
		"INSPECT_TRUCK":
			_inspect_truck(delta)
		"ATTACK":
			_attack(delta)
		"DISENGAGE":
			body.pose = "walk"
			if _move(delta):
				if not false_departure_used and _rng.randf() < 0.35 and not searched.is_empty():
					false_departure_used = true
					mark("F-H20")
					go_to(searched[searched.size() - 1], WALK)
					set_state("INVESTIGATE")
				else:
					mark("F-H19")
					false_departure_used = false
					searched.clear()
					set_state("ROAM")
					go_to(_roam_point(), WALK)


func _velocity_of(n: Node3D) -> Vector3:
	var v: Variant = n.get("velocity")
	return v if v is Vector3 else Vector3.ZERO


# --------------------------------------------------------- searching

## Builds a bounded list of places to check near the evidence: hide spots
## (suspicion from seen entry > nearby noise), cover, a parked truck.
func _plan_search(e: Dictionary) -> void:
	search_queue.clear()
	probe = null
	var c: Vector3 = e.get("pos", global_position)
	var spot: HideSpot = e.get("spot")
	if spot:
		search_queue.append({"spot": spot, "susp": 0.9})
	for s in get_tree().get_nodes_in_group("hide_spot"):
		var h := s as HideSpot
		if h == spot:
			continue
		var d := h.global_position.distance_to(c)
		if d < 14.0:
			search_queue.append({"spot": h, "susp": 0.15 + 0.3 * (1.0 - d / 14.0) + Game.hunt.seen_entry_bonus(h)})
	if Game.vehicles:
		for t in Game.vehicles.trucks.values():
			var tr := t as Truck
			if tr.global_position.distance_to(c) < 16.0 and tr.occupants().size() > 0:
				search_queue.append({"truck": tr, "susp": 0.6})
	search_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.susp) > float(b.susp))
	search_queue = search_queue.slice(0, 3)
	searched.append(c)
	if searched.size() > 6:
		searched.pop_front()
	if search_queue.is_empty():
		go_to(c + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), SEARCH_SPEED)
	set_state("SEARCH")


func _search(delta: float) -> void:
	if probe == null and search_queue.is_empty():
		if _move(delta):
			go_to(_away_point(), WALK)
			set_state("DISENGAGE")
		return
	if probe == null:
		var next: Dictionary = search_queue.pop_front()
		if next.has("truck"):
			var tr: Truck = next.truck
			go_to(tr.door_point(1.0), SEARCH_SPEED)
			set_state("INSPECT_TRUCK")
			attack_target = Game.player if Game.player and Game.hunt.in_vehicle(Game.player) and (Game.player as Player).vehicle == tr else null
			return
		probe = next.spot
		probe_t = 0.0
		interior_route = Game.hunt.route_to_spot(probe, global_position)
		if not interior_route.is_empty():
			path = interior_route
			_pi = 0
			want_speed = SEARCH_SPEED
			set_state("SHELTER_PROBE")
			return
		go_to(probe.approach, SEARCH_SPEED)
	if _move(delta):
		_probe_spot(delta)


func _shelter_probe(delta: float) -> void:
	body.pose = "fold" if _pi < path.size() and path.size() - _pi <= 2 else "walk"
	if _move(delta):
		set_state("SEARCH")
		_probe_spot(delta)


## Looks into a suspected hiding place. Found only if someone really is
## there AND the check succeeds (high after a seen entry, low otherwise).
func _probe_spot(delta: float) -> void:
	if probe == null:
		return
	body.pose = "search"
	probe_t += delta
	body.head_target = probe.global_position
	if probe_t < 2.4:
		if probe_t < delta * 1.5:
			match probe.kind:
				"closet": mark("F-H01")
				"under_bed": mark("F-H02"); mark("F-H21")
			if probe.occupant == null and Game.hunt.player_hidden_near(probe.global_position, 10.0):
				mark("F-H18")
			if Game.hunt.player_hidden_near(probe.global_position, 10.0):
				mark("F-H17")
		return
	var occ := probe.occupant
	if occ and is_instance_valid(occ):
		var chance := 0.25 + Game.hunt.seen_entry_bonus(probe) + (0.3 if Game.hunt.recent_noise_from(probe) else 0.0)
		if _rng.randf() < clampf(chance, 0.0, 0.95):
			Game.hunt.expose(probe)
			_begin_attack(occ)
			probe = null
			return
	if _rng.randf() < 0.2:
		_play("t_knock_1", -8.0)     # checks nearby cover; something falls
		mark("F-H10")
	probe = null


func _inspect_truck(delta: float) -> void:
	body.pose = "walk"
	if _move(delta):
		body.pose = "reach"
		if st_t > 0.1 and st_t < 0.2:
			_play("t_knock_0", -6.0)
			mark("F-H08")
			mark("F-H30")
		if st_t > 2.6:
			var p := attack_target
			if p and is_instance_valid(p) and Game.hunt.in_vehicle(p) and Game.hunt.vehicle_speed(p) < 0.5:
				_begin_attack(p)
			else:
				set_state("SEARCH")


# ------------------------------------------------------------- attacks

func _begin_attack(who: Node3D) -> void:
	attack_target = who
	attack_t = 0.0
	set_state("ATTACK")
	body.pose = "reach"
	_play("f_breath", -2.0)


## Telegraph (0.65 s) then commit only if the target is STILL reachable,
## not escaped into a moving truck, not out of reach.
func _attack(delta: float) -> void:
	attack_t += delta
	speed = move_toward(speed, 0.0, delta * 8.0)
	var who := attack_target
	if who == null or not is_instance_valid(who):
		set_state("SEARCH")
		return
	rotation.y = lerp_angle(rotation.y, atan2(-(who.global_position.x - global_position.x), -(who.global_position.z - global_position.z)), delta * 6.0)
	if attack_t < 0.65:
		return
	var d := Vector2(who.global_position.x - global_position.x, who.global_position.z - global_position.z).length()
	var reachable := d < REACH + 0.4 and absf(who.global_position.y - global_position.y) < 1.6
	if Game.hunt.in_vehicle(who) and Game.hunt.vehicle_speed(who) > 1.0:
		reachable = false
	if Game.hunt.is_hidden(who) and not Game.hunt.is_exposed(who):
		reachable = false
	if reachable:
		kills += 1
		killed.emit(who)
		Game.hunt.on_kill(who)
		last_seen = {}
		go_to(_away_point(), WALK)
		set_state("DISENGAGE")
	else:
		# Valid evasion: no stored kill follows them.
		set_state("LOST_CONTACT")
		go_to(who.global_position, SPRINT * 0.7)


# --------------------------------------------------------- helpers

func _roam_point() -> Vector3:
	if roam_points.is_empty():
		roam_points = Game.hunt.roam_points()
	var bias := Game.hunt.day_bias()
	for i in 6:
		var p := roam_points[_rng.randi() % roam_points.size()]
		if bias != Vector3.INF and _rng.randf() < 0.4:
			p = bias + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10))
			p.y = _surface(p)
		if p.distance_to(global_position) > 12.0:
			return p
	return roam_points[0]


func _away_point() -> Vector3:
	var p := Game.player as Node3D
	var from := p.global_position if p else global_position
	var best := global_position
	var bd := 0.0
	for r in Game.hunt.roam_points():
		var d := r.distance_to(from)
		if d > bd and d < 160.0:
			bd = d
			best = r
	return best


func _cover_from_player() -> Vector3:
	var p := Game.player as Node3D
	if p == null:
		return _roam_point()
	return TerrorPlacement.withdrawal(global_position, p.global_position)


## Rare broad search-sector hypothesis when contact is long lost. Sometimes
## wrong; never the exact position, closet or worker coordinates.
func _maybe_hint() -> void:
	if hint_cd > 0.0 or last_seen.is_empty() and evidence.is_empty() and Game.hunt.hunt_clock() < 200.0:
		return
	hint_cd = _rng.randf_range(110.0, 190.0)
	var sector := Game.hunt.sector_hint(_rng)
	if sector.wrong:
		mark("F-H27")
	evidence.append({"pos": sector.pos, "r": 25.0, "t": Game.hunt.hunt_clock(), "w": 0.35, "kind": "hint", "spot": null})


func _sounds(delta: float) -> void:
	# Footsteps come from ForemanBody.foot_contact (stride-synced).
	if not _steps_hooked:
		_steps_hooked = true
		_feet = AudioStreamPlayer3D.new()
		_feet.bus = "Horror"
		_feet.unit_size = 8.0
		_feet.max_polyphony = 2
		add_child(_feet)
		body.foot_contact.connect(func(_side: int, heavy: bool) -> void:
			if SoundService.instance() != null:
				# Phase 15: from its feet, occluded like any world sound
				# (walls and closed doors muffle it; an open door doesn't).
				var fp := global_position
				var wet := World.surface_at(fp.x, fp.z) in [World.Surface.WATER, World.Surface.SAND]
				SoundService.play("foreman.step.wet" if wet else "foreman.step", fp + Vector3(0, 0.1, 0), {"db": 0.0 if heavy else -4.0})
				steps_played += 1
				return
			var s: AudioStream = load("res://audio/generated/f_step_%d.wav" % (_rng.randi() % 2))
			var db := 0.0 if heavy else -4.0
			_feet.stream = s
			_feet.volume_db = db
			_feet.pitch_scale = _rng.randf_range(0.92, 1.05)
			_feet.play()
			steps_played += 1
			SoundEvents.emit(s, global_position, db, "foreman", ""))
	# Tags: only while the body actually moves; silent (and cut off) when it
	# stops to listen, so a motionless listening pause is truly quiet.
	if body.tags_silent or speed < 0.25:
		if _tags.playing and body.tags_silent:
			_tags.stop()
	elif not _tags.playing and _rng.randf() < delta * 0.25 and speed < 2.5:
		_tags.stream = load("res://audio/generated/f_tags.wav")
		_tags.volume_db = -12.0
		_tags.play()
	if voice_cd <= 0.0 and state in ["SEARCH", "INVESTIGATE"] and not TerrorDirector.voice_memory.is_empty():
		voice_cd = _rng.randf_range(160.0, 300.0)
		var mem: Dictionary = TerrorDirector.voice_memory[_rng.randi() % TerrorDirector.voice_memory.size()]
		_play("t_voice_%d" % (_rng.randi() % 4), -6.0)
		var words := str(mem.text).split(" ")
		TerrorDirector.caption("a broken voice like %s's: \"%s... %s\"" % [str(mem.speaker), words[0], words[0]], global_position)
		mark("F-H14")
		if Game.hunt.speaker_gone(str(mem.speaker)):
			mark("F-H25")


const PLAY_EVENTS := {"f_breath": "foreman.breath", "f_intake": "foreman.breath"}


func _play(n: String, db: float, at := Vector3.INF) -> void:
	if SoundService.instance() != null and PLAY_EVENTS.has(n):
		SoundService.play(str(PLAY_EVENTS[n]), (self if at == Vector3.INF else at), {"db": db, "offset": Vector3(0, 1.6, 0) if at == Vector3.INF else Vector3.ZERO})
		return
	var path_s := "res://audio/generated/%s.wav" % n
	if not ResourceLoader.exists(path_s):
		return
	var s: AudioStream = load(path_s)
	if at == Vector3.INF:
		_audio.stream = s
		_audio.volume_db = db
		_audio.play()
		SoundEvents.emit(s, global_position + Vector3(0, 1.5, 0), db, "foreman", "")
	else:
		var p := AudioStreamPlayer3D.new()
		p.stream = s
		p.bus = "Horror"
		p.volume_db = db
		get_parent().add_child(p)
		p.global_position = at
		p.play()
		p.finished.connect(p.queue_free)
		SoundEvents.emit(s, at, db, "foreman", "")


func capture() -> Dictionary:
	var ev := []
	for e in evidence:
		ev.append({"pos": [(e.pos as Vector3).x, (e.pos as Vector3).y, (e.pos as Vector3).z], "r": e.r, "t": e.t, "w": e.w, "kind": e.kind})
	return {"pos": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y, "state": state, "grace": grace, "evidence": ev, "false_departure_used": false_departure_used, "observed": observed.duplicate(), "kills": kills}


## Load: same single body, legal pose, no stale attack; a short grace so
## loading never drops the hunter on someone's face.
func restore(d: Dictionary) -> void:
	var p: Array = d.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	rotation.y = float(d.get("yaw", 0.0))
	var s := str(d.get("state", "ROAM"))
	state = "ROAM" if s in ["ATTACK", "CHASE", "CONFIRM", "INSPECT_TRUCK", "SHELTER_PROBE"] else s
	if state == "ARRIVAL":
		state = "ROAM"
	grace = maxf(float(d.get("grace", 0.0)), 12.0)
	evidence.clear()
	for e in d.get("evidence", []):
		var ep: Array = e.pos
		evidence.append({"pos": Vector3(float(ep[0]), float(ep[1]), float(ep[2])), "r": float(e.r), "t": float(e.t), "w": float(e.w), "kind": str(e.kind), "spot": null})
	false_departure_used = bool(d.get("false_departure_used", false))
	observed = d.get("observed", {})
	kills = int(d.get("kills", 0))
	path.clear()
	_pi = 0
	if Game.player:
		var pp := (Game.player as Node3D).global_position
		if pp.distance_to(global_position) < 25.0:
			global_position = Game.hunt.roam_points()[0] if not Game.hunt.roam_points().is_empty() else global_position
