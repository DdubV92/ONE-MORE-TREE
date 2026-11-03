class_name Equipment
extends Node
## Owned axe instances (Phase 3). Each axe has an id and one owner at a time
## ("boss", an employee id, or "rack"). The boss can only equip an axe they
## own; buying is an explicit, one-time, receipted wallet transaction.
## The starting small axe cannot be sold or lost (no softlock at $0).
## Cutting rate comes from TreeWorkConfig tier rates (x1.00/x1.40/x1.96) and
## a single Hard-working multiplier for employees - never from here.

signal changed()

const TIERS := ["small", "medium", "large"]

var axes: Array[Dictionary] = []
var equipped := ""                 # axe id the boss holds
var _counter := 0
var wallet: Wallet
var config: EconomyConfig


func setup(w: Wallet, cfg: EconomyConfig) -> void:
	wallet = w
	config = cfg


## New campaign: the boss's small axe, plus reserved starting axes for the
## two starting employees (handed over when they arrive in Phase 4).
func init_new(employee_ids: Array) -> void:
	axes.clear()
	_counter = 0
	var boss := _add("small", "boss", "starting")
	for eid in employee_ids:
		_add("small", str(eid), "starting")
	equipped = str(boss.id)
	changed.emit()


func _add(tier: String, owner: String, source: String, receipt := "") -> Dictionary:
	_counter += 1
	var a := {"id": "AXE-%04d" % _counter, "tier": tier, "owner": owner, "source": source, "receipt": receipt}
	axes.append(a)
	return a


func owned_by(owner: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in axes:
		if str(a.owner) == owner:
			out.append(a)
	return out


func boss_has(tier: String) -> bool:
	for a in owned_by("boss"):
		if str(a.tier) == tier:
			return true
	return false


func equipped_tier() -> String:
	for a in axes:
		if str(a.id) == equipped:
			return str(a.tier)
	return "small"


func price(tier: String) -> int:
	return int(config.axe_price_cents.get(tier, 0)) if config else 0


## Buys one axe for the boss. Returns {"ok", "reason", "axe"}.
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
	var a := _add(tier, "boss", "purchase", str(tx.id))
	changed.emit()
	return {"ok": true, "axe": a, "tx": tx.id}


## Equip an owned axe by tier (selection never costs money).
func equip_tier(tier: String) -> bool:
	for a in owned_by("boss"):
		if str(a.tier) == tier:
			equipped = str(a.id)
			changed.emit()
			return true
	return false


func capture() -> Dictionary:
	return {"axes": axes.duplicate(true), "equipped": equipped, "counter": _counter}


func restore(d: Dictionary) -> void:
	axes.clear()
	for a in d.get("axes", []):
		axes.append(a)
	equipped = str(d.get("equipped", ""))
	_counter = maxi(int(d.get("counter", 0)), axes.size())
	if axes.is_empty() or not boss_has("small"):
		# Never softlock: the boss always has the starting small axe.
		var a := _add("small", "boss", "starting")
		if equipped == "":
			equipped = str(a.id)
	changed.emit()
