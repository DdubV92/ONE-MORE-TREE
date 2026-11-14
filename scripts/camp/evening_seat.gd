class_name EveningSeat
extends StaticBody3D
## Phase 27: a stump by the fire. At dusk, with the fire burning and the
## crew back in camp, the boss can sit with them once an evening: somebody
## tells a story, people calm down and trust grows a little. It gives the
## fire a purpose again; it changes nothing about the night.

const STORIES := {
	"sceptic": [
		"My old man logged forty years and the worst thing he ever met in the woods was a foreman.",
		"It's wind in the tops. I'll say it as often as you like.",
		"You know what's out there? Trees. A lot of trees.",
	],
	"unsure": [
		"I counted us twice at the gate tonight. Got the right number both times. Still counted.",
		"{other} says it's owls. {other} wasn't facing the way I was facing.",
		"I keep my axe by the bunk now. Don't ask me what for.",
	],
	"believer": [
		"I don't look at the treeline after the lamps come on. Rule I made.",
		"Whatever it is, it was here before the paint went on those trees.",
		"It knows the difference between us. That's the part I don't like.",
	],
	"home": [
		"First thing I do when the boat comes: a bath. A real one.",
		"My sister writes that the dog still waits at the door at six.",
		"Thirty days. I've done longer for less.",
		"When this is paid out I'm buying a truck that starts.",
	],
}


func setup(at: Vector3) -> void:
	name = "EveningSeat"
	position = at
	BuildKit.cylinder(self, 0.26, 0.42, Vector3(0, 0.21, 0), "dark_wood", false, 10)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.3
	sh.height = 0.5
	cs.shape = sh
	cs.position = Vector3(0, 0.25, 0)
	add_child(cs)


func get_interact_text() -> String:
	var crew: CrewService = Game.crew
	if crew == null:
		return "A stump by the fire"
	var why := crew.evening_blocker()
	return "Sit with the crew by the fire" if why == "" else "A stump by the fire (%s)" % why


func interact(by: Node) -> void:
	var crew: CrewService = Game.crew
	if crew == null:
		return
	var r := crew.sit_evening()
	var msg := ""
	if bool(r.ok):
		msg = "You sit by the fire with %s.\n%s: \"%s\"\nNobody says much after that. It helps anyway." % [", ".join(r.names), str(r.teller), str(r.story)]
	else:
		msg = str(r.reason)
	if by.has_method("show_message"):
		by.show_message(msg)


## A line for this worker tonight (their belief decides the kind; every
## third evening somebody talks about home instead).
static func story_for(belief: float, day: int, other: String) -> String:
	var kind := "home" if day % 3 == 0 else ("sceptic" if belief < 0.3 else ("unsure" if belief < 0.6 else "believer"))
	var pool: Array = STORIES[kind]
	return str(pool[day % pool.size()]).replace("{other}", other if other != "" else "Somebody")
