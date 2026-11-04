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
