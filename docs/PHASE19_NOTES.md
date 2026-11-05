# Phase 19: Camp routines, fair survival cover, and the offshore survey

Status key: **observed** (an automated test, an audit or a measurement), **unrun** (implemented but not exercised), **gap** (not done). Everything here was checked headless. Nothing was looked at on a real GPU or listened to on real audio hardware.

## 1. Camp routines (`scripts/crew/camp_routine.gd`)

**Daily roles.** Each active worker whose job is "automatic" gets a role in the morning:

| Role | Who gets it |
|---|---|
| sawyer | Holds a chainsaw and trunks are waiting |
| yard | Level-headed or observant, when yard stock is 5 or more (two yard hands at 12 or more) |
| hauler | Stronger, or many loose logs |
| feller | Everyone else |

- The role only decides what the worker tries **first**. The Phase 14 bottleneck rules still apply.
- An explicit job you assign always wins.
- Roles are deterministic for the same inputs (observed).

**Transport plan.** It comes from the distance between camp and the work:

| Work distance | Plan |
|---|---|
| Under 120 m | Carry |
| 120 m or more | Handcart, if you have one |
| 260 m or more, with a truck and a reliable driver | Truck runs |

The plan is a recommendation with its reason, and you still drive the trucks. Observed: 40 m gave carry; 390 m with no truck gave the handcart.

**Midday gathering.** It starts at 430 s of daylight and lasts 55 s.
- Workers within 170 m of camp who are between jobs walk to the four fire seats (rocking chair and stools), or to the picnic table, and sit.
- Far crews take their break where they are.
- Break time is its own category ("midday break") and is never counted as idleness.
- The rest pose opens ordinary Phase 17 conversation (`act:rest` lines).
- Observed: three workers walked about 11 m and sat within 8 s, and two far workers took a field break.

**Dog.** An attendee calls Biscuit over and pets her (observed).

**Colleague awareness.** Attendees hear what each other actually did today, from the merit ledger. This becomes a `colleague_progress` context with exactly those listeners, so the existing "colleague progress" lines become true (observed: shared).

## 2. Survival cover (`scripts/world/survival_cover.gd`)

All placement is derived at runtime from the frozen r2 data. Nothing in `data/world` was hand-edited.

| Kind | Count | Concealment | Ways out |
|---|---:|---|---|
| thicket | 36 | Geometric: the Foreman's ray through the brush uses the Phase 12 soft-cover rule. Foliage never hides within 4 m. | 2–3 through the brush |
| shed (far field work sheds) | 2 | Walls. The door creaks, which the Foreman can hear. | Door and back hatch |
| dock_store (gear chest at the dock landing) | 1 | Lying inside. The lid knocks. | Two sides |
| Existing: rock recess / gap, beds, closet, desk, shelves, under the dock | 71 | Unchanged | Unchanged |

**Selection.**
- Thickets: radius at least 3 m, at least 10 plants, density at least 0.8, crown at least 1.3 m, at least 45 m from camp and at least 70 m apart. 55 were too thin and 10 too close to another.
- Sheds: flat, walkable ground with no trunk or rock within 4.5 m, at least 330 m from camp. Sites near a trail are preferred, and the two sheds must be more than 300 m apart.

**Clearance (observed).** A capsule matching the occupant's pose (crouched, or lying for the chest) is tested against every static collider, and the trunk and rock data are checked too. There were 0 failures across the 39 new hides and the 60 rock hides.

**Region audit (observed).** Distances are straight-line to any hide. "Alternate escape" means 2 or more hides within 150 m.

| Region | Median nearest | 90th percentile | Hide within 30 m | Alternate escape |
|---|---:|---:|---:|---:|
| Far logging (>350 m from camp) | 48 m | 76 m | 24% | 100% |
| Travel routes (trails) | 34 m | 57 m | 43% | 100% |
| Named regions (11) | 42–57 m | 65–86 m | 19–32% | 98–100% |

- 110 hides in total. The largest kind (rock recess) is 34%, so this is not a sea of identical boxes.
- **Cleared land:** every hide is rock, brush, a structure or the dock, so the fully cleared island keeps all of them. Undergrowth persists after logging.

**Evidence-based hides (observed, with the real Foreman):**
- **Unseen entry into a thicket.** No seen-entry record, and no evidence within 5 m of the hide, so the exact position doesn't leak. The Foreman at 10 m, from any of 6 sides, does not see the hidden eye.
- **Near reveal.** At 3 m the Foreman sees the hider: cover is not invulnerability.
- **Seen entry.** The Foreman watched the shed door. The entry was recorded, the Foreman's evidence points at that exact spot, and the search bonus is 0.6.
  - **Fix:** before Phase 19, the hunt marked a person hidden *before* asking whether the entry was seen. That made a seen entry into any non-rock hide impossible. It is now judged first.
- **Alternate escape.** Leaving a hide picks the way out farthest from the Foreman. Observed: it exited 15.9 m from the Foreman.
- **The dog is never a hunt target.** Days 31–35 timing is unchanged (`FIRST_DAY` 31, `LAST_DAY` 35, cycle 1,500 s).
- **Survival objective** while the hunt runs: "Survive until the rescue ship at dawn on day 36 (N dawns to go). Hide where you aren't seen going in; if you're found, use the other way out."

## 3. The offshore survey (`scripts/offshore/*`, `data/offshore/survey_config.json`)

**Schedule.**
- One visit every 3 contract days from day 3 (days 3, 6 … 30), starting at 40 s of daylight. Both values are data.
- Each visit has a persistent id (`V03`, `V06`, …).
- The save records the day, state, elapsed route time, exact bearing, lap angle, aircraft state, registered beats and spoken lines.
- **Reload:** a reload continues the same visit. It never starts another one or replays the introduction (observed mid-flight).
- **Contract end:** visits stop when the contract ends; a running visit turns for its departure.
- **The rescue ship:** the Day 36 rescue ship is a separate entity, and no survey ship exists during the rescue (observed).

**Route.**
- **The circle:** a fixed centre (0, 0) and radius 1,050 m. All 720 samples, each with a 200 m margin ring, stay in water at least 8 m deep (the minimum depth along the route is 13.4 m). The dock, skiff and rescue routes lie inside the circle.
- **The lap:** exactly 360° from logged samples, with 0.0 m deviation from the radius. The ship ends on the start bearing.
- **Speed:** 12 m/s in open water and 6 m/s through the 50° camp-facing arc, blended over 10° (observed ratio 2.000). The lap takes 623 s.
- **The circle stays exact** because only the angle is integrated (dθ/dt = v(θ)/R).
- **Arrival:** an arrival leg of 650 m along the tangent, slowing into the arc.
- **Departure:** a separate departure leg that turns 35° outward. The ship is retired once it is at least 900 m out and not in the player's view, or at 1,500 m.
- **Visibility:** at the camp-facing arc the ship is 654 m out. Its silhouette has clear line of sight at eye height from the yard, camp approach, beach gate, shoreline and dock end (observed), using the existing fog. Sight range comes from the live fog density.

**Vessel.**
- An original lofted hull (raked bow, transom, sheer) about 112 m long.
- White superstructure with a dark bridge window band, a radar mast, a funnel, a survey A-frame and crane, and lifeboats.
- A raised aft helipad with a plain perimeter and a touchdown ring.
- **No letters, numbers, names or emblems.**
- A foam wake that stretches with speed, a bow wave, and subtle heave, pitch and roll on the visual only.
- A distant diesel loop: original synthesis, 2.6 km range, not evidence.
- Far updates are bounded to 5 Hz beyond 2.5 km.

**Helicopter.**
- **Launch:** once the ship has been in view for 45 s, or by 200 s into the lap (data). A storm cancels the launch, which is recorded as a missed launch.
- **Takeoff:** it spools up and lifts off in the moving deck's frame, then hands over to free flight with the ship's velocity.
- **Survey:** a camp pass plus 3 of 5 island sweeps (ridge, west, north, east, interior), ordered by the visit's persistent seed. The order differed between V03 and V06 (observed).
- **Height:** terrain or sea plus the tallest standing tree within 14 m, looking ahead along the path. Observed minimum clearance 33.4 m; canopy reads 0 once trees are felled.
- **Banking:** coordinated banking, roll = atan(v·ω/g), capped at 28°.
- **Rotor sound:** a positional loop attached to the aircraft (observed), 2.2 km range, real evidence for camera mics.
- **Bounded animation:** every frame within 600 m, 10 Hz beyond, none past 3 km.
- **Recovery:** converges on a gate astern of and above the moving pad, then descends in the deck frame. Observed landing error 0.0 m on the moving ship.
- **Clear of the slow pass:** recovery must finish well before the ship re-enters the camp arc.
- **Missed recovery:** a credible offshore exit, flying out to sea on the far side and retiring out of view. Later lines can reflect it (`sea:knows_exit`).

**Crew observations.**
- **Lines:** 120 authored lines, the addendum's texts verbatim (0 mismatches against the pack), in 6 groups of 20. Ids are `sea.<who>.<nnn>`.
- **Speakers by personality** (see CAST.md):

| Speaker | Lines |
|---|---:|
| Priya | 15 |
| Tomas | 12 |
| Marta | 9 |
| Joan | 9 |
| Dale | 7 |
| Trait lines (observant 7, sociable 2, skeptical 2) | 11 |
| Anyone | 57 |

- **Row fields:** each row has a trigger, a knowledge class, `when`/`needs`, a cooldown (`rare` or `once`) and a priority. Directional lines are marked `directs`.
- **Knowledge rules (observed):**
  - A worker on the shoreline **sees** the hull.
  - A worker behind the ridge does **not** (terrain), and is ineligible for sighting lines.
  - A worker in the cabin **hears** the rotor but does **not see** the aircraft (walls).
  - A listener who was told gets a **secondhand** claim and never a sighting.
  - Two-pass comparisons need firsthand sightings on two different visits.
  - A nearby running chainsaw masks the rotor.
- **Beats:** first sighting, slow pass, rotor heard or lost, aircraft seen, over camp, banking, lost behind the ridge, deck launch, landing, recovery, departure, and repeat sightings.
  - Each beat gets **at most one** immediate callout, from the best-placed eligible worker. Workers near the player are preferred, and so are attention-directing lines while the player has not seen the target.
  - Cooldowns: 20 s across all beats and 70 s per beat type, plus each line's own cooldown.
  - Observed: one sighting produced exactly 1 callout.
- **Precedence:** a fall warning near the speaker blocks the callout (observed). Danger and team carries suppress it too.
- **Look gesture:** the speaker turns toward the target and glances. The player's camera is never moved.
- **Muted play:** subtitles carry a relative direction cue such as "[to your left, offshore]".
- **Later conversation:** later and secondhand lines join ordinary conversation after a visit (`sea:after`). Telling someone passes the claim on, not the sighting.

## 4. Counts (from the data)

| What | Count |
|---|---:|
| Authored offshore lines | **120** |
| Eligible line/voice mappings | **488** |
| Recordings available (eSpeak NG, offline, same pipeline as Phase 18) | **488** |
| Flagged (`source_clipped`, kept) | 2 (`crew_m/sea.any.069`, `crew_m/sea.any.096`) |
| Missing mappings (subtitle fallback) | 0 |
| Crew bank total | 1,796 lines / 3,316 mappings / 3,316 clips |

## 5. Save format

- Schema **13** adds a `phase19` block: `offshore` (visits, visit in progress, knowledge, cooldowns) and `routine`.
- Schema 12 saves migrate with an empty block: the next due visit day simply happens, and the routine starts the next morning (observed).
- Preview never writes saves.

## 6. Preview review stops

Preview → Tab → **"Phase 19 offshore survey, survival cover, camp routines"**:
1. The ship from the beach
2. The slow pass from the yard
3. Helicopter launch
4. Helicopter over camp
5. Offshore coverage counts
6. Thicket hide (try it)
7. Field shed
8. Dock gear chest
9. Cover audit
10. Midday gathering
11. Today's roles and transport

## 7. Known limits

- **Headless only.** The silhouette, wake and helicopter were not seen on a GPU, and the engine and rotor sounds were not heard.
- **Sheds and navigation.** The sheds are built after the crew navigation grid, so workers path to the door point and the last metre is authored, as with the utility building.
- **Seats.** The gathering seats four at the fire. Extra attendees stand at the picnic table.
- **Transport plan.** It is a recommendation. Trucks are still driven by the player.
- **Line coverage.** Callout lines are chosen by live geometry, so some rare situational lines (sun glare, swell, cabin wall) appear only when their conditions really happen.
