class_name CrewProgression
extends RefCounted
## Phase 16: persistent per-employee character and growth, kept apart from
## payroll (wages never change here) and from mood/fear (WorkerMind):
##
##  - profile: work ethic, reliability, chattiness, preferred work. Made
##    ONCE per employee id (deterministic seed), saved, never rerolled.
##  - career level 1-20 and four skills from the MeritLedger (useful work
##    only). Career level is a summary; it multiplies nothing.
##  - skill effects through ToolEffects (one capped `skill` factor):
##    cutting +2 %/level (max +20 %) on work per contact / saw rate;
##    handling -3 %/level pickup / set-down / loading overhead (max -30 %);
##    driving +1.5 %/level steady route speed for worker-driven trucks
##    (corner/route execution, never top speed); teamwork -4 %/level team
##    pairing wait. Combined skill on any one action <= MAX_SKILL.
##  - a time ledger per day: useful work / travel & handling / waiting on a
##    dependency / blocked route / no task / missing tool / yard full /
##    fear refusal / dusk return / discretionary pause - with real causes.
##  - recognition: praise for ONE specific contribution, once.
##  - context events for Phase 17 (who knows what).

const VERSION := 1
const MAX_LEVEL := 20
## Career curve: cumulative merit = CAREER_SCALE x (L-1)^1.8 (provisional,
## tuned against measured crew contribution; see PHASE16_NOTES).
const CAREER_SCALE := 400.0
const CAREER_EXP := 1.8
const SKILL_MAX := 10
const SKILL_SCALE := 380.0
const SKILL_EXP := 1.6
const CUT_PER_LEVEL := 0.02
const HANDLE_PER_LEVEL := 0.03
const DRIVE_PER_LEVEL := 0.015
const TEAM_PER_LEVEL := 0.04
const MAX_SKILL := 1.35
const CATEGORIES := ["useful", "travel", "waiting", "blocked", "no_task", "missing_tool", "yard_full", "fear", "dusk", "pause", "break"]
const CATEGORY_WORDS := {"useful": "useful work", "travel": "walking & handling", "waiting": "waiting on others", "blocked": "blocked route", "no_task": "no work available", "missing_tool": "missing a tool", "yard_full": "yard full", "fear": "refusing risky work", "dusk": "heading home", "pause": "short breaks", "break": "midday break (Phase 19)"}
const CONTEXT_CAP := 200
const PRAISE_TRUST := 0.03

signal advanced(eid: String, what: String, level: int)

var merit: MeritLedger
var profiles := {}        # eid -> profile dict
var levels := {}          # eid -> {"career": L, "cutting": l, ...} (last announced)
var time := {}            # "day" -> {eid: {category: seconds}}
var jobs := {}            # eid -> {"started", "finished", "dropped": {cause: n}}
var praised := {}         # contribution key -> day praised
var recognition: Array = []   # [{eid, day, what, kind}]
var pending: Array = []       # recognition opportunities [{eid, day, what, key}]
var context: Array = []       # Phase 17 hooks [{kind, who, about, knowers, day}]
var morale := {}          # eid -> 0..1 (modest; praise/waiting frustration)
var _pause_pending := {}  # eid -> seconds of pause awaiting classification


func _init(m: MeritLedger) -> void:
	merit = m
	merit.awarded.connect(_on_awarded)


# --------------------------------------------------------------- profiles

## Creates the profile once (deterministic per id, nudged by traits so
## the description fits them). Never rerolled on load or UI refresh.
func ensure_profile(eid: String, traits: Array) -> Dictionary:
	if profiles.has(eid):
		return profiles[eid]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("profile:" + eid)
	var ethic := clampf(rng.randf_range(0.55, 0.9) + (0.05 if "hard_working" in traits else 0.0), 0.45, 0.95)
	var rel := clampf(rng.randf_range(0.6, 0.9) + (0.05 if "reliable_driver" in traits else 0.0) + (0.03 if "level_headed" in traits else 0.0), 0.5, 0.95)
	var chat := clampf(rng.randf_range(0.25, 0.7) + (0.25 if "sociable" in traits else 0.0) - (0.1 if "timid" in traits else 0.0), 0.1, 0.95)
	var pref: String = ["felling", "processing", "hauling", "yard"][rng.randi() % 4]
	if "stronger" in traits:
		pref = "hauling"
	elif "hard_working" in traits:
		pref = "felling"
	elif "reliable_driver" in traits:
		pref = "driving"
	var p := {"version": VERSION, "ethic": snappedf(ethic, 0.01), "reliability": snappedf(rel, 0.01), "chattiness": snappedf(chat, 0.01), "prefers": pref}
	profiles[eid] = p
	levels[eid] = {"career": 1, "cutting": 0, "handling": 0, "driving": 0, "teamwork": 0}
	morale[eid] = 0.6
	return p


static func ethic_word(v: float) -> String:
	return "tireless" if v >= 0.85 else ("steady" if v >= 0.7 else ("easy-going" if v >= 0.58 else "unhurried"))


static func reliability_word(v: float) -> String:
	return "dependable" if v >= 0.82 else ("mostly dependable" if v >= 0.7 else "needs check-ins")


## Short break after finishing a job: 0.5 s (tireless) to 4 s (unhurried).
## Only ever counted as "pause" if there WAS work to go back to.
func pause_after_job(eid: String) -> float:
	var e := float((profiles.get(eid, {}) as Dictionary).get("ethic", 0.7))
	return lerpf(4.0, 0.5, clampf((e - 0.45) / 0.5, 0.0, 1.0))


# ----------------------------------------------------------- levels/skills

static func career_threshold(level: int) -> int:
	return int(round(CAREER_SCALE * pow(maxf(level - 1, 0), CAREER_EXP)))


static func skill_threshold(level: int) -> int:
	return int(round(SKILL_SCALE * pow(maxf(level, 0), SKILL_EXP)))


static func level_for(points: float) -> int:
	var l := 1
	while l < MAX_LEVEL and points >= career_threshold(l + 1):
		l += 1
	return l


static func skill_level_for(points: float) -> int:
	var l := 0
	while l < SKILL_MAX and points >= skill_threshold(l + 1):
		l += 1
	return l


func career(eid: String) -> int:
	return level_for(merit.total(eid))


func skill(eid: String, s: String) -> int:
	return skill_level_for(merit.skill_points(eid, s))


## The single cutting-skill factor ToolEffects receives (capped).
func cut_factor(eid: String) -> float:
	return minf(1.0 + CUT_PER_LEVEL * skill(eid, "cutting"), MAX_SKILL)


## Fraction of pickup / set-down / loading overhead time (0.7 .. 1.0).
func handling_time(eid: String) -> float:
	return clampf(1.0 - HANDLE_PER_LEVEL * skill(eid, "handling"), 1.0 / MAX_SKILL, 1.0)


func drive_factor(eid: String) -> float:
	return minf(1.0 + DRIVE_PER_LEVEL * skill(eid, "driving"), MAX_SKILL)


func team_wait(eid: String) -> float:
	return clampf(1.0 - TEAM_PER_LEVEL * skill(eid, "teamwork"), 1.0 / MAX_SKILL, 1.0)


func next_career(eid: String) -> Dictionary:
	var l := career(eid)
	var have := merit.total(eid)
	if l >= MAX_LEVEL:
		return {"level": l, "next": -1, "have": have}
	return {"level": l, "next": career_threshold(l + 1), "have": have}


func _on_awarded(actor: String, _stage: String, _amount: float, source: String) -> void:
	if actor == MeritLedger.BOSS or not levels.has(actor):
		return
	var lv: Dictionary = levels[actor]
	var c := career(actor)
	if c > int(lv.career):
		lv.career = c
		_opportunity(actor, "reached career level %d" % c, "level:%s:%d" % [actor, c])
		advanced.emit(actor, "career", c)
		add_context("improved", actor, "career level %d" % c, [actor])
	for s in MeritLedger.SKILLS:
		var l := skill(actor, s)
		if l > int(lv.get(s, 0)):
			lv[s] = l
			_opportunity(actor, "%s skill %d" % [s, l], "skill:%s:%s:%d" % [actor, s, l])
			advanced.emit(actor, s, l)
	# A finished tree stage is a concrete thing the boss can recognise.
	if source.begins_with("fell:") and float(merit.committed.get(source, 0.0)) >= 1.0:
		_opportunity(actor, "brought down a tree", "felled:" + source)


func _opportunity(eid: String, what: String, key: String) -> void:
	for p in pending:
		if str(p.key) == key:
			return
	pending.append({"eid": eid, "day": merit.day, "what": what, "key": key})
	if pending.size() > 40:
		pending.pop_front()


# ------------------------------------------------------------ recognition

## Praise for one specific contribution. Repeating it (same key) does
## nothing; it never pays, never changes wages and never cures fear.
func praise(eid: String, key: String, mind: WorkerMind) -> Dictionary:
	if praised.has(key):
		return {"ok": false, "reason": "You already thanked them for that."}
	var found := {}
	for p in pending:
		if str(p.key) == key and str(p.eid) == eid:
			found = p
	if found.is_empty():
		return {"ok": false, "reason": "Nothing specific to recognise."}
	praised[key] = merit.day
	pending.erase(found)
	recognition.append({"eid": eid, "day": merit.day, "what": str(found.what), "kind": "praise"})
	if recognition.size() > 60:
		recognition.pop_front()
	if mind:
		mind.trust = clampf(mind.trust + PRAISE_TRUST, 0.0, 0.95)
	morale[eid] = clampf(float(morale.get(eid, 0.6)) + 0.05, 0.0, 1.0)
	add_context("praised", eid, str(found.what), [eid])
	return {"ok": true, "what": str(found.what)}


func opportunities(eid: String) -> Array:
	return pending.filter(func(p: Dictionary) -> bool: return str(p.eid) == eid)


# ------------------------------------------------------------ time ledger

func add_time(eid: String, category: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	if category == "pause":
		_pause_pending[eid] = float(_pause_pending.get(eid, 0.0)) + seconds
		return
	_add(eid, category, seconds)


func _add(eid: String, category: String, seconds: float) -> void:
	var dk := str(merit.day)
	if not time.has(dk):
		time[dk] = {}
		var ks := time.keys()
		ks.sort_custom(func(a, b) -> bool: return int(a) < int(b))
		while ks.size() > 4:
			time.erase(ks.pop_front())
	if not time[dk].has(eid):
		time[dk][eid] = {}
	time[dk][eid][category] = float(time[dk][eid].get(category, 0.0)) + seconds


## Pending break time is "pause" only if the worker then found work; with
## nothing to do it was really "no task" (or the actual cause).
func settle_pause(eid: String, found_work: bool, cause := "no_task") -> void:
	var s := float(_pause_pending.get(eid, 0.0))
	if s <= 0.0:
		return
	_pause_pending.erase(eid)
	_add(eid, "pause" if found_work else cause, s)


func day_time(eid: String, d: int) -> Dictionary:
	return ((time.get(str(d), {}) as Dictionary).get(eid, {}) as Dictionary).duplicate()


func on_job_started(eid: String, _kind: String) -> void:
	if not jobs.has(eid):
		jobs[eid] = {"started": 0, "finished": 0, "dropped": {}}
	jobs[eid].started = int(jobs[eid].started) + 1


func on_job_finished(eid: String, _kind: String) -> void:
	if not jobs.has(eid):
		jobs[eid] = {"started": 0, "finished": 0, "dropped": {}}
	jobs[eid].finished = int(jobs[eid].finished) + 1


func on_job_dropped(eid: String, cause: String) -> void:
	if not jobs.has(eid):
		jobs[eid] = {"started": 0, "finished": 0, "dropped": {}}
	jobs[eid].dropped[cause] = int(jobs[eid].dropped.get(cause, 0)) + 1


# ------------------------------------------------------- Phase 17 context

## A structured fact for later conversation: `knowers` are the people who
## actually saw or were told (never the whole island).
func add_context(kind: String, who: String, about: String, knowers: Array) -> void:
	context.append({"kind": kind, "who": who, "about": about, "knowers": knowers.duplicate(), "day": merit.day})
	if context.size() > CONTEXT_CAP:
		context.pop_front()


func capture() -> Dictionary:
	return {"version": VERSION, "profiles": profiles.duplicate(true), "levels": levels.duplicate(true), "time": time.duplicate(true), "jobs": jobs.duplicate(true), "praised": praised.duplicate(), "recognition": recognition.duplicate(true), "pending": pending.duplicate(true), "context": context.duplicate(true), "morale": morale.duplicate()}


func restore(d: Dictionary) -> void:
	profiles = (d.get("profiles", {}) as Dictionary).duplicate(true)
	levels = (d.get("levels", {}) as Dictionary).duplicate(true)
	time = (d.get("time", {}) as Dictionary).duplicate(true)
	jobs = (d.get("jobs", {}) as Dictionary).duplicate(true)
	praised = (d.get("praised", {}) as Dictionary).duplicate()
	recognition = (d.get("recognition", []) as Array).duplicate(true)
	pending = (d.get("pending", []) as Array).duplicate(true)
	context = (d.get("context", []) as Array).duplicate(true)
	morale = (d.get("morale", {}) as Dictionary).duplicate()
	_pause_pending.clear()
	# JSON turns integers into floats: normalise the integer fields.
	for eid in profiles:
		profiles[eid]["version"] = int(profiles[eid].get("version", VERSION))
	for eid in levels:
		for k in levels[eid]:
			levels[eid][k] = int(levels[eid][k])
