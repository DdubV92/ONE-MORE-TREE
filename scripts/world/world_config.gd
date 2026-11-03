class_name WorldConfig
extends Resource
## Authored, data-driven description of the island. The generator turns this
## into the frozen world data in res://data/world/. Changing any value here
## changes the generated world: bump `generation_version` and regenerate
## (see docs/ARCHITECTURE.md, "Frozen world layout").
##
## Axes: meters, +Y up, +X east, +Z south (Godot's -Z is "north").

@export var world_seed: int = 20261103
@export var generation_version: int = 1

@export_group("Grid")
## World-space rectangle covered by the height field (includes sea floor).
@export var bounds_min := Vector2(-1000.0, -800.0)
@export var bounds_max := Vector2(1000.0, 800.0)
## Height-field sample spacing in meters.
@export var cell_size: float = 2.0
## Terrain chunk edge in cells (chunk = chunk_cells * cell_size meters).
@export var chunk_cells: int = 32

@export_group("Island shape")
## Half extents of the base island ellipse (~1600 x 1200 m footprint).
@export var island_half_extents := Vector2(735.0, 535.0)
@export var sea_level: float = 0.0
@export var max_sea_depth: float = 26.0
## Coves/bays carved out of the base ellipse: x, z, radius, strength.
@export var bays: Array[Vector4] = [
	Vector4(-170.0, 640.0, 230.0, 0.30),   # sheltered landing cove (south)
	Vector4(-640.0, -380.0, 210.0, 0.22),  # north-west inlet
	Vector4(560.0, 470.0, 200.0, 0.20),    # south-east bay
	Vector4(140.0, -650.0, 170.0, 0.16),   # north bight
]

@export_group("Relief")
@export var inland_base_height: float = 7.0
@export var hill_amplitude: float = 16.0
@export var ridge_start := Vector2(120.0, -360.0)
@export var ridge_end := Vector2(560.0, -120.0)
@export var ridge_height: float = 44.0
@export var ridge_half_width: float = 95.0
## Fern-rich lowland basin (x, z, radius).
@export var lowland := Vector3(-430.0, -40.0, 230.0)

@export_group("Beaches")
## Sand beaches: x, z, radius (soft masks; beaches are gentle slopes).
@export var beaches: Array[Vector3] = [
	Vector3(-170.0, 470.0, 230.0),  # landing beach below camp
	Vector3(-560.0, 260.0, 200.0),  # long south-west beach
	Vector3(380.0, 470.0, 150.0),   # east cove beach
]

@export_group("Camp")
@export var camp_center := Vector2(-175.0, 355.0)
@export var camp_size := Vector2(42.0, 34.0)
@export var camp_height: float = 5.2
## Direction (unit XZ) from camp center toward the forest entrance.
@export var camp_entrance_dir := Vector2(0.0, -1.0)

@export_group("Water")
## Pond definitions: x, z, radius, center depth.
@export var ponds: Array[Vector4] = [
	Vector4(-430.0, -55.0, 40.0, 2.2),
	Vector4(275.0, -15.0, 27.0, 1.8),
]
## River centerline from source to sea (XZ control points).
@export var river_points: PackedVector2Array = PackedVector2Array([
	Vector2(415.0, -185.0), Vector2(385.0, -150.0), Vector2(330.0, -105.0),
	Vector2(270.0, -70.0), Vector2(210.0, -10.0), Vector2(165.0, 70.0),
	Vector2(120.0, 150.0), Vector2(95.0, 235.0), Vector2(60.0, 320.0),
	Vector2(30.0, 410.0), Vector2(5.0, 500.0), Vector2(-15.0, 600.0),
])
@export var river_width_source: float = 4.0
@export var river_width_mouth: float = 9.0
@export var river_depth: float = 1.25
## Design water level at the source; the valley floor follows this grade.
@export var river_source_level: float = 15.0
## Arc-length positions (m from source) where authored riffles/steps occur.
@export var river_steps: PackedFloat32Array = PackedFloat32Array([150.0, 330.0, 520.0])
@export var river_step_drop: float = 1.1
## Crossing sites (fraction along river length) reserved for bridges.
@export var bridge_sites: PackedFloat32Array = PackedFloat32Array([0.527, 0.79])
## Wading limit: deeper water gently pushes the player back.
@export var wade_depth_limit: float = 0.9

@export_group("Trails")
## Faint walking trails from the camp entrance into the forest.
@export var trails: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-175.0, 330.0), Vector2(-190.0, 250.0), Vector2(-260.0, 150.0), Vector2(-360.0, 40.0), Vector2(-430.0, -10.0)]),
	PackedVector2Array([Vector2(-175.0, 330.0), Vector2(-120.0, 250.0), Vector2(-20.0, 195.0), Vector2(60.0, 186.0), Vector2(110.0, 180.0), Vector2(165.0, 150.0), Vector2(235.0, 90.0)]),
	PackedVector2Array([Vector2(-175.0, 372.0), Vector2(-178.0, 420.0), Vector2(-172.0, 470.0)]),
]

@export_group("Forest")
@export var tree_target: int = 12000
@export var tree_candidate_spacing: float = 4.6
@export var min_trunk_spacing: float = 2.8
@export var camp_tree_clearance: float = 16.0
@export var vegetation_chunk_size: float = 128.0

@export_group("Rocks")
@export var ridge_rock_count: int = 170
@export var forest_boulder_count: int = 240
@export var shore_stone_count: int = 160


func grid_size() -> Vector2i:
	var span := bounds_max - bounds_min
	return Vector2i(int(round(span.x / cell_size)) + 1, int(round(span.y / cell_size)) + 1)


func config_fingerprint() -> String:
	# Stable text digest of every authored value that affects generation.
	var parts: PackedStringArray = []
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and p.name != "resource_path" and p.name != "script":
			parts.append("%s=%s" % [p.name, str(get(p.name))])
	return "\n".join(parts).md5_text()
