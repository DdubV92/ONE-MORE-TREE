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
	add_child(fire)
	_build_camper()
	_build_cabin()
	_build_tool_area()
	_build_yard()
	_build_anchors()


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
	var W := L.CAMPER_SIZE.x * 0.5      # 1.5
	var Lz := L.CAMPER_SIZE.z * 0.5     # 4.7
	var H := L.CAMPER_SIZE.y            # 2.3
	var t := 0.08
	# Shell
	BuildKit.box(c, Vector3(W * 2 + t * 2, 0.12, Lz * 2 + t * 2), Vector3(0, F - 0.06, 0), "floor", true, 0.0, "Floor")
	BuildKit.box(c, Vector3(W * 2 + 0.3, 0.12, Lz * 2 + 0.3), Vector3(0, F + H + 0.06, 0), "camper_paint", true, 0.0, "Roof")
	BuildKit.box(c, Vector3(W * 2 + 0.36, 0.05, Lz * 2 + 0.36), Vector3(0, F + H + 0.14, 0), "camper_trim", false)
	var door_open := [2.44, 3.34, 0.0, 2.0]
	var east := [door_open, [0.44, 1.54, 1.0, 1.8], [7.34, 8.54, 1.1, 1.8], [5.04, 5.64, 1.6, 1.95]]
	var west := [[5.54, 6.94, 1.25, 1.85], [0.84, 2.34, 0.95, 1.8], [8.14, 9.14, 1.0, 1.8]]
	var east_o := Vector3(W + t * 0.5, F, Lz + t)
	var west_o := Vector3(-W - t * 0.5, F, -Lz - t)
	BuildKit.wall(c, east_o, PI * 0.5, Lz * 2 + t * 2, H, t, east, "camper_paint")
	BuildKit.wall(c, west_o, -PI * 0.5, Lz * 2 + t * 2, H, t, west, "camper_paint")
	var north := [[0.88, 2.28, 1.2, 1.85]]
	var south := [[0.78, 2.38, 1.0, 1.8]]
	BuildKit.wall(c, Vector3(-W - t, F, -Lz - t * 0.5), 0.0, W * 2 + t * 2, H, t, north, "camper_paint")
	BuildKit.wall(c, Vector3(W + t, F, Lz + t * 0.5), PI, W * 2 + t * 2, H, t, south, "camper_paint")
	for o in east:
		if o != door_open:
			BuildKit.window_glass(c, east_o, PI * 0.5, o, t)
	for o in west:
		BuildKit.window_glass(c, west_o, -PI * 0.5, o, t)
	BuildKit.window_glass(c, Vector3(-W - t, F, -Lz - t * 0.5), 0.0, north[0], t)
	BuildKit.window_glass(c, Vector3(W + t, F, Lz + t * 0.5), PI, south[0], t)
	# Teal stripe below the windows (split around the door)
	BuildKit.box(c, Vector3(0.012, 0.16, 2.3), Vector3(W + t + 0.006, F + 0.62, 3.55), "camper_stripe", false)
	BuildKit.box(c, Vector3(0.012, 0.16, 6.0), Vector3(W + t + 0.006, F + 0.62, -1.75), "camper_stripe", false)
	BuildKit.box(c, Vector3(0.012, 0.16, Lz * 2), Vector3(-W - t - 0.006, F + 0.62, 0), "camper_stripe", false)
	# Chassis, wheels, hitch, propane
	BuildKit.box(c, Vector3(W * 2 - 0.3, 0.3, Lz * 2 - 0.6), Vector3(0, F - 0.3, 0), "steel", true)
	for sx in [-1.0, 1.0]:
		for z in [-0.45, 0.45]:
			var wheel := BuildKit.cylinder(c, 0.36, 0.22, Vector3(sx * (W - 0.02), 0.36, z), "rubber", false, 16)
			wheel.rotation.z = PI * 0.5
			var hub := BuildKit.cylinder(c, 0.17, 0.24, wheel.position, "camper_trim", false, 12)
			hub.rotation.z = PI * 0.5
	BuildKit.box(c, Vector3(0.12, 0.12, 1.4), Vector3(0, 0.45, Lz + 0.75), "steel", true)
	BuildKit.box(c, Vector3(0.5, 0.25, 0.25), Vector3(0, 0.4, Lz + 1.5), "steel", false)
	BuildKit.prop(c, "propane_tank", Vector3(0.0, 0.52, Lz + 0.65), 0.0, 1.0)
	BuildKit.cylinder(c, 0.04, 0.45, Vector3(0, 0.22, Lz + 1.35), "steel", false, 6)
	# Entrance: door, steps, ramp collision, boots on a mat
	var door := Door.new()
	door.name = "CamperDoor"
	door.width = 0.9
	door.height = 2.0
	door.material_name = "camper_paint"
	door.open_angle = 100.0
	door.position = Vector3(W + t * 0.5, F, 2.3)
	door.rotation.y = PI * 0.5
	c.add_child(door)
	for s in 2:
		var hgt := F * float(s + 1) / 3.0
		BuildKit.box(c, Vector3(0.35, 0.05, 1.0), Vector3(W + t + 0.62 - s * 0.32, hgt, 1.85), "steel", false)
	BuildKit.ramp(c, Vector3(W + 1.4, 0.0, 1.85), Vector3(W + t, F, 1.85), 1.0)
	BuildKit.box(c, Vector3(0.9, 0.02, 0.6), Vector3(W + 1.6, 0.01, 1.85), "dog_bed", false)
	BuildKit.prop(c, "rubber_boots", Vector3(W + 1.75, 0.02, 2.55), -PI * 0.3, 0.75)
	# --- Kitchen (west wall, z 0.4..2.9)
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
	# --- Dinette (front)
	BuildKit.box(c, Vector3(W * 2 - 0.1, 0.42, 0.5), Vector3(0, F + 0.21, Lz - 0.3), "panel", true, 0.0, "Bench")
	BuildKit.box(c, Vector3(W * 2 - 0.2, 0.1, 0.48), Vector3(0, F + 0.47, Lz - 0.3), "denim", false)
	BuildKit.box(c, Vector3(W * 2 - 0.2, 0.45, 0.1), Vector3(0, F + 0.75, Lz - 0.05), "denim", false)
	BuildKit.box(c, Vector3(1.2, 0.05, 0.6), Vector3(0, F + 0.72, Lz - 0.9), "dark_wood", true, 0.0, "Table")
	BuildKit.cylinder(c, 0.04, 0.7, Vector3(0, F + 0.35, Lz - 0.9), "steel", false, 8)
	BuildKit.prop(c, "carved_wooden_plate", Vector3(0.25, F + 0.75, Lz - 0.9), 0.0, 1.0)
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
	BuildKit.box(c, Vector3(0.02, 1.9, 0.8), Vector3(0.62, F + 1.05, -0.95), "blanket_blue", false, 0.0, "ShowerCurtain")
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
	bed.position = Vector3(0.0, F, -Lz + 1.0)
	c.add_child(bed)
	BuildKit.box(bed, Vector3(1.45, 0.35, 2.0), Vector3(0, 0.175, 0), "dark_wood", true)
	BuildKit.box(bed, Vector3(1.38, 0.2, 1.95), Vector3(0, 0.45, 0.02), "mattress", false)
	BuildKit.box(bed, Vector3(1.42, 0.06, 1.35), Vector3(0, 0.57, 0.33), "blanket_red", false)
	BuildKit.box(bed, Vector3(1.45, 0.75, 0.08), Vector3(0, 0.5, -1.0), "dark_wood", false)
	BuildKit.prop(bed, "throw_pillows_01", Vector3(0, 0.55, -0.72), 0.0, 1.0)
	BuildKit.marker(bed, "PlayerSleepPoint", Vector3(0, 0.75, 0.1), PI, "player_bed")
	BuildKit.prop(c, "painted_wooden_nightstand", Vector3(1.15, F, -Lz + 0.35), PI, 0.85)
	BuildKit.box(c, Vector3(0.6, 2.0, 0.85), Vector3(W - 0.3, F + 1.0, -1.95), "panel", true, 0.0, "Wardrobe")
	# --- Interior lights (warm, no shadows: cheap and stable)
	for lz in [2.0, -3.0, -0.6]:
		var li := OmniLight3D.new()
		li.position = Vector3(0.0 if lz != -0.6 else 0.85, F + H - 0.15, lz)
		li.omni_range = 3.6 if lz != -0.6 else 1.6
		li.light_energy = 0.9
		li.light_color = Color(1.0, 0.78, 0.52)
		c.add_child(li)
		BuildKit.cylinder(c, 0.14, 0.03, li.position + Vector3(0, 0.12, 0), "lamp_bulb", false, 12)
	_interior_zone(c, "camper", Vector3(0, F + H * 0.5, 0), Vector3(W * 2, H, Lz * 2), true)


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
	var north := [[0.94, 1.94, 1.2, 1.8], [4.64, 5.64, 1.2, 1.8]]
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
		BuildKit.box(bed, Vector3(0.9, 0.05, 1.3), Vector3(0, 0.61, 0.3), spec[1], false)
		BuildKit.box(bed, Vector3(0.6, 0.12, 0.35), Vector3(0, 0.65, -0.72), "white", false)
		BuildKit.marker(bed, "SleepPoint", Vector3(0, 0.8, 0.1), 0.0, "worker_bed")
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
	BuildKit.cylinder(c, 0.045, 0.1, Vector3(-0.2, F + 0.83, -0.3), "blanket_blue", false, 10)
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
	var rack_it := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 1.6, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, 1.2, -0.85)
	rack_it.add_child(cs)
	rack_it.set_script(load("res://scripts/interaction/interactable.gd"))
	rack_it.set("prompt", "Inspect axe rack")
	rack_it.set("message", "Small, medium and large axes. Buying and swinging them comes with the logging prompts.")
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
		BuildKit.cylinder(y, 0.045, 0.1, _ground(L.PICNIC_POS) + Vector3(-0.3 + k * 0.25, 0.81, -0.2 + k * 0.1), ["blanket_ochre", "blanket_green"][k], false, 10)
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
	var blanket := BuildKit.box(y, Vector3(0.55, 0.03, 0.8), _ground(fp + Vector3(cos(-0.6) * 3.6, 0.62, sin(-0.6) * 3.6)), "blanket_green", false)
	blanket.rotation.x = 0.4
	BuildKit.prop(y, "wooden_crate_02", _ground(L.CAMPER_POS + Vector3(2.4, 0, -3.4)), 0.1, 1.0, Vector3(1.1, 0.45, 0.5))
	BuildKit.prop(y, "Barrel_02", _ground(L.CAMPER_POS + Vector3(2.2, 0, -4.4)), 0.0, 1.0, Vector3(0.5, 0.9, 0.5))
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
