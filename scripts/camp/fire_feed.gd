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
	if t and t.fire_out:
		var why := t.relight_blocker(Game.weather.rain if Game.weather else 0.0)
		return "Relight the fire" if why == "" else "Fire out (%s)" % why
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
	elif t and t.fire_out:
		var why := t.relight_blocker(Game.weather.rain if Game.weather else 0.0)
		if why == "" and t.relight("player"):
			msg = "You coax the coals back with dry kindling from under the stones. It smoulders, then catches."
			if SoundService.instance():
				SoundService.play("fire.log.place", (get_parent() as Node3D).global_position, {"emit": false})
		else:
			msg = "The fire is out and it's %s. Wait for the rain to ease." % why.trim_prefix("too wet: ")
	else:
		msg = message
	if msg != "" and by.has_method("show_message"):
		by.show_message(msg)
