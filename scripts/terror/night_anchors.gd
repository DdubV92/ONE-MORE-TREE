class_name NightAnchors
extends RefCounted
## Phase 20: named world points around the camp for night incidents
## (sleep interruptions and missed-night recordings). All outside the
## protected camper room; computed from the real camp nodes and CampLayout.


static func camper() -> Node3D:
	return Game.world_root.find_child("Camper", true, false) as Node3D if Game.world_root else null


static func point(name: String) -> Vector3:
	var c := camper()
	var W := CampLayout.CAMPER_SIZE.x * 0.5
	var F := CampLayout.CAMPER_FLOOR
	var base := name.split(":")[0]
	var k := int(name.split(":")[1]) if name.contains(":") else 0
	if c != null:
		var g := c.global_transform
		match base:
			"camper_door":
				return g * Vector3(W + 0.15, F + 1.0, 2.3)
			"camper_porch":
				return g * Vector3(W + 1.1, 0.25, 2.3)
			"camper_window_r":
				return g * Vector3(-W - 0.4, F + 1.4, 4.4)      # desk (west) window, outside
			"camper_window_l":
				return g * Vector3(W + 0.4, F + 1.4, -1.0)
			"camper_wall_n":
				return g * Vector3(0.0, F + 1.0, CampLayout.CAMPER_NORTH_Z - 0.4)
			"camper_roof":
				return g * Vector3(0.0, F + CampLayout.CAMPER_SIZE.y + 0.25, 1.0)
			"camper_under":
				return g * Vector3(0.0, 0.25, 1.0)
			"around_camper":
				var pts := [Vector3(W + 2.5, 0.0, -3.0), Vector3(0.0, 0.0, CampLayout.CAMPER_SOUTH_Z + 2.5), Vector3(-W - 2.5, 0.0, 2.0), Vector3(0.0, 0.0, CampLayout.CAMPER_NORTH_Z - 2.5)]
				var p: Vector3 = g * pts[k % 4]
				p.y = World.height_at(p.x, p.z)
				return p
			"desk":
				var mons := Game.world_root.get_tree().get_nodes_in_group("camper_monitor")
				if not mons.is_empty():
					return (mons[0] as Node3D).global_position
				return g * Vector3(-W + 0.6, F + 1.0, 4.4)
			"outside_far":
				var q := g * Vector3(-60.0, 0.0, 10.0)
				q.y = World.height_at(q.x, q.z) + 1.0
				return q
			"outside_far2":
				var q2 := g * Vector3(40.0, 0.0, -55.0)
				q2.y = World.height_at(q2.x, q2.z) + 1.0
				return q2
	match base:
		"gate":
			return CampLayout.world(Vector3(0.0, 1.0, -CampLayout.FENCE_HALF.y))
		"gate_out":
			return CampLayout.world(Vector3(0.6, 0.0, -CampLayout.FENCE_HALF.y - 5.0))
		"fence":
			return CampLayout.world(Vector3(-CampLayout.FENCE_HALF.x, 1.0, 3.0))
		"yard":
			return CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(0.0, 0.5, 3.0))
		"pit":
			return CampLayout.world(CampLayout.BURN_PIT_POS)
		"tool_area":
			return CampLayout.world(CampLayout.TOOL_AREA_POS + Vector3(0.0, 1.0, 0.0))
		"locker":
			return CampLayout.world(CampLayout.PARCEL_LOCKER_POS)
		"cabin":
			return CampLayout.world(CampLayout.CABIN_POS + Vector3(0.0, 1.5, 0.0))
		"truck":
			if Game.vehicles:
				var best := Vector3.INF
				for t in (Game.vehicles.trucks as Dictionary).values():
					var tp := (t as Node3D).global_position
					if best == Vector3.INF or tp.distance_to(World.camp_origin()) < best.distance_to(World.camp_origin()):
						best = tp
				return best
	return Vector3.INF


static func has_truck_near_camp() -> bool:
	var t := point("truck")
	return t != Vector3.INF and t.distance_to(World.camp_origin()) < 60.0


static func cabin_occupied() -> bool:
	if Game.crew == null:
		return false
	for w in Game.crew.workers.values():
		if str((w as Worker).emp.get("status", "")) == Payroll.ACTIVE:
			return true          # employed crew sleep in the cabin at night
	return false


static func dog_home() -> bool:
	return Game.dog != null and is_instance_valid(Game.dog) and Game.dog.state != CampDog.State.BOARDED


static func hhmm(hour: float) -> String:
	var h := int(floor(fposmod(hour, 24.0)))
	var m := int(floor((fposmod(hour, 24.0) - h) * 60.0))
	return "%02d:%02d" % [h, m]
