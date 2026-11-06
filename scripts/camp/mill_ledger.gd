class_name MillLedger
extends RefCounted
## Phase 24: the sawmill's authoritative accounting. No visuals, no nodes:
## the Sawmill node drives it with game time and turns its events into
## presentation, so an offscreen mill behaves identically.
##
## Volume: whole litres of log (TimberService.segment_litres, taper-aware,
## from the frozen tree record). The posted recipe needs PALLET_INPUT_L
## litres of INPUT log and pays PALLET_PAY_CENTS. YIELD only decides how
## many boards are shown and how much becomes offcuts/sawdust (scrap for the
## burn pit); it is never applied to money or to the recipe (applied once).
##
## Ledger: accepted (on the rack) -> processed (through the saw, integer
## litres) -> allocated to pallets (fill) -> completed pallets. Residual
## litres stay in the open pallet across days, saves and sleep; nothing is
## lost at a recipe boundary (one log can finish a pallet and start the
## next, or several).
##
## Money: wood whose delivery was already paid before Phase 24 is
## "prepaid" - it still makes pallets, but only the payable share of each
## pallet is credited: cents = floor((payable_l x PAY + carry) / PALLET_L),
## the remainder carried to the next pallet (never lost, never rounded up).
## Each pallet has a stable id and is credited ONCE through the wallet
## (idempotent by id); reconcile() re-credits only ledger rows whose credit
## is missing (crash between completion and wallet = impossible here, but
## loading never double-pays either way).

const PALLET_INPUT_L := 1000        # litres of log per pallet (posted)
const PALLET_PAY_CENTS := 4800      # $48 per pallet (~$100 per average tree)
const YIELD := 0.55                 # boards share of log volume (presentation)
const RATE_LPS := 30.0              # saw throughput, litres of log per second
const TRANSFER_S := 3.0             # rack -> infeed rollers between logs
const RACK_CAP := 10                # pieces waiting on the feed rack
const BOARD_L := 18                 # one 2.4 m x 150 x 50 board, litres
const LEDGER_KEEP := 400

signal pallet_completed(rec: Dictionary)

var pallet_l := PALLET_INPUT_L
var pay_cents := PALLET_PAY_CENTS
var rack: Array = []                # [{sid, litres, prepaid}]
var job := {}                       # {sid, litres, prepaid, done (float l), committed (int l), boards}
var transfer_t := 0.0
var fill_payable := 0               # litres of the open pallet that pay
var fill_prepaid := 0               # litres of the open pallet already paid
var cents_carry := 0                # remainder numerator (< pallet_l)
var counter := 0                    # pallet ids
var day := 0
var pallets_total := 0
var pallets_today := 0
var overflow_today := 0             # pallets beyond the visible yard today
var earnings_today := 0
var earnings_total := 0
var accepted_l := 0
var processed_l := 0
var scrap_l := 0                    # offcuts + sawdust (fuel for the pit)
var pieces_milled := 0
var records: Array = []             # [{id, day, t, payable_l, prepaid_l, cents, tx}]
var pay_fn := Callable()            # (pallet_id, cents, note) -> tx id


func _init(input_l := PALLET_INPUT_L, cents := PALLET_PAY_CENTS) -> void:
	pallet_l = maxi(input_l, 1)
	pay_cents = maxi(cents, 0)


func has_room() -> bool:
	return rack.size() < RACK_CAP


func rack_litres() -> int:
	var t := 0
	for r in rack:
		t += int(r.litres)
	return t


func open_fill() -> int:
	return fill_payable + fill_prepaid


## A log lands on the feed rack. Positive finite volume only; a piece can
## be on the rack (or in the saw) once.
func enqueue(sid: String, litres: int, prepaid: bool) -> bool:
	if litres <= 0 or not has_room() or has_piece(sid):
		return false
	rack.append({"sid": sid, "litres": litres, "prepaid": prepaid})
	accepted_l += litres
	return true


func has_piece(sid: String) -> bool:
	if str(job.get("sid", "")) == sid:
		return true
	for r in rack:
		if str(r.sid) == sid:
			return true
	return false


func busy() -> bool:
	return not job.is_empty()


## Advance the line by dt seconds. `feeding` false = finish the current log
## but start no new one (dusk wind-down). Returns events for presentation:
## {"kind": "log_in"|"board"|"log_done"|"pallet", ...}.
func step(dt: float, feeding: bool, t_now := 0.0) -> Array:
	var ev: Array = []
	var left := maxf(dt, 0.0)
	var guard := 0
	while left > 0.0 and guard < 64:
		guard += 1
		if job.is_empty():
			if not feeding or rack.is_empty():
				transfer_t = 0.0
				break
			transfer_t += left
			if transfer_t < TRANSFER_S:
				break
			left = transfer_t - TRANSFER_S
			transfer_t = 0.0
			var r: Dictionary = rack.pop_front()
			job = {"sid": r.sid, "litres": int(r.litres), "prepaid": bool(r.prepaid), "done": 0.0, "committed": 0, "boards": 0}
			ev.append({"kind": "log_in", "sid": r.sid, "litres": int(r.litres)})
			continue
		var need := float(job.litres) - float(job.done)
		var cut := minf(need, RATE_LPS * left)
		job.done = float(job.done) + cut
		left -= cut / RATE_LPS
		# Commit whole litres to the open pallet (integer ledger).
		var whole := mini(int(floor(float(job.done) + 1e-6)), int(job.litres))
		var add := whole - int(job.committed)
		if add > 0:
			job.committed = whole
			_commit(add, bool(job.prepaid), ev, t_now)
			var boards_due := int(floor(float(whole) * YIELD / float(BOARD_L)))
			while int(job.boards) < boards_due:
				job.boards = int(job.boards) + 1
				ev.append({"kind": "board", "sid": job.sid})
		if int(job.committed) >= int(job.litres):
			scrap_l += maxi(int(job.litres) - int(job.boards) * BOARD_L, 0)
			pieces_milled += 1
			ev.append({"kind": "log_done", "sid": job.sid, "litres": int(job.litres)})
			job = {}
	return ev


func _commit(litres: int, prepaid: bool, ev: Array, t_now: float) -> void:
	processed_l += litres
	var left := litres
	while left > 0:
		var room := pallet_l - open_fill()
		var take := mini(room, left)
		if prepaid:
			fill_prepaid += take
		else:
			fill_payable += take
		left -= take
		if open_fill() >= pallet_l:
			ev.append(_complete(t_now))


func _complete(t_now: float) -> Dictionary:
	counter += 1
	var num := fill_payable * pay_cents + cents_carry
	var cents := num / pallet_l
	cents_carry = num % pallet_l
	var rec := {"id": "PAL-%06d" % counter, "day": day, "t": snappedf(t_now, 0.01), "payable_l": fill_payable, "prepaid_l": fill_prepaid, "cents": cents, "tx": ""}
	fill_payable = 0
	fill_prepaid = 0
	pallets_total += 1
	pallets_today += 1
	if pallets_today > CampLayout.MILL_DISPLAY_CAP:
		overflow_today += 1
	earnings_today += cents
	earnings_total += cents
	if pay_fn.is_valid() and cents > 0:
		rec.tx = str(pay_fn.call(str(rec.id), cents, "Lumber pallet %s (%d L of logs)" % [rec.id, pallet_l]))
	records.append(rec)
	if records.size() > LEDGER_KEEP:
		records.pop_front()
	pallet_completed.emit(rec)
	var e := rec.duplicate()
	e["kind"] = "pallet"
	return e


## Visible pallets in the yard today (bounded; the rest are overflow).
func displayed() -> int:
	return mini(pallets_today, CampLayout.MILL_DISPLAY_CAP)


## Morning: the lumber boat took yesterday's pallets (they were paid when
## finished). The open pallet, the rack and the log in the saw stay.
func new_day(d: int) -> Dictionary:
	var out := {"day": day, "pallets": pallets_today, "overflow": overflow_today, "earnings": earnings_today}
	day = d
	pallets_today = 0
	overflow_today = 0
	earnings_today = 0
	return out


## Credits any completed pallet whose wallet credit is missing (by id; the
## wallet refuses a second credit for the same id).
func reconcile() -> int:
	var n := 0
	if not pay_fn.is_valid():
		return 0
	for r in records:
		if int(r.cents) > 0 and str(r.tx) == "":
			r.tx = str(pay_fn.call(str(r.id), int(r.cents), "Lumber pallet %s (reconciled)" % r.id))
			if str(r.tx) != "":
				n += 1
	return n


func capture() -> Dictionary:
	var j := job.duplicate()
	if not j.is_empty():
		j.done = snappedf(float(j.done), 0.001)
	return {"version": 1, "pallet_l": pallet_l, "pay_cents": pay_cents, "rack": rack.duplicate(true), "job": j, "transfer_t": snappedf(transfer_t, 0.01),
		"fill_payable": fill_payable, "fill_prepaid": fill_prepaid, "cents_carry": cents_carry, "counter": counter, "day": day,
		"pallets_total": pallets_total, "pallets_today": pallets_today, "overflow_today": overflow_today, "earnings_today": earnings_today, "earnings_total": earnings_total,
		"accepted_l": accepted_l, "processed_l": processed_l, "scrap_l": scrap_l, "pieces_milled": pieces_milled, "records": records.duplicate(true)}


func restore(d: Dictionary) -> void:
	pallet_l = maxi(int(d.get("pallet_l", PALLET_INPUT_L)), 1)
	pay_cents = maxi(int(d.get("pay_cents", PALLET_PAY_CENTS)), 0)
	rack = (d.get("rack", []) as Array).duplicate(true)
	job = (d.get("job", {}) as Dictionary).duplicate(true)
	transfer_t = float(d.get("transfer_t", 0.0))
	fill_payable = int(d.get("fill_payable", 0))
	fill_prepaid = int(d.get("fill_prepaid", 0))
	cents_carry = int(d.get("cents_carry", 0))
	counter = int(d.get("counter", 0))
	day = int(d.get("day", 0))
	pallets_total = int(d.get("pallets_total", 0))
	pallets_today = int(d.get("pallets_today", 0))
	overflow_today = int(d.get("overflow_today", 0))
	earnings_today = int(d.get("earnings_today", 0))
	earnings_total = int(d.get("earnings_total", 0))
	accepted_l = int(d.get("accepted_l", 0))
	processed_l = int(d.get("processed_l", 0))
	scrap_l = int(d.get("scrap_l", 0))
	pieces_milled = int(d.get("pieces_milled", 0))
	records = (d.get("records", []) as Array).duplicate(true)
