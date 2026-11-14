class_name IslandMap
extends Node
## Phase 28: the boss's map. The company's survey sheet shows the coast of
## the whole island; the inside is blank until it has been walked. What has
## been explored is a coarse grid, revealed around the player and saved
## with the campaign.
##
## The map shows real state only: the terrain as it is, the contract's lot
## trees as they stand or lie, work lamps where they were set down, and
## (in the hunt) the beacon parts once the beacon has been checked. It is
## never a detector: nothing that moves at night is on it.

signal changed()

const CELL := 32.0                  # metres per explored cell
const REVEAL_RADIUS := 70.0         # how far the boss "sees" for the map
const START_RADIUS := 150.0         # known around camp on day 1
const IMG_W := 320                  # base image width in pixels

var cols := 0
var rows := 0
var explored := PackedByteArray()
var _t := 0.0
var _last := Vector3.INF
var _composed: Image                # cached picture (rebuilt when new ground is walked)
var _dirty := true


func _ready() -> void:
	name = "IslandMap"
	_size()


func _size() -> void:
	var ws := World.world_size()
	cols = maxi(int(ceil(ws.x / CELL)), 1)
	rows = maxi(int(ceil(ws.y / CELL)), 1)
	if explored.size() != cols * rows:
		explored.resize(cols * rows)
		explored.fill(0)


func reset() -> void:
	_size()
	explored.fill(0)
	_dirty = true
	reveal(World.camp_origin(), START_RADIUS)
	changed.emit()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var p := Game.player as Node3D
	if p == null:
		return
	if _last != Vector3.INF and _last.distance_to(p.global_position) < 6.0:
		return
	_last = p.global_position
	if reveal(_last, REVEAL_RADIUS) > 0:
		changed.emit()


func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(floor((x - World.origin.x) / CELL)), 0, cols - 1), clampi(int(floor((z - World.origin.y) / CELL)), 0, rows - 1))


## Marks every cell within `radius` of `at`. Returns how many were new.
func reveal(at: Vector3, radius: float) -> int:
	if cols * rows != explored.size():
		_size()
	var n := 0
	var c0 := cell_of(at.x - radius, at.z - radius)
	var c1 := cell_of(at.x + radius, at.z + radius)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var mx := World.origin.x + (cx + 0.5) * CELL
			var mz := World.origin.y + (cy + 0.5) * CELL
			if Vector2(mx - at.x, mz - at.z).length() > radius + CELL * 0.5:
				continue
			var i := cy * cols + cx
			if explored[i] == 0:
				explored[i] = 1
				n += 1
	if n > 0:
		_dirty = true
	return n


func is_explored(x: float, z: float) -> bool:
	var c := cell_of(x, z)
	return explored[c.y * cols + c.x] != 0


func explored_share() -> float:
	var n := 0
	var land := 0
	for cy in rows:
		for cx in cols:
			var mx := World.origin.x + (cx + 0.5) * CELL
			var mz := World.origin.y + (cy + 0.5) * CELL
			if World.water_depth_at(mx, mz) > 0.05:
				continue
			land += 1
			if explored[cy * cols + cx] != 0:
				n += 1
	return float(n) / float(maxi(land, 1))


# ---------------------------------------------------------------- image

const MARGIN := 60.0                # metres of sea kept around the land
const LAND := 0                     # surface classes in the base picture
const SEA := 1

static var _base: Image
static var _base_key := ""
static var _cls := PackedByteArray()    # LAND / SEA per base pixel
static var _bounds := Rect2()           # world XZ rectangle the picture covers


## The world rectangle the map shows: the land, with a margin of sea.
static func bounds() -> Rect2:
	base_image()
	return _bounds


## World position -> point in a rectangle of the given size.
static func to_px(x: float, z: float, size: Vector2) -> Vector2:
	var b := bounds()
	return Vector2((x - b.position.x) / b.size.x * size.x, (z - b.position.y) / b.size.y * size.y)


const C_SEA := Color(0.42, 0.56, 0.62)
const C_SHALLOW := Color(0.55, 0.7, 0.72)
const C_SAND := Color(0.86, 0.8, 0.62)
const C_GRASS := Color(0.62, 0.7, 0.44)
const C_FOREST := Color(0.3, 0.44, 0.28)
const C_ROCK := Color(0.58, 0.57, 0.54)
const C_DIRT := Color(0.66, 0.55, 0.4)
const C_PAPER := Color(0.88, 0.85, 0.76)
const C_PAPER_SEA := Color(0.76, 0.79, 0.76)
const C_COAST := Color(0.3, 0.27, 0.22)


## The terrain as a picture, cropped to the island (built once per island).
static func base_image() -> Image:
	var key := "%s:%s:%d" % [World.island_revision, World.manifest_variant, World.W]
	if _base != null and _base_key == key:
		return _base
	# Where the land is (coarse scan), then the picture over that rectangle.
	var ws := World.world_size()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var step := 12.0
	var z := World.origin.y
	while z <= World.origin.y + ws.y:
		var x := World.origin.x
		while x <= World.origin.x + ws.x:
			if World.water_depth_at(x, z) <= 0.05:
				lo = Vector2(minf(lo.x, x), minf(lo.y, z))
				hi = Vector2(maxf(hi.x, x), maxf(hi.y, z))
			x += step
		z += step
	if lo.x > hi.x:
		lo = World.origin
		hi = World.origin + ws
	lo = (lo - Vector2(MARGIN, MARGIN)).max(World.origin)
	hi = (hi + Vector2(MARGIN, MARGIN)).min(World.origin + ws)
	_bounds = Rect2(lo, hi - lo)
	var h := maxi(int(round(IMG_W * _bounds.size.y / maxf(_bounds.size.x, 1.0))), 8)
	var img := Image.create(IMG_W, h, false, Image.FORMAT_RGB8)
	_cls = PackedByteArray()
	_cls.resize(IMG_W * h)
	for py in h:
		for px in IMG_W:
			var wx := _bounds.position.x + (px + 0.5) / IMG_W * _bounds.size.x
			var wz := _bounds.position.y + (py + 0.5) / h * _bounds.size.y
			var col := C_GRASS
			var cl := LAND
			match World.surface_at(wx, wz):
				World.Surface.WATER:
					col = C_SHALLOW if World.water_depth_at(wx, wz) < 1.2 else C_SEA
					cl = SEA
				World.Surface.SAND:
					col = C_SAND
				World.Surface.ROCK:
					col = C_ROCK
				World.Surface.FOREST:
					col = C_FOREST
				World.Surface.DIRT:
					col = C_DIRT
			img.set_pixel(px, py, col)
			_cls[py * IMG_W + px] = cl
	_base = img
	_base_key = key
	return img


## The map as the boss has it: explored ground in colour, the rest as
## blank survey paper with the coast inked in.
func compose() -> Image:
	if _composed != null and not _dirty:
		return _composed
	var base := base_image()
	var w := base.get_width()
	var h := base.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	for py in h:
		for px in w:
			var wx := _bounds.position.x + (px + 0.5) / w * _bounds.size.x
			var wz := _bounds.position.y + (py + 0.5) / h * _bounds.size.y
			if is_explored(wx, wz):
				out.set_pixel(px, py, base.get_pixel(px, py))
				continue
			var sea := _cls[py * w + px] == SEA
			# Unexplored: paper, with the shoreline drawn where land meets sea.
			var edge := false
			if not sea:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qx := clampi(px + d.x, 0, w - 1)
					var qy := clampi(py + d.y, 0, h - 1)
					if _cls[qy * w + qx] == SEA:
						edge = true
						break
			out.set_pixel(px, py, C_COAST if edge else (C_PAPER_SEA if sea else C_PAPER))
	_composed = out
	_dirty = false
	return out


# ----------------------------------------------------------------- save

func capture() -> Dictionary:
	return {"version": 1, "cols": cols, "rows": rows, "cells": Marshalls.raw_to_base64(explored)}


func restore(d: Dictionary) -> void:
	_size()
	explored.fill(0)
	if int(d.get("cols", 0)) == cols and int(d.get("rows", 0)) == rows:
		var raw := Marshalls.base64_to_raw(str(d.get("cells", "")))
		if raw.size() == explored.size():
			explored = raw
	if explored.count(1) == 0:
		reveal(World.camp_origin(), START_RADIUS)
	_dirty = true
	changed.emit()
