class_name BridgeBuilder
extends Node3D
## Timber footbridges at the reserved crossing sites (data/world/layout.json).
## Walkable deck with rails and ramp collision onto both banks, so every part
## of the island stays reachable on foot without swimming.

const WIDTH := 2.4


func build() -> void:
	for i in World.bridges().size():
		_bridge(i, World.bridges()[i])
	BuildKit.batch_static(self)


func _bridge(i: int, b: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Bridge_%d" % i
	var center := Vector3(b.x, float(b.deck), b.z)
	var across := Vector3(b.ax, 0, b.az).normalized()
	root.position = center
	root.basis = Basis.looking_at(across, Vector3.UP)   # local -Z runs across the river
	add_child(root)
	var half: float = b.half_span
	var deck_len := half * 2.0
	BuildKit.box(root, Vector3(WIDTH, 0.14, deck_len), Vector3(0, -0.07, 0), "planks", true, 0.0, "Deck")
	for s in [-1.0, 1.0]:
		BuildKit.box(root, Vector3(0.18, 0.28, deck_len + 0.4), Vector3(s * (WIDTH * 0.5 - 0.09), -0.26, 0), "dark_wood", false)
		var posts := int(deck_len / 1.8) + 1
		for k in posts + 1:
			var z := -half + deck_len * float(k) / posts
			BuildKit.box(root, Vector3(0.1, 1.05, 0.1), Vector3(s * (WIDTH * 0.5 - 0.05), 0.52, z), "dark_wood", true)
		BuildKit.box(root, Vector3(0.08, 0.08, deck_len + 0.1), Vector3(s * (WIDTH * 0.5 - 0.05), 1.0, 0), "planks", true)
		BuildKit.box(root, Vector3(0.05, 0.06, deck_len), Vector3(s * (WIDTH * 0.5 - 0.05), 0.55, 0), "planks", false)
	# Support piers into the river bed
	for z in [-half * 0.45, half * 0.45]:
		for s in [-1.0, 1.0]:
			var world_p := root.global_transform * Vector3(s * 0.9, 0, z)
			var bed := World.height_at(world_p.x, world_p.z)
			var hgt := float(b.deck) - bed + 0.3
			BuildKit.cylinder(root, 0.12, hgt, Vector3(s * 0.9, -hgt * 0.5, z), "dark_wood", true, 8)
	# Ramps from each bank up to the deck (visual planks + walkable collision)
	for s in [-1.0, 1.0]:
		var end_local := Vector3(0, 0, s * half)
		var end_world := root.global_transform * end_local
		var out_world := root.global_transform * Vector3(0, 0, s * (half + 3.0))
		var ground := World.height_at(out_world.x, out_world.z)
		var from := Vector3(out_world.x, ground, out_world.z)
		var to := Vector3(end_world.x, float(b.deck), end_world.z)
		BuildKit.ramp(self, from, to, WIDTH - 0.3)
		var mid := (from + to) * 0.5
		var plank := BuildKit.box(self, Vector3(WIDTH - 0.3, 0.08, from.distance_to(to)), mid - Vector3(0, 0.04, 0), "planks", false)
		plank.basis = Basis.looking_at((to - from).normalized(), Vector3.UP)
