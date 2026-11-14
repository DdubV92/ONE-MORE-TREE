class_name LampLocker
extends StaticBody3D
## Phase 26: where the company's work lamps wait (beside the parcel
## locker). E takes one, or puts the one in hand back.

var kit: NightKit
var _sign: Label3D
var _slots: Node3D


func setup(k: NightKit, at: Vector3) -> void:
	kit = k
	name = "LampLocker"
	position = at
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.78, 0.6, 0.12)
	paint.roughness = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.09, 0.09)
	dark.roughness = 0.7
	BuildKit.box(self, Vector3(1.5, 1.85, 0.62), Vector3(0, 0.95, 0), paint, false, 0.0, "Cabinet")
	BuildKit.box(self, Vector3(1.6, 0.08, 0.7), Vector3(0, 1.91, 0), BuildKit.mat("steel"), false, 0.0, "Roof")
	# An open rack front (facing -Z, into camp) with the lamps standing in it.
	BuildKit.box(self, Vector3(1.36, 1.6, 0.02), Vector3(0, 0.95, -0.3), dark, false, 0.0, "Back")
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.6, 1.95, 0.7)
	cs.shape = bx
	cs.position = Vector3(0, 0.97, 0)
	add_child(cs)
	_sign = Label3D.new()
	_sign.double_sided = false       # from behind it read mirrored
	_sign.text = "WORK LAMPS"
	_sign.font_size = 40
	_sign.pixel_size = 0.004
	_sign.position = Vector3(0, 2.1, -0.36)
	_sign.rotation.y = PI
	_sign.modulate = Color(0.95, 0.9, 0.75)
	add_child(_sign)
	_slots = Node3D.new()
	_slots.name = "Lamps"
	add_child(_slots)
	kit.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for c in _slots.get_children():
		c.queue_free()
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.95, 0.8, 0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.11)
	for i in mini(kit.stock, NightKit.MAX_LAMPS):
		var x := -0.55 + 0.22 * i
		var mast := MeshInstance3D.new()
		var mm := CylinderMesh.new()
		mm.top_radius = 0.02
		mm.bottom_radius = 0.02
		mm.height = 1.3
		mast.mesh = mm
		mast.material_override = dark
		mast.position = Vector3(x, 0.8, -0.36)
		_slots.add_child(mast)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.18, 0.14, 0.08)
		head.mesh = hm
		head.material_override = yellow
		head.position = Vector3(x, 1.5, -0.36)
		_slots.add_child(head)


func get_interact_text() -> String:
	return kit.take_prompt() if kit else ""


func interact(by: Node) -> void:
	if kit:
		kit.use_locker(by)
