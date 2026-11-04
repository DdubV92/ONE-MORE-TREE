# Time, pause and state ownership (Phase 9)

UI screens only *request* transitions; the authoritative services own them: `WorkdayClock` (time), `ContractService` (fulfilled/abandonment, decided once in `_commit`), `CampaignService.sleep` (one settlement per night, locked against double input), `Payroll` (wages by original due day), `HuntService` (continuous survival clock, extraction), `DogRescue` (once-only rescue). Reloading never replays a settlement, an outcome, the wind-door rescue or a ship arrival.

## What each surface does to time

| Surface | Simulation | Notes |
|---|---|---|
| Pause menu (Esc), Settings, Help | **Paused** (`get_tree().paused`) | Freezes the clock, crew, trucks, physics, night escalation (`NightThreat`), the director's cooldowns, dog rescue timers, weather and the hunt clock. Resume has no catch-up burst (timers use frame deltas; nothing accumulates while paused). Tested. |
| Journal and other management screens (shop, hire, fire, reports) | **Paused** | Same as the pause menu. Stated in Help. |
| Mandatory rule cards (night rules, rules summary, abandonment rules, leave-behind choice) | **Paused** until acknowledged | The first attack can't resolve behind a text wall. |
| Arcade cabinets | **Paused** | Quitting restores the camera, cursor and input state; queued timers don't burst. |
| Couch and TV (quad, focus, entertainment) | **Live** | The day, the crew and the night keep running. Focus never moves your body or changes safety. |
| Talking to a worker | **Live** | The worker stops to face you. Walk away or Esc ends it. |
| Hiding (hunt) | **Live** | Hiding is not invulnerability. |
| Driving | **Live** | |
| Sleep | One transition | Allowed from dusk (contract). It settles the night once (wages, report, morning checkpoint) and starts the next morning. It never skips more than one night. Blocked while Biscuit is out (the reason and the assist time are shown). |
| Waiting indoors at night | Live, bounded | The displayed clock stops at night. Awake unease can keep rising, but waiting never brings dawn. The camper stays absolutely safe during the contract. |
| Contract close (end of day 30's dusk) | One transition | `ContractService._close_deadline` decides FULFILLED vs ABANDONMENT once; a completion transaction at or before the boundary wins. The clock stops. |
| Completion summary | Paused | Return to Menu (save kept) or Keep exploring. |
| Post-contract exploring | No clock | Saved as `campaign.post_contract`. No workdays, wages, night, director or hunt. The completed summary is in Journal → Contract. |
| Hunt (days 31–35) | Continuous | Beds don't skip time. Loading restores the actual elapsed hunt clock, evidence and life states (no offline progress). |
| Rescue ship docked | Live, 8-minute boarding window | Leaving staff behind needs a deliberate, named confirmation (paused while you decide). The dog boards automatically, once. |
| End cards (caught, dead, survived/stranded) | Paused | Saves are blocked while a dead or caught state is shown. Checkpoints offer an explained rollback. |

## Save fields added in Phase 9 (schema stays v8, additive)

- `campaign.onboarding`: `done` steps, `skipped`, `night_rules_ack`, once-only `milestones` (e.g. `final_tree`), `version`. Saves without it (all earlier ones) load with the guide finished and the night rules acknowledged.
- `campaign.post_contract`: the completed contract is being explored.

Settings (not campaign saves) gain `ui_scale`, `captions`, `subtitles`, `hints`, `highlight`, `binds` (remapped keys).
