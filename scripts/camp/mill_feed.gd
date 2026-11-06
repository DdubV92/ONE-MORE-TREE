extends Node3D
## Phase 24: the sawmill feed rack's interaction.
##   carrying paid yard logs  -> onto the rack (a yard move, never re-paid)
##   carrying unpaid logs     -> delivered at the mill: contract credit now,
##                               money when the saw finishes a pallet
##   empty hands              -> what the rack holds


func get_interact_text() -> String:
	var t: TimberService = Game.timber
	var y: YardService = Game.yard
	if t == null or y == null:
		return ""
	var room := MillLedger.RACK_CAP - t.mill.rack.size()
	if not t.carried.is_empty():
		if y.is_yard_move(str(t.carried[0])):
			return "Put %d log%s on the sawmill rack (%d free)" % [t.carried.size(), "" if t.carried.size() == 1 else "s", room]
		return "Deliver %d log%s to the sawmill (%d free on the rack)" % [t.carried.size(), "" if t.carried.size() == 1 else "s", room]
	return "Sawmill feed rack: %d/%d logs" % [t.mill.rack.size(), MillLedger.RACK_CAP]


func interact(by: Node) -> void:
	var t: TimberService = Game.timber
	var y: YardService = Game.yard
	if t == null or y == null:
		return
	var msg := ""
	if t.carried.is_empty():
		var m: Sawmill = Game.mill
		msg = m.status_text().replace("\n", "  ·  ") if m else ""
	elif y.is_yard_move(str(t.carried[0])):
		var n := 0
		for sid in t.carried.duplicate():
			if y.is_yard_move(str(sid)) and y.load_mill("player", str(sid)):
				n += 1
		msg = ("Put %d log%s on the feed rack. The saw takes them in order." % [n, "" if n == 1 else "s"]) if n > 0 else y.last_reason
	else:
		var rs := t.accept(t.carried.duplicate(), "mill:player", CampLayout.world(CampLayout.MILL_RACK_POS))
		msg = ("Delivered %d log%s to the sawmill: contract credit now, paid as pallets are finished." % [rs.size(), "" if rs.size() == 1 else "s"]) if not rs.is_empty() else t.last_refusal
	if not msg.is_empty() and msg != t.last_refusal and SoundService.instance() != null:
		LoggingFX.play(LoggingFX.Sound.CLUNK, global_position + Vector3(0, 0.6, 0), 0.0, {"event": "log.stack"})
	if msg != "" and by.has_method("show_message"):
		by.show_message(msg)
