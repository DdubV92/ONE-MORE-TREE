class_name CampaignRules
extends RefCounted
## Fixed campaign rules from the authoritative expansion (Nov 3, 2026).
## Phase 1 only DEFINES these: nothing here starts a clock, charges wages,
## pays money or runs a deadline. Prompts 3-6 implement the systems; this
## file is the single source their numbers come from.

const RULE_SET_ID := "contract_v1"

enum State {
	CONTRACT_ACTIVE,        # days 1-30, ordinary logging / cozy-horror rules
	CONTRACT_FULFILLED,     # requirements met before the end of day 30
	ABANDONMENT_TRANSITION, # deadline missed; settlement frozen
	HUNT_ACTIVE,            # days 31-35, continuous clock, The Foreman (Prompt 6)
	RESCUE_AVAILABLE,       # dawn of day 36 at the dock
	ESCAPED,
	PLAYER_DEAD,
}

# --- clock (Prompt 3) --------------------------------------------------------
const DAYLIGHT_MINUTES := 15.0        # real minutes from morning start
const DUSK_MINUTES := 5.0             # return warning at minute 15, night at 20
const CONTRACT_DAYS := 30
const SURVIVAL_DAYS := 5               # failure mode, days 31-35
const SURVIVAL_CYCLE_MINUTES := 20.0   # proposed, tune after testing
const RESCUE_BOARDING_MINUTES := 8.0   # proposed

# --- money (Prompts 2-3) -----------------------------------------------------
const PAY_PER_TREE_CENTS := 10000      # $100, paid via accepted log shares
const WAGE_PER_WORKER_DAY_CENTS := 30000
const ARREARS_GRACE_DAYS := 1
const TRUCK_PRICE_CENTS := 900000      # proposed; measure time-to-afford
const TRUCK_UNLOCK_PAID_TREE_EQUIVALENTS := 50.0

# --- crew (Prompt 4) ---------------------------------------------------------
const STARTING_WORKERS := 2
const MAX_WORKERS := 5                 # boss + 5 = 6 humans
const CABIN_BEDS := 6                  # existing 4 + attached 2-bed room

# --- tools and traits ----------------------------------------------------------
const AXE_RATES := {"small": 1.0, "medium": 1.4, "large": 1.96}
const HARD_WORKING_MULTIPLIER := 1.25  # applied once to effective cut rate
const STRONGER_CARRY_MULTIPLIER := 1.5 # proposed: 1/3 -> 1/2 tree-equivalent

# --- cargo (Prompts 2 and 5) -------------------------------------------------
const HAND_LOAD_TREE_EQUIVALENTS := 1.0 / 3.0
const TRUCK_SEATS := 3                 # driver + 2 passengers
const TRUCK_CAPACITY_TREE_EQUIVALENTS := 3.0
const MAX_TRUCKS := 2

enum Assignment { IDLE, FELLER, PROCESSOR, HAULER, LOADER, DRIVER }


## Combined cutting rate for a worker: tool tier times (once) the trait.
static func cut_rate(tier: String, hard_working: bool) -> float:
	return float(AXE_RATES.get(tier, 1.0)) * (HARD_WORKING_MULTIPLIER if hard_working else 1.0)


static func hand_capacity(stronger: bool) -> float:
	return HAND_LOAD_TREE_EQUIVALENTS * (STRONGER_CARRY_MULTIPLIER if stronger else 1.0)


static func state_name(s: int) -> String:
	return State.keys()[s]
