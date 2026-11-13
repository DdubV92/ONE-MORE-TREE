# One More Tree: player guide

## Starting

- **Continue** loads your most recent unfinished campaign (the slot, its state and save time are shown under the button).
- **New Campaign** gives a short brief and asks for a slot. A slot that already has a save always asks before replacing it (the old save is kept once as a `.bak`).
- **Load** lists every slot with its state (contract day, survival day, completed, finished), logs delivered, cash, save time and any checkpoints.
- Before playing, open **Settings** to set text size, captions, horror intensity, flash reduction, head-bob, camera shake and key bindings.

## Your first day

A short guide in the top-right walks you through real work: walk, read the contract in the Journal, meet the crew and Biscuit, find the delivery rack, fell a tree, cut it into logs, carry one and deliver it (the money you see is the real payment), check wages, then get the night rules and sleep. Each step finishes when you actually do the thing, in any order and with any keys. **Journal → Help & log** lets you skip a step, skip the guide (you then get a one-page rules summary) or replay the hints. Replaying never changes your trees or money.

## The contract: three lots

- You sign for three marked lots of forest just outside the camp's forest entrance. Lot 1 has 30 trees (orange paint, due by day 10), lot 2 has 35 (blue, day 20) and lot 3 has 40 (yellow, day 30).
- A lot is finished when every painted tree is down, its stump is out and its logs are delivered. Journal → Contract shows each lot's progress.
- The company pays an advance when a lot opens ($3,000, $3,500, $4,000), the same again when it is finished, and a bonus ($1,500, $2,000, $2,500) if that is by its due day.
- Your crew fells painted trees only. You can cut any tree: wood from outside the lots is still paid at the sawmill, but it does not count toward the contract.
- Finish all three lots by nightfall on day 30 and the contract is won.

## Money and crew

- $100 per original tree, paid in shares as each log is accepted at the camp yard (the receiving cradle by the fire, or a log deck outside the north-east fence). If there's no room, the delivery is refused and not paid until there is. Felling alone pays nothing.
- The fire burns only what's on its loading pile. Carry paid logs from the cradle or decks to the fire, or put a worker on **Yard** duty. The handcart by the fire moves 4 logs at once, and logs too heavy to lift can be dragged.
- Each worker has their own daily rate, at least $100, set in the Payroll app on the camper computer, plus any bonuses; it is settled when you sleep. Pay below what a worker feels is fair makes them unhappy, and they may quit (always with at least one day's "on the verge" warning). Unpaid wages stay owed from their day; one more unpaid workday and that worker leaves. Paying part doesn't reset that.
- Example: two workers on $100 cost $200 a day. Two whole trees delivered that day earn that back ($100 a tree).
- Axes: small ×1.00, medium ×1.40, large ×1.96 cutting rate. Hard-working: ×1.25. Stronger: carries more by hand. Timid: frightens sooner and heads home earlier.

## Nights (during the contract)

- A workday is 20 minutes of daylight and 5 minutes of dusk. Warnings come at the start of dusk, halfway and one minute before night.
- **Safe at night:** the camper (always, even with the door open), an occupied cabin, and the pools of the working camp lamps. Moonlight, flashlights and screens don't count.
- Night only ends when you sleep. Waiting doesn't bring morning. Staying out at night can end the attempt; you can reload that morning's checkpoint.

## After the contract: the hunt

The hunt follows every contract. You get a rules card first (the game is paused until you continue). Something physical hunts you; lamps and the camper no longer guarantee safety. Hide, break line of sight and move quietly. Biscuit waits safely in the dock building and boards any ship on her own.

- **If you finished the contract:** survive three days. The company ship reaches the dock at dawn, and boarding stays open for 8 minutes. Your end summary includes the finished job's figures.
- **If you did not:** no ship is coming, and the thing hunting you guesses better the longer you last. The only way off is the emergency beacon in the dock building, which is dead.
  1. Check the beacon. It lists the three missing parts and where the spares are kept: two far field sheds and the sawmill control box.
  2. Fetch them. Taking each one makes noise.
  3. Fit them at the beacon and switch it on. It is loud, and it draws the hunter to the dock until the ship arrives at the next dawn.
  4. Board within 4 minutes.
- **If you miss a ship:** it leaves, and you are in the second case. The beacon has to be used (or used again).

## What pauses

The pause menu, Settings, Help, the Journal and management screens, rule cards and the arcade games pause everything. The couch and TV, talking, hiding and driving are live. See [TIME_AND_STATE.md](TIME_AND_STATE.md).

## Testing a build quickly

1. New Campaign → follow the guide through the first delivery (about 10 minutes).
2. Settings → rebind Interact, then check the on-screen prompts change.
3. Preview Tour (Tab) → Phase 6 stops → "Abandon -> hunt" for the hunt rules card; "Hunt: ship" for boarding.
4. Journal → Contract → "Locate the nearest remaining work".
