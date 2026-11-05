# Crew dialogue bank: data format (Phase 17)

The files are `data/dialogue/crew/<category>.json` (UTF-8 JSON), and each one has this shape:

```json
{"category": "cutting", "batch": "cutting-1", "review": "draft", "lines": [ LINE, ... ]}
```

## LINE fields

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Stable, unique, never reused: `<cat>.<who>.<nnn>`. `who` is `marta`, `dale`, `priya`, `tomas`, `joan` or `any`. Example: `cut.marta.004`. |
| `cat` | yes | One of the 12 categories below (the same as the file's category). |
| `speaker` | yes | `EMP-01` … `EMP-05` (character-specific), `any`, or `trait:<trait>` (any worker with that trait). |
| `to` | yes | `pair` (needs one nearby worker listener), `group` (needs 2–3 nearby workers), `boss` (said to the player, from the talk menu or as a callout near the player), or `self` (a callout; a listener is optional). |
| `ask` | only for `to: boss` | Which talk-menu topic it answers: `greet`, `work`, `blocker`, `strange`, `wages`, `thanks` (reply to being thanked), `chat`, `ack` (accepting an order), `refuse` (refusing an order), or `report` (an unprompted report to the boss). |
| `when` | no | A list of predicates (ALL must hold). Only use the vocabulary below. |
| `needs` | no | Knowledge the SPEAKER must have (ALL must hold). Only use the vocabulary below. |
| `resp` | no | A list of line ids that may answer this line (spoken by the listener). Each response must be a line in the bank with a `to` of `pair` or `group`, and normally a different speaker. Responses may themselves have `resp` (max chain 4). |
| `reply` | no | `true` if this line is ONLY used as a response (never opens a conversation). |
| `prio` | no | 1 filler … 3 normal (default) … 5 urgent (warnings). |
| `rep` | no | `often` (10-min cooldown), `sometimes` (default, about 1 day), `rare` (about 5 days) or `once` (once per campaign). |
| `interrupt` | no | `drop` (default: abandoned if interrupted) or `resume`. |
| `text` | yes | The words, as speakable subtitle text: 3–30 words for active work, up to about 45 words for breaks. The only allowed placeholder is `{listener}` (the listener's first name); use it sparingly. No stage directions or emoji. |

## Categories (`cat`, the file name, and the `id` prefix)

| cat | prefix | Covers |
|---|---|---|
| `cutting` | `cut` | Cutting, sectioning, stump work |
| `hauling` | `haul` | Carrying, unloading, stacking, fire tending |
| `tools` | `tool` | Tools, chainsaws, equipment comparisons, improvement |
| `ethic` | `eth` | Work ethic, merit, recognition, mistakes, recovery |
| `weather` | `wx` | Weather, terrain, foliage, the cleared landscape |
| `pair` | `pair` | Pair banter, familiarity, disagreement, friendship (two people, with responses) |
| `group` | `grp` | Group conversations (3–4 participants, with distinct perspectives) |
| `boss` | `boss` | Player-directed reports, requests and responses (`to: boss`, with `ask`) |
| `camp` | `camp` | Meals, breaks, cabin, arcade, the dog Biscuit, domestic camp life |
| `wages` | `wage` | Wages, finances, frustration, departure warnings |
| `dusk` | `dusk` | Dusk, witnessed events, doubt, reassurance, ordinary horror |
| `survival` | `surv` | Abandonment, hiding, survival, losses, rescue (`mode:hunt` / `mode:rescue`) |

## `when` predicates (the runtime implements exactly these)

**Activity** (the speaker's current job):
- `act:cut`: felling, bucking or stump work. More specific forms: `act:fell`, `act:buck`, `act:stump`.
- `act:carry`: carrying, picking up, delivering or a team carry.
- `act:yard`: stacking or feeding the fire.
- `act:idle`: no current job.
- `act:walk`: walking empty-handed.
- `act:home`: heading home at dusk.
- `act:rest`: sitting, in the cabin or in bed.
- `act:ride`: in a truck seat.
- `act:hide`: hidden.

**Time and campaign:**
- `phase:day`, `phase:dusk`, `phase:night`.
- `mode:contract` (days 1–30), `mode:hunt` (days 31–35), `mode:rescue` (the ship has arrived).
- `day>=N`, `day<=N` (the campaign day).

**Weather:** `weather:rain`, `weather:dry`, `weather:wind`, `weather:storm`.

**Place:**
- `where:camp`: inside the camp fence.
- `where:forest`: outside the camp.
- `where:cabin`.
- `where:shore`: near the water.

**The speaker:**
- Tool: `tool:saw`, `tool:axe`, `tool:big_axe` (medium/large axe), `tool:none`.
- Fear state: `mood:calm`, `mood:uneasy`, `mood:shaken`, `mood:refusing`.
- Belief: `belief:low` (doubts strange things), `belief:high`.
- Trust in the boss: `trust:low`, `trust:high`.
- Wages: `owed` (owed wages now), `paid` (nothing owed).
- Why they are or were idle (Phase 16 causes): `blocker:yard_full`, `blocker:blocked`, `blocker:no_task`, `blocker:missing_tool`, `blocker:waiting`.
- Career level: `level>=N`.

**The world:**
- `dog_near`: Biscuit within 8 m.
- `cleared>=N`: at least N % of the island's trees felled.
- `crew<=N`: N or fewer workers still employed.
- `boss_tired`: the boss's rest is below 45.

## `needs` (the speaker's own knowledge)

- `saw:strange`: a firsthand memory of something strange (they saw or heard it themselves).
- `heard:strange`: they were TOLD about something strange (a rumor) and have no firsthand memory.
- `know:praised`: the boss thanked them in the last 2 days.
- `know:levelup`: they reached a new career level recently.
- `know:colleague_progress`: they saw a colleague's progress (they were nearby).
- `know:team_carry`: they did a two-person carry today.
- `know:frustrated`: they spent a long time today waiting on the yard, routes or others.
- `know:owed_wages`: they were owed wages at a recent nightfall.
- `know:felled_today`: they felled a tree today.
- `know:delivered_today`: they delivered logs today.
- `know:departed`: a colleague has left the job.
- `know:dead`: (hunt) someone they know is dead.

## Writing rules

- **Situations and knowledge.** Every line must make sense in exactly the situation its `when`/`needs` describe, and must only claim what the speaker can know. A worker without `saw:strange` never describes what they saw; a worker with `heard:strange` repeats a claim ("Dale says he saw…") and may doubt it.
- **Observations.** Use concrete things a worker could see: the next trunk is ready, the lane is occupied, the cradle is full, sap on the gloves, wet bark, the fire pile. Recognition lines refer to actual useful contribution. Blocker lines name the real cause (a full yard is the yard's fault, not laziness).
- **Length.** Active jobs need short, speakable lines. Breaks and the cabin may be longer.
- **Tone.**
  - Mostly mundane, wry, companionable work talk, so that frightening moments change the tone.
  - Horror stays ordinary and uncertain: no monster names, lore dumps or confirmed supernatural explanations.
  - Never claim the island is safe or explain the Terrors.
- **Repetition.** No near-duplicates. A shared line is authored once, as `speaker: any` or `trait:`.
- **Exchanges.** Pair and group exchanges need real response content and distinct perspectives.
- **Content limits.** No real people, real companies or real-world tragedies. No profanity stronger than "hell"/"damn". No slurs.

## Phase 19: the `offshore` category (`sea.` ids)

`data/dialogue/crew/offshore.json` holds the 120 authored offshore-survey lines (the addendum's texts verbatim), generated from the table in `tools/content/offshore_lines.py`. Ids keep the authored number: `sea.<who>.<nnn>` (`nnn` = 001–120).

Extra fields on these rows:

| Field | Meaning |
|---|---|
| `n` | The authored line number (1–120). |
| `trigger` | The beat that may speak it: `sight`, `slow`, `rotor`, `heli`, `deck`, `depart`, `repeat` (immediate callouts) or `later` (ordinary conversation after a visit). |
| `knowledge` | Reported class: `firsthand_sight`, `hearing`, `visual_detail`, `secondhand`, `two_passes`. |
| `directs` | `true` if the line points the player's attention (preferred while the player has not seen it). |

`when` and `needs` may use the `sea:` predicates. The runtime implements them in `OffshoreSurvey.holds()` / `knows()`; the validator reads that list from the code, so an unimplemented predicate is an error.

- **Live situation (`when`)**:
  - Ship: `sea:ship_seen`, `sea:ship_unseen`, `sea:opening_soon`, `sea:slow`, `sea:speeding`, `sea:lap_late`, `sea:departing`, `sea:broadside`, `sea:near_view`, `sea:edge`, `sea:toward_sun`, `sea:hazy`, `sea:engine_heard`, `sea:deck_seen`, `sea:ship_lost_point`.
  - Rotor: `sea:rotor`, `sea:heli_unseen_heard`, `sea:rotor_rising`, `sea:rotor_long`, `sea:rotor_lost`, `sea:rotor_close`, `sea:from_water`.
  - Aircraft: `sea:heli_seen`, `sea:heli_behind_ridge`, `sea:over_camp`, `sea:over_water`, `sea:over_ridge`, `sea:over_cleared`, `sea:overhead`, `sea:heli_close`, `sea:heli_far`, `sea:banking`, `sea:turned`, `sea:sweep`, `sea:inland_next`, `sea:inbound`, `sea:near_dock`, `sea:seaward`, `sea:landing`, `sea:heli_airborne`, `sea:heli_lost_seaward`.
  - Speaker's surroundings: `sea:saw_running`, `sea:engine_noise`, `sea:truck_near`, `sea:away_from_pit`, `sea:among_trees`.
  - Campaign: `sea:yesterday_quiet`, `sea:player_missed`, `sea:after`, `sea:today`.
- **Knowledge (`needs`)**:
  - Firsthand sight: `sea:saw_ship_now`, `sea:saw_ship_long`, `sea:saw_ship_early`, `sea:saw_slow`, `sea:saw_slowdown`, `sea:saw_fast_then_slow`, `sea:saw_heli`, `sea:no_heli_seen`, `sea:saw_launch`, `sea:saw_land`, `sea:saw_recover`, `sea:saw_heli_camp`, `sea:both_sides`.
  - Hearing: `sea:heard_rotor`, `sea:heard_only`, `sea:heard_twice`, `sea:knows_recover`.
  - Earlier visits (two valid passes): `sea:two_passes`, `sea:prev_slow`, `sea:prev_ship_only`, `sea:prev_heli`, `sea:prev_deck`.
  - Secondhand: `sea:told`, `sea:called`, `sea:missed`, `sea:missed_saw`, `sea:wake_only`, `sea:knows_any`, `sea:knows_heli`, `sea:knows_ship`, `sea:knows_exit`.

**Knowledge rules.**
- A firsthand sighting needs line of sight from the worker's eyes to the hull or aircraft, through terrain, structures and standing trees, within the fog range.
- Rotor knowledge needs hearing only. A running chainsaw within 15 m masks it.
- Being told is secondhand and never becomes a sighting.
- Two-pass comparisons need firsthand sightings on two different visits.
