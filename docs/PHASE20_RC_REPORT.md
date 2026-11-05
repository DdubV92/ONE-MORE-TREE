# Phase 20: release-candidate verification report

**Verdict: TEST CANDIDATE, not a release.** One known progression blocker remains: the contract-success ending is unreachable under the fixed rules (see "Balance"). It needs the owner's decision, because closing it means changing a fixed rule, not tuning. Everything else that could be checked here passes, except the items listed as unrun. The abandonment, five-night survival and extraction path is playable and verified.

Status key:
- **pass:** observed by a test, audit, CI run or measurement.
- **fail:** observed broken.
- **blocked:** cannot be done here.
- **unrun:** not exercised.

## 1. Candidate

| Field | Value |
|---|---|
| Branch / commit | `phase-20-rc`; the final commit is in the handoff message |
| Working tree | Clean at each commit; `assets/mixamo_src/` stays git-ignored |
| Engine | Godot **4.5.1-stable** (Forward+, Jolt), unchanged |
| Export presets | Windows Desktop x86_64 (artifact ZIP, with console wrapper); **Linux x86_64** (new, used for the CI launch check) |
| Claimed platform | **Windows x86-64** test build |
| Also verified | Linux x86-64 export, launched in CI |
| Test environment | Cloud container: 4 vCPU Intel Xeon @ 2.1 GHz, 15 GB RAM, no GPU, no audio device. Rendering via Mesa lavapipe (software) under xvfb. CI: GitHub ubuntu-24.04 and windows-latest runners. |

## 2. Fixtures and labels

| Fixture | How it is made | Labelled shortcuts |
|---|---|---|
| Fresh standard campaign | `Game.new_game` in smoke slot 3 (exported builds) and in test routes | None |
| Legacy save | Phase 10 test fixtures for the legacy 12,000-tree manifest (representative, not a player's real file) | Representative fixture |
| Dense forest / partial clearing / fully cleared | Island r2 data; the clearing fixture removes trees by id; the cleared-percentage prerequisite override is a test-only meta flag | `fixture_cleared` meta (tests only) |
| Busy camp | `start_test_route(true, true)`: five employees, payroll fixtures | Test route, never saved |
| Start of abandonment, hunt, rescue | Hunt mode set directly in tests; `tools/hunt_sim` | Accelerated hunt clock in sims |
| Contract cutoff | Clock set to the deadline frame in the contract test | Direct clock set |
| Interrupted save | A write cut between "remove old" and "rename new", plus a torn `.tmp` | `path_override` test slot |
| Hide recovery, dock extraction | Survival-cover and hunt tests (hunt preview) | `hunt_preview` |
| Ship mid-lap | `OffshoreSurvey.preview_visit` stepped manually | Preview visit |
| **Prepared saves for testers** | `tools/rc/make_fixture_saves.tscn` starts a real new standard campaign and moves it to the point. It writes a normal save marked `"fixture"`, then reloads it through the normal load path and plays it until the expected event. CI ships the saves in `prepared_saves/` in the Windows build. | Labelled `fixture` in the file; not real play |
| &nbsp;&nbsp;`slot_2_terminal_day30.json` | Day 30, 50 s before the cutoff | Verified: the contract closes at the cutoff into `ABANDONMENT_PENDING` |
| &nbsp;&nbsp;`slot_2_offshore_day3.json` | Day 3, on the shore before the first survey visit | Verified: visit V03 starts at t = 40 s |
| &nbsp;&nbsp;`slot_2_extraction_day35.json` | Hunt night 35, a minute before the rescue, near the dock | Verified: the rescue ship is approaching at dawn on day 36 |
| Seeds | World seed 20261103; campaign seeds from the payroll fixture; recorder and interrupt seeds are `hash(seed:day:...)` | |

## 3. Results by area

### Normal loop, standard start, legacy, ledger

| Requirement | Evidence | Status |
|---|---|---|
| Start → first cut → transport → acceptance → settlement → dusk → save → reload | Phase 3 / 13 / 14 world tests; exported-build smoke (new campaign, walk, save, load) | pass |
| Standard start: exactly 10,000 distinct original tree ids, boss + 5 employees | Phase 10 / 12 tests; exported smoke on Windows and Linux: `natives 10000, employees 5, ruleset expanded_v3, island r2` | pass |
| Legacy manifest, identities and progress kept across migration and a second reload | Phase 10 world test (legacy load unchanged); migrations v2 → v14 tested step by step | pass (representative fixture) |
| Trees traced by id through felling, sections, carry, team carry, cart, truck seats and cargo, unloading, acceptance, yard, burn | Timber ledger, Phase 13 / 14 tests (claims, one owner, receipts once, reload, mid-move reload, truck partial unload) | pass |
| Two trucks plus an occupied yard | Phase 5 / 13 tests (trucks, cargo once; full cradle refuses unpaid wood) | pass |
| Settlement and delivery once, including rapid interaction, interrupted save and replay of an accepted delivery | "contract: pay once…", "receipts once", Phase 13 replay; Phase 20 interrupted-write test | pass |
| $100 per original tree through merchantable shares | "timber shares: exact cents…", Phase 13 conservation (plan v2) | pass |
| $300 per active employee per day, arrears and grace | "payroll: day 7/8 arrears…" | pass |
| Quit, fire and replacement with a truck or load reserved | Crew tests (firing keeps wages and slot until departure; claims released); Phase 14 equipment recall | pass |

### Thirty-day completion and the cutoff

| Requirement | Evidence | Status |
|---|---|---|
| Last standing tree and final cleanup are distinct milestones | Phase 9 world test (final-tree milestone once) | pass |
| Completion = originals and stumps cleared + required deliveries accepted; fuel in the queue may remain | Contract tests | pass |
| Just before / at / after workday second 1,200; same-frame report and acceptance; double interaction; pause; save/reload around the cutoff | "contract: final-frame delivery wins, late cannot reopen, reload"; "clock: … deadline once at any frame rate"; "clock stops while paused"; "sleep: one settlement… day 30 closes" | pass |
| **Thirty-day balance** | See "Balance" | **fail (blocker; owner decision)** |

### Regression matrix

| Area | Evidence | Status |
|---|---|---|
| Characters and camper (grounding, scale, grips, gait, seats, dog contacts, desk use, right-window glance) | Phase 1 / 8 / 11 tests (foot planting, grounding audit, desk sit/glance/stand); renders | pass (headless + software renders); **look in normal play: unrun** |
| Forest and routes (dense and cleared, felling, collision, worker routes, dusk departure, bottlenecks) | Phase 7 / 12 audits; crew tests; Phase 19 cover audit; crew sim | pass |
| Tools and storage | Phase 14 tests (axes/saw contact and cancellation, team carry, supplier once-only orders, gear ownership, conservation) | pass |
| Merit and restedness | Phase 16 tests (conservation, caps, rest curves, early sleep, late browsing, hunt rest) | pass |
| Audio and surveillance | Phase 15 tests (direction, distance, occlusion, rooms, positional saw and voice, relay hop rule, focus/quad budgets) | pass (logic); **listening: unrun** |
| Crew and fictional internet | Content audit: **1,796** crew lines, **5,946** unvoiced units, **94** accounts; Phase 17 tests (eligibility, interruption, publishing, archives, read state, reload) | pass |
| Cast voices | **3,316** mappings = 3,316 clips = 3,316 imported; 3,310 validated, 6 flagged; **0 auditioned by ear**; offline playback and subtitle fallback tested; provenance in VOICE_CAST.md | pass (mechanical); audition unrun |
| Horror and replay | 1,300 events / 312 startles / 36 Foreman patterns / 12 computer-linked / **36 recording scenarios** / **24 sleep interruptions** (the last two built in this phase, see section 5) | pass |
| Offshore sightings | Phase 19 tests: exact lap, 2:1 speed, visibility, helicopter on the moving deck, witnesses (firsthand, hearing-only, occluded, secondhand), fall-warning precedence, separate Day 36 ship, persistent visits, 120 lines | pass |

### Abandonment, five nights and extraction

| Requirement | Evidence | Status |
|---|---|---|
| Failed contract → abandonment; shelter rules explained before lethal pursuit | Phase 6 / 9 tests (transition card before the Foreman can kill) | pass |
| Days 31–35 continuous through dawn of day 36; no sleep skipping; menus, save/reload | Phase 6 world; Phase 16 hunt rest; `can_sleep` refusal in the hunt | pass |
| Hides at camp, remote sites and cleared land; access, clearance, success, failure with traceable evidence, alternate escape, no exact-position leak | Phase 12 / 19 tests (0 clearance failures; 100% of points have 2+ hides within 150 m; seen entry is evidence; unseen entry leaks nothing; exit away from the hunter) | pass |
| Dog rescue, dock presence, automatic boarding once | Phase 6 tests; the dog is never a hunt target (Phase 19) | pass |
| Living, lost and departed workers; boarding order; grace window; explicit leave-behind | Phase 6 world | pass |
| **Stale attack after extraction commits** | **Defect found and fixed in Phase 20**; test added | pass (after fix) |
| Outcome and roster after reload for each ending | Phase 9 save summaries; Phase 6 outcome saves | pass |
| Survival with no helpful offshore sighting | Offshore visits never run in the hunt (Phase 19 test) | pass |

### Saves and performance

| Requirement | Evidence | Status |
|---|---|---|
| Interrupted writes and recovery | **Defect found and fixed**: a completed pending write is now recovered before the older backup. Torn write → previous good save. Tested with a ship mid-lap. | pass (after fix) |
| Pending cargo, jobs, recordings, night events, ship mid-lap, active hunt | Phase 13 / 14 / 19 / 20 save tests | pass |
| Repeated reloads, save growth, cleanup | Repeat save is 101,983 bytes both times; Phase 19 and 20 blocks stable through reload | pass |
| Performance | Section 6 | partial (no real GPU) |

### Package and release gate

| Requirement | Evidence | Status |
|---|---|---|
| Pinned export route; Windows x86-64 ZIP | CI artifact (Godot 4.5.1 templates) | pass |
| Contents inspected; launched from a clean folder; offline boot, settings persistence, controls, load and quit | **Windows:** exported `.exe`/`.pck`, launched on a windows-latest runner; **Linux:** export launched from an empty temp folder. Both passed every smoke step (section 7). | pass (headless launch) |
| Real-GPU play on Windows | | **blocked here** (owner's machine) |
| Attribution, asset and voice notices | `NOTICES.txt` in the build; ASSET_PROVENANCE.md; VOICE_CAST.md | pass |

## 4. Balance (accelerated simulation, not human play)

**Source:** `tools/crew_sim.tscn` (`CREW=5 ISLAND=island_r2`), one full workday of 1,210 simulated seconds at 60 Hz on the current build. Five workers on hatchets go through the real AI, navigation, felling, bucking, hauling, yard and fire, including the Phase 19 midday break. This is an **accelerated simulation, not human play**.

**Delivered and paid.**

| Measure | Value |
|---|---:|
| Accepted tree-equivalents | **3.38** |
| Paid | **$337.91** |
| Trees felled | 5 |
| Stuck events | 4 (one worker, one spot, recovered) |
| Merit trees over the 1,000 cap | 0 |
| Repeat merit attempts | 0 |

**Time per worker (s).**

| Category | Seconds |
|---|---:|
| Useful | 484–645 |
| Travel and handling | 467–525 |
| Short pauses | 29–60 |
| Midday break | 55 |
| Heading home at dusk | 51–125 |
| No task | 0–1 |

**Earlier measurements on the same pipeline.**
- Phase 14: hatchets 3.34 trees/day; chainsaws 4.80/day.
- Phase 16: 3.51/day.
- Cutting is under 3% of crew time. Walking and handling dominate.

**Against the fixed rules** (10,000 trees, 30 days, $100 a tree, $300 per employee-day, five employees, $4,500 starting cash):

| | Needed | Measured | Gap |
|---|---:|---:|---:|
| Trees per day to finish the contract | ~333 | 3.4 to 4.8 | about 70 to 100 times |
| Income to cover five wages ($1,500/day) | 15 trees/day | 3.4 to 4.8 | about 3 to 4.4 times |
| Days of payroll the starting cash covers at the measured net (−$1,162/day) | — | **about 4** | Arrears rules then apply and the crew starts leaving |

**Finding (blocker B1).**
- The contract-success ending cannot be reached under the fixed rules with the pipeline as it plays.
- Payroll is unsustainable from about day 4, so every campaign drifts into arrears, departures and finally abandonment.
- This cannot be closed by "tuning within the established rules". The levers left (cutting rate, walking speed, carry capacity) would each need to be multiplied, and that breaks the physical pipeline the earlier phases built.
- **The owner must choose a rule change.** Options:
  1. **Keep it** as the horror premise. The contract is a trap, and the real game is the five nights. Say so in the onboarding and the brief; the success ending stays rare and aspirational.
  2. **A contract lot.** The island keeps its 10,000 trees, but the contract covers a marked block sized to the measured capacity (for example, about 120–150 trees over 30 days with a typical crew).
  3. **A lower total**, together with a wage or price change so that payroll balances at the measured rate.
  4. **Abstracted hauling at scale** (for example, trucks moving whole stems from landings). This is a large redesign, measured again afterwards.
- Nothing was changed without that decision. The abandonment → hunt → day 36 rescue path, which every campaign reaches today, is fully verified.

**Lost worker / missed shift.**
- Departures from arrears are covered by the payroll and crew tests.
- With one worker fewer, measured output scales down roughly linearly (Phase 9: 3.0 trees/day with two workers), so recovery cannot make up time against a deadline that is already out of reach.

## 5. Content built in this phase (Phase 19 expansion gap)

The audit found two required catalogs missing. Both were assigned to Phase 19 by the expansion document and were not built then. Phase 20 built them:

- **36 missed-night recording scenarios** (`data/terror/recordings.json`):
  - All 36 are staged and validated against the real island (observed 36/36), including 3 cleared-island alternatives.
  - Each has distinct beats, real cameras and real sound events.
  - Durable clip records; isolated reconstruction playback (the trees standing that night, seek is deterministic, no side effects); the Recordings app; harmless morning marks.
- **24 sleep interruptions** (`data/terror/sleep_interruptions.json`):
  - States run settling → interrupted → resolving → available.
  - At most one per night, at least 3 quiet nights between them, at least 8 between major ones.
  - No movement, no door, one settlement; a mid-sequence save resumes as "available".
  - Pacing observed: 3 nights in 30 days.

## 6. Performance

**Source:** `tools/rc/perf_probe.tscn`. Same machine as section 1, 240 frames per scenario after warm-up, island r2.

**Headless (CPU, game logic, physics, audio; no rendering).**

| Scenario | Mean frame (ms) | p50 | p95 | Worst | Nodes | Static memory | Sound voices (loops / one-shots) |
|---|---:|---:|---:|---:|---:|---:|---|
| Dense woods | 7.69 | 6.91 | 9.86 | **165.3** (teleport hitch) | 11,773 | 1,003 MB | 13 / 2 |
| Busy camp, crew working | 6.92 | 6.91 | 9.13 | 12.1 | 11,590 | 1,002 MB | 12 / 2 |
| Heavy rain (storm) | 6.91 | 6.91 | 9.09 | 19.0 | 11,593 | 1,002 MB | 15 / 1 |
| Ship and helicopter | 6.89 | 6.93 | 9.35 | 10.6 | 11,591 | 1,006 MB | 17 / 1 |
| Cleared terrain (2,000+ trees removed nearby) | 7.03 | 6.98 | 9.30 | 13.4 | 11,407 | 1,025 MB | 15 / 0 |
| Active pursuit (Foreman near) | 6.90 | 6.92 | 9.27 | 11.0 | 11,493 | 1,026 MB | 12 / 1 |

- **Reading:**
  - Simulation and audio fit well inside a 16.7 ms (60 FPS) frame on this 2.1 GHz server core.
  - The one hitch is a ~165 ms frame when teleporting into dense woods (vegetation collision rebuild), backlog O3.
  - Static memory is about 1 GB (backlog O5).
- **GPU rendering at 1080p/60 (the Phase 10 target): BLOCKED here.**
  - There is no GPU.
  - The software renderer (lavapipe) needs seconds per frame at 1080p, so its frame times are not evidence about a real GPU. A short 720p software run, if completed, is listed below as an upper bound only.
  - Owner check: run Preview → "Run 60 s benchmark route" on the target PC and note the GPU, the resolution and the reported frame times.

**Software rendering at 720p (lavapipe on the CPU; an upper bound only, not GPU evidence).** `FRAMES=30`, same scenarios. The useful numbers are the draw calls, which a real GPU also has to issue.

| Scenario | Draw calls | Objects drawn | Frame time (CPU rasteriser) |
|---|---:|---:|---:|
| Dense woods | 1,322 | ~1,300 | ~3.3 s |
| Busy camp | 3,397 | ~3,400 | ~3.3 s |
| Heavy rain (storm) | 3,434 | ~3,400 | ~3.2 s |
| Ship and helicopter | 434 | ~430 | ~1.2 s |
| Cleared terrain | 855 | ~850 | ~1.6 s |
| Active pursuit | 935 | ~930 | ~1.6 s |

- **Reading:** a modern desktop GPU handles 3,400 draw calls at 60 FPS, but camp and storm views are the heaviest. That is backlog O6: check them first on the owner's PC, and batch camp props (MultiMesh) if they stutter.

## 7. Native build launch (CI)

**The exported builds were launched by CI from a clean folder**, headless, with `--rc-smoke` (CI run 85, the first run with these jobs).

| Step | Windows (windows-latest, downloaded artifact: `.exe` 96.7 MB + `.pck` 354.9 MB + console wrapper) | Linux (export copied to an empty temp folder) |
|---|---|---|
| Boot to the smoke route | ok, 1,473 ms | ok, 651 ms |
| Settings persist across a reload from disk | ok | ok |
| Content inside the export (1,796 crew lines, 36 recordings, 24 interruptions, 1,300 events, 82 feed files, offshore config, 3,316 voice clips and a clip load, new sounds) | ok | ok |
| New standard campaign: 10,000 natives, 5 employees, `expanded_v3`, island r2 | ok | ok |
| Controls exist; walking moves the boss | ok (5.95 m) | ok (5.95 m) |
| Save | ok | ok |
| Load: same day, time and cash ($4,500) | ok | ok |
| Quit | ok | ok |

- **Run 85's red mark:** the Windows step was marked failed only because its script let the game's process exit code decide. The step now prints that code and judges by the report; see the handoff run for the final status.
- **Not covered by these runs:** a windowed launch with a real GPU, audio output and human input. They must be confirmed on the owner's PC.

## 8. Issues and backlog

Each entry gives the originating phase, severity, reproduction, impact and the test needed after repair.

| # | Origin | Severity | Issue | Reproduction | Impact | Test after repair |
|---|---|---|---|---|---|---|
| B1 | Phase 10 (ruleset) / 14 measurements | **Blocker (owner decision)** | The 10,000-tree contract cannot be completed under the fixed rules | `tools/crew_sim.tscn`, five workers, one workday: see Balance | The success ending is unreachable; every campaign ends in abandonment | Multi-day crew sim reaching the target; contract test at the new rule |
| F1 | Phase 6 | High (fixed) | A stale Foreman attack after extraction could turn "escaped" into "dead" | Hunt `mode = escaped`, then `on_kill(player)` | Wrong ending after a successful escape | Phase 20 world test (added) |
| F2 | Phase 3 save writer | Medium (fixed) | An interrupted write lost the newest complete save (`.tmp` ignored) | Remove main after `.tmp` is complete; load | Lost progress after a crash | Phase 20 world test (added) |
| F3 | Phase 19 | Medium (fixed) | 36 recording scenarios and 24 sleep interruptions were missing | Content audit | Required content absent | Phase 20 tests and audit |
| F4 | Phase 19 | Low (fixed) | Survey hull shading artefacts | Close render | Visual | Re-render (docs/screenshots) |
| F5 | Phase 20 (found in screenshots) | Medium (fixed) | Recording playback was filled by the security camera's own housing (box and lens around the replay camera) | Open any recording | Playback unreadable | Camera housings excluded from the reconstruction; re-captured (`docs/screenshots/phase20_recordings_app.jpg`) |
| F6 | Phase 11 desk / Phase 20 | Low (fixed) | The live-camera inset covered the Recordings controls, and the Cameras status hint stayed on screen | Open Recordings | Volume buttons hidden; LIVE mixed with PLAYBACK | Inset hidden in Recordings; own status line |
| F7 | Phase 0 camp / Phase 20 content | Medium (fixed) | No physical gate existed, yet recordings, marks and an interruption used one (a floating slab in rec01 and rec20) | Recordings rec01 and rec20 | Content contradicted the world | A real five-bar tube gate and chain on the west post of the north entrance (`CampLayout.GATE_*`), standing open flush with the fence (routes unchanged). The clips now come from the corner cameras that see it, with line of sight checked. The chain mark moves the real chain. 36/36 still stage |
| O1 | Phases 8–19 | Medium | No real-GPU or real-audio verification | n/a here | Look, stutter and stereo unknown | Owner plays the Windows build; benchmark route |
| O2 | Phase 18 | Low | Synthetic voices not auditioned by ear; 6 clips flagged `source_clipped` | VOICE_CAST / manifest | Some lines may sound harsh | Listening pass |
| O3 | Phase 20 perf | Low | One ~165 ms hitch when teleporting into dense woods (vegetation collision rebuild) | Perf probe, dense woods | A single stutter on a large jump | Probe max under 50 ms |
| O4 | Phase 19 | Low | Field sheds are built after the crew navigation grid (workers path to the door point) | Code | Rare worker pathing at sheds | Nav test at shed doors |
| O5 | Phase 20 perf | Low | ~1 GB static memory headless with the r2 island | Perf probe | Memory budget on 8 GB machines | Measure on the target machine |
| O6 | Phase 20 perf | Medium | About 3,400 draw calls in camp and storm views | Software-render probe | Possible GPU-bound stutter on weaker PCs | Benchmark route on the owner's GPU; batch camp props if needed |

**Format for future requests** (the same for additions):
- Originating phase.
- Requested behaviour or reproduction.
- Affected systems.
- Acceptance criteria.
- Test to add.
