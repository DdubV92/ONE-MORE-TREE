class_name Payroll
extends Node
## Wages and arrears (Phase 3). Each ACTIVE employee earns exactly $300 for
## each active working day. Settlement at the end of a day creates one
## liability per active employee-day, due at the end of the FOLLOWING
## workday, then pays what cash allows, oldest due first (deterministic).
## A liability still unpaid after its due day closes produces exactly one
## QuitDueToArrears request for that employee (Phase 4 performs the actual
## departure). Partial payments never move a due date. Cash never goes
## negative: unpaid wages stay here as liabilities.
##
## Employee records exist from the first day of a campaign. Until Phase 4
## brings real workers, the two starting employees are labeled
## "pending_integration": they are not charged (nobody is working), and the
## UI says so. Development fixtures mark them "active" in the Day & Economy
## Test only.

signal quit_due_to_arrears(employee_id: String)
signal liabilities_changed()

const ACTIVE := "active"
const PENDING := "pending_integration"
const QUIT_REQUESTED := "quit_requested"
const DEPARTED := "departed"

var employees: Array[Dictionary] = []
var liabilities: Array[Dictionary] = []
var settlements := {}              # day (str) -> settlement id
var quit_requests := {}            # employee id -> day requested
var wallet: Wallet
var config: EconomyConfig


func setup(w: Wallet, cfg: EconomyConfig) -> void:
	wallet = w
	config = cfg


static func starting_crew() -> Array[Dictionary]:
	# Two starting employees (Phase 4 gives them bodies, traits in play,
	# dialogue). Names/traits are data now.
	var out: Array[Dictionary] = []
	out.append({"id": "EMP-01", "name": "Marta Kell", "traits": ["hard_working"], "status": PENDING, "hired_day": 1, "active_days": [], "axe": ""})
	out.append({"id": "EMP-02", "name": "Dale Ostrow", "traits": ["stronger"], "status": PENDING, "hired_day": 1, "active_days": [], "axe": ""})
	return out


func employee(id: String) -> Dictionary:
	for e in employees:
		if str(e.id) == id:
			return e
	return {}


func active_employees() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in employees:
		if str(e.status) == ACTIVE:
			out.append(e)
	return out


func wage() -> int:
	return config.wage_cents if config else 30000


## Today's estimated payroll (what settlement will add tonight).
func todays_estimate() -> int:
	var n := 0
	for e in employees:
		if str(e.status) in [ACTIVE, "departing"]:
			n += 1
	return n * wage()


func owed_total() -> int:
	var s := 0
	for l in liabilities:
		s += int(l.amount) - int(l.paid)
	return s


func owed_for(emp_id: String) -> int:
	var s := 0
	for l in liabilities:
		if str(l.emp) == emp_id:
			s += int(l.amount) - int(l.paid)
	return s


## Earliest due day among this employee's unpaid liabilities (0 = none).
func due_day_for(emp_id: String) -> int:
	var d := 0
	for l in liabilities:
		if str(l.emp) == emp_id and int(l.paid) < int(l.amount):
			d = int(l.due_day) if d == 0 else mini(d, int(l.due_day))
	return d


## End-of-day settlement for `day`. Idempotent: a day settles once.
## Example: day 7 closes with an employee's $300 unpaid (due day 8). At day
## 8's close they are owed day 7 + day 8 ($600); unless all of it is paid,
## one QuitDueToArrears request is emitted.
## Returns a summary dictionary (also stored in the report).
func settle_day(day: int) -> Dictionary:
	var key := str(day)
	if settlements.has(key):
		return {"settlement": settlements[key], "repeat": true, "new_liabilities": 0, "paid": 0, "quits": []}
	var sid := "SETTLE-D%02d" % day
	# Employees entering this settlement already owed from an earlier day are
	# in their one-day grace: tonight everything they are owed (including
	# today's wage) is due.
	var in_grace := {}
	for l in liabilities:
		if int(l.paid) < int(l.amount) and int(l.day) < day:
			in_grace[str(l.emp)] = true
	var new_l := 0
	for e in employees:
		# Phase 4: a person earns the day if they were employed during that
		# day's daylight (recorded in worked_days) - even if fired or quitting
		# before the night. Development fixtures count as working.
		var worked: bool = day in (e.get("worked_days", []) as Array) or (str(e.status) == ACTIVE and bool(e.get("fixture", false))) or (str(e.status) == ACTIVE and not e.has("worked_days"))
		if not worked:
			continue
		var lid := "WAGE-D%02d-%s" % [day, e.id]
		if _liability(lid).is_empty():
			var due := day if in_grace.has(str(e.id)) else day + 1
			liabilities.append({"id": lid, "emp": e.id, "day": day, "due_day": due, "amount": wage(), "paid": 0})
			(e.active_days as Array).append(day)
			new_l += 1
	var paid := pay_oldest(-1, sid)
	# Anything still unpaid at or past its due day -> one quit request.
	var quits: Array[String] = []
	for e in employees:
		var eid := str(e.id)
		if quit_requests.has(eid):
			continue
		for l in liabilities:
			if str(l.emp) == eid and int(l.paid) < int(l.amount) and int(l.due_day) <= day:
				quit_requests[eid] = day
				if str(e.status) != "departed" and str(e.status) != "departing":
					e.status = QUIT_REQUESTED
				quits.append(eid)
				quit_due_to_arrears.emit(eid)
				break
	settlements[key] = sid
	liabilities_changed.emit()
	return {"settlement": sid, "repeat": false, "new_liabilities": new_l, "paid": paid, "quits": quits}


## Pays unpaid liabilities oldest-due first, up to `limit` cents (-1 = all
## that cash allows). Returns cents paid.
func pay_oldest(limit := -1, ref := "PAY") -> int:
	var order := liabilities.filter(func(l: Dictionary) -> bool: return int(l.paid) < int(l.amount))
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return [int(a.due_day), str(a.id)] < [int(b.due_day), str(b.id)])
	var total := 0
	for l in order:
		var need := int(l.amount) - int(l.paid)
		var can := mini(need, wallet.cash)
		if limit >= 0:
			can = mini(can, limit - total)
		if can <= 0:
			break
		var tx := wallet.spend(can, "wage", str(l.id), "Wages %s (day %d)" % [l.emp, int(l.day)])
		if tx.is_empty():
			break
		l.paid = int(l.paid) + can
		total += can
	if total > 0:
		liabilities_changed.emit()
	return total


## Manual "pay this employee" action (oldest of theirs first).
func pay_employee(emp_id: String) -> int:
	var total := 0
	for l in liabilities:
		if str(l.emp) != emp_id or int(l.paid) >= int(l.amount):
			continue
		var can := mini(int(l.amount) - int(l.paid), wallet.cash)
		if can <= 0:
			break
		if wallet.spend(can, "wage", str(l.id), "Wages %s (day %d)" % [l.emp, int(l.day)]).is_empty():
			break
		l.paid = int(l.paid) + can
		total += can
	liabilities_changed.emit()
	return total


func _liability(id: String) -> Dictionary:
	for l in liabilities:
		if str(l.id) == id:
			return l
	return {}


func capture() -> Dictionary:
	return {"employees": employees.duplicate(true), "liabilities": liabilities.duplicate(true), "settlements": settlements.duplicate(), "quit_requests": quit_requests.duplicate()}


func restore(d: Dictionary) -> void:
	employees.clear()
	for e in d.get("employees", []):
		employees.append(e)
	liabilities.clear()
	for l in d.get("liabilities", []):
		liabilities.append(l)
	settlements = (d.get("settlements", {}) as Dictionary).duplicate()
	quit_requests = (d.get("quit_requests", {}) as Dictionary).duplicate()
	liabilities_changed.emit()
