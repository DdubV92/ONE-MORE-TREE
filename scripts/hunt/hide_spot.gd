class_name HideSpot
extends StaticBody3D
## A usable hiding place (Phase 6): under a bed, inside a closet with slats,
## under the utility desk, behind storage shelves, under the dock. One
## occupant; a physical body/camera pose; a verified exit point; enter and
## exit take a readable moment. Hiding is concealment, not invisibility: a
## seen entry is evidence, a closet door makes a little noise, and a probe
## can find whoever is inside. Interaction-only (layer 16).

var kind := "under_bed"       # under_bed / closet / under_desk / behind_shelves / under_dock
                              # Phase 12: rock_recess / rock_gap (island r2 formations)
                              # Phase 19: thicket / shed / dock_store (SurvivalCover)
var building := ""            # camper / cabin / utility / dock / ""
var marker: Node3D
var occupant: Node3D
var approach := Vector3.ZERO  # where a searcher stands to check it
var exit_point := Vector3.ZERO
var eye := Vector3.ZERO       # camera position while hidden
var look_dir := Vector3.FORWARD
## Phase 12 rock hides: every verified exit, and whether the only way out
## is the way in (a deliberate dead end, shown in the prompt).
var exits: Array[Vector3] = []
var dead_end := false
var _rock := false


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
	var low := kind_ in ["under_bed", "under_dock", "dock_store"]
	var mid := kind_.begins_with("rock_") or kind_ in ["thicket", "shed"]
	bs.size = Vector3(1.0, 0.5, 1.0) if low else (Vector3(1.0, 1.1, 1.0) if mid else Vector3(0.7, 1.5, 0.7))
	cs.shape = bs
	cs.position = Vector3(0, 0.25 if low else (0.55 if mid else 0.8), 0)
	h.add_child(cs)
	m.add_child(h)
	h.add_to_group("hide_spot")
	return h


## Rock hides use the planner's verified geometry instead of the indoor
## defaults: crouched eye in the pocket, exits outside the opening(s).
func configure_rock(pos: Vector3, facing: Vector3, eye_h: float, exits_: Array[Vector3], approach_: Vector3, dead_end_: bool) -> void:
	_rock = true
	eye = pos + Vector3(0, eye_h, 0)
	look_dir = facing
	exits = exits_
	exit_point = exits_[0] if not exits_.is_empty() else pos + facing * 1.5
	approach = approach_
	dead_end = dead_end_


func _ready() -> void:
	if _rock:
		return
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
	if kind == "rock_recess":
		return "Crouch into the rock recess (one way out)"
	if kind == "rock_gap":
		return "Squeeze into the gap between the rocks"
	if kind == "thicket":
		return "Push into the thicket and crouch (%d ways out)" % maxi(exits.size(), 1)
	if kind == "shed":
		return "Hide behind the bench in the shed (door creaks; back hatch)"
	if kind == "dock_store":
		return "Climb into the gear chest (the lid knocks)"
	return {"under_bed": "Hide under the bed", "closet": "Hide in the closet", "under_desk": "Hide under the desk", "behind_shelves": "Hide behind the shelves", "under_dock": "Hide under the dock"}.get(kind, "Hide")


func interact(by: Node) -> void:
	if Game.hunt == null or not Game.hunt.hiding_enabled():
		return
	if occupant != null:
		return
	if by.has_method("hide_in"):
		by.hide_in(self)
