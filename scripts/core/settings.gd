extends Node
## Autoload "Settings": player-facing options persisted to user://settings.cfg
## (separate from campaign saves). Emits `changed` so systems re-apply.

signal changed

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Ambience", "Work", "Characters", "Music", "Horror", "UI"]

var values := {
	"mouse_sensitivity": 0.22,
	"invert_y": false,
	"fov": 75.0,
	"head_bob": true,
	"quality": "high",              # low / medium / high / ultra
	"vsync": true,
	"fullscreen": false,
	"render_scale": 1.0,
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
}

var defaults := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	defaults = values.duplicate()
	_ensure_buses()
	load_settings()
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
	for b in BUSES:
		values["vol_" + b] = clampf(float(values["vol_" + b]), 0.0, 1.0)


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)


func reset_defaults() -> void:
	values = defaults.duplicate()
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
		get_tree().root.scaling_3d_scale = values.render_scale
	changed.emit()
