class_name WorkdayClock
extends Node
## The ONE authoritative campaign clock (Phase 3). A monotonic simulation
## counter `t` (seconds into the workday) drives day index, phase, lighting,
## HUD countdown, warnings, scheduled hooks, wage-shift boundaries and the
## contract deadline. Nothing else keeps its own campaign timer.
##
##   0 ........ 1200 ........ 1500 -> night (bounded; t stays at 1500)
##   daylight      dusk          night: only sleep starts the next day
## (Phase 22, owner request: daylight 15 -> 20 minutes; dusk stays 5. Saves
## from before keep night as night: CampaignService.restore.)
##
## Advances in _physics_process (fixed step) so it is frame-rate independent;
## pausing the tree stops it (and burning, and everything else). Night
## exposure accumulates separately for later horror phases.

enum Phase { DAYLIGHT, DUSK, NIGHT }

const DAYLIGHT_SECONDS := 1200.0
const DUSK_SECONDS := 300.0
const NIGHT_AT := 1500.0
## The pre-Phase-22 nightfall (saves without "len" were made on that day).
const LEGACY_NIGHT_AT := 1200.0
const CONTRACT_DAYS := 30
## Warnings: main return warning at dusk start, a reminder half-way through
## dusk, a final warning one minute before night.
const WARNINGS := [[DAYLIGHT_SECONDS, "dusk"], [DAYLIGHT_SECONDS + DUSK_SECONDS * 0.5, "dusk_reminder"], [NIGHT_AT - 60.0, "dusk_final"]]
## Lighting hour keyframes for the workday (lighting presets blend by hour).
const HOUR_DAY_START := 6.6
const HOUR_DUSK_START := 18.1
const HOUR_NIGHT := 21.2

signal phase_changed(phase: int)
signal warning(kind: String, seconds_to_night: float)
signal night_started(day: int)
signal day_started(day: int)
signal deadline_reached()          # end of day 30's dusk (t = NIGHT_AT)
signal scheduled(tag: String)

var day := 1
var t := 0.0
var night_exposure := 0.0          # awake seconds during night (later horror)
var running := false               # true only in a timed campaign / test route
var deadline_enabled := true       # false for a labeled legacy continuation
var speed := 1.0                   # development preview acceleration only
var _phase := Phase.DAYLIGHT
var _fired := {}                   # warning/schedule tags fired today
var _schedule: Array = []          # [t, tag] hooks for the current day
var _deadline_fired := false


func _ready() -> void:
	process_physics_priority = -10     # before gameplay in each step


func phase() -> int:
	return _phase


static func phase_at(time: float) -> int:
	if time < DAYLIGHT_SECONDS:
		return Phase.DAYLIGHT
	if time < NIGHT_AT:
		return Phase.DUSK
	return Phase.NIGHT


func time_until_dusk() -> float:
	return maxf(DAYLIGHT_SECONDS - t, 0.0)


## Seconds left before night (workers later compare this with their
## measured route time and leave early when needed).
func time_until_night() -> float:
	return maxf(NIGHT_AT - t, 0.0)


func is_final_day() -> bool:
	return day >= CONTRACT_DAYS


func days_remaining() -> int:
	return maxi(CONTRACT_DAYS - day, 0)


## Hook for later phases: emits `scheduled(tag)` once when the day reaches
## `at` seconds (re-armed by the caller each morning).
func schedule(at: float, tag: String) -> void:
	_schedule.append([at, tag])


func lighting_hour() -> float:
	if t < DAYLIGHT_SECONDS:
		return lerpf(HOUR_DAY_START, HOUR_DUSK_START, t / DAYLIGHT_SECONDS)
	if t < NIGHT_AT:
		return lerpf(HOUR_DUSK_START, HOUR_NIGHT, (t - DAYLIGHT_SECONDS) / DUSK_SECONDS)
	# Night deepens slowly while awake, bounded (never reaches morning).
	return minf(HOUR_NIGHT + night_exposure / 600.0, 23.6)


func _physics_process(delta: float) -> void:
	if running:
		advance(delta * speed)


## Advances simulation time. Boundary events fire exactly once each, in
## order, however large the step.
func advance(dt: float) -> void:
	if dt <= 0.0:
		return
	var before := t
	t = minf(t + dt, NIGHT_AT)
	if t >= NIGHT_AT:
		night_exposure += maxf(before + dt - NIGHT_AT, 0.0)
	for w in WARNINGS:
		var at: float = w[0]
		var tag: String = w[1]
		if before < at and t >= at and not _fired.has(tag):
			_fired[tag] = true
			warning.emit(tag, time_until_night())
	for s in _schedule:
		if before < float(s[0]) and t >= float(s[0]) and not _fired.has("s:" + str(s[1])):
			_fired["s:" + str(s[1])] = true
			scheduled.emit(str(s[1]))
	var ph := phase_at(t)
	if ph != _phase:
		_phase = ph
		phase_changed.emit(ph)
		if ph == Phase.NIGHT:
			night_started.emit(day)
	if t >= NIGHT_AT and day >= CONTRACT_DAYS and deadline_enabled and not _deadline_fired:
		_deadline_fired = true
		deadline_reached.emit()


## Only the sleep/settlement transition calls this.
func start_next_day() -> void:
	day += 1
	t = 0.0
	night_exposure = 0.0
	_phase = Phase.DAYLIGHT
	_fired.clear()
	_schedule.clear()
	day_started.emit(day)
	phase_changed.emit(_phase)


func capture() -> Dictionary:
	return {"day": day, "t": t, "len": NIGHT_AT, "night_exposure": night_exposure, "running": running, "deadline_enabled": deadline_enabled, "fired": _fired.keys(), "deadline_fired": _deadline_fired}


## Phase 22: a clock saved on the shorter day (no "len") that was at night
## stays night; earlier times keep their seconds (more daylight left).
static func migrate_saved(d: Dictionary) -> Dictionary:
	var cl := d.duplicate()
	if not cl.has("len") and float(cl.get("t", 0.0)) >= LEGACY_NIGHT_AT - 0.01:
		cl["t"] = NIGHT_AT
	return cl


func restore(d: Dictionary) -> void:
	day = clampi(int(d.get("day", 1)), 1, 999)
	t = clampf(float(d.get("t", 0.0)), 0.0, NIGHT_AT)
	night_exposure = maxf(float(d.get("night_exposure", 0.0)), 0.0)
	running = bool(d.get("running", true))
	deadline_enabled = bool(d.get("deadline_enabled", true))
	_fired.clear()
	for k in d.get("fired", []):
		_fired[str(k)] = true
	_deadline_fired = bool(d.get("deadline_fired", false))
	_phase = phase_at(t)
