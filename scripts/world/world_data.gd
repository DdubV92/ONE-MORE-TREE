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


## Phase 10: trees outside the active campaign's native manifest (e.g. the
## 2,000 not in the standard 10,000-tree ruleset). They are never spawned,
## rendered, collided, targeted or counted; legacy campaigns have none.
var excluded_trees := {}
var manifest_variant := "full"


func native_total() -> int:
	return tree_count() - excluded_trees.size()


func is_native(tree_id: int) -> bool:
	return not excluded_trees.has(tree_id)


## Applies a manifest variant before vegetation is built (no signals: the
## excluded trees simply never exist in this world).
##   full          revision-1 island, all 12,000 trees (legacy contract)
##   standard_10k  revision-1 island, 10,000-tree subset (Phase 10 saves)
##   island_r2     Phase 12 island revision 2 (new standard campaigns):
##                 landform terrain, 10,000 planned native trees, rock
##                 formations, undergrowth and hide anchors (data/world/r2)
func apply_variant(variant: String) -> void:
	_restore_base()
	manifest_variant = variant
	excluded_trees = {}
	if variant == "island_r2":
		_apply_r2()
	else:
		excluded_trees = Ruleset.excluded_ids(variant).duplicate()
	for id in excluded_trees:
		removed_trees[id] = true


# ------------------------------------------------------- island revisions

const R2_DIR := "res://data/world/r2"
## "r1" = the frozen base island; "r2" = Phase 12 revision (new campaigns).
var island_revision := "r1"
var r2_manifest: Dictionary = {}
## Non-native undergrowth instances (r2 only): x, z, kind, scale, rot, seed.
var shrubs: Dictionary = {}
## r2 cover data: landforms, formations, hides, thickets, regions.
var cover: Dictionary = {}
var _base := {}
var _r2 := {}


func _restore_base() -> void:
	if island_revision == "r1":
		return
	height = _base.height
	masks = _base.masks
	trees = _base.trees
	rocks = _base.rocks
	shrubs = {}
	cover = {}
	island_revision = "r1"
	_build_textures()


func _apply_r2() -> void:
	if _base.is_empty():
		_base = {"height": height, "masks": masks, "trees": trees, "rocks": rocks}
	if _r2.is_empty():
		var t0 := Time.get_ticks_msec()
		r2_manifest = JSON.parse_string(FileAccess.get_file_as_string(R2_DIR.path_join("manifest.json")))
		var dlt := _read_r2("height_delta.bin").to_float32_array()
		var h2: PackedFloat32Array = (_base.height as PackedFloat32Array).duplicate()
		for i in mini(dlt.size(), h2.size()):
			if dlt[i] != 0.0:
				h2[i] += dlt[i]
		_r2 = {
			"height": h2, "masks": _read_r2("masks.bin"),
			"trees": bytes_to_var(_read_r2("trees.bin")), "rocks": bytes_to_var(_read_r2("rocks.bin")),
			"shrubs": bytes_to_var(_read_r2("shrubs.bin")),
			"cover": JSON.parse_string(FileAccess.get_file_as_string(R2_DIR.path_join("cover.json"))),
		}
		print("Island r2 loaded in %d ms (%d trees, %d rocks, %d undergrowth)" % [Time.get_ticks_msec() - t0, (_r2.trees.id as PackedInt32Array).size(), (_r2.rocks.x as PackedFloat32Array).size(), (_r2.shrubs.x as PackedFloat32Array).size()])
	height = _r2.height
	masks = _r2.masks
	trees = _r2.trees
	rocks = _r2.rocks
	shrubs = _r2.shrubs
	cover = _r2.cover
	island_revision = "r2"
	_build_textures()


func _read_r2(fname: String) -> PackedByteArray:
	var f := FileAccess.open_compressed(R2_DIR.path_join(fname + ".zst"), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("Island r2 data missing: run tools/generate_island_r2.gd")
		return PackedByteArray()
	return f.get_buffer(f.get_length())


## Identity of the active island for saves (revision + content hash).
func island_signature() -> Dictionary:
	if island_revision == "r2":
		return {"revision": "r2", "trees": str((r2_manifest.get("content_hashes", {}) as Dictionary).get("trees.bin", ""))}
	return {"revision": "r1", "trees": str((manifest.get("content_hashes", {}) as Dictionary).get("trees.bin", ""))}


## Rock shape helpers (r2 rocks carry explicit squash/stretch).
func rock_squash(i: int) -> float:
	if rocks.has("squash"):
		return float(rocks.squash[i])
	return [0.75, 0.85, 0.55, 0.6][int(rocks.kind[i])]


func rock_stretch(i: int) -> float:
	return float(rocks.stretch[i]) if rocks.has("stretch") else 1.0


## Conservative footprint radius used by navigation and placement checks.
func rock_radius(i: int) -> float:
	return float(rocks.scale[i]) * 0.45 * maxf(rock_stretch(i), 1.0)


func rock_basis(i: int) -> Basis:
	var s: float = rocks.scale[i]
	return Basis(Vector3.UP, rocks.rot[i]).scaled(Vector3(s * rock_stretch(i), s * rock_squash(i), s))


## Grounded trunk base: the lowest terrain under the flared trunk footprint
## minus a small root embed, so the downhill side never floats on slopes.
## Deterministic from the frozen record (x, z, radius); shared by rendering,
## collision, felling and the placement validator.
func tree_position(idx: int) -> Vector3:
	var x: float = trees.x[idx]
	var z: float = trees.z[idx]
	return Vector3(x, grounded_base_y(x, z, float(trees.radius[idx]) * 1.45, 0.12), z)


func grounded_base_y(x: float, z: float, footprint_radius: float, embed: float) -> float:
	var lowest := height_at(x, z)
	for k in 8:
		var a := TAU * k / 8.0
		lowest = minf(lowest, height_at(x + cos(a) * footprint_radius, z + sin(a) * footprint_radius))
	return lowest - embed


## Grounded rock centre height (rock meshes have a flattened base at -0.2
## of their scaled height). Runtime grounding of the frozen rock record.
func rock_position(idx: int) -> Vector3:
	var x: float = rocks.x[idx]
	var z: float = rocks.z[idx]
	var s: float = rocks.scale[idx]
	var squash := rock_squash(idx)
	var base := grounded_base_y(x, z, s * 0.38 * maxf(rock_stretch(idx), 1.0), 0.06 * s)
	return Vector3(x, base + 0.2 * s * squash, z)


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


## Returns a tree to the instanced forest (preview resets / tests only).
signal tree_restored(tree_id: int)
func restore_tree(tree_id: int) -> void:
	if removed_trees.erase(tree_id):
		tree_restored.emit(tree_id)


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
