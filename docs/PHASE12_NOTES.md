# Phase 12: dense island, terrain, hiding cover and motion capture

Status key:
- **observed:** an automated test, the audit or a software-renderer capture.
- **unrun:** implemented but not exercised.
- **gap:** not done.

Nothing here has been seen on a real GPU or played by a person.

## How it now feels

New standard campaigns play on **island revision 2** (`island_r2`), a re-planned island that keeps everything good about the original: shape, rivers, ponds, beaches, camp, dock, bridges, trails and cameras.

- **Trees:** exactly 10,000 native trees, grouped into dense groves and copses. Thinner woodland and open glades lie between them, so the woods read as dense where they stand rather than as evenly spaced parkland.
- **Under the canopy:**
  - hazel and bramble along the forest edges;
  - juniper on dry, open, higher ground;
  - bracken in the shade;
  - sedge at wet margins;
  - fallen deadwood (Poly Haven `dry_branches_medium_01`);
  - 150 bramble and hazel thickets.
- **Low boughs:** about one tree in five (1,950) has thick low branches. The branches belong to the tree, start above head height and fall with it.
- **Landforms and rock:** the ground now has hummocks, small ridges, shallow gullies, rock shelves and boulder clusters. There are 60 rock hides you can crouch into.
- **After logging:** the shrubs, rocks, landforms and hides stay. Cleared land reads as shrubby, rocky ground with places to break a hunter's line of sight, not as featureless earth.

## Island revisions and saves (no destructive refresh)

| Campaign | Island | Native trees | Notes |
|---|---|---|---|
| New standard campaign | **r2** (`data/world/r2`) | 10,000 planned records | Ruleset `expanded_v2` |
| Phase 10 standard saves | r1 (`data/world`) | 10,000 subset (`standard_10k`) | Ruleset `expanded_v1`, unchanged |
| Legacy saves | r1 | 12,000 | Ruleset `contract_v1`, unchanged |

- **Choosing the island:** the island is chosen from the save's ruleset before the world is built (`World.apply_variant`). r2 is applied on top of the frozen base, and switching back restores the base arrays exactly (tested).
- **Island identity in saves:** the campaign block stores `island: {revision, trees hash}`. A save that names a different frozen island is flagged (`island_mismatch`) and never re-planned (tested).
- **Never regenerated on load:** loading reads frozen data only, never re-runs the planner, and never fills missing data from a fresh seed.

## Exactly 10,000 valid native records

Planner: `scripts/world/island_r2.gd`; frozen with `tools/generate_island_r2.gd` (CI: `-- --check`). Generation takes about 15 s and is deterministic; content hashes are in `data/world/r2/manifest.json`.

**Allocation:**
- **Regions:** 11 named regions (Voronoi seeds).
- **Quotas:** each region gets a quota from usable area × an intentional density weight, using largest-remainder rounding.
- **Spill-over:** shortfalls spill to regions with spare ground. Spill rounds needed: 0.
- **Failure is loud:** if the count is not exactly 10,000, generation stops with exit code 3.

| Region | Usable m² | Weight | Quota = placed | Groves |
|---|---|---|---|---|
| Camp woods | 126,121 | 1.00 | 1,270 | 57 |
| Lowland fern basin | 67,918 | 1.18 | 807 | 30 |
| South-west shore woods | 45,423 | 0.85 | 389 | 20 |
| North-west inlet woods | 59,442 | 0.95 | 568 | 27 |
| Far west point | 41,524 | 0.90 | 376 | 18 |
| Central woods | 151,232 | 1.05 | 1,598 | 68 |
| North bight woods | 76,905 | 0.95 | 735 | 34 |
| River valley | 135,095 | 1.05 | 1,428 | 61 |
| Ridge slopes | 105,540 | 0.70 | 744 | 47 |
| East plateau | 125,887 | 1.00 | 1,267 | 57 |
| South-east cove woods | 90,259 | 0.90 | 818 | 41 |

**Candidates and rejections:**
- Candidates come from a finite jittered 2.1 m grid, with no retry loops.
- Rejections are reported by reason: water 221,298; beach 7,588; rock 4,663; slope 2,728; spacing 2,326; camp 1,010; trail 1,021; river 1,000; pond 784; bridge 114; camera 34; hide exit 54; approach 1; low grove intensity 51,058.

**Every accepted tree passes:**
- support under its flared footprint;
- slope;
- size-dependent spacing;
- clearance from rock footprints, measured on the real rock meshes;
- clearance from hide exits;
- trail, camp, bridge and camera clearance (including camera lens corridors);
- a work approach: at least two cutting stands, each on ground the crew's navigation grid can use (the planner mirrors `CrewNav`'s rock and steepness rules), and no later tree may take a neighbour's last approaches away.

**Sizes are real data:** cohorts young 4,049, mature 3,730 and veteran 2,221; heights 7–27 m; trunk radius from height × species × variation (veterans × 1.15); lean up to 5° (young), 3° and 2° (spruce). Log budget = height / 4.5, clamped to 2–5. Every tree is still worth $100.

**Species:** pine 5,233, spruce 2,896, birch 1,871, from the same coastal-woodland family. Variant 3 is the open-grown form with low boughs.

**IDs:** IDs 0..9999 are assigned by (chunk, z, x) at freeze time, so they don't depend on render order and survive felling, chunk rebuilds and save/load.

**Contract boundary:** the contract covers the island only. No tree stands on beaches or offshore, and nothing native-looking stands outside the manifest (saplings were deliberately not added).

## Terrain, rock and undergrowth

**Landforms:** 84 hummocks, 28 ridges and 14 gullies, with a maximum change of 2.76 m.
- **Where edits apply:** they are blended through an eligibility mask that is exactly zero within about 16–32 m of water, on beaches, around the camp, within 9–20 m of trails, near bridges and around trail cameras. So shorelines, crossings, truck trails and mounts keep their ground.
- **Terrain build:** terrain, collision and navigation are built from the edited height field, so chunk seams stay continuous.

**Rocks:** 851 new rocks (1,449 in total) in 250 formations: 153 boulder clusters, 37 rock shelves (stretched slabs), 37 rock recesses and 23 rock gaps.
- **Placement:** formations are placed greedily where work ground is farthest from any hard sightline break. They prefer plausible ground (rises, slopes, near existing rock).
- **Support:** every rock is grounded on its real elliptical footprint; the audit finds 0 floating.

**Undergrowth:** 36,019 plants: bramble 14,296, hazel 9,022, bracken 5,049, juniper 3,683, sedge 2,919, deadfall 1,050.
- **Habitat:** density follows shade, damp, forest edges and clumping noise.
- **Kept clear:** every trunk's cut zone (1.25 m), hide pockets and exits, trails (tall shrubs stay 3.5 m off truck trails), camp, water and camera lenses.
- **Collision:** no plant has a collider.

**Masks:** forest floor recomputed from the new trees; exposed rock and gravel around formations and on landform crowns; damp soil in gullies.

## Cover classification (`CoverService`)

| Class | What | How it works |
|---|---|---|
| Decorative | Grass, bracken, sedge, deadwood | Never blocks anything |
| Soft | Hazel, bramble, juniper, thickets | 2 m density grid. Only foliage below its crown height along the sight line counts, with transmittance e^(−0.85 × density × metres). A still target is hidden below T = 0.32; a moving one (> 2.2 m/s) only below 0.12. Never hides within 4 m. Brush never stops bodies or sound, and pushing through it fast makes a real rustle the hunter can hear. |
| Hard | Terrain, rocks, structures | Real colliders; the Foreman's physics ray is blocked by them |
| Hide | 60 rock hides | Reachable entry, crouched pose (eye 0.75 m), verified exits, the hunter's search approach. Concealment is **geometric**: the Foreman sees the crouched eye whenever its ray reaches it (the open front of a recess, either open end of a gap). There is no invisibility flag. |

- **Hides use the same search rules as every other hide:** a seen entry is evidence (the spot is searched first); evidence 40 m away never names the spot (tested). Hide positions are never handed to the director or hunter.
- **Hide types:**
  - **Rock recess (37):** one way out, labelled in the prompt ("one way out"), a deliberate dead-end risk.
  - **Rock gap (23):** two ways out.

## Persistent cover coverage (holds at 100 % cleared)

Distances to hard cover are measured from rocks, landforms and structures, excluding trees: island r2 audit, 10 m sampling of camp-connected work ground.

| Measure | Value |
|---|---|
| Work cells | 10,916 |
| Max distance to a hard sightline break | 75.3 m (open shore edges) |
| 95th percentile | 39.6 m |
| Within 50 m | 99.1 % |
| Hide: max distance / 95th percentile | 119.8 m / 90.8 m |

Clearing fixtures at 25, 50, 90, 99, 99.9 and 100 % (nearest-first, through the real removal signal):
- 0 remaining trees are unreachable at any level;
- every remaining tree is within 25 m of a truck route;
- 0 tree colliders remain after a full clear;
- rocks, landforms, hides and thickets remain.

## Navigation, trucks, dog

- **Reachability:** island r2 audit: 10,000 / 10,000 trees reachable with a cutting stand and a retreat cell. All facilities, beds, storage, the dog refuge and the dock gangway are reachable. All 60 hides have a reachable search approach and at least one standable exit connected to the camp-walkable area.
- **Trucks:** truck trails are untouched (no landform edits within 9–20 m of a trail, no rocks within 5 m, no tall shrubs within 3.5 m).
- **Unrun:** two trucks with a full crew and logs at shared bottlenecks were not driven graphically in this phase. The Phase 5/7 yield, queue and repath logic is unchanged.

## Motion capture (owner's Mixamo clips)

- **Clips:** the five FBX clips supplied by the owner (walk, run, two sits, lying with a nod) are retargeted to the HumanCharacter pivot rig by `tools/bake_mixamo.gd`, and the game loads them from `data/anim/mixamo_retarget.json`.
- **Raw files:** the raw FBX files stay out of the public repository (`assets/mixamo_src/` is git-ignored) because Adobe's terms don't allow redistributing them as standalone files.
- **Retargeting method:**
  - Global rotation deltas from each source bone's own rest, rest-aligned per bone (Mixamo's T-pose to our hanging rest) and flipped to our facing.
  - Hip motion is scaled per body, and walk feet are re-planted with each character's own leg lengths: the planted ankle lands within 1 cm of ankle height, on 1.65 m and 1.88 m bodies alike (tested).
  - Footfalls are emitted at the captured foot plants.
  - Walk and run nominal speeds are derived per body (1.65 m: walk 0.89 m/s, run 2.33 m/s; 1.88 m: walk 1.02 m/s, run 2.65 m/s), so stride matches ground speed. Run starts at 2.3 m/s.
- **Where it's used:**
  - walk and run;
  - sitting (`sitting_1`) for chairs, truck passengers and the desk;
  - relaxed sitting (`sitting`) on the couch;
  - driving: captured seated body with procedural hands on the wheel;
  - lying (body-relative, since the bed orients the body).
- **Improving clips the capture doesn't cover:** the captured seated idle's breathing, settling and head turns are layered onto the standing idle (now a 7 s loop) and onto talk, listen and fear. Carrying keeps the captured legs and torso with IK arms on the load.
- **Change from the source:** the supplied walk holds its elbows bent about 90° (forearms forward). The game relaxes the forearms halfway for a looser woodcutter's walk; everything else is as captured.
- **Fallback:** the procedural clips remain as `walk_proc`, `sit_proc` and `lie_proc`.

## Materials (owner request)

- **What was wrong:** denim had been used as a stand-in fabric for the couch, desk chair, every blanket, the shower curtain, window curtains, the dog bed, mugs and the crew's jackets.
- **What it uses now:**
  - Couch: Poly Haven `sofa_02` model (leather).
  - Desk chair: vinyl from `fabric_leather_02`.
  - Beds: cotton sheet (`stretch_poplin`), wool blankets (`caban`) and cotton pillows.
  - Shower curtain: translucent vinyl.
  - Window curtains: linen (`rough_linen`).
  - Dog bed: fleece (`polar_fleece`).
  - Picnic blanket: gingham (`gingham_check`).
  - Mugs: enamel.
  - Crew jackets: wool (`caban`); trousers stay denim, as work jeans.
- **Tinting:** fabrics are neutral-grey versions of the scans, made by `tools/bake_fabrics.py`, so a tint is the real colour (a red blanket is red, not red × blue denim).
- **Mixamo:** it needs an Adobe sign-in, which this environment can't do. Clips you export are retargeted as above.

## Other fixes in this phase

- Camera feeds rendered garbage or magenta before their first live frame; each now renders once at start-up.
- The Preview Tour panel scrolls, because it had outgrown a 720p screen.

## Review (Preview Tour → "Phase 12 dense island, cover & motion")

Stops:
- dense grove at eye level;
- low-bough work approach;
- undergrowth edge;
- rocks and landforms;
- rock hide (try it; hiding is enabled for the visit);
- ridge sightline break;
- over the woods;
- truck bottleneck (bridge);
- river and dock route;
- desk window view;
- all ten cameras;
- clearing 0/25/50/90/99.9/100 %;
- cover/navigation overlay (dev, with layers: soft, hard, hides, nav, support);
- undergrowth density preset;
- crew motion.

Preview from the title screen shows island r2. Tests, tools and `ISLAND=full` captures use the legacy island.

## Performance (software renderer only)

Lavapipe captures at 1280×720 (CPU rasteriser, *not* representative of a GPU):

| View | Draw calls | Primitives |
|---|---|---|
| Dense grove | ~1,070 | ~6.3 M |
| Thicket | ~1,290 | ~6.4 M |
| Camp | ~2,500 | ~11.3 M |

- **Load:** island r2 loads in about 0.5 s; vegetation builds in 1.3 s and undergrowth in 1.6 s (headless).
- **Gap:** 60 FPS at 1080p on a midrange GPU is not measured. Run the benchmark route on real hardware. The undergrowth's alpha overdraw is the most likely cost; the Low and Medium presets thin decorative plants only.

## Checks run (observed)

- **Automated tests:** 54/54 pass, including the new Phase 12 test and the updated walk test, which now checks both walks: the procedural one by phase and the captured one by its own foot-plant windows, with no skating.
- **Smoke test:** 0 errors, 0 warnings.
- **Island audits:** r1 (legacy) 0 issues; r2 0 issues.
- **Determinism:** r2 and base-world determinism checks pass.
- **Captures:** `docs/screenshots/phase12_*` (software renderer).

## Honest gaps

- **Not seen or played:** no real-GPU look or frame-time measurement; no human playtest of dense-forest navigation, hiding or the pace of the hunt.
- **Acoustic occlusion:** Phase 15. Rock and terrain are available as colliders; brush only rustles.
- **Lighter hides:** about 45 candidate hide sites were rejected for flatness. The hide coverage gap is under 115 m but not shorter.
- **Unrun:** a full crew plus two trucks in dense groves at real speed, and long-log corridors (Phase 13).
- **Characters:** still rigid-part models; the motion capture is only as good as the five supplied clips.
