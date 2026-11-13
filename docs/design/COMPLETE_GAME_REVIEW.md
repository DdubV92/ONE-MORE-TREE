# One More Tree: whole-project review and the path to a complete game

Written 13 November 2026 from a read of all game code (about 58,000 lines in 27 systems), the tests, the data files and every plan in `docs/`. Facts below were checked in the code; file paths are given where a claim matters.

## 1. Verdict

The game has an unusually deep simulation and a large amount of content, but it is not yet a complete game, for one main reason and four supporting ones.

- **Main reason: the contract cannot be won.** Measured output is 3.4 to 4.8 trees a day; the contract needs about 333 a day. Wages outrun income from about day 4. Every campaign therefore ends the same way: arrears, departures, abandonment, the hunt. The sawmill did not change this (`docs/PHASE20_RC_REPORT.md`, blocker B1).
- **Nights do not grow.** Night 4 and night 29 draw from the same pool. Ordinary Terrors cannot hurt you and cannot be answered, so the best play is to go to bed at once.
- **People are simulated but do not matter.** Belief, trust, traits, career level and the contributions ledger change nothing in play. There are no relationships or personal arcs.
- **The island is empty apart from trees.** No visible wildlife, nothing to find, no map.
- **Money and progress run out of purpose.** After gear and two trucks, cash only pays wages. Nothing late in a campaign is worth aiming for.

None of this needs the existing work thrown away. Almost every missing piece is a connection between systems that already exist.

## 2. What is already strong

| Area | What exists |
|---|---|
| Logging | Physical felling, bucking, stumps, carrying, dragging, handcart, two pickups, yard, sawmill, chainsaw, gear |
| Crew | Five named workers, hiring by skiff, nine job types, lanes and two-person carries, fear, memory, stories passed between workers, pay mood, raises, quitting |
| Night | 26 Terror families, 1,300 events, 312 startles, safety rules that match the published rules, dog rescue, 24 sleep interruptions, 36 night recordings |
| Hunt | Five-day Foreman hunt with 14 behaviour states, hiding, crew deaths, rescue ship, four endings |
| Weather | Seven storm profiles, real thunder delay, the Thunder Walker, 12 storm encounters |
| Fiction | 1,796 voiced crew lines, 5,946 feed posts across mail, news, forums and archives, a cartoon, two arcade games |
| Camp computer | Nine apps: cameras, supplier, gear, payroll, mail, news, forums, archives, recordings |
| Look | Drawn-world pass, pixel-art crew, dog and first-person axe |
| Safety net | 124 automated tests, save migrations across 15 schema versions, CI builds for Windows and Linux |

## 3. Where the chain breaks

### 3.1 The contract (blocker)
- The rules ask for 10,000 trees in 30 days with five workers at $100 a tree.
- Cutting is under 3% of crew time. **Walking and handling are the bottleneck**, so better axes barely help.
- The mill tops out near $1,700 a day (30 L/s for 1,200 s at $48 per 1,000 L), while a full crew costs $500 to $3,000 a day.
- The success ending and the post-contract exploring mode exist in code but no player will see them.

### 3.2 Nights
- No part of the Terror code reads the contract day. There is no escalation across the 30 days.
- The 1,300 events reduce to 218 step programs built from 13 primitives. The authored text of an event is never shown.
- Stakes are thin: a catch reloads the morning, horror never costs money, and workers cannot be harmed before the hunt.
- 11 of the 36 Foreman patterns are never used. Crew radio in the hunt was never built.
- Collected but unused: `computer_hints`, `quiet_outcomes`, stare and camera-dwell counters.

### 3.3 People
- **Belief** only picks dialogue lines (`conversation_service.gd:292`). **Trust** only picks lines and scales belief gain.
- Reliability, "prefers" and chattiness are display-only or unread. Career level "multiplies nothing".
- Recordings cannot be shown to the crew, so the evidence loop stops at the player.
- Feed hooks cl02 to cl12 were written for the night director and nothing reads them.
- No line can name who left. Tomas's sister Ana appears in 27 lines with no payoff. 44 authored boss lines are never played.
- The crew never use the arcade, kitchen or fire that their own lines talk about.

### 3.4 The island
- 1.17 km², 11 named regions, a river with two bridges, two ponds, three beaches, 250 rock formations. The regions only set tree density.
- Birds, owls, frogs, fish and insects exist as sounds only.
- No map, no landmarks with names in the world, nothing to collect or discover, no swimming.

### 3.5 Economy and goals
- Full kit for six people and two trucks is the end of spending.
- **Trap:** under the mill economy, logs put on the fire are never paid, and the fire still offers "Put logs on the fire" (`yard_service.gd:418`).
- Hiring is replacement only: the standard campaign starts at the five-worker cap.

### 3.6 Unfinished surface
- Player-visible leftovers: the camp notice board says "Payroll arrives in a later prompt"; the dock beacon says "not yet in this build"; a failure card says survival "arrives in Phase 6".
- The Journal shows a cutting bonus from a retired formula.
- No controller support, no translations, no colour-blind option.
- One short musical motif is the whole score. All sound is synthesised.
- Nothing has been seen on a real graphics card or heard on real speakers, and no newcomer has played it through.
- Onboarding does not teach the feed, recordings, hiring, trucks, the talk menu or the hunt.

## 4. The design spine: three loops that feed each other

Today the three loops mostly run side by side. A complete game makes each one pay into the next.

| From | To | Connection to add |
|---|---|---|
| Day work | Night | Cutting a region disturbs it. The more you clear, and the faster, the more that region answers at night |
| Night | Day work | What happened at night changes tomorrow: a shaken worker, a blocked trail, a lamp to repair, a region the crew refuses |
| Night | People | Evidence can be shown. Belief and trust change what workers do, not only what they say |
| People | Day work | Trust buys risky orders and patience with late pay. Career levels grant a chosen perk |
| Money | Night | Lamps, floodlights, fence and generator are bought and placed, so safety is something you build |
| Island | All three | Wildlife warns of what is near. Places found by day become shelter, shortcuts or stories at night |

## 5. Ideas, by pillar

Tiers: **Must** (needed for a complete game), **Should** (makes it feel right), **Could** (richness), **Wild** (bigger swings). ⚠ marks an idea that touches the charter's out-of-scope list and needs your say.

### 5.1 A contract you can win
| Tier | Idea | Connects |
|---|---|---|
| Must | **Contract lots.** The company marks blocks of forest. Each lot is a chapter with a target sized to real output, a milestone payment and a bonus for finishing early | Fixes B1 and gives pacing |
| Must | **Attack the real bottleneck, hauling.** Forest landings (a small paid log deck out in the woods), skid trails that speed carrying, and trucks collecting from landings | Money, island, crew |
| Should | **River drive.** Roll logs into the river and float them to a boom by the camp. Uses the river and bridges that already exist | Island, weather (storm surge scatters the boom) |
| Should | **Seasons.** Finishing a lot ends the season. The next season returns to the same island, with the cleared ground still cleared. Clearing all 10,000 trees becomes the long legacy goal | Makes "trees never regrow" the heart of the game |
| Should | **Mill orders.** The supplier posts timed orders (boards, beams) that pay more than loose pallets | Money, objectives |
| Must | Fix the fire trap: the fire burns offcuts and scrap, and warns before taking a paid log | Economy |
| Could | Storm windthrow: a storm fells trees, giving free timber and blocked trails the next morning | Weather, day work |

### 5.2 Nights that grow and can be answered
| Tier | Idea | Connects |
|---|---|---|
| Must | **Escalation by day and by clearing.** Each region has a disturbance level raised by cutting. Higher levels unlock that family's stronger behaviour | Day work to night |
| Must | **Rules you can learn, not lore.** Each family gets one clear rule (stops when watched, follows the saw, avoids running water). A Field Notes tab fills in as you witness them. Origins stay unexplained, as the charter requires | Mastery without explanation |
| Must | **Night verbs.** Buy and place lamps to build safe corridors; a breaker that trips and must be reset; a floodlight switch; the camp gate; a whistle for the dog | Money, safety |
| Should | **A reason to stay up.** Night work pays: run the mill under lamps, guard the yard, repair what was disturbed. Sleeping at once becomes a choice, not the answer | Economy |
| Should | Worker stakes before the hunt: a sceptic who wanders can go missing until dawn and return shaken ⚠ (charter says workers stop before dusk; nobody is harmed) | People |
| Should | Foreshadow the Foreman during the contract: tally marks, boot prints, a figure on the far camera | Hunt |
| Should | Hunt: shorten to three days (already your plan), add crew radio and orders, use the 11 unused patterns, stage the last boat leaving | Hunt, people |
| Could | Use the unread data: the night director reacts to what you read (`computer_hints`), stare and dwell counters shape which family comes | Fiction |

### 5.3 People who matter
| Tier | Idea | Connects |
|---|---|---|
| Must | **Belief does something.** Believers keep curfew and stay in the lamps but tire sooner; sceptics work later into dusk but panic harder. Telling the truth becomes a real choice | Night, output |
| Must | **Trust does something.** High trust accepts risky orders, waits through late pay, follows you in the hunt | Pay, hunt |
| Must | **Show the evidence.** Play a recording or show a photo to a worker | Recordings, belief |
| Should | **Arcs for the five named workers.** Three beats each, opened by day and trust, with letters arriving in Mail (Ana for Tomas) | Feed, dialogue |
| Should | **Evenings at the fire.** Sit with the crew at dusk: stories, trust, morale. Gives the fire a purpose again | Camp, people |
| Should | Lines that name who left; replacements with a short history | Dialogue |
| Should | Career perks: at levels 5, 10, 15 and 20 the worker picks one of two perks | Progression |
| Could | Crew play the arcade and post scores; gifts from the supplier (coffee, cards, a radio) lift morale | Money, camp |
| Could | Small favours workers ask for | Objectives |
| Could | Dog verbs: call, stay, fetch; the dog alerts before a Terror is seen | Night |

### 5.4 An island worth walking
| Tier | Idea | Connects |
|---|---|---|
| Must | **A map** in the Journal that fills in as you walk, with lots, trails and landings | Everything |
| Should | **Visible wildlife as pixel sprites:** deer, gulls, crabs, fish rings, owls. Birds going silent or flushing is a readable warning at dusk | Night |
| Should | **Named landmarks** for the 11 regions, with signposts and one feature each (old survey tower, wrecked skiff, an earlier camp) | Fiction |
| Should | **Things to find:** survey stakes, carved "witness" trees you may choose to spare, theme-park billboards | Story without explanation |
| Could | Photo camera: evidence for the crew and an album | People |
| Could | Fishing and berry picking as comfort for crew morale only, never a hunger meter ⚠ | People |
| Wild | The theme park premise made visible: each finished lot is surveyed, staked and fenced by the company between seasons | Seasons |

### 5.5 Reasons to keep going
| Tier | Idea | Connects |
|---|---|---|
| Should | Camp upgrades as money sinks: more bunks, a drying shed, a second saw, a workshop, a better fence | Economy |
| Should | Endings that reflect how you played: trees spared, crew kept, wages paid, nights endured | Everything |
| Should | Difficulty modes: Cozy (no catch), Standard, Long Night | Accessibility |
| Could | A company rating and a season summary that carries forward | Seasons |
| Wild | "One more tree": after the last lot, the company offers one more. Refusing or accepting is the final choice | Title, theme |

### 5.6 Finish and polish
| Tier | Item |
|---|---|
| Must | Remove the stale player-visible text; fix the Journal cutting figure |
| Must | A real-hardware pass: frame rate, colours, sound on speakers |
| Must | A newcomer playthrough, then teach the systems onboarding skips |
| Should | Controller support; colour-blind option; translation scaffolding |
| Should | A fuller score built on the existing motif; better bird and voice sources |
| Should | Terror sprites in the pixel style (already planned as P24g) |
| Could | Tests for the new rendering pieces; remove debug probes and dead fields; refresh stale docs |

## 6. Suggested order

| Phase | Name | Outcome |
|---|---|---|
| 25 | Make it winnable | Contract lots, hauling fixes, fire trap, stale text, re-measured balance |
| 26 | Nights that grow | Escalation, family rules and Field Notes, night verbs, night work, Terror sprites |
| 27 | People who matter | Belief and trust mechanics, showing evidence, five arcs, evenings at the fire, hunt radio |
| 28 | An island worth walking | Map, wildlife, landmarks, finds, windthrow |
| 29 | Reasons to keep going | Camp upgrades, mill orders, seasons, endings, difficulty modes |
| 30 | Ship it | Controller, score, real-hardware pass, newcomer playtest, onboarding, cleanup |

Phase 25 comes first because nothing else can be balanced, or even seen by a player, until a campaign can be won.

## 7. Decisions (owner, 13 November 2026)

- All six phases go ahead, in the order above.
- **The hunt** follows every contract. Won: the company ship comes. Lost: nobody comes, and a much harder second way off exists (the dock beacon). Built in Phase 25, first part.
- **Worker risk before the hunt:** yes.
- **Mystery:** never explain origins, and give each Terror a learnable rule.
- Still open: fishing and foraging as comfort only (decision 5).
- **Built so far (Phase 25):** the hunt and beacon rework, contract lots (three lots, 105 trees, advances, milestones and bonuses) sized from a fresh crew measurement, and loads carried straight to the sawmill so wood pays the day it is cut. Forest landings and the river drive are not built: with the lots beside the camp and the mill fed directly, the measured pace (about 4.5 to 6 trees a day against 3.5 needed) no longer depends on them. They stay on the list for the far lots of later seasons.
- **Built so far (Phase 26):** night pressure (nights grow with the day, the cutting and cleared ground), one learnable rule per Terror family, and Field notes in the Journal. Night verbs, night work, Terror sprites and the missing-worker night follow.

## 7a. The questions as they were asked

1. **Contract shape.** Recommended: lots as chapters, with seasons for the long goal. Alternatives: a lower tree total, or keep it unwinnable as the horror premise.
2. **The hunt.** Is it only the failure path, or should every playthrough be able to reach it (for example by choosing to stay behind)?
3. **Worker risk before the hunt.** May a worker go missing overnight and return at dawn?
4. **Explanation.** Recommended: keep "never explain", and give rules instead of origins.
5. **Charter exclusions.** Fishing and foraging as comfort only, and new hauling methods (landings, river drive) both sit near the out-of-scope list.
