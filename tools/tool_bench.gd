extends Node
## Phase 14: cutting time per tree for each tool on identical r2 trees
## (felling + every bucking boundary + crown + stump), using the real work
## requirements and the real swing/saw machines. Excludes walking and
## repositioning (see crew_sim for the whole pipeline).
##   godot --headless res://tools/tool_bench.tscn

func _ready() -> void:
	await get_tree().process_frame
	World.ensure_loaded()
	Game.mode = Game.Mode.PREVIEW
	Game.preview_variant = "island_r2"
	var world: IslandWorld = load("res://scenes/world.tscn").instantiate()
	world.build_ui = false
	world.build_player = false
	add_child(world)
	for i in 30:
		await get_tree().physics_frame
	var cfg: TreeWorkConfig = load("res://config/tree_work.tres")
	var t: TimberService = world.timber
	var tools := {"hatchet": {"tool": "axe", "tier": "small"}, "felling axe": {"tool": "axe", "tier": "medium"}, "heavy axe": {"tool": "axe", "tier": "large"}, "heavy axe + t3 helmet/gloves": {"tool": "axe", "tier": "large", "helmet": "t3", "gloves": "t3"}, "chainsaw": {"tool": "chainsaw"}}
	var totals := {}
	var trees := 0
	for j in 40:
		var idx := (j * 251) % World.tree_count()
		var id: int = World.trees.id[idx]
		var sp: int = World.trees.species[idx]
		var fell := cfg.required_units(sp, float(World.trees.radius[idx]))
		var rec := t._build_record(id, idx, {"plan": "v2", "segments": []})
		var cuts := []
		for b in rec.bounds:
			cuts.append(float(b.required))
		cuts.append(float(rec.crown.required))
		var stump := Game.trees.stump_required(id) if Game.trees.has_method("stump_required") else fell * 0.5
		var jobs := [fell] + cuts + [stump]
		trees += 1
		for name in tools:
			var b := ToolEffects.breakdown(tools[name])
			var secs := 0.0
			for need in jobs:
				if str(b.tool) == "axe":
					secs += ceil(float(need) / float(b.work_per_contact) - 1e-6) * float(b.cycle_s)
				else:
					# Real engine: spin-up per cut, ticks of rate x 0.1 s.
					var m := SawMachine.new()
					m.state = SawMachine.S.IDLE
					m.rpm = SawMachine.IDLE_RPM
					var done := 0.0
					var tt := 0.0
					while done < float(need) - 1e-6 and tt < 600.0:
						done += m.step(1.0 / 60.0, true, true) * float(b.saw_rate) * ToolEffects.SAW_TICK
						tt += 1.0 / 60.0
					secs += tt
			if str(b.tool) == "chainsaw":
				secs += float(b.start_s)     # one start per tree
			totals[name] = float(totals.get(name, 0.0)) + secs
	var base := float(totals["hatchet"]) / trees
	var out := {}
	for name in totals:
		var per := float(totals[name]) / trees
		out[name] = {"cut_s_per_tree": snappedf(per, 0.1), "vs_hatchet": snappedf(base / per, 0.01)}
	print("TOOL_BENCH ", JSON.stringify({"trees": trees, "results": out}))
	get_tree().quit()
