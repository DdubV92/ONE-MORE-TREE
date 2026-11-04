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
		for v in 5:
			_save("step_%s_%d" % [s, v], _step(s, v), false)
	_save("ui_click", _click(), false)
	# Logging (Phase 1)
	for v in 5:
		_save("chop_%d" % v, _chop(v), false)
	for v in 3:
		_save("clunk_%d" % v, _clunk(v), false)
		_save("creak_wood_%d" % v, _wood_creak(v), false)
	for v in 2:
		_save("axe_miss_%d" % v, _whoosh(v, 0.28, 300.0, 1400.0, 0.5), false)
		_save("tree_impact_%d" % v, _impact(v), false)
	_save("tree_crack", _crack(), false)
	_save("tree_rustle", _whoosh(9, 1.6, 1800.0, 4500.0, 0.4), false)
	# Dog (Phase 5) - separate seed so earlier sounds are unchanged.
	rng.seed = 505
	for v in 2:
		_save("dog_whine_%d" % v, _whine(v), false)
		_save("dog_bark_%d" % v, _bark(v), false)
	_save("dog_growl", _growl(), false)
	_save("dog_flap", _flap(), false)
	_save("dog_pant", _pant(2.0), true)
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


# --- Footsteps -----------------------------------------------------------
# Each step = heel impact + toe roll ~70-110 ms later, both shaped by the
# surface: a filtered body thump, a material layer (grit, crunch, swish,
# hollow knock, splash) and a soft attack so nothing clicks. Five variants
# per surface; the runtime also randomizes pitch and level.

class Biquad:
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func setup(kind: String, f: float, q: float, rate: float) -> Biquad:
		var w := TAU * f / rate
		var cw := cos(w)
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		match kind:
			"lp":
				b0 = (1.0 - cw) * 0.5; b1 = 1.0 - cw; b2 = b0
			"hp":
				b0 = (1.0 + cw) * 0.5; b1 = -(1.0 + cw); b2 = b0
			"bp":
				b0 = alpha; b1 = 0.0; b2 = -alpha
		a1 = -2.0 * cw
		a2 = 1.0 - alpha
		b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0
		return self

	func run(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		return y


func _bq(kind: String, f: float, q := 0.707) -> Biquad:
	return Biquad.new().setup(kind, f, q, RATE)


const STEP_SURFACES := {
	# thump_f, thump_decay(s), layer, layer_f, layer_q, layer_gain, toe_gain, length
	"grass":  [260.0, 0.035, "swish", 3200.0, 0.6, 0.55, 0.6, 0.26],
	"forest": [240.0, 0.04, "crunch", 3600.0, 0.9, 0.75, 0.75, 0.3],
	"dirt":   [320.0, 0.03, "grit", 2600.0, 0.8, 0.35, 0.55, 0.22],
	"sand":   [380.0, 0.06, "hiss", 1500.0, 0.5, 0.5, 0.7, 0.3],
	"rock":   [520.0, 0.02, "grit", 4200.0, 1.2, 0.6, 0.5, 0.2],
	"wood":   [180.0, 0.07, "knock", 0.0, 0.0, 0.8, 0.6, 0.3],
	"water":  [300.0, 0.05, "splash", 1400.0, 0.7, 1.0, 0.8, 0.38],
}


func _step(surface: String, variant: int) -> PackedFloat32Array:
	rng.seed = hash(surface) * 31 + variant * 7 + 1
	var spec: Array = STEP_SURFACES[surface]
	var n := int(float(spec[7]) * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var toe_t := rng.randf_range(0.065, 0.11)
	for hit in 2:
		var t0 := 0.0 if hit == 0 else toe_t
		var gain := 1.0 if hit == 0 else float(spec[6]) * rng.randf_range(0.8, 1.1)
		var thump := _bq("lp", float(spec[0]) * rng.randf_range(0.85, 1.2), 0.9)
		var layer_f: float = spec[3]
		var layer := _bq("bp", maxf(layer_f, 100.0) * rng.randf_range(0.85, 1.2), float(spec[4]) if spec[4] > 0.0 else 1.0)
		var hp := _bq("hp", 120.0)
		var start := int(t0 * RATE)
		var knock_f := [rng.randf_range(160, 200), rng.randf_range(390, 450), rng.randf_range(850, 980)]
		for i in range(start, n):
			var t := float(i - start) / RATE
			var attack := minf(t / 0.004, 1.0)
			var body := thump.run(_white()) * exp(-t / float(spec[1])) * 2.2
			var lay := 0.0
			match spec[2]:
				"swish":
					# Blades brushing: slower bloom, airy.
					lay = layer.run(_white()) * smoothstep(0.0, 0.03, t) * exp(-t / 0.07)
				"crunch":
					# Needles and twigs: dense random crackle.
					var c := _white() if rng.randf() < 0.18 * exp(-t / 0.06) else 0.0
					lay = layer.run(c * 2.5) + layer.run(_white()) * 0.15 * exp(-t / 0.05)
				"grit":
					var c := _white() if rng.randf() < 0.08 * exp(-t / 0.04) else 0.0
					lay = layer.run(c * 2.0 + _white() * 0.1 * exp(-t / 0.02))
				"hiss":
					# Sand: muffled shuffle, no sharp transient.
					lay = layer.run(_white()) * smoothstep(0.0, 0.02, t) * exp(-t / 0.09)
				"knock":
					var k := 0.0
					for m in 3:
						k += sin(TAU * knock_f[m] * t) * exp(-t / [0.06, 0.035, 0.018][m]) * [1.0, 0.5, 0.25][m]
					lay = k * 0.9
				"splash":
					var bub := sin(TAU * rng.randf_range(500, 1400) * t) * 0.3 if rng.randf() < 0.02 else 0.0
					lay = layer.run(_white()) * smoothstep(0.0, 0.015, t) * exp(-t / 0.12) + bub * exp(-t / 0.15)
			d[i] += hp.run(body + lay * float(spec[5])) * attack * gain
	# Gentle tail fade so variants end silently.
	for i in range(maxi(n - 600, 0), n):
		d[i] *= float(n - i) / 600.0
	return d


func _chop(v: int) -> PackedFloat32Array:
	rng.seed = 900 + v
	var n := int(0.32 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var f1 := rng.randf_range(170.0, 240.0)
	var f2 := f1 * rng.randf_range(2.3, 2.9)
	var click := _bq("bp", rng.randf_range(2500.0, 4200.0), 1.2)
	var crunch := _bq("bp", rng.randf_range(1200.0, 1900.0), 0.8)
	var body_lp := _bq("lp", 600.0, 0.8)
	for i in n:
		var t := float(i) / RATE
		var att := minf(t / 0.0015, 1.0)
		var tone := sin(TAU * f1 * t) * exp(-t / 0.07) + 0.4 * sin(TAU * f2 * t) * exp(-t / 0.035)
		var thump := body_lp.run(_white()) * exp(-t / 0.03) * 1.6
		var cl := click.run(_white()) * exp(-t / 0.006) * 2.2
		var cr := crunch.run(_white() if rng.randf() < 0.3 else 0.0) * exp(-t / 0.05) * 1.4
		d[i] = (tone * 0.9 + thump + cl + cr) * att
	return d


func _clunk(v: int) -> PackedFloat32Array:
	rng.seed = 950 + v
	var n := int(0.5 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var parts := [rng.randf_range(850, 1000), rng.randf_range(2200, 2500), rng.randf_range(3500, 3900)]
	var click := _bq("hp", 2000.0, 0.7)
	for i in n:
		var t := float(i) / RATE
		var ring := 0.0
		for k in 3:
			ring += sin(TAU * parts[k] * t) * exp(-t / [0.12, 0.07, 0.04][k]) * [1.0, 0.6, 0.35][k]
		d[i] = ring * 0.7 + click.run(_white()) * exp(-t / 0.004) * 1.5
	return d


func _wood_creak(v: int) -> PackedFloat32Array:
	rng.seed = 980 + v
	var n := int(rng.randf_range(1.0, 1.6) * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var res := _bq("bp", rng.randf_range(450.0, 750.0), 4.0)
	var res2 := _bq("bp", rng.randf_range(1100.0, 1500.0), 5.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := rng.randf_range(55.0, 70.0) + 40.0 * sin(t * PI) + 15.0 * sin(t * 17.0)
		phase += f / RATE
		var pulse := 1.0 if fmod(phase, 1.0) < 0.08 + 0.05 * rng.randf() else 0.0
		var x := pulse * (0.6 + 0.4 * rng.randf())
		d[i] = (res.run(x) + res2.run(x) * 0.5) * sin(PI * t) * (0.6 + 0.4 * sin(t * 9.0))
	return d


func _crack() -> PackedFloat32Array:
	rng.seed = 1010
	var n := int(1.4 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := _bq("lp", 180.0, 0.7)
	var split := _bq("bp", 2400.0, 0.9)
	for i in n:
		var t := float(i) / RATE
		var snap := _white() * exp(-t / 0.012) * 2.0
		var boom := lp.run(_white()) * exp(-t / 0.25) * 3.0 + sin(TAU * 52.0 * t) * exp(-t / 0.3) * 0.6
		var splinter := split.run(_white() if rng.randf() < 0.25 * exp(-t / 0.35) else 0.0) * 2.0
		d[i] = snap + boom + splinter
	return d


func _impact(v: int) -> PackedFloat32Array:
	rng.seed = 1050 + v
	var n := int(1.6 * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := _bq("lp", 140.0, 0.8)
	var crash := _bq("hp", 1500.0, 0.6)
	var f0 := rng.randf_range(38.0, 50.0)
	for i in n:
		var t := float(i) / RATE
		var thud := lp.run(_white()) * exp(-t / 0.35) * 3.5 + sin(TAU * f0 * t) * exp(-t / 0.45) * 0.9
		var branches := crash.run(_white()) * exp(-t / 0.4) * (0.6 + 0.4 * sin(t * 40.0)) * 0.7
		d[i] = (thud + branches) * minf(t / 0.004, 1.0)
	return d


func _whoosh(v: int, dur: float, f_from: float, f_to: float, q: float) -> PackedFloat32Array:
	rng.seed = 1100 + v
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	# Time-varying band-pass (filter retuned every 256 samples).
	var bp2 := _bq("bp", f_from, q)
	for i in n:
		var t := float(i) / n
		if i % 256 == 0:
			var keep_x1 := bp2.x1
			var keep_x2 := bp2.x2
			var keep_y1 := bp2.y1
			var keep_y2 := bp2.y2
			bp2 = _bq("bp", lerpf(f_from, f_to, t), q)
			bp2.x1 = keep_x1; bp2.x2 = keep_x2; bp2.y1 = keep_y1; bp2.y2 = keep_y2
		d[i] = bp2.run(_white()) * sin(PI * t) * (0.7 + 0.3 * sin(t * 30.0))
	return d


func _click() -> PackedFloat32Array:
	var d := PackedFloat32Array()
	for i in int(0.04 * RATE):
		var t := float(i) / RATE
		d.append(sin(TAU * 1800.0 * t) * exp(-t * 120.0))
	return d


# ------------------------------------------------------------------ dog

## Soft nasal whine: a gliding tone with harmonics and a little vibrato.
func _whine(v: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	var dur := 0.7 + v * 0.35
	var n := int(dur * RATE)
	var f0 := 820.0 + v * 140.0
	var phase := 0.0
	var bp := _bq("bandpass", 1400.0, 1.2)
	for i in n:
		var t := float(i) / n
		var f := f0 * (1.0 + 0.25 * sin(PI * t)) - 180.0 * t * t + 18.0 * sin(TAU * 6.0 * float(i) / RATE)
		phase += TAU * f / RATE
		var env := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.7, 1.0, t))
		var x := sin(phase) + 0.45 * sin(phase * 2.0) + 0.2 * sin(phase * 3.0) + 0.05 * _white()
		d.append(bp.run(x) * env + x * 0.15 * env)
	return d


## A low, muffled woof: short noisy formant burst over a falling pitch.
func _bark(v: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	var n := int((0.22 + v * 0.05) * RATE)
	var phase := 0.0
	var lp := _bq("lowpass", 1300.0, 0.9)
	var bp := _bq("bandpass", 650.0 + v * 120.0, 2.0)
	for i in n:
		var t := float(i) / n
		var f := lerpf(330.0 + v * 40.0, 190.0, t)
		phase += TAU * f / RATE
		var env := smoothstep(0.0, 0.05, t) * exp(-t * 4.0)
		var src := signf(sin(phase)) * 0.6 + sin(phase) * 0.4 + _white() * 0.35
		d.append((lp.run(src) * 0.6 + bp.run(src) * 0.8) * env)
	return d


## Low rumbling growl: amplitude-modulated filtered noise plus a buzz.
func _growl() -> PackedFloat32Array:
	var d := PackedFloat32Array()
	var n := int(1.3 * RATE)
	var lp := _bq("lowpass", 420.0, 1.1)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * (95.0 + 10.0 * sin(TAU * 1.5 * t)) / RATE
		var am := 0.6 + 0.4 * sin(TAU * 23.0 * float(i) / RATE)
		var env := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.75, 1.0, t))
		d.append(lp.run(_white() * 0.8 + signf(sin(phase)) * 0.5) * am * env)
	return d


## Dog flap swinging closed: a light plastic clack and rattle.
func _flap() -> PackedFloat32Array:
	var d := PackedFloat32Array()
	var bp := _bq("bandpass", 2300.0, 3.0)
	for i in int(0.35 * RATE):
		var t := float(i) / RATE
		var hit := exp(-t * 60.0) + 0.5 * exp(-maxf(t - 0.11, 0.0) * 70.0) * (1.0 if t > 0.11 else 0.0) + 0.25 * exp(-maxf(t - 0.19, 0.0) * 80.0) * (1.0 if t > 0.19 else 0.0)
		d.append(bp.run(_white()) * hit)
	return d


## Gentle panting loop (two breaths per second).
func _pant(sec: float) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	var n := int(sec * RATE)
	var bp := _bq("bandpass", 1800.0, 0.8)
	for i in n:
		var t := float(i) / RATE
		var ph := fposmod(t * 2.2, 1.0)
		var env := pow(sin(PI * ph), 3.0) * (1.0 if ph < 0.5 else 0.6)
		d.append(bp.run(_white()) * env)
	return _loopify(d, int(0.05 * RATE))
