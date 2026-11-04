class_name Hotspot
extends StaticBody3D
## Generic interaction-only spot on collision layer 16 (the player's ray
## sees it; nothing physical collides with it). Text and action are
## callables so the owning system stays authoritative.

var text_fn: Callable
var use_fn: Callable


static func make(parent: Node3D, name_: String, size: Vector3, pos: Vector3, text: Callable, use: Callable) -> Hotspot:
	var h := Hotspot.new()
	h.name = name_
	h.collision_layer = 16
	h.collision_mask = 0
	h.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	h.add_child(cs)
	h.text_fn = text
	h.use_fn = use
	parent.add_child(h)
	return h


func get_interact_text() -> String:
	return str(text_fn.call()) if text_fn.is_valid() else ""


func interact(by: Node) -> void:
	if use_fn.is_valid():
		use_fn.call(by)
	if by and by.has_method("refresh_interaction"):
		by.refresh_interaction()
