class_name CrewArcs
extends RefCounted
## Phase 27: the five people who came out on the first boat each have
## three things to say, in order, once enough days have passed and they
## trust the boss enough to say them. Asking is a talk option; each answer
## builds trust, and the third leaves that person settled (content with a
## little less pay, steadier). Two of Priya's hand over what she has
## worked out about the nights. A letter may come on the next boat.
##
## Text only (not voiced). Built on what the crew already say elsewhere:
## Tomas and his sister Ana, Priya's pages to her mother, Joan's cooking.

const TRUST_PER_BEAT := 0.05
const SETTLED_DISCOUNT := 2500      # cents a settled worker's fair wage drops by

## Employee id -> three beats {day, trust, ask, say, [insight], [letter]}.
const ARCS := {
	"EMP-01": [
		{"day": 3, "trust": 0.55, "ask": "How long have you done this?",
			"say": "Twenty-two years on crews. Nine bosses. I can tell by day three whether a job will pay out. Ask me again in a week and I'll tell you about this one."},
		{"day": 9, "trust": 0.65, "ask": "So. Will this one pay out?",
			"say": "It'll pay. You count the logs yourself. The bosses who don't are the ones who go under, and they take the crew's last week with them."},
		{"day": 15, "trust": 0.75, "ask": "What comes after this job?",
			"say": "Nothing. My knees decided. I wanted the last one to be a job that actually finished. Don't make a liar of me.",
			"letter": "Mum. The porch is mended and the dog has stopped waiting at the gate, mostly. Bring nothing back but yourself. Edie."},
	],
	"EMP-02": [
		{"day": 3, "trust": 0.55, "ask": "You don't say much.",
			"say": "I lift things. It's not a personality, but it has kept me fed."},
		{"day": 9, "trust": 0.65, "ask": "Where did you learn the mill?",
			"say": "My brother and I had one. Past tense. I like yours better. Nobody is shouting in it."},
		{"day": 15, "trust": 0.75, "ask": "Would you do this again?",
			"say": "If there's another island, ask me first. Before you ask the others. I'd want to know who I was lifting for."},
	],
	"EMP-03": [
		{"day": 3, "trust": 0.55, "ask": "You're always writing.",
			"say": "A page a day to my mother. And I notice things. On my last job I noticed the boss was shaving the scale. That is why it was my last job with him."},
		{"day": 9, "trust": 0.65, "ask": "What have you noticed here?",
			"say": "Times. When the lamps come on, when the sounds start, what stops them. It isn't random. Here: this much I'm sure of.",
			"insight": true},
		{"day": 15, "trust": 0.75, "ask": "Can I see the rest of your notes?",
			"say": "My mother thinks I'm a surveyor's assistant. Close enough. Take them. You're the one who keeps going out there.",
			"insight": true,
			"letter": "Priya, thirty pages arrived in one envelope and I read them in one sitting. You write about lamps a great deal. Eat properly. Your mother."},
	],
	"EMP-04": [
		{"day": 3, "trust": 0.55, "ask": "Who's Ana?",
			"say": "My sister. She's seventeen. She got into the nursing course and somebody has to pay for it. So here I am, afraid of trees."},
		{"day": 9, "trust": 0.65, "ask": "Are you sleeping?",
			"say": "Not much. I drive better than I sleep. If it ever goes bad out here, give me the truck. I won't leave anybody."},
		{"day": 15, "trust": 0.75, "ask": "What will you tell Ana about this place?",
			"say": "That the boss was all right. That's most of it, with a boss.",
			"letter": "Tomas. The first term is paid. I told them my brother cuts down islands. Come home with all your fingers. Ana."},
	],
	"EMP-05": [
		{"day": 3, "trust": 0.55, "ask": "Why do you do the cooking?",
			"say": "Because nobody else here should. And it's wind, by the way. Whatever it is you're all hearing."},
		{"day": 9, "trust": 0.65, "ask": "Still wind?",
			"say": "My sister says I've gone soft. I told her the wind out here has opinions. Don't repeat that."},
		{"day": 15, "trust": 0.75, "ask": "You've stopped saying it's wind.",
			"say": "I don't believe in it. I've stopped saying so after dark, that's all. There's stew. Sit down.",
			"letter": "Joan. You wrote four pages and never once said it was nothing. I'm keeping the letter. Come home. M."},
	],
}

var crew: CrewService
var done := {}                      # employee id -> beats heard (0..3)
var letters: Array = []             # [{"eid", "day", "text", "shown"}]


func heard(eid: String) -> int:
	return int(done.get(eid, 0))


func settled(eid: String) -> bool:
	return heard(eid) >= 3


## The next thing this worker would say now, or {} (too early, not enough
## trust, nothing left, or not one of the five).
func available(w: Worker) -> Dictionary:
	if w == null or not ARCS.has(w.id) or w.mind == null:
		return {}
	var n := heard(w.id)
	var arc: Array = ARCS[w.id]
	if n >= arc.size():
		return {}
	var b: Dictionary = arc[n]
	var day: int = crew.campaign.clock.day if crew and crew.campaign else 0
	if day < int(b.day) or w.mind.trust < float(b.trust):
		return {}
	return b


## Why the next beat is not available yet ("" if it is, or none is left).
func waiting_for(w: Worker) -> String:
	if w == null or not ARCS.has(w.id) or heard(w.id) >= (ARCS[w.id] as Array).size():
		return ""
	if not available(w).is_empty():
		return ""
	var b: Dictionary = (ARCS[w.id] as Array)[heard(w.id)]
	var day: int = crew.campaign.clock.day if crew and crew.campaign else 0
	if w.mind.trust < float(b.trust):
		return "has more to say once they trust you more"
	if day < int(b.day):
		return "has more to say in a few days"
	return ""


## The boss asks. Returns what they say ("" if nothing was available).
func ask(w: Worker) -> String:
	var b := available(w)
	if b.is_empty():
		return ""
	var day: int = crew.campaign.clock.day
	done[w.id] = heard(w.id) + 1
	w.mind.trust = clampf(w.mind.trust + TRUST_PER_BEAT, 0.0, maxf(WorkerMind.TRUST_CAP, w.mind.trust))
	if bool(b.get("insight", false)):
		_share_notes()
	if b.has("letter"):
		letters.append({"eid": w.id, "day": day + 1, "text": str(b.letter), "shown": false})
	if settled(w.id):
		w.emp["settled"] = true
	return str(b.say)


## Priya's notes: one step of certainty about one thing the boss has met
## and not yet worked out (never something unmet).
func _share_notes() -> void:
	var fn: FieldNotes = Game.director.notes if Game.director else null
	if fn == null:
		return
	var day: int = crew.campaign.clock.day
	for f in fn.met():
		if fn.stage(int(f)) < 3:
			fn.answered(int(f), day)
			return


## Morning: letters that came on the boat (once each).
func on_morning(day: int) -> void:
	for l in letters:
		if not bool(l.shown) and int(l.day) <= day:
			l.shown = true
			var e: Dictionary = crew.emp(str(l.eid))
			if not e.is_empty() and crew.campaign:
				crew.campaign.notice.emit("A letter came on the boat for %s. (Journal → Crew)" % str(e.name), 7.0)


## The letter this worker has received, if any (for the Journal).
func letter_for(eid: String) -> String:
	for l in letters:
		if str(l.eid) == eid and bool(l.shown):
			return str(l.text)
	return ""


func capture() -> Dictionary:
	return {"done": done.duplicate(), "letters": letters.duplicate(true)}


func restore(d: Dictionary) -> void:
	done = {}
	var src: Dictionary = d.get("done", {})
	for k in src:
		if ARCS.has(str(k)):
			done[str(k)] = clampi(int(src[k]), 0, 3)
	letters = []
	for l in d.get("letters", []):
		letters.append({"eid": str(l.get("eid", "")), "day": int(l.get("day", 0)), "text": str(l.get("text", "")), "shown": bool(l.get("shown", false))})
