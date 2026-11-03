# Architecture

## Engine pin

- Godot **4.5.1-stable**, renderer **Forward+**, physics **Jolt**. The pin lives in `project.godot`, `.github/workflows/ci.yml` (`GODOT_VERSION`), and here.
- Do not upgrade mid-pack. An upgrade needs a demonstrated need plus a migration pass: re-import, tests, smoke test, and screenshot comparison.

## Units and axes

Meters. **+Y up, +X east, +Z south (toward the landing beach), −Z north (forest entrance).** Characters face −Z, and their left is −X.

## Modules (ownership)

| Area | Script(s) | Owns |
|---|---|---|
| Autoloads | `core/game.gd` (Game), `core/settings.gd` (Settings), `core/diagnostics.gd` (Diag), `world/world_data.gd` (World) | Mode, shared `world_time`; options plus audio buses; error log and reports; frozen world data and the elevation/water/mask query API |
| World generation | `world/world_config.gd` + `config/world_config.tres`, `world/island_generator.gd`, `tools/generate_world.gd` | Authored island description, then deterministic data in `data/world/` |
| Terrain | `world/terrain_system.gd`, `shaders/terrain.gdshader` | Chunked GPU-displaced terrain, 3 LODs with skirts, `HeightMapShape3D` collision from the same samples |
| Water | `water/water_system.gd`, `shaders/ocean.gdshader`, `shaders/inland_water.gdshader`, `shaders/include/*` | Ocean (Gerstner), swash/foam, river ribbon, ponds, ripple pool, CPU wave mirror, depth queries |
| Bridges | `world/bridge_builder.gd` | Walkable crossings at reserved sites |
| Vegetation | `vegetation/tree_builder.gd`, `vegetation/vegetation_system.gd`, `vegetation/ground_cover.gd`, `vegetation/rock_builder.gd` | Tree meshes; per-chunk MultiMesh LODs; collision streaming; removal by ID; ground-cover streaming; rocks |
| Camp | `camp/camp_layout.gd` (single source of placement), `camp/camp_builder.gd`, `camp/fire_pit.gd`, `camp/camp_lamp.gd`, `camp/interior_zone.gd`, `camp/build_kit.gd` | Fence, lamps, burn pit, camper, cabin, tool area, anchors, interior zones |
| Lighting | `lighting/environment_controller.gd`, `lighting/lighting_preset.gd`, `config/lighting/*.tres`, `shaders/sky.gdshader` | Sun/moon/sky/ambient/fog/exposure/wind/post; keyframe blending by hour |
| Audio | `audio/ambient_audio.gd`, `tools/generate_audio.gd` | Emitter pools, zone filtering, footsteps; generated placeholder sounds |
| Player and UI | `player/player.gd`, `ui/*` | Controller, HUD, pause/settings, Preview Tour, benchmark, title |
| Characters | `characters/*` | Human and dog rigs, clip generation, preview scene, camp dog |
| Systems | `systems/safety_service.gd`, `systems/later_interfaces.gd`, `save/save_service.gd` | Authoritative safety; documented future interfaces; versioned saves |

| Logging (Phase 1) | `logging/tree_service.gd`, `logging/tree_actor.gd`, `logging/tree_work_config.gd` + `config/tree_work.tres`, `logging/logging_fx.gd`, `logging/logging_test.gd` | Tree states, work, TreeFelled, actor handoff, notch/fall/stump, pooled sounds/particles |
| Player tools | `player/axe_controller.gd`, `player/view_model.gd` | Swing state machine, contact-timed probe, first-person arms + axe |
| Placement | `systems/placement_validator.gd` | Grounding audit, cutting stands |
| Campaign data | `systems/campaign_rules.gd`, `crew/*`, `config/traits/*.tres` | Fixed contract numbers, trait/employee data (no behaviour yet) |
| Reservations | `camp/camp_reservations.gd` | Camera mounts, footprints, dock |
| Timber (Phase 2) | `logging/timber_service.gd` (ledger), `logging/timber_body.gd`, `logging/timber_mesh.gd`, `logging/timber_recovery.gd` | Partition, exact shares, segment states/ownership, bucking, receipts, burn queue, recovery, reconciliation |
| Carrying (Phase 2) | `player/carry_controller.gd` | Hand load presentation, pick up / set down / drop / deliver, put-down validation |
| Delivery and fire (Phase 2) | `camp/delivery_rack.gd`, `camp/fire_pit.gd`, `shaders/burning_log.gdshader`, `shaders/end_grain.gdshader` | Acceptance at camp, staged queue display, fuel-driven fire |
| Surf | `water/surf_system.gd`, `shaders/surf.gdshader` | Breaking-wave ribbons along the breaking-depth contour (runtime-derived) |

`world/world.gd` (IslandWorld) builds everything in order and registers services on `Game`.

## Frozen world layout

- The generator is deterministic. It uses `FastNoiseLite` with fixed seeds, integer hashing, and output quantized to 1 cm / 1 mm.
- Its output is **committed** in `data/world/` as zstd-compressed binaries plus `manifest.json` (seed, generation version, config fingerprint, content hashes, measured stats) and `layout.json` (river samples, ponds, bridges, shore audio points).
- The runtime only loads this data. CI regenerates it in memory and fails if any hash differs. Cosmetic code edits therefore can never silently move trees.
- To change the island intentionally:
  1. Edit `config/world_config.tres` or the generator.
  2. Bump `generation_version`.
  3. Regenerate.
  4. Accept that save files store felled tree IDs against the old version. A migration is required before shipping.
- **Tree records:** `id` (stable, sorted by vegetation chunk then z/x), `species` (0 pine, 1 spruce, 2 birch), `variant`, `chunk` (128 m cells), `x`, `z` (height comes from the elevation service), `rot`, `height`, `radius`, `lean_x`/`lean_z`, `logs` (future wood budget), `seed`.
- **Elevation service:** `World.height_at(x, z)` is triangle-exact against the LOD0 mesh (diagonal `(i,j)-(i+1,j+1)`). Rendering, collision, tree placement, water depth, footsteps and future logging all use it.

## Water regions

- **Ocean:** sea level 0.
- **River:** `layout.json → river.samples` hold x, z, level, width, rapid, arc. Levels are a running minimum of (ground − 1.05 m), with authored riffle steps. They never rise downstream and reach the sea at 0.04 m.
- **Ponds:** each has a fixed level and a closed rim (tested).
- **Region map:** `water_region.bin` marks 0 = ocean/none, 1 = river, 2+ = pond.
- **Shared wave model:** the Gerstner sum lives in `ocean.gdshader`, with a CPU mirror in `WaterSystem.ocean_height_at`. The swash (run-up) function lives in `world_common.gdshaderinc` and is used by both the ocean and the terrain wetness.
- **Reserved:** `WaterSystem.surface_height_at` / `depth_at` serve the future TimberRecoveryService.

## Rendering strategy and limits

- **Indirect light:** sky ambient + SSAO + SSIL (dynamic, nothing baked), with SDFGI on Ultra only. No lightmaps, because the forest is removable.
- **Water reflections:** sky radiance only. Screen-space reflections don't apply to transparent water, and there is no planar reflection.
- **Refraction:** screen texture with a depth guard that rejects samples of anything in front of the water.
- **Trees:** per 128 m chunk MultiMeshes, one per species/variant.
  - Near LOD: alpha-scissored needle/leaf cards, casting shadows.
  - Mid LOD: fewer cards, no shadows.
  - Far LOD: solid silhouettes.
  - Visibility ranges cross-fade the LODs, and chunk nodes sit at chunk centers because ranges are measured from the instance origin.
- **Grass/ferns/bushes:** streamed in 32 m cells within about 96 m.

## Characters

- **Rigid-part articulation, not skinning.** Each body part is a mesh attached to a pivot at an anatomical joint, and overlapping rounded limb ends prevent gaps. No `Skeleton3D`/`Skin`.
- **API** (stable for later AI): `play(name, blend)`, `set_locomotion(speed)`, `attachment("hand_r" | "hand_l" | "log" | "look")`, `bones` dictionary.
- **Clips:** generated in code into an `AnimationLibrary` and played by an `AnimationPlayer` advanced manually each frame, which keeps them frame-rate independent.
  - Human: `idle`, `walk`, `swing` (preview, non-functional).
  - Dog: `idle`, `walk`, `lie`.
  - Walk legs are IK-baked so stance feet stay planted and stride matches the nominal speed (tested).
  - Swing moves an axe along a designed arc and solves both arms to its grips at runtime.
- **In-place convention:** the mover translates at `WALK_NOMINAL_SPEED × playback_scale`.
- **AnimationTree is not used yet.** Crossfades come from `AnimationPlayer` blend times. A state machine can wrap the same clips later without changing the API.

## Safety rules (published = implemented)

`SafetyService.query(point)`:
1. Inside the camper interior zone (`always_safe`) → **safe** (`CAMPER_INTERIOR`), regardless of lamps.
2. Otherwise, inside the camp fence **and** within `safe_radius` of a `CampLamp` whose `working == true` → **safe** (`CAMP_LAMP`).
3. Everything else → **unsafe**.

The fire, flashlights, moonlight, emissive objects and screen brightness are never consulted. Phase 4: the worker cabin and its extension count as protected while a crew member is inside (occupied); otherwise a lamp covers the porch and most of the interior. Lamp positions and radii live in `CampLayout.LAMPS`. Tests cover the camper with every lamp broken, the yard with lamps broken and working, the forest and the beach.

## Anchors for later prompts

Marker3D nodes in these groups:
- `worker_bed` (4), `worker_seat` (4), `worker_spawn` (4)
- `arcade_spot` (2), `clutter_zone` (4), `worker_storage` (4)
- `player_bed`, `dog_bed`
- `shop_counter`, `payroll_anchor`, `burn_pit_load_point`
- `safe_reset`, `player_spawn`, `camp_entrance`
- Axes on the rack are in group `rack_axes`.

## Timber model (Phase 2)

- **Units.** Every original tree owns exactly **1000 mTE** (milli tree-equivalents) and **10,000 cents** of delivery entitlement. Integers only. `TimberService.allocate()` floors each share and gives the remainder to the last share, so three equal shares are 3333/3333/3334 and every tree sums exactly.
- **Partition** (`TimberService.partition(idx)`) is a pure function of the frozen tree record. The merchantable trunk runs from the cut (0.75 m) to where the diameter drops below 12 cm (and at most 82 % of the height). It is split into 3–12 equal-length segments, adding segments until no share exceeds one hand load (333 mTE). Shares are weighted by frustum volume, so the butt log is worth more than the top log. The crown/branch top is **non-payable brush**, as are chips and the stump. They are tracked as residue, never as a missing share.
- **IDs.** `T<tree id>_S<k>`, stable across loads. Never array positions.
- **States.** `ATTACHED` (part of a multi-segment run), `WORLD`, `CARRIED`, `VEHICLE_RESERVED` (Prompt 5), `ACCEPTED_QUEUED`, `BURNING`, `CONSUMED`. Partial cuts are boundary work values on the record (the prompt's "cut pending").
- **One owner per segment.** A segment is in exactly one place: one TimberBody, the player's hands, the queue or the pit. Consumed segments are nowhere. Transitions update the record before visuals change, and retries are idempotent. Tests check this invariant after every step.
- **Bucking.** Axe contacts on a resting body near an orange mark (within 0.75 m) add work to that boundary. The same work per contact as felling is used, so hold-to-chop cadence is identical. Separation is one synchronous transaction. The crown part (or the longer part) keeps its pose, the other part simulates briefly then freezes. Any part without support is woken.
- **Physics.** Resting bodies are frozen (static). Only freshly cut, dropped or recovered pieces simulate, for at most 9 s. Removing a piece wakes unsupported neighbours, so nothing hangs in the air.
- **Recovery** (`TimberRecovery`). Reason codes are `invalid_pose`, `out_of_bounds`, `below_terrain` and `deep_water`. A piece moves to the nearest dry, gentle, clear ground (spiral search ≤ 60 m), else to the camp recovery point. Identity, share and receipts are preserved. Each recovery is logged with from/to. It never pays and never moves the player or vehicles.
- **Acceptance.** `TimberService.accept(sids, source)` is the only place a receipt (`RCPT-000001`…) is created. It is idempotent per segment. The rack, future workers and future trucks all call it, and no camera ray or held mesh is required.
- **Burning.** The pit holds three pieces. A one-third piece burns in 240 s, faster when a backlog is waiting (up to ×4). Pause stops burning. The overnight advance is a bounded `OVERNIGHT_BURN_SECONDS` (3600 s of game time), never OS time. The contract counts *accepted* timber (`tree_delivered`); ash cleanup (`ash_clean`) is separate.

## Campaign, money and saves (Phase 3)

**Authoritative values**
- 30 workdays. Each day has 900 s of daylight and 300 s of dusk; night starts at t = 1200.
- The contract closes at the end of day 30's dusk.
- $100.00 (10,000 cents) per original tree, split across its logs and credited when each log is accepted at camp.
- Wages are $300 per active employee-day. Arrears are due at the end of the following workday, including that day's wage.
- Axes: small 1.00, medium 1.40, large 1.96. Hard-working applies ×1.25 once.
- Provisional values live in `config/economy.tres`: starting cash $2,000, medium axe $1,500, large axe $4,500, hire $1,000, truck $9,000 unlocked at 50 delivered tree-equivalents, at most 2 trucks.

| Module | Owns |
|---|---|
| `campaign/workday_clock.gd` (WorkdayClock) | The single campaign clock: day, t, phase, warnings (dusk start, reminder, final), schedule hooks, `time_until_night()`, bounded night with separate `night_exposure`, the deadline signal. It advances in `_physics_process`, so it is frame-rate independent and pausing stops it. |
| `campaign/contract_service.gd` (ContractService) | Manifest-based progress counts, evaluation after state changes and deliveries, the deferred deadline evaluation, outcome commit with id, and the acceptance gate. |
| `economy/wallet.gd` (Wallet) | The only payment service: integer cents, a transaction ledger, idempotent `credit_receipt()`, `reconcile_receipts()` for recovery and migration, and no negative cash. |
| `economy/payroll.gd` (Payroll) | Employee identities, liabilities with due days, idempotent per-day settlement, oldest-first auto-pay, manual pay, and one QuitDueToArrears request per employee. |
| `economy/equipment.gd` (Equipment) | Owned axe instances (`AXE-0001`…) with one owner each, receipted purchases and equip-by-ownership. The starting small axe can never be lost. |
| `campaign/campaign_service.gd` (CampaignService) | Wires all of the above, drives lighting from the clock, keeps day stats, runs the sleep → settlement → overnight burn → report → morning sequence, handles the legacy rule choice, and captures/restores saves. |
| `ui/campaign_ui.gd`, `ui/day_test_panel.gd`, `campaign/sleep_spot.gd`, `campaign/tool_shop.gd` | Clock/cash HUD, journal (J), shop, daily report, rules choice, outcome screens and the review route. |

**Deadline ordering.** The clock emits `deadline_reached` inside the physics step where t reaches 1200 on day 30. ContractService evaluates at the end of that frame, so an acceptance committed in the same frame (timestamped at the deadline) counts. After the outcome commits, `TimberService.accept()` is gated closed and later transactions are refused. Outcomes (`OUT-FULFILLED-D30` / `OUT-ABANDON-D30`) are saved and never change. Burning backlog does not affect success. Sleeping on day 30 closes the contract instead of starting day 31.

**Crew status.** Payroll records exist for the two starting employees (Marta Kell, Dale Ostrow) with reserved small axes. Until Phase 4 gives them bodies and work, they are `pending_integration`: never charged, and labeled as such in the journal and report. The Day & Economy Test switches them to `active` as development fixtures.

**Feasibility.** The manifest has 12,000 trees, so 30 days would need about 400 trees a day. Measured solo throughput is a handful of trees per 15-minute day. The count stays provisional until crew (Phase 4) and truck (Phase 5) throughput is measured. Nothing was removed and the day was not lengthened.

**Integration for later phases.**
- Workers call `TimberService.claim/accept` and appear in `Payroll.employees`; status becomes `active` on arrival.
- `Payroll.quit_due_to_arrears` drives departure.
- Trucks use `reserve_for_vehicle` + `accept(sids, "truck:<id>")`.
- Horror reads `WorkdayClock.night_exposure`.
- `SleepSpot.blocked_reason` is the state guard for the once-only dog rescue.
- `ContractService.ABANDONMENT` hands off to the Phase 6 hunt; until then an honest handoff screen keeps the save.

## The crew (Phase 4)

| Module | Owns |
|---|---|
| `crew/crew_service.gd` (CrewService) | The roster and employment states: `pending_arrival → active → departing → departed`. Records live in `Payroll.employees`, the single ledger, and identities are never deleted. Also: hiring (five maximum, counting arrivals and departures until they have left), beds 1–6, axes issued and returned, firing and quitting, the service dock and skiff, job selection with exclusive task claims, return-before-night planning, local perception of stimuli, story sharing between colleagues, doors, and save/restore. |
| `crew/worker.gd` (Worker) | One visible person: kinematic movement along navigation paths on the real walking surface, local steering around trunks and people, stuck detection (real versus expected displacement) with bounded escape and repath, then job release. Physical actions: felling through `TreeService.apply_contact` with retreat and fall-watching, bucking through `TimberService.apply_cut`, hauling through `pick_up_for` / `accept`, following, sitting, sleeping in their bed, and departing by boat. |
| `crew/worker_mind.gd` (WorkerMind) | Traits, fear (five states with hysteresis), belief, trust, a capped memory of what they perceived, reassurance with cooldown and diminishing returns, and warning before quitting. |
| `crew/crew_nav.gd` (CrewNav) | A 3 m island A* grid (water, slope, rocks, trees, logs, fence, gates, dock deck) and a 0.5 m camp grid rasterised from collision (walls, furniture, doors walkable, floor heights; the camper is private). |
| `crew/crew_dialogue.gd` | Original captioned lines with trait variants and no back-to-back repeats. |
| `ui/campaign_ui.gd` (Crew tab, talk, fire confirmation), `ui/crew_demo_panel.gd` | Roster, orders, hiring, conversations, the review route. |

**Rules in code.**
- **Wages.** A person earns $300 for each day they were employed during daylight (`worked_days`). A firing or quit before the night still pays that day. Arrears and grace stay in Payroll, and a fired or departed person remains owed what they earned.
- **Starting crew.** The same two Phase 3 identities (EMP-01 Marta Kell: hard-working, sociable; EMP-02 Dale Ostrow: stronger, skeptical) are activated exactly once, each with their reserved small axe and a bed. Phase 3 saves activate them on load with no back-charged wages.
- **Work rate and carrying.** Work per contact uses `TreeWorkConfig.work_per_contact(tier, hard_working)`, so Hard-working applies once. Carry budget is 333 mTE, or 500 for Stronger. Truck capacity is unchanged.
- **Automatic job priority.** Carry loose logs (when there are three or more), then buck waiting trunks, then carry any remaining logs. Fell only when nothing is waiting.
- **Return before night.** A worker heads home when the time left is less than return time plus margin. Return time is path length divided by walking speed (slower when carrying), plus 12 s for doors and 8 s to set a load down. The margin is 45 s, plus 60 s if timid and more if frightened. Workers warn once, then return, then refuse late orders. The Day & Economy clock acceleration is accounted for.
- **Perception.** Stimuli are events with a position, modality, loudness and severity. Each worker checks distance, occlusion, facing (for sight), sleep and the observant bonus. Ordinary sounds are never evidence, and each worker stores one memory per event. Boss reports are rumour unless a nearby colleague witnessed something firsthand.
- **Safety.** The worker cabin and extension are protected while a crew member is inside (`SafetyService`, `CABIN_OCCUPIED`).

**Hooks for Phase 5/6.**
- `CrewService.emit_stimulus()` is the director's entry point.
- `WorkerMind` states drive refusal, warning and quitting.
- `SleepSpot.blocked_reason` guards the dog-rescue exception.
- Trucks will use `TimberService.reserve_for_vehicle` / `accept(sids, "truck:<id>")`. The reliable-driver trait is data only, not a tested driving skill.
- Departed identities keep appearance seed, name and memories so later phases can imitate them, never revive them.

## Modes and saves

- `Game.Mode`: `MENU`, `CAMPAIGN`, `PREVIEW`. Preview Tour, the Character Preview and the benchmark run in PREVIEW, and `SaveService.save_campaign` refuses to write in any mode except CAMPAIGN (tested).
- **Save schema v5** (Phase 4) adds `campaign.crew`: worker positions and sleep/departure state, minds (traits, fear, belief, trust, memories, cooldowns), candidates and counters, skiff state, per-worker stats and the stuck log. Worker hand loads live in `timber.loads` (one owner per piece). Employee records (status, bed, look seed, job, focus, worked days, departure reason) stay in `economy.payroll.employees`. Loading never duplicates a person: one Worker per active or departing record, and an invalid saved position is repaired to the porch. v4 saves activate their pending starting crew exactly once.
- **Save schema v4** (Phase 3) uses three slots, `user://saves/slot_N.json`. Settings stay separate, and the old single `campaign.json` becomes slot 1 while the original file is kept. v4 fills the `campaign` block: rule set, `phase3` flag, clock (day, t, night exposure, fired warnings, deadline flag), contract state and outcome id, day stats and the last 35 reports. It also fills the `economy` block: wallet cash, full transaction ledger, receipt→transaction map, payroll employees, liabilities, settlements and quit requests, owned axes and the equipped axe. On load the wallet re-checks every receipt: a genuine receipt without a credit is credited once, and a credited one is never paid again. v3 (Phase 2) saves migrate as *pre-contract*. Their tracked receipts are credited once (`migrated_phase2_delivery`), an untouched `.pre_contract.json` copy is kept, and the player chooses either legacy continuation (days pass, no deadline) or the 30-day contract from day 1 with the island kept. Phase 0–2 never paid whole-tree bounties, so there is no historical payment to protect.
- **Save schema v3** (Phase 2) adds the `timber` block. It holds per-tree segment state, receipt id and burn progress, boundary/crown cut work, world bodies (tree, segments, crown flag, pose), carried bundle, queue order, pit contents, all receipts, the receipt counter and the recent recovery log. Geometry and shares are always rebuilt from the frozen tree record, so a save can never change quantities. On load the ledger is restored before trees: an accepted segment can never reappear as world timber, and a carried bundle returns to the hands exactly once. v2 saves migrate by adopting their fallen trunks into fresh timber records.
- **Save schema v2** (Phase 1) adds `trees` (modified trees by ID: state, work, cut side, fall direction, felled guard, trunk pose/velocity), `equipment`, and reserved `campaign` / `economy` / `timber` blocks. v1 saves migrate to a labeled **legacy** campaign. Saving keeps the previous good file as `.bak`; an unreadable main save falls back to the backup and is left on disk.
- **Save schema v1** (Phase 0) (`user://saves/campaign.json`, written atomically through a `.tmp` + rename):

```json
{
  "schema": 1,
  "world": {"seed": 20261103, "generation_version": 1},
  "player": {"position": [x, y, z], "yaw": 0.0},
  "time_of_day": 13.0,
  "felled_trees": [ids...],
  "economy": {"funds": 0, "axe_tier": "small", "workers": []},
  "timber": {"logs": [], "burned": 0},
  "horror": {"exposure": 0.0},
  "build": "0.0.1-phase0 (commit)"
}
```

Migration lives in `SaveService.migrate`: v0 dev saves are upgraded, and future schemas are rejected (an empty result is treated as "no save").
