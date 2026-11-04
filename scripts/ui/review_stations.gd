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
## Phase 12 dense island r2 stations (Preview from the title shows r2).
const STATIONS12 := [
	["Dense grove (eye level)", "p12_grove"],
	["Low-bough work approach", "p12_boughs"],
	["Undergrowth edge", "p12_thicket"],
	["Rocks & landforms", "p12_rocks"],
	["Rock hide (try it)", "p12_hide"],
	["Ridge sightline break", "p12_ridge"],
	["Over the woods", "p12_high"],
	["Truck bottleneck (bridge)", "p12_bridge"],
	["River & dock route", "p12_dock"],
	["Desk window view", "p12_window"],
	["All ten cameras", "p12_cams"],
	["Clearing 0/25/50/90/99.9/100 %", "p12_clear"],
	["Cover/nav overlay (dev)", "p12_overlay"],
	["Undergrowth density preset", "p12_density"],
	["Mocap: walk / run / sit", "p12_mocap"],
]
const STATIONS13 := [
	["Logging yard overview", "p13_yard"],
	["Fill the yard (stock fixture)", "p13_fill"],
	["Receiving cradle: full = refused", "p13_cradle_full"],
	["Handcart: load, push, unload", "p13_cart"],
	["Drag an oversized log", "p13_drag"],
	["Feed the fire from a deck", "p13_feed"],
	["Crew yard work", "p13_crew"],
	["Longer logs (plan v2) side by side", "p13_compare"],
]
static var _clear_i := 0
static var _density_i := 0
static var _overlay12: CoverOverlay
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
		"p12_grove", "p12_boughs", "p12_thicket", "p12_rocks", "p12_ridge", "p12_high":
			if World.island_revision != "r2":
				return "These stops show island r2 (new campaigns). Start Preview from the title screen."
			if not Viewpoints.all().has(which):
				return "No such feature near camp."
			w.teleport_to(which)
			env.apply_named("day")
			wx.set_override("light_cloud", true)
			return "%s. Native trees: %d (exactly the contract's), undergrowth and rock are permanent, not contract targets." % [str(Viewpoints.all()[which].label), World.native_total()]
		"p12_hide":
			if not Viewpoints.all().has("p12_hide"):
				return "No rock hide near camp on this island."
			w.teleport_to("p12_hide")
			if Game.hunt:
				Game.hunt.hunt_preview = true     # lets you use hides without a hunt
			return "Rock recess: walk into the opening and press %s. Concealment is geometric: rock blocks the hunter's view from the sides and back, the opening does not. One way out - a deliberate dead end." % Keys.label("interact")
		"p12_bridge":
			hud.call("_phase7_stop", "__p7_bridge_e")
			return "Truck bottleneck: the trail bridge. Trucks, logs and the crew share it (yield/queue); undergrowth keeps 3.5 m off truck trails."
		"p12_dock":
			w.teleport_to("dock")
			return "River mouth and dock route: the dog's refuge path and the extraction dock are unchanged; no landform edits within 30 m of water."
		"p12_window":
			w.teleport_to("desk_window")
			return "From the desk: the right-hand window keeps its view of the treeline and the approach beyond it."
		"p12_cams":
			hud.call("_phase5_stop", "__p5_tv")
			return "Ten fixed cameras (four live tiles at a time). Lens corridors were kept free of trees and tall shrubs by the planner."
		"p12_clear":
			var fracs := [0.0, 0.25, 0.5, 0.9, 0.999, 1.0]
			_clear_i = (_clear_i + 1) % fracs.size()
			for id in World.removed_trees.keys():
				if World.is_native(int(id)):
					World.restore_tree(int(id))
			var n := clear_near_camp(fracs[_clear_i]) if fracs[_clear_i] > 0.0 else 0
			w.teleport_to("p12_high" if Viewpoints.all().has("p12_high") else "ridge")
			return "Clearing fixture %.1f %% (%d native trees removed, in memory). Rocks, landforms, thickets and structures remain as persistent cover. Press again for the next level." % [fracs[_clear_i] * 100.0, n]
		"p12_overlay":
			if _overlay12 == null or not is_instance_valid(_overlay12):
				_overlay12 = CoverOverlay.new()
				w.add_child(_overlay12)
				return "Cover/nav overlay: all layers. Press again to cycle soft / hard / hides / nav / support, then off."
			var lay := _overlay12.next_layer()
			if lay == "all":
				_overlay12.queue_free()
				_overlay12 = null
				return "Overlay off."
			return "Overlay layer: %s (green soft concealment, grey hard cover, magenta hide / cyan exits / yellow search approach, blue walkable / orange drivable, red support problems)." % lay
		"p12_density":
			var ds := [1.0, 0.75, 0.45]
			_density_i = (_density_i + 1) % ds.size()
			if w.undergrowth:
				w.undergrowth.set_density(ds[_density_i])
			return "Undergrowth density %.0f %%: only scattered decorative plants thin out; thicket members (the soft cover the hunter uses) always stay." % (ds[_density_i] * 100.0)
		"p12_mocap":
			busy_camp_fixture()
			w.teleport_to("camp")
			return "Crew motion: walk and run are the owner's Mixamo clips retargeted to each body (feet re-planted per leg length); sitting, couch, driving and bed use the captured seated/lying clips."
		"p13_yard":
			w.teleport_to("p13_yard")
			env.apply_named("day")
			wx.set_override("clear", true)
			return yard_summary()
		"p13_fill":
			var n := yard_fixture(0.8, 0)
			w.teleport_to("p13_decks")
			env.apply_named("day")
			return "Stock fixture (in memory): %d paid logs stacked on the decks by real diameter and length. %s" % [n, yard_summary()]
		"p13_cradle_full":
			yard_fixture(0.0, CampLayout.CRADLE_SLOTS)
			_hand_player(1, false)
			w.teleport_to("p13_cradle")
			return "The cradle is full (%d/%d) and you are holding an unpaid log. Try %s at the cradle: it is refused and NOT paid until a slot frees up. Deliver straight onto a deck instead, or move cradle logs to a deck first." % [Game.yard.cradle.size(), CampLayout.CRADLE_SLOTS, Keys.label("interact")]
		"p13_cart":
			yard_fixture(0.0, 0)
			_hand_player(3, false)
			w.teleport_to("p13_cart")
			return "You hold %d unpaid logs. %s on the cart loads them (max %d logs / %.1f tree-eq). %s again grabs the handle; push it to the cradle and %s to unload (only what fits is accepted and paid)." % [Game.timber.carried.size(), Keys.label("interact"), TimberCart.MAX_PIECES, TimberCart.BUDGET_MTE / 1000.0, Keys.label("interact"), Keys.label("interact")]
		"p13_drag":
			yard_fixture(0.0, 0)
			var ok := _hand_player(1, true)
			w.teleport_to("p13_cradle")
			if not ok:
				return "No oversized log found."
			return "You are dragging a log heavier than one hand load: slow walk, no jumping. Bring it to the cradle (%s) or load it on the cart." % Keys.label("interact")
		"p13_feed":
			yard_fixture(0.5, 0)
			w.teleport_to("p13_decks")
			return "The fire only burns from its loading pile (%d/%d). Take a log from a deck (%s) and carry it to the fire pit (%s there) - the pile is east of the pit." % [Game.timber.queue.size(), CampLayout.PIT_QUEUE_CAP, Keys.label("interact"), Keys.label("interact")]
		"p13_crew":
			yard_fixture(0.3, 8)
			busy_camp_fixture()
			if Game.crew:
				for wk in Game.crew.workers.values():
					(wk as Worker).emp["job"] = "yard"
			w.teleport_to("p13_yard")
			return "Crew on yard work (Journal -> Crew -> Yard): they move cradle logs onto decks and keep the fire pile topped up. Unassigned crew help automatically when the cradle is nearly full or the fire runs low."
		"p13_compare":
			w.teleport_to("p13_cradle")
			return compare_plans()
		"cleared":
			var n := clear_near_camp(0.9)
			w.teleport_to("ridge")
			env.apply_named("day")
			wx.set_override("clear", true)
			return "Station 11 - cleared overlook (in memory): %d original trees removed around camp. No stale shadows, leaf audio or birds where trees are gone." % n
	return ""


## Phase 13: one-line yard status for the tour.
static func yard_summary() -> String:
	var y: YardService = Game.yard
	if y == null:
		return "No yard on this island."
	var deck_n := 0
	for d in y.decks:
		deck_n += (d as Array).size()
	return "Yard: cradle %d/%d, decks %d logs (%.2f tree-eq paid stock, room for about %d more), fire pile %d/%d." % [y.cradle.size(), CampLayout.CRADLE_SLOTS, deck_n, y.stock_mte() / 1000.0, y.deck_free_estimate(), Game.timber.queue.size(), CampLayout.PIT_QUEUE_CAP]


## In-memory yard stock (Preview only): accepted logs from real trees on the
## decks (fraction of their estimated room) and `cradle_n` in the cradle.
static func yard_fixture(deck_frac: float, cradle_n: int) -> int:
	var t: TimberService = Game.timber
	var y: YardService = Game.yard
	if t == null or y == null or not Game.is_preview():
		return 0
	t.clear_all()
	var want := int(y.deck_free_estimate() * deck_frac)
	var placed := 0
	var idx := 0
	var cradle_at := CampLayout.world(CampLayout.DELIVERY_RACK_POS)
	while (placed < want or y.cradle.size() < cradle_n) and idx < World.tree_count():
		var id: int = World.trees.id[idx]
		idx += 37
		if t.records.has(id):
			continue
		t.records[id] = t._build_record(id, idx - 37, {})
		var sids: Array = []
		for sg in t.records[id].segments:
			t.carried.append(str(sg.sid))
			t.claims[str(sg.sid)] = "player"
			sg.state = TimberService.Seg.CARRIED
			sids.append(str(sg.sid))
		for sid in sids:
			if y.cradle.size() < cradle_n:
				t.accept([sid], "fixture", cradle_at)
			elif placed < want:
				var dk := y.nearest_deck(y.deck_world(placed % y.decks.size()), sid)
				if dk >= 0 and not t.accept([sid], "fixture", y.deck_world(dk)).is_empty():
					placed += 1
		# Pieces not used stay out of the world (fixture only).
		for sid in t.carried.duplicate():
			t.carried.erase(sid)
			t.claims.erase(sid)
			t.segment(str(sid)).state = TimberService.Seg.CONSUMED
	t.carried_changed.emit()
	y.refresh()
	return placed


## Puts `n` unpaid logs from a fresh tree in the player's hands (Preview).
## `oversized`: one log heavier than a hand load (dragged).
static func _hand_player(n: int, oversized: bool) -> bool:
	var t: TimberService = Game.timber
	if t == null:
		return false
	for j in range(3, World.tree_count(), 53):
		var id: int = World.trees.id[j]
		if t.records.has(id):
			continue
		var part := TimberService.partition(j, TimberService.current_plan())
		if not oversized and float(part.d0) > 0.42:
			continue                       # hand loads from moderate trees
		var picks: Array[int] = []
		for k in (part.mte as PackedInt32Array).size():
			var m := int(part.mte[k])
			if oversized and m > TimberService.HAND_BUDGET_MTE + 2 and m <= TimberService.HAND_BUDGET_MTE * 2:
				picks = [k]
				break
			if not oversized and m <= 300 and picks.size() < n:
				picks.append(k)
		if picks.is_empty() or (not oversized and picks.size() < n):
			continue
		t.records[id] = t._build_record(id, j, {})
		for sg in t.records[id].segments:
			sg.state = TimberService.Seg.CONSUMED if not int(sg.k) in picks else TimberService.Seg.CARRIED
			if int(sg.k) in picks:
				t.carried.append(str(sg.sid))
				t.claims[str(sg.sid)] = "player"
		t.carried_changed.emit()
		return true
	return false


## Plan v1 vs v2 piece counts and lengths over a sample of the island.
static func compare_plans() -> String:
	var n1 := 0
	var n2 := 0
	var l1 := 0.0
	var l2 := 0.0
	var trees := 0
	for i in range(0, World.tree_count(), 25):
		var a := TimberService.partition(i, TimberService.PLAN_V1)
		var b := TimberService.partition(i, TimberService.PLAN_V2)
		n1 += int(a.n)
		n2 += int(b.n)
		l1 += float(a.merch_top) - float(a.cut_h)
		l2 += float(b.merch_top) - float(b.cut_h)
		trees += 1
	return "Plan v2 (new campaigns): %.2f logs per tree, mean %.2f m (old plan v1: %.2f logs, %.2f m). Same $100 and 1 tree-eq per tree; heavier logs are dragged or carted." % [float(n2) / trees, l2 / maxf(n2, 1), float(n1) / trees, l1 / maxf(n1, 1)]


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
