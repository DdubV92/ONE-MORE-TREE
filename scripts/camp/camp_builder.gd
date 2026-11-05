class_name CampBuilder
extends Node3D
## Builds the complete camp footprint from CampLayout: dirt clearing (terrain
## mask), chain-link perimeter with a wide logging entrance, exterior lamps,
## tool area, burn pit, the four-bed worker cabin with an arcade corner, and
## the player's camper (kitchen, bathroom, bedroom, dog bed). Every interior
## is real walkable geometry. Anchors for later prompts are Marker3D nodes in
## named groups (see docs/ARCHITECTURE.md).

const L = preload("res://scripts/camp/camp_layout.gd")

var lamps: Array[CampLamp] = []
var interior_zones: Array[Area3D] = []
var fire: FirePit


func build() -> void:
	position = World.camp_origin()
	_build_fence()
	_build_lamps()
	fire = FirePit.new()
	fire.name = "BurnPit"
	fire.position = _ground(L.BURN_PIT_POS)
	fire.set_meta("no_batch", true)      # demo logs toggle with the fuel state
	add_child(fire)
	var rack := DeliveryRack.new()
	rack.name = "DeliveryRack"
	rack.position = _ground(L.DELIVERY_RACK_POS)
	add_child(rack)
	_build_camper()
	_build_cabin()
	_build_tool_area()
	_build_yard()
	_build_anchors()
	_reflection_probe("CamperProbe", L.CAMPER_POS + Vector3(0, L.CAMPER_FLOOR + L.CAMPER_SIZE.y * 0.5, 0), L.CAMPER_SIZE)
	_reflection_probe("CabinProbe", L.CABIN_POS + Vector3(0, L.CABIN_FLOOR + L.CABIN_SIZE.y * 0.5, 0), L.CABIN_SIZE)
	var res := CampReservations.new()
	res.name = "Reservations"
	add_child(res)
	res.build(self)
	var merged := BuildKit.batch_static(self)
	print("Camp: batched %d static meshes" % merged)


## Interior reflection probe (rendered once): glossy counters, glass and
## metal inside show the room instead of the open sky.
func _reflection_probe(name: String, local_centre: Vector3, box: Vector3) -> void:
	var rp := ReflectionProbe.new()
	rp.name = name
	rp.size = box + Vector3(0.2, 0.2, 0.2)
	rp.interior = true
	rp.box_projection = true
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	rp.max_distance = 20.0
	rp.position = _ground(local_centre)
	add_child(rp)


func _ground(local: Vector3) -> Vector3:
	## Local camp position snapped to the terrain.
	var o := position
	return Vector3(local.x, World.height_at(o.x + local.x, o.z + local.z) - o.y + local.y, local.z)


# ------------------------------------------------------------------ fence

func _build_fence() -> void:
	var root := Node3D.new()
	root.name = "Fence"
	add_child(root)
	var hx := L.FENCE_HALF.x
	var hz := L.FENCE_HALF.y
	# Each side as a list of [start, end] spans (gaps for the entrances).
	var sides := [
		[Vector2(-hx, -hz), Vector2(-L.ENTRANCE_HALF_WIDTH, -hz)],
		[Vector2(L.ENTRANCE_HALF_WIDTH, -hz), Vector2(hx, -hz)],
		[Vector2(hx, -hz), Vector2(hx, hz)],
		[Vector2(hx, hz), Vector2(L.BEACH_GATE_HALF_WIDTH, hz)],
		[Vector2(-L.BEACH_GATE_HALF_WIDTH, hz), Vector2(-hx, hz)],
		[Vector2(-hx, hz), Vector2(-hx, -hz)],
	]
	var mesh_mat := BuildKit.mat("chainlink")
	for span in sides:
		var a: Vector2 = span[0]
		var b: Vector2 = span[1]
		var length := a.distance_to(b)
		var n := maxi(1, int(ceil(length / 3.0)))
		var dir := (b - a).normalized()
		for k in n:
			var p0 := a + dir * length * float(k) / n
			var p1 := a + dir * length * float(k + 1) / n
			var g0 := _ground(Vector3(p0.x, 0, p0.y))
			var g1 := _ground(Vector3(p1.x, 0, p1.y))
			var mid := (g0 + g1) * 0.5
			var seg := p0.distance_to(p1)
			# Mesh panel
			var quad := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(seg, L.FENCE_HEIGHT - 0.08)
			quad.mesh = qm
			quad.material_override = mesh_mat
			quad.position = mid + Vector3(0, L.FENCE_HEIGHT * 0.5 + 0.02, 0)
			quad.rotation.y = -atan2(dir.y, dir.x)
			root.add_child(quad)
			# Collision for the panel
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(seg, L.FENCE_HEIGHT, 0.06)
			cs.shape = shape
			body.add_child(cs)
			body.position = quad.position
			body.rotation = quad.rotation
			root.add_child(body)
			# Top rail
			var rail := BuildKit.cylinder(root, 0.022, seg, quad.position + Vector3(0, L.FENCE_HEIGHT * 0.5 - 0.03, 0), "galvanized", false, 6)
			rail.rotation = Vector3(0, -atan2(dir.y, dir.x), PI * 0.5)
			_post(root, g0, k == 0)
		_post(root, _ground(Vector3(b.x, 0, b.y)), true)
	_build_gate(root)


## The forest-entrance gate leaf (see CampLayout.GATE_HINGE): a galvanized
## five-bar tube gate standing open against the inside of the fence, its free
## end chained back. Visual only: it lies 0.18 m inside the fence line, whose
## own collision already closes that side.
func _build_gate(fence_root: Node3D) -> void:
	var gate := Node3D.new()
	gate.name = "GateLeaf"
	gate.add_to_group("camp_gate_leaf")
	fence_root.add_child(gate)
	var h := L.GATE_HINGE
	gate.position = Vector3(h.x, _ground(Vector3(h.x, 0, h.z)).y, h.z)
	var ln := L.GATE_LEAF.x
	var ht := L.GATE_LEAF.y
	var y0 := L.GATE_CLEARANCE
	# Stiles at both ends, five rails, one diagonal brace; leaf runs along -X.
	for x in [-0.05, -ln + 0.05]:
		BuildKit.cylinder(gate, 0.034, ht, Vector3(x, y0 + ht * 0.5, 0), "galvanized", false, 8)
	for k in 5:
		var r := BuildKit.cylinder(gate, 0.026, ln - 0.1, Vector3(-ln * 0.5, y0 + 0.06 + (ht - 0.12) * k / 4.0, 0), "galvanized", false, 8)
		r.rotation.z = PI * 0.5
	var brace := BuildKit.cylinder(gate, 0.022, sqrt(ln * ln + ht * ht) - 0.2, Vector3(-ln * 0.5, y0 + ht * 0.5, 0), "galvanized", false, 6)
	brace.rotation.z = atan2(ln, ht)
	# Hinge collars on the west post of the opening.
	for y in [y0 + 0.25, y0 + ht - 0.25]:
		BuildKit.cylinder(gate, 0.05, 0.08, Vector3(0.0, y, -0.09), "steel", false, 8)
	# Holdback chain: from the free stile to the fence behind it.
	var chain := BuildKit.box(gate, Vector3(0.035, 0.32, 0.18), Vector3(-ln + 0.05, y0 + ht * 0.55, -0.09), "steel", false, 0.0, "GateChain")
	chain.add_to_group("camp_gate_chain")


func _post(parent: Node3D, at: Vector3, terminal: bool) -> void:
	var r := 0.045 if terminal else 0.032
	BuildKit.cylinder(parent, r, L.FENCE_HEIGHT + 0.12, at + Vector3(0, (L.FENCE_HEIGHT + 0.12) * 0.5, 0), "galvanized", true, 8)
	var cap := BuildKit.cylinder(parent, r + 0.008, 0.04, at + Vector3(0, L.FENCE_HEIGHT + 0.13, 0), "galvanized", false, 8)
	cap.name = "Cap"


# ------------------------------------------------------------------ lamps

func _build_lamps() -> void:
	var root := Node3D.new()
	root.name = "Lamps"
	add_child(root)
	for k in L.LAMPS.size():
		var d: Dictionary = L.LAMPS[k]
		var lamp := CampLamp.new()
		lamp.name = "Lamp_%d" % k
		lamp.safe_radius = d.radius
		lamp.cast_shadows = k == 0 or k == L.LAMPS.size() - 1
		lamp.position = _ground(d.pos)
		lamp.rotation.y = atan2(d.pos.x, d.pos.z) + PI
		root.add_child(lamp)
		lamps.append(lamp)


# ----------------------------------------------------------------- camper

func _build_camper() -> void:
	var c := Node3D.new()
	c.name = "Camper"
	c.position = _ground(L.CAMPER_POS)
	add_child(c)
	var F := L.CAMPER_FLOOR
	var W := L.CAMPER_SIZE.x * 0.5      # 1.63 (Phase 11, was 1.5)
	var zn := L.CAMPER_NORTH_Z          # -4.7 (bedroom end, unchanged)
	var zs := L.CAMPER_SOUTH_Z          # 6.11 (lounge end, was 4.7)
	var zc := (zn + zs) * 0.5
	var Lz := (zs - zn) * 0.5
	var H := L.CAMPER_SIZE.y            # 2.3
	var t := 0.08
	var ext := zs - 4.7                 # lounge extension (1.41 m)
	# Shell
	BuildKit.box(c, Vector3(W * 2 + t * 2, 0.12, Lz * 2 + t * 2), Vector3(0, F - 0.06, zc), "floor", true, 0.0, "Floor")
	BuildKit.box(c, Vector3(W * 2 + 0.3, 0.12, Lz * 2 + 0.3), Vector3(0, F + H + 0.06, zc), "camper_paint", true, 0.0, "Roof")
	BuildKit.box(c, Vector3(W * 2 + 0.36, 0.05, Lz * 2 + 0.36), Vector3(0, F + H + 0.14, zc), "camper_trim", false)
	# Openings are measured along each wall from its start; east starts at
	# the lounge end, so every east opening keeps its world spot (+ext).
	var door_open := [2.44 + ext, 3.34 + ext, 0.0, 2.0]
	var east := [door_open, [0.44 + ext, 1.54 + ext, 1.0, 1.8], [7.34 + ext, 8.54 + ext, 1.1, 1.8], [5.04 + ext, 5.64 + ext, 1.6, 1.95], [0.3, 1.2, 1.0, 1.8]]
	# West starts at the bedroom end (unchanged). [9.4, 10.6] is the new
	# desk window: to the RIGHT of a player seated at the desk.
	var west := [[5.54, 6.94, 1.25, 1.85], [0.84, 2.34, 0.95, 1.8], [8.5, 9.25, 1.0, 1.8], [9.4, 10.6, 0.95, 1.85]]
	var east_o := Vector3(W + t * 0.5, F, zs + t)
	var west_o := Vector3(-W - t * 0.5, F, zn - t)
	BuildKit.wall(c, east_o, PI * 0.5, Lz * 2 + t * 2, H, t, east, "camper_paint")
	BuildKit.wall(c, west_o, -PI * 0.5, Lz * 2 + t * 2, H, t, west, "camper_paint")
	var north := [[W + t - 0.7, W + t + 0.7, 1.2, 1.85]]
	var south: Array = []   # front wall: desk monitor (west) and entertainment TV (east)
	BuildKit.wall(c, Vector3(-W - t, F, zn - t * 0.5), 0.0, W * 2 + t * 2, H, t, north, "camper_paint")
	BuildKit.wall(c, Vector3(W + t, F, zs + t * 0.5), PI, W * 2 + t * 2, H, t, south, "camper_paint")
	for o in east:
		if o != door_open:
			BuildKit.window_glass(c, east_o, PI * 0.5, o, t)
			Curtain.make(c, east_o, PI * 0.5, o, -0.08)
	for o in west:
		BuildKit.window_glass(c, west_o, -PI * 0.5, o, t)
		Curtain.make(c, west_o, -PI * 0.5, o, -0.08)
	BuildKit.window_glass(c, Vector3(-W - t, F, zn - t * 0.5), 0.0, north[0], t)
	Curtain.make(c, Vector3(-W - t, F, zn - t * 0.5), 0.0, north[0], 0.08)

	# Teal stripe below the windows (split around the door: z 1.44..2.34)
	BuildKit.box(c, Vector3(0.012, 0.16, zs - 2.34), Vector3(W + t + 0.006, F + 0.62, (zs + 2.34) * 0.5), "camper_stripe", false)
	BuildKit.box(c, Vector3(0.012, 0.16, 1.44 - zn), Vector3(W + t + 0.006, F + 0.62, (1.44 + zn) * 0.5), "camper_stripe", false)
	BuildKit.box(c, Vector3(0.012, 0.16, Lz * 2), Vector3(-W - t - 0.006, F + 0.62, zc), "camper_stripe", false)
	# Chassis, wheels, hitch, propane
	BuildKit.box(c, Vector3(W * 2 - 0.3, 0.3, Lz * 2 - 0.6), Vector3(0, F - 0.3, zc), "steel", true)
	for sx in [-1.0, 1.0]:
		for z in [zc - 0.45, zc + 0.45]:
			var wheel := BuildKit.cylinder(c, 0.36, 0.22, Vector3(sx * (W - 0.02), 0.36, z), "rubber", false, 16)
			wheel.rotation.z = PI * 0.5
			var hub := BuildKit.cylinder(c, 0.17, 0.24, wheel.position, "camper_trim", false, 12)
			hub.rotation.z = PI * 0.5
	# Stabilizer jacks under both ends (the longer body is supported).
	for jz in [zn + 0.5, zs - 0.5]:
		for sx in [-1.0, 1.0]:
			BuildKit.box(c, Vector3(0.08, F - 0.15, 0.08), Vector3(sx * (W - 0.25), (F - 0.15) * 0.5, jz), "steel", false)
	BuildKit.box(c, Vector3(0.12, 0.12, 1.4), Vector3(0, 0.45, zs + 0.75), "steel", true)
	BuildKit.box(c, Vector3(0.5, 0.25, 0.25), Vector3(0, 0.4, zs + 1.5), "steel", false)
	BuildKit.prop(c, "propane_tank", Vector3(0.0, 0.52, zs + 0.65), 0.0, 1.0)
	BuildKit.cylinder(c, 0.04, 0.45, Vector3(0, 0.22, zs + 1.35), "steel", false, 6)
	# Entrance: door, steps, ramp collision, boots on a mat
	var door := Door.new()
	door.name = "CamperDoor"
	door.width = 0.9
	door.height = 2.0
	door.material_name = "camper_paint"
	door.open_angle = 100.0
	door.dog_flap = true
	door.position = Vector3(W + t * 0.5, F, 2.3)
	door.rotation.y = PI * 0.5
	c.add_child(door)
	for s in 2:
		var hgt := F * float(s + 1) / 3.0
		BuildKit.box(c, Vector3(0.35, 0.05, 1.0), Vector3(W + t + 0.62 - s * 0.32, hgt, 1.85), "steel", false)
	BuildKit.ramp(c, Vector3(W + 1.4, 0.0, 1.85), Vector3(W + t, F, 1.85), 1.0)
	BuildKit.box(c, Vector3(0.9, 0.02, 0.6), Vector3(W + 1.6, 0.01, 1.85), "dog_bed", false)
	BuildKit.prop(c, "rubber_boots", Vector3(W + 1.75, 0.02, 2.55), -PI * 0.3, 0.75)
	# --- Kitchen (west wall, z 0.4..2.9) - unchanged spot
	var k := Node3D.new()
	k.name = "Kitchen"
	c.add_child(k)
	BuildKit.box(k, Vector3(0.6, 0.86, 2.5), Vector3(-W + 0.3, F + 0.43, 1.65), "panel", true)
	BuildKit.box(k, Vector3(0.64, 0.05, 2.54), Vector3(-W + 0.32, F + 0.885, 1.65), "counter", false)
	BuildKit.box(k, Vector3(0.38, 0.06, 0.45), Vector3(-W + 0.32, F + 0.89, 2.0), "steel", false, 0.0, "Sink")
	BuildKit.cylinder(k, 0.015, 0.25, Vector3(-W + 0.08, F + 1.02, 2.0), "steel", false, 6)
	BuildKit.box(k, Vector3(0.5, 0.04, 0.55), Vector3(-W + 0.32, F + 0.92, 0.85), "black", false, 0.0, "Stove")
	for bz in [0.72, 0.98]:
		BuildKit.cylinder(k, 0.09, 0.012, Vector3(-W + 0.32, F + 0.945, bz), "steel", false, 12)
	BuildKit.prop(k, "pot_enamel_01", Vector3(-W + 0.32, F + 0.95, 0.72), 0.3, 1.0)
	BuildKit.prop(k, "wooden_cutting_board", Vector3(-W + 0.35, F + 0.91, 1.45), 0.2, 1.0)
	BuildKit.prop(k, "plastic_thermos", Vector3(-W + 0.18, F + 0.91, 2.6), 0.0, 1.0)
	BuildKit.box(k, Vector3(0.38, 0.55, 0.6), Vector3(-W + 0.19, F + 1.85, 2.6), "panel", true)
	BuildKit.box(k, Vector3(0.38, 0.55, 0.4), Vector3(-W + 0.19, F + 1.85, 0.6), "panel", true)
	BuildKit.prop(k, "russian_food_cans_01", Vector3(-W + 0.2, F + 2.13, 2.5), 0.0, 1.0)
	BuildKit.box(k, Vector3(0.6, 1.6, 0.62), Vector3(-W + 0.3, F + 0.8, 3.28), "white", true, 0.0, "Fridge")
	BuildKit.box(k, Vector3(0.02, 0.5, 0.03), Vector3(-W + 0.61, F + 1.1, 3.05), "steel", false)
	# --- Lounge (front, east half): couch facing the entertainment TV.
	var couch := Node3D.new()
	couch.name = "Couch"
	couch.position = Vector3(W - 0.88, F, zs - 2.1)
	c.add_child(couch)
	# Phase 12: a real upholstered sofa (Poly Haven sofa_02, CC0) on the
	# unchanged collision base (seat markers and sitting are unaffected).
	var base := BuildKit.box(couch, Vector3(1.7, 0.42, 0.78), Vector3(0, 0.21, 0), "dark_wood", true, 0.0, "CouchBase")
	base.visible = false
	BuildKit.prop(couch, "sofa_02", Vector3(0, 0.0, 0.1), 0.0, 0.94)
	BuildKit.marker(couch, "CouchSeat_1", Vector3(-0.38, 0.55, 0.05), PI, "couch_seat")
	BuildKit.marker(couch, "CouchSeat_2", Vector3(0.38, 0.55, 0.05), PI, "couch_seat")
	BuildKit.prop(c, "throw_pillows_01", Vector3(W - 0.35, F + 0.55, zs - 2.2), PI, 0.6)
	var tv := Node3D.new()
	tv.name = "CamperTV"
	tv.position = Vector3(W - 0.88, F + 1.32, zs - 0.06)
	tv.rotation.y = PI
	c.add_child(tv)
	BuildKit.box(tv, Vector3(1.04, 0.62, 0.06), Vector3.ZERO, "black", false, 0.0, "Bezel")
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var sq := QuadMesh.new()
	sq.size = Vector2(0.96, 0.54)
	screen.mesh = sq
	screen.material_override = BuildKit.mat("screen")
	# Live display: never merged by BuildKit.batch_static (it would blank the
	# quad the TV/desk viewport draws on).
	screen.set_meta("no_batch", true)
	screen.position = Vector3(0, 0, 0.032)
	tv.add_child(screen)
	tv.add_to_group("camper_tv")
	BuildKit.box(c, Vector3(0.6, 0.06, 0.4), Vector3(W - 0.88, F + 0.42, zs - 1.05), "dark_wood", true, 0.0, "CoffeeTable")
	for lx in [-0.25, 0.25]:
		BuildKit.box(c, Vector3(0.05, 0.4, 0.36), Vector3(W - 0.88 + lx, F + 0.2, zs - 1.05), "dark_wood", false)
	BuildKit.prop(c, "carved_wooden_plate", Vector3(W - 0.95, F + 0.46, zs - 1.05), 0.0, 1.0)
	_build_desk(c, W, F, zs)
	# --- Dog bed by the door
	var dog_bed := Node3D.new()
	dog_bed.name = "DogBed"
	dog_bed.position = Vector3(0.85, F, 0.8)
	c.add_child(dog_bed)
	BuildKit.cylinder(dog_bed, 0.42, 0.09, Vector3(0, 0.045, 0), "dog_bed", false, 20)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.5
	tm.rings = 20
	tm.ring_segments = 8
	rim.mesh = tm
	rim.material_override = BuildKit.mat("dog_bed")
	rim.position = Vector3(0, 0.1, 0)
	rim.scale = Vector3(1, 1.4, 1)
	dog_bed.add_child(rim)
	BuildKit.marker(dog_bed, "DogSleepPoint", Vector3(0, 0.1, 0), 0.0, "dog_bed")
	# --- Bathroom (+x side, z -1.4..0.2)
	BuildKit.wall(c, Vector3(0.2, F, 0.2), PI * 0.5, 1.6, H, 0.06, [[0.5, 1.2, 0.0, 2.0]], "camper_paint")
	BuildKit.wall(c, Vector3(0.2, F, 0.2), 0.0, W - 0.2, H, 0.06, [], "camper_paint")
	var bdoor := Door.new()
	bdoor.name = "BathroomDoor"
	bdoor.width = 0.7
	bdoor.material_name = "panel"
	bdoor.open_angle = -95.0
	bdoor.position = Vector3(0.2, F, -0.3)
	bdoor.rotation.y = PI * 0.5
	c.add_child(bdoor)
	BuildKit.box(c, Vector3(0.85, 0.08, 0.8), Vector3(1.05, F + 0.04, -0.95), "ceramic", false, 0.0, "ShowerTray")
	BuildKit.box(c, Vector3(0.02, 1.9, 0.8), Vector3(0.62, F + 1.05, -0.95), "shower_vinyl", false, 0.0, "ShowerCurtain")
	var toilet := Node3D.new()
	toilet.name = "Toilet"
	toilet.position = Vector3(1.15, F, -0.12)
	c.add_child(toilet)
	BuildKit.cylinder(toilet, 0.17, 0.4, Vector3(0, 0.2, 0), "ceramic", true, 14, 0.2)
	BuildKit.box(toilet, Vector3(0.18, 0.35, 0.36), Vector3(0.18, 0.55, 0), "ceramic", false)
	BuildKit.cylinder(toilet, 0.2, 0.04, Vector3(0, 0.42, 0), "white", false, 14)
	BuildKit.box(c, Vector3(0.35, 0.12, 0.3), Vector3(0.45, F + 0.82, 0.02), "ceramic", false, 0.0, "BathSink")
	# --- Bedroom (z -4.7..-1.4) behind a partition with a doorway
	BuildKit.wall(c, Vector3(-W, F, -1.4), 0.0, W * 2, H, 0.06, [[0.05, 0.9, 0.0, 2.0]], "camper_paint")
	var bed := Node3D.new()
	bed.name = "PlayerBed"
	bed.position = Vector3(0.0, F, zn + 1.0)
	c.add_child(bed)
	BuildKit.box(bed, Vector3(1.45, 0.35, 2.0), Vector3(0, 0.175, 0), "dark_wood", true)
	BuildKit.box(bed, Vector3(1.38, 0.2, 1.95), Vector3(0, 0.45, 0.02), "mattress", false)
	BuildKit.box(bed, Vector3(1.4, 0.02, 1.96), Vector3(0, 0.555, 0.02), "sheet", false, 0.0, "Sheet")
	BuildKit.box(bed, Vector3(1.44, 0.05, 1.3), Vector3(0, 0.585, 0.35), "blanket_red", false, 0.0, "Blanket")
	BuildKit.box(bed, Vector3(1.45, 0.75, 0.08), Vector3(0, 0.5, -1.0), "dark_wood", false)
	BuildKit.prop(bed, "throw_pillows_01", Vector3(0, 0.55, -0.72), 0.0, 1.0)
	BuildKit.marker(bed, "PlayerSleepPoint", Vector3(0, 0.75, 0.1), PI, "player_bed")
	# Phase 3: the whole mattress is the sleep target (easy to hit at night).
	var sleep := SleepSpot.new()
	sleep.name = "SleepSpot"
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(1.45, 0.3, 2.0)
	scs.shape = sbox
	scs.position = Vector3(0, 0.55, 0)
	sleep.add_child(scs)
	bed.add_child(sleep)
	_hide_spot(bed, "UnderCamperBed", Vector3(0, 0.12, 0.2), "under_bed")
	BuildKit.prop(c, "painted_wooden_nightstand", Vector3(1.15, F, zn + 0.35), PI, 0.85)
	BuildKit.box(c, Vector3(0.6, 2.0, 0.85), Vector3(W - 0.3, F + 1.0, -1.95), "panel", true, 0.0, "Wardrobe")
	_hide_spot(c, "CamperWardrobe", Vector3(W - 0.3, F + 0.05, -1.95), "closet")
	# --- Interior lights (warm, no shadows: cheap and stable)
	for lz in [2.0, -3.0, -0.6, zs - 1.4]:
		var li := OmniLight3D.new()
		li.position = Vector3(0.0 if lz != -0.6 else 0.85, F + H - 0.15, lz)
		li.omni_range = 3.6 if lz != -0.6 else 1.6
		li.light_energy = 0.9
		li.light_color = Color(1.0, 0.78, 0.52)
		li.add_to_group("camper_light")
		c.add_child(li)
		var bulb := BuildKit.cylinder(c, 0.14, 0.03, li.position + Vector3(0, 0.12, 0), "lamp_bulb", false, 12)
		bulb.add_to_group("camper_bulb")
	# Light switch beside the door (Phase 5 comfort) and a reading lamp.
	BuildKit.box(c, Vector3(0.02, 0.12, 0.08), Vector3(W - 0.01, F + 1.25, 1.2), "white", false, 0.0, "LightSwitch")
	BuildKit.marker(c, "LightSwitchPoint", Vector3(W - 0.03, F + 1.25, 1.2), 0.0, "camper_switch")
	# Phase 11: future event staging spots outside the desk window (validated
	# ground support at build; reserved, never populated by themselves).
	for k2 in 3:
		var sz := zs - 0.9 - k2 * 0.8
		var mk := BuildKit.marker(c, "DeskWindowStage_%d" % k2, Vector3(-W - 3.0 - k2 * 1.2, 0.0, sz), PI * 0.5, "desk_window_stage")
		mk.position.y = World.height_at((c.global_transform * mk.position).x, (c.global_transform * mk.position).z) - c.global_position.y
	_interior_zone(c, "camper", Vector3(0, F + H * 0.5, zc), Vector3(W * 2, H, Lz * 2), true)


## Phase 11 computer station in the lounge's west corner. Seated, the
## monitor is straight ahead and the new west window is on the RIGHT.
func _build_desk(c: Node3D, W: float, F: float, zs: float) -> void:
	var desk := Node3D.new()
	desk.name = "Desk"
	desk.position = Vector3(-W + 0.68, F, zs - 0.34)
	c.add_child(desk)
	BuildKit.box(desk, Vector3(1.3, 0.04, 0.66), Vector3(0, 0.74, 0), "dark_wood", true, 0.0, "DeskTop")
	for sx in [-0.6, 0.6]:
		BuildKit.box(desk, Vector3(0.05, 0.72, 0.6), Vector3(sx, 0.36, 0), "dark_wood", true)
	BuildKit.box(desk, Vector3(0.4, 0.5, 0.58), Vector3(0.38, 0.47, 0), "panel", false, 0.0, "Drawers")
	# Monitor on a short stand, slightly toward the window side.
	var mon := Node3D.new()
	mon.name = "Monitor"
	mon.position = Vector3(-0.05, 1.08, 0.12)
	mon.rotation.y = PI
	desk.add_child(mon)
	BuildKit.box(mon, Vector3(0.66, 0.4, 0.035), Vector3.ZERO, "black", false, 0.0, "MonitorBezel")
	BuildKit.box(desk, Vector3(0.06, 0.26, 0.05), Vector3(-0.05, 0.88, 0.16), "black", false)
	BuildKit.box(desk, Vector3(0.24, 0.015, 0.16), Vector3(-0.05, 0.765, 0.16), "black", false)
	var ms := MeshInstance3D.new()
	ms.name = "Screen"
	var mq := QuadMesh.new()
	mq.size = Vector2(0.62, 0.35)
	ms.mesh = mq
	ms.material_override = BuildKit.mat("screen")
	ms.set_meta("no_batch", true)
	ms.position = Vector3(0, 0, 0.019)
	mon.add_child(ms)
	mon.add_to_group("camper_monitor")
	# Keyboard, mouse, two small speakers (the camera relay plays from them).
	BuildKit.box(desk, Vector3(0.44, 0.02, 0.15), Vector3(-0.05, 0.77, -0.12), "black", false, 0.0, "Keyboard")
	BuildKit.box(desk, Vector3(0.06, 0.025, 0.1), Vector3(0.27, 0.77, -0.12), "black", false, 0.0, "Mouse")
	for sx in [-0.46, 0.36]:
		var spk := BuildKit.box(desk, Vector3(0.1, 0.17, 0.1), Vector3(sx, 0.845, 0.16), "black", false, 0.0, "Speaker")
		spk.add_to_group("desk_speaker")
	BuildKit.prop(desk, "plastic_thermos", Vector3(0.5, 0.76, 0.12), 0.0, 0.7)
	# Screen glow: small, cosmetic (never a safety source).
	var glow := OmniLight3D.new()
	glow.name = "ScreenGlow"
	glow.position = Vector3(-0.05, 1.0, -0.15)
	glow.omni_range = 1.3
	glow.light_energy = 0.18
	glow.light_color = Color(0.75, 0.85, 1.0)
	glow.shadow_enabled = false
	desk.add_child(glow)
	# Chair (pulled back 0.55 m, clear of the couch and fridge routes).
	var chair := Node3D.new()
	chair.name = "DeskChair"
	chair.position = Vector3(-W + 0.62, F, zs - 1.12)
	c.add_child(chair)
	BuildKit.box(chair, Vector3(0.48, 0.07, 0.46), Vector3(0, 0.46, 0), "chair_vinyl", true, 0.0, "ChairSeat")
	BuildKit.box(chair, Vector3(0.46, 0.5, 0.06), Vector3(0, 0.76, -0.22), "chair_vinyl", false, 0.0, "ChairBack")
	BuildKit.cylinder(chair, 0.03, 0.42, Vector3(0, 0.22, 0), "steel", false, 8)
	BuildKit.cylinder(chair, 0.26, 0.03, Vector3(0, 0.03, 0), "steel", false, 10)
	BuildKit.marker(chair, "DeskSeat", Vector3(0, 0.55, 0.05), PI, "desk_seat")


# ------------------------------------------------------------------ cabin

func _build_cabin() -> void:
	var c := Node3D.new()
	c.name = "Cabin"
	c.position = _ground(L.CABIN_POS)
	add_child(c)
	var F := L.CABIN_FLOOR
	var hx := L.CABIN_SIZE.x * 0.5    # 3.6
	var hz := L.CABIN_SIZE.z * 0.5    # 5.2
	var H := L.CABIN_SIZE.y           # 2.7
	var t := 0.14
	BuildKit.box(c, Vector3(hx * 2 + t * 2, F, hz * 2 + t * 2), Vector3(0, F * 0.5 - 0.08, 0), "dark_wood", true, 0.0, "Foundation")
	BuildKit.box(c, Vector3(hx * 2, 0.06, hz * 2), Vector3(0, F - 0.03, 0), "floor", true, 0.0, "Floor")
	var door_o := [4.84 + 0.07, 5.84 + 0.07, 0.0, 2.05]
	var west := [door_o, [1.94, 3.14, 1.0, 1.8], [7.54, 8.74, 1.0, 1.8]]
	var east := [[7.34, 8.34, 1.1, 1.8], [2.34, 3.34, 1.1, 1.8]]
	# Phase 4: the centre of the north wall opens into the extension.
	var north_door := [3.31, 4.17, 0.0, 2.08]
	var north := [[0.94, 1.94, 1.2, 1.8], north_door]
	var south := [[5.54, 6.54, 1.2, 1.8], [1.84, 2.84, 1.2, 1.8]]
	var wo := Vector3(-hx - t * 0.5, F, -hz - t)
	var eo := Vector3(hx + t * 0.5, F, hz + t)
	var no := Vector3(-hx - t, F, -hz - t * 0.5)
	var so := Vector3(hx + t, F, hz + t * 0.5)
	BuildKit.wall(c, wo, -PI * 0.5, hz * 2 + t * 2, H, t, west, "siding")
	BuildKit.wall(c, eo, PI * 0.5, hz * 2 + t * 2, H, t, east, "siding")
	BuildKit.wall(c, no, 0.0, hx * 2 + t * 2, H, t, north, "siding")
	BuildKit.wall(c, so, PI, hx * 2 + t * 2, H, t, south, "siding")
	for o in west:
		if o != door_o:
			BuildKit.window_glass(c, wo, -PI * 0.5, o, t)
	for o in east:
		BuildKit.window_glass(c, eo, PI * 0.5, o, t)
	for o in north:
		if o != north_door:
			BuildKit.window_glass(c, no, 0.0, o, t)
	for o in south:
		BuildKit.window_glass(c, so, PI, o, t)
	# Ceiling and gabled roof (ridge along z)
	BuildKit.box(c, Vector3(hx * 2, 0.06, hz * 2), Vector3(0, F + H + 0.03, 0), "panel", false, 0.0, "Ceiling")
	var pitch := deg_to_rad(26.0)
	var half_span := hx + t + 0.45
	var slope_len := half_span / cos(pitch)
	var rise := half_span * tan(pitch)
	for s in [-1.0, 1.0]:
		var roof := BuildKit.box(c, Vector3(slope_len, 0.12, hz * 2 + t * 2 + 0.9), Vector3(s * half_span * 0.5, F + H + 0.06 + rise * 0.5, 0), "roof", true)
		roof.rotation.z = -s * pitch
	for s in [-1.0, 1.0]:
		_gable(c, Vector3(0, F + H, s * (hz + t * 0.5)), hx + t, rise - 0.05, t)
	# Porch (west, at the door) with steps ramp and lamp
	BuildKit.box(c, Vector3(2.2, 0.12, 3.4), Vector3(-hx - t - 1.1, F - 0.06, 0), "planks", true, 0.0, "Porch")
	for pz in [-1.6, 1.6]:
		BuildKit.box(c, Vector3(0.12, 2.5, 0.12), Vector3(-hx - t - 2.1, F + 1.25, pz), "dark_wood", true)
	var porch_roof := BuildKit.box(c, Vector3(2.5, 0.08, 3.8), Vector3(-hx - t - 1.15, F + 2.55, 0), "roof", false)
	porch_roof.rotation.z = deg_to_rad(10.0)
	BuildKit.ramp(c, Vector3(-hx - t - 3.3, 0.0, 0.0), Vector3(-hx - t - 2.2, F, 0.0), 1.6)
	BuildKit.box(c, Vector3(0.3, F * 0.5, 1.6), Vector3(-hx - t - 2.35, F * 0.25, 0), "planks", false, 0.0, "Step")
	var door := Door.new()
	door.name = "CabinDoor"
	door.width = 0.95
	door.height = 2.05
	door.open_angle = -100.0
	door.position = Vector3(-hx - t * 0.5, F, -0.45)
	door.rotation.y = -PI * 0.5
	c.add_child(door)
	BuildKit.prop(c, "industrial_wall_lamp", Vector3(-hx - t - 0.05, F + 2.15, 0.85), -PI * 0.5, 1.0)
	var porch_light := OmniLight3D.new()
	porch_light.position = Vector3(-hx - t - 0.4, F + 2.0, 0.85)
	porch_light.omni_range = 6.0
	porch_light.light_energy = 1.0
	porch_light.light_color = Color(1.0, 0.8, 0.55)
	c.add_child(porch_light)
	porch_light.add_to_group("porch_lights")
	# --- Four worker beds with storage and clutter zones
	var bed_specs := [
		[Vector3(-2.3, F, -hz + 0.62), "blanket_green"],
		[Vector3(1.4, F, -hz + 0.62), "blanket_ochre"],
		[Vector3(-2.3, F, hz - 0.62), "blanket_blue"],
		[Vector3(1.4, F, hz - 0.62), "blanket_red"],
	]
	for i in 4:
		var spec: Array = bed_specs[i]
		var bed := Node3D.new()
		bed.name = "WorkerBed_%d" % (i + 1)
		bed.position = spec[0]
		bed.rotation.y = PI * 0.5
		c.add_child(bed)
		BuildKit.prop(bed, "old_bed_frame", Vector3.ZERO, 0.0, 1.0)
		BuildKit.box(bed, Vector3(0.86, 0.18, 1.9), Vector3(0, 0.5, 0.02), "mattress", true)
		BuildKit.box(bed, Vector3(0.88, 0.02, 1.9), Vector3(0, 0.6, 0.02), "sheet", false, 0.0, "Sheet")
		BuildKit.box(bed, Vector3(0.92, 0.05, 1.3), Vector3(0, 0.625, 0.3), spec[1], false, 0.0, "Blanket")
		BuildKit.box(bed, Vector3(0.6, 0.12, 0.35), Vector3(0, 0.67, -0.72), "pillow", false, 0.0, "Pillow")
		var sp := BuildKit.marker(bed, "SleepPoint", Vector3(0, 0.8, 0.1), 0.0, "worker_bed")
		sp.set_meta("bed_index", i + 1)
		_hide_spot(bed, "UnderWorkerBed_%d" % (i + 1), Vector3(0, 0.08, 0.1), "under_bed")
		var side := -1.0 if spec[0].z < 0.0 else 1.0
		var crate := BuildKit.prop(c, "wooden_crate_02", Vector3(spec[0].x + 1.35, F, spec[0].z - side * 0.05), PI * 0.5, 0.8, Vector3(0.45, 0.4, 0.95), "Footlocker_%d" % (i + 1))
		crate.add_to_group("worker_storage")
		BuildKit.box(c, Vector3(1.0, 0.04, 0.25), Vector3(spec[0].x, F + 1.45, spec[0].z + side * 0.48), "dark_wood", false, 0.0, "Shelf_%d" % (i + 1))
		BuildKit.marker(c, "ClutterZone_%d" % (i + 1), Vector3(spec[0].x, F + 1.47, spec[0].z + side * 0.48), 0.0, "clutter_zone")
	# Shelf clutter (a little, not every surface)
	BuildKit.prop(c, "russian_food_cans_01", Vector3(-2.5, F + 1.47, -hz + 0.12), 0.0, 1.0)
	BuildKit.prop(c, "plastic_thermos", Vector3(1.6, F + 1.47, -hz + 0.12), 0.0, 1.0)
	BuildKit.prop(c, "wooden_lantern_01", Vector3(-2.0, F + 1.47, hz - 0.12), 0.0, 0.8)
	# --- Table and chairs
	BuildKit.box(c, Vector3(0.9, 0.06, 1.7), Vector3(-0.4, F + 0.75, 0), "dark_wood", true, 0.0, "Table")
	for lx in [-0.78, -0.02]:
		for lz in [-0.72, 0.72]:
			BuildKit.box(c, Vector3(0.06, 0.72, 0.06), Vector3(lx, F + 0.36, lz), "dark_wood", false)
	var seats := [[Vector3(-1.15, F, -0.45), PI * 0.5], [Vector3(-1.15, F, 0.45), PI * 0.5], [Vector3(0.35, F, -0.45), -PI * 0.5], [Vector3(0.35, F, 0.45), -PI * 0.5]]
	for i in 4:
		var s: Array = seats[i]
		BuildKit.prop(c, "painted_wooden_chair_01", s[0], s[1], 1.0, Vector3(0.45, 0.5, 0.45))
		BuildKit.marker(c, "WorkerSeat_%d" % (i + 1), s[0], s[1], "worker_seat")
	BuildKit.prop(c, "carved_wooden_plate", Vector3(-0.4, F + 0.78, 0.4), 0.0, 1.0)
	BuildKit.cylinder(c, 0.045, 0.1, Vector3(-0.2, F + 0.83, -0.3), "mug_blue", false, 10)
	# --- Arcade corner (east wall)
	for i in 2:
		var cab := _arcade_cabinet(i)
		cab.position = Vector3(hx - 0.45, F, -0.85 + i * 1.7)
		cab.rotation.y = -PI * 0.5
		c.add_child(cab)
		BuildKit.marker(c, "Arcade_%d" % (i + 1), Vector3(hx - 1.3, F, -0.85 + i * 1.7), -PI * 0.5, "arcade_spot")
	BuildKit.prop(c, "wooden_bookshelf_worn", Vector3(hx - 0.32, F, 4.0), -PI * 0.5, 0.9, Vector3(0.55, 1.9, 1.25))
	BuildKit.prop(c, "painted_wooden_cabinet", Vector3(hx - 0.35, F, -4.0), -PI * 0.5, 0.95, Vector3(0.6, 1.15, 1.15))
	BuildKit.prop(c, "wall_clock", Vector3(-hx + 0.03, F + 2.05, 2.0), PI * 0.5, 1.0)
	for lz in [-2.6, 2.6]:
		var li := OmniLight3D.new()
		li.position = Vector3(-0.3, F + H - 0.35, lz)
		li.omni_range = 5.5
		li.light_energy = 1.0
		li.light_color = Color(1.0, 0.78, 0.52)
		c.add_child(li)
		BuildKit.cylinder(c, 0.006, 0.3, li.position + Vector3(0, 0.2, 0), "black", false, 4)
		BuildKit.cylinder(c, 0.07, 0.12, li.position, "lamp_bulb", false, 10)
	for i in 4:
		BuildKit.marker(c, "WorkerSpawn_%d" % (i + 1), Vector3(-hx - t - 1.2, F, -1.2 + i * 0.8), -PI * 0.5, "worker_spawn")
	_interior_zone(c, "cabin", Vector3(0, F + H * 0.5, 0), Vector3(hx * 2, H, hz * 2), false)
	_build_cabin_extension(c, F, hx, hz, t)


## Phase 4: attached two-bed bedroom, shared kitchen and one bathroom on the
## cabin's north side (the reserved CABIN_EXTENSION footprint). Floor level
## matches the cabin; the foundation reaches the lowest ground under it so
## nothing floats. Open doorway from the cabin, open bedroom doorway, a real
## door on the bathroom. Beds 5 and 6 join the four originals (group
## worker_bed, ordered by `bed_index`).
func _build_cabin_extension(c: Node3D, F: float, hx: float, hz: float, t: float) -> void:
	var e := Node3D.new()
	e.name = "CabinExtension"
	c.add_child(e)
	var H := 2.55
	var z0 := -hz - t            # shared wall outer face (-5.34)
	var z1 := -10.5              # north outer face
	var x0 := -hx - t
	var x1 := hx + t
	var inner_z1 := z1 + t
	var depth := z0 - z1
	# Foundation down to the lowest ground under the footprint.
	var lowest := 0.0
	for gx in [x0, 0.0, x1]:
		for gz in [z0, (z0 + z1) * 0.5, z1]:
			var w := c.global_position + Vector3(gx, 0, gz)
			lowest = minf(lowest, World.height_at(w.x, w.z) - c.global_position.y)
	var fh := F - lowest + 0.1
	BuildKit.box(e, Vector3(x1 - x0, fh, depth), Vector3(0, F - fh * 0.5 - 0.05, (z0 + z1) * 0.5), "dark_wood", true, 0.0, "ExtFoundation")
	BuildKit.box(e, Vector3(x1 - x0 - t * 2, 0.06, depth - t), Vector3(0, F - 0.03, (z0 + z1) * 0.5 - t * 0.25), "floor", true, 0.0, "ExtFloor")
	# Outer walls: west (bedroom window), north (two windows), east (kitchen window).
	var west_o := [[1.2, 2.2, 1.0, 1.8]]
	var east_o := [[1.0, 1.9, 1.05, 1.75], [3.2, 3.8, 1.5, 1.9]]
	var north_o := [[0.9, 2.0, 1.0, 1.8], [5.55, 6.15, 1.5, 1.9]]
	# Wall helper runs along local +X: west wall (rot -90°) heads +Z from the
	# north end; east wall (rot +90°) heads -Z from the cabin side.
	var wo := Vector3(x0 + t * 0.5, F, z1)
	var eo := Vector3(x1 - t * 0.5, F, z0)
	var no := Vector3(x0, F, z1 + t * 0.5)
	BuildKit.wall(e, wo, -PI * 0.5, depth, H, t, west_o, "siding")
	BuildKit.wall(e, eo, PI * 0.5, depth, H, t, east_o, "siding")
	BuildKit.wall(e, no, 0.0, x1 - x0, H, t, north_o, "siding")
	for o in west_o:
		BuildKit.window_glass(e, wo, -PI * 0.5, o, t)
	for o in east_o:
		BuildKit.window_glass(e, eo, PI * 0.5, o, t)
	for o in north_o:
		BuildKit.window_glass(e, no, 0.0, o, t)
	# Interior partitions: bedroom (west) | kitchen/hall | bathroom (NE).
	var ti := 0.1
	# Bedroom partition along x = -0.6, doorway near the cabin side.
	var pw := Node3D.new()
	pw.name = "BedroomPartition"
	e.add_child(pw)
	var bed_door := [-6.95, -6.05]
	for seg in [[inner_z1, bed_door[0]], [bed_door[1], z0]]:
		var a: float = seg[0]
		var b: float = seg[1]
		BuildKit.box(pw, Vector3(ti, H, b - a), Vector3(-0.6, F + H * 0.5, (a + b) * 0.5), "wall_white", true)
	BuildKit.box(pw, Vector3(ti, H - 2.08, bed_door[1] - bed_door[0]), Vector3(-0.6, F + 2.08 + (H - 2.08) * 0.5, (bed_door[0] + bed_door[1]) * 0.5), "wall_white", true)
	# Bathroom: walls x = 1.2 (z inner_z1..-7.6) and z = -7.6 (x 1.2..x1-t), door at x 1.5..2.35.
	BuildKit.box(e, Vector3(ti, H, -7.6 - inner_z1), Vector3(1.2, F + H * 0.5, (inner_z1 - 7.6) * 0.5), "wall_white", true, 0.0, "BathWallW")
	var bx1 := x1 - t
	for seg in [[1.2, 1.5], [2.35, bx1]]:
		BuildKit.box(e, Vector3(seg[1] - seg[0], H, ti), Vector3((seg[0] + seg[1]) * 0.5, F + H * 0.5, -7.6), "wall_white", true)
	BuildKit.box(e, Vector3(0.85, H - 2.05, ti), Vector3(1.925, F + 2.05 + (H - 2.05) * 0.5, -7.6), "wall_white", true)
	var bath_door := Door.new()
	bath_door.name = "BathroomDoor"
	bath_door.width = 0.82
	bath_door.height = 2.02
	bath_door.open_angle = 100.0
	bath_door.position = Vector3(1.52, F, -7.6)
	e.add_child(bath_door)
	# Bathroom fixtures: toilet, sink, shower compartment.
	var toilet := Node3D.new()
	toilet.name = "ExtToilet"
	toilet.position = Vector3(1.6, F, -9.9)
	e.add_child(toilet)
	BuildKit.cylinder(toilet, 0.17, 0.4, Vector3(0, 0.2, 0), "ceramic", true, 14, 0.2)
	BuildKit.box(toilet, Vector3(0.36, 0.35, 0.18), Vector3(0, 0.55, -0.18), "ceramic", false)
	BuildKit.cylinder(toilet, 0.2, 0.04, Vector3(0, 0.42, 0), "white", false, 14)
	BuildKit.box(e, Vector3(0.45, 0.85, 0.4), Vector3(1.55, F + 0.42, -8.15), "panel", true, 0.0, "ExtVanity")
	BuildKit.box(e, Vector3(0.38, 0.1, 0.3), Vector3(1.55, F + 0.9, -8.15), "ceramic", false, 0.0, "ExtBathSink")
	BuildKit.box(e, Vector3(0.4, 0.5, 0.03), Vector3(1.55, F + 1.55, -8.33), "glass", false, 0.0, "Mirror")
	BuildKit.box(e, Vector3(1.0, 0.08, 1.0), Vector3(bx1 - 0.55, F + 0.04, -9.8), "ceramic", true, 0.0, "ShowerTray")
	BuildKit.box(e, Vector3(0.04, 1.9, 1.0), Vector3(bx1 - 1.07, F + 1.03, -9.8), "glass", true, 0.0, "ShowerScreen")
	BuildKit.cylinder(e, 0.08, 0.02, Vector3(bx1 - 0.4, F + 2.0, -10.0), "steel", false, 10)
	# Kitchen along the east wall (counter, sink, stove, fridge, shelves).
	var k := Node3D.new()
	k.name = "ExtKitchen"
	e.add_child(k)
	BuildKit.box(k, Vector3(0.6, 0.86, 1.9), Vector3(bx1 - 0.3, F + 0.43, -6.5), "panel", true)
	BuildKit.box(k, Vector3(0.64, 0.05, 1.94), Vector3(bx1 - 0.32, F + 0.885, -6.5), "counter", false)
	BuildKit.box(k, Vector3(0.38, 0.06, 0.45), Vector3(bx1 - 0.32, F + 0.89, -6.1), "steel", false, 0.0, "ExtSink")
	BuildKit.box(k, Vector3(0.5, 0.04, 0.55), Vector3(bx1 - 0.32, F + 0.92, -7.05), "black", false, 0.0, "ExtStove")
	BuildKit.prop(k, "pot_enamel_01", Vector3(bx1 - 0.32, F + 0.95, -7.1), 0.3, 1.0)
	BuildKit.box(k, Vector3(0.6, 1.6, 0.62), Vector3(0.3, F + 0.8, -10.0), "white", true, 0.0, "ExtFridge")
	BuildKit.box(k, Vector3(1.4, 0.04, 0.3), Vector3(bx1 - 0.2, F + 1.6, -6.5), "dark_wood", false, 0.0, "ExtShelf")
	BuildKit.prop(k, "russian_food_cans_01", Vector3(bx1 - 0.2, F + 1.62, -6.2), 0.0, 1.0)
	BuildKit.marker(e, "KitchenSpot", Vector3(bx1 - 1.0, F, -6.5), PI * 0.5, "worker_kitchen")
	BuildKit.marker(e, "BathroomDoorSpot", Vector3(1.925, F, -7.1), PI, "worker_bathroom_door")
	# Two beds along the west part of the bedroom (heads to the north wall).
	var specs := [[Vector3(-3.0, F, -9.25), "blanket_green"], [Vector3(-1.35, F, -9.25), "blanket_red"]]
	for i in 2:
		var spec: Array = specs[i]
		var bed := Node3D.new()
		bed.name = "WorkerBed_%d" % (5 + i)
		bed.position = spec[0]
		e.add_child(bed)
		BuildKit.prop(bed, "old_bed_frame", Vector3.ZERO, 0.0, 1.0)
		BuildKit.box(bed, Vector3(0.86, 0.18, 1.9), Vector3(0, 0.5, 0.02), "mattress", true)
		BuildKit.box(bed, Vector3(0.88, 0.02, 1.9), Vector3(0, 0.6, 0.02), "sheet", false, 0.0, "Sheet")
		BuildKit.box(bed, Vector3(0.92, 0.05, 1.3), Vector3(0, 0.625, 0.3), spec[1], false, 0.0, "Blanket")
		BuildKit.box(bed, Vector3(0.6, 0.12, 0.35), Vector3(0, 0.67, -0.72), "pillow", false, 0.0, "Pillow")
		var m := BuildKit.marker(bed, "SleepPoint", Vector3(0, 0.8, 0.1), 0.0, "worker_bed")
		m.set_meta("bed_index", 5 + i)
		_hide_spot(bed, "UnderWorkerBed_%d" % (5 + i), Vector3(0, 0.08, 0.1), "under_bed")
		var crate := BuildKit.prop(e, "wooden_crate_02", spec[0] + Vector3(0, 0, 1.35), 0.0, 0.8, Vector3(0.95, 0.4, 0.45), "Footlocker_%d" % (5 + i))
		crate.add_to_group("worker_storage")
		BuildKit.box(e, Vector3(0.9, 0.04, 0.25), Vector3((spec[0] as Vector3).x, F + 1.45, inner_z1 + 0.13), "dark_wood", false, 0.0, "Shelf_%d" % (5 + i))
		BuildKit.marker(e, "ClutterZone_%d" % (5 + i), Vector3((spec[0] as Vector3).x, F + 1.47, inner_z1 + 0.13), 0.0, "clutter_zone")
	# Ceiling, shed roof sloping north (drains away from the cabin).
	BuildKit.box(e, Vector3(x1 - x0 - t * 2, 0.06, depth - t), Vector3(0, F + H + 0.03, (z0 + z1) * 0.5 - t * 0.25), "panel", false, 0.0, "ExtCeiling")
	var roof := BuildKit.box(e, Vector3(x1 - x0 + 0.6, 0.12, depth + 0.7), Vector3(0, F + H + 0.32, (z0 + z1) * 0.5 - 0.2), "roof", true)
	roof.rotation.x = deg_to_rad(-6.0)
	for lz in [-8.6, -6.4]:
		var li := OmniLight3D.new()
		li.position = Vector3(-1.9 if lz < -7.0 else 1.6, F + H - 0.3, lz)
		li.omni_range = 4.5
		li.light_energy = 0.9
		li.light_color = Color(1.0, 0.78, 0.52)
		e.add_child(li)
		BuildKit.cylinder(e, 0.07, 0.12, li.position, "lamp_bulb", false, 10)
	_interior_zone(e, "cabin_extension", Vector3(0, F + H * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0 - t * 2, H, depth - t), false)


func _gable(parent: Node3D, base_center: Vector3, half_w: float, rise: float, thickness: float) -> void:
	# Triangular gable end as a thin prism.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-half_w, 0, 0)
	var b := Vector3(half_w, 0, 0)
	var top := Vector3(0, rise, 0)
	var dz := Vector3(0, 0, thickness * 0.5)
	for tri in [[a - dz, top - dz, b - dz], [a + dz, b + dz, top + dz]]:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = BuildKit.mat("siding")
	mi.position = base_center
	parent.add_child(mi)


func _arcade_cabinet(index: int) -> Node3D:
	var n := Node3D.new()
	n.name = "ArcadeCabinet_%d" % (index + 1)
	var body_mat := BuildKit._plain([Color(0.75, 0.2, 0.15), Color(0.18, 0.35, 0.65)][index], 0.4, 0.1)
	BuildKit.box(n, Vector3(0.7, 1.75, 0.7), Vector3(0, 0.875, 0), body_mat, true)
	BuildKit.box(n, Vector3(0.72, 0.08, 0.35), Vector3(0, 1.0, 0.45), "black", false)
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.56, 0.44)
	screen.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/arcade_screen.gdshader")
	sm.set_shader_parameter("game", index)
	screen.material_override = sm
	screen.position = Vector3(0, 1.38, 0.36)
	screen.rotation.x = -deg_to_rad(12.0)
	n.add_child(screen)
	var marquee := MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(0.66, 0.16)
	marquee.mesh = mq
	marquee.material_override = BuildKit._emissive([Color(1.0, 0.75, 0.3), Color(0.5, 0.9, 1.0)][index], 1.5)
	marquee.position = Vector3(0, 1.66, 0.356)
	n.add_child(marquee)
	for b in 3:
		BuildKit.cylinder(n, 0.025, 0.02, Vector3(-0.1 + b * 0.08, 1.05, 0.5), BuildKit._emissive(Color(1, 0.3, 0.3), 1.0), false, 8)
	BuildKit.cylinder(n, 0.012, 0.1, Vector3(-0.22, 1.09, 0.5), "black", false, 6)
	var it := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.6, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, 1.3, 0.3)
	it.add_child(cs)
	it.set_script(load("res://scripts/interaction/interactable.gd"))
	it.set("prompt", "Play %s" % ["Log Roller", "Beaver Bonk"][index])
	it.set("message", "Insert coin... (the arcade games become playable in a later prompt)")
	n.add_child(it)
	return n


# ------------------------------------------------------------- tool area

func _build_tool_area() -> void:
	var t := Node3D.new()
	t.name = "ToolArea"
	t.position = _ground(L.TOOL_AREA_POS)
	t.rotation.y = deg_to_rad(-20.0)
	add_child(t)
	# Lean-to shelter: back wall to the north, open to the south-west
	for px in [-2.0, 2.0]:
		BuildKit.box(t, Vector3(0.14, 2.7, 0.14), Vector3(px, 1.35, -1.0), "dark_wood", true)
		BuildKit.box(t, Vector3(0.14, 2.2, 0.14), Vector3(px, 1.1, 1.1), "dark_wood", true)
	BuildKit.box(t, Vector3(4.3, 2.6, 0.08), Vector3(0, 1.3, -1.08), "planks", true, 0.0, "BackWall")
	var roof := BuildKit.box(t, Vector3(4.7, 0.08, 2.75), Vector3(0, 2.52, 0.05), "roof", false)
	roof.rotation.x = deg_to_rad(11.0)
	# Tool rack: three axe tiers with clear silhouettes
	BuildKit.box(t, Vector3(2.6, 0.12, 0.05), Vector3(0, 1.62, -1.0), "dark_wood", false, 0.0, "ToolRackBoard")
	var axes := [["hatchet", 1.55, "Small axe"], ["wooden_axe_03", 1.1, "Medium axe"], ["wooden_axe_02", 1.3, "Large axe"]]
	for i in 3:
		var a: Array = axes[i]
		var x := -0.85 + i * 0.85
		BuildKit.cylinder(t, 0.015, 0.12, Vector3(x, 1.62, -0.95), "steel", false, 6).rotation.x = PI * 0.5
		var axe := BuildKit.prop(t, a[0], Vector3(x, 0.7 if i > 0 else 1.15, -0.96), 0.0, a[1], Vector3.ZERO, "Axe_%s" % ["Small", "Medium", "Large"][i])
		axe.add_to_group("rack_axes")
		BuildKit.box(t, Vector3(0.22, 0.08, 0.01), Vector3(x, 1.85, -1.03), BuildKit._plain([Color(0.8, 0.7, 0.3), Color(0.75, 0.5, 0.25), Color(0.6, 0.25, 0.2)][i], 0.6, 0.0), false)
	var rack_it := ToolShop.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 1.6, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, 1.2, -0.85)
	rack_it.add_child(cs)
	t.add_child(rack_it)
	BuildKit.marker(t, "ShopCounter", Vector3(1.4, 0, 0.3), PI, "shop_counter")
	# Chopping block, sawhorse, lumber, storage
	BuildKit.cylinder(t, 0.36, 0.55, Vector3(-1.2, 0.275, 0.6), "bark", true, 14)
	BuildKit.cylinder(t, 0.34, 0.02, Vector3(-1.2, 0.56, 0.6), "planks", false, 14)
	for sx in [-0.4, 0.4]:
		for sz in [-0.25, 0.25]:
			var leg := BuildKit.box(t, Vector3(0.06, 0.8, 0.06), Vector3(0.9 + sx, 0.38, 0.6 + sz), "planks", false)
			leg.rotation.z = sz * 0.6
	BuildKit.box(t, Vector3(1.0, 0.08, 0.1), Vector3(0.9, 0.75, 0.6), "planks", true, 0.0, "Sawhorse")
	for k in 5:
		BuildKit.box(t, Vector3(2.4, 0.08, 0.2), Vector3(-0.6, 0.06 + (k / 3) * 0.09, -0.6 + (k % 3) * 0.22 - 0.0), "planks", k == 0)
	BuildKit.prop(t, "steel_frame_shelves_01", Vector3(2.75, 0, -0.6), -PI * 0.5, 0.09, Vector3(0.5, 1.9, 1.0))  # asset is authored at 10x scale
	BuildKit.prop(t, "wooden_bucket_01", Vector3(2.75, 0.95, -0.6), 0.0, 0.8)
	BuildKit.prop(t, "metal_toolbox", Vector3(2.75, 0.02, -0.4), 0.3, 1.0)
	BuildKit.prop(t, "Barrel_02", Vector3(-2.6, 0, 0.3), 0.0, 1.0, Vector3(0.5, 0.9, 0.5))
	BuildKit.prop(t, "plastic_jerrycan", Vector3(-2.5, 0, 0.9), 0.4, 1.0)
	BuildKit.prop(t, "wooden_crate_01", Vector3(1.9, 0, 1.4), 0.2, 1.0, Vector3(0.8, 0.4, 0.4))
	var hammer := BuildKit.prop(t, "sledgehammer_01", Vector3(-1.7, 0.0, -0.9), 0.0, 1.0)
	hammer.rotation.x = deg_to_rad(-12.0)
	var spade := BuildKit.prop(t, "rusted_spade_01", Vector3(-1.95, 0.0, -0.92), 0.0, 1.0)
	spade.rotation.x = deg_to_rad(-12.0)


# ------------------------------------------------------------------ yard

func _build_yard() -> void:
	var y := Node3D.new()
	y.name = "Yard"
	add_child(y)
	var pt := BuildKit.prop(y, "wooden_picnic_table", _ground(L.PICNIC_POS), PI * 0.5, 1.0, Vector3(1.9, 0.78, 1.6), "PicnicTable")
	pt.name = "PicnicTable"
	BuildKit.prop(y, "wooden_lantern_01", _ground(L.PICNIC_POS) + Vector3(0.3, 0.76, 0.1), 0.0, 0.7)
	for k in 2:
		BuildKit.cylinder(y, 0.045, 0.1, _ground(L.PICNIC_POS) + Vector3(-0.3 + k * 0.25, 0.81, -0.2 + k * 0.1), ["mug_enamel", "mug_blue"][k], false, 10)
	# Seats around the fire, set back from embers
	var fp := L.BURN_PIT_POS
	var seats := [["Rockingchair_01", 1.0, -0.6], ["folding_wooden_stool", 1.0, 1.0], ["folding_wooden_stool", 1.0, 2.2], ["folding_wooden_stool", 1.0, 3.6]]
	for k in seats.size():
		var s: Array = seats[k]
		var ang: float = s[2]
		var r := 3.6
		var pos := _ground(fp + Vector3(cos(ang) * r, 0, sin(ang) * r))
		var face := atan2(-cos(ang), -sin(ang))
		BuildKit.prop(y, s[0], pos, face, s[1], Vector3(0.6, 0.5, 0.6))
	var blanket := BuildKit.box(y, Vector3(0.55, 0.03, 0.8), _ground(fp + Vector3(cos(-0.6) * 3.6, 0.62, sin(-0.6) * 3.6)), "picnic_check", false)
	blanket.rotation.x = 0.4
	BuildKit.prop(y, "wooden_crate_02", _ground(L.CAMPER_POS + Vector3(2.4, 0, -3.4)), 0.1, 1.0, Vector3(1.1, 0.45, 0.5))
	BuildKit.prop(y, "Barrel_02", _ground(L.CAMPER_POS + Vector3(1.85, 0, -4.4)), 0.0, 1.0, Vector3(0.5, 0.9, 0.5))
	# Payroll notice board (UI anchor for later prompts)
	var board := Node3D.new()
	board.name = "PayrollBoard"
	board.position = _ground(L.PAYROLL_BOARD_POS)
	board.rotation.y = deg_to_rad(-120.0)
	y.add_child(board)
	for px in [-0.6, 0.6]:
		BuildKit.box(board, Vector3(0.1, 1.9, 0.1), Vector3(px, 0.95, 0), "dark_wood", true)
	BuildKit.box(board, Vector3(1.4, 0.9, 0.05), Vector3(0, 1.35, 0), "planks", true)
	for k in 3:
		BuildKit.box(board, Vector3(0.22, 0.3, 0.005), Vector3(-0.4 + k * 0.38, 1.4 - (k % 2) * 0.1, 0.03), "white", false)
	var it := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 0.9, 0.2)
	cs.shape = shape
	cs.position = Vector3(0, 1.35, 0.05)
	it.add_child(cs)
	it.set_script(load("res://scripts/interaction/interactable.gd"))
	it.set("prompt", "Read notice board")
	it.set("message", "HIRING SOON: four bunks, fair wages. (Payroll arrives in a later prompt.)")
	board.add_child(it)
	BuildKit.marker(board, "PayrollUIAnchor", Vector3(0, 1.35, 0.6), 0.0, "payroll_anchor")


func _build_anchors() -> void:
	BuildKit.marker(self, "PlayerSpawn", _ground(Vector3(-3, 0, 12)), PI, "player_spawn")
	BuildKit.marker(self, "SafeResetPoint", _ground(Vector3(-2, 0, 4)), PI, "safe_reset")
	BuildKit.marker(self, "ForestEntrance", _ground(Vector3(0, 0, -L.FENCE_HALF.y)), 0.0, "camp_entrance")
	_interior_zone(self, "camp_yard", Vector3(0, 2.0, 0), Vector3(L.FENCE_HALF.x * 2, 6.0, L.FENCE_HALF.y * 2), false)


## Reserved hiding position for the failure-state hunt (Prompt 6). Never a
## safety zone during the contract.
func _hide_spot(parent: Node3D, name: String, pos: Vector3, kind: String) -> void:
	var m := BuildKit.marker(parent, name, pos, 0.0, "hiding_spot")
	m.set_meta("hide_kind", kind)


func _interior_zone(parent: Node3D, zone_name: String, center: Vector3, size: Vector3, always_safe: bool) -> void:
	var a := Area3D.new()
	a.name = "Zone_" + zone_name
	a.set_script(load("res://scripts/camp/interior_zone.gd"))
	a.set("zone_name", zone_name)
	a.set("always_safe", always_safe)
	a.set("is_interior", zone_name != "camp_yard")
	a.position = center
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	a.add_child(cs)
	parent.add_child(a)
	interior_zones.append(a)
