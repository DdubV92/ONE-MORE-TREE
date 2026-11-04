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

const QUAD_SIZE := Vector2i(384, 216)     # medium/high defaults (see PROFILES)
const FOCUS_SIZE := Vector2i(1280, 720)
const QUAD_HZ := 12.0
const FOCUS_HZ := 30.0
## Phase 8: per-quality remote-view budgets. Quad tiles are genuinely
## smaller and refresh less often; focus renders the composite's full
## resolution (1:1, never an upscaled tile). The composite renders at the
## focus resolution while its 2D layout stays in 960x540 units.
const PROFILES := {
	"low": {"quad": Vector2i(320, 180), "quad_hz": 10.0, "focus": Vector2i(960, 540), "focus_hz": 24.0},
	"medium": {"quad": Vector2i(384, 216), "quad_hz": 12.0, "focus": Vector2i(1280, 720), "focus_hz": 30.0},
	"high": {"quad": Vector2i(384, 216), "quad_hz": 12.0, "focus": Vector2i(1280, 720), "focus_hz": 30.0},
	"ultra": {"quad": Vector2i(448, 252), "quad_hz": 15.0, "focus": Vector2i(1600, 900), "focus_hz": 30.0},
}
const LAYOUT := Vector2i(960, 540)
## Display gain of the screen: feeds are scene-linear (no tone mapping in
## the remote render) and are tone-mapped ONCE by the room's camera, as a
## dimmer emissive display rather than a window onto full daylight.
const SCREEN_GAIN := 0.42
const MIC_RANGE := 38.0
const LAYER_TV := 18          # TV screen: never captured by security cameras
const LAYER_BOSS_BODY := 19   # boss stand-in body: cameras only (not the 1st-person view)
const LAYER_VIEWMODEL := 20   # first-person arms/axe: never captured
const MAX_REPLAYS := 6

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
var powered := true
var _music: AudioStreamPlayer3D
var _music_stream: AudioStreamWAV
var profile_name := ""
var quad_size := QUAD_SIZE
var focus_size := FOCUS_SIZE
var quad_hz := QUAD_HZ
var focus_hz := FOCUS_HZ
var _screen_mat: ShaderMaterial
## Phase 11: true when the wall is hosted by the desk computer (its desktop
## draws the composite; the relay speaker is the desk speakers).
var hosted := false
## Desk: the cameras only render while someone is at the computer area.
const HOSTED_RANGE := 6.0
var _gain := 0.0          # smoothed relay gain (quad ~0.25 -> focus 1.0)
var _recent := {}         # dedupe: stream id -> last replay time
var _caption_t := -10.0
var relayed := 0          # counters for tests / perf report
var dropped_range := 0
var dropped_dupe := 0
var dropped_natural := 0
const NATURAL_RANGE := 30.0
var last_relay := {}


func setup() -> void:
	_rng.seed = 5150
	var root := get_parent()
	for c in get_tree().get_nodes_in_group("security_camera"):
		if root == null or root.is_ancestor_of(c):   # only this world's cameras
			cams.append(c)
	cams.sort_custom(func(a: Node3D, b: Node3D) -> bool: return str(a.get_meta("camera_id")) < str(b.get_meta("camera_id")))
	# Phase 11: the live cameras live on the desk computer's monitor (the TV
	# is entertainment only). Older layouts without a desk keep the TV.
	var mons := get_tree().get_nodes_in_group("camper_monitor").filter(func(n: Node) -> bool: return root == null or root.is_ancestor_of(n))
	var tvs := get_tree().get_nodes_in_group("camper_tv").filter(func(n: Node) -> bool: return root == null or root.is_ancestor_of(n))
	hosted = not mons.is_empty()
	if (mons.is_empty() and tvs.is_empty()) or cams.size() < 4:
		return
	var tv: Node3D = mons[0] if hosted else tvs[0]
	screen = tv.get_node("Screen")
	screen.layers = 1 << (LAYER_TV - 1)
	var w := get_viewport().world_3d
	_pick_profile()
	for i in 4:
		var vp := _make_vp(quad_size, w)
		_quad_vps.append(vp)
		_quad_cams.append(vp.get_child(0))
		_render_t.append(float(i) / (quad_hz * 4.0))
	_focus_vp = _make_vp(focus_size, w)
	_focus_cam = _focus_vp.get_child(0)
	_sync_env()
	_build_composite()
	if not hosted:
		_screen_mat = ShaderMaterial.new()
		_screen_mat.shader = load("res://shaders/tv_screen.gdshader")
		_screen_mat.set_shader_parameter("feed", composite.get_texture())
		_screen_mat.set_shader_parameter("gain", SCREEN_GAIN)
		_screen_mat.set_shader_parameter("powered", 1.0)
		screen.material_override = _screen_mat
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
	_music = AudioStreamPlayer3D.new()
	_music.name = "TVMusic"
	_music.bus = "TV"
	_music.unit_size = 3.0
	tv.add_child(_music)
	_refill_bag()
	tiles = [0, 1, 2, 3]
	interval = float(Settings.get_v("tv_interval"))
	_apply_tiles()
	set_mode("quad")
	SoundEvents.listen(on_world_sound)
	Settings.changed.connect(func() -> void:
		var want := float(Settings.get_v("tv_interval"))
		if not is_equal_approx(want, interval):
			set_interval(want)
		if str(Settings.get_v("quality")) != profile_name:
			_apply_profile())


func _pick_profile() -> void:
	profile_name = str(Settings.get_v("quality"))
	var pr: Dictionary = PROFILES.get(profile_name, PROFILES["high"])
	quad_size = pr.quad
	focus_size = pr.focus
	quad_hz = float(pr.quad_hz)
	focus_hz = float(pr.focus_hz)


## Quality change: resize the SAME pooled viewports (no new allocations
## per click; only a settings change reallocates their textures).
func _apply_profile() -> void:
	_pick_profile()
	for vp in _quad_vps:
		vp.size = quad_size
	if _focus_vp:
		_focus_vp.size = focus_size
	if composite:
		composite.size = focus_size


## Actual runtime configuration (published in the HUD/perf report/docs).
func pipeline_info() -> Dictionary:
	return {"profile": profile_name, "quad_px": [quad_size.x, quad_size.y], "quad_hz": quad_hz,
		"focus_px": [focus_size.x, focus_size.y], "focus_hz": focus_hz,
		"composite_px": [composite.size.x, composite.size.y] if composite else [0, 0],
		"max_live_feeds": 1 if mode == "focus" else 4, "tone_map": "single (room camera), feeds linear, no remote bloom/grade",
		"renders_last_second": renders_this_second}


func _exit_tree() -> void:
	SoundEvents.unlisten(on_world_sound)


## Viewmodel arms never appear on the security feeds; a simple stand-in body
## for the boss is visible ONLY to the security cameras.
func _tag_player_layers(p: Node3D) -> void:
	var vm := p.find_child("ViewModel", true, false)
	if vm:
		_set_layers(vm, 1 << (LAYER_VIEWMODEL - 1))
	var cam := p.get_viewport().get_camera_3d()
	if cam:
		cam.cull_mask &= ~(1 << (LAYER_BOSS_BODY - 1))
	if p.find_child("CameraBody", false, false) == null:
		var body := BossBody.build()
		body.name = "CameraBody"
		p.add_child(body)
		_set_layers(body, 1 << (LAYER_BOSS_BODY - 1))


static func _set_layers(n: Node, mask: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = mask
	for c in n.get_children():
		_set_layers(c, mask)


func _make_vp(size: Vector2i, w: World3D) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.world_3d = w
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.use_hdr_2d = true      # keep scene-linear values for the single tone map
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if size.x < 800 else Viewport.SCREEN_SPACE_AA_FXAA
	vp.positional_shadow_atlas_size = 0
	add_child(vp)
	var cam := Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~(1 << (LAYER_TV - 1)) & ~(1 << (LAYER_VIEWMODEL - 1))
	cam.far = 900.0 if size.x < 800 else 1800.0
	vp.add_child(cam)
	return vp


## Security cameras use a lighter copy of the live environment (same sky,
## sun, fog colour/density, exposure, time of day) without the per-viewport
## heavy effects (SDFGI, SSIL, SSR, volumetric fog; SSAO only in focus).
## Synced from the world environment twice a second, never per frame.
var _env_quad: Environment
var _env_focus: Environment
var _env_t := 0.0
const _ENV_SKIP := ["sdfgi_enabled", "ssil_enabled", "ssr_enabled", "ssao_enabled", "volumetric_fog_enabled", "resource_local_to_scene", "resource_path", "resource_name", "script"]


func _sync_env() -> void:
	var src := get_viewport().world_3d.environment if get_viewport() and get_viewport().world_3d else null
	if src == null:
		return
	if _env_quad == null:
		_env_quad = src.duplicate() as Environment
		_env_focus = src.duplicate() as Environment
		for c in _quad_cams:
			c.environment = _env_quad
		_focus_cam.environment = _env_focus
	for prop in src.get_property_list():
		var n: String = prop.name
		if (int(prop.usage) & PROPERTY_USAGE_STORAGE) == 0 or n in _ENV_SKIP:
			continue
		var v: Variant = src.get(n)
		_env_quad.set(n, v)
		_env_focus.set(n, v)
	for e in [_env_quad, _env_focus]:
		e.sdfgi_enabled = false
		e.ssil_enabled = false
		e.ssr_enabled = false
		e.volumetric_fog_enabled = false
		# Volumetric fog carried the night murk: keep it as depth fog.
		if src.volumetric_fog_enabled:
			e.fog_enabled = true
			e.fog_light_color = src.volumetric_fog_albedo * src.ambient_light_energy
			e.fog_density = maxf(src.fog_density, src.volumetric_fog_density * 0.6)
	_env_quad.ssao_enabled = false
	_env_focus.ssao_enabled = src.ssao_enabled
	# One tone map only: remote renders stay scene-linear (HDR viewports);
	# the room camera tone-maps, blooms and grades the screen once. Remote
	# exposure is the outdoor preset's (never the camper interior boost).
	var ec: EnvironmentController = Game.environment
	for e in [_env_quad, _env_focus]:
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		e.tonemap_exposure = ec.current.exposure if ec else 1.0
		e.glow_enabled = false
		e.adjustment_enabled = false


func _build_composite() -> void:
	composite = SubViewport.new()
	composite.size = focus_size
	composite.size_2d_override = LAYOUT
	composite.size_2d_override_stretch = true
	composite.use_hdr_2d = true
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
	if screen == null:
		return
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
	_update_music()
	_update_anchors()
	mode_changed.emit(m)


func set_power(on: bool) -> void:
	powered = on
	if _screen_mat:
		_screen_mat.set_shader_parameter("powered", 1.0 if on else 0.0)
	_active = false   # re-evaluated next frame
	_update_ambience()
	_update_music()
	_update_anchors()


func cycle_mode() -> void:
	match mode:
		"quad": set_mode("entertainment")
		"entertainment": set_mode("quad")
		_: back_to_quad()


func set_interval(sec: float) -> void:
	interval = maxf(sec, 0.0)
	_timer = 0.0


func focus_tile(tile: int) -> void:
	if tile < 0 or tile >= 4:
		return
	focus_index = tiles[tile]   # exactly what that tile shows right now
	set_mode("focus")


## Which wall tile (0..3) a ray from the couch hits on the physical screen,
## or -1. Uses the tile currently displayed at the moment of the click.
func tile_under_ray(from: Vector3, dir: Vector3) -> int:
	if screen == null:
		return -1
	var xf := screen.global_transform
	var n := xf.basis.z.normalized()
	var denom := n.dot(dir)
	if absf(denom) < 1e-4:
		return -1
	var t := n.dot(xf.origin - from) / denom
	if t <= 0.0:
		return -1
	var local := xf.affine_inverse() * (from + dir * t)
	var half := (screen.mesh as QuadMesh).size * 0.5
	if absf(local.x) > half.x or absf(local.y) > half.y:
		return -1
	return (0 if local.x < 0.0 else 1) + (0 if local.y > 0.0 else 2)


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


## Camera indices currently on screen (one in focus, four on the wall).
func shown_cameras() -> Array[int]:
	var out: Array[int] = []
	if mode == "focus":
		out.append(focus_index)
	else:
		out.append_array(tiles)
	return out


func cam_id(i: int) -> String:
	return str(cams[i].get_meta("camera_id")).replace("_", "-")


func cam_name(i: int) -> String:
	const NAMES := {"CAM_01": "Cabin to camper", "CAM_02": "Camper to cabin", "CAM_03": "Forest entrance", "CAM_04": "Fence NW", "CAM_05": "Fence NE", "CAM_06": "Fence SW", "CAM_07": "Fence SE", "CAM_08": "West trail", "CAM_09": "East ridge trail", "CAM_10": "Deep woods"}
	var id := str(cams[i].get_meta("camera_id"))
	return NAMES.get(id, id)


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
	_update_anchors()


## Keeps vegetation built around what the displayed cameras look at.
func _update_anchors() -> void:
	if Game.world_root == null:
		return
	var gc: Node = Game.world_root.get("ground_cover")
	if gc == null or not gc.has_method("set_anchors"):
		return
	var pts: Array[Vector3] = []
	if _active:
		var shown := shown_cameras()
		for ci in shown:
			pts.append(cams[ci].global_transform * Vector3(0, 0, -30.0))
	gc.call("set_anchors", pts)
	_update_remote_weather()


## Remote feeds see the same weather: each camera the TV is actually
## rendering gets a small rain volume at its own mount (not the player's).
func _update_remote_weather() -> void:
	var w: Node = Game.weather
	if w == null or not w.has_method("set_remote_views"):
		return
	var nodes: Array = []
	if _active:
		for ci in shown_cameras():
			nodes.append(cams[ci])
	w.call("set_remote_views", nodes)


func _apply_tiles() -> void:
	for i in 4:
		_place(_quad_cams[i], tiles[i])
		_tile_labels[i].text = "%s  %s" % [cam_id(tiles[i]), cam_name(tiles[i])]


func _place(cam: Camera3D, index: int) -> void:
	var mount := cams[index]
	cam.global_transform = mount.global_transform.translated_local(Vector3(0, 0, -0.16))
	cam.fov = 72.0 if str(mount.get_meta("support")) == "rock" else 78.0


# ---------------------------------------------------------------- per frame

## Dev/capture override: render without a player in the camper.
var force_active := false


func is_active() -> bool:
	if not powered or screen == null:
		return false
	if force_active:
		return true
	var p := Game.player
	if p == null:
		return false
	return p.global_position.distance_to(screen.global_position) < (HOSTED_RANGE if hosted else 14.0)


var _tagged: Node = null


func _process(delta: float) -> void:
	if screen == null:
		return
	if Game.player and Game.player != _tagged:
		_tagged = Game.player
		_tag_player_layers(Game.player)
	var active := is_active() and not get_tree().paused
	if active != _active:
		_active = active
		_update_ambience()
		_update_music()
		_update_anchors()
		composite.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		if not active:
			for vp in _quad_vps:
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_focus_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			renders_this_second = 0
	if not active:
		return
	_gain = move_toward(_gain, 1.0 if mode == "focus" else 0.25, delta * 1.5)
	_env_t -= delta
	if _env_t <= 0.0:
		_env_t = 0.5
		_sync_env()
	if _ambience.playing:
		_ambience.volume_db = lerpf(-26.0, -12.0, (_gain - 0.25) / 0.75) + linear_to_db(tv_volume)
	# Rotation only advances while unpaused and in wall/entertainment modes.
	if (mode == "quad" or mode == "entertainment") and interval > 0.0:
		_timer += delta
		if _timer >= interval:
			_timer = 0.0      # no catch-up burst
			rotate_once()
	if mode == "focus":
		_focus_t += delta
		if _focus_t >= 1.0 / focus_hz:
			_focus_t = 0.0
			_focus_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			_rps_count += 1
	else:
		if _freeze_t > 0.0:
			_freeze_t -= delta
			if _freeze_t <= 0.0:
				_frozen_tile = -1
		for i in 4:
			if i == _frozen_tile:
				continue
			_render_t[i] = float(_render_t[i]) + delta
			if float(_render_t[i]) >= 1.0 / quad_hz:
				_render_t[i] = 0.0
				_quad_vps[i].render_target_update_mode = SubViewport.UPDATE_ONCE
				_rps_count += 1
	_rps_t += delta
	if _rps_t >= 1.0:
		renders_this_second = _rps_count
		_rps_count = 0
		_rps_t = 0.0


# ------------------------------------------------------------------- audio

## A world sound (SoundEvents registry). Each displayed camera's microphone
## samples it by distance and occlusion; ONE replay (the strongest pickup,
## not four copies) plays from the TV speaker, quiet for the wall, louder
## and clearer for the focused camera. TV output is never an event, so
## there is no feedback loop. The player's own listener stays in the room.
func on_world_sound(stream: AudioStream, pos: Vector3, volume_db: float, category := "world", label := "") -> void:
	if not _active or mic_muted or stream == null or mode == "entertainment" or speaker == null:
		return
	var shown := shown_cameras()
	var best := 0.0
	var best_tile := -1
	var space := get_world_3d().direct_space_state
	for ti in shown.size():
		var cp := cams[shown[ti]].global_position
		var d := cp.distance_to(pos)
		if d > MIC_RANGE:
			continue
		var g := pow(1.0 - d / MIC_RANGE, 2.0)
		var q := PhysicsRayQueryParameters3D.create(cp, pos + Vector3(0, 0.4, 0), 1)
		if not space.intersect_ray(q).is_empty():
			g *= 0.4          # occluded by a building / rock / terrain
		if g > best:
			best = g
			best_tile = ti
	if best <= 0.02:
		dropped_range += 1
		return
	# Already naturally audible where you are (e.g. a lamp-post camera right
	# outside the camper): the relay steps back instead of doubling it.
	var natural := 0.0
	var lis := get_viewport().get_camera_3d() if get_viewport() else null
	if lis:
		natural = clampf(1.0 - lis.global_position.distance_to(pos) / NATURAL_RANGE, 0.0, 1.0)
	if natural > 0.75:
		dropped_natural += 1
		return
	best *= 1.0 - natural
	# The same physical sound is one replay; repeated identical samples
	# within 120 ms (e.g. heard by neighbouring cameras) are dropped.
	var now := Time.get_ticks_msec()
	var key := stream.get_instance_id()
	if now - int(_recent.get(key, -100000)) < 120:
		dropped_dupe += 1
		return
	_recent[key] = now
	# Density limit: the oldest replay gives way to the newest cue.
	while speaker.get_child_count() >= MAX_REPLAYS:
		var oldest := speaker.get_child(0)
		speaker.remove_child(oldest)
		oldest.queue_free()
		dropped_dupe += 1
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "TV"
	p.unit_size = 3.0
	var g_db := lerpf(-15.0, -3.0, (_gain - 0.25) / 0.75)
	p.volume_db = clampf(g_db + linear_to_db(best) + clampf(volume_db, -30.0, 6.0) * 0.5 + linear_to_db(maxf(tv_volume, 0.001)), -40.0, 0.0)
	# Subtle tile-relative stereo: left tiles a little left on the screen.
	if mode == "quad" and best_tile >= 0:
		p.position = Vector3(-0.35 if best_tile % 2 == 0 else 0.35, 0.0, 0.0)
	speaker.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	relayed += 1
	# Reproduced sound is a real sound in the camper: the dog may hear it.
	if Game.dog and Game.dog.global_position.distance_to(speaker.global_position) < 8.0:
		Game.dog.hear(stream, speaker.global_position, p.volume_db, "tv", label)
	var cam_i: int = shown[maxi(best_tile, 0)]
	last_relay = {"camera": cam_id(cam_i), "gain": best, "volume_db": p.volume_db, "mode": mode, "category": category}
	_set_transmission()
	if label != "" and Game.world_time - _caption_t > 4.0 and Game.player and Game.player.global_position.distance_to(screen.global_position) < 6.0:
		_caption_t = Game.world_time
		Game.player.show_message("[TV · %s, remote] %s" % [cam_id(cam_i), label])


func _set_transmission() -> void:
	var bus := AudioServer.get_bus_index("TV")
	if bus < 0:
		return
	var fx := AudioServer.get_bus_effect(bus, 0)
	if fx is AudioEffectLowPassFilter:
		(fx as AudioEffectLowPassFilter).cutoff_hz = lerpf(2600.0, 8000.0, (_gain - 0.25) / 0.75)


## What the displayed cameras hear continuously (surf near the coast, the
## river, wind in the trees) - phase-locked to world time so a tile change
## never restarts the recording.
func _update_ambience() -> void:
	if _ambience == null:
		return
	if not _active or mic_muted or mode == "entertainment":
		_ambience.stop()
		return
	var c := cams[focus_index if mode == "focus" else tiles[0]].global_position
	var n := "wind_leaves"
	if World.height_at(c.x, c.z) < World.sea_level + 6.0:
		n = "ocean_surf"
	var s: AudioStreamWAV = _loop("res://audio/generated/%s.wav" % n)
	if s == null:
		return
	if _ambience.stream == s and _ambience.playing:
		return
	_ambience.stream = s
	_ambience.volume_db = -26.0 + linear_to_db(maxf(tv_volume, 0.001))
	_ambience.play(fposmod(Game.world_time, maxf(s.get_length(), 0.1)))
	_set_transmission()


func _update_music() -> void:
	if _music == null:
		return
	if not (_active and mode == "entertainment"):
		_music.stop()
		return
	if _music_stream == null:
		_music_stream = TVProgram.make_music()
	_music.stream = _music_stream
	_music.volume_db = -10.0 + linear_to_db(maxf(tv_volume, 0.001))
	if not _music.playing:
		_music.play(fposmod(Game.world_time, _music_stream.get_length()))


var _loops := {}


func _loop(path: String) -> AudioStreamWAV:
	if _loops.has(path):
		return _loops[path]
	if not ResourceLoader.exists(path):
		return null
	var src: AudioStreamWAV = load(path)
	var w: AudioStreamWAV = src.duplicate()
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(w.get_length() * w.mix_rate)
	_loops[path] = w
	return w


func set_volume(v: float) -> void:
	tv_volume = clampf(v, 0.0, 1.0)
	_ambience.stop()
	_update_ambience()
	if _music.playing:
		_music.volume_db = -10.0 + linear_to_db(maxf(tv_volume, 0.001))


func set_mic_muted(m: bool) -> void:
	mic_muted = m
	_update_ambience()


# ----------------------------------------------------------- anomalies

## "The Live Feed That Lies" (rare, camera-only illusion layer). The world
## video underneath stays live and input keeps working; these are flagged
## intentional anomalies (anomaly_log), separate from real render faults.
## Kinds: freeze (one tile holds its frame), static (noise burst), label
## (wrong camera text flickers), phantom (a figure drawn on the feed only).
var anomaly_log: Array[Dictionary] = []
var _frozen_tile := -1
var _freeze_t := 0.0
var _overlay: Control


func anomaly(kind: String, sec := 1.5) -> void:
	if screen == null or not _active or mode == "entertainment":
		return
	var tile := randi() % 4 if mode == "quad" else 0
	anomaly_log.append({"kind": kind, "tile": tile, "t": Game.world_time})
	if anomaly_log.size() > 50:
		anomaly_log.pop_front()
	match kind:
		"freeze":
			_frozen_tile = tile
			_freeze_t = sec
		"static", "phantom", "label":
			if _overlay == null:
				_overlay = Control.new()
				_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				composite.add_child(_overlay)
			var r := ColorRect.new()
			var rect := Rect2(Vector2.ZERO, Vector2(960, 540)) if mode == "focus" else Rect2(_tile_rects[tile].position, _tile_rects[tile].size)
			r.position = rect.position
			r.size = rect.size
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if kind == "static":
				r.color = Color(0.8, 0.8, 0.8, 0.35)
			elif kind == "label":
				r.color = Color(0, 0, 0, 0)
				var l := Label.new()
				l.text = "CAM-%02d" % (1 + randi() % 10)
				l.position = Vector2(8, 4)
				l.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
				r.add_child(l)
			else:
				r.color = Color(0, 0, 0, 0)
				var fig := ColorRect.new()
				fig.color = Color(0.03, 0.03, 0.03, 0.75)
				fig.size = Vector2(rect.size.x * 0.04, rect.size.y * 0.45)
				fig.position = Vector2(rect.size.x * randf_range(0.3, 0.7), rect.size.y * 0.35)
				r.add_child(fig)
			_overlay.add_child(r)
			get_tree().create_timer(sec, false).timeout.connect(r.queue_free)
			if kind == "static" and speaker:
				var p := AudioStreamPlayer3D.new()
				p.stream = load("res://audio/generated/t_static.wav")
				p.bus = "TV"
				p.volume_db = -14.0 + linear_to_db(maxf(tv_volume, 0.001))
				speaker.add_child(p)
				p.play()
				p.finished.connect(p.queue_free)


func capture() -> Dictionary:
	return {"mode": mode, "tiles": tiles.duplicate(), "focus": focus_index, "interval": interval, "mic_muted": mic_muted, "volume": tv_volume, "next_tile": _next_tile, "powered": powered, "bag": _bag.duplicate(), "last_removed": _last_removed}


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
	_last_removed = int(d.get("last_removed", -1))
	var bag: Array = d.get("bag", [])
	if not bag.is_empty():
		_bag.clear()
		for b in bag:
			if int(b) >= 0 and int(b) < cams.size() and not _bag.has(int(b)):
				_bag.append(int(b))
	_apply_tiles()
	var m := str(d.get("mode", "quad"))
	set_mode(m if m in ["quad", "focus", "entertainment"] else "quad")
	set_power(bool(d.get("powered", true)))
