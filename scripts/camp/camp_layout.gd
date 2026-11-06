class_name CampLayout
extends RefCounted
## Single source of truth for camp placement (meters, relative to the camp
## center at World.camp_origin(); +X east, +Z south toward the beach, -Z
## north toward the forest entrance). Builders, viewpoints, AI anchors and
## the safety service all read these values.

const FENCE_HALF := Vector2(22.5, 18.5)
const FENCE_HEIGHT := 2.0
const ENTRANCE_HALF_WIDTH := 6.5        # north opening (logging entrance)
const BEACH_GATE_HALF_WIDTH := 1.8      # small south opening to the beach path
## Phase 20: the forest-entrance gate is a real object. One galvanized tube
## leaf hangs on the west post of the north opening and normally stands open,
## folded flat against the inside of the fence (west of the opening), held by
## a chain at its free end. Folded back it narrows nothing: the opening, the
## truck bays/turning circle and the yard walkway are unchanged. Night
## incidents ("the gate swings", "the chain moved") use this leaf and chain.
const GATE_HINGE := Vector3(-ENTRANCE_HALF_WIDTH, 0.0, -FENCE_HALF.y + 0.18)
const GATE_LEAF := Vector2(3.0, 1.7)    # leaf length (along -X when open), height
const GATE_CLEARANCE := 0.1             # leaf bottom above the ground

const CAMPER_POS := Vector3(-15.0, 0.0, 3.0)    # camper origin (unchanged since Phase 0)
## Phase 11: +25 % usable floor. Width 3.0 -> 3.26 m (+8.7 %), length
## 9.4 -> 10.81 m (+15 %): 28.2 -> 35.24 m^2 (x1.2496). The north
## (bedroom) end, the entrance and the kitchen/bathroom stay where they
## were; all extra length goes to the lounge, where the desk station is.
const CAMPER_SIZE := Vector3(3.26, 2.3, 10.81)  # interior box (x width, y height, z length)
const CAMPER_V1_SIZE := Vector3(3.0, 2.3, 9.4)  # pre-Phase-11 interior (for reports/migration)
const CAMPER_NORTH_Z := -4.7                    # interior north wall (local), fixed
const CAMPER_SOUTH_Z := 6.11                    # interior south (lounge) wall (local)
const CAMPER_FLOOR := 0.62                      # floor height above ground
const CABIN_POS := Vector3(14.0, 0.0, -1.0)
const CABIN_SIZE := Vector3(7.2, 2.7, 10.4)
const CABIN_FLOOR := 0.35
const BURN_PIT_POS := Vector3(1.5, 0.0, -7.5)
const BURN_PIT_RADIUS := 1.7
const TOOL_AREA_POS := Vector3(13.5, 0.0, -14.0)
const PICNIC_POS := Vector3(-4.0, 0.0, 7.5)
const PAYROLL_BOARD_POS := Vector3(9.8, 0.0, 6.5)
## Phase 2 timber delivery: accepted-delivery rack beside the burn pit (its
## long axis runs along X), the hot-zone exclusion around the pit, standpoints
## for future workers and the truck drop-off point, and the camp recovery
## point for inaccessible timber.
const DELIVERY_RACK_POS := Vector3(5.6, 0.0, -7.3)
const DELIVERY_RACK_SIZE := Vector3(3.2, 1.2, 1.6)
const FIRE_HOT_RADIUS := 2.6
const DELIVERY_STANDPOINTS := [Vector3(5.6, 0.0, -5.6), Vector3(4.0, 0.0, -5.8), Vector3(7.2, 0.0, -5.8)]
const TRUCK_DROPOFF := Vector3(-2.0, 0.0, -9.5)
const RECOVERY_POINT := Vector3(8.6, 0.0, -9.6)

## Reserved footprints (camp-local, x/z rectangle centre + size). Built in
## later prompts; Phase 1 keeps them physically clear and validated.
const CABIN_EXTENSION := {"center": Vector3(14.0, 0.0, -9.0), "size": Vector3(7.4, 0.0, 5.0), "note": "attached 2-bed room + shared bathroom + kitchen nook (Prompt 4/5)"}
const TRUCK_BAYS := [
	{"center": Vector3(-11.5, 0.0, -13.5), "size": Vector3(3.0, 0.0, 6.0)},
	{"center": Vector3(-8.0, 0.0, -13.5), "size": Vector3(3.0, 0.0, 6.0)},
]
const TRUCK_TURNING := {"center": Vector3(-3.0, 0.0, -12.0), "radius": 5.5}

## Phase 13 logging yard. The receiving cradle is the Phase 2 delivery rack
## (unpaid intake becomes paid when it lands in a cradle slot). Accepted
## stock goes to three log decks in a small yard extension just outside the
## fence, north-east (flat, treeless on both islands, clear of the gate,
## turning circle, lamps, cameras and trails). Fuel for the fire waits on a short loading pile
## beside the pit. The early handcart parks by the cradle.
const CRADLE_SLOTS := 12
## Logs lie north-south (along Z), end grain facing the walkway; each deck
## stacks across X on sleepers, up to `size.y` high. size = (stack width X,
## max height, log bay length Z).
const YARD_DECKS := [
	{"center": Vector3(9.5, 0.0, -23.6), "size": Vector3(5.6, 2.4, 3.4)},
	{"center": Vector3(15.9, 0.0, -23.6), "size": Vector3(5.6, 2.4, 3.4)},
	{"center": Vector3(22.3, 0.0, -23.6), "size": Vector3(5.6, 2.4, 3.4)},
]
## Where people stand to work a deck's open south face (walkway between the
## fence and the decks).
const YARD_WALK_Z := -20.3
const YARD_RECT := {"center": Vector3(15.9, 0.0, -23.0), "size": Vector3(20.0, 0.0, 5.6)}
const PIT_LOAD_POS := Vector3(4.2, 0.0, -10.4)      # fuel loading pile (pit queue), east of the pit
const PIT_QUEUE_CAP := 12                          # pieces waiting beside the pit
const CART_PARK := Vector3(0.8, 0.0, -4.0)
## Phase 14: the supplier's parcel locker, in the quiet south-east corner of
## camp beside the payroll board (off the log, cart and truck routes). Its
## doors face north into camp.
const PARCEL_LOCKER_POS := Vector3(6.6, 0.0, 7.6)

## Phase 24 sawmill, outside the west fence behind the camper (surveyed
## tree-free and flat on both islands: tools/mill/corridor_probe.gd). The
## line runs north -> south: trucks stop at MILL_INTAKE (reached out of the
## north entrance and down a clear lane west of the fence), logs land on the
## feed rack, cross to the infeed rollers, pass the saw, ride the outfeed
## conveyor to the stacker at the bay's south edge; finished pallets go to
## the lumber yard south of the bay. The finishing lane (x = MILL_LINE_X)
## stays clear at every stack height. Not a safety place (no LAMPS entry).
const MILL_LINE_X := -29.5
const MILL_BAY := {"center": Vector3(-31.5, 0.0, 0.5), "size": Vector3(11.0, 4.2, 9.0)}
# The mill annex: a west wicket in the camp fence lines up with the rack
# standpoint, and the camp fence continues around the mill and its lumber
# yard (south side and far west side). The north side stays open to the
# logging road for trucks. The annex is part of the camp compound, not of
# the fenced camp interior (in_camp / night rules are unchanged).
const MILL_GATE_Z := -6.0
const MILL_GATE_HALF_WIDTH := 1.8
const MILL_ANNEX_LINE := [Vector2(-22.5, 18.5), Vector2(-39.0, 18.5), Vector2(-39.0, -12.5)]
const MILL_INTAKE := Vector3(-29.5, 0.0, -9.6)       # truck tailgate stop
const MILL_RACK_POS := Vector3(-29.5, 0.0, -3.3)     # feed rack (logs lie along Z)
const MILL_RACK_SIZE := Vector3(6.0, 0.9, 2.4)
const MILL_RACK_STAND := Vector3(-29.5, 0.0, -6.0)   # where carriers drop logs
const MILL_ROLLERS_POS := Vector3(-29.5, 0.0, -1.5)
const MILL_SAW_POS := Vector3(-29.5, 0.0, 0.6)
const MILL_OUTFEED := [Vector3(-29.5, 0.0, 1.6), Vector3(-29.5, 0.0, 4.6)]
const MILL_STACKER_POS := Vector3(-29.5, 0.0, 5.7)
const MILL_OPERATOR := Vector3(-27.3, 0.0, 0.6)
const MILL_BOARD_POS := Vector3(-25.9, 0.0, -4.4)    # yard board (status sign)
## Lumber yard: marked bays either side of the finishing lane, rows south,
## stacked up to MILL_LAYERS high -> MILL_DISPLAY_CAP visible pallets.
const MILL_YARD_BAYS_X := [-35.4, -32.6, -26.4]
const MILL_YARD_ROWS_Z := [8.6, 11.1, 13.6, 16.1]
const MILL_LAYERS := 4
const MILL_DISPLAY_CAP := 48
const MILL_PALLET_SIZE := Vector3(1.2, 0.62, 1.2)
## Solid footprints (navigation), [center, size] in camp-local metres.
const MILL_SOLIDS := [
	[Vector3(-29.5, 0.0, -3.3), Vector3(6.0, 0.0, 2.4)],     # feed rack
	[Vector3(-29.5, 0.0, 0.1), Vector3(1.6, 0.0, 4.2)],      # rollers + saw
	[Vector3(-29.5, 0.0, 3.4), Vector3(1.2, 0.0, 3.4)],      # outfeed + stacker
	[Vector3(-36.6, 0.0, 0.5), Vector3(0.4, 0.0, 9.0)],      # back wall
]


static func mill_world(local: Vector3) -> Vector3:
	return world(local)


## True inside the sawmill bay or its lumber yard (+margin): decorative
## ground cover, undergrowth and soft cover keep out.
static func in_mill(p: Vector3, margin := 0.0) -> bool:
	var o := origin()
	var lx := p.x - o.x
	var lz := p.z - o.z
	var c: Vector3 = MILL_BAY.center
	var sz: Vector3 = MILL_BAY.size
	if absf(lx - c.x) < sz.x * 0.5 + margin and absf(lz - c.z) < sz.z * 0.5 + margin:
		return true
	# Lumber yard and the approach apron in front of the feed rack.
	if lx > -38.0 - margin and lx < -24.4 + margin and lz > 5.0 - margin and lz < 17.6 + margin:
		return true
	return lx > -33.5 - margin and lx < -25.5 + margin and lz > -11.5 - margin and lz < -3.9 + margin


## Lumber-yard slot (0..MILL_DISPLAY_CAP-1) -> camp-local pallet base.
## Fills bays from the back row forward, then the next layer up.
static func mill_slot(i: int) -> Vector3:
	var per_layer: int = MILL_YARD_BAYS_X.size() * MILL_YARD_ROWS_Z.size()
	var layer := i / per_layer
	var k := i % per_layer
	var row: int = MILL_YARD_ROWS_Z.size() - 1 - k / MILL_YARD_BAYS_X.size()
	var bay: int = k % MILL_YARD_BAYS_X.size()
	return Vector3(float(MILL_YARD_BAYS_X[bay]), float(layer) * MILL_PALLET_SIZE.y, float(MILL_YARD_ROWS_Z[row]))


static func deck_standpoint(i: int) -> Vector3:
	var c: Vector3 = YARD_DECKS[i].center
	return Vector3(c.x, 0.0, YARD_WALK_Z)


## True inside the yard extension (+margin): decorative ground cover and
## undergrowth keep out, navigation treats decks as solid.
static func in_yard(p: Vector3, margin := 0.0) -> bool:
	var o := origin()
	var c: Vector3 = YARD_RECT.center
	var sz: Vector3 = YARD_RECT.size
	return absf(p.x - (o.x + c.x)) < sz.x * 0.5 + margin and absf(p.z - (o.z + c.z)) < sz.z * 0.5 + margin


static func on_deck(p: Vector3, margin := 0.0) -> int:
	var o := origin()
	for i in YARD_DECKS.size():
		var c: Vector3 = YARD_DECKS[i].center
		var sz: Vector3 = YARD_DECKS[i].size
		if absf(p.x - (o.x + c.x)) < sz.x * 0.5 + margin and absf(p.z - (o.z + c.z)) < sz.z * 0.5 + margin:
			return i
	return -1


## Exterior camp lamps (pole lights). Each defines an authoritative safe
## radius used by the SafetyService.
const LAMPS := [
	{"pos": Vector3(-4.6, 0.0, -16.6), "radius": 9.0},
	{"pos": Vector3(7.5, 0.0, -14.5), "radius": 9.0},
	{"pos": Vector3(-8.0, 0.0, 9.5), "radius": 9.0},
	{"pos": Vector3(6.0, 0.0, 12.0), "radius": 9.0},
	{"pos": Vector3(-19.0, 0.0, -12.0), "radius": 8.0},
	{"pos": Vector3(19.0, 0.0, 12.0), "radius": 8.0},
	{"pos": Vector3(0.0, 0.0, 1.0), "radius": 10.0},
]


## Interior box centre relative to CAMPER_POS (the box is no longer centred
## on the origin after the lounge extension).
static func camper_box_offset() -> Vector3:
	return Vector3(0.0, 0.0, (CAMPER_NORTH_Z + CAMPER_SOUTH_Z) * 0.5)


## Camper-local point inside the interior box (with a margin).
static func camper_local_inside(l: Vector3, margin := 0.0) -> bool:
	return absf(l.x) < CAMPER_SIZE.x * 0.5 + margin and l.z > CAMPER_NORTH_Z - margin and l.z < CAMPER_SOUTH_Z + margin and l.y > CAMPER_FLOOR - 0.2


static func camper_usable_area() -> float:
	return CAMPER_SIZE.x * CAMPER_SIZE.z


static func origin() -> Vector3:
	return World.camp_origin()


## Free end of the open gate leaf (where its chain is), camp-local, ground.
static func gate_latch() -> Vector3:
	return GATE_HINGE + Vector3(-GATE_LEAF.x, 0.0, 0.0)


static func world(local: Vector3) -> Vector3:
	var o := origin()
	return Vector3(o.x + local.x, World.height_at(o.x + local.x, o.z + local.z) + local.y, o.z + local.z)


static func inside_fence(p: Vector3) -> bool:
	var o := origin()
	return absf(p.x - o.x) < FENCE_HALF.x and absf(p.z - o.z) < FENCE_HALF.y
