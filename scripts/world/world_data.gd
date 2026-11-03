extends Node
## Autoload "World": loads the frozen world data and is the single source of
## world-space facts (elevation, water, masks, trees, rocks) for rendering,
## physics, placement, audio, navigation and future logging.

const DATA_DIR := "res://data/world"

signal loaded

var config: WorldConfig
var manifest: Dictionary = {}
var is_loaded := false

var W := 0
var H := 0
var cs := 2.0
var origin := Vector2.ZERO
var sea_level := 0.0

var height := PackedFloat32Array()
var masks := PackedByteArray()
var water_surface := PackedFloat32Array()
var water_region := PackedByteArray()
var trees: Dictionary = {}
var rocks: Dictionary = {}
var layout: Dictionary = {}

var river_points := PackedVector2Array()
var river_levels := PackedFloat32Array()
var river_widths := PackedFloat32Array()
var river_rapid := PackedFloat32Array()
var river_arc := PackedFloat32Array()

var height_texture: ImageTexture
var mask_texture: ImageTexture
var water_texture: ImageTexture

## Trees removed from the world (felled). Phase 0 never adds to this, but
## rendering and collision already respect it so removal-by-ID works.
var removed_trees := {}
signal tree_removed(tree_id: int)

var load_ms := 0


func ensure_loaded() -> void:
	if is_loaded:
		return
	var t0 := Time.get_ticks_msec()
	config = load("res://config/world_config.tres")
	var mf := FileAccess.open(DATA_DIR.path_join("manifest.json"), FileAccess.READ)
	if mf == null:
		push_error("World data missing: run tools/generate_world.gd")
		_generate_fallback()
	else:
		manifest = JSON.parse_string(mf.get_as_text())
		if int(manifest.get("generation_version", -1)) != config.generation_version:
			push_warning("World manifest generation_version %s differs from config %s" % [manifest.get("generation_version"), config.generation_version])
		var grid: Dictionary = manifest.grid
		W = int(grid.width)
		H = int(grid.height)
		cs = float(grid.cell_size)
		origin = Vector2(float(grid.origin[0]), float(grid.origin[1]))
		sea_level = float(manifest.sea_level)
		height = _read_bin("heightmap.bin").to_float32_array()
		masks = _read_bin("masks.bin")
		water_surface = _read_bin("water_surface.bin").to_float32_array()
		water_region = _read_bin("water_region.bin")
		trees = bytes_to_var(_read_bin("trees.bin"))
		rocks = bytes_to_var(_read_bin("rocks.bin"))
		var lf := FileAccess.open(DATA_DIR.path_join("layout.json"), FileAccess.READ)
		layout = JSON.parse_string(lf.get_as_text())
	_unpack_river()
	_build_textures()
	is_loaded = true
	load_ms = Time.get_ticks_msec() - t0
	loaded.emit()


func _read_bin(fname: String) -> PackedByteArray:
	var f := FileAccess.open_compressed(DATA_DIR.path_join(fname + ".zst"), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("Cannot open world file %s" % fname)
		return PackedByteArray()
	var bytes := f.get_buffer(f.get_length())
	return bytes


func _generate_fallback() -> void:
	# Slow path: regenerate in memory (keeps the game bootable if data is lost).
	var gen := IslandGenerator.new(config)
	gen.generate()
	W = gen.W
	H = gen.H
	cs = gen.cs
	origin = gen.bmin
	sea_level = config.sea_level
	height = gen.height
	masks = gen.masks
	water_surface = gen.water_surface
	water_region = gen.water_region
	trees = gen.trees
	rocks = gen.rocks
	layout = JSON.parse_string(JSON.stringify(gen.layout_json()))
	manifest = {"generation_version": config.generation_version, "world_seed": config.world_seed, "stats": gen.stats, "fallback": true}


func _unpack_river() -> void:
	var samples: Array = layout.river.samples
	river_points.resize(samples.size())
	river_levels.resize(samples.size())
	river_widths.resize(samples.size())
	river_rapid.resize(samples.size())
	river_arc.resize(samples.size())
	for k in samples.size():
		var s: Array = samples[k]
		river_points[k] = Vector2(s[0], s[1])
		river_levels[k] = s[2]
		river_widths[k] = s[3]
		river_rapid[k] = s[4]
		river_arc[k] = s[5]


func _build_textures() -> void:
	var himg := Image.create_from_data(W, H, false, Image.FORMAT_RF, height.to_byte_array())
	height_texture = ImageTexture.create_from_image(himg)
	var mimg := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, masks)
	mimg.generate_mipmaps()
	mask_texture = ImageTexture.create_from_image(mimg)
	var wimg := Image.create_from_data(W, H, false, Image.FORMAT_RF, water_surface.to_byte_array())
	water_texture = ImageTexture.create_from_image(wimg)


# ------------------------------------------------------------ sampling API

func world_size() -> Vector2:
	return Vector2((W - 1) * cs, (H - 1) * cs)


func in_bounds(p: Vector2) -> bool:
	return p.x >= origin.x and p.y >= origin.y and p.x <= origin.x + (W - 1) * cs and p.y <= origin.y + (H - 1) * cs


## Terrain height at world XZ. Triangle-exact: matches the rendered LOD0
## terrain mesh (quad split along the (i,j)-(i+1,j+1) diagonal).
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


func height_at_v(p: Vector3) -> float:
	return height_at(p.x, p.z)


func normal_at(x: float, z: float) -> Vector3:
	var e := cs
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func _texel(x: float, z: float) -> int:
	var i := clampi(int(round((x - origin.x) / cs)), 0, W - 1)
	var j := clampi(int(round((z - origin.y) / cs)), 0, H - 1)
	return j * W + i


## Mask channels 0..1: x=sand, y=forest floor, z=dirt/trail, w=rock.
func masks_at(x: float, z: float) -> Vector4:
	var t := _texel(x, z) * 4
	return Vector4(masks[t], masks[t + 1], masks[t + 2], masks[t + 3]) / 255.0


## Water surface height at XZ (sea level, river or pond level).
func water_level_at(x: float, z: float) -> float:
	return water_surface[_texel(x, z)]


## 0 = ocean / none, 1 = river, 2+ = pond index + 2
func water_region_at(x: float, z: float) -> int:
	return water_region[_texel(x, z)]


func water_depth_at(x: float, z: float) -> float:
	return maxf(water_level_at(x, z) - height_at(x, z), 0.0)


enum Surface { GRASS, DIRT, SAND, ROCK, FOREST, WATER, WOOD }


func surface_at(x: float, z: float) -> int:
	if water_depth_at(x, z) > 0.05:
		return Surface.WATER
	var m := masks_at(x, z)
	if m.z > 0.5:
		return Surface.DIRT
	if m.x > 0.5:
		return Surface.SAND
	if m.w > 0.5 or normal_at(x, z).y < 0.75:
		return Surface.ROCK
	if m.y > 0.4:
		return Surface.FOREST
	return Surface.GRASS


func nearest_river_index(p: Vector2) -> int:
	var best := 0
	var bd := INF
	for k in range(0, river_points.size(), 4):
		var d := p.distance_squared_to(river_points[k])
		if d < bd:
			bd = d
			best = k
	var lo := maxi(best - 4, 0)
	var hi := mini(best + 4, river_points.size() - 1)
	for k in range(lo, hi + 1):
		var d := p.distance_squared_to(river_points[k])
		if d < bd:
			bd = d
			best = k
	return best


func tree_count() -> int:
	return (trees.id as PackedInt32Array).size()


func tree_position(idx: int) -> Vector3:
	var x: float = trees.x[idx]
	var z: float = trees.z[idx]
	return Vector3(x, height_at(x, z), z)


func tree_record(idx: int) -> Dictionary:
	const SPECIES := ["pine", "spruce", "birch"]
	return {
		"id": trees.id[idx],
		"species": SPECIES[trees.species[idx]],
		"variant": trees.variant[idx],
		"chunk": trees.chunk[idx],
		"position": tree_position(idx),
		"rotation_deg": rad_to_deg(trees.rot[idx]),
		"height_m": trees.height[idx],
		"trunk_radius_m": trees.radius[idx],
		"lean_deg": Vector2(rad_to_deg(trees.lean_x[idx]), rad_to_deg(trees.lean_z[idx])),
		"log_budget": trees.logs[idx],
		"removed": removed_trees.has(int(trees.id[idx])),
	}


func remove_tree(tree_id: int) -> void:
	## Stable-ID removal hook for Phase 1 felling. Renderers and collision
	## listen to `tree_removed`.
	if removed_trees.has(tree_id):
		return
	removed_trees[tree_id] = true
	tree_removed.emit(tree_id)


func ponds() -> Array:
	return layout.ponds


func bridges() -> Array:
	return layout.bridges


func shore_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in layout.shore_points:
		out.append(Vector2(p[0], p[1]))
	return out


func camp_origin() -> Vector3:
	var c := config.camp_center
	return Vector3(c.x, config.camp_height, c.y)
