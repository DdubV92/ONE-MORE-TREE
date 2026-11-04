extends Node
## Phase 5 cost measurements (needs a real renderer; numbers from a software
## renderer are only relative). Preview world, player on the couch:
##   TV off / quad / focus / entertainment, then both trucks driving with
##   worker teams while the TV shows the wall.
##   godot res://tools/perf_p5.tscn
## Prints PERF lines: frame ms (avg / p95), main-view render CPU/GPU ms, and
## the summed security-camera render CPU/GPU ms per frame.

func _ready() -> void:
	Game.mode = Game.Mode.PREVIEW
	Game.pending_teleport = "camper_lounge"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	var g := 0
	while not world.systems_ready and g < 900:
		await get_tree().process_frame
		g += 1
	for i in 30:
		await get_tree().process_frame
	var p: Player = world.player
	var seats := get_tree().get_nodes_in_group("couch_seat")
	p.sit_on_couch(seats[0])
	var tv: CameraWall = world.tv
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for vp in tv._quad_vps:
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(tv._focus_vp.get_viewport_rid(), true)
	var out := {}
	tv.set_power(false)
	out["tv_off"] = await _measure(tv, 90)
	tv.set_power(true)
	tv.set_mode("quad")
	out["quad"] = await _measure(tv, 90)
	tv.focus_tile(0)
	out["focus"] = await _measure(tv, 90)
	tv.set_mode("entertainment")
	out["entertainment"] = await _measure(tv, 90)
	# Both trucks with teams on the road, TV wall on.
	var cs: CampaignService = world.campaign
	cs.start_test_route(false)
	cs.wallet.grant(3000000, "test", "PERF", "perf cash")
	var vs: VehicleService = world.vehicles
	vs.dev_unlock = true
	vs.buy()
	vs.buy()
	var ids: Array = vs.trucks.keys()
	var area := World.camp_origin() + Vector3(0, 0, -70)
	for k in ids.size():
		var t: Truck = vs.trucks[ids[k]]
		t.take_control("auto")
		t.set_route(vs.nav.route(t.global_position, area + Vector3(k * 12.0, 0, 0)))
	tv.set_mode("quad")
	out["quad_two_trucks_driving"] = await _measure(tv, 90)
	print("PERF_P5 ", JSON.stringify(out))
	get_tree().quit()


func _measure(tv: CameraWall, frames: int) -> Dictionary:
	for i in 20:
		await get_tree().process_frame
	var times: Array[float] = []
	var main_cpu := 0.0
	var main_gpu := 0.0
	var cam_cpu := 0.0
	var cam_gpu := 0.0
	var renders := 0
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await get_tree().process_frame
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
		t0 = t1
		main_cpu += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
		main_gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		for vp in tv._quad_vps + [tv._focus_vp]:
			cam_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
			cam_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
	renders = tv.renders_this_second
	times.sort()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= times.size()
	return {"frame_ms": snappedf(avg, 0.1), "p95_ms": snappedf(times[int(times.size() * 0.95)], 0.1), "main_cpu_ms": snappedf(main_cpu / frames, 0.01), "main_gpu_ms": snappedf(main_gpu / frames, 0.01), "cams_cpu_ms": snappedf(cam_cpu / frames, 0.01), "cams_gpu_ms": snappedf(cam_gpu / frames, 0.01), "cam_renders_per_s": renders, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
