#!/usr/bin/env python3
"""Phase 24 soundscape: original procedural sources (numpy/scipy), mono WAV
at the Phase 15 library rate (32 kHz), written to audio/generated/.

Footsteps (5 variants each, new surfaces):
  step_needles_*   conifer litter: soft compressed crunch
  step_gravel_*    camp / mill pad gravel: dense stone ticks
  step_puddle_*    a foot into standing water
  step_wetgrass_*  soaked grass: soft swish + squelch
  step_mud_*       wet dirt: suction squelch
Plant contact (3 variants each):
  plant_grass_*    thin grass / sedge brushing the legs (quiet, airy)
  plant_fern_*     bracken / hazel fronds sweeping past (leafy flutter)
  plant_shrub_*    dry juniper / bramble / deadwood: scrape, then release
  plant_wet_*      any foliage when wet: damp, softer swish + drips
Place beds (seamless 12 s loops, quiet):
  bed_brush_loop   inside thick brush: close leaf movement around the head
  bed_grove_loop   deep stand of veterans: low, still room tone
Music: one original motif (editable below as note lists), three arrangements
  motif_day        warm: plucked melody, pad, bass, with rests
  motif_dusk       thinned: slower, no bass, softer, fades on the subdominant
  motif_night      altered: minor colour, drifting tuning, unresolved ending
Run: python3 tools/content/soundscape24.py
No recordings or third-party material are used.
"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "audio_lib"))
from dsp import RATE, bp, brown, env_exp, fade, grains, hp, loopify, lp, pink, reson, white  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "generated")


def write(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def n_of(sec):
    return int(sec * RATE)


def tick(g, lo, hi, dur):
    k = max(n_of(dur), 8)
    return bp(white(k, g), lo, hi) * env_exp(k, dur * 0.3)


# ------------------------------------------------------------------ steps

def step_needles(g):
    n = n_of(0.28)
    body = lp(pink(n, g), 1800) * env_exp(n, 0.045, 0.004)
    crunch = grains(0.12, 420, g, lambda gg: tick(gg, 1200, 4200, gg.uniform(0.002, 0.006)) * gg.uniform(0.2, 0.7))
    thump = lp(white(n, g), 140) * env_exp(n, 0.03) * 1.4
    out = body * 0.8 + thump
    out[: len(crunch)] += crunch * 0.6
    return fade(out, 0.001, 0.05)


def step_gravel(g):
    n = n_of(0.26)
    stones = grains(0.18, 900, g, lambda gg: tick(gg, 2200, 7500, gg.uniform(0.001, 0.004)) * gg.uniform(0.2, 1.0))
    out = np.zeros(n)
    out[: len(stones)] += stones * np.linspace(1.0, 0.2, len(stones))
    out += lp(white(n, g), 220) * env_exp(n, 0.025) * 0.9
    out += bp(white(n, g), 600, 2400) * env_exp(n, 0.04) * 0.25
    return fade(out, 0.0005, 0.04)


def step_puddle(g):
    n = n_of(0.45)
    splash = bp(white(n, g), 450, 3200) * env_exp(n, 0.05, 0.003)
    out = splash
    t = np.arange(n) / RATE
    for _ in range(g.integers(2, 5)):
        at = g.uniform(0.01, 0.12)
        f0 = g.uniform(500, 900)
        k = n_of(0.06)
        tt = np.arange(k) / RATE
        bub = np.sin(2 * np.pi * (f0 * tt + f0 * 3.0 * tt * tt)) * np.exp(-tt / 0.015)
        i = n_of(at)
        out[i:i + k] += bub[: max(0, min(k, n - i))] * g.uniform(0.2, 0.5)
    out += lp(white(n, g), 160) * env_exp(n, 0.04) * 0.6
    drip = hp(white(n, g), 3000) * np.exp(-((t - 0.2) ** 2) / 0.002) * 0.08
    return fade(out + drip, 0.001, 0.08)


def step_wetgrass(g):
    n = n_of(0.3)
    swish = bp(pink(n, g), 900, 5000) * env_exp(n, 0.06, 0.012) * 0.5
    sq = bp(white(n, g), 180, 700) * env_exp(n, 0.05, 0.006) * (0.6 + 0.4 * np.sin(np.arange(n) / RATE * 2 * np.pi * 35))
    return fade(swish + sq * 0.8 + lp(white(n, g), 150) * env_exp(n, 0.03) * 0.8, 0.002, 0.06)


def step_mud(g):
    n = n_of(0.4)
    t = np.arange(n) / RATE
    suction = bp(white(n, g), 120, 600) * (np.exp(-t / 0.05) + 0.6 * np.exp(-((t - 0.18) ** 2) / 0.002))
    pop = reson(white(n, g) * np.exp(-((t - 0.2) ** 2) / 0.0002), g.uniform(240, 380), 6) * 0.3
    return fade(suction + pop + lp(white(n, g), 120) * env_exp(n, 0.04), 0.002, 0.08)


# ------------------------------------------------------------------ plants

def flutter(n, g, rate):
    t = np.arange(n) / RATE
    return 0.55 + 0.45 * np.abs(np.sin(2 * np.pi * rate * t + g.uniform(0, 6))) * (0.7 + 0.3 * lp(white(n, g), 30) / 0.2)


def plant_grass(g):
    n = n_of(g.uniform(0.22, 0.32))
    return fade(bp(pink(n, g), 2500, 9000) * env_exp(n, 0.07, 0.03), 0.01, 0.06)


def plant_fern(g):
    n = n_of(g.uniform(0.42, 0.55))
    x = bp(pink(n, g), 700, 5200) * flutter(n, g, g.uniform(14, 22))
    env = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return fade(x * env, 0.01, 0.05)


def plant_shrub(g):
    n = n_of(g.uniform(0.55, 0.7))
    t = np.arange(n) / RATE
    scrape = bp(white(n, g), 1500, 6500) * np.exp(-((t - 0.12) ** 2) / 0.006)
    twigs = grains(0.3, 60, g, lambda gg: tick(gg, 1800, 5500, gg.uniform(0.003, 0.01)) * gg.uniform(0.3, 1.0))
    out = scrape * 0.7
    out[: len(twigs)] += twigs * 0.8
    # Release: the branch springs back with a couple of dry snaps.
    rel = grains(0.12, 40, g, lambda gg: tick(gg, 2500, 7000, gg.uniform(0.002, 0.005)))
    i = n_of(0.38)
    out[i:i + len(rel)] += rel[: max(0, n - i)] * 0.7
    return fade(out, 0.004, 0.05)


def plant_wet(g):
    n = n_of(g.uniform(0.4, 0.5))
    x = lp(bp(pink(n, g), 400, 4000), 2500) * np.sin(np.linspace(0, np.pi, n)) ** 1.3
    t = np.arange(n) / RATE
    for _ in range(g.integers(2, 4)):
        at = g.uniform(0.1, 0.4)
        f0 = g.uniform(1800, 3200)
        x += np.sin(2 * np.pi * f0 * (t - at)) * np.exp(-np.clip(t - at, 0, None) / 0.01) * (t > at) * 0.12
    return fade(x, 0.01, 0.06)


# ------------------------------------------------------------------ beds

def bed_brush(g):
    sec = 12.6
    n = n_of(sec)
    leaves = bp(pink(n, g), 1400, 6500)
    patches = lp(np.abs(white(n, g)), 0.8)
    patches = (patches - patches.min()) / (np.ptp(patches) + 1e-9)
    out = leaves * (0.25 + 0.75 * patches ** 2)
    out += lp(brown(n, g), 200) * 0.15
    return loopify(out, 0.6)


def bed_grove(g):
    sec = 12.6
    n = n_of(sec)
    low = lp(brown(n, g), 260) * 0.8
    air = bp(pink(n, g), 600, 2400) * 0.12
    swell = 0.7 + 0.3 * np.sin(np.arange(n) / RATE * 2 * np.pi / sec)
    return loopify((low + air) * swell, 0.6)


# ------------------------------------------------------------------ music
# The motif (editable source). Notes as (MIDI, beats); None = rest.
MOTIF_A = [(74, 1), (78, .5), (81, .5), (79, 1), (78, .5), (76, .5), (74, 1.5), (None, .5), (69, 1), (None, 1)]
MOTIF_B = [(71, 1), (74, .5), (76, .5), (78, 1), (76, 1), (74, 2), (None, 2)]
CHORDS_DAY = [[50, 57, 62, 66], [43, 55, 59, 62], [47, 54, 59, 62], [45, 57, 61, 64]]   # D G Bm A
CHORDS_DAY_END = [[50, 57, 62, 66]]
# Night: same contour, minor colour (F natural, B flat), ends on E over B flat.
NIGHT = {78: 77, 71: 70, 66: 65, 61: 60}
CHORDS_NIGHT = [[50, 57, 62, 65], [46, 53, 58, 62], [43, 50, 58, 62], [46, 52, 58, 64]]   # Dm Bb Gm Bb(add#11)


def hz(m, cents=0.0):
    return 440.0 * 2 ** ((m - 69 + cents / 100.0) / 12)


def pluck(f, sec, g, bright=0.5):
    """Karplus-Strong string."""
    n = n_of(sec)
    period = max(int(RATE / f), 2)
    buf = (g.uniform(-1, 1, period) * 0.8)
    buf = lp(buf, 1500 + 6000 * bright, 1) if period > 16 else buf
    out = np.zeros(n)
    b = buf.copy()
    decay = 0.996
    for i in range(n):
        j = i % period
        v = b[j]
        out[i] = v
        b[j] = decay * 0.5 * (v + b[(j + 1) % period])
    # An integer delay line is up to ~40 cents off at high notes: resample
    # so the string sounds at exactly f. This loop averages with the not yet
    # updated next sample, so the loop delay is period - 0.5 samples.
    f_actual = RATE / (period - 0.5)
    ratio = f / f_actual
    src_t = np.arange(n) * ratio
    out = np.interp(src_t, np.arange(n), out, right=0.0)
    return out * env_exp(n, sec * 0.45, 0.002)


def bell(f, sec, g):
    """Soft music-box tone (slightly inharmonic partial)."""
    t = np.arange(n_of(sec)) / RATE
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.25)
    return x * np.exp(-t / (sec * 0.35)) * np.clip(t / 0.004, 0, 1)


def pad(notes, sec, g, detune=6.0, bright=900):
    n = n_of(sec)
    t = np.arange(n) / RATE
    x = np.zeros(n)
    for m in notes:
        for c in (-detune, detune):
            x += np.sin(2 * np.pi * hz(m, c + g.uniform(-1, 1)) * t + g.uniform(0, 6))
    x = lp(x, bright)
    a = min(1.2, sec * 0.3)
    env = np.clip(t / a, 0, 1) * np.clip((sec - t) / a, 0, 1)
    return x * env / max(len(notes), 1)


def arrange(kind, g):
    bpm = {"day": 76, "dusk": 64, "night": 58}[kind]
    beat = 60.0 / bpm
    phrases = [MOTIF_A, MOTIF_B, MOTIF_A, MOTIF_B] if kind == "day" else [MOTIF_A, MOTIF_B]
    chords = CHORDS_NIGHT if kind == "night" else CHORDS_DAY
    beats_total = sum(sum(d for _, d in p) for p in phrases) + 4 + 6     # intro bar + tail
    n = n_of(beats_total * beat)
    mel = np.zeros(n)
    acc = np.zeros(n)
    t0 = 4 * beat    # one bar of pad alone
    pos = t0
    drift = 0.0
    last_note = None
    for pi, ph in enumerate(phrases):
        for k, (m, d) in enumerate(ph):
            if m is not None:
                note = m
                cents = 0.0
                if kind == "night":
                    note = NIGHT.get(m, m)
                    drift = np.clip(drift + g.normal(0, 4), -18, 18)     # uncertain tuning
                    cents = drift
                    if pi == len(phrases) - 1 and k >= len(ph) - 3:
                        note = 76                                       # unresolved: hang on E
                if kind == "dusk" and pi == len(phrases) - 1 and k >= len(ph) - 3:
                    note = 79                                           # rests on G (subdominant)
                if kind == "night":
                    tone = bell(hz(note, cents), d * beat + 1.2, g) * 0.8
                else:
                    tone = pluck(hz(note, cents), d * beat + 1.0, g, 0.6 if kind == "day" else 0.45)
                i = n_of(pos)
                m2 = min(len(tone), n - i)
                mel[i:i + m2] += tone[:m2] * (1.0 if kind == "day" else 0.8)
                last_note = note
            pos += d * beat
    # Harmony: one chord per 2 bars (8 beats), pad (+ bass on day).
    bars = int(np.ceil((pos - t0) / (8 * beat))) + 1
    for b in range(bars):
        ch = chords[b % len(chords)]
        if b == bars - 1:
            ch = CHORDS_DAY_END[0] if kind == "day" else ([43, 55, 59, 62] if kind == "dusk" else chords[-1])
        st = t0 + b * 8 * beat - (4 * beat if b == 0 else 0)
        sec = 8 * beat + (4 * beat if b == 0 else 0) + (5 * beat if b == bars - 1 else 0.6)
        p = pad(ch[1:] if kind != "night" else ch, sec, g, 4.0 if kind == "day" else (7.0 if kind == "dusk" else 14.0), 1100 if kind == "day" else 700)
        i = n_of(st)
        m2 = min(len(p), n - i)
        if m2 <= 0:
            continue
        acc[i:i + m2] += p[:m2] * (0.22 if kind == "day" else 0.18)
        if kind == "day":
            for q in range(0, 8, 2):
                if b == bars - 1 and q > 0:
                    break
                bs = pluck(hz(ch[0], 0), 2 * beat + 0.4, g, 0.2) * 0.7
                j = n_of(st + (4 * beat if b == 0 else 0) + q * beat)
                m3 = min(len(bs), n - j)
                if m3 > 0:
                    acc[j:j + m3] += bs[:m3]
        if kind == "night" and b % 2 == 0:
            dr = pad([ch[0] - 12], sec, g, 3.0, 220) * 0.6               # low drone
            acc[i:i + min(len(dr), n - i)] += dr[: min(len(dr), n - i)]
    mix = mel * 0.8 + acc
    # Gentle room: a few early reflections (keeps it intimate, no wash).
    room = np.zeros_like(mix)
    for d_s, gn in [(0.031, 0.22), (0.057, 0.16), (0.089, 0.11), (0.143, 0.07)]:
        k = n_of(d_s)
        room[k:] += mix[:-k] * gn
    out = mix + lp(room, 3500)
    return fade(out, 0.05, 2.5)


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, f, cnt, peak in [
        ("step_needles", step_needles, 5, 0.8), ("step_gravel", step_gravel, 5, 0.8),
        ("step_puddle", step_puddle, 5, 0.8), ("step_wetgrass", step_wetgrass, 5, 0.8),
        ("step_mud", step_mud, 5, 0.8),
        ("plant_grass", plant_grass, 3, 0.7), ("plant_fern", plant_fern, 3, 0.8),
        ("plant_shrub", plant_shrub, 3, 0.85), ("plant_wet", plant_wet, 3, 0.75),
    ]:
        for k in range(cnt):
            g = np.random.default_rng(2400 + k * 31 + sum(map(ord, name)))
            write("%s_%d" % (name, k), f(g), peak)
            made.append("%s_%d" % (name, k))
    for name, f in [("bed_brush_loop", bed_brush), ("bed_grove_loop", bed_grove)]:
        write(name, f(np.random.default_rng(2424 + len(name))), 0.8)
        made.append(name)
    for kind in ["day", "dusk", "night"]:
        write("motif_" + kind, arrange(kind, np.random.default_rng(2440 + len(kind))), 0.8)
        made.append("motif_" + kind)
    print("wrote %d files to %s" % (len(made), os.path.abspath(OUT)))


if __name__ == "__main__":
    main()
