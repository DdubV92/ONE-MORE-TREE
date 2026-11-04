extends Node
## Autoload "Game": session mode, shared world time, scene switching and
## references to the active world's services.
##
## Modes:
##  CAMPAIGN - normal play; may save (Phase 0: free exploration only).
##  PREVIEW  - Preview Tour / review helpers. Never writes campaign saves,
##             never advances wages, damages trees or alters horror exposure.

enum Mode { MENU, CAMPAIGN, PREVIEW }

const SCENE_MENU := "res://scenes/main.tscn"
const SCENE_WORLD := "res://scenes/world.tscn"
const SCENE_CHARACTERS := "res://scenes/character_preview.tscn"

var mode: Mode = Mode.MENU
## Monotonic shader/simulation time in seconds (pauses with the game).
var world_time := 0.0
var time_scale := 1.0

# Services registered by the active world scene (null outside the world).
var world_root: Node3D
var water: WaterSystem
var environment: Node
var weather: Node
var safety: Node
var player: Node3D
var vegetation: Node
var cover: CoverService              # Phase 12 (island r2 only)
var trees: TreeService
var timber: TimberService
var yard: YardService                # Phase 13 logging yard
var cart: TimberCart                 # Phase 13 early handcart
var campaign: CampaignService
var crew: CrewService
var vehicles: VehicleService
var tv: CameraWall
var desk: Node                      # Phase 11 DeskComputer
var tv_set: Node                    # Phase 11 entertainment TV
var dog: CampDog
var director: TerrorDirector
var threat: NightThreat
var dog_rescue: DogRescue
var hunt: HuntService
var end_screen: EndScreen
## Current objective line shown by the HUD ("" = none).
var objective := ""
var arcade: ArcadeService
var dock_site: DockSite
var comfort: Node
var campaign_ui: CampaignUI
var preview_variant := ""          # Phase 10: manifest variant for Preview ("" = full)
var new_game := false              # start a fresh contract in SaveService.slot
## Set while a death/catch screen is up: nothing may save that state.
var block_saves := false

var pending_teleport := ""
var startup_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	startup_ms = Time.get_ticks_msec()


func _process(delta: float) -> void:
	if not get_tree().paused:
		world_time += delta * time_scale
	RenderingServer.global_shader_parameter_set("world_time", world_time)


func is_preview() -> bool:
	return mode == Mode.PREVIEW


func can_write_campaign_save() -> bool:
	return mode == Mode.CAMPAIGN


func start_campaign() -> void:
	mode = Mode.CAMPAIGN
	_change(SCENE_WORLD)


func start_preview(location: String = "camp") -> void:
	mode = Mode.PREVIEW
	# Phase 12: the Preview from the title shows the new-campaign island.
	if preview_variant == "":
		preview_variant = "island_r2"
	pending_teleport = location
	_change(SCENE_WORLD)


func open_character_preview() -> void:
	mode = Mode.PREVIEW
	_change(SCENE_CHARACTERS)


func return_to_menu() -> void:
	if mode == Mode.CAMPAIGN and world_root and world_root.has_method("save_campaign"):
		world_root.save_campaign()
	mode = Mode.MENU
	_change(SCENE_MENU)


func _change(path: String) -> void:
	get_tree().paused = false
	block_saves = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world_root = null
	water = null
	environment = null
	safety = null
	player = null
	vegetation = null
	cover = null
	yard = null
	cart = null
	trees = null
	timber = null
	campaign = null
	crew = null
	vehicles = null
	tv = null
	dog = null
	director = null
	threat = null
	dog_rescue = null
	hunt = null
	end_screen = null
	objective = ""
	arcade = null
	dock_site = null
	comfort = null
	campaign_ui = null
	get_tree().change_scene_to_file(path)
