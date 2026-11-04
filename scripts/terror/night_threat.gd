class_name NightThreat
extends Node
## The ordinary contract-night danger (abstract catch), separate from the
## Foreman's physical hunt. Exposure grows only while the player's physical
## body is outside every safe area during a contract night (SafetyService is
## authoritative: camper always, occupied cabin, designated lamp pools).
## Warnings come first; a catch is re-checked on the commit frame, so
## stepping into safety wins against a stale request. Remote camera views,
## curtains, TV glow or a flashlight never count. Pause stops it. The
## active dog rescue grants a bounded grace (no cheap catch on the route).

signal warned(level: int, text: String)
signal caught()

const RATE := 1.0 / 210.0        # ~3.5 minutes continuously exposed
const FAR_RATE := 1.0 / 140.0    # faster far from camp
const DECAY := 1.0 / 45.0
const LEVELS := [[0.35, "You feel watched. Get to a lit part of camp or inside."], [0.65, "Something is close. Get inside now."], [0.88, "Run. Get to safety."]]
const BOUNDARY_GRACE := 1.0      # seconds unsafe before exposure counts (flicker)

var exposure := 0.0
var outside_t := 0.0
var safe_return_t := 0.0
var night_awake_t := 0.0
var _warned := 0
var grace_until := -1.0          # night_awake_t until which catches are suppressed
var catches := 0
var disabled := false


func _process(delta: float) -> void:
	if get_tree().paused or disabled:
		return
	if not _contract_night():
		exposure = maxf(exposure - delta * DECAY * 3.0, 0.0)
		_warned = 0
		return
	night_awake_t += delta
	# Phase 9: no ordinary catch before the night rules were shown and
	# acknowledged (or the guide was skipped with its rules summary).
	var c0: CampaignService = Game.campaign
	if c0 and c0.onboarding and not c0.onboarding.night_rules_ack:
		exposure = 0.0
		return
	var p := Game.player as Node3D
	if p == null or Game.safety == null:
		return
	var safe := _player_safe(p)
	if safe:
		outside_t = 0.0
		safe_return_t += delta
		exposure = maxf(exposure - delta * DECAY, 0.0)
		if exposure < 0.3:
			_warned = 0
		return
	safe_return_t = 0.0
	outside_t += delta
	if outside_t < BOUNDARY_GRACE:
		return
	var far := p.global_position.distance_to(World.camp_origin()) > 70.0
	var gain := (FAR_RATE if far else RATE) * delta
	if night_awake_t < grace_until:
		gain = 0.0                # protected dog-rescue window
	exposure = minf(exposure + gain, 1.0)
	for i in LEVELS.size():
		if exposure >= float(LEVELS[i][0]) and _warned <= i:
			_warned = i + 1
			warned.emit(i + 1, str(LEVELS[i][1]))
			p.show_message(str(LEVELS[i][1]))
	if exposure >= 1.0:
		_commit_catch(p)


func _player_safe(p: Node3D) -> bool:
	# The physical body, a little above the feet (a seated/hidden body counts
	# where it actually is).
	return Game.safety.query(p.global_position + Vector3(0, 1.0, 0)).safe


func _contract_night() -> bool:
	var c: CampaignService = Game.campaign
	if c == null or not c.active:
		return false
	if c.contract.state != ContractService.ACTIVE and c.contract.state != ContractService.LEGACY:
		return false
	if Game.hunt and Game.hunt.hunt_active():
		return false
	return c.clock.phase() == WorkdayClock.Phase.NIGHT


## Re-validates on the commit frame: safety and grace win.
func _commit_catch(p: Node3D) -> void:
	if _player_safe(p) or night_awake_t < grace_until:
		exposure = 0.9
		return
	catches += 1
	exposure = 0.0
	_warned = 0
	caught.emit()


func grant_grace(seconds: float) -> void:
	grace_until = maxf(grace_until, night_awake_t + seconds)


## Sleep resets night escalation (waiting indoors does not).
func on_morning() -> void:
	exposure = 0.0
	outside_t = 0.0
	night_awake_t = 0.0
	grace_until = -1.0
	_warned = 0


func capture() -> Dictionary:
	return {"exposure": exposure, "night_awake_t": night_awake_t, "grace_until": grace_until, "catches": catches}


func restore(d: Dictionary) -> void:
	exposure = clampf(float(d.get("exposure", 0.0)), 0.0, 0.9)   # never load into a catch
	night_awake_t = float(d.get("night_awake_t", 0.0))
	grace_until = float(d.get("grace_until", -1.0))
	catches = int(d.get("catches", 0))
	outside_t = 0.0
