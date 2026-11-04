"""QA for the generated library: level, silence, seam, near-duplicates."""
import json, os, sys
import numpy as np, soundfile as sf
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
man = json.load(open(os.path.join(ROOT, "audio/lib/manifest.json")))
feats, names, issues, stats = [], [], [], {}
for name, m in sorted(man.items()):
    y, sr = sf.read(os.path.join(ROOT, m["file"].replace("res://", "")))
    rms = float(np.sqrt(np.mean(y ** 2)))
    lead = int(np.argmax(np.abs(y) > 0.02)) / sr
    if not np.all(np.isfinite(y)) or rms < 0.01:
        issues.append((name, "silent/invalid rms %.4f" % rms))
    if not m["loop"] and lead > 0.25 and m["category"] != "horror":
        issues.append((name, "leading silence %.2fs" % lead))
    if m["loop"]:
        seam = abs(y[0] - y[-1])
        typical = float(np.percentile(np.abs(np.diff(y)), 99.5))
        if seam > max(0.2, typical * 1.5):
            issues.append((name, "loop seam jump %.2f" % seam))
    S = np.abs(np.fft.rfft(y[: sr * 2] * np.hanning(min(len(y), sr * 2)), 8192))
    bands = np.array([S[int(lo):max(int(hi), int(lo) + 1)].mean() for lo, hi in zip(np.geomspace(4, 4000, 33)[:-1], np.geomspace(4, 4000, 33)[1:])])
    f = np.log(bands + 1e-9)
    f = (f - f.mean()) / (f.std() + 1e-9)
    env = np.abs(y[: sr * 2])
    env = np.convolve(env, np.ones(320) / 320, "same")[::320]
    env = np.pad(env, (0, 200 - len(env)))[:200]
    e = (env - env.mean()) / (env.std() + 1e-9)
    feats.append(np.concatenate([f, e * 0.5]))
    names.append(name)
F = np.array(feats)
F /= np.linalg.norm(F, axis=1, keepdims=True)
sim = F @ F.T
dups = []
for i in range(len(names)):
    for j in range(i + 1, len(names)):
        if sim[i, j] > 0.985:
            dups.append((names[i], names[j], round(float(sim[i, j]), 4)))
print("sources", len(names), "issues", len(issues), "near-duplicate pairs", len(dups))
for x in issues: print("ISSUE", x)
for x in dups: print("DUP", x)
