class_name MissingNight
extends RefCounted
## Phase 27 (owner decision 3): before the hunt, a worker can fail to come
## home one evening. It only happens on an island that has started to stir,
## only to someone who does not believe in any of it, to one person at a
## time and not often.
##
## At dusk the chosen worker walks out past the fence instead of home and
## stands there, listening. The boss can go and bring them in (a work lamp
## makes the walk survivable), or sleep: then they walk back in at first
## light, shaken, and sit out the morning. Nobody is ever harmed and
## nothing here touches safety: the worker is simply not in the cabin.

const MIN_TIER := 1                 # night pressure tier before it can happen
const CHANCE := 0.3                 # per eligible evening
const COOLDOWN_DAYS := 4
const BELIEF_BELOW := 0.4           # only someone who does not really believe
const NEAR := 55.0                  # metres from camp: how far out they stand
const FAR := 95.0
const LAST_DAY := 28                # never on the last evenings of the contract

const FOUND := {"trust": 0.2, "belief": 0.3, "fear": 0.2}
const ALONE := {"trust": -0.1, "belief": 0.5, "fear": 0.45}

var crew: CrewService
var id := ""                        # who is out tonight ("" = nobody)
var day := -1
var state := ""                     # walking / waiting / found / home
var spot := Vector3.ZERO
var decided_day := -1
var last_day := -99
var late_start := {}                # employee id -> day they sit out the morning
var count := 0
var found_count := 0                # nights the boss went out and brought them in
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 2707


func active() -> bool:
	return id != "" and state in ["walking", "waiting", "found"]


func is_missing(w: Worker) -> bool:
	return w != null and id == w.id and state in ["walking", "waiting"]


## Who could it be tonight? Calm, capable people who do not believe.
func candidates() -> Array:
	var out := []
	for w in crew.workers.values():
		var wk := w as Worker
		if str(wk.emp.status) != Payroll.ACTIVE or wk.seated or wk.mind == null:
			continue
		if wk.mind.has("timid") or wk.mind.belief >= BELIEF_BELOW or wk.mind.state >= WorkerMind.Fear.DISTRESSED:
			continue
		if str(wk.emp.get("job", "")) in ["follow", "ride", "home"] or wk.is_carrying():
			continue
		out.append(wk)
	return out


## Start of dusk: decide tonight once.
func on_dusk(force := false) -> bool:
	var c: CampaignService = crew.campaign
	if c == null or not c.active or decided_day == c.clock.day or active():
		return false
	decided_day = c.clock.day
	if not force:
		if c.contract.state != ContractService.ACTIVE or c.clock.day > LAST_DAY:
			return false
		if c.onboarding != null and not c.onboarding.night_rules_ack:
			return false
		if NightPressure.tier(NightPressure.island_level()) < MIN_TIER or c.clock.day - last_day < COOLDOWN_DAYS:
			return false
		if _rng.randf() >= CHANCE:
			return false
	var pool := candidates()
	if pool.is_empty():
		return false
	# A sceptic by nature first, then whoever believes least.
	pool.sort_custom(func(a: Worker, b: Worker) -> bool:
		var sa := 1 if a.mind.has("skeptical") else 0
		var sb := 1 if b.mind.has("skeptical") else 0
		return sa > sb if sa != sb else a.mind.belief < b.mind.belief)
	var w: Worker = pool[0]
	var at := _pick_spot(w)
	if at == Vector3.INF:
		return false
	id = w.id
	day = c.clock.day
	state = "walking"
	spot = at
	last_day = day
	count += 1
	w.abandon("time to go home")      # drops the job; the next decision walks them out
	return true


## A reachable place out past the fence, toward where they were working.
func _pick_spot(w: Worker) -> Vector3:
	var o := World.camp_origin()
	var focus := crew.work_focus(w)
	var dir := Vector3(focus.x - o.x, 0.0, focus.z - o.z)
	if dir.length() < 5.0:
		dir = Vector3(0, 0, -1)
	dir = dir.normalized()
	for k in 12:
		var d := dir.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
		var p := o + d * _rng.randf_range(NEAR, FAR)
		if World.water_depth_at(p.x, p.z) > 0.05 or crew.nav.in_camp(p) or not crew.nav.walkable(p):
			continue
		p.y = crew.nav.surface_at(p)
		if not crew.nav.find_path(w.global_position, p).is_empty():
			return p
	return Vector3.INF


## The crew's decision hook. Returns true if this worker is handled here.
func step(w: Worker) -> bool:
	if id != w.id:
		# The morning after: they sit it out until midday.
		if late_start.has(w.id):
			var c: CampaignService = crew.campaign
			if int(late_start[w.id]) != c.clock.day or c.clock.t > WorkdayClock.NIGHT_AT * 0.4:
				late_start.erase(w.id)
				return false
			if not w.activity in ["sit", "move"]:
				crew.on_home(w)
			return true
		return false
	match state:
		"walking":
			if w.global_position.distance_to(spot) < 2.5:
				state = "waiting"
				w.activity = "missing_wait"
			elif w.activity != "move" and not w.go_to(spot, "missing_wait", "somewhere past the fence"):
				_end_home(w)            # no way out there after all: an ordinary evening
			return true
		"waiting":
			w.activity = "missing_wait"
			return true
		"found":
			# Walking home with the boss; inside the fence they go to bed.
			if crew.nav.in_camp(w.global_position):
				_end_home(w)
				return true
			w.activity = "follow"
			return true
	return false


func _end_home(w: Worker) -> void:
	state = "home"
	id = ""
	w.activity = "idle"
	crew.send_home(w)


## Called every physics frame by the crew: the walk home ends at the fence.
func tick() -> void:
	if id == "" or state != "found":
		return
	var w: Worker = crew.workers.get(id)
	if w == null:
		id = ""
		return
	if crew.nav.in_camp(w.global_position):
		_end_home(w)
	elif w.activity == "idle":
		w.activity = "follow"


## Night has fallen and they are not in.
func on_night() -> void:
	if not active() or state == "found":
		return
	var c: CampaignService = crew.campaign
	var w: Worker = crew.workers.get(id)
	if w == null:
		id = ""
		return
	c.notice.emit("%s has not come back. Their bed is empty. They were last working out past the forest entrance." % str(w.emp.name), 10.0)


## The boss reached them: "Come back with me."
func bring_home(w: Worker) -> bool:
	if not is_missing(w):
		return false
	state = "found"
	found_count += 1
	_apply(w.mind, FOUND)
	w.activity = "follow"
	return true


## Morning. Whoever was still out walks in at first light.
func on_morning() -> void:
	if id == "":
		return
	var w: Worker = crew.workers.get(id)
	var c: CampaignService = crew.campaign
	if w != null:
		if state != "found":
			_apply(w.mind, ALONE)
			late_start[w.id] = c.clock.day
			c.notice.emit("%s walked back in at first light and will not say where they were. They are sitting this morning out." % str(w.emp.name), 10.0)
		var home := crew.bed_approach(w)
		w.global_position = home
		w.activity = "idle"
	id = ""
	state = "home"


func _apply(m: WorkerMind, d: Dictionary) -> void:
	if m == null:
		return
	m.trust = clampf(m.trust + float(d.trust), 0.0, maxf(WorkerMind.TRUST_CAP, m.trust))
	m.belief = clampf(m.belief + float(d.belief), 0.0, 1.0)
	m.fear = clampf(m.fear + float(d.fear) * m.sensitivity(), 0.0, 0.83)     # shaken, never straight to quitting
	m._update_state(crew.now())


func capture() -> Dictionary:
	return {"id": id, "day": day, "state": state, "spot": [snappedf(spot.x, 0.01), snappedf(spot.y, 0.01), snappedf(spot.z, 0.01)],
		"decided_day": decided_day, "last_day": last_day, "late_start": late_start.duplicate(), "count": count, "found_count": found_count}


func restore(d: Dictionary) -> void:
	id = str(d.get("id", ""))
	day = int(d.get("day", -1))
	state = str(d.get("state", ""))
	var s: Array = d.get("spot", [0.0, 0.0, 0.0])
	spot = Vector3(float(s[0]), float(s[1]), float(s[2])) if s.size() == 3 else Vector3.ZERO
	decided_day = int(d.get("decided_day", -1))
	last_day = int(d.get("last_day", -99))
	late_start = {}
	var ls: Dictionary = d.get("late_start", {})
	for k in ls:
		late_start[str(k)] = int(ls[k])
	count = int(d.get("count", 0))
	found_count = int(d.get("found_count", 0))
