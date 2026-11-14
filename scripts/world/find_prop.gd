class_name FindProp
extends StaticBody3D
## Phase 28: one thing to find (IslandFinds owns the list and the state).

var finds: IslandFinds
var id := ""


func setup(owner_: IslandFinds, f: Dictionary, at: Vector3) -> void:
	finds = owner_
	id = str(f.id)
	name = "Find_" + id
	position = at
	var wood := "dark_wood"
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.5, 0.5, 0.48)
	grey.roughness = 0.9
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.42, 0.24, 0.14)
	rust.roughness = 0.8
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.95, 0.55, 0.3)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.82, 0.7)
	var h := 1.2
	match str(f.prop):
		"stake":
			BuildKit.box(self, Vector3(0.06, 1.1, 0.06), Vector3(0, 0.55, 0), wood, false)
			BuildKit.box(self, Vector3(0.02, 0.3, 0.07), Vector3(0.04, 1.0, 0), tape, false)
		"ring":
			for k in 9:
				var a := TAU * k / 9.0
				BuildKit.box(self, Vector3(0.3, 0.18, 0.24), Vector3(cos(a) * 0.8, 0.09, sin(a) * 0.8), grey, false, a)
			BuildKit.cylinder(self, 0.14, 0.2, Vector3(0.2, 0.1, 0.1), rust, false, 8)
			h = 0.5
		"plank":
			BuildKit.box(self, Vector3(0.06, 1.3, 0.06), Vector3(0, 0.65, 0), wood, false)
			BuildKit.box(self, Vector3(0.9, 0.22, 0.03), Vector3(0, 1.15, 0.04), wood, false)
		"boot":
			BuildKit.box(self, Vector3(0.12, 0.26, 0.14), Vector3(0, 0.13, 0), rust, false)
			BuildKit.box(self, Vector3(0.12, 0.1, 0.3), Vector3(0, 0.05, 0.1), rust, false)
			h = 0.4
		"post":
			BuildKit.cylinder(self, 0.12, 1.5, Vector3(0, 0.75, 0), grey, false, 8)
			h = 1.5
		"sign":
			BuildKit.box(self, Vector3(0.1, 2.6, 0.1), Vector3(-1.1, 1.3, 0), wood, false)
			BuildKit.box(self, Vector3(0.1, 2.6, 0.1), Vector3(1.1, 1.3, 0), wood, false)
			BuildKit.box(self, Vector3(2.6, 1.3, 0.06), Vector3(0, 2.0, 0), paint, false)
			# Faded lettering and a strip of sky-blue, both sides.
			var sky := StandardMaterial3D.new()
			sky.albedo_color = Color(0.55, 0.7, 0.8)
			for side in [1.0, -1.0]:
				BuildKit.box(self, Vector3(2.5, 0.42, 0.01), Vector3(0, 2.38, 0.036 * side), sky, false)
				var big := Label3D.new()
				big.text = "ISLAND PARK"
				big.font_size = 64
				big.pixel_size = 0.005
				big.modulate = Color(0.62, 0.2, 0.14)
				big.outline_size = 0
				big.position = Vector3(0, 2.02, 0.04 * side)
				big.rotation.y = 0.0 if side > 0.0 else PI
				add_child(big)
				var small := Label3D.new()
				small.text = "COMING NEXT SUMMER"
				small.font_size = 36
				small.pixel_size = 0.005
				small.modulate = Color(0.25, 0.25, 0.22)
				small.outline_size = 0
				small.position = Vector3(0, 1.6, 0.04 * side)
				small.rotation.y = 0.0 if side > 0.0 else PI
				add_child(small)
			h = 2.7
		"saw":
			BuildKit.cylinder(self, 0.4, 0.5, Vector3(0, 0.25, 0), wood, false, 10)
			BuildKit.box(self, Vector3(1.6, 0.14, 0.02), Vector3(0, 0.42, 0), rust, false)
			h = 0.7
		"cairn":
			for k in 5:
				BuildKit.box(self, Vector3(0.5 - k * 0.08, 0.12, 0.4 - k * 0.06), Vector3(0, 0.06 + k * 0.12, 0), grey, false, k * 0.5)
			for k in 4:
				BuildKit.box(self, Vector3(0.42 - k * 0.08, 0.12, 0.34 - k * 0.06), Vector3(0, 0.06 + k * 0.12, 7.5), grey, false, k * 0.7)
			h = 0.8
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.45 if str(f.prop) != "sign" else 1.3
	sh.height = h
	cs.shape = sh
	cs.position = Vector3(0, h * 0.5, 0)
	add_child(cs)


func get_interact_text() -> String:
	if finds == null:
		return ""
	return "Look closer" if not finds.is_found(id) else "Look again"


func interact(by: Node) -> void:
	if finds == null:
		return
	var t := finds.discover(id)
	if t != "" and by.has_method("show_message"):
		by.show_message(t)
