class_name Onboarding
extends Node
## Phase 9 first-day guide, saved per campaign. Each step is completed by
## detecting a REAL result in the authoritative systems (distance walked, a
## tree actually felled, a log actually accepted and credited, a night
## actually slept), never by a key sequence, so rebound keys, hold-to-chop,
## workers helping, partial progress and save/load cannot trap the player.
## It never creates logs or money and never touches the clock: active work
## stays live; only mandatory rule cards pause (through EndScreen).
##
## Night gate: ordinary night catches stay off until the night rules have
## been presented and acknowledged (the dusk card, or the skip summary).

signal hint_changed(text: String)

const STEPS := [
	["move", "Look around with the mouse and walk ({move_forward}{move_left}{move_back}{move_right}). Pause any time with {pause}."],
	["journal", "Open your Journal ({toggle_journal}): the contract is there. Felling pays nothing; logs delivered to camp pay $100 per tree in shares."],
	["meet", "Meet your crew and Biscuit the dog: walk up to one of them. Your camper is the boss's (and the dog's); the crew sleep in the cabin."],
	["rack", "Find the delivery rack beside the burn pit in camp. Logs are paid there."],
	["fell", "Pick a tree near camp. Chop it with {attack} (hold if 'Hold to keep chopping' is on). When it creaks, step back from the side it leans to."],
	["section", "Cut the fallen trunk into logs: chop at the marked cut lines along it."],
	["carry", "Pick up a log ({interact}). Your hands hold about a third of a tree; big pieces may need another cut, help or a truck."],
	["deliver", "Carry it to the rack and deliver it ({interact}). The credit you see is the real payment."],
	["review", "Check money and crew in the Journal ({toggle_journal}): today's wages ($300 per employee) and your next axe at the tool rack."],
	["dusk", "When dusk comes you'll get the night rules. Head home before dark."],
	["sleep", "Sleep in the camper bed to end the day. Night only ends when you sleep."],
]
const OPTIONAL := [
	"Give a worker a job: Journal → Crew.",
	"Sit on the camper couch to watch the security cameras (live: time keeps running).",
	"The arcade cabinets in the cabin pause the game while you play.",
]

var done: Array = []
var skipped := false
var night_rules_ack := false
var milestones := {}
var _base := {}          # per-step baselines (not saved; re-taken on load)
var _t := 0.0
var _last_hint := ""
var _start_pos := Vector3.INF
var journal_opened := 0  # counter bumped by the Journal
var _card_open := false


func active() -> bool:
	return not skipped and current() != ""


func current() -> String:
	for s in STEPS:
		if not done.has(s[0]):
			return str(s[0])
	return ""


func step_index() -> int:
	return STEPS.map(func(s: Array) -> String: return str(s[0])).find(current())


static func fill(text: String) -> String:
	var out := text
	for a in ["move_forward", "move_left", "move_back", "move_right", "pause", "toggle_journal", "attack", "interact", "set_down"]:
		out = out.replace("{%s}" % a, Keys.label(a))
	return out


func hint() -> String:
	if not active() or not bool(Settings.get_v("hints")):
		return ""
	var i := step_index()
	return "First day %d/%d · %s" % [i + 1, STEPS.size(), fill(str(STEPS[i][1]))]


# ------------------------------------------------------------ life cycle

func start_new() -> void:
	replaying = false
	done.clear()
	skipped = false
	night_rules_ack = false
	milestones.clear()
	_base.clear()
	_start_pos = Vector3.INF


func capture() -> Dictionary:
	return {"done": done.duplicate(), "skipped": skipped, "night_rules_ack": night_rules_ack, "milestones": milestones.duplicate(), "version": 1}


## Saves from before Phase 9 have been played already: the guide is marked
## finished and the rules acknowledged (no surprise tutorial mid-campaign).
func restore(d: Dictionary) -> void:
	if d.is_empty():
		done = STEPS.map(func(s: Array) -> String: return str(s[0]))
		skipped = true
		night_rules_ack = true
		milestones = {}
		return
	done = (d.get("done", []) as Array).duplicate()
	skipped = bool(d.get("skipped", false))
	night_rules_ack = bool(d.get("night_rules_ack", false))
	milestones = (d.get("milestones", {}) as Dictionary).duplicate()
	_base.clear()
	_start_pos = Vector3.INF


func skip_step() -> void:
	var c := current()
	if c == "":
		return
	if c == "dusk":
		show_night_rules()
		return
	done.append(c)
	_base.clear()
	_emit_hint()


## Skip the whole guide: a concise rules summary that must be acknowledged
## (this is also the night-rules acknowledgement). The campaign stays normal.
func skip_all() -> void:
	skipped = true
	_emit_hint()
	_card("Rules summary", HelpText.contract() + "\n\n" + HelpText.night() + "\n\nControls: Journal → Help, or Settings → Key bindings.", "I understand", func() -> void: night_rules_ack = true)


## Replay the guide's hints (help only): the world, trees and money are
## untouched; each step re-checks the real state from now on.
func replay() -> void:
	done.clear()
	skipped = false
	replaying = true
	_base.clear()
	_start_pos = Vector3.INF
	_emit_hint()


func show_night_rules() -> void:
	_card("Before your first night", HelpText.night(), "Got it", func() -> void:
		night_rules_ack = true
		if not done.has("dusk"):
			done.append("dusk")
		_emit_hint())


func _card(title: String, body: String, button: String, on_ok: Callable) -> void:
	if Game.end_screen == null:
		on_ok.call()
		return
	_card_open = true
	Game.end_screen.show_info(title, body, button, func() -> void:
		_card_open = false
		on_ok.call())


## Milestones that fire once per campaign (saved).
func milestone(id: String) -> bool:
	if milestones.has(id):
		return false
	milestones[id] = true
	return true


# ------------------------------------------------------------ detection

func on_dusk() -> void:
	if not night_rules_ack and not _card_open:
		show_night_rules()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var cs: CampaignService = get_parent() as CampaignService
	if cs == null or not cs.active or cs.test_route:
		return
	if not night_rules_ack and cs.clock.phase() == WorkdayClock.Phase.NIGHT and not _card_open:
		show_night_rules()
	if skipped:
		return
	var c := current()
	if c != "" and _check(c, cs):
		done.append(c)
		_base.clear()
		if Game.player and Game.player.has_method("show_message"):
			Game.player.show_message("Done: %s" % c.capitalize())
	_emit_hint()


func _emit_hint() -> void:
	var h := hint()
	if h != _last_hint:
		_last_hint = h
		hint_changed.emit(h)


func _check(step: String, cs: CampaignService) -> bool:
	var p := Game.player as Node3D
	if p == null:
		return false
	match step:
		"move":
			if _start_pos == Vector3.INF:
				_start_pos = p.global_position
			return p.global_position.distance_to(_start_pos) > 4.0
		"journal", "review":
			if not _base.has(step):
				_base[step] = journal_opened
			return journal_opened > int(_base[step])
		"meet":
			if Game.dog and Game.dog.global_position.distance_to(p.global_position) < 4.0:
				return true
			if Game.crew:
				for w in Game.crew.workers.values():
					if (w as Node3D).global_position.distance_to(p.global_position) < 4.0:
						return true
			return false
		"rack":
			for r in p.get_tree().get_nodes_in_group("delivery_rack"):
				if (r as Node3D).global_position.distance_to(p.global_position) < 6.0:
					return true
			return false
		# Work steps accept results that already happened (any order, any
		# helper, before a save): the real counters decide. When replaying
		# the guide as help, only new results count.
		"fell":
			return _real(step, int(cs.contract.counts().felled))
		"section":
			return _real(step, _count_segs(TimberService.Seg.WORLD) + _count_segs(TimberService.Seg.CARRIED) + _accepted())
		"carry":
			return (Game.timber != null and not Game.timber.carried.is_empty()) or _real(step, _accepted())
		"deliver":
			return _real(step, _accepted())
		"dusk":
			return night_rules_ack
		"sleep":
			if not _base.has(step):
				_base[step] = cs.clock.day
			return cs.clock.day > int(_base[step])
	return false


var replaying := false


func _accepted() -> int:
	return int(Game.timber.totals().accepted_mte) if Game.timber else 0


func _real(step: String, value: int) -> bool:
	if not replaying:
		return value > 0
	if not _base.has(step):
		_base[step] = value
	return value > int(_base[step])


func _count_segs(st: int) -> int:
	if Game.timber == null:
		return 0
	var n := 0
	for id in Game.timber.records:
		for s in Game.timber.records[id].segments:
			if int(s.state) == st:
				n += 1
	return n
