class_name SawAudio
extends Node3D
## Phase 14: the chainsaw's sound, emitted AT the tool (3D players on the
## Work bus, so distance, direction and the existing interior routing
## apply - a saw behind the cabin is not in your head). Layers crossfade
## from the real engine state: start pull, idle, free-rev, loaded cut, stop.
## While running it also announces itself to the camera microphones
## (SoundEvents) and, during the hunt only, to the Foreman as ordinary
## hearing evidence at its real position (Game.hunt.noise) - never as
## knowledge of where a concealed player is.

const LAYERS := {"idle": "saw_idle", "rev": "saw_rev", "load": "saw_load"}
var who := "player"
var players := {}
var _oneshot: AudioStreamPlayer3D
var _last := -1
var _evidence_t := 0.0
var _mic_t := 0.0
var volume_offset := 0.0
var levels := {"idle": -80.0, "rev": -80.0, "load": -80.0}


func _ready() -> void:
	for k in LAYERS:
		var p := AudioStreamPlayer3D.new()
		p.name = "Saw_" + k
		p.stream = load("res://audio/generated/%s.wav" % LAYERS[k])
		p.bus = "Work"
		p.unit_size = 9.0
		p.max_distance = 140.0
		p.volume_db = -80.0
		add_child(p)
		players[k] = p
	_oneshot = AudioStreamPlayer3D.new()
	_oneshot.bus = "Work"
	_oneshot.unit_size = 9.0
	_oneshot.max_distance = 120.0
	add_child(_oneshot)


func _oneshot_play(n: String, db: float) -> void:
	_oneshot.stream = load("res://audio/generated/%s.wav" % n)
	_oneshot.volume_db = db + volume_offset
	_oneshot.play()


## Called every frame with the machine's state.
func update(m: SawMachine, delta: float) -> void:
	var st := m.state
	if st != _last:
		if st == SawMachine.S.STARTING:
			_oneshot_play("saw_start", -2.0)
		elif st == SawMachine.S.STOPPING:
			_oneshot_play("saw_stop", -4.0)
		elif st == SawMachine.S.STOPPED and _last != SawMachine.S.STOPPING and _last >= 0:
			_oneshot_play("saw_stop", -8.0)     # killed: a short cut-out
		_last = st
	var running := m.running()
	var cutting := st == SawMachine.S.CUTTING
	var free := clampf((m.rpm - SawMachine.IDLE_RPM) / (1.0 - SawMachine.IDLE_RPM), 0.0, 1.0)
	var want := {
		"idle": linear_to_db(clampf(1.0 - free * 1.3, 0.0, 1.0)) - 4.0 if running else -80.0,
		"rev": linear_to_db(clampf(free, 0.0, 1.0)) - 1.0 if running and not cutting else -80.0,
		"load": -1.0 if cutting else -80.0,
	}
	for k in players:
		var p: AudioStreamPlayer3D = players[k]
		var target: float = maxf(float(want[k]), -80.0) + volume_offset
		levels[k] = move_toward(float(levels[k]), target, delta * 160.0)
		p.volume_db = levels[k]
		if levels[k] > -70.0 and not p.playing:
			p.play(randf() * 1.5)
		elif levels[k] <= -79.0 and p.playing:
			p.stop()
		p.pitch_scale = (0.9 + 0.2 * m.rpm) if k != "idle" else 1.0
	if not running:
		return
	var loud := m.rpm > 0.5
	_evidence_t -= delta
	if _evidence_t <= 0.0:
		_evidence_t = 1.0
		if Game.hunt:
			Game.hunt.noise(global_position, 85.0 if loud else 40.0, "chainsaw", who)
	_mic_t -= delta
	if _mic_t <= 0.0:
		_mic_t = 2.5
		var key := "load" if cutting else ("rev" if loud else "idle")
		SoundEvents.emit((players[key] as AudioStreamPlayer3D).stream, global_position, -2.0, "work", "a chainsaw")


func silence() -> void:
	for k in players:
		(players[k] as AudioStreamPlayer3D).stop()
		levels[k] = -80.0
