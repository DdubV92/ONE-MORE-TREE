class_name Audition
extends Node3D
## Phase 15 audition route (Preview only, in memory): short scripted
## sequences that reveal mistakes in distance, direction, occlusion, rooms,
## state machines, relay and replay. Each run replaces the previous one;
## leaving or starting another stop stops its sources (explicit lifecycle).

static var _cur: Audition
var _loops: Array[int] = []
var _nodes: Array[Node] = []
var running := ""
var log_lines: PackedStringArray = []


static func start(world: Node, which: String) -> String:
	if _cur and is_instance_valid(_cur):
		_cur.stop_all()
		_cur.queue_free()
	_cur = Audition.new()
	_cur.name = "Audition"
	world.add_child(_cur)
	return _cur._run(which)


func stop_all() -> void:
	for h in _loops:
		SoundService.loop_stop(h, 0.1)
	_loops.clear()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func _exit_tree() -> void:
	stop_all()


func _player() -> Player:
	return Game.player


func _ahead(d: float, side := 0.0, up := 0.0) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var f := -cam.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var r := cam.global_basis.x
	return cam.global_position + f * d + r * side + Vector3(0, up, 0)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _run(which: String) -> String:
	running = which
	match which:
		"distance":
			_distance()
			return "One dry knock at 3 m, 12 m, 40 m and 120 m straight ahead (the far ones arrive late: sound travels ~343 m/s). Same source, same level setting."
		"orbit":
			_orbit()
			return "A small engine circles you at 6 m, then rises overhead and drops behind. Turn your head: the direction follows your view, not the screen."
		"door":
			_door()
			return "You're in the camper; something knocks just outside the door. The door opens and closes every 4 s: muffled through the closed door (a 2.4 kHz path), clear through the open doorway (and from its direction)."
		"in_out":
			_in_out()
			return "Typing at the desk (indoors, clear) and slow footsteps outside at the same time: only the outdoor source is muffled by the walls (per-source occlusion, not a whole-bus filter)."
		"work":
			_work()
			return "Material sequence: pine/birch bites thin and thick, bucking, stump, a log on the rack, on the cart, a deck stack, cart wheels, fire pops, a falling tree."
		"saw":
			_saw()
			return "Chainsaw state machine in front of you: start pull, idle, free-rev (no work), loaded cut, release, spin-down, cut-out stop. One start per start."
		"truck_dog":
			_truck_dog()
			return "Truck engine idle -> high -> idle with tyres and cargo rattle, then Biscuit: paws on boards and dirt, tags, a bark."
		"ambience":
			_ambience()
			return "Ambience in place: forest air + wind in what stands here, insects by day; a night layer (crickets, an owl). Rain on the roof above you if you're under one. Walk to the shore or the river to hear them anchored to the water."
		"relay":
			return "Sit at the camper desk and open Cameras: one camera's microphone relays nearby world sounds through the desk speakers (Relay bus), quiet in the wall, clearer when focused; 'Mics' mutes only the relay, never the night outside."
		"replay":
			return _replay()
		"night":
			_night()
			return "Night quiet: a long silence, then one localized knock at the fence and a far branch. Nothing announces itself with a sting."
		"worst":
			_worst()
			return "Worst supported overlap: a running saw, chopping, a falling tree, thunder, rain and a knock at once. Check the active voice counts with the debug list (dev)."
	return ""


func _distance() -> void:
	for d in [3.0, 12.0, 40.0, 120.0]:
		SoundService.play("terror.knock.wood", _ahead(d, 0.0, 0.3), {"emit": false, "file": "knock_wood_sharp"})
		await _wait(2.6)


func _orbit() -> void:
	var m := Marker3D.new()
	add_child(m)
	_nodes.append(m)
	var h := SoundService.loop("truck.engine.idle", m, {"emit": false})
	_loops.append(h)
	var t := 0.0
	var c := get_viewport().get_camera_3d().global_position
	while t < 10.0 and is_instance_valid(m):
		var a := t * 0.9
		var up := 0.0 if t < 7.0 else (t - 7.0) * 2.5
		m.global_position = c + Vector3(cos(a) * 6.0, up, sin(a) * 6.0)
		await get_tree().process_frame
		t += get_process_delta_time()
	SoundService.loop_stop(h, 0.3)


func _door() -> void:
	var w: IslandWorld = Game.world_root
	w.teleport_to("camper")
	await _wait(0.5)
	var door: Door = null
	for d in get_tree().get_nodes_in_group("doors"):
		if str((d as Node).name).contains("Camper") and not str((d as Node).name).contains("Bath"):
			door = d
	if door == null:
		return
	var out := door.global_position + door.global_basis.x * door.width * 0.5 - door.global_basis.z * 2.5 + Vector3(0, 1.0, 0)
	for k in 6:
		SoundService.play("terror.knock.wood", out, {"emit": false})
		await _wait(2.0)
		door.set_open(k % 2 == 0)
		await _wait(2.0)
	door.set_open(false)


func _in_out() -> void:
	var w: IslandWorld = Game.world_root
	w.teleport_to("camper_lounge")
	await _wait(0.5)
	var mons := get_tree().get_nodes_in_group("camper_monitor")
	if not mons.is_empty():
		_loops.append(SoundService.loop("home.keyboard", (mons[0] as Node3D), {"emit": false}))
	var out := World.camp_origin() + CampLayout.CAMPER_POS + Vector3(5.5, 0.5, 2.0)
	for k in 3:
		SoundService.play("terror.steps.gravel", out + Vector3(0, 0, -k * 1.5), {"emit": false})
		await _wait(4.2)
	stop_all()


func _work() -> void:
	var seq := ["work.axe.bite.pine.thin", "work.axe.bite.pine.thick", "work.axe.bite.birch.thin", "work.axe.bite.birch.thick", "work.axe.buck", "work.axe.stump", "log.drop.rack", "log.drop.cart", "log.stack", "fire.pop", "tree.strain", "tree.hinge.crack", "tree.fall.medium"]
	for e in seq:
		SoundService.play(e, _ahead(4.0, 1.0, 0.5), {"emit": false})
		await _wait(1.3)
	var m := Marker3D.new()
	add_child(m)
	_nodes.append(m)
	m.global_position = _ahead(3.0)
	var h := SoundService.loop("cart.roll.dirt", m, {"emit": false})
	_loops.append(h)
	await _wait(2.5)
	SoundService.loop_stop(h, 0.3)


func _saw() -> void:
	var m := SawMachine.new()
	var a := SawAudio.new()
	a.who = "audition"
	add_child(a)
	_nodes.append(a)
	a.global_position = _ahead(2.0, 0.4, -0.4)
	m.start()
	var plan := [[2.2, false, false], [1.5, true, false], [2.0, true, true], [1.0, false, false], [1.0, true, true], [0.6, false, false]]
	for st in plan:
		var t := 0.0
		while t < float(st[0]):
			var dt := get_process_delta_time()
			m.step(dt, bool(st[1]), bool(st[2]))
			a.update(m, dt)
			await get_tree().process_frame
			t += dt
	m.kill()
	a.update(m, 0.016)
	log_lines.append("saw starts: %d, ticks in air: 0 by design" % m.starts)


func _truck_dog() -> void:
	var m := Marker3D.new()
	add_child(m)
	_nodes.append(m)
	m.global_position = _ahead(8.0, -3.0)
	var ta := TruckAudio.new()
	m.add_child(ta)
	ta.set_state(0.0, 0.0, true)
	var t := 0.0
	while t < 6.0:
		var s := clampf(sin(t / 6.0 * PI), 0.0, 1.0)
		ta.set_state(s, s, true)
		await get_tree().process_frame
		t += get_process_delta_time()
	ta.set_state(0.0, 0.0, false)
	await _wait(1.0)
	ta.queue_free()
	for e in ["dog.paw.wood", "dog.paw.wood", "dog.paw.dirt", "dog.paw.dirt", "dog.tags", "dog.bark"]:
		SoundService.play(e, _ahead(2.0, 0.8, -1.2), {"emit": false})
		await _wait(0.35)


func _ambience() -> void:
	if Game.environment:
		Game.environment.apply_named("night")
	await _wait(6.0)
	SoundService.play("amb.owl", _ahead(30.0, 10.0, 8.0), {"emit": false})
	await _wait(6.0)
	if Game.environment:
		Game.environment.apply_named("day")


func _replay() -> String:
	var snd: SoundService = Game.sound
	if snd == null:
		return ""
	var mons := get_tree().get_nodes_in_group("camper_monitor")
	if mons.is_empty():
		return "No desk monitor here."
	var recs := snd.recorder.duplicate()
	if recs.is_empty():
		return "Nothing recorded yet: chop something first, then try again."
	var t1 := float(recs[recs.size() - 1].t)
	var n := SoundService.replay(recs, mons[0], t1 - 20.0, t1)
	return "Replayed %d recorded world sounds from the last 20 s through the desk speakers (RECORDING origin: no new evidence, no camera capture, no gameplay; the recorder did not grow)." % n


func _night() -> void:
	if Game.environment:
		Game.environment.apply_named("night")
	await _wait(9.0)
	var c := World.camp_origin()
	SoundService.play("camp.fence.rattle", c + Vector3(12.0, 1.0, -18.5), {"emit": false})
	await _wait(5.0)
	SoundService.play("amb.branch.far", _ahead(80.0, -30.0, 6.0), {"emit": false})


func _worst() -> void:
	var m := SawMachine.new()
	var a := SawAudio.new()
	add_child(a)
	_nodes.append(a)
	a.global_position = _ahead(3.0, 1.0, -0.4)
	m.start()
	var t := 0.0
	var fired := false
	while t < 6.0:
		var dt := get_process_delta_time()
		m.step(dt, t > 1.6, t > 2.2)
		a.update(m, dt)
		if t > 2.5 and not fired:
			fired = true
			SoundService.play("tree.fall.large", _ahead(25.0, -8.0), {"emit": false})
			SoundService.play("weather.thunder.near", _ahead(200.0, 60.0, 80.0), {"emit": false, "no_delay": true})
			SoundService.play("terror.knock.wood", _ahead(6.0, -4.0, 0.5), {"emit": false})
			for k in 3:
				SoundService.play("work.axe.bite.spruce.thick", _ahead(10.0 + k, 3.0), {"emit": false})
		await get_tree().process_frame
		t += dt
	log_lines.append("worst overlap active: %s" % str(SoundService.active_count()))
	m.kill()
	a.update(m, 0.016)


## Dev: the active voices (event, distance, bus/tier, level). Not shown in
## ordinary UI; entities' positions are never listed for hidden actors.
static func debug_list() -> String:
	var s := SoundService.instance()
	if s == null:
		return ""
	var cam := s.get_viewport().get_camera_3d()
	var lines := PackedStringArray()
	var all: Array = s.voices.filter(func(v) -> bool: return v.busy) + s.loops.values()
	for v in all:
		if str(v.base_bus) == "Horror" and not Game.is_preview():
			continue
		lines.append("%s · %.0f m · %s · %.1f dB%s" % [v.event, v.p.global_position.distance_to(cam.global_position) if cam else 0.0, v.p.bus, v.p.volume_db, " · via door" if v.portal != Vector3.INF else ""])
	return "Active voices %s\n%s" % [str(SoundService.active_count()), "\n".join(lines.slice(0, 14))]
