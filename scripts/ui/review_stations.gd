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
const STATIONS14 := [
	["Axe comparison (1 / 2 / 3)", "p14_axes"],
	["Chainsaw: try it (4, R)", "p14_saw"],
	["Crew in gear", "p14_gear"],
	["Supplier order -> parcel", "p14_supplier"],
	["Coordinated felling lanes", "p14_lanes"],
	["Two-person carry", "p14_team"],
	["Gear & tool numbers", "p14_numbers"],
]
const STATIONS15 := [
	["1 Distance ladder", "p15_distance"], ["2 Rotation & elevation", "p15_orbit"],
	["3 Camper door closed/open", "p15_door"], ["4 Indoor + outdoor at once", "p15_in_out"],
	["5 Work material sequence", "p15_work"], ["6 Chainsaw states", "p15_saw"],
	["7 Truck & dog", "p15_truck_dog"], ["8 Ambience in place", "p15_ambience"],
	["9 Desk relay (how to)", "p15_relay"], ["10 Replay last 20 s", "p15_replay"],
	["11 Quiet night event", "p15_night"], ["12 Worst overlap", "p15_worst"],
	["Active voices (dev)", "p15_debug"],
]
const STATIONS16 := [
	["1 Crew progress (roster)", "p16_roster"], ["2 Shared tree, split merit", "p16_shared"],
	["3 Merit & level numbers", "p16_numbers"], ["4 Daily review (read-only)", "p16_review"],
	["5 Rest: early night", "p16_rest_early"], ["6 Rest: very late night", "p16_rest_late"],
	["7 Rest: exhausted day", "p16_rest_low"], ["8 Hunt rest (how it works)", "p16_hunt_rest"],
]
const STATIONS17 := [
	["1 Start a crew conversation", "p17_talk"], ["2 Conversation inspector", "p17_inspect"],
	["3 Feed: publish next day", "p17_next_day"], ["4 Feed counts & digest", "p17_counts"],
	["5 Window-warning check", "p17_window"], ["6 How to read the feed", "p17_howto"],
]
const STATIONS18 := [
	["1 Marta", "p18_EMP-01"], ["2 Dale", "p18_EMP-02"], ["3 Priya", "p18_EMP-03"],
	["4 Tomas", "p18_EMP-04"], ["5 Joan", "p18_EMP-05"], ["6 Two-person exchange", "p18_exchange"],
	["7 Distance ladder", "p18_distance"], ["8 Five-voice lineup", "p18_lineup"], ["9 Voice coverage", "p18_counts"],
]
const STATIONS19 := [
	["1 Survey ship (beach)", "p19_ship"], ["2 Slow pass (yard)", "p19_yard"], ["3 Helicopter launch", "p19_launch"],
	["4 Helicopter over camp", "p19_heli"], ["5 Offshore coverage", "p19_counts"], ["6 Thicket hide (try it)", "p19_thicket"],
	["7 Field shed", "p19_shed"], ["8 Dock gear chest", "p19_chest"], ["9 Cover audit", "p19_audit"],
	["10 Midday gathering", "p19_break"], ["11 Roles & transport", "p19_roles"],
]
const STATIONS20 := [
	["1 Night recording (random)", "p20_rec"], ["2 Recording: the gate", "p20_rec01"], ["3 Recording: behind the crest", "p20_rec10"],
	["4 Sleep interruption", "p20_sleep"], ["5 The door (major)", "p20_si01"], ["6 Release checklist", "p20_rc"],
]
## Phase 21: payroll and pay morale (owner request).
const STATIONS21 := [
	["1 Payroll app (camper desk)", "p21_app"], ["2 Worker about to quit", "p21_verge"],
	["3 Raise request", "p21_request"], ["4 Simulate a pay night", "p21_night"],
]
static var _p20_i := 0
static var _feed_day := 0
static var _clear_i := 0
static var _density_i := 0
static var _overlay12: CoverOverlay
static var _light_i := 0


static func _p19_offshore(w: IslandWorld, p: Player, which: String) -> String:
	var off: OffshoreSurvey = Game.offshore
	if off == null:
		return ""
	off.stop_preview()
	off.preview_visit(3)
	off.visit.state = "lap"
	off.visit.seg_t = 0.0
	match which:
		"p19_ship", "p19_yard":
			off.visit.theta = off.theta0
			off.visit.lap = 0.0
		"p19_launch":
			off.visit.theta = off.theta_camp
			off.visit.lap = absf(off.theta_camp - off.theta0)
			off.visit.visible_s = 999.0
		"p19_heli":
			off.visit.theta = off.theta_camp + off.dir * 0.3
			off.visit.lap = absf(off.theta_camp - off.theta0) + 0.3
			off.visit.launched = true
			off._place_ship()
			off.heli.wps = off.leg_points("camp")
			off.heli.wp_i = 1
			off.heli.set_state("fly")
			off.heli.rotor = 1.0
			off.heli.global_position = World.camp_origin() + Vector3(260, 70, 300)
	off._place_ship()
	var sp := off.ship_position()
	var stand: Vector3 = Game.crew.dock_shore if which != "p19_yard" and Game.crew else CampLayout.world(CampLayout.DELIVERY_RACK_POS + Vector3(0, 0, 6))
	if which == "p19_heli":
		stand = CampLayout.world(Vector3(0, 0, 4))
		p.teleport(stand + Vector3(0, 1.65, 0), World.camp_origin() + Vector3(120, 60, 160))
	else:
		p.teleport(stand + Vector3(0, 1.65, 0), sp + Vector3(0, 10, 0))
	return {"p19_ship": "The survey vessel on the camp-facing arc (about %d m out). It slows to half speed past camp, makes one full lap of the island and leaves. No markings; no contact; nothing to do." % int(stand.distance_to(sp)),
		"p19_yard": "The same silhouette from the yard at eye height (existing fog and weather).",
		"p19_launch": "The helicopter spools up and lifts off the moving stern pad, then surveys camp and the island.",
		"p19_heli": "The camp pass: rotor heard first, then seen over the yard. Workers who see it call it out (look gesture; subtitles carry a direction)."}[which]


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
		"p14_axes", "p14_saw":
			var i := _tree_near_camp(40.0)
			if i < 0:
				return "No tree near camp."
			var stand := PlacementValidator.cut_stands(i)[0]
			var base := World.tree_position(i)
			w.vegetation.update_collision_around(base)
			p.teleport(stand + Vector3(0, 1.65, 0), base + Vector3(0, 1.0, 0))
			env.apply_named("day")
			if which == "p14_saw":
				p.axe.equip_saw()
				return "Chainsaw (preview). %s starts the engine (or just squeeze %s), hold %s to rev - it only cuts while the moving chain is in the wood. %s stops it. Hiding, sitting, driving or picking up logs stops it at once. Numbers: %s" % [Keys.label("saw_engine"), Keys.label("attack"), Keys.label("attack"), Keys.label("saw_engine"), " ".join(ToolEffects.describe(ToolEffects.breakdown({"tool": "chainsaw"})))]
			p.axe.equip("small")
			var lines := PackedStringArray()
			for t in ["small", "medium", "large"]:
				lines.append(ToolEffects.describe(ToolEffects.breakdown({"tool": "axe", "tier": t}))[0])
			return "Same tree, same swing rhythm: press %s / %s / %s to switch. Bigger axes bite deeper per hit, they don't swing faster.\n%s" % [Keys.label("tool_small"), Keys.label("tool_medium"), Keys.label("tool_large"), "\n".join(lines)]
		"p14_gear":
			busy_camp_fixture()
			gear_fixture()
			w.teleport_to("camp")
			return "Crew gear: boots, gloves and helmets fitted to each body (tiers 1-3, one per slot). Talk to a worker or open the tool rack (E) to see exactly what each item does."
		"p14_supplier":
			return supplier_fixture(w)
		"p14_lanes":
			busy_camp_fixture()
			w.teleport_to("ridge" if not Viewpoints.all().has("p12_high") else "p12_high")
			return "Each tree being felled reserves only its fall lane (trunk length + crown width along the planned direction). Others keep working outside it, routes bend around it, and anyone inside steps out at the warning crack."
		"p14_team":
			return team_fixture(w)
		"p14_numbers":
			var out := PackedStringArray()
			for k in [{"tool": "axe", "tier": "small"}, {"tool": "axe", "tier": "large", "helmet": "t3", "gloves": "t3"}, {"tool": "axe", "tier": "large", "hard_working": true}, {"tool": "chainsaw"}, {"tool": "chainsaw", "gloves": "t3"}]:
				var b := ToolEffects.breakdown(k)
				out.append("%s: %.2f work/s (%.2fx hatchet)" % [str(k), float(b.work_per_second), float(b.vs_hatchet)])
			return "\n".join(out)
		"p15_debug":
			return Audition.debug_list()
		"p16_roster", "p16_shared", "p16_review":
			var cs16: CampaignService = Game.campaign
			if Game.crew == null or Game.crew.workers.is_empty():
				cs16.start_test_route(true, true)
				return "Crew starting (they arrive on the boat). Pick this stop again in a moment."
			if which == "p16_shared":
				return shared_tree_fixture(w)
			if which == "p16_review":
				var out16 := PackedStringArray()
				for e in cs16.payroll.employees:
					if str(e.status) == Payroll.ACTIVE:
						var rv := Game.crew.review(str(e.id), cs16.clock.day)
						out16.append("%s L%d (%d merit, +%d today) · %s · %s, %s%s" % [rv.name, int(rv.level), int(round(float(rv.merit))), int(round(float(rv.merit_today))), str(rv.time_split), rv.ethic, rv.reliability, ("\n   " + str(rv.tip)) if str(rv.tip) != "" else ""])
				return "Today's crew review (opening it again changes nothing):\n" + "\n".join(out16)
			if Game.campaign_ui:
				Game.campaign_ui.toggle_journal(0)
			return "Journal -> Crew: level, merit to the next level, each skill's real effect, today's time split with causes, and 'Thank them' buttons for specific work."
		"p19_ship", "p19_yard", "p19_launch", "p19_heli":
			return _p19_offshore(w, p, which)
		"p19_counts":
			var off: OffshoreSurvey = Game.offshore
			var bank := CrewBank.get_bank()
			var n := 0
			var maps := 0
			var rec := 0
			for id in bank.lines:
				if str(bank.lines[id].get("cat", "")) != "offshore":
					continue
				n += 1
				for prof in ["marta", "dale", "priya", "tomas", "joan", "crew_m", "crew_f"]:
					if not VoiceBank.info(prof, id).is_empty():
						maps += 1
						if VoiceBank.has(prof, id):
							rec += 1
			var rc := off.route_clearance() if off else {}
			return "Offshore survey: %d authored crew lines (6 x 20), %d eligible line/voice mappings, %d recordings available (subtitles cover any gap). Lap %.0f s on a %.0f m circle (min depth %.1f m, dock routes clear: %s). Visits every %d days from day %d; none after the contract." % [n, maps, rec, off.lap_seconds() if off else 0.0, off.R if off else 0.0, float(rc.get("min_depth", 0.0)), str(rc.get("routes_ok", false)), int(off.sc("interval_days", 3)) if off else 3, int(off.sc("first_day", 3)) if off else 3]
		"p19_thicket", "p19_shed", "p19_chest":
			var sc: SurvivalCover = Game.survival_cover
			if sc == null or not sc.built:
				return "Survival cover exists on island r2 only."
			Game.hunt.hunt_preview = true
			var kind: String = {"p19_thicket": "thicket", "p19_shed": "shed", "p19_chest": "dock_store"}[which]
			for h in sc.hides:
				if h.kind == kind:
					var stand: Vector3 = h.get_meta("door_out", h.exits[0] if not h.exits.is_empty() else h.approach)
					p.teleport(stand + Vector3(0, 1.65, 0), h.global_position + Vector3(0, 0.6, 0))
					return {"thicket": "A dense persistent thicket: crouch inside (interact). The brush hides you from farther than 4 m if you were not seen going in; up close, or seen entering, it does not. %d ways out." % h.exits.size(),
						"shed": "A field work shed: hide behind the bench. The door creaks (a real sound); the back hatch is a second way out.",
						"dock_store": "The dock gear chest: lie inside. The lid knocks when you climb in. Biscuit is never a target."}[kind]
			return "None of that kind on this island."
		"p19_audit":
			var sc2: SurvivalCover = Game.survival_cover
			if sc2 == null:
				return "Survival cover exists on island r2 only."
			var au := sc2.audit()
			var lines := PackedStringArray()
			for k in au.regions:
				var r: Dictionary = au.regions[k]
				lines.append("%s: nearest hide median %d m (90%% within %d m); hide within 30 m at %d%% of points; 2+ within 150 m at %d%%" % [k, int(r.median_m), int(r.p90_m), int(float(r.hide_within_30m) * 100), int(float(r.two_or_more_within_150m) * 100)])
			return "Hides: %d (%s; largest kind %d%%).\n%s\n%s" % [int(au.hides), str(au.kinds), int(float(au.largest_kind_share) * 100), "\n".join(lines.slice(0, 8)), au.cleared_land]
		"p19_break", "p19_roles":
			var cs19: CampaignService = Game.campaign
			if Game.crew == null or Game.crew.workers.size() < 2:
				cs19.start_test_route(true, true)
				return "Crew starting (they arrive on the boat). Pick this stop again in a moment."
			var rt: CampRoutine = Game.crew.routine
			rt.plan_day(cs19.clock.day)
			if which == "p19_roles":
				var rl := PackedStringArray()
				for eid in rt.roles:
					rl.append("%s: %s" % [str(Game.crew.emp(eid).get("name", eid)).split(" ")[0], rt.roles[eid]])
				return "Today's roles (from kit, traits and the backlog; your job assignments win): %s.\nTransport: %s (%s)." % [", ".join(rl), str(rt.plan.get("mode", "")), str(rt.plan.get("why", ""))]
			w.teleport_to("camp")
			rt.start_break(cs19.clock.day)
			return "Midday gathering: workers near camp walk to the fire seats and talk; far crews break where they are; someone calls Biscuit over. Break time counts as a break, not idleness."
		"p20_rec", "p20_rec01", "p20_rec10":
			var nr: NightRecorder = Game.night_recorder
			var cs20: CampaignService = Game.campaign
			if nr == null or cs20 == null:
				return ""
			var sid := which.trim_prefix("p20_") if which != "p20_rec" else str(nr.scenarios[_p20_i % nr.scenarios.size()].id)
			_p20_i += 1
			var clip := nr.on_night(900 + _p20_i, sid)
			if clip.is_empty():
				return "Preview: scenario %s could not be staged honestly here right now (prerequisites: %s). Nothing was faked." % [sid, str(nr.by_id[sid].requires)]
			if Game.desk:
				Game.desk.flag_recording(str(clip.id))
			return "Preview recording staged from the live world: %s on %s (%s, %s). Sit at the camper desk -> Recordings to watch the reconstruction. (Preview: never saved.)" % [clip.title, clip.camera, clip.clock, clip.bookmark]
		"p20_sleep", "p20_si01":
			var si20: SleepInterrupts = Game.sleep_interrupts
			if si20 == null:
				return ""
			w.teleport_to("camper")
			var pick: String = "si01" if which == "p20_si01" else str(si20.sequences[_p20_i % si20.sequences.size()].id)
			_p20_i += 1
			si20.state = "idle"
			si20.start(pick, Game.campaign.clock.day if Game.campaign else 1)
			return "Preview interruption %s: %s. Watch the states: settling -> interrupted -> resolving -> sleep available. You cannot be hurt in the camper; nothing forces you out." % [pick, str(si20.by_id[pick].title)]
		"p21_app", "p21_verge", "p21_request", "p21_night":
			var cs21: CampaignService = Game.campaign
			if cs21 == null or cs21.pay == null:
				return ""
			if Game.crew == null or Game.crew.workers.size() < 2:
				cs21.start_test_route(true, true)
				cs21.wallet.grant(300000, "test", "P21", "preview cash")
			match which:
				"p21_app":
					w.teleport_to("camper")
					return "Payroll: sit at the camper desk (the computer) -> Payroll. One row per worker: pay mood, useful work and work done today, its value, rate, bonus, performance %, tonight's pay. Click a row for details and controls. (Preview: never saved.)"
				"p21_verge":
					var r21 := cs21.pay.rec("EMP-04")
					r21.sat = 0.22
					r21.min_days = 4
					r21.verge_day = cs21.clock.day
					return "Preview: %s has had four nights at the bare minimum and is on the verge of quitting (fair pay in their eyes about $%s). Raise them in Payroll, or simulate a night to see what happens. (Preview: never saved.)" % [str(cs21.payroll.employee("EMP-04").get("name", "EMP-04")), Money.format_cents(cs21.pay.expected_band("EMP-04")[1])]
				"p21_request":
					var r2 := cs21.pay.rec("EMP-02")
					r2.assertive = 1.0
					var lvl := int(r2.level) + 1
					cs21.pay.on_advanced("EMP-02", "career", lvl)
					var q21 := cs21.pay.pending_request("EMP-02")
					if q21.is_empty():
						return "Preview: no raise request - their pay already matches what they feel is fair."
					return "Preview: %s reached level %d and asks for +$%s a day, or a $%s bonus today. Answer it in Payroll. (Preview: never saved.)" % [str(cs21.payroll.employee("EMP-02").get("name", "EMP-02")), lvl, Money.format_cents(int(q21.raise)), Money.format_cents(int(q21.bonus))]
				"p21_night":
					cs21.clock.restore({"day": cs21.clock.day, "t": WorkdayClock.NIGHT_AT + 1.0, "running": true})
					var rr21 := cs21.sleep()
					var pn21: Dictionary = (rr21.get("report", {}) as Dictionary).get("pay", {})
					if pn21.is_empty():
						return "Preview: the night could not be settled: %s" % str(rr21.get("reason", ""))
					var moods := PackedStringArray()
					for l21 in pn21.lines:
						moods.append("%s %s" % [str(l21.name).split(" ")[0], ("QUIT" if bool(l21.quit) else str(l21.status).to_lower())])
					return "Preview night settled: wages $%s. %s. Full report: Payroll -> Last night. (Preview: never saved.)" % [Money.format_cents(int(pn21.totals.total)), ", ".join(moods)]
			return ""
		"p20_rc":
			return "Release checklist: docs/PHASE20_RC_REPORT.md (pass / fail / blocked / unrun per requirement). Content: %d crew lines, %d recording scenarios, %d sleep interruptions, %d offshore lines, %d voice clips indexed." % [CrewBank.get_bank().lines.size(), Game.night_recorder.scenarios.size() if Game.night_recorder else 0, Game.sleep_interrupts.sequences.size() if Game.sleep_interrupts else 0, (CrewBank.get_bank().offshore.values() as Array).reduce(func(a: int, b: Array) -> int: return a + b.size(), 0), VoiceBank.count()]
		"p18_counts":
			return "Voice bank: %d clips for %d authored lines (all required line/profile mappings). Generated offline with eSpeak NG (original synthetic voices; no recorded or cloned person). Runtime loads clips on demand; missing clips fall back to subtitles. The internet stays text only." % [VoiceBank.count(), CrewBank.get_bank().lines.size()]
		"p18_EMP-01", "p18_EMP-02", "p18_EMP-03", "p18_EMP-04", "p18_EMP-05", "p18_exchange", "p18_distance", "p18_lineup":
			w.teleport_to("camp")
			return VoiceAudition.start(w, which.trim_prefix("p18_"))
		"p17_talk", "p17_inspect":
			var cs17: CampaignService = Game.campaign
			if Game.crew == null or Game.crew.workers.size() < 2:
				cs17.start_test_route(true, true)
				return "Crew starting (they arrive on the boat). Pick this stop again in a moment."
			var ws17: Array = Game.crew.workers.values()
			ws17.sort_custom(func(a: Worker, b: Worker) -> bool: return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
			if which == "p17_inspect":
				return Game.crew.talk.explain(ws17[0])
			var a17: Worker = ws17[0]
			var b17: Worker = ws17[1]
			var fwd := -p.global_basis.z
			fwd.y = 0.0
			var spot := p.global_position + fwd.normalized() * 4.0
			spot.y = World.height_at(spot.x, spot.z)
			for wk in [a17, b17]:
				(wk as Worker).abandon("review")
				(wk as Worker).activity = "idle"
				(wk as Worker)._decide_cd = 25.0
			a17.global_position = spot
			b17.global_position = spot + Vector3(1.4, 0, 0)
			var talk17: ConversationService = Game.crew.talk
			for k in 40:
				talk17._try_start()
				if not talk17.active.is_empty():
					break
				talk17.cooldown.erase("g:%s,%s" % [a17.id, b17.id])
			if talk17.active.is_empty():
				return "No line fits these two right now (try another time of day, place or job)."
			var first: String = str((talk17.active.queue as Array)[0][0])
			return "%s and %s start talking (line %s). Subtitles appear as they speak; walk away and it drops." % [a17.emp.name, b17.emp.name, first]
		"p17_next_day":
			var fd: FeedService = Game.feed
			if fd == null:
				return ""
			_feed_day = clampi(_feed_day + 1, 1, 35)
			var got := fd.advance_to(float(_feed_day) * 10000.0 + 1679.0)
			return "Preview: the feed is published through the end of day %d (%d new units; %d published in all). Sit at the camper computer to read." % [_feed_day, got.size(), fd.pub.size()]
		"p17_counts":
			var fc: FeedService = Game.feed
			FeedService.load_bank()
			var kinds := {}
			for u in FeedService._bank_units:
				kinds[str(u.kind)] = int(kinds.get(str(u.kind), 0)) + 1
			var bank17 := CrewBank.get_bank()
			return "Crew bank: %d lines (%s).\nFeed bank: %d units %s, %d accounts. Published now: %d (skipped by branch/flag: %d).\nMail: %s\nForums: %s" % [bank17.lines.size(), str(bank17.count_by("cat")), FeedService.bank_size(), str(kinds), FeedService._accounts.size(), fc.pub.size(), fc.skipped.size(), fc.digest("Mail"), fc.digest("Forums")]
		"p17_window":
			var r17 := Game.feed.window_reservation() if Game.feed else {}
			return "Window-warning reservation right now: %s. (It needs: you reading at the desk, not glancing out, contract night, open curtains, a valid staging spot, nobody outside who would plainly see it, and the director free; otherwise the thread ends ordinarily.)" % ("OK" if bool(r17.get("ok", false)) else "refused - " + str(r17.get("reason", "")))
		"p17_howto":
			return "Sit at the camper desk: Mail, News, Forums and Archives are on the bar. New posts arrive with the clock (daytime news, evening and night discussion); anything you miss is waiting the next morning with a short 'since you last looked' digest. Bookmark threads; your place is remembered. Reading is live time - the night keeps going."
		"p16_numbers":
			var lv := PackedStringArray()
			for l in [2, 3, 5, 8, 10, 12, 15, 20]:
				lv.append("L%d %d" % [l, CrewProgression.career_threshold(l)])
			var sk := PackedStringArray()
			for l in [1, 3, 5, 7, 10]:
				sk.append("%d: %d" % [l, CrewProgression.skill_threshold(l)])
			return "Merit per original tree (max 1,000): felling 300, sectioning 200, stump 100, transport 300 (new closest approach to camp; 15%% for loading a truck/cart; the rest to the deliverer), receiving 100 (deck, then fire pile). Shared work splits by participation; the boss's share never becomes employee merit; repeats, circles and shuffles earn 0.\nCareer (cumulative merit): %s.\nSkill points: %s.\nSkill effects (combined cap x%.2f): cutting +2%%/level, handling -3%%/level lift time, driving +1.5%%/level smoother corners, teamwork -4%%/level lift sync. Career level multiplies nothing. Merit never pays money or changes wages." % [", ".join(lv), ", ".join(sk), ToolEffects.MAX_SKILL]
		"p16_rest_early", "p16_rest_late", "p16_rest_low":
			var rs: RestService = Game.rest
			if rs == null:
				return ""
			match which:
				"p16_rest_early":
					rs.rest = 64.0
					rs.late_s = 0.0
				"p16_rest_late":
					rs.rest = 38.0
					rs.late_s = 6.0 * 60.0
				"p16_rest_low":
					rs.rest = 0.0
					rs.late_s = 0.0
			rs._after_change()
			var fx16 := p.axe.effects()
			return "%s\nNow: walking x%.2f, cutting work per hit x%.2f (axe cadence unchanged). The camper is still safe at any rest." % [rs.describe_forecast(), float(fx16.factors.rest_walk), float(fx16.factors.fatigue)]
		"p16_hunt_rest":
			return "Survival days 31-35 run continuously: no bed-to-morning. Sit still on the couch or stay hidden in a real hiding place to recover about %d rest a minute up to %d - time keeps running, the Foreman keeps searching, and you can get up and run at once. Browsing the computer, chopping or driving is not rest." % [int(RestService.HUNT_REST), int(RestService.HUNT_CEILING)]
		"p15_distance", "p15_orbit", "p15_door", "p15_in_out", "p15_work", "p15_saw", "p15_truck_dog", "p15_ambience", "p15_relay", "p15_replay", "p15_night", "p15_worst":
			if which in ["p15_distance", "p15_orbit", "p15_work", "p15_saw", "p15_truck_dog", "p15_worst"]:
				w.teleport_to("camp")
				env.apply_named("day")
			return Audition.start(w, which.trim_prefix("p15_"))
		"cleared":
			var n := clear_near_camp(0.9)
			w.teleport_to("ridge")
			env.apply_named("day")
			wx.set_override("clear", true)
			return "Station 11 - cleared overlook (in memory): %d original trees removed around camp. No stale shadows, leaf audio or birds where trees are gone." % n
	return ""


## Phase 14 fixtures (Preview, in memory only).
static func _tree_near_camp(min_d: float) -> int:
	var o := World.camp_origin()
	var best := -1
	var bd := INF
	for i in World.tree_count():
		if World.removed_trees.has(int(World.trees.id[i])):
			continue
		var d := Vector2(World.trees.x[i] - o.x, World.trees.z[i] - o.z).length()
		if d > min_d and d < bd and float(World.trees.radius[i]) > 0.12:
			bd = d
			best = i
	return best


static func gear_fixture() -> void:
	var cs: CampaignService = Game.campaign
	if cs == null or Game.crew == null:
		return
	var tiers := ["t1", "t2", "t3", "t2", "t1"]
	var k := 0
	for e in cs.payroll.employees:
		if str(e.status) != Payroll.ACTIVE:
			continue
		var t: String = tiers[k % tiers.size()]
		for kind in ["boots", "gloves", "helmet"]:
			if kind == "helmet" and k == 4:
				continue
			var it := cs.equipment.add_item(kind, t, "storage", "preview")
			Game.crew.issue(str(it.id), str(e.id))
		if k == 1:
			var saw := cs.equipment.add_item("chainsaw", "saw", "storage", "preview")
			Game.crew.issue(str(saw.id), str(e.id))
		k += 1


static func supplier_fixture(w: IslandWorld) -> String:
	var cs: CampaignService = Game.campaign
	if cs == null:
		return ""
	if not cs.active:
		cs.start_test_route(true, false)
	cs.wallet.grant(800000, "test", "FIXTURE", "Preview supplier cash")
	cs.clock.t = 120.0
	var r := cs.supplier.place([{"key": "chainsaw:saw", "qty": 1}, {"key": "boots:t2", "qty": 1}, {"key": "gloves:t3", "qty": 1}], "PREVIEW-%d" % Time.get_ticks_msec())
	cs.clock.t = 302.0
	cs.supplier.tick()
	cs.supplier.tick()
	var lk := Game.player.get_tree().get_nodes_in_group("parcel_locker")
	if not lk.is_empty():
		var at: Vector3 = (lk[0] as Node3D).global_position
		Game.player.teleport(at + Vector3(0, 1.65, -2.6), at + Vector3(0, 1.0, 0))
	return "Order %s (in memory): paid at the computer, carried on the %s supply boat, now in the parcel locker. Press %s on the locker to collect it into camp storage, then the tool rack or the computer's Gear app to equip or issue it." % [str(r.get("order", {}).get("id", "?")), Supplier.hour_words(300.0), Keys.label("interact")]


static func team_fixture(w: IslandWorld) -> String:
	busy_camp_fixture()
	var crew: CrewService = Game.crew
	if crew == null or crew.workers.size() < 2:
		return "The crew is still arriving; try again in a moment."
	var t: TimberService = Game.timber
	var idx := _tree_near_camp(25.0)
	var id: int = World.trees.id[idx]
	if not t.records.has(id):
		t.records[id] = t._build_record(id, idx, {"plan": "v2", "segments": []})
	var big := -1
	for sg in t.records[id].segments:
		if int(sg.mte) > TimberService.HAND_BUDGET_MTE + 2 and int(sg.mte) <= TimberService.HAND_BUDGET_MTE * 2:
			big = int(sg.k)
	if big < 0:
		big = 0
	for sg in t.records[id].segments:
		sg.state = TimberService.Seg.CONSUMED if int(sg.k) != big else TimberService.Seg.CARRIED
	var sid := "T%d_S%d" % [id, big]
	t.carried.append(sid)
	var o := World.camp_origin()
	var at := Vector3(o.x + 3.0, 0, o.z - 24.0)
	var rr := TimberMesh.piece_radius(t.records[id], big)
	at.y = World.height_at(at.x, at.z) + rr + 0.02
	t.put_down(sid, at, Vector3.RIGHT, false)       # resting on the ground
	var lead: Worker = crew.workers.values()[0]
	for wk in crew.workers.values():
		(wk as Worker).abandon("preview")
		(wk as Worker).emp["job"] = "automatic"
	lead.target = {}
	var ok := crew._try_haul(lead)
	w.teleport_to("camp")
	return "A heavy log lies just outside the north gate. %s %s" % [("%s went to lift it and called %s to take the far end; they walk at the slower partner's carry speed." % [lead.emp.name, crew.emp(str(crew.coord.teams.get(lead.team, {}).get("follower", ""))).get("name", "nobody")]) if ok and lead.team != "" else "No free partner right now: one worker drags it alone (the solo fallback).", "If the partner is called away, the leader keeps the log and drags it - nothing is dropped or duplicated."]


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
			crew.candidates.append({"cid": cid, "name": ["Ines Vance", "Kofi Brandt", "Wren Salo"][i], "traits": sets[i], "look_seed": 9100 + i * 131, "fee": crew.econ.hire_fee_cents, "wage": PayMorale.asking_wage(cid, sets[i])})
			crew.hire(cid))


## Phase 16: two workers each do real felling work on one nearby tree
## (through TreeService, the authoritative path) - merit splits 60/40.
static func shared_tree_fixture(w: IslandWorld) -> String:
	var crew: CrewService = Game.crew
	if crew.workers.size() < 2:
		return "Needs two workers on site."
	var ws: Array = crew.workers.values()
	var a: Worker = ws[0]
	var b: Worker = ws[1]
	var o := World.camp_origin()
	var best := -1
	var bd := INF
	for i in World.tree_count():
		var d := Vector2(World.trees.x[i] - o.x, World.trees.z[i] - o.z).length()
		if d > 50.0 and d < bd and Game.trees.state_of(int(World.trees.id[i])) == TreeService.State.STANDING:
			bd = d
			best = i
	if best < 0:
		return "No standing tree found."
	var tid: int = World.trees.id[best]
	var req := float(Game.trees.record(tid).required)
	var st := PlacementValidator.cut_stands(best)[0]
	var ma := crew.merit.total(a.id)
	var mb := crew.merit.total(b.id)
	Game.trees.apply_contact(tid, st, req * 0.6, a.id)
	Game.trees.apply_contact(tid, st, req * 0.4, b.id)
	Game.trees.apply_contact(tid, st, req, a.id)
	return "%s cut 60%% of the notch and %s 40%%: felling merit %+.0f / %+.0f (300 per tree, split by accepted work). A third contact on the felled tree earned 0. The tree stood %.0f m from camp." % [a.emp.name, b.emp.name, crew.merit.total(a.id) - ma, crew.merit.total(b.id) - mb, bd]
