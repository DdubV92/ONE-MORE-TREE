class_name SafetyService
extends Node
## Authoritative night-safety query. The published rules (docs/ARCHITECTURE.md
## "Safety rules") are exactly what this code checks:
##  1. Inside the camper interior: always safe, regardless of lighting.
##  2. Inside the worker cabin (or its extension) while it is occupied by at
##     least one crew member (Phase 4): safe.
##  3. Outdoors: safe only inside the camp fence AND within the safe radius of
##     a designated, working camp lamp.
## Nothing else grants safety: flashlights, the fire, moonlight, distant glow,
## screen brightness or arbitrary emissive objects are never consulted.

enum Reason { UNSAFE, CAMPER_INTERIOR, CAMP_LAMP, CABIN_OCCUPIED }


func query(p: Vector3) -> Dictionary:
	for z in get_tree().get_nodes_in_group("zones"):
		if z.always_safe and z.contains_point(p):
			return {"safe": true, "reason": Reason.CAMPER_INTERIOR, "zone": z.zone_name}
	for z in get_tree().get_nodes_in_group("zones"):
		if z.zone_name in ["cabin", "cabin_extension"] and z.contains_point(p) and _cabin_occupied():
			return {"safe": true, "reason": Reason.CABIN_OCCUPIED, "zone": z.zone_name}
	if CampLayout.inside_fence(p):
		for lamp in get_tree().get_nodes_in_group("camp_lamps"):
			var l := lamp as CampLamp
			if l and l.working:
				var d := Vector2(p.x - l.global_position.x, p.z - l.global_position.z).length()
				if d <= l.safe_radius:
					return {"safe": true, "reason": Reason.CAMP_LAMP, "lamp": l.name}
	return {"safe": false, "reason": Reason.UNSAFE}


func is_point_safe(p: Vector3) -> bool:
	return query(p).safe


func is_player_safe() -> bool:
	return Game.player != null and is_point_safe(Game.player.global_position + Vector3(0, 0.9, 0))



func _cabin_occupied() -> bool:
	for w in get_tree().get_nodes_in_group("crew_workers"):
		var wk := w as Node3D
		for z in get_tree().get_nodes_in_group("zones"):
			if z.zone_name in ["cabin", "cabin_extension"] and z.contains_point(wk.global_position + Vector3(0, 0.5, 0)):
				return true
	return false
