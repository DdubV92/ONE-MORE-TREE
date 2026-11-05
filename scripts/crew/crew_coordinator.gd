class_name CrewCoordinator
extends RefCounted
## Phase 14: coordination around the real logging pipeline.
##
## Felling lanes. Each tree a worker is felling owns a lane: a strip from
## its base along the actual fall plan (predicted from the cut side until
## the first contact fixes TreeService's fall_dir), as long as the tree is
## tall plus a margin and as wide as its crown - not a sphere that freezes
## the whole camp. While a lane is active:
##  - no one else is assigned a tree whose lane overlaps it, a cut/stand
##    position inside it, or loose logs/trunks/stumps inside it;
##  - its island-grid cells cost much more to walk through (routes bend
##    around an active saw lane);
##  - at the fall warning, anyone else inside steps out sideways.
## A lane ends when the tree has settled into timber (or after a bounded
## timeout once it has fallen), or when its owner abandons the tree.
##
## Claim reaper. Claims (tree/trunk/stump/yard) whose owner left, quit,
## changed job or is no longer doing that task are released every few
## seconds, so nothing stays reserved forever.
##
## Team carry. An oversized log (heavier than one hand load) can be carried
## by two workers: one cargo owner (the leader holds the timber record),
## one follower at the far end. Both must be in place before the lift; the
## pair moves at the slower partner's carry speed x TEAM_FACTOR (not the
## sum). If the follower is called away, flees or must head home, the
## leader carries on alone by dragging (the Phase 13 supported solo
## fallback, always within two hand loads) - no dropped record, no
## duplicate, no one left attached. Teams are not saved: after a load the
## leader's log restores as a solo drag.

const LANE_MARGIN := 4.0
const LANE_TIMEOUT_AFTER_FALL := 30.0
const LANE_COST := 7.0
const TEAM_FACTOR := 0.9
const TEAM_WAIT := 25.0
const TEAM_RADIUS := 45.0

var crew: CrewService
var lanes := {}            # tree id -> lane dict
var teams := {}            # team id -> {"leader","follower","sid","state","since"}
var _team_counter := 0
var _reap_t := 0.0
var stats := {"lanes": 0, "step_outs": 0, "reaped": 0, "teams": 0, "team_lifts": 0, "team_breaks": 0, "lane_rejects": 0}


func _init(c: CrewService) -> void:
	crew = c


# ---------------------------------------------------------------- lanes

## Lane for tree index `idx` felled from `stand` (fall away from the cutter,
## or the recorded fall direction once notched).
func predict_lane(idx: int, stand: Vector3, owner := "") -> Dictionary:
	var base := Vector2(World.trees.x[idx], World.trees.z[idx])
	var dir := (base - Vector2(stand.x, stand.z))
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(0, 1)
	var tid: int = World.trees.id[idx]
	if Game.trees and Game.trees.records.has(tid):
		var fd: Array = Game.trees.records[tid].get("fall_dir", [])
		if fd.size() == 2 and Vector2(fd[0], fd[1]).length() > 0.01:
			dir = Vector2(fd[0], fd[1]).normalized()
	var h := float(World.trees.height[idx])
	var crown := clampf(h * 0.18, 2.0, 4.5)
	return {"tree": tid, "idx": idx, "base": base, "dir": dir, "len": h + LANE_MARGIN, "half_w": crown, "owner": owner, "since": crew.now(), "fell_at": -1.0, "cells": []}


## Is world point `p` inside `lane` (the strip plus a small skirt behind
## the stump)?
static func in_lane(lane: Dictionary, p: Vector3) -> bool:
	var d := Vector2(p.x, p.z) - (lane.base as Vector2)
	var along := d.dot(lane.dir)
	var side := absf(d.dot(Vector2(-(lane.dir as Vector2).y, (lane.dir as Vector2).x)))
	return along > -1.5 and along < float(lane.len) and side < float(lane.half_w)


static func lanes_overlap(a: Dictionary, b: Dictionary) -> bool:
	# Sample the centre line and edges of one lane against the other.
	for t in 9:
		var f := float(t) / 8.0
		var c: Vector2 = (a.base as Vector2) + (a.dir as Vector2) * float(a.len) * f
		var n := Vector2(-(a.dir as Vector2).y, (a.dir as Vector2).x) * float(a.half_w)
		for q in [c, c + n, c - n]:
			if in_lane(b, Vector3(q.x, 0, q.y)):
				return true
	return false


## Another worker's lane (not `me`'s) containing `p`, or -1.
func lane_at(p: Vector3, me := "") -> int:
	for tid in lanes:
		var l: Dictionary = lanes[tid]
		if str(l.owner) != me and in_lane(l, p):
			return int(tid)
	return -1


## True if felling tree `idx` from `stand` would conflict with live work:
## another active lane, someone else's work position inside the new lane,
## or this stand inside someone else's lane.
func fell_conflict(idx: int, stand: Vector3, me: Worker) -> bool:
	var lane := predict_lane(idx, stand, me.id)
	if lane_at(stand, me.id) >= 0:
		stats.lane_rejects += 1
		return true
	for tid in lanes:
		var other: Dictionary = lanes[tid]
		if str(other.owner) != me.id and (lanes_overlap(lane, other) or lanes_overlap(other, lane)):
			stats.lane_rejects += 1
			return true
	for o in crew.workers.values():
		var w := o as Worker
		if w == me or not w.activity in ["fell", "buck", "stump", "pick", "move", "retreat_wait", "team_follow"]:
			continue
		var at: Vector3 = w.target.get("stand", w.global_position)
		if in_lane(lane, at) or in_lane(lane, w.global_position):
			stats.lane_rejects += 1
			return true
	var p := Game.player
	if p and in_lane(lane, p.global_position):
		stats.lane_rejects += 1
		return true
	return false


func register_lane(tid: int, w: Worker, stand: Vector3) -> void:
	var idx: int = Game.vegetation.tree_index_by_id.get(tid, tid) if Game.vegetation else tid
	var lane := predict_lane(idx, stand, w.id)
	_set_cost(lane, true)
	lanes[tid] = lane
	stats.lanes += 1


func clear_lane(tid: int) -> void:
	if lanes.has(tid):
		_set_cost(lanes[tid], false)
		lanes.erase(tid)


## Recompute a lane's direction from the tree's recorded fall direction.
func refresh_lane(tid: int) -> void:
	if not lanes.has(tid):
		return
	var old: Dictionary = lanes[tid]
	_set_cost(old, false)
	var stand := Vector3((old.base as Vector2).x, 0, (old.base as Vector2).y) - Vector3((old.dir as Vector2).x, 0, (old.dir as Vector2).y)
	var nl := predict_lane(int(old.idx), stand, str(old.owner))
	nl.since = old.since
	nl.fell_at = old.fell_at
	_set_cost(nl, true)
	lanes[tid] = nl


func _set_cost(lane: Dictionary, on: bool) -> void:
	var nav: CrewNav = crew.nav
	if nav == null:
		return
	var cells: Array = lane.cells
	if on:
		cells.clear()
		var steps := int(ceil(float(lane.len) / (CrewNav.CELL * 0.5)))
		for s in steps + 1:
			var c: Vector2 = (lane.base as Vector2) + (lane.dir as Vector2) * float(s) * CrewNav.CELL * 0.5
			for side in [-1.0, 0.0, 1.0]:
				var q: Vector2 = c + Vector2(-(lane.dir as Vector2).y, (lane.dir as Vector2).x) * float(lane.half_w) * 0.8 * side
				var k := nav.to_cell(q)
				if not k in cells:
					cells.append(k)
	for k in cells:
		nav.lane_penalty(k, on)


## Fall warning: everyone else inside the lane steps out to the nearer side.
func on_warning(tid: int) -> void:
	if not lanes.has(tid):
		return
	var lane: Dictionary = lanes[tid]
	for o in crew.workers.values():
		var w := o as Worker
		if w.id == str(lane.owner) or not in_lane(lane, w.global_position):
			continue
		if w.activity in ["seated", "sleep", "hidden", "dead", "depart"]:
			continue
		var d := Vector2(w.global_position.x, w.global_position.z) - (lane.base as Vector2)
		var n := Vector2(-(lane.dir as Vector2).y, (lane.dir as Vector2).x)
		var sgn := 1.0 if d.dot(n) >= 0.0 else -1.0
		var out2 := Vector2(w.global_position.x, w.global_position.z) + n * sgn * (float(lane.half_w) + 2.5 - absf(d.dot(n)))
		var out := Vector3(out2.x, 0, out2.y)
		out.y = crew.nav.surface_at(out)
		crew.release_claims(w)
		break_team_of(w, "stepped clear of a falling tree")
		if w.is_carrying():
			# Keep the load in hand (carrying is legal); just move aside.
			pass
		w.go_to(out, "idle", "out of the fall line")
		stats.step_outs += 1


func on_felled(tid: int) -> void:
	if lanes.has(tid):
		lanes[tid].fell_at = crew.now()


# ---------------------------------------------------------------- upkeep

func tick(delta: float) -> void:
	var now := crew.now()
	for tid in lanes.keys():
		var l: Dictionary = lanes[tid]
		var st := Game.trees.state_of(int(tid)) if Game.trees else 0
		var owner: Worker = crew.workers.get(str(l.owner))
		var owned: bool = owner != null and owner.target.get("tree", -1) == int(tid) and owner.activity in ["fell", "move", "retreat", "retreat_wait"]
		if st >= TreeService.State.SECTIONED:
			clear_lane(int(tid))
		elif st == TreeService.State.FALLEN or st == TreeService.State.FALLING:
			if float(l.fell_at) < 0.0:
				l.fell_at = now
			if now - float(l.fell_at) > LANE_TIMEOUT_AFTER_FALL:
				clear_lane(int(tid))
		elif not owned and now - float(l.since) > 5.0:
			clear_lane(int(tid))          # owner abandoned the tree
		elif st == TreeService.State.NOTCHED and not bool(l.get("fixed", false)):
			l["fixed"] = true
			refresh_lane(int(tid))
	_tick_teams(delta)
	_reap_t -= delta
	if _reap_t <= 0.0:
		_reap_t = 4.0
		_reap_claims()


## Releases reservations whose owner is gone or no longer on that task.
func _reap_claims() -> void:
	for k in crew.claims.keys():
		var owner := str(crew.claims[k])
		if owner == "unreachable":
			continue
		var w: Worker = crew.workers.get(owner)
		var keep := false
		if w != null and str(w.emp.get("status", "")) == Payroll.ACTIVE:
			var kind := str(k).get_slice(":", 0)
			var id := int(str(k).get_slice(":", 1)) if str(k).get_slice(":", 1).is_valid_int() else -1
			match kind:
				"tree":
					keep = w.target.get("tree", -2) == id and w.activity in ["fell", "move", "retreat", "retreat_wait"]
				"trunk":
					keep = w.target.get("tree", -2) == id and w.activity in ["buck", "move"]
				"stump":
					keep = w.target.get("tree", -2) == id and w.activity in ["stump", "move"]
				_:
					keep = true                 # yard/rack slots: own release paths
		if not keep:
			crew.claims.erase(k)
			stats.reaped += 1


# ---------------------------------------------------------------- teams

## Looks for a free partner for `leader` to carry piece `sid` together.
## Returns the team id or "".
func form_team(leader: Worker, sid: String) -> String:
	var m := int(crew.timber.segment(sid).mte)
	var best: Worker = null
	var bd := TEAM_RADIUS
	for o in crew.workers.values():
		var w := o as Worker
		if w == leader or str(w.emp.get("status", "")) != Payroll.ACTIVE or w.is_carrying() or team_of(w) != "":
			continue
		if not w.activity in ["idle"] or str(w.emp.get("job", "automatic")) in ["home", "follow", "yard", "ride"]:
			continue
		if crew.carry_budget(leader) + crew.carry_budget(w) < m:
			continue
		var d := w.global_position.distance_to(leader.global_position)
		if d < bd:
			bd = d
			best = w
	if best == null:
		return ""
	_team_counter += 1
	var tid := "TEAM-%d" % _team_counter
	teams[tid] = {"leader": leader.id, "follower": best.id, "sid": sid, "state": "gather", "since": crew.now()}
	stats.teams += 1
	leader.team = tid
	best.start_team_follow(tid)
	return tid


func team_of(w: Worker) -> String:
	for t in teams:
		if str(teams[t].leader) == w.id or str(teams[t].follower) == w.id:
			return str(t)
	return ""


func follower_ready(tid: String) -> bool:
	if not teams.has(tid):
		return false
	var t: Dictionary = teams[tid]
	var f: Worker = crew.workers.get(str(t.follower))
	return f != null and f.activity == "team_follow" and f.target.get("team_ready", false)


func lifted(tid: String) -> void:
	if teams.has(tid):
		teams[tid].state = "carry"
		stats.team_lifts += 1
		var t: Dictionary = teams[tid]
		crew.progression.add_context("team_carry", str(t.leader), str(t.follower), [str(t.leader), str(t.follower)])


## The pair's walking speed: the slower partner's carry speed x TEAM_FACTOR.
func team_speed(tid: String) -> float:
	var t: Dictionary = teams.get(tid, {})
	var sp := INF
	for k in ["leader", "follower"]:
		var w: Worker = crew.workers.get(str(t.get(k, "")))
		if w:
			sp = minf(sp, Worker.CARRY_WALK * float(crew.tool_effects(w).walk_mult))
	return (sp if sp < INF else Worker.CARRY_WALK) * TEAM_FACTOR


## Ends a team safely: the leader keeps (and can drag) the log, the follower
## lets go. Never drops or duplicates the record.
func break_team_of(w: Worker, why: String) -> void:
	var tid := team_of(w)
	if tid == "":
		return
	var t: Dictionary = teams[tid]
	teams.erase(tid)
	stats.team_breaks += 1
	var f: Worker = crew.workers.get(str(t.follower))
	if f:
		f.team = ""
		if f != w and f.activity == "team_follow":
			f.activity = "idle"
			f.target = {}
		f.body_char.carry_grips = []
	var l: Worker = crew.workers.get(str(t.leader))
	if l:
		l.team = ""
		l.target["drag"] = true          # carries on alone (drag)
		l._carry_sig = ""                # redraw: far end back on the ground
	t["why"] = why


func end_team(tid: String) -> void:
	if not teams.has(tid):
		return
	var t: Dictionary = teams[tid]
	teams.erase(tid)
	var f: Worker = crew.workers.get(str(t.follower))
	if f:
		f.team = ""
		if f.activity == "team_follow":
			f.activity = "idle"
			f.target = {}
		f.body_char.carry_grips = []
	var l: Worker = crew.workers.get(str(t.leader))
	if l:
		l.team = ""


## Leader breadcrumbs (every 0.3 m) that the follower walks along.
func trail_point(tid: String, p: Vector3) -> void:
	if not teams.has(tid):
		return
	var tr: Array = teams[tid].get("trail", [])
	if tr.is_empty() or (tr[tr.size() - 1] as Vector3).distance_to(p) > 0.3:
		tr.append(p)
		if tr.size() > 60:
			tr.pop_front()
	teams[tid]["trail"] = tr


func _tick_teams(_delta: float) -> void:
	for tid in teams.keys():
		var t: Dictionary = teams[tid]
		var l: Worker = crew.workers.get(str(t.leader))
		var f: Worker = crew.workers.get(str(t.follower))
		if l == null or f == null or f.activity != "team_follow":
			break_team_of(l if l else f, "partner gone")
			continue
		if str(t.state) == "gather" and crew.now() - float(t.since) > TEAM_WAIT:
			break_team_of(l, "partner took too long")
			continue
		if str(t.state) == "carry" and not crew.timber.load_of(l.id).has(str(t.sid)):
			end_team(tid)           # delivered or set down: done


func capture() -> Dictionary:
	return {"stats": stats.duplicate()}
