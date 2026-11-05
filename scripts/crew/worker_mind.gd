class_name WorkerMind
extends RefCounted
## A crew member's inner state (Phase 4): traits, fear, belief, trust and a
## small memory of what THEY perceived. Belief ("something is out there"),
## fear, trust in the boss and willingness are separate numbers; the UI
## shows words, never a truth detector.
##
## Fear states with hysteresis (enter / leave thresholds):
##   COMFORTABLE < UNEASY (0.25/0.17) < DISTRESSED (0.5/0.4)
##   < REFUSING_RISK (0.68/0.56) < DEPARTURE_WARNING (0.84/0.72)
## A worker in DEPARTURE_WARNING who stays there through the next end of day
## (or is hit by a severe event while warning) decides to QUIT. Warnings come
## first, every time; departure reasons are recorded.

enum Fear { COMFORTABLE, UNEASY, DISTRESSED, REFUSING_RISK, DEPARTURE_WARNING, QUITTING }

const ENTER := [0.0, 0.25, 0.5, 0.68, 0.84]
const LEAVE := [0.0, 0.17, 0.4, 0.56, 0.72]
const MEMORY_CAP := 12
const REASSURE_COOLDOWN := 90.0
const SAME_KIND_WINDOW := 600.0       # repeats within 10 min count less

const TRAITS := ["timid", "hard_working", "stronger", "level_headed", "sociable", "skeptical", "observant", "reliable_driver"]
## Incompatible pairs (a person is not both).
const CLASH := [["timid", "level_headed"]]

var traits: Array = []
var fear := 0.0
var belief := 0.2
var trust := 0.6
var state := Fear.COMFORTABLE
var memories: Array[Dictionary] = []
var _last_reassure := -9999.0
var _reassure_count := 0
var _recent := {}                     # kind -> [last time, count]
var warning_since_day := -1
var quit_reason := ""


static func with_traits(t: Array) -> WorkerMind:
	var m := WorkerMind.new()
	m.traits = t.duplicate()
	m.belief = 0.05 if m.has("skeptical") else 0.2
	return m


func has(t: String) -> bool:
	return t in traits


## How strongly events hit this person.
func sensitivity() -> float:
	var k := 1.0
	if has("timid"):
		k *= 1.6
	if has("level_headed"):
		k *= 0.6
	return k


## Extra minutes of safety margin wanted before night (seconds).
func return_margin() -> float:
	var m := 45.0
	if has("timid"):
		m += 60.0
	if state >= Fear.UNEASY:
		m += 20.0 * float(state)
	return m


# ------------------------------------------------------------- perception

## A stimulus this person actually perceived (the crew service already did
## the distance/occlusion/facing checks). Returns the stored memory or {}.
## stim: {id, kind, modality ("sight"/"sound"/"voice"), severity 0..1,
##        pos, ambiguous (bool), imitates (employee id or "")}
func perceive(stim: Dictionary, now: float, info: Dictionary) -> Dictionary:
	for m in memories:
		if str(m.id) == str(stim.id):
			return {}                 # one memory per real event
	var kind := str(stim.get("kind", "?"))
	var sev := float(stim.get("severity", 0.1))
	var conf := float(info.get("confidence", 0.6))
	# Ordinary work/fire/weather sounds never become supernatural evidence.
	if bool(stim.get("ordinary", false)):
		return {}
	# A copied voice of someone standing right beside you is chilling.
	if str(stim.get("modality", "")) == "voice" and bool(info.get("imitated_is_present", false)):
		sev = maxf(sev, 0.55)
		conf = maxf(conf, 0.85)
	# Repeats of the same kind in a short window hit less (no farming).
	var rec: Array = _recent.get(kind, [-9999.0, 0])
	var reps := int(rec[1]) if now - float(rec[0]) < SAME_KIND_WINDOW else 0
	_recent[kind] = [now, reps + 1]
	var dim := pow(0.55, reps)
	var gain := sev * conf * sensitivity() * dim
	if bool(info.get("asleep", false)):
		gain *= 0.6
	fear = clampf(fear + gain, 0.0, 1.0)
	# Belief: firsthand sight moves it most; ambiguous sounds barely do.
	var b_gain := 0.0
	if str(stim.get("modality", "")) == "sight":
		b_gain = 0.35 * conf
	elif str(stim.get("modality", "")) == "voice":
		b_gain = 0.25 * conf
	elif not bool(stim.get("ambiguous", true)):
		b_gain = 0.12 * conf
	else:
		b_gain = 0.03 * conf
	if has("skeptical"):
		b_gain *= 0.7
	belief = clampf(belief + b_gain, 0.0, 1.0)
	var mem := {"id": stim.id, "kind": kind, "modality": stim.get("modality", "sound"), "pos": [snappedf((stim.pos as Vector3).x, 0.5), snappedf((stim.pos as Vector3).z, 0.5)], "time": now, "confidence": snappedf(conf, 0.01), "significance": snappedf(gain, 0.01), "firsthand": true, "status": "confirmed" if conf >= 0.7 and not bool(stim.get("ambiguous", true)) else "uncertain", "imitated_name": str(stim.get("imitated_name", ""))}
	_remember(mem)
	_update_state(now)
	return mem


## The boss says something happened (no firsthand evidence for this worker).
func hear_boss_report(now: float, corroborated: bool) -> String:
	var g := 0.03 if has("skeptical") else 0.08
	if corroborated:
		g += 0.1
	belief = clampf(belief + g * (0.5 + trust), 0.0, 1.0)
	fear = clampf(fear + 0.03 * sensitivity(), 0.0, 1.0)
	_remember({"id": "boss_report_%d" % int(now), "kind": "boss_report", "modality": "rumor", "pos": [], "time": now, "confidence": 0.3, "significance": 0.03, "firsthand": false, "status": "rumor"})
	_update_state(now)
	return "corroborated" if corroborated else "rumor"


## A coworker told them about something they witnessed.
func hear_coworker(now: float, mem: Dictionary, teller := "") -> void:
	belief = clampf(belief + (0.06 if has("skeptical") else 0.1) * float(mem.get("confidence", 0.5)), 0.0, 1.0)
	fear = clampf(fear + 0.04 * sensitivity(), 0.0, 1.0)
	# Phase 17: remember the CLAIM (second-hand: source, lower confidence),
	# once per original event - a told memory is never firsthand evidence.
	var tid := "told:" + str(mem.get("id", ""))
	for m in memories:
		if str(m.id) == tid or str(m.id) == str(mem.get("id", "")):
			_update_state(now)
			return
	_remember({"id": tid, "kind": str(mem.get("kind", "?")), "modality": "told", "pos": mem.get("pos", []), "time": now, "confidence": snappedf(float(mem.get("confidence", 0.5)) * 0.5, 0.01), "significance": 0.02, "firsthand": false, "status": "rumor", "source": teller})
	_update_state(now)


## Phase 17: a second-hand claim this worker was told (no firsthand one).
func told_count() -> int:
	return memories.filter(func(m: Dictionary) -> bool: return str(m.get("modality", "")) == "told").size()


func _remember(m: Dictionary) -> void:
	memories.append(m)
	memories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.significance) > float(b.significance) or (float(a.significance) == float(b.significance) and float(a.time) > float(b.time)))
	while memories.size() > MEMORY_CAP:
		memories.pop_back()


func firsthand_count() -> int:
	return memories.filter(func(m: Dictionary) -> bool: return bool(m.firsthand) and str(m.kind) != "boss_report").size()


func strongest_memory() -> Dictionary:
	for m in memories:
		if bool(m.firsthand):
			return m
	return {}


# ------------------------------------------------------------ the boss

## Reassurance: helps with credible context, diminishing, on a cooldown.
## Returns "helped" / "cooldown" / "hollow".
func reassure(now: float, credible: bool) -> String:
	if now - _last_reassure < REASSURE_COOLDOWN:
		return "cooldown"
	_last_reassure = now
	_reassure_count += 1
	var k := pow(0.6, maxf(_reassure_count - 1, 0)) * (1.0 if credible else 0.35)
	if has("sociable"):
		k *= 1.2
	# Dismissing someone who saw it with their own eyes costs trust.
	if not credible and firsthand_count() > 0:
		trust = clampf(trust - 0.06, 0.0, 1.0)
		k *= 0.5
	fear = clampf(fear - 0.14 * k, 0.0, 1.0)
	_update_state(now)
	return "helped" if k > 0.3 else "hollow"


func dismissed(now: float) -> void:
	trust = clampf(trust - (0.08 if firsthand_count() > 0 else 0.03), 0.0, 1.0)
	_update_state(now)


# -------------------------------------------------------------- over time

## Slow recovery: calm daylight work, company, a safe interior.
## ctx: {daylight, near_colleagues, safe_inside, isolated_at_dusk, arrears}
func tick(dt: float, now: float, ctx: Dictionary) -> void:
	var rec := 0.0
	if bool(ctx.get("safe_inside", false)):
		rec += 0.0007
	if bool(ctx.get("daylight", false)):
		rec += 0.0005
	if int(ctx.get("near_colleagues", 0)) > 0:
		rec += 0.0003 * (1.6 if has("sociable") else 1.0)
	if has("level_headed"):
		rec *= 1.5
	var up := 0.0
	if bool(ctx.get("isolated_at_dusk", false)):
		up += 0.0004 * sensitivity()
	fear = clampf(fear - rec * dt + up * dt, 0.0, 1.0)
	# Wages owed lower trust, not fear (kept separate on purpose).
	if bool(ctx.get("arrears", false)):
		trust = clampf(trust - 0.00002 * dt, 0.0, 1.0)
	_update_state(now)


func _update_state(_now: float) -> void:
	if state == Fear.QUITTING:
		return
	var s := int(state)
	while s < 4 and fear >= ENTER[s + 1]:
		s += 1
	while s > 0 and fear < LEAVE[s]:
		s -= 1
	state = s


## Called at each end of day: a warning that persisted becomes a decision.
func end_of_day(day: int) -> bool:
	if state == Fear.DEPARTURE_WARNING:
		if warning_since_day < 0:
			warning_since_day = day
		elif day > warning_since_day:
			state = Fear.QUITTING
			quit_reason = "fear: kept seeing and hearing things and would not stay another night"
			return true
	else:
		warning_since_day = -1
	return false


## A severe event while already warning accelerates departure.
func severe_while_warning(sev: float) -> bool:
	if state == Fear.DEPARTURE_WARNING and sev >= 0.6:
		state = Fear.QUITTING
		quit_reason = "fear: a severe experience after warning the boss"
		return true
	return false


func refuses_risk() -> bool:
	return state >= Fear.REFUSING_RISK


func state_word() -> String:
	return ["calm", "uneasy", "shaken", "refusing risky work", "talking about leaving", "quitting"][int(state)]


func belief_word() -> String:
	if belief < 0.15:
		return "doesn't believe in any of it"
	if belief < 0.4:
		return "not sure what to believe"
	if belief < 0.7:
		return "thinks something is out there"
	return "is convinced something is out there"


func capture() -> Dictionary:
	return {"traits": traits, "fear": snappedf(fear, 0.0001), "belief": snappedf(belief, 0.0001), "trust": snappedf(trust, 0.0001), "state": state, "memories": memories.duplicate(true), "last_reassure": _last_reassure, "reassure_count": _reassure_count, "recent": _recent.duplicate(true), "warning_since_day": warning_since_day, "quit_reason": quit_reason}


static func from_dict(d: Dictionary) -> WorkerMind:
	var m := WorkerMind.with_traits(d.get("traits", []))
	m.fear = clampf(float(d.get("fear", 0.0)), 0.0, 1.0)
	m.belief = clampf(float(d.get("belief", m.belief)), 0.0, 1.0)
	m.trust = clampf(float(d.get("trust", 0.6)), 0.0, 1.0)
	m.state = clampi(int(d.get("state", 0)), 0, 5)
	for x in d.get("memories", []):
		m.memories.append(x)
	m._last_reassure = float(d.get("last_reassure", -9999.0))
	m._reassure_count = int(d.get("reassure_count", 0))
	m._recent = (d.get("recent", {}) as Dictionary).duplicate(true)
	m.warning_since_day = int(d.get("warning_since_day", -1))
	m.quit_reason = str(d.get("quit_reason", ""))
	return m
