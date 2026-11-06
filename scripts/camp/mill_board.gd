extends Node3D
## Phase 24: the sawmill yard board (read the day's lumber at a glance).


func get_interact_text() -> String:
	return "Read the sawmill board"


func interact(by: Node) -> void:
	var m: Sawmill = Game.mill
	if m == null or not by.has_method("show_message"):
		return
	by.show_message("%s\nEach pallet takes %d L of logs and pays $%s once, when it is strapped. Unfinished pallets and the feed rack wait overnight. The lumber boat collects the yard each morning." % [m.status_text().replace("\n", "  ·  "), m.ledger.pallet_l, Money.format_cents(m.ledger.pay_cents)])
