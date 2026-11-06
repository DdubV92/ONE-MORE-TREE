#!/usr/bin/env python3
"""Phase 24 soundscape audit, step 2: adds each file's RMS (dBFS) to the
levels from tools/audio/ambience_audit.gd and sums the layers per route
point, so 'what is loud' is measured rather than guessed.
Usage: python3 tools/audio/ambience_rms.py audit.json [report.md]"""
import json, sys, os, glob
import numpy as np, soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_cache = {}

def rms_dbfs(name):
    if name in _cache:
        return _cache[name]
    hits = glob.glob(os.path.join(ROOT, "audio", "**", name), recursive=True)
    val = None
    if hits:
        x, sr = sf.read(hits[0], always_2d=True)
        x = x.mean(axis=1)
        val = 20 * np.log10(max(np.sqrt(np.mean(x * x)), 1e-9))
    _cache[name] = val
    return val

def main():
    data = json.load(open(sys.argv[1]))
    out = []
    for point, rows in data.items():
        if point.startswith("_"):
            continue
        out.append(f"\n### {point}\n")
        out.append("| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |")
        out.append("|---|---|---|---|---|---|---|---|")
        total = 0.0
        layers = []
        for r in rows:
            rm = rms_dbfs(r["file"]) if r["file"] else None
            ear = r["ear_db"] + (rm if rm is not None else -20.0)
            layers.append((ear, r, rm))
            total += 10 ** (ear / 10)
        layers.sort(key=lambda t: -t[0])
        for ear, r, rm in layers:
            out.append(f"| {r.get('event', r['node'])} | {r['file']} | {r['bus']} | {r.get('dist', '-')} | {r['vol_db']} | {r.get('att_db', '-')} | {'?' if rm is None else round(rm, 1)} | {round(ear, 1)} |")
        out.append(f"\n**Sum of layers: {round(10 * np.log10(max(total, 1e-12)), 1)} dBFS**")
    text = "\n".join(out)
    if len(sys.argv) > 2:
        open(sys.argv[2], "w").write(text)
    print(text)

main()
