class_name Difficulty
extends RefCounted
## Phase 29: how hard the nights are. Chosen when a campaign is started and
## saved with it; older saves are Standard.
##   cozy        contract nights cannot catch you, the island stirs less
##   standard    the game as designed
##   long_night  the island stirs sooner, the dark closes in faster and the
##               hunt after a finished contract lasts a day longer
## The hunt itself can still kill in every mode. Safety rules never change.

const MODES := ["cozy", "standard", "long_night"]
const LABEL := {"cozy": "Cozy", "standard": "Standard", "long_night": "Long Night"}
const BLURB := {
	"cozy": "Contract nights cannot catch you: the warnings still come, but the dark never takes you. The island stirs less. The hunt after the contract is unchanged and can still kill.",
	"standard": "The game as designed.",
	"long_night": "The island stirs sooner, the dark closes in a quarter faster, and the hunt after a finished contract lasts one day longer.",
}
const PRESSURE_OFFSET := {"cozy": -0.15, "standard": 0.0, "long_night": 0.2}
const PRESSURE_CAP := {"cozy": 0.6, "standard": 1.0, "long_night": 1.0}
const EXPOSURE := {"cozy": 0.8, "standard": 1.0, "long_night": 1.25}

## What the title screen's New Campaign page has selected.
static var pending := "standard"


static func valid(m: String) -> String:
	return m if m in MODES else "standard"


static func mode() -> String:
	var c: CampaignService = Game.campaign
	return valid(str(c.difficulty)) if c != null else "standard"


static func label() -> String:
	return str(LABEL[mode()])


static func catch_allowed() -> bool:
	return mode() != "cozy"


## Applied to the night pressure the campaign computes.
static func adjust_pressure(v: float) -> float:
	var m := mode()
	return clampf(v + float(PRESSURE_OFFSET[m]), 0.0, float(PRESSURE_CAP[m]))


static func exposure_scale() -> float:
	return float(EXPOSURE[mode()])


static func hunt_extra_days() -> int:
	return 1 if mode() == "long_night" else 0
