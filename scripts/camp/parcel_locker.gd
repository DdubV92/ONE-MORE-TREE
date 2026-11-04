class_name ParcelLocker
extends StaticBody3D
## Phase 14: the camp parcel locker. The supply boat crew carries arrived
## orders up from the dock and locks them in here; E collects every waiting
## parcel into camp storage (the tool rack) exactly once - never straight
## into a worker's hands. The visible parcels follow the order records, so
## a missing visual can always be rebuilt from them (no second order).

var _boxes: Node3D
var _sign: Label3D


func setup(at: Vector3) -> void:
	add_to_group("parcel_locker")
	name = "ParcelLocker"
	position = at
	var steel := BuildKit.mat("steel")
	var paint := ChainsawModel._m(Color(0.22, 0.34, 0.27), 0.55, 0.2)
	var dark := ChainsawModel._m(Color(0.08, 0.09, 0.09), 0.7)
	BuildKit.box(self, Vector3(1.6, 1.85, 0.62), Vector3(0, 0.95, 0), paint, false, 0.0, "Cabinet")
	BuildKit.box(self, Vector3(1.7, 0.08, 0.7), Vector3(0, 1.91, 0), steel, false, 0.0, "Roof")
	# Locker doors (3 x 3 grid) with handles, facing -Z (north, into camp).
	for r in 3:
		for c in 3:
			var cx := -0.5 + c * 0.5
			var cy := 0.36 + r * 0.55
			BuildKit.box(self, Vector3(0.46, 0.5, 0.02), Vector3(cx, cy, -0.32), paint, false, 0.0, "Door%d%d" % [r, c])
			BuildKit.box(self, Vector3(0.05, 0.02, 0.03), Vector3(cx + 0.15, cy, -0.345), dark, false)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.7, 1.95, 0.7)
	cs.shape = bx
	cs.position = Vector3(0, 0.97, 0)
	add_child(cs)
	_sign = Label3D.new()
	_sign.text = "PARCELS"
	_sign.font_size = 40
	_sign.pixel_size = 0.004
	_sign.position = Vector3(0, 2.1, -0.36)
	_sign.rotation.y = PI
	_sign.modulate = Color(0.95, 0.9, 0.75)
	add_child(_sign)
	_boxes = Node3D.new()
	_boxes.name = "Parcels"
	add_child(_boxes)
	refresh()


var _hook_t := 0.0


func _process(delta: float) -> void:
	# The campaign is built after the camp: hook its supplier when it exists.
	_hook_t -= delta
	if _hook_t > 0.0:
		return
	_hook_t = 1.0
	var cs: CampaignService = Game.campaign
	if cs and cs.supplier and not cs.supplier.changed.is_connected(refresh):
		cs.supplier.changed.connect(refresh)
		refresh()


## Parcels waiting are stacked on the locker shelf beside it (one box per
## waiting order, up to 6), from the order records.
func refresh() -> void:
	for c in _boxes.get_children():
		c.queue_free()
	var cs: CampaignService = Game.campaign
	var waiting := cs.supplier.waiting_parcels() if cs and cs.supplier else []
	var card := ChainsawModel._m(Color(0.62, 0.48, 0.3), 0.85)
	var tape := ChainsawModel._m(Color(0.75, 0.68, 0.5), 0.6)
	for i in mini(waiting.size(), 6):
		var p := Vector3(1.15, 0.2 + (i / 2) * 0.36, -0.1 + (i % 2) * 0.36 - 0.18)
		BuildKit.box(_boxes, Vector3(0.5, 0.34, 0.34), p, card, false, 0.0, "Parcel%d" % i)
		BuildKit.box(_boxes, Vector3(0.51, 0.04, 0.35), p + Vector3(0, 0.1, 0), tape, false)
	_sign.text = "PARCELS (%d waiting)" % waiting.size() if waiting.size() > 0 else "PARCELS"


func get_interact_text() -> String:
	var cs: CampaignService = Game.campaign
	if cs == null or not cs.active or cs.supplier == null:
		return "Parcel locker (supplier deliveries)"
	var w := cs.supplier.waiting_parcels()
	if not w.is_empty():
		var n := 0
		for o in w:
			n += (o.items as Array).size()
		return "Collect %d parcel%s (%d item%s) into camp storage" % [w.size(), "" if w.size() == 1 else "s", n, "" if n == 1 else "s"]
	var t := cs.supplier.in_transit()
	if not t.is_empty():
		return "Parcel locker: empty · next delivery on %s" % str(t[0].eta_words)
	return "Parcel locker: empty (order on the camper computer)"


func interact(by: Node) -> void:
	var cs: CampaignService = Game.campaign
	var msg := ""
	if cs == null or not cs.active or cs.supplier == null:
		msg = "Supplier deliveries arrive here during a campaign."
	else:
		var got := cs.supplier.collect_all()
		if got.is_empty():
			msg = get_interact_text()
		else:
			var names := PackedStringArray()
			for g in got:
				for id in cs.supplier.order(str(g[0])).items:
					var a := cs.equipment.item(str(id))
					names.append(GearCatalog.display_name(str(a.kind), str(a.tier)))
			msg = "Collected into camp storage: %s. Equip or hand them out at the tool rack (E) or on the computer." % ", ".join(names)
			LoggingFX.play(LoggingFX.Sound.CLUNK, global_position + Vector3(0, 1.0, 0), 0.0, {"event": "tool.pickup"})
	if by.has_method("show_message"):
		by.show_message(msg)
