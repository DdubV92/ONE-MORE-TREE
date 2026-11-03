class_name AxeController
extends Node
## Owns the player's axe: equipped tier, swing state machine, input
## ownership, and contact-timed hit validation. Damage never lands on
## button-down; it lands at the contact moment of the animation. Clicking
## faster than the cycle cannot bypass the cooldown (one buffered press).
## Hold-to-chop repeats at exactly the same legal cadence.

signal target_changed(info: Dictionary)
signal hit_result(kind: String, info: Dictionary)

const REACH := 2.05             # camera to strike point (m)

var player: Player
var view: ViewModel
var config: TreeWorkConfig
var tier := "small"
var swinging := false
var _u := 0.0                   # swing phase 0..1
var _contact_done := false
var _buffered := false
var _cycle := 0.95
var target_tree := -1
var _target_info := {}
var _walk_bob := 0.0


func setup(p: Player) -> void:
	player = p
	config = load("res://config/tree_work.tres")
	view = ViewModel.new()
	view.name = "ViewModel"
	player.camera.add_child(view)
	equip("small")


func equip(t: String) -> void:
	if swinging:
		return
	tier = t if config.tier_rates.has(t) else "small"
	_cycle = float(config.tier_cycle[tier])
	view.equip(tier)
	view.pose_at(0.0)


func input_allowed() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player.get_tree().paused and not player.fly_mode


func try_swing() -> void:
	if not input_allowed():
		return
	if swinging:
		_buffered = true      # at most one queued swing
		return
	swinging = true
	_u = 0.0
	_contact_done = false


func _physics_process_step(delta: float) -> void:
	# Called from Player._physics_process (fixed step): frame-rate independent.
	_update_target()
	var want_hold: bool = Settings.get_v("hold_to_chop") and Input.is_action_pressed("attack") and input_allowed()
	if not swinging and (want_hold or _buffered):
		_buffered = false
		try_swing()
	if advance_swing(delta):
		_contact()


## Advances the swing clock; returns true exactly once per swing, at the
## contact moment. Pure timing (no input/physics), shared with tests.
func advance_swing(delta: float) -> bool:
	if not swinging:
		return false
	var hit := false
	_u += delta / _cycle
	if not _contact_done and _u >= config.contact_fraction:
		_contact_done = true
		hit = true
	if _u >= 1.0:
		swinging = false
		_u = 0.0
	return hit


## Test hook: start a swing without input (same cadence rules).
func begin_swing_for_test() -> void:
	if not swinging:
		swinging = true
		_u = 0.0
		_contact_done = false


func _process_visual(delta: float, speed: float) -> void:
	if speed > 0.5 and not swinging:
		_walk_bob += delta * speed * 1.6
	view.pose_at(_u if swinging else 0.0, _walk_bob)


## The single arbitration query for the axe: the first thing along the view
## ray within reach decides the outcome (fence, another trunk, rock or
## building in front of a tree means that tree is not strikeable).
func probe() -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"kind": "miss"}
	var id := VegetationSystem.tree_id_from_hit(hit.collider, hit.shape)
	if id >= 0:
		var svc: TreeService = Game.trees
		var st := svc.state_of(id) if svc else 0
		if st == TreeService.State.STANDING or st == TreeService.State.NOTCHED:
			return {"kind": "tree", "id": id, "point": hit.position, "normal": hit.normal}
		return {"kind": "hard", "point": hit.position, "normal": hit.normal}
	if hit.collider and (hit.collider as Node).has_meta("fallen_tree"):
		return {"kind": "timber", "point": hit.position, "normal": hit.normal}
	return {"kind": "hard", "point": hit.position, "normal": hit.normal}


func _update_target() -> void:
	var p := probe()
	var id: int = p.get("id", -1) if p.kind == "tree" else -1
	if id != target_tree:
		target_tree = id
		_target_info = _describe(id)
		target_changed.emit(_target_info)
	elif id >= 0 and Game.trees:
		var pr := Game.trees.progress(id)
		if absf(pr - float(_target_info.get("progress", 0.0))) > 0.001:
			_target_info = _describe(id)
			target_changed.emit(_target_info)


func _describe(id: int) -> Dictionary:
	if id < 0:
		return {}
	var i: int = Game.vegetation.tree_index_by_id.get(id, id)
	const NAMES := ["Pine", "Spruce", "Birch"]
	var info := {
		"id": id,
		"species": NAMES[int(World.trees.species[i])],
		"diameter": float(World.trees.radius[i]) * 2.0,
		"progress": Game.trees.progress(id) if Game.trees else 0.0,
		"tier": tier,
	}
	if Game.trees and Game.trees.records.has(id):
		var fd: Array = Game.trees.records[id].fall_dir
		info["fall_dir"] = Vector3(fd[0], 0, fd[1])
	return info


func _contact() -> void:
	var p := probe()
	match p.kind:
		"tree":
			var work := config.work_per_contact(tier)
			var res: Dictionary = Game.trees.apply_contact(p.id, player.global_position, work)
			var bark := Color(0.35, 0.25, 0.18) if int(World.trees.species[Game.vegetation.tree_index_by_id.get(p.id, p.id)]) != 2 else Color(0.85, 0.83, 0.78)
			LoggingFX.chips(p.point, p.normal, bark)
			LoggingFX.play(LoggingFX.Sound.CHOP, p.point)
			if Settings.get_v("camera_shake"):
				player.add_shake(0.012 if tier == "small" else 0.018)
			hit_result.emit("tree", res)
			_target_info = _describe(p.id)
			target_changed.emit(_target_info)
		"timber", "hard":
			LoggingFX.play(LoggingFX.Sound.CLUNK, p.point)
			if Settings.get_v("camera_shake"):
				player.add_shake(0.02)
			hit_result.emit("hard", {})
		_:
			LoggingFX.play(LoggingFX.Sound.MISS, player.camera.global_position - player.camera.global_basis.z * 0.6)
			hit_result.emit("miss", {})
