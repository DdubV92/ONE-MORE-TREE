class_name TruckAudio
extends AudioStreamPlayer3D
## Original procedural engine and tyre sound (no recordings): a few engine
## harmonics whose pitch follows road speed and throttle, plus filtered
## gravel noise that rises with speed. Generated on the fly
## (AudioStreamGenerator), positional, on the Work bus.

const RATE := 22050.0
var _gen: AudioStreamGeneratorPlayback
var _phase := 0.0
var _rpm := 0.0
var _load := 0.0
var _on := false
var _noise := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.12
	stream = g
	bus = "Work"
	unit_size = 6.0
	max_distance = 90.0
	volume_db = -8.0
	play()
	_gen = get_stream_playback()


func set_state(speed01: float, throttle01: float, engine_on: bool) -> void:
	_on = engine_on
	_rpm = lerpf(_rpm, 0.18 + speed01 * 0.7 + throttle01 * 0.25, 0.08)
	_load = lerpf(_load, throttle01, 0.1)
	_noise = speed01


func _process(_d: float) -> void:
	if _gen == null:
		return
	var n := _gen.get_frames_available()
	if not _on:
		for i in n:
			_gen.push_frame(Vector2.ZERO)
		return
	var f0 := 28.0 + _rpm * 70.0
	var amp := 0.18 + _load * 0.16
	var lp := 0.0
	for i in n:
		_phase = fmod(_phase + f0 / RATE, 1.0)
		var ph := _phase * TAU
		var s := sin(ph) * 0.6 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0 + 0.4) * 0.18 + (1.0 if fmod(_phase * 4.0, 1.0) < 0.12 else 0.0) * 0.15
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.08)
		var v := s * amp + lp * _noise * 0.35
		_gen.push_frame(Vector2(v, v))
