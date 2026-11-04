# One More Tree: player guide

## Starting

- **Continue** loads your most recent unfinished campaign (the slot, its state and save time are shown under the button).
- **New Campaign** gives a short brief and asks for a slot. A slot that already has a save always asks before replacing it (the old save is kept once as a `.bak`).
- **Load** lists every slot with its state (contract day, survival day, completed, finished), logs delivered, cash, save time and any checkpoints.
- Before playing, open **Settings** to set text size, captions, horror intensity, flash reduction, head-bob, camera shake and key bindings.

## Your first day

A short guide in the top-right walks you through real work: walk, read the contract in the Journal, meet the crew and Biscuit, find the delivery rack, fell a tree, cut it into logs, carry one and deliver it (the money you see is the real payment), check wages, then get the night rules and sleep. Each step finishes when you actually do the thing, in any order and with any keys. **Journal → Help & log** lets you skip a step, skip the guide (you then get a one-page rules summary) or replay the hints. Replaying never changes your trees or money.

## Money and crew

- $100 per original tree, paid in shares as each log is accepted at the rack. Felling alone pays nothing.
- Each active employee costs $300 a day, settled when you sleep. Unpaid wages stay owed from their day; one more unpaid workday and that worker leaves. Paying part doesn't reset that.
- Example: two workers cost $600 a day. Five whole trees delivered that day earns $500, so you are $100 short on wages. A worker pays for themselves only by delivering more than three trees' worth of logs a day.
- Axes: small ×1.00, medium ×1.40, large ×1.96 cutting rate. Hard-working: ×1.25. Stronger: carries more by hand. Timid: frightens sooner and heads home earlier.

## Nights (during the contract)

- Dusk lasts five minutes. Warnings come at its start, halfway and one minute before night.
- **Safe at night:** the camper (always, even with the door open), an occupied cabin, and the pools of the working camp lamps. Moonlight, flashlights and screens don't count.
- Night only ends when you sleep. Waiting doesn't bring morning. Staying out at night can end the attempt; you can reload that morning's checkpoint.

## If the contract fails

The company leaves. You get a rules card (the game is paused until you continue). For five continuous days, something physical hunts you. Lamps and the camper no longer guarantee safety. Hide, break line of sight and move quietly. A rescue ship comes to the dock at dawn on day 36. Biscuit waits safely in the dock building and boards automatically.

## If you finish

The moment the last tree, stump and log are done, the contract completes. You don't need to wait for day 30, and logs still burning don't matter. You get a summary from your real ledger, and then you can return to the menu (the completed save is kept) or keep exploring the cleared island with no clock, wages or night.

## What pauses

The pause menu, Settings, Help, the Journal and management screens, rule cards and the arcade games pause everything. The couch and TV, talking, hiding and driving are live. See [TIME_AND_STATE.md](TIME_AND_STATE.md).

## Testing a build quickly

1. New Campaign → follow the guide through the first delivery (about 10 minutes).
2. Settings → rebind Interact, then check the on-screen prompts change.
3. Preview Tour (Tab) → Phase 6 stops → "Abandon -> hunt" for the hunt rules card; "Hunt: ship" for boarding.
4. Journal → Contract → "Locate the nearest remaining work".
