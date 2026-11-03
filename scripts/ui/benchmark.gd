class_name Benchmark
extends Node
## Repeatable 60 s performance route: shoreline -> forest -> camp. Flies the
## player camera along fixed waypoints (eye height), records every frame time
## and writes the result into a diagnostic report. Numbers are only as good
## as the machine they were measured on; nothing is assumed.

signal progress(text: String)
signal finished(report: String)

const DURATION := 60.0
var _t := 0.0
var _times := PackedFloat32Array()
var _draws := PackedInt32Array()
var _path: Array[Vector3] = []
var _was_fly := false


func _ready() -> void:
	var vps := Viewpoints.all()
	for k in ["coast_day", "beach", "shallows", "river", "forest", "camp", "camper"]:
		_path.append(vps[k].pos)
	if Game.player:
		_was_fly = Game.player.fly_mode
		Game.player.fly_mode = true


func _process(delta: float) -> void:
	_t += delta
	_times.append(delta * 1000.0)
	_draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	var f := clampf(_t / DURATION, 0.0, 0.9999) * (_path.size() - 1)
	var i := int(f)
	var a := _path[i]
	var b := _path[i + 1]
	var pos := a.lerp(b, smoothstep(0.0, 1.0, f - i))
	var look := b + (b - a).normalized() * 5.0
	if Game.player:
		Game.player.teleport(pos, look)
	progress.emit("Benchmark %d s / %d s  -  %d fps" % [int(_t), int(DURATION), Engine.get_frames_per_second()])
	if _t >= DURATION:
		_finish()


func _finish() -> void:
	set_process(false)
	var arr := Array(_times)
	arr.sort()
	var n := arr.size()
	var avg := 0.0
	for v in arr:
		avg += v
	avg /= maxf(n, 1)
	var dsum := 0
	for d in _draws:
		dsum += d
	var summary := "avg %.1f fps (%.2f ms), p50 %.2f ms, p95 %.2f ms, p99 %.2f ms, worst %.1f ms, %d frames, avg draw calls %d" % [1000.0 / avg, avg, arr[n / 2], arr[int(n * 0.95)], arr[mini(int(n * 0.99), n - 1)], arr[n - 1], n, dsum / maxi(n, 1)]
	var path := Diag.write_report({"Benchmark route (coast -> forest -> camp, 60 s)": summary})
	if Game.player:
		Game.player.fly_mode = _was_fly
		Game.world_root.teleport_to("camp")
	finished.emit(summary + "\nReport: " + Diag.sanitize(path))
	queue_free()
