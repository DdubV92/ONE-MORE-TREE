class_name Epilogue
extends RefCounted
## Phase 29: the ending reads back how the boss played. Every line comes
## from a real record (trees, payroll, wallet, field notes, the map, the
## hunt); nothing here is scored or invented, and nothing explains the
## island.


## The figures an ending is written from.
static func facts() -> Dictionary:
	var f := {"island_trees": World.native_total(), "cut": 0, "lot_trees": 0, "lot_cut": 0, "extra_cut": 0,
		"crew_total": 0, "crew_kept": 0, "crew_left": 0, "crew_dead": 0, "crew_escaped": 0, "crew_behind": 0,
		"wages_paid": 0, "wages_owed": 0, "things_met": 0, "rules_known": 0, "caught": 0, "breaker_trips": 0,
		"missing_nights": 0, "brought_home": 0, "map_share": 0.0, "one_more": "", "won": false, "stranded": false, "day": 0}
	var cs: CampaignService = Game.campaign
	var lots: ContractLots = cs.contract.lots if cs and cs.contract else null
	if Game.trees:
		for id in Game.trees.records:
			if int(Game.trees.records[id].state) >= TreeService.State.FALLING:
				f.cut = int(f.cut) + 1
				if lots and lots.has(int(id)):
					f.lot_cut = int(f.lot_cut) + 1
	if lots:
		f.lot_trees = lots.total()
		f.one_more = str(lots.one_more.state)
	f.extra_cut = int(f.cut) - int(f.lot_cut)
	var hunt: HuntService = Game.hunt
	if cs:
		f.day = cs.clock.day
		for e in cs.payroll.employees:
			f.crew_total = int(f.crew_total) + 1
			var st := str(e.status)
			if st == "dead":
				f.crew_dead = int(f.crew_dead) + 1
			elif hunt and hunt.escaped.has(str(e.id)):
				f.crew_escaped = int(f.crew_escaped) + 1
			elif st == Payroll.ACTIVE:
				f.crew_behind = int(f.crew_behind) + 1
			else:
				f.crew_left = int(f.crew_left) + 1
		f.crew_kept = int(f.crew_escaped) + int(f.crew_behind)
		for tx in cs.wallet.transactions:
			if str(tx.kind) == "wage":
				f.wages_paid = int(f.wages_paid) - int(tx.amount)
		f.wages_owed = cs.payroll.owed_total()
	if hunt:
		f.won = hunt.contract_won
		f.stranded = hunt.stranded
		if hunt.mode != "none":
			f.day = hunt.hunt_day
	if Game.director:
		f.things_met = Game.director.notes.notes.size()
		f.rules_known = Game.director.notes.rules_known()
	if Game.threat:
		f.caught = Game.threat.catches
	if Game.night_kit:
		f.breaker_trips = Game.night_kit.trips
	if Game.crew:
		f.missing_nights = Game.crew.missing.count
		f.brought_home = Game.crew.missing.found_count
	if Game.island_map:
		f.map_share = Game.island_map.explored_share()
	return f


## A name for how it went. The first that fits.
static func title(f: Dictionary) -> String:
	if not bool(f.won):
		return "The One Who Got Off Anyway"
	if str(f.one_more) == "felled":
		return "One More Tree"
	if int(f.crew_dead) == 0 and int(f.crew_behind) == 0 and int(f.crew_left) == 0 and int(f.wages_owed) == 0:
		return "A Clean Job"
	if int(f.crew_dead) > 0 or int(f.crew_behind) > 0:
		return "The Job Got Done"
	return "Contract Fulfilled"


static func lines(f: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(title(f).to_upper())
	# The trees.
	var left := int(f.island_trees) - int(f.cut)
	out.append("Of the island's %s trees, %s are still standing." % [_n(int(f.island_trees)), _n(left)])
	if int(f.lot_trees) > 0:
		if int(f.extra_cut) <= 0:
			out.append("You cut what you signed for (%d of %d lot trees) and nothing more." % [int(f.lot_cut), int(f.lot_trees)])
		else:
			out.append("You cut %d of the %d lot trees, and %d that nobody asked for." % [int(f.lot_cut), int(f.lot_trees), int(f.extra_cut)])
	match str(f.one_more):
		"felled":
			out.append("When the job was finished they asked for one more, and you gave it to them.")
		"refused":
			out.append("When the job was finished they asked for one more. You said no.")
		"lapsed":
			out.append("When the job was finished they asked for one more. You said yes, and it is still standing.")
	# The people.
	if int(f.crew_total) > 0:
		var bits := PackedStringArray()
		if int(f.crew_escaped) > 0:
			bits.append("%d left the island with you" % int(f.crew_escaped))
		if int(f.crew_left) > 0:
			bits.append("%d had already gone" % int(f.crew_left))
		if int(f.crew_behind) > 0:
			bits.append("%d stayed behind" % int(f.crew_behind))
		if int(f.crew_dead) > 0:
			bits.append("%d did not live" % int(f.crew_dead))
		out.append("%d people worked for you: %s." % [int(f.crew_total), ", ".join(bits) if not bits.is_empty() else "none of them is accounted for"])
		out.append("You paid $%s in wages%s." % [Money.format_cents(int(f.wages_paid)), (" and still owe $%s" % Money.format_cents(int(f.wages_owed))) if int(f.wages_owed) > 0 else " and owe nobody"])
	if int(f.missing_nights) > 0:
		out.append("%d night%s somebody did not come home; %s." % [int(f.missing_nights), "" if int(f.missing_nights) == 1 else "s", ("you went out and brought them in %d time%s" % [int(f.brought_home), "" if int(f.brought_home) == 1 else "s"]) if int(f.brought_home) > 0 else "you slept"])
	# The nights.
	if int(f.things_met) > 0:
		out.append("You met %d of the things that live here and worked out what %d of them want." % [int(f.things_met), int(f.rules_known)])
	else:
		out.append("You never wrote down a single thing you met at night.")
	if int(f.caught) > 0:
		out.append("The dark caught you %d time%s." % [int(f.caught), "" if int(f.caught) == 1 else "s"])
	out.append("You walked %d%% of the island." % int(round(float(f.map_share) * 100.0)))
	return out


static func _n(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
