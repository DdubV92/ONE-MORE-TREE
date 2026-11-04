class_name ReviewSubject
extends Node3D
## Preview-only harmless moving subject that proves the camera feeds are
## live: a surveyor in a hi-vis vest walking a fixed loop past the forest
## entrance (CAM-03), the north fence corners and the camp yard, with real
## footstep sounds the camera microphones can pick up. Deterministic (the
## loop is a function of world time). Never exists in a campaign.

var hc: HumanCharacter
var loop: Array[Vector3] = []
var _len := 0.0
var _step_t := 0.0
var _steps: Array[AudioStream] = []
var _player: AudioStreamPlayer3D
const SPEED := 1.25


func _ready() -> void:
	if not Game.is_preview():
		queue_free()
		return
	var a := HumanAppearance.new()
	a.label = "Review surveyor"
	a.jacket = Color(0.95, 0.75, 0.1)
	a.hair_style = 1
	hc = HumanCharacter.new()
	hc.appearance = a
	add_child(hc)
	for c in [Vector3(-6, 0, -22), Vector3(6, 0, -22), Vector3(6, 0, -12), Vector3(0, 0, -8), Vector3(-6, 0, -12)]:
		var p := CampLayout.world(c)
		p.y = World.height_at(p.x, p.z)
		loop.append(p)
	for i in loop.size():
		_len += loop[i].distance_to(loop[(i + 1) % loop.size()])
	for v in 5:
		_steps.append(load("res://audio/generated/step_dirt_%d.wav" % v))
	_player = AudioStreamPlayer3D.new()
	_player.bus = "Characters"
	_player.unit_size = 3.0
	add_child(_player)


func _process(delta: float) -> void:
	if loop.is_empty():
		return
	var d := fposmod(Game.world_time * SPEED, _len)
	for i in loop.size():
		var a := loop[i]
		var b := loop[(i + 1) % loop.size()]
		var seg := a.distance_to(b)
		if d <= seg:
			var p := a.lerp(b, d / seg)
			var n := Game.crew.nav if Game.crew and Game.crew.nav and Game.crew.nav.built else null
			p.y = n.surface_at(p) if n else World.height_at(p.x, p.z)
			global_position = p
			var dir := (b - a).normalized()
			rotation.y = atan2(-dir.x, -dir.z)
			break
		d -= seg
	hc.set_locomotion(SPEED)
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.55
		var s := _steps[int(Game.world_time * 7.0) % _steps.size()]
		_player.stream = s
		_player.volume_db = -14.0
		_player.play()
		SoundEvents.emit(s, global_position, -4.0, "steps_other", "footsteps")
