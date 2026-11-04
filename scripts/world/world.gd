class_name IslandWorld
extends Node3D
## Root of the explorable island. Builds every subsystem from the frozen world
## data, registers services with Game, and owns campaign save/restore.

signal ready_to_play

@export var build_camp := true
@export var build_player := true
@export var build_ui := true

var terrain: TerrainSystem
var water: WaterSystem
var vegetation: VegetationSystem
var trees: TreeService
var timber: TimberService
var campaign: CampaignService
var crew: CrewService
var vehicles: VehicleService
var tv: CameraWall
var comfort: CamperComfort
var dog: CampDog
var director: TerrorDirector
var threat: NightThreat
var dog_rescue: DogRescue
var hunt: HuntService
var end_screen: EndScreen
var arcade: ArcadeService
var dock_site: DockSite
var ground_cover: Node3D
var environment: EnvironmentController
var weather: WeatherService
var camp: Node3D
var audio: Node3D
var safety: Node
var player: Node3D
var hud: CanvasLayer
var build_ms := {}
var systems_ready := false
var _ready_queue: Array[Callable] = []


func _ready() -> void:
	Game.world_root = self
	var t0 := Time.get_ticks_msec()
	World.ensure_loaded()
	# Every world starts from the frozen manifest; campaign modifications are
	# re-applied from the save below. Preview changes never carry over.
	World.removed_trees.clear()
	# Phase 10: the campaign's ruleset decides the native manifest (standard
	# 10,000 subset or the legacy/full 12,000) before anything is spawned.
	World.apply_variant(Ruleset.variant_for_start())
	build_ms["world_data"] = Time.get_ticks_msec() - t0
	environment = _timed("environment", func() -> Node: var e := EnvironmentController.new(); e.name = "Environment"; add_child(e); e.build(); return e)
	Game.environment = environment
	weather = WeatherService.new()
	weather.name = "Weather"
	add_child(weather)
	Game.weather = weather
	terrain = _timed("terrain", func() -> Node: var t := TerrainSystem.new(); t.name = "Terrain"; add_child(t); t.build(); return t)
	water = _timed("water", func() -> Node: var w := WaterSystem.new(); w.name = "Water"; add_child(w); w.build(_ocean_grid()); return w)
	Game.water = water
	_timed("sand_haze", func() -> Node: var h := SandHaze.new(); h.name = "SandHaze"; add_child(h); h.build(); return h)
	_timed("bridges", func() -> Node: var b := BridgeBuilder.new(); b.name = "Bridges"; add_child(b); b.build(); return b)
	vegetation = _timed("vegetation", func() -> Node: var v := VegetationSystem.new(); v.name = "Vegetation"; add_child(v); v.build(); return v)
	Game.vegetation = vegetation
	var fx := LoggingFX.new()
	fx.name = "LoggingFX"
	add_child(fx)
	trees = TreeService.new()
	trees.name = "Trees"
	add_child(trees)
	var actors := Node3D.new()
	actors.name = "ActiveTrees"
	add_child(actors)
	trees.setup(actors, not Game.is_preview())
	Game.trees = trees
	timber = TimberService.new()
	timber.name = "Timber"
	add_child(timber)
	var logs := Node3D.new()
	logs.name = "TimberBodies"
	add_child(logs)
	timber.setup(logs, not Game.is_preview())
	trees.timber = timber
	Game.timber = timber
	campaign = CampaignService.new()
	campaign.name = "Campaign"
	add_child(campaign)
	Game.campaign = campaign
	crew = CrewService.new()
	crew.name = "Crew"
	add_child(crew)
	campaign.crew = crew
	Game.crew = crew
	vehicles = VehicleService.new()
	vehicles.name = "Vehicles"
	add_child(vehicles)
	campaign.vehicles = vehicles
	Game.vehicles = vehicles
	tv = CameraWall.new()
	tv.name = "CameraWall"
	add_child(tv)
	Game.tv = tv
	arcade = ArcadeService.new()
	arcade.name = "Arcade"
	add_child(arcade)
	Game.arcade = arcade
	director = TerrorDirector.new()
	director.name = "TerrorDirector"
	add_child(director)
	Game.director = director
	threat = NightThreat.new()
	threat.name = "NightThreat"
	add_child(threat)
	Game.threat = threat
	dog_rescue = DogRescue.new()
	dog_rescue.name = "DogRescue"
	add_child(dog_rescue)
	Game.dog_rescue = dog_rescue
	end_screen = EndScreen.new()
	end_screen.name = "EndScreen"
	add_child(end_screen)
	Game.end_screen = end_screen
	threat.caught.connect(end_screen.show_caught)
	hunt = HuntService.new()
	hunt.name = "Hunt"
	add_child(hunt)
	Game.hunt = hunt
	comfort = CamperComfort.new()
	comfort.name = "CamperComfort"
	add_child(comfort)
	Game.comfort = comfort
	if ClassDB.class_exists("GroundCover") or ResourceLoader.exists("res://scripts/vegetation/ground_cover.gd"):
		ground_cover = _timed("ground_cover", func() -> Node:
			var g: Node3D = load("res://scripts/vegetation/ground_cover.gd").new()
			g.name = "GroundCover"
			add_child(g)
			return g)
	if build_camp and ResourceLoader.exists("res://scripts/camp/camp_builder.gd"):
		camp = _timed("camp", func() -> Node:
			var c: Node3D = load("res://scripts/camp/camp_builder.gd").new()
			c.name = "Camp"
			add_child(c)
			c.call("build")
			return c)
	if camp:
		dog = CampDog.new()
		dog.name = "Dog"
		add_child(dog)
		Game.dog = dog
	if ResourceLoader.exists("res://scripts/systems/safety_service.gd"):
		safety = load("res://scripts/systems/safety_service.gd").new()
		safety.name = "Safety"
		add_child(safety)
		Game.safety = safety
	if ResourceLoader.exists("res://scripts/audio/ambient_audio.gd"):
		audio = _timed("audio", func() -> Node:
			var a: Node3D = load("res://scripts/audio/ambient_audio.gd").new()
			a.name = "Audio"
			add_child(a)
			return a)
	if build_player and ResourceLoader.exists("res://scripts/player/player.gd"):
		player = load("res://scripts/player/player.gd").new()
		player.name = "Player"
		add_child(player)
		Game.player = player
	if build_ui and ResourceLoader.exists("res://scripts/ui/hud.gd"):
		hud = load("res://scripts/ui/hud.gd").new()
		hud.name = "HUD"
		add_child(hud)
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	campaign.setup()
	# Phase 9: a fulfilled contract is saved at once as a safe completed state.
	campaign.outcome_ready.connect(func(s: String, _o: String) -> void:
		if s == ContractService.FULFILLED:
			save_campaign.call_deferred())
	crew.setup(campaign)
	vehicles.setup(campaign, crew)
	_place_player()
	_build_crew_world.call_deferred()
	build_ms["total"] = Time.get_ticks_msec() - t0
	print("World built: ", build_ms)
	ready_to_play.emit()


## Crew navigation needs the camp's collision in the physics space: build
## it after the first physics frame.
func _build_crew_world() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var t := Time.get_ticks_msec()
	crew.build_world()
	build_ms["crew_nav"] = Time.get_ticks_msec() - t
	dock_site = DockSite.new()
	dock_site.name = "DockSite"
	add_child(dock_site)
	dock_site.build(crew)
	Game.dock_site = dock_site
	var t2 := Time.get_ticks_msec()
	vehicles.build_world()
	build_ms["drive_nav"] = Time.get_ticks_msec() - t2
	tv.setup()
	comfort.setup()
	arcade.hook_cabinets()
	if campaign and campaign.contract.state == ContractService.ABANDONMENT and hunt.mode == "none":
		campaign.contract.outcome.emit.call_deferred(campaign.contract.state, campaign.contract.outcome_id)
	systems_ready = true
	for f in _ready_queue:
		f.call()
	_ready_queue.clear()
	print("Drive routes built: %d ms (%dx%d cells)" % [build_ms.drive_nav, vehicles.nav.dims.x, vehicles.nav.dims.y])
	print("Crew navigation built: %d ms (island %dx%d cells, camp %dx%d)" % [build_ms.crew_nav, crew.nav.dims.x, crew.nav.dims.y, crew.nav.camp_dims.x, crew.nav.camp_dims.y])


## Runs f once crew/dock/vehicles/TV/comfort/arcade exist (now or later).
func when_systems_ready(f: Callable) -> void:
	if systems_ready:
		f.call()
	else:
		_ready_queue.append(f)


func _timed(label: String, f: Callable) -> Node:
	var t := Time.get_ticks_msec()
	var n: Node = f.call()
	build_ms[label] = Time.get_ticks_msec() - t
	return n


func _ocean_grid() -> int:
	match Settings.get_v("quality"):
		"low": return 160
		"medium": return 240
		"ultra": return 400
	return 320


func _apply_quality() -> void:
	var q: String = Settings.get_v("quality")
	if vegetation:
		var near: float = {"low": 110.0, "medium": 140.0, "high": 170.0, "ultra": 220.0}[q]
		var mid: float = {"low": 380.0, "medium": 480.0, "high": 560.0, "ultra": 700.0}[q]
		if not is_equal_approx(near, vegetation.near_range) or not is_equal_approx(mid, vegetation.mid_range):
			vegetation.set_ranges(near, mid, q == "ultra")
	if terrain:
		terrain.set_lod_scale({"low": 0.7, "medium": 0.85, "high": 1.0, "ultra": 1.3}[q])
	if ground_cover and ground_cover.has_method("set_density"):
		ground_cover.set_density({"low": 0.35, "medium": 0.65, "high": 1.0, "ultra": 1.4}[q])


func _place_player() -> void:
	if player == null:
		return
	var spot := "camp"
	if Game.is_preview() and Game.pending_teleport != "":
		spot = Game.pending_teleport
	elif Game.mode == Game.Mode.CAMPAIGN and not Game.new_game and load_campaign():
		return
	if Game.mode == Game.Mode.CAMPAIGN:
		# New contract in the selected slot (other slots are never touched).
		Game.new_game = false
		campaign.new_campaign()
		teleport_to(spot)
		save_campaign()
		save_checkpoint("morning")
		return
	teleport_to(spot)


func viewpoints() -> Dictionary:
	return Viewpoints.all()


func teleport_to(name: String) -> void:
	var vp: Dictionary = Viewpoints.all().get(name, Viewpoints.all()["camp"])
	if vp.has("lighting") and environment and Game.is_preview():
		environment.apply_named(vp.lighting)
	if player and player.has_method("teleport"):
		player.teleport(vp.pos, vp.look)
	if vegetation:
		vegetation.update_collision_around(vp.pos)


func save_campaign() -> void:
	if not Game.can_write_campaign_save() or player == null or Game.block_saves:
		return
	SaveService.save_campaign(SaveService.capture_state(self))


func save_checkpoint(kind: String) -> void:
	if not Game.can_write_campaign_save() or player == null or Game.block_saves:
		return
	SaveService.write_checkpoint(kind, SaveService.capture_state(self))


func load_campaign() -> bool:
	var data := SaveService.load_campaign()
	if data.is_empty():
		return false
	SaveService.apply_state(self, data)
	return true
