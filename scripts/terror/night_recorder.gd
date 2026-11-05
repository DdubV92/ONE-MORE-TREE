class_name NightRecorder
extends Node
## Phase 20 (the Phase 19 expansion's "missed nights leave evidence, not
## punishment"): while the boss sleeps through a contract night, the world
## may produce ONE bounded, harmless incident, captured by a real camp
## camera before the morning settlement. 36 authored scenarios
## (data/terror/recordings.json, tools/content/night_recordings.py).
##
## A capture is a durable record of that night, built from the world AS IT
## IS at that moment: the camera and its transform, actor/prop tracks
## converted to real world points on the real terrain (validated: ground,
## water, sight lines, the scenario's prerequisites), sound events with
## their source points, light and weather, and which trees near the camera
## were already gone. The Recordings app replays it in an ISOLATED
## reconstruction (RecordingPlayer): nothing in it runs AI, pays, moves wood
## or touches the real dog. If no scenario validates, nothing happens -
## never a live view presented as yesterday.
##
## Morning: a camera bookmark notice and, for some scenarios, a cosmetic
## mark (wet prints, a moved chain, a branch) that is gone by midday. Never
## lost wood, tools, wages or a harmed dog; never a claim that contradicts
## where the crew actually slept.

const DATA := "res://data/terror/recordings.json"
const KEEP := 12             # retained clips (capacity policy)
const P_NIGHT := 0.35        # chance a night produces an incident
const MARK_UNTIL_T := 450.0  # cosmetic marks are gone by midday

var scenarios: Array = []
var by_id := {}
var clips: Array = []        # newest last (<= KEEP)
var total_captured := 0
var nights := {}             # "day" -> scenario id or "" (decided once)
var last_used := {}          # scenario id -> day
var marks: Array = []        # [{mark, pos, day}]
var pending_notice: Array = []
var stats := {"rolled": 0, "captured": 0, "rejected": {}}
var _mark_nodes: Array[Node3D] = []


func _ready() -> void:
	name = "NightRecorder"
	load_data()


func load_data() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	scenarios = (d as Dictionary).get("scenarios", []) if d is Dictionary else []
	by_id.clear()
	for s in scenarios:
		by_id[str(s.id)] = s


func _seed() -> int:
	if Game.campaign and Game.campaign.get("campaign_seed") != null:
		return int(Game.campaign.get("campaign_seed"))
	return 1717


func camera(id: String) -> Node3D:
	if Game.world_root == null:
		return null
	for c in Game.world_root.get_tree().get_nodes_in_group("security_camera"):
		if str((c as Node).get_meta("camera_id", "")) == id:
			return c as Node3D
	return null


# --------------------------------------------------------------- the night

## Called by CampaignService.sleep() BEFORE the settlement. Decides the
## night once (a reload or a second sleep never re-rolls it).
func on_night(d: int, force := "") -> Dictionary:
	var key := str(d)
	if nights.has(key) and force == "":
		return {}
	nights[key] = ""
	var c: CampaignService = Game.campaign
	if force == "":
		if c == null or d < 2 or (c.clock.is_final_day() and not c.legacy):
			return {}
		if Game.hunt and Game.hunt.hunt_active():
			return {}
		# Director budget: a night with a sleep interruption has no incident.
		if Game.sleep_interrupts and Game.sleep_interrupts.interrupted_night(d):
			return {}
		var r := RandomNumberGenerator.new()
		r.seed = hash("%d:%d:rec" % [_seed(), d])
		stats.rolled = int(stats.rolled) + 1
		if r.randf() > P_NIGHT:
			return {}
	var order := _candidates(d, force)
	for sid in order:
		var clip := capture(by_id[sid], d)
		if not clip.is_empty():
			nights[key] = sid
			last_used[sid] = d
			clips.append(clip)
			while clips.size() > KEEP:
				clips.pop_front()
			total_captured += 1
			stats.captured = int(stats.captured) + 1
			_queue_morning(clip)
			return clip
	return {}


func _candidates(d: int, force: String) -> Array:
	if force != "":
		return [force] if by_id.has(force) else []
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%d:pick" % [_seed(), d])
	var pool := []
	for s in scenarios:
		var sid := str(s.id)
		if last_used.has(sid) and d - int(last_used[sid]) < int(s.cooldown):
			continue
		pool.append([float(s.weight) * r.randf_range(0.2, 1.0), sid])
	pool.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return pool.map(func(p: Array) -> String: return str(p[1]))


func _reject(why: String) -> void:
	var rj: Dictionary = stats.rejected
	rj[why] = int(rj.get(why, 0)) + 1


# ------------------------------------------------------------- the capture

## Builds the durable record, or {} when the world cannot honestly stage it.
func capture(s: Dictionary, d: int) -> Dictionary:
	for cid in s.cameras:
		var cam := camera(str(cid))
		if cam == null:
			continue
		var why := _prereqs(s, cam)
		if why != "":
			_reject(why)
			continue
		var frame := _frame(cam)
		var actor := _convert_actor(s, cam, frame)
		if actor.has("fail"):
			_reject(str(actor.fail))
			continue
		var props := []
		var bad := ""
		for p in s.props:
			var cp := _convert_prop(p, cam, frame)
			if cp.has("fail"):
				bad = str(cp.fail)
				break
			props.append(cp)
		if bad != "":
			_reject(bad)
			continue
		var audio := []
		for a in s.audio:
			# Optional 6th field: the sound's own anchor (e.g. the real gate).
			var anchor := str(a[5]) if a.size() > 5 else str(s.actor.get("anchor", ""))
			var wp := _to_world(frame, float(a[2]), float(a[3]), anchor, cam) + Vector3(0, float(a[4]), 0)
			if not SoundBank.EVENTS.has(str(a[1])):
				bad = "sound " + str(a[1])
				break
			audio.append([float(a[0]), str(a[1]), wp.x, wp.y, wp.z])
		if bad != "":
			_reject(bad)
			continue
		var x := cam.global_transform
		var wx: Node = Game.weather
		var light := {"hour": float(s.hour), "moon": float(Game.environment.get("moon_phase")) if Game.environment else 0.3,
			"rain": float(wx.get("rain")) if wx and wx.get("rain") != null else 0.0, "wind": float(wx.get("wind_mult")) if wx and wx.get("wind_mult") != null else 1.0}
		return {"id": "R%02d-%s" % [d, str(s.id)], "scenario": str(s.id), "title": str(s.title), "day": d, "hour": float(s.hour), "clock": NightAnchors.hhmm(float(s.hour)),
			"camera": str(cid), "category": str(cam.get_meta("category", "")),
			"xform": [x.origin.x, x.origin.y, x.origin.z, x.basis.x.x, x.basis.x.y, x.basis.x.z, x.basis.y.x, x.basis.y.y, x.basis.y.z, x.basis.z.x, x.basis.z.y, x.basis.z.z],
			"duration": float(s.duration), "actor": actor, "props": props, "audio": audio, "light": light,
			"trees_absent": _absent_trees(x.origin, 110.0), "bookmark": ("motion" if str(actor.kind) != "none" or not props.is_empty() else "sound"),
			"consequence": (s.consequence as Dictionary).duplicate(), "captured_at": Game.world_time}
	return {}


## The camera's view frame on the ground: origin, forward and right
## (flattened), used to place view-frame coordinates on the terrain.
func _frame(cam: Node3D) -> Dictionary:
	var f := -cam.global_basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var r := Vector3(-f.z, 0.0, f.x)
	return {"o": cam.global_position, "f": f, "r": r}


func _to_world(fr: Dictionary, x: float, z: float, anchor := "", cam: Node3D = null) -> Vector3:
	var base: Vector3 = fr.o
	if anchor != "":
		var ap := _anchor(anchor, cam)
		if ap != Vector3.INF:
			base = ap
	var p: Vector3 = base + (fr.r as Vector3) * x + (fr.f as Vector3) * z
	var floor_y := World.height_at(p.x, p.z)
	if anchor == "camper_door" and z <= 0.05:
		floor_y = maxf(floor_y, base.y - 1.0)       # inside the door glass: camper floor
	return Vector3(p.x, floor_y, p.z)


func _anchor(name: String, cam: Node3D) -> Vector3:
	match name:
		"facing_window":
			return NightAnchors.point("cabin") if str(cam.get_meta("camera_id", "")) == "CAM_02" else NightAnchors.point("camper_door")
		"cabin_front":
			var cb := NightAnchors.point("cabin")
			var tc := cam.global_position - cb
			tc.y = 0.0
			var half := CampLayout.CABIN_SIZE.x * 0.5 if absf(tc.x) > absf(tc.z) else CampLayout.CABIN_SIZE.z * 0.5
			return cb + tc.normalized() * (half + 1.6)
		"locker_behind":
			var lp := NightAnchors.point("locker")
			var away := (lp - cam.global_position)
			away.y = 0.0
			return lp + away.normalized() * 1.1
	return NightAnchors.point(name)


func _visible(cam: Node3D, p: Vector3, tol := 1.0) -> String:
	var a := cam.global_position + (-cam.global_basis.z) * 0.3
	var d := a.distance_to(p)
	var steps := int(ceil(d / 6.0))
	for k in range(1, steps):
		var q := a.lerp(p, float(k) / steps)
		if World.height_at(q.x, q.z) > q.y + 0.2:
			return "terrain"
	var vp := get_viewport()
	if vp and vp.world_3d:
		var qr := PhysicsRayQueryParameters3D.create(a, p, 1)
		var hit := vp.world_3d.direct_space_state.intersect_ray(qr)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(p) > tol:
			return "structure"
	# Inside the camera's field of view (70 degrees, with margin).
	var to := (p - cam.global_position).normalized()
	if (-cam.global_basis.z).dot(to) < cos(deg_to_rad(42.0)):
		return "out_of_frame"
	return ""


func _convert_actor(s: Dictionary, cam: Node3D, fr: Dictionary) -> Dictionary:
	var a: Dictionary = s.actor
	var kind := str(a.get("kind", "none"))
	var out := {"kind": kind, "keys": [], "hidden": a.get("hidden", []), "kneel": a.get("kneel", [])}
	if kind == "none":
		return out
	var anchor := str(a.get("anchor", ""))
	var vis_h := float(a.get("vis_h", 1.2 if kind == "figure" else 0.4))
	if bool(a.get("search", false)):
		return _search_crest(cam, fr, a, out, vis_h)
	var n_vis := 0
	var n := 0
	for k in a.track:
		var p := _to_world(fr, float(k[1]), float(k[2]), anchor, cam)
		if kind == "figure" and p.y < World.sea_level - 0.3:
			return {"fail": "actor in water"}
		(out.keys as Array).append([float(k[0]), p.x, p.y, p.z])
		n += 1
		if _visible(cam, p + Vector3(0, vis_h, 0)) == "":
			n_vis += 1
	if bool(a.get("end_occluded", false)):
		var last: Array = (out.keys as Array)[(out.keys as Array).size() - 1]
		if _visible(cam, Vector3(last[1], float(last[2]) + 1.2, last[3])) != "terrain":
			return {"fail": "no crest to leave behind"}
		n_vis += 1
	if n > 0 and n_vis < int(ceil(n * 0.5)):
		return {"fail": "actor not in view"}
	return out


## "Waits behind a crest and leaves by an occluded route": find, on the real
## terrain, a waiting point the camera sees and a nearby exit point that a
## terrain crest hides from it (or fail honestly).
func _search_crest(cam: Node3D, fr: Dictionary, a: Dictionary, out: Dictionary, vis_h: float) -> Dictionary:
	var tr: Array = a.track
	var t_wait := float(tr[1][0]) if tr.size() > 1 else 6.0
	var t_end := float(tr[tr.size() - 1][0])
	for z in [40.0, 55.0, 70.0, 90.0, 110.0]:
		for x in [0.0, -12.0, 12.0, -25.0, 25.0]:
			var w := _to_world(fr, x, z)
			if w.y < World.sea_level + 0.5 or _visible(cam, w + Vector3(0, vis_h, 0)) != "":
				continue
			for ex in [Vector2(14, 12), Vector2(-14, 12), Vector2(0, 22), Vector2(20, 0), Vector2(-20, 0)]:
				var e := _to_world(fr, x + ex.x, z + ex.y)
				if e.y < World.sea_level + 0.5:
					continue
				if _visible(cam, e + Vector3(0, vis_h, 0)) == "terrain":
					out.keys = [[0.0, w.x, w.y, w.z], [t_wait, w.x, w.y, w.z], [t_end, e.x, e.y, e.z]]
					return out
	return {"fail": "no crest to leave behind"}


func _convert_prop(p: Dictionary, cam: Node3D, fr: Dictionary) -> Dictionary:
	var o := p.duplicate(true)
	var anchor := str(p.get("anchor", ""))
	if p.has("x") and p.has("z"):
		var w := _to_world(fr, float(p.x), float(p.z), anchor, cam)
		o["pos"] = [w.x, w.y, w.z]
	elif anchor != "":
		var ap := _anchor(anchor, cam)
		if ap == Vector3.INF:
			return {"fail": "no " + anchor}
		o["pos"] = [ap.x, ap.y, ap.z]
	match str(p.kind):
		"prints", "light_bob", "shadow_walk":
			var pts := []
			for k in p.track:
				var w2 := _to_world(fr, float(k[1]), float(k[2]), "", cam)
				pts.append([float(k[0]), w2.x, w2.y, w2.z])
			o["points"] = pts
		"pit_glow":
			var pp := NightAnchors.point("pit")
			o["pos"] = [pp.x, pp.y, pp.z]
		"lamp_occlude":
			var lamp := _lamp_in_view(cam)
			if lamp == Vector3.INF:
				return {"fail": "no lamp in view"}
			o["pos"] = [lamp.x, lamp.y, lamp.z]
		"gate_swing", "chain":
			# The real gate leaf and its chain (CampLayout.GATE_*): on the
			# ground at the anchor, and the camera must actually see the leaf.
			if anchor != "" and not (p.has("x") and p.has("z")):
				var gp := Vector3(float(o.pos[0]), 0.0, float(o.pos[2]))
				o["pos"] = [gp.x, World.height_at(gp.x, gp.z), gp.z]
				var why := _visible(cam, NightAnchors.point("gate_mid"), 0.6)
				if why != "":
					return {"fail": "gate " + why}
				var leaf := cam.get_tree().get_first_node_in_group("camp_gate_leaf") as Node3D
				o["yaw0"] = leaf.global_rotation.y if leaf else 0.0
		"truck_door":
			var tp := NightAnchors.point("truck")
			if tp == Vector3.INF:
				return {"fail": "no truck"}
			o["pos"] = [tp.x, tp.y, tp.z]
	return o


func _lamp_in_view(cam: Node3D) -> Vector3:
	for l in cam.get_tree().get_nodes_in_group("camp_lamps"):
		var lp := (l as Node3D).global_position + Vector3(0, 2.5, 0)
		if _visible(cam, lp) == "":
			return lp
	return Vector3.INF


func _absent_trees(c: Vector3, r: float) -> Array:
	var out := []
	for id in World.removed_trees:
		var idx: int = int(Game.vegetation.tree_index_by_id.get(int(id), -1)) if Game.vegetation else -1
		if idx >= 0 and World.tree_position(idx).distance_to(c) < r:
			out.append(int(id))
	return out


# ---------------------------------------------------------- prerequisites

func _prereqs(s: Dictionary, cam: Node3D) -> String:
	for tok in s.requires:
		var t := str(tok)
		if not prereq_ok(t, cam, s):
			return "prereq " + t
	return ""


func prereq_ok(t: String, cam: Node3D, s: Dictionary = {}) -> bool:
	var c: CampaignService = Game.campaign
	var wx: Node = Game.weather
	if t.begins_with("day>="):
		return c != null and c.clock.day >= int(t.substr(5))
	if t.begins_with("cleared>="):
		if has_meta("fixture_cleared"):
			return bool(get_meta("fixture_cleared"))   # labelled test fixture only
		if c == null or c.contract == null:
			return false
		var cnt: Dictionary = c.contract.counts()
		return 100.0 * float(cnt.get("felled", 0)) / maxf(float(World.native_total()), 1.0) >= float(t.substr(9))
	match t:
		"dog":
			return NightAnchors.dog_home()
		"cabin_occupied":
			return NightAnchors.cabin_occupied()
		"trees_near":
			return _standing_near(cam.global_position + (-cam.global_basis.z) * 18.0, 30.0) >= 5
		"open_ground":
			var p := cam.global_position + (-cam.global_basis.z) * 45.0
			return _standing_near(p, 25.0) <= 2 and World.height_at(p.x, p.z) > World.sea_level + 0.5
		"crest":
			return true          # validated by the actor's end_occluded check
		"wind":
			return wx != null and float(wx.get("wind_mult")) > 1.3
		"calm":
			return wx == null or float(wx.get("wind_mult")) < 1.15
		"rain":
			return wx != null and float(wx.get("rain")) > 0.3
		"pit_view":
			return _visible(cam, NightAnchors.point("pit") + Vector3(0, 0.6, 0), CampLayout.BURN_PIT_RADIUS + 0.9) == ""
		"tool_view":
			return _visible(cam, NightAnchors.point("tool_area"), 2.0) == ""
		"locker_view":
			return _visible(cam, NightAnchors.point("locker") + Vector3(0, 1.0, 0), 1.5) == ""
		"lamp_view":
			return _lamp_in_view(cam) != Vector3.INF
		"truck", "truck_view":
			if not NightAnchors.has_truck_near_camp():
				return false
			return t == "truck" or _visible(cam, NightAnchors.point("truck") + Vector3(0, 1.0, 0)) == ""
		"shore_view":
			return true          # actor points validated against water/terrain
	return false


func _standing_near(p: Vector3, r: float) -> int:
	var n := 0
	var xs: PackedFloat32Array = World.trees.x
	var zs: PackedFloat32Array = World.trees.z
	for i in xs.size():
		if absf(xs[i] - p.x) > r or absf(zs[i] - p.z) > r:
			continue
		var id := int(World.trees.id[i])
		if World.removed_trees.has(id) or not World.is_native(id):
			continue
		if Vector2(xs[i] - p.x, zs[i] - p.z).length() < r:
			n += 1
	return n


# ---------------------------------------------------------------- morning

func _queue_morning(clip: Dictionary) -> void:
	pending_notice.append(clip.id)
	var cq: Dictionary = clip.consequence
	if str(cq.get("kind", "")) in ["marks", "prop"]:
		var ap := NightAnchors.point(str(cq.get("anchor", "")))
		if ap != Vector3.INF:
			marks.append({"mark": str(cq.get("mark", "")), "pos": [ap.x, ap.y, ap.z], "day": int(clip.day) + 1})


## After the morning settlement: the bookmark notice and cosmetic marks.
func on_morning() -> void:
	var c: CampaignService = Game.campaign
	for cid in pending_notice:
		var clip := clip_by_id(str(cid))
		if clip.is_empty():
			continue
		var cq: Dictionary = clip.consequence
		if c:
			c.notice.emit("Recordings: %s flagged %s at %s last night (camper computer -> Recordings).%s" % [clip.camera, clip.bookmark, clip.clock, ("  " + str(cq.get("text", ""))) if str(cq.get("text", "")) != "" else ""], 9.0)
		if Game.desk and Game.desk.has_method("flag_recording"):
			Game.desk.flag_recording(str(cid))
	pending_notice.clear()
	refresh_marks()


func refresh_marks() -> void:
	for n in _mark_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_mark_nodes.clear()
	var c: CampaignService = Game.campaign
	var day := c.clock.day if c else 0
	var t := c.clock.t if c else 0.0
	marks = marks.filter(func(m: Dictionary) -> bool: return int(m.day) == day and t < MARK_UNTIL_T)
	var chain_moved := false
	for m in marks:
		var p: Array = m.pos
		_mark_nodes.append(_spawn_mark(str(m.mark), Vector3(p[0], p[1], p[2])))
		chain_moved = chain_moved or str(m.mark) == "gate_chain"
	# The moved chain IS the gate's chain: hide the usual one meanwhile.
	for ch in get_tree().get_nodes_in_group("camp_gate_chain"):
		(ch as Node3D).visible = not chain_moved


func _process(_dt: float) -> void:
	if not _mark_nodes.is_empty() and Game.campaign and Game.campaign.clock.t >= MARK_UNTIL_T:
		refresh_marks()


func _spawn_mark(kind: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "NightMark_" + kind
	n.add_to_group("night_marks")
	get_parent().add_child(n)
	n.global_position = Vector3(at.x, World.height_at(at.x, at.z) + 0.02, at.z)
	var dark := SurveyShip._m(Color(0.12, 0.1, 0.08, 1.0), 0.95, 0.0)
	match kind:
		"wet_prints":
			for k in 3:
				BuildKit.box(n, Vector3(0.11, 0.005, 0.26), Vector3(-0.3 + k * 0.32, 0.0, -0.4 + k * 0.45), dark, false, 0.2 * k)
		"pit_ring":
			for k in 10:
				var a := TAU * k / 10.0
				BuildKit.box(n, Vector3(0.1, 0.005, 0.24), Vector3(cos(a) * 2.4, 0.0, sin(a) * 2.4), dark, false, -a)
		"gate_chain":
			# Same chain, looped over the far side of the stile (west of it).
			var cy := CampLayout.GATE_CLEARANCE + CampLayout.GATE_LEAF.y * 0.55
			BuildKit.box(n, Vector3(0.035, 0.32, 0.18), Vector3(-0.12, cy, 0.09), "steel", false)
		"branch":
			var b := BuildKit.cylinder(n, 0.05, 1.6, Vector3.ZERO, "bark", false, 6)
			b.rotation = Vector3(PI * 0.5, 0.4, 0.0)
	return n


func clip_by_id(id: String) -> Dictionary:
	for c in clips:
		if str(c.id) == id:
			return c
	return {}


func capture_state() -> Dictionary:
	return {"version": 1, "clips": clips.duplicate(true), "total": total_captured, "nights": nights.duplicate(), "last_used": last_used.duplicate(), "marks": marks.duplicate(true), "pending": pending_notice.duplicate(), "stats": stats.duplicate(true)}


func restore_state(d: Dictionary) -> void:
	clips = (d.get("clips", []) as Array).duplicate(true)
	total_captured = int(d.get("total", clips.size()))
	nights = (d.get("nights", {}) as Dictionary).duplicate()
	last_used = (d.get("last_used", {}) as Dictionary).duplicate()
	marks = (d.get("marks", []) as Array).duplicate(true)
	pending_notice = (d.get("pending", []) as Array).duplicate()
	if d.has("stats"):
		stats = (d.stats as Dictionary).duplicate(true)
	refresh_marks()
