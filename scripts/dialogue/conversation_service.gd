class_name ConversationService
extends Node
## Phase 17: crew conversations from the authored bank (CrewBank).
##
## One conversation at a time per camp (one local owner), usually two
## people, up to four. Every turn re-checks the speaker, the listeners and
## the line's situation immediately before it is spoken. Lines are chosen
## from what is TRUE now (activity, place, weather, mood, wages, idle cause,
## level, tools) and what the speaker actually KNOWS (firsthand memories vs
## things they were told; praise, level-ups, team carries, waiting, wages,
## departures). Cooldowns per line / category / group survive a reload.
## Chatter is suppressed near a running chainsaw, around a fall warning, in
## a heavy team carry, during the hunt when the hunter is close (whispers
## only), and when anyone involved has left, died or gone into hiding.
## Subtitles reach the player only within hearing (distance + walls).
## Timing comes from `line_seconds()`, which Phase 18 replaces with real
## clip lengths. Text only: no voice files are required.

const PAIR_R := 6.0
const GROUP_R := 8.0
const HEAR_R := 14.0
const HEAR_R_WALL := 6.0
const WHISPER_R := 4.0
const CD := {"often": 600.0, "sometimes": 1300.0, "rare": 6500.0}
const TOPIC_CD := 60.0
const GROUP_CD := 150.0
const RESUME_S := 20.0

var crew: CrewService
var bank: CrewBank
var clock := 0.0               # simulation seconds (pause stops it)
var cooldown := {}             # "l:<id>" / "c:<cat>" / "g:<ids>" -> expiry
var once := {}                 # line id -> true
var active := {}               # current conversation
var history: Array = []        # [{t, id, by, to, heard}]
var stats := {"conversations": 0, "lines": 0, "heard": 0, "suppressed": 0, "dropped": 0, "boss": 0, "rumors": 0}
var _next_try := 20.0
var _next_callout := 45.0
var _tick := 0.0
var _rng := RandomNumberGenerator.new()
var _seq := 0
var _warn_t := {}              # tree id -> clock of its fall warning
var _cleared_cache := [-999.0, 0.0]


func setup(c: CrewService) -> void:
	crew = c
	bank = CrewBank.get_bank()
	if crew.trees and not crew.trees.tree_warning.is_connected(_on_warning):
		crew.trees.tree_warning.connect(_on_warning)


func _on_warning(tid: int) -> void:
	_warn_t[tid] = clock


func _seed() -> int:
	var s := 1717
	if Game.campaign and Game.campaign.get("campaign_seed") != null:
		s = int(Game.campaign.get("campaign_seed"))
	elif World.manifest.has("world_seed"):
		s = int(World.manifest.world_seed)
	return s


func _roll() -> float:
	_seq += 1
	_rng.seed = hash("%d:%d" % [_seed(), _seq])
	return _rng.randf()


# ------------------------------------------------------------- the tick

func _physics_process(delta: float) -> void:
	if get_tree().paused or crew == null or not crew.enabled:
		return
	clock += delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	if not active.is_empty():
		_advance()
		return
	if clock >= _next_try:
		_next_try = clock + lerpf(25.0, 70.0, _roll())
		_try_start()
	if clock >= _next_callout:
		_next_callout = clock + lerpf(30.0, 75.0, _roll())
		_try_callout()


# ------------------------------------------------------------ world state

func _talkers() -> Array:
	var out := []
	for w in crew.workers.values():
		var wk := w as Worker
		if _can_talk(wk):
			out.append(wk)
	return out


func _can_talk(w: Worker) -> bool:
	if w == null or not is_instance_valid(w):
		return false
	var st := str(w.emp.get("status", ""))
	if st in ["departed", "dead"] or w.activity in ["dead", "departed", "hide_enter", "sleep", "board"]:
		return false
	if Game.hunt and Game.hunt.hunt_active() and not Game.hunt.worker_alive(w):
		return false
	return true


## Reasons a conversation can't happen right here, right now.
func suppressed_at(w: Worker) -> String:
	if w.activity == "team_follow" or (w.team != "" and w.is_carrying()):
		return "heavy team carry"
	for o in crew.workers.values():
		var ow := o as Worker
		if ow.saw.state in [SawMachine.S.CUTTING, SawMachine.S.REVVING] and ow.global_position.distance_to(w.global_position) < 12.0:
			return "chainsaw running"
	for tid in _warn_t:
		if clock - float(_warn_t[tid]) < 8.0:
			var idx: int = int(Game.vegetation.tree_index_by_id.get(tid, -1)) if Game.vegetation else -1
			if idx >= 0 and World.tree_position(idx).distance_to(w.global_position) < 30.0:
				return "tree coming down"
	if Game.hunt and Game.hunt.hunt_active() and Game.hunt.foreman and is_instance_valid(Game.hunt.foreman):
		if (Game.hunt.foreman as Node3D).global_position.distance_to(w.global_position) < 45.0 and w.activity != "hidden":
			return "danger close"
	return ""


func _acts(w: Worker) -> Array:
	match w.activity:
		"fell", "retreat_wait":
			return ["act:cut", "act:fell"]
		"buck":
			return ["act:cut", "act:buck"]
		"stump":
			return ["act:cut", "act:stump"]
		"pick", "deliver", "deliver_deck", "load_truck", "team_follow":
			return ["act:carry"]
		"yard_take", "yard_drop":
			return ["act:yard"]
		"idle":
			return ["act:idle"]
		"move":
			if w._after_move in ["home_arrived", "depart_wait"]:
				return ["act:home"]
			return ["act:carry"] if w.is_carrying() else ["act:walk"]
		"follow":
			return ["act:walk"]
		"sleep", "sit":
			return ["act:rest"]
		"aboard", "seated":
			return ["act:ride"]
		"hidden":
			return ["act:hide"]
	return ["act:walk"]


func _cleared() -> float:
	if clock - float(_cleared_cache[0]) < 5.0:
		return float(_cleared_cache[1])
	var pct := 0.0
	if Game.campaign and Game.campaign.contract:
		var c: Dictionary = Game.campaign.contract.counts()
		pct = 100.0 * float(c.get("felled", 0)) / maxf(float(World.tree_count()), 1.0)
	_cleared_cache = [clock, pct]
	return pct


func _phase() -> String:
	if Game.hunt and Game.hunt.hunt_active():
		return Game.hunt.phase_name()
	if crew.campaign == null:
		return "day"
	return ["day", "dusk", "night"][crew.campaign.clock.phase()]


func _mode() -> String:
	if Game.hunt and Game.hunt.hunt_active():
		return "rescue" if str(Game.hunt.ship_state) in ["approaching", "docked"] else "hunt"
	return "contract"


func _day() -> int:
	if Game.hunt and Game.hunt.hunt_active():
		return maxi(int(Game.hunt.hunt_day), 31)
	return crew.campaign.clock.day if crew.campaign else 1


## Does predicate `p` hold for worker `w` now?
func holds(p: String, w: Worker) -> bool:
	if p.begins_with("act:"):
		return p in _acts(w)
	if p.begins_with("phase:"):
		return p.substr(6) == _phase()
	if p.begins_with("mode:"):
		return p.substr(5) == _mode()
	if p.begins_with("day>="):
		return _day() >= int(p.substr(5))
	if p.begins_with("day<="):
		return _day() <= int(p.substr(5))
	if p.begins_with("level>="):
		return crew.progression.career(w.id) >= int(p.substr(7))
	if p.begins_with("cleared>="):
		return _cleared() >= float(p.substr(9))
	if p.begins_with("crew<="):
		return crew.payroll.employees.filter(func(e: Dictionary) -> bool: return str(e.status) == Payroll.ACTIVE).size() <= int(p.substr(6))
	if p.begins_with("weather:"):
		var wx: Node = Game.weather
		var rain: float = float(wx.get("rain")) if wx else 0.0
		var storm: float = float(wx.get("storm")) if wx else 0.0
		var wind: float = float(wx.get("wind_mult")) if wx else 1.0
		match p.substr(8):
			"rain":
				return rain > 0.35
			"storm":
				return storm > 0.5
			"wind":
				return wind > 1.4
			"dry":
				return rain < 0.1
		return false
	if p.begins_with("where:"):
		var pos := w.global_position
		match p.substr(6):
			"camp":
				return CampLayout.inside_fence(pos)
			"forest":
				return not CampLayout.inside_fence(pos)
			"cabin":
				for z in get_tree().get_nodes_in_group("zones"):
					if str(z.get("zone_name")).begins_with("cabin") and z.contains_point(pos + Vector3(0, 1.0, 0)):
						return true
				return false
			"shore":
				return pos.y < 3.0
		return false
	if p.begins_with("tool:"):
		var k := crew.kit(w)
		var tool := str(k.get("tool", "axe"))
		var tier := str(k.get("tier", ""))
		match p.substr(5):
			"saw":
				return tool == "chainsaw"
			"axe":
				return tool == "axe" and tier != ""
			"big_axe":
				return tool == "axe" and tier in ["medium", "large"]
			"none":
				return not crew.axe_ok(w) and tool != "chainsaw"
		return false
	if p.begins_with("mood:"):
		var st := int(w.mind.state)
		match p.substr(5):
			"calm":
				return st == 0
			"uneasy":
				return st == 1
			"shaken":
				return st == 2
			"refusing":
				return st >= 3
		return false
	if p.begins_with("belief:"):
		return w.mind.belief < 0.35 if p.ends_with("low") else w.mind.belief > 0.6
	if p.begins_with("trust:"):
		return w.mind.trust < 0.4 if p.ends_with("low") else w.mind.trust > 0.7
	if p == "owed":
		return crew.payroll.owed_for(w.id) > 0
	if p == "paid":
		return crew.payroll.owed_for(w.id) == 0
	if p.begins_with("blocker:"):
		var cause := p.substr(8)
		if w.idle_reason == cause:
			return true
		return float(crew.progression.day_time(w.id, crew.campaign.clock.day).get(cause, 0.0)) > 45.0
	if p == "dog_near":
		return Game.dog != null and is_instance_valid(Game.dog) and (Game.dog as Node3D).global_position.distance_to(w.global_position) < 8.0
	if p == "boss_tired":
		return Game.rest != null and Game.rest.rest < 45.0
	return false


## Does the speaker actually know `n`?
func knows(n: String, w: Worker) -> bool:
	var pg := crew.progression
	var d := crew.campaign.clock.day if crew.campaign else 1
	match n:
		"saw:strange":
			return w.mind.firsthand_count() > 0
		"heard:strange":
			return w.mind.firsthand_count() == 0 and w.mind.told_count() > 0
		"know:praised":
			return pg.recognition.any(func(r: Dictionary) -> bool: return str(r.eid) == w.id and d - int(r.day) <= 2)
		"know:levelup":
			return _ctx(w, "improved", 2, true)
		"know:colleague_progress":
			return _ctx(w, "colleague_progress", 2, false)
		"know:team_carry":
			return _ctx(w, "team_carry", 0, false)
		"know:frustrated":
			var t := pg.day_time(w.id, d)
			return _ctx(w, "frustrated_waiting", 1, true) or float(t.get("yard_full", 0.0)) + float(t.get("blocked", 0.0)) + float(t.get("waiting", 0.0)) > 90.0
		"know:owed_wages":
			return _ctx(w, "owed_wages", 2, true) or crew.payroll.owed_for(w.id) > 0
		"know:felled_today":
			return float(crew.merit.today(w.id, d).get("fell", 0.0)) > 0.0
		"know:delivered_today":
			return float(crew.merit.today(w.id, d).get("transport", 0.0)) > 0.0
		"know:departed":
			return crew.payroll.employees.any(func(e: Dictionary) -> bool: return str(e.status) == "departed")
		"know:dead":
			return Game.hunt != null and not (Game.hunt.dead_workers as Array).is_empty()
	return false


func _ctx(w: Worker, kind: String, days: int, self_only: bool) -> bool:
	var d := crew.campaign.clock.day if crew.campaign else 1
	for c in crew.progression.context:
		if str(c.kind) != kind or d - int(c.day) > days:
			continue
		if self_only and str(c.who) != w.id:
			continue
		if not self_only and str(c.who) == w.id and kind == "colleague_progress":
			continue
		if w.id in (c.knowers as Array):
			return true
	return false


func speaker_ok(ln: Dictionary, w: Worker) -> bool:
	var sp := str(ln.get("speaker", "any"))
	if sp == "any":
		return true
	if sp.begins_with("trait:"):
		return w.mind.has(sp.substr(6))
	return sp == w.id


## Full eligibility of line `ln` for speaker `w` (with reason when not).
func eligible(ln: Dictionary, w: Worker) -> String:
	if not speaker_ok(ln, w):
		return "speaker"
	var id := str(ln.id)
	if once.has(id):
		return "used once"
	if float(cooldown.get("l:" + id, 0.0)) > clock:
		return "cooldown"
	for p in ln.get("when", []):
		if not holds(str(p), w):
			return "when " + str(p)
	for n in ln.get("needs", []):
		if not knows(str(n), w):
			return "needs " + str(n)
	return ""


# ------------------------------------------------------- conversations

func _try_start() -> void:
	var ts := _talkers()
	if ts.size() < 2:
		return
	# Pick a talker (seeded), then the people actually beside them.
	var start: Worker = ts[int(_roll() * ts.size()) % ts.size()]
	if suppressed_at(start) != "":
		stats.suppressed += 1
		return
	var near := []
	for o in ts:
		if o != start and (o as Worker).global_position.distance_to(start.global_position) < GROUP_R and suppressed_at(o) == "":
			near.append(o)
	if near.is_empty():
		return
	near.sort_custom(func(a: Worker, b: Worker) -> bool: return a.global_position.distance_to(start.global_position) < b.global_position.distance_to(start.global_position))
	var group: Array = [start] + near.slice(0, 3)
	var pair: Array = [start, near[0]] if (near[0] as Worker).global_position.distance_to(start.global_position) < PAIR_R else []
	var gkey := "g:" + ",".join(PackedStringArray(group.map(func(x: Worker) -> String: return x.id)))
	if float(cooldown.get(gkey, 0.0)) > clock:
		return
	var cands := []
	for id in bank.openers:
		var ln: Dictionary = bank.lines[id]
		var to := str(ln.get("to", ""))
		if to == "self":
			continue
		var members: Array = pair if to == "pair" else (group if group.size() >= 3 else [])
		if members.is_empty():
			continue
		if float(cooldown.get("c:" + str(ln.get("cat", "")), 0.0)) > clock:
			continue
		for m in members:
			if eligible(ln, m) == "":
				cands.append([id, m, members])
				break
	if cands.is_empty():
		return
	var pick: Array = _weighted(cands)
	_begin(str(pick[0]), pick[1], pick[2], gkey)


func _weighted(cands: Array) -> Array:
	var total := 0.0
	var ws := []
	for c in cands:
		var ln: Dictionary = bank.lines[c[0]]
		# Specific lines (more conditions met) and higher priority first.
		var w := float(ln.get("prio", 3)) * (1.0 + 0.5 * ((ln.get("when", []) as Array).size() + (ln.get("needs", []) as Array).size()))
		ws.append(w)
		total += w
	var r := _roll() * total
	for i in cands.size():
		r -= float(ws[i])
		if r <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


func _begin(id: String, speaker: Worker, members: Array, gkey: String) -> void:
	active = {"members": members, "queue": [[id, speaker]], "next_at": clock, "gkey": gkey, "cat": str(bank.lines[id].get("cat", "")), "paused_at": -1.0, "turns": 0}
	stats.conversations += 1
	cooldown[gkey] = clock + GROUP_CD
	cooldown["c:" + str(active.cat)] = clock + TOPIC_CD


func _advance() -> void:
	if active.is_empty() or clock < float(active.get("next_at", 0.0)):
		return
	# Every participant still here, able and not interrupted?
	var members: Array = active.members
	var broken := ""
	for m in members:
		if not _can_talk(m):
			broken = "left"
		elif suppressed_at(m) != "":
			broken = suppressed_at(m)
	if broken == "" and members.size() >= 2:
		var c := (members[0] as Worker).global_position
		for m in members:
			if (m as Worker).global_position.distance_to(c) > GROUP_R + 3.0:
				broken = "walked apart"
	var q: Array = active.queue
	if q.is_empty():
		active.clear()
		return
	var id := str(q[0][0])
	var ln: Dictionary = bank.lines.get(id, {})
	if broken != "":
		if str(ln.get("interrupt", "drop")) == "resume" and broken != "left":
			if float(active.paused_at) < 0.0:
				active.paused_at = clock
			if clock - float(active.paused_at) < RESUME_S:
				active.next_at = clock + 1.0
				return
		stats.dropped += 1
		active.clear()
		return
	active.paused_at = -1.0
	var sp: Worker = q[0][1]
	if eligible(ln, sp) not in ["", "cooldown"]:
		stats.dropped += 1
		active.clear()
		return
	q.pop_front()
	var listeners := members.filter(func(m: Worker) -> bool: return m != sp)
	_speak(id, sp, listeners)
	active.turns = int(active.turns) + 1
	# A response from someone else in the group, if one fits.
	if int(active.turns) < 4:
		var nexts := []
		for r in ln.get("resp", []):
			var rl: Dictionary = bank.lines.get(str(r), {})
			if rl.is_empty():
				continue
			for m in listeners:
				if eligible(rl, m) == "":
					nexts.append([str(r), m, members])
					break
		if not nexts.is_empty():
			var pk: Array = _weighted(nexts)
			q.append([pk[0], pk[1]])
	var dur := float(active.get("clip_s", 0.0)) if float(active.get("clip_s", 0.0)) > 0.0 else line_seconds(ln)
	active.erase("clip_s")
	active.next_at = clock + dur + lerpf(0.4, 1.2, _roll())
	if q.is_empty():
		active.clear()
		_next_try = maxf(_next_try, clock + line_seconds(ln) + lerpf(20.0, 50.0, _roll()))


## Speech duration estimate (Phase 18: replaced by the clip's length).
static func line_seconds(ln: Dictionary) -> float:
	return clampf(1.2 + 0.06 * str(ln.get("text", "")).length(), 1.6, 9.0)


func _speak(id: String, sp: Worker, listeners: Array) -> void:
	var ln: Dictionary = bank.lines[id]
	var rep := str(ln.get("rep", "sometimes"))
	if rep == "once":
		once[id] = true
	else:
		cooldown["l:" + id] = clock + float(CD.get(rep, CD.sometimes))
	var text := str(ln.text)
	if text.contains("{listener}"):
		var nm := "you"
		if not listeners.is_empty():
			nm = str((listeners[0] as Worker).emp.name).split(" ")[0]
		text = text.replace("{listener}", nm)
	stats.lines += 1
	# Phase 18 hook: a recorded clip (res://audio/voice/<voice>/<id>.ogg)
	# plays from the speaker's mouth and its real length drives the turn
	# timing; without one, text timing is used. None exist yet.
	var clip := SoundService.speak(sp, {"id": id, "voice": CrewBank.voice_of(sp.id), "text": text, "priority": int(ln.get("prio", 3))})
	if clip > 0.0 and not active.is_empty():
		active["clip_s"] = clip
	var heard := _player_hears(sp, "act:hide" in (ln.get("when", []) as Array))
	if heard and Settings.get_v("subtitles") == false:
		heard = false              # muted subtitles: still "said" (same game info elsewhere)
	if heard:
		stats.heard += 1
		var to := ""
		if not listeners.is_empty() and str(ln.get("to", "")) != "self":
			to = " (to %s)" % ", ".join(PackedStringArray(listeners.map(func(m: Worker) -> String: return str(m.emp.name).split(" ")[0])))
		crew.notice.emit("%s%s: \"%s\"" % [str(sp.emp.name).split(" ")[0], to, text], subtitle_seconds(ln))
	history.append({"t": snappedf(clock, 0.1), "id": id, "by": sp.id, "to": listeners.map(func(m: Worker) -> String: return m.id), "heard": heard})
	if history.size() > 60:
		history.pop_front()
	TerrorDirector.remember_voice(str(sp.emp.name), text, sp.global_position)
	# Telling someone what you saw passes on a CLAIM, not the evidence.
	if "saw:strange" in (ln.get("needs", []) as Array):
		var mem := sp.mind.strongest_memory()
		if not mem.is_empty():
			for m in listeners:
				(m as Worker).mind.hear_coworker(crew.now(), mem, sp.id)
			crew.progression.add_context("told_strange", sp.id, str(mem.get("kind", "")), [sp.id] + listeners.map(func(m: Worker) -> String: return m.id))
			stats.rumors += 1


static func subtitle_seconds(ln: Dictionary) -> float:
	var mult := float(Settings.get_v("subtitle_time")) if Settings.get_v("subtitle_time") != null else 1.0
	return clampf((1.4 + 0.065 * str(ln.get("text", "")).length()) * mult, 2.4, 12.0)


func _player_hears(sp: Worker, whisper: bool) -> bool:
	var p := Game.player as Node3D
	if p == null:
		return false
	var d := p.global_position.distance_to(sp.global_position)
	if whisper:
		return d < WHISPER_R
	if d > HEAR_R:
		return false
	if d < HEAR_R_WALL:
		return true
	var space := sp.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(sp.global_position + Vector3(0, 1.6, 0), p.global_position + Vector3(0, 1.5, 0), 1)
	q.exclude = [sp.col.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.collider == p


# ------------------------------------------------------ callouts / boss

## A single worker's callout (to: self) when the player is close enough
## to hear it: blocker reports, warnings, small observations.
func _try_callout() -> void:
	var p := Game.player as Node3D
	if p == null:
		return
	var best: Worker = null
	for w in _talkers():
		if (w as Worker).global_position.distance_to(p.global_position) < HEAR_R and suppressed_at(w) == "":
			best = w
			break
	if best == null:
		return
	var cands := []
	for id in bank.openers:
		var ln: Dictionary = bank.lines[id]
		if str(ln.get("to", "")) == "self" and eligible(ln, best) == "" and float(cooldown.get("c:" + str(ln.get("cat", "")), 0.0)) <= clock:
			cands.append([id, best, [best]])
	for id in bank.boss.get("report", []):
		if eligible(bank.lines[id], best) == "":
			cands.append([id, best, [best]])
	if cands.is_empty():
		return
	var pk: Array = _weighted(cands)
	_speak(str(pk[0]), best, [])
	cooldown["c:" + str(bank.lines[pk[0]].get("cat", ""))] = clock + TOPIC_CD


## The boss asked `w` about `ask` (talk menu). Returns the authored reply
## (most specific eligible line), or "" if none fits (the caller then uses
## the older functional line).
func boss_reply(w: Worker, ask: String) -> String:
	var cands := []
	for id in bank.boss.get(ask, []):
		var ln: Dictionary = bank.lines[id]
		if eligible(ln, w) == "":
			cands.append([id, w, [w]])
	if cands.is_empty():
		return ""
	# Prefer the most specific (most conditions) among the eligible.
	var best_n := -1
	for c in cands:
		var ln: Dictionary = bank.lines[c[0]]
		best_n = maxi(best_n, (ln.get("when", []) as Array).size() + (ln.get("needs", []) as Array).size() + (2 if str(ln.speaker) == w.id else 0))
	var top := cands.filter(func(c: Array) -> bool:
		var ln: Dictionary = bank.lines[c[0]]
		return (ln.get("when", []) as Array).size() + (ln.get("needs", []) as Array).size() + (2 if str(ln.speaker) == w.id else 0) >= best_n - 1)
	var pk: Array = _weighted(top)
	var ln2: Dictionary = bank.lines[pk[0]]
	var rep := str(ln2.get("rep", "sometimes"))
	if rep == "once":
		once[str(pk[0])] = true
	else:
		cooldown["l:" + str(pk[0])] = clock + minf(float(CD.get(rep, CD.sometimes)), 300.0)
	stats.boss += 1
	history.append({"t": snappedf(clock, 0.1), "id": str(pk[0]), "by": w.id, "to": ["boss"], "heard": true})
	return str(ln2.text).replace("{listener}", "boss")


## Preview inspector: why each line would or wouldn't be said by `w` now.
func explain(w: Worker, max_lines := 12) -> String:
	var out := PackedStringArray()
	out.append("%s · %s · phase %s · mode %s · day %d" % [w.emp.name, ", ".join(PackedStringArray(_acts(w))), _phase(), _mode(), _day()])
	var ok := 0
	for id in bank.openers + bank.boss.get("work", []) + bank.boss.get("blocker", []):
		var ln: Dictionary = bank.lines[id]
		if not speaker_ok(ln, w):
			continue
		var why := eligible(ln, w)
		if why == "":
			ok += 1
			if out.size() < max_lines:
				out.append("  OK %s: %s" % [id, str(ln.text).left(70)])
	out.append("%d lines eligible for %s right now (of %d in the bank)." % [ok, str(w.emp.name).split(" ")[0], bank.lines.size()])
	if not history.is_empty():
		var h: Dictionary = history[history.size() - 1]
		out.append("Last said: %s by %s%s" % [h.id, h.by, " (heard)" if bool(h.heard) else ""])
	return "\n".join(out)


func capture() -> Dictionary:
	var cd := {}
	for k in cooldown:
		if float(cooldown[k]) > clock:
			cd[k] = float(cooldown[k])
	return {"version": 1, "clock": clock, "cooldown": cd, "once": once.keys(), "seq": _seq, "stats": stats.duplicate(), "history": history.slice(-20)}


func restore(d: Dictionary) -> void:
	clock = float(d.get("clock", 0.0))
	cooldown = (d.get("cooldown", {}) as Dictionary).duplicate()
	once.clear()
	for k in d.get("once", []):
		once[str(k)] = true
	_seq = int(d.get("seq", 0))
	history = (d.get("history", []) as Array).duplicate(true)
	active.clear()
	_next_try = clock + 15.0
	_next_callout = clock + 30.0
