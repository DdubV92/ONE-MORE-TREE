# Phase checklist

## Phase 4: The living crew

Status key: ✅ implemented and observed (test or headless sim) · 🟡 implemented, needs live review · ⬜ later phase.

| Item | Status | Notes |
|---|---|---|
| Cabin extension: two-bed bedroom, kitchen, bathroom (toilet, sink, shower), grounded foundation, doorway; six beds with unique indices | ✅ / 🟡 | Rendered and checked; circulation needs live review |
| Two starting employees (same Phase 3 identities, activated once), seeded original looks, traits, small axes, beds | ✅ | Migration is idempotent (tested) |
| Roster states pending_arrival → active → departing → departed; five maximum counting arrivals and departures | ✅ | Tested |
| Hiring from a seeded candidate pool (fee once, new ids only), arrival by daylight skiff at a minimal service dock | ✅ / 🟡 | Boat and dock are simple originals, tagged for Phase 5 polish |
| Firing with a confirmation (wages owed, gear returned, jobs cancelled, logs set down, real walk to the boat) | ✅ / 🟡 | Worked-day wage kept (tested) |
| Quitting from unpaid wages (Payroll) or fear (after a warning) through the same departure | ✅ | |
| Navigation: 3 m island A* (water, slope, rocks, trees, logs, fence gates, dock) and 0.5 m camp grid rasterised from collision (doors, floors, private camper) | ✅ | Built in about 0.8 s |
| Physical jobs through the shared APIs: felling with retreat, bucking, hauling with visible loads, rack queue, automatic bottleneck priority, follow, return home | ✅ / 🟡 | Headless shifts below; animation needs live review |
| Exclusive claims (trees, trunks, pieces, rack places, seats); worker, worker and player contest | ✅ | Tested through `pick_up_for` / claims |
| Hard-working ×1.25 once; Stronger 500 mTE hand budget; four-piece visible cap for workers | ✅ | Tested |
| Return before night: route time, load, doors, margin (timid earlier); warn → return → refuse late orders; mid-task re-checks | ✅ | All five in bed at nightfall in the 5-worker shift |
| Stuck detection with bounded escape and repath, then job release; unreachable targets skipped until morning; stuck log | ✅ | 9–11 recovered events per shift, logged for repair |
| Minds: traits change behaviour (fear sensitivity, margins, carry, rate, belief gain, reassurance, perception range) | ✅ | Tested |
| Local perception (distance, occlusion, facing, sleep, observant) and firsthand vs rumour evidence; story sharing between colleagues | ✅ / 🟡 | Development stimuli only |
| Fear with hysteresis, diminishing repeats, reassurance cooldown, warning before quitting | ✅ | Tested |
| Dialogue: 60+ original captioned lines with trait variants, no back-to-back repeats; branching talk panel | ✅ / 🟡 | |
| Crew tab (roster, jobs, work-near-me, hire, fire) and Crew Demonstration route | 🟡 | |
| Occupied worker cabin counts as protected at night | ✅ | `SafetyService` |
| Save v5 (crew block, worker loads); reload without duplicates | ✅ | Tested |
| Trucks, drivers, TV and cameras (Phase 5); Terrors and Foreman hunt (Phase 6) | ⬜ | Hooks only |

### Crew shift measurements (headless, `tools/crew_sim.tscn`, one full 20-minute day, small axes)

| Crew | Trees felled | Bucking cuts | Delivered (tree-eq) | Paid | Walking time | Axe-swinging time | Stuck events (recovered) | In bed at nightfall | Ownership ledger |
|---|---|---|---|---|---|---|---|---|---|
| 2 | 5 | 38 | 3.00 | $300.00 | 1915 s | 154 s | 9 | 2 / 2 | consistent |
| 5 | 9 | 61 | 4.65 | $464.32 | 4751 s | 252 s | 11 | 5 / 5 | consistent |

These are honest numbers. Hand hauling dominates the day: workers spend about 90 % of their time walking (logs to the rack and back), so a five-person crew delivers roughly 4.6 tree-equivalents (about $460) a day against $1,500 of wages. The 30-day contract (about 400 trees a day) is not feasible with hand crews. Phase 5 trucks (three tree-equivalents per load) are the designed answer, and the workload will only be judged once trucks are measured.

## Graphics pass 3 and nights (user request after Phase 3)

| Item | Status | Notes |
|---|---|---|
| Moon phases: 29.5-day cycle (full moon on day 4, new moon around day 19); moonlight, night ambient, stars and the sky disc follow the visible fraction | ✅ / 🟡 | Preview: F4 moon slider, Tour "Dark night" / "Full moon" |
| Night visibility: dark mist that thickens on moonless nights (things fade to black within a few dozen metres; a full moon lets you see silhouettes at 100–200 m) | 🟡 | Software-rendered comparisons in the session; judge on a real monitor |
| Low ground mist that follows the terrain under the camera; volumetric night mist with lamp halos (High/Ultra) | 🟡 | |
| Moonlight vision grade: desaturated, cooler, higher contrast at night; warm lamp pools and lit interiors stand out | 🟡 | |
| Tonemapper option: Filmic (default) or AgX with contrast, saturation and exposure compensation | ✅ | AgX compared side by side: deeper shadows but muddier sunsets, so Filmic stays the default |
| Upscaler option: FSR 2 (temporal), FSR 1 or bilinear, used when render scale < 100 % | ✅ | TAA + FXAA and soft shadows (quality 3) were already on |
| Interior reflection probes (camper, cabin), rendered once | ✅ | |
| SDFGI | ✅ (Ultra) | Kept off on High for the 60 FPS mid-range target. Lightmaps are not used because every tree can be felled. |
| Reference video | ⬜ | Videos cannot be watched from this environment; the written tips were applied |

## Phase 3: Workdays, the thirty-day contract, delivery income, payroll, axes and saves

Status key: ✅ implemented and observed (headless test) · 🟡 implemented, needs live review · ⬜ absent / later phase.

| Item | Status | Notes |
|---|---|---|
| One authoritative clock (900 s daylight, 300 s dusk, night at 1200) driving lighting, HUD, warnings, hooks and the deadline | ✅ | `WorkdayClock`. Boundaries at 899.9/900/1199.9/1200 are tested, and steps of 1/23, 1/60, 1/144 and 7.3 s each give exactly one event per boundary |
| Dusk warnings: main warning, reminder, final warning, all as on-screen text | ✅ / 🟡 | Text and countdown never rely on colour; the lighting transition needs live review |
| Pause and focus loss freeze the simulation; the night is bounded and never creates morning | ✅ | Tested: no time passes while paused, and 10,000 s of night stays day N |
| `time_until_night()`, `schedule()` hooks and separate `night_exposure` | ✅ | Used by Phase 4/6 |
| Contract closes at the end of day 30's dusk without sleep; sleeping on day 30 closes it instead of starting day 31 | ✅ | Tested |
| Completion: no standing original trees, no stumps, all timber accepted, no orphan records (manifest-based counts) | ✅ | Stump removal (chop the stump out) was added for this |
| Final-frame ordering, deferred evaluation, closed acceptance gate, persisted outcome id | ✅ | Tested: an on-time final delivery wins, a late delivery is refused, and outcomes never flip |
| Wallet: integer cents, one subscriber, idempotent per receipt, credited at acceptance, never negative | ✅ | Tested, including a retry and reconciliation after reload |
| Phase 2 receipts migrated once with a marker; untimed saves get an explicit legacy/new-rules choice with a backup | ✅ | `.pre_contract.json` copy is kept |
| Payroll: $300 liabilities per active employee-day, one-day grace including the next day's wage, oldest-first auto-pay, manual pay, one quit request | ✅ | Day 7/8 example tested |
| Starting crew records (2) and reserved axes; not charged until Phase 4 brings them | ✅ | Labeled "arrives in Phase 4" everywhere. Fixtures in the Day & Economy Test |
| Axe shop at the tool rack: owned instances, receipts, affordability, payroll warning, equip by ownership | ✅ / 🟡 | Tested logic; UI needs live review |
| Hire and truck entries locked with honest Phase 4/5 notes, including the 50 tree-eq milestone progress | ✅ | |
| Camper bed sleep (whole mattress is the target), one settlement, bounded overnight burn, report, morning beside the bed | ✅ / 🟡 | Tested logic; staging needs live review |
| Daily report: cash reconciliation, felled, remaining, delivered, purchases, wages, arrears with due days, contract status | ✅ | Reconciliation tested; reopenable from the journal |
| HUD: day, phase, countdown, cash, wages owed; journal (J); delivery notices | 🟡 | |
| Save v4 with three slots, atomic write + backup, corrupt fallback, separate settings, slot summaries on the title screen | ✅ / 🟡 | Slot UI needs live review |
| Day & Economy Test route (in memory): speed, jumps, sleep, day 30, prepared win/loss, fixtures | ✅ / 🟡 | Never writes files; seed and tree count unchanged (tested) |
| Fulfilled screen; failure → honest Phase 6 handoff screen (save kept) | ✅ | The hunt itself is Phase 6 ⬜ |
| Employees with bodies, dialogue, firing (Phase 4); trucks, dock, TV, cameras (Phase 5); Terrors and hunt (Phase 6) | ⬜ | Not claimed |

**Feasibility (honest).** The manifest holds 12,000 trees, so a 30-day clearance needs about 400 trees a day. Measured solo pace is roughly one tree every 2–3 minutes of real work (felling 10–30 s, bucking 20–40 s, four hand-load trips), or about 5–7 trees per 15-minute day. The count is provisional until crew and truck throughput are measured in Phases 4–5. No trees were removed and the day was not lengthened.

**Economy check (provisional prices).** A solo day earns about $500–700, so the medium axe ($1,500) takes about two to three days of deliveries. Two active workers would cost $600 a day, so the crew must be productive to break even. These are review values in `config/economy.tres`.

## Phase 2: Fallen timber, bucking, carrying, delivery and the burn pit

Status key: ✅ implemented and observed (headless test or sim) · 🟡 implemented, needs live/visual review on a real GPU · ⬜ absent.

| Item | Status | Notes |
|---|---|---|
| Timber record per felled tree (same tree ID; species, dimensions, partition, cut progress, poses) | ✅ | `TimberService`; built when the trunk settles (tree state SECTIONED) |
| Exact units: 1000 mTE and 10,000 cents per tree, deterministic remainder | ✅ | `allocate()`: 3333/3333/3334, nine-piece and unequal shares tested; every 37th island tree checked |
| Stable segment IDs `T<tree>_S<k>`, legal states, one owner per segment | ✅ | Ownership invariant asserted after every step of the ledger test |
| 3–12 segments sized so no piece exceeds one hand load (1/3 tree-eq) | ✅ | Large trunks get more, shorter pieces |
| Visible bucking marks, V-groove progress, end-grain caps both sides | 🟡 | Paint rings at uncut boundaries; caps wound to face outward (checked analytically); judge close-up on a real GPU |
| Cut only when resting ("Settling..." cue); same work per contact as felling | ✅ | Hold-to-chop cadence unchanged (shared swing clock) |
| Crown/branches = non-payable brush that sinks away; chips/stump non-payable | ✅ | Explicit in the reconciliation report |
| Partial cuts persist; separation is one synchronous transaction | ✅ | Tested through save/restore |
| Carry: shoulder load, gloves on the log, axe stowed, bounded speed (−25 % max), no jump above half load | 🟡 | Comfort needs live review |
| Pick up (E) / add to bundle / set down (G, validated) / drop all (X) / deliver (E at rack) | ✅ / 🟡 | Logic tested; feel needs review |
| Put-down validation: reachable, line of sight, slope, water depth, fire hot zone, clearance | ✅ | Keeps ownership with a reason if no spot is valid |
| Load pulls back from walls (no deep clipping); no physics body carried | ✅ | |
| Frozen resting bodies; brief bounded simulation after cuts/drops; unsupported pieces woken | ✅ | 0 floating pieces in all sims |
| TimberRecovery with reason codes; preserves identity/receipts; never pays | ✅ | Buried-piece case tested |
| Delivery rack beside the pit; acceptance is the only receipt source; idempotent | ✅ | Retried acceptance: 0 new receipts (tested) |
| Staged queue: 12 visible pieces, honest meter and sign for the full backlog | ✅ | |
| Fire driven by actual fuel: flames, light, embers, smoke, haze, crackle; 3 charring logs; coals relight automatically | 🟡 | Logic observed; look/sound need review |
| Pause stops burning; bounded overnight advance (3600 s game time) | ✅ | Tested |
| Contract delivery (`tree_delivered`) separate from ash cleanup (`ash_clean`) | ✅ | Tested |
| Save v3: timber block; carried bundle restores once; accepted never respawns; consumed stays consumed | ✅ | Tested |
| Reconciliation report per tree (F2 ledger) | ✅ | |
| Logging Loop preview stop + reset + in-memory snapshot/restore | ✅ | Preview never writes files |
| 50-tree stress fixture | ✅ | `tools/timber_stress.tscn`, see below |
| Hooks: claim/release, reserve_for_vehicle, accept(source), standpoints, truck drop-off, recovery point | ✅ | Behaviour arrives with workers (Phase 4) and trucks (Phase 5) |
| Dock dog-refuge anchors (refuge, shelter footprint, water-edge bounds, ship boarding) | ✅ | Anchors only (Phase 5/6) |
| Surf: curling breakers + bigger swell (user request) | 🟡 | Software-rendered screenshots; review on a GPU |

### Logging loop measurements (headless physics, real island trees, `tools/timber_sim.tscn`)

| Case | Species | Trunk Ø | Pieces | Bucking contacts (small axe) | Bucking time | Hand trips | Floating | Reload identical | Retry receipts | Reconciles to $100.00 |
|---|---|---|---|---|---|---|---|---|---|---|
| camp edge | pine | 0.65 m | 10 | 26 | 24.7 s | 4 | 0 | yes | 0 | yes |
| slope | pine | 0.61 m | 10 | 24 | 22.8 s | 4 | 0 | yes | 0 | yes |
| rock | pine | 0.56 m | 10 | 24 | 22.8 s | 4 | 0 | yes | 0 | yes |
| small | birch | 0.29 m | 5 | 9 | 8.5 s | 4 | 0 | yes | 0 | yes |
| large | pine | 1.05 m | 12 | 57 | 54.2 s | 4 | 0 | yes | 0 | yes |

### 50-tree stress fixture (`tools/timber_stress.tscn`, headless)

| Measure | Result |
|---|---|
| Trees felled and handed to the ledger | 50 / 50 |
| Timber pieces in the world | 557 (all frozen: 557; physics-active objects: 0) |
| Floating pieces | 0 |
| Recoveries (genuinely inaccessible pieces) | 9 |
| Physics / process time with the full pile (headless CPU) | 9.37 ms / 1.75 ms per frame |
| Extra nodes / static memory | +2102 nodes / +22.7 MB |
| Queue after delivering every loose piece | 556 pieces = 49.674 tree-eq (rack shows 12, meter/sign report all) |
| Conservation | every tree reconciles: True; entitlement $4,967 |
| Cleanup | 0 bodies left; +196 nodes are brush residue that sinks away after about a minute |

Honest notes: 0.33 tree-equivalent of one trunk was still being bucked or settling when delivery was measured, so the total queued is 49.67 rather than 50 (conservation still holds). The headless timings are on a CPU-only container and say nothing about a real desktop.

## Phase 1: The axe, a grounded island, and convincing falling trees

| Item | Status | Notes |
|---|---|---|
| Grounding audit (PlacementValidator) of all 12,000 tree bases and 598 rocks | ✅ | 475 trees floated on slopes under the old rule (worst 0.25 m, tree 3369); fixed at the source with footprint-minimum bases. Now 0 floating, 0 in water, 0 on rocks, every tree has a cutting stand. Tested. |
| Visible hands and forearms holding a real axe (hatchet / medium / large) | ✅ | Arms are solved onto the handle grips each frame; the small hatchet is one-handed |
| Central interaction arbitration | ✅ | One view-ray probe decides tree / hard surface / miss; trees behind a fence or another trunk are not strikeable. UI clicks never reach the axe (`_unhandled_input` + captured mouse only). |
| Hold-to-chop at the same legal cadence | ✅ | Max one buffered press; tested frame-rate independent (30/60/144/23 Hz) |
| Tree states STANDING → NOTCHED → FALLING → FALLEN (SECTIONED/DISPOSED reserved) | ✅ | Illegal transitions rejected; tested |
| Exactly one TreeFelled per original tree (not a payment) | ✅ | Persisted guard; never re-emitted by restore; tested |
| Single representation handoff (instance ↔ actor), no ghost canopy or collision | ✅ | Tested: 0 instances at the base after notching, 1 actor |
| Work model: species/diameter, tiers 1.00/1.40/1.96, Hard-working ×1.25 once | ✅ | `config/tree_work.tres`, `CampaignRules`; tested (1.25/1.75/2.45) |
| Contact-timed swing (prep, accel, contact, recoil, recover) | ✅ | Damage only at the contact frame |
| Visible notch on the struck side, end-grain wood, chips, creak at 86 % | 🟡 | Rendered on a software GPU; judge close-up on a real GPU |
| Directional fall: away from the chopper, bounded natural lean, hinge phase then rigid body | ✅ | See the measurements below |
| Stump with growth-ring cut face; tracked target (group `stumps`) | ✅ | |
| Settling validation (lift from ground, lower unsupported) with recorded reason | ✅ | All 7 test cases settled "rest" without correction |
| Neighbour canopy flex on impact, impact/crack/rustle audio at the trunk | 🟡 | Implemented; motion and sound need live review |
| Player never pinned (falling trunk ignores the player; push-clear after settle) | ✅ | |
| Save v2: notch, falling (pose + velocity), fallen pose, stump; backup; corrupt fallback; legacy migration | ✅ | Tested |
| Logging Test stop (7 real island trees) | ✅ | Preview Tour → Logging Test / Next test tree |
| Reservations: camper couch + TV, 10 camera mounts (CAM_01–10, 3 on trail rocks), cabin extension footprint, 2 truck bays + turning circle, dock + utility footprint, hiding anchors, campaign state/clock/traits data | ✅ | Locations only; behaviour belongs to Prompts 3–6 |

### Felling measurements (headless physics, real island trees, small axe, 60 Hz)

| Case | Species | Trunk Ø | Work units | Small-axe swings | Chop time | Fall→rest | Settle | Lying angle | Ground penetration | TreeFelled |
|---|---|---|---|---|---|---|---|---|---|---|
| flat | pine | 0.89 m | 22.8 | 23 | 21.4 s | 8.9 s | rest | 88° | 0.00 m | 1 |
| slope | pine | 0.61 m | 11.4 | 12 | 10.9 s | 7.2 s | rest | 86° | 0.00 m | 1 |
| rock | pine | 0.56 m | 9.7 | 10 | 9.0 s | 8.1 s | rest | 91° | 0.00 m | 1 |
| neighbour | pine | 0.70 m | 14.8 | 15 | 13.8 s | 6.6 s | rest | 82° | 0.00 m | 1 |
| small | birch | 0.29 m | 2.4 | 3 | 2.3 s | 5.7 s | rest | 82° | 0.00 m | 1 |
| large | pine | 1.05 m | 30.2 | 31 | 28.9 s | 10.1 s | rest | 78° | 0.00 m | 1 |
| camp_edge | pine | 0.65 m | 13.0 | 13 | 11.9 s | 8.0 s | rest | 84° | 0.00 m | 1 |


Legend: ✅ implemented and checked (test, smoke or render) · 🟡 implemented, only partially verified · ⛔ not done

## Phase 0: Build the island we want to live on

### A. Technical foundation and scale

| Item | Status | Notes |
|---|---|---|
| Godot 4.5.1, Forward+, typed GDScript, meters, +Y up | ✅ | Pinned in project.godot, CI and ARCHITECTURE.md |
| CI: import, determinism, tests, bounded smoke test | ✅ | First run green on GitHub Actions |
| Windows x86_64 export with matching templates, ZIP artifact | ✅ | CI run #1 produced `OneMoreTree-windows-x86_64-phase-0-island-1` (242 MB). Not launched on real Windows by me. |
| No engine binaries or `.godot` cache committed; no Blender dependency | ✅ | |
| Deterministic, idempotent generation; frozen world manifest | ✅ | `--check` verifies hashes in CI |
| Title screen, Preview Tour (Camp, Beach, Forest, River/Pond, Character Preview; Day/Sunset/Night) | ✅ | Plus camper, cabin, shallows, rapids, pond 2, ridge, coast, and a benchmark |
| Standalone character preview (orbit, zoom, playback) | ✅ | |
| Preview never writes saves or alters campaign state | ✅ | Tested |
| Diagnostic report (build, engine, preset, errors, sanitized paths) | ✅ | Tested |
| Exploration controller: pause, mouse capture, sensitivity, collision, slopes, steps, reset-to-safe | ✅ | Bridge/wading bug found by the traversal tool and fixed |
| Island: ~1,600×1,200 m footprint, 0.9–1.2 km² land, ~12,000 trees | ✅ | 1,552×1,060 m, 1.17 km², exactly 12,000 trees |
| Terrain: landing beach, camp approach, rises, rocky ridge, fern lowland, pond basins, river corridor; no cliff ring; no square water edge | ✅ | Ocean mesh runs to a 30 km horizon |
| Elevation service shared by placement, water, physics, footsteps | ✅ | Triangle-exact; tested |

### B. Water

| Item | Status | Notes |
|---|---|---|
| Vertex-displaced Gerstner ocean, LOD tessellation, shared time/wind, CPU height mirror | ✅ | |
| Depth absorption, fresnel, guarded refraction, sky reflections, caustics, restrained glints | 🟡 | Rendered on a software GPU. Needs a real-GPU look. |
| Shoreline swash, broken foam (swash edge, breaking band, rocks, flecks), beach masks | 🟡 | Visible in renders. Motion is best judged live. |
| Wet sand driven by the swash function, with drying lag | 🟡 | Same function as the water. Judge in motion. |
| Two ponds and a downhill river with flow and whitewater at grade changes | ✅ | River/pond invariants tested; renders checked |
| Ripples from wading and the F7 test, pooled and rate-limited | 🟡 | Logic verified headless; visual not captured |
| Wading limit with gentle push-back, no dry-land walls; bridges | ✅ | |
| Timber-recovery interface reserved | ✅ | `WaterSystem.surface_height_at` / `depth_at` |

### C. Woodland and ground

| Item | Status | Notes |
|---|---|---|
| Three species × three variants, stable IDs and metadata | ✅ | |
| Clustered distribution, exclusions (camp, trails, water, bridges, rocks) | ✅ | Tested |
| Instanced chunks, LOD, limited shadows, wind, removal by ID | ✅ | Removal tested |
| Chunk-managed trunk collision | ✅ | |
| Tree inspector (F6) | ✅ | |
| Ground: sand, damp/wet sand, grass, needles, leaf litter, dirt, moss rock, rock, gravel, pebbles, mud; multi-scale anti-tiling | ✅ | |
| Streamed grass, ferns, bushes, reeds, dune grass, pebbles | ✅ | |

### D. Camp

| Item | Status | Notes |
|---|---|---|
| Clearing, ~2 m chain-link fence, wide forest entrance, exterior lamps | ✅ | |
| Camper: kitchen, bathroom (with door), bedroom with player bed, dog bed, woods-facing windows, real entrance | ✅ | |
| Cabin: exactly four beds with storage, table, clutter zones, arcade corner, porch | ✅ | |
| Burn pit: stones, ash, loading approach, particle fire, light, sound, placeholder interaction | ✅ | Prompt 2 adds fuel |
| Tool rack with small/medium/large axes, props, anchors for payroll/shop/workers | ✅ | |

### E. Light, atmosphere, post, sound

| Item | Status | Notes |
|---|---|---|
| Day, sunset, night, overcast, dawn/dusk, and warm-interior blend; time slider | ✅ | |
| Dynamic GI strategy: sky + SSAO + SSIL; SDFGI on Ultra; no lightmaps | ✅ | |
| Tone mapping, bloom, AA (TAA + FXAA), optional DOF, CA (default 0), vignette, grading, separate toggles | ✅ | |
| Local heat haze over the fire | ✅ | |
| Heat haze over hot sand at midday | 🟡 | Up to 24 bounded shimmer quads on dry beach sand, scaled by the preset's `heat_haze` (Day = 1, others 0) and the comfort toggle. Subtle by design; judge on a real GPU. |
| Spatial audio: listener on camera, nearest-shore ocean, river/pond, wind/leaves, pooled birds with silence, fire, creaks, room tone, buses, interior filtering | 🟡 | Logic runs. Sounds are procedural placeholders, and direction and quality were not listened to (no audio device here). |

### F. Characters

| Item | Status | Notes |
|---|---|---|
| Human rig spec and four distinct worker looks | ✅ | Rigid-part articulation (not skinned) |
| Dog rig: articulated legs, head, ears, tail | ✅ | |
| Human idle, walk, axe-swing preview; dog idle, walk, lie/sleep | ✅ | Foot contact tested |
| Attachment points; in-place convention; frame-rate independent | ✅ | |
| Dog in camp by day, inside at night, cannot be harmed or lost | ✅ | |

### G. Completion gates

| Item | Status | Notes |
|---|---|---|
| Representative screenshots | ✅ | `docs/screenshots/`, software-rendered |
| 10-minute walkthrough | ✅ | REVIEW_GUIDE.md |
| Repeatable performance route | ✅ | Benchmark button |
| 60 FPS measured on a midrange GPU | ⛔ | Not measurable here. Please run the benchmark. |

## Known limitations (exact)

1. **No real-GPU verification.** Everything visual was checked on a software renderer. Frame rate, shader cost, TAA ghosting, and the exact look of water, foam and heat haze still need your review on real hardware.
2. **Audio is synthetic.** All sounds are procedural placeholders. 3D direction (left/right, front/back) is set up through `AudioStreamPlayer3D` on a camera-mounted listener, but nobody has listened to it yet.
3. **Characters are stylized primitives.** They use rigid parts, not a skinned mesh. Faces have eyes, brows and a mouth, but no facial animation beyond blinking. A licensed rigged GLB can replace them later behind the same API.
4. **Trees use cards.** Pine crowns read as clumpy up close, and the far LOD is a solid silhouette.
5. **Sand heat haze is placement-based.** It appears only near the placed beach quads, not on every hot surface.
6. **No planar or SSR water reflections.** Water reflects sky radiance only, so trees and the camp aren't mirrored in ponds.
7. **Dog movement ignores physics.** The dog walks straight lines between authored camp points, avoiding a few obstacle circles. It is visual only.
8. **Windows SmartScreen.** The Windows build is unsigned and will show a SmartScreen warning.
9. **First launch may stutter.** Shader compilation on first launch can stutter for a few seconds (Godot's shader cache warms after that).
