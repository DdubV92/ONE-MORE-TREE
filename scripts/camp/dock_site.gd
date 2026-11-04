class_name DockSite
extends Node3D
## Phase 5: finishes the Phase 4 service dock (stringers, joists, pile caps,
## cleats, fenders, end ladder, landward railing, lamp, sign, shore path)
## and builds the utility building on its reserved footprint (piers,
## raised floor, real door, windows, storage shelves, electrical panel,
## radio desk with the emergency-beacon console, later hiding spots) plus
## the dog's dry alcove on its west side (raised floor, roof, bed, bowl).
##
## The beacon console shows campaign status and exposes request/state hooks
## for Phase 6/9. The five-day ship rescue itself is NOT implemented here.

const BW := 2.5      # utility building half-width (x)
const BD := 2.0      # half-depth (z)
const BH := 2.4      # wall height
const T := 0.12

var building: Node3D
var floor_y := 0.0
var beacon_state := "standby"      # standby / requested (Phase 6) / ship_inbound (Phase 9)
var rescue_requested_day := -1
var refuge_point := Vector3.ZERO
var refuge_approach := Vector3.ZERO
var built := false


func build(crew: CrewService) -> void:
	if crew == null or crew.dock_end == Vector3.ZERO:
		return
	_detail_dock(crew)
	var ub := Vector3.INF
	for f in WorldGroups.of(self, "reserved_footprint"):
		if f.name == "Reserved_UtilityBuilding":
			ub = (f as Node3D).global_position
	if ub != Vector3.INF:
		_build_utility(ub, crew)
		_shore_path(crew)
	built = true


# ------------------------------------------------------------------ dock

func _detail_dock(crew: CrewService) -> void:
	var d := Node3D.new()
	d.name = "DockDetails"
	add_child(d)
	var end := crew.dock_end
	var shore := crew.dock_shore
	var deck_y := World.sea_level + 0.5
	var length := Vector2(end.x - shore.x, end.z - shore.z).length() + 1.0
	var mid_z := (end.z + shore.z) * 0.5 + 0.5
	var x := end.x
	# Under-structure: two stringers and cross joists, pile caps.
	for sx in [-0.7, 0.7]:
		BuildKit.box(d, Vector3(0.14, 0.2, length), Vector3(x + sx, deck_y - 0.16, mid_z), "dark_wood", false)
	var z := 0.0
	while z <= length:
		BuildKit.box(d, Vector3(2.15, 0.12, 0.12), Vector3(x, deck_y - 0.13, end.z + 0.5 - z), "dark_wood", false)
		z += 1.25
	z = 0.0
	var posts: Array[float] = []
	while z <= length:
		posts.append(end.z - z)
		for sx in [-1.0, 1.0]:
			BuildKit.cylinder(d, 0.12, 0.05, Vector3(x + sx * 1.0, deck_y + 0.2 + 0.6 - 0.32, end.z - z), "black", false, 8)
		z += 2.5
	# Cleats along the boarding (+x) edge.
	for k in 4:
		var cz := end.z - 0.6 - k * 2.6
		if cz < shore.z + 1.0:
			break
		var c := Node3D.new()
		c.name = "Cleat_%d" % k
		c.position = Vector3(x + 0.95, deck_y + 0.06, cz)
		d.add_child(c)
		BuildKit.box(c, Vector3(0.1, 0.05, 0.16), Vector3(0, 0.025, 0), "galvanized", false)
		BuildKit.box(c, Vector3(0.06, 0.04, 0.34), Vector3(0, 0.07, 0), "galvanized", false)
	# Fenders hung on the boarding-side piles near the berth.
	for k in 3:
		var fz := end.z - 0.2 - k * 2.5
		var f := BuildKit.cylinder(d, 0.11, 0.6, Vector3(x + 1.13, deck_y - 0.25, fz), "rubber", false, 10)
		f.name = "Fender_%d" % k
		BuildKit.cylinder(d, 0.012, 0.3, Vector3(x + 1.1, deck_y + 0.1, fz), "rubber", false, 4)
	# Ladder at the seaward end, down into the water.
	var lad := Node3D.new()
	lad.name = "Ladder"
	lad.position = Vector3(x + 0.55, deck_y, end.z + 0.55)
	d.add_child(lad)
	var bed := World.height_at(lad.position.x, lad.position.z + 0.05)
	var lh := deck_y - bed + 0.9
	for sx in [-0.22, 0.22]:
		BuildKit.box(lad, Vector3(0.05, lh, 0.05), Vector3(sx, 0.9 - lh * 0.5, 0.04), "galvanized", false)
	var ry := 0.6
	while ry > -lh + 1.0:
		BuildKit.box(lad, Vector3(0.44, 0.03, 0.03), Vector3(0, ry, 0.04), "galvanized", false)
		ry -= 0.3
	# Landward railing on the -x edge (the +x side stays open for boarding).
	for pz in posts:
		BuildKit.box(d, Vector3(0.08, 1.0, 0.08), Vector3(x - 1.02, deck_y + 0.56, pz), "dark_wood", false)
	BuildKit.box(d, Vector3(0.07, 0.07, length - 1.0), Vector3(x - 1.02, deck_y + 1.04, mid_z), "dark_wood", true, 0.0, "TopRail")
	BuildKit.box(d, Vector3(0.05, 0.05, length - 1.0), Vector3(x - 1.02, deck_y + 0.6, mid_z), "dark_wood", false)
	# Lamp at the end (practical light only: never a safety source).
	var lp := Vector3(x - 0.95, deck_y, end.z + 0.2)
	BuildKit.box(d, Vector3(0.09, 2.3, 0.09), lp + Vector3(0, 1.15, 0), "black", false, 0.0, "LampPost")
	BuildKit.box(d, Vector3(0.45, 0.05, 0.05), lp + Vector3(0.2, 2.28, 0), "black", false)
	BuildKit.cylinder(d, 0.1, 0.12, lp + Vector3(0.4, 2.2, 0), "lamp_bulb", false, 10)
	var li := OmniLight3D.new()
	li.name = "DockLamp"
	li.position = lp + Vector3(0.4, 2.1, 0)
	li.omni_range = 7.0
	li.light_energy = 0.7
	li.light_color = Color(1.0, 0.82, 0.58)
	li.add_to_group("camp_lamps")
	d.add_child(li)
	# Sign at the shore end.
	var sp := Vector3(x - 1.6, World.height_at(x - 1.6, shore.z - 0.8), shore.z - 0.8)
	for sx in [-0.55, 0.55]:
		BuildKit.box(d, Vector3(0.08, 1.5, 0.08), sp + Vector3(sx, 0.75, 0), "dark_wood", false)
	BuildKit.box(d, Vector3(1.3, 0.5, 0.05), sp + Vector3(0, 1.25, 0), "planks", false, 0.0, "Sign")
	var lab := Label3D.new()
	lab.text = "SERVICE DOCK\ncrew & supply boat\nno swimming"
	lab.font_size = 34
	lab.pixel_size = 0.0035
	lab.modulate = Color(0.95, 0.92, 0.85)
	lab.outline_size = 6
	lab.position = sp + Vector3(0, 1.25, 0.035)
	d.add_child(lab)


# ------------------------------------------------------- utility building

func _build_utility(ub: Vector3, crew: CrewService) -> void:
	# Raised floor clears the highest ground under the footprint.
	var gmax := -INF
	for dz in [-BD, 0.0, BD]:
		for dx in [-BW - 1.6, -BW, 0.0, BW]:
			gmax = maxf(gmax, World.height_at(ub.x + dx, ub.z + dz))
	floor_y = gmax + 0.3
	building = Node3D.new()
	building.name = "UtilityBuilding"
	add_child(building)
	building.global_position = Vector3(ub.x, floor_y, ub.z)
	var b := building
	# Piers (concrete-grey stone) down to the real ground, plus skirting.
	for px in [-BW + 0.15, 0.0, BW - 0.15]:
		for pz in [-BD + 0.15, BD - 0.15]:
			var g := World.height_at(ub.x + px, ub.z + pz)
			var h := floor_y - g + 0.1
			BuildKit.box(b, Vector3(0.3, h, 0.3), Vector3(px, -h * 0.5, pz), "stone", true)
	BuildKit.box(b, Vector3(BW * 2 + T * 2, 0.12, BD * 2 + T * 2), Vector3(0, -0.06, 0), "floor", true, 0.0, "Floor")
	# Walls (BuildKit.wall conventions as in the camper).
	var west_door := [0.92, 1.82, 0.0, 2.0]
	BuildKit.wall(b, Vector3(-BW - T * 0.5, 0, -BD - T), -PI * 0.5, BD * 2 + T * 2, BH, T, [west_door], "siding")
	BuildKit.wall(b, Vector3(BW + T * 0.5, 0, BD + T), PI * 0.5, BD * 2 + T * 2, BH, T, [], "siding")
	var south_win := [1.82, 3.22, 1.0, 1.7]
	var north_win := [2.12, 3.32, 1.1, 1.7]
	BuildKit.wall(b, Vector3(BW + T, 0, BD + T * 0.5), PI, BW * 2 + T * 2, BH, T, [south_win], "siding")
	BuildKit.wall(b, Vector3(-BW - T, 0, -BD - T * 0.5), 0.0, BW * 2 + T * 2, BH, T, [north_win], "siding")
	BuildKit.window_glass(b, Vector3(BW + T, 0, BD + T * 0.5), PI, south_win, T)
	BuildKit.window_glass(b, Vector3(-BW - T, 0, -BD - T * 0.5), 0.0, north_win, T)
	# Mono-pitch roof, overhanging.
	# Top band closes the walls up under the sloped roof (no sky gap).
	for side in [-1.0, 1.0]:
		BuildKit.box(b, Vector3(BW * 2 + T * 2, 0.36, T), Vector3(0, BH + 0.18, side * (BD + T * 0.5)), "siding", false)
		BuildKit.box(b, Vector3(T, 0.36, BD * 2 + T * 2), Vector3(side * (BW + T * 0.5), BH + 0.18, 0), "siding", false)
	BuildKit.box(b, Vector3(BW * 2, 0.02, BD * 2), Vector3(0, BH + 0.01, 0), "panel", false, 0.0, "Ceiling")
	var roof := BuildKit.box(b, Vector3(BW * 2 + 0.7, 0.1, BD * 2 + 0.8), Vector3(0, BH + 0.4, 0), "roof", true, 0.0, "Roof")
	roof.rotation.x = -0.05
	# Real door on the west wall (faces the dock path).
	var door := Door.new()
	door.name = "UtilityDoor"
	door.width = 0.9
	door.height = 2.0
	door.material_name = "dark_wood"
	door.open_angle = -100.0
	door.position = Vector3(-BW - T * 0.5, 0, -1.2)
	door.rotation.y = -PI * 0.5
	b.add_child(door)
	# Step in front of the door down to the ground.
	var gd := World.height_at(ub.x - BW - 0.6, ub.z - 0.75)
	var step_h := floor_y - gd
	if step_h > 0.12:
		BuildKit.box(b, Vector3(0.6, step_h * 0.5, 1.0), Vector3(-BW - 0.45, -step_h * 0.75, -0.75), "planks", true)
		BuildKit.ramp(b, Vector3(-BW - 1.3, -step_h, -0.75), Vector3(-BW - T, 0.0, -0.75), 1.0)
	# Inside: storage shelves (east), electrical panel (north), radio desk
	# with the beacon console (south), warm ceiling light.
	for sy in [0.45, 1.1, 1.75]:
		BuildKit.box(b, Vector3(0.45, 0.04, 3.4), Vector3(BW - 0.28, sy, 0), "planks", false)
	BuildKit.box(b, Vector3(0.45, 2.0, 0.05), Vector3(BW - 0.28, 1.0, -1.7), "dark_wood", true)
	BuildKit.box(b, Vector3(0.45, 2.0, 0.05), Vector3(BW - 0.28, 1.0, 1.7), "dark_wood", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for sy in [0.45, 1.1, 1.75]:
		var zz := -1.5
		while zz < 1.4:
			var w := rng.randf_range(0.25, 0.5)
			var h := rng.randf_range(0.18, 0.4)
			BuildKit.box(b, Vector3(0.36, h, w), Vector3(BW - 0.3, sy + 0.02 + h * 0.5, zz + w * 0.5), ["planks", "panel", "camper_paint", "galvanized"][rng.randi() % 4], false, 0.0, "Crate")
			zz += w + rng.randf_range(0.05, 0.2)
	BuildKit.box(b, Vector3(0.6, 0.8, 0.12), Vector3(0.4, 1.4, -BD + 0.06), "galvanized", false, 0.0, "ElectricalPanel")
	for k in 4:
		BuildKit.box(b, Vector3(0.06, 0.12, 0.03), Vector3(0.2 + k * 0.13, 1.45, -BD + 0.13), "black", false)
	BuildKit.box(b, Vector3(0.04, 1.6, 0.04), Vector3(0.95, 1.6, -BD + 0.05), "black", false, 0.0, "Conduit")
	var desk := Node3D.new()
	desk.name = "RadioDesk"
	desk.position = Vector3(-0.3, 0, BD - 0.4)
	b.add_child(desk)
	BuildKit.box(desk, Vector3(1.5, 0.05, 0.65), Vector3(0, 0.76, 0), "dark_wood", true)
	for lx in [-0.7, 0.7]:
		BuildKit.box(desk, Vector3(0.05, 0.74, 0.6), Vector3(lx, 0.37, 0), "dark_wood", false)
	BuildKit.box(desk, Vector3(0.55, 0.22, 0.3), Vector3(-0.35, 0.9, 0.08), "black", false, 0.0, "Radio")
	BuildKit.box(desk, Vector3(0.42, 0.3, 0.28), Vector3(0.38, 0.94, 0.1), "camper_stripe", false, 0.0, "BeaconConsole")
	var led := OmniLight3D.new()
	led.position = Vector3(0.38, 1.12, -0.06)
	led.omni_range = 0.8
	led.light_energy = 0.4
	led.light_color = Color(1.0, 0.25, 0.15)
	desk.add_child(led)
	BuildKit.cylinder(desk, 0.02, 0.012, Vector3(0.38, 1.1, -0.05), "lamp_bulb", false, 8)
	Hotspot.make(desk, "BeaconSpot", Vector3(0.6, 0.45, 0.45), Vector3(0.3, 0.98, 0.05), func() -> String: return "Check the emergency beacon", func(by: Node) -> void: _beacon_use(by))
	BuildKit.box(desk, Vector3(0.45, 0.45, 0.45), Vector3(0.0, 0.25, -0.55), "dark_wood", true, 0.0, "Stool")
	var li := OmniLight3D.new()
	li.position = Vector3(0, BH - 0.25, 0)
	li.omni_range = 4.0
	li.light_energy = 0.7
	li.light_color = Color(1.0, 0.8, 0.55)
	b.add_child(li)
	BuildKit.cylinder(b, 0.14, 0.03, Vector3(0, BH - 0.06, 0), "lamp_bulb", false, 12)
	# Later human hiding positions (Phase 6): under the desk, behind shelves.
	for hs in [["UtilityHide_UnderDesk", Vector3(-0.3, 0.05, BD - 0.4), "under_desk"], ["UtilityHide_Shelves", Vector3(BW - 0.75, 0.05, 1.45), "behind_shelves"]]:
		var m := BuildKit.marker(b, hs[0], hs[1], 0.0, "hiding_spot")
		m.set_meta("hide_kind", hs[2])
	_interior_zone(b)
	_dog_alcove(b)
	# Workers and trucks route around the building and the alcove.
	if crew.nav:
		crew.nav._mark_disc(Vector2(ub.x - 0.6, ub.z), 3.1, true)


func _interior_zone(b: Node3D) -> void:
	# Indoor acoustics only; NOT a night shelter (SafetyService decides).
	var a := Area3D.new()
	a.name = "Zone_utility"
	a.set_script(load("res://scripts/camp/interior_zone.gd"))
	a.set("zone_name", "utility")
	a.set("always_safe", false)
	a.set("is_interior", true)
	a.position = Vector3(0, BH * 0.5, 0)
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(BW * 2, BH, BD * 2)
	cs.shape = bx
	a.add_child(cs)
	b.add_child(a)


## The dog's dry alcove against the west wall, south of the door.
func _dog_alcove(b: Node3D) -> void:
	var al := Node3D.new()
	al.name = "DogAlcove"
	al.position = Vector3(-BW - T - 0.75, 0, 1.05)
	b.add_child(al)
	var w := 1.4
	var dpt := 1.6
	# Raised floor on its own posts.
	for px in [-0.6, 0.6]:
		for pz in [-0.7, 0.7]:
			var gp := al.global_position + Vector3(px, 0, pz)
			var h := floor_y - World.height_at(gp.x, gp.z) + 0.05
			BuildKit.box(al, Vector3(0.12, h, 0.12), Vector3(px, -h * 0.5 - 0.06, pz), "dark_wood", false)
	BuildKit.box(al, Vector3(w, 0.08, dpt), Vector3(0, -0.04, 0), "planks", true, 0.0, "AlcoveFloor")
	# North and south side walls, low back is the building wall; open west.
	BuildKit.box(al, Vector3(w, 1.0, 0.06), Vector3(0, 0.5, -dpt * 0.5), "siding", true)
	BuildKit.box(al, Vector3(w, 1.0, 0.06), Vector3(0, 0.5, dpt * 0.5), "siding", true)
	var r := BuildKit.box(al, Vector3(w + 0.3, 0.06, dpt + 0.3), Vector3(-0.08, 1.08, 0), "roof", true, 0.0, "AlcoveRoof")
	r.rotation.z = 0.18
	# Bed, water bowl, name board.
	BuildKit.cylinder(al, 0.4, 0.09, Vector3(0.15, 0.045, 0.15), "dog_bed", false, 20)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.32
	tm.outer_radius = 0.46
	rim.mesh = tm
	rim.material_override = BuildKit.mat("dog_bed")
	rim.position = Vector3(0.15, 0.1, 0.15)
	rim.scale = Vector3(1, 1.4, 1)
	al.add_child(rim)
	BuildKit.cylinder(al, 0.13, 0.07, Vector3(-0.35, 0.035, -0.5), "steel", false, 14, 0.15)
	var water := BuildKit.cylinder(al, 0.11, 0.01, Vector3(-0.35, 0.06, -0.5), "glass", false, 14)
	water.name = "WaterBowl"
	BuildKit.box(al, Vector3(0.6, 0.16, 0.03), Vector3(0.1, 0.85, -dpt * 0.5 + 0.05), "planks", false)
	var lab := Label3D.new()
	lab.text = "BISCUIT"
	lab.font_size = 40
	lab.pixel_size = 0.003
	lab.modulate = Color(0.25, 0.15, 0.08)
	lab.position = Vector3(0.1, 0.85, -dpt * 0.5 + 0.07)
	al.add_child(lab)
	# Refuge anchor on the bed; approach point on the ground in front.
	refuge_point = al.global_position + Vector3(0.15, 0.1, 0.15)
	var gfront := al.global_position + Vector3(-1.5, 0, 0)
	refuge_approach = Vector3(gfront.x, World.height_at(gfront.x, gfront.z), gfront.z)
	for n in WorldGroups.of(self, "dog_refuge"):
		(n as Node3D).global_position = refuge_point
	var ap := Marker3D.new()
	ap.name = "DogRefugeApproach"
	ap.add_to_group("dog_refuge_approach")
	add_child(ap)
	ap.global_position = refuge_approach
	# A short plank ramp for the dog from the ground up onto the floor.
	var rise := floor_y - refuge_approach.y
	var run := 1.0
	var ramp := BuildKit.box(al, Vector3(sqrt(run * run + rise * rise), 0.04, 0.5), Vector3(-w * 0.5 - run * 0.5, -rise * 0.5, 0.15), "planks", false)
	ramp.rotation.z = atan2(rise, run)
	refuge_approach = al.global_position + Vector3(-w * 0.5 - run - 0.4, 0, 0.15)
	refuge_approach.y = World.height_at(refuge_approach.x, refuge_approach.z)
	ap.global_position = refuge_approach


func _shore_path(crew: CrewService) -> void:
	# Plank boardwalk from the dock root past the utility door toward the
	# beach gate (visual; the ground underneath is walkable already).
	if building == null:
		return
	var pts := [crew.dock_shore, building.global_position + Vector3(-BW - 1.6, 0, -0.75)]
	for g in crew.nav.gates:
		if (g.outside as Vector3).z > World.camp_origin().z:
			pts.append(g.outside)
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		var L := Vector2(c.x - a.x, c.z - a.z).length()
		var dir := Vector2(c.x - a.x, c.z - a.z).normalized()
		var s := 0.4
		while s < L - 0.3:
			var p := Vector2(a.x, a.z) + dir * s
			var h := World.height_at(p.x, p.y)
			if h > World.sea_level + 0.15:
				var pl := BuildKit.box(self, Vector3(1.1, 0.04, 0.22), Vector3(p.x, h + 0.02, p.y), "planks", false)
				pl.rotation.y = atan2(dir.x, dir.y)   # long axis across the path
			s += 0.32


# ---------------------------------------------------------------- beacon

func _beacon_use(by: Node) -> void:
	if by and by.has_method("show_message"):
		by.show_message(beacon_status_text())


func beacon_status_text() -> String:
	var c: CampaignService = Game.campaign
	var day := "-"
	if c and c.active:
		day = "day %d of %d" % [c.clock.day, WorkdayClock.CONTRACT_DAYS]
	match beacon_state:
		"requested":
			return "BEACON: rescue requested on day %d. Waiting for the ship." % rescue_requested_day
		"ship_inbound":
			return "BEACON: ship inbound. Head for the dock."
	return "BEACON: standby, battery good. Contract %s. Rescue requests open only in an emergency (not yet in this build)." % day


## Phase 6/9 hooks (state only; the ship rescue is not implemented yet).
func request_rescue(day: int) -> bool:
	if beacon_state != "standby":
		return false
	beacon_state = "requested"
	rescue_requested_day = day
	return true


func capture() -> Dictionary:
	return {"beacon_state": beacon_state, "rescue_requested_day": rescue_requested_day}


func restore(d: Dictionary) -> void:
	beacon_state = str(d.get("beacon_state", "standby"))
	if not beacon_state in ["standby", "requested", "ship_inbound"]:
		beacon_state = "standby"
	rescue_requested_day = int(d.get("rescue_requested_day", -1))
