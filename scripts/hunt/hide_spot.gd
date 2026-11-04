class_name HideSpot
extends StaticBody3D
## A usable hiding place (Phase 6): under a bed, inside a closet with slats,
## under the utility desk, behind storage shelves, under the dock. One
## occupant; a physical body/camera pose; a verified exit point; enter and
## exit take a readable moment. Hiding is concealment, not invisibility: a
## seen entry is evidence, a closet door makes a little noise, and a probe
## can find whoever is inside. Interaction-only (layer 16).

var kind := "under_bed"       # under_bed / closet / under_desk / behind_shelves / under_dock
var building := ""            # camper / cabin / utility / dock / ""
var marker: Node3D
var occupant: Node3D
var approach := Vector3.ZERO  # where a searcher stands to check it
var exit_point := Vector3.ZERO
var eye := Vector3.ZERO       # camera position while hidden
var look_dir := Vector3.FORWARD


static func make(m: Node3D, kind_: String, building_: String) -> HideSpot:
	var h := HideSpot.new()
	h.name = "Hide_" + m.name
	h.kind = kind_
	h.building = building_
	h.marker = m
	h.collision_layer = 16
	h.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 0.5, 1.0) if kind_ in ["under_bed", "under_dock"] else Vector3(0.7, 1.5, 0.7)
	cs.shape = bs
	cs.position = Vector3(0, 0.25 if kind_ in ["under_bed", "under_dock"] else 0.8, 0)
	h.add_child(cs)
	m.add_child(h)
	h.add_to_group("hide_spot")
	return h


func _ready() -> void:
	var fwd := -marker.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var base := marker.global_position
	match kind:
		"under_bed", "under_dock":
			eye = base + Vector3(0, 0.22, 0)
			exit_point = base + fwd * 1.1
			approach = base + fwd * 1.0
			look_dir = fwd
		_:
			eye = base + Vector3(0, 1.45, 0)
			exit_point = base + fwd * 0.9
			approach = base + fwd * 1.0
			look_dir = fwd
	exit_point.y = base.y
	approach.y = base.y


func get_interact_text() -> String:
	if Game.hunt == null or not Game.hunt.hiding_enabled():
		return ""
	if occupant != null and occupant != Game.player:
		return "Occupied"
	return {"under_bed": "Hide under the bed", "closet": "Hide in the closet", "under_desk": "Hide under the desk", "behind_shelves": "Hide behind the shelves", "under_dock": "Hide under the dock"}.get(kind, "Hide")


func interact(by: Node) -> void:
	if Game.hunt == null or not Game.hunt.hiding_enabled():
		return
	if occupant != null:
		return
	if by.has_method("hide_in"):
		by.hide_in(self)
