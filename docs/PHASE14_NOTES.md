# Phase 14: stronger axes, chainsaws, gear, the supplier and coordinated logging

Status key:
- **observed:** an automated test, a headless probe or simulation, or a software-renderer capture.
- **unrun:** implemented but not exercised.
- **gap:** not done.

Nothing here has been seen on a real GPU, listened to, or played by a person.

## How the logging loop now behaves

### Axes
- **Same rhythm, deeper bite.** All three axes swing at one legal rhythm (one hit every 0.95 s). The upgrade is how much each valid hit does: ×1.00, ×1.40, ×1.96.
- **Output unchanged.** Work per second is exactly what Phases 1–13 gave, so no tree progress was rescaled.
- **Input.** Hold-to-chop and clicking share the same cadence: one buffered press, no extra hits.

### Chainsaw
- **Controls.** Key `4` holds the saw. `R` starts it, or just squeeze the attack button. Hold attack for throttle; `R` stops it.
- **Engine states.** The engine is an explicit machine: stopped, starting (1.5 s pull), idle, free-running, cutting, spinning down, stopping.
- **When it cuts.** Work happens only while the running chain is at cutting speed AND the bar is in the selected wood:
  - a standing tree;
  - a cuttable boundary of resting timber;
  - a ready stump.

  It must be the first thing along the bar: a wall or another trunk in front blocks it. Throttle at the sky does nothing.
- **Frame-rate safety.** Work is committed in fixed 0.1 s ticks. Each step is clamped, so a hitch, a pause or a load can't release a burst of damage.
- **When it stops.** The saw stops at once when you:
  - hide, sit (couch or desk computer), drive or ride;
  - pick up logs;
  - switch to an axe;
  - sleep.

  It is never left running in a seat.
- **Ownership.** The player and any employee issued a saw can use it. Workers start it once per job, cut in a leaning two-handed stance and shut it off when they move on.
- **Not a weapon.** There is no damage to people, the dog or the Foreman.
- **During the hunt.** A running saw is ordinary hearing evidence at its real position (85 m loaded, 40 m idle), via `Game.hunt.noise`. It never reveals where a hidden player is.

### Gear
- **One item per slot.** A better tier replaces a worse one; tiers never stack.
- **Boots:** +3, +6 or +9 % walking. They apply on top of load, cart, water and slope, never to trucks.
- **Gloves:** +2, +4 or +6 % axe swing rhythm, plus a quicker saw start. They never change the saw's cutting rate.
- **Helmets:** +2, +4 or +6 % axe work per hit. This is an explicitly game-like camp-morale bonus, for axes only.
- **Smaller than an axe tier.** Full tier-3 gear on a hatchet is 1.12× (exactly 1.06 × 1.06), less than the medium axe's 1.40×.

### Supplier and parcel locker
- **Ordering.** The camper computer's **Supplier** app has:
  - a catalog with each item's exact benefit for you, computed by the same function the game uses;
  - a cart;
  - a quote showing the total, cash after, tonight's payroll, wages owed, a warning if the order leaves less than payroll, and the delivery time.

  Confirming is idempotent: a double click or a reopened app never charges twice.
- **Delivery schedule.**
  - Supply boats arrive at about 10:30 and 15:00 (campaign time) every day.
  - An order must be placed 2 minutes before a run; otherwise it takes the next one, which is tomorrow's 10:30 after the afternoon cutoff.
  - Nothing has to be ordered at night.
  - An order that couldn't arrive before the end of day 30 is refused up front.
- **Collecting.** Arrived orders wait in the **parcel locker**: a green steel cabinet by the payroll board, off the log, cart and truck routes. E collects them into **camp storage** (the tool rack) exactly once, never straight into a worker's hands.
- **Contract end.** If the contract closes with orders still at sea, each is refunded once and no boat comes. Parcels already in the locker stay collectable.
- **Gear app and tool rack.** The computer's **Gear** app and the tool rack (E) show:
  - your kit, with the exact breakdown;
  - what you own;
  - camp storage;
  - each employee's kit.

  You can equip, put away, give an item to an employee, or take it back.
- **Mail.** The computer's **Mail** app lists supplier confirmations and delivery notices generated from the real order records.

### Crew coordination
- **Felling lanes.** A tree being felled owns only its fall lane: a strip from the stump along the planned fall direction, the tree's height plus 4 m long and as wide as its crown. While the lane is active:
  - no one else is assigned a tree whose lane overlaps it;
  - no one is assigned a cut position, log, trunk or stump inside it;
  - routes bend around it (its cells cost 7× to cross);
  - at the warning crack, anyone else inside steps out sideways.

  The lane ends when the tree has settled into timber, 30 s after the fall at most, or when its feller leaves.
- **Claims expire.** A claim on a tree, trunk or stump whose owner left, changed job or stopped working on it is released within 4 s.
- **Stage division.**
  - A saw holder bucks and fells while axe hands haul first.
  - When the yard is nearly full (cradle full and room for fewer than ~10 logs on the decks), moving paid logs to the fire comes before cutting more, and nobody fells.
- **Two-person carry.** A log heavier than one hand load is carried by two workers when a free partner is near:
  - one cargo owner (the leader holds the timber record) and a follower at the far end, walking the leader's actual path;
  - both must be in place before the lift;
  - they move at the slower partner's carry speed × 0.9, not the sum;
  - if the follower is called away, flees or must head home, the leader keeps the log and drags it (the Phase 13 solo fallback, always within two hand loads), so nothing is dropped or duplicated;
  - teams aren't saved: after a load, the log restores in the leader's hands as a solo drag.

## The one calculation

Everything uses `ToolEffects.breakdown(kit)` in `scripts/economy/tool_effects.gd`: the player, every worker, the Supplier comparison, the Gear screens and the tests.

| Factor | Where it applies | Value |
|---|---|---|
| Base work per hit | axes | 1.0 |
| Axe tier | per hit | 1.00 / 1.40 / 1.96 |
| Hard-working (employees with the trait) | output only: work per hit, or saw rate, **once** | ×1.25 |
| Skill (Phase 16 hook) | output | 1.0 (neutral until implemented) |
| Helmet | axe work per hit | 1.02 / 1.04 / 1.06 |
| Gloves | axe cycle; saw start pull | ÷1.02 / 1.04 / 1.06 |
| Fatigue / restedness (Phase 16 hook) | output | 1.0 (neutral until implemented) |
| Boots | walking (controller base × load × water × cart × boots) | 1.03 / 1.06 / 1.09 |
| Chainsaw | work per second of loaded contact | 4.5 (4.3× a hatchet's steady 1.05) |

- Each slot holds one item, and the totals are clamped (walk ≤ 1.09, cadence ≤ 1.06, helmet ≤ 1.06).
- Gear never touches truck or cart capacity, or the Stronger hand budget.

## Prices (provisional, chosen against measured income)

| Item | Price |
|---|---|
| Felling axe | $800 |
| Heavy felling axe | $1,800 |
| Chainsaw | $2,800 |
| Boots | $90 / $200 / $400 |
| Gloves | $50 / $120 / $250 |
| Helmets | $70 / $160 / $320 |

Other rules:
- At most 6 of each item per camp (one per person).
- The starting hatchets stay free and can't be lost.
- Manual logging always works at $0.

Why these prices:
- A new standard campaign starts with $4,500 and pays $1,500 of wages a day.
- A five-worker hatchet day measured below earns about $334, far less than payroll. That is the existing Phase 10/13 feasibility gap: crews spend ~98 % of their time walking.
- Prices are therefore low enough that a saw ($2,800) is a real day-1 or day-2 choice, at the cost of a payroll night.
- The medium axe ($800) is an easy early step, and gear costs pocket money.
- With the current measured income, time-to-afford a saw from earnings alone is more than one day of the whole crew's pay. So buying one is a decision against wages, which the order screen warns about.

## Measured balance

**Cutting time per tree, cutting only.** 40 identical r2 trees (fell + every buck cut + crown + stump); real swing and saw machines; no walking. Source: `tools/tool_bench.tscn`.

| Tool | Seconds of cutting per tree | vs hatchet |
|---|---|---|
| Hatchet | 37.8 | 1.00 |
| Felling axe | 29.2 | 1.29 |
| Heavy axe | 21.1 | 1.79 |
| Heavy axe + t3 helmet + t3 gloves | 18.9 | 2.00 |
| Chainsaw | 11.7 | **3.23** |

- **Why the axes measure below 1.40 / 1.96.** Many buck cuts are small: a cut needing 1.6 units takes 2 hits with the hatchet and 1 with the large axe, but still a whole hit. That rounding is real play, not a bug.
- **Saw tuning.** The saw includes its start pull per tree and its spin-up per cut. At first it measured 2.89×, just below the 3–5× target. I shortened the spin-up to a realistic 0.3 s and set the rate to 4.5, which gives 3.23×.

**Whole pipeline.** One full simulated day on island r2: five workers, automatic jobs, real hauling, yard and fire. Source: `tools/crew_sim.tscn` with `CREW=5 ISLAND=island_r2 TOOL=...`.

| Crew tools | Trees felled | Tree-eq delivered (paid) | Cutting time | Walking time | Stuck events |
|---|---|---|---|---|---|
| Hatchets | 5 | 3.34 ($334) | 112 s | 5,624 s | 0 |
| Chainsaws | 7 | 4.80 ($480) | 134 s | 5,598 s | 5 (one worker, one spot; recovered) |

- **What the saw changes.** Saws turn about a 3× cutting advantage into **+44 % deliveries**. Walking to and from the woods dominates the day; cutting is under 3 % of crew time.
- **The real bottleneck.** That bottleneck is hauling distance, which the faster tool exposes rather than hides. Trucks, the cart and team carries are the levers.
- **What is not proven.** The full 10,000-tree campaign is NOT proven feasible by these numbers. At this rate it isn't, and that needs later balance work: route distance, truck use and staffing.
- **Team carry probe** (Preview fixture, headless): the pair formed, lifted once both were in place (~18 s, the leader walking out), carried together and delivered; the team ended cleanly.
- **Lane probe:** 14 tree choices were rejected because their fall line crossed live work. There were no step-outs in that window.

## Saves (schema 10)

- **Legacy axes.** Phase 3–13 axe records become item records once, with the same ids, owners and receipts. Owner "rack" becomes storage. Each employee's best axe is put in their tool slot. Nothing is granted, and restoring twice never duplicates.
- **What is saved.** Item slots, pending gear changes, orders and request ids are saved. Items always follow their order state on load.
- **What is not saved.** Engine state isn't saved: a saw always loads stopped, and committed tree progress is kept. Teams aren't saved either (see above).

## Tests

- **`phase 14 units`** checks:
  - axe ratios and the shared cadence;
  - agreement with the old config's work per second;
  - Hard-working applied once and on output only;
  - exact gear factors, and that gear stays smaller than a tier step;
  - the saw inside 3–5×, with helmet and gloves never raising the saw rate;
  - no saw work in the air or during the start pull;
  - saw ticks independent of frame step, with a 5 s hitch releasing at most one tick;
  - kill stops the saw at once;
  - legacy axes mapped once, re-restore without duplicates, boots replacement, transfer, departure back to storage, unique ids;
  - supplier: quote and payroll warning, double-confirm idempotency, schedule (same day, next run, next day, refused after day 30), dispatch and arrival, collect once, refund once at close, no orders after close, stock limit, save round-trip;
  - schema 9 → 10.
- **`phase 14 world`** checks:
  - the player saw cuts a real tree, by exactly rate × ticks;
  - pointing at the sky is not contact;
  - hiding and switching to an axe stop the saw;
  - worker gear is issued mid-cut but only put on at a boundary, and recall is refused mid-cut;
  - a worker's saw does nothing during the start pull, works after it, and stops after leaving the cut;
  - lane geometry, route cost and its release;
  - a broken team keeps the log with its one owner;
  - the parcel locker collects an order exactly once.
- **Updated earlier tests:** the axe-purchase test uses catalog prices.
- **Full suite:** 58 / 58 passed.

## Review (Preview → Tab → "Phase 14 tools, gear, supplier & teamwork")

The stops are:
- axe comparison (`1`/`2`/`3` on one tree, with the exact numbers);
- chainsaw (try it);
- crew in gear;
- supplier order to parcel;
- coordinated felling lanes;
- two-person carry;
- gear and tool numbers.

All of them are in memory and never saved.

Screenshots (software renderer):
- `docs/screenshots/phase14_gear_lineup.png`
- `phase14_worker_saw.png`
- `phase14_saw_first_person.png`
- `phase14_saw_closeup.png`
- `phase14_parcel_locker.png`

## Sound (interim; Phase 15 owns the audio overhaul)

The chainsaw has five distinct procedural source layers in `audio/generated/saw_*.wav`, generated by `tools/generate_audio.gd` with their own seed so earlier sounds are unchanged:
- start: two cord pulls, a cough, then the engine catches;
- idle;
- free-rev;
- loaded cut: a labouring engine plus tooth-rate wood rasp;
- stop: wind-down.

They play from 3D players at the tool, on the Work bus, crossfaded by the real engine state and speed.

**Gaps:** these are synthetic two-stroke approximations that no one has listened to. They are not convincing recordings and should be replaced by licensed or recorded saws in Phase 15. Interior occlusion uses the existing positional routing only.

## Fixed while testing

- **Phase 13 worker drag never engaged.** The drag flag was set before `start_pick()` replaced the worker's target, so a worker could never actually drag an oversized log.
- **Phase 13 dragged-log visual offset twice.** The worker's dragged log was offset along its own axis a second time (the same mistake as the cart, fixed in Phase 13).
- **Saw stance.** The worker saw stance first leaned backwards (pitch sign); now it leans into the cut.
- **First-person saw hidden.** The housing hid the bar; it is now held right of centre with the bar angled in.

## Known limits (honest)

- **No playtest.** No real GPU, no listening, no human playtest. The grip, the weight of the swings, team movement and comfort need hands-on review.
- **Stylized hands.** Worker hands are IK-placed near the saw handles (stylized), not finger-accurate.
- **Team carry is visual-kinematic.** The follower walks the leader's breadcrumb trail. There is no physics on the log, and doorway turning sweep isn't simulated.
- **No player in team carries.** The player can't take the other end of a team carry yet.
- **Feasibility unproven.** The 10,000-tree campaign is still not shown to be feasible (see the measurements above).
- **Phase 15 and 16 hooks.** Sound quality is Phase 15's; skill, merit and restedness factors are neutral hooks for Phase 16.
