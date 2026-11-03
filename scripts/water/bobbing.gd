extends Node3D
## Gentle bob for floating props, following the shared wave model.

var _base := Vector3.ZERO
var _phase := 0.0


func _ready() -> void:
	_base = position
	_phase = fmod(position.x * 0.37 + position.z * 0.21, TAU)


func _process(_delta: float) -> void:
	var water: WaterSystem = get_parent() as WaterSystem
	var y := World.sea_level
	if water:
		y = water.ocean_height_at(global_position.x, global_position.z)
	var t := Game.world_time
	position.y = _base.y + (y - World.sea_level) + 0.04 * sin(t * 1.3 + _phase)
	rotation.x = 0.06 * sin(t * 0.9 + _phase)
	rotation.z = 0.05 * sin(t * 1.1 + _phase * 1.7)
