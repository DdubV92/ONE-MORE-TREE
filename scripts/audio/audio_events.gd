class_name AudioEvents
extends RefCounted
## Phase 10: stable audio event IDs (the interface Phase 15's event service
## and asset replacement will keep). Gameplay can ask for an ID instead of a
## file. Each entry lists its current source files and an honest quality
## grade: "placeholder" = synthesized stand-in (all current sounds),
## "missing" = reserved for a later phase, no asset yet.

const EVENTS := {
	# Work and materials
	"work.axe.contact.wood": {"files": ["chop_0", "chop_1", "chop_2", "chop_3", "chop_4"], "grade": "placeholder", "note": "too clicky; no bark-bite/deep layer"},
	"work.axe.miss": {"files": ["axe_miss_0", "axe_miss_1"], "grade": "placeholder"},
	"tree.strain.creak": {"files": ["creak_wood_0", "creak_wood_1", "creak_wood_2"], "grade": "placeholder"},
	"tree.hinge.crack": {"files": ["tree_crack"], "grade": "placeholder"},
	"tree.crown.rustle": {"files": ["tree_rustle"], "grade": "placeholder"},
	"tree.fall.impact": {"files": ["tree_impact_0", "tree_impact_1"], "grade": "placeholder", "note": "thin low end"},
	"log.settle": {"files": ["log_settle", "clunk_0", "clunk_1", "clunk_2"], "grade": "placeholder"},
	"log.stack": {"files": [], "grade": "missing", "phase": 13},
	"tool.chainsaw.start": {"files": [], "grade": "missing", "phase": 14},
	"tool.chainsaw.idle": {"files": [], "grade": "missing", "phase": 14},
	"tool.chainsaw.load": {"files": [], "grade": "missing", "phase": 14},
	"tool.chainsaw.stop": {"files": [], "grade": "missing", "phase": 14},
	"yard.cradle.receive": {"files": [], "grade": "missing", "phase": 13},
	# People and dog
	"step.grass": {"files": ["step_grass_0", "step_grass_1", "step_grass_2", "step_grass_3", "step_grass_4"], "grade": "placeholder"},
	"step.forest": {"files": ["step_forest_0", "step_forest_1", "step_forest_2", "step_forest_3", "step_forest_4"], "grade": "placeholder"},
	"step.dirt": {"files": ["step_dirt_0", "step_dirt_1", "step_dirt_2", "step_dirt_3", "step_dirt_4"], "grade": "placeholder"},
	"step.sand": {"files": ["step_sand_0", "step_sand_1", "step_sand_2", "step_sand_3", "step_sand_4"], "grade": "placeholder"},
	"step.rock": {"files": ["step_rock_0", "step_rock_1", "step_rock_2", "step_rock_3", "step_rock_4"], "grade": "placeholder"},
	"step.wood": {"files": ["step_wood_0", "step_wood_1", "step_wood_2", "step_wood_3", "step_wood_4"], "grade": "placeholder"},
	"step.water": {"files": ["step_water_0", "step_water_1", "step_water_2", "step_water_3", "step_water_4"], "grade": "placeholder"},
	"voice.worker.line": {"files": [], "grade": "missing", "phase": 18, "note": "no voice generation tool available in this environment"},
	"dog.bark": {"files": ["dog_bark_0", "dog_bark_1"], "grade": "placeholder", "note": "reads synthetic"},
	"dog.whine": {"files": ["dog_whine_0", "dog_whine_1"], "grade": "placeholder"},
	"dog.growl": {"files": ["dog_growl"], "grade": "placeholder"},
	"dog.pant": {"files": ["dog_pant"], "grade": "placeholder"},
	"dog.flap": {"files": ["dog_flap"], "grade": "placeholder"},
	# World
	"amb.ocean": {"files": ["ocean_surf"], "grade": "placeholder"},
	"amb.river": {"files": ["river"], "grade": "placeholder"},
	"amb.pond": {"files": ["pond_lap"], "grade": "placeholder"},
	"amb.wind.leaves": {"files": ["wind_leaves"], "grade": "placeholder"},
	"amb.birds": {"files": ["bird_0", "bird_1", "bird_2", "bird_3", "bird_4"], "grade": "placeholder", "note": "simple chirps"},
	"amb.fire": {"files": ["fire_crackle"], "grade": "placeholder"},
	"amb.room": {"files": ["room_tone"], "grade": "placeholder"},
	"weather.rain.open": {"files": ["rain_open"], "grade": "placeholder"},
	"weather.rain.roof": {"files": ["rain_roof"], "grade": "placeholder"},
	"weather.thunder.far": {"files": ["thunder_far_0", "thunder_far_1"], "grade": "placeholder"},
	"music.day": {"files": ["motif_day"], "grade": "original", "note": "Phase 24 motif, warm day arrangement (tools/content/soundscape24.py)"},
	"music.dusk": {"files": ["motif_dusk"], "grade": "original", "note": "same motif, thinned"},
	"music.night": {"files": ["motif_night"], "grade": "original", "note": "same motif, altered harmony / drifting tuning / unresolved"},
	# Horror and hunt
	"terror.knock": {"files": ["t_knock_0", "t_knock_1", "t_knock_2"], "grade": "placeholder"},
	"terror.call": {"files": ["t_call"], "grade": "placeholder"},
	"terror.voice": {"files": ["t_voice_0", "t_voice_1", "t_voice_2", "t_voice_3"], "grade": "placeholder"},
	"terror.stinger": {"files": ["t_stinger"], "grade": "placeholder"},
	"foreman.step": {"files": ["f_step_0", "f_step_1"], "grade": "placeholder"},
	"foreman.tags": {"files": ["f_tags"], "grade": "placeholder"},
	"foreman.breath": {"files": ["f_breath", "f_intake"], "grade": "placeholder"},
	"ship.horn": {"files": ["ship_horn"], "grade": "placeholder"},
}


static func stream(id: String, variant := -1) -> AudioStream:
	var e: Dictionary = EVENTS.get(id, {})
	var files: Array = e.get("files", [])
	if files.is_empty():
		return null
	var f: String = files[(variant if variant >= 0 else randi()) % files.size()]
	var path := "res://audio/generated/%s.wav" % f
	return load(path) if ResourceLoader.exists(path) else null


## Inventory for docs/tests: {"events", "placeholder", "missing", "files_missing": [...]}.
static func inventory() -> Dictionary:
	var out := {"events": EVENTS.size(), "placeholder": 0, "missing": 0, "files_missing": []}
	for id in EVENTS:
		var e: Dictionary = EVENTS[id]
		out[str(e.grade)] = int(out.get(str(e.grade), 0)) + 1
		for f in e.files:
			if not ResourceLoader.exists("res://audio/generated/%s.wav" % f):
				(out.files_missing as Array).append(f)
	return out
