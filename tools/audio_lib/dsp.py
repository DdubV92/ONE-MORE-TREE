"""Phase 15 DSP toolkit for the original procedural sound library.

Everything here is deterministic (explicit numpy Generators) and produces mono
float32 arrays at RATE. Models:
  modal()        - bank of damped resonances excited by a shaped impulse/noise
                   (wood, metal, plastic, glass impacts)
  stick_slip()   - friction creak: irregular pulse train through resonances
  engine()       - firing-pulse train through body/exhaust resonances
  grains()       - stochastic short events (crackle, rain drops, chips, ticks)
  formant()      - glottal pulse / noise through formant filters (voices,
                   animal calls, breaths)
  wind_bed()     - pink noise through slowly moving band filters
No recordings are used anywhere: these are original synthesized sources.
"""
import numpy as np
from scipy import signal

RATE = 32000


def rng(seed):
    return np.random.default_rng(seed)


def t_axis(sec):
    return np.arange(int(sec * RATE)) / RATE


def white(n, g):
    return g.standard_normal(n).astype(np.float64)


def pink(n, g):
    # FFT 1/f shaping.
    x = g.standard_normal(n)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / RATE)
    f[0] = f[1]
    X /= np.sqrt(f)
    y = np.fft.irfft(X, n)
    return y / (np.std(y) + 1e-9)


def brown(n, g):
    y = np.cumsum(g.standard_normal(n))
    y = signal.sosfilt(signal.butter(1, 20, "hp", fs=RATE, output="sos"), y)
    return y / (np.std(y) + 1e-9)


def bp(x, lo, hi, order=2):
    hi = min(hi, RATE / 2 - 100)
    return signal.sosfilt(signal.butter(order, [lo, hi], "bandpass", fs=RATE, output="sos"), x)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, min(f, RATE / 2 - 100), "lowpass", fs=RATE, output="sos"), x)


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, "highpass", fs=RATE, output="sos"), x)


def reson(x, f, q):
    """Two-pole resonator (peaking bandpass) at f with quality q."""
    b, a = signal.iirpeak(min(f, RATE / 2 - 200), q, fs=RATE)
    return signal.lfilter(b, a, x)


def env_exp(n, decay_s, attack_s=0.001):
    t = np.arange(n) / RATE
    a = np.clip(t / max(attack_s, 1e-5), 0, 1)
    return a * np.exp(-t / max(decay_s, 1e-5))


def env_adsr(n, a, d, s, r):
    t = np.arange(n) / RATE
    total = n / RATE
    e = np.where(t < a, t / max(a, 1e-5), 1.0)
    e = np.where((t >= a) & (t < a + d), 1 - (1 - s) * (t - a) / max(d, 1e-5), e)
    e = np.where(t >= a + d, s, e)
    rel = np.clip((total - t) / max(r, 1e-5), 0, 1)
    return e * rel


def fade(x, fin=0.005, fout=0.02):
    n = len(x)
    a = min(int(fin * RATE), n // 2)
    b = min(int(fout * RATE), n // 2)
    y = x.copy()
    if a > 0:
        y[:a] *= np.linspace(0, 1, a)
    if b > 0:
        y[-b:] *= np.linspace(1, 0, b)
    return y


def loopify(x, xfade_s=0.3):
    """Seamless loop: crossfade the tail into the head (equal power)."""
    k = int(xfade_s * RATE)
    head = x[:k].copy()
    tail = x[-k:].copy()
    w = np.linspace(0, np.pi / 2, k)
    y = x[:-k].copy()
    y[:k] = head * np.sin(w) + tail * np.cos(w)
    return y


def modal(sec, freqs, decays, amps, g, excite="click", excite_s=0.002, noise_mix=0.0, jitter=0.0):
    """Impact through a resonance bank. freqs/decays/amps are lists."""
    n = int(sec * RATE)
    ex = np.zeros(n)
    k = max(int(excite_s * RATE), 2)
    if excite == "click":
        ex[:k] = np.hanning(k * 2)[k:] * (1 + 0.3 * g.standard_normal(k))
    elif excite == "noise":
        ex[:k] = g.standard_normal(k) * np.hanning(k)
    elif excite == "soft":
        ex[:k] = np.hanning(k)
    t = np.arange(n) / RATE
    y = np.zeros(n)
    for f, d, a in zip(freqs, decays, amps):
        f2 = f * (1 + jitter * g.uniform(-1, 1))
        ir = np.exp(-t / d) * np.sin(2 * np.pi * f2 * t + g.uniform(0, 6.28))
        y += a * signal.fftconvolve(ex, ir[: min(n, int(d * 8 * RATE) + 1)])[:n]
    if noise_mix > 0:
        y += noise_mix * hp(white(n, g), 1500) * env_exp(n, excite_s * 6)
    return y


def grains(sec, rate_hz, g, make, rate_env=None):
    """Poisson-distributed grains; make(g) returns a short array."""
    n = int(sec * RATE)
    y = np.zeros(n)
    t = 0.0
    while t < sec:
        r = rate_hz * (rate_env(t) if rate_env else 1.0)
        t += g.exponential(1.0 / max(r, 1e-3))
        i = int(t * RATE)
        if i >= n:
            break
        gr = make(g)
        m = min(len(gr), n - i)
        y[i:i + m] += gr[:m]
    return y


def click_grain(g, f_lo=1500, f_hi=6000, dur=(0.002, 0.012), amp=(0.2, 1.0)):
    d = g.uniform(*dur)
    m = max(int(d * RATE), 8)
    x = g.standard_normal(m) * env_exp(m, d / 3)
    f = g.uniform(f_lo, f_hi)
    return reson(x, f, 4) * g.uniform(*amp)


def stick_slip(sec, f0, g, res_freqs, res_q=12, jitter=0.25, f_curve=None, amp_curve=None):
    """Creak/scrape: irregular friction pulses exciting resonances."""
    n = int(sec * RATE)
    y = np.zeros(n)
    t = 0.0
    while t < sec:
        f = f0 * (f_curve(t / sec) if f_curve else 1.0)
        t += (1.0 / max(f, 1.0)) * (1 + jitter * g.uniform(-1, 1))
        i = int(t * RATE)
        if i >= n:
            break
        a = amp_curve(t / sec) if amp_curve else 1.0
        y[i] += a * g.uniform(0.5, 1.0)
    out = np.zeros(n)
    for fr in res_freqs:
        out += reson(y, fr, res_q)
    return out


def engine(sec, f_fire, g, body=(110, 420, 1150), jitter=0.04, f_end=None, rough=0.3):
    """Firing-pulse engine (f_fire = firing pulses per second)."""
    n = int(sec * RATE)
    imp = np.zeros(n)
    t = 0.0
    while t < sec:
        f = f_fire if f_end is None else f_fire + (f_end - f_fire) * (t / sec)
        t += (1.0 / f) * (1 + jitter * g.uniform(-1, 1))
        i = int(t * RATE)
        if i >= n:
            break
        imp[i] = g.uniform(1 - rough, 1.0)
    y = np.zeros(n)
    for k, fr in enumerate(body):
        y += reson(imp, fr, 2.5 + k) * (1.0 / (k + 1))
    y += lp(imp, 300) * 6
    y += 0.06 * bp(white(n, g), 300, 2500) * (lp(np.abs(imp), 60) * 40 + 0.2)
    return y


def formant(sec, f0, formants, g, breath=0.0, vibrato=0.0, f0_curve=None, amp_env=None):
    """Glottal pulse train (or noise when f0 <= 0) through formant filters."""
    n = int(sec * RATE)
    if f0 > 0:
        t = np.arange(n) / RATE
        f = f0 * (f0_curve(t / sec) if f0_curve else 1.0) * (1 + vibrato * np.sin(2 * np.pi * 5.5 * t))
        ph = np.cumsum(f / RATE)
        src = (ph % 1.0) ** 3 - 0.25       # skewed glottal-ish pulse
        src = src - np.mean(src)
        src += breath * white(n, g)
    else:
        src = white(n, g)
    y = np.zeros(n)
    for fr, q, a in formants:
        y += a * reson(src, fr, q)
    if amp_env is not None:
        y *= amp_env
    return y


def wind_bed(sec, g, lo=150, hi=1400, gust=0.5, speed=0.08):
    n = int(sec * RATE)
    x = pink(n, g)
    t = np.arange(n) / RATE
    m = 0.5 + 0.5 * np.sin(2 * np.pi * speed * t + g.uniform(0, 6)) * gust + 0.2 * pink(n, g)[::1] * 0.0
    out = bp(x, lo, hi) * (0.6 + 0.4 * m)
    # A slowly moving resonance gives the "whistle through branches" colour.
    centre = (lo + hi) / 2
    out += 0.25 * reson(x, centre * (1 + 0.3 * np.sin(2 * np.pi * speed * 0.7 * t[0])), 3)
    return out


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return (x / m * peak).astype(np.float32)


def place(dst, src, at_s, gain=1.0):
    i = int(at_s * RATE)
    m = min(len(src), len(dst) - i)
    if m > 0:
        dst[i:i + m] += src[:m] * gain
    return dst


def padto(x, n):
    y = np.zeros(n)
    m = min(n, len(x))
    y[:m] = x[:m]
    return y
