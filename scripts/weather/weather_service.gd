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

signal state_changed(name: String)

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
var storm := 0.0
var wind_dir := Vector2(0.8, 0.6)
var wetness := 0.0              # smoothed cosmetic surface wetness 0..1
var flash := 0.0                # current lightning flash level (after comfort setting)
var current_name := "clear"
var plan_name := "fair"
var _override_from := {}
var _override_t := 0.0
var _cos_rng := RandomNumberGenerator.new()   # cosmetic only (lightning timing)
var _next_flash := 25.0
var _flash_t := -1.0
var _thunder_due := -1.0
var _thunder_db := -10.0
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

## The plan for a campaign day (pure function of seed and day).
func plan_for_day(day: int) -> Dictionary:
	if day <= 1:
		return {"name": "fair", "s": [[0.0, "clear"]]}
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, day, "weather"])
	var total := 0
	for k in PLANS:
		total += int(PLANS[k].w)
	var pick := r.randi_range(0, total - 1)
	var chosen := "fair"
	for k in PLANS:
		pick -= int(PLANS[k].w)
		if pick < 0:
			chosen = k
			break
	var segs: Array = []
	for seg in PLANS[chosen].s:
		var at: float = float(seg[0])
		if at > 0.0:
			at = maxf(at + r.randf_range(-60.0, 60.0), 30.0)
		segs.append([at, str(seg[1])])
	return {"name": chosen, "s": segs}


## Blended weather parameters at (day, clock seconds). Deterministic.
func sample(day: int, t: float) -> Dictionary:
	var plan := plan_for_day(day)
	var segs: Array = plan.s
	# The previous day's final state is where this morning starts blending from.
	var prev_plan := plan_for_day(day - 1) if day > 1 else plan
	var prev_state: String = str((prev_plan.s as Array).back()[1])
	var out := {}
	var idx := 0
	for i in segs.size():
		if t >= float(segs[i][0]):
			idx = i
	var cur_state: String = str(segs[idx][1])
	var from_state: String = str(segs[idx - 1][1]) if idx > 0 else prev_state
	var start: float = float(segs[idx][0])
	var k := clampf((t - start) / BLEND_SECONDS, 0.0, 1.0)
	if idx == 0 and day > 1:
		# Overnight the weather has had time to settle: morning starts calmer
		# than the previous evening's storm, but not with a hard cut.
		from_state = "overcast" if prev_state in ["light_rain", "storm"] else prev_state
		k = clampf((t + BLEND_SECONDS * 0.5) / BLEND_SECONDS, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var a: Dictionary = STATES[from_state]
	var b: Dictionary = STATES[cur_state]
	for p in a:
		out[p] = lerpf(float(a[p]), float(b[p]), k)
	out["name"] = cur_state if k >= 0.5 else from_state
	out["plan"] = str(plan.name)
	out["blend"] = k
	# Wind direction: per-day prevailing direction with a slow drift.
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, day, "wind"])
	var ang := r.randf_range(-0.6, 0.6) + 0.64 + 0.18 * sin(t / 230.0 + float(day))
	out["wind_dir"] = Vector2(cos(ang), sin(ang))
	return out


func _clock_now() -> Array:
	if time_source.is_valid():
		return time_source.call()
	var hunt: Node = Game.hunt
	if hunt and hunt.call("hunt_active"):
		var ht: float = float(hunt.get("t"))
		return [int(hunt.get("hunt_day")) + int(ht / HuntService.CYCLE), fmod(ht, HuntService.CYCLE)]
	var cs: CampaignService = Game.campaign
	if cs and (cs.active or cs.test_route) and cs.clock:
		return [cs.clock.day, cs.clock.t]
	return []


## Preview / test override ("" returns to the schedule).
func set_override(state: String, instant := false) -> void:
	if state != "" and not STATES.has(state):
		return
	_override_from = {"cloud": cloud, "rain": rain, "wind": wind_mult, "storm": storm}
	_override_t = PREVIEW_BLEND if instant else 0.0
	override = state
	if instant and state != "":
		var s: Dictionary = STATES[state]
		cloud = s.cloud
		rain = s.rain
		wind_mult = s.wind
		storm = s.storm
		wetness = clampf(s.rain * 1.4, 0.0, 1.0)
		current_name = state
	_push(true)


func _target() -> Dictionary:
	if override != "":
		var s: Dictionary = STATES[override].duplicate()
		var k := clampf(_override_t / PREVIEW_BLEND, 0.0, 1.0)
		var out := {}
		for p in s:
			out[p] = lerpf(float(_override_from.get(p, s[p])), float(s[p]), k)
		out["name"] = override
		out["plan"] = "preview"
		out["wind_dir"] = wind_dir
		return out
	var now := _clock_now()
	if now.is_empty():
		var c: Dictionary = STATES["clear"].duplicate()
		c["name"] = "clear"
		c["plan"] = "none"
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
	_update_audio()
	_push_t -= delta
	if _push_t <= 0.0 or flash > 0.001:
		_push_t = 0.2
		_push(false)


func _push(force: bool) -> void:
	var env: EnvironmentController = Game.environment
	if env:
		env.set_weather(cloud, rain, wind_mult, wind_dir, wetness, flash, force)
	for v in views:
		if is_instance_valid(v):
			v.set_rain(rain, wind_dir, wind_mult)


# ------------------------------------------------------------ lightning

## Distant storm only: flashes far out at sea, thunder delayed by distance.
## Purely cosmetic: no SoundEvents (no AI evidence), no Terror triggers, no
## lamp or safety change. Follows the flash-reduction comfort setting.
func _update_lightning(delta: float) -> void:
	if _flash_t >= 0.0:
		_flash_t += delta
		var mode := str(Settings.get_v("flash_reduction"))
		var raw := 0.0
		if mode == "full":
			raw = exp(-_flash_t * 9.0) + 0.6 * exp(-absf(_flash_t - 0.18) * 30.0)
		elif mode == "reduced":
			# Slow, dim swell instead of a strobe.
			raw = 0.22 * sin(clampf(_flash_t / 1.2, 0.0, 1.0) * PI)
		flash = clampf(raw, 0.0, 1.0)
		if _flash_t > 1.3:
			_flash_t = -1.0
			flash = 0.0
	if _thunder_due >= 0.0:
		_thunder_due -= delta
		if _thunder_due < 0.0:
			_play_thunder()
	if storm < 0.5:
		_next_flash = maxf(_next_flash, 12.0)
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = _cos_rng.randf_range(18.0, 55.0)
		_flash_t = 0.0
		flashes += 1
		var dist := _cos_rng.randf_range(2200.0, 4500.0)
		_thunder_due = minf(dist / 343.0, 12.0)
		_thunder_ang = _cos_rng.randf_range(0.0, TAU)
		_thunder_db = lerpf(-8.0, -16.0, (dist - 2200.0) / 2300.0)


func _play_thunder() -> void:
	thunders += 1
	if SoundService.instance() != null:
		# From the flash direction, already delayed by its real distance.
		var lp := _listener()
		var dir := Vector3(cos(_thunder_ang), 0, sin(_thunder_ang))
		SoundService.play("weather.thunder.far", lp + dir * 400.0 + Vector3(0, 120, 0), {"no_delay": true, "db": _thunder_db + 10.0})
		return
	var s: AudioStream = load("res://audio/generated/thunder_far_%d.wav" % (thunders % 2))
	if s == null:
		return
	_thunder.stream = s
	_thunder.volume_db = _thunder_db - shelter * 3.0
	_thunder.play()


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
var _thunder_ang := 0.0
var _roof_kind := ""
var _roof_t := 0.0


func _update_audio() -> void:
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
	_rain_layer("light_l", "weather.rain.light", _rain_pts[0], r * (1.0 - heavy * 0.6), -2.0)
	_rain_layer("light_r", "weather.rain.light", _rain_pts[1], r * (1.0 - heavy * 0.6), -2.0)
	_rain_layer("heavy", "weather.rain.heavy", _rain_pts[0], r * heavy, 0.0)
	# The roof right above you, by what it is made of (rechecked 4x/s).
	_roof_t -= 0.25
	if _roof_t <= 0.0:
		_roof_t = 1.0
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
	for k in ["metal", "wood", "canvas"]:
		_rain_layer("roof_" + k, "weather.rain." + k, _rain_pts[2], r if _roof_kind == k else 0.0, -2.0)
	_rain_layer("drips", "weather.rain.drips", _rain_pts[2], r * (0.6 if _roof_kind != "" else 0.0), 0.0)


func _rain_layer(key: String, event: String, at: Node3D, lin: float, top_db: float) -> void:
	var h := int(_rain_h.get(key, 0))
	if lin < 0.01:
		if h != 0:
			SoundService.loop_stop(h, 0.6)
			_rain_h.erase(key)
		return
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
	return {"seed": seed_value, "wetness": snappedf(wetness, 0.001), "version": 1}


func restore(d: Dictionary) -> void:
	seed_value = int(d.get("seed", seed_value))
	wetness = clampf(float(d.get("wetness", 0.0)), 0.0, 1.0)
	override = ""
	_process(0.0)
	_push(true)
