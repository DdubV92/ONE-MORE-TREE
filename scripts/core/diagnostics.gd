extends Node
## Autoload "Diag": collects engine errors/warnings through a custom Logger,
## tracks frame-time statistics, and writes a plain-text diagnostic report
## the player can send back for review. Reports never include credentials
## and strip the user's home/profile paths.

const REPORT_DIR := "user://diagnostics"
const MAX_LOG := 200

var errors: Array[String] = []
var warnings: Array[String] = []
var frame_times := PackedFloat32Array()
var _ft_index := 0
var build_info := {}
var _logger: DiagLogger


class DiagLogger extends Logger:
	var owner_node: Node
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		var msg := "%s: %s (%s:%d %s)" % ["WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR", rationale if rationale != "" else code, file.get_file(), line, function]
		mutex.lock()
		owner_node.call_deferred("_record", msg, error_type == ERROR_TYPE_WARNING)
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	frame_times.resize(600)
	_logger = DiagLogger.new()
	_logger.owner_node = self
	OS.add_logger(_logger)
	_load_build_info()


func _exit_tree() -> void:
	if _logger:
		OS.remove_logger(_logger)


func _record(msg: String, is_warning: bool) -> void:
	var list := warnings if is_warning else errors
	list.append(sanitize(msg))
	if list.size() > MAX_LOG:
		list.remove_at(0)


func _process(delta: float) -> void:
	frame_times[_ft_index] = delta * 1000.0
	_ft_index = (_ft_index + 1) % frame_times.size()


func _load_build_info() -> void:
	var f := FileAccess.open("res://build_info.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			build_info = parsed
	if build_info.is_empty():
		build_info = {"commit": "local-dev", "run": "-", "built_at": "-"}


func version_string() -> String:
	return "%s (%s)" % [ProjectSettings.get_setting("application/config/version"), str(build_info.get("commit", "?")).left(10)]


func frame_stats() -> Dictionary:
	var arr := Array(frame_times).filter(func(v: float) -> bool: return v > 0.0)
	if arr.is_empty():
		return {}
	arr.sort()
	var n := arr.size()
	var avg := 0.0
	for v in arr:
		avg += v
	avg /= n
	return {
		"samples": n,
		"avg_ms": snappedf(avg, 0.01),
		"p50_ms": snappedf(arr[n / 2], 0.01),
		"p95_ms": snappedf(arr[int(n * 0.95)], 0.01),
		"p99_ms": snappedf(arr[mini(int(n * 0.99), n - 1)], 0.01),
		"max_ms": snappedf(arr[n - 1], 0.01),
		"avg_fps": snappedf(1000.0 / avg, 0.1),
	}


static func sanitize(s: String) -> String:
	# Strip absolute user paths (home dirs, Windows profiles, user data dir).
	var out := s
	var data_dir := OS.get_user_data_dir()
	if data_dir != "":
		out = out.replace(data_dir, "user://")
	var home := OS.get_environment("HOME")
	if home == "":
		home = OS.get_environment("USERPROFILE")
	if home != "":
		out = out.replace(home, "~")
	var re := RegEx.create_from_string("(?i)([A-Z]:\\\\Users\\\\)[^\\\\/]+")
	out = re.sub(out, "$1<user>", true)
	re = RegEx.create_from_string("/home/[^/\\s]+")
	out = re.sub(out, "/home/<user>", true)
	return out


func build_report(extra: Dictionary = {}) -> String:
	var lines: PackedStringArray = []
	lines.append("ONE MORE TREE - diagnostic report")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(true))
	lines.append("Game version: %s" % version_string())
	lines.append("Build: commit=%s run=%s built_at=%s" % [build_info.get("commit"), build_info.get("run"), build_info.get("built_at")])
	var ev := Engine.get_version_info()
	lines.append("Engine: Godot %s" % ev.string)
	lines.append("OS: %s %s" % [OS.get_name(), OS.get_version()])
	lines.append("CPU: %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	lines.append("GPU: %s / %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()])
	lines.append("Renderer: %s, API %s" % [ProjectSettings.get_setting("rendering/renderer/rendering_method"), RenderingServer.get_video_adapter_api_version()])
	lines.append("Window: %s, render scale %.2f" % [str(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else "headless", Settings.get_v("render_scale")])
	lines.append("Quality preset: %s" % Settings.get_v("quality"))
	lines.append("Mode: %s" % Game.Mode.keys()[Game.mode])
	if Game.environment and Game.environment.has_method("describe"):
		lines.append("Lighting: %s" % Game.environment.describe())
	if Game.player:
		lines.append("Player position: %s" % str(Game.player.global_position.snapped(Vector3.ONE * 0.1)))
	if World.is_loaded:
		lines.append("World: seed=%s generation=%s trees=%d load_ms=%d" % [World.manifest.get("world_seed"), World.manifest.get("generation_version"), World.tree_count(), World.load_ms])
	lines.append("")
	lines.append("Frame times (last %d frames): %s" % [frame_times.size(), JSON.stringify(frame_stats())])
	lines.append("Draw calls: %d  Primitives: %d  Objects: %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	lines.append("Physics 3D active objects: %d  pairs: %d  islands: %d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)])
	lines.append("Memory: static %.1f MB, video %.1f MB, texture %.1f MB" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
	for k in extra:
		lines.append("%s: %s" % [k, str(extra[k])])
	lines.append("")
	lines.append("Errors (%d):" % errors.size())
	for e in errors.slice(-50):
		lines.append("  " + e)
	lines.append("Warnings (%d):" % warnings.size())
	for w in warnings.slice(-30):
		lines.append("  " + w)
	return sanitize("\n".join(lines))


## Writes the report and returns its absolute path (shown to the player).
func write_report(extra: Dictionary = {}) -> String:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	var stamp := Time.get_datetime_string_from_system(false).replace(":", "-")
	var path := REPORT_DIR.path_join("diagnostics_%s.txt" % stamp)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(build_report(extra))
	f.close()
	var latest := FileAccess.open(REPORT_DIR.path_join("diagnostics_latest.txt"), FileAccess.WRITE)
	if latest:
		latest.store_string(build_report(extra))
	return ProjectSettings.globalize_path(path)


func open_report_folder() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	OS.shell_open(ProjectSettings.globalize_path(REPORT_DIR))
