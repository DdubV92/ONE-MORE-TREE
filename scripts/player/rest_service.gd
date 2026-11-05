class_name RestService
extends Node
## Phase 16: the ONE authority on the boss's restedness (100 = well rested,
## 0 = exhausted). A provisional, tunable game model - not medical realism.
##
## Awake drain (simulation time; a true pause stops it, live computer/TV
## viewing does not):
##   workday (daylight + dusk): DAY_BASE 1.5/min + up to EFFORT 0.6/min
##     while exerting (chopping, carrying, sprinting) -> a normal 20-minute
##     workday costs ~30-40;
##   ordinary night (after workday second 1,200; the night clock is
##     bounded but awake time keeps counting): NIGHT 5/min instead.
## Sleep (the bed, once per day, settled in the same locked transition as
## wages): Q = max(0.25, 1 - 0.75 x late_minutes / 8)
##   recovery = 80 x Q ; ceiling = 100 - 40 x (1 - Q)
##   morning  = clamp(min(ceiling, bedtime rest + recovery), 0, 100)
## so an early night fully restores a normal day, one late night is
## recoverable in a night or two, and several compound.
## Effects (smooth from 70 down to 0, applied ONCE each through
## ToolEffects): walking x(1 - 0.15 p), cutting work per contact
## x(1 - 0.20 p) with p = (70 - rest) / 70. Never a hidden wage change,
## forced sleep, lost input or fatigue death; the camper stays safe.
## Hunt (days 31-35, continuous time): no bed-to-morning; resting while
## hidden or seated and still recovers 4/min up to 70 (time keeps running;
## no immunity, nothing skipped).

const VERSION := 1
const DAY_BASE := 1.5
const EFFORT := 0.6
const NIGHT := 5.0
const LATE_FULL_MIN := 8.0
const Q_FLOOR := 0.25
const RECOVERY := 80.0
const CEILING_LOSS := 40.0
const HUNT_REST := 4.0
const HUNT_CEILING := 70.0
const PENALTY_START := 70.0
const WALK_PENALTY := 0.15
const CUT_PENALTY := 0.20
const FEAR_WEIGHT := 0.25
const INTERRUPT_MAX := 15.0      # bounded cost of one system-imposed wake

signal band_changed(band: String)

var rest := 100.0
var late_s := 0.0             # awake seconds after night began (tonight)
var awake_s := 0.0            # simulation seconds awake since waking
var effort := 0.0             # smoothed 0..1
var settled_day := -1         # last day whose sleep recovery was applied
var resting := false          # hunt: currently resting (hidden/seated, still)
var history: Array = []       # [{day, bed, q, morning, late_min}]
var interruptions := {}       # day -> rest cost (Phase 19 hook, bounded)
var _last_hit := -999.0
var _band := ""
var _last_key := -1


func _ready() -> void:
	process_physics_priority = -5


static func band_of(r: float) -> String:
	if r >= 70.0:
		return "Well rested"
	if r >= 45.0:
		return "A little tired"
	if r >= 20.0:
		return "Tired"
	return "Exhausted"


static func penalty(r: float) -> float:
	return clampf((PENALTY_START - r) / PENALTY_START, 0.0, 1.0)


func walk_factor() -> float:
	return 1.0 - WALK_PENALTY * penalty(rest)


func cut_factor() -> float:
	return 1.0 - CUT_PENALTY * penalty(rest)


## Quantized key so tool effects are recomputed only when the factor moves.
func factor_key() -> int:
	return int(round(penalty(rest) * 200.0))


## Ordinary-encounter opportunity weight (1.0 .. 1.25) for the director,
## within its existing caps; never touches rare-startle cooldowns.
func fear_weight() -> float:
	var late := clampf(late_s / (LATE_FULL_MIN * 60.0), 0.0, 1.0)
	return 1.0 + FEAR_WEIGHT * maxf(penalty(rest + 25.0), late)


func note_effort_hit() -> void:
	_last_hit = Time.get_ticks_msec() / 1000.0


static func quality(late_min: float) -> float:
	return maxf(Q_FLOOR, 1.0 - (1.0 - Q_FLOOR) * clampf(late_min / LATE_FULL_MIN, 0.0, 1.0))


## The bed preview: what sleeping NOW would give (applies nothing).
func forecast(extra_min := 0.0) -> Dictionary:
	var late_min := late_s / 60.0 + extra_min
	var bed := clampf(rest - NIGHT * extra_min, 0.0, 100.0)
	var q := quality(late_min)
	var morning := clampf(minf(100.0 - CEILING_LOSS * (1.0 - q), bed + RECOVERY * q), 0.0, 100.0)
	var p := penalty(morning)
	return {"now": rest, "bed": bed, "q": q, "late_min": late_min, "morning": morning, "band": band_of(morning), "walk_pct": WALK_PENALTY * p * 100.0, "cut_pct": CUT_PENALTY * p * 100.0}


func describe_forecast() -> String:
	var f := forecast()
	var lines := PackedStringArray()
	lines.append("Rest now: %d / 100 (%s)" % [int(round(rest)), band_of(rest)])
	lines.append("Sleep now -> morning about %d (%s)%s" % [int(round(float(f.morning))), str(f.band), "" if float(f.walk_pct) < 0.5 else ": walking %d%% slower, cutting %d%% weaker" % [int(round(float(f.walk_pct))), int(round(float(f.cut_pct)))]])
	if float(f.late_min) > 0.05:
		var f2 := forecast(4.0)
		lines.append("Awake %.0f min past nightfall: sleep quality %d%%. Another 4 minutes up -> morning about %d." % [float(f.late_min), int(round(float(f.q) * 100.0)), int(round(float(f2.morning)))])
	else:
		lines.append("Going to bed before nightfall gives a full night's recovery.")
	lines.append("Morning only comes by sleeping in the camper bed.")
	return "\n".join(lines)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var cs: CampaignService = Game.campaign
	if cs == null or not cs.active:
		return
	var hunting := Game.hunt != null and Game.hunt.hunt_active()
	if not hunting and cs.contract.is_closed():
		return
	_update_effort(delta)
	var night := false
	var resting_now := false
	if hunting:
		night = Game.hunt.phase_name() == "night"
		resting_now = _hunt_resting()
	else:
		night = cs.clock.phase() == WorkdayClock.Phase.NIGHT
	step(delta, night, effort, hunting, resting_now)
	if night and not hunting:
		_remind()


## Pure drain/recovery step (used by the live tick and by tests).
## `contract_night`: the ordinary night (late awake time counts toward
## sleep quality); hunt nights drain the same but have no bedtime.
func step(dt: float, night: bool, effort01: float, hunting := false, hunt_resting := false) -> void:
	awake_s += dt
	resting = hunting and hunt_resting
	if resting:
		if rest < HUNT_CEILING:
			rest = minf(rest + HUNT_REST * dt / 60.0, HUNT_CEILING)
		_after_change()
		return
	if night:
		if not hunting:
			late_s += dt
		rest -= NIGHT * dt / 60.0
	else:
		rest -= (DAY_BASE + EFFORT * clampf(effort01, 0.0, 1.0)) * dt / 60.0
	rest = clampf(rest, 0.0, 100.0)
	_after_change()


func _after_change() -> void:
	var b := band_of(rest)
	if b != _band:
		_band = b
		band_changed.emit(b)
	var k := factor_key()
	if k != _last_key:
		_last_key = k
		var p := Game.player
		if p and p.get("axe"):
			p.axe.invalidate_kit()


func _update_effort(delta: float) -> void:
	var target := 0.0
	var p := Game.player as CharacterBody3D
	if p:
		var v := Vector2(p.velocity.x, p.velocity.z).length()
		if v > 0.5:
			target = 0.35
		if v > 5.0:
			target = 1.0
		if p.get("carry") and p.carry.is_carrying() and v > 0.5:
			target = 1.0
	if Time.get_ticks_msec() / 1000.0 - _last_hit < 1.6:
		target = 1.0
	effort = move_toward(effort, target, delta * 0.5)


## Gentle, optional reminders as tonight's recovery worsens: at most three
## a night (2, 5 and 8 minutes after nightfall), never a sting or a popup.
const REMIND_AT := [120.0, 300.0, 480.0]
var _reminded := -1


func _remind() -> void:
	var due := -1
	for i in REMIND_AT.size():
		if late_s >= float(REMIND_AT[i]):
			due = i
	if due <= _reminded:
		return
	_reminded = due
	if not bool(Settings.get_v("rest_reminders")) or Game.campaign == null:
		return
	var f := forecast()
	Game.campaign.notice.emit("Late night: sleep now and you'd wake at about %d rest (%s). Staying up keeps lowering tonight's recovery." % [int(round(float(f.morning))), str(f.band)], 7.0)


## Hunt rest: hidden in a real hide, or seated, and not moving/driving.
func _hunt_resting() -> bool:
	var p := Game.player as CharacterBody3D
	if p == null:
		return false
	if Game.hunt.in_vehicle(p):
		return false
	if Vector2(p.velocity.x, p.velocity.z).length() > 0.3:
		return false
	if p.get("at_desk") == true:
		return false              # browsing the computer is not rest
	return Game.hunt.is_hidden(p) or p.get("couch") != null


## Called once from the campaign's sleep transition for day `d`. Idempotent:
## a repeated call (reload, double input) changes nothing.
func on_sleep(d: int) -> Dictionary:
	if settled_day == d:
		return {}
	var f := forecast()
	var morning := float(f.morning)
	var cost := minf(float(interruptions.get(str(d), 0.0)), INTERRUPT_MAX)
	morning = clampf(morning - cost, 0.0, 100.0)
	history.append({"day": d, "bed": snappedf(rest, 0.1), "q": snappedf(float(f.q), 0.01), "morning": snappedf(morning, 0.1), "late_min": snappedf(float(f.late_min), 0.1)})
	if history.size() > 10:
		history.pop_front()
	rest = morning
	_reminded = -1
	late_s = 0.0
	awake_s = 0.0
	settled_day = d
	_after_change()
	return history[history.size() - 1]


## Phase 19 hook: a system-imposed wake on night `d` costs a bounded amount
## once (repeated reports of the same night do not stack past the cap).
func interrupt(d: int, cost: float) -> void:
	interruptions[str(d)] = minf(float(interruptions.get(str(d), 0.0)) + maxf(cost, 0.0), INTERRUPT_MAX)


func capture() -> Dictionary:
	return {"version": VERSION, "rest": rest, "late_s": late_s, "awake_s": awake_s, "settled_day": settled_day, "history": history.duplicate(true), "interruptions": interruptions.duplicate()}


## A save without rest data starts well rested (never a surprise wake at
## exhaustion); otherwise it restores exactly. Real-world offline time is
## never counted.
func restore(d: Dictionary) -> void:
	rest = clampf(float(d.get("rest", 100.0)), 0.0, 100.0)
	late_s = maxf(float(d.get("late_s", 0.0)), 0.0)
	awake_s = maxf(float(d.get("awake_s", 0.0)), 0.0)
	settled_day = int(d.get("settled_day", -1))
	history = (d.get("history", []) as Array).duplicate(true)
	interruptions = (d.get("interruptions", {}) as Dictionary).duplicate()
	_after_change()
