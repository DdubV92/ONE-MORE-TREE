class_name LaterInterfaces
extends RefCounted
## Documented interfaces reserved for later prompts. Phase 0 deliberately does
## NOT implement these systems; it only fixes their shape so world data,
## anchors and saves line up. Each lives in its own module when implemented.
##
## Economy (Prompt 1-2): EconomyService
##   funds: int, axe_tier: "small"/"medium"/"large", workers: Array
##   pay_for_tree(tree_id) / buy_axe(tier) / hire_worker(slot) / pay_wages()
## Timber (Prompt 1-2): TimberService
##   spawn_logs(tree_id, transform) / burn(log_id) at FirePit.add_fuel()
## Timber recovery (Prompt 2): TimberRecoveryService
##   recover_from_water(log_id) using WaterSystem.surface_height_at()
## Clock (Prompt 3): GameClock -> EnvironmentController.set_time_of_day(h)
##   bounded night; morning only after sleeping (see PROJECT_BRIEF.md)
## Horror (Prompt 4+): HorrorDirector
##   exposure, awake_timer; reads SafetyService.query(); never in PREVIEW mode
## Workers (Prompt 5+): anchors in groups worker_bed / worker_seat /
##   worker_spawn / arcade_spot / clutter_zone; HumanCharacter rig API.

const ECONOMY_IMPLEMENTED := false
const HORROR_IMPLEMENTED := false
const CLOCK_IMPLEMENTED := false
