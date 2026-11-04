class_name CrewDialogue
extends RefCounted
## Original crew lines (Phase 4). Each topic has general lines and optional
## trait variants; `line()` picks from the speaker's actual state and never
## repeats the previous line for that topic. Captions are the product; no
## voice files are required.

const LINES := {
	"greet": [
		"Boss.", "Morning, boss. Or whatever time it is out here.", "What do you need?",
	],
	"greet_sociable": ["There you are! Was starting to think it was just us and the trees."],
	"work_felling": [
		"Working on {target}. Should be down soon - stay out of the fall line.",
		"This one's fighting me, but it'll go.",
	],
	"work_felling_hard_working": ["Two more after this one if the light holds."],
	"work_processing": [
		"Bucking the trunk into carry-sized pieces.",
		"Cutting at your orange marks. Neat work, whoever painted them.",
	],
	"work_hauling": [
		"Hauling to the rack. These add up fast.",
		"Every log on that rack is money in the tin, right?",
	],
	"work_hauling_stronger": ["I can take a bit more than most. Point me at the heavy ones."],
	"work_idle": [
		"Looking for the next job.", "Nothing claimed near here. Want me somewhere else?",
	],
	"work_home": ["Heading in. The cabin's where I want to be when it gets dark."],
	"work_follow": ["Right behind you."],
	"equipment": [
		"Using a {axe} axe.",
		"{axe} axe. Gets the job done.",
	],
	"equipment_small": ["A bigger axe would make a real difference, if the company can spare one."],
	"wages_ok": [
		"Paid up. No complaints.", "Wages are square. Appreciate it.",
	],
	"wages_owed": [
		"You owe me ${owed}. I need it by the end of day {due}.",
		"I'm still waiting on ${owed}. End of day {due}, boss - I mean it.",
	],
	"wages_owed_timid": ["I don't like asking, but... ${owed}. By day {due}, please."],
	"strange_none": [
		"Strange? Just the usual noises. Wind, birds, the fire.",
		"Nothing I could put a name to.",
	],
	"strange_none_skeptical": ["It's an old forest. Old forests creak. That's all it is."],
	"strange_uncertain": [
		"I heard something near {where}. Could've been an animal. Probably was.",
		"There was a sound out by {where}. I didn't like it, but I didn't see anything.",
	],
	"strange_confirmed": [
		"I saw it. Near {where}. Don't tell me I didn't.",
		"Something was standing at the trees by {where}. Too tall. Too still.",
	],
	"strange_voice": [
		"It used {name}'s voice. {name} was right next to me.",
	],
	"report_skeptic_rumor": [
		"I believe you saw something. I don't believe it was what you think.",
		"Shadows play tricks out here, boss. Get some sleep.",
	],
	"report_rumor": [
		"...You're serious. Alright. I'll keep my eyes open.",
		"Don't say that. Not out here.",
	],
	"report_corroborated": [
		"You're not the first to say it. I'm listening.",
	],
	"reassure_helped": [
		"Yeah. Yeah, okay. We stick together.", "Thanks. I needed to hear that.",
	],
	"reassure_hollow": [
		"Easy for you to say.", "I know what I saw.",
	],
	"reassure_cooldown": ["You already said. I'm trying."],
	"dismiss_hurt": ["Right. Forget I said anything."],
	"concern": [
		"I'm not sleeping right. Something about this place.",
		"Can we keep the crew closer together today?",
	],
	"concern_timid": ["I don't want to be the last one out there. Please."],
	"refuse_risk": [
		"Not out there. Not that far. I'll work close to camp.",
		"I'll do the job, but nowhere near the treeline after dark.",
	],
	"departure_warning": [
		"Boss, I'm thinking about leaving. One more night like that and I'm on the boat.",
		"If it happens again, I'm done. I'm telling you now so you know.",
	],
	"quit_fear": [
		"I'm sorry. I can't stay. I'm taking the next boat.",
	],
	"quit_wages": [
		"I told you I needed that money. I'm done. I'll be on the next boat.",
	],
	"fired": [
		"...Fine. You still owe me what I earned.",
		"Your call. I'll get my things and wait for the boat.",
	],
	"dusk_reminder": [
		"We'll need to head back soon, boss.", "Light's going. A few more minutes, then I'm walking in.",
	],
	"dusk_reminder_timid": ["It's getting dark. I'm going in early, if that's alright."],
	"hunt_warning": [
		"It's here - get down!",
		"Quiet. It's by the fence.",
		"I see it. Hide!",
		"Don't move. It's listening.",
	],
	"hunt_warning_timid": [
		"Oh god, oh god - it's right there -",
	],
	"hunt_regroup": [
		"The ship! Get to the dock!",
		"That's the horn - go, go!",
	],
	"dusk_return": [
		"That's it, I'm heading back to camp.", "Walking in now. Don't stay out late.",
	],
	"dusk_refuse": [
		"Too late for that. I won't make it back before dark.",
		"No. Not with the light this low. Tomorrow.",
	],
	"dusk_refuse_hard_working": ["I'd love to, but I'm not getting stuck out here at night. First thing tomorrow."],
	"follow_ack": ["Lead the way.", "Sticking with you."],
	"job_ack": ["On it.", "Got it.", "Sure thing."],
	"route_too_long": ["That's too far to get there and back before dark."],
	"arrived": ["Hello! Where do you want me?", "Nice island. Very... trees."],
	"departing": ["Waiting for the boat.", "Just waiting for my ride off this rock."],
}


## Picks a line for `topic`, preferring a trait variant when one applies,
## never repeating the last line used for that topic by this speaker.
static func line(topic: String, traits: Array, last: Dictionary, vars := {}) -> String:
	var pool: Array = []
	for t in traits:
		var k := "%s_%s" % [topic, t]
		if LINES.has(k):
			pool.append_array(LINES[k])
	if LINES.has(topic):
		pool.append_array(LINES[topic])
	if pool.is_empty():
		return "..."
	var prev := str(last.get(topic, ""))
	var choice: String = pool[0]
	for p in pool:
		if p != prev:
			choice = p
			break
	# Rotate so the next call picks a different line.
	if pool.size() > 1 and choice == prev:
		choice = pool[1]
	last[topic] = choice
	var out := choice
	for k in vars:
		out = out.replace("{%s}" % k, str(vars[k]))
	return out


static func line_count() -> int:
	var n := 0
	for k in LINES:
		n += (LINES[k] as Array).size()
	return n
