# Phase 13: logging yard, longer logs and storage

Status key:
- **observed:** an automated test, a headless probe or a software-renderer capture.
- **unrun:** implemented but not exercised.
- **gap:** not done.

Nothing here has been seen on a real GPU or played by a person.

## How it now plays

- **Longer logs (new campaigns).** A felled tree is bucked into fewer, longer logs:
  - about 6.8 logs per tree at a mean of 1.71 m, instead of 8.8 logs at 1.31 m (Preview → "Longer logs" measures this live);
  - each tree is still exactly $100 and exactly 1 tree-equivalent.
- **Oversized logs.** A log heavier than one hand load (up to two hand loads) can't be lifted, but it can be **dragged** by one end:
  - half walking speed, no jumping, nothing else in your hands;
  - workers drag them too.
- **Logging yard.** The yard has three parts:
  - the **receiving cradle** beside the fire, which holds 12 logs;
  - **three log decks** outside the north-east fence, along a walkway;
  - the fire's **loading pile**, which holds 12 logs.
- **Paid on acceptance, only with room.** Delivered wood is accepted and paid the moment the yard takes it:
  - into the cradle, or straight onto the deck you deliver at;
  - if the cradle (or that deck) is full, the delivery is **refused and not paid**;
  - the log stays in your hands, cart or truck, and the message says why.
- **The fire burns only from its pile.** Paid logs must be carried from the cradle or a deck to the fire (E at the fire pit, or G near it).
  - Paid logs can never be dropped back into the woods or loaded onto the cart.
- **Handcart.** It is parked beside the fire.
  - Load up to 4 unpaid logs (1.1 tree-equivalent, each at most 3 m long).
  - Grab the handle (E) and push it. Turning is limited, and you move at 80 % speed.
  - At the cradle or a deck, press E to unload. Only what fits is accepted; the rest stays on the cart.
  - X or E lets go. If the cart snags, it lets go by itself. The cart's position and load are saved.
- **Crew yard work.** Journal → Crew → **Yard** assigns a worker to the yard full time: they move cradle logs onto decks and top up the fire pile.
  - Workers on Auto help on their own when the cradle is nearly full or the fire is about to run dry.
  - Workers who deliver to a full cradle stack straight onto a deck instead.
- **Trucks** unload what fits and keep the rest, with a message giving the reason.
- **Reports.** The end-of-day report now adds:
  - trees processed;
  - logs accepted, split by hand, handcart and truck;
  - tree-equivalents burned;
  - yard moves (stacked and fed);
  - yard stock (cradle, decks and room left, fire pile).
- **Journal and help.** The Journal shows paid stock in the yard separately from the fire pile. The help text explains the yard, the cart and dragging.

## Rulesets and saves (no destructive refresh)

| Campaign | Ruleset | Island | Cutting plan |
|---|---|---|---|
| New standard campaign | **`expanded_v3`** | r2 | **v2** (target length ×1.5, equal pieces, at most two hand loads each) |
| Phase 12 saves | `expanded_v2` | r2 | v1 (unchanged) |
| Phase 10 saves | `expanded_v1` | r1 (10k manifest) | v1 |
| Legacy saves | `contract_v1` | r1 (12k) | v1 |

- **The plan belongs to the tree record.** It is stored per record (`"plan"`), so a save never re-cuts existing logs. Records without a plan are v1.
- **Save schema 9.** Saves add the yard block to `timber`: the cradle, decks, logs mid-move, counters and the cart's position. Restore rules:
  - Only pieces with a receipt can be in the yard.
  - A piece saved mid-move goes back to where it was taken from (it is never re-paid and never lost).
- **Older saves (schema ≤ 8).** On first load, the old pit backlog moves onto the decks:
  - this happens exactly once, keeping 12 logs on the fire pile;
  - receipts, payments and burn progress do not change;
  - the move is recorded in the recovery log;
  - a second load does nothing.
- **Save menu.** The title-screen summary shows the yard stock.

## Conservation (what the tests prove)

Tests: `phase 13 units` and `phase 13 world` (both **observed**, passing), plus the updated Phase 2 timber ledger test.

- **Exact shares under plan v2.** For 600 sampled r2 trees:
  - the pieces sum to exactly 1,000 mTE and 10,000 cents per tree;
  - no tree has more pieces than under plan v1;
  - no piece exceeds 666 mTE (two hand loads).
- **Old rulesets are unchanged.** `expanded_v2`, `expanded_v1` and `contract_v1` keep plan v1.
- **Paid once.** A whole tree delivered at the cradle is paid exactly $100. Retries create no receipts, and a paid log in your hands is never paid again.
- **Full cradle.** A delivery to a full cradle is refused with a reason. The money doesn't change and the logs stay in your hands. Delivering onto a deck works.
- **Yard moves.** Logs move from the cradle to a deck and from a deck to the fire pile, and states follow (`ACCEPTED_STAGED` → `ACCEPTED_MOVING` → `ACCEPTED_RACKED` → `ACCEPTED_QUEUED`). The fire pile never exceeds 12.
- **One place per log.** After every step, each accepted log is in exactly one place: cradle, a deck, mid-move, fire pile, burning or consumed. No paid log is in anyone's hands unless it is a recorded yard move.
- **Reloads.**
  - Save and reload mid-move: same payments, and the log is back in the yard.
  - "Ash clean" is not reported while paid logs are still in the yard.
  - Old-queue migration happens once and doesn't change payments.
- **Cart.**
  - With room for 2 logs in the cradle, 2 are accepted and paid, and the rest stay on the cart unpaid with a reason.
  - The cart's position and load survive a reload.
- **Dragging.**
  - An oversized piece can't be lifted, and the message suggests dragging.
  - With drag allowed, it is picked up and `is_dragging` is true.
- **Zero workers.** All of the above uses the player alone, so the chain works with no crew.

## Capacity and throughput (measured)

| Store | Capacity | Notes |
|---|---|---|
| Receiving cradle | 12 logs ≈ 1.8 TE | |
| Three log decks | **141 logs ≈ 22.6 TE** (plan v2); 156 logs ≈ 18.3 TE (plan v1) | Probe fills the decks with real logs from random trees, packed by real diameter, largest at the bottom |
| Fire loading pile | 12 logs ≈ 1.8 TE | |
| Burn rate | 4.2 mTE/s base, up to ×4 with a full pile ≈ **20 TE per 20-minute day** | Overnight burn is limited to what is on the pile |

- **Crew probe** (5 workers on Yard from a cold start, 90 s, Preview fixture): 4 logs stacked on decks and 2 fed to the fire. Walking from the cabin dominates a short window like this. Full-day crew throughput is **unrun**.
- **How this compares with measured logging.** The best measured intake (Phase 9/10) was about 7 TE a day.
  - The yard (≈ 26 TE including the cradle and pile) holds 3 to 4 days of that intake without any feeding.
  - A well-fed fire burns about 3 times that intake.
  - If deliveries outpace feeding for long enough, the cradle and decks fill and deliveries are refused until logs go to the fire. This is the intended pressure.
- **Finishing the contract.** Paid logs in the yard or the fire never block completion.

## Review

Preview (title screen) → Tab → **"Phase 13 logging yard, longer logs & cart"** has these stops. All of them are in memory and never saved.
- yard overview;
- stock fixture;
- full cradle (try to deliver);
- handcart (you hold 3 logs);
- drag an oversized log;
- feed the fire from a deck;
- crew yard work;
- plan v1/v2 comparison.

Screenshots (software renderer): `docs/screenshots/phase13_yard.png`, `phase13_decks.png`, `phase13_cradle.png`, `phase13_cart.png`.

## Fixed while testing

- **Deck logs drawn as giant upright discs.** The scale was applied after the rotation, and the triangles were wound inside out. Fixed, and the screenshots were retaken.
- **Deliveries at deck 3 checked against deck 2.** The decks are 6.4 m apart, inside the old 6.5 m match radius. Deliveries now go to the nearest deck.
- **Decks filled at about 40 % of capacity.** Packing was in arrival order. It now packs the largest diameters first, which raised capacity from 14.8 to 22.6 TE.
- **Cart logs drawn off the end of the cart.** The mesh was offset twice. Fixed.

## Known limits (honest)

- **Skidding.** Dragging is a slow carry with a drag pose, not a physics skid; the log doesn't plough the ground.
- **Cart physics.** The cart is kinematic: it follows the pusher with bounded turning and stops when blocked. It does not roll on its own.
- **Deck stacking is deterministic, not physical.** Logs rest in computed slots; nothing rolls off a deck.
- **Crew yard throughput** over a full day hasn't been measured.
- **No real-GPU check.** The yard and the longer logs were only seen on a software renderer.
