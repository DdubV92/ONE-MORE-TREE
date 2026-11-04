class_name SawMachine
extends RefCounted
## Phase 14: the chainsaw's bounded engine state machine (player and
## workers share it). Work is never applied here: `step()` only reports how
## many fixed cut ticks (ToolEffects.SAW_TICK seconds of valid loaded
## contact at cutting speed) completed during this step; the caller applies
## rate x SAW_TICK of work per tick to the target it validated THIS step.
##
##   STOPPED --start--> STARTING --(start_s)--> IDLE
##   IDLE --throttle--> REVVING (free-running, chain speeding up)
##   REVVING --contact & rpm >= SAW_MIN_RPM--> CUTTING (loaded)
##   CUTTING --contact lost--> REVVING ; --throttle released--> SPINDOWN
##   SPINDOWN --rpm at idle--> IDLE ; --throttle--> REVVING
##   any running state --stop--> STOPPING --(SAW_STOP_S)--> STOPPED
##   kill(): immediately STOPPED (vehicle, computer, hide, sleep, carry,
##           stow, load) - never left running.
## Frame-rate safety: each step's delta is clamped to MAX_STEP, so a long
## frame, a pause or a load can never release a burst of work; a partial
## tick is discarded whenever contact is lost.

enum S { STOPPED, STARTING, IDLE, REVVING, CUTTING, SPINDOWN, STOPPING }
const NAMES := ["stopped", "starting", "idle", "free-running", "cutting", "spinning down", "stopping"]
const MAX_STEP := 0.1
const IDLE_RPM := 0.25
const LOAD_RPM := 0.82

var state := S.STOPPED
var rpm := 0.0
var t := 0.0
var start_s := ToolEffects.SAW_START_S
var cut_time := 0.0
var ticks_total := 0
var starts := 0


func running() -> bool:
	return state in [S.IDLE, S.REVVING, S.CUTTING, S.SPINDOWN]


func state_name() -> String:
	return NAMES[state]


func start(seconds := -1.0) -> bool:
	if state != S.STOPPED:
		return false
	if seconds > 0.0:
		start_s = seconds
	state = S.STARTING
	t = 0.0
	starts += 1
	return true


func stop() -> void:
	if state in [S.STOPPED, S.STOPPING]:
		return
	state = S.STOPPING
	t = 0.0
	cut_time = 0.0


func kill() -> void:
	state = S.STOPPED
	rpm = 0.0
	t = 0.0
	cut_time = 0.0


## Advances the engine. Returns the number of completed cut ticks.
func step(delta: float, throttle: bool, contact: bool) -> int:
	var dt := clampf(delta, 0.0, MAX_STEP)
	var n := 0
	match state:
		S.STOPPED:
			rpm = 0.0
		S.STARTING:
			t += dt
			rpm = 0.08 + 0.17 * clampf(t / start_s, 0.0, 1.0)
			if t >= start_s:
				state = S.IDLE
				rpm = IDLE_RPM
		S.IDLE:
			rpm = move_toward(rpm, IDLE_RPM, dt)
			if throttle:
				state = S.REVVING
		S.REVVING:
			rpm = minf(1.0, rpm + dt * (1.0 - IDLE_RPM) / ToolEffects.SAW_SPINUP_S)
			if not throttle:
				state = S.SPINDOWN
			elif contact and rpm >= ToolEffects.SAW_MIN_RPM:
				state = S.CUTTING
		S.CUTTING:
			if not throttle:
				state = S.SPINDOWN
				cut_time = 0.0
			elif not contact:
				state = S.REVVING
				cut_time = 0.0
			else:
				rpm = move_toward(rpm, LOAD_RPM, dt * 1.5)
				cut_time += dt
				while cut_time >= ToolEffects.SAW_TICK - 1e-6:
					cut_time -= ToolEffects.SAW_TICK
					n += 1
		S.SPINDOWN:
			rpm = maxf(IDLE_RPM, rpm - dt * (1.0 - IDLE_RPM) / ToolEffects.SAW_SPINDOWN_S)
			if throttle:
				state = S.REVVING
			elif rpm <= IDLE_RPM + 0.001:
				state = S.IDLE
		S.STOPPING:
			t += dt
			rpm = maxf(0.0, rpm - dt * 0.5)
			if t >= ToolEffects.SAW_STOP_S:
				kill()
	ticks_total += n
	return n
