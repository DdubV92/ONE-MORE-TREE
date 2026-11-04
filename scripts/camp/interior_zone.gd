extends Area3D
## A named space (camper, cabin, camp yard). Tracks whether the player is
## inside, drives interior lighting/audio blending, and answers containment
## queries for the SafetyService with a pure geometric test (no physics
## timing), so gameplay and the published rules always agree.

@export var zone_name := ""
@export var always_safe := false
@export var is_interior := true
var player_inside := false


## Phase 15: audio-area layer (SoundService players listen on this mask
## only) and the zone's room response.
const AUDIO_AREA_LAYER := 1 << 19


func _ready() -> void:
	add_to_group("zones")
	if is_interior:
		collision_layer |= AUDIO_AREA_LAYER
		reverb_bus_enabled = true
		reverb_bus_name = "RoomCamper" if zone_name.begins_with("camper") else "RoomCabin"
		reverb_bus_amount = 0.7
		reverb_bus_uniformity = 0.4
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func contains_point(p: Vector3) -> bool:
	var cs: CollisionShape3D = get_child(0)
	var box: BoxShape3D = cs.shape
	var local := global_transform.affine_inverse() * p
	var h := box.size * 0.5
	return absf(local.x) <= h.x and absf(local.y) <= h.y and absf(local.z) <= h.z


func _on_enter(body: Node) -> void:
	if body == Game.player:
		player_inside = true
		_notify()


func _on_exit(body: Node) -> void:
	if body == Game.player:
		player_inside = false
		_notify()


func _notify() -> void:
	if not is_interior:
		return
	var any := false
	for z in get_tree().get_nodes_in_group("zones"):
		if z.is_interior and z.player_inside:
			any = true
	if Game.environment:
		Game.environment.set_interior_target(1.0 if any else 0.0)
	get_tree().call_group("audio_listeners", "set_interior", any, zone_name if player_inside else "")
