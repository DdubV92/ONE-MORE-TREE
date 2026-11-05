class_name Worker
extends Node3D
## One visible crew member (Phase 4). Walks real routes (CrewNav), works
## through the same authoritative APIs as the player (TreeService contacts,
## TimberService bucking / pickup / acceptance), carries a visible load,
## returns to an assigned bed before night, and never teleports.
##
## Activities: idle -> move -> fell / retreat / buck / pick / deliver /
## follow / home / sit / sleep / depart. Claims are released whenever an
## activity ends for any reason.

signal said(worker: Worker, text: String, important: bool)

const WALK := 1.45
const CARRY_WALK := 1.15
const TURN := 6.0
const ARRIVE := 0.35
const STUCK_WINDOW := 2.5
const SEARCH_RADIUS := 140.0

var crew: CrewService
var emp: Dictionary                 # payroll/roster record (shared dict)
var mind: WorkerMind
var body_char: HumanCharacter
var col: AnimatableBody3D
var id := ""

# movement
var path: Array[Vector3] = []
var _pi := 0
var _speed := 0.0
var _stuck_t := 0.0
var _stuck_from := Vector3.ZERO
var stuck_events := 0
var _repaths := 0
var travel_seconds := 0.0
var work_seconds := 0.0

# activity
var activity := "idle"
var target := {}                   # activity data
var _after_move := ""
var _swing_t := -1.0
var _contacted := false
var _decide_cd := 0.0
var _warned := {}
var _last_lines := {}
var _carry_nodes: Array[Node3D] = []
var talking_until := 0.0
var _far := false
var _time_check := 0.0
var seated := false
## Phase 16: why this worker is idle (set by the crew's decision with the
## real cause: no_task / yard_full / missing_tool / blocked / fear / pause).
var idle_reason := ""
var _hold_t := 0.0                 # bounded pickup handling time left
var _sync_t := -1.0                # two-person lift sync countdown
## Base handling and lift-sync times (shortened by handling / teamwork).
const PICK_HANDLE_S := 0.9
const TEAM_SYNC_S := 1.4


func setup(c: CrewService, record: Dictionary, m: WorkerMind) -> void:
	crew = c
	emp = record
	mind = m
	id = str(record.id)
	name = "Worker_" + id
	body_char = HumanCharacter.new()
	body_char.appearance = HumanAppearance.for_employee(id, int(record.get("look_seed", 1)))
	add_child(body_char)
	_flavor_rng.seed = hash(id)
	refresh_kit_visuals.call_deferred()
	body_char.step.connect(func(_side: int) -> void:
		if body_char.visible:
			get_tree().call_group("footstep_listeners", "play_crowd_step", global_position, _speed))
	col = AnimatableBody3D.new()
	col.sync_to_physics = false
	col.collision_layer = 1
	col.collision_mask = 0
	col.set_meta("worker_id", id)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.88, 0)
	col.add_child(cs)
	add_child(col)
	add_to_group("crew_workers")


## The equipped axe tier, "chainsaw" for a saw, "" for no cutting tool.
func axe_tier() -> String:
	var k := crew.kit(self)
	if str(k.tool) == "chainsaw":
		return "chainsaw"
	return str(k.tier) if str(k.tool) == "axe" else ""


## Shows the equipped tool and gear on the body.
func refresh_kit_visuals() -> void:
	if body_char == null:
		return
	body_char.set_axe_tier(axe_tier())
	var k := crew.kit(self)
	body_char.set_gear(str(k.get("boots", "")), str(k.get("gloves", "")), str(k.get("helmet", "")))
	if axe_tier() != "chainsaw" and saw.state != SawMachine.S.STOPPED:
		saw.kill()


## Phase 14 team carry: the team this worker belongs to ("" = none).
var team := ""


## Follower: walk to the far end of the log, wait for the lift, then carry
## the far end along the leader's actual path (breadcrumb trail).
func start_team_follow(tid: String) -> void:
	team = tid
	path.clear()
	_after_move = ""
	activity = "team_follow"
	target = {"team": tid, "label": "a long log", "team_ready": false}


func _do_team_follow(delta: float) -> void:
	var t: Dictionary = crew.coord.teams.get(team, {})
	if t.is_empty():
		activity = "idle"
		team = ""
		target = {}
		body_char.carry_grips = []
		return
	var leader: Worker = crew.workers.get(str(t.leader))
	if leader == null:
		crew.coord.break_team_of(self, "leader gone")
		return
	var goal: Vector3
	var sid := str(t.sid)
	var s := crew.timber.segment(sid)
	var rec: Dictionary = crew.timber.records.get(int(sid.trim_prefix("T").split("_S")[0]), {})
	var L := TimberMesh.piece_length(rec, int(s.k)) if not rec.is_empty() else 2.0
	if str(t.state) == "gather":
		var b := crew.timber.body_of(sid)
		if b == null:
			if crew.timber.load_of(leader.id).has(sid):
				crew.coord.lifted(team)
			return
		# The end of the log farther from the leader.
		var ends: Array = b.axis_samples(2)
		var e0: Vector3 = ends[0][0]
		var e1: Vector3 = ends[ends.size() - 1][0]
		var far := e0 if e0.distance_to(leader.global_position) > e1.distance_to(leader.global_position) else e1
		var off := (far - (e0 + e1) * 0.5).normalized()
		goal = far + off * 0.45
		target["team_ready"] = Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 1.1
	else:
		# Carry: L x 0.95 behind the leader along the leader's trail.
		var trail: Array = t.get("trail", [])
		var need := L * 0.95
		var acc := 0.0
		var prev := leader.global_position
		goal = prev + leader.global_basis.z * need
		for i in range(trail.size() - 1, -1, -1):
			var q: Vector3 = trail[i]
			var d := prev.distance_to(q)
			if acc + d >= need:
				goal = prev.lerp(q, (need - acc) / maxf(d, 0.001))
				break
			acc += d
			prev = q
	var to := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	var dist := to.length()
	var sp := 0.0
	if dist > 0.15:
		sp = minf(crew.coord.team_speed(team) * (1.6 if str(t.state) == "carry" else 1.0) + dist * 0.5, WALK * 1.4)
		var step := to.normalized() * minf(sp * delta, dist)
		var np := global_position + step
		np.y = crew.nav.surface_at(np)
		global_position = np
	if str(t.state) == "carry":
		_face(Vector3(leader.global_position.x - global_position.x, 0, leader.global_position.z - global_position.z).normalized(), delta * 4.0)
		var g0 := global_position + (leader.global_position - global_position).normalized() * 0.35 + Vector3(0, 0.85, 0)
		body_char.carry_grips = [g0 + global_basis.x * -0.15, g0 + global_basis.x * 0.15]
	body_char.set_locomotion(sp if dist > 0.15 else 0.0)


## Phase 14: the worker's chainsaw engine and its sound (only used while
## a saw is equipped).
var saw := SawMachine.new()
var saw_audio: SawAudio


func _saw_audio() -> SawAudio:
	if saw_audio == null:
		saw_audio = SawAudio.new()
		saw_audio.name = "SawAudio"
		saw_audio.who = id
		saw_audio.position = Vector3(0, 1.0, -0.6)
		add_child(saw_audio)
	return saw_audio


## One step of cutting work with the equipped tool (the caller has already
## validated the target, range and facing). Axe: the worker's work per
## contact exactly once per swing at contact. Chainsaw: the engine starts
## once, then rate x SAW_TICK per completed loaded tick.
func _work_step(delta: float) -> float:
	var fx := crew.tool_effects(self)
	if str(fx.tool) == "chainsaw":
		if body_char.current != "saw":
			body_char.play("saw", 0.2)
		if saw.state == SawMachine.S.STOPPED:
			saw.start(float(fx.start_s))
		var n := saw.step(delta, saw.state != SawMachine.S.STARTING, true)
		work_seconds += delta
		return float(n) * float(fx.saw_rate) * ToolEffects.SAW_TICK
	return float(fx.work_per_contact) if _swing(delta) else 0.0


## Saw upkeep every frame: cutting stops the moment the worker leaves a
## cutting job; the engine is switched off when they move on, carry, ride,
## sit, sleep, hide or flee.
func _saw_upkeep(delta: float) -> void:
	if saw.state == SawMachine.S.STOPPED and saw_audio == null:
		return
	if not activity in ["fell", "buck", "stump"]:
		if activity in ["retreat", "retreat_wait", "move", "idle"] and saw.running():
			saw.step(delta, false, false)
			if activity != "retreat_wait" and activity != "idle":
				saw.stop()
		elif saw.state != SawMachine.S.STOPPED:
			saw.kill()
		else:
			saw.step(delta, false, false)
	_saw_audio().update(saw, delta)


func trait_list() -> Array:
	return mind.traits


# ------------------------------------------------------------- interaction

func get_interact_text() -> String:
	return "Talk to %s (%s)" % [emp.name, activity_words()]


func interact(_by: Node) -> void:
	if Game.campaign_ui:
		Game.campaign_ui.open_talk(self)


func dragging_log() -> bool:
	return crew != null and is_carrying() and crew.timber.is_dragging(id, crew.carry_budget(self))


func activity_words() -> String:
	match activity:
		"fell": return "felling"
		"retreat": return "stepping clear of a fall"
		"buck": return "bucking a trunk"
		"stump": return "chopping out a stump"
		"hidden": return "hiding"
		"dead": return "dead"
		"pick", "deliver", "load_truck": return ("carrying a long log with a partner" if team != "" else "dragging a long log") if dragging_log() else "hauling"
		"team_follow": return "helping carry a long log"
		"deliver_deck": return "stacking logs on a yard deck"
		"yard_take", "yard_drop": return "yard work: moving paid logs"
		"seated": return "riding in a truck"
		"follow": return "following you"
		"home": return "heading home"
		"sit": return "resting"
		"sleep": return "asleep"
		"depart": return "leaving on the next boat"
		"arrive": return "arriving"
		"move":
			return "walking to " + str(target.get("label", "a job"))
	return "between jobs"


## Phase 8 presentation layer (cosmetic only, never changes jobs, claims,
## pay or timing): a frightened worker stands guarded instead of relaxed,
## and between jobs each trait shows a restrained, interruptible idle.
var _idle_flavor_t := 9.0
var _flavor_rng := RandomNumberGenerator.new()


func witnessed_firsthand() -> bool:
	for m in mind.memories:
		if bool((m as Dictionary).get("firsthand", false)) and str((m as Dictionary).get("status", "")) == "confirmed":
			return true
	return false


func _presentation(delta: float) -> void:
	body_char.rest_clip = "fear" if mind.state >= WorkerMind.Fear.DISTRESSED and activity in ["idle", "retreat_wait"] else ""
	if activity == "seated":
		var want := "drive" if driving_seat() else "sit"
		if body_char.current != want:
			body_char.play(want, 0.3)
		return
	if not activity in ["idle", "retreat_wait"] or _speed > 0.05 or body_char.action != "":
		return
	_idle_flavor_t -= delta
	if _idle_flavor_t > 0.0:
		return
	_idle_flavor_t = _flavor_rng.randf_range(10.0, 22.0)
	var clip := ""
	if mind.has("timid") and _flavor_rng.randf() < 0.6:
		clip = "glance"
	elif mind.has("hard_working") and _flavor_rng.randf() < 0.6:
		clip = "grip"
	elif mind.has("observant") and _flavor_rng.randf() < 0.6:
		clip = "listen"
	elif _flavor_rng.randf() < 0.25:
		clip = ["glance", "grip", "listen"][_flavor_rng.randi() % 3]
	if clip != "":
		body_char.play_action(clip, body_char.rest_clip if body_char.rest_clip != "" else "idle")


func driving_seat() -> bool:
	var p := get_parent()
	return p != null and str(p.name).to_lower().contains("driver")


func say(topic: String, important := false, vars := {}) -> String:
	var t := CrewDialogue.line(topic, mind.traits, _last_lines, vars)
	said.emit(self, t, important)
	return t


# ---------------------------------------------------------------- movement

func go_to(dest: Vector3, then: String, label := "") -> bool:
	var p := crew.nav.find_path(global_position, dest)
	if p.is_empty():
		return false
	path = p
	_pi = 1 if p.size() > 1 else 0
	_after_move = then
	target["dest"] = dest
	target["label"] = label
	activity = "move"
	_stuck_t = 0.0
	_stuck_from = global_position
	return true


func _move(delta: float) -> void:
	if _pi >= path.size():
		_arrived()
		return
	var wp := path[_pi]
	var to := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z)
	var dist := to.length()
	if dist < ARRIVE or (_pi < path.size() - 1 and dist < 0.9):
		_pi += 1
		return
	var dir := to / maxf(dist, 0.001)
	dir = _avoid(dir)
	var want := (CARRY_WALK if is_carrying() else WALK)
	if is_carrying() and crew.timber.is_dragging(id, crew.carry_budget(self)):
		want = CARRY_WALK * 0.5           # dragging an oversized log
		if team != "" and str(crew.coord.teams.get(team, {}).get("state", "")) == "carry":
			want = crew.coord.team_speed(team) / maxf(float(crew.tool_effects(self).walk_mult), 0.01)   # boots applied below
			crew.coord.trail_point(team, global_position)
	if mind.state >= WorkerMind.Fear.DISTRESSED and activity == "move" and _after_move == "home":
		want *= 1.12       # hurrying home
	want *= float(crew.tool_effects(self).walk_mult)   # boots (one pair)
	_speed = move_toward(_speed, want, delta * 3.0)
	var step := dir * _speed * delta
	var np := global_position + step
	np.y = crew.nav.surface_at(np)
	if absf(np.y - global_position.y) > 0.6:
		np.y = lerpf(global_position.y, np.y, 0.5)
	global_position = np
	_face(dir, delta)
	travel_seconds += delta
	crew.open_doors_near(global_position)
	body_char.set_locomotion(_speed)
	# Stuck detection: real displacement vs expected over a window.
	_stuck_t += delta
	if _stuck_t >= STUCK_WINDOW:
		var moved := Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
		if moved < want * STUCK_WINDOW * 0.25:
			_on_stuck()
		_stuck_t = 0.0
		_stuck_from = global_position


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * TURN, 0.0, 1.0))


## Local steering: step around trunks and other people instead of through.
func _avoid(dir: Vector3) -> Vector3:
	var p := global_position
	var push := Vector3.ZERO
	var dest: Vector3 = target.get("dest", Vector3.INF)
	for t in crew.nav.trunks_near(p, 2.2):
		var d := Vector3(p.x - t.x, 0, p.z - t.z)
		var r := t.y + 0.45
		var L := d.length()
		# The trunk we are walking up to (felling/standing beside) is the goal,
		# not an obstacle.
		if dest != Vector3.INF and Vector2(dest.x - t.x, dest.z - t.z).length() < t.y + 1.6:
			continue
		if L < r + 0.6 and dir.dot(-d.normalized()) > 0.2:
			var side := Vector3(-dir.z, 0, dir.x)
			if side.dot(d) < 0:
				side = -side
			push += side * (r + 0.6 - L) * 1.5
	for w in crew.workers.values():
		if w == self:
			continue
		var d := Vector3(p.x - w.global_position.x, 0, p.z - w.global_position.z)
		if d.length() < 0.8 and d.length() > 0.01:
			push += d.normalized() * (0.8 - d.length()) * 2.0
	if Game.player:
		var d := Vector3(p.x - Game.player.global_position.x, 0, p.z - Game.player.global_position.z)
		if d.length() < 0.9 and d.length() > 0.01:
			push += d.normalized() * (0.9 - d.length()) * 2.0
	return (dir + push).normalized() if push.length() > 0.001 else dir


func _on_stuck() -> void:
	stuck_events += 1
	_repaths += 1
	crew.log_stuck(self)
	if _repaths > 3:
		crew.mark_unreachable(self)
	if _repaths <= 3:
		var dest: Vector3 = target.get("dest", global_position)
		# Small local escape, then a fresh path.
		var side := global_basis.x * (1.0 if _repaths % 2 == 0 else -1.0)
		var esc := global_position + side * 1.2
		if crew.nav.walkable(esc):
			esc.y = crew.nav.surface_at(esc)
			global_position = global_position.lerp(esc, 0.25)
		var p := crew.nav.find_path(global_position, dest)
		if not p.is_empty():
			path = p
			_pi = 1 if p.size() > 1 else 0
			return
	# Give up on this job: release claims, think again. (Never teleport.)
	_repaths = 0
	abandon("stuck")


func _arrived() -> void:
	_speed = 0.0
	_repaths = 0
	body_char.set_locomotion(0.0)
	var next := _after_move
	_after_move = ""
	activity = next if next != "" else "idle"
	_swing_t = -1.0


func is_carrying() -> bool:
	return not crew.timber.load_of(id).is_empty()


# -------------------------------------------------------------- the brain

func _physics_process(delta: float) -> void:
	if crew == null or get_tree().paused:
		return
	var now := crew.now()
	mind.tick(delta, now, crew.mind_context(self))
	_presentation(delta)
	if talking_until > now and activity in ["idle", "fell", "buck", "pick", "move"]:
		body_char.set_locomotion(0.0)
		# Delivery differs, knowledge does not: someone who actually saw
		# something firsthand talks guarded; a skeptic talks loose.
		if body_char.action == "":
			body_char.play("talk_shaken" if witnessed_firsthand() else "talk", 0.3)
		if Game.player:
			_face(Vector3(Game.player.global_position.x - global_position.x, 0, Game.player.global_position.z - global_position.z).normalized(), delta)
		return
	_update_lod()
	_saw_upkeep(delta)
	# Long jobs re-check the clock: a far worker turns back in time, even in
	# the middle of a task (claims released, load handled by the crew).
	_time_check -= delta
	if _time_check <= 0.0:
		_time_check = 3.0
		if activity in ["fell", "buck", "stump", "pick", "follow", "retreat_wait"] or (activity == "move" and not _after_move in ["home_arrived", "depart_wait", "deliver", "hide_enter", "board"]):
			crew.check_time(self)
	match activity:
		"move":
			_move(delta)
		"fell":
			_do_fell(delta)
		"retreat_wait":
			_do_retreat_wait(delta)
		"buck":
			_do_buck(delta)
		"stump":
			_do_stump(delta)
		"pick":
			_do_pick()
		"deliver":
			_do_deliver()
		"deliver_deck":
			_do_deliver_deck()
		"yard_take":
			_do_yard_take()
		"yard_drop":
			_do_yard_drop()
		"load_truck":
			_do_load_truck()
		"follow":
			_do_follow(delta)
		"team_follow":
			_do_team_follow(delta)
		"sleep", "sit", "departed", "aboard", "seated", "hidden", "dead", "board":
			pass
		"hide_enter":
			_enter_hide()
		"depart_wait":
			body_char.set_locomotion(0.0)
		"home_arrived":
			crew.on_home(self)
		_:
			_decide_cd -= delta
			if _decide_cd <= 0.0:
				_decide_cd = 0.7
				crew.decide(self)
	_update_carry_visual()


func _update_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var far := cam.global_position.distance_to(global_position) > 160.0
	if far != _far:
		_far = far
		body_char.visible = not far
		body_char.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT


## Ends the current activity safely: claims released, load kept (the crew
## service decides whether to stage it), swing stopped.
## Phase 16: a job reached its useful end. A short break follows (ethic);
## it only counts as a break if there was work waiting afterwards.
func job_done(kind: String) -> void:
	crew.progression.on_job_finished(id, kind)
	idle_reason = "pause"
	_decide_cd = crew.progression.pause_after_job(id)


func abandon(reason: String) -> void:
	if reason in ["cut done", "stump out"]:
		crew.progression.on_job_finished(id, reason)
		idle_reason = "pause"
		_decide_cd = crew.progression.pause_after_job(id)
	elif not reason in ["time to go home", "departing", "dead", "boarding", "hiding"]:
		crew.progression.on_job_dropped(id, {"stuck": "blocked route", "refusing risk": "fear"}.get(reason, reason))
	crew.coord.break_team_of(self, reason)
	crew.release_claims(self)
	path.clear()
	_after_move = ""
	activity = "idle"
	target = {"why": reason}
	_swing_t = -1.0
	body_char.set_locomotion(0.0)


# ---------------------------------------------------------- felling action

func start_fell(tree_id: int, stand: Vector3, retreat: Vector3) -> bool:
	crew.progression.on_job_started(id, "fell")
	target = {"tree": tree_id, "stand": stand, "retreat": retreat, "label": "a tree"}
	if global_position.distance_to(stand) > 0.6:
		if not go_to(stand, "fell", "a tree"):
			return false
		target["tree"] = tree_id
		target["stand"] = stand
		target["retreat"] = retreat
	else:
		activity = "fell"
	return true


func _swing_cycle() -> float:
	return float(crew.tool_effects(self).cycle_s)


## Advances one swing; returns true exactly once per swing at contact.
func _swing(delta: float) -> bool:
	var cyc := _swing_cycle()
	if _swing_t < 0.0:
		_swing_t = 0.0
		_contacted = false
		body_char.play("swing", 0.1)
		body_char.playback_scale = 1.7 / cyc
		body_char.anim.seek(0.0, true)
	_swing_t += delta
	work_seconds += delta
	var hit := false
	if not _contacted and _swing_t >= cyc * crew.work_config.contact_fraction:
		_contacted = true
		hit = true
	if _swing_t >= cyc:
		_swing_t = 0.0
		_contacted = false
		body_char.anim.seek(0.0, true)
	return hit


func _do_fell(delta: float) -> void:
	var tid: int = target.get("tree", -1)
	var st := Game.trees.state_of(tid)
	if st != TreeService.State.STANDING and st != TreeService.State.NOTCHED:
		# Someone (maybe the boss) already felled it: step clear, stop.
		_begin_retreat()
		return
	var base := World.tree_position(Game.vegetation.tree_index_by_id.get(tid, tid))
	_face(Vector3(base.x - global_position.x, 0, base.z - global_position.z).normalized(), delta * 3.0)
	var wk := _work_step(delta)
	if wk > 0.0:
		var res := Game.trees.apply_contact(tid, global_position, wk, id)
		if bool(res.get("accepted", false)):
			crew.contributions.add_work(id, wk)
		if saw.state == SawMachine.S.STOPPED:
			LoggingFX.play(LoggingFX.Sound.CHOP, base + Vector3(0, 0.8, 0), 0.0, {"tree": tid})
		if bool(res.get("felled", false)):
			crew.on_felled(self, tid)
			_begin_retreat()


func _begin_retreat() -> void:
	body_char.play("idle")
	_swing_t = -1.0
	var r: Vector3 = target.get("retreat", global_position)
	var tid: int = target.get("tree", -1)
	crew.release_claims(self)
	target = {"tree": tid, "since": crew.now()}
	if go_to(r, "retreat_wait", "a safe spot"):
		target["tree"] = tid
		target["since"] = crew.now()
	else:
		activity = "retreat_wait"


func _do_retreat_wait(_delta: float) -> void:
	# Watch the fall; resume once it has come to rest (or after a while).
	var tid: int = target.get("tree", -1)
	var st := Game.trees.state_of(tid)
	if st >= TreeService.State.SECTIONED or crew.now() - float(target.get("since", 0.0)) > 20.0:
		activity = "idle"
		job_done("fell")


# ---------------------------------------------------------- bucking action

func start_buck(body: TimberBody, y: float, stand: Vector3) -> bool:
	crew.progression.on_job_started(id, "buck")
	var tree_id := body.tree_id
	if global_position.distance_to(stand) > 0.6:
		if not go_to(stand, "buck", "a fallen trunk"):
			return false
	else:
		activity = "buck"
	target["tree"] = tree_id
	target["y"] = y
	target["stand"] = stand
	return true


func _do_buck(delta: float) -> void:
	var tid: int = target.get("tree", -1)
	var y: float = target.get("y", 0.0)
	var body := crew.body_for_cut(tid, y)
	if body == null:
		abandon("trunk changed")
		return
	var at := body.global_transform * Vector3(0, y, 0)
	_face(Vector3(at.x - global_position.x, 0, at.z - global_position.z).normalized(), delta * 3.0)
	if global_position.distance_to(at) > 2.6:
		abandon("moved away")
		return
	var wk := _work_step(delta)
	if wk > 0.0:
		var res := crew.timber.apply_cut(body, y, wk, id)
		if str(res.get("reason", "")) == "wait":
			return
		if not bool(res.get("accepted", false)):
			abandon("no cut there")
			return
		crew.contributions.add_work(id, wk)
		if saw.state == SawMachine.S.STOPPED:
			LoggingFX.play(LoggingFX.Sound.CHOP, at, 0.0, {"event": "work.axe.buck"})
		if bool(res.get("separated", false)):
			crew.on_bucked(self)
			abandon("cut done")


## Phase 7: chop out a stump (shared claims; same swing and work rate).
func start_stump(tree_id: int, base: Vector3, stand: Vector3) -> bool:
	crew.progression.on_job_started(id, "stump")
	target["tree"] = tree_id
	target["stump_at"] = base
	target["stand"] = stand
	target["label"] = "a stump"
	if global_position.distance_to(stand) > 0.6:
		return go_to(stand, "stump", "a stump")
	activity = "stump"
	return true


func _do_stump(delta: float) -> void:
	var tid: int = target.get("tree", -1)
	var at: Vector3 = target.get("stump_at", global_position)
	_face(Vector3(at.x - global_position.x, 0, at.z - global_position.z).normalized(), delta * 3.0)
	if global_position.distance_to(at) > 2.8:
		abandon("moved away")
		return
	var wk := _work_step(delta)
	if wk > 0.0:
		var res := crew.trees.apply_stump_work(tid, wk, id)
		if not bool(res.get("accepted", false)):
			abandon("no stump there")
			return
		if saw.state == SawMachine.S.STOPPED:
			LoggingFX.play(LoggingFX.Sound.CHOP, at + Vector3(0, 0.3, 0), 0.0, {"event": "work.axe.stump"})
		crew.contributions.add_work(id, wk)
		if bool(res.get("removed", false)):
			crew.on_stump_removed(self, tid)
			abandon("stump out")


# --------------------------------------------------------- hauling actions

func start_pick(sids: Array) -> bool:
	crew.progression.on_job_started(id, "pick")
	target = {"pick": sids.duplicate(), "label": "logs"}
	return _next_pick()


func _next_pick() -> bool:
	var list: Array = target.get("pick", [])
	while not list.is_empty():
		var sid: String = list[0]
		var b := crew.timber.body_of(sid)
		if b == null or not b.is_single_piece():
			list.pop_front()
			crew.timber.release(sid, id)
			continue
		var at := b.piece_world_center(b.ks[0])
		var stand := crew.stand_beside(at, b.axis_samples(2), global_position)
		if global_position.distance_to(stand) < 0.8:
			activity = "pick"
			target["pick"] = list
			return true
		if go_to(stand, "pick", "logs"):
			target["pick"] = list
			return true
		list.pop_front()
		crew.timber.release(sid, id)
	# Nothing (left) to pick: deliver what we hold.
	if is_carrying():
		return crew.send_to_rack(self)
	activity = "idle"
	return false


func _do_pick() -> void:
	var list: Array = target.get("pick", [])
	if list.is_empty():
		_next_pick()
		return
	# Phase 14 team carry: both people in place before the lift.
	if team != "" and crew.coord.teams.has(team) and str(crew.coord.teams[team].state) == "gather" and not crew.coord.follower_ready(team):
		body_char.set_locomotion(0.0)
		_sync_t = -1.0
		return
	# Phase 16: then a short "on three" (teamwork of both shortens it).
	if team != "" and crew.coord.teams.has(team) and str(crew.coord.teams[team].state) == "gather":
		if _sync_t < 0.0:
			var fid := str(crew.coord.teams[team].follower)
			_sync_t = TEAM_SYNC_S * 0.5 * (crew.progression.team_wait(id) + crew.progression.team_wait(fid))
		_sync_t -= get_physics_process_delta_time()
		body_char.set_locomotion(0.0)
		if _sync_t > 0.0:
			return
		_sync_t = -1.0
	if team != "" and not crew.coord.teams.has(team):
		team = ""
	# Phase 16: getting a grip and lifting takes a moment before each piece
	# (handling skill shortens it, bounded).
	if str(target.get("hold_for", "")) != str(list[0]):
		target["hold_for"] = str(list[0])
		_hold_t = PICK_HANDLE_S * crew.progression.handling_time(id)
	if _hold_t > 0.0:
		_hold_t -= get_physics_process_delta_time()
		body_char.set_locomotion(0.0)
		return
	var sid: String = list.pop_front()
	var b := crew.timber.body_of(sid)
	if b != null:
		var res := crew.timber.pick_up_for(id, b, crew.carry_budget(self), bool(target.get("drag", false)))
		if bool(res.ok):
			# The transaction already happened; the bend is presentation.
			body_char.play_action("pickup")
			if team != "":
				crew.coord.lifted(team)
	else:
		crew.timber.release(sid, id)
	target["pick"] = list
	if list.is_empty():
		if is_carrying():
			crew.send_to_rack(self)
		else:
			activity = "idle"
	else:
		_next_pick()


func _do_deliver() -> void:
	var held: Array = crew.timber.load_of(id).duplicate()
	if not held.is_empty():
		var rs := crew.timber.accept(held, "rack:" + id, CampLayout.world(CampLayout.DELIVERY_RACK_POS))
		crew.on_delivered(self, rs)
		if not rs.is_empty():
			body_char.play_action("setdown")
		_set_down_unpaid()
	crew.release_rack_slot(self)
	activity = "idle"
	job_done("deliver")
	target.erase("drag")


## Phase 13: logs the yard could not take (no free place) are set down on
## the ground beside the receiving cradle - still unpaid, never lost - so a
## worker is never stuck holding them until night.
func _set_down_unpaid() -> void:
	var left: Array = crew.timber.load_of(id).duplicate()
	var k := 0
	for sid in left:
		if Game.yard and Game.yard.is_yard_move(str(sid)):
			continue
		var p := CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(-1.2 + 1.2 * (k % 3), 0.0, 3.2 + 0.7 * (k / 3)))
		crew.timber.put_down_for(id, str(sid), p + Vector3(0, 0.45, 0), Vector3.RIGHT, true)
		k += 1


## Phase 13: cradle full -> deliver onto a yard deck (accepted there).
func _do_deliver_deck() -> void:
	var held: Array = crew.timber.load_of(id).duplicate()
	var dk := int(target.get("deck", 0))
	if not held.is_empty():
		var rs := crew.timber.accept(held, "deck:" + id, CampLayout.world(CampLayout.YARD_DECKS[dk].center))
		crew.on_delivered(self, rs)
		if not rs.is_empty():
			body_char.play_action("setdown")
	activity = "idle"
	job_done("deliver_deck")
	target.erase("drag")


## Phase 13 yard: take one paid log from the cradle or a deck.
func _do_yard_take() -> void:
	var y: YardService = Game.yard
	var from := str(target.get("yard_from", ""))
	var sid := ""
	if y:
		if from == "cradle":
			sid = y.take_from_cradle(id, crew.carry_budget(self), global_position)
		elif from.begins_with("deck:"):
			sid = y.take_from_deck(id, int(from.get_slice(":", 1)), crew.carry_budget(self))
	crew.release_yard_claims(self)
	target.erase("yard_from")
	if sid == "":
		activity = "idle"
		return
	body_char.play_action("pickup")
	if not go_to(crew.yard_destination_point(sid), "yard_drop", "the yard"):
		y.return_to_origin(sid)
		activity = "idle"


## Puts the held paid log at its reserved place (or the nearest valid one).
func _do_yard_drop() -> void:
	var y: YardService = Game.yard
	var held: Array = crew.timber.load_of(id).duplicate()
	activity = "idle"
	job_done("yard_drop")
	if y == null or held.is_empty():
		return
	var sid: String = held[0]
	if not y.is_yard_move(sid):
		return
	var dest := str(y.moving[sid].dest)
	var ok := false
	if dest.begins_with("deck:"):
		ok = y.place_on_deck(id, sid, int(dest.get_slice(":", 1)))
		if not ok:
			var alt := y.nearest_deck(global_position, sid)
			ok = alt >= 0 and y.place_on_deck(id, sid, alt)
	else:
		ok = y.load_pit(id, sid)
	if ok:
		body_char.play_action("setdown")
	else:
		# Nowhere valid right now: put it back where it came from.
		y.return_to_origin(sid)


func _do_load_truck() -> void:
	var t: Truck = Game.vehicles.haul_target(self) if Game.vehicles else null
	if t and t.tailgate_point().distance_to(global_position) < 3.0:
		var n := Game.vehicles.load_from(id, t)
		if n > 0:
			crew.on_delivered_to_truck(self, n)
			body_char.play_action("setdown")
	activity = "idle"
	job_done("load_truck")
	if is_carrying():
		crew.send_to_rack(self)


## Into a truck seat: walking, collision and steering stop; the body rides
## the seat in a sitting pose (one person, one seat).
func board_seat(seat: Marker3D) -> void:
	abandon("boarding")
	seated = true
	activity = "seated"
	col.collision_layer = 0
	reparent(seat, false)
	transform = Transform3D(Basis(), Vector3(0, -0.47, 0.12))
	body_char.play("sit_relaxed" if seat.is_in_group("couch_seat") and body_char.anim.has_animation("sit_relaxed") else "sit", 0.3)
	body_char.set_locomotion(0.0)


# ------------------------------------------------------ hunt (Phase 6)

var _hide_spot: Node3D


## Runs to a free hiding place (claimed) and gets in.
func go_hide(spot: HideSpot) -> void:
	abandon("hiding")
	spot.set_meta("claimed", id)
	_hide_spot = spot
	if not go_to(spot.approach, "hide_enter", "hiding"):
		spot.set_meta("claimed", "")
		_hide_spot = null
		return
	_speed = 3.6


func _enter_hide() -> void:
	var spot := _hide_spot as HideSpot
	if spot == null or spot.occupant != null:
		activity = "idle"
		return
	spot.set_meta("claimed", "")
	global_position = spot.marker.global_position
	body_char.visible = false
	col.collision_layer = 0
	activity = "hidden"
	Game.hunt.on_enter_hide(self, spot)


func leave_hide(at: Vector3) -> void:
	_hide_spot = null
	body_char.visible = true
	col.collision_layer = 1
	global_position = Vector3(at.x, crew.nav.surface_at(at), at.z)
	activity = "idle"


## Killed by the Foreman: persistent life state; the body stays where it fell.
func die() -> void:
	abandon("dead")
	activity = "dead"
	body_char.visible = true
	col.collision_layer = 0
	body_char.set_locomotion(0.0)
	body_char.rotation = Vector3(-PI * 0.5, body_char.rotation.y, 0)
	body_char.position.y = 0.25
	body_char.process_mode = Node.PROCESS_MODE_DISABLED


func leave_seat(at: Vector3) -> void:
	seated = false
	reparent(crew, true)
	global_transform = Transform3D(Basis(Vector3.UP, global_rotation.y), Vector3(at.x, crew.nav.surface_at(at), at.z))
	col.collision_layer = 1
	body_char.play("idle", 0.2)
	activity = "idle"


var _carry_sig := "-"


func _update_carry_visual() -> void:
	var held: Array = crew.timber.load_of(id)
	var sig := ",".join(PackedStringArray(held)) + "|" + team
	if sig == _carry_sig:
		if held.is_empty():
			body_char.carry_grips = []
		return
	_carry_sig = sig
	for n in _carry_nodes:
		n.queue_free()
	_carry_nodes.clear()
	if held.is_empty():
		body_char.carry_grips = []
		return
	# Phase 13: one oversized log is dragged: front end in both hands at hip
	# height, the rest trailing on the ground behind (+Z = behind).
	if crew.timber.is_dragging(id, crew.carry_budget(self)):
		var sid0 := str(held[0])
		var s0 := crew.timber.segment(sid0)
		var rec0: Dictionary = crew.timber.records[int(sid0.trim_prefix("T").split("_S")[0])]
		var L := TimberMesh.piece_length(rec0, int(s0.k))
		var r0 := TimberMesh.piece_radius(rec0, int(s0.k))
		var mi0 := MeshInstance3D.new()
		mi0.mesh = TimberMesh.piece_mesh(rec0, int(s0.k))
		# Phase 14 team carry: held level at hip height, the partner takes the
		# far end; otherwise the far end trails on the ground.
		var axis := Vector3(0.0, -(0.85 - r0) / maxf(L, 0.5), 1.0).normalized() if team == "" else Vector3(0, 0, 1)
		var b0 := TimberMesh.frame_for(axis)
		var front := Vector3(0.0, 0.85, -0.45)
		# piece_mesh is already centred on the piece's middle.
		mi0.transform = Transform3D(b0, front + axis * (L * 0.5))
		body_char.add_child(mi0)
		_carry_nodes.append(mi0)
		var g0 := Marker3D.new()
		var g1 := Marker3D.new()
		g0.position = front + Vector3(-0.18, 0.05, 0.05)
		g1.position = front + Vector3(0.18, 0.05, 0.05)
		body_char.add_child(g0)
		body_char.add_child(g1)
		_carry_nodes.append(g0)
		_carry_nodes.append(g1)
		body_char.carry_grips = [g0, g1]
		return
	var mount := body_char.attachment("log")
	var i := 0
	for sid in held:
		var s := crew.timber.segment(sid)
		var rec: Dictionary = crew.timber.records[int(str(sid).trim_prefix("T").split("_S")[0])]
		var mi := MeshInstance3D.new()
		mi.mesh = TimberMesh.piece_mesh(rec, int(s.k))
		var r := TimberMesh.piece_radius(rec, int(s.k))
		# Across the shoulders, stacked; axis along the body's left-right.
		mi.basis = TimberMesh.frame_for(Vector3.RIGHT)
		mi.position = Vector3(0, r + float(i) * r * 1.8, 0.0)
		mount.add_child(mi)
		_carry_nodes.append(mi)
		i += 1
	var gl := Marker3D.new()
	var gr := Marker3D.new()
	gl.position = Vector3(-0.28, -0.02, 0.02)
	gr.position = Vector3(0.28, -0.02, 0.02)
	mount.add_child(gl)
	mount.add_child(gr)
	_carry_nodes.append(gl)
	_carry_nodes.append(gr)
	body_char.carry_grips = [gl, gr]


# ----------------------------------------------------------------- follow

func _do_follow(delta: float) -> void:
	var p := Game.player
	if p == null:
		activity = "idle"
		return
	var d := Vector3(p.global_position.x - global_position.x, 0, p.global_position.z - global_position.z)
	var L := d.length()
	if L > 30.0:
		# Too far for direct steering: path to a spot near the boss.
		var spot := p.global_position - d.normalized() * 3.0
		if go_to(spot, "follow", "you"):
			return
	if L > 3.5:
		var dir := _avoid(d / L)
		_speed = move_toward(_speed, WALK * (1.25 if L > 8.0 else 1.0), delta * 3.0)
		var np := global_position + dir * _speed * delta
		if crew.nav.walkable(np):
			np.y = crew.nav.surface_at(np)
			global_position = np
		_face(dir, delta)
		body_char.set_locomotion(_speed)
		crew.open_doors_near(global_position)
	else:
		_speed = 0.0
		body_char.set_locomotion(0.0)
		_face(d / maxf(L, 0.01), delta)


# ----------------------------------------------------------- home & sleep

func lie_down(bed: Node3D) -> void:
	path.clear()
	activity = "sleep"
	var bb := bed.get_parent() as Node3D
	var up_world := (bb.global_basis * Vector3(0, 0, -1)).normalized()   # toward the pillow
	# Lying on the back: body up-axis toward the pillow, face to the ceiling
	# (the character faces -Z, so Z points down). Right-handed: X = Y x Z.
	var z := Vector3.DOWN
	var x := up_world.cross(z).normalized()
	var foot := bb.global_transform * Vector3(0, 0.64, 0.92)
	global_transform = Transform3D(Basis(x, up_world, z).orthonormalized(), foot + Vector3(0, 0.12, 0))
	body_char.play("lie", 0.3)
	col.collision_layer = 0


func get_up(at: Vector3) -> void:
	rotation = Vector3(0, rotation.y, 0)
	global_basis = Basis(Vector3.UP, global_rotation.y)
	global_position = at
	body_char.play("idle", 0.3)
	col.collision_layer = 1
	activity = "idle"


func sit_at(seat: Node3D) -> void:
	path.clear()
	activity = "sit"
	global_transform = Transform3D(Basis(Vector3.UP, seat.global_rotation.y + PI), seat.global_position)
	body_char.play("sit", 0.3)


func capture() -> Dictionary:
	return {"pos": [global_position.x, global_position.y, global_position.z], "yaw": global_rotation.y, "activity": activity if activity in ["sleep", "depart_wait", "aboard"] else "idle"}
