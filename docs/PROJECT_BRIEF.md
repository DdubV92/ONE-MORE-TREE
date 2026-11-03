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
- Slow-burning outdoor timber pit.
- Worker cabin with an arcade corner: four beds plus an attached two-bed bedroom, kitchen and bathroom (six beds).
- The player's camper: mini kitchen, bathroom, bedroom, player bed and dog bed.

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

Combat, hunger meters, weapon shops, chainsaws, vehicles, crafting trees, multiplayer, supernatural lore explanations, a second web/Three.js version.

## Current phase

Phases 0–4 are implemented (Phase 4: the living crew): the island; the axe and felling; timber, carrying, delivery and the fuel-driven burn pit; workdays, the 30-day contract, exact delivery income, payroll with arrears, owned axes, sleep and reports, and save slots. See PHASE_CHECKLIST.md for exact status and ARCHITECTURE.md for the authoritative values.

## Phase 0 scope (this pack)

Phase 0 is the atmospheric, explorable world foundation, plus interfaces for later systems. No cutting, economy or horror director yet. See PHASE_CHECKLIST.md.
