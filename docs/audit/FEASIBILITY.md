# Thirty-day workload and economy feasibility

## Phase 9 re-measurement and projection

**Method.** One full 20-minute workday per strategy, run through the real rules at 60 Hz (`tools/workload_sim.tscn`, headless accelerated agent simulation). The days were then projected over 30 days with `tools/balance_projection.py`, using the real prices (`economy_config.gd`) and real constraints: you can't spend cash you don't have, unpaid wages carry over, and an employee leaves after the following unpaid workday. This is **not** a human playthrough. It assumes every day repeats the measured day (no fear refusals, weather, learning curve or onboarding time), which is optimistic.

Phase 9 added no costs to the simulated work loop (the guide and UI are cosmetic, and the animations are presentation-only). The 2-worker day re-measured after Phase 8 and 9 gives **3.00 tree-eq accepted, $300 paid, 6 felled, 4 stumps**, identical to Phase 7. The mixed and full-crew rows use the Phase 7 measurements; Phase 8 and 9 did not touch the work rules.

| Strategy | Upfront cost | Affordable at start ($2,000)? | Measured tree-eq/day | Wages/day | Margin/day | Crew leave (unpaid) on day | Cash day 30 | Trees delivered by day 30 (boss alone afterwards: assumed 1/day, not measured) | Share of 12,000 |
|---|---|---|---|---|---|---|---|---|---|
| Modest crew, no truck (2 workers, small axes) | $0 | yes | 3.00 | $600 | -300 | 8 | $2200 | 46 | 0.4 % |
| Practical growth (3 workers, medium axe, 1 truck) | $11,500 | no (falls back to 2 workers, small axes) | 4.22 | $900 | -478 | 8 | $2200 | 46 | 0.4 % |
| Full crew (5 workers, large axe, 2 trucks) | $25,500 | no (falls back to 2 workers, small axes) | 7.01 | $1500 | -799 | 8 | $2200 | 46 | 0.4 % |


**Findings.**
- Every measured strategy loses money every day: wages are $300 per worker-day, and a worker currently delivers about 1–1.5 tree-eq a day ($100–150).
- The truck ($9,000), hires ($1,000) and better axes ($1,500 / $4,500) can't be afforded from the $2,000 start. The economy never generates the cash, so "growth" strategies aren't reachable. Hiring is currently a trap, not a decision.
- Unpaid crew leave around day 8. About 0.4 % of the 12,000-tree island is delivered by day 30.
- For hiring to pay, a worker must deliver more than 3 trees' worth of logs per day. To clear 12,000 trees in 30 days with 6 people, each person would need about 67 trees a day (about 55× today's full-crew rate per person).

**Decision.** The standard configuration stays **12,000 trees, unverified and not completable at current tuning**, per the owner's decision (Phase 7) and their planned faster cutting and longer days. Phase 9 does not change any fixed term or any running save. When the speed-ups land, re-run:

```bash
SCEN=hand2 godot --headless res://tools/workload_sim.tscn
SCEN=mixed3 godot --headless res://tools/workload_sim.tscn
SCEN=full5 godot --headless res://tools/workload_sim.tscn
python3 tools/balance_projection.py hand2=<a> mixed3=<b> full5=<c>
```

The variables that can be tuned without touching the fixed terms are tree work time, sectioning time, the new-campaign tree count, and the axe, truck and hire prices.

---

# Phase 7 measurements

All numbers below were **measured** through the real game rules: worker AI, navigation, felling physics, bucking, hand hauling, truck teams and rack acceptance, at 60 Hz simulated time for one full 20-minute workday per run (`tools/workload_sim.tscn`, `tools/crew_sim.tscn`, `tools/truck_sim.tscn`, Preview, never saved). They are simulation estimates, not human play.

## Fixed terms (yours, unchanged)

30 days · 15 min daylight + 5 min dusk · $100 per original tree, paid only when its logs are accepted · $300 per employee per worked day · 2 starting, 5 maximum employees · 2 pickups, 3 seats and 3 tree-equivalents each · hand load 1/3 tree-eq (Stronger 1/2) · axes 1.00 / 1.40 / 1.96 · Hard-working ×1.25.

## What the current island asks for

| Quantity | Value |
|---|---|
| Original native trees (current world, generation 1) | 12,000 |
| Trees (and stumps) per day to finish in 30 days | **400** |
| Truck loads if every tree went by truck (3 tree-eq/load) | 4,000 → ~67 per truck per day, one every ~18 s of daylight+dusk |
| Hand trips if carried (1/3 tree-eq) | 36,000 |
| Maximum contract income | $1,200,000 |
| Wages for a full crew for 30 days | $45,000 |

## Measured throughput (one day each)

| Scenario | Crew / tools | Trees felled | Stumps out | Delivered (tree-eq) | Paid | Wages | Walking / swinging (s, all workers) | Stuck events | In bed at nightfall |
|---|---|---|---|---|---|---|---|---|---|
| Early, hand hauling (`hand2`) | 2 workers, small axes | 6 | 4 | **3.00** | $300 | $600 | 1,929 / 209 | 5 | 2 / 2 |
| First truck (`mixed3`) | 3 workers, medium axes, 1 truck team + 1 by hand | 6 | 5 | **4.22** (2.89 by truck) | $421 | $900 | 2,772 / 165 | 7 | 1 / 3 |
| Full operation (`full5`), before the Phase 7 logistics fixes | 5 workers, large axes, 2 truck teams | 5 | 0 | 3.37 (all by truck) | $336 | $1,500 | 1,973 / 66 | 1 | 5 / 5 (home by 1,140 s) |
| **Full operation (`full5`), after the fixes** (truck waypoint progress guard; team members who miss departure go back to work) | 5 workers, large axes, 2 truck teams | 11 | 9 | **7.01** (5.18 by truck) | $701 | $1,500 | 4,920 / 169 | 9 | 5 / 5 |
| Late distant cleanup (`far5`) | as `full5`, ~270 m from camp | 5 | 0 | **0.00** | $0 | $1,500 | 559 / 31 | 0 | 0 / 5 |
| Phase 4 hand crew (`crew_sim`) | 5 workers, small axes, hand | 9 | — | 4.65 | $464 | $1,500 | 4,751 / 252 | 11 | 5 / 5 |
| Phase 5 single team (`truck_sim`, two runs) | 2 workers, 1 truck | — | — | 3.07 / 2.90 | $306 / $300 | $600 | — | 6 / 9 | home |

**Best measured day: about 7 tree-equivalents** (full crew, two trucks, after the fixes). At that rate a 30-day contract clears about **150–210 trees** once the early hand-hauling days are counted, under 2 % of the current island. Wages still exceed income in every measured configuration.

## Why (from the traces)

- Workers spend about **90 % of their time walking** and only a few minutes a day swinging. Cutting speed (axes, Hard-working) barely matters at this scale.
- Truck teams spend most of the day gathering, boarding, driving and waiting for the bed to fill. Loading is done by walking single logs to the tailgate, so a full bed takes a team most of an hour of game time.
- Distant work is dominated by travel: the far run delivered nothing before it had to turn back for dusk.

## Theoretical ceiling under the fixed terms (generous)

A truck parked beside a cut area, with two loaders, a short drive (70 m) and instant felling: about 2 minutes per round trip, so roughly 9 loads (27 tree-eq) per truck per day. Two trucks plus hand haulers give at most about **55–60 tree-eq per day, about 1,700 trees in 30 days**, before felling and stump time, distant regions, dusk margins, fear or mistakes. **12,000 trees cannot be cleared in 30 days under these fixed terms, even in theory.**

## What would make the contract feasible (decision needed)

Changing the island is a world regeneration (new generation version, frozen data and hashes), so existing saves need an explicit legacy rule set. I have **not** made that change without your decision.

1. **Fewer native trees for new campaigns** (unfixed tuning): about **400–900 harvestable trees**, concentrated in dense stands near trails and the camp so the island still reads as woodland. Shrubs, saplings and ferns provide cover (clearly not target trees). Existing saves keep their 12,000-tree island as a labelled legacy contract.
2. **Logistics efficiency** (also unfixed): truck teams fell and buck beside the parked truck and load directly, with loaders cycling short distances; queue/claim tuning at the rack; fewer, larger log sections per tree (same $100 and tree-equivalent per tree). The goal is **15–25 tree-eq per truck team per day**.
3. Both together give a hard but finishable contract: for example ~600 trees needs ~20 per day, reachable with two efficient truck teams by mid-campaign.

## Decision (owner, Phase 7)

**Keep the 12,000-tree island.** No world regeneration or save migration. With today's tuning the contract cannot be finished in 30 days: the best measured day is about 7 tree-equivalents against 400 needed.

**Planned (owner):** much faster cutting methods and a longer day, eventually about double the time of day. When they land, re-measure with `tools/workload_sim.tscn` (scenarios `hand2`, `mixed3`, `full5`, `far5`) and update this table. Note that hauling, not cutting, is the measured bottleneck: walking is about 90 % of worker time, and each truck carries 3 tree-eq per load. Faster cutting alone will not close the gap. A longer day raises everything roughly in proportion; faster loading, unloading and hauling methods would matter most.
