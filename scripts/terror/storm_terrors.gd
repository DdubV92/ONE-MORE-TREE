class_name StormTerrors
extends Node
## Phase 23 (pack Phase 21 sections 3-5): storm-only Terror encounters.
##
## Twelve authored beats (data/terror/storm_beats.json), each a variant or
## presentation of an EXISTING Terror family. They run only in a storm
## visit that is not "quiet" (some major storms carry no horror at all),
## after dusk on contract nights, never in the hunt (the Foreman uses the
## storm through its own senses instead). Every beat:
##   - asks TerrorDirector for the one global opportunity (shared budget,
##     family cooldowns, no overlap with ordinary encounters);
##   - validates its places against the real world (grounded, reachable,
##     outside refuges, a real line of sight or audio coverage);
##   - keeps three outcome streams apart: what was PRESENTED (seen or heard
##     by you / by a camera), what workers KNOW (sight or hearing, through
##     CrewService.emit_stimulus) and what AI heard (SoundEvents);
##   - never replays: one run per beat per visit, bounded per campaign.
##
## The Thunder Walker moves ONLY inside thunder masking windows computed
## from the strike's arrival at the relevant listener (WeatherService
## masking model, world values before player volume), and stands perfectly
## still otherwise; a flash can reveal it, a later roll hides its steps.
## Footsteps are real positional emissions on its actual path: each
## listener (you, a camera mic, a worker, the dog) gets its own masking
## result, so a step a roll cannot cover still carries.

const DATA := "res://data/terror/storm_beats.json"
const STEP_DB := 64.0             # wet footstep at 1 m (world simulation scale)
const CRACK_DB := 82.0            # a board / branch crack at 1 m
const CHECK_EVERY := 2.0
const MAX_RUN_S := 420.0

var beats: Array = []
var by_id := {}
var runs: Array = []              # active runs (dicts), saved
var records: Array = []           # outcome records (bounded, saved)
var done := {}                    # "visit:beat" -> true (never replay in a visit)
var counts := {}                  # beat -> campaign count
var forced := ""                  # preview / tests: force one beat
var _check_t := 1.0
var _actors := {}                 # run id -> TerrorActor
var _nodes := {}                  # run id -> Array[Node]
var _run_counter := 0
var stats := {"moved_outside_window": 0.0, "steps": 0, "steps_masked_player": 0, "steps_heard_player": 0, "windows": 0, "reveals": 0}


func _ready() -> void:
	var f := FileAccess.open(DATA, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
	beats = d.get("beats", [])
	for b in beats:
		by_id[str(b.id)] = b
	await get_tree().process_frame
	if Game.weather:
		Game.weather.strike_flashed.connect(_on_flash)


# ------------------------------------------------------------- selection

## Why a beat cannot start right now ("" = it may).
func eligible(b: Dictionary) -> String:
	var w: WeatherService = Game.weather
	if w == null:
		return "no weather"
	if Game.hunt and Game.hunt.hunt_active():
		return "hunt (the Foreman uses the storm itself)"
	var cs: CampaignService = Game.campaign
	if cs == null or not (cs.active or cs.test_route):
		return "no campaign"
	if forced == "" and cs.clock.phase() == WorkdayClock.Phase.DAYLIGHT:
		return "daylight"
	if forced == "":
		if w.visit_id == "":
			return "no storm visit"
		if w.visit_quiet:
			return "quiet storm"
	if not (str(w.profile_name) in (b.profiles as Array)) and forced == "":
		return "profile " + w.profile_name
	if not ("any" in (b.phases as Array)) and not (w.phase_name in (b.phases as Array)) and forced == "":
		return "phase " + w.phase_name
	if w.lightning < float(b.min_lightning) and forced == "":
		return "lightning"
	var rr: Array = b.rain
	if (w.rain < float(rr[0]) or w.rain > float(rr[1])) and forced == "":
		return "rain"
	if w.gust < float(b.gust_min) and forced == "":
		return "gust"
	if done.has("%s:%s" % [w.visit_id, b.id]) and forced == "":
		return "already this visit"
	if int(counts.get(str(b.id), 0)) >= int(b.per_campaign) and forced == "":
		return "campaign cap"
	if Game.director:
		var why := Game.director.can_reserve(int(b.family))
		if why != "":
			return why
	return ""


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	for r in runs.duplicate():
		_tick(r, delta)
	_check_t -= delta
	if _check_t > 0.0 or not runs.is_empty():
		return
	_check_t = CHECK_EVERY
	var cands: Array = []
	for b in beats:
		if str(b.executor) in ["missed_flash"]:
			continue                     # at sleep (on_night)
		if forced != "" and str(b.id) != forced:
			continue
		if eligible(b) == "":
			cands.append(b)
	if cands.is_empty():
		return
	# The storm's strength widens the range; the director's budget limits
	# frequency (one opportunity at a time).
	var w: WeatherService = Game.weather
	var chance := 0.12 + 0.2 * w.lightning + 0.1 * w.gust
	if forced == "" and randf() > chance:
		return
	var total := 0.0
	for b in cands:
		total += float(b.weight)
	var x := randf() * total
	for b in cands:
		x -= float(b.weight)
		if x <= 0.0:
			start(str(b.id))
			return


## Plans and starts a beat (returns the run, or {} with the reason recorded).
func start(id: String) -> Dictionary:
	var b: Dictionary = by_id.get(id, {})
	if b.is_empty():
		return {}
	var plan: Dictionary = call("_plan_" + str(b.executor))
	if plan.has("fail"):
		_record({"beat": id, "result": "not staged", "reason": str(plan.fail)})
		return {}
	_run_counter += 1
	var rid := "SR%03d-%s" % [_run_counter, id]
	if Game.director and not Game.director.reserve(rid, int(b.family), id):
		_record({"beat": id, "result": "not staged", "reason": "director: " + Game.director.can_reserve(int(b.family))})
		return {}
	var r := {"id": rid, "beat": id, "executor": str(b.executor), "family": int(b.family), "visit": Game.weather.visit_id, "t": 0.0,
		"state": "setup", "plan": plan, "presented": [], "npc": [], "ai": [], "strikes": []}
	runs.append(r)
	done["%s:%s" % [r.visit, id]] = true
	counts[id] = int(counts.get(id, 0)) + 1
	call("_begin_" + str(b.executor), r)
	return r


func _finish(r: Dictionary, result: String, cooldown := 900.0) -> void:
	if not runs.has(r):
		return
	runs.erase(r)
	var a: TerrorActor = _actors.get(r.id)
	if a and is_instance_valid(a):
		a.queue_free()
	_actors.erase(r.id)
	for n in _nodes.get(r.id, []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	_nodes.erase(r.id)
	if Game.director:
		Game.director.release(str(r.id), cooldown if result != "cancelled" else 120.0, result)
	_record({"beat": r.beat, "run": r.id, "visit": r.visit, "result": result, "presented": r.presented, "npc": r.npc, "ai": r.ai, "strikes": r.strikes})
	# A camera-seen storm encounter makes the local rumor legitimate.
	for p in r.presented:
		if str(p.get("by", "")).begins_with("CAM"):
			_rumor(true, str(p.by))
			break


func _record(e: Dictionary) -> void:
	e["day"] = Game.campaign.clock.day if Game.campaign else 0
	e["weather"] = Game.weather.profile_name if Game.weather else ""
	records.append(e)
	if records.size() > 200:
		records.pop_front()


func _tick(r: Dictionary, delta: float) -> void:
	r.t = float(r.t) + delta
	if float(r.t) > MAX_RUN_S and str(r.state) != "leaving":
		r.state = "leaving"
	call("_tick_" + str(r.executor), r, delta)


## Morning / sleep / day change: everything ends without replaying.
func morning_cleanup() -> void:
	for r in runs.duplicate():
		_finish(r, "ended at morning")


# ------------------------------------------------------------- shared helpers

func _space() -> PhysicsDirectSpaceState3D:
	return get_viewport().world_3d.direct_space_state if get_viewport() else null


func player_eye() -> Vector3:
	var p: Player = Game.player
	return p.camera.global_position if p and p.camera else Vector3.ZERO


## In the player's view right now (cone + real line of sight).
func player_sees(p: Vector3, cone_deg := 45.0) -> bool:
	var pl: Player = Game.player
	if pl == null or pl.camera == null:
		return false
	var eye := pl.camera.global_position
	var to := (p - eye)
	if to.length() > 140.0:
		return false
	if (-pl.camera.global_basis.z).dot(to.normalized()) < cos(deg_to_rad(cone_deg)):
		return false
	return TerrorPlacement.visible_from(eye, p, _space())


## A shown camera that sees the point (index), or -1.
func camera_sees(p: Vector3) -> int:
	var wall: CameraWall = Game.tv
	if wall == null:
		return -1
	for ci in wall.shown_cameras():
		var cam: Node3D = wall.cams[int(ci)]
		var to := p - cam.global_position
		if to.length() > 70.0:
			continue
		if (-cam.global_basis.z).dot(to.normalized()) < cos(deg_to_rad(38.0)):
			continue
		if TerrorPlacement.visible_from(cam.global_position + (-cam.global_basis.z) * 0.3, p, _space()):
			return int(ci)
	return -1


func _ground(p: Vector3) -> Vector3:
	var n := Game.crew.nav if Game.crew and Game.crew.nav and Game.crew.nav.built else null
	return Vector3(p.x, n.surface_at(p) if n else World.height_at(p.x, p.z), p.z)


func _valid_spot(p: Vector3) -> bool:
	return p != Vector3.INF and not TerrorPlacement.forbidden(p)


## Along a window's outward line: the first point that is on land and
## outside every refuge (camp lamp pools are safe at night: nothing stands
## in them). Inside the fence is fine for window beats when unlit.
func _window_line_spot(from: Vector3, outward: Vector3, dmin: float, dmax: float) -> Vector3:
	var d := dmin
	while d <= dmax:
		var c := _ground(from + outward * d)
		if World.water_depth_at(c.x, c.z) < 0.1 and not (Game.safety and Game.safety.query(c + Vector3(0, 1.0, 0)).safe):
			return c
		d += 0.75
	return Vector3.INF


func _path(a: Vector3, b: Vector3) -> Array:
	if Game.crew and Game.crew.nav and Game.crew.nav.built:
		var pts: Array = Game.crew.nav.find_path(a, b)
		if pts.is_empty():
			return []
		var l := 0.0
		var prev := a
		for q in pts:
			l += prev.distance_to(q)
			prev = q
		if l > a.distance_to(b) * 1.8 + 4.0:
			return []                    # not a believable walk
		return pts
	return [b]


func _actor(r: Dictionary, kind: String, at: Vector3, look: Vector3) -> TerrorActor:
	var a := TerrorActor.make(kind)
	add_child(a)
	a.stand_at(at, look)
	_actors[r.id] = a
	return a


func _add_node(r: Dictionary, n: Node) -> void:
	if not _nodes.has(r.id):
		_nodes[r.id] = []
	(_nodes[r.id] as Array).append(n)


## Occlusion loss between two points (SoundService's material model).
func _loss(a: Vector3, b: Vector3) -> float:
	var ss: Node = SoundService.instance()
	return float(ss.call("path_loss", a, b, [])) if ss and ss.has_method("path_loss") else 0.0


## One real footstep at `at`: every listener gets its own masking result.
## Returns {player: heard?, camera: id or "", workers: n}.
func step(r: Dictionary, at: Vector3, src_db := STEP_DB, ev := "terror.step.wet") -> Dictionary:
	var w: WeatherService = Game.weather
	stats.steps += 1
	var out := {"player": false, "camera": "", "workers": 0}
	var lp := player_eye()
	if w.audible_over_masking(at, src_db, lp, -1.0, _loss(at, lp)):
		out.player = true
		stats.steps_heard_player += 1
		SoundService.play(ev, at + Vector3(0, 0.1, 0), {"bus": "Horror", "emit": false, "db": (src_db - STEP_DB) * 0.5})
	else:
		stats.steps_masked_player += 1
	var wall: CameraWall = Game.tv
	if wall:
		for ci in wall.shown_cameras():
			var cp := wall.camera_position(int(ci))
			if cp.distance_to(at) < 40.0 and w.audible_over_masking(at, src_db, cp, -1.0, 0.0):
				var path := SoundBank.path_of(ev)
				if path != "":
					wall.relay_at_camera(load(path), int(ci), -6.0, "", "terror")
					out.camera = wall.cam_id(int(ci))
				break
	# Workers and the dog: heard only where the roll does not cover it.
	if Game.crew:
		var hear_r := 0.0
		for wk in Game.crew.workers.values():
			var wp: Vector3 = (wk as Node3D).global_position + Vector3(0, 1.6, 0)
			if w.audible_over_masking(at, src_db, wp, -1.0, _loss(at, wp)):
				hear_r = maxf(hear_r, wp.distance_to(at) + 1.0)
		if hear_r > 0.0:
			var who: Array = Game.crew.emit_stimulus({"id": "%s@step%d" % [r.id, stats.steps], "kind": "T%02d" % int(r.family), "modality": "sound", "pos": at,
				"loudness": hear_r / 60.0, "severity": 0.12, "ambiguous": true})
			out.workers = who.size()
			if who.size() > 0:
				(r.npc as Array).append({"heard_steps": who})
	if Game.dog and w.audible_over_masking(at, src_db, Game.dog.global_position, -1.0, 0.0):
		Game.dog.hear(null, at, -12.0, "terror", "")
	return out


## Workers who could SEE a point at a flash (sight stimulus, firsthand).
func _witness_sight(r: Dictionary, at: Vector3, st: Dictionary) -> void:
	if Game.crew == null:
		return
	var who: Array = Game.crew.emit_stimulus({"id": "%s@%s" % [r.id, str(st.get("id", "flash"))], "kind": "T%02d" % int(r.family), "modality": "sight",
		"pos": at, "loudness": 0.4, "severity": 0.2, "ambiguous": true})
	if who.size() > 0:
		(r.npc as Array).append({"saw_shape": who, "strike": str(st.get("id", ""))})


## Who got a look at the actor on this flash: you, a camera, workers.
func _reveal(r: Dictionary, at: Vector3, st: Dictionary) -> void:
	stats.reveals += 1
	var head := at + Vector3(0, 1.4, 0)
	var seen := player_sees(head)
	var cam := camera_sees(head)
	(r.presented as Array).append({"strike": str(st.id), "kind": str(st.kind), "pos": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)],
		"by": "player" if seen else (Game.tv.cam_id(cam) if cam >= 0 else "nobody")})
	(r.strikes as Array).append(str(st.id))
	_witness_sight(r, head, st)
	# Reduced flashes: an equivalent soft silhouette cue instead.
	var a: TerrorActor = _actors.get(r.id)
	if a and str(Settings.get_v("flash_reduction")) != "full":
		r["cue_t"] = 1.2


func _on_flash(st: Dictionary) -> void:
	for r in runs.duplicate():
		if has_method("_flash_" + str(r.executor)):
			call("_flash_" + str(r.executor), r, st)


## Cue envelope (reduced-flash accessibility) for an actor.
func _cue(r: Dictionary, delta: float) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null or not is_instance_valid(a):
		return
	var k := float(r.get("cue_t", 0.0))
	if k > 0.0:
		r.cue_t = maxf(k - delta, 0.0)
	a.set_cue(sin(clampf(float(r.get("cue_t", 0.0)) / 1.2, 0.0, 1.0) * PI) if k > 0.0 else 0.0)


## A point is unobserved when neither you nor a shown camera sees it.
func unobserved(p: Vector3) -> bool:
	return not player_sees(p + Vector3(0, 1.4, 0), 55.0) and camera_sees(p + Vector3(0, 1.4, 0)) < 0


# ------------------------------------------------------------- Thunder Walker

## Waypoints: a treeline, stump corridor, fence corner or shoreline break
## the viewer (you, or a shown camera) can actually see; consecutive points
## 6-14 m apart along a real walkable route; an exit behind cover.
func _plan_thunder_walker() -> Dictionary:
	var w: WeatherService = Game.weather
	var ahead := w.upcoming_strikes(w.weather_t, 40.0)
	if ahead.is_empty() and forced == "":
		return {"fail": "no strikes ahead"}
	if not ahead.is_empty() and float(ahead[0].t) - w.weather_t < 4.0 and forced == "":
		return {"fail": "not enough setup time before the next strike"}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Game.weather.seed_value, w.visit_id, "walker", _run_counter])
	var viewer := "player"
	var eye := player_eye()
	var ccam := -1
	var pl: Player = Game.player
	var inside := pl != null and TerrorPlacement.context_of(pl) in ["camper", "cabin"]
	if inside and Game.tv:
		var shown: Array = Game.tv.shown_cameras()
		if not shown.is_empty():
			ccam = int(shown[rng.randi() % shown.size()])
			viewer = Game.tv.cam_id(ccam)
			var cam: Node3D = Game.tv.cams[ccam]
			eye = cam.global_position
	for attempt in 16:
		var base_dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		if ccam >= 0:
			var cf: Vector3 = -(Game.tv.cams[ccam] as Node3D).global_basis.z
			base_dir = Vector3(cf.x, 0, cf.z).normalized()
		elif pl:
			var f := -pl.camera.global_basis.z
			base_dir = Vector3(f.x, 0, f.z).normalized().rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
		var p0 := TerrorPlacement.treeline_point(eye, base_dir, 24.0, 55.0, 0.6, rng)
		if not _valid_spot(p0):
			# Cleared land (no treeline left): a stump corridor / open ground
			# at the same distance, still grounded, reachable and outside refuges.
			p0 = _ground(eye + base_dir.rotated(Vector3.UP, rng.randf_range(-0.4, 0.4)) * rng.randf_range(24.0, 50.0))
			if not _valid_spot(p0):
				continue
		var side := base_dir.cross(Vector3.UP).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
		var pts: Array = [_ground(p0)]
		var ok := true
		for k in 2:
			var nxt := _ground(pts.back() + side * rng.randf_range(6.0, 12.0) + base_dir * rng.randf_range(-3.0, 3.0))
			if not _valid_spot(nxt) or _path(pts.back(), nxt).is_empty():
				ok = false
				break
			pts.append(nxt)
		if not ok:
			continue
		var seen := 0
		for q in pts:
			if TerrorPlacement.visible_from(eye, q + Vector3(0, 1.4, 0), _space()):
				seen += 1
		if seen < 2:
			continue
		var exit := TerrorPlacement.withdrawal(pts.back(), eye)
		if not _valid_spot(exit) or _path(pts.back(), exit).is_empty():
			continue
		return {"points": pts.map(func(v: Vector3) -> Array: return [v.x, v.y, v.z]), "exit": [exit.x, exit.y, exit.z], "viewer": viewer, "cam": ccam,
			"eye": [eye.x, eye.y, eye.z], "kind": "thin_man"}
	return {"fail": "no visible, reachable waypoint chain"}


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _listener_pos(r: Dictionary) -> Vector3:
	var p: Dictionary = r.plan
	if int(p.cam) >= 0 and Game.tv:
		return Game.tv.camera_position(int(p.cam))
	return player_eye()


func _begin_thunder_walker(r: Dictionary) -> void:
	var p: Dictionary = r.plan
	var pts: Array = p.points
	r["idx"] = 0                       # current waypoint it stands at / leaves
	r["route"] = []                    # path to the next waypoint
	r["win"] = []                      # active masking window [start, end]
	r["windows"] = []                  # [{strike, start, end, moved}]
	r["last_strike_t"] = Game.weather.weather_t
	r["stand_s"] = 0.0
	var at := _v(pts[0])
	# Placed while unobserved where possible; it is simply "already there".
	_actor(r, str(p.kind), at, _listener_pos(r))
	r.state = "waiting"


func _flash_thunder_walker(r: Dictionary, st: Dictionary) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null:
		return
	r.last_strike_t = float(st.t)
	if str(r.state) in ["waiting", "moving", "leaving"]:
		_reveal(r, a.global_position, st)
	# The flash is NOT the window: the window opens when this strike's
	# thunder arrives at the relevant listener and masks steps there.
	var lp := _listener_pos(r)
	var need := STEP_DB - 20.0 * log(maxf(a.global_position.distance_to(lp), 1.0)) / log(10.0) - _loss(a.global_position, lp)
	var win: Array = Game.weather.masking_window(st, lp, need)
	if not win.is_empty():
		(r.windows as Array).append({"strike": str(st.id), "start": float(win[0]), "end": float(win[1]), "moved": 0.0, "listener": str(r.plan.viewer)})
		stats.windows += 1


func _in_window(r: Dictionary) -> Dictionary:
	var t: float = Game.weather.weather_t
	for wd in r.get("windows", []):
		if t >= float(wd.start) and t <= float(wd.end):
			return wd
	return {}


func _tick_thunder_walker(r: Dictionary, delta: float) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null or not is_instance_valid(a):
		_finish(r, "lost")
		return
	_cue(r, delta)
	var w: WeatherService = Game.weather
	var pts: Array = r.plan.points
	# At its exit: it stands there (coherent) for as long as anyone watches,
	# and is gone only once unobserved.
	if bool(r.get("at_exit", false)):
		a.stand()
		if unobserved(a.global_position):
			a.dissolve(0.8)
			_finish(r, "completed")
		return
	var wd := _in_window(r)
	# Conditions run out: no thunder for a while -> leave (unseen) or end.
	if str(r.state) != "leaving" and w.weather_t - float(r.last_strike_t) > 60.0 and w.upcoming_strikes(w.weather_t, 30.0).is_empty():
		r.state = "leaving"
	if wd.is_empty():
		a.stand()
		r.stand_s = float(r.stand_s) + delta
		if str(r.state) == "leaving" and unobserved(a.global_position):
			a.dissolve(0.8)
			_finish(r, "withdrew unseen")
		return
	# Inside a masking window: walk along a real route, grounded each frame.
	var route: Array = r.route
	if route.is_empty():
		var target := _v(r.plan.exit) if (str(r.state) == "leaving" or int(r.idx) >= pts.size() - 1) else _v(pts[int(r.idx) + 1])
		route = _path(a.global_position, target)
		if route.is_empty():
			r.state = "leaving"
			if unobserved(a.global_position):
				_finish(r, "route invalid")
			return
		r.route = route
		r["step_acc"] = 0.0
	var remaining := 0.0
	var prev := a.global_position
	for q in route:
		remaining += prev.distance_to(q)
		prev = q
	var left_s := maxf(float(wd.end) - w.weather_t, 0.25)
	var spd := clampf(remaining / left_s, 1.0, 2.6)
	var move := spd * delta
	var pos := a.global_position
	while move > 0.0 and not route.is_empty():
		var tgt: Vector3 = route[0]
		var d := pos.distance_to(tgt)
		if d <= move:
			pos = tgt
			move -= d
			route.pop_front()
		else:
			pos = pos + (tgt - pos) / d * move
			move = 0.0
	var moved := pos.distance_to(a.global_position)
	wd.moved = float(wd.moved) + moved
	a.stride_to(pos, spd)
	r.step_acc = float(r.get("step_acc", 0.0)) + moved
	if float(r.step_acc) >= 0.75:
		r.step_acc = 0.0
		var heard := step(r, a.global_position)
		(r.ai as Array).append({"t": snappedf(w.weather_t, 0.01), "player": heard.player, "camera": heard.camera, "workers": heard.workers})
	if route.is_empty():
		r.route = []
		if str(r.state) == "leaving" or int(r.idx) >= pts.size() - 1:
			# Arrived at the exit behind cover.
			r["at_exit"] = true
			a.stand()
			return
		r.idx = int(r.idx) + 1
		r.state = "moving" if int(r.idx) < pts.size() - 1 else "leaving"


# ------------------------------------------------------------- shared walking

## Walks an actor toward `target` along a real route. With `need_window`
## it moves only inside a masking window at the run's listener (and stands
## still otherwise). Returns true on arrival.
func _walk(r: Dictionary, a: TerrorActor, target: Vector3, spd: float, need_window: bool, delta: float) -> bool:
	if need_window and _in_window(r).is_empty():
		a.stand()
		return false
	var route: Array = r.get("route", [])
	if route.is_empty() or not r.has("route_to") or _v(r.route_to).distance_to(target) > 0.5:
		route = _path(a.global_position, target)
		r["route_to"] = [target.x, target.y, target.z]
		if route.is_empty():
			return false
	var move := spd * delta
	var pos := a.global_position
	while move > 0.0 and not route.is_empty():
		var tgt: Vector3 = route[0]
		var d := pos.distance_to(tgt)
		if d <= move:
			pos = tgt
			move -= d
			route.pop_front()
		else:
			pos = pos + (tgt - pos) / d * move
			move = 0.0
	r.route = route
	var moved := pos.distance_to(a.global_position)
	if not need_window and _in_window(r).is_empty():
		pass
	a.stride_to(pos, spd)
	r["step_acc"] = float(r.get("step_acc", 0.0)) + moved
	if float(r.step_acc) >= 0.8:
		r.step_acc = 0.0
		var heard := step(r, a.global_position)
		(r.ai as Array).append({"t": snappedf(Game.weather.weather_t, 0.01), "player": heard.player, "camera": heard.camera, "workers": heard.workers})
	return route.is_empty()


## Masking windows for any run with a listener: opened by each strike.
func _open_window(r: Dictionary, st: Dictionary, src: Vector3) -> void:
	var lp := _listener_pos(r) if r.plan.has("cam") else player_eye()
	var need := STEP_DB - 20.0 * log(maxf(src.distance_to(lp), 1.0)) / log(10.0) - _loss(src, lp)
	var win: Array = Game.weather.masking_window(st, lp, need)
	if win.is_empty():
		return
	if not r.has("windows"):
		r["windows"] = []
	(r.windows as Array).append({"strike": str(st.id), "start": float(win[0]), "end": float(win[1]), "moved": 0.0, "listener": "player"})
	stats.windows += 1


func _leave_unseen(r: Dictionary, a: TerrorActor, delta: float, need_window := true) -> void:
	var exit := _v(r.plan.exit)
	var arrived := _walk(r, a, exit, 1.3, need_window, delta)
	if (arrived or float(r.t) > MAX_RUN_S) and unobserved(a.global_position):
		a.dissolve(0.8)
		_finish(r, "withdrew unseen")


# ------------------------------------------------------------- 1 borrowed shadow

func _plan_borrowed_shadow() -> Dictionary:
	var pl: Player = Game.player
	if pl == null or TerrorPlacement.context_of(pl) != "camper":
		return {"fail": "player not in the camper"}
	var cam_c := NightAnchors.camper()
	if cam_c == null:
		return {"fail": "no camper"}
	var side := "camper_window_r" if randf() < 0.6 else "camper_window_l"
	var wout := NightAnchors.point(side)
	var center := cam_c.global_position
	var outward := Vector3(wout.x - center.x, 0, wout.z - center.z).normalized()
	var caster := _window_line_spot(wout, outward, 1.3, 22.0)
	if caster == Vector3.INF:
		return {"fail": "the window looks onto lamp light or water only (refuge rules)"}
	var light := caster + outward * 5.0 + Vector3(0, 1.2, 0)
	return {"window": [wout.x, wout.y, wout.z], "caster": [caster.x, caster.y, caster.z], "light": [light.x, light.y, light.z], "out": [outward.x, 0, outward.z], "side": side}


func _begin_borrowed_shadow(r: Dictionary) -> void:
	var p: Dictionary = r.plan
	var root := Node3D.new()
	add_child(root)
	_add_node(r, root)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.22
	cm.height = 1.75
	body.mesh = cm
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	body.name = "ShadowCaster"
	root.add_child(body)
	root.global_position = _v(p.caster) + Vector3(0, 0.9, 0)
	var sl := SpotLight3D.new()
	sl.shadow_enabled = true
	sl.spot_range = 14.0
	sl.spot_angle = 28.0
	sl.light_color = Color(0.82, 0.86, 1.0)
	sl.light_energy = 0.0
	sl.name = "FlashThroughWindow"
	add_child(sl)
	_add_node(r, sl)
	sl.global_position = _v(p.light)
	sl.look_at(_v(p.window), Vector3.UP)
	r["caster"] = root
	r["light"] = sl
	r["flash_n"] = 0
	r["fx"] = -1.0
	r.state = "waiting"


func _flash_borrowed_shadow(r: Dictionary, st: Dictionary) -> void:
	r.flash_n = int(r.flash_n) + 1
	r.fx = 0.0
	r["strike_kind"] = str(st.kind)
	var seen := player_sees(_v(r.plan.window), 70.0)
	if int(r.flash_n) == 1:
		(r.presented as Array).append({"strike": str(st.id), "by": "player" if seen else "nobody", "what": "a shadow crossing the window"})
	else:
		var caster: Node3D = r.caster
		if is_instance_valid(caster):
			caster.visible = false        # it has had time to leave
		(r.presented as Array).append({"strike": str(st.id), "by": "player" if seen else "nobody", "what": "the empty patch"})
	(r.strikes as Array).append(str(st.id))


func _tick_borrowed_shadow(r: Dictionary, delta: float) -> void:
	var sl: SpotLight3D = r.get("light")
	if float(r.fx) >= 0.0 and sl:
		r.fx = float(r.fx) + delta
		var raw := WeatherService.flash_raw("mid", 1, float(r.fx))
		if str(Settings.get_v("flash_reduction")) == "reduced":
			raw = 0.25 * sin(clampf(float(r.fx) / 1.2, 0.0, 1.0) * PI)
		elif str(Settings.get_v("flash_reduction")) != "full":
			raw = 0.15 * sin(clampf(float(r.fx) / 1.2, 0.0, 1.0) * PI)   # soft equivalent cue
		sl.light_energy = 9.0 * raw
		var caster: Node3D = r.caster
		if int(r.flash_n) == 1 and is_instance_valid(caster):
			var along := Vector3(-float(r.plan.out[2]), 0, float(r.plan.out[0]))
			caster.global_position += along * 2.4 * delta
		if float(r.fx) > 1.4:
			r.fx = -1.0
			sl.light_energy = 0.0
			if int(r.flash_n) >= 2:
				_finish(r, "completed")
	if TerrorPlacement.context_of(Game.player) != "camper" and int(r.flash_n) == 0:
		_finish(r, "cancelled")
	elif float(r.t) > 90.0 and int(r.flash_n) == 0:
		_finish(r, "cancelled")


# ------------------------------------------------------------- 3 between the trunks

func _plan_between_trunks() -> Dictionary:
	var pl: Player = Game.player
	if pl == null:
		return {"fail": "no player"}
	var eye := player_eye()
	var f := -pl.camera.global_basis.z
	f.y = 0.0
	f = f.normalized()
	# Standing trunks 30-70 m out, in front of the player (whole-island list,
	# not the nav hash, which only covers trees near routes).
	var cands: Array = []
	var xs: PackedFloat32Array = World.trees.x
	var zs: PackedFloat32Array = World.trees.z
	for i in xs.size():
		var dx := xs[i] - eye.x
		var dz := zs[i] - eye.z
		var d := sqrt(dx * dx + dz * dz)
		if d < 28.0 or d > 80.0:
			continue
		var id := int(World.trees.id[i])
		if World.removed_trees.has(id) or not World.is_native(id):
			continue
		cands.append(Vector3(xs[i], 0, zs[i]))
	# Prefer what is in front of the player; anywhere is allowed (the flash
	# reveals it wherever it stands; where to look stays the player's choice).
	cands.sort_custom(func(a: Vector3, b: Vector3) -> bool: return (a - eye).normalized().dot(f) > (b - eye).normalized().dot(f))
	var what := "trunks"
	for a in cands.slice(0, 220):
		for b in cands.slice(0, 220):
			var gap := (a as Vector3).distance_to(b)
			if gap < 1.4 or gap > 6.0:
				continue
			var spot := _ground(((a as Vector3) + (b as Vector3)) * 0.5)
			if not _valid_spot(spot):
				continue
			if not (TerrorPlacement.visible_from(eye, spot + Vector3(0, 1.5, 0), _space()) or TerrorPlacement.visible_from(eye, spot + Vector3(0, 2.2, 0), _space())):
				continue
			var exit := TerrorPlacement.withdrawal(spot, eye)
			if not _valid_spot(exit) or _path(spot, exit).is_empty():
				continue
			return {"spot": [spot.x, spot.y, spot.z], "exit": [exit.x, exit.y, exit.z], "what": what, "kind": "tall_woman"}
	# Cleared land: an equivalent rock location in view.
	for i in (World.rocks.x as PackedFloat32Array).size():
		var rc := Vector3(World.rocks.x[i], 0, World.rocks.z[i])
		var d2 := rc.distance_to(Vector3(eye.x, 0, eye.z))
		if d2 < 25.0 or d2 > 70.0 or (rc - Vector3(eye.x, 0, eye.z)).normalized().dot(f) < 0.5:
			continue
		var side := f.cross(Vector3.UP).normalized()
		var spot2 := _ground(rc + side * (World.rock_radius(i) + 0.7))
		if not _valid_spot(spot2) or not TerrorPlacement.visible_from(eye, spot2 + Vector3(0, 1.6, 0), _space()):
			continue
		var exit2 := TerrorPlacement.withdrawal(spot2, eye)
		if not _valid_spot(exit2) or _path(spot2, exit2).is_empty():
			continue
		return {"spot": [spot2.x, spot2.y, spot2.z], "exit": [exit2.x, exit2.y, exit2.z], "what": "rock", "kind": "tall_woman"}
	return {"fail": "no visible trunk pair, stump or rock (%d trunks in view)" % cands.size()}


func _begin_between_trunks(r: Dictionary) -> void:
	_actor(r, str(r.plan.kind), _v(r.plan.spot), player_eye())
	r.state = "waiting"


func _flash_between_trunks(r: Dictionary, st: Dictionary) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null:
		return
	if str(r.state) == "waiting":
		_reveal(r, a.global_position, st)
		r.state = "leaving"
	_open_window(r, st, a.global_position)


func _tick_between_trunks(r: Dictionary, delta: float) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null:
		_finish(r, "lost")
		return
	_cue(r, delta)
	if Game.player and Game.player.global_position.distance_to(a.global_position) < 15.0:
		r.state = "leaving"
	if str(r.state) == "leaving":
		_leave_unseen(r, a, delta, true)
	elif float(r.t) > 120.0:
		r.state = "leaving"


# ------------------------------------------------------------- 4 fence-step

func _plan_fence_step() -> Dictionary:
	var pl: Player = Game.player
	if pl == null:
		return {"fail": "no player"}
	var o := CampLayout.origin()
	var lp := pl.global_position - o
	var hx := CampLayout.FENCE_HALF.x
	var hz := CampLayout.FENCE_HALF.y
	if absf(lp.x) > hx + 25.0 or absf(lp.z) > hz + 25.0:
		return {"fail": "player far from the fence"}
	# The long side nearest the player, 1.5 m outside, an 8 m run.
	var side := 1.0 if lp.x >= 0.0 else -1.0
	var z0 := clampf(lp.z, -hz + 5.0, hz - 13.0)
	var a := _ground(o + Vector3(side * (hx + 1.5), 0, z0))
	var b := _ground(o + Vector3(side * (hx + 1.5), 0, z0 + 8.0))
	if not _valid_spot(a) or not _valid_spot(b):
		return {"fail": "fence ground invalid"}
	return {"a": [a.x, a.y, a.z], "b": [b.x, b.y, b.z]}


func _begin_fence_step(r: Dictionary) -> void:
	r["u"] = 0.0
	r.state = "waiting"
	r["windows"] = []


func _flash_fence_step(r: Dictionary, st: Dictionary) -> void:
	if str(r.state) == "waiting":
		_open_window(r, st, _v(r.plan.a))
		(r.strikes as Array).append(str(st.id))


func _tick_fence_step(r: Dictionary, delta: float) -> void:
	var wd := _in_window(r)
	if str(r.state) == "waiting" and not wd.is_empty():
		r.state = "walking"
		r["win_end"] = float(wd.end)
	if str(r.state) == "walking":
		var t: float = Game.weather.weather_t
		var a := _v(r.plan.a)
		var b := _v(r.plan.b)
		if t < float(r.win_end):
			var before := float(r.u)
			r.u = minf(float(r.u) + delta * 1.4 / a.distance_to(b), 0.92)
			if floor(before * 10.0) != floor(float(r.u) * 10.0):
				var heard := step(r, a.lerp(b, float(r.u)))
				(r.ai as Array).append({"t": snappedf(t, 0.01), "player": heard.player, "covered": not heard.player})
		elif t > float(r.win_end) + 0.35 and (Game.weather.audible_over_masking(b, CRACK_DB, player_eye(), -1.0, _loss(b, player_eye())) or t > float(r.win_end) + 10.0):
			# The lull: one final contact at the real endpoint, exposed.
			var heard2 := step(r, b, CRACK_DB, "terror.fence")
			(r.presented as Array).append({"what": "final contact at the fence", "by": "player" if heard2.player else "nobody", "pos": [snappedf(b.x, 0.1), snappedf(b.z, 0.1)]})
			_finish(r, "completed")
			return
	if float(r.t) > 120.0:
		_finish(r, "cancelled")


# ------------------------------------------------------------- 5 the porch count

func _plan_porch_count() -> Dictionary:
	var porch := NightAnchors.point("camper_porch")
	if porch == Vector3.INF or Game.player == null or Game.player.global_position.distance_to(porch) > 14.0:
		return {"fail": "player not near the camper porch"}
	var c := NightAnchors.camper()
	var rail := porch + (porch - c.global_position).normalized() * 0.6 + Vector3(0, 0.9, 0)
	return {"eave": [porch.x, porch.y + 2.3, porch.z], "rail": [rail.x, rail.y, rail.z]}


func _begin_porch_count(r: Dictionary) -> void:
	r["drip_t"] = 0.0
	r["n"] = 0
	r["talk_seen"] = false
	r.state = "counting"


func _tick_porch_count(r: Dictionary, delta: float) -> void:
	r.drip_t = float(r.drip_t) - delta
	if float(r.drip_t) <= 0.0:
		r.n = int(r.n) + 1
		r.drip_t = 1.3 + 0.05 * sin(float(r.n) * 2.1)       # near-regular
		SoundService.play("amb.drip", _v(r.plan.eave), {"emit": false})
	# After a worker stops talking (or a long enough lull), one tap from the
	# exterior rail; it stays where it is however you move.
	var talking := false
	if Game.crew:
		for wk in Game.crew.workers.values():
			if SoundService.speaking(wk):
				talking = true
	if talking:
		r.talk_seen = true
	var lull := not talking and (bool(r.talk_seen) or int(r.n) > 14)
	if lull and int(r.n) > 6 and str(r.state) == "counting":
		var rail := _v(r.plan.rail)
		var heard: bool = Game.weather.audible_over_masking(rail, 70.0, player_eye(), -1.0, _loss(rail, player_eye()))
		SoundService.play("terror.knock.wood", rail, {"bus": "Horror", "db": -6.0, "emit": true})
		(r.presented as Array).append({"what": "one tap from the porch rail", "by": "player" if heard else "nobody", "after": "a worker stopped talking" if bool(r.talk_seen) else "a lull"})
		_finish(r, "completed")
		return
	if Game.weather.rain < 0.2 or float(r.t) > 120.0:
		_finish(r, "cancelled")


# ------------------------------------------------------------- 6 the wrong wake

func _plan_wrong_wake() -> Dictionary:
	var wall: CameraWall = Game.tv
	if wall == null:
		return {"fail": "no cameras"}
	for ci in wall.shown_cameras():
		var cam: Node3D = wall.cams[int(ci)]
		var f := -cam.global_basis.z
		f.y = 0.0
		f = f.normalized()
		for dist in [18.0, 26.0, 34.0, 44.0, 56.0, 68.0, 80.0, 92.0]:
			var c := cam.global_position + f * float(dist)
			var d0 := World.water_depth_at(c.x, c.z)
			if d0 < 0.2 or d0 > 2.0:
				continue
			var side := f.cross(Vector3.UP).normalized()
			var a := c - side * 8.0
			var b := c + side * 8.0
			var ok := true
			for k in 7:
				var q := a.lerp(b, k / 6.0)
				var dd := World.water_depth_at(q.x, q.z)
				if dd < 0.2 or dd > 2.0 or not TerrorPlacement.visible_from(cam.global_position, Vector3(q.x, World.water_level_at(q.x, q.z) + 0.3, q.z), _space()):
					ok = false
					break
			if ok:
				return {"cam": int(ci), "a": [a.x, 0, a.z], "b": [b.x, 0, b.z], "viewer": wall.cam_id(int(ci))}
	return {"fail": "no shown camera with a shallow route in view"}


func _begin_wrong_wake(r: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "WrongWake"
	add_child(root)
	_add_node(r, root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.93, 0.95, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 6:
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.5 + k * 0.25, 0.9)
		q.mesh = pm
		q.material_override = mat
		q.position = Vector3(0, 0.02, 0.6 * k)
		root.add_child(q)
	r["node"] = root
	r["u"] = 0.0
	r.state = "moving"


func _tick_wrong_wake(r: Dictionary, delta: float) -> void:
	var a := _v(r.plan.a)
	var b := _v(r.plan.b)
	r.u = float(r.u) + delta * 1.4 / a.distance_to(b)
	var q := a.lerp(b, minf(float(r.u), 1.0))
	var root: Node3D = r.node
	root.global_position = Vector3(q.x, World.water_level_at(q.x, q.z) + 0.03, q.z)
	root.look_at(Vector3(b.x, root.global_position.y, b.z) + (b - a) * 10.0, Vector3.UP)
	if float(r.u) >= 1.0:
		(r.presented as Array).append({"what": "a moving break in the foam (shallow route)", "by": str(r.plan.viewer)})
		_finish(r, "completed")


# ------------------------------------------------------------- 7 two windows

func _plan_two_windows() -> Dictionary:
	var pl: Player = Game.player
	if pl == null or TerrorPlacement.context_of(pl) != "camper":
		return {"fail": "player not in the camper"}
	var c := NightAnchors.camper()
	var wr := NightAnchors.point("camper_window_r")
	var wl := NightAnchors.point("camper_window_l")
	var out := Vector3(wr.x - c.global_position.x, 0, wr.z - c.global_position.z).normalized()
	var spot := _window_line_spot(wr, out, 3.0, 26.0)
	if spot == Vector3.INF:
		return {"fail": "the right window looks onto lamp light or water only (refuge rules)"}
	var inner_l := wl - Vector3(wl.x - c.global_position.x, 0, wl.z - c.global_position.z).normalized() * 0.8
	var second := TerrorPlacement.visible_from(inner_l, spot + Vector3(0, 1.4, 0), _space())
	var exit := TerrorPlacement.withdrawal(spot, c.global_position)
	return {"spot": [spot.x, spot.y, spot.z], "second_angle": second, "exit": [exit.x, exit.y, exit.z], "kind": "thin_man"}


func _begin_two_windows(r: Dictionary) -> void:
	_actor(r, str(r.plan.kind), _v(r.plan.spot), NightAnchors.camper().global_position)
	r["flash_n"] = 0
	r.state = "waiting"


func _flash_two_windows(r: Dictionary, st: Dictionary) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null:
		return
	r.flash_n = int(r.flash_n) + 1
	if int(r.flash_n) == 1:
		_reveal(r, a.global_position, st)
	elif int(r.flash_n) == 2:
		(r.presented as Array).append({"strike": str(st.id), "what": "second angle through the other window" if bool(r.plan.second_angle) else "no second angle (geometry does not support one)",
			"by": "player" if bool(r.plan.second_angle) and player_sees(a.global_position + Vector3(0, 1.4, 0), 70.0) else "nobody"})
		r.state = "leaving"
	_open_window(r, st, a.global_position)


func _tick_two_windows(r: Dictionary, delta: float) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null:
		_finish(r, "lost")
		return
	_cue(r, delta)
	if str(r.state) == "leaving":
		_leave_unseen(r, a, delta, true)
	elif float(r.t) > 150.0:
		r.state = "leaving"


# ------------------------------------------------------------- 8 still in the gust

func _plan_still_in_gust() -> Dictionary:
	var pl: Player = Game.player
	if pl == null:
		return {"fail": "no player"}
	var eye := player_eye()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Game.weather.seed_value, Game.weather.visit_id, "gust", _run_counter])
	var f := -pl.camera.global_basis.z
	for attempt in 12:
		var dir := Vector3(f.x, 0, f.z).normalized().rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
		var p := TerrorPlacement.treeline_point(eye, dir, 20.0, 45.0, 0.5, rng)
		if not _valid_spot(p) or not TerrorPlacement.visible_from(eye, p + Vector3(0, 1.5, 0), _space()):
			continue
		var exit := TerrorPlacement.withdrawal(p, eye)
		if not _valid_spot(exit) or _path(p, exit).is_empty():
			continue
		return {"spot": [p.x, p.y, p.z], "exit": [exit.x, exit.y, exit.z], "kind": "afterimage"}
	return {"fail": "no visible treeline spot"}


func _begin_still_in_gust(r: Dictionary) -> void:
	_actor(r, str(r.plan.kind), _v(r.plan.spot), player_eye())
	r["rolls"] = 0
	r.state = "waiting"


func _flash_still_in_gust(r: Dictionary, st: Dictionary) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null:
		return
	r.rolls = int(r.rolls) + 1
	if int(r.rolls) == 1:
		_reveal(r, a.global_position, st)
	else:
		r.state = "leaving"        # it leaves during a LATER roll
	_open_window(r, st, a.global_position)


func _tick_still_in_gust(r: Dictionary, delta: float) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null:
		_finish(r, "lost")
		return
	_cue(r, delta)
	if str(r.state) == "waiting" and player_sees(a.global_position + Vector3(0, 1.4, 0)) and int(r.rolls) == 0 and Game.weather.gust > 0.6:
		(r.presented as Array).append({"what": "a motionless silhouette among bending branches", "by": "player"})
		r.rolls = 1
	if str(r.state) == "leaving":
		_leave_unseen(r, a, delta, true)
	elif float(r.t) > 160.0:
		r.state = "leaving"


# ------------------------------------------------------------- 9 camera desync rumor

var rumor := {"generic": false, "local": false, "camera": ""}

func _plan_feed_rumor() -> Dictionary:
	if bool(rumor.generic):
		return {"fail": "already posted"}
	if Game.feed == null:
		return {"fail": "no feed"}
	return {"ok": true}


func _begin_feed_rumor(r: Dictionary) -> void:
	_rumor(false, "")
	(r.presented as Array).append({"what": "a forum thread about shapes arriving with the flash", "by": "feed"})
	_finish(r, "completed", 600.0)


## The generic post is allowed on any stormy night; the LOCAL reply only
## after a real storm encounter was seen on one of this camp's cameras.
func _rumor(local: bool, cam: String) -> void:
	var feed: FeedService = Game.feed
	if feed == null:
		return
	var day := Game.campaign.clock.day if Game.campaign else 1
	if not bool(rumor.generic):
		rumor.generic = true
		feed.post_dynamic({"id": "fo.storm.desync.01", "kind": "forum", "site": "lamphours", "thread": "t.lamphours-storm-desync",
			"title": "Shapes that arrive with the flash", "author": "lh_crane_halvard", "day": day, "slot": "night", "at": 0, "region": "halvard", "votes": 14,
			"text": "Night lifts were stood down for the storm, so I watched the site cameras from the cabin. Every few flashes the frame jumps a little and the yard looks different for one picture, then the thunder comes and it's the yard again. Lightning plays with the sensor, I know. Still. Anyone else get the feeling a camera shows you something one flash early?"}, day)
	if local and not bool(rumor.local):
		rumor.local = true
		rumor.camera = cam
		feed.post_dynamic({"id": "fo.storm.desync.02", "kind": "forum", "site": "lamphours", "thread": "t.lamphours-storm-desync",
			"author": "lh_carer_vellmark", "parent": "fo.storm.desync.01", "day": day, "slot": "night", "at": 0, "region": "vellmark", "votes": 6,
			"text": "A man on one of those island clearance jobs posted the same thing last night on another board, then deleted it. Said his camp camera caught a figure on one flash and the next flash it was somewhere else, nearer, and the recording kept both. He said the thunder on the recording came late, like it should, but the figure didn't."}, day)


# ------------------------------------------------------------- 10 unanswered call

func _plan_unanswered_call() -> Dictionary:
	var pl: Player = Game.player
	if pl == null:
		return {"fail": "no player"}
	var eye := player_eye()
	# Only in a lull between rolls: the call must not be covered.
	if Game.weather.masking_db(eye) > WeatherService.RAIN_BED_DB + 4.0:
		return {"fail": "no lull (thunder rolling)"}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Game.weather.seed_value, Game.weather.visit_id, "call", _run_counter])
	for attempt in 10:
		var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var p := TerrorPlacement.treeline_point(eye, dir, 30.0, 60.0, 1.0, rng)
		if _valid_spot(p):
			return {"spot": [p.x, p.y + 1.6, p.z]}
	return {"fail": "no plausible exterior spot"}


func _begin_unanswered_call(r: Dictionary) -> void:
	var at := _v(r.plan.spot)
	SoundService.play("terror.call.far", at, {"bus": "Horror", "emit": true})
	var heard: bool = Game.weather.audible_over_masking(at, 92.0, player_eye(), -1.0, _loss(at, player_eye()))
	(r.presented as Array).append({"what": "a voice between rolls", "by": "player" if heard else "nobody"})
	# Workers who actually heard it may say so later (hearing only, no name).
	if Game.crew:
		var hear_r := 0.0
		for wk in Game.crew.workers.values():
			var wp: Vector3 = (wk as Node3D).global_position + Vector3(0, 1.6, 0)
			if Game.weather.audible_over_masking(at, 92.0, wp, -1.0, _loss(at, wp)):
				hear_r = maxf(hear_r, wp.distance_to(at) + 1.0)
		if hear_r > 0.0:
			var who: Array = Game.crew.emit_stimulus({"id": "%s@call" % r.id, "kind": "T02", "modality": "voice", "pos": at, "loudness": hear_r / 60.0, "severity": 0.15, "ambiguous": true})
			(r.npc as Array).append({"heard_voice": who})
	_finish(r, "completed")


func _tick_unanswered_call(_r: Dictionary, _delta: float) -> void:
	pass


# ------------------------------------------------------------- 11 the missed flash

## At sleep: if this night's scheduled storm had strikes in the part of the
## night you slept through, a camera may keep one ambiguous silhouette with
## that strike's identity (through the ordinary recorder; one per night).
func on_night(d: int) -> Dictionary:
	var nr: NightRecorder = Game.night_recorder
	var w: WeatherService = Game.weather
	if nr == null or w == null or nr.nights.has(str(d)) and str(nr.nights[str(d)]) != "":
		return {}
	var b: Dictionary = by_id.get("sb11", {})
	if int(counts.get("sb11", 0)) >= int(b.get("per_campaign", 3)):
		return {}
	var slept_from := w.weather_t if w.weather_day == d else WorkdayClock.NIGHT_AT
	var pick := {}
	var sched := w._sched()
	for v in (sched.days.get(d, {"visits": []}) as Dictionary).visits:
		if bool(v.quiet) or not str(v.profile) in (b.profiles as Array):
			continue
		for st in sched.strikes(d, v):
			if float(st.t) > slept_from and str(st.kind) != "far":
				pick = st
				break
		if not pick.is_empty():
			break
	if pick.is_empty():
		return {}
	var scen := {"id": "storm_missed_flash", "title": "The missed flash", "cameras": ["CAM_03", "CAM_04", "CAM_05", "CAM_08", "CAM_09", "CAM_10"],
		"requires": [], "hour": 1.0, "duration": 8.0,
		"actor": {"kind": "figure", "track": [[0.0, 1.2, 30.0], [8.0, 1.2, 30.0]], "hidden": [[0.0, 2.0], [2.6, 8.0]]},
		"props": [], "audio": [], "consequence": {"kind": "notice", "text": ""}, "cooldown": 6, "weight": 1.0}
	var clip := nr.capture(scen, d)
	if clip.is_empty():
		return {}
	# The strike's identity, its flash at 2.0 s and its thunder at the
	# camera's own distance: playback keeps the original strike timing.
	var cp := Game.tv.camera_position(Game.tv.cams.find(nr.camera(str(clip.camera)))) if Game.tv else Vector3.ZERO
	var delay := StormSchedule.thunder_delay(WeatherService.strike_pos(pick).distance_to(cp))
	clip["strike"] = {"id": str(pick.id), "kind": str(pick.kind), "flash_at": 2.0, "thunder_at": snappedf(2.0 + delay, 0.01)}
	(clip.audio as Array).append([snappedf(2.0 + delay, 0.01), "weather.thunder.near" if str(pick.kind) == "near" else "weather.thunder.far", cp.x, cp.y + 30.0, cp.z])
	nr.clips.append(clip)
	nr.nights[str(d)] = str(clip.id)
	nr._queue_morning(clip)
	counts["sb11"] = int(counts.get("sb11", 0)) + 1
	_record({"beat": "sb11", "result": "recorded", "clip": str(clip.id), "strike": str(pick.id), "camera": str(clip.camera)})
	_rumor(true, str(clip.camera))
	return clip


func _plan_missed_flash() -> Dictionary:
	return {"fail": "happens at sleep only"}


# ------------------------------------------------------------- 12 after the rain

func _plan_after_the_rain() -> Dictionary:
	var pl: Player = Game.player
	if pl == null:
		return {"fail": "no player"}
	var eye := player_eye()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Game.weather.seed_value, Game.weather.visit_id, "after", _run_counter])
	for attempt in 12:
		var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var p := TerrorPlacement.treeline_point(eye, dir, 25.0, 45.0, 0.4, rng)
		if not _valid_spot(p):
			continue
		var exit := TerrorPlacement.withdrawal(p, eye)
		if not _valid_spot(exit) or _path(p, exit).is_empty():
			continue
		return {"spot": [p.x, p.y, p.z], "exit": [exit.x, exit.y, exit.z], "kind": "worker_like"}
	return {"fail": "no clearing edge"}


func _begin_after_the_rain(r: Dictionary) -> void:
	_actor(r, str(r.plan.kind), _v(r.plan.spot), player_eye())
	r["stepped"] = false
	r.state = "waiting"


func _tick_after_the_rain(r: Dictionary, delta: float) -> void:
	var a: TerrorActor = _actors.get(r.id)
	if a == null:
		_finish(r, "lost")
		return
	if not bool(r.stepped) and float(r.t) > 3.0:
		r.stepped = true
		var heard := step(r, a.global_position, STEP_DB + 8.0)
		(r.presented as Array).append({"what": "one exposed step at the clearing edge", "by": "player" if heard.player else "nobody",
			"seen": player_sees(a.global_position + Vector3(0, 1.4, 0))})
		r.state = "leaving"
	if str(r.state) == "leaving":
		_leave_unseen(r, a, delta, false)      # a quiet withdrawal, unhurried
	if Game.weather.rain > 0.5:
		r.state = "leaving"


# ------------------------------------------------------------- saves

func capture() -> Dictionary:
	var rs: Array = []
	for r in runs:
		var c: Dictionary = (r as Dictionary).duplicate(true)
		var a: TerrorActor = _actors.get(r.id)
		if a and is_instance_valid(a):
			c["actor"] = {"pos": [a.global_position.x, a.global_position.y, a.global_position.z], "rot": a.rotation.y, "kind": a.kind, "visible": a.visible}
		c.erase("route")             # recomputed in the next window
		rs.append(c)
	return {"version": 1, "runs": rs, "records": records.slice(-80), "done": done.duplicate(), "counts": counts.duplicate(), "counter": _run_counter, "stats": stats.duplicate()}


## Reload mid-encounter: the same figure stands exactly where it was (no
## fade, no replay); its reservation is restored with the director's.
func restore(d: Dictionary) -> void:
	for r in runs.duplicate():
		var a: TerrorActor = _actors.get(r.id)
		if a and is_instance_valid(a):
			a.queue_free()
		for n in _nodes.get(r.id, []):
			if is_instance_valid(n):
				(n as Node).queue_free()
	runs.clear()
	_actors.clear()
	_nodes.clear()
	records = (d.get("records", []) as Array).duplicate(true)
	done = (d.get("done", {}) as Dictionary).duplicate()
	counts = (d.get("counts", {}) as Dictionary).duplicate()
	_run_counter = int(d.get("counter", 0))
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = st[k]
	for c in d.get("runs", []):
		var r: Dictionary = (c as Dictionary).duplicate(true)
		r["route"] = []
		runs.append(r)
		var ad: Dictionary = r.get("actor", {})
		if not ad.is_empty():
			var a := _actor(r, str(ad.kind), _v(ad.pos), _listener_pos(r))
			a.rotation.y = float(ad.rot)
			a.visible = bool(ad.visible)
		if has_method("_restore_" + str(r.executor)):
			call("_restore_" + str(r.executor), r)
		if Game.director and Game.director.reservation.is_empty():
			Game.director.reservation = {"owner": r.id, "family": int(r.family), "beat": r.beat, "since": Game.world_time}
