class_name DogRescue
extends Node
## T26 "The Night the Dog Runs": the once-per-campaign recoverable rescue.
## States: IDLE -> ELIGIBLE -> ARMED -> WINDDOOR -> ESCAPE -> SEARCH ->
## REUNION -> RETURN_HOME -> RESOLVED (+ RECOVERY). A pre-event checkpoint
## and the persistent trigger id are written before the door opens; reload
## never replays the wind-door scare. The real dog (one identity) runs a
## validated 60-150 m route to reachable cover and WAITS there. While the
## objective is active, sleep is replaced by "Find your dog" and the
## ordinary catch has a protected grace window (pause excluded).

signal changed(state: String)

const MIN_DAY := 4
const SEARCH_GRACE := 200.0
const ASSIST_AFTER := 480.0
const TRIGGER_CHANCE := 0.35

var state := "IDLE"
var trigger_id := ""
var spot := Vector3.INF
var t := 0.0                   # seconds in the current state (pause excluded)
var night_checked := -1        # day already rolled for this campaign
var arm_at := -1.0
var beats: Array[String] = []  # T26 beats that actually happened
var forced := false            # preview fixture
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2626


func active() -> bool:
	return state in ["ARMED", "WINDDOOR", "ESCAPE", "SEARCH", "REUNION", "RETURN_HOME", "RECOVERY"]


func blocks_sleep() -> bool:
	return state in ["WINDDOOR", "ESCAPE", "SEARCH", "REUNION", "RETURN_HOME", "RECOVERY"]


func _beat(id: String) -> void:
	if not beats.has(id):
		beats.append(id)


func _goto(s: String) -> void:
	state = s
	t = 0.0
	changed.emit(s)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	t += delta
	match state:
		"IDLE":
			_check_eligible()
		"ELIGIBLE":
			var c: CampaignService = Game.campaign
			if c == null or c.clock.phase() != WorkdayClock.Phase.NIGHT or not _preconditions():
				_goto("IDLE")
			elif t >= arm_at:
				_arm()
		"ARMED":
			if t > 0.2:
				_wind_door()
		"WINDDOOR":
			if t > 1.2:
				_escape()
		"ESCAPE":
			var d := Game.dog
			if d and d.state == CampDog.State.RESCUE_WAIT:
				_goto("SEARCH")
				if Game.threat:
					Game.threat.grant_grace(SEARCH_GRACE + _route_bonus())
				_beat("T26-E018")
				_beat("T26-E019")
				Game.objective = "Find your dog - Biscuit ran out. Follow the whining."
			elif t > 45.0:
				_recover()
		"SEARCH":
			if t > ASSIST_AFTER:
				# Technical/stalled search: the dog finds its own way home.
				_goto("RETURN_HOME")
				Game.dog.rescue_home()
				_beat("T26-E025")
				if Game.player:
					Game.player.show_message("Biscuit found the way back on its own.")
		"REUNION":
			if t > 1.5:
				_goto("RETURN_HOME")
				Game.dog.follow_owner()
				Game.objective = "Take Biscuit home to the camper."
		"RETURN_HOME":
			var dog := Game.dog
			if dog == null:
				return
			var p := Game.player as Node3D
			# Home: the boss is in the camper (or near its door) - the dog goes
			# in through the flap and settles; sleep is restored.
			if dog.routine == "rescue" and p and _near_camper(p.global_position, 4.0) and _near_camper(dog.global_position, 9.0):
				dog.rescue_home()
			if dog.routine == "camp" and (dog.state == CampDog.State.SLEEP or (dog.inside_camper() and dog.state != CampDog.State.GO_HOME)):
				_resolve()
			elif t > 300.0 and dog.routine == "rescue":
				dog.rescue_home()


func _route_bonus() -> float:
	if Game.player == null or spot == Vector3.INF:
		return 0.0
	return clampf((spot.distance_to(Game.player.global_position) - 80.0) * 0.6, 0.0, 120.0)


func _preconditions() -> bool:
	var c: CampaignService = Game.campaign
	if c == null or not c.active or Game.dog == null or Game.player == null:
		return false
	if c.contract.state != ContractService.ACTIVE or c.clock.is_final_day():
		return false
	if Game.hunt and Game.hunt.hunt_active():
		return false
	if not forced and (c.clock.day < MIN_DAY or Game.dog.pets < 1):
		return false
	# Before sleep, awake in the camper, dog asleep on its bed.
	if c.get("_sleeping") == true:
		return false
	if TerrorPlacement.context_of(Game.player) not in ["camper", "cameras"]:
		return false
	return Game.dog.state == CampDog.State.SLEEP


func _check_eligible() -> void:
	if trigger_id != "":
		return       # at most once per campaign
	var c: CampaignService = Game.campaign
	if c == null or c.clock.phase() != WorkdayClock.Phase.NIGHT:
		return
	if not forced and night_checked == c.clock.day:
		return
	if not _preconditions():
		return
	night_checked = c.clock.day
	if forced or _rng.randf() < TRIGGER_CHANCE:
		arm_at = 3.0 if forced else _rng.randf_range(20.0, 90.0)
		_goto("ELIGIBLE")


func force_start() -> void:
	forced = true
	if Game.dog and Game.dog.state != CampDog.State.SLEEP:
		Game.dog.go_home()


## Checkpoint + persistent trigger id BEFORE the door opens.
func _arm() -> void:
	spot = _pick_spot()
	if spot == Vector3.INF:
		_goto("IDLE")
		return
	trigger_id = "RESCUE-D%02d" % (Game.campaign.clock.day if Game.campaign else 0)
	_goto("ARMED")
	if Game.world_root:
		Game.world_root.save_checkpoint("rescue")
		Game.world_root.save_campaign()


## A reachable spot 60-150 m out along the familiar trail side, with cover,
## on dry supported ground, reachable on the crew grid.
func _pick_spot() -> Vector3:
	var nav := Game.crew.nav if Game.crew and Game.crew.nav and Game.crew.nav.built else null
	if nav == null:
		return Vector3.INF
	var gate: Vector3 = nav.gates[0].outside
	var away := (gate - World.camp_origin())
	away.y = 0.0
	away = away.normalized()
	for i in 40:
		var c := TerrorPlacement.treeline_point(gate, away, 50.0, 130.0, 0.9, _rng)
		if c == Vector3.INF:
			continue
		if c.distance_to(World.camp_origin()) < 60.0 or c.distance_to(World.camp_origin()) > 150.0:
			continue
		if nav.find_path(gate, c).is_empty():
			continue
		return c
	return Vector3.INF


func _wind_door() -> void:
	_goto("WINDDOOR")
	_beat("T26-E006")
	_beat("T26-E007")
	_beat("T26-E017")
	var door := Game.dog._camper_door() if Game.dog else null
	var at := door.global_position if door else Game.player.global_position
	_play("wind_roar", at + Vector3(2.0, 1.5, 0), 0.0)
	if door:
		door.set_open(true)
		_play("door_bang", door.global_position + Vector3(0, 1.0, 0), -2.0)
	if Game.player:
		Game.player.show_message("A roar of wind throws the camper door open -")


func _escape() -> void:
	_goto("ESCAPE")
	_beat("T26-E008")
	_beat("T26-E009")
	var d := Game.dog
	if d == null or not d.rescue_run(spot):
		_recover()
		return
	if Game.player:
		Game.player.show_message("Biscuit bolts out into the dark. Find your dog.")
	Game.objective = "Find your dog - Biscuit ran out toward the north trail."


## Invalid route/pose: the same dog waits at a verified point by the gate.
func _recover() -> void:
	var nav := Game.crew.nav if Game.crew and Game.crew.nav else null
	if nav == null or Game.dog == null:
		_goto("RESOLVED")
		return
	var g: Vector3 = nav.gates[0].outside
	Game.dog.global_position = g
	Game.dog.routine = "rescue"
	Game.dog.state = CampDog.State.RESCUE_WAIT
	spot = g
	_goto("SEARCH")
	if Game.threat:
		Game.threat.grant_grace(SEARCH_GRACE)
	Game.objective = "Find your dog - waiting near the north gate."


## Called when the boss reaches and pets the waiting dog.
func reunite(by: Node) -> void:
	if state != "SEARCH":
		return
	_goto("REUNION")
	_beat("T26-E005")
	_beat("T26-E003")
	if by and by.has_method("show_message"):
		by.show_message("There you are. Good dog, Biscuit. Let's go home.")
	Game.dog.state = CampDog.State.PET


func _resolve() -> void:
	_goto("RESOLVED")
	_beat("T26-E010")
	_beat("T26-E020")
	Game.objective = ""
	var door := Game.dog._camper_door() if Game.dog else null
	if door and door.is_open:
		door.set_open(false)
	if Game.player:
		Game.player.show_message("Biscuit is home and settled. You can sleep now.")


func _near_camper(p: Vector3, r: float) -> bool:
	var c := World.camp_origin() + CampLayout.CAMPER_POS
	return Vector2(p.x - c.x, p.z - c.z).length() < r + 5.0


func _play(n: String, at: Vector3, db: float) -> void:
	var path := "res://audio/generated/%s.wav" % n
	if not ResourceLoader.exists(path):
		return
	var s: AudioStream = load(path)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "Horror"
	p.unit_size = 10.0
	p.volume_db = db
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
	SoundEvents.emit(s, at, db, "terror", "")


func capture() -> Dictionary:
	return {"state": state, "trigger_id": trigger_id, "spot": [spot.x, spot.y, spot.z] if spot != Vector3.INF else [], "t": t, "night_checked": night_checked, "beats": beats.duplicate()}


## Loading never replays the door scare: an interrupted ARMED/WINDDOOR/
## ESCAPE resumes as SEARCH with the dog waiting at the spot.
func restore(d: Dictionary) -> void:
	state = str(d.get("state", "IDLE"))
	trigger_id = str(d.get("trigger_id", ""))
	night_checked = int(d.get("night_checked", -1))
	var sp: Array = d.get("spot", [])
	spot = Vector3(float(sp[0]), float(sp[1]), float(sp[2])) if sp.size() == 3 else Vector3.INF
	beats.clear()
	for b in d.get("beats", []):
		beats.append(str(b))
	t = 0.0
	if state == "ELIGIBLE":
		state = "IDLE"
	if state in ["ARMED", "WINDDOOR", "ESCAPE"]:
		if spot == Vector3.INF:
			state = "RESOLVED"
		else:
			state = "SEARCH"
	if state == "SEARCH" and Game.dog and spot != Vector3.INF:
		Game.dog.routine = "rescue"
		Game.dog.global_position = spot
		Game.dog.state = CampDog.State.RESCUE_WAIT
		Game.objective = "Find your dog - follow the whining."
		if Game.threat:
			Game.threat.grant_grace(SEARCH_GRACE)
	elif state in ["REUNION", "RETURN_HOME"] and Game.dog:
		state = "RETURN_HOME"
		Game.dog.follow_owner()
		Game.objective = "Take Biscuit home to the camper."
	elif state == "RESOLVED":
		Game.objective = ""
