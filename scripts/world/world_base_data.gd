class_name WorldBaseData
extends RefCounted
## Phase 12: read-only loader for the frozen base world (data/world,
## revision 1) without any autoload/game dependency, for offline tools such
## as the island_r2 planner. Mirrors the parts of WorldData it needs.

const DATA_DIR := "res://data/world"

var config: WorldConfig
var manifest: Dictionary = {}
var W := 0
var H := 0
var cs := 2.0
var origin := Vector2.ZERO
var height := PackedFloat32Array()
var masks := PackedByteArray()
var water_surface := PackedFloat32Array()
var water_region := PackedByteArray()
var trees: Dictionary = {}
var rocks: Dictionary = {}
var layout: Dictionary = {}
var river_points := PackedVector2Array()
var river_widths := PackedFloat32Array()


func ensure_loaded() -> void:
	config = load("res://config/world_config.tres")
	manifest = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join("manifest.json")))
	var grid: Dictionary = manifest.grid
	W = int(grid.width)
	H = int(grid.height)
	cs = float(grid.cell_size)
	origin = Vector2(float(grid.origin[0]), float(grid.origin[1]))
	height = _read("heightmap.bin").to_float32_array()
	masks = _read("masks.bin")
	water_surface = _read("water_surface.bin").to_float32_array()
	water_region = _read("water_region.bin")
	trees = bytes_to_var(_read("trees.bin"))
	rocks = bytes_to_var(_read("rocks.bin"))
	layout = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join("layout.json")))
	for s in layout.river.samples:
		river_points.append(Vector2(s[0], s[1]))
		river_widths.append(s[3])


func _read(fname: String) -> PackedByteArray:
	var f := FileAccess.open_compressed(DATA_DIR.path_join(fname + ".zst"), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	return f.get_buffer(f.get_length())


func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / cs, 0.0, W - 1.0001)
	var fz := clampf((z - origin.y) / cs, 0.0, H - 1.0001)
	var i := int(fx)
	var j := int(fz)
	fx -= i
	fz -= j
	var row := j * W + i
	var a := height[row]
	var b := height[row + 1]
	var c := height[row + W]
	var d := height[row + W + 1]
	if fx > fz:
		return a + (b - a) * fx + (d - b) * fz
	return a + (c - a) * fz + (d - c) * fx


func ponds() -> Array:
	return layout.ponds


func bridges() -> Array:
	return layout.bridges
