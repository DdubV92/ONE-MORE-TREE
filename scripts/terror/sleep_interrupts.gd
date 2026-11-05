class_name SleepInterrupts
extends Node
## Phase 20 (the Phase 19 expansion's "interrupted sleep without trapping
## the player"): 24 authored rare sleep interruptions
## (data/terror/sleep_interruptions.json, tools/content/sleep_interruptions.py).
##
## States: idle -> settling (sleep requested; the screen dims) ->
## interrupted (the sequence plays at real points around the camper; the
## boss is awake; caption for muted play) -> resolving (it withdraws) ->
## available (sleep can be chosen again; it can't roll another one that
## night) -> the ordinary CampaignService.sleep() settles ONCE.
##
## Rules: contract nights only, from day 4, never the final contract day,
## never in the hunt; at most one per night; at least 3 quiet nights between
## interruptions and 8 between major ones; per-sequence cooldowns; many
## peaceful nights. Inside the camper nothing can hurt the boss, nothing
## forces an exit, a door opening or a camera turn. Awake time is charged as
## ordinary awake time plus a small bounded cost. Save/load in any state
## keeps the one-shot flag and resumes as "available".

signal state_changed(state: String)

const DATA := "res://data/terror/sleep_interruptions.json"
const P_NIGHT := 0.18
const MIN_GAP := 3
const MAJOR_GAP := 8
const SETTLE_S := 2.5
const RESOLVE_S := 3.0

var sequences: Array = []
var by_id := {}
var state := "idle"
var night := -1                # contract day of the night in progress
var seq := ""                  # current sequence id
var t := 0.0
var rolled := {}               # "day" -> sequence id or "" (decided once)
var last_day := -99
var last_major := -99
var used := {}                 # sequence id -> day
var history: Array = []
var morning_notes := {}        # "day" -> text shown after that night's sleep
var stats := {"rolled": 0, "interrupted": 0}
var _fired := {}
var _overlay: ColorRect
var _layer: CanvasLayer
var _visual: Node3D


func _ready() -> void:
	name = "SleepInterrupts"
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	sequences = (d as Dictionary).get("sequences", []) if d is Dictionary else []
	for q in sequences:
		by_id[str(q.id)] = q
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_overlay)


func _seed() -> int:
	if Game.campaign and Game.campaign.get("campaign_seed") != null:
		return int(Game.campaign.get("campaign_seed"))
	return 1717


func interrupted_night(d: int) -> bool:
	return str(rolled.get(str(d), "")) != ""


func busy() -> bool:
	return state in ["settling", "interrupted", "resolving"]


## The bed's sleep request goes through here first. Returns true when the
## request was consumed (an interruption starts or one is running).
func intercept(_by: Node) -> bool:
	var c: CampaignService = Game.campaign
	if c == null or not c.active:
		return false
	if busy():
		return true
	if not bool(c.can_sleep().ok):
		return false
	var d := c.clock.day
	if state == "available" and night == d:
		state = "idle"          # the one-shot: this night's sleep now settles normally
		return false
	if rolled.has(str(d)):
		return false
	var pick := roll(d)
	if pick == "":
		return false
	start(pick, d)
	return true


## Decides the night once (deterministic per campaign and day).
func roll(d: int) -> String:
	var c: CampaignService = Game.campaign
	rolled[str(d)] = ""
	stats.rolled = int(stats.rolled) + 1
	if d < 4 or (c.clock.is_final_day() and not c.legacy) or (Game.hunt and Game.hunt.hunt_active()):
		return ""
	if d - last_day < MIN_GAP + 1:
		return ""
	if not _in_camper():
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%d:sleep" % [_seed(), d])
	if r.randf() > P_NIGHT:
		return ""
	var pool := []
	for q in sequences:
		var qid := str(q.id)
		if used.has(qid) and d - int(used[qid]) < int(q.cooldown):
			continue
		if bool(q.major) and d - last_major < MAJOR_GAP:
			continue
		if not _requires_ok(q):
			continue
		pool.append([float(q.weight) * r.randf_range(0.2, 1.0), qid])
	if pool.is_empty():
		return ""
	pool.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var pick := str(pool[0][1])
	rolled[str(d)] = pick
	return pick


func _requires_ok(q: Dictionary) -> bool:
	for tok in q.requires:
		match str(tok):
			"dog":
				if not NightAnchors.dog_home():
					return false
			"cabin_occupied":
				if not NightAnchors.cabin_occupied():
					return false
			"truck":
				if not NightAnchors.has_truck_near_camp():
					return false
	for st in q.steps:
		if NightAnchors.point(str(st[2])) == Vector3.INF:
			return false
	return true


func _in_camper() -> bool:
	var c := NightAnchors.camper()
	var p := Game.player as Node3D
	if c == null or p == null:
		return true
	var l := c.global_transform.affine_inverse() * p.global_position
	return CampLayout.camper_local_inside(l, 0.3)


func start(id: String, d: int) -> void:
	seq = id
	night = d
	t = 0.0
	_fired.clear()
	state = "settling"
	used[id] = d
	last_day = d
	if bool(by_id[id].major):
		last_major = d
	stats.interrupted = int(stats.interrupted) + 1
	history.append({"day": d, "id": id})
	if history.size() > 40:
		history.pop_front()
	if str(by_id[id].morning) != "":
		morning_notes[str(d)] = str(by_id[id].morning)
	if Game.player and Game.player.has_method("show_message"):
		Game.player.show_message("You settle into bed...")
	state_changed.emit(state)


func _process(delta: float) -> void:
	if not busy() or get_tree().paused:
		_overlay.color.a = move_toward(_overlay.color.a, 0.0, delta * 2.0)
		return
	step(delta)


## Advances the sequence (also driven directly by tests).
func step(delta: float) -> void:
	t += delta
	var q: Dictionary = by_id.get(seq, {})
	match state:
		"settling":
			_overlay.color.a = clampf(t / SETTLE_S, 0.0, 0.85)
			if t >= SETTLE_S:
				state = "interrupted"
				t = 0.0
				_overlay.color.a = 0.0         # woken: full view, no forced turn
				if Game.campaign:
					Game.campaign.notice.emit(str(q.caption), maxf(float(q.duration) * 0.6, 4.0))
				if Game.rest:
					Game.rest.interrupt(night, float(q.rest_cost))
				_start_visual(str(q.visual))
				state_changed.emit(state)
		"interrupted":
			for i in (q.steps as Array).size():
				var st: Array = q.steps[i]
				if not _fired.has(i) and t >= float(st[0]):
					_fired[i] = true
					var at := NightAnchors.point(str(st[2]))
					if at != Vector3.INF:
						SoundService.play(str(st[1]), at, {"db": float(st[3]), "priority": 3})
			_update_visual(delta)
			if t >= float(q.duration):
				state = "resolving"
				t = 0.0
				_end_visual()
				state_changed.emit(state)
		"resolving":
			if t >= RESOLVE_S:
				state = "available"
				if Game.player and Game.player.has_method("show_message"):
					Game.player.show_message("It's quiet again. You can try to sleep.")
				state_changed.emit(state)


## Shown with the morning report of the night it happened.
func morning_note(d: int) -> String:
	return str(morning_notes.get(str(d), ""))


# ----------------------------------------------------------------- visuals

func _start_visual(kind: String) -> void:
	_end_visual()
	match kind:
		"window_shape", "window_shape_l":
			var anchor := "camper_window_r" if kind == "window_shape" else "camper_window_l"
			var p := NightAnchors.point(anchor)
			if p == Vector3.INF:
				return
			_visual = Node3D.new()
			_visual.name = "WindowShape"
			get_parent().add_child(_visual)
			var dark := SurveyShip._m(Color(0.02, 0.02, 0.025), 1.0, 0.0)
			var body := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.24
			cm.height = 1.7
			body.mesh = cm
			body.material_override = dark
			_visual.add_child(body)
			_visual.global_position = p + Vector3(0, -0.5, 0) + _outward(anchor) * 0.9
			_visual.set_meta("dir", (NightAnchors.camper().global_basis.z if NightAnchors.camper() else Vector3.FORWARD))
		"door_shudder":
			var door := Game.world_root.find_child("CamperDoor", true, false) as Node3D if Game.world_root else null
			if door:
				_visual = door
				_visual.set_meta("shudder_base", door.rotation.y)
		"hush":
			var i := AudioServer.get_bus_index("Ambience")
			if i >= 0:
				AudioServer.set_bus_volume_db(i, AudioServer.get_bus_volume_db(i) - 12.0)
				set_meta("hushed", true)


func _outward(anchor: String) -> Vector3:
	var c := NightAnchors.camper()
	if c == null:
		return Vector3.ZERO
	return (-c.global_basis.x if anchor == "camper_window_r" else c.global_basis.x).normalized()


func _update_visual(delta: float) -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	if _visual.name == "WindowShape":
		_visual.global_position += (_visual.get_meta("dir") as Vector3) * delta * 1.4
	elif _visual.has_meta("shudder_base"):
		var base := float(_visual.get_meta("shudder_base"))
		_visual.rotation.y = base + (sin(t * 70.0) * 0.012 * exp(-t * 4.0) if t < 1.5 else 0.0)


func _end_visual() -> void:
	if _visual and is_instance_valid(_visual):
		if _visual.name == "WindowShape":
			_visual.queue_free()
		elif _visual.has_meta("shudder_base"):
			_visual.rotation.y = float(_visual.get_meta("shudder_base"))
			_visual.remove_meta("shudder_base")
	_visual = null
	if has_meta("hushed"):
		var i := AudioServer.get_bus_index("Ambience")
		if i >= 0:
			AudioServer.set_bus_volume_db(i, AudioServer.get_bus_volume_db(i) + 12.0)
		remove_meta("hushed")


# ------------------------------------------------------------------ saving

func capture_state() -> Dictionary:
	return {"version": 1, "state": state, "night": night, "seq": seq, "rolled": rolled.duplicate(), "last_day": last_day, "last_major": last_major,
		"used": used.duplicate(), "history": history.duplicate(true), "morning": morning_notes.duplicate(), "stats": stats.duplicate()}


## A save taken mid-sequence resumes as "available": the night's one-shot
## flag and the ability to sleep are kept; nothing replays.
func restore_state(d: Dictionary) -> void:
	_end_visual()
	_overlay.color.a = 0.0
	state = str(d.get("state", "idle"))
	night = int(d.get("night", -1))
	seq = str(d.get("seq", ""))
	rolled = (d.get("rolled", {}) as Dictionary).duplicate()
	last_day = int(d.get("last_day", -99))
	last_major = int(d.get("last_major", -99))
	used = (d.get("used", {}) as Dictionary).duplicate()
	history = (d.get("history", []) as Array).duplicate(true)
	morning_notes = (d.get("morning", {}) as Dictionary).duplicate()
	if d.has("stats"):
		stats = (d.stats as Dictionary).duplicate()
	if state in ["settling", "interrupted", "resolving"]:
		state = "available"
	t = 0.0
