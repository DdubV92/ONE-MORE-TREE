class_name YardService
extends Node3D
## Phase 13 logging yard: where accepted wood physically is between the
## receiving cradle and the fire. TimberService still owns every segment's
## state and every receipt; this service owns WHERE accepted wood sits and
## the reservations that make each move honest.
##
##   intake      unpaid wood lands in a free cradle slot (or on a deck when
##               delivered there). The destination is reserved FIRST; no
##               free destination = no acceptance = no payment (a truck or
##               hand keeps its load, with a reason).
##   cradle      ACCEPTED_STAGED. Paid. Someone carries it to a deck.
##   deck        ACCEPTED_RACKED. Paid. Stacked by real diameter/length in
##               a bounded bay (rows across the deck, up to its height).
##   moving      ACCEPTED_MOVING. Paid. In hands, with a reserved
##               destination (a deck slot or the pit loading pile).
##   pit pile    ACCEPTED_QUEUED (TimberService.queue). Bounded by
##               CampLayout.PIT_QUEUE_CAP; the fire takes from it.
## Moving accepted wood never creates a receipt, money or work credit twice
## (contribution keys are unique per piece and stage).

signal changed()

const LOG_SLEEPER := 0.22          # stack base above the ground (sleepers)

var cradle: Array[String] = []
var decks: Array = []                # Array of Array[String] (stack order)
var moving := {}                     # sid -> {"carrier", "from", "dest"}
var migrated_queue := false
var last_reason := ""
var counters := {"accepted_cradle": 0, "accepted_deck": 0, "racked": 0, "fed": 0}

var _deck_roots: Array[Node3D] = []
var _deck_mm := []                   # deck -> [MultiMeshInstance3D per species]
var _pile_root: Node3D
var _pile_mm := []
var _unit_logs := []                 # per species ArrayMesh (unit cylinder)
var _dirty := true


func setup() -> void:
	name = "Yard"
	add_to_group("logging_yard")
	for i in CampLayout.YARD_DECKS.size():
		decks.append([] as Array[String])
	for sp in 3:
		_unit_logs.append(_make_unit_log(sp))
	_build_decks()
	_pile_root = Node3D.new()
	_pile_root.name = "PitLoadingPile"
	add_child(_pile_root)
	_pile_root.global_position = CampLayout.world(CampLayout.PIT_LOAD_POS)
	_pile_mm = _species_mmis(_pile_root)
	if Game.timber:
		Game.timber.queue_changed.connect(_mark_dirty)
		Game.timber.carried_changed.connect(_mark_dirty)
	for r in get_tree().get_nodes_in_group("delivery_rack"):
		if r.has_method("_refresh"):
			changed.connect(r._refresh)


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		refresh()


# ------------------------------------------------------------- geometry

func deck_world(i: int) -> Vector3:
	return CampLayout.world(CampLayout.YARD_DECKS[i].center)


func deck_size(i: int) -> Vector3:
	return CampLayout.YARD_DECKS[i].size


## Ground level a deck stands on: the highest terrain under its footprint
## (sleepers and posts reach down to the terrain everywhere else).
func deck_base_y(i: int) -> float:
	var c := deck_world(i)
	var sz := deck_size(i)
	var hi := -INF
	for dx in [-0.5, 0.0, 0.5]:
		for dz in [-0.5, 0.0, 0.5]:
			hi = maxf(hi, World.height_at(c.x + sz.x * dx, c.z + sz.z * dz))
	return hi


func _piece_dims(sid: String) -> Vector2:
	var t: TimberService = Game.timber
	var s := t.segment(sid)
	var rec: Dictionary = t.records[int(sid.trim_prefix("T").split("_S")[0])]
	return Vector2(TimberMesh.piece_radius(rec, int(s.k)), TimberMesh.piece_length(rec, int(s.k)))


## Deterministic stack layout: rows across the deck (X), filled left to
## right by each piece's real diameter, rows nested 0.9 x the row below.
## Returns {"ok": bool, "slots": [[sid, x, y, r, len]]} in deck-local
## coordinates (y above the sleepers).
func pack(i: int, list: Array) -> Dictionary:
	var sz := deck_size(i)
	var slots := []
	var row_y := 0.0
	var row_h := 0.0
	var x := -sz.x * 0.5
	# Largest diameters at the bottom (how a loader builds a deck); ties by
	# id so the layout is a pure function of the deck's contents.
	var order := []
	for sid in list:
		order.append([_piece_dims(str(sid)).x, str(sid)])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and str(a[1]) < str(b[1])))
	for o in order:
		var sid: String = o[1]
		var d := _piece_dims(sid)
		var dia := d.x * 2.0
		if d.y > sz.z + 0.05:
			return {"ok": false, "slots": slots, "reason": "too long for the deck"}
		if x + dia > sz.x * 0.5 + 0.001:
			row_y += row_h * 0.9
			row_h = 0.0
			x = -sz.x * 0.5
		if row_y + dia > sz.y + 0.001:
			return {"ok": false, "slots": slots, "reason": "deck full"}
		slots.append([sid, x + d.x, row_y + d.x, d.x, d.y])
		x += dia + 0.02
		row_h = maxf(row_h, dia)
	return {"ok": true, "slots": slots}


func _incoming(dest: String) -> Array:
	var out := []
	for sid in moving:
		if str(moving[sid].dest) == dest:
			out.append(sid)
	return out


func deck_fits(i: int, sid: String) -> bool:
	var list: Array = (decks[i] as Array).duplicate()
	list.append_array(_incoming("deck:%d" % i))
	if not sid in list:
		list.append(sid)
	return bool(pack(i, list).ok)


func cradle_free() -> int:
	return CampLayout.CRADLE_SLOTS - cradle.size() - _incoming("cradle").size()


func pit_free() -> int:
	return CampLayout.PIT_QUEUE_CAP - Game.timber.queue.size() - _incoming("pit").size()


# ----------------------------------------------------------- sawmill (P24)

## Free places on the sawmill feed rack (counting logs already on the way).
func mill_free() -> int:
	return MillLedger.RACK_CAP - Game.timber.mill.rack.size() - _incoming("mill").size()


## Under the mill economy paid wood goes to the sawmill (it pays there);
## otherwise (older rules) it feeds the fire as before.
func feed_destination() -> String:
	return "mill" if Game.timber and Game.timber.mill_economy else "pit"


## Puts an accepted piece on the feed rack (ledger + segment state).
func mill_enqueue(sid: String) -> bool:
	var t: TimberService = Game.timber
	var s := t.segment(sid)
	if s.is_empty():
		return false
	var tid := int(sid.trim_prefix("T").split("_S")[0])
	var litres := TimberService.segment_litres(t.records[tid], int(s.k))
	if not t.mill.enqueue(sid, litres, t.prepaid(sid)):
		last_reason = "The sawmill's feed rack is full (%d logs). Let the saw catch up." % MillLedger.RACK_CAP
		return false
	t.set_state(sid, TimberService.Seg.MILL_RACK)
	counters["milled_in"] = int(counters.get("milled_in", 0)) + 1
	_day_stat("mill_fed", 1)
	return true


## Puts a moving piece on the sawmill feed rack.
func load_mill(carrier: String, sid: String) -> bool:
	last_reason = ""
	if not moving.has(sid) or str(moving[sid].carrier) != carrier:
		return false
	var keep: Dictionary = moving[sid]
	moving.erase(sid)
	if MillLedger.RACK_CAP - Game.timber.mill.rack.size() <= 0:
		moving[sid] = keep
		last_reason = "The sawmill's feed rack is full."
		return false
	_release_hand(carrier, sid)
	if not mill_enqueue(sid):
		# Never strand it: back where it came from.
		moving[sid] = keep
		_hand(carrier, sid, 99999)
		return false
	_contribute(carrier, "fed", sid)
	_dirty = true
	changed.emit()
	return true


## Rough free capacity of the decks in pieces of median size (for UI).
func deck_free_estimate() -> int:
	var n := 0
	for i in decks.size():
		var used: float = 0.0
		for sid in decks[i]:
			var d := _piece_dims(str(sid))
			used += (d.x * 2.0 + 0.02) * d.x * 2.0
		var sz := deck_size(i)
		n += int(maxf(sz.x * sz.y * 0.5 - used, 0.0) / (0.36 * 0.36))   # 0.5: measured packing (Phase 13 capacity probe)
	return n


func stock_count() -> int:
	var n := cradle.size()
	for d in decks:
		n += (d as Array).size()
	return n + moving.size()


func stock_mte() -> int:
	var t: TimberService = Game.timber
	var m := 0
	for sid in cradle:
		m += int(t.segment(sid).mte)
	for d in decks:
		for sid in d:
			m += int(t.segment(str(sid)).mte)
	for sid in moving:
		m += int(t.segment(str(sid)).mte)
	return m


func nearest_deck(at: Vector3, sid := "") -> int:
	var best := -1
	var bd := INF
	for i in decks.size():
		if sid != "" and not deck_fits(i, sid):
			continue
		var d := at.distance_to(deck_world(i))
		if d < bd:
			bd = d
			best = i
	return best


# ----------------------------------------------------------- transactions

## Where unpaid wood arriving at `at` may legally go ("" = nowhere: the
## caller must not accept it). Near the cradle: a free cradle slot; at a
## deck: that deck if the piece fits.
func intake_destination(sid: String, at: Vector3) -> String:
	last_reason = ""
	var cradle_pos := CampLayout.world(CampLayout.DELIVERY_RACK_POS)
	if at == Vector3.INF or Vector2(at.x - cradle_pos.x, at.z - cradle_pos.z).length() < 9.0:
		if cradle_free() > 0:
			return "cradle"
		last_reason = "The receiving cradle is full (%d logs). Move logs to the decks or feed the fire first." % cradle.size()
		return ""
	# Phase 24: deliveries at the sawmill go straight onto its feed rack.
	var mill_rack := CampLayout.world(CampLayout.MILL_RACK_POS)
	var mill_in := CampLayout.world(CampLayout.MILL_INTAKE)
	if Vector2(at.x - mill_rack.x, at.z - mill_rack.z).length() < 7.5 or Vector2(at.x - mill_in.x, at.z - mill_in.z).length() < 6.0:
		if mill_free() > 0:
			return "mill"
		last_reason = "The sawmill's feed rack is full (%d logs). Let the saw catch up or deliver to the yard." % MillLedger.RACK_CAP
		return ""
	# The deck delivered onto is the nearest one (decks are ~6.4 m apart).
	var near := -1
	var nd := 6.5
	for i in decks.size():
		var dc := deck_world(i)
		var dd := Vector2(at.x - dc.x, at.z - dc.z).length()
		if dd < nd:
			nd = dd
			near = i
	if near >= 0:
		if deck_fits(near, sid):
			return "deck:%d" % near
		last_reason = "Deck %d is full. Try another deck or the receiving cradle." % (near + 1)
		return ""
	last_reason = "Deliver at the receiving cradle beside the fire pit, or at a yard deck."
	return ""


## Called by TimberService.accept() after the receipt exists.
func receive(sid: String, dest: String) -> void:
	var t: TimberService = Game.timber
	if dest == "mill":
		mill_enqueue(sid)
		_dirty = true
		changed.emit()
		return
	if dest == "cradle":
		cradle.append(sid)
		t.set_state(sid, TimberService.Seg.ACCEPTED_STAGED)
		counters.accepted_cradle += 1
	else:
		var i := int(dest.get_slice(":", 1))
		(decks[i] as Array).append(sid)
		t.set_state(sid, TimberService.Seg.ACCEPTED_RACKED)
		counters.accepted_deck += 1
	_dirty = true
	changed.emit()


## Takes one accepted piece from the cradle (oldest) into `carrier`'s hands
## with a reserved deck destination. Returns the sid or "" (+last_reason).
func take_from_cradle(carrier: String, budget: int, from_pos := Vector3.INF) -> String:
	last_reason = ""
	if cradle.is_empty():
		last_reason = "The receiving cradle is empty."
		return ""
	for sid in cradle:
		var m := int(Game.timber.segment(sid).mte)
		if m > budget * 2:
			continue
		var dk := nearest_deck(from_pos if from_pos != Vector3.INF else CampLayout.world(CampLayout.DELIVERY_RACK_POS), sid)
		if dk < 0:
			last_reason = "Every deck is full. Feed the fire to make room."
			return ""
		if not _hand(carrier, sid, budget):
			return ""
		cradle.erase(sid)
		moving[sid] = {"carrier": carrier, "from": "cradle", "dest": "deck:%d" % dk}
		_dirty = true
		changed.emit()
		return sid
	last_reason = "Those logs are too heavy to lift; drag them or use the cart."
	return ""


## Takes the top piece from deck i for the sawmill (Phase 24 mill economy)
## or the fire (older rules); needs room at that destination.
func take_from_deck(carrier: String, i: int, budget: int, dest := "") -> String:
	last_reason = ""
	if dest == "":
		dest = feed_destination()
	var list: Array = decks[i]
	if list.is_empty():
		last_reason = "Deck %d is empty." % (i + 1)
		return ""
	if dest == "mill" and mill_free() <= 0:
		last_reason = "The sawmill's feed rack is full (%d logs). Let the saw catch up." % MillLedger.RACK_CAP
		return ""
	if dest == "pit" and pit_free() <= 0:
		last_reason = "The fire's loading pile is full (%d logs). Let it burn down." % CampLayout.PIT_QUEUE_CAP
		return ""
	var sid := str(list[list.size() - 1])
	if int(Game.timber.segment(sid).mte) > budget * 2:
		last_reason = "That log is too heavy to lift."
		return ""
	if not _hand(carrier, sid, budget):
		return ""
	list.erase(sid)
	moving[sid] = {"carrier": carrier, "from": "deck:%d" % i, "dest": dest}
	_dirty = true
	changed.emit()
	return sid


func _hand(carrier: String, sid: String, budget: int) -> bool:
	var t: TimberService = Game.timber
	var held := t.load_of(carrier)
	var m := int(t.segment(sid).mte)
	if not held.is_empty() and (t.carrier_mte(carrier) + m > budget + 2):
		last_reason = "Your hands are full."
		return false
	held.append(sid)
	t.claims[sid] = carrier
	t.set_state(sid, TimberService.Seg.ACCEPTED_MOVING)
	t.carried_changed.emit()
	return true


func _release_hand(carrier: String, sid: String) -> void:
	var t: TimberService = Game.timber
	t.load_of(carrier).erase(sid)
	t.claims.erase(sid)
	moving.erase(sid)
	t.carried_changed.emit()


## Stacks a moving piece on deck i (any deck with room is valid).
func place_on_deck(carrier: String, sid: String, i: int) -> bool:
	last_reason = ""
	if not moving.has(sid) or str(moving[sid].carrier) != carrier:
		return false
	var keep: Dictionary = moving[sid]
	moving.erase(sid)
	if not deck_fits(i, sid):
		moving[sid] = keep
		last_reason = "Deck %d is full." % (i + 1)
		return false
	_release_hand(carrier, sid)
	(decks[i] as Array).append(sid)
	Game.timber.set_state(sid, TimberService.Seg.ACCEPTED_RACKED)
	counters.racked += 1
	_day_stat("yard_racked", 1)
	_contribute(carrier, "racked", sid)
	_dirty = true
	changed.emit()
	return true


## Puts a moving piece on the fire's loading pile (the burn queue).
func load_pit(carrier: String, sid: String) -> bool:
	last_reason = ""
	if not moving.has(sid) or str(moving[sid].carrier) != carrier:
		return false
	var keep: Dictionary = moving[sid]
	moving.erase(sid)
	if pit_free() <= 0:
		moving[sid] = keep
		last_reason = "The loading pile by the fire is full."
		return false
	_release_hand(carrier, sid)
	var t: TimberService = Game.timber
	t.queue.append(sid)
	t.set_state(sid, TimberService.Seg.ACCEPTED_QUEUED)
	counters.fed += 1
	_day_stat("yard_fed", 1)
	_contribute(carrier, "fed", sid)
	t.queue_changed.emit()
	_dirty = true
	changed.emit()
	return true


## Puts a moving piece back where it came from (cancel at the source, or a
## save taken mid-move: the piece returns to its last yard place).
func return_to_origin(sid: String) -> void:
	if not moving.has(sid):
		return
	var from := str(moving[sid].from)
	_release_hand(str(moving[sid].carrier), sid)
	if from == "cradle":
		cradle.append(sid)
		Game.timber.set_state(sid, TimberService.Seg.ACCEPTED_STAGED)
	else:
		(decks[int(from.get_slice(":", 1))] as Array).append(sid)
		Game.timber.set_state(sid, TimberService.Seg.ACCEPTED_RACKED)
	_dirty = true
	changed.emit()


## Phase 16 hook: one useful-work credit per piece per stage, ever.
func _contribute(carrier: String, stage: String, sid: String) -> void:
	if Game.crew and Game.crew.get("contributions") and carrier != "player":
		Game.crew.contributions.stage(carrier, stage, sid)
	# Phase 16 merit: the receiving budget of this share, once per stage
	# (moving it between decks again finds the budget already committed).
	var ml := MeritLedger.active()
	if ml and Game.timber:
		ml.on_receive(sid, int(Game.timber.segment(sid).get("mte", 0)), MeritLedger.BOSS if carrier == "player" else carrier, stage)


func _day_stat(k: String, n: int) -> void:
	if Game.campaign and is_instance_valid(Game.campaign):
		Game.campaign._stat_add(k, n)


func is_yard_move(sid: String) -> bool:
	return moving.has(sid)


# ---------------------------------------------------------- persistence

func capture() -> Dictionary:
	var dk := []
	for d in decks:
		dk.append((d as Array).duplicate())
	var mv := {}
	for sid in moving:
		mv[sid] = (moving[sid] as Dictionary).duplicate()
	var out := {"version": 1, "cradle": cradle.duplicate(), "decks": dk, "moving": mv, "migrated_queue": migrated_queue, "counters": counters.duplicate()}
	if Game.cart and is_instance_valid(Game.cart):
		out["cart"] = Game.cart.capture()
	return out


## Restores yard places from a save. Only accepted pieces (those with a
## receipt) can be in the yard; anything else in a saved yard list is
## ignored. A piece saved mid-move goes back to where it was taken from.
func restore(d: Dictionary, accepted: Dictionary) -> void:
	cradle.clear()
	for i in decks.size():
		(decks[i] as Array).clear()
	moving.clear()
	var seen := {}
	for sid in d.get("cradle", []):
		if accepted.has(str(sid)) and not seen.has(str(sid)):
			cradle.append(str(sid))
			seen[str(sid)] = true
	var dk: Array = d.get("decks", [])
	for i in mini(dk.size(), decks.size()):
		for sid in dk[i]:
			if accepted.has(str(sid)) and not seen.has(str(sid)):
				(decks[i] as Array).append(str(sid))
				seen[str(sid)] = true
	var mv: Dictionary = d.get("moving", {})
	for sid in mv:
		if not accepted.has(str(sid)) or seen.has(str(sid)):
			continue
		var from := str(mv[sid].get("from", "cradle"))
		if from.begins_with("deck:") and int(from.get_slice(":", 1)) < decks.size():
			(decks[int(from.get_slice(":", 1))] as Array).append(str(sid))
		else:
			cradle.append(str(sid))
		seen[str(sid)] = true
	migrated_queue = bool(d.get("migrated_queue", false))
	var c: Dictionary = d.get("counters", {})
	for k in counters:
		counters[k] = int(c.get(k, 0))
	if Game.cart and is_instance_valid(Game.cart) and d.has("cart"):
		Game.cart.restore(d.get("cart", {}))
	_dirty = true
	changed.emit()


func all_yard_sids() -> Dictionary:
	var out := {}
	for sid in cradle:
		out[sid] = "cradle"
	for i in decks.size():
		for sid in decks[i]:
			out[str(sid)] = "deck:%d" % i
	for sid in moving:
		out[str(sid)] = "moving"
	return out


## Pre-Phase-13 saves: the whole accepted backlog sat in the pit queue.
## Once, keep what fits on the loading pile and stack the rest on decks
## (no receipt, payment or burn progress changes). Overflow beyond the
## decks stays in the queue (shown honestly as "waiting by the fire").
func migrate_old_queue() -> int:
	if migrated_queue:
		return 0
	migrated_queue = true
	var t: TimberService = Game.timber
	var moved := 0
	while t.queue.size() > CampLayout.PIT_QUEUE_CAP:
		var sid: String = t.queue[t.queue.size() - 1]
		var placed := false
		for i in decks.size():
			if deck_fits(i, sid):
				t.queue.erase(sid)
				(decks[i] as Array).append(sid)
				t.set_state(sid, TimberService.Seg.ACCEPTED_RACKED)
				placed = true
				moved += 1
				break
		if not placed:
			break
	if moved > 0:
		t.queue_changed.emit()
	_dirty = true
	return moved


# -------------------------------------------------------------- visuals

func _build_decks() -> void:
	var post := BuildKit.mat("dark_wood")
	for i in CampLayout.YARD_DECKS.size():
		var root := Node3D.new()
		root.name = "LogDeck_%d" % (i + 1)
		add_child(root)
		var c := deck_world(i)
		var base := deck_base_y(i)
		root.global_position = Vector3(c.x, base, c.z)
		var sz := deck_size(i)
		# Two sleepers under the logs (log axis = Z), reaching the terrain.
		for zz in [-sz.z * 0.32, sz.z * 0.32]:
			var low := minf(World.height_at(c.x - sz.x * 0.5, c.z + zz), World.height_at(c.x + sz.x * 0.5, c.z + zz))
			var h := LOG_SLEEPER + (base - low)
			BuildKit.box(root, Vector3(sz.x + 0.3, h, 0.24), Vector3(0, LOG_SLEEPER - h * 0.5, zz), post, false, 0.0, "Sleeper")
		# Stakes at both sides keep the stack from rolling, set into the ground.
		for sx in [-1.0, 1.0]:
			for zz in [-sz.z * 0.32, sz.z * 0.32]:
				var drop := base - World.height_at(c.x + sx * (sz.x * 0.5 + 0.12), c.z + zz)
				var top := LOG_SLEEPER + sz.y + 0.1
				BuildKit.box(root, Vector3(0.14, top + drop + 0.15, 0.14), Vector3(sx * (sz.x * 0.5 + 0.12), (top - drop - 0.15) * 0.5, zz), post, false, 0.0, "Stake")
		# Collision: the stack volume (people work it from the walkway).
		var body := StaticBody3D.new()
		body.name = "DeckBody"
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(sz.x + 0.4, sz.y + LOG_SLEEPER, sz.z)
		cs.shape = bx
		cs.position = Vector3(0, (sz.y + LOG_SLEEPER) * 0.5, 0)
		body.add_child(cs)
		var deck := YardDeck.new()
		deck.name = "Deck"
		deck.index = i
		deck.add_child(body)
		root.add_child(deck)
		# Sign facing the walkway.
		var sign := Label3D.new()
		sign.name = "Sign"
		sign.position = Vector3(-sz.x * 0.5 - 0.4, 1.5, sz.z * 0.5)
		sign.pixel_size = 0.004
		sign.font_size = 34
		sign.modulate = Color(0.95, 0.9, 0.75)
		sign.outline_size = 6
		sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		root.add_child(sign)
		_deck_roots.append(root)
		_deck_mm.append(_species_mmis(root))


func _species_mmis(parent: Node3D) -> Array:
	var out := []
	for sp in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _unit_logs[sp]
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Logs_%s" % TreeBuilder.SPECIES_NAMES[sp]
		mmi.multimesh = mm
		mmi.visibility_range_end = 260.0
		parent.add_child(mmi)
		out.append(mmi)
	return out


## Unit log (radius 1, length 1 along +Y, centred): bark + end-grain caps.
func _make_unit_log(sp: int) -> ArrayMesh:
	var rec := {"species": sp, "variant": 0, "xs": 1.0, "ys": 1.0, "segments": [{"a": 0.0, "b": 1.0}]}
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p0 := Vector3(cos(a0), -0.5, sin(a0))
		var p1 := Vector3(cos(a1), -0.5, sin(a1))
		var q0 := Vector3(cos(a0), 0.5, sin(a0))
		var q1 := Vector3(cos(a1), 0.5, sin(a1))
		var u0 := float(k) / n
		var u1 := float(k + 1) / n
		# Clockwise seen from outside (Godot front faces).
		for v in [[p0, Vector2(u0, 1)], [p1, Vector2(u1, 1)], [q1, Vector2(u1, 0)], [p0, Vector2(u0, 1)], [q1, Vector2(u1, 0)], [q0, Vector2(u0, 0)]]:
			var pos: Vector3 = v[0]
			bark.set_normal(Vector3(pos.x, 0, pos.z).normalized())
			bark.set_uv((v[1] as Vector2) * Vector2(2.0, 1.0))
			bark.add_vertex(pos)
		for side in [-1.0, 1.0]:
			var c := Vector3(0, 0.5 * side, 0)
			var e0 := Vector3(cos(a0), 0.5 * side, sin(a0))
			var e1 := Vector3(cos(a1), 0.5 * side, sin(a1))
			var tri: Array = [c, e0, e1] if side > 0.0 else [c, e1, e0]
			for pp in tri:
				var pv: Vector3 = pp
				wood.set_normal(Vector3(0, side, 0))
				wood.set_uv(Vector2(pv.x, pv.z) * 0.5 + Vector2(0.5, 0.5))
				wood.add_vertex(pv)
	var mesh := ArrayMesh.new()
	bark.generate_tangents()
	bark.commit(mesh)
	wood.commit(mesh)
	mesh.surface_set_material(0, TimberMesh.bark_material(sp))
	mesh.surface_set_material(1, TimberMesh.wood_material())
	return mesh


func refresh() -> void:
	var t: TimberService = Game.timber
	if t == null:
		return
	for i in decks.size():
		var lay := pack(i, decks[i])
		var by_sp := [[], [], []]
		for sl in lay.slots:
			var sid: String = sl[0]
			var sp := int(t.records[int(sid.trim_prefix("T").split("_S")[0])].species)
			# Logs lie along Z; slight per-piece offsets read as a real stack.
			var r: float = sl[3]
			var L: float = sl[4]
			var jitter := float(hash(sid) % 100) / 100.0 - 0.5
			# Local scale (radius, length, radius), then lay the +Y axis along Z.
			var b := Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(r, L, r))
			b = Basis(Vector3.UP, jitter * 0.04) * b
			by_sp[sp].append(Transform3D(b, Vector3(float(sl[1]), LOG_SLEEPER + float(sl[2]), jitter * 0.12)))
		for sp in 3:
			var mm: MultiMesh = (_deck_mm[i][sp] as MultiMeshInstance3D).multimesh
			var arr: Array = by_sp[sp]
			mm.instance_count = arr.size()
			for k in arr.size():
				mm.set_instance_transform(k, arr[k])
		var sign := _deck_roots[i].get_node("Sign") as Label3D
		sign.text = "DECK %d\n%d logs  %.2f tree-eq" % [i + 1, (decks[i] as Array).size(), _mte_of(decks[i]) / 1000.0]
	# Fuel loading pile beside the pit: the burn queue, logs along X.
	var by := [[], [], []]
	var x := 0.0
	var y := 0.0
	var row_h := 0.0
	for sid in t.queue:
		var d := _piece_dims(sid)
		if x > 1.4:
			x = 0.0
			y += row_h * 0.9
			row_h = 0.0
		var sp := int(t.records[int(sid.trim_prefix("T").split("_S")[0])].species)
		var b := Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(d.x, d.y, d.x))
		by[sp].append(Transform3D(b, Vector3(0, LOG_SLEEPER * 0.5 + y + d.x, -0.7 + x + d.x)))
		x += d.x * 2.0 + 0.02
		row_h = maxf(row_h, d.x * 2.0)
	for sp in 3:
		var mm: MultiMesh = (_pile_mm[sp] as MultiMeshInstance3D).multimesh
		var arr: Array = by[sp]
		mm.instance_count = arr.size()
		for k in arr.size():
			mm.set_instance_transform(k, arr[k])


func _mte_of(list: Array) -> int:
	var m := 0
	for sid in list:
		m += int(Game.timber.segment(str(sid)).mte)
	return m
