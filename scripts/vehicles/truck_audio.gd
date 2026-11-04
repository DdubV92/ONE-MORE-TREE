class_name TruckAudio
extends Node3D
## Phase 15: the pickup's sound from its real state, through SoundService
## (positional, per-source occlusion, camera microphones). Engine layers
## (idle / low / mid / high, original 4-stroke firing model) crossfade by
## engine speed; tyres follow the actual surface under the truck and road
## speed; the cargo rattles only when loaded AND moving; starting and
## stopping the engine play once per transition. Doppler stays off (seated
## driving and camera cuts never pitch-swing). Loops are owned handles:
## freeing the truck stops them.

const LAYERS := ["idle", "low", "mid", "high"]
const CENTRES := [0.0, 0.33, 0.62, 0.95]
var _on := false
var _rpm := 0.0
var _speed := 0.0
var _h := {}
var _tire_kind := ""
var _t_surface := 0.0


func set_state(speed01: float, throttle01: float, engine_on: bool) -> void:
	if engine_on != _on:
		_on = engine_on
		if SoundService.instance() != null:
			SoundService.play("truck.start" if engine_on else "truck.stop", self, {"emit": engine_on})
	_rpm = lerpf(_rpm, clampf(0.1 + speed01 * 0.7 + throttle01 * 0.25, 0.0, 1.0), 0.08)
	_speed = speed01


func _layer(key: String, event: String, db: float, on: bool) -> void:
	var h := int(_h.get(key, 0))
	if not on or db < -60.0:
		if h != 0:
			SoundService.loop_stop(h, 0.3)
			_h.erase(key)
		return
	if h == 0 or not SoundService.is_playing(h):
		h = SoundService.loop(event, self, {"gain": db})
		_h[key] = h
	SoundService.loop_set(h, db, 0.85 + _rpm * 0.35)


func _process(delta: float) -> void:
	if SoundService.instance() == null:
		return
	for i in LAYERS.size():
		var w := clampf(1.0 - absf(_rpm - CENTRES[i]) / 0.33, 0.0, 1.0)
		_layer("eng_" + LAYERS[i], "truck.engine." + LAYERS[i], linear_to_db(maxf(w, 0.0001)), _on and w > 0.01)
	_t_surface -= delta
	if _t_surface <= 0.0:
		_t_surface = 0.5
		var p := global_position
		var s := World.surface_at(p.x, p.z)
		var kind := "truck.tire.dirt"
		if s == World.Surface.ROCK or s == World.Surface.SAND:
			kind = "truck.tire.gravel"
		elif s == World.Surface.GRASS or s == World.Surface.FOREST:
			kind = "truck.tire.grass"
		if kind != _tire_kind:
			_layer("tire", "", 0.0, false)
			_tire_kind = kind
	_layer("tire", _tire_kind, linear_to_db(maxf(_speed, 0.0001)) + 2.0, _speed > 0.04)
	var tr := get_parent()
	var loaded: bool = tr != null and tr.has_method("cargo_mte") and int(tr.call("cargo_mte")) > 0
	_layer("cargo", "truck.cargo.rattle", linear_to_db(maxf(_speed, 0.0001)), loaded and _speed > 0.05)
