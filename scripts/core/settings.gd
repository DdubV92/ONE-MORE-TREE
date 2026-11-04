extends Node
## Autoload "Settings": player-facing options persisted to user://settings.cfg
## (separate from campaign saves). Emits `changed` so systems re-apply.

signal changed

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Ambience", "Work", "Characters", "Music", "Horror", "UI", "TV"]

var values := {
	"mouse_sensitivity": 0.22,
	"invert_y": false,
	"fov": 75.0,
	"head_bob": true,
	"camera_shake": true,
	"hold_to_chop": true,
	"felling_aid": true,
	"quality": "high",              # low / medium / high / ultra
	"vsync": true,
	"fullscreen": false,
	"render_scale": 1.0,
	"upscaler": "fsr2",             # bilinear / fsr1 / fsr2 (used when render scale < 1)
	"tonemapper": "filmic",         # filmic / agx
	"dof_mode": "off",              # off / subtle / cinematic
	"chromatic_aberration": 0.0,    # 0..1, default off
	"vignette": 0.22,
	"bloom": true,
	"color_grading": 1.0,           # 0..1 strength
	"heat_haze": true,
	"film_grain": 0.0,
	"vol_Master": 0.9,
	"vol_Ambience": 0.85,
	"vol_Work": 0.9,
	"vol_Characters": 0.9,
	"vol_Music": 0.6,
	"vol_Horror": 0.9,
	"vol_UI": 0.7,
	"vol_TV": 0.8,
	"tv_interval": 5.0,             # camera wall: seconds per tile swap (0 = frozen)
	# Phase 8 comfort / presentation
	"flash_reduction": "reduced",   # full / reduced / off (distant lightning, bright cues)
	"shake_strength": 1.0,          # 0..1 camera shake scale (camera_shake toggle still applies)
	"bob_strength": 1.0,            # 0..1 head-bob scale
	"horror_intensity": 1.0,        # 0.4..1 startle/peak loudness & flash scale (never changes event count or rules)
	"music": true,                  # sparse daytime phrases
	# Phase 9 accessibility / input
	"ui_scale": 1.0,                # text and UI size, 0.85..1.6
	"captions": true,               # captions for meaningful sounds and remote mic cues
	"subtitles": true,              # worker speech text
	"highlight": 1.0,               # interaction target highlight strength 0..1
	"hints": true,                  # tutorial / contextual hints
	"binds": {},                    # remapped actions (Keys.capture())
}

var defaults := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	defaults = values.duplicate()
	_ensure_buses()
	load_settings()
	Keys.remember_defaults()
	Keys.apply_saved(values.binds)
	apply()


func _ensure_buses() -> void:
	# Bus layout is created in code so it cannot drift from this list.
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	# Ambience gets an "interior" low-pass + reverb that audio zones drive.
	var amb := AudioServer.get_bus_index("Ambience")
	if AudioServer.get_bus_effect_count(amb) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 20000.0
		lp.resonance = 0.5
		AudioServer.add_bus_effect(amb, lp)
	# TV speaker: transmission low-pass (camera wall drives the cutoff) and
	# a limiter so relayed peaks are bounded.
	var tvb := AudioServer.get_bus_index("TV")
	if AudioServer.get_bus_effect_count(tvb) == 0:
		var tlp := AudioEffectLowPassFilter.new()
		tlp.cutoff_hz = 2600.0
		AudioServer.add_bus_effect(tvb, tlp)
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 180.0
		AudioServer.add_bus_effect(tvb, hp)
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -3.0
		AudioServer.add_bus_effect(tvb, lim)
	# Peak control: horror cues and the master mix are limited so a focused
	# TV relay plus a local scare cannot stack into an uncontrolled spike.
	var hb := AudioServer.get_bus_index("Horror")
	if AudioServer.get_bus_effect_count(hb) == 0:
		var hl := AudioEffectHardLimiter.new()
		hl.ceiling_db = -2.0
		AudioServer.add_bus_effect(hb, hl)
	if AudioServer.get_bus_effect_count(0) == 0:
		var ml := AudioEffectHardLimiter.new()
		ml.ceiling_db = -0.3
		AudioServer.add_bus_effect(0, ml)
	var chars := AudioServer.get_bus_index("Characters")
	if AudioServer.get_bus_effect_count(chars) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.25
		rv.damping = 0.7
		rv.wet = 0.0
		rv.dry = 1.0
		AudioServer.add_bus_effect(chars, rv)


func get_v(key: String) -> Variant:
	return values.get(key, defaults.get(key))


func set_v(key: String, v: Variant, save := true) -> void:
	values[key] = v
	apply()
	if save:
		save_settings()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in values.keys():
		if cf.has_section_key("settings", k):
			var v: Variant = cf.get_value("settings", k)
			if typeof(v) == typeof(values[k]) or (typeof(values[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[k] = v
	sanitize()


func sanitize() -> void:
	values.mouse_sensitivity = clampf(float(values.mouse_sensitivity), 0.02, 1.5)
	values.fov = clampf(float(values.fov), 55.0, 100.0)
	values.chromatic_aberration = clampf(float(values.chromatic_aberration), 0.0, 1.0)
	values.vignette = clampf(float(values.vignette), 0.0, 1.0)
	values.color_grading = clampf(float(values.color_grading), 0.0, 1.0)
	values.film_grain = clampf(float(values.film_grain), 0.0, 1.0)
	values.render_scale = clampf(float(values.render_scale), 0.5, 1.0)
	if not values.quality in ["low", "medium", "high", "ultra"]:
		values.quality = "high"
	if not values.dof_mode in ["off", "subtle", "cinematic"]:
		values.dof_mode = "off"
	if not values.upscaler in ["bilinear", "fsr1", "fsr2"]:
		values.upscaler = "fsr2"
	if not values.tonemapper in ["filmic", "agx"]:
		values.tonemapper = "filmic"
	for b in BUSES:
		values["vol_" + b] = clampf(float(values["vol_" + b]), 0.0, 1.0)
	values.tv_interval = clampf(float(values.get("tv_interval", 5.0)), 0.0, 60.0)
	if not values.flash_reduction in ["full", "reduced", "off"]:
		values.flash_reduction = "reduced"
	values.shake_strength = clampf(float(values.shake_strength), 0.0, 1.0)
	values.bob_strength = clampf(float(values.bob_strength), 0.0, 1.0)
	values.horror_intensity = clampf(float(values.horror_intensity), 0.4, 1.0)
	values.ui_scale = clampf(float(values.ui_scale), 0.85, 1.6)
	values.highlight = clampf(float(values.highlight), 0.0, 1.0)
	if typeof(values.binds) != TYPE_DICTIONARY:
		values.binds = {}


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)


## Rebinds an action, persists all bindings and refreshes every prompt.
func rebind(action: String, ev: InputEvent) -> String:
	var swapped := Keys.rebind(action, ev)
	values.binds = Keys.capture()
	save_settings()
	changed.emit()
	return swapped


func reset_bindings() -> void:
	Keys.reset_defaults()
	values.binds = {}
	save_settings()
	changed.emit()


func reset_defaults() -> void:
	values = defaults.duplicate()
	Keys.reset_defaults()
	apply()
	save_settings()


func apply() -> void:
	sanitize()
	for b in BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx >= 0:
			var lin: float = values["vol_" + b]
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
			AudioServer.set_bus_mute(idx, lin <= 0.001)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
		var want_fs: bool = values.fullscreen
		var is_fs := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		if want_fs != is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_factor = float(values.ui_scale)
		get_tree().root.scaling_3d_scale = values.render_scale
		# FSR 2 is temporal upscaling (also anti-aliases); FSR 1 is spatial.
		var mode := Viewport.SCALING_3D_MODE_BILINEAR
		if float(values.render_scale) < 0.999:
			mode = {"bilinear": Viewport.SCALING_3D_MODE_BILINEAR, "fsr1": Viewport.SCALING_3D_MODE_FSR, "fsr2": Viewport.SCALING_3D_MODE_FSR2}[values.upscaler]
		get_tree().root.scaling_3d_mode = mode
	changed.emit()
