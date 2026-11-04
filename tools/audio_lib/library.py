"""Phase 15 sound library catalog: 200 original procedural sources.

Run:  python3 tools/audio_lib/build.py   (writes audio/lib/... + manifest)
Each entry: name -> (category, loop, model, function). Functions take a
numpy Generator and return a mono float array at dsp.RATE. Every source is
synthesized here (no recordings, no third-party material).
"""
import numpy as np
from dsp import *  # noqa

SPECIES = {  # wood modal character: (body freqs Hz, decay s, bark hp cutoff)
    "pine": ([210, 470, 830, 1350, 2100], [0.06, 0.04, 0.025, 0.015, 0.01], 2600),
    "spruce": ([240, 520, 910, 1480, 2300], [0.055, 0.035, 0.022, 0.014, 0.009], 2900),
    "birch": ([290, 610, 1050, 1720, 2600], [0.07, 0.045, 0.03, 0.018, 0.011], 3400),
}


# ------------------------------------------------------------------ work

def axe_bite(species, size, deep=False):
    def f(g):
        fr, dc, bark = SPECIES[species]
        scale = 0.8 if size == "thick" else 1.15
        if deep:
            scale *= 0.85
        fr2 = [x * scale for x in fr]
        dc2 = [d * (1.5 if size == "thick" else 1.0) * (1.3 if deep else 1.0) for d in dc]
        body = modal(0.4, fr2, dc2, [1, 0.6, 0.4, 0.25, 0.15], g, "click", 0.0015, jitter=0.03)
        n = len(body)
        bite = hp(white(n, g), bark) * env_exp(n, 0.006) * 1.6
        fibre = grains(0.12, 260, g, lambda gg: click_grain(gg, 1800, 5200, (0.002, 0.006), (0.1, 0.4)))
        fib = np.zeros(n)
        fib[: len(fibre)] = fibre * np.linspace(1, 0, len(fibre))
        thump = lp(white(n, g), 180) * env_exp(n, 0.03) * (2.0 if size == "thick" else 1.2)
        return fade(body + bite + fib * 0.8 + thump, 0.0005, 0.05)
    return f


def stump_chop(v):
    def f(g):
        body = modal(0.45, [140 + 20 * v, 330, 610], [0.08, 0.05, 0.03], [1, 0.5, 0.3], g, "click", 0.003)
        n = len(body)
        grit = bp(white(n, g), 900, 4000) * env_exp(n, 0.02) * (0.6 + 0.2 * v)
        dirt = grains(0.25, 120, g, lambda gg: click_grain(gg, 600, 2000, (0.003, 0.01), (0.05, 0.25)))
        out = body + grit
        out[: len(dirt)] += dirt
        return fade(out, 0.0005, 0.05)
    return f


def buck_hit(size):
    def f(g):
        base = 260 if size == "small" else 170
        body = modal(0.5, [base, base * 2.3, base * 4.1, base * 6.7], [0.12, 0.07, 0.04, 0.02], [1, 0.55, 0.35, 0.2], g, "click", 0.0015)
        n = len(body)
        return fade(body + hp(white(n, g), 2800) * env_exp(n, 0.004), 0.0005, 0.05)
    return f


def axe_hard(kind):
    def f(g):
        if kind == "stone":
            y = modal(0.35, [1800, 3100, 4700, 6900], [0.03, 0.02, 0.012, 0.008], [1, 0.7, 0.4, 0.2], g, "click", 0.0008)
        else:
            y = modal(0.35, [380, 900, 2100], [0.04, 0.02, 0.01], [1, 0.4, 0.3], g, "click", 0.002)
        n = len(y)
        return fade(y + bp(white(n, g), 2000, 7000) * env_exp(n, 0.005), 0.0005, 0.04)
    return f


def swish(weight):
    def f(g):
        d = 0.32 if weight == "light" else 0.42
        n = int(d * RATE)
        t = np.arange(n) / RATE
        x = white(n, g)
        centre = 700 + 1800 * np.sin(np.pi * t / d)
        y = np.zeros(n)
        for k in range(0, n, 256):
            seg = x[k:k + 512]
            y[k:k + len(seg)] += bp(seg, max(centre[k] * 0.6, 200), centre[k] * 1.6)[: len(seg)] * np.hanning(len(seg))
        return fade(y * np.sin(np.pi * t / d) ** 2, 0.01, 0.05)
    return f


def strain(v):
    def f(g):
        sec = 1.2 + 0.5 * v
        return fade(stick_slip(sec, 22 + 9 * v, g, [190 + 40 * v, 520, 1100 + 150 * v], 10,
                               0.35, lambda u: 1 + 0.6 * u, lambda u: np.sin(np.pi * u) ** 0.7), 0.05, 0.2)
    return f


def hinge_crack(v):
    def f(g):
        # Short tearing lead-in (the break is the snap; it must land close
        # to the moment the hinge fails, not most of a second later).
        sec = 0.75
        n = int(sec * RATE)
        y = grains(sec, 40, g, lambda gg: click_grain(gg, 800, 4000, (0.002, 0.02), (0.35, 1.0)), lambda t: 6 + 30 * (t / sec) ** 2)
        snap = modal(0.5, [130, 320, 880], [0.12, 0.06, 0.03], [1.5, 0.8, 0.4], g, "noise", 0.004)
        place(y, snap, 0.26 + 0.05 * v, 1.0 + 0.3 * v)
        return fade(y, 0.01, 0.1)
    return f


def crown_rustle(kind):
    def f(g):
        sec = 1.8
        n = int(sec * RATE)
        lo, hi = (2500, 7000) if kind == "pine" else (1200, 5000)
        y = grains(sec, 900 if kind == "pine" else 420, g, lambda gg: click_grain(gg, lo, hi, (0.002, 0.01), (0.05, 0.3)),
                   lambda t: np.sin(np.pi * min(t / sec, 1)) ** 0.5)
        y += 0.4 * bp(pink(n, g), lo * 0.5, hi) * np.sin(np.pi * np.arange(n) / n)
        return fade(y, 0.05, 0.3)
    return f


def fall_impact(size):
    def f(g):
        s = {"small": 0.7, "medium": 1.0, "large": 1.35}[size]
        sec = 2.0 * s
        n = int(sec * RATE)
        boom = lp(white(n, g), 120) * env_exp(n, 0.25 * s) * 4.0
        body = modal(sec, [55 / s, 95 / s, 170 / s], [0.4 * s, 0.25 * s, 0.12 * s], [1, 0.6, 0.3], g, "noise", 0.02)
        crash = grains(1.0 * s, 700, g, lambda gg: click_grain(gg, 1500, 6000, (0.003, 0.015), (0.1, 0.5)), lambda t: np.exp(-t * 3 / s))
        y = boom + body * 1.5
        place(y, crash, 0.02, 0.8)
        bounce = lp(white(int(0.3 * RATE), g), 200) * env_exp(int(0.3 * RATE), 0.06) * 2
        place(y, bounce, 0.35 * s, 0.6)
        return fade(y, 0.002, 0.3)
    return f


def branch_snap(v):
    def f(g):
        y = modal(0.3, [700 + 200 * v, 1700, 3200], [0.03, 0.015, 0.008], [1, 0.6, 0.3], g, "noise", 0.002)
        n = len(y)
        place(y, grains(0.08, 300, g, lambda gg: click_grain(gg, 1500, 5000, (0.001, 0.004), (0.2, 0.6))), 0.0)
        return fade(y, 0.0005, 0.05)
    return f


def log_roll(surface):
    def f(g):
        sec = 1.4
        n = int(sec * RATE)
        rumble = lp(brown(n, g), 160 if surface == "ground" else 260) * 1.5
        knocks = grains(sec, 9, g, lambda gg: modal(0.12, [180 if surface == "ground" else 320, 640], [0.04, 0.02], [1, 0.4], gg, "click", 0.002))
        return fade((rumble + knocks) * env_adsr(n, 0.05, 0.3, 0.7, 0.5), 0.01, 0.2)
    return f


def log_drop(onto):
    def f(g):
        fr = {"ground": ([90, 210, 480], 0.08), "log": ([160, 410, 900, 1600], 0.12), "rack_wood": ([240, 560, 1250], 0.09), "cart_metal": ([180, 420, 1900, 3300], 0.2)}[onto]
        y = modal(0.6, fr[0], [fr[1] * (1.0 / (k + 1)) for k in range(len(fr[0]))], [1, 0.6, 0.4, 0.25][: len(fr[0])], g, "soft", 0.006)
        n = len(y)
        if onto == "ground":
            y += bp(white(n, g), 300, 1500) * env_exp(n, 0.03) * 0.5
        bounce = modal(0.3, fr[0], [fr[1] * 0.6] * len(fr[0]), [0.5] * len(fr[0]), g, "soft", 0.004)
        place(y, bounce, 0.11, 0.35)
        return fade(y, 0.001, 0.08)
    return f


def log_stack(v):
    def f(g):
        y = log_drop("log")(g)
        roll = log_roll("log")(g)[: int(0.5 * RATE)] * np.linspace(1, 0, int(0.5 * RATE))
        place(y, roll, 0.05, 0.4 + 0.2 * v)
        return y
    return f


def log_drag(g):
    sec = 4.0
    n = int(sec * RATE)
    scrape = bp(pink(n, g), 250, 1800) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.9 * np.arange(n) / RATE))
    ticks = grains(sec, 25, g, lambda gg: click_grain(gg, 500, 2500, (0.003, 0.01), (0.1, 0.4)))
    return loopify(scrape + ticks, 0.4)


def saw_v2(kind):
    def f(g):
        if kind == "idle":
            y = engine(3.0, 48, g, (95, 410, 1300), 0.12, rough=0.5)
            return loopify(y, 0.4)
        if kind == "rev":
            y = engine(3.0, 165, g, (130, 520, 1500, 3200), 0.03, rough=0.15)
            n = len(y)
            y += 0.18 * bp(white(n, g), 4500, 8000)
            return loopify(y, 0.4)
        if kind == "load":
            y = engine(3.0, 132, g, (120, 480, 1400), 0.06, rough=0.3)
            n = len(y)
            t = np.arange(n) / RATE
            bog = 0.75 + 0.25 * np.sin(2 * np.pi * 0.8 * t) * np.sin(2 * np.pi * 0.31 * t)
            teeth = bp(white(n, g), 1800, 5200) * (0.5 + 0.5 * np.sin(2 * np.pi * 132 * 7 * t)) * 0.6
            chips = grains(3.0, 600, g, lambda gg: click_grain(gg, 2500, 7000, (0.001, 0.004), (0.05, 0.25)))
            return loopify(y * bog + teeth + padto(chips, n), 0.4)
        if kind == "start":
            out = np.zeros(int(2.2 * RATE))
            for k in range(2):
                pull = bp(white(int(0.3 * RATE), g), 1200, 4000) * (0.5 + 0.5 * np.sin(2 * np.pi * 55 * np.arange(int(0.3 * RATE)) / RATE)) * np.hanning(int(0.3 * RATE))
                place(out, pull, 0.05 + k * 0.55, 0.8)
                place(out, engine(0.25, 30, g, (100, 400), 0.4) * np.linspace(1, 0, int(0.25 * RATE)), 0.36 + k * 0.55, 0.6 if k == 0 else 0.0)
            catch = engine(1.0, 95, g, (95, 410, 1300), 0.1, f_end=48)
            place(out, catch * np.minimum(np.arange(len(catch)) / (0.05 * RATE), 1), 1.15, 1.0)
            return fade(out, 0.01, 0.1)
        if kind == "stop":
            y = engine(1.2, 48, g, (95, 410), 0.3, f_end=6)
            return fade(y * np.linspace(1, 0, len(y)) ** 1.5, 0.005, 0.1)
        if kind == "spray":
            sec = 0.8
            return fade(grains(sec, 1500, g, lambda gg: click_grain(gg, 3000, 9000, (0.001, 0.003), (0.05, 0.2))) * np.linspace(1, 0.3, int(sec * RATE)), 0.01, 0.1)
    return f


def fire_bed(size):
    def f(g):
        sec = 6.0
        n = int(sec * RATE)
        roar = lp(brown(n, g), 400 if size == "large" else 250) * (1.2 if size == "large" else 0.6)
        crackle = grains(sec, 70 if size == "large" else 25, g, lambda gg: click_grain(gg, 1500, 6000, (0.001, 0.006), (0.1, 0.8)))
        hiss = bp(white(n, g), 3000, 9000) * 0.05
        return loopify(roar + crackle + hiss, 0.5)
    return f


def fire_pop(v):
    def f(g):
        y = modal(0.25, [900 + 400 * v, 2400], [0.01, 0.006], [1, 0.5], g, "noise", 0.0015)
        n = len(y)
        sparks = grains(0.2, 120, g, lambda gg: click_grain(gg, 3000, 8000, (0.001, 0.003), (0.05, 0.2)))
        y[: len(sparks)] += sparks
        return fade(y, 0.0005, 0.05)
    return f


def fire_hiss(g):
    n = int(1.6 * RATE)
    return fade(bp(white(n, g), 2500, 7000) * env_adsr(n, 0.2, 0.4, 0.6, 0.6) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * np.arange(n) / RATE)), 0.05, 0.2)


def fire_log_place(g):
    y = log_drop("log")(g)
    n = len(y)
    flare = bp(white(n, g), 300, 3000) * env_adsr(n, 0.15, 0.2, 0.3, 0.2) * 0.4
    sparks = grains(0.5, 300, g, lambda gg: click_grain(gg, 3000, 8000, (0.001, 0.004), (0.05, 0.3)))
    flare[: len(sparks)] += sparks
    return y + flare


def embers_settle(g):
    sec = 1.2
    return fade(grains(sec, 60, g, lambda gg: click_grain(gg, 1200, 4500, (0.003, 0.012), (0.05, 0.3)), lambda t: np.exp(-t * 2)) + 0.3 * lp(white(int(sec * RATE), g), 300) * env_exp(int(sec * RATE), 0.2), 0.01, 0.2)


def chips_fall(g):
    sec = 0.7
    return fade(grains(sec, 160, g, lambda gg: click_grain(gg, 1000, 4000, (0.002, 0.008), (0.05, 0.4)), lambda t: np.exp(-t * 4)), 0.002, 0.1)


def root_tear(g):
    sec = 1.1
    n = int(sec * RATE)
    y = stick_slip(sec, 35, g, [150, 380, 900], 6, 0.5, lambda u: 1 + u, lambda u: np.sin(np.pi * u))
    y += bp(brown(n, g), 80, 600) * env_adsr(n, 0.2, 0.3, 0.6, 0.3) * 0.6
    snap = modal(0.3, [120, 300], [0.08, 0.04], [1, 0.5], g, "noise", 0.004)
    place(y, snap, 0.85, 1.2)
    return fade(y, 0.02, 0.1)


def tool_pickup(g):
    y = modal(0.3, [520, 1300, 2900], [0.04, 0.02, 0.01], [0.6, 0.4, 0.2], g, "soft", 0.004)
    n = len(y)
    return fade(y + bp(white(n, g), 600, 3000) * env_exp(n, 0.04) * 0.3, 0.002, 0.05)


def log_stack_b(g):
    """A log rolling onto two others: two-point contact, short slide, settle."""
    a = modal(0.5, [190, 470, 1050], [0.1, 0.06, 0.03], [1, 0.6, 0.3], g, "soft", 0.005)
    b = modal(0.5, [230, 560, 1240], [0.09, 0.05, 0.025], [0.8, 0.5, 0.25], g, "soft", 0.005)
    out = np.zeros(int(1.1 * RATE))
    place(out, a, 0.0)
    place(out, b, 0.07)
    n = int(0.4 * RATE)
    slide = stick_slip(0.4, 90, g, [300, 800], 6, 0.4, None, lambda u: np.sin(np.pi * u)) * 0.4
    place(out, slide, 0.12)
    place(out, modal(0.3, [210, 520], [0.05, 0.03], [0.4, 0.2], g, "soft", 0.004), 0.55)
    return fade(out, 0.001, 0.1)


# ---------------------------------------------------------------- vehicles

def truck_loop(rpm):
    def f(g):
        f_fire = {"idle": 26, "low": 42, "mid": 62, "high": 90}[rpm]
        y = engine(4.0, f_fire, g, (60, 180, 520, 1300), 0.05, rough=0.25)
        n = len(y)
        y += 0.12 * lp(brown(n, g), 220)
        if rpm in ("mid", "high"):
            y += 0.06 * bp(white(n, g), 1500, 4000) * (1.0 if rpm == "high" else 0.6)
        return loopify(lp(y, 2500), 0.4)
    return f


def truck_start(g):
    out = np.zeros(int(2.4 * RATE))
    crank = engine(0.9, 9, g, (120, 300, 800), 0.1, rough=0.2)
    place(out, crank, 0.0, 0.7)
    catch = engine(1.4, 45, g, (60, 180, 520), 0.08, f_end=26)
    place(out, catch * np.minimum(np.arange(len(catch)) / (0.08 * RATE), 1), 0.85, 1.0)
    return fade(out, 0.01, 0.15)


def truck_stop(g):
    y = engine(1.0, 26, g, (60, 180), 0.2, f_end=5)
    return fade(y * np.linspace(1, 0, len(y)) ** 1.3, 0.005, 0.1)


def truck_door(op):
    def f(g):
        if op == "open":
            latch = modal(0.15, [1800, 3400], [0.01, 0.006], [1, 0.5], g, "click", 0.0006)
            hinge = stick_slip(0.4, 60, g, [700, 1600], 14, 0.3, None, lambda u: np.sin(np.pi * u)) * 0.3
            out = np.zeros(int(0.6 * RATE))
            place(out, latch, 0.0)
            place(out, hinge, 0.06)
            return fade(out, 0.001, 0.05)
        thunk = modal(0.5, [95, 230, 610, 1400], [0.09, 0.05, 0.03, 0.015], [1.4, 0.7, 0.4, 0.2], g, "soft", 0.008)
        latch2 = modal(0.1, [2200, 4100], [0.006, 0.004], [0.6, 0.3], g, "click", 0.0005)
        place(thunk, latch2, 0.004, 0.8)
        return fade(thunk, 0.001, 0.05)
    return f


def tailgate(op):
    def f(g):
        # Pressed-steel panel: inharmonic, long-ringing partials (not a
        # wooden thud), a sharp latch clank and the check chains snapping taut.
        y = modal(1.1, [212, 517, 1338, 2655, 4110], [0.45, 0.32, 0.22, 0.15, 0.09], [0.8, 1, 0.7, 0.5, 0.3], g, "click", 0.0015)
        clank = modal(0.15, [3100, 5200], [0.03, 0.02], [0.6, 0.4], g, "click", 0.0004)
        place(y, clank, 0.0 if op == "open" else 0.04, 0.8)
        chain = grains(0.35, 55, g, lambda gg: modal(0.05, [2600, 4300], [0.01, 0.006], [0.4, 0.2], gg, "click", 0.0004))
        place(y, chain, 0.12 if op == "open" else 0.0, 0.7)
        return fade(y, 0.001, 0.08)
    return f


def cargo_rattle(g):
    sec = 3.0
    y = grains(sec, 14, g, lambda gg: modal(0.12, [gg.uniform(150, 260), gg.uniform(400, 700)], [0.04, 0.02], [1, 0.4], gg, "soft", 0.003))
    y += grains(sec, 25, g, lambda gg: modal(0.05, [gg.uniform(2000, 3500)], [0.008], [0.3], gg, "click", 0.0004))
    return loopify(y, 0.3)


def tire(surface):
    def f(g):
        sec = 3.0
        n = int(sec * RATE)
        if surface == "gravel":
            y = grains(sec, 900, g, lambda gg: click_grain(gg, 800, 4000, (0.002, 0.006), (0.05, 0.4)))
            y += 0.4 * lp(brown(n, g), 200)
        elif surface == "dirt":
            y = 0.8 * bp(brown(n, g), 60, 500) + 0.1 * grains(sec, 150, g, lambda gg: click_grain(gg, 600, 2000, (0.003, 0.008), (0.05, 0.2)))
        else:
            y = 0.6 * bp(pink(n, g), 150, 2500) + 0.3 * lp(brown(n, g), 150)
        return loopify(y, 0.3)
    return f


def suspension(v):
    def f(g):
        y = modal(0.5, [70 + 20 * v, 160, 450], [0.15, 0.07, 0.03], [1.4, 0.6, 0.3], g, "soft", 0.01)
        n = len(y)
        y += padto(grains(0.3, 30, g, lambda gg: modal(0.04, [gg.uniform(1800, 3000)], [0.006], [0.25], gg, "click", 0.0004)), n)
        return fade(y, 0.002, 0.08)
    return f


def truck_horn(g):
    n = int(0.9 * RATE)
    t = np.arange(n) / RATE
    y = np.zeros(n)
    for f0 in (380, 480):
        ph = 2 * np.pi * f0 * t
        y += np.sign(np.sin(ph)) * 0.5 + np.sin(ph) * 0.5
    y = reson(y, 900, 2) + reson(y, 2300, 4) * 0.5
    return fade(y * env_adsr(n, 0.02, 0.1, 0.9, 0.15), 0.01, 0.05)


def handbrake(g):
    n = int(0.6 * RATE)
    clicks = grains(0.45, 30, g, lambda gg: modal(0.03, [3200, 5200], [0.004, 0.003], [0.6, 0.3], gg, "click", 0.0003))
    y = np.zeros(n)
    y[: len(clicks)] += clicks
    y += stick_slip(0.6, 80, g, [900, 2000], 10) * 0.2
    return fade(y, 0.002, 0.05)


def gear_clunk(g):
    y = modal(0.3, [210, 640, 1500], [0.05, 0.025, 0.012], [1, 0.6, 0.3], g, "click", 0.002)
    return fade(y, 0.0005, 0.04)


def cart_roll(surface):
    def f(g):
        sec = 3.0
        n = int(sec * RATE)
        if surface == "dirt":
            y = 0.5 * bp(brown(n, g), 80, 700) + grains(sec, 60, g, lambda gg: click_grain(gg, 500, 2500, (0.003, 0.008), (0.05, 0.25)))
        else:
            y = grains(sec, 6, g, lambda gg: modal(0.08, [260, 610], [0.03, 0.015], [0.8, 0.4], gg, "click", 0.002)) + 0.3 * lp(brown(n, g), 180)
        return loopify(y, 0.3)
    return f


def cart_squeak(g):
    return fade(stick_slip(0.7, 340, g, [1700, 3300], 18, 0.1, lambda u: 1 + 0.3 * np.sin(np.pi * u), lambda u: np.sin(np.pi * u)), 0.02, 0.1)


def cart_bump(g):
    y = modal(0.35, [150, 420, 1300, 2900], [0.07, 0.035, 0.015, 0.008], [1, 0.6, 0.3, 0.2], g, "soft", 0.004)
    return fade(y, 0.001, 0.05)


def outboard(g):
    y = engine(3.0, 75, g, (180, 650, 1800, 3500), 0.05, rough=0.2)
    n = len(y)
    y += 0.15 * bp(white(n, g), 300, 1500) * (0.6 + 0.4 * np.sin(2 * np.pi * 1.3 * np.arange(n) / RATE))
    return loopify(y, 0.4)


# ---------------------------------------------------------- movement / dog

def cloth(v):
    def f(g):
        sec = 0.35 + 0.15 * v
        n = int(sec * RATE)
        x = bp(white(n, g), 1200 + 600 * v, 6000) * env_adsr(n, 0.05, 0.1, 0.5, 0.15)
        x += padto(grains(sec, 80, g, lambda gg: click_grain(gg, 2000, 6000, (0.001, 0.003), (0.02, 0.1))), n)
        return fade(x, 0.01, 0.05)
    return f


def jacket_swish(g):
    n = int(0.45 * RATE)
    return fade(bp(pink(n, g), 700, 4500) * np.sin(np.pi * np.arange(n) / n) ** 2, 0.01, 0.05)


def gear_jingle(g):
    y = grains(0.3, 40, g, lambda gg: modal(0.12, [gg.uniform(3000, 5500), gg.uniform(6000, 8000)], [0.03, 0.02], [0.5, 0.3], gg, "click", 0.0003))
    return fade(y, 0.002, 0.05)


def boot_scuff(surface):
    def f(g):
        n = int(0.4 * RATE)
        if surface == "dirt":
            y = bp(white(n, g), 600, 3500) * env_adsr(n, 0.03, 0.1, 0.4, 0.2) + padto(grains(0.4, 120, g, lambda gg: click_grain(gg, 800, 3000, (0.002, 0.006), (0.05, 0.2))), n)
        else:
            y = stick_slip(0.4, 120, g, [900, 2200], 8, 0.4, None, lambda u: np.sin(np.pi * u)) * 0.5
        return fade(y, 0.005, 0.05)
    return f


def kneel_cloth(g):
    y = cloth(2)(g)
    thud = lp(white(int(0.2 * RATE), g), 200) * env_exp(int(0.2 * RATE), 0.04) * 1.5
    place(y, thud, 0.12)
    return y


def body_sit(g):
    n = int(0.5 * RATE)
    y = lp(white(n, g), 250) * env_exp(n, 0.06) * 1.5 + bp(white(n, g), 400, 2000) * env_exp(n, 0.1) * 0.3
    return fade(y, 0.002, 0.08)


def paw(surface, v):
    def f(g):
        n = int(0.12 * RATE)
        if surface == "dirt":
            y = bp(white(n, g), 400, 2500) * env_exp(n, 0.012) * 0.7
        elif surface == "wood":
            y = modal(0.12, [700 + 90 * v, 1600], [0.015, 0.008], [0.6, 0.3], g, "soft", 0.002)
            y += modal(0.12, [3200], [0.003], [0.3], g, "click", 0.0003)    # claws
        else:
            y = bp(white(n, g), 1500, 6000) * env_exp(n, 0.02) * 0.5
        return fade(y, 0.0005, 0.02)
    return f


def collar(v):
    def f(g):
        y = grains(0.25 + 0.1 * v, 30, g, lambda gg: modal(0.15, [gg.uniform(4200, 5200) + 300 * v, gg.uniform(7000, 8200)], [0.05, 0.03], [0.4, 0.2], gg, "click", 0.0002))
        return fade(y, 0.002, 0.05)
    return f


def dog_shake(g):
    sec = 0.9
    n = int(sec * RATE)
    t = np.arange(n) / RATE
    flap = bp(white(n, g), 500, 4000) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) * env_adsr(n, 0.05, 0.2, 0.8, 0.3)
    drops = grains(sec, 200, g, lambda gg: click_grain(gg, 2000, 6000, (0.001, 0.004), (0.05, 0.2)))
    jingle = collar(1)(g)
    y = flap + drops[:n]
    place(y, jingle, 0.05, 0.5)
    return fade(y, 0.01, 0.1)


def dog_drink(g):
    sec = 1.6
    y = grains(sec, 5.5, g, lambda gg: modal(0.08, [gg.uniform(600, 900), gg.uniform(1800, 2600)], [0.02, 0.01], [0.6, 0.3], gg, "noise", 0.004))
    return fade(y, 0.01, 0.1)


def dog_sniff(g):
    out = np.zeros(int(0.9 * RATE))
    for k in range(4):
        m = int(0.09 * RATE)
        s = bp(white(m, g), 1500, 6000) * np.hanning(m)
        place(out, s, 0.05 + 0.18 * k, 0.6)
    return fade(out, 0.005, 0.05)


def dog_yawn(g):
    n = int(1.1 * RATE)
    env = env_adsr(n, 0.2, 0.3, 0.6, 0.4)
    y = formant(1.1, 220, [(700, 5, 1.0), (1300, 6, 0.5), (2600, 8, 0.2)], g, 0.4, 0.02, lambda u: 1.4 - 0.7 * u, env)
    return fade(y, 0.02, 0.15)


def dog_bark2(v):
    def f(g):
        n = int(0.35 * RATE)
        env = env_adsr(n, 0.008, 0.05, 0.5, 0.18)
        f0 = 420 + 80 * v
        y = formant(0.35, f0, [(900 + 100 * v, 4, 1.0), (1600, 5, 0.6), (2900, 7, 0.3)], g, 0.6, 0.0, lambda u: 1.15 - 0.4 * u, env)
        y += hp(white(n, g), 2000) * env * 0.2
        return fade(y, 0.002, 0.05)
    return f


def dog_whine2(g):
    n = int(1.2 * RATE)
    env = env_adsr(n, 0.1, 0.2, 0.7, 0.4)
    y = formant(1.2, 780, [(1100, 6, 1.0), (2400, 8, 0.4)], g, 0.1, 0.03, lambda u: 1.0 + 0.25 * np.sin(np.pi * u), env)
    return fade(y, 0.02, 0.1)


def dog_pant2(g):
    sec = 3.0
    out = np.zeros(int(sec * RATE))
    t = 0.0
    while t < sec - 0.2:
        m = int(0.14 * RATE)
        s = bp(white(m, g), 900, 3500) * np.hanning(m)
        place(out, s, t, 0.7)
        t += 0.2 + g.uniform(-0.02, 0.02)
    return loopify(out, 0.2)


def dog_growl2(g):
    n = int(1.4 * RATE)
    env = env_adsr(n, 0.15, 0.2, 0.8, 0.3)
    y = formant(1.4, 95, [(450, 4, 1.0), (1100, 5, 0.5), (2300, 6, 0.2)], g, 0.8, 0.06, None, env)
    return fade(y, 0.02, 0.1)


# ------------------------------------------------------------ environment

def surf(dist):
    def f(g):
        sec = 12.0
        n = int(sec * RATE)
        t = np.arange(n) / RATE
        out = np.zeros(n)
        k = 0.0
        while k < sec:
            m = int(g.uniform(2.5, 4.0) * RATE)
            e = env_adsr(m, g.uniform(0.6, 1.2), 0.5, 0.6, m / RATE * 0.5)
            w = bp(pink(m, g), 150 if dist == "far" else 250, 1800 if dist == "far" else 6000) * e
            place(out, w, k, g.uniform(0.6, 1.0))
            k += g.uniform(3.0, 5.0)
        out += 0.3 * lp(brown(n, g), 150)
        if dist == "far":
            out = lp(out, 900)
        return loopify(out, 1.0)
    return f


def wash(v):
    def f(g):
        sec = 3.0
        n = int(sec * RATE)
        y = bp(pink(n, g), 400, 7000) * env_adsr(n, 0.4, 0.8, 0.5, 1.2)
        fizz = grains(sec, 500, g, lambda gg: click_grain(gg, 3000, 9000, (0.001, 0.004), (0.02, 0.15)), lambda t: np.exp(-t * (0.6 + 0.3 * v)))
        return fade(y + fizz, 0.1, 0.4)
    return f


def bubble(g, lo=300, hi=1600):
    d = g.uniform(0.01, 0.04)
    m = int(d * RATE)
    t = np.arange(m) / RATE
    f0 = g.uniform(lo, hi)
    return np.sin(2 * np.pi * f0 * (1 + 3 * t / d) * t) * env_exp(m, d / 3) * g.uniform(0.1, 0.6)


def water_flow(kind):
    def f(g):
        sec = 8.0
        n = int(sec * RATE)
        rate = {"fast": 450, "slow": 120, "trickle": 60}[kind]
        y = grains(sec, rate, g, lambda gg: bubble(gg, 300 if kind != "trickle" else 900, 1800 if kind != "trickle" else 3000))
        y += (0.5 if kind == "fast" else 0.2) * bp(pink(n, g), 200, 3000)
        return loopify(y, 0.6)
    return f


def pond(g):
    sec = 8.0
    n = int(sec * RATE)
    y = grains(sec, 1.2, g, lambda gg: lp(white(int(0.6 * RATE), gg), 500) * env_adsr(int(0.6 * RATE), 0.1, 0.2, 0.4, 0.3))
    y += grains(sec, 8, g, lambda gg: bubble(gg, 250, 700) * 0.4)
    return loopify(y, 0.6)


def wind(kind):
    def f(g):
        sec = 10.0
        lo, hi = {"low": (60, 400), "pines": (500, 4500), "birch": (300, 2500), "cleared": (90, 900)}[kind]
        y = wind_bed(sec, g, lo, hi, 0.7, 0.07)
        if kind == "birch":
            y += 0.4 * grains(sec, 160, g, lambda gg: click_grain(gg, 1500, 4500, (0.004, 0.012), (0.02, 0.15)), lambda t: 0.6 + 0.4 * np.sin(2 * np.pi * 0.1 * t))
        return loopify(y, 1.0)
    return f


def gust(v):
    def f(g):
        sec = 4.0
        n = int(sec * RATE)
        y = bp(pink(n, g), 200 + 100 * v, 2500) * env_adsr(n, 1.2, 0.8, 0.6, 1.4)
        return fade(y, 0.2, 0.5)
    return f


def rain(kind):
    def f(g):
        sec = 8.0
        n = int(sec * RATE)
        if kind == "light":
            y = grains(sec, 260, g, lambda gg: click_grain(gg, 2500, 8000, (0.001, 0.003), (0.05, 0.3))) + 0.1 * bp(white(n, g), 3000, 9000)
        elif kind == "heavy":
            y = grains(sec, 2200, g, lambda gg: click_grain(gg, 1500, 8000, (0.001, 0.004), (0.05, 0.3))) + 0.6 * bp(pink(n, g), 400, 8000)
        elif kind == "canvas":
            y = grains(sec, 700, g, lambda gg: modal(0.03, [gg.uniform(250, 500)], [0.01], [0.6], gg, "click", 0.0004)) + 0.2 * bp(pink(n, g), 200, 2000)
        elif kind == "metal":
            y = grains(sec, 600, g, lambda gg: modal(0.08, [gg.uniform(1800, 4200), gg.uniform(5000, 7000)], [0.02, 0.01], [0.4, 0.2], gg, "click", 0.0003)) + 0.15 * bp(white(n, g), 2000, 8000)
        elif kind == "wood":
            y = grains(sec, 600, g, lambda gg: modal(0.04, [gg.uniform(400, 900)], [0.012], [0.5], gg, "click", 0.0005)) + 0.3 * lp(pink(n, g), 1200)
        else:  # drips
            y = grains(sec, 3, g, lambda gg: modal(0.12, [gg.uniform(1200, 2400)], [0.03], [0.8], gg, "click", 0.0004))
        return loopify(y, 0.6)
    return f


def thunder(dist, v):
    def f(g):
        sec = 6.0 if dist == "far" else 5.0
        n = int(sec * RATE)
        y = lp(brown(n, g), 120 if dist == "far" else 400) * env_adsr(n, 0.3 if dist == "far" else 0.02, 1.5, 0.4, 2.5)
        cracks = grains(1.2, 25 if dist == "near" else 6, g, lambda gg: lp(white(int(0.1 * RATE), gg), 2000) * env_exp(int(0.1 * RATE), 0.02))
        place(y, cracks, 0.1 + 0.3 * v, 1.5 if dist == "near" else 0.4)
        return fade(y, 0.02, 0.8)
    return f


def bird(kind):
    def f(g):
        if kind == "woodpecker":
            out = np.zeros(int(1.4 * RATE))
            for k in range(14):
                place(out, modal(0.04, [1100, 2600], [0.01, 0.006], [1, 0.5], g, "click", 0.0004), 0.1 + k * 0.045 + 0.002 * k * k)
            return fade(out, 0.002, 0.1)
        if kind in ("crow", "gull"):
            n = int(0.5 * RATE)
            env = env_adsr(n, 0.02, 0.1, 0.7, 0.2)
            f0 = 520 if kind == "crow" else 900
            y = formant(0.5, f0, [(1400, 3, 1.0), (2600, 4, 0.6), (3800, 6, 0.3)], g, 0.5, 0.01, (lambda u: 1.1 - 0.3 * u) if kind == "crow" else (lambda u: 1.0 + 0.5 * np.sin(np.pi * u)), env)
            out = np.zeros(int(1.6 * RATE))
            for k in range(2 if kind == "crow" else 3):
                place(out, y, 0.05 + k * 0.55, 1.0 - 0.15 * k)
            return fade(out, 0.002, 0.1)
        # Song birds: sequences of FM syllables, each species its own grammar.
        spec = {"robin": (2200, 3600, 8, 0.08), "thrush": (1500, 3200, 6, 0.14), "wren": (3500, 7000, 18, 0.03)}[kind]
        out = np.zeros(int(2.4 * RATE))
        t0 = 0.05
        for k in range(spec[2]):
            d = spec[3] * g.uniform(0.7, 1.3)
            m = int(d * RATE)
            tt = np.arange(m) / RATE
            fa, fb = g.uniform(spec[0], spec[1]), g.uniform(spec[0], spec[1])
            fr = fa + (fb - fa) * tt / d
            syl = np.sin(2 * np.pi * np.cumsum(fr) / RATE + 3 * np.sin(2 * np.pi * 60 * tt)) * np.sin(np.pi * tt / d) ** 2
            place(out, syl, t0, g.uniform(0.5, 1.0))
            t0 += d + g.uniform(0.01, 0.06)
            if t0 > 2.2:
                break
        return fade(out, 0.002, 0.1)
    return f


def crickets(g):
    sec = 6.0
    n = int(sec * RATE)
    out = np.zeros(n)
    for c in range(5):
        f0 = g.uniform(4000, 5200)
        rate = g.uniform(2.5, 4.5)
        t = np.arange(n) / RATE
        gate = (np.sin(2 * np.pi * rate * t + g.uniform(0, 6)) > 0.6).astype(float)
        pulse = (np.sin(2 * np.pi * 45 * t) > 0).astype(float)
        out += np.sin(2 * np.pi * f0 * t) * gate * pulse * g.uniform(0.2, 0.5)
    return loopify(lp(out, 7000), 0.5)


def frogs(g):
    sec = 6.0
    return loopify(grains(sec, 4, g, lambda gg: formant(0.25, gg.uniform(180, 260), [(600, 4, 1.0), (1300, 5, 0.4)], gg, 0.2, 0.0, None, env_adsr(int(0.25 * RATE), 0.01, 0.05, 0.6, 0.1))), 0.5)


def frog_single(g):
    return fade(formant(0.4, 140, [(450, 4, 1.0), (1100, 5, 0.4)], g, 0.3, 0.0, None, env_adsr(int(0.4 * RATE), 0.01, 0.1, 0.6, 0.15)), 0.002, 0.05)


def owl(v):
    def f(g):
        out = np.zeros(int(2.0 * RATE))
        for k in range(3 if v == 0 else 2):
            n = int(0.35 * RATE)
            y = formant(0.35, 380 - 30 * v, [(400, 8, 1.0), (800, 10, 0.2)], g, 0.15, 0.01, lambda u: 1.05 - 0.1 * u, env_adsr(n, 0.05, 0.1, 0.7, 0.15))
            place(out, y, 0.1 + k * 0.5 + (0.3 if k == 2 else 0), 1.0)
        return fade(out, 0.01, 0.1)
    return f


def nightjar(g):
    sec = 5.0
    n = int(sec * RATE)
    t = np.arange(n) / RATE
    y = np.sin(2 * np.pi * 1200 * t) * (np.sin(2 * np.pi * 28 * t) > 0) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.4 * t))
    return loopify(bp(y, 600, 3000), 0.5)


def leaves_fall(g):
    sec = 2.0
    return fade(grains(sec, 40, g, lambda gg: click_grain(gg, 1500, 5000, (0.003, 0.01), (0.02, 0.15))), 0.05, 0.3)


def distant_crack(g):
    """Far branch break: dull snap, long low tail and forest echo taps."""
    out = np.zeros(int(2.0 * RATE))
    snap = modal(0.6, [260, 610, 1150], [0.06, 0.03, 0.015], [1, 0.4, 0.2], g, "noise", 0.004)
    place(out, snap, 0.0)
    for k, (d, a) in enumerate([(0.21, 0.35), (0.47, 0.2), (0.83, 0.1)]):
        place(out, lp(snap, 900 - 150 * k), d, a)
    n = len(out)
    out += lp(brown(n, g), 120) * env_exp(n, 0.3) * 0.4
    return fade(lp(out, 2200), 0.002, 0.3)


def drip(v):
    def f(g):
        return fade(modal(0.3, [1300 + 500 * v, 2900], [0.04, 0.02], [1, 0.3], g, "click", 0.0004), 0.0005, 0.05)
    return f


def insects_day(g):
    sec = 6.0
    n = int(sec * RATE)
    t = np.arange(n) / RATE
    y = 0.2 * np.sin(2 * np.pi * 230 * t + 2 * np.sin(2 * np.pi * 7 * t)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.2 * t))
    y += 0.05 * bp(white(n, g), 5000, 9000) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t))
    return loopify(y, 0.5)


def air(kind):
    def f(g):
        sec = 8.0
        n = int(sec * RATE)
        if kind == "forest":
            y = 0.4 * bp(pink(n, g), 80, 1500) + 0.08 * grains(sec, 6, g, lambda gg: click_grain(gg, 1500, 4000, (0.004, 0.015), (0.05, 0.2)))
        else:
            y = 0.3 * bp(pink(n, g), 60, 700)
        return loopify(y, 0.8)
    return f


def bees(g):
    sec = 5.0
    n = int(sec * RATE)
    t = np.arange(n) / RATE
    y = np.zeros(n)
    for k in range(4):
        f0 = g.uniform(190, 260)
        y += np.sign(np.sin(2 * np.pi * f0 * t + 3 * np.sin(2 * np.pi * g.uniform(0.3, 0.9) * t))) * g.uniform(0.1, 0.25)
    return loopify(bp(y, 200, 2000), 0.5)


def splash(g):
    n = int(0.6 * RATE)
    y = bp(white(n, g), 500, 5000) * env_exp(n, 0.08) + padto(grains(0.4, 200, g, lambda gg: bubble(gg, 600, 2000)), n)
    return fade(y, 0.001, 0.1)


def reeds(g):
    sec = 6.0
    return loopify(0.6 * grains(sec, 300, g, lambda gg: click_grain(gg, 1800, 6000, (0.003, 0.01), (0.02, 0.1)), lambda t: 0.6 + 0.4 * np.sin(2 * np.pi * 0.15 * t)), 0.5)


# ---------------------------------------------------------------- domestic

def door_wood(op):
    def f(g):
        if op == "open":
            y = stick_slip(0.7, 45, g, [300, 800, 1900], 9, 0.3, lambda u: 1 + 0.5 * u, lambda u: np.sin(np.pi * u))
            latch = modal(0.1, [1500, 3000], [0.008, 0.005], [0.8, 0.4], g, "click", 0.0006)
            place(y, latch, 0.0)
            return fade(y, 0.002, 0.08)
        y = modal(0.5, [120, 290, 700, 1600], [0.08, 0.05, 0.025, 0.012], [1.2, 0.7, 0.4, 0.2], g, "soft", 0.006)
        latch = modal(0.08, [1700, 3300], [0.006, 0.004], [0.8, 0.4], g, "click", 0.0005)
        place(y, latch, 0.01)
        return fade(y, 0.001, 0.06)
    return f


def latch(g):
    return fade(modal(0.15, [1400, 2900, 5200], [0.012, 0.007, 0.004], [1, 0.5, 0.3], g, "click", 0.0005), 0.0005, 0.03)


def creak(g):
    return fade(stick_slip(1.3, 30, g, [260, 640, 1500], 11, 0.25, lambda u: 1 + 0.8 * u, lambda u: np.sin(np.pi * u) ** 0.6), 0.05, 0.2)


def window_slide(g):
    n = int(0.7 * RATE)
    return fade(stick_slip(0.7, 160, g, [900, 2300], 6, 0.5, None, lambda u: np.sin(np.pi * u)) * 0.6 + bp(white(n, g), 1000, 5000) * env_adsr(n, 0.05, 0.2, 0.4, 0.2) * 0.2, 0.01, 0.05)


def window_rattle(g):
    return fade(grains(0.6, 35, g, lambda gg: modal(0.05, [gg.uniform(1500, 2600), gg.uniform(3500, 5000)], [0.01, 0.006], [0.6, 0.3], gg, "click", 0.0004)), 0.002, 0.05)


def hum(kind):
    def f(g):
        sec = 5.0
        n = int(sec * RATE)
        t = np.arange(n) / RATE
        if kind == "fridge":
            y = sum(np.sin(2 * np.pi * 50 * k * t) / k for k in range(1, 6)) * 0.3 + 0.1 * bp(white(n, g), 200, 800)
        elif kind == "fan":
            y = 0.5 * bp(pink(n, g), 300, 3000) + 0.1 * np.sin(2 * np.pi * 185 * t)
        else:  # lamp buzz
            y = 0.25 * np.sign(np.sin(2 * np.pi * 100 * t)) + 0.05 * hp(white(n, g), 4000)
            y = bp(y, 100, 3000)
        return loopify(y, 0.4)
    return f


def keyboard(g):
    sec = 4.0
    y = grains(sec, 7, g, lambda gg: modal(0.04, [gg.uniform(1800, 2600), gg.uniform(4000, 5500)], [0.006, 0.003], [0.6, 0.3], gg, "click", 0.0003))
    return loopify(y, 0.2)


def mouse_click(g):
    return fade(modal(0.05, [3200, 6100], [0.004, 0.002], [1, 0.5], g, "click", 0.0002), 0.0002, 0.01)


def chime(g):
    n = int(0.9 * RATE)
    t = np.arange(n) / RATE
    y = (np.sin(2 * np.pi * 880 * t) * env_exp(n, 0.25) + 0.6 * np.sin(2 * np.pi * 1318 * t) * env_exp(n, 0.2))
    y[: int(0.12 * RATE)] *= 0.0
    y += np.sin(2 * np.pi * 1046 * t) * env_exp(n, 0.2) * (t < 0.12)
    return fade(y, 0.002, 0.1)


def kettle(g):
    sec = 5.0
    n = int(sec * RATE)
    y = grains(sec, 200, g, lambda gg: bubble(gg, 400, 1500)) + 0.3 * bp(pink(n, g), 300, 3000)
    return loopify(y, 0.5)


def cupboard(g):
    """Small cabinet door: light high panel modes and a magnetic catch."""
    y = modal(0.3, [420, 980, 2100, 3900], [0.04, 0.025, 0.012, 0.006], [1, 0.6, 0.35, 0.2], g, "soft", 0.003)
    place(y, modal(0.05, [4800, 7600], [0.004, 0.002], [0.5, 0.25], g, "click", 0.0002), 0.006)
    return fade(y, 0.0005, 0.04)


def floor_creak(v):
    def f(g):
        return fade(stick_slip(0.5 + 0.2 * v, 55 + 25 * v, g, [220 + 60 * v, 560], 10, 0.3, None, lambda u: np.sin(np.pi * u)), 0.01, 0.08)
    return f


def heater_tick(g):
    out = np.zeros(int(1.5 * RATE))
    for k in range(3):
        place(out, modal(0.06, [2600 + 300 * k, 5200], [0.008, 0.004], [0.5, 0.2], g, "click", 0.0003), 0.1 + k * g.uniform(0.3, 0.5))
    return out


def fence_rattle(g):
    y = grains(0.9, 60, g, lambda gg: modal(0.1, [gg.uniform(800, 1500), gg.uniform(2500, 4500)], [0.03, 0.015], [0.6, 0.3], gg, "click", 0.0004), lambda t: np.exp(-t * 2.5))
    return fade(y, 0.002, 0.1)


def gate_clank(g):
    y = modal(0.8, [190, 470, 1150, 2700], [0.2, 0.12, 0.06, 0.03], [1, 0.7, 0.5, 0.3], g, "click", 0.002)
    place(y, fence_rattle(g) * 0.5, 0.02)
    return fade(y, 0.001, 0.1)


def rack_hang(g):
    y = modal(0.35, [330, 900, 2200], [0.05, 0.025, 0.012], [0.8, 0.5, 0.3], g, "soft", 0.003)
    place(y, modal(0.2, [3000, 5000], [0.01, 0.006], [0.3, 0.2], g, "click", 0.0004), 0.03)
    return fade(y, 0.001, 0.05)


# ------------------------------------------------------------------ horror

def knock(material, style):
    def f(g):
        hits = {"dull": [0.0, 0.35, 0.7], "sharp": [0.0, 0.18], "slow": [0.0, 0.9, 1.9]}[style]
        out = np.zeros(int((hits[-1] + 0.6) * RATE))
        for i, t0 in enumerate(hits):
            if material == "wood":
                k = modal(0.4, [150, 360, 820, 1700], [0.06, 0.035, 0.02, 0.01], [1, 0.6, 0.35, 0.2], g, "soft" if style != "sharp" else "click", 0.004 if style != "sharp" else 0.001)
            elif material == "metal":
                k = modal(0.8, [240, 610, 1430, 2950], [0.25, 0.15, 0.08, 0.04], [1, 0.7, 0.5, 0.3], g, "soft", 0.003)
            else:
                k = modal(0.35, [2300, 4100, 6600], [0.04, 0.02, 0.012], [1, 0.6, 0.3], g, "click", 0.0006)
            place(out, k, t0, 1.0 - 0.1 * i)
        return fade(out, 0.001, 0.1)
    return f


def gravel_steps(g):
    out = np.zeros(int(4.0 * RATE))
    for k in range(4):
        n = int(0.35 * RATE)
        s = grains(0.35, 500, g, lambda gg: click_grain(gg, 900, 4000, (0.002, 0.006), (0.05, 0.35)), lambda t: np.exp(-t * 8))
        s = padto(s, n) + lp(white(n, g), 200) * env_exp(n, 0.03)
        place(out, s, 0.2 + k * 0.95 + g.uniform(-0.05, 0.05), 0.8)
    return fade(out, 0.01, 0.2)


def whisper(v):
    def f(g):
        sec = 1.4 + 0.3 * v
        n = int(sec * RATE)
        out = np.zeros(n)
        t = 0.0
        while t < sec - 0.2:
            d = g.uniform(0.08, 0.22)
            m = int(d * RATE)
            fs = [(g.uniform(500, 900), 6, 1.0), (g.uniform(1200, 2200), 7, 0.6), (g.uniform(2500, 3500), 8, 0.3)]
            syl = formant(d, 0, fs, g, 0, 0, None, np.sin(np.pi * np.arange(m) / m) ** 2)
            place(out, syl, t, g.uniform(0.4, 1.0))
            t += d + g.uniform(0.02, 0.12)
        return fade(hp(out, 600), 0.05, 0.2)
    return f


def drone(kind):
    def f(g):
        sec = 10.0
        n = int(sec * RATE)
        t = np.arange(n) / RATE
        if kind == "low":
            y = sum(np.sin(2 * np.pi * f0 * t + g.uniform(0, 6)) / (k + 1) for k, f0 in enumerate([41, 61.7, 82.3]))
            y += 0.3 * lp(brown(n, g), 90)
        else:
            y = np.sin(2 * np.pi * 55 * t) + np.sin(2 * np.pi * 55.6 * t) + 0.4 * np.sin(2 * np.pi * 110.9 * t)
            y *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.07 * t)
        return loopify(y, 1.0)
    return f


def breath(dist):
    def f(g):
        sec = 3.0
        n = int(sec * RATE)
        out = np.zeros(n)
        for k, (st, d) in enumerate([(0.1, 0.9), (1.5, 1.2)]):
            m = int(d * RATE)
            b = formant(d, 0, [(500, 3, 1.0), (1500, 4, 0.5), (2700, 5, 0.3)], g, 0, 0, None, np.sin(np.pi * np.arange(m) / m) ** 1.5)
            place(out, b, st, 1.0 if k == 0 else 0.8)
        if dist == "far":
            out = lp(out, 1200)
        return fade(out, 0.05, 0.2)
    return f


def cloth_drag(g):
    sec = 2.5
    n = int(sec * RATE)
    return fade(bp(pink(n, g), 300, 3000) * env_adsr(n, 0.4, 0.5, 0.6, 0.8) * (0.7 + 0.3 * np.sin(2 * np.pi * 1.7 * np.arange(n) / RATE)), 0.1, 0.4)


def metal_scrape(g):
    return fade(stick_slip(1.8, 140, g, [700, 1900, 3800], 20, 0.15, lambda u: 1 + 0.4 * u, lambda u: np.sin(np.pi * u)), 0.05, 0.3)


def metal_groan(g):
    return fade(stick_slip(2.5, 18, g, [95, 260, 780], 25, 0.2, lambda u: 1 + 0.3 * np.sin(np.pi * u), lambda u: np.sin(np.pi * u) ** 0.5), 0.1, 0.4)


def wood_scratch(g):
    sec = 1.6
    out = np.zeros(int(sec * RATE))
    for k in range(3):
        m = int(0.35 * RATE)
        s = bp(white(m, g), 1200, 5000) * np.hanning(m) * 0.6 + padto(grains(0.35, 300, g, lambda gg: click_grain(gg, 1500, 5000, (0.001, 0.004), (0.05, 0.2))), m)
        place(out, s, 0.1 + k * 0.45)
    return fade(out, 0.01, 0.1)


def low_thud(g):
    n = int(1.5 * RATE)
    return fade(lp(white(n, g), 90) * env_exp(n, 0.25) * 3 + modal(1.5, [48, 76], [0.4, 0.25], [1, 0.5], g, "soft", 0.02), 0.002, 0.3)


def wet_step(v):
    def f(g):
        n = int(0.4 * RATE)
        y = lp(white(n, g), 300) * env_exp(n, 0.04) * 1.5 + padto(grains(0.25, 300, g, lambda gg: bubble(gg, 300, 1200)), n) * 0.6
        y += bp(white(n, g), 800, 3000) * env_exp(n, 0.07) * (0.3 + 0.15 * v)
        return fade(y, 0.002, 0.05)
    return f


def distant_call(g):
    n = int(1.6 * RATE)
    y = formant(1.6, 210, [(600, 5, 1.0), (1000, 6, 0.6), (2400, 8, 0.2)], g, 0.3, 0.02, lambda u: 1.0 + 0.15 * np.sin(np.pi * u) - 0.2 * u, env_adsr(n, 0.2, 0.4, 0.6, 0.6))
    return fade(lp(y, 1600), 0.05, 0.3)


def tags_far(g):
    """One heavy tag swinging slowly against a buckle, irregular, far."""
    out = np.zeros(int(2.2 * RATE))
    t0 = 0.05
    for k in range(5):
        hit = modal(0.25, [2300 + g.uniform(-80, 80), 3900, 6100], [0.05, 0.03, 0.015], [0.8, 0.4, 0.2], g, "click", 0.0003)
        place(out, hit, t0, 1.0 - 0.15 * k)
        t0 += g.uniform(0.25, 0.55)
    return fade(lp(out, 4500), 0.002, 0.2)


def glass_tap(g):
    out = np.zeros(int(1.2 * RATE))
    for k in range(2):
        place(out, modal(0.3, [2900, 5300, 8100], [0.05, 0.03, 0.015], [1, 0.4, 0.2], g, "click", 0.0004), 0.05 + k * 0.6)
    return fade(out, 0.001, 0.1)


def fence_pull(g):
    out = np.zeros(int(2.6 * RATE))
    creak2 = stick_slip(1.6, 14, g, [380, 900, 2100], 14, 0.3, lambda u: 1 + 0.5 * u, lambda u: np.sin(np.pi * u))
    place(out, creak2, 0.1, 0.6)
    ticks = grains(2.4, 6, g, lambda gg: modal(0.12, [gg.uniform(900, 1400), gg.uniform(2600, 3600)], [0.04, 0.02], [0.6, 0.3], gg, "click", 0.0004))
    place(out, ticks, 0.0, 0.7)
    return fade(lp(out, 4000), 0.02, 0.2)


def branch_bend_snap(g):
    out = np.zeros(int(1.6 * RATE))
    bend = stick_slip(0.9, 40, g, [500, 1200, 2600], 9, 0.3, lambda u: 1 + 1.5 * u, lambda u: u ** 1.5)
    place(out, bend, 0.0, 0.6)
    snap = modal(0.4, [520, 1300, 2800], [0.04, 0.02, 0.01], [1.2, 0.6, 0.3], g, "noise", 0.002)
    place(out, snap, 0.88, 1.0)
    return fade(out, 0.01, 0.1)


def cargo_thud(g):
    y = modal(0.9, [62, 140, 410, 1300, 2500], [0.25, 0.12, 0.06, 0.03, 0.015], [1.4, 0.8, 0.5, 0.3, 0.2], g, "soft", 0.008)
    chain = grains(0.5, 30, g, lambda gg: modal(0.05, [gg.uniform(2400, 3800)], [0.01], [0.3], gg, "click", 0.0003))
    place(y, chain, 0.03, 0.6)
    return fade(y, 0.001, 0.1)


# ------------------------------------------------------------------ catalog

def build_catalog():
    C = {}

    def add(cat, name, loop, model, fn):
        C[name] = (cat, loop, model, fn)
    # WORK (60)
    for sp in ("pine", "spruce", "birch"):
        for sz in ("thin", "thick"):
            add("work", "axe_bite_%s_%s" % (sp, sz), False, "modal wood body + bark noise + fibre grains (%s, %s)" % (sp, sz), axe_bite(sp, sz))
        add("work", "axe_deep_%s" % sp, False, "modal wood body, deep notch (%s)" % sp, axe_bite(sp, "thick", True))
    for v in range(3):
        add("work", "axe_stump_%d" % v, False, "modal stump body + soil grit", stump_chop(v))
    for s in ("small", "large"):
        add("work", "axe_buck_%s" % s, False, "modal lying-log ring", buck_hit(s))
    add("work", "axe_hard_stone", False, "modal stone/steel ring", axe_hard("stone"))
    add("work", "axe_hard_post", False, "modal hard post", axe_hard("post"))
    for w in ("light", "heavy"):
        add("work", "axe_swish_%s" % w, False, "moving band-noise swish", swish(w))
    for v in range(4):
        add("work", "trunk_strain_%d" % v, False, "stick-slip fibre creak", strain(v))
    for v in range(3):
        add("work", "hinge_crack_%d" % v, False, "accelerating fibre tear grains + snap", hinge_crack(v))
    for k in ("pine", "birch"):
        add("work", "crown_rustle_%s" % k, False, "needle/leaf grains moving", crown_rustle(k))
    for s in ("small", "medium", "large"):
        add("work", "fall_impact_%s" % s, False, "ground boom + trunk modes + crown crash", fall_impact(s))
    for v in range(3):
        add("work", "branch_snap_%d" % v, False, "modal snap + splinters", branch_snap(v))
    for s in ("ground", "log"):
        add("work", "log_roll_%s" % s, False, "rumble + knocks", log_roll(s))
    for o in ("ground", "log", "rack_wood", "cart_metal"):
        add("work", "log_drop_%s" % o, False, "two-hit modal drop onto %s" % o, log_drop(o))
    add("work", "log_stack_0", False, "drop + short roll on a deck", log_stack(0))
    add("work", "log_stack_1", False, "two-point roll-on, slide and settle", log_stack_b)
    add("work", "log_drag_loop", True, "scrape bed + ticks", log_drag)
    for k in ("start", "idle", "rev", "load", "stop", "spray"):
        add("work", "saw2_%s" % k, k in ("idle", "rev", "load"), "two-stroke engine model (%s)" % k, saw_v2(k))
    for s in ("small", "large"):
        add("work", "fire_bed_%s_loop" % s, True, "combustion roar + crackle grains", fire_bed(s))
    for v in range(4):
        add("work", "fire_pop_%d" % v, False, "resin pop + sparks", fire_pop(v))
    add("work", "fire_hiss_sap", False, "sap hiss", fire_hiss)
    add("work", "fire_log_place", False, "log drop + flare", fire_log_place)
    add("work", "fire_embers_settle", False, "ember collapse", embers_settle)
    add("work", "chips_fall", False, "falling chip grains", chips_fall)
    add("work", "stump_root_tear", False, "root tear friction + snap", root_tear)
    add("work", "tool_pickup", False, "tool handle knock", tool_pickup)
    # VEHICLES (25)
    for r in ("idle", "low", "mid", "high"):
        add("vehicle", "truck_engine_%s_loop" % r, True, "4-stroke firing model (%s)" % r, truck_loop(r))
    add("vehicle", "truck_start", False, "starter crank + catch", truck_start)
    add("vehicle", "truck_stop", False, "engine wind-down", truck_stop)
    for o in ("open", "close"):
        add("vehicle", "truck_door_%s" % o, False, "door latch/hinge/thunk", truck_door(o))
        add("vehicle", "tailgate_%s" % o, False, "steel panel + chain", tailgate(o))
    add("vehicle", "cargo_rattle_loop", True, "log/chain rattle grains", cargo_rattle)
    add("vehicle", "cargo_log_thud", False, "log onto truck bed: chassis boom + bed ring + chain", cargo_thud)
    for s in ("gravel", "dirt", "grass"):
        add("vehicle", "tire_%s_loop" % s, True, "tyre contact (%s)" % s, tire(s))
    for v in range(2):
        add("vehicle", "suspension_thump_%d" % v, False, "suspension bottoming", suspension(v))
    add("vehicle", "truck_horn", False, "dual-tone horn", truck_horn)
    add("vehicle", "truck_handbrake", False, "ratchet clicks", handbrake)
    add("vehicle", "truck_gear_clunk", False, "gearbox clunk", gear_clunk)
    for s in ("dirt", "wood"):
        add("vehicle", "cart_roll_%s_loop" % s, True, "cart wheel on %s" % s, cart_roll(s))
    add("vehicle", "cart_squeak", False, "axle squeak", cart_squeak)
    add("vehicle", "cart_bump", False, "cart frame bump", cart_bump)
    add("vehicle", "skiff_outboard_loop", True, "outboard engine + water", outboard)
    # MOVEMENT / DOG (25)
    for v in range(3):
        add("movement", "cloth_rustle_%d" % v, False, "cloth band noise + fibre ticks", cloth(v))
    add("movement", "jacket_swish", False, "jacket swish", jacket_swish)
    add("movement", "gear_jingle", False, "belt gear jingle", gear_jingle)
    for s in ("dirt", "wood"):
        add("movement", "boot_scuff_%s" % s, False, "boot scuff (%s)" % s, boot_scuff(s))
    add("movement", "kneel_cloth", False, "kneel: cloth + knee thud", kneel_cloth)
    add("movement", "body_sit", False, "sitting down", body_sit)
    for s, vs in (("dirt", 2), ("wood", 2), ("grass", 1)):
        for v in range(vs):
            add("movement", "paw_%s_%d" % (s, v), False, "dog paw (%s)" % s, paw(s, v))
    for v in range(2):
        add("movement", "collar_tags_%d" % v, False, "collar tag jingle", collar(v))
    add("movement", "dog_shake", False, "dog shake-off", dog_shake)
    add("movement", "dog_drink", False, "lapping", dog_drink)
    add("movement", "dog_sniff", False, "sniff bursts", dog_sniff)
    add("movement", "dog_yawn", False, "formant yawn", dog_yawn)
    for v in range(2):
        add("movement", "dog_bark2_%d" % v, False, "formant bark", dog_bark2(v))
    add("movement", "dog_whine2", False, "formant whine", dog_whine2)
    add("movement", "dog_pant2_loop", True, "panting bursts", dog_pant2)
    add("movement", "dog_growl2", False, "low formant growl", dog_growl2)
    # ENVIRONMENT (45)
    for d in ("near", "far"):
        add("env", "surf_%s_loop" % d, True, "breaking-wave noise swells", surf(d))
    for v in range(2):
        add("env", "shore_wash_%d" % v, False, "swash + fizz", wash(v))
    for k in ("fast", "slow", "trickle"):
        add("env", "water_%s_loop" % k, True, "bubble grains (%s)" % k, water_flow(k))
    add("env", "pond_lap_loop", True, "lap + bubbles", pond)
    for k in ("low", "pines", "birch", "cleared"):
        add("env", "wind_%s_loop" % k, True, "moving filtered wind (%s)" % k, wind(k))
    for v in range(2):
        add("env", "wind_gust_%d" % v, False, "gust swell", gust(v))
    for k in ("light", "heavy", "canvas", "metal", "wood", "drips"):
        add("env", "rain_%s_loop" % k, True, "rain grains (%s)" % k, rain(k))
    add("env", "thunder_near", False, "near thunder", thunder("near", 0))
    for v in range(2):
        add("env", "thunder_far2_%d" % v, False, "far thunder roll", thunder("far", v))
    for b in ("robin", "thrush", "wren", "crow", "gull", "woodpecker"):
        add("env", "bird_%s" % b, False, "bird model (%s)" % b, bird(b))
    add("env", "crickets_loop", True, "cricket chorus", crickets)
    add("env", "frog_chorus_loop", True, "frog chorus", frogs)
    for v in range(2):
        add("env", "owl_hoot_%d" % v, False, "owl hoot formant", owl(v))
    add("env", "nightjar_loop", True, "churring", nightjar)
    add("env", "leaves_fall", False, "falling leaves", leaves_fall)
    add("env", "distant_branch_crack", False, "far branch crack", distant_crack)
    for v in range(2):
        add("env", "drip_%d" % v, False, "water drip", drip(v))
    add("env", "insects_day_loop", True, "day insects", insects_day)
    add("env", "forest_air_loop", True, "forest room tone", air("forest"))
    add("env", "field_air_loop", True, "open-ground room tone", air("field"))
    add("env", "bees_loop", True, "bees", bees)
    add("env", "frog_single", False, "single frog", frog_single)
    add("env", "fish_splash", False, "small splash", splash)
    add("env", "reeds_rustle_loop", True, "reeds rustle", reeds)
    # DOMESTIC (20)
    for o in ("open", "close"):
        add("domestic", "door_wood_%s" % o, False, "wood door %s" % o, door_wood(o))
    add("domestic", "door_latch", False, "latch", latch)
    add("domestic", "door_creak", False, "hinge creak", creak)
    add("domestic", "window_slide", False, "window slide", window_slide)
    add("domestic", "window_rattle", False, "window rattle", window_rattle)
    for k in ("fridge", "fan", "lamp"):
        add("domestic", "%s_hum_loop" % k, True, "%s hum" % k, hum(k))
    add("domestic", "keyboard_type_loop", True, "typing", keyboard)
    add("domestic", "mouse_click", False, "mouse click", mouse_click)
    add("domestic", "notify_chime", False, "computer chime", chime)
    add("domestic", "kettle_boil_loop", True, "kettle boil", kettle)
    add("domestic", "cupboard_close", False, "cupboard close", cupboard)
    for v in range(2):
        add("domestic", "floor_creak_%d" % v, False, "floorboard creak", floor_creak(v))
    add("domestic", "heater_tick", False, "heater expansion ticks", heater_tick)
    add("domestic", "fence_rattle", False, "chain-link rattle", fence_rattle)
    add("domestic", "gate_clank", False, "gate clank", gate_clank)
    add("domestic", "rack_hang", False, "tool hung on rack", rack_hang)
    # HORROR (25)
    for st in ("dull", "sharp", "slow"):
        add("horror", "knock_wood_%s" % st, False, "knock on wood (%s)" % st, knock("wood", st))
    add("horror", "knock_metal", False, "knock on metal", knock("metal", "dull"))
    add("horror", "knock_glass", False, "knock on glass", knock("glass", "sharp"))
    add("horror", "fence_rattle_unseen", False, "slow fence pull: post creak + sparse wire ticks", fence_pull)
    add("horror", "gravel_steps_slow", False, "slow heavy gravel steps", gravel_steps)
    add("horror", "branch_snap_near", False, "green branch bend creak then snap", branch_bend_snap)
    for v in range(3):
        add("horror", "whisper_%d" % v, False, "noise formant whisper", whisper(v))
    for k in ("low", "beating"):
        add("horror", "drone_%s_loop" % k, True, "drone (%s)" % k, drone(k))
    for d in ("close", "far"):
        add("horror", "breath_%s" % d, False, "breath (%s)" % d, breath(d))
    add("horror", "cloth_drag", False, "cloth dragged", cloth_drag)
    add("horror", "metal_scrape", False, "metal scrape", metal_scrape)
    add("horror", "metal_groan", False, "metal groan", metal_groan)
    add("horror", "wood_scratch", False, "scratching on wood", wood_scratch)
    add("horror", "low_thud_far", False, "far heavy thud", low_thud)
    for v in range(2):
        add("horror", "wet_step_%d" % v, False, "wet footstep", wet_step(v))
    add("horror", "distant_call", False, "distant call (formant)", distant_call)
    add("horror", "tags_far", False, "far tag jingle", tags_far)
    add("horror", "glass_tap", False, "glass tap", glass_tap)
    return C
