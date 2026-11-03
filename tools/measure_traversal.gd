extends Node
## Walks the real player controller (collision, slopes, trees, water push-back)
## along fixed routes and reports traversal times. Headless, fixed 60 Hz:
##   godot --headless --fixed-fps 60 res://tools/measure_traversal.tscn

const ROUTES_ALL := {
	"camp_to_west_pond (trail 1)": [Vector2(-175, 330), Vector2(-190, 250), Vector2(-260, 150), Vector2(-360, 40), Vector2(-420, 5)],
	"camp_to_east_bridge (trail 2)": [Vector2(-175, 330), Vector2(-120, 250), Vector2(-20, 195), Vector2(60, 186), Vector2(110, 180), Vector2(165, 150)],
	"west_coast_to_east_coast (long axis, cross-country)": [Vector2(-740, 60), Vector2(-430, 70), Vector2(-100, 150), Vector2(108, 182), Vector2(400, 150), Vector2(700, 122)],
}


func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	add_child(world)
	await get_tree().physics_frame
	var p: Player = Game.player
	var lines: PackedStringArray = []
	var routes := ROUTES_ALL
	if OS.has_environment("TRAV_ONLY"):
		routes = {OS.get_environment("TRAV_ONLY"): ROUTES_ALL[OS.get_environment("TRAV_ONLY")]}
	for route_name in routes:
		var pts: Array = routes[route_name]
		var start: Vector2 = pts[0]
		p.teleport_feet(Vector3(start.x, World.height_at(start.x, start.y) + 0.2, start.y), 0.0)
		var t := 0.0
		var dist := 0.0
		var stuck := 0.0
		var last := p.global_position
		var ok := true
		for k in range(1, pts.size()):
			var target: Vector2 = pts[k]
			while Vector2(p.global_position.x, p.global_position.z).distance_to(target) > 2.5:
				var d := Vector2(target.x - p.global_position.x, target.y - p.global_position.z)
				p.set("_yaw", atan2(-d.x, -d.y))
				p.call("_apply_look")
				Input.action_press("move_forward")
				await get_tree().physics_frame
				t += 1.0 / 60.0
				var moved := Vector2(p.global_position.x - last.x, p.global_position.z - last.z).length()
				dist += moved
				last = p.global_position
				stuck = stuck + 1.0 / 60.0 if moved < 0.02 else 0.0
				if stuck > 4.0:
					# Side-step around an obstacle (trunk/rock) like a player would.
					p.global_position += p.global_basis.x * 1.5
					stuck = 0.0
				if OS.has_environment("TRAV_DEBUG") and int(t * 60.0) % 300 == 0:
					print("  t=%d pos=%s target=%s depth=%.2f floor=%s" % [int(t), str(p.global_position.snapped(Vector3.ONE * 0.1)), str(target), p.wading_depth, p.is_on_floor()])
				if t > 900.0:
					ok = false
					break
		Input.action_release("move_forward")
		var line := "%s: %.0f m walked in %.1f s (%.1f min) at walk speed%s" % [route_name, dist, t, t / 60.0, "" if ok else " [TIMEOUT]"]
		print(line)
		lines.append(line)
	var f := FileAccess.open("user://traversal.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines))
	get_tree().quit()
