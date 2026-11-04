#!/usr/bin/env python3
"""Phase 9 campaign projection from MEASURED daily throughput.

Inputs are the per-day results of tools/workload_sim.tscn (one simulated
workday at 60 Hz through the real task rules, headless; accelerated agent
simulation, not human play). Prices come from scripts/economy/economy_config.gd.
The projection assumes every day repeats the measured day (no fear, refusals,
weather or learning curve), which is optimistic for a newcomer.

    python3 tools/balance_projection.py hand2=3.0 mixed3=4.22 full5=7.01
"""
import sys

START = 2000.0
WAGE = 300.0
HIRE = 1000.0
AXE = {"small": 0, "medium": 1500, "large": 4500}
TRUCK = 9000.0
TREE = 100.0
TREES = 12000

# strategy: workers, axe bought, trucks bought (purchases on day 1 if affordable, else when cash allows)
STRATS = {
    "hand2":  {"label": "Modest crew, no truck (2 workers, small axes)", "workers": 2, "hires": 0, "axe": "small", "trucks": 0},
    "mixed3": {"label": "Practical growth (3 workers, medium axe, 1 truck)", "workers": 3, "hires": 1, "axe": "medium", "trucks": 1},
    "full5":  {"label": "Full crew (5 workers, large axe, 2 trucks)", "workers": 5, "hires": 3, "axe": "large", "trucks": 2},
}


def project(key, te_per_day):
    """Day-by-day with the game's real constraints: purchases only when the
    cash exists, cash never negative, unpaid wages carried as arrears, and a
    worker with arrears older than one following workday leaves."""
    s = STRATS[key]
    capex = s["hires"] * HIRE + AXE[s["axe"]] + s["trucks"] * TRUCK
    affordable = capex <= START
    workers = s["workers"] if affordable else 2
    rate = te_per_day if affordable else measured_hand2
    cash = START - (capex if affordable else 0)
    arrears_days = 0
    arrears = 0.0
    delivered = 0.0
    quit_day = None
    rows = []
    for day in range(1, 31):
        if workers == 0:
            rate = measured_boss
        income = rate * TREE
        delivered += rate
        cash += income
        due = workers * WAGE + arrears
        paid = min(cash, due)
        cash -= paid
        arrears = due - paid
        arrears_days = arrears_days + 1 if arrears > 0 else 0
        if arrears_days >= 2 and workers > 0:
            quit_day = quit_day or day
            workers = 0          # unpaid crew leave after the grace day
            arrears = 0.0        # (the debt is still owed in-game; not re-billed daily)
        rows.append((day, cash, arrears, delivered, workers))
    return capex, affordable, quit_day, rows


measured_hand2 = 3.0
measured_boss = 1.0


def main(argv):
    global measured_hand2, measured_boss
    measured = {}
    for a in argv:
        k, v = a.split("=")
        if k == "boss":
            measured_boss = float(v)
        else:
            measured[k] = float(v)
    measured_hand2 = measured.get("hand2", measured_hand2)
    out = []
    out.append("| Strategy | Upfront cost | Affordable at start ($2,000)? | Measured tree-eq/day | Wages/day | Margin/day | Crew leave (unpaid) on day | Cash day 30 | Trees delivered by day 30 (boss alone afterwards: assumed 1/day, not measured) | Share of 12,000 |")
    out.append("|---|---|---|---|---|---|---|---|---|---|")
    for k, te in measured.items():
        capex, ok, quit_day, rows = project(k, te)
        s = STRATS[k]
        d30 = rows[29]
        out.append("| %s | $%s | %s | %.2f | $%d | %+d | %s | $%d | %.0f | %.1f %% |" % (
            s["label"], format(int(capex), ","), "yes" if ok else "no (falls back to 2 workers, small axes)", te,
            s["workers"] * WAGE, te * TREE - s["workers"] * WAGE, str(quit_day) if quit_day else "-", d30[1], d30[3], 100.0 * d30[3] / TREES))
    print("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1:])
