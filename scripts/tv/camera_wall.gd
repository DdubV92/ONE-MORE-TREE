class_name CameraWall
extends Node3D
## The camper TV and the ten live security cameras (Phase 5).
##
## Rendering is pooled and bounded: four low-resolution SubViewports for the
## 2x2 wall (each re-rendered ~12 times a second, staggered) OR one
## high-resolution SubViewport for a focused camera (~30 times a second).
## They render the shared live world (same World3D as the player) from each
## camera's real mount transform and FOV; the TV screen (layer 20) and the
## first-person arms (layer 22) are excluded from capture, and the boss's
## stand-in body (layer 21) is visible only to cameras. Nothing renders when
## the TV is off or nobody is near it.
##
## Rotation: every `interval` seconds ONE tile changes (round-robin tile
## order); the replacement comes from a fair shuffled bag excluding the
## cameras on screen and the one just removed. Pause suspends it (no burst
## on resume). A click selects the camera that tile shows at that moment.
##
## Audio: world sounds near the displayed cameras are re-played quietly from
## the TV speaker (quad), or louder and clearer for the focused camera; the
## player's own hearing stays in the camper.

signal mode_changed(mode: String)

const QUAD_SIZE := Vector2i(384, 216)
const FOCUS_SIZE := Vector2i(1280, 720)
const QUAD_HZ := 12.0
const FOCUS_HZ := 30.0
const MIC_RANGE := 38.0
const LAYER_TV := 20
const LAYER_BOSS_BODY := 21
const LAYER_VIEWMODEL := 22

var cams: Array[Node3D] = []          # sorted CAM_01..CAM_10
var mode := "quad"                   # quad / focus / entertainment / off
var tiles: Array[int] = [0, 1, 2, 3]  # camera index on each tile
var focus_index := 0
var interval := 5.0
var mic_muted := false
var tv_volume := 0.8
var _next_tile := 0
var _timer := 0.0
var _bag: Array[int] = []
var _last_removed := -1
var _quad_vps: Array[SubViewport] = []
var _quad_cams: Array[Camera3D] = []
var _focus_vp: SubViewport
var _focus_cam: Camera3D
var _render_t := []
var _focus_t := 0.0
var composite: SubViewport
var _tile_rects: Array[TextureRect] = []
var _tile_labels: Array[Label] = []
var _focus_rect: TextureRect
var _focus_label: Label
var _ent: Control
var _inset: Array[TextureRect] = []
var screen: MeshInstance3D
var speaker: AudioStreamPlayer3D
var _ambience: AudioStreamPlayer3D
var _active := false
var _rng := RandomNumberGenerator.new()
var renders_this_second := 0
var _rps_t := 0.0
var _rps_count := 0


func setup() -> void:
	_rng.seed = 5150
	for c in get_tree().get_nodes_in_group("security_camera"):
		cams.append(c)
	cams.sort_custom(func(a: Node3D, b: Node3D) -> bool: return str(a.get_meta("camera_id")) < str(b.get_meta("camera_id")))
	var tvs := get_tree().get_nodes_in_group("camper_tv")
	if tvs.is_empty() or cams.size() < 4:
		return
	var tv: Node3D = tvs[0]
	screen = tv.get_node("Screen")
	screen.layers = 1 << (LAYER_TV - 1)
	var w := get_viewport().world_3d
	for i in 4:
		var vp := _make_vp(QUAD_SIZE, w)
		_quad_vps.append(vp)
		_quad_cams.append(vp.get_child(0))
		_render_t.append(float(i) / (QUAD_HZ * 4.0))
	_focus_vp = _make_vp(FOCUS_SIZE, w)
	_focus_cam = _focus_vp.get_child(0)
	_build_composite()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = composite.get_texture()
	screen.material_override = mat
	speaker = AudioStreamPlayer3D.new()
	speaker.name = "TVSpeaker"
	speaker.bus = "TV"
	speaker.unit_size = 3.0
	speaker.max_polyphony = 6
	tv.add_child(speaker)
	_ambience = AudioStreamPlayer3D.new()
	_ambience.name = "TVAmbience"
	_ambience.bus = "TV"
	_ambience.unit_size = 3.0
	tv.add_child(_ambience)
	_refill_bag()
	tiles = [0, 1, 2, 3]
	_apply_tiles()
	set_mode("quad")


func _make_vp(size: Vector2i, w: World3D) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.world_3d = w
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if size.x < 800 else Viewport.SCREEN_SPACE_AA_FXAA
	vp.positional_shadow_atlas_size = 0
	add_child(vp)
	var cam := Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~(1 << (LAYER_TV - 1)) & ~(1 << (LAYER_VIEWMODEL - 1))
	cam.cull_mask |= 1 << (LAYER_BOSS_BODY - 1)
	cam.far = 900.0 if size.x < 800 else 1800.0
	vp.add_child(cam)
	return vp


func _build_composite() -> void:
	composite = SubViewport.new()
	composite.size = Vector2i(960, 540)
	composite.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	composite.disable_3d = true
	add_child(composite)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025)
	bg.size = Vector2(960, 540)
	composite.add_child(bg)
	for i in 4:
		var r := TextureRect.new()
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.position = Vector2(4 + (i % 2) * 478, 4 + (i / 2) * 268)
		r.size = Vector2(474, 264)
		r.texture = _quad_vps[i].get_texture()
		composite.add_child(r)
		_tile_rects.append(r)
		var l := Label.new()
		l.position = r.position + Vector2(8, 4)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		composite.add_child(l)
		_tile_labels.append(l)
	_focus_rect = TextureRect.new()
	_focus_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_focus_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_focus_rect.size = Vector2(960, 540)
	_focus_rect.texture = _focus_vp.get_texture()
	composite.add_child(_focus_rect)
	_focus_label = Label.new()
	_focus_label.position = Vector2(14, 10)
	_focus_label.add_theme_font_size_override("font_size", 20)
	_focus_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_focus_label.add_theme_constant_override("outline_size", 5)
	composite.add_child(_focus_label)
	_ent = TVProgram.new()
	_ent.size = Vector2(960, 540)
	composite.add_child(_ent)
	for i in 4:
		var r := TextureRect.new()
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.position = Vector2(724 + (i % 2) * 116, 362 + (i / 2) * 68)
		r.size = Vector2(112, 64)
		r.texture = _quad_vps[i].get_texture()
		composite.add_child(r)
		_inset.append(r)


# ------------------------------------------------------------------- modes

func set_mode(m: String) -> void:
	mode = m
	for r in _tile_rects:
		r.visible = m == "quad"
	for l in _tile_labels:
		l.visible = m == "quad"
	_focus_rect.visible = m == "focus"
	_focus_label.visible = m == "focus"
	_ent.visible = m == "entertainment"
	for r in _inset:
		r.visible = m == "entertainment"
	(_ent as TVProgram).playing = m == "entertainment"
	if m == "focus":
		_place(_focus_cam, focus_index)
		_focus_label.text = "%s  ·  %s  ·  LIVE" % [cam_id(focus_index), cam_name(focus_index)]
	_timer = 0.0
	_update_ambience()
	mode_changed.emit(m)


func focus_tile(tile: int) -> void:
	if tile < 0 or tile >= 4:
		return
	focus_index = tiles[tile]   # exactly what that tile shows right now
	set_mode("focus")


func focus_step(d: int) -> void:
	focus_index = posmod(focus_index + d, cams.size())
	set_mode("focus")


## Back to the wall: a valid distinct set containing the focused camera,
## with a fresh timer.
func back_to_quad() -> void:
	if not focus_index in tiles:
		tiles[_next_tile] = focus_index
	_dedupe_tiles()
	_apply_tiles()
	set_mode("quad")


func _dedupe_tiles() -> void:
	var seen := {}
	for i in 4:
		if seen.has(tiles[i]):
			for c in cams.size():
				if not c in tiles:
					tiles[i] = c
					break
		seen[tiles[i]] = true


func cam_id(i: int) -> String:
	return str(cams[i].get_meta("camera_id")).replace("_", "-")


func cam_name(i: int) -> String:
	const NAMES := {"cabin_to_camper": "Cabin to camper", "camper_to_cabin": "Camper to cabin", "forest_entrance": "Forest entrance", "perimeter_nw": "Fence NW", "perimeter_ne": "Fence NE", "perimeter_sw": "Fence SW", "perimeter_se": "Fence SE", "trail_1": "West trail", "trail_2": "Ridge trail", "trail_3": "River trail"}
	return NAMES.get(str(cams[i].get_meta("category")), str(cams[i].get_meta("category")))


# ---------------------------------------------------------------- rotation

func _refill_bag() -> void:
	_bag.clear()
	for i in cams.size():
		_bag.append(i)
	for i in range(_bag.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t := _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = t


## One tile changes per step (round-robin tile order, fair shuffled bag).
func rotate_once() -> void:
	var tile := _next_tile
	var old := tiles[tile]
	var pick := -1
	for attempt in 2:
		for k in _bag.size():
			var c := _bag[k]
			if not c in tiles and c != old and c != _last_removed:
				pick = c
				_bag.remove_at(k)
				break
		if pick >= 0:
			break
		_refill_bag()
	if pick < 0:
		return
	_last_removed = old
	tiles[tile] = pick
	_place(_quad_cams[tile], pick)
	_tile_labels[tile].text = "%s  %s" % [cam_id(pick), cam_name(pick)]
	_next_tile = (_next_tile + 1) % 4
	if Game.environment and Game.world_root:
		var gc: Node = Game.world_root.get("ground_cover")
		if gc and gc.has_method("force_build_around"):
			gc.call_deferred("force_build_around", cams[pick].global_position)


func _apply_tiles() -> void:
	for i in 4:
		_place(_quad_cams[i], tiles[i])
		_tile_labels[i].text = "%s  %s" % [cam_id(tiles[i]), cam_name(tiles[i])]


func _place(cam: Camera3D, index: int) -> void:
	var mount := cams[index]
	cam.global_transform = mount.global_transform.translated_local(Vector3(0, 0, -0.16))
	cam.fov = 72.0 if str(mount.get_meta("support")) == "rock" else 78.0


# ---------------------------------------------------------------- per frame

func is_active() -> bool:
	if mode == "off" or screen == null:
		return false
	var p := Game.player
	if p == null:
		return false
	return p.global_position.distance_to(screen.global_position) < 14.0


func _process(delta: float) -> void:
	if screen == null:
		return
	var active := is_active() and not get_tree().paused
	if active != _active:
		_active = active
		_update_ambience()
		if not active:
			for vp in _quad_vps:
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_focus_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not active:
		return
	# Rotation only advances while unpaused and in wall/entertainment modes.
	if (mode == "quad" or mode == "entertainment") and interval > 0.0:
		_timer += delta
		if _timer >= interval:
			_timer = 0.0      # no catch-up burst
			rotate_once()
	if mode == "focus":
		_focus_t += delta
		if _focus_t >= 1.0 / FOCUS_HZ:
			_focus_t = 0.0
			_focus_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			_rps_count += 1
	else:
		for i in 4:
			_render_t[i] = float(_render_t[i]) + delta
			if float(_render_t[i]) >= 1.0 / QUAD_HZ:
				_render_t[i] = 0.0
				_quad_vps[i].render_target_update_mode = SubViewport.UPDATE_ONCE
				_rps_count += 1
	_rps_t += delta
	if _rps_t >= 1.0:
		renders_this_second = _rps_count
		_rps_count = 0
		_rps_t = 0.0


# ------------------------------------------------------------------- audio

## World sound at `pos` (from LoggingFX and other sound sources). Picks up
## at the displayed cameras within range, de-duplicated (strongest pickup
## wins, one replay), quiet for the wall, louder and clearer when focused.
func on_world_sound(stream: AudioStream, pos: Vector3, volume_db: float) -> void:
	if not _active or mic_muted or stream == null or mode == "entertainment":
		return
	var shown: Array[int] = [focus_index] if mode == "focus" else tiles.duplicate()
	var best := 0.0
	var space := get_world_3d().direct_space_state
	for ci in shown:
		var cp := cams[ci].global_position
		var d := cp.distance_to(pos)
		if d > MIC_RANGE:
			continue
		var g := pow(1.0 - d / MIC_RANGE, 2.0)
		var q := PhysicsRayQueryParameters3D.create(cp, pos + Vector3(0, 0.3, 0), 1)
		if not space.intersect_ray(q).is_empty():
			g *= 0.45          # occluded
		best = maxf(best, g)
	if best <= 0.02:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "TV"
	p.unit_size = 3.0
	var base := -4.0 if mode == "focus" else -15.0
	p.volume_db = clampf(base + linear_to_db(best) + volume_db * 0.5 + linear_to_db(tv_volume), -40.0, 0.0)
	speaker.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	_set_transmission()


func _set_transmission() -> void:
	var bus := AudioServer.get_bus_index("TV")
	if bus < 0:
		return
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectLowPassFilter:
			(fx as AudioEffectLowPassFilter).cutoff_hz = 7800.0 if mode == "focus" else 2600.0


## A low ambient bed for what the cameras hear (wind, surf), phase-locked to
## world time so switching tiles never restarts it.
func _update_ambience() -> void:
	if _ambience == null:
		return
	if not _active or mic_muted or mode == "entertainment":
		_ambience.stop()
		return
	var s: AudioStream = load("res://assets/audio/wind_trees.ogg") if ResourceLoader.exists("res://assets/audio/wind_trees.ogg") else null
	if s == null:
		return
	_ambience.stream = s
	_ambience.volume_db = (-14.0 if mode == "focus" else -24.0) + linear_to_db(tv_volume)
	var length := s.get_length()
	_ambience.play(fposmod(Game.world_time, maxf(length, 0.1)))
	_set_transmission()


func capture() -> Dictionary:
	return {"mode": mode, "tiles": tiles.duplicate(), "focus": focus_index, "interval": interval, "mic_muted": mic_muted, "volume": tv_volume, "next_tile": _next_tile}


func restore(d: Dictionary) -> void:
	if screen == null:
		return
	var t: Array = d.get("tiles", [0, 1, 2, 3])
	for i in 4:
		tiles[i] = clampi(int(t[i]) if i < t.size() else i, 0, cams.size() - 1)
	_dedupe_tiles()
	focus_index = clampi(int(d.get("focus", 0)), 0, cams.size() - 1)
	interval = float(d.get("interval", 5.0))
	mic_muted = bool(d.get("mic_muted", false))
	tv_volume = float(d.get("volume", 0.8))
	_next_tile = int(d.get("next_tile", 0)) % 4
	_apply_tiles()
	set_mode(str(d.get("mode", "quad")))
