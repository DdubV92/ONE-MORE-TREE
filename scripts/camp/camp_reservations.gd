class_name CampReservations
extends Node3D
## Physical reservations for later prompts, placed and grounded now so the
## camp layout already fits them (Phase 1 scope: locations, mounts and
## clear footprints; no feeds, vehicles, dock or extension behaviour).
##  - 10 security camera mounts with stable IDs (7 camp + 3 rock-mounted trail)
##  - cabin extension footprint (2 beds + bathroom + kitchen nook)
##  - two pickup bays + turning circle at the forest entrance
##  - dock + utility/beacon building footprint at the landing beach
## Cameras are observational infrastructure, never a safety zone.

const L := preload("res://scripts/camp/camp_layout.gd")

var cameras: Array[Dictionary] = []
var footprints: Array[Dictionary] = []


func build(camp: Node3D) -> void:
	# Children are placed in world coordinates.
	top_level = true
	global_transform = Transform3D()
	_footprint(camp, "CabinExtension", L.CABIN_EXTENSION.center, L.CABIN_EXTENSION.size, L.CABIN_EXTENSION.note)
	for k in L.TRUCK_BAYS.size():
		var b: Dictionary = L.TRUCK_BAYS[k]
		_footprint(camp, "TruckBay_%d" % (k + 1), b.center, b.size, "pickup parking / drop-off bay (Prompt 5)")
	_footprint(camp, "TruckTurningCircle", L.TRUCK_TURNING.center, Vector3(L.TRUCK_TURNING.radius * 2, 0, L.TRUCK_TURNING.radius * 2), "turning clearance radius %.1f m" % L.TRUCK_TURNING.radius)
	_build_cameras(camp)
	_reserve_dock(camp)


func _footprint(camp: Node3D, name: String, center: Vector3, size: Vector3, note: String) -> void:
	var m := Marker3D.new()
	m.name = "Reserved_" + name
	var o := camp.global_position
	var y := World.height_at(o.x + center.x, o.z + center.z)
	m.set_meta("size", size)
	m.set_meta("note", note)
	m.add_to_group("reserved_footprint")
	camp.add_child(m)
	m.global_position = Vector3(o.x + center.x, y, o.z + center.z)
	footprints.append({"name": name, "center": m.global_position, "size": size, "note": note})


# ---------------------------------------------------------------- cameras

func _build_cameras(camp: Node3D) -> void:
	var o := camp.global_position
	var cabin := L.CABIN_POS
	var camper := L.CAMPER_POS
	var hx := L.FENCE_HALF.x
	var hz := L.FENCE_HALF.y
	# id, category, mount position (camp-local, y above ground), look target
	var specs := [
		["CAM_01", "cabin_to_camper", cabin + Vector3(-3.74 - 0.14 - 2.1, 2.35, 1.6), camper],
		["CAM_02", "camper_to_cabin", camper + Vector3(L.CAMPER_SIZE.x * 0.5 + 0.12, 2.75, 4.2), cabin],
		["CAM_03", "forest_entrance", Vector3(0.0, 2.8, -hz + 0.2), Vector3(0, 0, -hz - 25.0)],
		["CAM_04", "perimeter_nw", Vector3(-hx, 2.3, -hz), Vector3(0, 0, 0)],
		["CAM_05", "perimeter_ne", Vector3(hx, 2.3, -hz), Vector3(0, 0, 0)],
		["CAM_06", "perimeter_sw", Vector3(-hx, 2.3, hz), Vector3(0, 0, 0)],
		["CAM_07", "perimeter_se", Vector3(hx, 2.3, hz), Vector3(0, 0, 0)],
	]
	for s in specs:
		var pos: Vector3 = s[2]
		var g := Vector3(o.x + pos.x, World.height_at(o.x + pos.x, o.z + pos.z) + pos.y, o.z + pos.z)
		var tgt: Vector3 = s[3]
		var tg := Vector3(o.x + tgt.x, World.height_at(o.x + tgt.x, o.z + tgt.z) + 1.0, o.z + tgt.z)
		var support := "post" if s[1].begins_with("perimeter") or s[1] == "forest_entrance" else "wall"
		if support == "post":
			var post := BuildKit.cylinder(self, 0.045, pos.y + 0.1, Vector3(g.x, g.y - (pos.y + 0.1) * 0.5 + 0.05, g.z), "galvanized", true, 8)
			post.name = s[0] + "_Post"
		_camera(s[0], s[1], g, tg, support)
	# Three trail cameras on rocks beside the trails, looking along them.
	var trail_specs := [["CAM_08", 0, 2], ["CAM_09", 1, 3], ["CAM_10", 0, 4]]
	for t in trail_specs:
		var trail: PackedVector2Array = World.config.trails[t[1]]
		var a: Vector2 = trail[mini(t[2] - 1, trail.size() - 2)]
		var b: Vector2 = trail[mini(t[2], trail.size() - 1)]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x)
		var spot := a.lerp(b, 0.5) + side * 3.2
		var rock_y := World.grounded_base_y(spot.x, spot.y, 0.5, 0.05)
		var rock := MeshInstance3D.new()
		rock.name = t[0] + "_Rock"
		rock.mesh = RockBuilder.build_variants(1)[0]
		rock.material_override = RockBuilder.material()
		rock.scale = Vector3(1.3, 0.95, 1.2)
		rock.position = Vector3(spot.x, rock_y + 0.2 * 0.95, spot.y)
		add_child(rock)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.55
		cs.shape = sph
		body.add_child(cs)
		body.position = rock.position
		add_child(body)
		var top := Vector3(spot.x, rock_y + 0.95 * 0.8, spot.y)
		var look_at := b + along * 15.0
		_camera(t[0], "trail_%d" % (t[1] + 1), top + Vector3(0, 0.12, 0), Vector3(look_at.x, World.height_at(look_at.x, look_at.y) + 1.0, look_at.y), "rock")


func _camera(id: String, category: String, pos: Vector3, look: Vector3, support: String) -> void:
	var cam := Node3D.new()
	cam.name = id
	add_child(cam)
	cam.global_position = pos
	var flat := Vector3(look.x - pos.x, 0, look.z - pos.z)
	if flat.length() > 0.01:
		cam.look_at(Vector3(look.x, pos.y + (look.y - pos.y) * 0.4, look.z), Vector3.UP)
	BuildKit.box(cam, Vector3(0.12, 0.11, 0.24), Vector3(0, 0, 0.02), "white", false, 0.0, "Body")
	BuildKit.box(cam, Vector3(0.15, 0.02, 0.28), Vector3(0, 0.065, 0.02), "white", false, 0.0, "Hood")
	var lens := BuildKit.cylinder(cam, 0.035, 0.04, Vector3(0, 0, -0.11), "black", false, 10)
	lens.rotation.x = PI * 0.5
	BuildKit.box(cam, Vector3(0.04, 0.04, 0.12), Vector3(0, -0.07, 0.12), "steel", false, 0.0, "Bracket")
	var aim := Marker3D.new()
	aim.name = "Aim"
	cam.add_child(aim)
	cam.add_to_group("security_camera")
	cam.set_meta("camera_id", id)
	cam.set_meta("category", category)
	cam.set_meta("support", support)
	cameras.append({"id": id, "category": category, "pos": pos, "support": support})


# -------------------------------------------------------------------- dock

## Finds the shoreline below the beach gate and reserves a dock running out
## to about 1.4 m of water plus a utility/beacon building on dry sand.
func _reserve_dock(camp: Node3D) -> void:
	var o := camp.global_position
	var x := o.x + 6.0
	var z := o.z + L.FENCE_HALF.y + 4.0
	while z < o.z + 400.0 and World.height_at(x, z) > 0.25:
		z += 0.5
	var shore := Vector3(x, World.height_at(x, z), z)
	var end_z := z
	while end_z < z + 60.0 and World.sea_level - World.height_at(x, end_z) < 1.4:
		end_z += 0.5
	var dock_len := end_z - z
	var dock_center := Vector3(x, World.sea_level, (z + end_z) * 0.5)
	_footprint_abs("Dock", dock_center, Vector3(3.0, 0.0, dock_len), "timber dock, %.1f m long, shore %.2f m -> water %.2f m deep at the end (Prompt 5)" % [dock_len, shore.y, World.sea_level - World.height_at(x, end_z)])
	# Utility / beacon building inland of the dock root on dry ground.
	var uz := z - 9.0
	while uz > o.z + L.FENCE_HALF.y + 3.0 and World.height_at(x + 6.0, uz) < 1.4:
		uz -= 0.5
	var ub := Vector3(x + 6.0, World.height_at(x + 6.0, uz), uz)
	_footprint_abs("UtilityBuilding", ub, Vector3(5.0, 0.0, 4.0), "utility / emergency beacon building, ground %.2f m (Prompt 5)" % ub.y)
	var hide := Marker3D.new()
	hide.name = "UtilityHideSpot"
	hide.add_to_group("hiding_spot")
	hide.set_meta("hide_kind", "utility_closet_reserved")
	add_child(hide)
	hide.global_position = ub + Vector3(1.5, 0.05, 1.0)
	# Dock dog refuge (Phases 5/6): after abandonment the dog waits here,
	# dry and protected, never follows humans into the hunt, and boards the
	# rescue ship at the dock end. Anchors only; ordinary dog routines are
	# unchanged. The water-edge bounds keep the dog off the wet sand/dock edge.
	var refuge := _anchor("DogRefuge", ub + Vector3(-1.4, 0.05, -0.8), "dog_refuge")
	refuge.set_meta("note", "dry floor inside the utility building, small protected shelter")
	_footprint_abs("DogShelter", ub + Vector3(-1.4, 0.0, -0.8), Vector3(1.6, 0.0, 1.4), "small protected dog shelter inside the utility building (Phase 5/6)")
	var avoid := Marker3D.new()
	avoid.name = "DogWaterEdgeBounds"
	avoid.add_to_group("dog_avoid_bounds")
	avoid.set_meta("note", "dog stays on ground at least 0.4 m above sea level and off the dock deck except for boarding")
	avoid.set_meta("min_ground", World.sea_level + 0.4)
	avoid.set_meta("dock_rect", [dock_center.x, dock_center.z, 3.0, dock_len])
	add_child(avoid)
	avoid.global_position = Vector3(x, World.sea_level, z)
	_anchor("ShipBoardingHandoff", Vector3(x, World.sea_level + 0.6, end_z - 0.5), "ship_boarding")


func _anchor(name: String, at: Vector3, group: String) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.add_to_group(group)
	add_child(m)
	m.global_position = at
	return m


func _footprint_abs(name: String, center: Vector3, size: Vector3, note: String) -> void:
	var m := Marker3D.new()
	m.name = "Reserved_" + name
	m.set_meta("size", size)
	m.set_meta("note", note)
	m.add_to_group("reserved_footprint")
	add_child(m)
	m.global_position = center
	footprints.append({"name": name, "center": center, "size": size, "note": note})
