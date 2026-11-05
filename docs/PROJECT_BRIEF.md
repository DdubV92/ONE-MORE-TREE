# Project brief: One More Tree

**Genre:** first-person, single-player, cozy logging on a large, finite island.
**Engine:** Godot 4.5.1-stable, Forward+, typed GDScript, native desktop (Windows test builds via CI).

## Core loop (whole game)

- Cut every original tree on the island. Process the fallen timber, then dispose of it in the camp burn pit.
- Felling trees during the day earns money. Spend it on a medium or large axe.
- Later, hire up to four workers. Each costs a hiring fee plus daily wages, and workers use the same axe tiers.
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
- Outdoors, safety exists only inside the fence AND within a working designated camp lamp's radius. Flashlights, the fire, moonlight, distant glow and screen brightness never grant safety. The published rules equal the code: see `SafetyService` and ARCHITECTURE.md.
- Workers stop before dusk and the dog goes inside.
- Staying awake escalates apparitions, sound and stalking impressions. A catch and jumpscare can only happen outside authoritative safety after sufficient escalation.
- Night is a bounded state, and morning starts only after sleeping:
  - Sleep is always available at night and resets escalation.
  - A camper holdout can't be killed. It also can't advance to morning by waiting, changing the real clock, or leaving the program open.
  - The night clock may reach its terminal time while an independent awake timer keeps pacing.
  - Menus pause both.

## Explicitly out of scope (unless separately requested)

Combat, hunger meters, weapon shops, fuel/durability grinds for tools, vehicles beyond the two pickups, crafting trees, multiplayer, supernatural lore explanations, a second web/Three.js version.

## Current phase

Phases 0–20 are implemented; Phase 20 closed the planned roadmap with a release-candidate verification (verdict: TEST CANDIDATE, see PHASE20_RC_REPORT.md). It added the missed-night camera recordings with an isolated playback reconstruction, rare sleep interruptions, two save/extraction fixes and native launch checks of the exported Windows and Linux builds. It found one owner-level blocker: the 10,000-tree contract is not completable under the fixed rules at measured crew throughput. Later phases address named defects or requested additions only. Phase 19: a crew day has a shape (daily roles from kit, traits and backlog, a transport plan, a midday gathering with the dog and talk about real work). The five-night hunt gets fair, evidence-based cover: dense thickets, far field sheds with back hatches and a dock gear chest; nothing is a safe zone, and a seen entry is evidence. An ambient offshore survey vessel makes one exact lap of the island every three contract days, and its helicopter surveys the camp; 120 crew lines react to what each worker actually saw or heard. Phase 18: every crew line is voiced (2,828 offline clips in five persistent synthetic worker voices plus two replacement voices, five context deliveries), spoken positionally from the speaker with clip-timed captions and simple mouth motion. Phase 17 added 1,676 authored crew lines spoken through a context- and knowledge-aware conversation runtime (text only until Phase 18), and a 5,500+ unit offline fictional internet (mail, news, forums, advisories, archives) published by the campaign clock on the camper computer, with a director-checked window warning. Phase 16 added persistent employee profiles, a conserved merit ledger (at most 1,000 per tree, split by real contribution) feeding career levels and four capped skills, daily reviews that name real causes, and the boss's restedness with a bedtime forecast and bounded next-day effects. Phase 15 added a library of 200 original procedural sounds and a source-based spatial audio service (per-source occlusion by material, door portals, room reverb, travel delay, origin kinds that keep relay/replay out of the microphones, AI hearing independent of the mix); nothing has been listened to on real audio hardware yet. Phase 14 added stronger per-hit axes, the chainsaw, boots/gloves/helmets, the camper computer's supplier with boat deliveries to a parcel locker, crew gear, fall-lane coordination and two-person carries. Phase 13 added longer logs for new campaigns, the logging yard (cradle, decks, fire loading pile), dragging, the handcart and crew yard work. Phase 12 added the dense 10,000-tree island with cover and hiding, the owner's motion-capture clips, and proper fabrics. Earlier phases built: the island; the axe and felling; timber, carrying, delivery and the fuel-driven burn pit; workdays, the 30-day contract, exact delivery income, payroll with arrears, owned axes, sleep and reports, and save slots. See PHASE_CHECKLIST.md for exact status and ARCHITECTURE.md for the authoritative values.

## Phase 0 scope (this pack)

Phase 0 is the atmospheric, explorable world foundation, plus interfaces for later systems. No cutting, economy or horror director yet. See PHASE_CHECKLIST.md.
