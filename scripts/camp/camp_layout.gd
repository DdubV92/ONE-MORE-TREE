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

const CAMPER_POS := Vector3(-15.0, 0.0, 3.0)    # center of footprint at ground
const CAMPER_SIZE := Vector3(3.0, 2.3, 9.4)     # interior box (x width, y height, z length)
const CAMPER_FLOOR := 0.62                      # floor height above ground
const CABIN_POS := Vector3(14.0, 0.0, -1.0)
const CABIN_SIZE := Vector3(7.2, 2.7, 10.4)
const CABIN_FLOOR := 0.35
const BURN_PIT_POS := Vector3(1.5, 0.0, -7.5)
const BURN_PIT_RADIUS := 1.7
const TOOL_AREA_POS := Vector3(13.5, 0.0, -14.0)
const PICNIC_POS := Vector3(-4.0, 0.0, 7.5)
const PAYROLL_BOARD_POS := Vector3(9.8, 0.0, 6.5)

## Exterior camp lamps (pole lights). Each defines an authoritative safe
## radius used by the SafetyService.
const LAMPS := [
	{"pos": Vector3(-7.0, 0.0, -14.5), "radius": 9.0},
	{"pos": Vector3(7.5, 0.0, -14.5), "radius": 9.0},
	{"pos": Vector3(-8.0, 0.0, 9.5), "radius": 9.0},
	{"pos": Vector3(6.0, 0.0, 12.0), "radius": 9.0},
	{"pos": Vector3(-19.0, 0.0, -12.0), "radius": 8.0},
	{"pos": Vector3(19.0, 0.0, 12.0), "radius": 8.0},
	{"pos": Vector3(0.0, 0.0, 1.0), "radius": 10.0},
]


static func origin() -> Vector3:
	return World.camp_origin()


static func world(local: Vector3) -> Vector3:
	var o := origin()
	return Vector3(o.x + local.x, World.height_at(o.x + local.x, o.z + local.z) + local.y, o.z + local.z)


static func inside_fence(p: Vector3) -> bool:
	var o := origin()
	return absf(p.x - o.x) < FENCE_HALF.x and absf(p.z - o.z) < FENCE_HALF.y
