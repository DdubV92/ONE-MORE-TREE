class_name WorkLamp
extends StaticBody3D
## Phase 26: a battery work lamp the boss carries out and sets down. It is
## a DESIGNATED safety lamp: while `working`, SafetyService treats its pool
## as safe at night, wherever it stands (rule 4). The light itself grants
## nothing; only this flag, read by SafetyService, does.
##
## The battery only drains at night while the lamp is lit, lasts
## NightKit.BATTERY_S seconds, and recharges in daylight. It flickers for
## the last minute, then goes dark and stops being safe.

const FULL_OMNI := 3.6
const FULL_SPOT := 6.0

var kit: NightKit
var charge := 0.0                   # seconds of night light left
var lit := false                    # switched on by nightfall (NightKit)
var working := false                # authoritative for SafetyService
var safe_radius := 6.0
var _light: OmniLight3D
var _spot: SpotLight3D
var _bulb: MeshInstance3D
var _mat_on: StandardMaterial3D
var _mat_off: StandardMaterial3D
var _flick := 0.0


func setup(k: NightKit, at: Vector3, charge_s: float) -> void:
	kit = k
	charge = charge_s
	safe_radius = NightKit.SAFE_RADIUS
	add_to_group("work_lamps")
	name = "WorkLamp"
	position = at
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.11)
	dark.roughness = 0.7
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.86, 0.66, 0.1)
	yellow.roughness = 0.55
	# Tripod, mast, battery box and head.
	for i in 3:
		var a := TAU * i / 3.0
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.015
		lm.bottom_radius = 0.02
		lm.height = 0.95
		leg.mesh = lm
		leg.material_override = dark
		leg.position = Vector3(cos(a) * 0.22, 0.42, sin(a) * 0.22)
		leg.rotation = Vector3(sin(a) * 0.5, 0.0, -cos(a) * 0.5)
		add_child(leg)
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.02
	mm.bottom_radius = 0.025
	mm.height = 1.0
	mast.mesh = mm
	mast.material_override = dark
	mast.position = Vector3(0, 1.3, 0)
	add_child(mast)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.18, 0.16)
	box.mesh = bm
	box.material_override = yellow
	box.position = Vector3(0, 0.84, 0)
	add_child(box)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.34, 0.22, 0.1)
	head.mesh = hm
	head.material_override = yellow
	head.position = Vector3(0, 1.84, 0)
	add_child(head)
	_mat_on = StandardMaterial3D.new()
	_mat_on.albedo_color = Color(1.0, 0.95, 0.8)
	_mat_on.emission_enabled = true
	_mat_on.emission = Color(1.0, 0.9, 0.7)
	_mat_on.emission_energy_multiplier = 4.0
	_mat_off = StandardMaterial3D.new()
	_mat_off.albedo_color = Color(0.6, 0.6, 0.58)
	_bulb = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.3, 0.18, 0.02)
	_bulb.mesh = gm
	_bulb.position = Vector3(0, 1.84, -0.055)
	add_child(_bulb)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.9, 0)
	_light.omni_range = safe_radius + 2.5
	_light.light_color = Color(1.0, 0.92, 0.78)
	_light.light_energy = FULL_OMNI
	_light.shadow_enabled = false
	add_child(_light)
	_spot = SpotLight3D.new()
	_spot.position = Vector3(0, 1.9, 0)
	_spot.rotation_degrees = Vector3(-90, 0, 0)
	_spot.spot_range = 7.0
	_spot.spot_angle = 72.0
	_spot.light_color = Color(1.0, 0.92, 0.78)
	_spot.light_energy = FULL_SPOT
	_spot.shadow_enabled = false
	add_child(_spot)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.22
	sh.height = 1.9
	cs.shape = sh
	cs.position = Vector3(0, 0.95, 0)
	add_child(cs)
	_show(false)


## Called by NightKit every frame: `night` is a contract night (the battery
## drains), `dark` is whether lamps should be lit at all.
func tick(delta: float, night: bool, dark: bool) -> void:
	lit = dark and charge > 0.0
	if lit and night:
		charge = maxf(charge - delta, 0.0)
	working = lit and charge > 0.0
	var show := working
	if working and charge < NightKit.LOW_S:
		# Failing: the light stutters, more as it runs down. It is still
		# safe until it is actually dark.
		_flick -= delta
		if _flick <= 0.0:
			_flick = randf_range(0.05, 0.5) * (0.4 + charge / NightKit.LOW_S)
			_light.light_energy = randf_range(0.5, FULL_OMNI)
			_spot.light_energy = _light.light_energy * FULL_SPOT / FULL_OMNI
	elif working:
		_light.light_energy = FULL_OMNI
		_spot.light_energy = FULL_SPOT
	_show(show)


func _show(on: bool) -> void:
	if _light.visible != on:
		_light.visible = on
		_spot.visible = on
		_bulb.material_override = _mat_on if on else _mat_off


func charge_text() -> String:
	return "%d%%" % int(round(100.0 * charge / NightKit.BATTERY_S))


func get_interact_text() -> String:
	if kit == null:
		return ""
	return kit.pick_prompt(self)


func interact(by: Node) -> void:
	if kit:
		kit.pick_up(self, by)
