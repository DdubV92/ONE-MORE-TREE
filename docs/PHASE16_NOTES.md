# Phase 16: crew growth through useful work, and the boss's restedness

Status key:
- **observed:** an automated test, a headless simulation, or a probe.
- **unrun:** implemented but not exercised.
- **gap:** not done.

## How the crew grows

- **Workers earn merit only for useful work.** Merit is a separate ledger: it never pays money, never changes wages and never touches the contract count.
- **Each original tree is worth at most 1,000 merit.** It is split across the people who actually did each stage:

  | Stage | Budget | Awarded for |
  |---|---|---|
  | Felling | 300 | Accepted notch progress (work / required), not swings |
  | Sectioning | 200 | Each cut's share of the tree's total cutting work, by accepted progress |
  | Stump | 100 | Accepted stump-removal progress |
  | Transport | 300 (per share: its mte / 1,000) | 85 % for bringing the share to a new closest distance to the receiving cradle; 15 % once for loading it into a truck or onto the cart; whatever is left goes to whoever delivers it |
  | Receiving | 100 (per share) | 50 % for the first move onto a deck, the rest when it goes onto the fire pile |

  How the split works:
  - A saw does the work faster, but earns the same 300 per tree as an axe (observed).
  - Two people on one tree split it by accepted work: 60/40 work gives 180/120 (observed in the world test and in the "Shared tree" stop).
  - A two-person carry splits the transport 50/50, and both gain teamwork skill.
  - The boss's work goes to a separate "boss" bucket and never becomes employee merit.
  - Nobody earns anything from automatic burning.
- **No farming.**
  - Every award commits a fraction of one stage of one source, and that fraction only grows.
  - These earn nothing (all observed in unit tests):
    - repeating a contact on a felled tree;
    - walking a log away and back 30 times;
    - shuffling between decks;
    - re-delivering;
    - re-praising.
  - A whole tree processed end to end commits exactly 1,000.
  - The committed table is saved in the same snapshot as the world, so save/load and checkpoint rollback restore both together. A restored ledger never reopens a budget (observed).
  - Fixture deliveries (preview stops) award nothing.
- **Levels and skills.**
  - **Career level (1–20).** It is a readable summary of total merit and multiplies nothing. Curve: cumulative merit = 400 × (L − 1)^1.8.
    - Thresholds: L2 400, L5 4,850, L10 20,878, L20 80,134.
    - This is a provisional scale: the brief's 5,000 was too slow for the measured rate (see Balance).
  - **Skills (0–10).** There are four, fed only by the relevant work. Skill points = 380 × L^1.6, so L10 is 15,128 points.

    | Skill | Fed by | Effect | Cap |
    |---|---|---|---|
    | Cutting | Felling, sectioning, stump | +2 % per level on work per hit / saw cut | +20 % |
    | Handling | Hand/cart transport, loading, yard moves | −3 % per level on the new 0.9 s lift time | −30 % |
    | Driving | Truck transport as driver | +1.5 % per level smoother cornering for worker-driven trucks; top speed unchanged | +15 % |
    | Teamwork | Two-person carries (50 % of that transport) | −4 % per level on the new 1.4 s two-person lift sync | −40 %, clamped |

    The combined skill factor on any one action is clamped to ×1.35 in `ToolEffects`.
  - Skills never change carry or seat capacity, and no work happens without real contact.
- **Character.** Each employee has a profile made once, deterministically from their id, then saved and never rerolled. It holds:
  - **work ethic**, which sets the length of a short break after finishing a job (0.5–4 s);
  - **reliability**, which affects how they report problems;
  - **chattiness** and a **preferred kind of work**.

  Profiles are nudged to fit traits:
  - Hard-working leans tireless, but it is still only the single ×1.25 cutting bonus (no hidden second multiplier);
  - Stronger prefers hauling;
  - Reliable driver prefers driving.

  Replacement hires get new ids and new profiles.
- **Time with real causes.** Each worker's workday is logged as:
  - useful work;
  - walking & handling;
  - waiting on others;
  - blocked route;
  - no work available;
  - missing a tool;
  - yard full;
  - refusing risky work;
  - heading home;
  - short breaks.

  A break is counted as a break only if there was work to go back to; otherwise it is logged as the real cause, such as "yard full" (observed). A full yard or a blocked route is shown as a logistics problem with a suggestion, never as poor effort.
- **Recognition.**
  - Real milestones create a "Thank them" option in the Journal → Crew tab: a felled tree, a new career level, a new skill level.
  - Thanking someone works once per milestone: trust +0.03 and a little morale. It never pays, changes wages, cures fear or converts a skeptic.
  - Repeats are refused (observed).
- **Phase 17 context hooks.** Structured facts record who actually knows them:
  - improved;
  - praised;
  - colleague progress (workers within 25 m);
  - frustrated by waiting (over 90 s in a day);
  - owed wages;
  - team carry;
  - strange sound/sight perceived.

  Only facts are stored; no dialogue is written here.

## How bedtime affects tomorrow (provisional game model, not medical)

- **Rest runs from 100 (well rested) to 0 (exhausted).** Bands: Well rested ≥ 70, A little tired ≥ 45, Tired ≥ 20, Exhausted.
- **Drain** uses simulation time: a true pause stops it; the computer and TV are live time.
  - Workday (daylight + dusk): 1.5/min, plus up to 0.6/min while exerting (chopping, carrying, sprinting). A normal 20-minute workday costs about 36 at moderate effort (observed).
  - After nightfall (workday second 1,200): 5/min. The night clock stays bounded, but awake time keeps counting.
- **Sleep** settles once per day in the same locked transition as wages:
  - Q = max(0.25, 1 − 0.75 × late minutes / 8);
  - morning = clamp(min(100 − 40 × (1 − Q), bedtime + 80 × Q), 0, 100).

  Results (all observed in unit tests):
  - Going to bed before nightfall fully restores a normal day.
  - Going to bed 9 minutes after nightfall gives Q 0.25, and the morning is at most 45.
  - A second late night compounds.
  - Two early nights recover fully.
  - Sleeping twice for the same day changes nothing.
- **Effects.** Below 70, effects scale smoothly up to:
  - walking ×0.85 at 0;
  - cutting work per hit ×0.80 at 0.

  Each applies once through `ToolEffects`. The swing cadence is not touched, so cutting is not penalised twice (observed). There is no forced sleep, lost input, blur, death or wage change, and the camper stays safe at 0 rest (observed).
- **Bed preview** (applies nothing): "rest 64 now → about 100 tomorrow (Well rested)". The Journal → Rest tab adds:
  - current walk/cut factors;
  - what 4 more minutes awake would cost;
  - recent nights;
  - a reminder that morning only comes from the bed.

  Optional gentle reminders appear at 2, 5 and 8 minutes after nightfall (setting `rest_reminders`).
- **Fear.** Being tired or up late shortens the quiet gap between ordinary encounters by up to ×1.25, never below the existing 45 s minimum. Peak and startle cooldowns are untouched.
- **Survival days (31–35).** There is no sleeping to morning, and rest is not refilled at abandonment.
  - Sitting still on the couch or staying in a real hiding place recovers 4/min, up to 70.
  - Time keeps running and the Foreman keeps searching; you can get up at once.
  - Browsing the computer, chopping or driving is not rest.
  - Five full cycles with realistic rest opportunities stay above 0 and are bounded by the worst penalties (observed in a model test).
- **Phase 19 hook.** `RestService.interrupt(day, cost)` adds a bounded cost (at most 15) to a night, applied once.
- **Saves.** Schema 11 adds `phase16.rest`. Older saves start well rested. Employees start at level 1 with no merit, because older work had no reliable per-actor attribution and none is assigned retroactively. Profiles are made once from each id. Real-world offline time is never counted.

## Measured (headless crew simulation, island r2, five workers with hatchets, one workday)

- **Output:** 3.51 tree-equivalents delivered ($350). Phase 14 measured 3.34 with the same setup, so the new lift time did not cost output.
- **Merit per worker:** 599–926 (all at level 2 after day 1).
- **Conservation:** 5 trees touched, 0 over the 1,000 cap, 0 repeat attempts.
- **Time split per worker:** useful 476–697 s, walking & handling 442–588 s, short breaks 34–59 s, almost no "no task".
- **Projection.** At about 760 merit per worker per day, a typical worker reaches about level 10 by day 30 (career scale 400). A dedicated cutter (about 550 cutting points a day) reaches cutting 10 near the end of the contract (skill scale 380).
- **Economics unchanged.** Wages, prices, the 10,000-tree manifest and the day length are all unchanged. Fatigue affects only the boss's own walking and cutting.
- **Not measured.** Human play, how the reviews read in real play, full-crew performance with cameras on a real GPU, and a multi-day simulation with skills compounding. All **unrun**.

## Preview review route

Preview → Tab → **"Phase 16 crew growth & restedness"**:

| # | Stop | What it shows |
|---|---|---|
| 1 | Crew progress | Opens Journal → Crew (starts the test-route crew if needed) |
| 2 | Shared tree | Two workers do real felling work on one tree, 60/40 → merit 180/120 |
| 3 | Merit & level numbers | Budgets, thresholds, skill effects and caps |
| 4 | Daily review | Today's read-only crew review |
| 5 | Rest: early night | Forecast at rest 64 |
| 6 | Rest: very late night | Forecast at rest 38, 6 minutes late |
| 7 | Rest: exhausted day | Rest 0 and the real tool and walk factors |
| 8 | Hunt rest | How it works |

## Known limits (honest)

- **Transport distance** is straight-line distance to the cradle, not route distance. A detour around the river earns nothing extra (only new closest approaches count), but carrying a log away from camp toward a truck earns only the loading milestone.
- **Reliability** affects job-finish statistics and how problems are reported; it does not yet drive richer behaviour.
- **Personality behaviour** differences are deliberately small, and there are no scripted lazy workers.
- **Recognition** shows the two most recent opportunities per worker. Older ones drop off the list after 40 total.
- **Hunt rest** works on the couch and in hides only. No new lying-in-bed pose was added.
- **Voice and dialogue** for the new context facts are Phase 17/18 work.
