class_name CampDog
extends Node3D
## The player's dog: wanders the camp clearing by day (idle/walk with stride
## matched to speed), heads to the camper door at dusk and sleeps on its bed
## inside at night. It has no health, cannot be harmed, cannot leave camp and
## is restored to its bed or the yard on any state change, so it can never be
## lost. Phase 0 behaviour only; petting/following arrive in later prompts.

enum State { WANDER, PAUSE, GO_HOME, SLEEP }

var dog: DogCharacter
var state := State.PAUSE
var _target := Vector3.ZERO
var _timer := 1.0
var _rng := RandomNumberGenerator.new()
var _speed := 0.0
var _points: Array[Vector3] = []


func _ready() -> void:
	_rng.seed = 314
	dog = DogCharacter.new()
	add_child(dog)
	var c := CampLayout
	for p in [Vector3(-4, 0, 3), Vector3(4, 0, 2), Vector3(-6, 0, -9), Vector3(6, 0, -10), Vector3(-1, 0, 13), Vector3(5, 0, 14), Vector3(-9, 0, 12), Vector3(9, 0, -5), Vector3(-10, 0, -2), Vector3(0, 0, -13)]:
		_points.append(c.world(p))
	global_position = _points[0]


func _process(delta: float) -> void:
	var night: bool = Game.environment != null and (Game.environment.hour >= 19.6 or Game.environment.hour < 6.0)
	if night and state != State.GO_HOME and state != State.SLEEP:
		state = State.GO_HOME
		_target = CampLayout.world(CampLayout.CAMPER_POS + Vector3(2.4, 0, 1.85))
	elif not night and state == State.SLEEP:
		global_position = CampLayout.world(CampLayout.CAMPER_POS + Vector3(2.6, 0, 1.6))
		state = State.PAUSE
		_timer = 1.0
	match state:
		State.PAUSE:
			_speed = move_toward(_speed, 0.0, delta * 3.0)
			_timer -= delta
			if _timer <= 0.0:
				_target = _points[_rng.randi() % _points.size()]
				state = State.WANDER
		State.WANDER, State.GO_HOME:
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.4:
				if state == State.GO_HOME:
					_go_to_bed()
					return
				state = State.PAUSE
				_timer = _rng.randf_range(2.0, 7.0)
			else:
				_speed = move_toward(_speed, DogCharacter.WALK_NOMINAL_SPEED * (1.25 if state == State.GO_HOME else 1.0), delta * 2.0)
				var dir := to.normalized()
				global_position += dir * _speed * delta
				global_position.y = World.height_at(global_position.x, global_position.z)
				var want := atan2(-dir.x, -dir.z)
				rotation.y = lerp_angle(rotation.y, want, clampf(delta * 5.0, 0.0, 1.0))
		State.SLEEP:
			_speed = 0.0
	if state != State.SLEEP:
		dog.set_locomotion(_speed)


func _go_to_bed() -> void:
	var beds := get_tree().get_nodes_in_group("dog_bed")
	if beds.size() > 0:
		var b: Node3D = beds[0]
		global_position = b.global_position - Vector3(0, 0.08, 0)
		rotation.y = 0.6
	state = State.SLEEP
	dog.play("lie", 1.2)
