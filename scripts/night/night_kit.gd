class_name NightKit
extends Node3D
## Phase 26: the boss's night tools.
##
## WORK LAMPS. The company issues two battery work lamps with each lot
## (campaigns without lots get two). They wait in the lamp locker by the
## parcel locker. Take one, carry it out and set it down (the set-down
## key): at night its pool of light is a real safe place, wherever it
## stands, for as long as its battery lasts. Lamps recharge in daylight.
## Safety comes only from SafetyService rule 4 reading each lamp's
## `working` flag; nothing here grants safety by itself.
##
## THE BREAKER. On a disturbed night the camp's pole lamps can fail: they
## flicker, then go out, and their pools stop being safe until the breaker
## beside the lockers is reset. The camper is never affected, and the
## battery work lamps keep working.

signal changed()

const LAMPS_PER_LOT := 2
const MAX_LAMPS := 6
const BATTERY_S := 420.0            # seven minutes of night light
const LOW_S := 60.0                 # flickers below this
const SAFE_RADIUS := 6.0
const PLACE_REACH := 1.5
const MIN_SPACING := 2.0            # between placed lamps
const TRIP_TIER := 2                # night pressure tier ("disturbed") before the breaker can fail
const TRIP_CHANCE := 0.55           # per eligible night
const TRIP_WINDOW := [50.0, 200.0]  # seconds of night spent awake
const FLICKER_S := 6.0

const LOCKER_POS := Vector3(4.85, 0.0, 7.6)     # camp-local, beside the parcel locker
const BREAKER_POS := Vector3(8.2, 0.0, 7.6)

var stock := 0                      # lamps in the locker
var issued := 0                     # lamps the company has sent so far
var held := false                   # the boss is carrying one
var held_charge := BATTERY_S
var lamps: Array[WorkLamp] = []
var breaker_tripped := false
var trip_day := -1                  # the day whose night has been decided
var trips := 0
var _trip_at := -1.0                # night-awake second the breaker goes (< 0: not tonight)
var _flicker := 0.0
var _awake := 0.0
var _hook_t := 0.0
var _warned_low := {}
var _rng := RandomNumberGenerator.new()
var locker: LampLocker
var breaker: BreakerBox
var _held_view: Node3D


func _ready() -> void:
	name = "NightKit"
	_rng.seed = 2606


## Builds the camp fixtures (called by the world once the camp exists).
func setup() -> void:
	locker = LampLocker.new()
	add_child(locker)
	var lp := CampLayout.world(LOCKER_POS)
	locker.setup(self, Vector3(lp.x, World.height_at(lp.x, lp.z), lp.z))
	breaker = BreakerBox.new()
	add_child(breaker)
	var bp := CampLayout.world(BREAKER_POS)
	breaker.setup(self, Vector3(bp.x, World.height_at(bp.x, bp.z), bp.z))


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_hook_t -= delta
	if _hook_t <= 0.0:
		_hook_t = 1.0
		var cs: CampaignService = Game.campaign
		if cs and not cs.lots_changed.is_connected(sync_issue):
			cs.lots_changed.connect(sync_issue)
		sync_issue()
	var night := contract_night()
	var dark := night or (Game.environment != null and float(Game.environment.get("lamp_level")) > 0.05)
	for l in lamps:
		l.tick(delta, night, dark)
		if night and l.working and l.charge < LOW_S and not _warned_low.has(l.get_instance_id()):
			_warned_low[l.get_instance_id()] = true
			if Game.player and (Game.player as Node3D).global_position.distance_to(l.global_position) < SAFE_RADIUS + 4.0:
				Game.player.show_message("This work lamp is failing. About a minute of light left.")
	if not night:
		_awake = 0.0
		_flicker = 0.0
		# Daylight: batteries recharge and yesterday's fault is cleared.
		if not dark:
			_recharge()
			if breaker_tripped:
				reset_breaker(null)
		return
	_awake += delta
	_breaker_step(delta)


## A contract night (not the hunt, which has its own rules).
func contract_night() -> bool:
	var c: CampaignService = Game.campaign
	if c == null or not c.active:
		return false
	if c.contract.state != ContractService.ACTIVE and c.contract.state != ContractService.LEGACY:
		return false
	if Game.hunt and Game.hunt.hunt_active():
		return false
	return c.clock.phase() == WorkdayClock.Phase.NIGHT


# ---------------------------------------------------------------- issue

## Lamps the company has sent by now: two per opened lot, or two flat.
func entitled() -> int:
	var c: CampaignService = Game.campaign
	if c == null or not c.active:
		return 0
	var lots: ContractLots = c.contract.lots if c.contract else null
	if lots == null:
		return LAMPS_PER_LOT
	return mini(LAMPS_PER_LOT * maxi(lots.advanced.size(), 1), MAX_LAMPS)


func sync_issue() -> void:
	var want := entitled()
	if want <= issued:
		return
	var n := want - issued
	issued = want
	stock += n
	changed.emit()
	var c: CampaignService = Game.campaign
	if c and c.active:
		c.notice.emit("The company sent %d work lamp%s. They are in the lamp locker beside the parcel locker (%d there now)." % [n, "" if n == 1 else "s", stock], 8.0)


func total() -> int:
	return stock + lamps.size() + (1 if held else 0)


# ------------------------------------------------------------- carrying

func take_prompt() -> String:
	if held:
		return "Put the work lamp back in the locker"
	if stock <= 0:
		return "Lamp locker: empty (%d lamp%s out on the island)" % [lamps.size(), "" if lamps.size() == 1 else "s"] if issued > 0 else "Lamp locker: the company has not sent any lamps yet"
	return "Take a work lamp (%d in the locker)" % stock


## At the locker: take one, or put the held one back.
func use_locker(by: Node) -> void:
	if held:
		held = false
		stock += 1
		_view(false)
		changed.emit()
		_say(by, "Lamp back in the locker (%d there)." % stock)
		return
	if stock <= 0:
		_say(by, take_prompt() + ".")
		return
	var why := _hands_blocker()
	if why != "":
		_say(by, why)
		return
	stock -= 1
	held = true
	held_charge = BATTERY_S
	_view(true)
	changed.emit()
	_say(by, "Work lamp in hand. %s sets it down. At night its light is a safe place for about %d minutes; it recharges in daylight." % [Keys.label("set_down"), int(BATTERY_S / 60.0)])


func pick_prompt(l: WorkLamp) -> String:
	return "Pick up the work lamp (battery %s)" % l.charge_text()


func pick_up(l: WorkLamp, by: Node) -> void:
	if not lamps.has(l):
		return
	var why := _hands_blocker()
	if why != "":
		_say(by, why)
		return
	held = true
	held_charge = l.charge
	lamps.erase(l)
	_warned_low.erase(l.get_instance_id())
	l.working = false
	l.remove_from_group("work_lamps")
	l.queue_free()
	_view(true)
	changed.emit()
	_say(by, "Work lamp picked up (battery %d%%). %s sets it down." % [int(round(100.0 * held_charge / BATTERY_S)), Keys.label("set_down")])


func _hands_blocker() -> String:
	if held:
		return "You are already carrying a work lamp."
	if Game.timber and not Game.timber.carried.is_empty():
		return "Your hands are full of logs. Set them down first."
	return ""


## Where the held lamp would stand, or why it cannot ("reason").
func place_spot(p: Node3D) -> Dictionary:
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var at := p.global_position + fwd * PLACE_REACH
	if World.water_depth_at(at.x, at.z) > 0.15:
		return {"ok": false, "reason": "Not in the water."}
	at.y = World.height_at(at.x, at.z)
	if absf(at.y - p.global_position.y) > 1.6:
		return {"ok": false, "reason": "The ground there is too steep. Try another spot."}
	for l in lamps:
		if l.global_position.distance_to(at) < MIN_SPACING:
			return {"ok": false, "reason": "Too close to another lamp."}
	var space := p.get_world_3d().direct_space_state
	if space:
		var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 1.0, 0), at + Vector3(0, 1.0, 0), 1)
		if p is CollisionObject3D:
			q.exclude = [(p as CollisionObject3D).get_rid()]
		if not space.intersect_ray(q).is_empty():
			return {"ok": false, "reason": "Something is in the way."}
	return {"ok": true, "at": at}


## The set-down key while a lamp is held. Returns true if it handled the key.
func set_down(p: Node3D) -> bool:
	if not held:
		return false
	var s := place_spot(p)
	if not bool(s.ok):
		_say(p, str(s.reason))
		return true
	var l := _spawn(s.at, held_charge)
	held = false
	_view(false)
	changed.emit()
	var q: Dictionary = Game.safety.query((s.at as Vector3) + Vector3(0, 1.0, 0)) if Game.safety else {}
	var extra := ""
	if int(q.get("reason", 0)) in [SafetyService.Reason.CAMP_LAMP, SafetyService.Reason.CAMPER_INTERIOR, SafetyService.Reason.CABIN_OCCUPIED]:
		extra = " This spot is already safe at night."
	_say(p, "Work lamp set down (battery %s). At night, stay inside its light.%s" % [l.charge_text(), extra])
	return true


func _spawn(at: Vector3, charge_s: float) -> WorkLamp:
	var l := WorkLamp.new()
	add_child(l)
	l.setup(self, at, clampf(charge_s, 0.0, BATTERY_S))
	lamps.append(l)
	return l


func _recharge() -> void:
	var any := false
	for l in lamps:
		if l.charge < BATTERY_S:
			l.charge = BATTERY_S
			any = true
	if held and held_charge < BATTERY_S:
		held_charge = BATTERY_S
		any = true
	if any:
		_warned_low.clear()
		changed.emit()


## The lamp in the boss's left hand (a small stand-in on the camera).
func _view(on: bool) -> void:
	if _held_view and is_instance_valid(_held_view):
		_held_view.queue_free()
		_held_view = null
	if not on or Game.player == null:
		return
	var cam: Camera3D = (Game.player as Node).get("camera")
	if cam == null:
		return
	_held_view = Node3D.new()
	_held_view.name = "HeldWorkLamp"
	cam.add_child(_held_view)
	_held_view.position = Vector3(-0.34, -0.38, -0.62)
	_held_view.rotation_degrees = Vector3(8, 18, 6)
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.86, 0.66, 0.1)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.11)
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.012
	mm.bottom_radius = 0.014
	mm.height = 0.5
	mast.mesh = mm
	mast.material_override = dark
	_held_view.add_child(mast)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.16, 0.1, 0.05)
	head.mesh = hm
	head.material_override = yellow
	head.position = Vector3(0, 0.28, 0)
	_held_view.add_child(head)
	for m in [mast, head]:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _say(by: Node, text: String) -> void:
	if by and by.has_method("show_message"):
		by.call("show_message", text)
	elif Game.player:
		Game.player.show_message(text)


# -------------------------------------------------------------- breaker

func _breaker_step(delta: float) -> void:
	var c: CampaignService = Game.campaign
	if trip_day != c.clock.day:
		# Decide tonight once: only on a disturbed island, and not before
		# the night rules have been shown.
		trip_day = c.clock.day
		_trip_at = -1.0
		var known: bool = c.onboarding == null or c.onboarding.night_rules_ack
		if known and not breaker_tripped and NightPressure.tier(NightPressure.island_level()) >= TRIP_TIER and _rng.randf() < TRIP_CHANCE:
			_trip_at = _rng.randf_range(TRIP_WINDOW[0], TRIP_WINDOW[1])
	if breaker_tripped or _trip_at < 0.0:
		return
	if _flicker <= 0.0 and _awake >= _trip_at:
		_flicker = FLICKER_S
		c.notice.emit("The camp lamps are flickering. The breaker is going.", 6.0)
	if _flicker > 0.0:
		_flicker -= delta
		# The lamps stutter while they are still safe: this is the warning.
		var on := fmod(_flicker * 7.0, 1.0) > 0.35
		for n in get_tree().get_nodes_in_group("camp_lamps"):
			var cl := n as CampLamp
			if cl:
				cl._light.visible = on
				cl._fill.visible = on
		if _flicker <= 0.0:
			trip_breaker()


## The camp's pole lamps go out: their pools stop being safe (SafetyService
## reads CampLamp.working). The camper and battery lamps are unaffected.
func trip_breaker() -> void:
	if breaker_tripped:
		return
	breaker_tripped = true
	trips += 1
	_trip_at = -1.0
	_flicker = 0.0
	_apply_breaker()
	changed.emit()
	var c: CampaignService = Game.campaign
	if c:
		c.notice.emit("The camp lamps are out, and so are their safe pools. Reset the breaker beside the lockers, or get inside the camper.", 10.0)
	if SoundService.instance():
		SoundService.play("door.latch", CampLayout.world(BREAKER_POS) + Vector3(0, 1.3, 0), {"emit": false})


func reset_breaker(by: Node) -> void:
	if not breaker_tripped:
		if by:
			_say(by, "The breaker is fine. The camp lamps come on at dusk.")
		return
	breaker_tripped = false
	_apply_breaker()
	changed.emit()
	if by:
		_say(by, "Breaker reset. The camp lamps are back.")
		if SoundService.instance():
			SoundService.play("door.latch", CampLayout.world(BREAKER_POS) + Vector3(0, 1.3, 0), {"emit": false})


func _apply_breaker() -> void:
	for n in get_tree().get_nodes_in_group("camp_lamps"):
		var cl := n as CampLamp
		if cl:
			cl.working = not breaker_tripped
			cl.set_level(cl.level)


func breaker_prompt() -> String:
	return "Reset the breaker (the camp lamps are OUT)" if breaker_tripped else "Camp breaker (lamps working)"


# ------------------------------------------------------------------ save

func reset() -> void:
	for l in lamps:
		if is_instance_valid(l):
			l.working = false
			l.remove_from_group("work_lamps")
			l.queue_free()
	lamps.clear()
	stock = 0
	issued = 0
	held = false
	held_charge = BATTERY_S
	trip_day = -1
	trips = 0
	_trip_at = -1.0
	_flicker = 0.0
	_warned_low.clear()
	_view(false)
	if breaker_tripped:
		breaker_tripped = false
		_apply_breaker()
	changed.emit()


func capture() -> Dictionary:
	var out := []
	for l in lamps:
		out.append({"x": snappedf(l.global_position.x, 0.01), "y": snappedf(l.global_position.y, 0.01), "z": snappedf(l.global_position.z, 0.01), "charge": snappedf(l.charge, 0.1)})
	return {"version": 1, "stock": stock, "issued": issued, "held": held, "held_charge": snappedf(held_charge, 0.1), "lamps": out,
		"breaker_tripped": breaker_tripped, "trip_day": trip_day, "trips": trips, "trip_at": snappedf(_trip_at, 0.1), "awake": snappedf(_awake, 0.1)}


func restore(d: Dictionary) -> void:
	reset()
	stock = maxi(int(d.get("stock", 0)), 0)
	issued = maxi(int(d.get("issued", 0)), 0)
	held = bool(d.get("held", false))
	held_charge = clampf(float(d.get("held_charge", BATTERY_S)), 0.0, BATTERY_S)
	for r in d.get("lamps", []):
		_spawn(Vector3(float(r.get("x", 0.0)), float(r.get("y", 0.0)), float(r.get("z", 0.0))), float(r.get("charge", BATTERY_S)))
	trip_day = int(d.get("trip_day", -1))
	trips = int(d.get("trips", 0))
	_trip_at = float(d.get("trip_at", -1.0))
	_awake = float(d.get("awake", 0.0))
	breaker_tripped = bool(d.get("breaker_tripped", false))
	_apply_breaker()
	_view(held)
	changed.emit()
