class_name TerrorDirector
extends Node
## The one ordinary-night director (Phase 6). It observes only in-game state
## (player body position/facing/movement, safety, context, displayed camera
## views, workers, dog, recent event history) and offers at most one primary
## encounter at a time, chosen from the compiled authored bank
## (data/terror/bank.json: 26 families x 50 events + 12 startle types each).
##
## Pacing: irregular quiet gaps (45-150 s when eligible), one shared peak
## budget (8-12 active night minutes refractory; ~3 under sustained
## deliberate pursuit), startle opportunity weight ~4 % normally and up to
## ~22 % under pursuit. If every candidate is bad - no grounded place, no
## valid withdrawal, wrong context - nothing happens: a quiet night is valid.
## Morning removes temporary actors/props/audio; it never touches wood,
## trees, money, roster or vehicles.

signal encounter_started(id: String)
signal encounter_ended(id: String, result: String)

const QUIET_MIN := 45.0
const QUIET_MAX := 150.0
const PEAK_REFRACTORY := [480.0, 720.0]
const PURSUIT_REFRACTORY := 180.0

static var _inst: TerrorDirector
static var voice_memory: Array[Dictionary] = []

var bank: Dictionary = {}
var events_by_ctx := {}
var startles_by_family := {}
var enabled := true
var forced := false                 # preview fixture: run even outside night
var active: TerrorEncounter
var next_in := 30.0
var night_active_t := 0.0           # active night seconds (pause excluded)
var last_peak_t := -99999.0
var peak_refractory := 600.0
var history: Array[String] = []     # encounter ids this campaign (bounded)
var fired_tonight := {}             # family -> count
var observed := {}                  # id -> result (runtime observed coverage)
var profile := {"pursuit": 0.0, "stare_windows": 0.0, "camera_dwell": 0.0, "retreats": 0.0}
var quiet_outcomes := 0
var _rng := RandomNumberGenerator.new()
var _caption_t := -10.0
var _props: Node3D


func _ready() -> void:
	_inst = self
	_rng.seed = 6606
	_props = Node3D.new()
	_props.name = "TerrorProps"
	add_child(_props)
	load_bank()


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


static func instance() -> TerrorDirector:
	return _inst


func load_bank() -> void:
	var f := FileAccess.open("res://data/terror/bank.json", FileAccess.READ)
	if f == null:
		push_warning("TerrorDirector: bank.json missing")
		return
	bank = JSON.parse_string(f.get_as_text())
	events_by_ctx.clear()
	startles_by_family.clear()
	for e in bank.events:
		var c := str(e.context)
		if not events_by_ctx.has(c):
			events_by_ctx[c] = []
		events_by_ctx[c].append(e)
	for s in bank.startles:
		var fam := int(s.family)
		if not startles_by_family.has(fam):
			startles_by_family[fam] = []
		startles_by_family[fam].append(s)


## Static validation used by tests and the coverage report.
func validate() -> Dictionary:
	var ids := {}
	var errors: Array[String] = []
	var known := ["sound", "voice", "figure", "shadow", "lights", "warmth", "sky", "prop", "feed", "dog_react", "witness", "peak", "rescue_beat"]
	var count := {"events": 0, "startles": 0, "foreman": 0}
	for group in ["events", "startles", "foreman"]:
		for e in bank.get(group, []):
			count[group] = int(count[group]) + 1
			if ids.has(e.id):
				errors.append("duplicate " + str(e.id))
			ids[e.id] = true
			if group != "foreman":
				if (e.get("steps", []) as Array).is_empty():
					errors.append("no executor " + str(e.id))
				for st in e.steps:
					if not str(st.p) in known:
						errors.append("unknown primitive %s in %s" % [str(st.p), str(e.id)])
	return {"counts": count, "errors": errors, "families": (bank.get("families", []) as Array).size()}


# ------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if get_tree().paused or not enabled:
		return
	_update_profile(delta)
	var night := _is_ordinary_night()
	if not night and not forced:
		return
	night_active_t += delta
	if active != null or not reservation.is_empty():
		return
	next_in -= delta
	if next_in <= 0.0:
		# Phase 16: a tired, late-awake boss gets ordinary encounters a
		# little more often (up to x1.25), never below the quiet minimum;
		# peak/startle cooldowns are untouched.
		var w: float = Game.rest.fear_weight() if Game.rest else 1.0
		next_in = maxf(_rng.randf_range(QUIET_MIN, QUIET_MAX) / w, QUIET_MIN)
		offer()


func _is_ordinary_night() -> bool:
	var c: CampaignService = Game.campaign
	if c == null or not c.active:
		return false
	if c.contract.state != ContractService.ACTIVE and c.contract.state != ContractService.LEGACY:
		return false
	if Game.hunt and Game.hunt.hunt_active():
		return false
	return c.clock.phase() == WorkdayClock.Phase.NIGHT


func peak_available() -> bool:
	var refr := PURSUIT_REFRACTORY if float(profile.pursuit) > 0.6 else peak_refractory
	return night_active_t - last_peak_t >= refr


## Phase 17: computer-linked opportunities. Reading can make a pattern
## eligible; execution belongs to the Phase 19 catalog (recorded here so
## the source relationship stays traceable). Never fires anything itself.
var computer_hints: Array = []


func computer_hint(pattern: String, unit_id: String) -> void:
	computer_hints.append({"pattern": pattern, "unit": unit_id, "night_t": snappedf(night_active_t, 0.1)})
	if computer_hints.size() > 60:
		computer_hints.pop_front()


## Phase 17 cl01: stage an ORDINARY window encounter (camper context, an
## event that needs the window, low intensity) through the normal
## placement/reservation path. Returns true only if it really started; the
## feed then commits the warning post, otherwise its fallback.
func stage_window_encounter(_res: Dictionary) -> bool:
	var p := Game.player as Node3D
	if p == null or active != null or not enabled:
		return false
	var cands: Array = []
	for ev in events_by_ctx.get("camper", []):
		if "window" in (ev.get("needs", []) as Array) and int(ev.get("intensity", 3)) <= 2 and bool(ev.get("visual", false)) and _needs_ok(ev):
			cands.append(ev)
	if cands.is_empty():
		return false
	var ev: Dictionary = cands[_rng.randi() % cands.size()]
	return _start(ev, "camper", p, false) != ""


## One opportunity: choose and start an encounter, or deliberately nothing.
func offer(force_id := "") -> String:
	var p := Game.player as Node3D
	if p == null or active != null:
		return ""
	var ctx := TerrorPlacement.context_of(p)
	var startle := false
	var pick: Dictionary = {}
	if force_id != "":
		pick = find(force_id)
		startle = force_id.contains("-J")
	else:
		var weight := 0.22 if float(profile.pursuit) > 0.6 else 0.04
		if peak_available() and _rng.randf() < weight:
			pick = _pick_startle(ctx)
			startle = not pick.is_empty()
		if pick.is_empty():
			pick = _pick_event(ctx)
	if pick.is_empty():
		quiet_outcomes += 1
		return ""
	return _start(pick, ctx, p, startle or force_id != "")


func _start(ev: Dictionary, ctx: String, p: Node3D, peak_ok: bool) -> String:
	if "rescue_beat" in str(ev.get("steps", [])):
		return ""     # the dog-runs family belongs to the once-only rescue quest
	var e := TerrorEncounter.new()
	e.name = "Encounter"
	add_child(e)
	e.setup(ev, str(ev.get("context", ctx)) if str(ev.get("context", "")) in ["woods", "camp", "cabin", "camper", "cameras"] else ctx, peak_ok and peak_available(), _rng.randi())
	if not e.reserve(p):
		e.queue_free()
		quiet_outcomes += 1
		return ""
	active = e
	e.ended.connect(_on_ended.bind(str(ev.id)))
	e.begin(p)
	history.append(str(ev.id))
	if history.size() > 400:
		history.pop_front()
	fired_tonight[int(ev.family)] = int(fired_tonight.get(int(ev.family), 0)) + 1
	encounter_started.emit(str(ev.id))
	return str(ev.id)


func _on_ended(result: String, id: String) -> void:
	if result == "peak":
		last_peak_t = night_active_t
		peak_refractory = _rng.randf_range(PEAK_REFRACTORY[0], PEAK_REFRACTORY[1])
	observed[id] = result
	active = null
	encounter_ended.emit(id, result)


func _needs_ok(ev: Dictionary) -> bool:
	for n in ev.get("needs", []):
		match str(n):
			"workers":
				if Game.crew == null or Game.crew.workers.is_empty():
					return false
			"truck":
				if Game.vehicles == null or Game.vehicles.trucks.is_empty():
					return false
			"dog":
				if Game.dog == null:
					return false
			"dog_rescue_active":
				return false
	return true


func _pick_event(ctx: String) -> Dictionary:
	var pool: Array = events_by_ctx.get(ctx, [])
	if pool.is_empty():
		return {}
	var best: Dictionary = {}
	var best_s := -INF
	for k in 24:
		var e: Dictionary = pool[_rng.randi() % pool.size()]
		if not _needs_ok(e):
			continue
		var s := 1.0 + _rng.randf()
		if not history.has(str(e.id)):
			s += 1.0                                   # novelty
		s -= 0.8 * float(fired_tonight.get(int(e.family), 0))   # no repeats of a family tonight
		if int(e.intensity) >= 3 and not peak_available():
			s -= 3.0                                   # sharp beats respect the shared budget
		if s > best_s:
			best_s = s
			best = e
	return best if best_s > -1.0 else {}


func _pick_startle(ctx: String) -> Dictionary:
	var fams := fired_tonight.keys()
	var fam: int = int(fams[_rng.randi() % fams.size()]) if not fams.is_empty() else 1 + _rng.randi() % 25
	var pool: Array = startles_by_family.get(fam, [])
	var ok: Array = pool.filter(func(s: Dictionary) -> bool: return _needs_ok(s) and (str(s.context) == ctx or (str(s.context) == "interior" and ctx in ["cabin", "camper"]) or str(s.context) == "woods" and ctx in ["woods", "camp"]))
	return ok[_rng.randi() % ok.size()] if not ok.is_empty() else {}


func find(id: String) -> Dictionary:
	for group in ["events", "startles"]:
		for e in bank.get(group, []):
			if str(e.id) == id:
				return e
	return {}


# --------------------------------------------------- behaviour profile

## Recency-weighted tendencies from in-game behaviour only (no thoughts, no
## devices). Pursuit = sustained deliberate movement toward a presented
## presence while outside safety; ordinary work or going home is not it.
func _update_profile(delta: float) -> void:
	for k in profile:
		profile[k] = maxf(float(profile[k]) - delta * 0.01, 0.0)
	var p := Game.player as CharacterBody3D
	if p == null or active == null or active.actor == null or not active.actor.visible:
		return
	var to := active.actor.global_position - p.global_position
	to.y = 0.0
	var v := Vector3(p.velocity.x, 0, p.velocity.z)
	if v.length() > 2.0 and to.length() > 1.0 and v.normalized().dot(to.normalized()) > 0.75:
		if Game.safety and not Game.safety.is_player_safe():
			profile.pursuit = minf(float(profile.pursuit) + delta * 0.08, 1.0)
	elif v.length() > 2.0 and v.normalized().dot(to.normalized()) < -0.5:
		profile.retreats = minf(float(profile.retreats) + delta * 0.05, 1.0)


# ------------------------------------------------- Phase 23 reservations

## One global opportunity at a time: storm encounters (StormTerrors) ask for
## it here, so they share the ordinary director's budget, never overlap an
## encounter, and respect per-family cooldowns (seconds of world time).
var reservation := {}               # {owner, family, beat, since}
var family_cooldown := {}           # family (int) -> world time it is free again
var last_end_t := -99999.0          # world time the last encounter/reservation ended
const STORM_GAP := 75.0             # quiet seconds after any encounter

func can_reserve(family: int) -> String:
	if not enabled:
		return "director off"
	if active != null:
		return "encounter active"
	if not reservation.is_empty():
		return "reserved by " + str(reservation.owner)
	if Game.world_time - last_end_t < STORM_GAP:
		return "quiet gap"
	if Game.world_time < float(family_cooldown.get(family, -1.0)):
		return "family cooldown"
	if fired_tonight.get(family, 0) >= 2:
		return "family used tonight"
	return ""


func reserve(owner: String, family: int, beat: String) -> bool:
	if can_reserve(family) != "":
		return false
	reservation = {"owner": owner, "family": family, "beat": beat, "since": Game.world_time}
	return true


## Ends a reservation (completed, cancelled or withdrawn): the family cools
## down and the ordinary budget restarts from a quiet minimum.
func release(owner: String, cooldown := 900.0, result := "completed") -> void:
	if reservation.is_empty() or str(reservation.owner) != owner:
		return
	var fam := int(reservation.family)
	family_cooldown[fam] = Game.world_time + cooldown
	fired_tonight[fam] = int(fired_tonight.get(fam, 0)) + (1 if result != "cancelled" else 0)
	history.append(str(reservation.beat))
	reservation = {}
	last_end_t = Game.world_time
	next_in = maxf(next_in, QUIET_MIN)


# ------------------------------------------------------------- morning

## Called at morning: ends any encounter and removes night props/actors.
func morning_cleanup() -> void:
	if active:
		active.cancel()
		active = null
	reservation = {}
	for c in _props.get_children():
		c.queue_free()
	for n in get_tree().get_nodes_in_group("terror_prop"):
		n.queue_free()
	fired_tonight.clear()
	night_active_t = 0.0
	last_peak_t = -99999.0
	next_in = _rng.randf_range(20.0, 60.0)


# ------------------------------------------------------- shared helpers

## Captions for meaningful cues, rate-limited, never revealing coordinates.
static func caption(text: String, at: Vector3) -> void:
	if _inst == null or Game.player == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _inst._caption_t < 6.0:
		return
	var d := (Game.player as Node3D).global_position.distance_to(at)
	if d > 70.0:
		return
	_inst._caption_t = now
	var where := "nearby" if d < 15.0 else ("outside" if d < 35.0 else "far off")
	Game.player.show_message("[%s, %s]" % [text, where])


## Short memory of real things people said near anyone (for the Voice
## family and the Foreman's fragments). Only lines actually spoken in game.
static func remember_voice(speaker: String, text: String, at: Vector3) -> void:
	voice_memory.append({"speaker": speaker, "text": text, "pos": [at.x, at.y, at.z], "t": Time.get_ticks_msec()})
	if voice_memory.size() > 40:
		voice_memory.pop_front()


static func voice_memory_pick(rng: RandomNumberGenerator) -> Dictionary:
	if voice_memory.is_empty():
		return {}
	return voice_memory[rng.randi() % voice_memory.size()]


func capture() -> Dictionary:
	return {"reservation": reservation.duplicate(), "family_cooldown": family_cooldown.duplicate(), "next_in": next_in, "night_active_t": night_active_t, "last_peak_t": last_peak_t, "peak_refractory": peak_refractory, "history": history.slice(-120), "fired_tonight": fired_tonight.duplicate(), "profile": profile.duplicate(), "observed": observed.duplicate(), "voice_memory": voice_memory.slice(-20)}


## Restores pacing state; never replays an encounter or a stored peak.
func restore(d: Dictionary) -> void:
	if active:
		active.cancel()
		active = null
	next_in = maxf(float(d.get("next_in", 60.0)), 20.0)    # input grace after load
	reservation = (d.get("reservation", {}) as Dictionary).duplicate()
	family_cooldown = {}
	var fc: Dictionary = d.get("family_cooldown", {})
	for k in fc:
		family_cooldown[int(k)] = float(fc[k])
	night_active_t = float(d.get("night_active_t", 0.0))
	last_peak_t = float(d.get("last_peak_t", -99999.0))
	peak_refractory = float(d.get("peak_refractory", 600.0))
	history.clear()
	for h in d.get("history", []):
		history.append(str(h))
	fired_tonight = {}
	var ft: Dictionary = d.get("fired_tonight", {})
	for k in ft:
		fired_tonight[int(k)] = int(ft[k])
	var pr: Dictionary = d.get("profile", {})
	for k in profile:
		profile[k] = clampf(float(pr.get(k, 0.0)), 0.0, 1.0)
	observed = d.get("observed", {})
	voice_memory.clear()
	for v in d.get("voice_memory", []):
		voice_memory.append(v)
