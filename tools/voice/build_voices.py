"""Phase 18 voice pipeline: renders the crew dialogue bank into game-ready
speech clips (offline; generation never runs inside the game).

  python3 tools/voice/build_voices.py                 # all required mappings
  python3 tools/voice/build_voices.py --only cut.marta.019 [--only ...]
  python3 tools/voice/build_voices.py --check         # report, render nothing

Inputs:  data/dialogue/crew/*.json (canonical text), tools/voice/profiles.json
Outputs: audio/voice/<profile>/<line_id>.ogg  (mono Ogg Vorbis, 16 kHz)
         data/voice/manifest.json   full provenance per mapping
         data/voice/index.json      compact runtime index (duration, delivery,
                                     mouth envelope at 20 Hz)

Mapping rules (docs/editorial/VOICE_CAST.md):
  - a character line (speaker EMP-0x) -> that worker's profile;
  - `any` -> all five roster profiles + the two replacement profiles;
  - `trait:x` -> roster workers who have that trait (incl. the legacy second
    traits EMP-01 sociable / EMP-02 skeptical) + the replacement profiles.
Delivery per line is decided from its own context (see delivery_for()) and
mirrored by scripts/dialogue/voice_bank.gd.
Cache key = sha1(normalized spoken text, profile settings, delivery
settings, generator + version, preset); unchanged mappings are skipped, so
runs are resumable and only affected clips are refreshed after a revision.
"""
import glob, hashlib, json, os, re, subprocess, sys, tempfile

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROFILES = json.load(open(os.path.join(ROOT, "tools/voice/profiles.json"), encoding="utf-8"))
ROSTER_TRAITS = {
    "EMP-01": {"hard_working", "sociable"},
    "EMP-02": {"stronger", "skeptical"},
    "EMP-03": {"observant", "level_headed"},
    "EMP-04": {"timid", "reliable_driver"},
    "EMP-05": {"sociable", "skeptical"},
}
WORKER_PROFILE = {v["worker"]: k for k, v in PROFILES["profiles"].items() if v["worker"]}
REPLACEMENTS = ["crew_m", "crew_f"]
OUT_AUDIO = os.path.join(ROOT, "audio/voice")
MANIFEST = os.path.join(ROOT, "data/voice/manifest.json")
INDEX = os.path.join(ROOT, "data/voice/index.json")


# ---------------------------------------------------------------- Phase 24
# Flite (CMU, permissive BSD-style licence, installed as the system library
# libflite1) statistical-parametric voices trained on recorded speakers: far
# less robotic than eSpeak's formant synthesis. Called through ctypes (no
# command-line tool or model download). A small resample after synthesis
# moves pitch and vocal-tract size together (a slightly bigger or smaller
# speaker) while the duration stretch is pre-compensated so timing holds.
_FLITE = {}


def _flite():
    if "lib" in _FLITE:
        return _FLITE
    import ctypes as C
    lib = C.CDLL("libflite.so.1", mode=C.RTLD_GLOBAL)
    for d in ["libflite_usenglish.so.1", "libflite_cmulex.so.1"]:
        C.CDLL(d, mode=C.RTLD_GLOBAL)
    lib.flite_init()

    class Voice(C.Structure):
        _fields_ = [("name", C.c_char_p), ("features", C.c_void_p), ("ffunctions", C.c_void_p)]

    lib.flite_text_to_wave.restype = C.c_void_p
    lib.flite_text_to_wave.argtypes = [C.c_char_p, C.c_void_p]
    lib.cst_wave_save_riff.argtypes = [C.c_void_p, C.c_char_p]
    lib.delete_wave.argtypes = [C.c_void_p]
    lib.feat_set_float.argtypes = [C.c_void_p, C.c_char_p, C.c_float]
    lib.get_param_float.restype = C.c_float
    lib.get_param_float.argtypes = [C.c_void_p, C.c_char_p, C.c_float]
    _FLITE["lib"] = lib
    _FLITE["voices"] = {}
    _FLITE["defaults"] = {}
    for v in ["slt", "rms", "awb"]:
        vl = C.CDLL("libflite_cmu_us_%s.so.1" % v, mode=C.RTLD_GLOBAL)
        reg = getattr(vl, "register_cmu_us_%s" % v)
        reg.restype = C.POINTER(Voice)
        reg.argtypes = [C.c_char_p]
        vo = reg(None)
        f = vo.contents.features
        _FLITE["voices"][v] = vo
        _FLITE["defaults"][v] = {k: lib.get_param_float(f, k.encode(), dflt) for k, dflt in
                                  [("int_f0_target_mean", 110.0), ("int_f0_target_stddev", 20.0), ("duration_stretch", 1.0)]}
    return _FLITE


def flite_version():
    if "version" in _FLITE:
        return _FLITE["version"]
    try:
        import subprocess as sp
        out = sp.run(["dpkg-query", "-W", "-f=${Version}", "libflite1"], capture_output=True, text=True).stdout.strip()
        _FLITE["version"] = "flite " + (out or "unknown")
        return _FLITE["version"]
    except Exception:
        return "flite unknown"


def generator_version():
    return flite_version() if PROFILES["generator"] == "flite" else espeak_version()


def _lpc(frame, order):
    r = np.correlate(frame, frame, "full")[len(frame) - 1:len(frame) + order]
    if r[0] <= 1e-12:
        return np.zeros(order + 1)
    a = np.zeros(order + 1)
    a[0] = 1.0
    e = r[0]
    for i in range(1, order + 1):
        k = -(r[i] + np.dot(a[1:i], r[i - 1:0:-1])) / e
        a[1:i] = a[1:i] + k * a[i - 1:0:-1]
        a[i] = k
        e *= (1 - k * k)
        if e <= 1e-12:
            break
    return a


def whisperize(y, sr, seed):
    """Whispered speech: the voice's own spectral envelope (LPC, per 20 ms
    frame) excited by noise instead of a pitched source."""
    from scipy.signal import lfilter
    g = np.random.default_rng(seed)
    n = int(0.02 * sr)
    hop = n // 2
    win = np.hanning(n)
    out = np.zeros(y.size + n)
    for i in range(0, y.size - n, hop):
        fr = y[i:i + n] * win
        en = np.sqrt(np.mean(fr ** 2))
        if en < 1e-5:
            continue
        a = _lpc(fr, 18)
        ex = g.standard_normal(n)
        sh = lfilter([1.0], a, ex)
        sh *= en / max(np.sqrt(np.mean(sh ** 2)), 1e-9)
        out[i:i + n] += sh * win
    return out[: y.size]


def render_flite(text, st):
    from scipy.signal import resample_poly
    F = _flite()
    lib = F["lib"]
    vo = F["voices"][st["fvoice"]]
    f = vo.contents.features
    d = F["defaults"][st["fvoice"]]
    shift = float(st.get("shift", 1.0))
    lib.feat_set_float(f, b"int_f0_target_mean", float(st.get("f0", d["int_f0_target_mean"])) / shift)
    lib.feat_set_float(f, b"int_f0_target_stddev", float(st.get("f0_sd", d["int_f0_target_stddev"])) / shift)
    lib.feat_set_float(f, b"duration_stretch", float(st.get("stretch", 1.0)) * shift)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        path = tf.name
    w = lib.flite_text_to_wave(text.encode("utf-8"), vo)
    lib.cst_wave_save_riff(w, path.encode())
    lib.delete_wave(w)
    y, sr = sf.read(path, dtype="float64")
    os.unlink(path)
    if y.ndim > 1:
        y = y.mean(axis=1)
    if abs(shift - 1.0) > 1e-3 and y.size:
        # Play back `shift` times faster: pitch and formants x shift.
        up, down = 200, int(round(200 * shift))
        y = resample_poly(y, up, down)
    if st.get("whisper"):
        y = whisperize(y, sr, int(hashlib.sha1(text.encode()).hexdigest()[:6], 16))
    return y, sr


def clean_speech(y, sr):
    """Phase 24 cleanup: DC/rumble out, a gentle presence lift for
    intelligibility (2-4 kHz), soft top to tame vocoder buzz, light
    compression so quiet syllables carry at distance."""
    from scipy.signal import butter, sosfilt
    if y.size == 0:
        return y
    y = sosfilt(butter(2, 80, "hp", fs=sr, output="sos"), y)
    pres = sosfilt(butter(2, [2000, 4200], "bandpass", fs=sr, output="sos"), y)
    y = y + 0.35 * pres
    y = sosfilt(butter(2, min(7200, sr / 2 - 200), "lp", fs=sr, output="sos"), y)
    # RMS envelope compressor (2:1 above -24 dBFS relative, 10 ms / 120 ms).
    env = np.sqrt(np.convolve(y * y, np.ones(int(0.01 * sr)) / int(0.01 * sr), "same")) + 1e-9
    ref = np.sqrt(np.mean(y * y)) + 1e-9
    lvl = 20 * np.log10(env / ref)
    gain_db = np.where(lvl > -6.0, -(lvl + 6.0) * 0.5, 0.0)
    k = int(0.12 * sr)
    gain_db = np.convolve(gain_db, np.ones(k) / k, "same")
    return y * 10 ** (gain_db / 20)


def espeak_version():
    try:
        return subprocess.run(["espeak-ng", "--version"], capture_output=True, text=True).stdout.strip()
    except Exception:
        return "unavailable"


def delivery_for(line):
    """One purposeful delivery per line, from its own situation."""
    when = set(line.get("when", []))
    needs = set(line.get("needs", []))
    cat = line.get("cat", "")
    if "act:hide" in when:
        return "whisper"
    if "mood:shaken" in when or "mood:refusing" in when:
        return "frightened"
    if "mood:uneasy" in when or "saw:strange" in needs or "heard:strange" in needs or cat == "survival" or (cat == "dusk" and "phase:night" in when):
        return "uneasy"
    if when & {"act:cut", "act:fell", "act:buck", "act:stump", "act:carry", "act:yard"} and len(line.get("text", "")) < 90:
        return "effort"
    return "calm"


def profiles_for(line):
    sp = line.get("speaker", "any")
    if sp in WORKER_PROFILE:
        return [WORKER_PROFILE[sp]]
    if sp == "any":
        return [WORKER_PROFILE[e] for e in sorted(ROSTER_TRAITS)] + REPLACEMENTS
    if sp.startswith("trait:"):
        t = sp[6:]
        return [WORKER_PROFILE[e] for e in sorted(ROSTER_TRAITS) if t in ROSTER_TRAITS[e]] + REPLACEMENTS
    return REPLACEMENTS


def spoken_text(text, listener="you"):
    t = text.replace("{listener}", listener)
    for k, v in PROFILES["pronounce"].items():
        t = re.sub(r"\b%s\b" % re.escape(k), v, t)
    return re.sub(r"\s+", " ", t).strip()


def settings(profile, delivery):
    p = dict(PROFILES["profiles"][profile])
    d = PROFILES["deliveries"][delivery]
    if PROFILES["generator"] == "flite":
        fl = p["flite"]
        return {"fvoice": fl["voice"], "f0": round(fl["f0"] * d.get("f0_mul", 1.0), 1),
                "f0_sd": round(fl["f0_sd"] * d.get("sd_mul", 1.0), 1),
                "stretch": round(fl["stretch"] * d.get("stretch_mul", 1.0), 3), "shift": fl["shift"],
                "whisper": bool(d.get("whisper", False)), "rms_db": d["rms_db"]}
    var = p["variant"]
    if delivery == "whisper":
        var = d["variant_f"] if profile in PROFILES["female"] else d["variant"]
    return {"voice": p["voice"], "variant": var, "pitch": max(0, min(99, p["pitch"] + d["pitch"])),
            "speed": int(round(p["speed"] * d["speed"])),
            "gap": p["gap"], "amp": d["amp"], "rms_db": d["rms_db"]}


def cache_key(text, st):
    raw = json.dumps({"t": text.lower(), "s": st, "g": PROFILES["generator"], "v": generator_version(), "p": PROFILES["preset"]}, sort_keys=True)
    return hashlib.sha1(raw.encode()).hexdigest()


def render(text, st):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        path = tf.name
    cmd = ["espeak-ng", "-v", "%s+%s" % (st["voice"], st["variant"]), "-p", str(st["pitch"]),
           "-s", str(st["speed"]), "-g", str(st["gap"]), "-a", str(st["amp"]), "-w", path, text]
    subprocess.run(cmd, check=True, capture_output=True)
    y, sr = sf.read(path, dtype="float64")
    os.unlink(path)
    if y.ndim > 1:
        y = y.mean(axis=1)
    return y, sr


def process(y, sr, rms_db):
    flags = []
    if y.size == 0 or not np.isfinite(y).all():
        return y, ["empty"]
    a = np.abs(y)
    thr = 10 ** (-45 / 20) * max(a.max(), 1e-9)
    idx = np.where(a > thr)[0]
    if idx.size == 0:
        return y[:0], ["silent"]
    pad = int(0.04 * sr)
    y = y[max(idx[0] - pad, 0): min(idx[-1] + pad, y.size)]
    if a.max() >= 0.999:
        flags.append("source_clipped")
    rms = np.sqrt(np.mean(y ** 2))
    y = y * (10 ** (rms_db / 20) / max(rms, 1e-9))
    peak = np.abs(y).max()
    lim = 10 ** (-1 / 20)
    if peak > lim:
        y = y * (lim / peak)
    fade = min(int(0.008 * sr), y.size // 4)
    if fade > 0:
        y[:fade] *= np.linspace(0, 1, fade)
        y[-fade:] *= np.linspace(1, 0, fade)
    return y, flags


def envelope(y, sr):
    hop = sr // 20
    n = max(1, y.size // hop)
    e = np.array([np.sqrt(np.mean(y[i * hop:(i + 1) * hop] ** 2)) for i in range(n)])
    if e.max() > 0:
        e = e / e.max()
    return "".join(str(int(round(v * 9))) for v in e)


def load_lines():
    lines = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data/dialogue/crew/*.json"))):
        lines += json.load(open(f, encoding="utf-8"))["lines"]
    return lines


def main():
    args = sys.argv[1:]
    only = [args[i + 1] for i, a in enumerate(args) if a == "--only"]
    check = "--check" in args
    man = json.load(open(MANIFEST, encoding="utf-8")) if os.path.exists(MANIFEST) else {"mappings": {}}
    maps = man.get("mappings", {})
    want = {}
    for ln in load_lines():
        d = delivery_for(ln)
        for p in profiles_for(ln):
            want["%s/%s" % (p, ln["id"])] = (ln, p, d)
    if only:
        want = {k: v for k, v in want.items() if k.split("/", 1)[1] in only}
    made = skipped = flagged = 0
    for key, (ln, p, d) in sorted(want.items()):
        text = spoken_text(ln["text"])
        st = settings(p, d)
        ck = cache_key(text, st)
        rel = "audio/voice/%s/%s.ogg" % (p, ln["id"])
        out = os.path.join(ROOT, rel)
        old = maps.get(key, {})
        if old.get("cache_key") == ck and os.path.exists(out):
            skipped += 1
            continue
        if check:
            continue
        if PROFILES["generator"] == "flite":
            y, sr = render_flite(text, st)
            y = clean_speech(y, sr)
        else:
            y, sr = render(text, st)
        y, flags = process(y, sr, st["rms_db"])
        # Game asset: 16 kHz mono speech (ample for spatial voice), Vorbis.
        if sr != 16000 and y.size:
            from scipy.signal import resample_poly
            g = np.gcd(16000, sr)
            y = resample_poly(y, 16000 // g, sr // g)
            sr = 16000
            pk = np.abs(y).max()
            if pk > 10 ** (-1 / 20):
                y = y * (10 ** (-1 / 20) / pk)
        dur = y.size / sr if sr else 0.0
        expect = 0.35 + len(text) * 0.055 * (175.0 / st["speed"] if "speed" in st else float(st.get("stretch", 1.0)))
        if dur < 0.35:
            flags.append("too_short")
        if dur > expect * 2.6 + 1.0:
            flags.append("too_long")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sf.write(out, y.astype(np.float32), sr, format="OGG", subtype="VORBIS", compression_level=0.75)
        content = hashlib.sha1(open(out, "rb").read()).hexdigest()
        maps[key] = {"line": ln["id"], "profile": p, "delivery": d, "text_sha1": hashlib.sha1(ln["text"].encode()).hexdigest(),
                     "spoken": text, "clip": rel, "duration": round(dur, 3), "codec": "vorbis", "channels": 1, "rate": sr,
                     "content_sha1": content, "cache_key": ck, "settings": st, "generator": PROFILES["generator"],
                     "generator_version": generator_version(), "preset": PROFILES["preset"],
                     "provenance": PROFILES.get("provenance", "original synthetic voice (eSpeak NG formant synthesis); no recorded or cloned person"),
                     "review": "flagged: " + ",".join(flags) if flags else "validated", "envelope": envelope(y, sr)}
        made += 1
        flagged += 1 if flags else 0
    # Drop mappings whose line or profile no longer exists (stale).
    full_want = {}
    for ln in load_lines():
        for p in profiles_for(ln):
            full_want["%s/%s" % (p, ln["id"])] = True
    stale = [k for k in maps if k not in full_want]
    if not only and not check:
        for k in stale:
            maps.pop(k, None)
    man = {"version": 1, "generator": PROFILES["generator"], "generator_version": generator_version(), "preset": PROFILES["preset"], "mappings": maps}
    if not check:
        json.dump(man, open(MANIFEST, "w", encoding="utf-8"), indent=0, sort_keys=True)
        idx = {k: [v["duration"], v["delivery"], v["envelope"]] for k, v in maps.items()}
        json.dump({"version": 1, "clips": idx}, open(INDEX, "w", encoding="utf-8"), separators=(",", ":"), sort_keys=True)
    lines = load_lines()
    print("AUTHORED_LINES %d REQUIRED_MAPPINGS %d IN_MANIFEST %d RENDERED %d CACHED %d FLAGGED_NEW %d STALE %d" % (
        len(lines), len(full_want), len(maps), made, skipped, flagged, len(stale)))


main()
