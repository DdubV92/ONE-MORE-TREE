class_name StormSchedule
extends RefCounted
## Phase 23 (pack Phase 21): the campaign's weather as authored VISITS.
##
## A pure function of the world seed: the whole run (contract days 1-30,
## hunt days 31-35, rescue day 36) is planned once, in day order, so the
## rules can look back (minimum gaps between severe storms, "a thunderstorm
## before the first severe storm", "the first major storm carries no
## horror"). Loading a save rebuilds exactly the same schedule; the save
## also stores the derived state for checking (WeatherService.capture).
##
## Weather time (T) on a day:
##   contract days: the workday clock, then nightfall + awake night seconds
##                  (the night clock is bounded, the weather keeps moving
##                  while you are awake; sleep skips the rest of the night);
##   hunt days:     the hunt cycle (0 .. HuntService.CYCLE).
## A visit has approach -> onset -> build -> peak -> recovery. Parameters
## are blended from the day's quiet base toward the profile's peak by a
## per-parameter envelope (cloud leads, rain follows, lightning may lead the
## rain: distant thunder before rain at camp; sea and cloud lag on the way
## out). Thunderstorm and severe peaks breathe in cells with lulls; showers
## come in bands. Lightning is its own parameter: heavy steady rain can stay
## silent, and thunder can arrive before any rain.
##
## Strikes: each visit's lightning envelope is integrated at 1 s steps with
## its own seeded stream (never the campaign RNG), giving stable strike
## records: id, emission time, kind (near / mid / far), offset from camp,
## distance, power. Positions follow the storm's track along the day's wind.

const DATA := "res://data/weather/profiles.json"
const PHASES := ["approach", "onset", "build", "peak", "recovery"]
const PARAMS := ["cloud", "rain", "gust", "wind", "visibility", "sea", "lightning"]
const LAST_DAY := 36

static var _cache := {}             # seed -> StormSchedule
static var _data := {}

var seed_value := 0
var days := {}                      # day -> {"visits": [visit...]}
var _strikes := {}                  # visit id -> Array


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text()) if f else {}
	return _data


static func for_seed(s: int) -> StormSchedule:
	if not _cache.has(s):
		var sc := StormSchedule.new()
		sc.seed_value = s
		sc._plan()
		_cache[s] = sc
	return _cache[s]


static func profile(name: String) -> Dictionary:
	return (data().get("profiles", {}) as Dictionary).get(name, {})


## Length of a day's weather timeline.
static func timeline_len(day: int) -> float:
	if day <= WorkdayClock.CONTRACT_DAYS:
		return WorkdayClock.NIGHT_AT + float(data().schedule.contract_night_span)
	return HuntService.CYCLE


static func is_major(name: String) -> bool:
	return bool(profile(name).get("major", false))


# ------------------------------------------------------------ planning

func _plan() -> void:
	var sch: Dictionary = data().get("schedule", {})
	var order: Array = data().get("order", [])
	var last_major := {}            # profile -> last day used
	var thunder_seen := false
	var first_major_done := false
	for day in range(1, LAST_DAY + 1):
		var r := RandomNumberGenerator.new()
		r.seed = hash([seed_value, day, "storm-plan"])
		var visits: Array = []
		var span := timeline_len(day)
		# Visits per day (day 1 stays fair: the player learns the island).
		var n := 0 if day == 1 else _weighted(r, sch.visits_per_day)
		# Make sure ordinary thunder is met early, before any severe storm.
		var force_thunder := not thunder_seen and day == int(sch.first_thunderstorm_by_day)
		if force_thunder and n == 0:
			n = 1
		var cursor := 0.0
		for k in n:
			var pick := "thunderstorm" if (force_thunder and k == 0) else _pick_profile(r, day, order, last_major, thunder_seen)
			if pick == "":
				continue
			var p := profile(pick)
			var durs: Array = []
			var total := 0.0
			for ph in PHASES:
				var rng: Array = p.phases[ph]
				var dd := r.randf_range(float(rng[0]), float(rng[1]))
				durs.append(dd)
				total += dd
			# Start: some visits wait for nightfall (storms that own the
			# night); others fall in the workday. Visits never overlap.
			var at_night := r.randf() < float(sch.night_share) and day <= WorkdayClock.CONTRACT_DAYS
			var lo := maxf(cursor, WorkdayClock.NIGHT_AT - 200.0 if at_night else 20.0)
			var hi := span - total * 0.35 if at_night else maxf(lo, (WorkdayClock.NIGHT_AT if day <= WorkdayClock.CONTRACT_DAYS else span) - total * 0.6)
			if hi <= lo:
				continue
			var start := r.randf_range(lo, hi)
			var vid := "W%02d-%d" % [day, visits.size() + 1]
			var major := is_major(pick)
			var quiet := false
			if major:
				quiet = (bool(sch.first_major_quiet) and not first_major_done) or r.randf() < float(sch.quiet_major_share)
				first_major_done = true
				last_major[pick] = day
			if pick == "thunderstorm":
				thunder_seen = true
			var cells: Array = p.get("cells", [])
			var bands: Array = p.get("bands", [])
			visits.append({"id": vid, "profile": pick, "start": snappedf(start, 0.1), "durs": durs.map(func(x: float) -> float: return snappedf(x, 0.1)),
				"end": snappedf(start + total, 0.1), "quiet": quiet, "major": major,
				"cell": [r.randf_range(float(cells[0]), float(cells[1])), r.randf_range(float(cells[2]), float(cells[3]))] if cells.size() == 4 else [],
				"band": r.randf_range(float(bands[0]), float(bands[1])) if bands.size() == 2 else 0.0,
				"phase0": r.randf_range(0.0, TAU), "front": bool(p.get("front", false)), "lead": bool(p.get("lead", false))})
			cursor = start + total + 120.0
		days[day] = {"visits": visits}
	# A storm still running at the end of a contract day leaves the next
	# morning in its recovery (sleep skipped the rest of it).
	for day in range(2, LAST_DAY + 1):
		var prev: Array = days[day - 1].visits
		if prev.is_empty():
			continue
		var last: Dictionary = prev.back()
		if float(last.end) > timeline_len(day - 1):
			var durs: Array = (last.durs as Array).duplicate()
			var before: float = float(durs[0]) + float(durs[1]) + float(durs[2]) + float(durs[3])
			(days[day].visits as Array).push_front({"id": "W%02d-0" % day, "profile": last.profile, "start": -before, "durs": durs,
				"end": float(durs[4]), "quiet": true, "major": false, "cell": last.cell, "band": last.band, "phase0": last.phase0,
				"front": false, "lead": false, "tail_of": last.id})


func _weighted(r: RandomNumberGenerator, pairs: Array) -> int:
	var total := 0
	for p in pairs:
		total += int(p[1])
	var x := r.randi_range(0, total - 1)
	for p in pairs:
		x -= int(p[1])
		if x < 0:
			return int(p[0])
	return 0


func _pick_profile(r: RandomNumberGenerator, day: int, order: Array, last_major: Dictionary, thunder_seen: bool) -> String:
	var ok: Array = []
	var total := 0
	for nm in order:
		var p := profile(str(nm))
		if int(p.get("weight", 0)) <= 0 or day < int(p.get("min_day", 1)):
			continue
		if last_major.has(nm) and day - int(last_major[nm]) < int(p.get("gap_days", 0)):
			continue
		if str(p.get("needs_prior", "")) == "thunderstorm" and not thunder_seen:
			continue
		ok.append(nm)
		total += int(p.weight)
	if ok.is_empty():
		return ""
	var x := r.randi_range(0, total - 1)
	for nm in ok:
		x -= int(profile(str(nm)).weight)
		if x < 0:
			return str(nm)
	return str(ok.back())


# ------------------------------------------------------------ sampling

## Which phase a visit is in at T: [index (-1 before, 5 after), progress].
static func phase_of(v: Dictionary, t: float) -> Array:
	var x := t - float(v.start)
	if x < 0.0:
		return [-1, 0.0]
	var durs: Array = v.durs
	for i in 5:
		if x < float(durs[i]):
			return [i, x / maxf(float(durs[i]), 0.001)]
		x -= float(durs[i])
	return [5, 1.0]


static func _ss(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## Envelope (0..1 of the peak) per parameter at T.
static func envelope(v: Dictionary, t: float) -> Dictionary:
	var ph := phase_of(v, t)
	var i: int = ph[0]
	var k := _ss(float(ph[1]))
	var e := {}
	for p in PARAMS:
		e[p] = 0.0
	if i < 0 or i > 4:
		return e
	var lead := bool(v.lead)
	match i:
		0:   # approach: sky darkens, wind picks up; a storm may thunder far off
			e.cloud = 0.6 * k
			e.wind = 0.3 * k
			e.gust = 0.25 * k
			e.sea = 0.3 * k
			e.visibility = 0.15 * k
			e.lightning = 0.35 * k if lead else 0.0
		1:   # onset: first rain
			e.cloud = 0.6 + 0.3 * k
			e.rain = 0.35 * k
			e.wind = 0.3 + 0.3 * k
			e.gust = 0.25 + 0.35 * k
			e.sea = 0.3 + 0.3 * k
			e.visibility = 0.15 + 0.4 * k
			e.lightning = (0.35 + 0.25 * k) if lead else 0.3 * k
		2:   # build
			e.cloud = 0.9 + 0.1 * k
			e.rain = 0.35 + 0.65 * k
			e.wind = 0.6 + 0.4 * k
			e.gust = 0.6 + 0.4 * k
			e.sea = 0.6 + 0.4 * k
			e.visibility = 0.55 + 0.45 * k
			e.lightning = (0.6 if lead else 0.3) + (0.4 if lead else 0.7) * k
		3:   # peak, with cells / bands / a gust front
			for p in PARAMS:
				e[p] = 1.0
			var x := t - float(v.start) - float(v.durs[0]) - float(v.durs[1]) - float(v.durs[2])
			var cell: Array = v.cell
			if cell.size() == 2:
				var per := float(cell[0]) + float(cell[1])
				var c := fposmod(x, per)
				# Smooth bump across the cell, lull between cells.
				var on := _ss(c / 25.0) * (1.0 - _ss((c - float(cell[0]) + 25.0) / 25.0))
				e.rain = 0.45 + 0.55 * on
				e.lightning = 0.12 + 0.88 * on
				e.gust = 0.65 + 0.35 * on
				e.visibility = 0.6 + 0.4 * on
			var band := float(v.band)
			if band > 0.0:
				e.rain = 0.3 + 0.7 * (0.5 + 0.5 * sin(x / band * TAU + float(v.phase0)))
			if bool(v.front):
				e.gust = minf(1.0, 0.75 + 0.25 * exp(-x / 18.0) + 0.25 * _ss(1.0 - x / 30.0))
		4:   # recovery: rain eases first, thunder retreats, sky and sea lag
			# Cloud and sea lag behind (they ease out last) but reach the
			# day's own sky exactly at the end of the visit.
			e.cloud = pow(1.0 - k, 0.6)
			e.rain = (1.0 - k) * (1.0 - k)
			e.lightning = pow(1.0 - k, 3.0)
			e.wind = 1.0 - k
			e.gust = (1.0 - k) * 0.8
			e.sea = pow(1.0 - k, 0.5)
			e.visibility = 1.0 - k
	return e


## The day's quiet base: broken cloud drifting slowly (seeded, smooth).
func base(day: int, t: float) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, day, "base"])
	var a := r.randf_range(0.0, TAU)
	var b := r.randf_range(0.0, TAU)
	var lvl := r.randf_range(0.05, 0.35) if day > 1 else 0.05
	var n := 0.5 + 0.3 * sin(t / 410.0 + a) + 0.2 * sin(t / 157.0 + b)
	return {"cloud": clampf(lvl + 0.18 * n, 0.0, 0.5), "rain": 0.0, "gust": 0.12 + 0.08 * n, "wind": 1.0, "visibility": 1.0, "sea": 0.18, "lightning": 0.0}


## Blended parameters at (day, T). Also names the active profile and phase.
func sample(day: int, t: float) -> Dictionary:
	var out := base(day, t)
	var active := {}
	var best := 0.0
	var vis: Array = (days.get(day, {"visits": []}) as Dictionary).visits
	for v in vis:
		if t < float(v.start) - 1.0 or t > float(v.end) + 1.0:
			continue
		var e := envelope(v, t)
		var pk := profile(str(v.profile))
		for p in PARAMS:
			out[p] = lerpf(float(out[p]), float(pk.get(p, out[p])), float(e[p]))
		var strength := maxf(float(e.cloud), float(e.rain))
		if strength > best:
			best = strength
			active = v
	out["profile"] = str(active.get("profile", "clear_broken")) if best > 0.35 else "clear_broken"
	out["visit"] = str(active.get("id", "")) if not active.is_empty() else ""
	var ph := phase_of(active, t) if not active.is_empty() else [-1, 0.0]
	out["phase"] = PHASES[int(ph[0])] if int(ph[0]) >= 0 and int(ph[0]) <= 4 else "none"
	out["phase_k"] = snappedf(float(ph[1]), 0.001)
	out["quiet"] = bool(active.get("quiet", true))
	return out


# ------------------------------------------------------------ strikes

## Stable strike records for a visit (cached; own seeded stream).
func strikes(day: int, v: Dictionary) -> Array:
	var vid := str(v.id)
	if _strikes.has(vid):
		return _strikes[vid]
	var out: Array = []
	var pk := profile(str(v.profile))
	if float(pk.get("lightning", 0.0)) <= 0.0:
		_strikes[vid] = out
		return out
	var sch: Dictionary = data().schedule
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, vid, "strikes"])
	var wind := wind_dir(day, float(v.start))
	var up := Vector2(-wind.x, -wind.y)            # the storm arrives from upwind
	var t := maxf(float(v.start), 0.0)
	var t_end := minf(float(v.end), timeline_len(day))
	var cool := 0.0
	while t < t_end:
		var e := envelope(v, t)
		var act := float(e.lightning) * float(pk.lightning)
		if cool <= 0.0 and act > 0.02 and r.randf() < float(sch.strike_rate_per_min) / 60.0 * act:
			var ph := phase_of(v, t)
			var near_p := float(sch.near_share_peak) * act * act if int(ph[0]) in [2, 3] else 0.0
			var roll := r.randf()
			var kind := "near" if roll < near_p else ("mid" if roll < near_p + 0.4 * act else "far")
			var prog := clampf((t - float(v.start)) / maxf(float(v.end) - float(v.start), 1.0), 0.0, 1.0)
			var center := up * lerpf(3200.0, -3200.0, prog)
			var dist := 0.0
			var off := Vector2.ZERO
			match kind:
				"near":
					var a := r.randf_range(0.0, TAU)
					off = Vector2(cos(a), sin(a)) * r.randf_range(160.0, 700.0)
				"mid":
					var a2 := r.randf_range(0.0, TAU)
					off = center * 0.35 + Vector2(cos(a2), sin(a2)) * r.randf_range(900.0, 2400.0)
				_:
					var a3 := up.angle() + r.randf_range(-0.9, 0.9)
					off = Vector2(cos(a3), sin(a3)) * r.randf_range(3200.0, 7000.0)
			dist = off.length()
			out.append({"id": "%s-S%03d" % [vid, out.size() + 1], "visit": vid, "day": day, "t": snappedf(t, 0.01), "kind": kind,
				"off": [snappedf(off.x, 0.1), snappedf(off.y, 0.1)], "dist": snappedf(dist, 0.1),
				"power": snappedf(r.randf_range(0.7, 1.0) * (1.0 if kind == "near" else (0.8 if kind == "mid" else 0.55)), 0.01),
				"strokes": 1 + (r.randi_range(1, 3) if kind == "near" else r.randi_range(0, 1)), "seed": r.randi()})
			cool = 4.0                 # strikes are never closer than 4 s apart
		t += 1.0
		cool -= 1.0
	_strikes[vid] = out
	return out


## Every strike of a day, in time order.
func strikes_for_day(day: int) -> Array:
	var all: Array = []
	for v in (days.get(day, {"visits": []}) as Dictionary).visits:
		all.append_array(strikes(day, v))
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	return all


## Prevailing wind for a day (moved here from WeatherService.sample).
func wind_dir(day: int, t: float) -> Vector2:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, day, "wind"])
	var ang := r.randf_range(-0.6, 0.6) + 0.64 + 0.18 * sin(t / 230.0 + float(day))
	return Vector2(cos(ang), sin(ang))


## Thunder travel delay for a distance (real speed of sound, bounded for the
## island's scale so distant rolls still arrive within a few seconds).
static func thunder_delay(dist: float) -> float:
	return clampf(dist / 343.0, 0.05, 9.0)


## Counts used by reports and tests.
func summary() -> Dictionary:
	var counts := {}
	var major_days := []
	var quiet := 0
	var strikes_n := 0
	for day in range(1, LAST_DAY + 1):
		for v in days[day].visits:
			if str(v.id).ends_with("-0"):
				continue
			counts[v.profile] = int(counts.get(v.profile, 0)) + 1
			if bool(v.major):
				major_days.append([day, v.profile])
				if bool(v.quiet):
					quiet += 1
			strikes_n += strikes(day, v).size()
	return {"profiles": counts, "major": major_days, "quiet_major": quiet, "strikes": strikes_n}
