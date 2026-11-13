class_name EscapeBeacon
extends Node
## Phase 25: the hard way off the island. When nobody is coming (the
## contract failed, or the ship left without you), the dock building's
## emergency beacon is the only thing that can reach anyone - and it is
## dead. Three parts are missing; the spares are in three places across
## the island. Carry them back, fit them, switch it on and hold out until
## the answering ship reaches the dock at the next dawn. The Foreman hears
## every part you take, and hears the beacon the whole time it calls.
##
## State lives here and is saved with the hunt; HuntService owns the ship.

signal changed

const PARTS := ["battery", "coil", "fuse"]
const LABEL := {"battery": "beacon battery", "coil": "antenna coil", "fuse": "signal fuse"}
const CALL_PING := 45.0          # seconds between beacon pulses the Foreman hears

var active := false              # parts are out in the world (stranded only)
var part_state := {"battery": "missing", "coil": "missing", "fuse": "missing"}   # missing / carried / installed
var state := "dead"              # dead / ready / calling / answered
var sites := {}                  # part -> Vector3 (world)
var where := {}                  # part -> short place description
var _props := {}                 # part -> Node3D
var _ping := 0.0


func hunt() -> HuntService:
	return get_parent() as HuntService


## Puts the three spares out in the world (idempotent).
func activate() -> void:
	if active:
		_build_props()
		return
	active = true
	_pick_sites()
	_build_props()
	changed.emit()


func _pick_sites() -> void:
	var camp := World.camp_origin()
	var far: Array[Vector3] = []
	var names: Array[String] = []
	# Island r2: the two far field sheds hold the battery and the coil.
	var sc: SurvivalCover = Game.survival_cover
	if sc:
		for shed in sc.sheds:
			if is_instance_valid(shed):
				far.append(shed.global_position)
				names.append("field shed")
	# Otherwise (or if a shed is missing): survey caches far from camp.
	var ang := 0.7
	var guard := 0
	while far.size() < 2 and guard < 64:
		guard += 1
		ang += 2.4
		var p := camp + Vector3(sin(ang), 0, cos(ang)) * (230.0 + 20.0 * (guard % 4))
		if not World.in_bounds(Vector2(p.x, p.z)) or World.water_depth_at(p.x, p.z) > 0.0 or World.height_at(p.x, p.z) < World.sea_level + 1.0:
			continue
		if not far.is_empty() and far[0].distance_to(p) < 150.0:
			continue
		far.append(p)
		names.append("survey cache")
	for i in mini(far.size(), 2):
		var part: String = PARTS[i]
		var q := far[i] + Vector3(2.2, 0, 0.6)
		q.y = World.height_at(q.x, q.z)
		sites[part] = q
		where[part] = "the %s %s of camp" % [names[i], _compass(q - camp)]
	# The fuse is in the sawmill's control box (or the camp tool area).
	var f := CampLayout.world(Vector3(CampLayout.MILL_LINE_X + 2.6, 0.0, 3.4))
	f.y = World.height_at(f.x, f.z)
	sites["fuse"] = f
	where["fuse"] = "the sawmill control box at camp"


static func _compass(d: Vector3) -> String:
	var a := fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)
	return ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"][int(round(a / 45.0)) % 8]


func _build_props() -> void:
	for part in PARTS:
		if _props.has(part) and is_instance_valid(_props[part]):
			continue
		if part_state[part] != "missing" or not sites.has(part):
			continue
		var n := Node3D.new()
		n.name = "BeaconSpare_%s" % part
		get_parent().get_parent().add_child(n)
		n.global_position = sites[part]
		# A small orange company crate: visible, readable, not a marker.
		var crate := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.55, 0.38, 0.4)
		crate.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.86, 0.42, 0.1)
		m.roughness = 0.7
		crate.material_override = m
		crate.position = Vector3(0, 0.19, 0)
		n.add_child(crate)
		var p: String = part
		Hotspot.make(n, "Take", Vector3(0.9, 0.8, 0.8), Vector3(0, 0.3, 0),
			func() -> String: return "Take the %s" % LABEL[p],
			func(by: Node) -> void: take(p, by))
		_props[part] = n


func take(part: String, by: Node = null) -> bool:
	if part_state.get(part, "") != "missing":
		return false
	part_state[part] = "carried"
	if _props.has(part) and is_instance_valid(_props[part]):
		(_props[part] as Node).queue_free()
	_props.erase(part)
	if by and by.has_method("show_message"):
		by.show_message("You have the %s (%d of 3). Fit it at the beacon in the dock building." % [LABEL[part], carried_or_fitted()])
	# Prising a crate open is not quiet.
	var h := hunt()
	if h and h.foreman and is_instance_valid(h.foreman) and sites.has(part):
		h.foreman.hear(sites[part], 70.0, "metal")
	changed.emit()
	return true


func carried_or_fitted() -> int:
	var n := 0
	for part in PARTS:
		if part_state[part] != "missing":
			n += 1
	return n


func fitted() -> int:
	var n := 0
	for part in PARTS:
		if part_state[part] == "installed":
			n += 1
	return n


## The beacon console: prompt text for the player's interaction ray.
func console_prompt() -> String:
	if not active:
		return "Check the emergency beacon"
	match state:
		"calling":
			return "Check the beacon (transmitting)"
		"answered":
			return "Check the beacon (answered)"
	for part in PARTS:
		if part_state[part] == "carried":
			return "Fit the %s to the beacon" % LABEL[part]
	if fitted() == 3:
		return "Switch the beacon on"
	return "Check the dead beacon"


## Using the console: fit what you carry, then switch on, else report.
func console_use(by: Node) -> void:
	var say := func(t: String) -> void:
		if by and by.has_method("show_message"):
			by.show_message(t)
	if state == "calling":
		say.call("BEACON: transmitting. A ship has answered and will reach the dock at dawn. It can be heard a long way off.")
		return
	if state == "answered":
		say.call("BEACON: the ship is here. Get to the gangway.")
		return
	var did := false
	for part in PARTS:
		if part_state[part] == "carried":
			part_state[part] = "installed"
			did = true
	if did:
		if fitted() == 3:
			state = "ready"
			say.call("All three parts are fitted. The beacon has power. Switching it on will be loud.")
		else:
			say.call("Fitted. %s" % missing_text())
		changed.emit()
		return
	if fitted() == 3:
		switch_on(by)
		return
	say.call("BEACON: dead. %s" % missing_text())


func missing_text() -> String:
	var out := PackedStringArray()
	for part in PARTS:
		if part_state[part] == "missing":
			out.append("%s (spare in %s)" % [LABEL[part], str(where.get(part, "the island"))])
	return "Still missing: %s." % ", ".join(out) if not out.is_empty() else "Nothing is missing."


func switch_on(by: Node = null) -> bool:
	if fitted() < 3 or state in ["calling", "answered"]:
		return false
	state = "calling"
	_ping = 0.0
	if Game.dock_site:
		Game.dock_site.beacon_state = "requested"
	if by and by.has_method("show_message"):
		by.show_message("The beacon wails out over the water. A ship answers: it will reach the dock at dawn. Stay alive until then.")
	_pulse()
	changed.emit()
	return true


func calling() -> bool:
	return state == "calling"


func _process(delta: float) -> void:
	if state != "calling" or get_tree().paused:
		return
	_ping += delta
	if _ping >= CALL_PING:
		_ping = 0.0
		_pulse()


## The beacon can be heard across the island: it keeps drawing the Foreman.
func _pulse() -> void:
	var h := hunt()
	if h and h.foreman and is_instance_valid(h.foreman) and Game.crew:
		h.foreman.hear(Game.crew.dock_shore, 999.0, "beacon")


func objective() -> String:
	if not active:
		return ""
	match state:
		"calling":
			return "The beacon is calling. A ship reaches the dock at dawn. Stay alive, and be at the dock when it comes."
		"answered":
			return "The ship is at the dock. Get to the gangway."
	if fitted() == 3:
		return "The beacon is repaired. Switch it on in the dock building. It will be loud."
	var carried := 0
	for part in PARTS:
		if part_state[part] == "carried":
			carried += 1
	if carried > 0 and carried + fitted() == 3:
		return "You have every part. Fit them at the beacon in the dock building."
	return "No ship is coming. Repair the dock beacon to call one: %d of 3 parts found. Check the beacon to see what is missing." % carried_or_fitted()


func capture() -> Dictionary:
	var s := {}
	for part in sites:
		var p: Vector3 = sites[part]
		s[part] = [p.x, p.y, p.z]
	return {"active": active, "parts": part_state.duplicate(), "state": state, "sites": s, "where": where.duplicate()}


func restore(d: Dictionary) -> void:
	active = bool(d.get("active", false))
	state = str(d.get("state", "dead"))
	if not state in ["dead", "ready", "calling", "answered"]:
		state = "dead"
	var ps: Dictionary = d.get("parts", {})
	for part in PARTS:
		var v := str(ps.get(part, "missing"))
		part_state[part] = v if v in ["missing", "carried", "installed"] else "missing"
	sites.clear()
	var s: Dictionary = d.get("sites", {})
	for part in s:
		var a: Array = s[part]
		if a.size() == 3:
			sites[str(part)] = Vector3(float(a[0]), float(a[1]), float(a[2]))
	where = (d.get("where", {}) as Dictionary).duplicate()
	if active:
		if sites.size() < 3:
			_pick_sites()
		_build_props()
