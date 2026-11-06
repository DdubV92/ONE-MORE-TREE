class_name Wallet
extends Node
## The ONE authoritative payment service (Phase 3). Integer cents only.
##
## Income: `credit_receipt()` is the only way timber earns money. It is
## subscribed once to TimberService.delivery_accepted and is idempotent per
## receipt id: a receipt is verified against the timber ledger (exists,
## segment genuinely accepted) and credited at most once, ever. The receipt
## records the paying transaction id, so reloads, reports and repeated
## signals can never pay again.
##
## Spending: `spend()` never lets cash go negative. Unpaid wages are
## liabilities in Payroll, not negative cash.

signal cash_changed(cents: int)
signal transaction(tx: Dictionary)

var cash := 0
var transactions: Array[Dictionary] = []
var credited := {}                 # receipt id -> transaction id
var _tx_counter := 0
var timber: TimberService
var clock: WorkdayClock
var enabled := true                # false in Preview unless a test route enables it


func setup(t: TimberService, c: WorkdayClock) -> void:
	timber = t
	clock = c
	if timber and not timber.delivery_accepted.is_connected(_on_delivery):
		timber.delivery_accepted.connect(_on_delivery)


func _on_delivery(receipt: Dictionary) -> void:
	if enabled:
		credit_receipt(str(receipt.get("id", "")))


func _new_tx(kind: String, amount: int, ref: String, note: String) -> Dictionary:
	_tx_counter += 1
	cash += amount
	var tx := {"id": "TX-%06d" % _tx_counter, "kind": kind, "amount": amount, "ref": ref, "note": note, "day": clock.day if clock else 0, "t": snappedf(clock.t, 0.01) if clock else 0.0, "balance": cash}
	transactions.append(tx)
	transaction.emit(tx)
	cash_changed.emit(cash)
	return tx


## Credits one accepted delivery receipt exactly once. Returns the paying
## transaction id ("" if refused).
func credit_receipt(receipt_id: String, kind := "delivery") -> String:
	if receipt_id == "" or credited.has(receipt_id) or timber == null:
		return str(credited.get(receipt_id, ""))
	var r := _find_receipt(receipt_id)
	if r.is_empty():
		push_warning("Wallet: unknown receipt %s refused" % receipt_id)
		return ""
	# Phase 24: wood accepted under the mill economy is paid when the sawmill
	# finishes a pallet from it, never on delivery (one payment per log).
	if str(r.get("pay", "")) == "mill":
		r["settled"] = true
		r["deferred"] = true
		return ""
	var seg := timber.segment(str(r.sid))
	if seg.is_empty() or int(seg.state) < TimberService.Seg.ACCEPTED_QUEUED or str(seg.receipt) != receipt_id:
		push_warning("Wallet: receipt %s is not a genuine acceptance" % receipt_id)
		return ""
	var tx := _new_tx(kind, int(r.cents), receipt_id, "Delivered %s (tree %d)" % [r.sid, int(r.tree)])
	credited[receipt_id] = tx.id
	r["settled"] = true
	r["tx"] = tx.id
	return tx.id


func _find_receipt(receipt_id: String) -> Dictionary:
	for r in timber.receipts:
		if str(r.id) == receipt_id:
			return r
	return {}


## Recoverable idempotent settlement (used on load and after migration):
## credits any genuine receipt that has no transaction yet; marks receipts
## whose transaction exists. Never pays twice.
func reconcile_receipts(kind := "delivery") -> int:
	if timber == null:
		return 0
	var n := 0
	for r in timber.receipts:
		var rid := str(r.id)
		if credited.has(rid):
			r["settled"] = true
			r["tx"] = credited[rid]
		elif str(r.get("pay", "")) == "mill":
			r["settled"] = true
			r["deferred"] = true
		elif credit_receipt(rid, kind) != "":
			n += 1
	return n


## Phase 24: one completed lumber pallet, credited once ever (by pallet id).
func credit_pallet(pallet_id: String, cents: int, note: String) -> String:
	if pallet_id == "" or cents <= 0:
		return ""
	var key := "pallet:" + pallet_id
	if credited.has(key):
		return str(credited[key])
	var tx := _new_tx("lumber", cents, pallet_id, note)
	credited[key] = tx.id
	return str(tx.id)


func can_afford(cents: int) -> bool:
	return cents <= cash


## Spends cash. Refuses (returns {}) rather than going negative.
func spend(cents: int, kind: String, ref: String, note: String) -> Dictionary:
	if cents < 0 or cents > cash:
		return {}
	return _new_tx(kind, -cents, ref, note)


func grant(cents: int, kind: String, ref: String, note: String) -> Dictionary:
	return _new_tx(kind, maxi(cents, 0), ref, note)


func income_between(day_from: int, day_to: int, kind := "delivery") -> int:
	var s := 0
	for tx in transactions:
		if str(tx.kind) == kind and int(tx.day) >= day_from and int(tx.day) <= day_to:
			s += int(tx.amount)
	return s


func capture() -> Dictionary:
	return {"cash": cash, "transactions": transactions.duplicate(true), "credited": credited.duplicate(), "tx_counter": _tx_counter}


func restore(d: Dictionary) -> void:
	cash = int(d.get("cash", 0))
	transactions.clear()
	for tx in d.get("transactions", []):
		transactions.append(tx)
	credited = (d.get("credited", {}) as Dictionary).duplicate()
	_tx_counter = maxi(int(d.get("tx_counter", 0)), transactions.size())
	# Cash must equal the ledger; a mismatch means a damaged save: trust the
	# ledger (sum of transactions) and log it.
	var sum := 0
	for tx in transactions:
		sum += int(tx.amount)
	if sum != cash and not transactions.is_empty():
		push_warning("Wallet: cash %d != ledger %d; using ledger" % [cash, sum])
		cash = sum
	cash_changed.emit(cash)
