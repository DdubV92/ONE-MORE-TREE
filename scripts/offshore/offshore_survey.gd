class_name OffshoreSurvey
extends Node
## Phase 19: the offshore survey visits (docs/PHASE19_NOTES.md).
##
## A large vessel appears every few contract days (data:
## data/offshore/survey_config.json), makes exactly one lap of a fixed
## world-space circle that clears the island, its shoals and the dock
## routes, then leaves on a separate departure leg and is retired out of
## view. It slows to half speed through the camp-facing arc (smoothly
## blended; the circle stays exact because only the ANGLE is integrated).
## Its helicopter launches from the moving deck once the ship has been in
## view long enough, flies a seeded survey (a camp pass plus island sweeps
## at terrain + canopy clearance) and lands back on the same deck - or, if
## the recovery window is missed, leaves on a credible offshore exit.
##
## Nothing here is a mission: no marker, no contact, no reward, no combat.
## The vessel's identity and purpose are never stated. It is a separate
## entity from the Day 36 rescue ship (HuntService) and never runs once the
## contract has ended.
##
## Witnesses: each worker's knowledge is earned from real geometry (line of
## sight from the eyes to the hull / aircraft through terrain, structures
## and standing trees, fog-limited range) or hearing (rotor range, masked by
## a nearby running chainsaw); secondhand knowledge only through being told.
## Beats (first sighting, slow pass, rotor heard, aircraft seen, deck work,
## departure, repeat sightings) produce at most one immediate callout each,
## spoken through ConversationService with cooldowns, priorities and the
## Phase 18 voices.

const CONFIG := "res://data/offshore/survey_config.json"
const EYE := 1.6

var cfg := {}
var center := Vector2.ZERO
var R := 1050.0
var dir := 1.0
var theta_camp := 0.0
var theta0 := 0.0
var arc_half := 0.0
var blend := 0.0
var v_full := 12.0
var v_slow := 6.0

var visit := {}              # the current visit (empty when none is running)
var visits := {}             # id -> summary (persists: no re-run, history)
var know := {}               # eid -> {key: {visit_id: value}}
var ship: SurveyShip
var heli: SurveyHelicopter
var heli_final_from := Vector3.ZERO
var heli_final_yaw := 0.0
var logging := false
var samples: Array = []   # logged route samples (tests / audit)
var stats := {"visits": 0, "callouts": 0, "beats": 0, "beats_unspoken": 0, "evals": 0, "max_eval_us": 0}
var enabled := true
var preview_force := false   # Preview station: run a visit without a campaign
var clock := 0.0             # this service's sim seconds (callout cooldowns)

var _live := {}              # eid/"player" -> live witness flags
var _cd := {}                # beat or "*" -> clock expiry
var _rr := 0                 # round-robin worker index
var _eval_t := 0.0
var _log_t := 0.0
var _tree_grid := {}         # Vector2i(16 m) -> PackedInt32Array of tree indices
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Offshore"
	load_config()


func load_config(override := {}) -> void:
	var txt := FileAccess.get_file_as_string(CONFIG)
	var d: Variant = JSON.parse_string(txt)
	cfg = d if d is Dictionary else {}
	for k in override:
		cfg[k] = override[k]
	var r: Dictionary = cfg.get("route", {})
	var c: Array = r.get("center", [0.0, 0.0])
	center = Vector2(float(c[0]), float(c[1]))
	R = float(r.get("radius", 1050.0))
	dir = signf(float(r.get("direction", 1.0)))
	if dir == 0.0:
		dir = 1.0
	v_full = float(r.get("speed", 12.0))
	v_slow = v_full * float(r.get("slow_factor", 0.5))
	arc_half = deg_to_rad(float(r.get("camp_arc_deg", 50.0))) * 0.5
	blend = deg_to_rad(float(r.get("blend_deg", 10.0)))
	var camp := World.camp_origin() if World.is_loaded else Vector3(-175, 0, 355)
	theta_camp = atan2(camp.z - center.y, camp.x - center.x)
	# Start INSIDE the camp-facing arc, a fraction of the way in from its
	# entry edge (in the direction of travel).
	theta0 = theta_camp - dir * arc_half + dir * 2.0 * arc_half * float(r.get("start_in_arc", 0.25))


func sc(k: String, def: Variant) -> Variant:
	return (cfg.get("schedule", {}) as Dictionary).get(k, def)


func rc(k: String, def: Variant) -> Variant:
	return (cfg.get("route", {}) as Dictionary).get(k, def)


func hc(k: String, def: Variant) -> Variant:
	return (cfg.get("heli", {}) as Dictionary).get(k, def)


func wc(k: String, def: Variant) -> Variant:
	return (cfg.get("witness", {}) as Dictionary).get(k, def)


func cc(k: String, def: Variant) -> Variant:
	return (cfg.get("callouts", {}) as Dictionary).get(k, def)


# ------------------------------------------------------------- the route

func circle_point(theta: float) -> Vector3:
	return Vector3(center.x + R * cos(theta), World.sea_level, center.y + R * sin(theta))


func tangent(theta: float) -> Vector3:
	return Vector3(-sin(theta), 0.0, cos(theta)) * dir


## 1 inside the camp-facing arc, 0 in open water, smooth across the edges.
func slow_k(theta: float) -> float:
	var d := absf(wrapf(theta - theta_camp, -PI, PI))
	return 1.0 - smoothstep(arc_half - blend * 0.5, arc_half + blend * 0.5, d)


func speed_at(theta: float) -> float:
	return lerpf(v_full, v_slow, slow_k(theta))


func in_slow_arc(theta: float) -> bool:
	return slow_k(theta) > 0.5


## Total lap seconds (numerical integration of dt = R dtheta / v).
func lap_seconds() -> float:
	var n := 3600
	var t := 0.0
	for i in n:
		var th := theta0 + dir * TAU * (i + 0.5) / n
		t += R * TAU / n / speed_at(th)
	return t


func arrival_start() -> Vector3:
	return circle_point(theta0) - tangent(theta0) * float(rc("arrival_m", 650.0))


func _departure_heading(s: float, from_theta: float) -> Vector3:
	var t0 := tangent(from_theta)
	var radial := Vector3(cos(from_theta), 0, sin(from_theta))
	var turn := deg_to_rad(float(rc("departure_turn_deg", 35.0)))
	var tgt := (t0 * cos(turn) + radial * sin(turn)).normalized()
	return t0.lerp(tgt, smoothstep(0.0, 300.0, s)).normalized()


## Route check: the whole circle clears land, shoals and the dock routes.
func route_clearance() -> Dictionary:
	var margin := float(rc("clear_margin_m", 200.0))
	var min_depth := float(rc("min_depth_m", 8.0))
	var worst := INF
	var bad := 0
	for i in 720:
		var p := circle_point(TAU * i / 720.0)
		for k in 13:
			var q := p
			if k > 0:
				var a := TAU * k / 12.0
				q += Vector3(cos(a), 0, sin(a)) * margin
			var h := World.height_at(q.x, q.z)
			worst = minf(worst, -h)
			if h > -min_depth:
				bad += 1
	# Dock routes (supply skiff, rescue ship approach) stay inside the circle
	# by at least the margin.
	var routes_ok := true
	var dock := Game.crew.dock_end if Game.crew else World.camp_origin() + Vector3(0, 0, 120)
	for p in [dock, dock + Vector3(0, 0, 160), dock + Vector3(6.5, 0, 260)]:
		if Vector2(p.x, p.z).distance_to(center) > R - margin:
			routes_ok = false
	return {"bad_samples": bad, "min_depth": worst, "routes_ok": routes_ok, "margin": margin}


# ------------------------------------------------------------- schedule

func _campaign_live() -> bool:
	var c: CampaignService = Game.campaign
	if c == null or c.clock == null or not c.clock.running:
		return false
	if c.contract and c.contract.is_closed():
		return false
	if Game.hunt and (Game.hunt.hunt_active() or str(Game.hunt.mode) != "none"):
		return false
	return true


func is_visit_day(day: int) -> bool:
	var first := int(sc("first_day", 3))
	var every := maxi(int(sc("interval_days", 3)), 1)
	return day >= first and day <= int(sc("last_day", 30)) and (day - first) % every == 0


static func visit_id(day: int) -> String:
	return "V%02d" % day


func _seed() -> int:
	if Game.campaign and Game.campaign.get("campaign_seed") != null:
		return int(Game.campaign.get("campaign_seed"))
	return int(World.manifest.get("world_seed", 1717)) if World.manifest else 1717


## Starts today's visit if one is due (never twice: the id is recorded).
func _maybe_start() -> void:
	var c: CampaignService = Game.campaign
	var day := c.clock.day
	if not is_visit_day(day) or visits.has(visit_id(day)):
		return
	if c.clock.t < float(sc("start_t", 40.0)) or c.clock.t > WorkdayClock.DAYLIGHT_SECONDS - 300.0:
		return
	start_visit(day)


func start_visit(day: int) -> void:
	var id := visit_id(day)
	var seed := hash("%d:%s" % [_seed(), id])
	visit = {"id": id, "day": day, "seed": seed, "state": "arriving", "route_t": 0.0, "seg_t": 0.0, "s": 0.0, "lap": 0.0,
		"theta": theta0, "heli_state": "deck", "heli_outcome": "", "launched": false, "visible_s": 0.0, "beats": {},
		"lines": [], "slow_seg": 0, "slow_seg_t": 0.0, "dep_from": theta0, "dep_pos": [0.0, 0.0], "dep_s": 0.0,
		"legs": plan_legs(seed), "n": visits.size() + 1}
	visits[id] = {"id": id, "day": day, "state": "arriving", "heli_outcome": "", "n": visits.size() + 1}
	stats.visits += 1
	_build_actors()
	_place_ship()
	ship.start_engine()


func _build_actors() -> void:
	_free_actors()
	ship = SurveyShip.new()
	get_parent().add_child(ship)
	heli = SurveyHelicopter.new()
	heli.svc = self
	get_parent().add_child(heli)


func _free_actors() -> void:
	for n in [ship, heli]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	ship = null
	heli = null


## The survey order for a visit: the camp pass plus `legs_per_visit` of the
## island sweeps, shuffled by the visit's persistent seed.
func plan_legs(seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var pool := ["ridge", "west", "north", "east", "interior"]
	for i in range(pool.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var legs: Array = ["camp"] + pool.slice(0, int(hc("legs_per_visit", 3)))
	for i in range(legs.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t2: Variant = legs[i]
		legs[i] = legs[j]
		legs[j] = t2
	return legs


## Waypoints of one leg: [[point, label, agl]].
func leg_points(leg: String) -> Array:
	var camp := World.camp_origin()
	var agl := float(hc("clearance_m", 45.0))
	match leg:
		"camp":
			var ca := float(hc("camp_pass_agl", 65.0))
			return [[Vector3(camp.x + 260, 0, camp.z + 360), "camp", ca], [Vector3(camp.x + 30, 0, camp.z + 20), "camp", ca], [Vector3(camp.x - 160, 0, camp.z - 280), "camp", ca]]
		"ridge":
			return [[Vector3(40, 0, -430), "ridge", agl], [Vector3(600, 0, -100), "ridge", agl]]
		"west":
			return [[Vector3(-660, 0, 140), "west", agl], [Vector3(-300, 0, -220), "west", agl]]
		"north":
			return [[Vector3(-420, 0, -560), "north", agl], [Vector3(320, 0, -580), "north", agl]]
		"east":
			return [[Vector3(720, 0, 260), "east", agl], [Vector3(430, 0, 430), "east", agl]]
		"interior":
			return [[Vector3(-120, 0, -90), "interior", agl], [Vector3(260, 0, 160), "interior", agl]]
	return []


static func inland_leg(leg: String) -> bool:
	return leg in ["ridge", "west", "interior"]


# ------------------------------------------------------------- stepping

func _physics_process(delta: float) -> void:
	if get_tree().paused or not enabled:
		return
	clock += delta
	var live := _campaign_live() or preview_force
	if visit.is_empty():
		if live and not preview_force:
			_maybe_start()
		return
	var spd := 1.0
	if Game.campaign and Game.campaign.clock and not preview_force:
		if not Game.campaign.clock.running:
			return
		spd = float(Game.campaign.clock.speed)
	# Visits end with the contract (or at night): leave now, credibly.
	if not live and str(visit.state) in ["arriving", "lap"]:
		_begin_departure()
	step(delta * spd)
	_witness_tick(delta)


## Advances the visit by dt seconds of route time (substepped).
func step(dt: float) -> void:
	var left := dt
	while left > 0.0 and not visit.is_empty():
		var h := minf(left, 0.25)
		_step1(h)
		left -= h


func _step1(h: float) -> void:
	visit.route_t = float(visit.route_t) + h
	visit.seg_t = float(visit.seg_t) + h
	match str(visit.state):
		"arriving":
			var L := float(rc("arrival_m", 650.0))
			var u := clampf(float(visit.s) / L, 0.0, 1.0)
			var v := lerpf(v_full, speed_at(theta0), smoothstep(0.0, 1.0, u))
			visit.s = float(visit.s) + v * h
			if float(visit.s) >= L:
				visit.state = "lap"
				visit.seg_t = 0.0
				visit.lap = 0.0
				visit.theta = theta0
		"lap":
			var th := float(visit.theta)
			var dth := speed_at(th) / R * h
			var lap := float(visit.lap) + dth
			if lap >= TAU:
				lap = TAU
				visit.lap = lap
				visit.theta = theta0            # exactly back on the start bearing
				visit.lap_end_t = visit.route_t
				if logging:
					var pe := circle_point(theta0)
					samples.append({"t": visit.route_t, "state": "lap", "x": pe.x, "z": pe.z, "speed": speed_at(theta0), "theta": theta0, "lap": TAU, "lap_end": true, "heli": heli.state if heli else ""})
				_begin_departure()
			else:
				visit.lap = lap
				visit.theta = theta0 + dir * lap
			var sl := in_slow_arc(float(visit.theta))
			if sl:
				visit.slow_seg_t = float(visit.slow_seg_t) + h
			elif float(visit.slow_seg_t) > 0.0:
				visit.slow_seg_t = 0.0
				visit.slow_seg = int(visit.slow_seg) + 1
		"departing":
			var s := float(visit.dep_s)
			var hd := _departure_heading(s, float(visit.dep_from))
			var v2 := lerpf(float(visit.get("dep_v0", v_slow)), v_full, smoothstep(0.0, 250.0, s))
			visit.dep_s = s + v2 * h
			var p: Array = visit.dep_pos
			visit.dep_pos = [float(p[0]) + hd.x * v2 * h, float(p[1]) + hd.z * v2 * h]
			if float(visit.dep_s) >= float(rc("retire_min_m", 900.0)) and (not player_sees(ship_position()) or float(visit.dep_s) >= float(rc("departure_m", 1500.0))):
				_retire()
				return
	_place_ship()
	_heli_step(h)
	if logging and float(visit.route_t) - _log_t >= 1.0:
		_log_t = float(visit.route_t)
		var sp := ship_position()
		samples.append({"t": visit.route_t, "state": visit.state, "x": sp.x, "z": sp.z, "speed": ship_speed(), "theta": visit.theta, "lap": visit.lap,
			"heli": heli.state if heli else "", "hx": heli.global_position.x if heli else 0.0, "hy": heli.global_position.y if heli else 0.0, "hz": heli.global_position.z if heli else 0.0,
			"hfloor": clearance_floor(heli.global_position, Vector3.ZERO, 0.0) if heli and heli.airborne() else 0.0, "bank": heli.bank if heli else 0.0})


func _begin_departure() -> void:
	var p := ship_position()
	var from := float(visit.theta)
	if str(visit.state) == "arriving":
		from = theta0
	visit.dep_v0 = ship_speed()
	visit.state = "departing"
	visit.seg_t = 0.0
	visit.dep_from = atan2(p.z - center.y, p.x - center.x)
	visit.dep_pos = [p.x, p.z]
	visit.dep_s = 0.0
	visits[visit.id].state = "departing"
	# A helicopter still away misses the recovery: offshore exit.
	if heli and heli.airborne() and heli.state != "exit":
		_heli_offshore_exit("ship departed before recovery")


func _retire() -> void:
	visit.state = "retired"
	var sm: Dictionary = visits[visit.id]
	sm.state = "retired"
	sm.heli_outcome = visit.heli_outcome if str(visit.heli_outcome) != "" else ("no_launch" if not bool(visit.launched) else "recovered")
	sm.lines = (visit.lines as Array).duplicate()
	sm.route_t = visit.route_t
	sm.ended_day = Game.campaign.clock.day if Game.campaign and Game.campaign.clock else int(visit.day)
	visit.clear()
	_free_actors()
	_live.clear()


func ship_position() -> Vector3:
	match str(visit.get("state", "")):
		"arriving":
			return arrival_start() + tangent(theta0) * float(visit.s)
		"lap":
			return circle_point(float(visit.theta))
		"departing":
			var p: Array = visit.dep_pos
			return Vector3(float(p[0]), World.sea_level, float(p[1]))
	return Vector3.INF


func ship_forward() -> Vector3:
	match str(visit.get("state", "")):
		"arriving":
			return tangent(theta0)
		"lap":
			return tangent(float(visit.theta))
		"departing":
			return _departure_heading(float(visit.dep_s), float(visit.dep_from))
	return Vector3.FORWARD


func ship_speed() -> float:
	match str(visit.get("state", "")):
		"arriving":
			var u := clampf(float(visit.s) / float(rc("arrival_m", 650.0)), 0.0, 1.0)
			return lerpf(v_full, speed_at(theta0), smoothstep(0.0, 1.0, u))
		"lap":
			return speed_at(float(visit.theta))
		"departing":
			return lerpf(float(visit.get("dep_v0", v_slow)), v_full, smoothstep(0.0, 250.0, float(visit.dep_s)))
	return 0.0


func ship_velocity() -> Vector3:
	return ship_forward() * ship_speed()


func _place_ship() -> void:
	if ship == null or visit.is_empty():
		return
	ship.set_route(ship_position(), ship_forward(), ship_speed())


func deck_transform() -> Transform3D:
	if ship == null:
		return Transform3D.IDENTITY
	return ship.deck_transform()


# ------------------------------------------------------------ helicopter

func _heli_step(h: float) -> void:
	if heli == null:
		return
	if heli.state == "deck" and not bool(visit.launched) and str(visit.state) == "lap":
		var long_enough := float(visit.visible_s) >= float(hc("launch_after_visible_s", 45.0))
		var late := float(visit.seg_t) >= float(hc("launch_latest_lap_s", 200.0))
		var storm: float = float(Game.weather.get("storm")) if Game.weather and Game.weather.get("storm") != null else 0.0
		if (long_enough or late) and storm < 0.5:
			_launch()
		elif late and storm >= 0.5 and str(visit.heli_outcome) == "":
			visit.heli_outcome = "no_launch"      # a missed launch (weather)
	heli.step(h)
	visit.heli_state = heli.state


func _launch() -> void:
	visit.launched = true
	var wps: Array = []
	for lg in visit.legs:
		for w in leg_points(str(lg)):
			wps.append(w)
	heli.wps = wps
	heli.wp_i = 0
	heli.set_state("spool")
	_beat("launch", "deck")


func on_heli_waypoint(_i: int) -> void:
	pass


## Survey done: go back to the ship, unless the recovery window is gone.
func on_heli_route_done() -> void:
	if not _recovery_window_ok():
		_heli_offshore_exit("recovery window missed")
		return
	heli.set_state("approach")


## Recovery must finish before the ship re-enters the camp-facing arc
## (keeps the slow pass clear of deck work).
func _recovery_window_ok() -> bool:
	if str(visit.state) != "lap":
		return false
	var margin := deg_to_rad(float(hc("recover_by_arc_margin_deg", 30.0)))
	var entry := TAU - (theta0 - (theta_camp - dir * arc_half)) * dir   # lap angle at arc entry
	return float(visit.lap) < entry - margin - deg_to_rad(25.0)


func approach_gate() -> Vector3:
	return deck_transform() * Vector3(0, 22.0, 55.0)


func begin_final(h: SurveyHelicopter) -> void:
	if str(visit.state) != "lap":
		_heli_offshore_exit("ship turned away during the approach")
		return
	var d := deck_transform()
	heli_final_from = d.affine_inverse() * h.global_position
	heli_final_yaw = wrapf(h.yaw - SurveyHelicopter._yaw_of(d.basis), -PI, PI)
	h.set_state("final")
	_beat("landing", "deck")


func on_heli_landed() -> void:
	visit.heli_outcome = "recovered"
	visits[visit.id].heli_outcome = "recovered"
	_beat("recovered", "deck")


func _heli_offshore_exit(why: String) -> void:
	visit.heli_outcome = "offshore_exit"
	visit.heli_exit_why = why
	visits[visit.id].heli_outcome = "offshore_exit"
	heli.set_state("exit")


## Out to sea on the far side from camp, well past the circle.
func heli_exit_point() -> Vector3:
	var away := theta_camp + PI
	return Vector3(center.x + (R + 2500.0) * cos(away), 120.0, center.y + (R + 2500.0) * sin(away))


func heli_out_of_view(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(center) > R + 1400.0 and not player_sees(p)


func on_heli_retired() -> void:
	pass


## The lowest safe height around p (terrain or sea + standing canopy),
## looking ahead along fwd.
func clearance_floor(p: Vector3, fwd: Vector3, spd: float) -> float:
	var g := _ground(p.x, p.z)
	if fwd.length() > 0.1:
		var look := clampf(spd * 8.0, 60.0, 320.0)
		for k in range(1, 5):
			var q := p + fwd * look * k / 4.0
			g = maxf(g, _ground(q.x, q.z))
	return g


func _ground(x: float, z: float) -> float:
	return maxf(World.sea_level, World.height_at(x, z)) + canopy_at(x, z, 14.0)


## Height of the tallest STANDING tree within r of (x, z) (0 when cleared).
func canopy_at(x: float, z: float, r: float) -> float:
	_ensure_tree_grid()
	var best := 0.0
	var c0 := Vector2i(int(floor((x - r) / 16.0)), int(floor((z - r) / 16.0)))
	var c1 := Vector2i(int(floor((x + r) / 16.0)), int(floor((z + r) / 16.0)))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var arr: PackedInt32Array = _tree_grid.get(Vector2i(cx, cz), PackedInt32Array())
			for i in arr:
				if not _standing(i):
					continue
				var dx: float = World.trees.x[i] - x
				var dz: float = World.trees.z[i] - z
				if dx * dx + dz * dz < r * r:
					best = maxf(best, float(World.trees.height[i]))
	return best


func _standing(i: int) -> bool:
	var id := int(World.trees.id[i])
	return not World.removed_trees.has(id) and World.is_native(id)


func _ensure_tree_grid() -> void:
	if not _tree_grid.is_empty() or World.trees.is_empty():
		return
	var grid := {}
	var xs: PackedFloat32Array = World.trees.x
	var zs: PackedFloat32Array = World.trees.z
	for i in xs.size():
		var c := Vector2i(int(floor(xs[i] / 16.0)), int(floor(zs[i] / 16.0)))
		if not grid.has(c):
			grid[c] = []
		(grid[c] as Array).append(i)
	for c in grid:
		_tree_grid[c] = PackedInt32Array(grid[c])


# --------------------------------------------------------- line of sight

## Fog-limited sight range for a large object right now.
func sight_range(base: float) -> float:
	var dens := 0.00022
	if Game.environment and Game.environment.get("env") != null:
		dens = maxf(float((Game.environment.get("env") as Environment).fog_density), 0.00001)
	return minf(base, -log(0.15) / dens)


## Line of sight from an eye to a point through terrain, structures (near)
## and standing trees (opacity along the ray where it passes below crowns).
func los(eye: Vector3, target: Vector3, max_d: float, exclude: Array = []) -> String:
	var d := eye.distance_to(target)
	if d > max_d:
		return "range"
	# Terrain: sample the ray against the height field.
	var steps := int(ceil(d / 15.0))
	for k in range(1, steps):
		var q := eye.lerp(target, float(k) / steps)
		if World.height_at(q.x, q.z) > q.y + 0.3:
			return "terrain"
	# Structures near the eye (camp buildings, fences, trucks): physics ray.
	var vp := get_viewport()
	if vp and vp.world_3d:
		var space := vp.world_3d.direct_space_state
		var end := eye + (target - eye).normalized() * minf(d, 160.0)
		var q2 := PhysicsRayQueryParameters3D.create(eye, end, 1)
		q2.exclude = exclude
		var hit := space.intersect_ray(q2)
		if not hit.is_empty():
			return "structure"
	if _tree_blocks(eye, target):
		return "trees"
	return ""


func _tree_blocks(eye: Vector3, target: Vector3) -> bool:
	_ensure_tree_grid()
	var flat := Vector2(target.x - eye.x, target.z - eye.z)
	var dist := flat.length()
	if dist < 0.5:
		return false
	var dirv := flat / dist
	var reach := minf(dist, 220.0)
	var slope := (target.y - eye.y) / dist
	var opacity := 0.0
	var seen := {}
	var s := 0.0
	while s < reach:
		var px := eye.x + dirv.x * s
		var pz := eye.z + dirv.y * s
		var c := Vector2i(int(floor(px / 16.0)), int(floor(pz / 16.0)))
		for cc2 in [c, c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
			if seen.has(cc2):
				continue
			seen[cc2] = true
			for i in (_tree_grid.get(cc2, PackedInt32Array()) as PackedInt32Array):
				if not _standing(i):
					continue
				var tx: float = World.trees.x[i] - eye.x
				var tz: float = World.trees.z[i] - eye.z
				var along := tx * dirv.x + tz * dirv.y
				if along < 0.8 or along > reach:
					continue
				var off := absf(tx * dirv.y - tz * dirv.x)
				var th := float(World.trees.height[i])
				var base := World.height_at(World.trees.x[i], World.trees.z[i])
				var ray_y := eye.y + slope * along
				if ray_y > base + th:
					continue                       # passes above the crown
				var crown_r := clampf(th * 0.16, 1.2, 3.6)
				var crown_low := base + th * 0.35
				if ray_y >= crown_low and off < crown_r:
					opacity += 0.45
				elif off < float(World.trees.radius[i]) + 0.15:
					opacity += 1.0
				if opacity >= 1.0:
					return true
		s += 8.0
	return false


func ship_sight_points() -> Array[Vector3]:
	if ship == null:
		return []
	return ship.sight_points()


func sees_ship(eye: Vector3, exclude: Array = []) -> bool:
	if ship == null or visit.is_empty():
		return false
	var rng := sight_range(float(wc("ship_sight_m", 3400.0)))
	for p in ship_sight_points():
		if los(eye, p, rng, exclude) == "":
			return true
	return false


func ship_block_reason(eye: Vector3, exclude: Array = []) -> String:
	var rng := sight_range(float(wc("ship_sight_m", 3400.0)))
	var why := "none"
	for p in ship_sight_points():
		var r := los(eye, p, rng, exclude)
		if r == "":
			return ""
		why = r
	return why


func sees_heli(eye: Vector3, exclude: Array = []) -> bool:
	if heli == null or not heli.visible or heli.state == "gone":
		return false
	return los(eye, heli.global_position + Vector3(0, 1.5, 0), sight_range(float(wc("heli_sight_m", 2400.0))), exclude) == ""


func deck_seen(eye: Vector3, exclude: Array = []) -> bool:
	if ship == null:
		return false
	var p := deck_transform().origin + Vector3(0, 1.0, 0)
	return los(eye, p, minf(sight_range(float(wc("ship_sight_m", 3400.0))), 2200.0), exclude) == ""


func _saw_near(p: Vector3, r: float) -> bool:
	if Game.crew:
		for o in Game.crew.workers.values():
			var ow := o as Worker
			if ow.saw.state in [SawMachine.S.CUTTING, SawMachine.S.REVVING] and ow.global_position.distance_to(p) < r:
				return true
	return false


func hears_rotor(pos: Vector3, indoors := false) -> bool:
	if heli == null or not heli.audible():
		return false
	var rng := float(wc("rotor_hear_m", 1500.0)) * heli.rotor
	if _saw_near(pos, 15.0):
		rng = minf(rng, float(wc("rotor_hear_masked_m", 320.0)))
	if indoors:
		rng *= 0.6
	return pos.distance_to(heli.global_position) < rng


func hears_engine(pos: Vector3) -> bool:
	if ship == null:
		return false
	var rng := float(wc("engine_hear_m", 950.0))
	if _saw_near(pos, 20.0):
		rng *= 0.3
	return pos.distance_to(ship.global_position) < rng


## The player's view: camera frustum + line of sight.
func player_sees(p: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null or not cam.is_position_in_frustum(p):
		return false
	return los(cam.global_position, p, 6000.0) == ""


# -------------------------------------------------------------- witnesses

func _k(eid: String) -> Dictionary:
	if not know.has(eid):
		know[eid] = {}
	return know[eid]


func _kset(eid: String, key: String, vid: String, val: Variant = true) -> void:
	var k := _k(eid)
	if not k.has(key):
		k[key] = {}
	(k[key] as Dictionary)[vid] = val


func _kget(eid: String, key: String, vid: String) -> Variant:
	return (_k(eid).get(key, {}) as Dictionary).get(vid, null)


func _kcount(eid: String, key: String) -> int:
	return (_k(eid).get(key, {}) as Dictionary).size()


func _witness_tick(delta: float) -> void:
	if visit.is_empty() or Game.crew == null:
		return
	_eval_t -= delta
	if _eval_t > 0.0:
		return
	_eval_t = 0.25
	var ws: Array = Game.crew.workers.values()
	var t0 := Time.get_ticks_usec()
	# One worker per tick (bounded cost) + the player every other tick.
	if not ws.is_empty():
		_rr = (_rr + 1) % ws.size()
		var w := ws[_rr] as Worker
		if is_instance_valid(w) and Game.crew.talk and Game.crew.talk._can_talk(w):
			eval_worker(w, 0.25 * ws.size())
	if _rr % 2 == 0:
		_eval_player()
	var us := Time.get_ticks_usec() - t0
	stats.evals += 1
	stats.max_eval_us = maxi(int(stats.max_eval_us), us)
	_pending_beats()


func _eye_of(w: Worker) -> Vector3:
	return w.global_position + Vector3(0, EYE, 0)


func _indoors(p: Vector3) -> bool:
	for z in get_tree().get_nodes_in_group("zones"):
		if z.has_method("contains_point") and z.contains_point(p + Vector3(0, 1.0, 0)):
			return true
	return false


## One worker's observation now; records firsthand knowledge and beats.
func eval_worker(w: Worker, dt: float) -> Dictionary:
	var vid := str(visit.get("id", ""))
	if vid == "":
		return {}
	var eye := _eye_of(w)
	var ex: Array = [w.col.get_rid()] if w.col else []
	var L: Dictionary = _live.get(w.id, {})
	var was_ship := bool(L.get("ship", false))
	var was_heli := bool(L.get("heli", false))
	var was_rotor := bool(L.get("rotor", false))
	var s := sees_ship(eye, ex)
	var why := "" if s else ship_block_reason(eye, ex)
	var hv := sees_heli(eye, ex)
	var ind := _indoors(w.global_position)
	var ro := hears_rotor(w.global_position, ind)
	L.ship = s
	L.ship_why = why
	L.heli = hv
	L.rotor = ro
	L.t = clock
	if s:
		var secs := float(_kget(w.id, "ship", vid) if _kget(w.id, "ship", vid) != null else 0.0) + dt
		_kset(w.id, "ship", vid, secs)
		visit.visible_s = float(visit.visible_s) + dt / maxf(Game.crew.workers.size(), 1)
		var spd := ship_speed()
		if spd > v_full * 0.85:
			_kset(w.id, "fast", vid)
		if spd < v_full * 0.7 and str(visit.state) == "lap":
			_kset(w.id, "slow", vid)
		var k := slow_k(float(visit.get("theta", theta0)))
		if k > 0.05 and k < 0.95 and float(L.get("last_k", k)) < k:
			_kset(w.id, "slowdown", vid)
		if str(visit.state) == "arriving" and spd < v_full * 0.9:
			_kset(w.id, "slowdown", vid)
		L.last_k = k
		if float(visit.get("lap", 0.0)) < 0.6 and str(visit.state) != "departing":
			_kset(w.id, "early", vid)
		if str(visit.state) == "departing":
			_kset(w.id, "depart", vid)
		var sp := ship_position()
		var sector := int(floor(fposmod(atan2(sp.z - center.y, sp.x - center.x) + PI / 4.0, TAU) / (PI / 2.0)))
		var sides: int = int(_kget(w.id, "sides", vid) if _kget(w.id, "sides", vid) != null else 0)
		_kset(w.id, "sides", vid, sides | (1 << sector))
		if deck_seen(eye, ex):
			_kset(w.id, "deck", vid)
			if heli and heli.state in ["spool", "lift"]:
				_kset(w.id, "launch", vid)
			if heli and heli.state in ["approach", "final"]:
				_kset(w.id, "land", vid)
			if heli and heli.state == "landed" and heli.st_t < 30.0:
				_kset(w.id, "recover", vid)
		L.ship_since = float(L.get("ship_since", clock)) if was_ship else clock
	else:
		if was_ship and why == "terrain":
			L.ship_lost_t = clock
		L.ship_since = -1.0
	if hv:
		_kset(w.id, "heli", vid)
		if absf(heli.bank) > deg_to_rad(12.0):
			_kset(w.id, "bank", vid)
		if not was_heli:
			L.heli_yaw0 = heli.yaw
			L.heli_since = clock
		elif absf(wrapf(heli.yaw - float(L.get("heli_yaw0", heli.yaw)), -PI, PI)) > deg_to_rad(60.0):
			L.turned_t = clock
			L.heli_yaw0 = heli.yaw
			_kset(w.id, "turn", vid)
		if over_camp():
			_kset(w.id, "heli_camp", vid)
		if heli.state in ["approach", "final"]:
			_kset(w.id, "land", vid)
		if heli.state in ["spool", "lift"]:
			_kset(w.id, "launch", vid)
		if heli.state == "landed":
			_kset(w.id, "recover", vid)
	elif was_heli and heli:
		var hb := los(eye, heli.global_position, 99999.0, ex)
		if hb == "terrain":
			L.heli_lost_ridge_t = clock
		if heli_seaward():
			L.heli_lost_sea_t = clock
			_kset(w.id, "lost_seaward", vid)
	if ro:
		_kset(w.id, "rotor", vid)
		if not was_rotor:
			L.rotor_since = clock
			L.rotor_from_water = heli_over_water()
			var ep := int(_kget(w.id, "rotor_eps", vid) if _kget(w.id, "rotor_eps", vid) != null else 0)
			_kset(w.id, "rotor_eps", vid, ep + 1)
		var dnow := w.global_position.distance_to(heli.global_position)
		var hist: Array = L.get("rd", [])
		hist.append([clock, dnow])
		while hist.size() > 0 and clock - float(hist[0][0]) > 5.0:
			hist.pop_front()
		L.rd = hist
	elif was_rotor:
		L.rotor_lost_t = clock
		L.rd = []
	_live[w.id] = L
	# Beats from this observation.
	if s and not was_ship and float(_kget(w.id, "ship", vid)) <= dt + 0.01:
		_beat("sight_%s" % w.id, "sight")
		if _two_passes(w.id) or int(visit.get("n", 1)) >= 2:
			_beat("repeat", "repeat")
	if s and str(visit.state) == "lap" and in_slow_arc(float(visit.theta)) and float(visit.slow_seg_t) > 25.0:
		_beat("slow_%d" % int(visit.slow_seg), "slow")
	if s and str(visit.state) == "departing" and float(visit.seg_t) > 10.0:
		_beat("depart", "depart")
	if ro and not was_rotor and not hv:
		_beat("rotor_%s_%d" % [w.id, int(_kget(w.id, "rotor_eps", vid))], "rotor")
	if was_rotor and not ro:
		_beat("rotor_lost_%s" % w.id, "rotor")
	if hv and not was_heli:
		_beat("heli_%s" % w.id, "heli")
		if int(visit.get("n", 1)) >= 2:
			_beat("repeat_heli", "repeat")
	if hv and over_camp():
		_beat("heli_camp", "heli")
	if hv and absf(heli.bank) > deg_to_rad(15.0):
		_beat("heli_bank_%d" % heli.wp_i, "heli")
	if not hv and was_heli and float(L.get("heli_lost_ridge_t", -99.0)) == clock:
		_beat("heli_ridge_%d" % heli.wp_i, "heli")
	if not hv and was_heli and float(L.get("heli_lost_sea_t", -99.0)) == clock:
		_beat("heli_sea", "depart")
	return L


func _eval_player() -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return
	var vid := str(visit.get("id", ""))
	var L: Dictionary = _live.get("player", {})
	L.ship = player_sees(ship_position() + Vector3(0, 8, 0)) if ship else false
	L.heli = player_sees(heli.global_position) if heli and heli.visible else false
	if bool(L.ship):
		_kset("player", "ship", vid)
	if bool(L.heli):
		_kset("player", "heli", vid)
	_live["player"] = L


func _two_passes(eid: String) -> bool:
	var n := 0
	for vid in (_k(eid).get("ship", {}) as Dictionary):
		if float(_k(eid).ship[vid]) >= float(wc("valid_pass_s", 5.0)):
			n += 1
	return n >= 2


func over_camp() -> bool:
	if heli == null or not heli.airborne():
		return false
	var c := World.camp_origin()
	return Vector2(heli.global_position.x - c.x, heli.global_position.z - c.z).length() < 150.0


func heli_over_water() -> bool:
	if heli == null:
		return false
	var p := heli.global_position
	return World.height_at(p.x, p.z) < World.sea_level - 0.5


func heli_seaward() -> bool:
	if heli == null or not heli_over_water():
		return false
	var p := heli.global_position
	var out := Vector2(p.x - center.x, p.z - center.y).normalized()
	var v := Vector2(heli.vel.x, heli.vel.z)
	return v.length() > 3.0 and v.normalized().dot(out) > 0.3


# ---------------------------------------------------------------- beats

## Registers a beat instance (once per visit). It is spoken as soon as a
## suitable speaker exists, within its window.
func _beat(key: String, trigger: String) -> void:
	if visit.is_empty():
		return
	var b: Dictionary = visit.beats
	if b.has(key):
		return
	b[key] = {"trigger": trigger, "at": clock, "done": false}
	stats.beats += 1


func _pending_beats() -> void:
	if visit.is_empty():
		return
	if float(_cd.get("*", 0.0)) > clock:
		return
	for key in (visit.beats as Dictionary).keys():
		var b: Dictionary = visit.beats[key]
		if bool(b.done):
			continue
		if clock - float(b.at) > 40.0:
			b.done = true
			stats.beats_unspoken += 1
			continue
		var trig := str(b.trigger)
		if float(_cd.get(trig, 0.0)) > clock:
			continue
		if try_callout(trig, key):
			b.done = true
			_cd["*"] = clock + float(cc("global_cd", 20.0))
			_cd[trig] = clock + float(cc("beat_cd", 70.0))
			return


## The best eligible offshore callout for a beat, from the best-placed
## worker. Returns true if a line was spoken.
func try_callout(trigger: String, key := "") -> bool:
	var crew := Game.crew
	if crew == null or crew.talk == null:
		return false
	var talk: ConversationService = crew.talk
	var bank := talk.bank
	var pl := Game.player as Node3D
	var player_missed := not bool((_live.get("player", {}) as Dictionary).get("ship" if trigger in ["sight", "slow", "depart", "repeat"] else "heli", false))
	var best := []
	var best_s := -1.0
	for id in bank.offshore.get(trigger, []):
		var ln: Dictionary = bank.lines[id]
		for w in talk._talkers():
			var wk := w as Worker
			var sup := talk.suppressed_at(wk)
			if sup != "" and not (sup == "chainsaw running" and "sea:saw_running" in (ln.get("when", []) as Array)):
				continue
			if wk.saw.state in [SawMachine.S.CUTTING, SawMachine.S.REVVING]:
				continue
			if talk.eligible(ln, wk) != "":
				continue
			var score := float(ln.get("prio", 3)) * (1.0 + 0.4 * ((ln.get("when", []) as Array).size() + (ln.get("needs", []) as Array).size()))
			if pl and wk.global_position.distance_to(pl.global_position) < ConversationService.HEAR_R:
				score += 4.0
			if player_missed and bool(ln.get("directs", false)):
				score += 2.5
			score += _jitter(id + wk.id)
			if score > best_s:
				best_s = score
				best = [id, wk]
	if best.is_empty():
		return false
	var sp: Worker = best[1]
	var tgt := ship_position() + Vector3(0, 10, 0) if trigger in ["sight", "slow", "depart", "repeat"] or heli == null else heli.global_position
	var listeners := []
	for o in talk._talkers():
		if o != sp and (o as Worker).global_position.distance_to(sp.global_position) < 16.0:
			listeners.append(o)
	sp.look_toward(tgt, 4.0)
	talk.offshore_say(str(best[0]), sp, listeners, _cue(tgt))
	(visit.lines as Array).append(str(best[0]))
	for o in listeners:
		_kset((o as Worker).id, "called", str(visit.id))
		if (o as Worker).saw.state in [SawMachine.S.CUTTING, SawMachine.S.REVVING]:
			_kset((o as Worker).id, "called_sawing", str(visit.id))
	stats.callouts += 1
	return true


func _jitter(s: String) -> float:
	_rng.seed = hash("%s:%d" % [s, int(clock)])
	return _rng.randf() * 0.8


## A short directional cue for subtitles (muted play): relative to the
## player's view.
func _cue(tgt: Vector3) -> String:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return ""
	var to := tgt - cam.global_position
	var flat := Vector3(to.x, 0, to.z)
	var elev := rad_to_deg(atan2(to.y, flat.length()))
	if elev > 50.0:
		return "overhead"
	var f := -cam.global_basis.z
	f.y = 0
	var ang := rad_to_deg(f.normalized().signed_angle_to(flat.normalized(), Vector3.UP))
	var side := "ahead"
	if absf(ang) > 135.0:
		side = "behind you"
	elif ang > 35.0:
		side = "to your left"
	elif ang < -35.0:
		side = "to your right"
	var where := "offshore" if World.height_at(tgt.x, tgt.z) < World.sea_level else ("over the island" if heli and tgt.distance_to(heli.global_position) < 1.0 else "")
	return side + (", " + where if where != "" else "")


## Phase 17 conversations: a firsthand witness's offshore line passes the
## CLAIM to listeners (secondhand), never the sighting itself.
func on_line_spoken(id: String, sp: Worker, listeners: Array) -> void:
	var vid := latest_visit_id()
	if vid == "":
		return
	var firsthand := _kget(sp.id, "ship", vid) != null or _kget(sp.id, "heli", vid) != null or _kget(sp.id, "rotor", vid) != null
	if not firsthand and _kget(sp.id, "told", vid) == null:
		return
	for o in listeners:
		var ow := o as Worker
		if _kget(ow.id, "ship", vid) == null and _kget(ow.id, "told", vid) == null:
			_kset(ow.id, "told", vid, sp.id)


func latest_visit_id() -> String:
	if not visit.is_empty():
		return str(visit.id)
	var best := ""
	var bd := -1
	for id in visits:
		if int(visits[id].day) > bd:
			bd = int(visits[id].day)
			best = str(id)
	return best


func _prev_visits(vid: String) -> Array:
	var d := int(visits.get(vid, {}).get("day", 99))
	return visits.keys().filter(func(k: String) -> bool: return int(visits[k].day) < d)


# ------------------------------------------------------ dialogue predicates

## `when` predicates in the sea: namespace (ConversationService.holds).
func holds(p: String, w: Worker) -> bool:
	var L: Dictionary = _live.get(w.id, {})
	var active := not visit.is_empty()
	var vid := latest_visit_id()
	match p:
		"sea:ship_seen":
			return active and bool(L.get("ship", false))
		"sea:ship_unseen":
			return active and ship != null and not bool(L.get("ship", false))
		"sea:opening_soon":
			if not active or ship == null:
				return false
			var fut := ship_position() + ship_forward() * ship_speed() * 6.0 + Vector3(0, 12, 0)
			return los(_eye_of(w), fut, sight_range(float(wc("ship_sight_m", 3400.0))), [w.col.get_rid()] if w.col else []) == ""
		"sea:slow":
			return active and str(visit.state) == "lap" and in_slow_arc(float(visit.theta))
		"sea:speeding":
			if not active or str(visit.state) != "lap":
				return false
			var k := slow_k(float(visit.theta))
			return k < 0.9 and k > 0.05 and slow_k(float(visit.theta) + dir * 0.01) < k
		"sea:lap_late":
			return active and str(visit.state) == "lap" and float(visit.lap) > deg_to_rad(300.0)
		"sea:departing":
			return active and str(visit.state) == "departing"
		"sea:broadside":
			if not active:
				return false
			var los_d := (ship_position() - w.global_position)
			los_d.y = 0
			return absf(ship_forward().dot(los_d.normalized())) < 0.4
		"sea:near_view":
			return active and w.global_position.distance_to(ship_position()) < 1300.0
		"sea:edge":
			if not active or ship == null:
				return false
			var fut2 := ship_position() + ship_forward() * ship_speed() * 30.0 + Vector3(0, 12, 0)
			return los(_eye_of(w), fut2, 99999.0, [w.col.get_rid()] if w.col else []) == "terrain"
		"sea:toward_sun":
			var sun: DirectionalLight3D = Game.environment.get("sun") if Game.environment else null
			if not active or sun == null or not sun.visible:
				return false
			var sd := sun.global_basis.z
			if sd.y < 0.08:
				return false
			var to := ship_position() - w.global_position
			return Vector2(sd.x, sd.z).normalized().dot(Vector2(to.x, to.z).normalized()) > 0.8
		"sea:hazy":
			var dens := float((Game.environment.get("env") as Environment).fog_density) if Game.environment and Game.environment.get("env") else 0.0
			var rain: float = float(Game.weather.get("rain")) if Game.weather and Game.weather.get("rain") != null else 0.0
			return dens > 0.0005 or rain > 0.2
		"sea:engine_heard":
			return active and hears_engine(w.global_position)
		"sea:heli_seen":
			return active and bool(L.get("heli", false))
		"sea:rotor":
			return active and bool(L.get("rotor", false))
		"sea:heli_unseen_heard":
			return active and bool(L.get("rotor", false)) and not bool(L.get("heli", false))
		"sea:rotor_rising":
			var hist: Array = L.get("rd", [])
			return hist.size() >= 2 and float(hist[0][1]) - float(hist[hist.size() - 1][1]) > 30.0
		"sea:rotor_long":
			return bool(L.get("rotor", false)) and clock - float(L.get("rotor_since", clock)) >= 30.0
		"sea:rotor_lost":
			return not bool(L.get("rotor", false)) and clock - float(L.get("rotor_lost_t", -999.0)) < 25.0
		"sea:rotor_close":
			return active and heli != null and bool(L.get("rotor", false)) and w.global_position.distance_to(heli.global_position) < 450.0
		"sea:heli_behind_ridge":
			return clock - float(L.get("heli_lost_ridge_t", -999.0)) < 10.0
		"sea:from_water":
			return bool(L.get("rotor_from_water", false))
		"sea:saw_running":
			return _saw_near(w.global_position, 15.0)
		"sea:among_trees":
			return _trees_within(w.global_position, 22.0) >= 6
		"sea:engine_noise":
			return _saw_near(w.global_position, 20.0) or _truck_near(w.global_position, 20.0)
		"sea:truck_near":
			return _truck_near(w.global_position, 14.0) or w.activity in ["aboard", "seated"]
		"sea:away_from_pit":
			return CampLayout.world(CampLayout.BURN_PIT_POS).distance_to(w.global_position) > 15.0
		"sea:over_camp":
			return active and over_camp()
		"sea:over_water":
			return active and heli_over_water()
		"sea:over_ridge":
			return active and heli != null and World.height_at(heli.global_position.x, heli.global_position.z) > 26.0
		"sea:over_cleared":
			if not active or heli == null:
				return false
			var hp := heli.global_position
			return World.height_at(hp.x, hp.z) > World.sea_level + 1.0 and canopy_at(hp.x, hp.z, 40.0) == 0.0
		"sea:overhead":
			if not active or heli == null:
				return false
			var d := heli.global_position - _eye_of(w)
			return atan2(d.y, Vector2(d.x, d.z).length()) > deg_to_rad(50.0)
		"sea:heli_close":
			return active and heli != null and Vector2(heli.global_position.x - w.global_position.x, heli.global_position.z - w.global_position.z).length() < 320.0
		"sea:heli_far":
			return active and heli != null and w.global_position.distance_to(heli.global_position) > 600.0
		"sea:banking":
			return active and heli != null and absf(heli.bank) > deg_to_rad(12.0)
		"sea:turned":
			return clock - float(L.get("turned_t", -999.0)) < 20.0
		"sea:sweep":
			return active and heli != null and heli.state == "fly" and _leg_index() >= 1
		"sea:inland_next":
			var i := _leg_index()
			var legs: Array = visit.get("legs", [])
			return active and i + 1 < legs.size() and inland_leg(str(legs[i + 1]))
		"sea:inbound":
			if not active or heli == null or not heli_over_water():
				return false
			var hp2 := heli.global_position
			var inward := Vector2(center.x - hp2.x, center.y - hp2.z).normalized()
			return Vector2(heli.vel.x, heli.vel.z).normalized().dot(inward) > 0.5
		"sea:near_dock":
			var dock := Game.crew.dock_end if Game.crew else Vector3.INF
			return active and heli != null and Vector2(heli.global_position.x - dock.x, heli.global_position.z - dock.z).length() < 200.0
		"sea:seaward":
			return active and heli_seaward()
		"sea:landing":
			return active and heli != null and heli.state in ["approach", "final"]
		"sea:heli_airborne":
			return active and heli != null and heli.airborne()
		"sea:deck_seen":
			return active and deck_seen(_eye_of(w), [w.col.get_rid()] if w.col else [])
		"sea:ship_lost_point":
			return clock - float(L.get("ship_lost_t", -999.0)) < 30.0 and not bool(L.get("ship", false))
		"sea:heli_lost_seaward":
			return clock - float(L.get("heli_lost_sea_t", -999.0)) < 30.0
		"sea:yesterday_quiet":
			var day := Game.campaign.clock.day if Game.campaign else 0
			return active and day > 1 and not is_visit_day(day - 1)
		"sea:player_missed":
			return active and _kget("player", "ship", vid) == null
		"sea:after":
			if active or vid == "":
				return false
			var day2 := Game.campaign.clock.day if Game.campaign else int(visits[vid].day)
			return day2 - int(visits[vid].day) <= 2
		"sea:today":
			var day3 := Game.campaign.clock.day if Game.campaign else -1
			return not active and vid != "" and int(visits[vid].day) == day3
	return false


func _leg_index() -> int:
	if heli == null or visit.is_empty():
		return 0
	var n := 0
	var legs: Array = visit.legs
	var count := 0
	for i in legs.size():
		count += leg_points(str(legs[i])).size()
		if heli.wp_i < count:
			return i
		n = i
	return n


func _trees_within(p: Vector3, r: float) -> int:
	_ensure_tree_grid()
	var n := 0
	var c0 := Vector2i(int(floor((p.x - r) / 16.0)), int(floor((p.z - r) / 16.0)))
	var c1 := Vector2i(int(floor((p.x + r) / 16.0)), int(floor((p.z + r) / 16.0)))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for i in (_tree_grid.get(Vector2i(cx, cz), PackedInt32Array()) as PackedInt32Array):
				if _standing(i) and Vector2(World.trees.x[i] - p.x, World.trees.z[i] - p.z).length() < r:
					n += 1
	return n


func _truck_near(p: Vector3, r: float) -> bool:
	if Game.vehicles == null:
		return false
	for t in (Game.vehicles.trucks as Dictionary).values():
		if is_instance_valid(t) and (t as Node3D).global_position.distance_to(p) < r:
			return true
	return false


## `needs` knowledge in the sea: namespace (ConversationService.knows).
func knows(n: String, w: Worker) -> bool:
	var vid := latest_visit_id()
	if vid == "":
		return false
	var e := w.id
	var saw_ship := _kget(e, "ship", vid) != null and float(_kget(e, "ship", vid)) >= 1.0
	var saw_heli := _kget(e, "heli", vid) != null
	var heard := _kget(e, "rotor", vid) != null
	match n:
		"sea:saw_ship_now":
			return saw_ship
		"sea:saw_ship_long":
			return saw_ship and float(_kget(e, "ship", vid)) >= 60.0
		"sea:saw_ship_early":
			return _kget(e, "early", vid) != null
		"sea:saw_slow":
			return _kget(e, "slow", vid) != null
		"sea:saw_slowdown":
			return _kget(e, "slowdown", vid) != null
		"sea:saw_fast_then_slow":
			return _kget(e, "fast", vid) != null and _kget(e, "slow", vid) != null
		"sea:heard_rotor":
			return heard
		"sea:heard_only":
			return heard and not saw_heli
		"sea:heard_twice":
			return int(_kget(e, "rotor_eps", vid) if _kget(e, "rotor_eps", vid) != null else 0) >= 2
		"sea:saw_heli":
			return saw_heli
		"sea:no_heli_seen":
			return not saw_heli
		"sea:saw_launch":
			return _kget(e, "launch", vid) != null
		"sea:saw_land":
			return _kget(e, "land", vid) != null
		"sea:saw_recover":
			return _kget(e, "recover", vid) != null
		"sea:knows_recover":
			return _kget(e, "recover", vid) != null or (heard and str(visits[vid].get("heli_outcome", "")) == "recovered")
		"sea:saw_heli_camp":
			return _kget(e, "heli_camp", vid) != null
		"sea:both_sides":
			var bits := int(_kget(e, "sides", vid) if _kget(e, "sides", vid) != null else 0)
			return (bits & 5) == 5 or (bits & 10) == 10
		"sea:two_passes":
			return _two_passes(e)
		"sea:prev_slow":
			return _prev_visits(vid).any(func(v: String) -> bool: return _kget(e, "slow", v) != null)
		"sea:prev_ship_only":
			return _prev_visits(vid).any(func(v: String) -> bool: return _kget(e, "ship", v) != null and _kget(e, "heli", v) == null)
		"sea:prev_heli":
			return _prev_visits(vid).any(func(v: String) -> bool: return _kget(e, "heli", v) != null)
		"sea:prev_deck":
			return _prev_visits(vid).any(func(v: String) -> bool: return _kget(e, "deck", v) != null)
		"sea:told":
			return _kget(e, "told", vid) != null and not saw_ship
		"sea:called":
			return _kget(e, "called", vid) != null
		"sea:missed":
			return _kget(e, "called", vid) != null and not saw_ship and not saw_heli
		"sea:missed_saw":
			return _kget(e, "called_sawing", vid) != null and not saw_heli
		"sea:wake_only":
			return _kget(e, "called", vid) != null and _kget(e, "depart", vid) != null and _kget(e, "early", vid) == null and not saw_heli
		"sea:knows_any":
			return saw_ship or saw_heli or heard or _kget(e, "told", vid) != null
		"sea:knows_heli":
			return saw_heli or heard
		"sea:knows_ship":
			return saw_ship or _kget(e, "told", vid) != null
		"sea:knows_exit":
			return str(visits[vid].get("heli_outcome", "")) == "offshore_exit" and (saw_heli or heard)
	return false


# --------------------------------------------------------------- save/load

func capture() -> Dictionary:
	var v := visit.duplicate(true)
	if not v.is_empty():
		v.beats = (visit.beats as Dictionary).duplicate(true)
		if heli:
			v.heli = heli.capture()
	return {"version": 1, "visit": v, "visits": visits.duplicate(true), "know": know.duplicate(true), "clock": clock, "cd": _cd.duplicate(), "stats": stats.duplicate()}


## Restores the visit in progress exactly where it was (no new visit, no
## replayed introduction: beats already registered stay registered).
func restore(d: Dictionary) -> void:
	_free_actors()
	visits = (d.get("visits", {}) as Dictionary).duplicate(true)
	know = (d.get("know", {}) as Dictionary).duplicate(true)
	clock = float(d.get("clock", 0.0))
	_cd = (d.get("cd", {}) as Dictionary).duplicate()
	_live.clear()
	visit = (d.get("visit", {}) as Dictionary).duplicate(true)
	if visit.is_empty():
		return
	_build_actors()
	_place_ship()
	ship.start_engine()
	var hd: Dictionary = visit.get("heli", {})
	if not hd.is_empty():
		heli.restore(hd)
		if heli.state in ["deck", "spool", "lift", "final", "landed"]:
			heli.step(0.0)
	else:
		heli.step(0.0)
	visit.erase("heli")


## Phase 19 preview / tests: run a visit outside a campaign.
func preview_visit(day := 3) -> void:
	preview_force = true
	visits.erase(visit_id(day))
	start_visit(day)


func stop_preview() -> void:
	preview_force = false
	if not visit.is_empty():
		visits.erase(str(visit.id))
	visit.clear()
	_free_actors()
	_live.clear()
