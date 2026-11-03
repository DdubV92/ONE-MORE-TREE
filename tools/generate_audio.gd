extends SceneTree
## Offline generator for the ORIGINAL procedural placeholder sounds in
## audio/generated/ (filtered noise, FM chirps, resonant sweeps). They are
## deliberate temporary stand-ins until licensed recordings are added; see
## docs/ASSET_PROVENANCE.md. Deterministic (fixed seeds).
##   godot --headless --script res://tools/generate_audio.gd

const RATE := 22050
const OUT := "res://audio/generated/"
var rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	rng.seed = 7
	_save("ocean_surf", _ocean(10.0), true)
	_save("river", _river(5.0), true)
	_save("pond_lap", _pond(7.0), true)
	_save("wind_leaves", _wind(9.0), true)
	_save("fire_crackle", _fire(6.0), true)
	_save("room_tone", _room(4.0), true)
	for i in 5:
		_save("bird_%d" % i, _bird(i), false)
	_save("metal_creak", _creak(), false)
	for s in ["grass", "dirt", "sand", "wood", "water", "rock", "forest"]:
		for v in 3:
			_save("step_%s_%d" % [s, v], _step(s, v), false)
	_save("ui_click", _click(), false)
	print("audio generated")
	quit()


func _save(name: String, data: PackedFloat32Array, loop: bool) -> void:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	var peak := 0.0001
	for v in data:
		peak = maxf(peak, absf(v))
	var norm := 0.89 / peak
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i] * norm, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size()
	wav.save_to_wav(ProjectSettings.globalize_path(OUT + name + ".wav"))


func _loopify(d: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	# Crossfade the tail into the head so the loop point is seamless.
	var n := d.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = d[i]
	for i in fade:
		var t := float(i) / fade
		out[i] = d[i] * t + d[n + i] * (1.0 - t)
	return out


func _white() -> float:
	return rng.randf() * 2.0 - 1.0


func _ocean(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE) + RATE
	var d := PackedFloat32Array()
	d.resize(n)
	var brown := 0.0
	var lp := 0.0
	var hp_prev := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		brown = clampf(brown + _white() * 0.02, -1.0, 1.0) * 0.999
		var w := _white()
		lp += (w - lp) * 0.25
		hp = 0.97 * (hp + lp - hp_prev)
		hp_prev = lp
		var swell := 0.5 + 0.5 * sin(TAU * t / (sec / 1.0))
		var wash := pow(maxf(sin(TAU * t / (sec / 1.0) + 0.6), 0.0), 3.0)
		d[i] = brown * 0.6 * (0.6 + 0.4 * swell) + hp * 0.5 * (0.15 + wash)
	return _loopify(d, RATE)


func _river(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE) + RATE / 2
	var d := PackedFloat32Array()
	d.resize(n)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var bp := 0.0
	var bp2 := 0.0
	for i in n:
		var w := _white()
		b0 = 0.99765 * b0 + w * 0.099
		b1 = 0.963 * b1 + w * 0.2965
		b2 = 0.57 * b2 + w * 1.0527
		var pink := (b0 + b1 + b2 + w * 0.1848) * 0.2
		bp += (pink - bp) * 0.35
		bp2 += (bp - bp2) * 0.08
		var bubble := 0.0
		if rng.randf() < 0.0015:
			bubble = 1.0
		d[i] = (bp - bp2) * 1.2 + bubble * 0.3 * _white()
	return _loopify(d, RATE / 2)


func _pond(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE) + RATE
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_white() - lp) * 0.08
		lp2 += (lp - lp2) * 0.05
		var lap := pow(maxf(sin(TAU * t / 1.7) * sin(TAU * t / 3.5), 0.0), 2.0)
		d[i] = (lp - lp2) * (0.15 + lap)
	return _loopify(d, RATE)


func _wind(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE) + RATE
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var gust := 0.45 + 0.35 * sin(TAU * t / sec) + 0.2 * sin(TAU * t * 3.0 / sec + 1.0)
		var w := _white()
		lp += (w - lp) * (0.08 + 0.12 * gust)
		hp = 0.9 * (hp + lp - prev)
		prev = lp
		var rustle := _white() * 0.25 * pow(gust, 2.0) * (1.0 if rng.randf() < 0.3 else 0.3)
		d[i] = hp * gust * 0.8 + rustle * 0.35
	return _loopify(d, RATE)


func _fire(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE) + RATE / 2
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	var pop_env := 0.0
	var pop_lp := 0.0
	for i in n:
		lp += (_white() - lp) * 0.04
		if rng.randf() < 0.0009:
			pop_env = rng.randf_range(0.4, 1.0)
		pop_env *= 0.993
		pop_lp += (_white() - pop_lp) * 0.6
		var crackle := 0.0
		if rng.randf() < 0.006:
			crackle = _white() * rng.randf_range(0.2, 0.6)
		d[i] = lp * 0.5 + pop_lp * pop_env * 0.7 + crackle
	return _loopify(d, RATE / 2)


func _room(sec: float) -> PackedFloat32Array:
	var n := int(sec * RATE) + RATE / 2
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_white() - lp) * 0.02
		d[i] = lp * 0.5 + 0.06 * sin(TAU * 60.0 * t) + 0.03 * sin(TAU * 120.0 * t)
	return _loopify(d, RATE / 2)


func _bird(variant: int) -> PackedFloat32Array:
	var notes := 2 + variant % 3
	var d := PackedFloat32Array()
	var base: float = [2800.0, 3400.0, 2200.0, 4100.0, 3000.0][variant]
	for k in notes:
		var dur := rng.randf_range(0.07, 0.16)
		var n := int(dur * RATE)
		var f0 := base * rng.randf_range(0.85, 1.15)
		var f1 := f0 * rng.randf_range(0.7, 1.4)
		var phase := 0.0
		for i in n:
			var t := float(i) / n
			var f := lerpf(f0, f1, t) + 300.0 * sin(TAU * 28.0 * float(i) / RATE)
			phase += TAU * f / RATE
			var env := sin(PI * t) * (1.0 - 0.3 * t)
			d.append(sin(phase) * env)
		for i in int(rng.randf_range(0.03, 0.09) * RATE):
			d.append(0.0)
	return d


func _creak() -> PackedFloat32Array:
	var n := int(1.4 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var phase := 0.0
	var bp := 0.0
	for i in n:
		var t := float(i) / n
		var f := 180.0 + 90.0 * sin(t * 7.0) + 40.0 * sin(t * 23.0)
		phase += f / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		bp += (saw - bp) * 0.3
		var stick := 1.0 if fmod(phase, 1.0) < 0.15 else 0.4
		d[i] = bp * sin(PI * t) * stick * 0.6
	return d


func _step(surface: String, variant: int) -> PackedFloat32Array:
	rng.seed = hash(surface) + variant
	var n := int(0.18 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	var cut: float = {"grass": 0.25, "dirt": 0.12, "sand": 0.35, "wood": 0.06, "water": 0.45, "rock": 0.5, "forest": 0.2}[surface]
	var decay: float = {"grass": 0.9993, "dirt": 0.9991, "sand": 0.9994, "wood": 0.9986, "water": 0.9996, "rock": 0.998, "forest": 0.9994}[surface]
	var env := 1.0
	var phase := 0.0
	for i in n:
		env *= decay
		lp += (_white() - lp) * cut
		var v := lp
		if surface == "wood":
			phase += TAU * 140.0 / RATE
			v = lp * 0.5 + sin(phase) * 0.7 * env
		elif surface == "water":
			v = lp * (0.6 + 0.4 * sin(float(i) / RATE * TAU * 30.0))
		elif surface == "forest" and rng.randf() < 0.01:
			v += _white() * 0.8
		d[i] = v * env * minf(float(i) / 60.0, 1.0)
	return d


func _click() -> PackedFloat32Array:
	var d := PackedFloat32Array()
	for i in int(0.04 * RATE):
		var t := float(i) / RATE
		d.append(sin(TAU * 1800.0 * t) * exp(-t * 120.0))
	return d
