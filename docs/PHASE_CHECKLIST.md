# Phase checklist

> **Revised Phase 10** (stabilization and ruleset migration): see [PHASE10_STATUS.md](PHASE10_STATUS.md). New standard campaigns use the 10,000-tree / five-employee ruleset; older saves stay on the legacy 12,000-tree contract.

## Phase 17: Crew conversations and the camper internet

Full detail: [PHASE17_NOTES.md](PHASE17_NOTES.md). Manifest: [editorial/CONTENT_MANIFEST.md](editorial/CONTENT_MANIFEST.md). Calendar: [editorial/FEED_CALENDAR.md](editorial/FEED_CALENDAR.md).

| Item | Status | Notes |
|---|---|---|
| Crew bank >= 1,200 lines, >= 100 per category, >= 150 per starting worker | ✅ | 1,676 lines; 277-289 per worker; 0 errors / 0 near-duplicates |
| Cast sheet, schema, stable ids, voice profile keys | ✅ | docs/editorial |
| Conversation runtime: eligibility, pairing, per-turn re-checks, responses, cooldowns saved | ✅ | Tested in a live world |
| Knowledge: firsthand vs told, rumor transfer, knowers from context facts | ✅ | Tested |
| Suppression: saw, fall warning, team carry, hunt danger, departed/hidden | ✅ | Interruption tested |
| Hearing-gated subtitles with duration setting; boss talk menu from the bank | ✅ | |
| Fictional internet >= 5,500 units within kind minimums; 94 accounts | ✅ | 0 validator errors |
| Clock publication, sleep catch-up, cap 240, branches, flags, edits, moderation | ✅ | Calendar simulated; reload/refresh tested |
| Mail/News/Forums/Archives reader with unread, digest, bookmarks, positions | ✅ | Headless only |
| cl01 window warning with director reservation and fallback | ✅ | Fallback tested; staging unplayed |
| cl02-cl12 authored and handed to Phase 19 | 🟡 | Recorded as opportunities only |
| Voices | ⛔ | Phase 18 |

## Phase 16: Crew merit, personality, skills and the boss's restedness

Full detail: [PHASE16_NOTES.md](PHASE16_NOTES.md).

| Item | Status | Notes |
|---|---|---|
| Persistent profiles (ethic, reliability, chattiness, preference), made once, never rerolled | ✅ | Tested across save/restore |
| Time ledger with real causes (yard full, blocked, missing tool, fear, waiting, break only if work waited) | ✅ | Tested |
| Conserved merit ledger: 300/200/100/300/100 per tree, proportional split, boss bucket, no repeats/circles/shuffles | ✅ | Tested; whole tree = exactly 1,000 |
| Saw earns the same merit per tree as an axe | ✅ | Tested |
| Career levels 1-20 (summary only) + four skills with capped effects (x1.35) through ToolEffects | ✅ | Tested |
| Roster/daily review with reasons, read-only snapshots; praise once per real contribution | ✅ | Tested; UI reviewed headless only |
| Phase 17 context facts with knowers | ✅ | Data hooks only |
| Restedness: drain, bedtime quality, forecast, once-per-day sleep settlement, bounded debuffs | ✅ | Curves tested (early/late/repeated/recovery) |
| Rest never makes the camper unsafe; true pause stops drain | ✅ | Tested |
| Hunt: continuous rest on the couch/hidden (4/min to 70), no skipping | ✅ | Five-cycle model tested; not played |
| Schema 11 migration (rest 100, level 1, no retroactive merit) | ✅ | Tested |
| Multi-day balance with compounding skills; human play | ⛔ | Unrun |

## Phase 15: Sound library, source-based spatial audio, occlusion and rooms

Full detail: [PHASE15_NOTES.md](PHASE15_NOTES.md). Coverage matrix: [audio/SOUND_COVERAGE.md](audio/SOUND_COVERAGE.md).

| Item | Status | Notes |
|---|---|---|
| 200 original non-dialogue sources (60 work / 25 vehicle / 25 movement+dog / 45 env / 20 domestic / 25 horror) | ✅ | Procedural (`tools/audio_lib`), deterministic, QA'd; 0 recordings |
| Every source bound to a stable event; 0 missing files | ✅ | Tested; 156 events |
| SoundService (Godot native): pool, loop handles, priorities, debounce, no immediate repeat | ✅ | One tested backend; no Steam Audio/FMOD/Wwise |
| Origin kinds (world/internal/relay/recording/ui/music); only world reaches microphones | ✅ | Hop rule tested |
| Per-source occlusion by material (rays), filter tiers, no whole-bus indoor filter | ✅ | Tested indoor + outdoor at once |
| Door portals (open door = path, closed = filtered) | ✅ | Around-the-corner routing tested; ray approximation, not diffraction |
| Room response (camper, cabin) per source | ✅ | |
| Distance classes, near-field caps, travel delay frozen by pause; Doppler off | ✅ | Tested |
| Logging, saw, truck, cart, dog, doors, camper, ambience, weather, night, encounters, Foreman on the new path | ✅ | Some families still legacy (see notes) |
| Relay bus separate from TV; replay through the desk without new evidence | ✅ | Tested; archive is Phase 19 |
| AI hearing independent of mix volume | ✅ | Muted-master test |
| Speech interface (`SoundService.speak`) | 🟡 | Interface only; no voice files yet |
| Audition route (12 stops) + active voice list | ✅ | Probe ran; **not listened to** |
| Heard on real headphones/speakers; HRTF; real audio CPU cost | ⛔ | No audio device here |

## Phase 14: Stronger axes, chainsaws, gear, the computer supplier and coordinated logging

Full detail: [PHASE14_NOTES.md](PHASE14_NOTES.md).

| Item | Status | Notes |
|---|---|---|
| One tool/gear/trait calculation (player, crew, UI, tests) | ✅ | `ToolEffects.breakdown` |
| Axes 1.00/1.40/1.96 per hit at one cadence; Hard-working x1.25 once | ✅ | Output per second unchanged (no progress rescale) |
| Chainsaw state machine, contact-only work, bounded ticks, interruptions | ✅ | 3.23x a hatchet over whole trees (measured) |
| Saw sound layers (start/idle/rev/load/stop) at the tool; hunt hearing evidence | ✅ | Replaced by the Phase 15 library + SoundService loops (still unauditioned) |
| Boots/gloves/helmets, one per slot, tier replacement, honest numbers | ✅ | |
| Unique items, one owner, legacy axes mapped once, issue/recall at boundaries | ✅ | |
| Visible tools and gear on the crew; gloves in first person | ✅ | Software renderer only |
| Supplier app, idempotent prepaid orders, boat schedule, parcel locker, refunds at close | ✅ | |
| Fall lanes, claim reaper, stage division, yard backlog awareness | ✅ | |
| Two-person carry with safe break and solo fallback | ✅ | Probe observed; teams not saved |
| Measured cutting and whole-day pipeline | ✅ | +44 % deliveries with saws; walking dominates |
| 10,000-tree feasibility | ⛔ | Not shown; hauling distance is the bottleneck |
| 60 FPS with full crew + saws + cameras on a midrange GPU | ⛔ | Not measurable here |

## Phase 13: Logging yard, longer logs and storage

Full detail: [PHASE13_NOTES.md](PHASE13_NOTES.md).

| Item | Status | Notes |
|---|---|---|
| Cutting plan v2 (target length ×1.5) for new campaigns; exact $100 and 1 TE per tree | ✅ | Ruleset `expanded_v3`; plan stored per record |
| Older rulesets and saves keep plan v1; no re-cutting on load | ✅ | Tested |
| Oversized logs (up to two hand loads) dragged by player and crew | ✅ | Slow carry with a drag pose, not a physics skid |
| Receiving cradle (12) + three log decks + fire loading pile (12) | ✅ | Measured deck capacity 141 logs ≈ 22.6 TE |
| Acceptance reserves a yard place first; full = refused and unpaid | ✅ | Tested (cradle full, deck delivery, partial cart unload) |
| Fire burns only from its loading pile; paid logs moved by hand or crew | ✅ | |
| Handcart: load 4, push, unload what fits; pose and load saved | ✅ | Kinematic, bounded turning |
| Crew yard job and automatic yard help | ✅ | Probe observed; full-day throughput unrun |
| Trucks unload what fits and keep the rest | ✅ | |
| Save schema 9; old pit backlog moves to decks once | ✅ | Tested, payments unchanged |
| Daily report: processed, accepted by route, burned, yard moves and stock | ✅ | |
| Preview stations, screenshots | ✅ | Software renderer |
| 60 FPS at 1080p on a midrange GPU | ⛔ | Software renderer only |

## Phase 12: Dense 10,000-tree island, terrain, cover and hiding (plus motion capture and proper fabrics)

Full detail: [PHASE12_NOTES.md](PHASE12_NOTES.md). Audit: [audit/ISLAND_AUDIT_R2.md](audit/ISLAND_AUDIT_R2.md).

| Item | Status | Notes |
|---|---|---|
| Exactly 10,000 valid native records for new campaigns (deterministic, region quotas, rejection report, loud failure) | ✅ | Island r2; CI `generate_island_r2 --check` |
| Legacy and Phase 10 saves keep their island and manifest | ✅ | Island identity stored in saves; tested |
| Groves, gaps, size cohorts, low boughs that belong to their tree | ✅ | Removal clears every LOD (tested) |
| Undergrowth families by habitat; cut zones, hides, trails, lenses clear | ✅ | 36,019 plants, no colliders |
| Landforms (hummocks, ridges, gullies) and rock formations, supported | ✅ | 0 floating rocks; no edits near water, trails or camp |
| Cover classes; soft concealment bounded; hard cover geometric | ✅ | `CoverService`, Foreman sight |
| Rock hides with entries, crouched pose and exits; dead ends labelled | ✅ | 60 hides; geometry and search tested |
| Persistent cover after full clearing | ✅ | 99 % of work ground within 50 m of hard cover |
| Whole-manifest support and access audit | ✅ | 0 issues, 10,000/10,000 reachable |
| Clearing fixtures at 0/25/50/90/99.9/100 % | ✅ | Audit and Preview |
| Preview stations and dev cover/nav overlay | ✅ | |
| 60 FPS at 1080p on a midrange GPU | ⛔ | Software renderer only |
| Owner's Mixamo clips on the crew; uncovered clips improved | ✅ | Retargeted, feet re-planted per body |
| Proper fabrics and models instead of denim stand-ins | ✅ | Poly Haven CC0 |

## Phase 9: Onboarding, UI, crew management, accessibility, balance and endings

Status key: ✅ implemented and observed (automated test or capture) · 🟡 implemented, not yet run by a person / partial · ⬜ absent. Player guide: [PLAYER_GUIDE.md](PLAYER_GUIDE.md). Time/pause/state: [TIME_AND_STATE.md](TIME_AND_STATE.md).

| Item | Status | Notes |
|---|---|---|
| Title: Continue / New Campaign / Load / Settings / Help & Controls / Preview Tour / Character Preview / Credits / Quit; disabled Continue explains why | ✅ / 🟡 | Keyboard focus and Esc back. Summaries tested (completed, hunt, escaped = finished, too-new, legacy). Buttons not clicked by a person yet |
| New Campaign brief (30 days, real delivery pay, two workers, $300 wages, sleep rule, content note); overwrite confirmation for occupied slots | ✅ / 🟡 | Only the standard campaign is offered; no fake difficulty choice |
| Continue never picks a finished (escaped/dead/stranded) run or a too-new save | ✅ | `SaveService.continue_slot` |
| Prioritized notification queue (critical > warning > info > minor), coalescing, reviewable log | ✅ | A minor message can't bury the dusk warning (tested) |
| Live key names in prompts and help; rebinding with conflict swap, reset, persistence; Esc always cancels, Pause can't be lost | ✅ / 🟡 | Tested at the logic level; the rebinding UI hasn't been used by a person |
| Accessibility: text/UI size, captions, subtitles, hints, highlight strength, flash reduction, horror intensity, bob/shake strength, DOF/CA/grain/vignette | ✅ / 🟡 | Captions/subtitles toggles are stored; per-source caption styling remains as in Phase 6/8. No controller support is advertised |
| First-day guide from real results (walk, journal, crew/dog, rack, fell, section, carry, real delivery credit, money, night rules, sleep); any order, any keys, hold-to-chop, save/load; skip step, skip guide with rules summary, replay as help (never touches world/money) | ✅ / 🟡 | Detection tested; a full newcomer playthrough has not been run |
| Night rules shown before the first night (paused card) and **no ordinary catch until acknowledged** | ✅ | Tested |
| Journal: Help & log tab; contract counts incl. stumps, undelivered shares, logs on ground / in hands / in trucks, burning (already paid) | ✅ | |
| Last-tree assist (Phase 7 locator) + once-only final-tree milestone that is not completion and says what's left | ✅ | Tested |
| Success: completes immediately when all done; saved at once; summary from the ledger; Return to Menu or post-contract exploring (no clock/wages/night/hunt), saved distinctly | ✅ / 🟡 | Summary content tested; the full completion run needs a prepared fixture |
| Hunt: rules card (paused, Continue) incl. continuous days, closed hiring/boats, boarding window, dog safe; status line shows survival day, ship and boarding time, dog status; sleep and hiring refusals explain the hunt | ✅ / 🟡 | |
| Leave-behind requires a named, deliberate choice; escape summary lists dog, escaped, dead, departed and left-behind people and notes the failed contract | ✅ | |
| Dog rescue: objective line, sleep refusal explains the dog is unhurt and when it will come home by itself | ✅ | Phase 6 rescue rules unchanged |
| True pause freezes clock, night escalation and director | ✅ | Tested |
| Crew roster, shop, hiring, firing, wages by due day, trucks | ✅ (Phases 3–5) | Reused; wage example added; stale Phase-4 wording removed |
| Worker conversation reflects their own evidence | ✅ (Phase 4/8) | Unchanged |
| Measured campaign balance | 🟡 | See [audit/FEASIBILITY.md](audit/FEASIBILITY.md) Phase 9 section. The standard 12,000-tree configuration stays **unverified/infeasible at today's tuning**, by owner decision |
| Gamepad | ⬜ | Not supported, not advertised |

### Phase 9 known limits (honest)

- No person has played the new menus, guide or endings; checks are automated state tests and software-renderer captures.
- The first-day guide teaches with text plus real detection; there are no animated arrows or world markers beyond the Phase 7 locator.
- Captions follow the existing Phase 6/8 system (TV and Terror captions); there is no separate per-speaker caption styling yet.
- The 30-day contract on the 12,000-tree island is still not completable at the current work rates. The owner has planned faster cutting and longer days.

## Phase 8: Animation, water, lighting, weather, camera and spatial sound

Status key: ✅ implemented and observed (test, headless run or software-renderer screenshot) · 🟡 implemented, needs live review on real hardware/ears · ⬜ not done. Reference: [docs/PRESENTATION.md](PRESENTATION.md). Coverage: [docs/coverage/phase8_sensory_matrix.md](coverage/phase8_sensory_matrix.md).

| Item | Status | Notes |
|---|---|---|
| **Fix: trees looked split in half / see-through** (owner report) | ✅ | Trunk/branch tubes, far-LOD cones and character limb capsules were wound inside-out, so `cull_back` removed the near half. A world-wide probe now finds no culled surface wound against its normals. A test guards it. Also shipped as Phase 7 build 34. |
| Presentation ownership: weather decides, EnvironmentController is the single writer of sky/fog/ambient/shared shader globals | ✅ | No other script writes those properties per frame |
| Seeded, restrained weather (clear, light cloud, overcast, light rain, distant storm) blended over 90 s from the authoritative clock (campaign or hunt) | ✅ | Deterministic, no reroll on load (tested); schema v8 stores seed + cosmetic wetness only |
| Shared wind field for trees, grass, water detail, rain, clouds and leaf audio | ✅ / 🟡 | Per-day prevailing direction with drift; local gusts |
| Rain: bounded per-view GPU rain, roof/cab/canopy shelter mask, splashes (High+), wetness on terrain/rock/bark, rain rings on water, open vs roof audio | ✅ / 🟡 | Software-renderer screenshots; streaks are fixed-Y billboards (documented) |
| Remote cameras see the same weather (own rain volume per rendered feed) | ✅ | Bounded budget per feed; released when the feed stops |
| Distant lightning follows flash reduction (full/reduced/off); thunder delayed by distance; no AI evidence, lamp or safety change | ✅ | Tested: safety answers and lamp states identical in a storm, zero SoundEvents |
| Heat haze only over sunny dry sand/pit; caustics fade with cloud/rain/depth/night; sun/moon discs hidden by cloud; milder rain fog | ✅ / 🟡 | |
| Comfort: flash reduction, shake and bob strength, horror intensity (playback only), music toggle; DOF off by default; CA 0 by default; no fake motion blur/auto-exposure setting | ✅ | Settings → Comfort |
| Peak control: Horror and Master limiters; TV limiter | ✅ / 🟡 | Not listened to on real speakers |
| TV: per-profile feed resolution/refresh published by `pipeline_info()`; focus 1:1 at composite resolution; quad genuinely cheaper; single tone map (HDR linear feeds); pooled viewports, no growth (tested 200 toggles) | ✅ / 🟡 | Colour look on real GPUs not reviewed |
| TV relay steps back when the source is naturally audible nearby (no doubling) | ✅ | |
| Human animation: pickup, setdown, talk, talk_shaken, fear, listen, glance, grip, drive, hide + existing idle/walk/swing/sit/lie; interruptible one-shots; planted feet; bounded head yaw | ✅ / 🟡 | Procedural keyframes + IK; tested |
| Work/animation sync: one contact per swing under frame skips (no duplicated work); pickups/set-downs play after the real transaction | ✅ | Tested |
| Trait idles (timid glance, hard-working grip, observant listen), fear stance, guarded vs loose talk by firsthand evidence | ✅ / 🟡 | Cosmetic only |
| Dog: sniff and growl postures; attention tracks sensed sound positions only | ✅ | |
| Foreman: footsteps from foot plants; tags only while moving and cut off when listening; head offset bounded | ✅ | Tested (no steps while still) |
| Worker footsteps by surface (6-voice pool, 28 m), timber impact debounce, leaf wind and birds follow standing trees only, rocky-hollow echo, sparse original daytime music + dusk pad | ✅ / 🟡 | |
| Ordinary Terror sensory matrix (1,300 events + 312 startles): assets, state, trigger, observed result, missing | ✅ | 1,607 implemented-observed, 5 partial (audio-first families' figure beats); figure beats for T12/T23/T16 now use the family's own visual |
| Review tour: 11 named Phase 8 stations + F4 weather buttons | ✅ / 🟡 | Stations that need no HUD are exercised by the test |
| Phase 7 support/path checks re-run after the changes | ✅ | Island audit: 0 issues (see below) |
| Final production art for humans, dog and Foreman (skinned, face-rigged) | ⬜ | Still stylized rigid-part primitives; see PRESENTATION.md "Assets" |
| Authored traversal animations (truck entry/exit, door, bed entry/wake) | ⬜ | Blended cuts |
| Real-GPU performance at 1080p | ⬜ | Unmeasured; counts only |

Verification: 48/48 tests (`tests/test_runner.tscn`), smoke 0 errors / 0 warnings, island audit 0 issues, Terror coverage 1,612 observed / 0 errors. Screenshots (software renderer): `docs/screenshots/phase8_*.png`.

### Phase 8 known limits (honest)

- Everything visual was checked on a CPU software renderer (lavapipe) at a few frames per second. Shader look, rain density in motion, TAA behaviour and frame rate need a real-GPU review.
- No one has listened to the mix on speakers or headphones. Stereo direction, limiter behaviour and music balance are unreviewed.
- Characters remain stylized primitives with procedural animation. The Mixamo/licensed-rig question is still open.
- Weather is cosmetic by design. Rain doesn't slow work, wet logs or change any rule.

## Phase 7: Whole-island grounding, reachability, clearing, logistics and the 30-day feasibility audit

Status key: ✅ implemented and observed (audit run, test or headless sim) · 🟡 implemented, needs live review · ⬜ not done / decision needed. Reports: [docs/audit/ISLAND_AUDIT.md](audit/ISLAND_AUDIT.md) (generated), [docs/audit/ISSUE_LEDGER.md](audit/ISSUE_LEDGER.md), [docs/audit/FEASIBILITY.md](audit/FEASIBILITY.md).

| Item | Status | Notes |
|---|---|---|
| Reproducible whole-island audit (`tools/island_audit.tscn`): tree roots, rocks, ground cover near camp, 43 grounded anchors, camera mounts (mount and rock), bridge ends | ✅ | 0 floating trees/rocks, 0 bad anchors/mounts after fixes; see the ledger for exceptions and false positives |
| Named regions (camp surroundings, inner/outer compass sectors) for progress and diagnostics | ✅ | 17 regions |
| Required-target coverage: every original tree has a reachable cutting stand plus a retreat cell connected to camp (stumps share it), in the original forest and at 25/50/90/99/100 % cleared | ✅ | 12,000 / 12,000 at every fixture |
| Facilities: six cabin beds, arcade spots, table seats, footlockers, rack/drop-off, dock gangway, dog refuge approach, every hiding entry | ✅ | Real A* from the camp yard; authored routes for the private camper/utility |
| Bridges: walkers now stay on the deck (crew grid deck heights); 3.6 m truck-capable bridges with ≤ 22 % ramps; drivable cells along each bridge | ✅ | **P7-B01, P7-B02** |
| Truck coverage: trees within 25 m of a drivable route from the bays | ✅ | **11,898 / 12,000** (was 7,995); all remaining by 90 % cleared |
| Workers chop out stumps (required targets) through shared claims | ✅ | **P7-B03**; workload runs show stumps removed |
| Final-item assist: Journal → Contract → Locate the nearest remaining work | ✅ | **P7-B04** |
| Clearing fixtures through the real removal signal (nav refresh), vegetation chunks rebuilt, tree collision cells rebuilt from cleared data | ✅ | 0 tree colliders after a full clear |
| Island Audit review route in the Preview Tour (overlay of support samples, walkable and drivable cells; bridges; truck height; locator; dock and hides) | ✅ / 🟡 | Dev only, off by default |
| Measured workload through the real task rules (`tools/workload_sim.tscn`) | ✅ | See FEASIBILITY.md |
| **30-day feasibility of the 12,000-tree island** | 🟡 (decided, re-measure later) | Not feasible with today's tuning (best day ≈ 7 tree-eq; ceiling ≈ 1,700 trees in 30 days). Owner decision: keep 12,000. Faster cutting methods and a longer day (about double) are planned; re-measure with `tools/workload_sim.tscn` then. See FEASIBILITY.md |
| Dynamic obstruction: displacement-based stuck detection, bounded escape/repath, claim release, unreachable marking, door/rack reservations (Phase 4/5 systems) | ✅ / 🟡 | Stuck events per measured day are listed in FEASIBILITY.md; queues not stress-tested with five workers on one rack |

### Phase 7 known limits (honest)

- With today's tuning the contract is not completable on the current island; faster cutting and a longer day are planned (owner). Income stays below full-crew wages in every measured configuration.
- Workload numbers come from single simulated days at 60 Hz through the real rules. They are not human play and have not been averaged over many seeds.
- Queues with five workers on one rack, two trucks arriving together at the drop-off, and a player deliberately blocking doorways were not stress-tested.
- Visual checks of the new 3.6 m bridges were done on a software renderer only; driving across them was verified as a route, not by physically driving the truck.
- The overlay and review route are development aids; they have not been reviewed on real hardware.

## Phase 6: The Terror director, living nights, the dog rescue and the Foreman's hunt

Status key: ✅ implemented and observed (automated test or headless sim) · 🟡 implemented, needs live review on real hardware · ⬜ later phase. Separate coverage statuses for the authored bank are in [docs/coverage/phase6_coverage.md](coverage/phase6_coverage.md).

### Authored content as working data

| Item | Status | Notes |
|---|---|---|
| Packet preserved verbatim (`docs/design/phase6_packet.md`) and compiled by `tools/compile_terror_bank.py` into `data/terror/bank.json` | ✅ | 26 families, 1,300 events (T01-E001…T26-E050), 312 startle types (T01-J01…T26-J12), 36 Foreman patterns (F-H01…F-H36); unique ids, source text kept per entry |
| Every event has an executor plan made of real runtime primitives (sound, voice, figure, shadow, lantern lights, interior warmth, starless sky patch, props: red thread/footprints/stakes, camera feed watch/anomaly, dog reaction, worker witness, startle peak) | ✅ | Schema/reference validation test; the mapping is keyword-derived and traceable |
| **Implemented** (has a valid executor) | 1,300 / 1,300 events, 312 / 312 startles | T26 events map to beats of the single rescue quest |
| **RuntimeObserved** (executed headless in its context through the real director to cleanup, no script errors) | 1550 / 1,550 non-rescue ids (1250 ran to cleanup, 300 with a sharp peak); 0 quiet; 62 T26 ids are rescue-quest beats (11 observed in the rescue run) | See the coverage table; quiet = no valid place in that fixture (a legal outcome) |
| **Missing / art gaps** | 🟡 | Apparition bodies are stylised procedural silhouettes (tall woman, surveyor, worker-like, low crawler, antlered wing, backward walker, wrong dog, drowned walker, hanging shapes, afterimage, extra person). Several authored beats are approximated by the shared primitives (e.g. "two cameras catch different portions", "flashlight passes beneath her shoulders"): the cue plays, the exact staging is simplified. Voices are original synthesized murmurs with captions of lines the crew really said (no recorded voices). |

### Ordinary nights

| Item | Status | Notes |
|---|---|---|
| One director: context (woods / camp / cabin / camper / cameras), needs (workers, truck, dog), novelty, no repeat of a family the same night, quiet outcomes when nothing fits | ✅ | |
| Pacing: 45–150 s quiet gaps, one active primary encounter, shared peak budget with 8–12 active-minute refractory (3 min under sustained pursuit), startle weight ~4 % (~22 % under pursuit) | ✅ | Refractory tested; values need night play-testing |
| Behaviour profile: pursuit / retreat / stare / camera dwell from in-game movement only, decaying | ✅ / 🟡 | |
| Encounters: grounded placement outside every safe area with cover, emergence instead of pop-in when watched, react to a sustained look or approach, optional peak, withdrawal through cover, aftermath, cleanup | ✅ / 🟡 | |
| Sound at its world source through the Horror bus; real `SoundEvents`, so TV microphones relay it, workers can perceive it (Phase 4 evidence API), the dog reacts; captions without coordinates | ✅ | |
| Morning removes night actors/props/audio; never touches wood, trees, money, roster, vehicles | ✅ | Tested |
| "Live Feed That Lies": camera-only anomalies (frozen tile, static, wrong label, phantom figure on the feed) logged separately from real render faults | ✅ / 🟡 | |
| Ordinary catch: exposure only while the physical body is outside safety on a contract night; boundary grace; three warnings; commit-frame re-check (safety wins); pause stops it; no catch during the rescue grace | ✅ | Tested |
| Catch screen: saves blocked, load this morning's checkpoint (written every contract morning, separate from manual saves) or the last save | ✅ / 🟡 | |

### The dog rescue (T26, once per campaign)

| Item | Status | Notes |
|---|---|---|
| Eligibility: day ≥ 4, the dog has been petted, a contract night, boss awake in the camper, dog asleep, not day 30, never during the hunt; 35 % per eligible night | ✅ | |
| Checkpoint + trigger id before the door opens; wind roar, the real camper door blown open, the real dog runs a validated 60–150 m route and waits at cover, whining (heard by mics/workers) | ✅ | Sim |
| "Find your dog" replaces sleep; ≥ 200 s protected grace (longer for far routes) | ✅ | |
| Pet to reunite → the dog follows → home through the flap → bed → sleep restored; stalled search assist after 8 min; invalid route recovery to the gate | ✅ | Sim |
| Reload never replays the door; resolved state never retriggers | ✅ | Sim |

### Abandonment and the hunt

| Item | Status | Notes |
|---|---|---|
| Only on an unmet day-30 deadline; a fulfilled contract can never spawn the Foreman | ✅ | Tested |
| Transition: company frozen (no hires, no boat, departing workers stay), beacon acknowledged at the utility radio (rescue at dawn day 36), dog walks to its dock refuge, clear rules card **before** anything can kill | ✅ | |
| Continuous hunt clock: 900 s day + 300 s dusk + 300 s survival night, days 31–35, no sleep, pause stops it; survival checkpoint at each dawn; rescue only at dawn of day 36 | ✅ | Tested |
| The Foreman: one persistent original procedural body (~3 m, coat, back mass, long arms/hands, hood, folds, off-centre jaw, throat tags), idle/walk/sprint/listen/low search/doorway fold/reach | ✅ / 🟡 | Stylised; close-up face/skin is an art gap. Character Preview has a dev turntable |
| Senses: FOV, distance by light, occlusion, confirmation time; hears real sound events (footsteps, work, doors, engines, voices, hide doors) with uncertainty; decaying evidence; rare broad sector hints that are sometimes wrong | ✅ | |
| States ARRIVAL/ROAM/LISTEN/NOTICE/INVESTIGATE/CONFIRM/CHASE/LOST_CONTACT/SEARCH/SHELTER_PROBE/INSPECT_TRUCK/ATTACK/DISENGAGE/RECOVER; sprint limited to 7 s then recovery; one false departure per search | ✅ / 🟡 | |
| Hiding: camper bed + wardrobe, six cabin beds, utility desk + shelves, under the dock; enter/exit with a short transition and a verified exit; seen entry is evidence; probes find occupants by suspicion | ✅ | Probe trials in the sim |
| Attacks: telegraphed 0.65 s, re-checked (reach, hidden-and-not-found, moving truck) — no stored kill after a valid evasion | ✅ | Tested |
| Workers: stay in the cabin, warn, flee to free hiding places, come out when quiet; real death state persists; a witness believes | ✅ / 🟡 | |
| Rescue ship approaches the real dock at dawn of day 36, 8-minute boarding window, workers board at the dock end, the dog boards automatically exactly once, boss boards (confirmation if crew still ashore); outcome lists escaped / departed / dead / left behind | ✅ | Sim |
| 36 Foreman patterns as conditional plans in the one agent (pattern ids recorded when their situation occurs) | ✅ / 🟡 | Observed ids in the sim are listed below |

### Headless scenario evidence (`tools/hunt_sim.tscn`, Preview, in memory)

- **Dog rescue:** IDLE → ELIGIBLE → ARMED → WINDDOOR → ESCAPE → SEARCH. The real dog ran out through the open camper door along a nav route to cover 145 m from camp and waited there, whining. "Find your dog first." replaced sleep, and the protected grace ran to 306 s of night time. A capture/restore mid-search resumed SEARCH, and the door did not replay. Petting led to RETURN_HOME: the dog followed a boss walking at 4 m/s (largest gap 24.6 m), then went in through the flap to its bed (SLEEP inside the camper). The rescue ended RESOLVED and does not retrigger. Beats observed: T26-E003, E005, E006, E007, E008, E009, E010, E017, E018, E019, E020.
- **Abandonment:** hunt mode on, the Foreman revealed 143 m away, hiring blocked, sleep unavailable, 11 hiding places built, and the dog walked to the dock refuge.
- **Open ground:** a boss standing still in front of it went through CONFIRM → CHASE → LOST_CONTACT (×2) → CHASE → ATTACK and was killed. Preview showed the death card.
- **Hidden probes (20 trials each):** found 7/20 after an unseen entry and 16/20 after a seen entry. A hidden, unfound target is never killed by a stored attack (unit test).
- **Clock:** days 31, 32, 33, 34 and 35 in hunt mode, then 36 → rescue. The ship docked, the dog boarded exactly once (a second attempt was refused), a worker at the dock end escaped, the boss boarded, and the outcome card listed everyone.
- **Foreman patterns observed in this run:** F-H10, F-H13, F-H23, F-H24, F-H28, F-H31, F-H36 (7 of 36). The others are wired to their situations in the agent (door folds, closet/bed probes, truck inspection, engine listener, wrong sector, false departure/return, voice fragments, etc.) but were **not observed** in this scripted headless run; they need live play-testing.

### Phase 6 known limits (honest)

- Nothing was play-tested on a real GPU or with real speakers. Apparitions and the Foreman are stylised procedural bodies; the close-up grotesque face/skin, cloth and hand contact are Phase 8 art work.
- Event staging is approximated by shared primitives. The coverage run proves every id executes and cleans up, not that each reads exactly as written.
- Pacing numbers (quiet gaps, refractory, startle weights, exposure rates, hunt night length, probe chances) are first values from the packet, not tuned by play.
- Workers in the hunt use simple hide/regroup behaviour and are not ordered individually. Crew radio is not implemented.
- The ship approach is a straight run to the dock; boarding is per person at the dock end.

## Phase 5: Two logging pickups, a living camp, dock and dog, couch television, and ten live cameras

Status key: ✅ implemented and observed (automated test or headless sim) · 🟡 implemented, needs live review on real hardware · ⬜ later phase.

### Trucks

| Item | Status | Notes |
|---|---|---|
| Purchase: $9,000 (provisional), at most two, unlocked at 50 delivered tree-equivalents; charged once; free parking bay | ✅ | Locked before the unlock, two succeed, third refused, exact charge (test) |
| Procedural original pickup (cab, bed, bench, lamps, mirrors, plate), compound collision, raycast spring/damper wheels, AWD, grip, brakes, reverse, anti-roll, camp speed limit | ✅ / 🟡 | Headless drive: 4.1 m/s in camp, brakes to 0, reverses at 4 m/s, upright, steers. Handling feel needs live review |
| Player driving: E at the driver door, W/S/A/D, Space handbrake, H lights, E to get out only when stopped at a clear dry door spot; HUD (speed, bed load, lights, camp limit, tutorial step) | ✅ / 🟡 | |
| Driving tutorial: enter, drive, reverse, load, deliver, park | 🟡 | Steps tick from real actions |
| Seats: driver plus two passengers; workers board real seat markers; "Ride with me" order; nobody in two trucks | ✅ | Test |
| Cargo: 3 tree-equivalents through the timber ledger (VEHICLE_RESERVED, one owner); load at the tailgate; paid only when unloaded at the drop-off (accept), never twice; unloading elsewhere sets logs down unpaid | ✅ | Test: one payment, second unload pays nothing, no piece in two trucks |
| Separate drivable route graph (4 m cells, slope, water only on bridges, trunk/rock clearance, open camp yard, logs block, felling opens corridors) | ✅ | Built in about 1.1 s |
| Worker team (driver + up to two loaders): gather → board → drive out → work/load → board back → drive back → unload at drop-off → park → next run or home | ✅ | Full headless day below |
| Dusk: no departure when the return no longer fits; teams head back early; passengers warned | ✅ | Second run turned back "before dark" in the sim |
| Dismissing / firing a driver while moving: brake to a safe stop first, riders stay aboard, cargo stays in the ledger | ✅ | Test |
| Recovery button (journal) puts a stuck/flipped truck on the nearest drivable cell; refused during a future hunt | 🟡 | |
| Save: trucks restored parked and stationary, nobody seated, cargo from the ledger, teams resume at "gather" | ✅ | Documented policy |

**Team cycle measurement** (headless, `tools/truck_sim.tscn`, one full day, two starters, area 70 m north of the gate). Run A: 2 runs, 35 truck receipts, 3.07 tree-equivalents paid at the drop-off ($306.31), 797 m driven. Run B (after the safe-stop changes): 1 run, 34 receipts, 2.90 tree-equivalents ($299.68), 412 m driven; on the way back one loader missed the 75 s boarding window and walked home. The difference is which trees the loaders reached. A truck day is roughly what the same two workers carry by hand (3.0 tree-eq/day in Phase 4), but with one load in place of dozens of trips to the rack, so the crew's time goes into felling and bucking. The honest conclusion stands: the 30-day contract needs far more throughput, and loading at the work site is now the bottleneck.

### Camp, dock, dog

| Item | Status | Notes |
|---|---|---|
| Dock finished in place (not a second dock): stringers, joists, pile caps, cleats, fenders, end ladder, landward railing, practical lamp, sign, plank path to the utility door and beach gate | ✅ / 🟡 | Rendered |
| Utility building on piers: raised floor, real door and step, windows, ceiling, storage shelves, electrical panel, radio desk, emergency-beacon console (status + `request_rescue` hook only), two later hiding spots | ✅ / 🟡 | The five-day ship rescue is **not** implemented |
| Dog alcove: raised floor on posts, roof, side walls, bed, water bowl, name board, ramp; refuge + approach anchors | ✅ / 🟡 | |
| Dog: articulated body with idle, walk, trot, sit, lie/sleep, alert, petting pose; ear/tail motion; head turn and ear-perk overlays; red collar and tag | ✅ / 🟡 | Clip quality needs live review |
| Day life on the crew's camp grid: wander, sit, nap, come over to the boss; avoids the burn pit, moving trucks; stuck guard re-plans | ✅ / 🟡 | Fire avoidance tested |
| Dusk: walks home across the yard, up the ramp and in through a **dog flap** in the camper door (or the open door), sleeps on its bed; after dawn leaves the same way; no teleporting | ✅ | Test: flap passages, largest step under 0.4 m |
| Petting: optional, reachable hotspot, cancellable by walking away | ✅ | Test |
| Reactions: real nearby sounds and sounds replayed by the TV (ears, head turn, alert, retreat, rare whine); calm cooldowns; footsteps ignored | ✅ / 🟡 | |
| Survival interface: `enter_refuge()`, `board_ship()` exactly once, distinct saved routines (camp / refuge / boarded) for the same identity; wind-door escape reserved, never triggered | ✅ | Test |

### Camper comfort and the TV

| Item | Status | Notes |
|---|---|---|
| Couch: sit with a short transition, look around, verified stand-up spot | ✅ | Test |
| Light switch (lights + bulbs), curtains on every window (animated), hot drink at the kitchen | ✅ / 🟡 | Cosmetic only; safety is untouched |
| Ten cameras CAM-01..10 on real mounts and FOVs (cabin/camper, forest entrance, four fence corners, west trail, east ridge trail, deep woods) | ✅ | |
| 2×2 wall: four distinct live feeds, labels, aspect kept | ✅ / 🟡 | |
| Rotation: one tile per interval (5 s default), round-robin tile order, fair shuffled bag, no immediate repeat; all ten appear; pause halts it, no catch-up burst; `[`/`]` sets 0 (frozen), 5, 10, 20 or 40 s | ✅ | Test: 40 steps, one tile each, all ten shown |
| Click selects the camera the tile shows at that moment; focus is locked; A/D or wheel prev/next; right-click returns to a distinct set with a fresh timer | ✅ | Test |
| Pooled rendering: at most four 384×216 feeds at 12 Hz (staggered) **or** one 1280×720 feed at 30 Hz; nothing renders when the TV is off or nobody is within 14 m | ✅ | Test checks the pool |
| No recursive capture: the screen is on its own layer and every camera excludes it; first-person arms excluded; a camera-only body shows the boss on the feeds | ✅ | Test |
| Remote views get vegetation around what they look at (ground-cover anchors) | ✅ / 🟡 | |
| Lighter camera environment (same sky/sun/fog/time; no SDFGI/SSIL/SSR/volumetric; SSAO only in focus) | 🟡 | Night look on feeds needs review |
| Entertainment channel: original procedural cartoon (Timber Tales) with a synthesized jingle and the wall as an inset | ✅ / 🟡 | |
| Remote microphones: world sounds (logging, footsteps, dog) are sampled at displayed cameras by distance and occlusion and re-played from the TV speaker; one replay per sound (strongest camera), density cap; quiet in quad, louder/clearer in focus (smooth ramp, low-pass opens); mute (room unaffected); TV output never re-enters the registry; remote captions | ✅ | Test: near, out-of-range, duplicate, mute, focus louder, no feedback |
| Ambient bed for the cameras (wind or surf) phase-locked to world time | 🟡 | |

### Arcade, saves, preview

| Item | Status | Notes |
|---|---|---|
| Two original cabinet games: **Log Stacker** and **Flapjack Flip**, with score, failure, restart, help, exit and high score | ✅ / 🟡 | Logic tested; feel needs play |
| Arcade pauses the whole world (clock, work, fire, crew, trucks) with a clear banner; exit restores the previous pause/mouse state; a scene change never leaves a phantom pause; the TV is live time by design | ✅ | Test: clock frozen, game running, state restored |
| Save schema 6: player seat (saved standing at a verified spot; couch re-seats in the real camper), dog, TV (mode, quad set, bag, interval, mute, volume, power), lights/curtains, arcade high scores, beacon; trucks in the campaign block; v5 → v6 migration | ✅ | Tests |
| Preview Tour stops: Driving & hauling, Dock & dog, Surveillance (with a preview-only surveyor walking past CAM-03), Arcade, Dog refuge / home | 🟡 | In memory only |
| Terror Director, Foreman hunt, rescue ship (Phase 6+) | ⬜ | Hooks only |

### Phase 5 performance (honest status)

- **Not measured on a GPU.** This container only has a software Vulkan renderer. `tools/perf_p5.tscn` (TV off, quad, focus, entertainment, then both trucks driving) did not finish 450 measured frames within 50 minutes there, so no frame-time numbers are reported. Run it on real hardware: `godot res://tools/perf_p5.tscn` prints a `PERF_P5` line with average/p95 frame time, main-view and summed security-camera render CPU/GPU time, and camera renders per second.
- **Bounded by design (verified by tests):** at most four 384×216 feeds at 12 Hz (48 small renders a second, staggered) or one 1280×720 feed at 30 Hz; zero camera renders when the TV is off or nobody is within 14 m. Feeds use a lighter environment (no SDFGI/SSIL/SSR/volumetric fog).
- **Draw-call counts from the capture tool** (software renderer, 1280×720 main view): couch view with the quad wall 8,060 draw calls in the frame (main view + four feeds), focused feed 2,612; the dock view alone 3,412.

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
