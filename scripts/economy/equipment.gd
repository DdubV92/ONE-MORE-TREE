class_name Equipment
extends Node
## Owned durable items (Phase 3 axes; Phase 14 all supplier items). Every
## item is one record with a stable id, kind/tier, acquisition source and
## receipt, and exactly ONE owner at a time:
##   "boss"            the player
##   an employee id    that employee (company kit issued to them)
##   "storage"         camp storage at the tool rack (was "rack" before Phase 14)
##   "order:ORD-n"     paid, in transit on the supply boat
##   "parcel:ORD-n"    arrived, waiting in the camp parcel locker
##   "refunded"        an undelivered order refunded at contract close
## Each owner equips at most one item per slot (tool/boots/gloves/helmet);
## a better tier REPLACES a worse one, nothing stacks. Effects come only from
## ToolEffects. The starting hatchet cannot be lost (no softlock at $0).

signal changed()

const TIERS := ["small", "medium", "large"]

var items: Array[Dictionary] = []
## owner -> {slot: item id}
var slots := {}
var _counter := 0
var wallet: Wallet
var config: EconomyConfig

## Phase 3 compatibility: the axe records.
var axes: Array:
	get:
		return items.filter(func(a: Dictionary) -> bool: return str(a.get("kind", "axe")) == "axe")

## Phase 3 compatibility: the boss's equipped tool id.
var equipped: String:
	get:
		return str((slots.get("boss", {}) as Dictionary).get("tool", ""))
	set(v):
		if not slots.has("boss"):
			slots["boss"] = {}
		slots["boss"]["tool"] = v


func setup(w: Wallet, cfg: EconomyConfig) -> void:
	wallet = w
	config = cfg


## New campaign: the boss's hatchet, plus one issued to each starting
## employee.
func init_new(employee_ids: Array) -> void:
	items.clear()
	slots.clear()
	_counter = 0
	var boss := add_item("axe", "small", "boss", "starting")
	for eid in employee_ids:
		var a := add_item("axe", "small", str(eid), "starting")
		_set_slot(str(eid), "tool", str(a.id))
	_set_slot("boss", "tool", str(boss.id))
	changed.emit()


## Creates one new item record (callers emit `changed`).
func add_item(kind: String, tier: String, owner: String, source: String, receipt := "") -> Dictionary:
	_counter += 1
	var prefix: String = {"axe": "AXE", "chainsaw": "SAW", "boots": "BOOT", "gloves": "GLOV", "helmet": "HELM"}.get(kind, "ITEM")
	var a := {"id": "%s-%04d" % [prefix, _counter], "kind": kind, "tier": tier, "owner": owner, "source": source, "receipt": receipt}
	items.append(a)
	return a


## Phase 3 name, kept for callers that issue company hatchets.
func _add(tier: String, owner: String, source: String, receipt := "") -> Dictionary:
	return add_item("axe", tier, owner, source, receipt)


func item(id: String) -> Dictionary:
	for a in items:
		if str(a.id) == id:
			return a
	return {}


func owned_by(owner: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in items:
		if str(a.owner) == owner and str(a.get("kind", "axe")) == "axe":
			out.append(a)
	return out


## Every item (any kind) an owner holds.
func items_of(owner: String, kind := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in items:
		if str(a.owner) == owner and (kind == "" or str(a.get("kind", "axe")) == kind):
			out.append(a)
	return out


func count_kind(kind: String) -> int:
	var n := 0
	for a in items:
		if str(a.get("kind", "axe")) == kind and str(a.owner) != "refunded":
			n += 1
	return n


func boss_has(tier: String) -> bool:
	for a in owned_by("boss"):
		if str(a.tier) == tier:
			return true
	return false


func _set_slot(owner: String, slot: String, id: String) -> void:
	if not slots.has(owner):
		slots[owner] = {}
	if id == "":
		(slots[owner] as Dictionary).erase(slot)
	else:
		slots[owner][slot] = id


## The item an owner has equipped in a slot ({} = none). Stale entries
## (item moved to someone else) are ignored.
func equipped_item(owner: String, slot: String) -> Dictionary:
	var id := str((slots.get(owner, {}) as Dictionary).get(slot, ""))
	var a := item(id)
	if a.is_empty() or str(a.owner) != owner:
		return {}
	return a


func equipped_tier() -> String:
	var a := equipped_item("boss", "tool")
	if a.is_empty() or str(a.kind) != "axe":
		return "small"
	return str(a.tier)


## "axe" or "chainsaw": what the boss has in the tool slot.
func boss_tool_kind() -> String:
	var a := equipped_item("boss", "tool")
	return str(a.get("kind", "axe")) if not a.is_empty() else "axe"


## The owner's equipped kit in ToolEffects form.
func kit_of(owner: String) -> Dictionary:
	var tool := equipped_item(owner, "tool")
	if tool.is_empty():
		# Legacy: a worker's best owned axe is their tool.
		for a in owned_by(owner):
			if tool.is_empty() or GearCatalog.rank("axe", str(a.tier)) > GearCatalog.rank("axe", str(tool.tier)):
				tool = a
	var out := {"tool": str(tool.get("kind", "")), "tier": str(tool.get("tier", "")), "tool_id": str(tool.get("id", ""))}
	for s in ["boots", "gloves", "helmet"]:
		out[s] = str(equipped_item(owner, s).get("tier", ""))
	return out


## Equips an item the owner holds into its slot (replacing what was there).
func equip(owner: String, id: String) -> Dictionary:
	var a := item(id)
	if a.is_empty():
		return {"ok": false, "reason": "No such item."}
	if str(a.owner) != owner:
		return {"ok": false, "reason": "%s is %s, not yours to equip." % [GearCatalog.display_name(str(a.kind), str(a.tier)), where_words(a)]}
	_set_slot(owner, GearCatalog.slot_of(str(a.kind)), id)
	changed.emit()
	return {"ok": true}


func unequip(owner: String, slot: String) -> void:
	if slot == "tool" and owner == "boss":
		# The boss always holds a tool: fall back to an owned axe.
		for a in owned_by("boss"):
			_set_slot(owner, "tool", str(a.id))
			changed.emit()
			return
	_set_slot(owner, slot, "")
	changed.emit()


## Moves an item between the boss, storage and employees (one owner at a
## time; never out of an order or parcel). Clears the old owner's slot.
func transfer(id: String, to_owner: String) -> Dictionary:
	var a := item(id)
	if a.is_empty():
		return {"ok": false, "reason": "No such item."}
	var from := str(a.owner)
	if from.begins_with("order:") or from.begins_with("parcel:") or from == "refunded":
		return {"ok": false, "reason": "%s is %s." % [GearCatalog.display_name(str(a.kind), str(a.tier)), where_words(a)]}
	if from == to_owner:
		return {"ok": true}
	if from == "boss" and str(a.get("kind", "")) == "axe" and str(a.tier) == "small" and items_of("boss", "axe").size() <= 1 and equipped_item("boss", "tool").get("id", "") == id:
		return {"ok": false, "reason": "Keep your hatchet: you'd have nothing to cut with."}
	for s in GearCatalog.SLOTS:
		if str((slots.get(from, {}) as Dictionary).get(s, "")) == id:
			_set_slot(from, s, "")
	a.owner = to_owner
	if from == "boss" and equipped_item("boss", "tool").is_empty():
		unequip("boss", "tool")
	changed.emit()
	return {"ok": true}


func where_words(a: Dictionary) -> String:
	var o := str(a.owner)
	if o == "boss":
		return "yours"
	if o == "storage":
		return "in camp storage"
	if o.begins_with("order:"):
		return "still on its way (order %s)" % o.get_slice(":", 1)
	if o.begins_with("parcel:"):
		return "waiting in the parcel locker (order %s)" % o.get_slice(":", 1)
	if o == "refunded":
		return "refunded (never delivered)"
	var name := o
	if Game.crew:
		name = str(Game.crew.emp(o).get("name", o))
	return "issued to " + name


func price(tier: String) -> int:
	return GearCatalog.price("axe", tier)


## Development/test purchase: an immediate, receipted axe for the boss.
## The game itself orders through Supplier (delivered by boat).
func buy(tier: String) -> Dictionary:
	if not tier in TIERS or tier == "small":
		return {"ok": false, "reason": "Not for sale."}
	if boss_has(tier):
		return {"ok": false, "reason": "You already own a %s axe." % tier}
	var cost := price(tier)
	if not wallet.can_afford(cost):
		return {"ok": false, "reason": "Not enough cash ($%s needed)." % Money.format_cents(cost)}
	var tx := wallet.spend(cost, "purchase", "axe:" + tier, "Bought %s axe" % tier)
	if tx.is_empty():
		return {"ok": false, "reason": "Payment failed."}
	var a := add_item("axe", tier, "boss", "purchase", str(tx.id))
	changed.emit()
	return {"ok": true, "axe": a, "tx": tx.id}


## Equip an owned axe by tier (selection never costs money).
func equip_tier(tier: String) -> bool:
	for a in owned_by("boss"):
		if str(a.tier) == tier:
			_set_slot("boss", "tool", str(a.id))
			changed.emit()
			return true
	return false


## The boss's chainsaw, if owned.
func boss_saw() -> Dictionary:
	var s := items_of("boss", "chainsaw")
	return s[0] if not s.is_empty() else {}


func equip_saw() -> bool:
	var s := boss_saw()
	if s.is_empty():
		return false
	_set_slot("boss", "tool", str(s.id))
	changed.emit()
	return true


## Departure policy (explicit): company kit an employee held goes back to
## camp storage, never with them and never duplicated.
func return_to_storage(owner: String) -> int:
	var n := 0
	for a in items:
		if str(a.owner) == owner:
			a.owner = "storage"
			n += 1
	slots.erase(owner)
	if n > 0:
		changed.emit()
	return n


func capture() -> Dictionary:
	return {"items": items.duplicate(true), "slots": slots.duplicate(true), "counter": _counter, "version": 2}


## Phase 3-13 saves have {"axes": [...], "equipped": id}: each axe becomes
## an item record (same id, tier, owner, receipt - once; "rack" -> storage),
## the boss's equipped axe stays equipped and each employee's best axe is
## put in their tool slot. Nothing is granted.
func restore(d: Dictionary) -> void:
	items.clear()
	slots.clear()
	var legacy := not d.has("items")
	var seen := {}
	for a in (d.get("axes", []) if legacy else d.get("items", [])):
		var r: Dictionary = (a as Dictionary).duplicate(true)
		if seen.has(str(r.get("id", ""))):
			continue                       # never duplicate an item
		seen[str(r.get("id", ""))] = true
		if not r.has("kind"):
			r["kind"] = "axe"
		if str(r.get("owner", "")) == "rack":
			r["owner"] = "storage"
		items.append(r)
	_counter = maxi(int(d.get("counter", 0)), items.size())
	if legacy:
		var eq := str(d.get("equipped", ""))
		if eq != "":
			_set_slot("boss", "tool", eq)
		var owners := {}
		for a in items:
			var o := str(a.owner)
			if o != "boss" and o != "storage" and not o.contains(":"):
				owners[o] = true
		for o in owners:
			var k := kit_of(o)
			if str(k.tool_id) != "":
				_set_slot(o, "tool", str(k.tool_id))
	else:
		for o in d.get("slots", {}):
			for s in d.slots[o]:
				var id := str(d.slots[o][s])
				var a := item(id)
				if not a.is_empty() and str(a.owner) == str(o):
					_set_slot(str(o), str(s), id)
	if items_of("boss", "axe").is_empty() and items_of("boss", "chainsaw").is_empty():
		# Never softlock: the boss always has something to cut with.
		var b := add_item("axe", "small", "boss", "starting")
		if equipped == "":
			_set_slot("boss", "tool", str(b.id))
	if equipped_item("boss", "tool").is_empty():
		unequip("boss", "tool")
	changed.emit()
