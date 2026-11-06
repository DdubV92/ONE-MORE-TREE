class_name WeatherService
extends Node
## Phase 8 weather: a restrained, seeded schedule (clear, light cloud,
## overcast, light rain, distant storm) that is a pure function of the
## campaign seed, the day and the authoritative clock. Loading a save
## therefore reconstructs exactly the same weather and blend progress;
## nothing is rerolled. Only the smoothed cosmetic wetness is stored.
##
## Ownership: this service decides WHAT the weather is. EnvironmentController
## remains the single writer of sky/sun/fog/ambient and the shared shader
## globals (wind, wetness, rain); it reads `cloud/rain/wind_mult/wind_dir/
## flash` from here through set_weather(). Rain views, rain audio and
## lightning live here. Weather never changes wages, trees, lamps, safety,
## cargo, the contract or any campaign RNG (it owns its own cosmetic RNG).

## Phase 23 (pack Phase 21): authored weather VISITS from StormSchedule
## (seven profiles, approach/onset/build/peak/recovery, cells and bands,
## seeded gating), a separate lightning parameter, STABLE STRIKE RECORDS
## (id, emission time, position, kind) whose flash and thunder come from the
## same record, thunder delayed and levelled per listener (you, and each
## shown camera microphone by its own path), and a thunder MASKING model
## that encounters, AI hearing and crew perception share.
signal state_changed(name: String)
signal strike_flashed(strike: Dictionary)
signal thunder_arrived(strike: Dictionary, listener: String, level_db: float)

const STATES := {
	# cloud cover, rain, wind multiplier, storm (distant lightning)
	"clear": {"cloud": 0.0, "rain": 0.0, "wind": 1.0, "storm": 0.0},
	"light_cloud": {"cloud": 0.3, "rain": 0.0, "wind": 1.1, "storm": 0.0},
	"overcast": {"cloud": 0.82, "rain": 0.0, "wind": 1.25, "storm": 0.0},
	"light_rain": {"cloud": 0.95, "rain": 0.62, "wind": 1.4, "storm": 0.0},
	"storm": {"cloud": 1.0, "rain": 0.85, "wind": 1.7, "storm": 1.0},
}
const ORDER := ["clear", "light_cloud", "overcast", "light_rain", "storm"]

## Day plans: [clock seconds, state]. Times get a deterministic per-day
## jitter. Weights keep most days fair; rain is an occasional mood.
const PLANS := {
	"fair": {"w": 30, "s": [[0, "clear"], [620, "light_cloud"], [1000, "clear"]]},
	"fair_cloud": {"w": 18, "s": [[0, "light_cloud"], [420, "clear"], [980, "light_cloud"]]},
	"overcast_clearing": {"w": 12, "s": [[0, "overcast"], [420, "light_cloud"], [780, "clear"]]},
	"afternoon_shower": {"w": 12, "s": [[0, "light_cloud"], [360, "overcast"], [500, "light_rain"], [700, "overcast"], [880, "light_cloud"]]},
	"grey_day": {"w": 8, "s": [[0, "overcast"], [560, "light_rain"], [760, "overcast"]]},
	"rainy_evening": {"w": 10, "s": [[0, "light_cloud"], [680, "overcast"], [940, "light_rain"]]},
	"distant_storm": {"w": 8, "s": [[0, "clear"], [760, "light_cloud"], [1010, "overcast"], [1150, "storm"]]},
}
const BLEND_SECONDS := 90.0
const PREVIEW_BLEND := 4.0
const WET_RISE := 70.0          # seconds of steady rain to soak exterior surfaces
const WET_DRY := 300.0          # seconds to dry after the rain stops

var seed_value := 0
var override := ""              # preview / test override state name ("" = schedule)
var cloud := 0.0
var rain := 0.0
var wind_mult := 1.0
var storm := 0.0                # = lightning activity (kept name)
var lightning := 0.0
var gust := 0.0
var visibility := 1.0
var sea := 0.2
var profile_name := "clear_broken"
var phase_name := "none"
var phase_k := 0.0
var visit_id := ""
var visit_quiet := true
var schedule: StormSchedule
var weather_t := 0.0            # T on the day's weather timeline
var weather_day := 0
var strikes_fired := 0          # position in the strike stream (saved)
var fired_ids := {}             # strike id -> true (never flash twice)
var pending: Array = []         # [{strike, listener, cam, due_T, level_db}] thunder in flight
var last_strike := {}
var _last_T := -1.0
var _last_day := -1
var wind_dir := Vector2(0.8, 0.6)
var wetness := 0.0              # smoothed cosmetic surface wetness 0..1
var flash := 0.0                # current lightning flash level (after comfort setting)
var current_name := "clear"
var plan_name := "fair"
var _override_from := {}
var _override_t := 0.0
var _cos_rng := RandomNumberGenerator.new()   # cosmetic only (lightning timing)
var flashes := 0                # counters for tests / diagnostics
var thunders := 0
var views: Array = []           # RainView nodes
var player_view: Node3D
var _audio_open: AudioStreamPlayer
var _audio_roof: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var shelter := 0.0              # listener shelter 0 (open) .. 1 (indoors)
var _shelter_t := 0.0
var _push_t := 0.0
var time_source := Callable()   # optional override (tests): returns [day, t]


func _ready() -> void:
	add_to_group("weather")
	seed_value = int(World.manifest.get("world_seed", 20261103))
	_cos_rng.seed = seed_value ^ 0x5EED
	player_view = RainView.new()
	player_view.name = "PlayerRain"
	player_view.follow_main_camera = true
	add_child(player_view)
	views.append(player_view)
	# Phase 15: rain is positional (SoundService): open-air emitters around
	# the listener (walls occlude them), the real roof above you (metal
	# camper, wood cabin, canvas lean-to) and eave drips.
	for k in 3:
		var m := Marker3D.new()
		m.name = "RainEmitter%d" % k
		add_child(m)
		_rain_pts.append(m)
	_thunder = AudioStreamPlayer.new()
	_thunder.bus = "Ambience"
	add_child(_thunder)


func _loop_player(name_: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Ambience"
	var s: AudioStreamWAV = load("res://audio/generated/%s.wav" % name_)
	if s:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
		p.stream = s
	p.volume_db = -80.0
	add_child(p)
	return p


# ------------------------------------------------------------ schedule

func _sched() -> StormSchedule:
	if schedule == null or schedule.seed_value != seed_value:
		schedule = StormSchedule.for_seed(seed_value)
	return schedule


## Kept for older callers: the visits of a day as a "plan".
func plan_for_day(day: int) -> Dictionary:
	var vs: Array = (_sched().days.get(day, {"visits": []}) as Dictionary).visits
	return {"name": str(vs[0].profile) if not vs.is_empty() else "fair", "s": vs}


## Blended weather parameters at (day, weather seconds). Deterministic.
func sample(day: int, t: float) -> Dictionary:
	var out := _sched().sample(day, t)
	out["wind"] = out.wind
	out["storm"] = out.lightning
	out["name"] = str(out.profile)
	out["plan"] = str(out.profile) if str(out.visit) != "" else "fair"
	out["wind_dir"] = _sched().wind_dir(day, t)
	return out


## (day, T): contract days run the workday clock, then nightfall + awake
## night seconds (the night clock is bounded; weather keeps moving while you
## are awake). Hunt days run the hunt cycle.
func _clock_now() -> Array:
	if time_source.is_valid():
		return time_source.call()
	var hunt: Node = Game.hunt
	if hunt and hunt.call("hunt_active"):
		var ht: float = float(hunt.get("t"))
		return [int(hunt.get("hunt_day")) + int(ht / HuntService.CYCLE), fmod(ht, HuntService.CYCLE)]
	var cs: CampaignService = Game.campaign
	if cs and (cs.active or cs.test_route) and cs.clock:
		var t := cs.clock.t
		if cs.clock.phase() == WorkdayClock.Phase.NIGHT:
			t = minf(WorkdayClock.NIGHT_AT + cs.clock.night_exposure, StormSchedule.timeline_len(cs.clock.day))
		return [cs.clock.day, t]
	return []


## Preview / test override ("" returns to the schedule).
func set_override(state: String, instant := false) -> void:
	if state != "" and not STATES.has(state) and StormSchedule.profile(state).is_empty():
		return
	_override_from = {"cloud": cloud, "rain": rain, "wind": wind_mult, "storm": storm, "lightning": lightning, "gust": gust, "visibility": visibility, "sea": sea}
	_override_t = PREVIEW_BLEND if instant else 0.0
	override = state
	if instant and state != "":
		var s: Dictionary = _override_params(state)
		cloud = s.cloud
		rain = s.rain
		wind_mult = s.wind
		storm = s.storm
		lightning = float(s.get("lightning", s.storm))
		gust = float(s.get("gust", 0.2))
		visibility = float(s.get("visibility", 1.0))
		sea = float(s.get("sea", 0.2))
		wetness = clampf(s.rain * 1.4, 0.0, 1.0)
		current_name = state
	_push(true)


## Override parameters: an old Phase 8 state name or a Phase 23 profile at
## its peak (preview stations, tests, perf probes).
func _override_params(state: String) -> Dictionary:
	if STATES.has(state):
		var o: Dictionary = (STATES[state] as Dictionary).duplicate()
		o["lightning"] = o.storm
		o["gust"] = 0.2 + 0.5 * float(o.storm)
		o["visibility"] = 1.0 - 0.5 * float(o.rain)
		o["sea"] = 0.2 + 0.6 * float(o.storm)
		return o
	var p := StormSchedule.profile(state)
	return {"cloud": p.cloud, "rain": p.rain, "wind": p.wind, "storm": p.lightning, "lightning": p.lightning, "gust": p.gust, "visibility": p.visibility, "sea": p.sea}


func _target() -> Dictionary:
	if override != "":
		var s: Dictionary = _override_params(override)
		var k := clampf(_override_t / PREVIEW_BLEND, 0.0, 1.0)
		var out := {}
		for p in s:
			out[p] = lerpf(float(_override_from.get(p, s[p])), float(s[p]), k)
		out["name"] = override
		out["profile"] = override
		out["plan"] = "preview"
		out["visit"] = ""
		out["phase"] = "peak"
		out["phase_k"] = 0.5
		out["quiet"] = true
		out["wind_dir"] = wind_dir
		return out
	var now := _clock_now()
	if now.is_empty():
		var c: Dictionary = _override_params("clear")
		c["name"] = "clear"
		c["profile"] = "clear_broken"
		c["plan"] = "none"
		c["visit"] = ""
		c["phase"] = "none"
		c["phase_k"] = 0.0
		c["quiet"] = true
		c["wind_dir"] = Vector2(0.8, 0.6)
		return c
	return sample(int(now[0]), float(now[1]))


# ------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_override_t += delta
	var tg := _target()
	cloud = float(tg.cloud)
	rain = float(tg.rain)
	wind_mult = float(tg.wind)
	storm = float(tg.storm)
	lightning = float(tg.get("lightning", storm))
	gust = float(tg.get("gust", 0.2))
	visibility = float(tg.get("visibility", 1.0))
	sea = float(tg.get("sea", 0.2))
	profile_name = str(tg.get("profile", "clear_broken"))
	phase_name = str(tg.get("phase", "none"))
	phase_k = float(tg.get("phase_k", 0.0))
	visit_id = str(tg.get("visit", ""))
	visit_quiet = bool(tg.get("quiet", true))
	wind_dir = tg.wind_dir
	plan_name = str(tg.plan)
	var nm := str(tg.name)
	if nm != current_name:
		current_name = nm
		state_changed.emit(nm)
	# Wetness soaks in with rain and dries slowly afterwards.
	if rain > 0.05:
		wetness = minf(wetness + delta * rain / WET_RISE * 1.6, 1.0)
	else:
		wetness = maxf(wetness - delta / WET_DRY, 0.0)
	_update_lightning(delta)
	_update_shelter(delta)
	_update_audio(delta)
	_push_t -= delta
	if _push_t <= 0.0 or flash > 0.001:
		_push_t = 0.2
		_push(false)


func _push(force: bool) -> void:
	var env: EnvironmentController = Game.environment
	if env:
		env.set_weather(cloud, rain, wind_mult, wind_dir, wetness, flash, force)
		env.set_storm(visibility, gust, sea)
	BuildKit.apply_wetness(wetness)
	for v in views:
		if is_instance_valid(v):
			v.set_rain(rain, wind_dir, wind_mult)


# ------------------------------------------------------------ lightning

## Flash envelope by strike kind (raw 0..1 before the comfort setting).
static func flash_raw(kind: String, strokes: int, x: float) -> float:
	match kind:
		"near":
			var v := 0.0
			for k in strokes:
				var at := 0.11 * k
				v = maxf(v, exp(-maxf(x - at, 0.0) * 14.0) * (1.0 if x >= at else 0.0) * (1.0 - 0.18 * k))
			return v
		"mid":
			return exp(-x * 8.0) * 0.6 + 0.25 * exp(-absf(x - 0.2) * 22.0)
	return 0.28 * sin(clampf(x / 0.9, 0.0, 1.0) * PI)


## Where a strike is in the world (near ones on the ground under the cloud).
static func strike_pos(st: Dictionary) -> Vector3:
	var o := CampLayout.origin() if Engine.get_main_loop() else Vector3.ZERO
	var off: Array = st.off
	var x := o.x + float(off[0])
	var z := o.z + float(off[1])
	var y := World.height_at(x, z) if World.manifest != null and not World.manifest.is_empty() else 0.0
	return Vector3(x, y + (0.0 if str(st.kind) == "near" else 900.0), z)


## Thunder source level (dB SPL-like scale of the world simulation) and roll
## length per kind. Shared by playback, masking and AI hearing.
const THUNDER_SRC := {"near": 118.0, "mid": 110.0, "far": 102.0}
const THUNDER_ROLL := {"near": 3.2, "mid": 5.0, "far": 6.5}
const RAIN_BED_DB := 46.0           # heavy rain bed at the ear, open air


static func thunder_level(st: Dictionary, listener: Vector3, sheltered := 0.0) -> float:
	var d := maxf(strike_pos(st).distance_to(listener), 30.0)
	return float(THUNDER_SRC[str(st.kind)]) + linear_to_db(float(st.power)) - 20.0 * log(d / 30.0) / log(10.0) - sheltered * 12.0


static func thunder_arrival(st: Dictionary, listener: Vector3) -> float:
	return float(st.t) + StormSchedule.thunder_delay(strike_pos(st).distance_to(listener))


## Loudness envelope of one roll at a listener, x seconds after arrival.
static func roll_env(kind: String, x: float) -> float:
	if x < 0.0:
		return 0.0
	var att := clampf(x / 0.08, 0.0, 1.0)
	var tau := float(THUNDER_ROLL[kind]) / 2.3
	var base := exp(-x / tau)
	if kind == "near":
		base = maxf(base, exp(-x / 0.35))      # the crack, then the roll
	return att * base


## Modelled masking level (dB) at a listener at weather time T: every
## thunder roll sounding there, plus the rain bed. World simulation values
## (before any player volume settings): encounters, AI and crew share it.
func masking_db(listener: Vector3, at_t := -1.0, sheltered := 0.0) -> float:
	var t := weather_t if at_t < 0.0 else at_t
	var pw := db_to_linear(RAIN_BED_DB - 30.0 * (1.0 - rain) - sheltered * 10.0) if rain > 0.05 else 0.0
	for st in _recent_strikes(t):
		var e := roll_env(str(st.kind), t - thunder_arrival(st, listener))
		if e > 0.001:
			pw += db_to_linear(thunder_level(st, listener, sheltered) + linear_to_db(e))
	return linear_to_db(maxf(pw, 1e-9))


## Would a sound of `src_db` at `src` (1 m reference) reach the listener
## above the masking? (occlusion loss supplied by the caller if known).
func audible_over_masking(src: Vector3, src_db: float, listener: Vector3, at_t := -1.0, extra_loss := 0.0) -> bool:
	var lvl := src_db - 20.0 * log(maxf(src.distance_to(listener), 1.0)) / log(10.0) - extra_loss
	return lvl > masking_db(listener, at_t) - 3.0


## The masking window a strike opens at a listener for sounds of level
## `need_db` there: [start, end] in weather time (empty if it never covers).
func masking_window(st: Dictionary, listener: Vector3, need_db: float) -> Array:
	var arr := thunder_arrival(st, listener)
	var lvl := thunder_level(st, listener)
	var start := -1.0
	var x := 0.0
	while x < 14.0:
		var m := lvl + linear_to_db(maxf(roll_env(str(st.kind), x), 1e-6))
		if m >= need_db + 3.0:
			if start < 0.0:
				start = arr + x
		elif start >= 0.0:
			return [start, arr + x]
		x += 0.05
	return [start, arr + 14.0] if start >= 0.0 else []


func _recent_strikes(t: float) -> Array:
	var out: Array = []
	if weather_day <= 0:
		return out
	for st in _sched().strikes_for_day(weather_day):
		if float(st.t) <= t and float(st.t) > t - 22.0:
			out.append(st)
	for st in _preview_strikes:
		if float(st.t) <= t and float(st.t) > t - 22.0:
			out.append(st)
	return out


## Upcoming strikes of the current day (for encounter planning).
func upcoming_strikes(from_t: float, horizon: float) -> Array:
	var out: Array = []
	for st in _sched().strikes_for_day(weather_day):
		if float(st.t) > from_t and float(st.t) <= from_t + horizon:
			out.append(st)
	return out


var _preview_strikes: Array = []
var _flashes_live: Array = []      # [strike, x]


## Strikes fire from the schedule as weather time passes (a load or a
## sleep jumps without firing the past; thunder already in flight resumes
## from the save). Preview / override storms synthesise records instead.
func _update_lightning(delta: float) -> void:
	var now := _clock_now()
	var day := int(now[0]) if not now.is_empty() else 0
	var t := float(now[1]) if not now.is_empty() else weather_t + delta
	if override != "":
		day = weather_day if weather_day > 0 else 0
		t = weather_t + delta
		_preview_fire(t)
	if day != _last_day or t < _last_T - 0.01 or t - _last_T > 30.0:
		_last_T = t                     # jumped (load / sleep / day change)
	weather_day = day
	weather_t = t
	if override == "" and day > 0:
		for st in _sched().strikes_for_day(day):
			if float(st.t) > _last_T and float(st.t) <= t and not fired_ids.has(str(st.id)):
				fire(st)
	_last_T = t
	_last_day = day
	# Thunder in flight arrives per listener.
	for i in range(pending.size() - 1, -1, -1):
		var p: Dictionary = pending[i]
		if t >= float(p.due):
			pending.remove_at(i)
			_thunder_now(p)
	# Flash envelopes (comfort setting applied here, presentation only).
	var mode := str(Settings.get_v("flash_reduction"))
	var f := 0.0
	for i in range(_flashes_live.size() - 1, -1, -1):
		var fl: Array = _flashes_live[i]
		fl[1] = float(fl[1]) + delta
		var st: Dictionary = fl[0]
		var raw := flash_raw(str(st.kind), int(st.strokes), float(fl[1]))
		if mode == "reduced":
			raw = 0.22 * sin(clampf(float(fl[1]) / 1.2, 0.0, 1.0) * PI) * (1.0 if str(st.kind) != "far" else 0.6)
		elif mode != "full":
			raw = 0.0
		f = maxf(f, raw)
		if float(fl[1]) > 1.4:
			_flashes_live.remove_at(i)
	flash = clampf(f, 0.0, 1.0)
	_strike_light(delta)


## One strike: flash now, thunder scheduled per listener from the same
## record (you, and every shown camera microphone at its own distance).
func fire(st: Dictionary) -> void:
	fired_ids[str(st.id)] = true
	strikes_fired += 1
	flashes += 1
	last_strike = st
	_flashes_live.append([st, 0.0])
	if str(st.kind) == "near":
		_light_strike = st
		_light_x = 0.0
	var lp := _listener()
	pending.append({"strike": st, "listener": "player", "cam": -1, "due": thunder_arrival(st, lp), "pos": [lp.x, lp.y, lp.z]})
	var wall: CameraWall = Game.tv
	if wall:
		for ci in wall.shown_cameras():
			var cp := wall.camera_position(int(ci))
			if cp != Vector3.INF:
				pending.append({"strike": st, "listener": wall.cam_id(int(ci)), "cam": int(ci), "due": thunder_arrival(st, cp), "pos": [cp.x, cp.y, cp.z]})
	strike_flashed.emit(st)


func _thunder_now(p: Dictionary) -> void:
	var st: Dictionary = p.strike
	var lpos := Vector3(p.pos[0], p.pos[1], p.pos[2])
	var lvl := thunder_level(st, lpos, shelter if int(p.cam) < 0 else 0.0)
	thunders += 1
	thunder_arrived.emit(st, str(p.listener), lvl)
	var ev := "weather.thunder.near" if str(st.kind) == "near" else "weather.thunder.far"
	# Gain inside the established mix limits (the bus and calibration cap it).
	var db := clampf((lvl - 90.0) * 0.45, -18.0, 4.0)
	if int(p.cam) >= 0:
		var wall: CameraWall = Game.tv
		if wall:
			var stream: AudioStream = load(SoundBank.path_of(ev)) if SoundBank.path_of(ev) != "" else null
			wall.relay_at_camera(stream, int(p.cam), db, "thunder", "weather")
		return
	if SoundService.instance() != null:
		# From the strike's direction (bounded distance for the mixer), its
		# delay already applied here; occlusion and rooms by SoundService.
		var lp := _listener()
		var sp := strike_pos(st)
		var dir := (sp - lp)
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
		SoundService.play(ev, lp + dir * 300.0 + Vector3(0, 80, 0), {"no_delay": true, "db": db, "emit": false})


var _light_strike := {}
var _light_x := 0.0
var _slight: OmniLight3D


## A near strike lights the land around it briefly (one pooled light with
## real shadows; interiors only through their windows). Reduced flashes:
## a soft, slow glow instead of a strobe; Off: none.
func _strike_light(delta: float) -> void:
	if _light_strike.is_empty():
		if _slight:
			_slight.visible = false
		return
	_light_x += delta
	if _slight == null:
		_slight = OmniLight3D.new()
		_slight.name = "StrikeLight"
		_slight.omni_range = 260.0
		_slight.omni_attenuation = 1.2
		_slight.shadow_enabled = true
		_slight.light_color = Color(0.82, 0.86, 1.0)
		add_child(_slight)
	var mode := str(Settings.get_v("flash_reduction"))
	var raw := flash_raw("near", int(_light_strike.strokes), _light_x)
	if mode == "reduced":
		raw = 0.2 * sin(clampf(_light_x / 1.2, 0.0, 1.0) * PI)
	elif mode != "full":
		raw = 0.0
	_slight.visible = raw > 0.01
	_slight.global_position = strike_pos(_light_strike) + Vector3(0, 120.0, 0)
	_slight.light_energy = 14.0 * raw
	if _light_x > 1.4:
		_light_strike = {}


## Preview storms (station / override / perf probe): synthetic strikes so a
## preview never touches the campaign's schedule.
var _prev_next := 6.0
func _preview_fire(t: float) -> void:
	if lightning < 0.3:
		_prev_next = maxf(_prev_next, t + 8.0)
		return
	if t < _prev_next:
		return
	_prev_next = t + _cos_rng.randf_range(10.0, 30.0) / maxf(lightning, 0.3)
	var kind := "near" if _cos_rng.randf() < 0.2 else ("mid" if _cos_rng.randf() < 0.5 else "far")
	var a := _cos_rng.randf_range(0.0, TAU)
	var r: float = {"near": 450.0, "mid": 1600.0, "far": 4500.0}[kind]
	var st := {"id": "P-%d" % flashes, "visit": "preview", "day": weather_day, "t": t, "kind": kind,
		"off": [cos(a) * r, sin(a) * r], "dist": r, "power": 0.85, "strokes": 2 if kind == "near" else 1, "seed": 0}
	_preview_strikes.append(st)
	if _preview_strikes.size() > 8:
		_preview_strikes.pop_front()
	fire(st)


# ------------------------------------------------------------ shelter + audio

## 0 in the open, ~0.5 under a porch roof / truck cab, 1 indoors.
func shelter_at(pos: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state if get_viewport() else null
	if space == null:
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.3, 0), pos + Vector3(0, 18.0, 0))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return 0.5 if not hit.is_empty() else 0.0


func _listener() -> Vector3:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	return cam.global_position if cam else Vector3.ZERO


func _update_shelter(delta: float) -> void:
	_shelter_t -= delta
	if _shelter_t > 0.0:
		return
	_shelter_t = 0.25
	var target := 0.0
	var env: EnvironmentController = Game.environment
	if env and env._interior_target > 0.5:
		target = 1.0
	elif rain > 0.01:
		target = shelter_at(_listener())
	shelter = move_toward(shelter, target, 0.25 / 0.6)


var _rain_pts: Array[Marker3D] = []
var _rain_h := {}            # layer -> SoundService loop handle
var _roof_kind := ""
var _roof_t := 0.0


func _update_audio(delta: float) -> void:
	if SoundService.instance() == null:
		return
	var r := rain
	var lp := _listener()
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var right := cam.global_basis.x if cam else Vector3.RIGHT
	right.y = 0.0
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	# Open-air rain left/right of the listener, a little above (outdoors).
	_rain_pts[0].global_position = lp + right * 7.0 + Vector3(0, 2.5, 0)
	_rain_pts[1].global_position = lp - right * 7.0 + Vector3(0, 2.5, 0)
	var heavy := clampf((r - 0.45) / 0.4, 0.0, 1.0)
	_rain_layer("light_l", "weather.rain.light", _rain_pts[0], r * (1.0 - heavy * 0.6), -2.0, delta)
	_rain_layer("light_r", "weather.rain.light", _rain_pts[1], r * (1.0 - heavy * 0.6), -2.0, delta)
	_rain_layer("heavy", "weather.rain.heavy", _rain_pts[0], r * heavy, 0.0, delta)
	# The roof right above you, by what it is made of (rechecked 4x/s).
	_roof_t -= delta
	if _roof_t <= 0.0:
		_roof_t = 0.25
		_roof_kind = ""
		var space := get_viewport().world_3d.direct_space_state if get_viewport() else null
		if space:
			var q := PhysicsRayQueryParameters3D.create(lp, lp + Vector3(0, 6.0, 0))
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				var col := hit.collider as Node
				var m := str(col.get_meta("acoustic", "wood")) if col else "wood"
				_roof_kind = "metal" if m == "metal" else ("canvas" if m == "fabric" else "wood")
				_rain_pts[2].global_position = hit.position
	# Phase 23 listening layers (every source is a real positional emitter;
	# walls, doors and rooms filter them through SoundService).
	layer = listening_layer()
	if layer == "vehicle":
		_roof_kind = "metal"           # rain drumming on the cab roof
		_rain_pts[2].global_position = lp + Vector3(0, 1.0, 0)
	for k in ["metal", "wood", "canvas"]:
		_rain_layer("roof_" + k, "weather.rain." + k, _rain_pts[2], r if _roof_kind == k else 0.0, -2.0, delta)
	_rain_layer("drips", "weather.rain.drips", _rain_pts[2], r * (0.6 if _roof_kind != "" else 0.0), 0.0, delta)
	# Under the canopy: the open rain thins, the trees drip heavily.
	if _rain_pts.size() < 5:
		for k in 2:
			var m := Marker3D.new()
			m.name = "RainEmitterX%d" % k
			add_child(m)
			_rain_pts.append(m)
	_rain_pts[3].global_position = lp + Vector3(0, 6.0, 0)
	_rain_layer("canopy", "weather.canopy", _rain_pts[3], r * (0.9 if layer == "canopy" else 0.0), 0.0, delta)
	# Roof-edge runoff where you stand sheltered outside (porch, eaves).
	if _roof_kind != "" and layer in ["porch", "camper", "cabin"]:
		_rain_pts[4].global_position = _eave_point(lp)
	_rain_layer("runoff", "weather.runoff", _rain_pts[4], clampf((r - 0.4) / 0.5, 0.0, 1.0) if _roof_kind != "" else 0.0, 0.0, delta)
	# Gusts arrive from upwind; louder on an open shore, muffled indoors.
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_t = lerpf(14.0, 4.0, gust) * randf_range(0.7, 1.3)
		if gust > 0.35:
			var up := Vector3(-wind_dir.x, 0, -wind_dir.y)
			SoundService.play("weather.gust", lp + up * 18.0 + Vector3(0, 4, 0), {"db": linear_to_db(gust) + (3.0 if layer == "shore" else 0.0), "emit": false})


## Phase 23: where the listener is, for the rain/wind mix: open, canopy,
## shore, porch, camper, cabin, vehicle.
var layer := "open"
var _gust_t := 6.0

func listening_layer() -> String:
	var p: Node3D = Game.player
	if p and p.get("vehicle") != null:
		return "vehicle"
	if p:
		var ctx := TerrorPlacement.context_of(p)
		if ctx in ["camper", "cabin"] and Game.environment and Game.environment._interior_target > 0.5:
			return ctx
	var lp := _listener()
	if _roof_kind != "":
		return "porch"
	if World.manifest != null and not World.manifest.is_empty():
		if World.surface_at(lp.x, lp.z) == World.Surface.FOREST:
			return "canopy"
		for k in 6:
			var a := TAU * k / 6.0
			if World.water_depth_at(lp.x + cos(a) * 22.0, lp.z + sin(a) * 22.0) > 0.3:
				return "shore"
	return "open"


## The nearest roof edge around a sheltered listener (first open sky found
## stepping outward in eight directions).
func _eave_point(lp: Vector3) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state if get_viewport() else null
	if space == null:
		return lp
	for dist in [1.5, 2.5, 3.5, 5.0]:
		for k in 8:
			var a := TAU * k / 8.0
			var q: Vector3 = lp + Vector3(cos(a), 0, sin(a)) * float(dist)
			var ray := PhysicsRayQueryParameters3D.create(q + Vector3(0, 0.3, 0), q + Vector3(0, 12.0, 0))
			if space.intersect_ray(ray).is_empty():
				return Vector3(q.x, lp.y + 1.0, q.z)
	return lp


## A rain layer keeps its loop while weather flickers: silent layers idle at
## -80 dB and are released only after RAIN_RELEASE s of continuous silence,
## so rapid weather changes never churn players (bounded nodes).
const RAIN_RELEASE := 4.0
var _rain_quiet := {}


func _rain_layer(key: String, event: String, at: Node3D, lin: float, top_db: float, delta: float) -> void:
	var h := int(_rain_h.get(key, 0))
	if lin < 0.01:
		if h != 0:
			_rain_quiet[key] = float(_rain_quiet.get(key, 0.0)) + delta
			if float(_rain_quiet[key]) >= RAIN_RELEASE or not SoundService.is_playing(h):
				SoundService.loop_stop(h, 0.3)
				_rain_h.erase(key)
				_rain_quiet.erase(key)
			else:
				SoundService.loop_set(h, -80.0)
		return
	_rain_quiet.erase(key)
	if h == 0 or not SoundService.is_playing(h):
		h = SoundService.loop(event, at, {"gain": -40.0})
		_rain_h[key] = h
	SoundService.loop_set(h, top_db + linear_to_db(maxf(lin, 0.0001)))


func _set_loop(p: AudioStreamPlayer, lin: float, top_db: float) -> void:
	if p.stream == null:
		return
	if lin < 0.01:
		if p.playing:
			p.stop()
		return
	p.volume_db = top_db + linear_to_db(maxf(lin, 0.0001))
	if not p.playing:
		p.play(randf() * maxf(p.stream.get_length() - 0.1, 0.0))


# ------------------------------------------------------------ remote views

## The camera wall registers the remote cameras it is currently rendering;
## each gets a small rain volume at the camera itself (not the player).
func set_remote_views(cams: Array) -> void:
	var keep: Array = [player_view]
	var budget := RainView.remote_budget(cams.size())
	for cam in cams:
		var found: RainView = null
		for v in views:
			if is_instance_valid(v) and v != player_view and v.anchor == cam:
				found = v
		if found == null:
			found = RainView.new()
			found.name = "RemoteRain"
			found.anchor = cam
			add_child(found)
		found.amount_cap = budget
		found.set_rain(rain, wind_dir, wind_mult)
		keep.append(found)
	for v in views:
		if is_instance_valid(v) and not keep.has(v):
			v.queue_free()
	views = keep


func describe() -> String:
	return "%s (plan %s): cloud %.2f, rain %.2f, wind x%.2f, wet %.2f, shelter %.1f%s" % [current_name, plan_name, cloud, rain, wind_mult, wetness, shelter, ", override" if override != "" else ""]


# ------------------------------------------------------------ save

func capture() -> Dictionary:
	var pend: Array = []
	for p in pending:
		pend.append({"strike": str(p.strike.id), "listener": p.listener, "cam": p.cam, "due": snappedf(float(p.due), 0.01), "pos": p.pos})
	return {"seed": seed_value, "wetness": snappedf(wetness, 0.001), "version": 2, "day": weather_day, "t": snappedf(weather_t, 0.01),
		"profile": profile_name, "visit": visit_id, "phase": phase_name, "phase_k": snappedf(phase_k, 0.001),
		"strikes_fired": strikes_fired, "fired": fired_ids.keys().slice(-64), "pending": pend}


func restore(d: Dictionary) -> void:
	seed_value = int(d.get("seed", seed_value))
	wetness = clampf(float(d.get("wetness", 0.0)), 0.0, 1.0)
	override = ""
	strikes_fired = int(d.get("strikes_fired", 0))
	fired_ids.clear()
	for k in d.get("fired", []):
		fired_ids[str(k)] = true
	pending.clear()
	var day := int(d.get("day", 0))
	var by_id := {}
	if day > 0:
		for st in _sched().strikes_for_day(day):
			by_id[str(st.id)] = st
	for p in d.get("pending", []):
		if by_id.has(str(p.strike)):
			# Loaded between a flash and its thunder: the thunder still comes.
			pending.append({"strike": by_id[str(p.strike)], "listener": str(p.listener), "cam": int(p.cam), "due": float(p.due), "pos": p.pos})
	_last_day = day
	_last_T = float(d.get("t", 0.0))
	weather_day = day
	weather_t = _last_T
	_process(0.0)
	_push(true)
