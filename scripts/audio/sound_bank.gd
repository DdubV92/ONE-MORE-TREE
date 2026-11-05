class_name SoundBank
extends RefCounted
## Phase 15: stable gameplay sound-event IDs -> sources in the original
## procedural library (audio/lib, SoundLibIndex), with routing and distance
## calibration. Gameplay asks SoundService for an ID; it never names files.
##
## Fields: files (library names, no immediate repeat), bus, cal (distance
## class, see CAL), db (level), pitch [lo, hi], loop, label (caption text),
## debounce_ms (same event within this window and 2 m = one sound).

## Distance calibration per class: unit_size (m at full level), max
## distance, max_db (near-field cap), and whether far copies arrive late
## (sound travel ~343 m/s for transients beyond 40 m).
const CAL := {
	"tiny": {"unit": 1.6, "max": 22.0, "max_db": 0.0, "delay": false},      # tags, clicks, cloth
	"step": {"unit": 2.4, "max": 34.0, "max_db": 0.0, "delay": false},
	"contact": {"unit": 6.0, "max": 110.0, "max_db": 3.0, "delay": true},   # axe, knocks, logs
	"impact": {"unit": 16.0, "max": 380.0, "max_db": 4.0, "delay": true},   # falls, thunder near
	"engine": {"unit": 9.0, "max": 230.0, "max_db": 3.0, "delay": false},   # saws, trucks (loops)
	"voice": {"unit": 4.0, "max": 70.0, "max_db": 0.0, "delay": false},     # dog, calls
	"domestic": {"unit": 2.2, "max": 26.0, "max_db": 0.0, "delay": false},
	"ambient": {"unit": 12.0, "max": 220.0, "max_db": 0.0, "delay": false}, # surf, river, wind emitters
	"distant": {"unit": 30.0, "max": 900.0, "max_db": 0.0, "delay": true},  # far thunder, far cracks
	"vessel": {"unit": 70.0, "max": 2600.0, "max_db": 0.0, "delay": false}, # Phase 19 survey ship (loop)
	"aircraft": {"unit": 45.0, "max": 2200.0, "max_db": 3.0, "delay": false}, # Phase 19 helicopter rotor (loop)
}

const EVENTS := {
	# ---- work: axe by material/size/target (contact point) ----
	"work.axe.bite.pine.thin": {"files": ["axe_bite_pine_thin"], "bus": "Work", "cal": "contact", "db": -4.0, "pitch": [0.96, 1.04], "label": "chopping"},
	"work.axe.bite.pine.thick": {"files": ["axe_bite_pine_thick", "axe_deep_pine"], "bus": "Work", "cal": "contact", "db": -3.0, "pitch": [0.96, 1.04], "label": "chopping"},
	"work.axe.bite.spruce.thin": {"files": ["axe_bite_spruce_thin"], "bus": "Work", "cal": "contact", "db": -4.0, "pitch": [0.96, 1.04], "label": "chopping"},
	"work.axe.bite.spruce.thick": {"files": ["axe_bite_spruce_thick", "axe_deep_spruce"], "bus": "Work", "cal": "contact", "db": -3.0, "pitch": [0.96, 1.04], "label": "chopping"},
	"work.axe.bite.birch.thin": {"files": ["axe_bite_birch_thin"], "bus": "Work", "cal": "contact", "db": -4.0, "pitch": [0.96, 1.04], "label": "chopping"},
	"work.axe.bite.birch.thick": {"files": ["axe_bite_birch_thick", "axe_deep_birch"], "bus": "Work", "cal": "contact", "db": -3.0, "pitch": [0.96, 1.04], "label": "chopping"},
	"work.axe.buck": {"files": ["axe_buck_small", "axe_buck_large"], "bus": "Work", "cal": "contact", "db": -4.0, "pitch": [0.95, 1.05], "label": "bucking a log"},
	"work.axe.stump": {"files": ["axe_stump_0", "axe_stump_1", "axe_stump_2"], "bus": "Work", "cal": "contact", "db": -4.0, "pitch": [0.95, 1.05], "label": "chopping a stump"},
	"work.axe.hard": {"files": ["axe_hard_stone", "axe_hard_post"], "bus": "Work", "cal": "contact", "db": -6.0, "pitch": [0.95, 1.05], "label": "axe on something hard"},
	"work.axe.miss": {"files": ["axe_swish_light", "axe_swish_heavy"], "bus": "Work", "cal": "tiny", "db": -16.0, "pitch": [0.95, 1.08]},
	"work.chips": {"files": ["chips_fall"], "bus": "Work", "cal": "tiny", "db": -16.0, "pitch": [0.9, 1.1]},
	"tree.strain": {"files": ["trunk_strain_0", "trunk_strain_1", "trunk_strain_2", "trunk_strain_3"], "bus": "Work", "cal": "contact", "db": -6.0, "pitch": [0.92, 1.06], "label": "wood straining", "debounce_ms": 900},
	"tree.hinge.crack": {"files": ["hinge_crack_0", "hinge_crack_1", "hinge_crack_2"], "bus": "Work", "cal": "impact", "db": -2.0, "pitch": [0.95, 1.05], "label": "trunk cracking", "debounce_ms": 1500},
	"tree.crown.rustle.pine": {"files": ["crown_rustle_pine"], "bus": "Work", "cal": "contact", "db": -6.0, "pitch": [0.95, 1.05], "label": "branches rustling", "debounce_ms": 1200},
	"tree.crown.rustle.birch": {"files": ["crown_rustle_birch"], "bus": "Work", "cal": "contact", "db": -6.0, "pitch": [0.95, 1.05], "label": "leaves rustling", "debounce_ms": 1200},
	"tree.fall.small": {"files": ["fall_impact_small"], "bus": "Work", "cal": "impact", "db": 0.0, "pitch": [0.95, 1.05], "label": "a tree falling", "debounce_ms": 1500},
	"tree.fall.medium": {"files": ["fall_impact_medium"], "bus": "Work", "cal": "impact", "db": 1.0, "pitch": [0.95, 1.05], "label": "a tree falling", "debounce_ms": 1500},
	"tree.fall.large": {"files": ["fall_impact_large"], "bus": "Work", "cal": "impact", "db": 2.0, "pitch": [0.95, 1.05], "label": "a big tree falling", "debounce_ms": 1500},
	"tree.branch.snap": {"files": ["branch_snap_0", "branch_snap_1", "branch_snap_2"], "bus": "Work", "cal": "contact", "db": -5.0, "pitch": [0.92, 1.08], "debounce_ms": 300},
	"stump.root.tear": {"files": ["stump_root_tear"], "bus": "Work", "cal": "contact", "db": -3.0, "pitch": [0.95, 1.05], "label": "a stump tearing out"},
	"log.roll.ground": {"files": ["log_roll_ground"], "bus": "Work", "cal": "contact", "db": -7.0, "pitch": [0.9, 1.1], "debounce_ms": 600},
	"log.roll.log": {"files": ["log_roll_log"], "bus": "Work", "cal": "contact", "db": -7.0, "pitch": [0.9, 1.1], "debounce_ms": 600},
	"log.drop.ground": {"files": ["log_drop_ground"], "bus": "Work", "cal": "contact", "db": -6.0, "pitch": [0.92, 1.08], "label": "a log thudding down", "debounce_ms": 280},
	"log.drop.log": {"files": ["log_drop_log"], "bus": "Work", "cal": "contact", "db": -6.0, "pitch": [0.92, 1.08], "label": "logs knocking", "debounce_ms": 280},
	"log.drop.rack": {"files": ["log_drop_rack_wood"], "bus": "Work", "cal": "contact", "db": -6.0, "pitch": [0.92, 1.08], "label": "a log on the rack", "debounce_ms": 280},
	"log.drop.cart": {"files": ["log_drop_cart_metal"], "bus": "Work", "cal": "contact", "db": -7.0, "pitch": [0.92, 1.08], "debounce_ms": 280},
	"log.stack": {"files": ["log_stack_0", "log_stack_1"], "bus": "Work", "cal": "contact", "db": -6.0, "pitch": [0.92, 1.08], "label": "logs stacked", "debounce_ms": 280},
	"log.drag": {"files": ["log_drag_loop"], "bus": "Work", "cal": "contact", "db": -10.0, "loop": true},
	"tool.saw.start": {"files": ["saw2_start"], "bus": "Work", "cal": "engine", "db": -2.0, "pitch": [0.98, 1.02]},
	"tool.saw.idle": {"files": ["saw2_idle"], "bus": "Work", "cal": "engine", "db": -6.0, "loop": true},
	"tool.saw.rev": {"files": ["saw2_rev"], "bus": "Work", "cal": "engine", "db": -2.0, "loop": true},
	"tool.saw.load": {"files": ["saw2_load"], "bus": "Work", "cal": "engine", "db": -1.0, "loop": true},
	"tool.saw.stop": {"files": ["saw2_stop"], "bus": "Work", "cal": "engine", "db": -4.0},
	"tool.saw.spray": {"files": ["saw2_spray"], "bus": "Work", "cal": "tiny", "db": -10.0},
	"tool.pickup": {"files": ["tool_pickup", "rack_hang"], "bus": "Work", "cal": "tiny", "db": -12.0},
	"fire.bed.small": {"files": ["fire_bed_small_loop"], "bus": "Ambience", "cal": "domestic", "db": -6.0, "loop": true},
	"fire.bed.large": {"files": ["fire_bed_large_loop"], "bus": "Ambience", "cal": "domestic", "db": -4.0, "loop": true},
	"fire.pop": {"files": ["fire_pop_0", "fire_pop_1", "fire_pop_2", "fire_pop_3", "fire_hiss_sap", "fire_embers_settle"], "bus": "Ambience", "cal": "domestic", "db": -8.0, "pitch": [0.9, 1.1]},
	"fire.log.place": {"files": ["fire_log_place"], "bus": "Work", "cal": "contact", "db": -6.0},
	# ---- vehicles ----
	"truck.engine.idle": {"files": ["truck_engine_idle_loop"], "bus": "Work", "cal": "engine", "db": -6.0, "loop": true},
	"truck.engine.low": {"files": ["truck_engine_low_loop"], "bus": "Work", "cal": "engine", "db": -5.0, "loop": true},
	"truck.engine.mid": {"files": ["truck_engine_mid_loop"], "bus": "Work", "cal": "engine", "db": -4.0, "loop": true},
	"truck.engine.high": {"files": ["truck_engine_high_loop"], "bus": "Work", "cal": "engine", "db": -3.0, "loop": true},
	"truck.start": {"files": ["truck_start"], "bus": "Work", "cal": "engine", "db": -3.0},
	"truck.stop": {"files": ["truck_stop"], "bus": "Work", "cal": "engine", "db": -5.0},
	"truck.door.open": {"files": ["truck_door_open"], "bus": "Work", "cal": "domestic", "db": -6.0},
	"truck.door.close": {"files": ["truck_door_close"], "bus": "Work", "cal": "contact", "db": -5.0, "label": "a truck door"},
	"truck.tailgate.open": {"files": ["tailgate_open"], "bus": "Work", "cal": "contact", "db": -6.0},
	"truck.tailgate.close": {"files": ["tailgate_close"], "bus": "Work", "cal": "contact", "db": -5.0},
	"truck.cargo.rattle": {"files": ["cargo_rattle_loop"], "bus": "Work", "cal": "domestic", "db": -12.0, "loop": true},
	"truck.cargo.thud": {"files": ["cargo_log_thud"], "bus": "Work", "cal": "contact", "db": -5.0, "debounce_ms": 250},
	"truck.tire.gravel": {"files": ["tire_gravel_loop"], "bus": "Work", "cal": "engine", "db": -10.0, "loop": true},
	"truck.tire.dirt": {"files": ["tire_dirt_loop"], "bus": "Work", "cal": "engine", "db": -10.0, "loop": true},
	"truck.tire.grass": {"files": ["tire_grass_loop"], "bus": "Work", "cal": "engine", "db": -12.0, "loop": true},
	"truck.suspension": {"files": ["suspension_thump_0", "suspension_thump_1"], "bus": "Work", "cal": "contact", "db": -8.0, "debounce_ms": 350},
	"truck.horn": {"files": ["truck_horn"], "bus": "Work", "cal": "impact", "db": -2.0, "label": "a truck horn"},
	"truck.handbrake": {"files": ["truck_handbrake"], "bus": "Work", "cal": "tiny", "db": -10.0},
	"truck.gear": {"files": ["truck_gear_clunk"], "bus": "Work", "cal": "tiny", "db": -10.0},
	"cart.roll.dirt": {"files": ["cart_roll_dirt_loop"], "bus": "Work", "cal": "step", "db": -10.0, "loop": true},
	"cart.roll.wood": {"files": ["cart_roll_wood_loop"], "bus": "Work", "cal": "step", "db": -10.0, "loop": true},
	"cart.squeak": {"files": ["cart_squeak"], "bus": "Work", "cal": "step", "db": -14.0, "debounce_ms": 2500},
	"cart.bump": {"files": ["cart_bump"], "bus": "Work", "cal": "step", "db": -10.0, "debounce_ms": 400},
	"skiff.outboard": {"files": ["skiff_outboard_loop"], "bus": "Work", "cal": "engine", "db": -6.0, "loop": true},
	# ---- people, cloth, dog ----
	"cloth.rustle": {"files": ["cloth_rustle_0", "cloth_rustle_1", "cloth_rustle_2", "jacket_swish"], "bus": "Characters", "cal": "tiny", "db": -18.0, "pitch": [0.95, 1.05]},
	"gear.jingle": {"files": ["gear_jingle"], "bus": "Characters", "cal": "tiny", "db": -18.0},
	"boot.scuff.dirt": {"files": ["boot_scuff_dirt"], "bus": "Characters", "cal": "step", "db": -16.0},
	"boot.scuff.wood": {"files": ["boot_scuff_wood"], "bus": "Characters", "cal": "step", "db": -16.0},
	"body.kneel": {"files": ["kneel_cloth"], "bus": "Characters", "cal": "tiny", "db": -14.0},
	"body.sit": {"files": ["body_sit"], "bus": "Characters", "cal": "tiny", "db": -14.0},
	"dog.paw.dirt": {"files": ["paw_dirt_0", "paw_dirt_1"], "bus": "Characters", "cal": "tiny", "db": -16.0, "pitch": [0.9, 1.1]},
	"dog.paw.wood": {"files": ["paw_wood_0", "paw_wood_1"], "bus": "Characters", "cal": "tiny", "db": -14.0, "pitch": [0.9, 1.1]},
	"dog.paw.grass": {"files": ["paw_grass_0"], "bus": "Characters", "cal": "tiny", "db": -18.0, "pitch": [0.9, 1.1]},
	"dog.tags": {"files": ["collar_tags_0", "collar_tags_1"], "bus": "Characters", "cal": "tiny", "db": -16.0, "debounce_ms": 700},
	"dog.shake": {"files": ["dog_shake"], "bus": "Characters", "cal": "step", "db": -10.0},
	"dog.drink": {"files": ["dog_drink"], "bus": "Characters", "cal": "tiny", "db": -12.0},
	"dog.sniff": {"files": ["dog_sniff"], "bus": "Characters", "cal": "tiny", "db": -12.0},
	"dog.yawn": {"files": ["dog_yawn"], "bus": "Characters", "cal": "tiny", "db": -12.0},
	"dog.bark": {"files": ["dog_bark2_0", "dog_bark2_1"], "bus": "Characters", "cal": "voice", "db": -6.0, "pitch": [0.95, 1.05], "label": "Biscuit barking"},
	"dog.whine": {"files": ["dog_whine2"], "bus": "Characters", "cal": "voice", "db": -10.0, "label": "Biscuit whining"},
	"dog.pant": {"files": ["dog_pant2_loop"], "bus": "Characters", "cal": "tiny", "db": -16.0, "loop": true},
	"dog.growl": {"files": ["dog_growl2"], "bus": "Characters", "cal": "voice", "db": -10.0, "label": "Biscuit growling"},
	# ---- environment (emitters placed by AmbientAudio) ----
	"amb.surf.near": {"files": ["surf_near_loop"], "bus": "Ambience", "cal": "ambient", "db": -2.0, "loop": true},
	"offshore.ship.engine": {"files": ["ship_diesel_far_loop"], "bus": "Ambience", "cal": "vessel", "db": -3.0, "loop": true, "emit": false, "label": "a ship's engine"},
	"offshore.heli.rotor": {"files": ["rotor_beat_loop"], "bus": "Ambience", "cal": "aircraft", "db": 0.0, "loop": true, "emit": true, "label": "a helicopter"},
	"amb.surf.far": {"files": ["surf_far_loop"], "bus": "Ambience", "cal": "distant", "db": -6.0, "loop": true},
	"amb.shore.wash": {"files": ["shore_wash_0", "shore_wash_1"], "bus": "Ambience", "cal": "ambient", "db": -8.0},
	"amb.river.fast": {"files": ["water_fast_loop"], "bus": "Ambience", "cal": "ambient", "db": -4.0, "loop": true},
	"amb.river.slow": {"files": ["water_slow_loop"], "bus": "Ambience", "cal": "ambient", "db": -6.0, "loop": true},
	"amb.stream": {"files": ["water_trickle_loop"], "bus": "Ambience", "cal": "domestic", "db": -8.0, "loop": true},
	"amb.pond": {"files": ["pond_lap_loop", "reeds_rustle_loop"], "bus": "Ambience", "cal": "ambient", "db": -8.0, "loop": true},
	"amb.wind.low": {"files": ["wind_low_loop"], "bus": "Ambience", "cal": "ambient", "db": -10.0, "loop": true},
	"amb.wind.pines": {"files": ["wind_pines_loop"], "bus": "Ambience", "cal": "ambient", "db": -10.0, "loop": true},
	"amb.wind.birch": {"files": ["wind_birch_loop"], "bus": "Ambience", "cal": "ambient", "db": -10.0, "loop": true},
	"amb.wind.cleared": {"files": ["wind_cleared_loop"], "bus": "Ambience", "cal": "ambient", "db": -10.0, "loop": true},
	"amb.wind.gust": {"files": ["wind_gust_0", "wind_gust_1"], "bus": "Ambience", "cal": "ambient", "db": -10.0},
	"amb.forest.air": {"files": ["forest_air_loop"], "bus": "Ambience", "cal": "ambient", "db": -18.0, "loop": true},
	"amb.field.air": {"files": ["field_air_loop"], "bus": "Ambience", "cal": "ambient", "db": -18.0, "loop": true},
	"amb.insects.day": {"files": ["insects_day_loop", "bees_loop"], "bus": "Ambience", "cal": "domestic", "db": -18.0, "loop": true},
	"amb.crickets": {"files": ["crickets_loop"], "bus": "Ambience", "cal": "ambient", "db": -14.0, "loop": true},
	"amb.frogs": {"files": ["frog_chorus_loop"], "bus": "Ambience", "cal": "ambient", "db": -12.0, "loop": true},
	"amb.nightjar": {"files": ["nightjar_loop"], "bus": "Ambience", "cal": "ambient", "db": -16.0, "loop": true},
	"amb.bird.day": {"files": ["bird_robin", "bird_thrush", "bird_wren", "bird_crow", "bird_woodpecker"], "bus": "Ambience", "cal": "voice", "db": -6.0, "pitch": [0.94, 1.08]},
	"amb.bird.shore": {"files": ["bird_gull"], "bus": "Ambience", "cal": "voice", "db": -6.0, "pitch": [0.94, 1.08]},
	"amb.owl": {"files": ["owl_hoot_0", "owl_hoot_1"], "bus": "Ambience", "cal": "voice", "db": -8.0},
	"amb.frog.single": {"files": ["frog_single"], "bus": "Ambience", "cal": "voice", "db": -10.0},
	"amb.leaves.fall": {"files": ["leaves_fall"], "bus": "Ambience", "cal": "step", "db": -16.0},
	"amb.branch.far": {"files": ["distant_branch_crack"], "bus": "Ambience", "cal": "distant", "db": -6.0},
	"amb.drip": {"files": ["drip_0", "drip_1"], "bus": "Ambience", "cal": "tiny", "db": -14.0},
	"amb.fish.splash": {"files": ["fish_splash"], "bus": "Ambience", "cal": "contact", "db": -10.0},
	"weather.rain.light": {"files": ["rain_light_loop"], "bus": "Ambience", "db": -8.0, "loop": true, "cal": "ambient"},
	"weather.rain.heavy": {"files": ["rain_heavy_loop"], "bus": "Ambience", "db": -6.0, "loop": true, "cal": "ambient"},
	"weather.rain.canvas": {"files": ["rain_canvas_loop"], "bus": "Ambience", "db": -8.0, "loop": true, "cal": "domestic"},
	"weather.rain.metal": {"files": ["rain_metal_loop"], "bus": "Ambience", "db": -8.0, "loop": true, "cal": "domestic"},
	"weather.rain.wood": {"files": ["rain_wood_loop"], "bus": "Ambience", "db": -8.0, "loop": true, "cal": "domestic"},
	"weather.rain.drips": {"files": ["rain_drips_loop"], "bus": "Ambience", "db": -12.0, "loop": true, "cal": "domestic"},
	"weather.thunder.near": {"files": ["thunder_near"], "bus": "Ambience", "cal": "distant", "db": 0.0, "label": "thunder"},
	"weather.thunder.far": {"files": ["thunder_far2_0", "thunder_far2_1"], "bus": "Ambience", "cal": "distant", "db": -4.0, "label": "distant thunder"},
	# ---- camper, cabin, computer, fence ----
	"door.wood.open": {"files": ["door_wood_open"], "bus": "Characters", "cal": "domestic", "db": -8.0, "label": "a door opening"},
	"door.wood.close": {"files": ["door_wood_close"], "bus": "Characters", "cal": "contact", "db": -6.0, "label": "a door closing"},
	"door.latch": {"files": ["door_latch"], "bus": "Characters", "cal": "domestic", "db": -10.0},
	"door.creak": {"files": ["door_creak"], "bus": "Characters", "cal": "domestic", "db": -10.0, "label": "a hinge creaking"},
	"window.slide": {"files": ["window_slide"], "bus": "Characters", "cal": "domestic", "db": -10.0},
	"window.rattle": {"files": ["window_rattle"], "bus": "Characters", "cal": "domestic", "db": -10.0, "label": "the window rattling"},
	"home.fridge": {"files": ["fridge_hum_loop"], "bus": "Ambience", "cal": "domestic", "db": -24.0, "loop": true},
	"home.fan": {"files": ["fan_hum_loop"], "bus": "Ambience", "cal": "domestic", "db": -24.0, "loop": true},
	"home.lamp": {"files": ["lamp_hum_loop"], "bus": "Ambience", "cal": "tiny", "db": -28.0, "loop": true},
	"home.keyboard": {"files": ["keyboard_type_loop"], "bus": "UI", "cal": "tiny", "db": -16.0, "loop": true},
	"home.kettle": {"files": ["kettle_boil_loop"], "bus": "Ambience", "cal": "domestic", "db": -14.0, "loop": true},
	"home.cupboard": {"files": ["cupboard_close"], "bus": "Characters", "cal": "domestic", "db": -12.0},
	"home.floor.creak": {"files": ["floor_creak_0", "floor_creak_1"], "bus": "Characters", "cal": "domestic", "db": -14.0},
	"home.heater": {"files": ["heater_tick"], "bus": "Ambience", "cal": "domestic", "db": -18.0},
	"ui.click": {"files": ["mouse_click"], "bus": "UI", "cal": "tiny", "db": -14.0},
	"ui.chime": {"files": ["notify_chime"], "bus": "UI", "cal": "tiny", "db": -14.0},
	"camp.fence.rattle": {"files": ["fence_rattle"], "bus": "Ambience", "cal": "contact", "db": -10.0, "label": "the fence rattling"},
	"camp.gate.clank": {"files": ["gate_clank"], "bus": "Work", "cal": "contact", "db": -8.0, "label": "the gate"},
	# ---- horror (authored physical sources; "internal" ones say so) ----
	"terror.knock.wood": {"files": ["knock_wood_dull", "knock_wood_sharp", "knock_wood_slow"], "bus": "Horror", "cal": "contact", "db": -4.0, "label": "knocking"},
	"terror.knock.metal": {"files": ["knock_metal"], "bus": "Horror", "cal": "contact", "db": -4.0, "label": "knocking on metal"},
	"terror.knock.glass": {"files": ["knock_glass", "glass_tap"], "bus": "Horror", "cal": "domestic", "db": -6.0, "label": "tapping on glass"},
	"terror.fence": {"files": ["fence_rattle_unseen"], "bus": "Horror", "cal": "contact", "db": -6.0, "label": "the fence moving"},
	"terror.steps.gravel": {"files": ["gravel_steps_slow"], "bus": "Horror", "cal": "step", "db": -4.0, "label": "slow footsteps"},
	"terror.branch": {"files": ["branch_snap_near"], "bus": "Horror", "cal": "contact", "db": -4.0, "label": "a branch snapping"},
	"terror.whisper": {"files": ["whisper_0", "whisper_1", "whisper_2"], "bus": "Horror", "cal": "voice", "db": -12.0, "label": "whispering", "internal_ok": true},
	"terror.drone.low": {"files": ["drone_low_loop"], "bus": "Horror", "cal": "ambient", "db": -20.0, "loop": true},
	"terror.drone.beating": {"files": ["drone_beating_loop"], "bus": "Horror", "cal": "ambient", "db": -22.0, "loop": true},
	"terror.breath.close": {"files": ["breath_close"], "bus": "Horror", "cal": "tiny", "db": -10.0, "label": "breathing"},
	"terror.breath.far": {"files": ["breath_far"], "bus": "Horror", "cal": "voice", "db": -10.0, "label": "breathing"},
	"terror.drag": {"files": ["cloth_drag"], "bus": "Horror", "cal": "step", "db": -8.0, "label": "something dragging"},
	"terror.scrape": {"files": ["metal_scrape"], "bus": "Horror", "cal": "contact", "db": -8.0, "label": "metal scraping"},
	"terror.groan": {"files": ["metal_groan"], "bus": "Horror", "cal": "contact", "db": -8.0, "label": "metal groaning"},
	"terror.scratch": {"files": ["wood_scratch"], "bus": "Horror", "cal": "domestic", "db": -8.0, "label": "scratching"},
	"terror.thud.far": {"files": ["low_thud_far"], "bus": "Horror", "cal": "distant", "db": -4.0, "label": "a heavy thud"},
	"terror.step.wet": {"files": ["wet_step_0", "wet_step_1"], "bus": "Horror", "cal": "step", "db": -8.0, "label": "wet footsteps"},
	"terror.call.far": {"files": ["distant_call"], "bus": "Horror", "cal": "distant", "db": -8.0, "label": "a distant call"},
	"terror.tags.far": {"files": ["tags_far"], "bus": "Horror", "cal": "tiny", "db": -10.0, "label": "metal tags"},
	# Legacy Phase 6 sources (audio/generated) where the new library has no
	# better one yet - bound honestly, listed as gaps in the coverage table.
	"foreman.step": {"files": ["f_step_0", "f_step_1"], "bus": "Horror", "cal": "step", "db": -2.0, "pitch": [0.92, 1.05], "label": "heavy footsteps", "legacy": true},
	"foreman.step.wet": {"files": ["wet_step_0", "wet_step_1"], "bus": "Horror", "cal": "step", "db": -2.0, "pitch": [0.92, 1.05], "label": "heavy wet footsteps"},
	"foreman.breath": {"files": ["f_breath", "f_intake", "breath_close"], "bus": "Horror", "cal": "voice", "db": -4.0, "label": "breathing"},
	"foreman.tags": {"files": ["f_tags", "tags_far"], "bus": "Horror", "cal": "tiny", "db": -10.0, "label": "metal tags"},
}


## Library path for a source name ("" if missing).
static func path_of(name: String) -> String:
	var e: Array = SoundLibIndex.FILES.get(name, [])
	if not e.is_empty():
		return str(e[0])
	var legacy := "res://audio/generated/%s.wav" % name
	return legacy if ResourceLoader.exists(legacy) else ""


static func is_legacy(name: String) -> bool:
	return not SoundLibIndex.FILES.has(name)


## Coverage report for docs/tests: events, sources used, missing sources.
static func coverage() -> Dictionary:
	var used := {}
	var missing := []
	var legacy := {}
	for id in EVENTS:
		for f in EVENTS[id].files:
			used[f] = true
			if is_legacy(str(f)):
				legacy[f] = true
			if path_of(str(f)) == "" or not ResourceLoader.exists(path_of(str(f))):
				missing.append("%s:%s" % [id, f])
	return {"events": EVENTS.size(), "sources_bound": used.size(), "legacy_bound": legacy.size(), "library": SoundLibIndex.FILES.size(), "missing": missing}
