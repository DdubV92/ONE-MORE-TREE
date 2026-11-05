class_name RCSmoke
extends Node
## Phase 20 release-candidate smoke route for the EXPORTED build (run from a
## clean folder by CI on Linux and Windows):
##   OneMoreTree(.exe) --headless -- --rc-smoke
## Steps: offline boot -> settings persist across a reload from disk -> a
## new standard campaign (10,000 native trees, five employees) in a
## dedicated slot -> the movement controls exist and move the boss ->
## save -> load the campaign again and compare day/time/cash -> quit.
## Writes user://rc_smoke.json and prints "RC_SMOKE PASS|FAIL ...".
## Uses save slot 3 only (never the player's slots 1-2).

const SLOT := 3
var report := {"steps": {}, "boot_ms": 0}
var _fail := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _step(name: String, ok: bool, detail: Variant = "") -> void:
	report.steps[name] = {"ok": ok, "detail": detail}
	print("RC_SMOKE step %s: %s %s" % [name, "ok" if ok else "FAIL", str(detail)])
	if not ok and _fail == "":
		_fail = name


func _wait_world(max_frames := 3600) -> IslandWorld:
	var g := 0
	while g < max_frames:
		await get_tree().process_frame
		g += 1
		var w := Game.world_root as IslandWorld
		if w != null and is_instance_valid(w) and w.systems_ready and Game.campaign != null and Game.player != null:
			for k in 30:
				await get_tree().physics_frame
			return w
	return null


func _run() -> void:
	report.boot_ms = Time.get_ticks_msec()
	report["version"] = ProjectSettings.get_setting("application/config/version", "")
	var bi := FileAccess.get_file_as_string("res://build_info.json")
	report["build_info"] = JSON.parse_string(bi) if bi != "" else {}
	_step("boot", true, "%d ms to the smoke route" % report.boot_ms)
	# Settings persistence (real file round trip).
	var old: Variant = Settings.get_v("subtitle_time")
	Settings.set_v("subtitle_time", 1.35)
	Settings.values["subtitle_time"] = 1.0
	Settings.load_settings()
	_step("settings_persist", absf(float(Settings.get_v("subtitle_time")) - 1.35) < 0.001, Settings.get_v("subtitle_time"))
	Settings.set_v("subtitle_time", old)
	# Content shipped inside the export (JSON data read at runtime, voices).
	var bank := CrewBank.get_bank()
	var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/terror/recordings.json"))
	var sl: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/terror/sleep_interruptions.json"))
	var tb: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/terror/bank.json"))
	var feed_files := DirAccess.get_files_at("res://data/feed").size() if DirAccess.dir_exists_absolute("res://data/feed") else 0
	var offc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/offshore/survey_config.json"))
	var voice_ok := VoiceBank.count() > 3000 and VoiceBank.has("marta", "cut.marta.019") and load(VoiceBank.path("marta", "cut.marta.019")) != null
	var content := {"crew_lines": bank.lines.size(), "recordings": (rec as Dictionary).get("scenarios", []).size() if rec is Dictionary else 0,
		"interruptions": (sl as Dictionary).get("sequences", []).size() if sl is Dictionary else 0, "terror_events": (tb as Dictionary).get("events", []).size() if tb is Dictionary else 0,
		"feed_files": feed_files, "offshore_config": offc is Dictionary, "voice_clips_indexed": VoiceBank.count(), "voice_clip_loads": voice_ok,
		"sound_lib": load(SoundBank.path_of("door_impact")) != null and load(SoundBank.path_of("rotor_beat_loop")) != null}
	_step("content", int(content.crew_lines) >= 1796 and int(content.recordings) == 36 and int(content.interruptions) == 24 and int(content.terror_events) == 1300
		and int(content.feed_files) > 10 and bool(content.offshore_config) and voice_ok and bool(content.sound_lib), content)
	# A new standard campaign in the smoke slot.
	SaveService.slot = SLOT
	for p in [SaveService.save_path(), SaveService.save_path() + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	Game.new_game = true
	Game.start_campaign()
	var w := await _wait_world()
	if w == null:
		_step("campaign_start", false, "world never became ready")
		_finish()
		return
	var emps := (Game.campaign.payroll.employees as Array).filter(func(e: Dictionary) -> bool: return str(e.status) == Payroll.ACTIVE).size()
	_step("standard_start", World.native_total() == 10000 and emps == 5, {"natives": World.native_total(), "employees": emps, "ruleset": str(Game.campaign.get("rule_set")), "island": World.island_revision})
	# Controls: actions exist and walking moves the boss.
	var actions := ["move_forward", "move_back", "move_left", "move_right", "interact", "jump", "pause"]
	var missing := actions.filter(func(a: String) -> bool: return not InputMap.has_action(a))
	var p0 := (Game.player as Node3D).global_position
	Input.action_press("move_forward")
	for k in 90:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var moved := (Game.player as Node3D).global_position.distance_to(p0)
	_step("controls", missing.is_empty() and moved > 0.5, {"missing": missing, "walked_m": snappedf(moved, 0.01)})
	# Save, then load the campaign again from disk.
	Game.campaign.clock.t = 123.0
	var cash0: int = Game.campaign.wallet.cash
	w.save_campaign()
	var summary := SaveService.slot_summary(SLOT)
	_step("save", not summary.is_empty() and FileAccess.file_exists(SaveService.save_path()), summary.get("status", ""))
	Game.new_game = false
	Game.start_campaign()
	var w2 := await _wait_world()
	if w2 == null:
		_step("load", false, "world never became ready after load")
		_finish()
		return
	_step("load", Game.campaign.clock.day == 1 and absf(Game.campaign.clock.t - 123.0) < 2.0 and Game.campaign.wallet.cash == cash0,
		{"day": Game.campaign.clock.day, "t": snappedf(Game.campaign.clock.t, 0.1), "cash": Game.campaign.wallet.cash, "expected_cash": cash0})
	_finish()


func _finish() -> void:
	report["result"] = "PASS" if _fail == "" else "FAIL"
	report["failed_step"] = _fail
	var f := FileAccess.open("user://rc_smoke.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, " "))
		f.close()
	print("RC_SMOKE %s %s" % [report.result, JSON.stringify(report.steps)])
	get_tree().quit(0 if _fail == "" else 1)
