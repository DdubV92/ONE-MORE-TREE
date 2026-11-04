#!/usr/bin/env python3
"""Compiles the authored Phase 6 packet (docs/design/phase6_packet.md) into
data/terror/bank.json: 26 families x 50 events (T01-E001..T26-E050), 12
startle types per family (T01-J01..T26-J12) and the 36 Foreman hunt patterns
(F-H01..F-H36). Each entry keeps its exact source text and gets an executor
plan built from the runtime primitive vocabulary (scripts/terror/*). The plan
is derived from the text with deterministic keyword rules so a reviewer can
trace why an event uses the primitives it uses.

  python3 tools/compile_terror_bank.py
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "docs", "design", "phase6_packet.md")
OUT = os.path.join(HERE, "..", "data", "terror", "bank.json")

CONTEXTS_A = ["woods", "camp", "cabin", "camper", "cameras"]

# Primitive vocabulary implemented in scripts/terror/terror_executor.gd.
SOUND_KINDS = [
    ("bell", r"\bbell|chime|tone"),
    ("choir", r"choir|\bhum\b|humming|chord|vocal|\bsing|\bsong|chant"),
    ("knock", r"knock|tap|taps|tapping|rhythm|tick|ticks"),
    ("wing", r"wingbeat|wing|landing|feather|membrane|leathery"),
    ("chop", r"\baxe|chop|cutting|swing|work rhythm|felling"),
    ("water", r"drip|splash|wet|water|slosh|puddle|dripping"),
    ("bark", r"\bbark|howl|yip|growl|panting|pant\b|collar|jingle|whine"),
    ("scrape", r"scrape|scratch|drag|claw|fabric|scuff"),
    ("steps", r"footstep|footfall|steps\b|boots|walking|crunch|gravel"),
    ("breath", r"breath|intake|exhal"),
    ("creak", r"creak|groan|flex|settling"),
    ("call", r"call|three-note|cry|vocalization|whistle"),
    ("lantern", r"lantern|clink|metal|chain"),
]

FAMILY_DEFAULT = {
    1: {"p": "figure"}, 2: {"p": "voice"}, 3: {"p": "sound", "k": "wing"}, 4: {"p": "figure"},
    5: {"p": "figure"}, 6: {"p": "figure"}, 7: {"p": "shadow"}, 8: {"p": "sound", "k": "knock"},
    9: {"p": "figure"}, 10: {"p": "sound", "k": "bark"}, 11: {"p": "sound", "k": "water"},
    12: {"p": "lights"}, 13: {"p": "prop", "k": "stakes"}, 14: {"p": "figure"}, 15: {"p": "figure"},
    16: {"p": "warmth"}, 17: {"p": "sound", "k": "choir"}, 18: {"p": "sound", "k": "chop"},
    19: {"p": "sound", "k": "steps"}, 20: {"p": "figure"}, 21: {"p": "figure"}, 22: {"p": "sound", "k": "bell"},
    23: {"p": "sky"}, 24: {"p": "prop", "k": "thread"}, 25: {"p": "feed", "k": "lie"},
}


def plan_for(family, ctx, text, startle=False):
    t = text.lower()
    steps = []
    needs = set()
    vis = re.search(r"silhouette|figure|shape|outline|\bshe\b|\bher\b|surveyor|walker|logger|jacket|hat\b|sleeve|creature|body|pale|shoulder|\bform\b|person|someone|extra|horn|antler|wing edge|head|hand|face|lantern|light|procession|thread|stars|sky|dog\b|tail|eyes|points", t)
    if family == 26:
        return {"steps": [{"p": "rescue_beat"}], "needs": ["dog_rescue_active"], "intensity": 3 if re.search(r"jumpscare|bolts|roar", t) else 1, "visual": True}
    sound = None
    for kind, rx in SOUND_KINDS:
        if re.search(rx, t):
            sound = kind
            break
    if re.search(r"voice|name|says|spoken|greeting|laugh|murmur|whisper|phrase|plea|syllable|sentence|request|farewell|answer|repeats", t):
        steps.append({"p": "voice"})
    if sound:
        steps.append({"p": "sound", "k": sound})
    if re.search(r"shadow", t):
        steps.append({"p": "shadow"})
    elif vis and family not in (2, 8, 16, 17, 19, 22):
        steps.append({"p": "figure"})
    if family == 12 or re.search(r"lantern|lamp-like|lights? (in|between|move)", t):
        steps.append({"p": "lights"})
    if family == 16 or re.search(r"warmth|colder|cooler|color drains|dims?|grading|chill", t):
        steps.append({"p": "warmth"})
    if family == 23 or re.search(r"stars|starless|patch of sky|sky", t):
        steps.append({"p": "sky"})
    if family == 24 or re.search(r"thread|ribbon|string|cord", t):
        steps.append({"p": "prop", "k": "thread"})
    if re.search(r"footprint|prints|tracks", t):
        steps.append({"p": "prop", "k": "prints"})
    if ctx == "cameras" or family in (15, 25) or re.search(r"\bfeed|tile|camera|lens|focused|quad", t):
        steps.append({"p": "feed", "k": "lie" if family == 25 else "watch"})
    if re.search(r"\bdog\b", t) and family not in (10, 26):
        steps.append({"p": "dog_react"})
        needs.add("dog")
    if family == 10:
        steps.append({"p": "sound", "k": "bark"})
    if re.search(r"worker|crew|skeptic|everyone|sleeping person|occupied beds|headcount|companion", t):
        steps.append({"p": "witness"})
        needs.add("workers")
    if re.search(r"\btruck|headlight|\bcab\b|cab's|braking|\broad\b|\breverse", t):
        needs.add("truck")
    if re.search(r"window|glass|pane|curtain|blind", t):
        needs.add("window")
    if re.search(r"pond|river|shore|water|dock|lake|bank", t) or family == 11:
        needs.add("water")
    # Every event presents at least one real sensory cue of its family.
    if not any(st["p"] in ("sound", "voice", "figure", "shadow", "lights", "warmth", "sky", "prop", "feed") for st in steps):
        steps.insert(0, FAMILY_DEFAULT.get(family, {"p": "sound", "k": "creak"}))
    if startle:
        steps.append({"p": "peak"})
    # de-duplicate while keeping order
    seen, uniq = set(), []
    for s in steps:
        key = (s["p"], s.get("k"))
        if key not in seen:
            seen.add(key)
            uniq.append(s)
    inten = 1
    if re.search(r"close|closer|beside|directly|near|nearest", t):
        inten = 2
    if startle or re.search(r"rare|sudden|fast|rush|lunge|abrupt|startle|snaps|sharp", t):
        inten = 3
    return {"steps": uniq, "needs": sorted(needs), "intensity": inten, "visual": any(s["p"] in ("figure", "shadow", "lights", "sky", "prop", "warmth") for s in uniq)}


def main():
    src = open(SRC, encoding="utf-8").read().splitlines()
    a0 = next(i for i, l in enumerate(src) if l.startswith("# APPENDIX A"))
    b0 = next(i for i, l in enumerate(src) if l.startswith("# APPENDIX B"))
    c0 = next(i for i, l in enumerate(src) if l.startswith("# APPENDIX C"))
    families = {}
    events = []
    startles = []

    def parse_block(lines, part):
        fam = None
        ctx_i = -1
        for l in lines:
            m = re.match(r"^### (\d\d)\. (.+)$", l)
            if m:
                fam = int(m.group(1))
                if fam not in families:
                    families[fam] = {"id": "T%02d" % fam, "name": m.group(2).strip(), "identity": "", "constraint": ""}
                ctx_i = -1
                continue
            if fam is None:
                continue
            m = re.match(r"^\*\*Identity:\*\* (.+)$", l)
            if m:
                families[fam]["identity"] = m.group(1).strip()
                continue
            m = re.match(r"^\*\*Eligibility and constraint:\*\* (.+)$", l)
            if m:
                families[fam]["constraint"] = m.group(1).strip()
                continue
            if re.match(r"^\*\*.*(variations|events \d).*\*\*$", l):
                ctx_i += 1
                block = l.strip("*")
                continue
            m = re.match(r"^(\d+)\. (.+)$", l)
            if m and ctx_i >= 0:
                n = int(m.group(1))
                ctx = CONTEXTS_A[ctx_i]
                text = m.group(2).strip()
                e = {"id": "T%02d-E%03d" % (fam, n), "family": fam, "n": n, "context": ctx, "block": block, "text": text, "source": part}
                e.update(plan_for(fam, ctx, text))
                events.append(e)
                continue
            m = re.match(r"^- \*\*J(\d\d):\*\* (.+)$", l)
            if m:
                j = int(m.group(1))
                text = m.group(2).strip()
                s = {"id": "T%02d-J%02d" % (fam, j), "family": fam, "n": j, "text": text, "source": part}
                ctx = "woods"
                tl = text.lower()
                if re.search(r"window|curtain|cabin|camper|door|wall|bed", tl):
                    ctx = "interior"
                elif re.search(r"lens|feed|camera|tile|microphone", tl):
                    ctx = "cameras"
                elif re.search(r"fence|camp|gate|lamp", tl):
                    ctx = "camp"
                s["context"] = ctx
                s.update(plan_for(fam, ctx, text, startle=True))
                startles.append(s)

    parse_block(src[a0:b0], "A")
    parse_block(src[b0:c0], "B")

    # Appendix C: 12 close-encounter patterns + 24 additional sequences.
    foreman = []
    c = src[c0:]
    sec = None
    for l in c:
        if l.startswith("### Twelve Foreman"):
            sec = "close"
            continue
        if l.startswith("### Twenty-four additional"):
            sec = "extra"
            continue
        if l.startswith("### ") or l.startswith("#### "):
            if sec in ("close", "extra") and not l.startswith("### Twelve") and not l.startswith("### Twenty"):
                sec = None if not l.startswith("####") else sec
        m = re.match(r"^(\d+)\. (.+)$", l)
        if m and sec in ("close", "extra"):
            n = int(m.group(1)) + (0 if sec == "close" else 12)
            text = m.group(2).strip()
            name = ""
            mm = re.match(r"^\*\*(.+?):\*\* (.+)$", text)
            if mm:
                name, text = mm.group(1), mm.group(2)
            foreman.append({"id": "F-H%02d" % n, "n": n, "group": sec, "name": name, "text": text})
    foreman.sort(key=lambda f: f["n"])

    errs = []
    if len(families) != 26: errs.append("families %d" % len(families))
    if len(events) != 1300: errs.append("events %d" % len(events))
    if len(startles) != 312: errs.append("startles %d" % len(startles))
    if len(foreman) != 36: errs.append("foreman %d" % len(foreman))
    ids = [e["id"] for e in events] + [s["id"] for s in startles] + [f["id"] for f in foreman]
    if len(ids) != len(set(ids)): errs.append("duplicate ids")
    if errs:
        print("BANK ERRORS:", errs)
        sys.exit(1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out = {"version": 1, "source": "docs/design/phase6_packet.md", "families": [families[k] for k in sorted(families)], "events": events, "startles": startles, "foreman": foreman}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
    from collections import Counter
    pc = Counter(s["p"] for e in events for s in e["steps"])
    print("bank: %d families, %d events, %d startles, %d foreman patterns" % (len(families), len(events), len(startles), len(foreman)))
    print("primitive use:", dict(pc))

main()
