class_name TreeService
extends Node
## Authoritative per-tree state for MODIFIED original trees (unmodified trees
## are fully described by the frozen manifest). Owns legal transitions, the
## work/notch model, the single TreeFelled emission, and the handoff between
## the instanced forest and one active TreeActor per modified tree.
##
## States: STANDING -> NOTCHED -> FALLING -> FALLEN -> (SECTIONED -> DISPOSED,
## reserved for Phase 2/3; never set here).

enum State { STANDING, NOTCHED, FALLING, FALLEN, SECTIONED, DISPOSED }

signal tree_notched(tree_id: int)
## Emitted exactly once per original tree when felling commits (release).
## Work/progress hook only: NOT a payment. Payment comes from accepted log
## shares in Phase 2/3.
signal tree_felled(tree_id: int)
signal tree_settled(tree_id: int, reason: String)
signal tree_warning(tree_id: int)

const LEGAL := {
	State.STANDING: [State.NOTCHED],
	State.NOTCHED: [State.FALLING],
	State.FALLING: [State.FALLEN],
	State.FALLEN: [State.SECTIONED],
	State.SECTIONED: [State.DISPOSED],
	State.DISPOSED: [],
}

var config: TreeWorkConfig
var records := {}          # tree id -> Dictionary (see _new_record)
var actors := {}           # tree id -> TreeActor
var felled_log: Array[int] = []    # ids in the order TreeFelled fired (this session)
var persistent := true     # false in Preview: nothing is saved
var actor_parent: Node3D


func _ready() -> void:
	config = load("res://config/tree_work.tres")


func setup(parent: Node3D, is_persistent: bool) -> void:
	actor_parent = parent
	persistent = is_persistent


static func _new_record(id: int) -> Dictionary:
	return {
		"id": id,
		"state": State.STANDING,
		"work": 0.0,
		"required": 0.0,
		"cut_height": 0.75,
		"cut_dir": [0.0, 0.0],       # unit XZ from trunk centre toward the notched face
		"fall_dir": [0.0, 0.0],      # unit XZ, intended fall direction
		"felled_committed": false,   # TreeFelled already emitted (persisted guard)
		"pose": [],                  # 12 floats: basis + origin (falling/fallen trunk)
		"lin_vel": [0.0, 0.0, 0.0],
		"ang_vel": [0.0, 0.0, 0.0],
		"settle_reason": "",
		"hits": 0,
	}


func index_of(id: int) -> int:
	return Game.vegetation.tree_index_by_id.get(id, -1) if Game.vegetation else id


func state_of(id: int) -> int:
	return int(records[id].state) if records.has(id) else State.STANDING


func record(id: int) -> Dictionary:
	if not records.has(id):
		var r := _new_record(id)
		var i := index_of(id)
		r.required = config.required_units(int(World.trees.species[i]), float(World.trees.radius[i]))
		r.cut_height = config.cut_height
		records[id] = r
	return records[id]


func progress(id: int) -> float:
	if not records.has(id):
		return 0.0
	var r: Dictionary = records[id]
	return clampf(float(r.work) / maxf(float(r.required), 0.001), 0.0, 1.0)


func _transition(id: int, to: int) -> bool:
	var r := record(id)
	var from: int = r.state
	if not (to in LEGAL[from]):
		push_warning("TreeService: illegal transition %d -> %d for tree %d" % [from, to, id])
		return false
	r.state = to
	return true


## One valid axe contact. `from_pos` is where the chopper stands (world).
## Returns {"accepted", "progress", "felled"}.
func apply_contact(id: int, from_pos: Vector3, work: float) -> Dictionary:
	var r := record(id)
	var st: int = r.state
	if st != State.STANDING and st != State.NOTCHED:
		return {"accepted": false, "progress": progress(id), "felled": false}
	var i := index_of(id)
	var base := World.tree_position(i)
	if st == State.STANDING:
		# The first contact fixes the cut side; the tree falls away from it,
		# blended toward its natural lean (bounded).
		var away := Vector2(base.x - from_pos.x, base.z - from_pos.z)
		away = away.normalized() if away.length() > 0.01 else Vector2(0, 1)
		var lean := Vector2(float(World.trees.lean_x[i]), float(World.trees.lean_z[i]))
		var fall := away
		if lean.length() > 0.001:
			var lean_dir := lean.normalized()
			var ang := clampf(away.angle_to(lean_dir), -deg_to_rad(config.max_lean_deg), deg_to_rad(config.max_lean_deg))
			fall = away.rotated(ang * clampf(lean.length() / deg_to_rad(4.0), 0.0, 1.0) * 0.6)
		r.cut_dir = [-away.x, -away.y]
		r.fall_dir = [fall.x, fall.y]
		_transition(id, State.NOTCHED)
		_ensure_actor(id)
		tree_notched.emit(id)
	r.work = float(r.work) + work
	r.hits = int(r.hits) + 1
	var p := progress(id)
	if actors.has(id):
		(actors[id] as TreeActor).set_notch(p)
	if p >= 0.86 and p - work / maxf(float(r.required), 0.001) < 0.86:
		tree_warning.emit(id)
	if p >= 1.0:
		_commit_fell(id)
		return {"accepted": true, "progress": 1.0, "felled": true}
	return {"accepted": true, "progress": p, "felled": false}


func _commit_fell(id: int) -> void:
	var r := record(id)
	if not _transition(id, State.FALLING):
		return
	if not bool(r.felled_committed):
		r.felled_committed = true
		felled_log.append(id)
		tree_felled.emit(id)
	(actors[id] as TreeActor).start_fall()


## Called by TreeActor when its trunk has come to rest (or was corrected).
func on_actor_settled(id: int, pose: Transform3D, reason: String) -> void:
	var r := record(id)
	r.pose = _xf_to_array(pose)
	r.lin_vel = [0.0, 0.0, 0.0]
	r.ang_vel = [0.0, 0.0, 0.0]
	r.settle_reason = reason
	if int(r.state) == State.FALLING:
		_transition(id, State.FALLEN)
	tree_settled.emit(id, reason)


func on_actor_motion(id: int, pose: Transform3D, lin: Vector3, ang: Vector3) -> void:
	var r := record(id)
	r.pose = _xf_to_array(pose)
	r.lin_vel = [lin.x, lin.y, lin.z]
	r.ang_vel = [ang.x, ang.y, ang.z]


func _ensure_actor(id: int) -> TreeActor:
	if actors.has(id):
		return actors[id]
	# Hand the tree from the instanced forest to exactly one actor.
	World.remove_tree(id)
	var a := TreeActor.new()
	a.name = "TreeActor_%d" % id
	actor_parent.add_child(a)
	a.setup(self, id, index_of(id))
	actors[id] = a
	return a


func active_count() -> int:
	return actors.size()


# ------------------------------------------------------------ persistence

static func _xf_to_array(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


static func array_to_xf(a: Array) -> Transform3D:
	if a.size() != 12:
		return Transform3D()
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])).orthonormalized(), Vector3(a[9], a[10], a[11]))


func capture() -> Dictionary:
	var out := {}
	for id in records:
		var r: Dictionary = records[id]
		if actors.has(id) and int(r.state) == State.FALLING:
			(actors[id] as TreeActor).report_motion()
		out[str(id)] = r.duplicate(true)
	return out


## Restores modified trees. Policy for a save taken mid-fall: the trunk is
## re-created as a physics body at its saved pose with its saved velocity
## (not re-felled, never duplicated, TreeFelled is not re-emitted).
func restore(data: Dictionary) -> void:
	for key in data:
		var src: Dictionary = data[key]
		var id := int(key)
		if index_of(id) < 0:
			push_warning("TreeService: save references unknown tree %d (ignored)" % id)
			continue
		var r := _new_record(id)
		for k in r:
			if src.has(k):
				r[k] = src[k]
		r.state = clampi(int(r.state), State.STANDING, State.DISPOSED)
		r.felled_committed = bool(r.felled_committed) or int(r.state) >= State.FALLING
		records[id] = r
		if int(r.state) == State.STANDING:
			continue
		var a := _ensure_actor(id)
		match int(r.state):
			State.NOTCHED:
				a.set_notch(progress(id))
			State.FALLING:
				a.restore_falling(array_to_xf(r.pose), _v(r.lin_vel), _v(r.ang_vel))
			_:
				a.restore_fallen(array_to_xf(r.pose))


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2]) if a.size() == 3 else Vector3.ZERO


func clear_all() -> void:
	for id in actors:
		(actors[id] as Node).queue_free()
		World.restore_tree(id)
	actors.clear()
	records.clear()
	felled_log.clear()
