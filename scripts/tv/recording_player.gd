class_name RecordingPlayer
extends Node
## Phase 20: plays back a missed-night recording (NightRecorder clip) as an
## ISOLATED reconstruction - its own World3D in a SubViewport - never the
## live world presented as the past:
##   terrain     a patch of the real height field around the camera
##   trees       the native trees STANDING AT THAT TIME (all within range
##               minus the clip's `trees_absent`), as simple proxies
##   camp        copies of the real static camp meshes near the camera
##   event       the actor/props evaluated from their tracks (pure, so seek
##               rebuilds the same state); night light from the snapshot
##   sound       the clip's events replayed through the desk speaker with
##               the RECORDING origin (no evidence, no capture, no AI)
## Nothing here runs AI, pays, moves wood or touches the real dog or crew.
## The viewport only renders while visible and playing (or once on seek).

signal finished

const SIZE := Vector2i(640, 360)
const RADIUS := 70.0

var clip := {}
var t := 0.0
var duration := 1.0
var playing := false
var speaker: Node3D
var volume_db := -6.0
var vp: SubViewport
var cam: Camera3D
var _root: Node3D
var _actor: Node3D
var _props := {}            # index -> Node3D
var _crowns: MultiMeshInstance3D
var _crown_base: Array = [] # [index, Transform3D] near the camera (sway)
var _built := false


func _ready() -> void:
	name = "RecordingPlayer"
	vp = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(vp)


func texture() -> Texture2D:
	return vp.get_texture()


func load_clip(c: Dictionary) -> void:
	stop_audio()
	clip = c
	duration = maxf(float(c.get("duration", 1.0)), 0.5)
	t = 0.0
	playing = false
	_build()
	apply_pose(0.0)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func clear() -> void:
	stop_audio()
	playing = false
	if _root and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_built = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _exit_tree() -> void:
	stop_audio()


# ------------------------------------------------------------- transport

func play() -> void:
	if clip.is_empty():
		return
	if t >= duration - 0.01:
		t = 0.0
	playing = true
	_start_audio(t)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func pause() -> void:
	playing = false
	stop_audio()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Seeking rebuilds the state at `to` from the tracks (no side effects).
func seek(to: float) -> void:
	t = clampf(to, 0.0, duration)
	stop_audio()
	apply_pose(t)
	if playing:
		_start_audio(t)
	else:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func stop_audio() -> void:
	SoundService.cancel_replay()


func _start_audio(from: float) -> void:
	if speaker == null or not is_instance_valid(speaker):
		return
	var recs := []
	for a in clip.get("audio", []):
		recs.append({"t": float(a[0]), "event": str(a[1]), "file": ""})
	SoundService.replay(recs, speaker, from, duration)


func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	if t >= duration:
		t = duration
		playing = false
		apply_pose(t)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		finished.emit()
		return
	apply_pose(t)


# ------------------------------------------------------------ evaluation

static func _lerp_track(track: Array, tt: float) -> Variant:
	if track.is_empty():
		return null
	if tt <= float(track[0][0]):
		return track[0]
	for i in range(1, track.size()):
		var a: Array = track[i - 1]
		var b: Array = track[i]
		if tt <= float(b[0]):
			var u := (tt - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			var out := []
			for k in a.size():
				out.append(lerpf(float(a[k]), float(b[k]), u) if (a[k] is float or a[k] is int) else a[k])
			return out
	return track[track.size() - 1]


static func _in_ranges(ranges: Array, tt: float) -> bool:
	for r in ranges:
		if tt >= float(r[0]) and tt < float(r[1]):
			return true
	return false


## The reconstructed state at time `tt` (pure: the same input always gives
## the same output; used for rendering, seeking and tests).
func pose(tt: float) -> Dictionary:
	var out := {"t": tt}
	var a: Dictionary = clip.get("actor", {})
	if str(a.get("kind", "none")) != "none" and not (a.get("keys", []) as Array).is_empty():
		var k: Array = _lerp_track(a.keys, tt)
		out["actor"] = Vector3(float(k[1]), float(k[2]), float(k[3]))
		out["actor_visible"] = not _in_ranges(a.get("hidden", []), tt)
		out["kneel"] = _in_ranges(a.get("kneel", []), tt)
	var ps := []
	for p in clip.get("props", []):
		var v := 0.0
		if p.has("track") and not (p.track as Array).is_empty() and (p.track[0] as Array).size() == 2:
			var tv: Array = _lerp_track(p.track, tt)
			v = float(tv[1])
		ps.append(v)
	out["props"] = ps
	return out


# --------------------------------------------------------------- building

func _build() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()
	_props.clear()
	_root = Node3D.new()
	_root.name = "Reconstruction"
	vp.add_child(_root)
	var xf: Array = clip.get("xform", [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
	var origin := Vector3(xf[0], xf[1], xf[2])
	var basis := Basis(Vector3(xf[3], xf[4], xf[5]), Vector3(xf[6], xf[7], xf[8]), Vector3(xf[9], xf[10], xf[11]))
	# Night light from the snapshot (moon + a little ambient, IR-ish).
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.07)
	env.fog_density = 0.012 + 0.01 * float((clip.get("light", {}) as Dictionary).get("rain", 0.0))
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_energy = 0.25 + 0.35 * float((clip.get("light", {}) as Dictionary).get("moon", 0.3))
	moon.rotation = Vector3(-0.9, 0.6, 0.0)
	_root.add_child(moon)
	_terrain(origin)
	_trees(origin)
	_camp(origin)
	_event_nodes()
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 600.0
	_root.add_child(cam)
	cam.global_transform = Transform3D(basis, origin)
	cam.current = true
	_built = true


func _terrain(c: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 2.5
	var n := int(RADIUS * 2.0 / step)
	var x0 := c.x - RADIUS
	var z0 := c.z - RADIUS
	for i in n:
		for j in n:
			var xa := x0 + i * step
			var za := z0 + j * step
			var p := [Vector3(xa, World.height_at(xa, za), za), Vector3(xa + step, World.height_at(xa + step, za), za),
				Vector3(xa + step, World.height_at(xa + step, za + step), za + step), Vector3(xa, World.height_at(xa, za + step), za + step)]
			for v in [p[0], p[1], p[2], p[0], p[2], p[3]]:
				st.set_normal(World.normal_at((v as Vector3).x, (v as Vector3).z))
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.29, 0.25)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	_root.add_child(mi)
	# Sea surface where the patch dips below sea level.
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	sea.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.08, 0.1, 0.12)
	sm.roughness = 0.2
	sea.material_override = sm
	_root.add_child(sea)
	sea.global_position = Vector3(c.x, World.sea_level, c.z)


## Trees standing AT THE TIME: native trees in range minus those already
## gone that night (trees felled since then are shown standing).
func _trees(c: Vector3) -> void:
	var absent := {}
	for id in clip.get("trees_absent", []):
		absent[int(id)] = true
	var xs: PackedFloat32Array = World.trees.x
	var zs: PackedFloat32Array = World.trees.z
	var pick := []
	for i in xs.size():
		if absf(xs[i] - c.x) > RADIUS or absf(zs[i] - c.z) > RADIUS:
			continue
		var id := int(World.trees.id[i])
		if absent.has(id) or not World.is_native(id):
			continue
		pick.append(i)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.7
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 6
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.0
	crown.height = 1.0
	crown.radial_segments = 7
	var mt := MultiMesh.new()
	mt.transform_format = MultiMesh.TRANSFORM_3D
	mt.mesh = trunk
	mt.instance_count = pick.size()
	var mc := MultiMesh.new()
	mc.transform_format = MultiMesh.TRANSFORM_3D
	mc.mesh = crown
	mc.instance_count = pick.size()
	_crown_base.clear()
	for k in pick.size():
		var i: int = pick[k]
		var h := float(World.trees.height[i])
		var r := float(World.trees.radius[i])
		var base := Vector3(xs[i], World.height_at(xs[i], zs[i]), zs[i])
		mt.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(r, h * 0.55, r)), base + Vector3(0, h * 0.275, 0)))
		var cr := clampf(h * 0.18, 1.2, 4.0)
		var ct := Transform3D(Basis.from_scale(Vector3(cr, h * 0.65, cr)), base + Vector3(0, h * 0.62, 0))
		mc.set_instance_transform(k, ct)
		if base.distance_to(c) < 40.0:
			_crown_base.append([k, ct])
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.22, 0.17, 0.12)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.12, 0.18, 0.12)
	var ti := MultiMeshInstance3D.new()
	ti.multimesh = mt
	ti.material_override = bark
	_root.add_child(ti)
	_crowns = MultiMeshInstance3D.new()
	_crowns.multimesh = mc
	_crowns.material_override = leaf
	_root.add_child(_crowns)
	set_meta("trees_shown", pick.size())


## Copies of the real static camp meshes near the camera (geometry only).
func _camp(c: Vector3) -> void:
	var camp := Game.world_root.find_child("Camp", false, false) if Game.world_root else null
	if camp == null:
		return
	var n := 0
	var kinds := (clip.get("props", []) as Array).map(func(p: Dictionary) -> String: return str(p.kind))
	var moves_gate := kinds.has("gate_swing")
	var moves_chain := moves_gate or kinds.has("chain")
	for mi in camp.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		if m.global_position.distance_to(c) > RADIUS + 10.0 and m.get_aabb().size.length() < 30.0:
			continue
		# Never the recording camera's own housing (or any camera body): the
		# replay camera sits exactly where the real one hangs, so its box and
		# lens would fill the frame from the inside.
		if _is_camera_part(m) or (m.global_transform * m.get_aabb()).grow(0.25).has_point(c):
			continue
		# The gate leaf / chain are replayed by their own props when the
		# clip moves them (no frozen duplicate beside the moving one).
		if (moves_gate and _in_group_up(m, "camp_gate_leaf")) or (moves_chain and _in_group_up(m, "camp_gate_chain")):
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = m.mesh
		copy.material_override = m.material_override
		_root.add_child(copy)
		copy.global_transform = m.global_transform
		n += 1
		if n > 900:
			break
	set_meta("camp_meshes", n)


static func _is_camera_part(n: Node) -> bool:
	return _in_group_up(n, "security_camera")


static func _in_group_up(n: Node, group: String) -> bool:
	var p := n
	while p:
		if p.is_in_group(group):
			return true
		p = p.get_parent()
	return false


func _event_nodes() -> void:
	var a: Dictionary = clip.get("actor", {})
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.035)
	dark.roughness = 1.0
	match str(a.get("kind", "none")):
		"figure":
			_actor = Node3D.new()
			var body := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.24
			cm.height = 1.55
			body.mesh = cm
			body.position = Vector3(0, 0.78, 0)
			body.material_override = dark
			_actor.add_child(body)
			var head := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.13
			sm.height = 0.26
			head.mesh = sm
			head.position = Vector3(0, 1.68, 0)
			head.material_override = dark
			_actor.add_child(head)
			_root.add_child(_actor)
		"dog":
			_actor = Node3D.new()
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.35, 0.25, 0.16)
			BuildKit.box(_actor, Vector3(0.28, 0.3, 0.75), Vector3(0, 0.45, 0), mat, false)
			BuildKit.box(_actor, Vector3(0.2, 0.2, 0.25), Vector3(0, 0.62, -0.45), mat, false)
			_root.add_child(_actor)
	var props: Array = clip.get("props", [])
	for i in props.size():
		var p: Dictionary = props[i]
		var at := Vector3.ZERO
		if p.has("pos"):
			at = Vector3(p.pos[0], p.pos[1], p.pos[2])
		var node := Node3D.new()
		_root.add_child(node)
		node.global_position = at
		match str(p.kind):
			"gate_swing" when p.has("yaw0"):
				# The real leaf: hinge at the node, running along local -X.
				node.rotation.y = float(p.yaw0)
				# Copies of the real leaf's meshes (frame, chain-link, chain).
				var real := get_tree().get_first_node_in_group("camp_gate_leaf") as Node3D
				if real:
					var inv := real.global_transform.affine_inverse()
					for m2 in real.find_children("*", "MeshInstance3D", true, false):
						var src := m2 as MeshInstance3D
						var cp := MeshInstance3D.new()
						cp.mesh = src.mesh
						cp.material_override = src.material_override
						node.add_child(cp)
						cp.transform = inv * src.global_transform
				else:
					var ln := CampLayout.GATE_LEAF.x
					var ht := CampLayout.GATE_LEAF.y
					BuildKit.box(node, Vector3(ln, ht, 0.05), Vector3(-ln * 0.5, CampLayout.GATE_CLEARANCE + ht * 0.5, 0), "galvanized", false)
			"chain" when p.has("yaw0"):
				BuildKit.box(node, Vector3(0.035, 0.32, 0.18), Vector3(0.05, CampLayout.GATE_CLEARANCE + CampLayout.GATE_LEAF.y * 0.55, -0.09), "steel", false)
			"gate_swing", "rack_cover", "truck_door":
				var panel := BuildKit.box(node, Vector3(1.4 if p.kind == "gate_swing" else 1.0, 1.4 if p.kind != "rack_cover" else 0.05, 0.06), Vector3(0.7, 0.75, 0), "steel" if p.kind != "rack_cover" else "dark_wood", false)
				panel.name = "Panel"
			"chain":
				BuildKit.box(node, Vector3(0.05, 0.35, 0.05), Vector3(0, 0.9, 0), "steel", false)
			"fence_shiver":
				BuildKit.box(node, Vector3(3.0, 1.2, 0.03), Vector3(0, 0.9, 0), "steel", false)
			"reflection":
				var q := MeshInstance3D.new()
				var qm := QuadMesh.new()
				qm.size = Vector2(0.4, 1.2)
				q.mesh = qm
				var rm := StandardMaterial3D.new()
				rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				rm.albedo_color = Color(0.85, 0.88, 0.9, 0.35)
				q.material_override = rm
				node.add_child(q)
			"pit_glow", "lamp_occlude", "light_bob":
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.55, 0.2) if p.kind == "pit_glow" else Color(1.0, 0.9, 0.7)
				l.omni_range = 9.0 if p.kind != "light_bob" else 4.0
				l.position = Vector3(0, 0.6 if p.kind == "pit_glow" else 0.0, 0)
				node.add_child(l)
				if p.kind == "light_bob":
					var bulb := MeshInstance3D.new()
					var bs := SphereMesh.new()
					bs.radius = 0.06
					bs.height = 0.12
					bulb.mesh = bs
					var em := StandardMaterial3D.new()
					em.emission_enabled = true
					em.emission = Color(1, 0.9, 0.7)
					em.emission_energy_multiplier = 4.0
					bulb.material_override = em
					node.add_child(bulb)
			"shadow", "shadow_walk":
				var sh := MeshInstance3D.new()
				var pm := PlaneMesh.new()
				pm.size = Vector2(0.6, 1.0)
				sh.mesh = pm
				sh.material_override = dark
				sh.position = Vector3(0, 0.03, 0)
				sh.name = "Shadow"
				node.add_child(sh)
			"prints":
				for k in (p.get("points", []) as Array).size():
					var pt: Array = p.points[k]
					var pr := BuildKit.box(_root, Vector3(0.11, 0.01, 0.26), Vector3(pt[1], float(pt[2]) + 0.02, pt[3]), dark, false)
					pr.name = "Print_%d_%d" % [i, k]
					pr.visible = false
			"branch_land":
				var b := BuildKit.cylinder(node, 0.05, 1.6, Vector3(0, 0.05, 0), "bark", false, 6)
				b.rotation = Vector3(PI * 0.5, 0.4, 0)
				b.name = "Branch"
		_props[i] = node


## Places everything for time `tt` (rendering side of pose()).
func apply_pose(tt: float) -> void:
	if not _built:
		return
	var ps := pose(tt)
	if _actor and ps.has("actor"):
		_actor.global_position = ps.actor
		_actor.visible = bool(ps.actor_visible)
		_actor.scale = Vector3(1, 0.6 if bool(ps.kneel) else 1.0, 1)
		var nxt: Dictionary = pose(minf(tt + 0.2, duration))
		var d: Vector3 = (nxt.get("actor", ps.actor) as Vector3) - (ps.actor as Vector3)
		d.y = 0
		if d.length() > 0.01:
			_actor.rotation.y = atan2(-d.x, -d.z)
	var props: Array = clip.get("props", [])
	for i in props.size():
		var p: Dictionary = props[i]
		var node: Node3D = _props.get(i)
		var v := float(ps.props[i])
		if node == null:
			continue
		match str(p.kind):
			"gate_swing", "truck_door":
				node.rotation.y = float(p.get("yaw0", 0.0)) + v
			"rack_cover":
				node.rotation.x = -v
			"chain":
				var base := Vector3(p.pos[0], p.pos[1], p.pos[2]) if p.has("pos") else Vector3.ZERO
				node.global_position = base + Vector3(-0.17 * v if p.has("yaw0") else 0.6 * v, 0, 0.18 * v if p.has("yaw0") else 0.0)
			"fence_shiver":
				node.rotation.z = sin(tt * 40.0) * 0.01 * v
			"reflection":
				var base := Vector3(p.pos[0], p.pos[1], p.pos[2])
				node.global_position = base + cam.global_basis.x * v + Vector3(0, 1.2, 0)
				node.look_at(cam.global_position, Vector3.UP)
			"pit_glow":
				(node.get_child(0) as OmniLight3D).light_energy = 0.8 + 0.3 * sin(tt * 9.0)
			"lamp_occlude":
				(node.get_child(0) as OmniLight3D).light_energy = 1.4 * v
			"shadow":
				var sh := node.get_node("Shadow") as Node3D
				sh.scale = Vector3(1, 1, maxf(v, 0.1))
			"light_bob", "shadow_walk":
				var pts: Array = p.get("points", [])
				if not pts.is_empty():
					var k: Array = _lerp_track(pts, tt)
					node.global_position = Vector3(k[1], float(k[2]) + (1.6 + 0.1 * sin(tt * 3.0) if p.kind == "light_bob" else 0.0), k[3])
			"prints":
				for k2 in (p.get("points", []) as Array).size():
					var pr := _root.get_node_or_null("Print_%d_%d" % [i, k2]) as Node3D
					if pr:
						pr.visible = tt >= float(p.points[k2][0])
			"branch_land":
				node.visible = tt >= float(p.get("t", 0.0))
			"branches":
				_sway(v * (1.0 if not bool(p.get("against_wind", false)) else -1.0), tt)


func _sway(amount: float, tt: float) -> void:
	if _crowns == null:
		return
	for e in _crown_base:
		var xf: Transform3D = e[1]
		var off := Vector3(sin(tt * 2.3 + float(e[0])) * 0.35 * amount, 0, cos(tt * 1.7 + float(e[0])) * 0.25 * amount)
		_crowns.multimesh.set_instance_transform(int(e[0]), Transform3D(xf.basis.rotated(Vector3(0, 0, 1), off.x * 0.05), xf.origin + off))
