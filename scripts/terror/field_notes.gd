class_name FieldNotes
extends RefCounted
## Phase 26: what the boss has worked out about the nights. Every Terror
## family follows one rule that is true in the simulation (TerrorEncounter
## applies it), and this notebook fills in as the player witnesses a family
## and then sees its rule work. It records what a thing does, never what it
## is or where it came from.
##
## Stages per family:
##   0  never met        not listed
##   1  met              what it looked or sounded like
##   2  a hint           after meeting it a few times, or answering it once
##   3  the rule         after the answer has worked twice
## Saved with the campaign. Nothing here affects safety.

signal note_changed(family: int, stage: int)

const HINT_AFTER_SEEN := 3
const HINT_AFTER_ANSWERED := 1
const RULE_AFTER_ANSWERED := 2

## Rule kinds (see TerrorEncounter._rule_met):
##   watched    keep looking straight at it
##   look_away  take your eyes off it and keep them off
##   still      stop moving
##   approach   walk toward where it seems to be
##   leave      put distance between you and the place
##   cover      get under a roof or thick canopy
##   lamp       stand in a real safe light
##   feed       switch the monitor off
##   companion  have the real dog beside you
##   ignore     nothing is asked of you; it passes
const FAMILIES := {
	1: {"name": "The Tall Woman Beyond the Trees", "rule": "look_away",
		"met": "Somebody far too tall, standing among the trunks in a wide dark hat. I never saw a face.",
		"hint": "She was nearer after I stared. She was gone after I made myself look at my boots.",
		"know": "Do not stare. Look away and keep looking away, and she goes."},
	2: {"name": "The Voice Wearing Someone Else", "rule": "still",
		"met": "One of the crew called me from the dark. They were in bed at the time.",
		"hint": "It called again each time I took a step toward it.",
		"know": "It wants to be followed. Stand where you are and it gives up."},
	3: {"name": "The Antlered Wing", "rule": "cover",
		"met": "Something wide crossed the sky with branches where a head should be. Mostly I heard it.",
		"hint": "It lost me when I went under the trees.",
		"know": "It hunts open sky. Get under a roof or thick canopy."},
	4: {"name": "The Low White Shape", "rule": "still",
		"met": "Low to the ground and pale, too many joints, moving between the roots.",
		"hint": "It only moved when I did.",
		"know": "It follows movement. Stand dead still until it loses interest."},
	5: {"name": "The Faceless Surveyor", "rule": "watched",
		"met": "A thin man a long way off, standing as if he were taking a measurement of me.",
		"hint": "He does not like being measured back.",
		"know": "Look straight at him and hold it. He leaves."},
	6: {"name": "The Worker Who Never Came Back", "rule": "watched",
		"met": "Someone finishing a shift at the treeline after everyone was home. Everyone was home.",
		"hint": "It walked off when I kept my eyes on it.",
		"know": "Watch it properly. It only keeps working while nobody is checking."},
	7: {"name": "The Guest at the Window", "rule": "look_away",
		"met": "The feeling of a face at the glass. Curtain, reflection, something.",
		"hint": "It stays as long as I keep checking the window.",
		"know": "Stop looking at the window. It needs to be looked back at."},
	8: {"name": "The Knocking Rule", "rule": "ignore",
		"met": "Knocking in a pattern, on wood that nobody was near.",
		"hint": "I answered once. Nothing changed. I ignored it once. Nothing changed.",
		"know": "It asks for nothing. There is no answer to give, and it stops on its own."},
	9: {"name": "The Backward Walker", "rule": "watched",
		"met": "A person walking the wrong way round, far off, never tripping.",
		"hint": "It covers ground when I look elsewhere.",
		"know": "Keep it in sight. It only travels while unwatched, and it leaves if it cannot."},
	10: {"name": "The Dog That Is Not Your Dog", "rule": "companion",
		"met": "Biscuit barking out in the dark. Biscuit was asleep by the stove.",
		"hint": "It has never once called while Biscuit was beside me.",
		"know": "Keep the real dog close. It will not call over the top of her."},
	11: {"name": "The Drowned Walker", "rule": "leave",
		"met": "Somebody wading where nobody should be, soaked through, making no hurry.",
		"hint": "It did not come up the bank after me.",
		"know": "It keeps to the water. Walk away inland and it stays behind."},
	12: {"name": "The Lantern Procession", "rule": "lamp",
		"met": "A line of small lights going somewhere through the trees. I could not keep count of them.",
		"hint": "Their lights do nothing for me. Ours still do.",
		"know": "Their lanterns are not lamps. Stand in a real camp light and they pass by."},
	13: {"name": "The Boundary That Seems to Move", "rule": "lamp",
		"met": "The fence looked further off than it is, and the way home looked wrong.",
		"hint": "The camp lamps were exactly where they always are.",
		"know": "Distance lies; the lamps do not. Walk to a real light and it stops."},
	14: {"name": "The Hanging Shadows", "rule": "leave",
		"met": "Long shapes hanging in a crown. Coats, I told myself. Branches.",
		"hint": "They are only there from where I was standing.",
		"know": "Do not go under them to make sure. Walk on and they are not there."},
	15: {"name": "The Camera Audience", "rule": "feed",
		"met": "Something on a camera that knew which camera I was watching.",
		"hint": "It is only ever there while the screen is on.",
		"know": "It performs for the monitor. Switch the screen off."},
	16: {"name": "The Room That Loses Its Warmth", "rule": "ignore",
		"met": "The light in the room went thin and cold, and everything in it looked borrowed.",
		"hint": "Nothing in the room had actually changed. I checked.",
		"know": "The room is still the room. It asks for nothing and it passes."},
	17: {"name": "The Choir in the Dead Air", "rule": "approach",
		"met": "The wind nearly made words. Then it was only wind.",
		"hint": "It was never where it sounded like it was.",
		"know": "Walk at it. It cannot hold together when someone comes to listen."},
	18: {"name": "The Axe Beneath the Ground", "rule": "approach",
		"met": "Somebody chopping, steady, in a place we have not cut.",
		"hint": "It stopped when I started toward it.",
		"know": "Go and look. It only works while nobody comes to check."},
	19: {"name": "The Room That Sounds Occupied", "rule": "approach",
		"met": "Somebody moving about next door. Nobody was next door.",
		"hint": "It went quiet when I walked over.",
		"know": "Go to it. The room is empty, and then it is quiet."},
	20: {"name": "The Afterimage on the Trail", "rule": "look_away",
		"met": "A person on the trail, for exactly as long as it took to turn my head.",
		"hint": "It is only there the second time I look.",
		"know": "Do not look twice. Keep your eyes forward and it has nothing to stand in."},
	21: {"name": "The Uninvited Fifth", "rule": "watched",
		"met": "One more of us than there should have been.",
		"hint": "It cannot stand being counted.",
		"know": "Look right at the extra one and count. It will not stay to be the last number."},
	22: {"name": "The Bell That Finds You", "rule": "still",
		"met": "A small bell, somewhere behind me, keeping pace.",
		"hint": "It rang when I walked and it did not ring when I did not.",
		"know": "It follows footsteps. Stop, wait, and it loses you."},
	23: {"name": "The Patch Without Stars", "rule": "cover",
		"met": "A piece of the sky with nothing in it, and it was not cloud.",
		"hint": "I felt better with a roof between us.",
		"know": "Do not stand under it. Get beneath a roof or the canopy until it has gone."},
	24: {"name": "The Red Thread", "rule": "ignore",
		"met": "Red thread tied where we had been working. None of us tied it.",
		"hint": "Never on a tree we had not touched. Gone by morning, every time.",
		"know": "It marks; it does nothing else. Leave it. It is gone by morning."},
	25: {"name": "The Live Feed That Lies", "rule": "feed",
		"met": "The camera showed me something the yard did not.",
		"hint": "The cameras were fine. The picture was not.",
		"know": "Trust the yard, not the picture. Switch the screen off and look for yourself."},
}

const RULE_HELP := {
	"watched": "Keep looking straight at it.",
	"look_away": "Look away and keep looking away.",
	"still": "Stand still.",
	"approach": "Walk toward it.",
	"leave": "Walk away from the place.",
	"cover": "Get under a roof or thick canopy.",
	"lamp": "Stand in a real camp light.",
	"feed": "Switch the monitor off.",
	"companion": "Keep the real dog beside you.",
	"ignore": "Nothing. It passes.",
}

## family (int) -> {seen, answered, first_day}
var notes := {}


static func rule_of(family: int) -> String:
	return str((FAMILIES.get(family, {}) as Dictionary).get("rule", ""))


static func name_of(family: int) -> String:
	return str((FAMILIES.get(family, {}) as Dictionary).get("name", "Something"))


func stage(family: int) -> int:
	if not notes.has(family):
		return 0
	var n: Dictionary = notes[family]
	if int(n.answered) >= RULE_AFTER_ANSWERED:
		return 3
	if int(n.answered) >= HINT_AFTER_ANSWERED or int(n.seen) >= HINT_AFTER_SEEN:
		return 2
	return 1


func knows_rule(family: int) -> bool:
	return stage(family) >= 3


func _entry(family: int, day: int) -> Dictionary:
	if not notes.has(family):
		notes[family] = {"seen": 0, "answered": 0, "first_day": day}
	return notes[family]


## The player was there for an encounter of this family.
func witness(family: int, day: int) -> int:
	if not FAMILIES.has(family):
		return 0
	var before := stage(family)
	var n := _entry(family, day)
	n.seen = int(n.seen) + 1
	var after := stage(family)
	if after != before:
		note_changed.emit(family, after)
	return after


## The family's rule ended an encounter (the right answer, or for the
## families that ask for nothing, leaving it alone).
func answered(family: int, day: int) -> int:
	if not FAMILIES.has(family):
		return 0
	var before := stage(family)
	var n := _entry(family, day)
	n.answered = int(n.answered) + 1
	var after := stage(family)
	if after != before:
		note_changed.emit(family, after)
	return after


## Lines for one family at its current stage (name first).
func lines(family: int) -> PackedStringArray:
	var out := PackedStringArray()
	var st := stage(family)
	if st <= 0:
		return out
	var f: Dictionary = FAMILIES[family]
	out.append(str(f.name))
	out.append(str(f.met))
	if st >= 2:
		out.append(str(f.hint))
	if st >= 3:
		out.append("WHAT WORKS: " + str(f.know))
	return out


## Families met so far, in the order they were first met.
func met() -> Array:
	var ids := notes.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var da := int(notes[a].first_day)
		var db := int(notes[b].first_day)
		return da < db if da != db else a < b)
	return ids


func rules_known() -> int:
	var n := 0
	for f in notes:
		if stage(int(f)) >= 3:
			n += 1
	return n


func capture() -> Dictionary:
	var out := {}
	for f in notes:
		out[str(f)] = (notes[f] as Dictionary).duplicate()
	return {"version": 1, "notes": out}


func restore(d: Dictionary) -> void:
	notes.clear()
	var src: Dictionary = d.get("notes", {})
	for k in src:
		var f := int(k)
		if not FAMILIES.has(f):
			continue
		var n: Dictionary = src[k]
		notes[f] = {"seen": maxi(int(n.get("seen", 0)), 0), "answered": maxi(int(n.get("answered", 0)), 0), "first_day": int(n.get("first_day", 1))}
