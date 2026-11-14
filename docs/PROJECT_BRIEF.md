# Project brief: One More Tree

**Genre:** first-person, single-player, cozy logging on a large, finite island.
**Engine:** Godot 4.5.1-stable, Forward+, typed GDScript, native desktop (Windows test builds via CI).

## Core loop (whole game)

- Cut every original tree on the island. Process the fallen timber, then dispose of it in the camp burn pit.
- Felling trees during the day earns money. Spend it on a medium or large axe.
- Later, hire up to four workers. Each costs a hiring fee plus daily wages, and workers use the same axe tiers.
  - **Phase 21 (owner request):** wages are per worker, from a $100 minimum, with optional bonuses. Pay below what a worker feels is fair lowers their pay mood and can make them quit; see [PHASE21_NOTES.md](PHASE21_NOTES.md).
- Trees never regenerate. Cleared forest stays cleared, and fallen timber persists until it is legitimately burned.
- The game must remain completable after large-scale clearing, with long worker trips, at low funds, and across save/load cycles.

## Tone

- **Day:** relaxing, tactile, occasionally silly.
- **Night:** an unsettling pressure to stop working and go to bed. Horror comes from obscurity, timing and spatial sound, never from gore or a full-face creature reveal.

## Places

**Camp**
- Dirt clearing with a chain-link perimeter and a wide forest entrance.
- Reliable exterior lights and a tool area.
- Slow-burning outdoor timber pit, fed from its loading pile.
- Logging yard (Phase 13): a receiving cradle by the fire, three log decks outside the north-east fence and an early handcart. Logs are paid when the yard accepts them, and only when it has room.
- Worker cabin with an arcade corner: four beds plus an attached two-bed bedroom, kitchen and bathroom (six beds).
- The player's camper: mini kitchen, bathroom, bedroom, player bed and dog bed.

**The island (Phase 12)**
- New campaigns use island revision 2: exactly 10,000 native trees in groves and glades.
- Persistent undergrowth, landforms, rock formations and 60 rock hides. They aren't contract targets and stay after logging.
- Older saves keep the island they started on.
- New campaigns (ruleset `expanded_v3`, Phase 13) cut fewer, longer logs. Older campaigns keep their cutting plan.

**The dog** lives with the player. It wanders camp by day and comes inside at dusk. It cannot be harmed or lost.

## Night rules (authoritative)

- The camper interior is always safe, regardless of lighting.
- Outdoors, safety exists inside the fence AND within a working designated camp lamp's radius, or (Phase 26) anywhere on land within the pool of a working battery work lamp the boss has set down. Flashlights, the fire, moonlight, distant glow and screen brightness never grant safety. The published rules equal the code: see `SafetyService` and ARCHITECTURE.md.
- Workers stop before dusk and the dog goes inside. Exception (Phase 27, owner decision): one sceptical worker may rarely stay out past the fence for a night; they are never harmed.
- Staying awake escalates apparitions, sound and stalking impressions. A catch and jumpscare can only happen outside authoritative safety after sufficient escalation.
- Night is a bounded state, and morning starts only after sleeping:
  - Sleep is always available at night and resets escalation.
  - A camper holdout can't be killed. It also can't advance to morning by waiting, changing the real clock, or leaving the program open.
  - The night clock may reach its terminal time while an independent awake timer keeps pacing.
  - Menus pause both.

## Reasons to keep going (Phase 29)

- **One more tree.** When the last lot is finished, before the hunt, the company asks for one more: the tallest tree past the forest entrance, $5,000, the boss alone, seven minutes. Yes or no is the game's last choice; the hunt follows either way (a day longer if the tree came down).
- **The ending reads back the play** from real records and names it. It never scores and never explains the island.
- **Difficulty:** Cozy, Standard or Long Night, chosen at the start and saved. It changes how fast the island stirs and whether a contract night can catch the boss, never the safety rules.

## An island worth walking (Phase 28)

- **Things to find:** eight small finds in fixed places far from camp (a survey stake numbered far past three, an older fire ring, a sign for the park). Each is one line of what the boss saw. None explains anything.
- **The map** is the company's survey sheet: the coast is inked, the inside is blank until the boss has walked it. It marks real places and the boss's own work (lot trees, work lamps, beacon parts once known) and never anything that moves at night.

## People who matter (Phase 27)

- **Belief** sets a worker's curfew and how a sighting lands: the convinced head in early and take it steadier; a sceptic works later and is hit harder when they finally see something.
- **Trust** moves the line for risky orders, buys one more day on late wages, and decides who will follow the boss in the hunt. It grows slowly with fair pay and praise and wears with underpay and dismissal.
- **Evidence:** a camera recording can be shown to a worker once. It moves belief much more than a report does, more still for someone who trusts the boss.
- **The first five have something to say** (Phase 27): three short text beats each, opened by day and trust through the talk menu. They build trust; the third settles the worker (a slightly lower fair wage); Priya's hand the boss a step of Field notes about something already met, never an explanation of origins.
- **Crew radio in the hunt** (Phase 27): roll call and two orders, paid for in noise the Foreman hears. Silence on the roll call is never explained.
- **A worker can fail to come home** one evening before the hunt (owner decision). Only a calm sceptic, only once the island has started to stir, one at a time and rarely. The boss can walk out and bring them in, or sleep and have them return shaken at first light. Nobody is harmed.

## Nights that grow (Phase 26)

- **Night pressure** is a pure function of the campaign: the day (45%) and the share of the contract's trees that are down (55%), plus up to 0.3 for cleared ground within 45 m of the player. It is never saved (`NightPressure`).
- It sets which Terror families are awake (four tiers: sound and atmosphere from the first night, then distant shapes, then things that come close or wear something familiar, then the feed that lies), how sharp an encounter may be, how long the quiet between them lasts, and how fast exposure builds outside safety late in a campaign (up to ×1.4).
- **Each family keeps to one rule** that is true in the simulation: keep looking, look away, stand still, walk toward it, walk away, get under cover, stand in a real camp light, switch the monitor off, keep the real dog beside you, or nothing at all. Doing what works ends the encounter quietly, makes that family leave you alone for the night and eases the exposure; provoking one into a peak outside safety tightens it.
- **Field notes** (last Journal tab) fill in as the player meets a family and then sees its rule work twice. They record what a thing does, never what it is or where it came from.
- No rule grants safety. `SafetyService.query()` stays the only authority; the lamp rule only asks it.
- **Work lamps** (`NightKit`, `WorkLamp`): the company sends two with each lot, kept in the lamp locker beside the parcel locker. The boss carries one out and sets it down; at night its 6 m pool is safe for a seven-minute battery, flickering for the last minute, and it recharges in daylight. This is what makes working at night possible.
- **Night work pays:** the sawmill has a night-shift switch. At night the saw only takes logs while the boss stays at the mill, and what it cuts then pays 50% more. It is loud, so the night's visits come faster while it runs.
- **The breaker:** on a disturbed island (pressure tier 2 or more) the camp's pole lamps can fail at most once a night: a six-second flicker, then their pools are unsafe until the breaker beside the lockers is reset. The camper and the battery lamps are unaffected.

## The contract (Phase 25)

- New campaigns sign for **three marked lots** of forest growing out from the camp's forest entrance: 30, 35 and 40 trees (105 in all), due by days 10, 20 and 30. Lot trees wear a band of company paint (orange, blue, yellow).
- The contract is fulfilled when every lot tree is down, its stump is out and its logs are accepted. The crew fells painted trees only, one lot at a time.
- The company pays an advance when a lot opens, a milestone when it is finished and a bonus if that is by its due day. Wood from any tree is still paid at the sawmill.
- The sizes come from measurement: five hatchet workers accepted about 3.6 to 3.9 tree-equivalents a day when the lots were sized, and 105 trees in 30 days is 3.5 a day. Since loads go straight to the sawmill, the same crew accepts about 4.7 to 8 a day, and in a seven-day simulated run closed lot 1 on day 5.
- Wood through the sawmill does not cover a fairly paid crew by itself; the lot advance, milestone and on-time bonus are where the profit is.
- Wood is paid at the sawmill per finished pallet, so the crew carries loads straight to its feed rack while it has room; the receiving cradle and the decks are the overflow.
- The rest of the island's 10,000 trees are optional wood. Clearing more of it across later seasons is planned (Phase 29).
- Campaigns started before this keep their whole-island contract.

## Leaving the island (owner decisions, 13 November 2026)

- **The hunt follows every contract, won or lost.** It is how the player leaves the island.
- **Won:** the company ship reaches the dock at dawn after three hunt days. Missing it strands the player.
- **Lost:** nobody is coming and the hunt has no end date, so it is a matter of time. The one other way off is much harder: repair the dead emergency beacon in the dock building (three parts, spread across the island), switch it on and hold out until the ship it calls arrives at the next dawn.
- **Worker risk before the hunt is allowed:** a worker may go missing overnight and return at dawn.
- **Mystery:** never explain where the Terrors come from. Give each one a rule the player can learn.
- The full plan these decisions belong to is in [design/COMPLETE_GAME_REVIEW.md](design/COMPLETE_GAME_REVIEW.md).

## Explicitly out of scope (unless separately requested)

Combat, hunger meters, weapon shops, fuel/durability grinds for tools, vehicles beyond the two pickups, crafting trees, multiplayer, supernatural lore explanations, a second web/Three.js version.

## Current phase

Phase 23 (pack-21 prompt 21) added seeded dynamic weather: seven storm profiles that approach, build, peak and recover, lightning with real per-listener thunder delay, wet glass, puddles and heavier seas. It also added a masking model the Foreman hears through, the Thunder Walker (moves only while thunder covers its steps) and 12 storm encounter variants. Phase 22 (owner request) lengthened each workday to 20 minutes of daylight plus 5 of dusk; the contract stays 30 days for now (a 100-day contract with more content and a 3-day hunt is planned). Phase 21 added per-worker pay, pay mood and the Payroll app. Phases 0–20 are implemented; Phase 20 closed the planned roadmap with a release-candidate verification (verdict: TEST CANDIDATE, see PHASE20_RC_REPORT.md). It added the missed-night camera recordings with an isolated playback reconstruction, rare sleep interruptions, two save/extraction fixes and native launch checks of the exported Windows and Linux builds. It found one owner-level blocker: the 10,000-tree contract is not completable under the fixed rules at measured crew throughput. Later phases address named defects or requested additions only. Phase 19: a crew day has a shape (daily roles from kit, traits and backlog, a transport plan, a midday gathering with the dog and talk about real work). The five-night hunt gets fair, evidence-based cover: dense thickets, far field sheds with back hatches and a dock gear chest; nothing is a safe zone, and a seen entry is evidence. An ambient offshore survey vessel makes one exact lap of the island every three contract days, and its helicopter surveys the camp; 120 crew lines react to what each worker actually saw or heard. Phase 18: every crew line is voiced (2,828 offline clips in five persistent synthetic worker voices plus two replacement voices, five context deliveries), spoken positionally from the speaker with clip-timed captions and simple mouth motion. Phase 17 added 1,676 authored crew lines spoken through a context- and knowledge-aware conversation runtime (text only until Phase 18), and a 5,500+ unit offline fictional internet (mail, news, forums, advisories, archives) published by the campaign clock on the camper computer, with a director-checked window warning. Phase 16 added persistent employee profiles, a conserved merit ledger (at most 1,000 per tree, split by real contribution) feeding career levels and four capped skills, daily reviews that name real causes, and the boss's restedness with a bedtime forecast and bounded next-day effects. Phase 15 added a library of 200 original procedural sounds and a source-based spatial audio service (per-source occlusion by material, door portals, room reverb, travel delay, origin kinds that keep relay/replay out of the microphones, AI hearing independent of the mix); nothing has been listened to on real audio hardware yet. Phase 14 added stronger per-hit axes, the chainsaw, boots/gloves/helmets, the camper computer's supplier with boat deliveries to a parcel locker, crew gear, fall-lane coordination and two-person carries. Phase 13 added longer logs for new campaigns, the logging yard (cradle, decks, fire loading pile), dragging, the handcart and crew yard work. Phase 12 added the dense 10,000-tree island with cover and hiding, the owner's motion-capture clips, and proper fabrics. Earlier phases built: the island; the axe and felling; timber, carrying, delivery and the fuel-driven burn pit; workdays, the 30-day contract, exact delivery income, payroll with arrears, owned axes, sleep and reports, and save slots. See PHASE_CHECKLIST.md for exact status and ARCHITECTURE.md for the authoritative values.

## Phase 0 scope (this pack)

Phase 0 is the atmospheric, explorable world foundation, plus interfaces for later systems. No cutting, economy or horror director yet. See PHASE_CHECKLIST.md.
