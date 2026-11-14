class_name CrewAbsence
extends RefCounted
## Phase 27: the crew notice who is gone. For a few days after someone
## leaves on the boat, each remaining worker has one thing to say about
## it, by name, the next time the boss talks to them; and one of them says
## it out loud the first morning. Text only (not voiced).

const DAYS := 3                     # how long a departure is talked about

const LINES := {
	"fear": [
		"{name}'s bunk is stripped. Said they would rather be poor than hear that again.",
		"{name} went on the boat. Never said goodbye. Watched the trees the whole way down the dock.",
		"I set out a cup for {name} this morning. Habit. {name} wasn't wrong to go, boss.",
	],
	"fear_skeptical": [
		"{name} left over noises. Noises. I've taken that bunk, mind. It's further from the window.",
	],
	"fear_timid": [
		"{name} got out. I nearly asked if there was room on the boat.",
	],
	"wages": [
		"{name} left over the money. I'm not saying anything. I'm saying {name} left over the money.",
		"{name} did the sums and got on the boat. We can all do sums, boss.",
	],
	"fired": [
		"You sent {name} home. Your call. The rest of us noticed, that's all.",
		"{name}'s gone, then. I'll take that share of the hauling. Somebody has to.",
	],
}


static func kind_of(reason: String) -> String:
	if reason.begins_with("fired"):
		return "fired"
	return "wages" if reason in ["unpaid wages", "low pay"] else "fear"


## The most recent person who left within DAYS (not `skip`), or {}.
static func recent(crew: CrewService, skip := "") -> Dictionary:
	var best := {}
	var day: int = crew.campaign.clock.day
	for e in crew.campaign.payroll.employees:
		if str(e.status) != Payroll.DEPARTED or str(e.id) == skip or not e.has("departed_day"):
			continue
		var dd := int(e.departed_day)
		if day - dd > DAYS or day < dd:
			continue
		if best.is_empty() or dd > int(best.departed_day):
			best = e
	return best


## What this worker says about it, once per departure ("" otherwise).
static func line(crew: CrewService, w: Worker, mark := true) -> String:
	if w == null or w.mind == null:
		return ""
	var gone := recent(crew, w.id)
	if gone.is_empty() or str(w.emp.get("spoke_of", "")) == str(gone.id):
		return ""
	var kind := kind_of(str(gone.get("departure_reason", "")))
	var pool: Array = []
	for t in w.mind.traits:
		pool.append_array(LINES.get("%s_%s" % [kind, t], []))
	if pool.is_empty():
		pool = LINES[kind]
	var pick: String = pool[absi(hash("%s:%s" % [w.id, gone.id])) % pool.size()]
	if mark:
		w.emp["spoke_of"] = str(gone.id)
	return pick.replace("{name}", str(gone.name).get_slice(" ", 0))


## The first morning after: one of the crew says it where everyone hears.
static func on_morning(crew: CrewService) -> void:
	var day: int = crew.campaign.clock.day
	var gone := recent(crew)
	if gone.is_empty() or int(gone.departed_day) != day - 1:
		return
	for w in crew.workers.values():
		var wk := w as Worker
		if str(wk.emp.status) != Payroll.ACTIVE:
			continue
		var t := line(crew, wk)
		if t != "":
			wk.said.emit(wk, t, true)
			return
