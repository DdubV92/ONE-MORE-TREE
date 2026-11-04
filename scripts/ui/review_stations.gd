class_name ReviewStations
extends RefCounted
## Phase 8 Preview Tour: eleven named, repeatable presentation stations.
## Every station is an isolated in-memory preview fixture (Preview never
## writes saves; the test session clock is separate from any campaign).
## Developer event forcing is labelled: it previews assets and contact; it
## does not prove natural director pacing, AI uncertainty or balance.

const STATIONS := [
	["1 Morning camper", "morning"],
	["2 Busy camp", "busy"],
	["3 Dense forest", "forest"],
	["4 River & pond", "river"],
	["5 Beach & dock noon", "beach"],
	["6 Sunset return", "sunset"],
	["7 Rainy night camper", "rain_night"],
	["8 TV quad/focus", "tv"],
	["9 Horror previews (forced)", "horror"],
	["10 HUNT fixture (forced)", "hunt"],
	["11 Cleared overlook", "cleared"],
]


## Phase 11 cast / dog / camper stations.
const STATIONS11 := [
	["Cast lineup (preview)", "p11_cast"],
	["Clean / pixel style", "p11_style"],
	["Work loop", "p11_work"],
	["Truck seats", "p11_truck"],
	["Dog close-up", "p11_dog"],
	["Camper +25 % tour", "p11_camper"],
	["Sit at the desk", "p11_desk"],
	["Cast on the cameras", "p11_feeds"],
	["Light: day/dusk/night", "p11_light"],
	["Hide & camper search", "p11_hide"],
]
static var _light_i := 0


static func go(hud: Node, which: String) -> String:
	var w: IslandWorld = Game.world_root
	var p: Player = Game.player
	if w == null or p == null:
		return ""
	var env: EnvironmentController = w.environment
	var wx: WeatherService = w.weather
	match which:
		"morning":
			w.teleport_to("camper")
			env.apply_named("dawn")
			wx.set_override("clear", true)
			if Game.dog:
				Game.dog.leave_refuge()
				Game.dog.go_home()
			return "Station 1 - morning camper: soft dawn light through the windows, Biscuit heading in through the flap. Look outside: the window keeps exterior silhouettes readable."
		"busy":
			busy_camp_fixture()
			w.teleport_to("camp")
			env.apply_named("day")
			wx.set_override("light_cloud", true)
			return "Station 2 - busy camp (preview crew: two starters + three hires arriving by boat). Watch varied builds and idles (timid glance, grip, listen), pickups, set-downs and the pit."
		"forest":
			w.teleport_to("forest")
			env.apply_named("day")
			wx.set_override("light_cloud", true)
			return "Station 3 - dense forest: dappled shade, shared wind in crowns and grass, footsteps on needles. Use Logging Test (Tour) for a real tree fall and impact."
		"river":
			w.teleport_to("river")
			env.apply_named("day")
			wx.set_override("clear", true)
			return "Station 4 - river: downstream flow, riffle whitewater only where the bed steepens, wet banks. Pond 2 in Locations for still water and reeds."
		"beach":
			w.teleport_to("beach")
			env.set_time_of_day(12.5)
			env.set_overcast(0.0)
			wx.set_override("clear", true)
			return "Station 5 - beach at noon: wave swash and wet sand band, caustics in the shallows (fade with depth/cloud), heat shimmer over dry sand only."
		"sunset":
			hud.call("_phase5_stop", "__p5_drive")
			env.apply_named("sunset")
			wx.set_override("light_cloud", true)
			return "Station 6 - sunset return: pickups in the bays at golden hour. Drive one; light and music ease into dusk."
		"rain_night":
			w.teleport_to("camper_night")
			env.apply_named("night")
			wx.set_override("light_rain", true)
			return "Station 7 - rainy night camper: roof patter inside, rain stops at the roof edge, wet ground under the lamps. The camper stays absolutely safe; weather never changes lamp safety."
		"tv":
			hud.call("_phase5_stop", "__p5_tv")
			wx.set_override("light_rain", true)
			var info: Dictionary = Game.tv.pipeline_info() if Game.tv else {}
			return "Station 8 - TV: quad %s @ %.0f Hz, focus %s @ %.0f Hz (profile %s). Remote feeds show the same rain at each camera. Click a tile to focus." % [str(info.get("quad_px", [])), float(info.get("quad_hz", 0.0)), str(info.get("focus_px", [])), float(info.get("focus_hz", 0.0)), str(info.get("profile", ""))]
		"horror":
			wx.set_override("overcast", true)
			hud.call("_phase6_stop", "__p6_next")
			return "Station 9 - FORCED ordinary event preview (dev): press again to step families. Previews assets/contact only, not natural pacing."
		"hunt":
			hud.call("_phase6_stop", "__p6_hunt")
			wx.set_override("overcast", true)
			return "Station 10 - FORCED hunt fixture (dev): doorway fold, listening stop (tags fall silent), search, hiding, loss of contact; Biscuit stays at the dock alcove."
		"p11_cast":
			Game.open_character_preview.call_deferred()
			return "Character Preview: the five employees (Marta, Dale, Priya, Tomas, Joan) and Biscuit. Use its buttons to cycle looks, walk, swing and orbit."
		"p11_style":
			var nxt := "pixel" if str(Settings.get_v("character_style")) == "clean" else "clean"
			Settings.set_v("character_style", nxt)
			return "Character style: %s (characters only; water, light and fog unchanged). Press again to compare. Strength in Settings." % nxt
		"p11_work":
			busy_camp_fixture()
			w.teleport_to("forest")
			return "Work loop: preview crew heading to the woods. Watch grips, swings, pickups (bend and lift), carrying and set-downs at the rack."
		"p11_truck":
			hud.call("_phase5_stop", "__p5_drive")
			return "Two pickups: get in (driver pose) and send a crew team from the Journal to see two different body sizes seated."
		"p11_dog":
			if Game.dog:
				p.teleport_feet(Game.dog.global_position + Vector3(1.6, 0, 1.2), atan2(1.6, 1.2))
			return "Biscuit up close: deep chest, shoulder blades, tucked waist, hocks, toes, collar and tag. Pet with %s." % Keys.label("interact")
		"p11_camper":
			w.teleport_to("camper_lounge")
			env.apply_named("day")
			return "Camper: %.2f x %.2f m interior = %.1f m^2 (was %.1f m^2, x%.2f). Bedroom, bathroom, kitchen and entrance unchanged; the lounge gained the desk." % [CampLayout.CAMPER_SIZE.x, CampLayout.CAMPER_SIZE.z, CampLayout.camper_usable_area(), CampLayout.CAMPER_V1_SIZE.x * CampLayout.CAMPER_V1_SIZE.z, CampLayout.camper_usable_area() / (CampLayout.CAMPER_V1_SIZE.x * CampLayout.CAMPER_V1_SIZE.z)]
		"p11_desk", "p11_feeds":
			if which == "p11_feeds":
				busy_camp_fixture()
			var seats := WorldGroups.of(w, "desk_seat")
			w.teleport_to("camper_lounge")
			if not seats.is_empty():
				p.sit_on_couch.call_deferred(seats[0])
			return "At the desk: Cameras app (click a feed to focus), Shop (real orders). %s glances right out of the window, %s looks back, %s stands." % [Keys.label("move_right"), Keys.label("move_left"), Keys.label("interact")]
		"p11_light":
			var presets := ["day", "sunset", "night_full", "night_new"]
			_light_i = (_light_i + 1) % presets.size()
			env.apply_named(presets[_light_i])
			return "Lighting: %s (press again to cycle sun / dusk / moonlit night / dark night)." % presets[_light_i]
		"p11_hide":
			hud.call("_phase6_stop", "__p6_hunt")
			return "FORCED hunt fixture (dev): hide under the camper bed or in the wardrobe; the Foreman searches by evidence and can look there."
		"cleared":
			var n := clear_near_camp(0.9)
			w.teleport_to("ridge")
			env.apply_named("day")
			wx.set_override("clear", true)
			return "Station 11 - cleared overlook (in memory): %d original trees removed around camp. No stale shadows, leaf audio or birds where trees are gone." % n
	return ""


## In-memory clearing fixture: removes the given fraction of original trees,
## nearest the camp first (the same order as the Phase 7 audit fixtures).
static func clear_near_camp(frac: float) -> int:
	var order: Array = []
	var o := World.camp_origin()
	for i in World.tree_count():
		if not World.removed_trees.has(int(World.trees.id[i])):
			order.append([Vector2(World.trees.x[i] - o.x, World.trees.z[i] - o.z).length(), int(World.trees.id[i])])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var target := int(round(frac * order.size()))
	var veg: VegetationSystem = Game.vegetation
	var hooked := veg != null and World.tree_removed.is_connected(veg._on_tree_removed)
	if hooked:
		World.tree_removed.disconnect(veg._on_tree_removed)
	var chunks := {}
	for k in target:
		var id := int(order[k][1])
		World.remove_tree(id)
		var idx: int = veg.tree_index_by_id.get(id, -1) if veg else -1
		if idx >= 0:
			chunks[int(World.trees.chunk[idx])] = true
	if veg:
		for c in chunks:
			veg._build_chunk(c)
		for c2 in veg._collision_cells.keys():
			(veg._collision_cells[c2] as Node).queue_free()
		veg._collision_cells.clear()
		veg._last_cell = Vector2i(999999, 999999)
	if hooked:
		World.tree_removed.connect(veg._on_tree_removed)
	return target


## Five workers (two starters + three demo hires by boat), preview only.
static func busy_camp_fixture() -> void:
	var cs: CampaignService = Game.campaign
	var crew: CrewService = Game.crew
	if cs == null or crew == null:
		return
	if not cs.active:
		cs.start_test_route(false)
	if crew.workers.size() >= 5:
		return
	cs.wallet.grant(800000, "test", "FIXTURE", "Preview crew cash")
	crew.when_ready(func() -> void:
		var sets := [["timid", "observant"], ["hard_working", "sociable"], ["skeptical", "stronger"]]
		for i in 3:
			crew._cand_counter += 1
			var cid := "P8-%d-%d" % [i, crew._cand_counter]
			crew.candidates.append({"cid": cid, "name": ["Ines Vance", "Kofi Brandt", "Wren Salo"][i], "traits": sets[i], "look_seed": 9100 + i * 131, "fee": crew.econ.hire_fee_cents, "wage": crew.econ.wage_cents})
			crew.hire(cid))
