class_name SawAudio
extends Node3D
## Phase 14/15: the chainsaw's sound, emitted AT the tool through the
## SoundService (per-source occlusion, rooms, camera microphones). Layers
## follow the REAL engine state: a start pull once per start, idle /
## free-rev / loaded-cut loops crossfaded by chain speed and actual wood
## contact (throttle in the air is never the loaded sound), a spray of
## chips when the chain bites, and a wind-down on stop (a short cut-out
## when killed). Loops are explicit handles: stopping, stowing or freeing
## the tool ends them - never an orphan engine.
## While running it is also ordinary hearing evidence for the hunt
## (Game.hunt.noise at its real position; never the hidden player's spot).

var who := "player"
var _last := -1
var _loops := {}            # layer -> handle
var _evidence_t := 0.0
var volume_offset := 0.0
var levels := {"idle": -80.0, "rev": -80.0, "load": -80.0}
const EVENTS := {"idle": "tool.saw.idle", "rev": "tool.saw.rev", "load": "tool.saw.load"}


func _ensure_loops() -> void:
	for k in EVENTS:
		if not _loops.has(k) or not SoundService.is_playing(int(_loops[k])):
			_loops[k] = SoundService.loop(str(EVENTS[k]), self, {"gain": -80.0})


func _stop_loops(fade := 0.15) -> void:
	for k in _loops:
		SoundService.loop_stop(int(_loops[k]), fade)
	_loops.clear()
	for k in levels:
		levels[k] = -80.0


## Called every frame with the machine's state.
func update(m: SawMachine, delta: float) -> void:
	var st := m.state
	if st != _last:
		if st == SawMachine.S.STARTING:
			SoundService.play("tool.saw.start", self, {"db": volume_offset})
		elif st == SawMachine.S.STOPPING:
			SoundService.play("tool.saw.stop", self, {"db": volume_offset})
			_stop_loops(0.4)
		elif st == SawMachine.S.STOPPED and _last >= 0 and _last != SawMachine.S.STOPPING:
			SoundService.play("tool.saw.stop", self, {"db": volume_offset - 6.0})
			_stop_loops(0.08)
		elif st == SawMachine.S.CUTTING:
			SoundService.play("tool.saw.spray", self, {"db": volume_offset})
		_last = st
	var running := m.running()
	if not running:
		if not _loops.is_empty() and st != SawMachine.S.STOPPING:
			_stop_loops(0.08)
		return
	_ensure_loops()
	var cutting := st == SawMachine.S.CUTTING
	var free := clampf((m.rpm - SawMachine.IDLE_RPM) / (1.0 - SawMachine.IDLE_RPM), 0.0, 1.0)
	var want := {
		"idle": linear_to_db(clampf(1.0 - free * 1.3, 0.0, 1.0)),
		"rev": linear_to_db(clampf(free, 0.0, 1.0)) if not cutting else -80.0,
		"load": 0.0 if cutting else -80.0,
	}
	for k in _loops:
		levels[k] = move_toward(float(levels[k]), maxf(float(want[k]), -80.0), delta * 160.0)
		SoundService.loop_set(int(_loops[k]), float(levels[k]) + volume_offset, (0.9 + 0.2 * m.rpm) if k != "idle" else 1.0)
	_evidence_t -= delta
	if _evidence_t <= 0.0:
		_evidence_t = 1.0
		if Game.hunt:
			Game.hunt.noise(global_position, 85.0 if m.rpm > 0.5 else 40.0, "chainsaw", who)


func silence() -> void:
	_stop_loops(0.05)


func _exit_tree() -> void:
	_stop_loops(0.05)
