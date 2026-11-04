# Revised Phase 10: stabilization, ruleset migration and status inventory

Source revision: branch `phase-10-stabilization` (from `phase-9-onboarding-ui`). Engine: Godot 4.5.1-stable, Forward+, Jolt (unchanged). Status key: **observed** = exercised by an automated test, headless tool or software-renderer capture · **unrun** = implemented, not exercised · **partial** · **absent**. Nothing here was played by a person or run on a real GPU.

## What Phase 10 changed

| Item | Status | Where |
|---|---|---|
| Versioned rulesets stored per campaign; unknown rulesets refused with a readable message | observed | `scripts/campaign/ruleset.gd`, `SaveService.summarize`, tests `phase 10 units` |
| New standard campaigns: exactly 10,000 original native trees, a deterministic subset of the frozen island chosen by thinning the 2,000 most isolated trees, so clusters stay dense and the island keeps its full extent. The other 2,000 never spawn, render, collide, appear in the locator or count | observed | `Ruleset.excluded_ids`, `World.apply_variant`, `World.native_total()`; test `phase 10 world` |
| Legacy saves keep the 12,000-tree manifest, their two employees, their wages and their progress, labelled "Legacy 12,000-tree contract". Nothing is deleted or regenerated | observed | `Ruleset.id_of_save` (no ruleset = legacy); test labels |
| Five persistent starting employees (boss + 5 = 6 humans): unique IDs EMP-01..05, distinct traits, five different beds, five small axes | observed | `Payroll.STARTING_ROSTER`, `CrewService.start_new_campaign` |
| $4,500 starting cash for the standard ruleset (three full-crew payroll days; tunable in the ruleset) | observed | `Ruleset.DEFS.expanded_v1.start_cash_cents` |
| Five employees accrue $1,500 per day, settled once per day | observed | test |
| Section length ×1.5 reserved in the ruleset (`section_length_active: false`); `TimberService.section_count_for`; share conservation proven for 1–12 pieces at ×1.0 and ×1.5 | observed (interface only) | activates in Phase 13 with handling/storage |
| Tool model: axes already give more work per contact with slightly slower heavy swings, keeping effective ratios 1.00 / 1.40 / 1.96 (no double multiplication) | observed (Phase 1–3 tests) | `TreeWorkConfig` |
| Chainsaw | absent (reserved: `chainsaw: false`, audio IDs) | Phase 14 |
| Contribution hooks for merit: work applied per accepted contact, once-per-item stages (felled, stump, accepted share), saved; no XP yet | observed | `scripts/crew/contributions.gd` |
| Stable audio event IDs with current files and quality grades; reserved IDs for chainsaw, yard and voice | observed | `scripts/audio/audio_events.gd` |
| UI, help and guide text for five employees, $1,500/day and 10,000 trees; payroll example scales with the actual crew | observed (captures pending) | title, Help, Journal |
| Contract boundary: completion at the last half-second of day 30 wins once; deadline close and re-evaluation can't flip it | observed | test |

## Inventory of earlier phases (actual state)

| Phase | Area | Status | Notes / gaps |
|---|---|---|---|
| 0 | Island, water, vegetation, camp, lighting | observed (software renderer) | Never reviewed on a real GPU |
| 1 | Axe, felling physics, stumps, tree records | observed | |
| 2 | Timber, bucking, carrying, rack acceptance, burn | observed | Conservation tests; long-haul stress partial |
| 3 | Clock, contract, wages/arrears, axes shop, saves | observed | |
| 4 | Crew AI, navigation, minds, dialogue (48+ lines) | observed / partial | Far below the 1,200 authored lines planned for Phase 17 |
| 5 | Trucks, TV wall, dog, comfort, arcade | observed | TV becomes entertainment once the desk computer arrives (Phase 11+ per expansion) |
| 6 | 1,300 events / 312 startles / Foreman / hunt / rescue | observed (headless coverage) | Visual/audio review not done |
| 7 | Whole-island audit, bridges, stump jobs, locator | observed | Re-run in Phase 10: 0 issues |
| 8 | Weather, animation coverage, TV pipeline, audio pass | observed / partial | Models and sounds remain placeholders (below) |
| 9 | Menus, onboarding, notifications, keys, endings | observed (logic + captures) | No person has played it |
| — | **Feasibility of the contract** | **not completable at current rates** | 10,000 trees ≈ 333 trees/day; measured best ≈ 7 tree-eq/day. Faster tools (Phase 14), larger sections/yard (13) and merit (16) are the planned levers |

## Honest model, animation, audio and voice gaps

- **Humans:** rigid-part primitive rigs (no skinned meshes, no face rig). Hands are simple shapes; grips are IK-placed. Rough, as you reported. Phase 11 rebuilds them.
- **Dog:** box-and-capsule body. It reads as a dog at a distance; up close the paws, muzzle and gait are crude. Phase 11.
- **Foreman:** primitive blobs with a strong silhouette; close-ups are weak.
- **Animation:** procedural keyframes plus IK, with no mocap. Getting in and out of trucks, doors and beds are blended cuts.
- **Audio:** every sound is a synthesized placeholder (see the `AudioEvents` grades: 46 events: 39 placeholder, 7 reserved with no asset yet). Chops are clicky, impacts thin, birds are simple chirps and the dog sounds synthetic. No licensed recordings yet. Phase 15 replaces the library.
- **Voice:** **blocked.** This environment has no text-to-speech or voice-export tool (no espeak, piper, festival, pico or Python TTS; no connected generation tool). Nothing was installed or used. Phase 18 needs a voice provider/model with confirmed commercial output rights, chosen by the owner.

## Performance (honest)

Unmeasured on real hardware. Measured: the new-campaign manifest selection runs once at world start (157 ms headless in the test run); thinning 2,000 trees reduces MultiMesh instances by about 17 %. Draw-call counts from Phase 8 still apply. The 60 FPS at 1080p target remains unverified.

## Verification

52/52 automated tests (`tests/test_runner.tscn`), smoke test 0 errors / 0 warnings, island audit 0 issues. The 2-worker and 3-worker workday sims re-measured identically to Phase 7 (3.00 and 4.22 tree-eq).

## Next

**Phase 11:** original human and dog rebuild plus a subtle-pixel style proof. Then Phases 12–20 in order (see the expanded roadmap).
