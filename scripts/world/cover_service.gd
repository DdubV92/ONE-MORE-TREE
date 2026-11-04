class_name CoverService
extends Node
## Phase 12: cover classification for island r2 (docs/PHASE12_NOTES.md).
##
##   decorative   grass, ferns, sedge, deadwood: dressing, never blocks.
##   soft         dense woody undergrowth (hazel, bramble, juniper,
##                thickets): bounded visual transmittance along a sight
##                line below the crown height. It never stops bodies or
##                sound, and up close, or when the target moves fast,
##                it stops hiding.
##   hard         terrain, rocks, structures: real colliders; the Foreman's
##                physics ray is blocked by them (no flag involved).
##   hide         authored anchors in rock formations (rock recess / rock
##                gap): reachable entry, crouched pose, verified exit(s).
##                Concealment there is GEOMETRIC: the Foreman sees the
##                hidden eye whenever its ray reaches it (e.g. through the
##                opening); search uses evidence like every other hide.
## No cover kind is a safe zone; nothing here tells the hunter where anyone
## is. Sound: soft cover rustles (a real, hearable event) when pushed
## through quickly; acoustic occlusion is left to Phase 15.

const CELL := 2.0
const SOFT_K := 0.85          # extinction per metre of full-density foliage
const SEEN_T := 0.32          # transmittance above which a still target is seen
const SEEN_T_MOVING := 0.12   # moving targets shake the brush
const NEAR_REVEAL := 4.0      # metres: foliage never hides this close

var _dens := {}               # Vector2i -> float 0..1
var _top := {}                # Vector2i -> crown height above ground (m)
var hides: Array[HideSpot] = []
var _rustle: AudioStream
var _rustle_t := {}           # actor -> seconds until next rustle
var _pool: Array[AudioStreamPlayer3D] = []
var rustles := 0


func build(root: Node3D) -> void:
	if World.shrubs.is_empty():
		return
	_rustle = load("res://audio/generated/tree_rustle.wav")
	_build_grid()
	_build_hides(root)
	for k in 3:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		p.unit_size = 4.0
		p.max_distance = 30.0
		add_child(p)
		_pool.append(p)


func _build_grid() -> void:
	var xs: PackedFloat32Array = World.shrubs.x
	var zs: PackedFloat32Array = World.shrubs.z
	for i in xs.size():
		var k: int = World.shrubs.kind[i]
		if k > 2:
			continue          # bracken, sedge and deadwood are decorative
		var r := UndergrowthSystem.crown_radius(i)
		var h := UndergrowthSystem.crown_height(i)
		var strength: float = [0.8, 0.6, 0.95][k]
		var c0 := Vector2i(int(floor((xs[i] - r) / CELL)), int(floor((zs[i] - r) / CELL)))
		var c1 := Vector2i(int(floor((xs[i] + r) / CELL)), int(floor((zs[i] + r) / CELL)))
		for cx in range(c0.x, c1.x + 1):
			for cz in range(c0.y, c1.y + 1):
				var c := Vector2i(cx, cz)
				var d := Vector2((cx + 0.5) * CELL, (cz + 0.5) * CELL).distance_to(Vector2(xs[i], zs[i]))
				if d > r + CELL * 0.5:
					continue
				_dens[c] = minf(float(_dens.get(c, 0.0)) + strength * clampf(1.0 - d / (r + CELL * 0.5), 0.2, 1.0), 1.0)
				_top[c] = maxf(float(_top.get(c, 0.0)), h)


func _build_hides(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "RockHides"
	root.add_child(holder)
	for h in World.cover.get("hides", []):
		var pos := Vector3(float(h.pos[0]), 0.0, float(h.pos[1]))
		pos.y = World.height_at(pos.x, pos.z)
		var facing := Vector3(float(h.facing[0]), 0.0, float(h.facing[1])).normalized()
		var m := Marker3D.new()
		m.name = "RockHide_%d" % int(h.id)
		holder.add_child(m)
		m.global_position = pos
		m.look_at(pos + facing, Vector3.UP)
		var spot := HideSpot.make(m, str(h.kind), "")
		var exits: Array[Vector3] = []
		for e in h.exits:
			exits.append(Vector3(float(e[0]), World.height_at(float(e[0]), float(e[1])), float(e[1])))
		var ap := Vector3(float(h.approach[0]), 0.0, float(h.approach[1]))
		ap.y = World.height_at(ap.x, ap.z)
		spot.configure_rock(pos, facing, float(h.eye_h), exits, ap, bool(h.dead_end))
		spot.set_meta("cover_id", int(h.id))
		hides.append(spot)


## 0..1 crown density and height of soft cover at a point.
func soft_at(p: Vector3) -> Vector2:
	var c := Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))
	return Vector2(float(_dens.get(c, 0.0)), float(_top.get(c, 0.0)))


## Fraction of light that survives soft cover between two points (1 =
## clear). Only foliage below its crown height along the segment counts.
func transmittance(a: Vector3, b: Vector3) -> float:
	if _dens.is_empty():
		return 1.0
	var d := b - a
	var len := d.length()
	if len < 0.01:
		return 1.0
	var steps := int(ceil(len / 1.0))
	var acc := 0.0
	for s in steps:
		var p := a + d * ((s + 0.5) / steps)
		var c := Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))
		if not _dens.has(c):
			continue
		var ground := World.height_at(p.x, p.z)
		if p.y - ground < float(_top[c]):
			acc += float(_dens[c]) * (len / steps)
	return exp(-SOFT_K * acc)


## The Foreman's soft-cover test (after its hard-cover ray succeeded).
func soft_hides(head: Vector3, target: Vector3, moving_fast: bool) -> bool:
	if head.distance_to(target) < NEAR_REVEAL:
		return false
	var t := transmittance(head, target)
	return t < (SEEN_T_MOVING if moving_fast else SEEN_T)


func classify(p: Vector3) -> String:
	for h in hides:
		if h.global_position.distance_to(p) < 1.0:
			return "hide"
	# Hard: a rock or structure that rises above a crouched person nearby.
	for i in (World.rocks.x as PackedFloat32Array).size():
		var c := Vector2(World.rocks.x[i], World.rocks.z[i])
		if c.distance_to(Vector2(p.x, p.z)) < World.rock_radius(i) + 1.2 and 0.7 * float(World.rocks.scale[i]) * World.rock_squash(i) >= 1.0:
			return "hard"
	var space := get_viewport().get_world_3d().direct_space_state if get_viewport() else null
	if space:
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.6
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, World.height_at(p.x, p.z) + 1.3, p.z))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			return "hard"
	if soft_at(p).x > 0.45:
		return "soft"
	return "open"


func _process(delta: float) -> void:
	if _dens.is_empty():
		return
	var actors: Array = []
	if Game.player:
		actors.append(Game.player)
	if Game.crew:
		for w in Game.crew.workers.values() if Game.crew.workers is Dictionary else Game.crew.workers:
			if w is Node3D:
				actors.append(w)
	for a in actors:
		var n := a as Node3D
		var cd: float = float(_rustle_t.get(n, 0.0)) - delta
		_rustle_t[n] = cd
		if cd > 0.0:
			continue
		var v: Variant = n.get("velocity")
		var spd := (v as Vector3).length() if v is Vector3 else 0.0
		if spd < 1.2:
			continue
		var s := soft_at(n.global_position)
		if s.x < 0.4:
			continue
		_rustle_t[n] = 0.55
		_emit_rustle(n.global_position + Vector3(0, 0.5, 0), -16.0 + spd * 2.5)


func _emit_rustle(pos: Vector3, db: float) -> void:
	rustles += 1
	for p in _pool:
		if not p.playing:
			p.global_position = pos
			p.stream = _rustle
			p.volume_db = db
			p.pitch_scale = randf_range(1.2, 1.5)
			p.play()
			break
	# A real sound in the world: microphones and the hunter can hear it.
	SoundEvents.emit(_rustle, pos, db, "steps", "brush")
