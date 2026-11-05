class_name HelpText
extends RefCounted
## Phase 9: player-facing help shared by the title screen and the Journal.
## Rules are stated plainly; ordinary night presences are never described
## (no bestiary, no triggers). Keys always come from the live bindings.

static func controls() -> String:
	var k := func(a: String) -> String: return Keys.label(a)
	return "\n".join([
		"Move: %s %s %s %s · Sprint: %s (hold) · Crouch: %s · Jump: %s" % [k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right"), k.call("sprint"), k.call("crouch"), k.call("jump")],
		"Interact / use / pick up / talk: %s (tap)" % k.call("interact"),
		"Swing the axe: %s (tap per swing, or hold if \"Hold to keep chopping\" is on: same swing speed and work)" % k.call("attack"),
		"Axes: %s small · %s medium · %s large · %s chainsaw (only tools you own)" % [k.call("tool_small"), k.call("tool_medium"), k.call("tool_large"), k.call("tool_saw")],
		"Chainsaw: %s starts/stops the engine (or squeeze %s to start), hold %s for throttle - it cuts only while the running chain is in the wood" % [k.call("saw_engine"), k.call("attack"), k.call("attack")],
		"Set a carried load down gently: %s · Drop it: %s" % [k.call("set_down"), k.call("drop_load")],
		"Journal (contract, crew, money, help, recent messages): %s" % k.call("toggle_journal"),
		"Controls overlay: %s · Pause and settings: %s · Quick save: %s" % [k.call("toggle_help"), k.call("pause"), k.call("quick_save")],
		"In a truck: %s/%s drive, %s/%s steer, %s lights, %s get out" % [k.call("move_forward"), k.call("move_back"), k.call("move_left"), k.call("move_right"), k.call("headlights"), k.call("interact")],
		"All keys can be changed in Settings → Key bindings.",
	])


static func contract() -> String:
	return "\n".join([
		"The contract: clear the whole island in 30 days. Every original tree must be felled, its stump removed and all of its merchantable logs delivered to the camp yard.",
		"Pay: $100 per original tree, paid in shares as each of its logs is accepted at camp. Felling alone pays nothing. Trees never grow back.",
		"Crew: a standard campaign starts with 5 employees (the maximum; older legacy campaigns started with 2). Each active employee costs $300 per workday ($1,500 for five). Unpaid wages stay owed from their original day; after one more workday unpaid, that worker leaves. Paying part does not restart that grace, and firing does not cancel debt.",
		"Axes: small ×1.00, medium ×1.40, large ×1.96 work per hit, all at the same swing rhythm. The chainsaw cuts about 4× a hatchet while the chain is in the wood (about 3× over whole trees); no fuel or wear. Hard-working: ×1.25 cutting (once). Stronger: carries more by hand (not more in a truck). Timid: frightens sooner and heads home earlier.",
		"Gear (one of each worn; a better tier replaces a worse one): boots +3/6/9 % walking, gloves +2/4/6 % axe swing rhythm and a quicker saw start, helmet +2/4/6 % axe work per hit (axes only). Order tools and gear on the camper computer (Supplier); the supply boat brings them to the parcel locker by the payroll board, collected into camp storage at the tool rack. Orders are prepaid and refunded if the contract ends before they arrive.",
		"Crew: give gear at the tool rack or the computer's Gear app; workers put it on between jobs. Fellers keep others out of each tree's fall line; a log too heavy for one worker is carried by two when someone is free, otherwise dragged.",
		"Logs: new campaigns cut longer logs (about 1.5× the old length). Light logs are carried; a log too heavy for one load is dragged slowly (no jumping). The yard has a receiving cradle by the gate and three log decks outside the north-east fence. A log is paid the moment the yard accepts it; if the cradle and the nearby decks are full, the delivery is refused and nothing is paid until there is room.",
		"The fire burns only from its loading pile (up to 12 logs). Carry paid logs from the cradle or decks to the fire (Interact on the fire), or set your crew to yard work. The handcart beside the yard takes up to 4 logs: grab its handle with Interact, push it, and Interact at the cradle or a deck to unload. Trucks unload what fits and keep the rest.",
		"Trucks: up to 2, each with 3 seats (driver included) and room for 3 trees' worth of logs.",
		"Finishing: the moment every tree, stump and log is done, the contract completes, even before day 30. Paid logs still in the yard or burning in the pit do not count against you.",
	])


static func night() -> String:
	return "\n".join([
		"Each workday is 15 minutes of daylight and 5 minutes of dusk. Dusk is your return warning: you get messages at the start of dusk, halfway, and one minute before night.",
		"Your crew and the dog head for shelter at dusk. Workers who think you are ignoring the time may leave in a truck without you.",
		"At night during the contract, the camper is always safe, even with the door open. An occupied cabin is safe, and so are the pools of the working camp lamps. Moonlight, a flashlight or a screen's glow are NOT protection.",
		"Staying awake makes the night more uneasy. Being outside a safe place at night can end the attempt (you can reload the morning checkpoint).",
		"Night only ends when you sleep in your bed. Waiting does not bring morning. Whatever you think you see through a window does not make the camper unsafe.",
	])


static func time_rules() -> String:
	return "\n".join([
		"Paused (time, crew, night and every timer stop): the pause menu, Settings, the Journal and other management screens, mandatory rule cards, and the arcade games.",
		"Live (time keeps running): the couch and TV, talking to a worker, hiding, driving.",
		"Sleeping: one night per sleep, settled once (wages, reports, a morning checkpoint).",
		"During the survival days after a failed contract, time is continuous: beds do not skip time.",
	])


static func hunt() -> String:
	return "\n".join([
		"The company has left. Survive five full days (days 31-35); a rescue ship comes to the dock at dawn on day 36.",
		"Lights and the camper no longer guarantee safety. Something physical is hunting by what it hears and sees.",
		"Hide (under beds, desks or the dock, in closets, behind shelves), break line of sight and move quietly. Being seen going into a hiding place can give it away; places can be searched.",
		"Biscuit is safe in the dock building's dry alcove the whole time and boards the ship automatically. Do not go back for the dog.",
		"When the ship docks, get yourself and your surviving crew aboard within the boarding window.",
	])


## Phase 16: how the crew grows and how bedtime affects tomorrow.
static func growth_and_rest() -> String:
	return "\n".join([
		"Crew growth: workers earn merit only for useful work - felling, sectioning, stumps, moving logs closer to camp, loading trucks/the cart, and stacking or feeding the fire. Each tree is worth at most 1,000 merit shared by everyone who worked on it; your own work counts for you, not them. Merit never pays money and never changes wages.",
		"Levels and skills: merit raises a career level (1-20, a summary) and four skills - cutting (+2 % work per hit per level), handling (quicker lifting), driving (smoother corners, same top speed) and teamwork (quicker two-person lifts). All skill effects together are capped at +35 %.",
		"Reviews: the Journal's Crew tab and each end-of-day report show what everyone did, time spent working versus waiting (and why - a full yard or a blocked route is a logistics problem, not laziness), and a 'Thank them' button for a specific piece of work (once each).",
		"Your rest: a workday costs about 30-40 rest. After nightfall each awake minute costs about 5 more and makes tonight's sleep less restful (sleep quality falls to 25 % after 8 minutes). Going to bed before nightfall fully restores a normal day; one late night is recovered in a night or two. Below 70 rest you walk up to 15 % slower and cut up to 20 % weaker (at 0). The bed shows what tomorrow will be like before you sleep. Tiredness never hurts you and never makes the camper unsafe.",
		"Survival days: no sleeping to morning. Sitting still on the couch or staying hidden recovers a little (time keeps running).",
	])
