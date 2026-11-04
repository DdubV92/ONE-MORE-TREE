class_name Supplier
extends Node
## Phase 14: the camp supplier (ordered on the camper computer). Orders are
## prepaid, idempotent records; their items exist from the moment of
## payment (stable ids, owner "order:ORD-n"), arrive with a scheduled supply
## boat (owner "parcel:ORD-n", in the camp parcel locker) and move to camp
## storage exactly once when collected. Nothing is ever charged, delivered,
## collected or refunded twice: every transition checks the order state.
##
## Schedule (campaign time, daylight only, never at night):
##   supply boat runs at t = 300 s (~10:30) and t = 660 s (~15:00) each day;
##   an order must be placed CUTOFF seconds before a run to make it, else it
##   rides the next one (the first run tomorrow after the afternoon cutoff).
## No boat can arrive after the contract closes. If the contract closes with
## paid orders still undelivered, each is refunded once (state "refunded");
## orders already in the locker stay collectable. An order that couldn't
## arrive before the deadline is refused up front, never accepted.

signal changed()
signal arrived(order_id: String)

const RUNS := [300.0, 660.0]
const CUTOFF := 120.0
const DISPATCH_LEAD := 120.0       # "on the boat" this long before arrival
const MAX_LINES := 8

var orders: Array[Dictionary] = []
var _counter := 0
var _requests := {}                # request id -> order id (idempotency)
var equipment: Equipment
var wallet: Wallet
var clock: WorkdayClock
var contract: ContractService
var payroll: Payroll


func setup(eq: Equipment, w: Wallet, c: WorkdayClock, k: ContractService, p: Payroll) -> void:
	equipment = eq
	wallet = w
	clock = c
	contract = k
	payroll = p


static func hour_words(t: float) -> String:
	var h := WorkdayClock.HOUR_DAY_START + t / WorkdayClock.DAYLIGHT_SECONDS * (WorkdayClock.HOUR_DUSK_START - WorkdayClock.HOUR_DAY_START)
	var hh := int(h)
	var mm := int(round((h - hh) * 60.0 / 15.0)) * 15
	if mm == 60:
		hh += 1
		mm = 0
	return "%d:%02d" % [hh, mm]


## Next arrival for an order placed now: {"ok", "day", "t", "words", "reason"}.
func next_arrival(day := -1, t := -1.0) -> Dictionary:
	var d := clock.day if day < 0 else day
	var now := clock.t if t < 0.0 else t
	if contract and contract.is_closed():
		return {"ok": false, "reason": "The company's supply boat no longer runs: the contract has ended."}
	for r in RUNS:
		if now <= float(r) - CUTOFF:
			return {"ok": true, "day": d, "t": float(r), "words": "today's %s supply boat (day %d)" % [hour_words(r), d]}
	var nd := d + 1
	if clock.deadline_enabled and nd > WorkdayClock.CONTRACT_DAYS:
		return {"ok": false, "reason": "No supply boat can reach the island before the contract ends (the last run was day %d at %s)." % [WorkdayClock.CONTRACT_DAYS, hour_words(RUNS[RUNS.size() - 1])]}
	return {"ok": true, "day": nd, "t": float(RUNS[0]), "words": "tomorrow's %s supply boat (day %d)" % [hour_words(RUNS[0]), nd]}


func _pending_qty(k: String) -> int:
	var n := 0
	for o in orders:
		if str(o.state) in ["pending", "dispatched"]:
			for ln in o.lines:
				if str(ln.key) == k:
					n += int(ln.qty)
	return n


## Price, cash and obligations for a cart: {"ok", "total", "after", "lines",
## "warnings", "eta", "reason"}. Never reserves anything.
func quote(lines: Array) -> Dictionary:
	var total := 0
	var clean := []
	var reason := ""
	for ln in lines:
		var k := str(ln.get("key", ""))
		var q := int(ln.get("qty", 1))
		var dfn := GearCatalog.def(k)
		if dfn.is_empty() or int(dfn.price) <= 0 or q <= 0:
			reason = "Not stocked: %s." % k
			continue
		var have := equipment.count_kind(str(dfn.kind)) if str(dfn.kind) != "axe" else equipment.items.filter(func(a: Dictionary) -> bool: return str(a.get("kind", "axe")) == "axe" and str(a.tier) == str(dfn.tier) and str(a.owner) != "refunded").size()
		if have + _pending_qty(k) + q > GearCatalog.STOCK_LIMIT:
			reason = "%s: the supplier sells at most %d per camp (one per person); you have %d and %d on order." % [str(dfn.name), GearCatalog.STOCK_LIMIT, have, _pending_qty(k)]
			continue
		total += int(dfn.price) * q
		clean.append({"key": k, "qty": q, "price": int(dfn.price)})
	var eta := next_arrival()
	var after := wallet.cash - total
	var warnings: Array[String] = []
	var tonight := payroll.todays_estimate() if payroll else 0
	var owed := payroll.owed_total() if payroll else 0
	if after < tonight + owed:
		warnings.append("After this order you'd have $%s, less than tonight's payroll $%s%s. Unpaid wages become arrears; a worker leaves after one more unpaid day." % [Money.format_cents(after), Money.format_cents(tonight), (" plus $%s already owed" % Money.format_cents(owed)) if owed > 0 else ""])
	if not bool(eta.ok):
		reason = str(eta.reason)
	elif total > wallet.cash:
		reason = "Not enough cash: $%s needed, you have $%s." % [Money.format_cents(total), Money.format_cents(wallet.cash)]
	elif clean.is_empty() and reason == "":
		reason = "The order is empty."
	return {"ok": reason == "" and not clean.is_empty(), "total": total, "after": after, "lines": clean, "warnings": warnings, "eta": eta, "reason": reason, "tonight": tonight, "owed": owed}


## Places (and pays for) an order. Idempotent per `request_id`: a double
## click, a re-sent confirm or a reopened app returns the same order.
func place(lines: Array, request_id: String) -> Dictionary:
	if request_id != "" and _requests.has(request_id):
		var prev := order(str(_requests[request_id]))
		return {"ok": true, "order": prev, "repeat": true}
	if lines.size() > MAX_LINES:
		return {"ok": false, "reason": "Too many lines on one order."}
	var q := quote(lines)
	if not bool(q.ok):
		return {"ok": false, "reason": str(q.reason)}
	_counter += 1
	var oid := "ORD-%04d" % _counter
	var tx := wallet.spend(int(q.total), "purchase", oid, "Supplier order %s" % oid)
	if tx.is_empty():
		_counter -= 1
		return {"ok": false, "reason": "Payment failed."}
	var ids := []
	for ln in q.lines:
		var dfn := GearCatalog.def(str(ln.key))
		for i in int(ln.qty):
			var a := equipment.add_item(str(dfn.kind), str(dfn.tier), "order:" + oid, "order", str(tx.id))
			ids.append(str(a.id))
	var o := {"id": oid, "request": request_id, "lines": q.lines, "items": ids, "total": int(q.total), "tx": str(tx.id), "state": "pending",
		"placed": {"day": clock.day, "t": snappedf(clock.t, 0.1)}, "eta": {"day": int(q.eta.day), "t": float(q.eta.t)}, "eta_words": str(q.eta.words), "refund_tx": "", "collected": {}}
	orders.append(o)
	if request_id != "":
		_requests[request_id] = oid
	equipment.changed.emit()
	changed.emit()
	return {"ok": true, "order": o}


func order(oid: String) -> Dictionary:
	for o in orders:
		if str(o.id) == oid:
			return o
	return {}


func _due(o: Dictionary, lead := 0.0) -> bool:
	var e: Dictionary = o.eta
	return clock.day > int(e.day) or (clock.day == int(e.day) and clock.t >= float(e.t) - lead)


## Advances deliveries (called by the campaign every frame; cheap).
func tick() -> void:
	if contract and contract.is_closed():
		refund_undelivered()
		return
	for o in orders:
		match str(o.state):
			"pending":
				if _due(o, DISPATCH_LEAD):
					o.state = "dispatched"
					changed.emit()
			"dispatched":
				if _due(o):
					_arrive(o)


func _arrive(o: Dictionary) -> void:
	if str(o.state) != "dispatched" and str(o.state) != "pending":
		return
	o.state = "arrived"
	o["arrived_at"] = {"day": clock.day, "t": snappedf(clock.t, 0.1)}
	for id in o.items:
		var a := equipment.item(str(id))
		if not a.is_empty() and str(a.owner) == "order:" + str(o.id):
			a.owner = "parcel:" + str(o.id)
	equipment.changed.emit()
	changed.emit()
	arrived.emit(str(o.id))


## Moves an arrived parcel's items into camp storage, once.
func collect(oid: String) -> int:
	var o := order(oid)
	if o.is_empty() or str(o.state) != "arrived":
		return 0
	var n := 0
	for id in o.items:
		var a := equipment.item(str(id))
		if not a.is_empty() and str(a.owner) == "parcel:" + oid:
			a.owner = "storage"
			n += 1
	o.state = "collected"
	o.collected = {"day": clock.day, "t": snappedf(clock.t, 0.1)}
	equipment.changed.emit()
	changed.emit()
	return n


func collect_all() -> Array:
	var got := []
	for o in orders:
		if str(o.state) == "arrived":
			got.append([str(o.id), collect(str(o.id))])
	return got


func waiting_parcels() -> Array:
	return orders.filter(func(o: Dictionary) -> bool: return str(o.state) == "arrived")


func in_transit() -> Array:
	return orders.filter(func(o: Dictionary) -> bool: return str(o.state) in ["pending", "dispatched"])


## Contract closed with paid orders still at sea: each is refunded once.
func refund_undelivered() -> int:
	var n := 0
	for o in orders:
		if not str(o.state) in ["pending", "dispatched"] or str(o.refund_tx) != "":
			continue
		var tx := wallet.grant(int(o.total), "refund", str(o.id), "Refund: order %s never delivered (contract ended)" % str(o.id))
		o.refund_tx = str(tx.get("id", "REFUND"))
		o.state = "refunded"
		for id in o.items:
			var a := equipment.item(str(id))
			if not a.is_empty() and str(a.owner) == "order:" + str(o.id):
				a.owner = "refunded"
		n += 1
	if n > 0:
		equipment.changed.emit()
		changed.emit()
	return n


func state_words(o: Dictionary) -> String:
	match str(o.state):
		"pending":
			return "ordered · arrives on %s" % str(o.eta_words)
		"dispatched":
			return "on the supply boat now · arrives at %s" % hour_words(float(o.eta.t))
		"arrived":
			return "ARRIVED · waiting in the camp parcel locker"
		"collected":
			return "collected into camp storage (day %d)" % int(o.collected.get("day", 0))
		"refunded":
			return "refunded ($%s): the contract ended before delivery" % Money.format_cents(int(o.total))
	return str(o.state)


func capture() -> Dictionary:
	return {"orders": orders.duplicate(true), "counter": _counter, "requests": _requests.duplicate()}


func restore(d: Dictionary) -> void:
	orders.clear()
	var seen := {}
	for o in d.get("orders", []):
		if seen.has(str(o.get("id", ""))):
			continue
		seen[str(o.id)] = true
		orders.append((o as Dictionary).duplicate(true))
	_counter = maxi(int(d.get("counter", 0)), orders.size())
	_requests = (d.get("requests", {}) as Dictionary).duplicate()
	# Items follow their order state (repairs a save taken mid-transition;
	# never creates or removes an item).
	for o in orders:
		var want := ""
		match str(o.state):
			"pending", "dispatched":
				want = "order:" + str(o.id)
			"arrived":
				want = "parcel:" + str(o.id)
			"refunded":
				want = "refunded"
		if want == "":
			continue
		for id in o.items:
			var a := equipment.item(str(id))
			if not a.is_empty() and (str(a.owner).begins_with("order:") or str(a.owner).begins_with("parcel:") or str(a.owner) == "refunded"):
				a.owner = want
	changed.emit()
