#!/usr/bin/env python3
"""Phase 8 sensory coverage matrix for the ordinary Terror library.

For every authored event (1,300) and conditional startle (312) this lists the
family, context, the visual / audio / animation assets its executor steps
need, whether those assets exist in the repository, how to trigger it in
Preview, the result observed by the Phase 6 headless coverage run, and any
missing dependency. Run from the repository root:

    python3 tools/sensory_matrix.py

Writes docs/coverage/phase8_sensory_matrix.csv and .md. "Observed" means the
executor ran to completion in the headless coverage harness (no renderer);
it does not mean a person reviewed the picture or the sound.
"""
import csv, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bank = json.load(open(os.path.join(ROOT, "data/terror/bank.json")))
cov = json.load(open(os.path.join(ROOT, "docs/coverage/phase6_coverage.json")))["results"]
enc = open(os.path.join(ROOT, "scripts/terror/terror_encounter.gd")).read()

# Figure model per family (mirrors TerrorEncounter._figure_kind).
fig = {}
for m in re.finditer(r"^\t\t([\d, ]+): return \"(\w+)\"", enc[enc.index("func _figure_kind"):], re.M):
    for f in m.group(1).split(","):
        fig[int(f)] = m.group(2)
    if "return \"\"" in enc[enc.index("func _figure_kind"):m.end() + 40]:
        pass
sounds = {}
blk = enc[enc.index("const SOUNDS"):enc.index("const CAPTIONS")]
for k, v in re.findall(r'"(\w+)": \[([^\]]*)\]', blk):
    sounds[k] = re.findall(r'"(\w+)"', v)

def audio_exists(name):
    return os.path.exists(os.path.join(ROOT, "audio/generated", name + ".wav"))

# Families without a body: a figure beat uses the family's own visual.
FAMILY_VISUAL = {12: "lantern procession lights (figure beat)", 23: "starless sky patch (figure beat)", 16: "lost-warmth tint (figure beat)"}
ACTOR_ANIM = "TerrorActor present/hold/withdraw (cover-validated)"
STEP_ASSETS = {
    "shadow": ("figure silhouette scaled", ACTOR_ANIM),
    "prop": ("prop mesh (TerrorEncounter._prop)", "prop place/remove"),
    "lights": ("lantern procession lights", "procession drift"),
    "sky": ("sky patch quad", "fade"),
    "warmth": ("camp lamp warmth tint (cosmetic, not safety)", "lerp"),
    "feed": ("CameraWall.anomaly (freeze/static/label/phantom)", "feed effect"),
    "witness": ("worker perception stimulus", "worker fear/listen/talk_shaken clips"),
    "dog_react": ("dog hear(): look/ear attention", "dog alert/growl clips"),
    "voice": ("t_voice_0..3 + caption", "-"),
    "rescue_beat": ("dog-rescue quest beat", "dog rescue states"),
    "peak": ("peak presentation (stinger or breath at reduced intensity)", "actor withdraw"),
}

rows = []
def row_for(e, kind):
    steps = [s["p"] for s in e["steps"]]
    fam = int(e["family"])
    vis, aud, ani, missing = [], [], [], []
    for s in e["steps"]:
        p = s["p"]
        if p in ("figure", "shadow") or (p == "peak" and fam in fig):
            if fam in fig:
                vis.append("TerrorActor:" + fig[fam])
                ani.append(ACTOR_ANIM)
            elif fam in FAMILY_VISUAL:
                vis.append(FAMILY_VISUAL[fam])
            else:
                missing.append("no figure model for family T%02d (figure step renders nothing; other channels carry it)" % fam)
        if p == "sound":
            k = s.get("k", "creak")
            files = sounds.get(k, ["creak_wood_0"])
            aud.append("%s[%s]" % (k, "|".join(files)))
            for f in files:
                if not audio_exists(f):
                    missing.append("audio " + f)
        elif p in STEP_ASSETS and p not in ("figure",):
            a, an = STEP_ASSETS[p]
            (aud if p == "voice" else vis).append(a)
            if an != "-":
                ani.append(an)
        if p == "peak":
            for f in ("t_stinger", "t_breath"):
                if not audio_exists(f):
                    missing.append("audio " + f)
    if fam == 10 and not any(s["p"] == "sound" for s in e["steps"]):
        aud.append("bark[dog_bark_0|dog_bark_1|dog_whine_1] pitch 0.82")
    observed = cov.get(e["id"], "not run")
    state = "implemented" if not missing else "partial"
    state += "-observed" if observed in ("completed", "peak", "rescue_quest") else "-unrun" if observed == "not run" else "-" + observed
    trig = "Tour > Phase 6 > Next family event (steps to T%02d) / Phase 8 station 9; harness: tools/terror_coverage.gd" % fam
    rows.append({
        "id": e["id"], "type": kind, "family": "T%02d" % fam, "context": e.get("context", ""),
        "steps": "+".join(steps), "visual": "; ".join(dict.fromkeys(vis)) or "-",
        "audio": "; ".join(dict.fromkeys(aud)) or "-", "animation": "; ".join(dict.fromkeys(ani)) or "-",
        "state": state, "preview_trigger": trig, "observed_phase6": observed,
        "missing": "; ".join(dict.fromkeys(missing)) or "-",
    })

for e in bank["events"]:
    row_for(e, "event")
for e in bank["startles"]:
    row_for(e, "startle")

out_csv = os.path.join(ROOT, "docs/coverage/phase8_sensory_matrix.csv")
with open(out_csv, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)

from collections import Counter, defaultdict
st = Counter(r["state"] for r in rows)
per = defaultdict(Counter)
for r in rows:
    per[r["family"]][r["state"]] += 1
names = {"T%02d" % (i + 1): f["name"] for i, f in enumerate(bank["families"])}
lines = ["# Phase 8 sensory coverage matrix (ordinary Terrors)", "",
         "Generated by `python3 tools/sensory_matrix.py` from `data/terror/bank.json`, the executor in "
         "`scripts/terror/terror_encounter.gd` and the Phase 6 headless coverage run. Full per-event table: "
         "[phase8_sensory_matrix.csv](phase8_sensory_matrix.csv) (%d rows: %d events + %d startles)." % (len(rows), len(bank["events"]), len(bank["startles"])), "",
         "**What \"observed\" means:** the event's executor ran to completion in the headless harness "
         "(`tools/terror_coverage.gd`, no renderer). It is not a human review of picture or sound. "
         "Visual/audio review of representative events was done in lavapipe screenshots only.", "",
         "| State | Rows |", "|---|---|"]
for k, v in sorted(st.items()):
    lines.append("| %s | %d |" % (k, v))
lines += ["", "| Family | Name | Figure model | implemented-observed | partial-observed | other |", "|---|---|---|---|---|---|"]
for fam in sorted(per):
    c = per[fam]
    n = int(fam[1:])
    other = sum(v for k, v in c.items() if k not in ("implemented-observed", "partial-observed"))
    lines.append("| %s | %s | %s | %d | %d | %d |" % (fam, names.get(fam, ""), fig.get(n, "none (sound/feed/prop/lights only)"), c["implemented-observed"], c["partial-observed"], other))
lines += ["", "## Remaining gaps", "",
          "- T12, T23 and T16 have no body by design: a `figure` beat plays through the procession lights, the starless patch or the lost warmth.",
          "- T17, T19 and T22 are audio-first families: the few events whose text includes a `figure` beat show nothing extra for it (listed as partial); their sound, voice, feed and witness channels still run. A restrained visual for those beats is the remaining gap.",
          "- All sounds are original synthesized placeholders (see docs/ASSET_PROVENANCE.md); a family shares its sound vocabulary across its 50 events (different timing, placement and context, same sample set).",
          "- No event has a hand-animated performance: figures use the shared present/hold/withdraw controller with cover-validated withdrawal.",
          ""]
open(os.path.join(ROOT, "docs/coverage/phase8_sensory_matrix.md"), "w").write("\n".join(lines))
print("rows", len(rows), dict(st))
