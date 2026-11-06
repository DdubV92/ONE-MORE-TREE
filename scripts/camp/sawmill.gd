class_name Sawmill
extends Node3D
## Phase 24: the camp sawmill (roofed bay behind the camper, lumber yard to
## its south). The ledger (MillLedger, saved inside TimberService) is the
## only authority: this node advances it with game time and turns its events
## into presentation - logs crossing to the rollers, the saw under load,
## boards riding the outfeed conveyor, the stacker strapping a pallet and
## pallets filling the yard. Offscreen the ledger advances the same way.
##
## Shift: the line runs during daylight; at dusk nobody feeds it and it
## finishes the log in the saw, then winds down. The rack, the log in the
## saw and the open pallet stay overnight and across saves.

const BOARD_POOL := 24
const BOARD_SPEED := 0.9          # m/s along the outfeed conveyor
const NIGHT_CUE_CHANCE := 0.22    # per eligible night (director budget)

var ledger: MillLedger
var _root: Node3D
var _rack_root: Node3D
var _rack_logs: Array[MeshInstance3D] = []
var _saw_log: MeshInstance3D
var _rollers: Array[MeshInstance3D] = []
var _blade: MeshInstance3D
var _belt_rollers: Array[MeshInstance3D] = []
var _boards: Array[MeshInstance3D] = []
var _board_t: Array[float] = []
var _open_stack: MeshInstance3D
var _open_pallet: Node3D
var _yard_mm: MultiMeshInstance3D
var _board_label: Label3D
var _dust: GPUParticles3D
var _lamp: OmniLight3D
var _motor_h := -1
var _blade_h := -1
var _roll_h := -1
var _spin := 0.0                  # 0..1 motor speed (spin-up / wind-down)
var _label_t := 0.0
var _shown_rack := -1
var _shown_yard := -1
var _was_running := false
var night_cue_done := {}          # day -> true (presentation only, saved via campaign stats)
var _cue_t := -1.0
var _cue_day := -1


func setup() -> void:
	name = "Sawmill"
	ledger = Game.timber.mill if Game.timber else MillLedger.new()
	_root = Node3D.new()
	_root.name = "Line"
	add_child(_root)
	_build_structure()
	_build_line()
	_build_yard()
	_build_board()
	_build_camera()
	if Game.timber:
		ledger.pay_fn = _pay
		ledger.reconcile()


func _ground(local: Vector3) -> Vector3:
	var w := CampLayout.world(local)
	return Vector3(w.x, World.height_at(w.x, w.z) + local.y, w.z)


# --------------------------------------------------------------- building

func _build_structure() -> void:
	var c: Vector3 = CampLayout.MILL_BAY.center
	var sz: Vector3 = CampLayout.MILL_BAY.size
	var base := _ground(Vector3(c.x, 0, c.z))
	var floor_y := base.y
	# A packed-gravel pad under the bay so the line sits level.
	var pad := BuildKit.box(_root, Vector3(sz.x, 0.25, sz.z + 1.0), Vector3(base.x, floor_y - 0.08, base.z), "stone", true, 0.0, "MillPad")
	pad.set_meta("acoustic", "rock")
	# Posts + a mono-pitch corrugated roof, high side to the east (camp side).
	for px in [-sz.x * 0.5 + 0.2, sz.x * 0.5 - 0.2]:
		for pz in [-sz.z * 0.5 + 0.2, 0.0, sz.z * 0.5 - 0.2]:
			var h := sz.y + (0.5 if px > 0 else 0.0)
			BuildKit.box(_root, Vector3(0.18, h, 0.18), Vector3(base.x + px, floor_y + h * 0.5, base.z + pz), "steel", true, 0.0, "Post")
	var roof := BuildKit.box(_root, Vector3(sz.x + 1.0, 0.08, sz.z + 1.2), Vector3(base.x, floor_y + sz.y + 0.3, base.z), "roof", false, 0.0, "Roof")
	roof.rotation.z = atan2(0.5, sz.x)
	# Back (west) wall of planks; the rest is open for air and sightlines.
	BuildKit.box(_root, Vector3(0.12, 2.6, sz.z), Vector3(base.x - sz.x * 0.5 + 0.1, floor_y + 1.3, base.z), "planks", true, 0.0, "BackWall")
	# A practical lamp under the roof (light only - never safety).
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(base.x + 1.0, floor_y + sz.y - 0.4, base.z)
	_lamp.light_color = Color(1.0, 0.86, 0.62)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 9.0
	_lamp.shadow_enabled = false
	_root.add_child(_lamp)
	BuildKit.box(_root, Vector3(0.3, 0.12, 0.3), _lamp.position + Vector3(0, 0.12, 0), "lamp_bulb", false, 0.0, "LampShade")
	# Marked lumber-yard bays (painted timber kerbs).
	for bx in CampLayout.MILL_YARD_BAYS_X:
		for rz in CampLayout.MILL_YARD_ROWS_Z:
			var p := _ground(Vector3(float(bx), 0, float(rz)))
			BuildKit.box(_root, Vector3(1.5, 0.06, 1.5), p + Vector3(0, 0.03, 0), "dark_wood", false, 0.0, "Bay")


func _build_line() -> void:
	# Feed rack: two steel skids across X; logs lie along Z on top.
	var rp := _ground(CampLayout.MILL_RACK_POS)
	var rs := CampLayout.MILL_RACK_SIZE
	for dz in [-0.7, 0.7]:
		BuildKit.box(_root, Vector3(rs.x, 0.12, 0.16), rp + Vector3(0, 0.55, dz), "steel", false, 0.0, "Skid")
		for dx in [-rs.x * 0.5 + 0.1, 0.0, rs.x * 0.5 - 0.1]:
			BuildKit.box(_root, Vector3(0.12, 0.55, 0.12), rp + Vector3(dx, 0.27, dz), "steel", false, 0.0, "Leg")
	_rack_root = Node3D.new()
	_rack_root.name = "RackLogs"
	_root.add_child(_rack_root)
	var rack_body := Node3D.new()
	rack_body.name = "FeedRack"
	rack_body.set_script(load("res://scripts/camp/mill_feed.gd"))
	_root.add_child(rack_body)
	BuildKit.box(rack_body, Vector3(rs.x, 0.9, rs.z), rp + Vector3(0, 0.45, 0), "steel", true, 0.0, "RackHit").visible = false
	# Infeed rollers (axis X), the saw head with its blade, outfeed belt.
	var rl := _ground(CampLayout.MILL_ROLLERS_POS)
	for k in 3:
		var r := BuildKit.cylinder(_root, 0.11, 0.9, rl + Vector3(0, 0.62, -0.5 + k * 0.5), "galvanized", false, 12)
		r.rotation.z = PI * 0.5
		_rollers.append(r)
	BuildKit.box(_root, Vector3(1.2, 0.5, 1.6), rl + Vector3(0, 0.25, 0), "camper_trim", true, 0.0, "RollerFrame")
	var sp := _ground(CampLayout.MILL_SAW_POS)
	BuildKit.box(_root, Vector3(1.5, 1.6, 1.2), sp + Vector3(0.0, 1.05, 0), "camper_paint", true, 0.0, "SawHousing")
	BuildKit.box(_root, Vector3(1.6, 0.25, 1.3), sp + Vector3(0, 1.95, 0), "camper_stripe", false, 0.0, "SawCap")
	_blade = BuildKit.cylinder(_root, 0.55, 0.03, sp + Vector3(0.3, 0.95, 0), "steel", false, 24)
	_blade.rotation.z = PI * 0.5
	BuildKit.box(_root, Vector3(1.2, 0.55, 0.9), sp + Vector3(0, 0.27, 0), "steel", false, 0.0, "SawBase")
	_saw_log = MeshInstance3D.new()
	_saw_log.name = "LogInSaw"
	_saw_log.visible = false
	_root.add_child(_saw_log)
	var a: Vector3 = _ground(CampLayout.MILL_OUTFEED[0])
	var b: Vector3 = _ground(CampLayout.MILL_OUTFEED[1])
	var mid := (a + b) * 0.5
	BuildKit.box(_root, Vector3(0.9, 0.08, b.z - a.z), mid + Vector3(0, 0.72, 0), "rubber", false, 0.0, "Belt")
	BuildKit.box(_root, Vector3(1.0, 0.6, b.z - a.z), mid + Vector3(0, 0.36, 0), "steel", true, 0.0, "BeltFrame")
	var z := a.z
	while z <= b.z:
		var br := BuildKit.cylinder(_root, 0.05, 0.95, Vector3(a.x, mid.y + 0.66, z), "galvanized", false, 8)
		br.rotation.z = PI * 0.5
		_belt_rollers.append(br)
		z += 0.6
	for i in BOARD_POOL:
		var bd := BuildKit.box(_root, Vector3(0.15, 0.05, 2.4), a, "planks", false, 0.0, "Board%d" % i)
		bd.visible = false
		_boards.append(bd)
		_board_t.append(-1.0)
	# Stacker + the open (unfinished) pallet at the bay's south edge.
	var st := _ground(CampLayout.MILL_STACKER_POS)
	for dx in [-0.8, 0.8]:
		BuildKit.box(_root, Vector3(0.12, 2.2, 0.12), st + Vector3(dx, 1.1, -0.7), "camper_stripe", false, 0.0, "StackerPost")
	BuildKit.box(_root, Vector3(1.8, 0.12, 0.12), st + Vector3(0, 2.2, -0.7), "camper_stripe", false, 0.0, "StackerBeam")
	_open_pallet = Node3D.new()
	_open_pallet.position = st
	_root.add_child(_open_pallet)
	BuildKit.box(_open_pallet, Vector3(1.2, 0.14, 1.2), Vector3(0, 0.07, 0), "dark_wood", false, 0.0, "Pallet")
	_open_stack = BuildKit.box(_open_pallet, Vector3(1.15, 1.0, 1.18), Vector3(0, 0.64, 0), "planks", false, 0.0, "OpenStack")
	_open_stack.scale.y = 0.001
	# Sawdust at the blade while cutting.
	_dust = GPUParticles3D.new()
	_dust.amount = 48
	_dust.lifetime = 1.2
	_dust.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.4, 1)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -2.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	_dust.process_material = pm
	var dq := QuadMesh.new()
	dq.size = Vector2(0.03, 0.03)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.86, 0.74, 0.52)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dq.material = dm
	_dust.draw_pass_1 = dq
	_dust.position = sp + Vector3(0.3, 0.8, 0.6)
	_root.add_child(_dust)


func _build_yard() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ps := CampLayout.MILL_PALLET_SIZE
	_add_box(st, Vector3(0, 0.07, 0), Vector3(ps.x, 0.14, ps.z), Color(0.36, 0.25, 0.16))
	_add_box(st, Vector3(0, 0.14 + (ps.y - 0.14) * 0.5, 0), Vector3(ps.x - 0.04, ps.y - 0.16, ps.z - 0.02), Color(0.86, 0.72, 0.5))
	for bz in [-0.35, 0.35]:
		_add_box(st, Vector3(0, ps.y * 0.5 + 0.04, bz), Vector3(ps.x + 0.01, ps.y - 0.06, 0.03), Color(0.2, 0.2, 0.22))
	st.generate_normals()
	mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = CampLayout.MILL_DISPLAY_CAP
	mm.visible_instance_count = 0
	for i in CampLayout.MILL_DISPLAY_CAP:
		var l := CampLayout.mill_slot(i)
		var g := _ground(Vector3(l.x, 0, l.z))
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(g.x, g.y + 0.06 + l.y, g.z)))
	_yard_mm = MultiMeshInstance3D.new()
	_yard_mm.name = "LumberYard"
	_yard_mm.multimesh = mm
	add_child(_yard_mm)


func _add_box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var v := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	# Clockwise seen from outside (Godot front faces).
	var faces := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]
	st.set_color(col)
	for f in faces:
		st.add_vertex(c + v[f[0]])
		st.add_vertex(c + v[f[1]])
		st.add_vertex(c + v[f[2]])
		st.add_vertex(c + v[f[0]])
		st.add_vertex(c + v[f[2]])
		st.add_vertex(c + v[f[3]])


func _build_board() -> void:
	var p := _ground(CampLayout.MILL_BOARD_POS)
	BuildKit.box(_root, Vector3(0.1, 2.0, 0.1), p + Vector3(0, 1.0, 0), "dark_wood", true, 0.0, "BoardPost")
	var panel := Node3D.new()
	panel.name = "YardBoard"
	panel.set_script(load("res://scripts/camp/mill_board.gd"))
	_root.add_child(panel)
	BuildKit.box(panel, Vector3(1.4, 1.0, 0.06), p + Vector3(0, 1.75, 0), "dark_wood", true, PI * 0.5, "BoardPanel")
	_board_label = Label3D.new()
	_board_label.font_size = 36
	_board_label.pixel_size = 0.0028
	_board_label.modulate = Color(0.95, 0.92, 0.84)
	_board_label.outline_size = 6
	_board_label.position = p + Vector3(0.05, 1.75, 0)
	_board_label.rotation.y = PI * 0.5
	_board_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_board_label.width = 460
	_root.add_child(_board_label)


func _build_camera() -> void:
	var res := Game.world_root.find_child("Reservations", true, false) if Game.world_root else null
	if res == null or not res.has_method("_camera"):
		return
	var c: Vector3 = CampLayout.MILL_BAY.center
	var sz: Vector3 = CampLayout.MILL_BAY.size
	var mount := _ground(Vector3(c.x + sz.x * 0.5 - 0.2, 0, c.z + sz.z * 0.5 - 0.2))
	var look := _ground(CampLayout.MILL_RACK_POS) + Vector3(-1.0, 0.4, 0)
	res.call("_camera", "CAM_12", "sawmill", mount + Vector3(-0.3, 3.6, 0), look, "post")


# ---------------------------------------------------------------- running

func _pay(pallet_id: String, cents: int, note: String) -> String:
	var cs: CampaignService = Game.campaign
	if cs == null or cs.wallet == null or not cs.wallet.enabled:
		return ""
	return cs.wallet.credit_pallet(pallet_id, cents, note)


## The line feeds new logs in daylight only (dusk: finish and wind down).
func feeding() -> bool:
	var cs: CampaignService = Game.campaign
	if cs == null or cs.clock == null or not (cs.active or cs.test_route):
		return Game.is_preview()
	if Game.hunt and Game.hunt.hunt_active():
		return false
	return cs.clock.phase() == WorkdayClock.Phase.DAYLIGHT


func _process(delta: float) -> void:
	if Game.timber and ledger != Game.timber.mill:
		ledger = Game.timber.mill          # cleared / reloaded ledger
		ledger.pay_fn = _pay
		_shown_rack = -1
		_shown_yard = -1
	if ledger == null or get_tree().paused:
		return
	var dt := delta * Game.time_scale
	var t_now: float = Game.campaign.clock.t if Game.campaign and Game.campaign.clock else 0.0
	var ev: Array = Game.timber.mill_step(dt, feeding(), t_now) if Game.timber else ledger.step(dt, feeding(), t_now)
	for e in ev:
		_present(e)
	var running := ledger.busy() or (feeding() and not ledger.rack.is_empty())
	var target := 1.0 if running else 0.0
	if _was_running and not running and _spin > 0.5:
		_sound("mill.winddown", CampLayout.MILL_SAW_POS)
	_was_running = running
	_spin = move_toward(_spin, target, delta * (0.8 if target > _spin else 0.35))
	_animate(delta)
	_audio(delta)
	_label_t -= delta
	if _label_t <= 0.0:
		_label_t = 0.5
		_refresh_static()
	_night_cue(delta)


func _present(e: Dictionary) -> void:
	match str(e.kind):
		"log_in":
			_shown_rack = -1
		"board":
			for i in BOARD_POOL:
				if _board_t[i] < 0.0:
					_board_t[i] = 0.0
					_boards[i].visible = true
					break
			if randf() < 0.5:
				_sound("mill.board", CampLayout.MILL_OUTFEED[1])
		"pallet":
			_sound("mill.band", CampLayout.MILL_STACKER_POS)
			_shown_yard = -1
			if Game.campaign and not Game.is_preview() and int(e.cents) > 0:
				Game.campaign.notice.emit("Pallet %s finished: +$%s lumber." % [str(e.id), Money.format_cents(int(e.cents))], 3.0)


func _animate(delta: float) -> void:
	var spin_rate := _spin * 30.0
	_blade.rotation.x += delta * spin_rate
	var job := ledger.job
	for r in _rollers:
		r.rotation.x += delta * (8.0 if not job.is_empty() else 0.0) * _spin
	for r in _belt_rollers:
		r.rotation.x += delta * 6.0 * _spin
	# The log in the saw moves from the rollers through the blade.
	if job.is_empty():
		_saw_log.visible = false
		_dust.emitting = false
	else:
		var k := clampf(float(job.done) / maxf(float(job.litres), 1.0), 0.0, 1.0)
		var dims := _dims(str(job.sid))
		if _saw_log.mesh == null or _saw_log.get_meta("sid", "") != str(job.sid):
			var cm := CylinderMesh.new()
			cm.top_radius = dims.x
			cm.bottom_radius = dims.x
			cm.height = dims.y
			_saw_log.mesh = cm
			_saw_log.material_override = BuildKit.mat("bark")
			_saw_log.set_meta("sid", str(job.sid))
			_saw_log.rotation = Vector3(PI * 0.5, 0, 0)
		var a := _ground(CampLayout.MILL_ROLLERS_POS)
		var z0 := a.z - dims.y * 0.5
		_saw_log.position = Vector3(a.x, a.y + 0.62 + dims.x, z0 + k * (dims.y + 1.8))
		_saw_log.visible = k < 0.98
		_dust.emitting = _spin > 0.6
	# Boards ride the conveyor to the stacker, then join the open pallet.
	var p0: Vector3 = _ground(CampLayout.MILL_OUTFEED[0])
	var p1: Vector3 = _ground(CampLayout.MILL_OUTFEED[1])
	var length := p1.z - p0.z
	for i in BOARD_POOL:
		if _board_t[i] < 0.0:
			continue
		_board_t[i] += delta * Game.time_scale * BOARD_SPEED
		if _board_t[i] >= length:
			_board_t[i] = -1.0
			_boards[i].visible = false
			continue
		_boards[i].position = Vector3(p0.x, p0.y + 0.8, p0.z + _board_t[i])
	_open_stack.scale.y = maxf(float(ledger.open_fill()) / float(ledger.pallet_l), 0.001)
	_open_stack.position.y = 0.14 + 0.5 * _open_stack.scale.y
	if _lamp:
		var dusk_on: bool = Game.environment != null and Game.environment.is_night()
		_lamp.light_energy = move_toward(_lamp.light_energy, 1.6 if (running_or_open() or dusk_on) else 0.0, delta)


func running_or_open() -> bool:
	return ledger.busy() or not ledger.rack.is_empty()


func _audio(_delta: float) -> void:
	if SoundService.instance() == null:
		return
	var on := _spin > 0.05
	if on and _motor_h < 0:
		_motor_h = SoundService.loop("mill.motor", _ground(CampLayout.MILL_SAW_POS) + Vector3(0, 1.0, 0))
		_blade_h = SoundService.loop("mill.blade", _ground(CampLayout.MILL_SAW_POS) + Vector3(0.3, 1.0, 0))
		_roll_h = SoundService.loop("mill.rollers", _ground(CampLayout.MILL_ROLLERS_POS) + Vector3(0, 0.7, 0))
	elif not on and _motor_h >= 0:
		for h in [_motor_h, _blade_h, _roll_h]:
			SoundService.loop_stop(h, 0.6)
		_motor_h = -1
		_blade_h = -1
		_roll_h = -1
	if _motor_h >= 0:
		var cutting := not ledger.job.is_empty()
		SoundService.loop_set(_motor_h, linear_to_db(maxf(_spin, 0.01)), 0.6 + 0.4 * _spin)
		SoundService.loop_set(_blade_h, linear_to_db(maxf(_spin * (1.0 if cutting else 0.35), 0.01)), (0.75 if cutting else 1.0) * (0.5 + 0.5 * _spin))
		SoundService.loop_set(_roll_h, linear_to_db(maxf(_spin * (1.0 if cutting else 0.0), 0.005)), 1.0)


func _sound(ev: String, local: Vector3) -> void:
	if SoundService.instance() != null:
		SoundService.play(ev, _ground(local) + Vector3(0, 0.8, 0))


func _dims(sid: String) -> Vector2:
	var t: TimberService = Game.timber
	var s := t.segment(sid) if t else {}
	if s.is_empty():
		return Vector2(0.2, 2.0)
	var rec: Dictionary = t.records[int(sid.trim_prefix("T").split("_S")[0])]
	return Vector2(TimberMesh.piece_radius(rec, int(s.k)), TimberMesh.piece_length(rec, int(s.k)))


## Rack logs and yard pallets are rebuilt only when their counts change.
func _refresh_static() -> void:
	if _shown_rack != ledger.rack.size():
		_shown_rack = ledger.rack.size()
		for n in _rack_logs:
			n.queue_free()
		_rack_logs.clear()
		var rp := _ground(CampLayout.MILL_RACK_POS)
		var x := -CampLayout.MILL_RACK_SIZE.x * 0.5 + 0.3
		for r in ledger.rack:
			var d := _dims(str(r.sid))
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = d.x
			cm.bottom_radius = d.x
			cm.height = minf(d.y, 3.6)
			mi.mesh = cm
			mi.material_override = BuildKit.mat("bark")
			mi.rotation = Vector3(PI * 0.5, 0, 0)
			mi.position = rp + Vector3(x + d.x, 0.61 + d.x, 0)
			_rack_root.add_child(mi)
			_rack_logs.append(mi)
			x += d.x * 2.0 + 0.05
	if _shown_yard != ledger.displayed():
		_shown_yard = ledger.displayed()
		_yard_mm.multimesh.visible_instance_count = _shown_yard
	if _board_label:
		_board_label.text = status_text()


## The yard board / interaction text: queue, job, pallet, today, earnings.
func status_text() -> String:
	var l := ledger
	var lines := PackedStringArray()
	lines.append("SAWMILL")
	lines.append("Feed rack: %d/%d logs (%d L)" % [l.rack.size(), MillLedger.RACK_CAP, l.rack_litres()])
	if not l.job.is_empty():
		lines.append("In the saw: %d%% of %d L" % [int(100.0 * float(l.job.done) / maxf(float(l.job.litres), 1.0)), int(l.job.litres)])
	else:
		lines.append("In the saw: -" + ("" if feeding() else "  (shift over)"))
	lines.append("Next pallet: %d / %d L" % [l.open_fill(), l.pallet_l])
	lines.append("Pallets today: %d%s" % [l.pallets_today, ("  (yard full, +%d overflow)" % l.overflow_today) if l.overflow_today > 0 else ""])
	lines.append("Lumber today: $%s  ($%s / pallet)" % [Money.format_cents(l.earnings_today), Money.format_cents(l.pay_cents)])
	return "\n".join(lines)


# ------------------------------------------------------- the rare night cue

## After the line has wound down, rarely (director budget, one per night,
## only if the boss can hear it): ONE set of feed rollers turns over. The
## rack is empty; the mill camera sees the rollers turn. Presentation only:
## no inventory, XP or money changes.
func _night_cue(delta: float) -> void:
	var cs: CampaignService = Game.campaign
	if cs == null or not cs.active or cs.clock.phase() != WorkdayClock.Phase.NIGHT or Game.is_preview():
		return
	var d := cs.clock.day
	if _cue_day != d:
		_cue_day = d
		var r := RandomNumberGenerator.new()
		r.seed = hash([Game.weather.seed_value if Game.weather else 0, d, "mill-cue"])
		_cue_t = r.randf_range(60.0, 400.0) if r.randf() < NIGHT_CUE_CHANCE and not night_cue_done.has(d) else -1.0
	if _cue_t < 0.0 or night_cue_done.has(d):
		return
	if cs.clock.night_exposure < _cue_t:
		return
	if ledger.busy() or not ledger.rack.is_empty() or _spin > 0.01:
		_cue_t = -1.0
		return
	var p := Game.player as Node3D
	var src := _ground(CampLayout.MILL_ROLLERS_POS)
	if p == null or p.global_position.distance_to(src) > 70.0:
		return
	var dir := Game.director
	if dir and dir.has_method("can_reserve") and str(dir.can_reserve(15)) != "":
		return
	if dir and dir.has_method("reserve"):
		dir.reserve("MILL-CUE", 15, "rollers")
	night_cue_done[d] = true
	_cue_t = -1.0
	_sound("mill.rollers.turn", CampLayout.MILL_ROLLERS_POS)
	var tw := create_tween()
	for r in _rollers:
		tw.parallel().tween_property(r, "rotation:x", r.rotation.x + TAU * 1.5, 3.0)
	tw.tween_callback(func() -> void:
		if dir and dir.has_method("release"):
			dir.release("MILL-CUE", 90.0, "rollers"))
