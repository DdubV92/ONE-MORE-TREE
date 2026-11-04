class_name GearPanel
extends RefCounted
## Phase 14: the supplier catalog/cart/orders and the camp gear screen, as
## one builder shared by the camper computer (Supplier app) and the tool
## rack. Every number shown comes from ToolEffects / Supplier.quote, the
## same calculations the game uses.

## Supplier: catalog with exact benefits, cart, quote (total, cash after,
## payroll and arrears, delivery), idempotent confirm, order status.
## `cart` is an Array of {"key","qty"} owned by the caller; `req` a
## one-element Array holding the current request id.
static func build_supplier(v: VBoxContainer, cart: Array, req: Array, status: Callable, refresh: Callable) -> void:
	var cs: CampaignService = Game.campaign
	v.add_child(UITheme.label("Camp Supply · company account", 20, UITheme.ACCENT))
	if cs == null or not cs.active or cs.supplier == null:
		v.add_child(UITheme.label("Orders are only available during a campaign.", 16))
		return
	var sup: Supplier = cs.supplier
	var eq: Equipment = cs.equipment
	var eta := sup.next_arrival()
	v.add_child(UITheme.label("Cash $%s · tonight's payroll $%s · wages owed $%s · %s" % [Money.format_cents(cs.wallet.cash), Money.format_cents(cs.payroll.todays_estimate()), Money.format_cents(cs.payroll.owed_total()), ("Orders placed now arrive on " + str(eta.words)) if bool(eta.ok) else str(eta.reason)], 14, UITheme.MUTED))
	var mine := ToolEffects.breakdown(_boss_kit())
	var last_kind := ""
	for k in GearCatalog.listing():
		var d := GearCatalog.def(k)
		if str(d.kind) != last_kind:
			last_kind = str(d.kind)
			v.add_child(UITheme.label({"axe": "Axes (same swing cadence; more work per hit)", "chainsaw": "Chainsaw", "boots": "Boots (one pair worn; a better pair replaces a worse one)", "gloves": "Gloves", "helmet": "Helmets"}[last_kind], 16, UITheme.ACCENT))
		var row := HBoxContainer.new()
		var owned := eq.items.filter(func(a: Dictionary) -> bool: return str(a.get("kind", "axe")) == str(d.kind) and str(a.tier) == str(d.tier) and str(a.owner) != "refunded")
		var info := "%s · $%s · %s\n%s" % [str(d.name), Money.format_cents(int(d.price)), str(d.blurb), _benefit_line(str(d.kind), str(d.tier), mine)]
		if not owned.is_empty():
			var where := PackedStringArray()
			for a in owned:
				where.append(eq.where_words(a))
			info += "\nOwned %d: %s" % [owned.size(), ", ".join(where)]
		var l := UITheme.label(info, 13)
		l.custom_minimum_size = Vector2(700, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var kk: String = k
		row.add_child(UITheme.button("Add", func() -> void:
			for ln in cart:
				if str(ln.key) == kk:
					ln.qty = int(ln.qty) + 1
					refresh.call()
					return
			cart.append({"key": kk, "qty": 1})
			refresh.call(), 80))
		v.add_child(row)
	# Cart and quote.
	v.add_child(UITheme.label("Order", 18, UITheme.ACCENT))
	if cart.is_empty():
		v.add_child(UITheme.label("Your cart is empty.", 14, UITheme.MUTED))
	else:
		for ln in cart:
			var r2 := HBoxContainer.new()
			var d2 := GearCatalog.def(str(ln.key))
			var l2 := UITheme.label("%d x %s  $%s" % [int(ln.qty), str(d2.name), Money.format_cents(int(d2.price) * int(ln.qty))], 14)
			l2.custom_minimum_size = Vector2(600, 0)
			r2.add_child(l2)
			var lref: Dictionary = ln
			r2.add_child(UITheme.button("Remove", func() -> void:
				cart.erase(lref)
				refresh.call(), 100))
			v.add_child(r2)
		var q := sup.quote(cart)
		var summary := "Total $%s · cash after $%s · tonight's payroll $%s%s" % [Money.format_cents(int(q.total)), Money.format_cents(int(q.after)), Money.format_cents(int(q.tonight)), (" · already owed $%s" % Money.format_cents(int(q.owed))) if int(q.owed) > 0 else ""]
		if bool(q.eta.get("ok", false)):
			summary += "\nDelivery: %s, to the parcel locker by the camp gate (prepaid; refunded if the contract ends before it arrives)." % str(q.eta.words)
		v.add_child(UITheme.label(summary, 14))
		for wtxt in q.warnings:
			v.add_child(UITheme.label("Warning: " + str(wtxt), 14, Color(1.0, 0.75, 0.4)))
		if not bool(q.ok):
			v.add_child(UITheme.label(str(q.reason), 14, Color(1.0, 0.6, 0.5)))
		else:
			if req[0] == "":
				req[0] = "REQ-%d-%d" % [Time.get_ticks_usec(), randi() % 100000]
			var rid: String = req[0]
			v.add_child(UITheme.button("Confirm order ($%s)" % Money.format_cents(int(q.total)), func() -> void:
				var res := sup.place(cart, rid)
				if bool(res.ok):
					status.call("Order %s placed: $%s paid. It arrives on %s." % [str(res.order.id), Money.format_cents(int(res.order.total)), str(res.order.eta_words)])
					cart.clear()
					req[0] = ""
				else:
					status.call(str(res.reason))
				refresh.call(), 300))
	# Orders.
	if not sup.orders.is_empty():
		v.add_child(UITheme.label("Orders", 18, UITheme.ACCENT))
		for i in range(sup.orders.size() - 1, maxi(sup.orders.size() - 9, -1), -1):
			var o: Dictionary = sup.orders[i]
			var parts := PackedStringArray()
			for ln in o.lines:
				parts.append("%dx %s" % [int(ln.qty), str(GearCatalog.def(str(ln.key)).name)])
			v.add_child(UITheme.label("%s · %s · $%s · %s" % [str(o.id), ", ".join(parts), Money.format_cents(int(o.total)), sup.state_words(o)], 13))
	# The pickup order stays here (Phase 5 real VehicleService).
	if Game.vehicles:
		var u: Dictionary = Game.vehicles.unlock_state()
		var row2 := HBoxContainer.new()
		var lt := UITheme.label("Logging pickup: 3 seats, 3 trees' worth of logs · $%s · owned %d of 2%s" % [Money.format_cents(int(u.price)), int(u.owned), "" if bool(u.unlocked) else " · unlocks after %.0f trees' worth delivered" % float(u.get("need", 0))], 14)
		lt.custom_minimum_size = Vector2(620, 0)
		row2.add_child(lt)
		if int(u.owned) < 2:
			row2.add_child(UITheme.button("Order", func() -> void:
				var r3: Dictionary = Game.vehicles.buy()
				status.call("Pickup delivered to the camp bays." if bool(r3.get("ok", false)) else str(r3.get("reason", "Not possible.")))
				refresh.call(), 100))
		v.add_child(row2)


static func _boss_kit() -> Dictionary:
	var cs: CampaignService = Game.campaign
	if Game.player and Game.player.get("axe"):
		return Game.player.axe.kit()
	return cs.equipment.kit_of("boss") if cs else {"tool": "axe", "tier": "small"}


## What an item would do for the boss compared with the current kit.
static func _benefit_line(kind: String, tier: String, mine: Dictionary) -> String:
	var k := _boss_kit()
	match kind:
		"axe":
			k["tool"] = "axe"
			k["tier"] = tier
			var b := ToolEffects.breakdown(k)
			return "For you: %.2f work per hit, %.2f work/s (now %.2f work/s)." % [float(b.work_per_contact), float(b.work_per_second), float(mine.work_per_second)]
		"chainsaw":
			k["tool"] = "chainsaw"
			var b2 := ToolEffects.breakdown(k)
			return "For you: %.2f work/s while cutting (%.1fx a hatchet; now %.2f work/s). Start pull %.1f s; no fuel or wear." % [float(b2.saw_rate), float(b2.vs_hatchet), float(mine.work_per_second), float(b2.start_s)]
		"boots":
			return "Walking x%.2f (now x%.2f). Loads, slopes, water and the cart still slow you as before; trucks unaffected." % [1.0 + float(GearCatalog.BOOTS_WALK[tier]), float(mine.walk_mult)]
		"gloves":
			k["gloves"] = tier
			var b3 := ToolEffects.breakdown(k)
			return "Axe: one hit every %.3f s (now %.3f s); saw start %.2f s. Never changes the saw's cutting rate." % [ToolEffects.AXE_CYCLE / (1.0 + float(GearCatalog.GLOVES_CADENCE[tier])), ToolEffects.AXE_CYCLE / float(mine.factors.gloves), float(b3.get("start_s", ToolEffects.SAW_START_S / (1.0 + float(GearCatalog.GLOVES_CADENCE[tier]))))]
		"helmet":
			return "Axe work per hit x%.2f (camp morale bonus, axes only; no effect on the saw)." % (1.0 + float(GearCatalog.HELMET_WORK[tier]))
	return ""


## Camp gear: your kit (with the exact breakdown), what you own, camp
## storage, and each employee's issued kit.
static func build_gear(v: VBoxContainer, status: Callable, refresh: Callable) -> void:
	var cs: CampaignService = Game.campaign
	v.add_child(UITheme.label("Camp gear", 20, UITheme.ACCENT))
	if cs == null or not cs.active:
		v.add_child(UITheme.label("Gear is managed during a campaign.", 16))
		return
	var eq: Equipment = cs.equipment
	var b := ToolEffects.breakdown(_boss_kit())
	v.add_child(UITheme.label("Your kit", 16, UITheme.ACCENT))
	for line in ToolEffects.describe(b):
		v.add_child(UITheme.label(line, 13))
	for a in eq.items_of("boss"):
		var row := HBoxContainer.new()
		var slot := GearCatalog.slot_of(str(a.kind))
		var on := str(eq.equipped_item("boss", slot).get("id", "")) == str(a.id)
		var l := UITheme.label("%s %s%s" % [str(a.id), GearCatalog.display_name(str(a.kind), str(a.tier)), "  · EQUIPPED" if on else ""], 14)
		l.custom_minimum_size = Vector2(440, 0)
		row.add_child(l)
		var aid := str(a.id)
		if not on:
			row.add_child(UITheme.button("Equip", func() -> void:
				var r := eq.equip("boss", aid)
				status.call("Equipped." if bool(r.ok) else str(r.reason))
				refresh.call(), 100))
		row.add_child(UITheme.button("To storage", func() -> void:
			var r2 := eq.transfer(aid, "storage")
			status.call("Put in camp storage." if bool(r2.ok) else str(r2.reason))
			refresh.call(), 130))
		_issue_picker(row, aid, status, refresh)
		v.add_child(row)
	v.add_child(UITheme.label("Camp storage (tool rack)", 16, UITheme.ACCENT))
	var st := eq.items_of("storage")
	if st.is_empty():
		v.add_child(UITheme.label("Empty. Collected parcels and returned company kit go here.", 13, UITheme.MUTED))
	for a in st:
		var row3 := HBoxContainer.new()
		var l3 := UITheme.label("%s %s" % [str(a.id), GearCatalog.display_name(str(a.kind), str(a.tier))], 14)
		l3.custom_minimum_size = Vector2(440, 0)
		row3.add_child(l3)
		var aid3 := str(a.id)
		row3.add_child(UITheme.button("Take & equip", func() -> void:
			var r3 := eq.transfer(aid3, "boss")
			if bool(r3.ok):
				eq.equip("boss", aid3)
			status.call("Equipped." if bool(r3.ok) else str(r3.reason))
			refresh.call(), 150))
		_issue_picker(row3, aid3, status, refresh)
		v.add_child(row3)
	if Game.crew:
		v.add_child(UITheme.label("Crew kit (changes happen between jobs)", 16, UITheme.ACCENT))
		for e in cs.payroll.employees:
			if not str(e.status) in [Payroll.ACTIVE, "pending_arrival"]:
				continue
			var eid := str(e.id)
			var w: Worker = Game.crew.workers.get(eid)
			var kit := eq.kit_of(eid)
			var desc := "%s: %s" % [str(e.name), ("chainsaw" if str(kit.tool) == "chainsaw" else ("%s axe" % str(kit.tier) if str(kit.tool) == "axe" else "no cutting tool"))]
			for s2 in ["boots", "gloves", "helmet"]:
				if str(kit[s2]) != "":
					desc += " · %s" % GearCatalog.display_name(s2, str(kit[s2]))
			if w:
				var fx := Game.crew.tool_effects(w)
				desc += "  (%.2f work/s%s)" % [float(fx.work_per_second), ", Hard-working x1.25" if float(fx.factors.hard_working) > 1.0 else ""]
			var pend: Array = e.get("pending_equip", [])
			if not pend.is_empty():
				desc += "  · will put on %d item(s) between jobs" % pend.size()
			v.add_child(UITheme.label(desc, 14))
			for a in eq.items_of(eid):
				var row4 := HBoxContainer.new()
				var l4 := UITheme.label("    %s %s" % [str(a.id), GearCatalog.display_name(str(a.kind), str(a.tier))], 13)
				l4.custom_minimum_size = Vector2(440, 0)
				row4.add_child(l4)
				var aid4 := str(a.id)
				row4.add_child(UITheme.button("Take back", func() -> void:
					var r4: Dictionary = Game.crew.recall(aid4)
					status.call("Returned to camp storage." if bool(r4.ok) else str(r4.reason))
					refresh.call(), 130))
				v.add_child(row4)


static func _issue_picker(row: HBoxContainer, item_id: String, status: Callable, refresh: Callable) -> void:
	var cs: CampaignService = Game.campaign
	if Game.crew == null or cs == null:
		return
	var ob := OptionButton.new()
	ob.add_item("Give to...", 0)
	var ids := [""]
	for e in cs.payroll.employees:
		if str(e.status) == Payroll.ACTIVE:
			ob.add_item(str(e.name))
			ids.append(str(e.id))
	if ids.size() <= 1:
		return
	ob.custom_minimum_size = Vector2(180, 40)
	ob.item_selected.connect(func(i: int) -> void:
		if i <= 0:
			return
		var r: Dictionary = Game.crew.issue(item_id, str(ids[i]))
		status.call(("Issued to %s%s." % [Game.crew.emp(str(ids[i])).name, " (they'll put it on between jobs)" if bool(r.get("pending", false)) else ""]) if bool(r.ok) else str(r.reason))
		refresh.call())
	row.add_child(ob)
