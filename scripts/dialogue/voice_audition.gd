class_name VoiceAudition
extends Node3D
## Phase 18 audition route (Preview): real bank lines through the real
## speech path (SoundService.speak: positional, occluded, captioned), from a
## stand-in speaker 3 m in front of you. One run at a time; a new stop or
## leaving stops the current one.

static var _cur: VoiceAudition
var _marker: Node3D


static func start(world: Node, which: String) -> String:
	if _cur and is_instance_valid(_cur):
		_cur.queue_free()
	_cur = VoiceAudition.new()
	world.add_child(_cur)
	return _cur._run(which)


func _exit_tree() -> void:
	if _marker and is_instance_valid(_marker):
		SoundService.stop_speech(_marker)


func _ahead(d: float, side := 0.0) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var f := -cam.global_basis.z
	f.y = 0.0
	f = f.normalized()
	return cam.global_position + f * d + cam.global_basis.x * side + Vector3(0, -0.1, 0)


## The first line for `eid` whose delivery matches, from the given categories.
func _pick(eid: String, delivery: String, cats: Array) -> String:
	var bank := CrewBank.get_bank()
	var prof := CrewBank.voice_of(eid)
	var ids := bank.lines.keys()
	ids.sort()
	for id in ids:
		var ln: Dictionary = bank.lines[id]
		if str(ln.speaker) == eid and str(ln.cat) in cats and VoiceBank.has(prof, str(id)) and str(VoiceBank.info(prof, str(id)).delivery) == delivery:
			return str(id)
	return ""


func _say(prof: String, id: String, at: Vector3) -> float:
	if _marker == null:
		_marker = Node3D.new()
		add_child(_marker)
	_marker.global_position = at
	var vi := VoiceBank.info(prof, id)
	var ln := CrewBank.get_bank().line(id)
	var d := SoundService.speak(_marker, {"id": id, "voice": prof, "text": str(ln.get("text", "")), "db": float(VoiceBank.DB.get(str(vi.get("delivery", "calm")), -4.0))})
	if Game.campaign:
		Game.campaign.notice.emit("[%s · %s] %s" % [prof, str(vi.get("delivery", "")), str(ln.get("text", "")).replace("{listener}", "you")], maxf(d + 0.6, 2.5))
	return d


func _run(which: String) -> String:
	var names := {"EMP-01": "Marta", "EMP-02": "Dale", "EMP-03": "Priya", "EMP-04": "Tomas", "EMP-05": "Joan"}
	if which in names:
		_worker(which)
		return "%s: an ordinary line, a work callout and a tense line (subtitles show profile and delivery)." % names[which]
	match which:
		"exchange":
			_exchange()
			return "A real two-person exchange from the pair bank, spoken by both voices from two positions."
		"distance":
			_distance()
			return "The same line at 3 m, 12 m and 30 m (speech fades and dulls with distance)."
		"lineup":
			_lineup()
			return "All five voices at matching level: one calm line each, left to right."
	return ""


func _worker(eid: String) -> void:
	var prof := CrewBank.voice_of(eid)
	var seq := [_pick(eid, "calm", ["camp", "pair", "boss", "weather"]), _pick(eid, "effort", ["cutting", "hauling", "tools"]), _pick(eid, "whisper", ["survival"])]
	if seq[2] == "":
		seq[2] = _pick(eid, "uneasy", ["dusk", "survival"])
	for id in seq:
		if id == "":
			continue
		var d := _say(prof, id, _ahead(3.0))
		await get_tree().create_timer(d + 0.8, false).timeout


func _exchange() -> void:
	var bank := CrewBank.get_bank()
	var ids := bank.lines.keys()
	ids.sort()
	for id in ids:
		var ln: Dictionary = bank.lines[id]
		if str(ln.cat) != "pair" or bool(ln.get("reply", false)) or (ln.get("resp", []) as Array).is_empty() or not str(ln.speaker).begins_with("EMP-"):
			continue
		var r := str(ln.resp[0])
		var rl := bank.line(r)
		if not str(rl.get("speaker", "")).begins_with("EMP-"):
			continue
		var pa := CrewBank.voice_of(str(ln.speaker))
		var pb := CrewBank.voice_of(str(rl.speaker))
		if not VoiceBank.has(pa, str(id)) or not VoiceBank.has(pb, r):
			continue
		var d := _say(pa, str(id), _ahead(3.0, -1.2))
		await get_tree().create_timer(d + 0.6, false).timeout
		d = _say(pb, r, _ahead(3.0, 1.2))
		await get_tree().create_timer(d + 0.6, false).timeout
		return


func _distance() -> void:
	var id := _pick("EMP-02", "calm", ["camp", "pair", "boss", "weather"])
	for dist in [3.0, 12.0, 30.0]:
		var d := _say("dale", id, _ahead(dist))
		await get_tree().create_timer(d + 0.8, false).timeout


func _lineup() -> void:
	var k := -2.0
	for eid in ["EMP-01", "EMP-02", "EMP-03", "EMP-04", "EMP-05"]:
		var id := _pick(eid, "calm", ["camp", "weather", "pair"])
		var d := _say(CrewBank.voice_of(eid), id, _ahead(4.0, k))
		k += 1.0
		await get_tree().create_timer(d + 0.6, false).timeout
