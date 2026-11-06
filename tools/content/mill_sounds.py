#!/usr/bin/env python3
"""Phase 24: original procedural sawmill sounds (numpy), 22.05 kHz mono WAV.

  mill_motor_loop     electric motor + belt hum (seamless 4 s loop)
  mill_blade_loop     band/circular saw whine with wood-load grit (loop)
  mill_rollers_loop   feed rollers: knurled steel on bark, low rumble (loop)
  mill_board_0..3     a sawn board dropping onto the outfeed conveyor / stack
  mill_band           pallet strapping: tension crank + steel band snap
  mill_winddown       motor and blade spinning down (one-shot, ~5 s)
  mill_rollers_turn   ONE set of rollers turning briefly, unloaded (night cue)
Run: python3 tools/content/mill_sounds.py   (writes audio/generated/)
"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "generated")
rng = np.random.default_rng(2401)


def write(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def t(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, cut):
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def loopable(x, fade=0.25):
    n = int(SR * fade)
    head = x[:n].copy()
    x = x[n:].copy()
    ramp = np.linspace(0, 1, n)
    x[-n:] = x[-n:] * (1 - ramp) + head * ramp
    return x


def env(n, a, d):
    e = np.ones(n)
    ai = max(int(SR * a), 1)
    e[:ai] = np.linspace(0, 1, ai)
    e[ai:] = np.exp(-np.arange(n - ai) / (SR * d))
    return e


def motor():
    tt = t(4.25)
    f = 50.0 * 2   # 100 Hz mains hum + harmonics, slight belt wobble
    wob = 1 + 0.004 * np.sin(2 * np.pi * 0.5 * tt)
    x = sum(a * np.sin(2 * np.pi * f * k * wob * tt) for k, a in [(1, 1.0), (2, 0.5), (3, 0.22), (5, 0.08)])
    belt = lowpass(rng.normal(size=tt.size), 600) * 0.6
    slap = 0.15 * np.sin(2 * np.pi * 6.25 * tt) ** 8
    return loopable(x * 0.6 + belt + slap * belt)


def blade():
    tt = t(4.25)
    whine = sum(a * np.sin(2 * np.pi * f * tt) for f, a in [(820, 1.0), (1640, 0.35), (2470, 0.18)])
    grit = rng.normal(size=tt.size)
    grit = grit - lowpass(grit, 1200)          # high band: wood fibre
    load = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 1.7 * tt + np.sin(2 * np.pi * 0.31 * tt)))
    return loopable(whine * 0.35 + grit * 0.5 * load)


def rollers():
    tt = t(4.25)
    knurl = np.sign(np.sin(2 * np.pi * 37 * tt)) * 0.3
    rumble = lowpass(rng.normal(size=tt.size), 180) * 2.2
    clack = (np.sin(2 * np.pi * 2.3 * tt) > 0.985).astype(float)
    clack = lowpass(clack * rng.normal(size=tt.size), 2500) * 4.0
    return loopable(lowpass(knurl, 900) + rumble + clack)


def board(seed):
    r = np.random.default_rng(seed)
    n = int(SR * 0.45)
    tt = np.arange(n) / SR
    knock = sum(a * np.sin(2 * np.pi * f * tt) for f, a in [(r.uniform(180, 240), 1.0), (r.uniform(410, 520), 0.6), (r.uniform(900, 1150), 0.3)])
    knock *= env(n, 0.002, r.uniform(0.05, 0.09))
    slap = lowpass(r.normal(size=n), 3500) * env(n, 0.001, 0.02)
    rattle = np.zeros(n)
    k = int(SR * r.uniform(0.07, 0.11))
    rattle[k:] = (knock[: n - k] * 0.35)
    return knock + slap * 0.8 + rattle


def band():
    crank = []
    for i in range(5):
        n = int(SR * 0.09)
        c = lowpass(rng.normal(size=n), 4000) * env(n, 0.001, 0.015)
        crank.append(c)
        crank.append(np.zeros(int(SR * 0.06)))
    crank = np.concatenate(crank)
    n = int(SR * 0.6)
    tt = np.arange(n) / SR
    snap = (np.sin(2 * np.pi * 1900 * tt) * 0.5 + rng.normal(size=n)) * env(n, 0.0005, 0.06)
    ring = np.sin(2 * np.pi * 3100 * tt) * env(n, 0.001, 0.25) * 0.25
    return np.concatenate([crank, np.zeros(int(SR * 0.1)), snap + ring])


def winddown():
    tt = t(5.0)
    f = 820 * np.exp(-tt / 1.6)
    ph = 2 * np.pi * np.cumsum(f) / SR
    whine = np.sin(ph) * np.exp(-tt / 2.2)
    hum = np.sin(2 * np.pi * np.cumsum(100 * np.exp(-tt / 2.5)) / SR) * np.exp(-tt / 2.8)
    return whine * 0.5 + hum * 0.7


def rollers_turn():
    tt = t(3.2)
    e = np.minimum(1, tt / 0.4) * np.minimum(1, (3.2 - tt) / 0.9)
    knurl = lowpass(np.sign(np.sin(2 * np.pi * 37 * tt)) * 0.3, 900)
    rumble = lowpass(rng.normal(size=tt.size), 160) * 1.6
    squeal = np.sin(2 * np.pi * (610 + 25 * np.sin(2 * np.pi * 0.7 * tt)) * tt) * 0.06
    return (knurl + rumble + squeal) * e


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("mill_motor_loop", motor(), 0.7)
    write("mill_blade_loop", blade(), 0.7)
    write("mill_rollers_loop", rollers(), 0.7)
    for i in range(4):
        write("mill_board_%d" % i, board(100 + i))
    write("mill_band", band())
    write("mill_winddown", winddown(), 0.75)
    write("mill_rollers_turn", rollers_turn(), 0.7)
    print("wrote mill sounds to", os.path.normpath(OUT))
