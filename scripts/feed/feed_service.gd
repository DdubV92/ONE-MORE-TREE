class_name FeedService
extends Node
## Phase 17: the fictional internet on the camper computer (Mail, News,
## Forums, Archives) - an authored, offline, deterministic bank
## (data/feed/*.json, accounts in data/feed/accounts.json; format in
## docs/editorial/FEED_BIBLE.md) PUBLISHED by the authoritative campaign
## clock, never generated:
##   - a unit of day D appears at its slot time: daylight `at` s into the
##     day, dusk 900 + `at`, night once the boss has been awake `at` s
##     into the (bounded) night; whatever is left of a day publishes when
##     the day ends at sleep (so sleeping never loses the story, and the
##     reader shows a catch-up digest instead of a burst of alerts);
##   - survival days 31-35 follow the continuous hunt clock;
##   - at most NIGHT_CAP units per day; extras roll to the next day;
##   - `mx:` branches are fixed per campaign seed; `if:`/`unless:` flags
##     are decided ONCE when the unit falls due (refresh never rerolls);
##     a reply whose parent wasn't published is skipped with it;
##   - edits apply `after_s` seconds after publication; removed posts show
##     a moderation note, not the text;
##   - hooks: cl01 (the window warning) asks the director for a safe
##     reservation at commit time and uses its authored fallback when it
##     can't be staged; other hooks are recorded as opportunities for the
##     Phase 19 encounter catalog (reading never forces a scare).
## Reading is live world time and optional: nothing here blocks wages,
## bedtime, completion or rescue.

const DIR := "res://data/feed"
const NIGHT_CAP := 240
const SLOT_BASE := {"day": 0.0, "dusk": 900.0, "night": 1200.0}
const SLOT_ORDER := {"day": 0, "dusk": 1, "night": 2}
const NOTICE_GAP := 180.0
const APP_KINDS := {"Mail": ["mail"], "News": ["news", "advisory"], "Forums": ["forum"], "Archives": ["archive"]}

signal published(ids: Array)

static var _bank_units: Array = []      # all units, sorted by schedule
static var _bank_by_id := {}
static var _accounts := {}
static var _problems: PackedStringArray = []

var clock := 0.0                # feed seconds (simulation time)
var cursor := 0                 # next index in the schedule
var pub := {}                   # id -> feed clock when published
var pub_day := {}               # id -> campaign day published on
var skipped := {}               # id -> reason (branch/flag/parent/cap)
var deferred: Array = []        # ids deferred by the nightly cap
var day_count := {}             # "day" -> units published that day
var read := {}                  # id -> true
var bookmarks := {}             # thread key -> true
var positions := {}             # "app" / thread key -> scroll / view state
var last_visit := {}            # app -> feed clock of the last visit
var hooks := {}                 # hook unit id -> "staged" / "fallback" / "hint"
var opportunities: Array = []   # [{hook, id, day}] for the Phase 19 director
var read_at_night := {}         # "day" -> true (the late_reader flag)
var _last_notice := -9999.0
var _pending_notice := 0
var _tick := 0.0


static func load_bank() -> void:
	if not _bank_units.is_empty():
		return
	_problems.clear()
	var acc: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/accounts.json"))
	if typeof(acc) == TYPE_DICTIONARY:
		for a in (acc as Dictionary).get("accounts", []):
			_accounts[str(a.id)] = a
	var d := DirAccess.open(DIR)
	if d == null:
		_problems.append("no feed directory")
		return
	var names := Array(d.get_files()).filter(func(f: String) -> bool: return f.ends_with(".json") and f != "accounts.json")
	names.sort()
	for f in names:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/" + f))
		if typeof(data) != TYPE_DICTIONARY:
			_problems.append("%s: invalid JSON" % f)
			continue
		for u in (data as Dictionary).get("units", []):
			var id := str(u.get("id", ""))
			if id == "" or _bank_by_id.has(id):
				_problems.append("%s: missing/duplicate id %s" % [f, id])
				continue
			_bank_by_id[id] = u
			_bank_units.append(u)
	_bank_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _key(a) < _key(b))


static func _key(u: Dictionary) -> float:
	return float(u.get("day", 0)) * 10000.0 + float(SLOT_BASE.get(str(u.get("slot", "day")), 0.0)) + float(u.get("at", 0))


static func unit(id: String) -> Dictionary:
	return _bank_by_id.get(id, {})


static func account(id: String) -> Dictionary:
	return _accounts.get(id, {})


static func bank_size() -> int:
	return _bank_units.size()


static func bank_problems() -> PackedStringArray:
	return _problems


func _ready() -> void:
	load_bank()


# ----------------------------------------------------------- the clock

## Where the campaign is now, as (day, seconds into the publishing day).
## Contract nights are bounded at nightfall, so night progress is the
## boss's awake time at night (WorkdayClock.night_exposure).
func now_key() -> float:
	var cs: CampaignService = Game.campaign
	if Game.hunt and Game.hunt.hunt_active():
		var hd := maxi(int(Game.hunt.hunt_day), 31)
		return float(hd) * 10000.0 + float(Game.hunt.t)
	if cs == null:
		return 0.0
	var c := cs.clock
	# The publishing day keeps its authored shape (daylight 0-900, dusk
	# 900-1200, night 1200+); the workday maps onto it proportionally
	# (Phase 22: 20 minutes of daylight). Hunt days use hunt time above.
	var s := c.t * 900.0 / WorkdayClock.DAYLIGHT_SECONDS
	if c.t >= WorkdayClock.DAYLIGHT_SECONDS:
		s = 900.0 + (c.t - WorkdayClock.DAYLIGHT_SECONDS) * 300.0 / WorkdayClock.DUSK_SECONDS
	if c.phase() == WorkdayClock.Phase.NIGHT:
		s = 1200.0 + minf(c.night_exposure, 479.0)
	return float(c.day) * 10000.0 + s


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var cs: CampaignService = Game.campaign
	if cs == null or not cs.active:
		return
	clock += delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	advance_to(now_key())
	_maybe_notice()


## Publishes everything due up to `key` (idempotent: each unit once).
func advance_to(key: float) -> Array:
	var out: Array = []
	# Units the cap pushed out of an earlier day go first.
	var today := int(key / 10000.0)
	if not deferred.is_empty() and int(day_count.get(str(today), 0)) < NIGHT_CAP:
		var keep: Array = []
		for id in deferred:
			if int(day_count.get(str(today), 0)) < NIGHT_CAP:
				_publish(str(id), today)
				out.append(id)
			else:
				keep.append(id)
		deferred = keep
	while cursor < _bank_units.size():
		var u: Dictionary = _bank_units[cursor]
		if _key(u) > key:
			break
		cursor += 1
		var id := str(u.id)
		if pub.has(id) or skipped.has(id):
			continue
		var why := _gate(u)
		if why != "":
			skipped[id] = why
			continue
		if str(u.get("hook", "")) != "":
			if not _resolve_hook(u):
				continue
		if int(day_count.get(str(today), 0)) >= NIGHT_CAP:
			deferred.append(id)
			continue
		_publish(id, today)
		out.append(id)
	if not out.is_empty():
		_pending_notice += out.size()
		published.emit(out)
	return out


## The day ended at sleep: everything left of it publishes now (counted
## on that day), so the next morning reads as a catch-up, not a burst.
func on_day_end(day: int) -> Array:
	return advance_to(float(day) * 10000.0 + 1200.0 + 479.0)


func _publish(id: String, day: int) -> void:
	pub[id] = clock
	pub_day[id] = day
	day_count[str(day)] = int(day_count.get(str(day), 0)) + 1


func _gate(u: Dictionary) -> String:
	var b := str(u.get("branch", ""))
	if b.begins_with("mx:"):
		var parts := b.split(":")
		if parts.size() == 3 and mx_choice(parts[1]) != parts[2]:
			return "other branch"
	elif b.begins_with("if:"):
		if not flag(b.substr(3)):
			return "flag " + b
	elif b.begins_with("unless:"):
		if flag(b.substr(7)):
			return "flag " + b
	elif b == "fallback:cl01":
		return "fallback (only if cl01 fails)"
	var p := str(u.get("parent", ""))
	if p != "" and not pub.has(p):
		return "parent not published"
	return ""


func _seed() -> int:
	return int(World.manifest.get("world_seed", 1)) if World.manifest else 1


func mx_choice(group: String) -> String:
	var cs: CampaignService = Game.campaign
	var cid := str(cs.get("campaign_id")) if cs and cs.get("campaign_id") != null else ""
	return "a" if (hash("mx:%s:%d:%s" % [group, _seed(), cid]) & 1) == 0 else "b"


## World flags the authored branches may depend on (decided when due).
func flag(f: String) -> bool:
	var cs: CampaignService = Game.campaign
	match f:
		"wages_owed":
			return cs != null and cs.payroll.owed_total() > 0
		"worker_left":
			return cs != null and cs.payroll.employees.any(func(e: Dictionary) -> bool: return str(e.status) == "departed")
		"dog_rescued":
			return Game.dog_rescue != null and str(Game.dog_rescue.get("state")) in ["DONE", "done", "RESOLVED", "resolved"]
		"truck_owned":
			return Game.vehicles != null and not Game.vehicles.trucks.is_empty()
		"saw_owned":
			return cs != null and cs.equipment != null and cs.equipment.items.any(func(it: Dictionary) -> bool: return str(it.get("kind", "")) == "chainsaw" and not str(it.get("owner", "")).begins_with("order:") and str(it.get("owner", "")) != "refunded")
		"cleared25", "cleared50", "cleared75":
			var n := int(f.substr(7))
			return cs != null and 100.0 * float(cs.contract.counts().get("felled", 0)) / maxf(float(World.tree_count()), 1.0) >= n
		"late_reader":
			var d := cs.clock.day if cs else 1
			for k in read_at_night:
				if int(k) < d:
					return true
			return false
		"night_event":
			return Game.director != null and int(Game.director.get("night_active_t")) > 0 and not (Game.director.get("observed") as Dictionary).is_empty()
		"hunt":
			return Game.hunt != null and Game.hunt.hunt_active()
		"rescue":
			return Game.hunt != null and str(Game.hunt.ship_state) in ["approaching", "docked"]
	return false


# ------------------------------------------------------------ hooks

## cl01 needs a safe reservation from the director at commit time; if it
## can't be staged the authored fallback continuation publishes instead.
## Other hooks publish normally and are recorded as opportunities.
func _resolve_hook(u: Dictionary) -> bool:
	var id := str(u.id)
	var h := str(u.hook)
	if h != "cl01":
		hooks[id] = "hint"
		opportunities.append({"hook": h, "id": id, "day": int(u.get("day", 0))})
		if Game.director and Game.director.has_method("computer_hint"):
			Game.director.computer_hint(h, id)
		return true
	var res := window_reservation()
	if bool(res.ok) and Game.director and Game.director.stage_window_encounter(res):
		hooks[id] = "staged"
		return true
	if bool(res.ok):
		res = {"ok": false, "reason": "no ordinary window encounter could be placed"}
	hooks[id] = "fallback: " + str(res.reason)
	skipped[id] = "cl01 not stageable: " + str(res.reason)
	for f in _bank_units:
		if str(f.get("branch", "")) == "fallback:cl01" and str(f.get("thread", "")) == str(u.thread) and not pub.has(str(f.id)):
			_publish(str(f.id), int(now_key() / 10000.0))
	return false


## Can an ordinary Terror be staged outside the camper's right-hand
## window right now? Checks the reader, placement, curtains, attention,
## other witnesses and the director's pacing. Never inside the camper,
## never moves the camera.
func window_reservation() -> Dictionary:
	var desk: Node = Game.desk
	if desk == null or not bool(desk.get("seated")):
		return {"ok": false, "reason": "the boss isn't reading at the desk"}
	if bool(desk.get("glancing")):
		return {"ok": false, "reason": "already looking out of the window"}
	if Game.hunt and Game.hunt.hunt_active():
		return {"ok": false, "reason": "the hunt has its own rules"}
	var cs: CampaignService = Game.campaign
	if cs == null or cs.clock.phase() != WorkdayClock.Phase.NIGHT:
		return {"ok": false, "reason": "not night"}
	var dir: TerrorDirector = Game.director
	if dir == null or dir.active != null:
		return {"ok": false, "reason": "the director is busy"}
	if dir.has_method("peak_available") and not dir.peak_available():
		return {"ok": false, "reason": "global pacing (refractory)"}
	# Phase 11 reserved staging spots outside the desk's right-hand window.
	var stages := get_tree().get_nodes_in_group("desk_window_stage")
	if stages.is_empty():
		return {"ok": false, "reason": "no staging spot outside the window"}
	var mk: Node3D = stages[int(clock) % stages.size()]
	var spot := mk.global_position
	for c in get_tree().get_nodes_in_group("camper_curtain"):
		if (c as Node3D).global_position.distance_to(spot) < 6.0 and bool(c.get("closed")):
			return {"ok": false, "reason": "curtains closed"}
	if Game.safety and Game.safety.query(spot + Vector3(0, 1, 0)).safe and Game.safety.query(spot + Vector3(0, 1, 0)).reason == SafetyService.Reason.CAMPER_INTERIOR:
		return {"ok": false, "reason": "the spot is inside the camper"}
	if Game.crew:
		for w in Game.crew.workers.values():
			var wk := w as Worker
			if wk.activity != "sleep" and wk.global_position.distance_to(spot) < 25.0:
				return {"ok": false, "reason": "a worker would see it plainly"}
	return {"ok": true, "spot": spot, "marker": mk.name}


# --------------------------------------------------------- reading

func visible(id: String) -> bool:
	return pub.has(id)


## Text as shown now: edits applied after their delay, moderation notes.
func shown_text(u: Dictionary) -> String:
	var st := str(u.get("status", "ok"))
	if st == "removed":
		return "[Removed by a moderator.]"
	var e: Dictionary = u.get("edit", {})
	var t := str(u.get("text", ""))
	if not e.is_empty() and pub.has(str(u.id)) and clock - float(pub[str(u.id)]) >= float(e.get("after_s", 0)):
		t = str(e.get("text", t)) + "\n(" + str(e.get("note", "edited")) + ")"
	if st == "retracted":
		t += "\n[The author has retracted this.]"
	return t


func author_name(u: Dictionary) -> String:
	var a := str(u.get("author", ""))
	var acc := account(a)
	if not acc.is_empty():
		return str(acc.get("handle", a))
	return {"courier": "The Ammet Courier", "soundfm": "Sound FM News", "weypost": "Weyhaven Evening Post", "tradejournal": "Timber & Land Trade Journal", "met": "Marrow Sound Met Office", "ferry": "Sound Lines", "power": "Sound Power Co-op", "council": "Ammet District Council", "coast": "Coastguard"}.get(a, a)


## Threads (or articles / mail subjects) visible in an app, newest first.
func threads(app: String, limit := 60, offset := 0) -> Array:
	var kinds: Array = APP_KINDS.get(app, [])
	var by := {}
	for id in pub:
		var u := unit(str(id))
		if u.is_empty() or not str(u.kind) in kinds:
			continue
		var k := thread_key(u)
		if not by.has(k):
			by[k] = {"key": k, "site": str(u.site), "thread": str(u.thread), "title": "", "latest": 0.0, "count": 0, "unread": 0, "kind": str(u.kind)}
		var t: Dictionary = by[k]
		t.count += 1
		if not read.has(id):
			t.unread += 1
		t.latest = maxf(float(t.latest), float(pub[id]))
		if str(u.get("title", "")) != "" and str(t.title) == "":
			t.title = str(u.title)
	var arr := by.values()
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.latest) > float(b.latest))
	return arr.slice(offset, offset + limit)


static func thread_key(u: Dictionary) -> String:
	return "%s/%s" % [str(u.get("site", "")), str(u.get("thread", ""))]


## The visible units of one thread in order, with reply depth.
func thread_units(key: String) -> Array:
	var out: Array = []
	for id in pub:
		var u := unit(str(id))
		if not u.is_empty() and thread_key(u) == key:
			out.append(u)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _key(a) < _key(b) or (_key(a) == _key(b) and str(a.id) < str(b.id)))
	return out


func depth(u: Dictionary) -> int:
	var d := 0
	var p := str(u.get("parent", ""))
	while p != "" and d < 6:
		d += 1
		p = str(unit(p).get("parent", ""))
	return d


func mark_read(ids: Array) -> void:
	var cs: CampaignService = Game.campaign
	for id in ids:
		read[str(id)] = true
	if cs and cs.clock.phase() == WorkdayClock.Phase.NIGHT and not ids.is_empty():
		read_at_night[str(cs.clock.day)] = true


func toggle_bookmark(key: String) -> bool:
	if bookmarks.has(key):
		bookmarks.erase(key)
		return false
	bookmarks[key] = true
	return true


func unread(app: String) -> int:
	var kinds: Array = APP_KINDS.get(app, [])
	var n := 0
	for id in pub:
		if not read.has(id) and str(unit(str(id)).get("kind", "")) in kinds:
			n += 1
	return n


## Concise catch-up since the last visit to `app`.
func digest(app: String) -> String:
	var since := float(last_visit.get(app, -1.0))
	var kinds: Array = APP_KINDS.get(app, [])
	var n := 0
	var titles := {}
	for id in pub:
		var u := unit(str(id))
		if float(pub[id]) > since and str(u.get("kind", "")) in kinds and not read.has(id):
			n += 1
			var k := thread_key(u)
			titles[k] = int(titles.get(k, 0)) + 1
	if n == 0:
		return "Nothing new since you last looked."
	var top := titles.keys()
	top.sort_custom(func(a, b) -> bool: return int(titles[a]) > int(titles[b]))
	var names := PackedStringArray()
	for k in top.slice(0, 3):
		var tt := ""
		for u2 in thread_units(str(k)):
			if str(u2.get("title", "")) != "":
				tt = str(u2.title)
				break
		names.append("%s (%d)" % [tt if tt != "" else str(k), int(titles[k])])
	return "Since you last looked: %d new. Busiest: %s." % [n, ", ".join(names)]


func visit(app: String) -> void:
	last_visit[app] = clock


## A gentle, bounded notice when new things arrive while the boss is in
## the camper (never during sleep, never more than once per 3 minutes).
func _maybe_notice() -> void:
	if _pending_notice <= 0 or clock - _last_notice < NOTICE_GAP:
		return
	var p := Game.player as Node3D
	if p == null or Game.desk == null:
		return
	var mon := get_tree().get_nodes_in_group("camper_monitor")
	if mon.is_empty() or (mon[0] as Node3D).global_position.distance_to(p.global_position) > 7.0:
		return
	_last_notice = clock
	if Game.campaign:
		Game.campaign.notice.emit("Computer: %d new message%s and posts." % [_pending_notice, "" if _pending_notice == 1 else "s"], 4.0)
	_pending_notice = 0


# ------------------------------------------------------------ saves

func capture() -> Dictionary:
	return {"version": 1, "clock": clock, "cursor": cursor, "pub": pub.duplicate(), "pub_day": pub_day.duplicate(), "skipped": skipped.duplicate(), "deferred": deferred.duplicate(), "day_count": day_count.duplicate(), "read": read.keys(), "bookmarks": bookmarks.keys(), "positions": positions.duplicate(true), "last_visit": last_visit.duplicate(), "hooks": hooks.duplicate(), "opportunities": opportunities.duplicate(true), "read_at_night": read_at_night.keys()}


func restore(d: Dictionary) -> void:
	clock = float(d.get("clock", 0.0))
	cursor = int(d.get("cursor", 0))
	pub = (d.get("pub", {}) as Dictionary).duplicate()
	pub_day = (d.get("pub_day", {}) as Dictionary).duplicate()
	skipped = (d.get("skipped", {}) as Dictionary).duplicate()
	deferred = (d.get("deferred", []) as Array).duplicate()
	day_count = (d.get("day_count", {}) as Dictionary).duplicate()
	read.clear()
	for k in d.get("read", []):
		read[str(k)] = true
	bookmarks.clear()
	for k in d.get("bookmarks", []):
		bookmarks[str(k)] = true
	positions = (d.get("positions", {}) as Dictionary).duplicate(true)
	last_visit = (d.get("last_visit", {}) as Dictionary).duplicate()
	hooks = (d.get("hooks", {}) as Dictionary).duplicate()
	opportunities = (d.get("opportunities", []) as Array).duplicate(true)
	read_at_night.clear()
	for k in d.get("read_at_night", []):
		read_at_night[str(k)] = true
	# The bank can grow between versions: re-seek the cursor (units already
	# published or skipped stay so; nothing is re-rolled).
	cursor = mini(cursor, _bank_units.size())
