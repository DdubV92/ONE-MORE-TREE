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
    var = p["variant"]
    if delivery == "whisper":
        var = d["variant_f"] if profile in PROFILES["female"] else d["variant"]
    return {"voice": p["voice"], "variant": var, "pitch": max(0, min(99, p["pitch"] + d["pitch"])),
            "speed": int(round(p["speed"] * d["speed"])),
            "gap": p["gap"], "amp": d["amp"], "rms_db": d["rms_db"]}


def cache_key(text, st):
    raw = json.dumps({"t": text.lower(), "s": st, "g": PROFILES["generator"], "v": espeak_version(), "p": PROFILES["preset"]}, sort_keys=True)
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
        expect = 0.35 + len(text) * 0.055 * (175.0 / st["speed"])
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
                     "generator_version": espeak_version(), "preset": PROFILES["preset"],
                     "provenance": "original synthetic voice (eSpeak NG formant synthesis); no recorded or cloned person",
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
    man = {"version": 1, "generator": PROFILES["generator"], "generator_version": espeak_version(), "preset": PROFILES["preset"], "mappings": maps}
    if not check:
        json.dump(man, open(MANIFEST, "w", encoding="utf-8"), indent=0, sort_keys=True)
        idx = {k: [v["duration"], v["delivery"], v["envelope"]] for k, v in maps.items()}
        json.dump({"version": 1, "clips": idx}, open(INDEX, "w", encoding="utf-8"), separators=(",", ":"), sort_keys=True)
    lines = load_lines()
    print("AUTHORED_LINES %d REQUIRED_MAPPINGS %d IN_MANIFEST %d RENDERED %d CACHED %d FLAGGED_NEW %d STALE %d" % (
        len(lines), len(full_want), len(maps), made, skipped, flagged, len(stale)))


main()
