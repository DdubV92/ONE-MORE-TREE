class_name YardDeck
extends Node3D
## Interaction for one yard log deck (Phase 13). The deck's collision body is
## a child, so the player's interact ray resolves here.
##   carrying accepted logs   -> stack them on this deck
##   carrying unpaid logs     -> deliver them onto this deck (acceptance)
##   empty hands              -> take the top log for the fire

var index := 0


func _yard() -> YardService:
	return Game.yard


func get_interact_text() -> String:
	var y := _yard()
	var t: TimberService = Game.timber
	if y == null or t == null:
		return ""
	var held: Array = t.carried
	if not held.is_empty():
		if y.is_yard_move(str(held[0])):
			return "Stack on deck %d" % (index + 1)
		return "Deliver %d log%s onto deck %d" % [held.size(), "" if held.size() == 1 else "s", index + 1]
	var n := (y.decks[index] as Array).size()
	if n == 0:
		return "Deck %d: empty" % (index + 1)
	return "Take a log to the fire (deck %d: %d logs)" % [index + 1, n]


func interact(by: Node) -> void:
	var y := _yard()
	var t: TimberService = Game.timber
	if y == null or t == null:
		return
	var msg := ""
	if not t.carried.is_empty():
		if y.is_yard_move(str(t.carried[0])):
			var placed := 0
			for sid in t.carried.duplicate():
				if y.is_yard_move(str(sid)) and y.place_on_deck("player", str(sid), index):
					placed += 1
			msg = "Stacked %d log%s on deck %d." % [placed, "" if placed == 1 else "s", index + 1] if placed > 0 else y.last_reason
			if placed > 0:
				LoggingFX.play(LoggingFX.Sound.CLUNK, global_position + Vector3(0, 0.8, 0), -8.0)
		else:
			var rs := t.accept(t.carried.duplicate(), "deck:player", global_position)
			var cents := 0
			for r in rs:
				cents += int(r.cents)
			msg = ("Delivered %d log%s onto deck %d. Contract entitlement +$%s." % [rs.size(), "" if rs.size() == 1 else "s", index + 1, Money.format_cents(cents)]) if not rs.is_empty() else t.last_refusal
			if not rs.is_empty():
				LoggingFX.play(LoggingFX.Sound.CLUNK, global_position + Vector3(0, 0.8, 0), -6.0)
	else:
		var budget := 333
		if by.get("carry"):
			budget = by.carry.budget()
		var sid := y.take_from_deck("player", index, budget)
		msg = "Carry it to the fire's loading pile (%s at the pit)." % Keys.label("interact") if sid != "" else y.last_reason
	if msg != "" and by.has_method("show_message"):
		by.show_message(msg)
