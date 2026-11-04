class_name CamperComfort
extends Node
## Phase 5 camper comfort: couch seats, TV power, the light switch, curtains
## and a hot drink. Everything here is cosmetic/comfort: SafetyService stays
## authoritative for safety and none of these change it.

var camper: Node3D
var lights_on := true
var curtains: Array[Curtain] = []
var _bulb_mat: StandardMaterial3D
var _mug: MeshInstance3D
var _mug_t := 0.0


func setup() -> void:
	camper = Game.world_root.find_child("Camper", true, false) if Game.world_root else null
	if camper == null:
		return
	for m in get_tree().get_nodes_in_group("couch_seat"):
		var seat := m as Node3D
		Hotspot.make(seat, "SitSpot", Vector3(0.62, 0.35, 0.6), Vector3(0, 0.05, 0), func() -> String: return "Sit on the couch", func(by: Node) -> void: _sit(by, seat))
	var tvs := get_tree().get_nodes_in_group("camper_tv")
	if not tvs.is_empty():
		Hotspot.make(tvs[0], "PowerSpot", Vector3(1.24, 0.72, 0.1), Vector3(0, 0, 0.03), func() -> String: return ("Turn the TV off" if Game.tv and Game.tv.powered else "Turn the TV on"), func(_by: Node) -> void: toggle_tv())
	for sw in get_tree().get_nodes_in_group("camper_switch"):
		Hotspot.make(sw, "SwitchSpot", Vector3(0.12, 0.2, 0.16), Vector3.ZERO, func() -> String: return ("Lights off" if lights_on else "Lights on"), func(_by: Node) -> void: set_lights(not lights_on))
	for c in get_tree().get_nodes_in_group("camper_curtain"):
		var cur := c as Curtain
		curtains.append(cur)
		var mid: float = cur._panels[0].get_meta("mid")
		Hotspot.make(cur, "CurtainSpot", Vector3(cur._w + 0.1, 0.8, 0.12), Vector3(mid, cur._panels[0].position.y, cur._panels[0].position.z), func() -> String: return ("Open the curtains" if cur.closed else "Close the curtains"), func(_by: Node) -> void: cur.set_closed(not cur.closed))
	var k := camper.find_child("Kitchen", false, false) as Node3D
	if k:
		var W := CampLayout.CAMPER_SIZE.x * 0.5
		var F := CampLayout.CAMPER_FLOOR
		Hotspot.make(k, "DrinkSpot", Vector3(0.25, 0.3, 0.25), Vector3(-W + 0.18, F + 1.05, 2.6), func() -> String: return "Pour a hot drink", func(by: Node) -> void: pour_drink(by))
	for b in get_tree().get_nodes_in_group("camper_bulb"):
		var mi := b as MeshInstance3D
		if _bulb_mat == null:
			var src: Material = mi.material_override if mi.material_override else mi.get_active_material(0)
			_bulb_mat = (src.duplicate() as StandardMaterial3D) if src is StandardMaterial3D else StandardMaterial3D.new()
		mi.material_override = _bulb_mat


func _sit(by: Node, seat: Node3D) -> void:
	if by.has_method("sit_on_couch"):
		by.sit_on_couch(seat)


func toggle_tv() -> void:
	if Game.tv:
		Game.tv.set_power(not Game.tv.powered)


func set_lights(on: bool) -> void:
	lights_on = on
	for l in get_tree().get_nodes_in_group("camper_light"):
		(l as Light3D).visible = on
	if _bulb_mat:
		_bulb_mat.emission_enabled = on
		_bulb_mat.albedo_color = Color(1.0, 0.95, 0.85) if on else Color(0.35, 0.33, 0.3)


func pour_drink(by: Node) -> void:
	var cam: Camera3D = by.get("camera") if by else null
	if cam == null:
		return
	if _mug == null or not is_instance_valid(_mug):
		_mug = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.042
		cm.bottom_radius = 0.038
		cm.height = 0.1
		_mug.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.3, 0.22)
		m.roughness = 0.4
		_mug.material_override = m
		_mug.layers = 1 << 19   # first-person only (never on camera feeds)
		var steam := MeshInstance3D.new()
		var cof := CylinderMesh.new()
		cof.top_radius = 0.036
		cof.bottom_radius = 0.036
		cof.height = 0.005
		steam.mesh = cof
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.22, 0.12, 0.06)
		steam.material_override = sm
		steam.position = Vector3(0, 0.04, 0)
		steam.layers = 1 << 19
		_mug.add_child(steam)
		cam.add_child(_mug)
	_mug.position = Vector3(0.26, -0.24, -0.45)
	_mug.visible = true
	_mug_t = 45.0
	if by.has_method("show_message"):
		by.show_message("A hot mug of coffee. Nice and warm.")


func _process(delta: float) -> void:
	if _mug_t > 0.0:
		_mug_t -= delta
		if _mug and is_instance_valid(_mug):
			_mug.position.y = -0.24 + (0.05 if fposmod(_mug_t, 8.0) < 0.8 else 0.0)
			if _mug_t <= 0.0:
				_mug.visible = false


func capture() -> Dictionary:
	var cs: Array = []
	for c in curtains:
		cs.append(c.closed)
	return {"lights_on": lights_on, "curtains": cs}


func restore(d: Dictionary) -> void:
	set_lights(bool(d.get("lights_on", true)))
	var cs: Array = d.get("curtains", [])
	for i in mini(cs.size(), curtains.size()):
		curtains[i].snap(bool(cs[i]))
