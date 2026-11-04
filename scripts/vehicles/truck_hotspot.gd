class_name TruckHotspot
extends AnimatableBody3D
## Interaction spot on a truck (driver door, passenger door, tailgate). On
## its own collision layer (16): the player's interaction ray sees it, no
## physics body collides with it.

var truck: Truck
var kind := ""


func _ready() -> void:
	sync_to_physics = false


func get_interact_text() -> String:
	return Game.vehicles.hotspot_text(truck, kind) if Game.vehicles else ""


func interact(by: Node) -> void:
	if Game.vehicles:
		Game.vehicles.hotspot_use(truck, kind, by)
