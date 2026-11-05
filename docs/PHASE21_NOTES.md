# Phase 21: payroll, pay mood and quitting (owner request)

**Origin.** Owner request during Phase 20, queued until Phase 20 was published.

**Behaviour requested:**
- lower daily wages, with a **$100 minimum** per worker;
- a clean **Payroll app** on the camper computer listing workers, their productivity and their planned pay;
- optional raises and productivity-based payouts;
- workers on the minimum for too long may quit, depending on personality, and sometimes even +$50 is not enough;
- visible "on the verge of quitting";
- better gear and levels lead to raise requests, for the day or permanently;
- an end-of-day and end-of-game pay report on the computer.

**Systems affected:** `Payroll` (settlement), the new `PayMorale`, `CampaignService` (wiring, save, report), `CrewService` (hiring, departures), `CrewProgression` (morale → breaks), `DeskComputer` (the app), the UI texts, the tests and the review stations.

## Pay (`scripts/economy/pay_morale.gd`)

Each employee has:
- **Rate:** their own daily wage. Minimum **$100**, maximum $600, in $25 steps.
- **Bonus today:** a one-day bonus, cleared after the night.
- **Performance bonus:** 0 / 10 / 25 / 50% of the value of the work they really did that day:
  - value = merit tree-equivalents × $100;
  - one tree-equivalent is 1,000 merit, i.e. one tree felled, cut up, cleared and delivered.

**Settlement.** `Payroll.settle_day` charges exactly `planned_for()` once per worked day, itemised as base, bonus and performance. The rules for arrears, grace and quitting over unpaid wages are unchanged.

**Starting rates and old saves:**
- New campaigns start everyone at the $100 minimum.
- Hires start at the asking wage the hire screen showed.
- Saves from before Phase 21 keep **$300 for everyone**, so loading never cuts anybody's pay.

## Fair pay and pay mood

**Fair wage.** Every worker has a fair wage in their own eyes:

  **$100 + personality demand ($0–$120) + $6 per career level above 1 + $5 per gear point**

Gear points:

| Slot | Points |
|---|---|
| Tool | felling axe 2, heavy axe 3, chainsaw 4 |
| Boots, gloves, helmet | 1, 2 or 3 by tier |

**Personality.** Each worker has four values, seeded once from their id (or from the candidate id for hires), saved and never rerolled. Traits nudge them; for example, *timid* means less demanding, more patient and quieter, and *skeptical* means more demanding and less patient.
- **demand:** how far above the minimum their fair wage sits.
- **patience:** how slowly underpay wears them down.
- **assertiveness:** how readily they ask for raises.
- **pride in output:** how much a performance bonus counts for them, from 0.7× to 1.3× its cash value.

**Pay mood** (0–100%) moves once per settled night:

| Situation | Effect each night |
|---|---|
| Paid below their fair wage | Falls with the gap (−0.3 × gap, capped at −18%). Faster if impatient (× 1.35) and slower if patient (× 0.65) |
| On the bare minimum | Each extra night in a row costs a little more (1.2% × nights × impatience) |
| Paid fairly | Recovers by at least +3% |
| Wages not actually paid | −5% |
| A raise | Feels good at once (once a day) |
| A pay cut | Hurts more than a raise helps |

**Status words:**

| Mood | Status |
|---|---|
| 70% and above | Content |
| 45–70% | Okay |
| 25–45% | Unhappy |
| Below 25% | **On the verge of quitting** |

On the verge comes with a notice and the Payroll warning ("they would be happier around $X"). It always lasts **at least one full day** before anyone can quit.

**Quitting.** After at least one day on the verge, a worker leaves through the normal departure (walk to the dock, leave on the boat, still owed what they earned) if either:
- their mood is below 12%; or
- they have spent 3 nights on the verge.

**Measured** (`tests/test_runner.gd`, phase 21 units, real formulas):

| Worker | Fair wage | At $100 | At $150 (+$50) | At their fair wage |
|---|---|---|---|---|
| Modest and patient | $130 | Leaves after 8 nights | Stays | Stays |
| Demanding and impatient | $200 | Warned on night 3, leaves on night 4 | Leaves after 6 nights | Stays |

**Mood and work.** Mood is also the worker's morale. A content worker works as before. An unhappy one takes longer breaks between jobs, up to twice as long when about to quit. This shows up in their useful-work share.

## Raise requests

**Triggers.** Two things can prompt a request:
- better gear (2 or more extra gear points);
- a career level-up.

**When they ask.** Only if they are paid at least $15 below their new fair wage. The chance is 30% + 60% × assertiveness, rolled once per trigger (seeded).

**What they ask for.** Either "+$X a day" (the gap) or "a 1.6× bonus today".

**Your answers:**

| Answer | Effect on mood |
|---|---|
| Give raise | +8% |
| Bonus today | +4% |
| Decline | −5% to −15%, by assertiveness |

An unanswered request expires after the next night, as a softer decline.

## The Payroll app (camper computer → Payroll)

- **Crew page:**
  - **Table**, one row per worker: pay mood bar (white tick = the quitting line) and word, useful-work share today, work today in tree-equivalents, its value, rate, bonus, performance %, and tonight's pay.
  - **Detail panel:**
    - traits and temperament;
    - fair pay band, nights on the minimum and the verge warning;
    - rate, bonus and performance controls, and the exact sum for tonight;
    - any raise request with its three answers;
    - the last five nights.
- **Last night:** the pay report of the latest settlement per worker (rate, bonuses, earned, paid, fair, work, value, mood before → after, status or quit), plus totals.
- **Campaign report:** the end-of-game page, per worker and in total: days, rates, bonuses, total paid, average per day, work, value and status or reason for leaving. It ends with a line: "You paid $X in wages for work worth $Y."

**The report object.** The sleep report also carries the night's pay block as `report.pay`.

## Saves

`economy.pay`:
- **Contents:** `{version, workers, requests, nights, req_counter}`.
- **Absent in older saves:** every employee gets $300, as above.

## What this does not change

- The contract math (blocker B1 in `PHASE20_RC_REPORT.md`): five workers still produce a few tree-equivalents a day. Cheaper wages make cash last far longer, but the 10,000-tree target is still out of reach.
- Arrears: unpaid wages still lead to a departure.
