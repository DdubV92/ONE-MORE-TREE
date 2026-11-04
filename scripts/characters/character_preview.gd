extends Node3D
## Standalone character review scene: one human and the dog with idle/walk
## demos, the axe-swing preview, lie/sleep, orbit/zoom camera, playback
## speed, joint/foot-contact debug and the four worker looks. Lives outside
## the campaign: it never touches saves or simulation state.

var human: HumanCharacter
var dog: DogCharacter
var cam: Camera3D
var env: EnvironmentController
var _yaw := PI + 0.55
var _pitch := 0.22
var _dist := 4.2
var _focus := Vector3(0, 0.9, 0)
var _dragging := false
var _speed := 1.0
var _human_circle := false
var _dog_circle := false
var _human_angle := 0.0
var _dog_angle := 0.0
var _appearance_i := 0
## Phase 11: the five standard employees (authored, by persistent ID).
var _looks: Array[HumanAppearance] = [HumanAppearance.for_employee("EMP-01", 1), HumanAppearance.for_employee("EMP-02", 2), HumanAppearance.for_employee("EMP-03", 3), HumanAppearance.for_employee("EMP-04", 4), HumanAppearance.for_employee("EMP-05", 5)]
var _show_joints := false
var _joint_marks: Array[MeshInstance3D] = []
var _info: Label
var _contact: ImmediateMesh
var _contact_mi: MeshInstance3D


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	env = EnvironmentController.new()
	add_child(env)
	env.build()
	env.apply_named("day")
	_build_stage()
	human = HumanCharacter.new()
	human.appearance = _looks[0]
	human.position = Vector3(-0.9, 0, 0)
	human.rotation.y = PI * 0.15
	add_child(human)
	dog = DogCharacter.new()
	dog.position = Vector3(1.0, 0, 0.2)
	dog.rotation.y = -PI * 0.3
	add_child(dog)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.02
	add_child(cam)
	cam.make_current()
	_contact = ImmediateMesh.new()
	_contact_mi = MeshInstance3D.new()
	_contact_mi.mesh = _contact
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.vertex_color_use_as_albedo = true
	cm.no_depth_test = true
	_contact_mi.material_override = cm
	add_child(_contact_mi)
	_build_ui()
	_update_camera()


var foreman: ForemanBody
var _turn := false


func _show_foreman(pose: String) -> void:
	if foreman == null:
		foreman = ForemanBody.new()
		foreman.position = Vector3(0, 0, -2.2)
		add_child(foreman)
		_dist = 7.0
		_focus = Vector3(0, 1.5, -1.0)
	foreman.pose = pose
	foreman.speed = 1.7 if pose == "walk" else (6.5 if pose == "sprint" else 0.0)
	_turn = true


func _process_turntable(delta: float) -> void:
	if foreman and _turn:
		foreman.rotation.y += delta * 0.35


func _build_stage() -> void:
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/preview_floor.gdshader")
	floor_mi.material_override = sm
	add_child(floor_mi)
	# Scale references: 2.0 m door frame and 1 m posts.
	BuildKit.box(self, Vector3(0.1, 2.0, 0.1), Vector3(-3.0, 1.0, -1.5), "dark_wood", false)
	BuildKit.box(self, Vector3(0.1, 2.0, 0.1), Vector3(-2.1, 1.0, -1.5), "dark_wood", false)
	BuildKit.box(self, Vector3(1.0, 0.1, 0.1), Vector3(-2.55, 2.05, -1.5), "dark_wood", false)
	BuildKit.box(self, Vector3(0.06, 1.0, 0.06), Vector3(2.6, 0.5, -1.5), "camper_stripe", false)
	BuildKit.prop(self, "tree_stump_01", Vector3(-1.9, 0, -1.0), 0.0, 0.7)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = UITheme.get_theme()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UITheme.label("Character Preview", 24, UITheme.ACCENT))
	v.add_child(UITheme.label("Human", 18, UITheme.MUTED))
	var h1 := HBoxContainer.new()
	h1.add_child(UITheme.button("Idle", func() -> void: _human_circle = false; human.set_locomotion(0.0), 80))
	h1.add_child(UITheme.button("Walk", func() -> void: _human_circle = false; human.play("walk"); human.playback_scale = _speed, 80))
	h1.add_child(UITheme.button("Axe swing", func() -> void: _human_circle = false; human.play("swing"), 120))
	v.add_child(h1)
	var h1b := HBoxContainer.new()
	h1b.add_child(UITheme.button("Walk a circle", func() -> void: _human_circle = true, 140))
	h1b.add_child(UITheme.button("Next look", _next_look, 140))
	v.add_child(h1b)
	v.add_child(UITheme.label("Dog", 18, UITheme.MUTED))
	var h2 := HBoxContainer.new()
	h2.add_child(UITheme.button("Idle", func() -> void: _dog_circle = false; dog.play("idle"), 80))
	h2.add_child(UITheme.button("Walk", func() -> void: _dog_circle = false; dog.play("walk"); dog.playback_scale = _speed, 80))
	h2.add_child(UITheme.button("Lie & sleep", func() -> void: _dog_circle = false; dog.play("lie"), 120))
	v.add_child(h2)
	v.add_child(UITheme.button("Dog: walk a circle", func() -> void: _dog_circle = true, 288))
	var h2b := HBoxContainer.new()
	for c in ["trot", "sit", "alert", "pet"]:
		h2b.add_child(UITheme.button(c.capitalize(), func() -> void: _dog_circle = false; dog.play(c), 66))
	v.add_child(h2b)
	# Phase 6 development turntable: the Foreman (dev review only).
	v.add_child(UITheme.label("The Foreman (Phase 6 dev turntable)", 18, UITheme.MUTED))
	var h3 := HBoxContainer.new()
	for fp in ["idle", "walk", "sprint", "listen", "search", "fold", "reach"]:
		h3.add_child(UITheme.button(fp.capitalize(), func() -> void: _show_foreman(fp), 54))
	v.add_child(h3)
	var sp := HBoxContainer.new()
	sp.add_child(UITheme.label("Speed", 16))
	var sl := HSlider.new()
	sl.min_value = 0.25
	sl.max_value = 1.75
	sl.step = 0.05
	sl.value = 1.0
	sl.custom_minimum_size = Vector2(200, 24)
	sl.value_changed.connect(func(x: float) -> void:
		_speed = x
		if not _human_circle:
			human.playback_scale = x
		if not _dog_circle:
			dog.playback_scale = x)
	sp.add_child(sl)
	v.add_child(sp)
	var lt := HBoxContainer.new()
	for p in ["day", "sunset", "night"]:
		lt.add_child(UITheme.button(p.capitalize(), func() -> void: env.apply_named(p), 92))
	v.add_child(lt)
	var dbg := CheckButton.new()
	dbg.text = "Show joints & foot contact"
	dbg.toggled.connect(func(on: bool) -> void: _show_joints = on)
	v.add_child(dbg)
	v.add_child(UITheme.button("Back to title", func() -> void: Game.return_to_menu(), 288))
	_info = UITheme.label("", 15, UITheme.MUTED)
	_info.position = Vector2(12, 0)
	_info.anchor_top = 1.0
	_info.offset_top = -86
	layer.add_child(_info)
	var help := UITheme.label("Drag (left or right mouse) to orbit, wheel to zoom, middle-drag to pan.", 15, UITheme.TEXT)
	help.anchor_left = 1.0
	help.position = Vector2(-560, 14)
	layer.add_child(help)


func _next_look() -> void:
	_appearance_i = (_appearance_i + 1) % _looks.size()
	var pos := human.position
	var rot := human.rotation
	human.queue_free()
	human = HumanCharacter.new()
	human.appearance = _looks[_appearance_i]
	human.position = pos
	human.rotation = rot
	add_child(human)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 15.0)
		_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_focus += (-cam.global_basis.x * event.relative.x + cam.global_basis.y * event.relative.y) * 0.003 * _dist
		else:
			_yaw -= event.relative.x * 0.008
			_pitch = clampf(_pitch + event.relative.y * 0.006, -0.3, 1.4)
		_update_camera()
	elif event.is_action_pressed("pause"):
		Game.return_to_menu()


func _update_camera() -> void:
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	cam.global_position = _focus + off
	cam.look_at(_focus)


func _process(delta: float) -> void:
	_process_turntable(delta)
	if _human_circle:
		_human_angle += delta * HumanCharacter.WALK_NOMINAL_SPEED * _speed / 1.6
		human.position = Vector3(-0.9 + cos(_human_angle) * 1.6, 0, sin(_human_angle) * 1.6)
		human.rotation.y = -_human_angle
		human.set_locomotion(HumanCharacter.WALK_NOMINAL_SPEED * _speed)
	if _dog_circle:
		_dog_angle += delta * DogCharacter.WALK_NOMINAL_SPEED * _speed / 1.2
		dog.position = Vector3(1.0 + cos(_dog_angle) * 1.2, 0, sin(_dog_angle) * 1.2)
		dog.rotation.y = -_dog_angle
		dog.set_locomotion(DogCharacter.WALK_NOMINAL_SPEED * _speed)
	_draw_debug()
	_info.text = "Human: %s  |  clip %s  |  height %.2f m\nDog: clip %s  |  speed x%.2f  |  FPS %d\nRigid-part articulated rigs (no skinning). In-place clips; mover speed = nominal x playback scale." % [human.appearance.label, human.current, human.H, dog.current, _speed, Engine.get_frames_per_second()]


func _draw_debug() -> void:
	_contact.clear_surfaces()
	if not _show_joints:
		return
	_contact.surface_begin(Mesh.PRIMITIVE_LINES)
	for c in [human, dog]:
		for b in c.bones.values():
			var n: Node3D = b
			if n.get_parent() is Node3D and c.bones.values().has(n.get_parent()):
				_contact.surface_set_color(Color(1, 0.8, 0.2))
				_contact.surface_add_vertex((n.get_parent() as Node3D).global_position)
				_contact.surface_add_vertex(n.global_position)
	# Ground contact: green when an ankle/paw is within 2.5 cm of its rest height.
	var feet: Array = human.ankle_positions()
	for p in feet:
		var ok := absf((p as Vector3).y - human.ankle_h - human.global_position.y) < 0.025
		_contact.surface_set_color(Color(0.2, 1, 0.3) if ok else Color(1, 0.3, 0.2))
		_contact.surface_add_vertex(Vector3(p.x, 0.005, p.z) + Vector3(-0.08, 0, 0))
		_contact.surface_add_vertex(Vector3(p.x, 0.005, p.z) + Vector3(0.08, 0, 0))
	for p in dog.paw_positions():
		var ok := absf((p as Vector3).y - dog.paw_h) < 0.025
		_contact.surface_set_color(Color(0.2, 1, 0.3) if ok else Color(1, 0.3, 0.2))
		_contact.surface_add_vertex(Vector3(p.x, 0.005, p.z) + Vector3(-0.05, 0, 0))
		_contact.surface_add_vertex(Vector3(p.x, 0.005, p.z) + Vector3(0.05, 0, 0))
	_contact.surface_end()
