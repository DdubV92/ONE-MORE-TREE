class_name TimberService
extends Node
## Authoritative timber ledger for felled original trees (Phase 2).
##
## Every original tree owns exactly 1000 milli tree-equivalents (mTE) of
## merchantable timber and exactly 10,000 cents of potential delivery
## entitlement. A fallen trunk is partitioned (stable, deterministic) into
## 3-9 segments; shares are integers that always sum to the tree total.
## Segment IDs are "T<tree>_S<k>" - never array positions or random IDs.
##
## One owner per segment at all times. States:
##   ATTACHED -> WORLD <-> CARRIED -> ACCEPTED_QUEUED -> BURNING -> CONSUMED
##   (VEHICLE_RESERVED reserved for Prompt 5 trucks)
## Acceptance at the camp rack is the ONLY event that creates an
## entitlement receipt. Phase 3's PaymentService turns receipts into cash
## exactly once.

enum Seg { ATTACHED, WORLD, CARRIED, VEHICLE_RESERVED, ACCEPTED_QUEUED, BURNING, CONSUMED, ACCEPTED_STAGED, ACCEPTED_RACKED, ACCEPTED_MOVING }
## Phase 13 states (appended so saved integers keep their meaning):
##   ACCEPTED_STAGED  paid, lying in the receiving cradle
##   ACCEPTED_RACKED  paid, stacked on a yard log deck
##   ACCEPTED_MOVING  paid, in someone's hands between yard places
## Every accepted state is >= ACCEPTED_QUEUED, so "accepted" checks hold.
const SEG_MAX := Seg.ACCEPTED_MOVING
## Segmentation plans: v1 = Phases 2-12 (0.9-2.0 m targets, at least three
## pieces, each within a hand load); v2 = Phase 13 (targets x1.5, equal
## pieces, as few as one; pieces over a hand load are dragged or carted).
const PLAN_V1 := "v1"
const PLAN_V2 := "v2"
const SECTION_LENGTH_MULT_V2 := 1.5
## Plan v2 bound: a piece is at most two hand loads (dragged or carted).
const V2_MAX_PIECE_MTE := 666

const TREE_MTE := 1000
const TREE_CENTS := 10000
const MIN_SEGMENTS := 3
const MAX_SEGMENTS := 12
const HAND_BUDGET_MTE := 333          # one-third tree-equivalent
const MIN_MERCH_DIAMETER := 0.12      # m; above this the trunk is merchantable

signal delivery_accepted(receipt: Dictionary)
signal segment_state_changed(sid: String, state: int)
signal piece_consumed(sid: String)
signal recovered(sid: String, reason: String)
signal carried_changed()
signal queue_changed()

var config: TreeWorkConfig
var records := {}          # tree id -> record
var bodies := {}           # body key -> TimberBody
var carried: Array[String] = []        # sids in the player's hands (bundle)
## Phase 4: worker hand loads, carrier id -> Array of sids (same rules).
var loads := {}
var queue: Array[String] = []          # accepted, waiting to burn (FIFO)
var burning: Array[String] = []        # in the pit (max BURN_SLOTS)
var receipts: Array[Dictionary] = []
var recovery_log: Array[Dictionary] = []
var claims := {}           # sid -> claimant id (future workers)
var _receipt_counter := 0
var _body_counter := 0
var persistent := true
## Phase 3: the contract closes acceptance after its outcome commits.
var accept_gate: Callable
## Phase 4: navigation marks resting logs (callable(body, +1/-1)).
var body_settled_hook: Callable
var _nav_marked := {}
var body_parent: Node3D

const BURN_SLOTS := 3                   # detailed logs in the pit at once
const BURN_SECONDS_PER_THIRD := 240.0   # a 1/3 tree-equivalent piece burns 4 min
const BURN_BACKLOG_BOOST := 3.0         # bigger fire for a big backlog (max x4)
const OVERNIGHT_BURN_SECONDS := 3600.0  # bounded game-time burn applied at sleep


func _ready() -> void:
	config = load("res://config/tree_work.tres")


func setup(parent: Node3D, is_persistent: bool) -> void:
	body_parent = parent
	persistent = is_persistent


# --------------------------------------------------------------- partition

## Deterministic segment partition for a felled tree. Pure function of the
## frozen tree record, so it is identical on every load.
## The plan new records use: the active campaign's ruleset, or (Preview,
## tools) the standard ruleset of the loaded island variant.
static func current_plan() -> String:
	var rs: Dictionary = {}
	if Game.campaign and Game.campaign.get("ruleset") is Dictionary and not (Game.campaign.ruleset as Dictionary).is_empty() and Game.campaign.active:
		rs = Game.campaign.ruleset
	else:
		rs = Ruleset.get_def(Ruleset.for_variant(World.manifest_variant))
	return str(rs.get("section_plan", PLAN_V1))


static func partition(idx: int, plan := PLAN_V1) -> Dictionary:
	var sp: int = World.trees.species[idx]
	var v: int = World.trees.variant[idx]
	var height: float = World.trees.height[idx]
	var dims := tree_scale(idx)
	var xs: float = dims.x
	var ys: float = dims.y
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	var cut_h := cfg.cut_height
	var radius := func(len_from_base: float) -> float:
		return TreeBuilder.trunk_radius_local(sp, v, len_from_base / ys) * xs
	# Merchantable top: diameter >= 12 cm and below 82 % of the height.
	var top := cut_h + 1.0
	var y := cut_h
	while y < height * 0.82:
		if float(radius.call(y)) * 2.0 < MIN_MERCH_DIAMETER:
			break
		top = y
		y += 0.25
	var merch_len: float = maxf(top - cut_h, 1.0)
	var d0: float = float(radius.call(cut_h)) * 2.0
	var max_piece := clampf(2.2 - d0 * 1.4, 0.9, 2.0)
	if plan == PLAN_V2:
		# Phase 13: target length x1.5. Equal division of the merchantable
		# length (no stub remainders); small trees can be one piece, large
		# ones several. Shares by real volume, so $100/tree is unchanged.
		var target := max_piece * SECTION_LENGTH_MULT_V2
		var n2 := clampi(int(ceil(merch_len / target - 1e-6)), 1, MAX_SEGMENTS)
		var parts2 := _shares(n2, cut_h, merch_len, radius)
		# Supported bound: no piece heavier than two hand loads (what one
		# person can drag or lever onto the cart); split further if needed.
		while n2 < MAX_SEGMENTS:
			var mx := 0
			for q in parts2.mte:
				mx = maxi(mx, q)
			if mx <= V2_MAX_PIECE_MTE:
				break
			n2 += 1
			parts2 = _shares(n2, cut_h, merch_len, radius)
		parts2["cut_h"] = cut_h
		parts2["merch_top"] = cut_h + merch_len
		parts2["n"] = n2
		parts2["species"] = sp
		parts2["d0"] = d0
		parts2["target"] = target
		parts2["plan"] = PLAN_V2
		return parts2
	var n := clampi(int(ceil(merch_len / max_piece)), MIN_SEGMENTS, MAX_SEGMENTS)
	var parts: Dictionary
	while true:
		parts = _shares(n, cut_h, merch_len, radius)
		var max_q := 0
		for q in parts.mte:
			max_q = maxi(max_q, q)
		if max_q <= HAND_BUDGET_MTE or n >= MAX_SEGMENTS:
			break
		n += 1
	parts["cut_h"] = cut_h
	parts["merch_top"] = cut_h + merch_len
	parts["n"] = n
	parts["species"] = sp
	parts["d0"] = d0
	parts["target"] = max_piece
	parts["plan"] = PLAN_V1
	return parts


## (x, y) scale of the grounded tree instance (mesh units -> meters).
static func tree_scale(idx: int) -> Vector2:
	if Game.vegetation:
		var t: Transform3D = Game.vegetation.tree_transform(idx)
		return Vector2(t.basis.x.length(), t.basis.y.length())
	var sp: int = World.trees.species[idx]
	var h: float = World.trees.height[idx]
	var s := h / TreeBuilder.mesh_height(sp, World.trees.variant[idx])
	return Vector2(s, s)


## Phase 10 interface (inactive until Phase 13 brings the handling path):
## sections 1.5x longer means proportionally fewer pieces for the same
## merchantable length, never fewer than one. Existing records keep their
## pieces; only new trees in a ruleset with section_length_active use it.
static func section_count_for(base_n: int, length_mult: float) -> int:
	return maxi(1, int(round(float(base_n) / maxf(length_mult, 0.01))))


static func _shares(n: int, cut_h: float, merch_len: float, radius: Callable) -> Dictionary:
	var starts := PackedFloat32Array()
	var ends := PackedFloat32Array()
	var vols := PackedFloat64Array()
	for k in n:
		var a := cut_h + merch_len * k / n
		var b := cut_h + merch_len * (k + 1) / n
		var ra: float = radius.call(a)
		var rb: float = radius.call(b)
		starts.append(a)
		ends.append(b)
		vols.append(PI * (b - a) * (ra * ra + ra * rb + rb * rb) / 3.0)
	return {"starts": starts, "ends": ends, "mte": allocate(vols, TREE_MTE), "cents": allocate(vols, TREE_CENTS)}


## Exact integer allocation of `total` by weights: floor shares, remainder to
## the final share (deterministic). The result always sums to `total`; for
## equal thirds of 10,000 cents: 3333, 3333, 3334.
static func allocate(weights: PackedFloat64Array, total: int) -> PackedInt32Array:
	var sum := 0.0
	for w in weights:
		sum += w
	var out := PackedInt32Array()
	var acc := 0
	for k in weights.size():
		if k < weights.size() - 1:
			var q := int(floor(float(total) * weights[k] / sum + 1e-9))
			out.append(q)
			acc += q
		else:
			out.append(total - acc)
	return out


# ----------------------------------------------------------------- records

func has_record(tree_id: int) -> bool:
	return records.has(tree_id)


## Builds (or rebuilds on load) the authoritative record for a tree. Saved
## data only overrides progress/state fields; geometry and shares always
## come from the frozen tree record, so a save cannot change quantities.
func _build_record(id: int, idx: int, saved: Dictionary) -> Dictionary:
	# A record keeps the plan it was created with for life (saves without a
	# plan are Phases 2-12: v1). New trees use the campaign's current plan.
	var plan := str(saved.get("plan", PLAN_V1)) if not saved.is_empty() else current_plan()
	var p := partition(idx, plan)
	var sp: int = World.trees.species[idx]
	var v: int = World.trees.variant[idx]
	var dims := tree_scale(idx)
	var base_basis := Basis()
	if Game.vegetation:
		base_basis = (Game.vegetation.tree_transform(idx) as Transform3D).basis
	var axis := base_basis.y.normalized() if base_basis.y.length() > 0.001 else Vector3.UP
	var segs := []
	var saved_segs: Array = saved.get("segments", [])
	for k in int(p.n):
		var ss: Dictionary = saved_segs[k] if k < saved_segs.size() else {}
		segs.append({"sid": "T%d_S%d" % [id, k], "k": k, "a": p.starts[k], "b": p.ends[k], "mte": p.mte[k], "cents": p.cents[k], "state": clampi(int(ss.get("state", Seg.ATTACHED)), Seg.ATTACHED, SEG_MAX), "receipt": str(ss.get("receipt", "")), "burn": clampf(float(ss.get("burn", 0.0)), 0.0, 1.0)})
	var rec := {
		"tree": id, "idx": idx, "species": sp, "variant": v, "plan": plan,
		"xs": dims.x, "ys": dims.y, "base_basis": base_basis, "frame": TimberMesh.frame_for(axis),
		"cut_h": float(p.cut_h), "merch_top": float(p.merch_top),
		"segments": segs, "bounds": [], "crown": {},
	}
	var saved_bounds: Array = saved.get("bounds", [])
	for k in int(p.n) - 1:
		var sb: Dictionary = saved_bounds[k] if k < saved_bounds.size() else {}
		var r := TimberMesh.radius_at(rec, float(p.ends[k]))
		rec.bounds.append({"k": k, "work": maxf(float(sb.get("work", 0.0)), 0.0), "required": section_units(r * 2.0), "cut": bool(sb.get("cut", false))})
	var sc: Dictionary = saved.get("crown", {})
	var crown_r := TimberMesh.radius_at(rec, float(p.merch_top))
	rec.crown = {"attached": bool(sc.get("attached", true)), "work": maxf(float(sc.get("work", 0.0)), 0.0), "required": section_units(crown_r * 2.0) * 0.6}
	return rec


## Called when a felled trunk has settled: builds the timber record and
## hands the trunk from the TreeActor to one TimberBody (same pose, so the
## swap is invisible). The tree's ID is kept throughout.
func adopt_fallen(actor: TreeActor) -> void:
	var id := actor.tree_id
	if records.has(id) or actor.body == null:
		return
	var rec := _build_record(id, actor.idx, {})
	records[id] = rec
	# Actor body frame: +Y = world up of the standing tree's mesh frame;
	# timber frame: +Y = the tree's own (leaning) trunk axis.
	var pose := actor.body.global_transform * Transform3D(rec.frame as Basis, Vector3.ZERO)
	actor.release_fallen_body()
	var all: Array[int] = []
	for k in rec.segments.size():
		all.append(k)
	var b := _make_body(id, all, true, pose, false)
	if not b.has_support():
		b.set_dynamic(true)


func section_units(diameter: float) -> float:
	# Bucking cuts are cheaper than felling the standing tree.
	# At least two small-axe contacts even for a thin top log.
	return maxf(config.reference_units * 0.35 * pow(maxf(diameter, 0.05) / config.reference_diameter, config.diameter_exponent), 1.6)


func _make_body(tree_id: int, ks: Array[int], crown: bool, pose: Transform3D, dynamic: bool) -> TimberBody:
	_body_counter += 1
	var key := "B%d_%d" % [tree_id, _body_counter]
	var b := TimberBody.new()
	b.name = key
	body_parent.add_child(b)
	b.setup(self, key, tree_id, ks, crown, pose, dynamic)
	bodies[key] = b
	if not dynamic:
		_nav_mark(b, true)
	for k in ks:
		var s: Dictionary = records[tree_id].segments[k]
		var st := Seg.WORLD if ks.size() == 1 and not crown else Seg.ATTACHED
		if int(s.state) != st:
			s.state = st
			segment_state_changed.emit(str(s.sid), st)
	return b


func set_state(sid: String, st: int) -> void:
	_set_state(sid, st)


func segment(sid: String) -> Dictionary:
	var parts := sid.trim_prefix("T").split("_S")
	var tid := int(parts[0])
	if not records.has(tid):
		return {}
	var k := int(parts[1])
	var segs: Array = records[tid].segments
	return segs[k] if k >= 0 and k < segs.size() else {}


func _set_state(sid: String, st: int) -> void:
	var s := segment(sid)
	if s.is_empty():
		return
	s.state = st
	segment_state_changed.emit(sid, st)


# --------------------------------------------------------------- sectioning

## Axe contact on a timber body near local length `y` (m from the base along
## the trunk axis). Returns {"accepted", "progress", "separated", "reason"}.
func apply_cut(body: TimberBody, y: float, work: float, actor := "", tool := "axe", saw_s := 0.0) -> Dictionary:
	if not body.is_resting():
		return {"accepted": false, "reason": "wait"}
	var rec: Dictionary = records[body.tree_id]
	var target := _nearest_boundary(body, y)
	if target.is_empty():
		return {"accepted": false, "reason": "no_boundary"}
	if target.kind == "crown":
		var c: Dictionary = rec.crown
		c.work = float(c.work) + work
		var wcc := Woodcutting.active()
		if wcc and work > 0.0:
			wcc.on_hit(actor, tool, "%s|c%d|%.4f" % [actor, body.tree_id, float(c.work)], saw_s)
		var pr := clampf(float(c.work) / float(c.required), 0.0, 1.0)
		var mlc := MeritLedger.active()
		if mlc:
			mlc.on_section(body.tree_id, "crown", float(c.required) / section_total(body.tree_id), pr, actor)
		body.refresh_cut(-1)
		if pr >= 1.0:
			_clear_crown(body)
			return {"accepted": true, "progress": 1.0, "separated": true}
		return {"accepted": true, "progress": pr, "separated": false}
	var bd: Dictionary = rec.bounds[target.k]
	bd.work = float(bd.work) + work
	var wc := Woodcutting.active()
	if wc and work > 0.0:
		wc.on_hit(actor, tool, "%s|b%d:%d|%.4f" % [actor, body.tree_id, int(target.k), float(bd.work)], saw_s)
	var p := clampf(float(bd.work) / float(bd.required), 0.0, 1.0)
	var ml := MeritLedger.active()
	if ml:
		ml.on_section(body.tree_id, str(target.k), float(bd.required) / section_total(body.tree_id), p, actor)
	body.refresh_cut(int(target.k))
	if p >= 1.0 and not bool(bd.cut):
		bd.cut = true
		_split(body, int(target.k))
		return {"accepted": true, "progress": 1.0, "separated": true}
	return {"accepted": true, "progress": p, "separated": false}


## Phase 16: the tree's whole sectioning work (every cut + the crown), so
## each cut's share of the 200-merit sectioning budget is fixed per tree.
func section_total(tid: int) -> float:
	var rec: Dictionary = records.get(tid, {})
	if rec.is_empty():
		return 1.0
	var t := 0.0
	for bd in rec.bounds:
		t += float(bd.required)
	if not (rec.crown as Dictionary).is_empty():
		t += float(rec.crown.get("required", 0.0))
	return maxf(t, 0.001)


func _nearest_boundary(body: TimberBody, y: float) -> Dictionary:
	var rec: Dictionary = records[body.tree_id]
	var best := {}
	var best_d := 0.75
	for k in body.ks:
		if k < body.ks.max():
			var bd: Dictionary = rec.bounds[k]
			if bool(bd.cut):
				continue
			var by: float = rec.segments[k].b
			var d := absf(y - by)
			if d < best_d:
				best_d = d
				best = {"kind": "bound", "k": k}
	if body.crown and bool(rec.crown.attached):
		var d := absf(y - float(rec.merch_top))
		if d < best_d + 0.35:
			best = {"kind": "crown"}
	return best


func boundary_progress(body: TimberBody, y: float) -> float:
	var t := _nearest_boundary(body, y)
	if t.is_empty():
		return -1.0
	var rec: Dictionary = records[body.tree_id]
	if t.kind == "crown":
		return clampf(float(rec.crown.work) / float(rec.crown.required), 0.0, 1.0)
	var bd: Dictionary = rec.bounds[t.k]
	return clampf(float(bd.work) / float(bd.required), 0.0, 1.0)


## Separation is one synchronous transaction (no frame where both the old
## run and the new pieces exist logically). The part with the crown, or the
## longer part, keeps its resting pose; the other part is released to a
## short local simulation. Either part without support is woken.
func _split(body: TimberBody, k: int) -> void:
	var low: Array[int] = []
	var high: Array[int] = []
	for s in body.ks:
		if s <= k:
			low.append(s)
		else:
			high.append(s)
	var pose := body.global_transform
	var crown := body.crown
	var tid := body.tree_id
	var keep_high := crown or high.size() >= low.size()
	_remove_body(body, false)
	var bl := _make_body(tid, low, false, pose, not keep_high)
	var bh := _make_body(tid, high, crown, pose, keep_high == false)
	for b in [bl, bh]:
		if b.is_resting() and not b.has_support():
			b.set_dynamic(true)
	var at := pose * Vector3(0, float(records[tid].segments[k].b), 0)
	LoggingFX.play(LoggingFX.Sound.CRACK, at, 0.0, {"event": "tree.branch.snap"})
	LoggingFX.chips(at, Vector3.UP, Color(0.85, 0.72, 0.5))


func _clear_crown(body: TimberBody) -> void:
	# The crown/branch top is non-payable brush (explicitly tracked, not a
	# missing share). It collapses into residue that fades over a minute.
	var rec: Dictionary = records[body.tree_id]
	rec.crown.attached = false
	body.drop_crown()
	if body.ks.size() == 1:
		_set_state(rec.segments[body.ks[0]].sid, Seg.WORLD)
	if not body.has_support():
		body.set_dynamic(true)


func _remove_body(body: TimberBody, wake_neighbours := true) -> void:
	_nav_mark(body, false)
	bodies.erase(body.key)
	var at := body.global_position
	var reach := body.span().y + 2.0
	body.collision_layer = 0
	body.queue_free()
	if wake_neighbours and is_inside_tree():
		_wake_unsupported_near.call_deferred(at, reach)


## Pieces that were resting on a removed piece must not hang in the air.
func _wake_unsupported_near(at: Vector3, reach: float) -> void:
	await get_tree().physics_frame
	for key in bodies:
		var b: TimberBody = bodies[key]
		if b.is_resting() and b.global_position.distance_to(at) < reach + b.span().y and not b.has_support():
			b.set_dynamic(true)


## A dynamic piece came to rest: repair it only if it is truly inaccessible.
func _nav_mark(b: TimberBody, on: bool) -> void:
	if not body_settled_hook.is_valid():
		return
	if on and not _nav_marked.has(b.key):
		_nav_marked[b.key] = true
		body_settled_hook.call(b, 1)
	elif not on and _nav_marked.has(b.key):
		_nav_marked.erase(b.key)
		body_settled_hook.call(b, -1)


func on_body_settled(b: TimberBody) -> void:
	_nav_mark(b, true)
	var reason := TimberRecovery.diagnose(b)
	if reason != "":
		_recover_body(b, reason)
	elif not b.has_support():
		b.set_dynamic(true)


func body_of(sid: String) -> TimberBody:
	var s := segment(sid)
	if s.is_empty():
		return null
	var tid := int(sid.trim_prefix("T").split("_S")[0])
	for key in bodies:
		var b: TimberBody = bodies[key]
		if b.tree_id == tid and int(s.k) in b.ks:
			return b
	return null


# ------------------------------------------------------------------ carrying

func carried_mte() -> int:
	return carrier_mte("player")


## The list a carrier holds ("player" is the boss's bundle).
func load_of(carrier: String) -> Array:
	if carrier == "player":
		return carried
	if not loads.has(carrier):
		loads[carrier] = []
	return loads[carrier]


## A carrier with one piece heavier than its hand budget is dragging it.
func is_dragging(carrier: String, budget := HAND_BUDGET_MTE) -> bool:
	var h := load_of(carrier)
	return h.size() == 1 and int(segment(str(h[0])).mte) > budget + 2


func carrier_mte(carrier: String) -> int:
	var total := 0
	for sid in load_of(carrier):
		total += int(segment(sid).mte)
	return total


## Picks up a single free piece into the player's bundle. Budget check uses
## integer mTE; Stronger carriers pass a larger budget.
func pick_up(body: TimberBody, budget := HAND_BUDGET_MTE) -> Dictionary:
	return pick_up_for("player", body, budget)


## Shared pickup for the boss and workers: one authoritative transaction, so
## two hands can never take the same piece.
func pick_up_for(carrier: String, body: TimberBody, budget := HAND_BUDGET_MTE, allow_drag := false) -> Dictionary:
	if body == null or not is_instance_valid(body) or not bodies.has(body.key):
		return {"ok": false, "reason": "That piece is gone."}
	if body.ks.size() != 1 or body.crown:
		return {"ok": false, "reason": "Cut this section free first."}
	var sid: String = records[body.tree_id].segments[body.ks[0]].sid
	if claims.has(sid) and claims[sid] != carrier:
		return {"ok": false, "reason": "Someone else is handling this piece."}
	var s := segment(sid)
	var held := load_of(carrier)
	# Workers carry at most four pieces (what fits on a shoulder visibly).
	# Phase 13: a single piece up to two hand loads can be DRAGGED by one end
	# (slowly, nothing else in hand); heavier pieces need the cart or a truck.
	var drag := allow_drag and held.is_empty() and int(s.mte) > budget and int(s.mte) <= budget * 2 + 2
	if not drag and ((carrier != "player" and held.size() >= 4) or carrier_mte(carrier) + int(s.mte) > budget + 2):
		if held.is_empty() and int(s.mte) <= budget * 2 + 2:
			return {"ok": false, "reason": "Too heavy to lift (%d%% of a hand load). Drag it (%s) or use the cart." % [int(100.0 * int(s.mte) / budget), "hold to drag"]}
		return {"ok": false, "reason": "Too heavy to add to your load (%d%% of a hand load)." % int(100.0 * (carrier_mte(carrier) + int(s.mte)) / budget)}
	# Record first, then visuals: the piece is CARRIED before the body goes.
	held.append(sid)
	claims[sid] = carrier
	_set_state(sid, Seg.CARRIED)
	_remove_body(body)
	carried_changed.emit()
	return {"ok": true, "sid": sid}


## Phase 5: moves one held piece from one carrier to another (hands ->
## truck bed). Atomic: the piece leaves the first list and joins the second
## in one step; in a vehicle it is VEHICLE_RESERVED to that truck.
func transfer(from_carrier: String, to_carrier: String, sid: String, to_budget: int) -> bool:
	var src := load_of(from_carrier)
	if not sid in src:
		return false
	var s := segment(sid)
	if carrier_mte(to_carrier) + int(s.mte) > to_budget:
		return false
	src.erase(sid)
	load_of(to_carrier).append(sid)
	claims[sid] = to_carrier
	_set_state(sid, Seg.VEHICLE_RESERVED if to_carrier.begins_with("truck:") else Seg.CARRIED)
	carried_changed.emit()
	return true


## Sets a carried piece down (caller validated the spot): `centre` is where
## the middle of the piece goes, `dir` its lengthwise direction.
func put_down(sid: String, centre: Vector3, dir: Vector3, dynamic: bool) -> TimberBody:
	return put_down_for("player", sid, centre, dir, dynamic)


func put_down_for(carrier: String, sid: String, centre: Vector3, dir: Vector3, dynamic: bool) -> TimberBody:
	var held := load_of(carrier)
	if not sid in held:
		return null
	var s := segment(sid)
	var tid := int(sid.trim_prefix("T").split("_S")[0])
	var k: int = s.k
	var basis := TimberMesh.frame_for(dir)
	var mid := (float(s.a) + float(s.b)) * 0.5
	held.erase(sid)
	claims.erase(sid)
	var ks: Array[int] = [k]
	var b := _make_body(tid, ks, false, Transform3D(basis, centre - basis.y * mid), dynamic)
	carried_changed.emit()
	return b


# ------------------------------------------------------- delivery and burning

## Accepts pieces into the camp delivery queue. The ONLY place entitlement
## receipts are created. Idempotent per segment.
##
## Phase 13: with a yard, each piece first needs a reserved destination at
## `at` (a free cradle slot, or the deck it is delivered onto). No
## destination = the piece is NOT accepted and NOT paid; `last_refusal`
## says why and the carrier/truck keeps it.
var last_refusal := ""


func accept(sids: Array, source: String, at := Vector3.INF) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	last_refusal = ""
	if accept_gate.is_valid() and not bool(accept_gate.call()):
		last_refusal = "Deliveries are closed."
		return out
	for sid in sids:
		var s := segment(sid)
		if s.is_empty() or int(s.state) >= Seg.ACCEPTED_QUEUED or str(s.receipt) != "":
			continue
		if int(s.state) not in [Seg.CARRIED, Seg.WORLD, Seg.VEHICLE_RESERVED]:
			continue
		var dest := ""
		if Game.yard and is_instance_valid(Game.yard):
			dest = Game.yard.intake_destination(sid, at)
			if dest == "":
				last_refusal = Game.yard.last_reason
				continue
		_receipt_counter += 1
		var r := {"id": "RCPT-%06d" % _receipt_counter, "sid": sid, "tree": int(sid.trim_prefix("T").split("_S")[0]), "mte": int(s.mte), "cents": int(s.cents), "source": source, "time": Game.world_time, "settled": false}
		s.receipt = r.id
		receipts.append(r)
		carried.erase(sid)
		for c in loads:
			(loads[c] as Array).erase(sid)
		var b := body_of(sid)
		if b:
			_remove_body(b)
		claims.erase(sid)
		if dest != "":
			Game.yard.receive(sid, dest)
		else:
			queue.append(sid)
			_set_state(sid, Seg.ACCEPTED_QUEUED)
		delivery_accepted.emit(r)
		out.append(r)
	if not out.is_empty():
		carried_changed.emit()
		queue_changed.emit()
	return out


func queue_mte() -> int:
	var t := 0
	for sid in queue:
		t += int(segment(sid).mte)
	return t


func burning_mte() -> float:
	var t := 0.0
	for sid in burning:
		var s := segment(sid)
		t += float(s.mte) * (1.0 - float(s.burn))
	return t


## Advances combustion by `seconds` of simulated time (also used for the
## bounded overnight advance). Pause stops it because the world is paused.
func advance_burn(seconds: float) -> void:
	var remaining := seconds
	var guard := 0
	while remaining > 0.0 and guard < 10000:
		guard += 1
		while burning.size() < BURN_SLOTS and not queue.is_empty():
			var sid: String = queue.pop_front()
			burning.append(sid)
			_set_state(sid, Seg.BURNING)
		if burning.is_empty():
			return
		var step := minf(remaining, 5.0)
		var done: Array[String] = []
		var boost := 1.0 + clampf(float(queue_mte()) / TREE_MTE, 0.0, 1.0) * BURN_BACKLOG_BOOST
		for sid in burning:
			var s := segment(sid)
			var dur := BURN_SECONDS_PER_THIRD * maxf(float(s.mte), 20.0) / float(HAND_BUDGET_MTE) / boost
			s.burn = minf(float(s.burn) + step / dur, 1.0)
			if float(s.burn) >= 1.0:
				done.append(sid)
		for sid in done:
			burning.erase(sid)
			_set_state(sid, Seg.CONSUMED)
			piece_consumed.emit(sid)
		if not done.is_empty():
			queue_changed.emit()
		remaining -= step


func _process(delta: float) -> void:
	# Pause stops burning (this node pauses with the tree); time scale
	# follows the shared world clock.
	if not get_tree().paused:
		var dt := delta * Game.time_scale
		update_fire_weather(dt, Game.weather.rain if Game.weather else 0.0)
		advance_burn(dt * burn_factor())


# ------------------------------------------------- rain on the open pit
# Phase 23 (owner request): rain soaks the fire. Drizzle and short showers
# only beat it down to a smoky smoulder (it burns slower); steady rain or a
# storm puts it out. Nothing burns while it is out (the logs wait in the pit
# and on the pile; contract delivery never depended on burning). It is
# relit by the player once the rain eases, by the crew after two dry
# minutes of the workday, or by the crew in the morning.

const FIRE_RAIN_MIN := 0.06        # lighter than this the fire shrugs it off
const FIRE_SOAK_S := 150.0         # heat lost per second = (rain - 0.06) / 150
const FIRE_DRY_S := 90.0           # a smouldering fire recovers in ~90 s dry
const FIRE_RELIGHT_RAIN := 0.3     # too wet to relight above this
const FIRE_CREW_RELIGHT_S := 120.0

signal fire_state_changed(out: bool, by: String)

var fire_heat := 1.0               # 1 = healthy, < ~0.6 smouldering
var fire_out := false
var fire_dry_s := 0.0              # seconds without rain since it went out


func update_fire_weather(dt: float, rain: float) -> void:
	if dt <= 0.0:
		return
	if fire_out:
		fire_dry_s = fire_dry_s + dt if rain < 0.05 else 0.0
		if fire_dry_s >= FIRE_CREW_RELIGHT_S and _crew_can_relight():
			relight("crew")
		return
	if rain > FIRE_RAIN_MIN:
		fire_heat = maxf(fire_heat - dt * (rain - FIRE_RAIN_MIN) / FIRE_SOAK_S, 0.0)
		if fire_heat <= 0.0:
			fire_out = true
			fire_dry_s = 0.0
			fire_state_changed.emit(true, "rain")
			_fire_notice("The rain has put the burn-pit fire out.")
	else:
		fire_heat = minf(fire_heat + dt / FIRE_DRY_S, 1.0)


## How fast the pit burns now: 0 when out, slower while smouldering.
func burn_factor() -> float:
	return 0.0 if fire_out else lerpf(0.25, 1.0, fire_heat)


func fire_smouldering() -> bool:
	return not fire_out and fire_heat < 0.6


## "" if it can be relit now, else why not.
func relight_blocker(rain: float) -> String:
	if not fire_out:
		return "already burning"
	if rain > FIRE_RELIGHT_RAIN:
		return "too wet: it's still pouring"
	return ""


func relight(by: String) -> bool:
	if not fire_out:
		return false
	fire_out = false
	fire_heat = 0.35                # starts smouldering and catches up dry
	fire_dry_s = 0.0
	fire_state_changed.emit(false, by)
	if by == "crew":
		_fire_notice("The crew relit the burn-pit fire now the rain has passed.")
	return true


func _fire_notice(text: String) -> void:
	var cs: CampaignService = Game.campaign
	if cs and (cs.active or cs.test_route) and not Game.is_preview():
		cs.notice.emit(text, 5.0)


func _crew_can_relight() -> bool:
	var cs: CampaignService = Game.campaign
	if cs == null or cs.clock == null or cs.clock.phase() == WorkdayClock.Phase.NIGHT:
		return false
	if Game.hunt and Game.hunt.hunt_active():
		return false
	return Game.crew != null and not Game.crew.workers.is_empty()


## Fire intensity 0..1.5 from the actual fuel in the pit (FirePit reads it),
## damped while smouldering and nothing while out.
func fire_level() -> float:
	if burning.is_empty() or fire_out:
		return 0.0
	var f := burning_mte() / float(HAND_BUDGET_MTE * BURN_SLOTS)
	return clampf(0.35 + f * 0.9 + clampf(float(queue_mte()) / TREE_MTE, 0.0, 1.0) * 0.25, 0.0, 1.5) * lerpf(0.2, 1.0, fire_heat)


# ----------------------------------------------------------------- recovery

## Inspects free timber and repairs only genuinely inaccessible pieces.
## Recovery keeps ID, quantity, share and acceptance flags; never pays.
func run_recovery() -> int:
	var fixed := 0
	for key in bodies.keys():
		var b: TimberBody = bodies[key]
		var reason := TimberRecovery.diagnose(b)
		if reason != "":
			_recover_body(b, reason)
			fixed += 1
	return fixed


func _recover_body(b: TimberBody, reason: String) -> void:
	var from := b.global_position
	var target := TimberRecovery.recover(b)
	for sid in b.sid_list():
		recovery_log.append({"sid": sid, "reason": reason, "from": [snappedf(from.x, 0.1), snappedf(from.y, 0.1), snappedf(from.z, 0.1)], "to": target, "time": Game.world_time})
		recovered.emit(sid, reason)
	push_warning("TimberRecovery: %s %s -> %s" % [str(b.sid_list()), reason, target])


# -------------------------------------------------------------- reconciliation

## Per-tree conservation check: quantities and cents by state always sum to
## the tree totals; accepted+consumed never double-counted.
func reconcile(tree_id: int) -> Dictionary:
	var rec: Dictionary = records[tree_id]
	var by_state := {}
	var mte := 0
	var cents := 0
	var receipt_cents := 0
	for s in rec.segments:
		var st: String = Seg.keys()[int(s.state)]
		by_state[st] = int(by_state.get(st, 0)) + int(s.mte)
		mte += int(s.mte)
		cents += int(s.cents)
	for r in receipts:
		if int(r.tree) == tree_id:
			receipt_cents += int(r.cents)
	return {"tree": tree_id, "mte_total": mte, "cents_total": cents, "receipt_cents": receipt_cents, "by_state": by_state, "ok": mte == TREE_MTE and cents == TREE_CENTS and receipt_cents <= TREE_CENTS, "nonpayable": "crown/branch brush, chips, stump residue"}


## Contract view: every share of this tree has been accepted at camp
## (queued, burning or consumed). Burning to ash is NOT required.
func tree_delivered(tree_id: int) -> bool:
	if not records.has(tree_id):
		return false
	for s in records[tree_id].segments:
		if int(s.state) < Seg.ACCEPTED_QUEUED:
			return false
	return true


## Optional final-ash cleanup view (separate from contract delivery).
func ash_clean() -> bool:
	if Game.yard and is_instance_valid(Game.yard) and Game.yard.stock_count() > 0:
		return false
	return queue.is_empty() and burning.is_empty()


func totals() -> Dictionary:
	var accepted_mte := 0
	var entitlement := 0
	for r in receipts:
		accepted_mte += int(r.mte)
		entitlement += int(r.cents)
	return {"accepted_mte": accepted_mte, "entitlement_cents": entitlement, "queue_mte": queue_mte(), "burning": burning.size(), "queued": queue.size(), "receipts": receipts.size(), "bodies": bodies.size(), "trees": records.size()}


func reconcile_all() -> Array:
	var out := []
	for id in records:
		out.append(reconcile(id))
	return out


# ------------------------------------------------------------- future hooks

## Workers (Prompt 4) claim a piece before acting on it; offscreen work still
## goes through accept()/put_down() so conservation holds.
func claim(sid: String, claimant: String) -> bool:
	if claims.has(sid) and claims[sid] != claimant:
		return false
	claims[sid] = claimant
	return true


func release(sid: String, claimant: String) -> void:
	if claims.get(sid, "") == claimant:
		claims.erase(sid)


## Trucks (Prompt 5): reserve pieces as cargo; acceptance later uses accept()
## with the bay as source. Implemented as a reservation only in Phase 2.
func reserve_for_vehicle(sids: Array, vehicle_id: String) -> void:
	for sid in sids:
		var s := segment(sid)
		if int(s.get("state", -1)) == Seg.WORLD:
			claims[sid] = vehicle_id
			_set_state(sid, Seg.VEHICLE_RESERVED)


# ---------------------------------------------------------------- persistence

func capture() -> Dictionary:
	var recs := {}
	for id in records:
		var r: Dictionary = records[id]
		var segs := []
		for sg in r.segments:
			segs.append({"k": sg.k, "state": sg.state, "receipt": sg.receipt, "burn": sg.burn})
		var bds := []
		for bd in r.bounds:
			bds.append({"work": bd.work, "cut": bd.cut})
		recs[str(id)] = {"plan": str(r.get("plan", PLAN_V1)), "segments": segs, "bounds": bds, "crown": {"attached": r.crown.attached, "work": r.crown.work}}
	var body_list := []
	for key in bodies:
		var b: TimberBody = bodies[key]
		body_list.append({"tree": b.tree_id, "ks": b.ks.duplicate(), "crown": b.crown, "pose": TreeService._xf_to_array(b.global_transform)})
	var out := {"records": recs, "bodies": body_list, "carried": carried.duplicate(), "loads": loads.duplicate(true), "queue": queue.duplicate(), "burning": burning.duplicate(), "receipts": receipts.duplicate(true), "receipt_counter": _receipt_counter, "recovery_log": recovery_log.slice(-50),
		"fire": {"heat": snappedf(fire_heat, 0.001), "out": fire_out, "dry_s": snappedf(fire_dry_s, 0.1)}}
	# Phase 13: yard places of accepted wood (cradle / decks / mid-move).
	if Game.yard and is_instance_valid(Game.yard):
		out["yard"] = Game.yard.capture()
		# Accepted pieces in hands are yard moves, not unpaid carried wood.
		var c2: Array = out.carried
		for sid in c2.duplicate():
			if Game.yard.is_yard_move(str(sid)):
				c2.erase(sid)
		for c in out.loads:
			for sid in (out.loads[c] as Array).duplicate():
				if Game.yard.is_yard_move(str(sid)):
					(out.loads[c] as Array).erase(sid)
	return out


## Rebuilds the ledger from a save. Ownership is re-derived and validated:
## each segment ends up in exactly one place (body, hands, queue, pit or
## consumed); a segment claimed twice keeps its most-advanced legal owner.
func restore(data: Dictionary) -> void:
	clear_all()
	var fd: Dictionary = data.get("fire", {})
	fire_heat = clampf(float(fd.get("heat", 1.0)), 0.0, 1.0)
	fire_out = bool(fd.get("out", false))
	fire_dry_s = float(fd.get("dry_s", 0.0))
	for key in data.get("records", {}):
		var id := int(key)
		var idx: int = Game.vegetation.tree_index_by_id.get(id, -1) if Game.vegetation else id
		if idx < 0:
			push_warning("TimberService: save references unknown tree %d (ignored)" % id)
			continue
		records[id] = _build_record(id, idx, data.records[key])
	receipts.clear()
	for r in data.get("receipts", []):
		receipts.append(r)
	_receipt_counter = maxi(int(data.get("receipt_counter", 0)), receipts.size())
	# Accepted shares are defined by receipts; their segments are never world timber.
	var accepted := {}
	for r in receipts:
		accepted[str(r.sid)] = true
	for sid in data.get("burning", []):
		if accepted.has(str(sid)) and not str(sid) in burning:
			burning.append(str(sid))
	for sid in data.get("queue", []):
		if accepted.has(str(sid)) and not str(sid) in burning and not str(sid) in queue:
			queue.append(str(sid))
	# Phase 13 yard places (accepted pieces only; never re-paid).
	var yard_places := {}
	if Game.yard and is_instance_valid(Game.yard):
		var yd: Dictionary = data.get("yard", {})
		var clean := {}
		for sid in accepted:
			if not str(sid) in burning and not str(sid) in queue:
				clean[sid] = true
		Game.yard.restore(yd, clean)
		yard_places = Game.yard.all_yard_sids()
	for sid in accepted:
		var sg := segment(sid)
		if sg.is_empty():
			continue
		if sid in burning:
			sg.state = Seg.BURNING
		elif sid in queue:
			sg.state = Seg.ACCEPTED_QUEUED
		elif yard_places.has(sid):
			sg.state = Seg.ACCEPTED_STAGED if str(yard_places[sid]) == "cradle" else Seg.ACCEPTED_RACKED
		else:
			sg.state = Seg.CONSUMED
	for sid in data.get("carried", []):
		var sg := segment(str(sid))
		if not sg.is_empty() and not accepted.has(str(sid)) and not str(sid) in carried:
			carried.append(str(sid))
			sg.state = Seg.CARRIED
			claims[str(sid)] = "player"
	for c in data.get("loads", {}):
		for sid in data.loads[c]:
			var sg := segment(str(sid))
			if not sg.is_empty() and not accepted.has(str(sid)) and not str(sid) in carried and not _in_any_load(str(sid)):
				load_of(str(c)).append(str(sid))
				sg.state = Seg.VEHICLE_RESERVED if str(c).begins_with("truck:") else Seg.CARRIED
				claims[str(sid)] = str(c)
	var placed := {}
	for bd in data.get("bodies", []):
		var tid := int(bd.tree)
		if not records.has(tid):
			continue
		var ks: Array[int] = []
		for k in bd.ks:
			var sg: Dictionary = records[tid].segments[int(k)] if int(k) < records[tid].segments.size() else {}
			if sg.is_empty() or accepted.has(str(sg.sid)) or str(sg.sid) in carried or _in_any_load(str(sg.sid)) or placed.has(str(sg.sid)):
				continue
			ks.append(int(k))
			placed[str(sg.sid)] = true
		if ks.is_empty():
			continue
		var crown: bool = bool(bd.crown) and bool(records[tid].crown.attached) and ks.max() == records[tid].segments.size() - 1
		_make_body(tid, ks, crown, TreeService.array_to_xf(bd.pose), false)
	# Any segment still unowned (e.g. a save taken from an older build) gets
	# a body at its tree's stump so it can never vanish from the contract.
	for id in records:
		for sg in records[id].segments:
			var sid: String = sg.sid
			if accepted.has(sid) or sid in carried or _in_any_load(sid) or placed.has(sid):
				continue
			var stump := World.tree_position(int(records[id].idx))
			var ks2: Array[int] = [int(sg.k)]
			var b := _make_body(id, ks2, false, Transform3D(TimberMesh.frame_for(Vector3.RIGHT), stump + Vector3(1.5, 0.4, 0) - TimberMesh.frame_for(Vector3.RIGHT).y * float(sg.a)), true)
			b.name += "_orphan"
			recovery_log.append({"sid": sid, "reason": "invalid_pose", "to": "stump", "time": Game.world_time})
	for r in data.get("recovery_log", []):
		recovery_log.append(r)
	# Pre-Phase-13 saves: the accepted backlog moves from the pit queue onto
	# the decks once (no payment or burn change).
	if Game.yard and is_instance_valid(Game.yard) and not data.has("yard"):
		var moved: int = Game.yard.migrate_old_queue()
		if moved > 0:
			recovery_log.append({"sid": "*", "reason": "phase13_queue_to_decks", "to": "%d pieces" % moved, "time": Game.world_time})
	elif Game.yard and is_instance_valid(Game.yard):
		Game.yard.migrated_queue = true
	carried_changed.emit()
	queue_changed.emit()


func _in_any_load(sid: String) -> bool:
	for c in loads:
		if sid in (loads[c] as Array):
			return true
	return false


func clear_all() -> void:
	for key in bodies:
		_nav_mark(bodies[key], false)
	for key in bodies:
		(bodies[key] as Node).queue_free()
	bodies.clear()
	records.clear()
	carried.clear()
	loads.clear()
	queue.clear()
	burning.clear()
	receipts.clear()
	if Game.yard and is_instance_valid(Game.yard):
		Game.yard.restore({"migrated_queue": true}, {})
	claims.clear()
	recovery_log.clear()
	_receipt_counter = 0
	_body_counter = 0
