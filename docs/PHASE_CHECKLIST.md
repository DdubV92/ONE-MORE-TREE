# Phase checklist

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
