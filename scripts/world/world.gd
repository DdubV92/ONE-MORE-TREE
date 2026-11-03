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
var ground_cover: Node3D
var environment: EnvironmentController
var camp: Node3D
var audio: Node3D
var safety: Node
var player: Node3D
var hud: CanvasLayer
var build_ms := {}


func _ready() -> void:
	Game.world_root = self
	var t0 := Time.get_ticks_msec()
	World.ensure_loaded()
	build_ms["world_data"] = Time.get_ticks_msec() - t0
	environment = _timed("environment", func() -> Node: var e := EnvironmentController.new(); e.name = "Environment"; add_child(e); e.build(); return e)
	Game.environment = environment
	terrain = _timed("terrain", func() -> Node: var t := TerrainSystem.new(); t.name = "Terrain"; add_child(t); t.build(); return t)
	water = _timed("water", func() -> Node: var w := WaterSystem.new(); w.name = "Water"; add_child(w); w.build(_ocean_grid()); return w)
	Game.water = water
	_timed("sand_haze", func() -> Node: var h := SandHaze.new(); h.name = "SandHaze"; add_child(h); h.build(); return h)
	_timed("bridges", func() -> Node: var b := BridgeBuilder.new(); b.name = "Bridges"; add_child(b); b.build(); return b)
	vegetation = _timed("vegetation", func() -> Node: var v := VegetationSystem.new(); v.name = "Vegetation"; add_child(v); v.build(); return v)
	Game.vegetation = vegetation
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
		var dog := CampDog.new()
		dog.name = "Dog"
		add_child(dog)
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
	_place_player()
	build_ms["total"] = Time.get_ticks_msec() - t0
	print("World built: ", build_ms)
	ready_to_play.emit()


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
	elif Game.mode == Game.Mode.CAMPAIGN and load_campaign():
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
	if not Game.can_write_campaign_save() or player == null:
		return
	SaveService.save_campaign(SaveService.capture_state(self))


func load_campaign() -> bool:
	var data := SaveService.load_campaign()
	if data.is_empty():
		return false
	SaveService.apply_state(self, data)
	return true
