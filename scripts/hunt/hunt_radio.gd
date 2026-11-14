class_name HuntRadio
extends RefCounted
## Phase 27: the crew radio in the hunt. The boss can call the roll, tell
## everyone to get out of sight, or ask them to come. Talking has a price:
## the boss's voice carries, and so does every spoken answer, and the
## Foreman hears both. Someone already hidden answers with two clicks of
## the key (no sound). Someone who cannot answer is silence; the radio
## never says why.

const COOLDOWN := 25.0              # seconds between calls
const BOSS_RADIUS := 16.0           # how far the boss's voice carries
const REPLY_RADIUS := 10.0          # how far a spoken answer carries
const ORDERS := {"report": "Call the roll.", "hide": "Everyone out of sight.", "come": "Come to me."}
const SPOT_WORDS := {"under_bed": "under a bed", "closet": "in a closet", "under_desk": "under the desk", "behind_shelves": "behind the shelves",
	"under_dock": "under the dock", "thicket": "in a thicket", "shed": "in a field shed", "dock_store": "in the dock store", "rock": "among the rocks"}

var hunt: HuntService
var last_at := -999.0
var calls := 0


## Why the radio cannot be used right now ("" = it can).
func blocker() -> String:
	if hunt == null or not hunt.hunt_active():
		return "Nobody is on the radio."
	if Game.crew == null:
		return "Nobody is on the radio."
	var left := COOLDOWN - (hunt.hunt_clock() - last_at)
	if left > 0.0:
		return "Wait. Let it go quiet first. (%d s)" % int(ceil(left))
	return ""


## Everyone who was on the island when the hunt began and has not sailed.
func _roster() -> Array:
	var out := []
	for e in Game.campaign.payroll.employees:
		if str(e.status) in [Payroll.ACTIVE, "dead"] and not hunt.escaped.has(str(e.id)):
			out.append(e)
	return out


func _where(w: Worker) -> String:
	var cabin := CampLayout.world(CampLayout.CABIN_POS)
	if Vector2(w.global_position.x - cabin.x, w.global_position.z - cabin.z).length() < 9.0:
		return "in the cabin"
	var o := World.camp_origin()
	var d := Vector2(w.global_position.x - o.x, w.global_position.z - o.z)
	if Game.crew.nav.in_camp(w.global_position):
		return "in camp, in the open"
	var side := ("north" if d.y < 0.0 else "south") if absf(d.y) > absf(d.x) else ("east" if d.x > 0.0 else "west")
	return "out %s of camp, %d metres" % [side, int(round(d.length() / 10.0)) * 10]


## One call. Returns {ok, why, lines: PackedStringArray, spoke: int}.
func call_out(order: String) -> Dictionary:
	var why := blocker()
	if why != "" or not ORDERS.has(order):
		return {"ok": false, "why": why if why != "" else "Nobody is on the radio.", "lines": PackedStringArray(), "spoke": 0}
	last_at = hunt.hunt_clock()
	calls += 1
	var pl := Game.player as Node3D
	if pl:
		hunt.noise(pl.global_position, BOSS_RADIUS, "voice", "boss")
		var mine: HideSpot = hunt.hidden.get(pl)
		if mine:
			hunt.hide_noise[mine] = hunt.hunt_clock()     # talking from a hiding place gives it away
	var lines := PackedStringArray()
	var spoke := 0
	for e in _roster():
		var name_ := str(e.name).get_slice(" ", 0)
		var w: Worker = Game.crew.workers.get(str(e.id))
		if str(e.status) == "dead" or w == null or not hunt.worker_alive(w):
			lines.append("%s: nothing. Static." % name_)
			continue
		if w.mind and w.mind.state >= WorkerMind.Fear.DEPARTURE_WARNING and not hunt.hidden.has(w):
			lines.append("%s: breathing. No words." % name_)
			continue
		var spot: HideSpot = hunt.hidden.get(w)
		if spot:
			# Two clicks: hidden, and staying hidden. No sound.
			lines.append("%s: two clicks. Hidden %s." % [name_, str(SPOT_WORDS.get(spot.kind, "somewhere"))])
			continue
		spoke += 1
		hunt.noise(w.global_position, REPLY_RADIUS, "voice", w.id)
		match order:
			"report":
				lines.append("%s: %s." % [name_, "right behind you" if bool(w.emp.get("hunt_follow", false)) else _where(w)])
			"hide":
				w.emp.erase("hunt_follow")
				var free := hunt._nearest_free_spot(w.global_position)
				if free:
					w.go_hide(free)
					lines.append("%s: going to ground." % name_)
				else:
					lines.append("%s: nowhere left to hide. Staying %s." % [name_, _where(w)])
			"come":
				lines.append("%s: %s" % [name_, "coming." if hunt.ask_to_follow(w) else "no. Not out there."])
	if lines.is_empty():
		lines.append("Nobody answers.")
	return {"ok": true, "why": "", "lines": lines, "spoke": spoke}


func capture() -> Dictionary:
	return {"last_at": snappedf(last_at, 0.1), "calls": calls}


func restore(d: Dictionary) -> void:
	last_at = float(d.get("last_at", -999.0))
	calls = int(d.get("calls", 0))
