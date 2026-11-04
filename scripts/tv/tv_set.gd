class_name TVSet
extends Node
## Phase 11: the camper TV is entertainment only (surveillance moved to the
## desk computer). It shows the original procedural channel in its own
## small viewport that only renders while powered and someone is nearby,
## and plays its music from the TV itself (bus "TV"). No cameras here.

const SIZE := Vector2i(640, 360)
const RANGE := 9.0

var tv: Node3D
var screen: MeshInstance3D
var vp: SubViewport
var program: TVProgram
var music: AudioStreamPlayer3D
var mat: ShaderMaterial
var powered := false
var volume := 0.7
var _active := false
## Capture tools have no player: render as if someone were nearby.
var force_active := false


func setup() -> void:
	var root := get_parent()
	var tvs := get_tree().get_nodes_in_group("camper_tv").filter(func(n: Node) -> bool: return root == null or root.is_ancestor_of(n))
	if tvs.is_empty():
		return
	tv = tvs[0]
	screen = tv.get_node("Screen")
	screen.layers = 1 << (CameraWall.LAYER_TV - 1)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	program = TVProgram.new()
	program.size = Vector2(SIZE)
	vp.add_child(program)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/tv_screen.gdshader")
	mat.set_shader_parameter("feed", vp.get_texture())
	mat.set_shader_parameter("gain", 0.55)
	mat.set_shader_parameter("powered", 0.0)
	screen.material_override = mat
	music = AudioStreamPlayer3D.new()
	music.bus = "TV"
	music.unit_size = 3.0
	music.stream = TVProgram.make_music()
	tv.add_child(music)


func set_power(on: bool) -> void:
	powered = on
	if mat:
		mat.set_shader_parameter("powered", 1.0 if on else 0.0)
	_active = false


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)


func _process(_delta: float) -> void:
	if tv == null:
		return
	var p := Game.player
	var near := force_active or (p != null and p.global_position.distance_to(tv.global_position) < RANGE)
	var on := powered and near and not get_tree().paused
	if on != _active:
		_active = on
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		program.playing = on
		if on and music.stream:
			music.play()
		else:
			music.stop()
	if music.playing:
		music.volume_db = -14.0 + linear_to_db(maxf(volume, 0.001))


func capture() -> Dictionary:
	return {"powered": powered, "volume": volume}


func restore(d: Dictionary) -> void:
	set_power(bool(d.get("powered", false)))
	set_volume(float(d.get("volume", 0.7)))
