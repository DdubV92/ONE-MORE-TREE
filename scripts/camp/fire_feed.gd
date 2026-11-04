extends "res://scripts/interaction/interactable.gd"
## Phase 13: the burn pit's interaction. Paid logs from the yard go onto the
## fire's loading pile (bounded; the fire takes from it). Unpaid wood is
## never burned here - it must be delivered first - and touching the fire
## never creates money, receipts or work credit.


func get_interact_text() -> String:
	var t: TimberService = Game.timber
	if t and not t.carried.is_empty():
		if Game.yard and Game.yard.is_yard_move(str(t.carried[0])):
			return "Put %d log%s on the fire's loading pile (%d/%d)" % [t.carried.size(), "" if t.carried.size() == 1 else "s", t.queue.size(), CampLayout.PIT_QUEUE_CAP]
		return "Deliver these logs at the receiving cradle first"
	return prompt


func interact(by: Node) -> void:
	var t: TimberService = Game.timber
	var msg := ""
	if t and not t.carried.is_empty():
		if Game.yard and Game.yard.is_yard_move(str(t.carried[0])):
			var n := 0
			for sid in t.carried.duplicate():
				if Game.yard.is_yard_move(str(sid)) and Game.yard.load_pit("player", str(sid)):
					n += 1
			msg = ("Loaded %d log%s for the fire. It burns on its own from the pile." % [n, "" if n == 1 else "s"]) if n > 0 else Game.yard.last_reason
		else:
			msg = "Unpaid logs aren't burned. Deliver them at the receiving cradle beside the pit first."
	else:
		msg = message
	if msg != "" and by.has_method("show_message"):
		by.show_message(msg)
