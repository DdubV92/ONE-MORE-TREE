class_name CrewDemoPanel
extends VBoxContainer
## Preview Tour "Crew Demonstration" (Phase 4): an isolated in-memory
## session (never saved) with a five-person crew of mixed traits, plus
## development stimuli that the workers perceive with their own senses.
## These fixtures stand in for the Phase 6 Terror director; nothing here is
## a monster, a reward, or campaign state.

var hud: Node
var _n := 0


func setup(h: Node) -> void:
	hud = h
	add_child(UITheme.label("Crew Demonstration", 16, UITheme.MUTED))
	var g := GridContainer.new()
	g.columns = 2
	add_child(g)
	var b := func(text: String, cb: Callable) -> void:
		g.add_child(UITheme.button(text, cb, 130))
	b.call("Start crew demo", _start)
	b.call("Twig snap", func() -> void: _stim("twig", "sound", 0.25, 0.06, true, 8.0))
	b.call("Howl in trees", func() -> void: _stim("howl", "sound", 1.2, 0.22, true, 45.0))
	b.call("Voice mimic", _mimic)
	b.call("Figure at trees", func() -> void: _stim("figure", "sight", 0.0, 0.6, false, 18.0, true))
	b.call("Boss: I saw it", _report)
	b.call("Crew follow me", func() -> void: _all_job("follow"))
	b.call("Crew back to work", func() -> void: _all_job("automatic"))
	b.call("Jump to dusk", func() -> void:
		if _c():
			Game.campaign.clock.t = WorkdayClock.DAYLIGHT_SECONDS - 5.0)
	b.call("Empty the till", func() -> void:
		if _c():
			Game.campaign.wallet.spend(Game.campaign.wallet.cash, "test", "FIXTURE", "Fixture: empty the till")
			_msg("Cash emptied (fixture). Sleep twice without paying to see arrears and a quit."))
	b.call("Crew journal", func() -> void:
		if _c():
			hud.tour_panel.visible = false
			Game.campaign_ui.toggle_journal(0))


func _c() -> bool:
	if Game.crew == null or not Game.crew.enabled or not Game.campaign.test_route:
		_msg("Press 'Start crew demo' first.")
		return false
	return true


func _start() -> void:
	var cs: CampaignService = Game.campaign
	cs.start_test_route(false)
	cs.wallet.grant(800000, "test", "FIXTURE", "Demo cash")
	var crew: CrewService = Game.crew
	crew.when_ready(func() -> void:
		# Three demonstration hires with chosen traits, delivered by the boat.
		var sets := [["timid", "observant"], ["level_headed", "sociable"], ["skeptical", "hard_working"]]
		crew.candidates.clear()
		for i in 3:
			crew._cand_counter += 1
			crew.candidates.append({"cid": "DEMO-%d" % i, "name": ["Ines Vance", "Kofi Brandt", "Wren Salo"][i], "traits": sets[i], "look_seed": 4242 + i * 77, "fee": crew.econ.hire_fee_cents, "wage": PayMorale.asking_wage("DEMO-%d" % i, sets[i])})
		for i in 3:
			crew.hire("DEMO-%d" % i)
		_msg("Crew demo: two starters at camp, three hires (timid+observant, level-headed+sociable, skeptical+hard-working) arriving by boat at the dock. In memory only."))
	hud.tour_panel.visible = false


func _nearest_worker() -> Worker:
	var best: Worker = null
	var bd := INF
	for w in Game.crew.workers.values():
		var d := (w as Worker).global_position.distance_to(Game.player.global_position)
		if d < bd:
			bd = d
			best = w
	return best


## A development stimulus near the nearest worker (or the boss).
func _stim(kind: String, modality: String, loud: float, sev: float, ambiguous: bool, dist: float, visual := false) -> void:
	if not _c():
		return
	var w := _nearest_worker()
	var origin: Vector3 = w.global_position if w else Game.player.global_position
	var dir := (-w.global_basis.z) if w else Vector3.FORWARD
	if modality == "sound":
		dir = dir.rotated(Vector3.UP, 2.4)
	var pos := origin + dir * dist
	pos.y = World.height_at(pos.x, pos.z) + 1.0
	_n += 1
	var who: Array = Game.crew.emit_stimulus({"id": "DEV-%s-%d" % [kind, _n], "kind": kind, "modality": modality, "pos": pos, "loudness": loud, "severity": sev, "ambiguous": ambiguous})
	if visual:
		_silhouette(pos)
	_msg("Stimulus '%s' at %.0f m. Perceived by: %s" % [kind, dist, ", ".join(PackedStringArray(who.map(func(i: String) -> String: return str(Game.crew.emp(i).get("name", i))))) if not who.is_empty() else "nobody"])


func _mimic() -> void:
	if not _c():
		return
	var w := _nearest_worker()
	if w == null:
		return
	var other: Worker = null
	for o in Game.crew.workers.values():
		if o != w and (other == null or (o as Worker).global_position.distance_to(w.global_position) < other.global_position.distance_to(w.global_position)):
			other = o
	var pos := w.global_position - w.global_basis.z * 25.0
	pos.y = World.height_at(pos.x, pos.z) + 1.2
	_n += 1
	var who: Array = Game.crew.emit_stimulus({"id": "DEV-voice-%d" % _n, "kind": "voice_mimic", "modality": "voice", "pos": pos, "loudness": 0.8, "severity": 0.35, "ambiguous": false, "imitates": other.id if other else "", "imitated_name": other.emp.name if other else "someone"})
	_msg("A voice like %s called from the trees. Heard by: %d" % [other.emp.name if other else "someone", who.size()])


func _report() -> void:
	if not _c():
		return
	var w := _nearest_worker()
	if w:
		var r := Game.crew.boss_report(w)
		_msg("%s took your report as %s." % [w.emp.name, "corroborated" if r == "corroborated" else "an unconfirmed rumour"])


func _all_job(job: String) -> void:
	if not _c():
		return
	for w in Game.crew.workers.values():
		Game.campaign_ui.order_job(w, job)


## A brief dark shape at the treeline (so the reviewer sees what was shown).
func _silhouette(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 2.6)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.025, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	Game.world_root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.3, 0)
	var tw := mi.create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(mi.queue_free)


func _msg(t: String) -> void:
	hud.show_message(t, 6.0)
