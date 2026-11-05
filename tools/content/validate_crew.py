"""Validates the crew dialogue bank (data/dialogue/crew/*.json).

  python3 tools/content/validate_crew.py [file ...]   # default: all files
Prints counts per category and speaker, and every problem found: schema,
unknown predicates, duplicate ids, missing response targets, exact and
near-duplicate texts. Exit code 1 if any hard problem exists."""
import json, os, re, sys, glob, itertools

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATS = {"cutting": "cut", "hauling": "haul", "tools": "tool", "ethic": "eth", "weather": "wx", "pair": "pair",
        "group": "grp", "boss": "boss", "camp": "camp", "wages": "wage", "dusk": "dusk", "survival": "surv",
        "offshore": "sea"}
SPEAKERS = {"EMP-01", "EMP-02", "EMP-03", "EMP-04", "EMP-05", "any"}
TRAITS = {"timid", "hard_working", "stronger", "level_headed", "sociable", "skeptical", "observant", "reliable_driver"}
TO = {"pair", "group", "boss", "self"}
ASK = {"greet", "work", "blocker", "strange", "wages", "thanks", "chat", "ack", "refuse", "report"}
REP = {"often", "sometimes", "rare", "once"}
WHEN_FIXED = {"act:cut", "act:fell", "act:buck", "act:stump", "act:carry", "act:yard", "act:idle", "act:walk", "act:home",
              "act:rest", "act:ride", "act:hide", "phase:day", "phase:dusk", "phase:night", "mode:contract", "mode:hunt",
              "mode:rescue", "weather:rain", "weather:dry", "weather:wind", "weather:storm", "where:camp", "where:forest",
              "where:cabin", "where:shore", "tool:saw", "tool:axe", "tool:big_axe", "tool:none", "mood:calm", "mood:uneasy",
              "mood:shaken", "mood:refusing", "belief:low", "belief:high", "trust:low", "trust:high", "owed", "paid",
              "blocker:yard_full", "blocker:blocked", "blocker:no_task", "blocker:missing_tool", "blocker:waiting",
              "dog_near", "boss_tired"}
WHEN_NUM = re.compile(r"^(day>=|day<=|level>=|cleared>=|crew<=)\d+$")
NEEDS = {"saw:strange", "heard:strange", "know:praised", "know:levelup", "know:colleague_progress", "know:team_carry",
         "know:frustrated", "know:owed_wages", "know:felled_today", "know:delivered_today", "know:departed", "know:dead"}


def sea_vocab():
    """Phase 19: the sea: predicates the runtime actually implements, read
    from OffshoreSurvey.holds() / knows() (so the validator can't drift)."""
    src = open(os.path.join(ROOT, "scripts/offshore/offshore_survey.gd"), encoding="utf-8").read()
    h = src.split("func holds(", 1)[1].split("\nfunc ", 1)[0]
    k = src.split("func knows(", 1)[1].split("\nfunc ", 1)[0]
    pat = re.compile(r'^\t\t"(sea:[a-z_]+)":', re.M)
    return set(pat.findall(h)), set(pat.findall(k))


SEA_WHEN, SEA_NEEDS = sea_vocab()
TRIGGERS = {"sight", "slow", "rotor", "heli", "deck", "depart", "repeat", "later"}
KNOWLEDGE = {"firsthand_sight", "hearing", "visual_detail", "secondhand", "two_passes"}


def norm(t):
    return re.sub(r"[^a-z0-9 ]", "", t.lower().replace("{listener}", "")).split()


def load(files):
    lines = []
    errs = []
    for f in files:
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception as e:
            errs.append("%s: invalid JSON: %s" % (f, e))
            continue
        for ln in d.get("lines", []):
            ln["_file"] = os.path.basename(f)
            lines.append(ln)
    return lines, errs


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, "data/dialogue/crew/*.json")))
    lines, errs = load(files)
    ids = {}
    for ln in lines:
        i = ln.get("id", "")
        if i in ids:
            errs.append("duplicate id %s (%s, %s)" % (i, ids[i]["_file"], ln["_file"]))
        ids[i] = ln
    for ln in lines:
        i = ln.get("id", "?")
        c = ln.get("cat", "")
        if c not in CATS:
            errs.append("%s: bad cat %r" % (i, c))
        elif not i.startswith(CATS[c] + "."):
            errs.append("%s: id prefix must be %s." % (i, CATS[c]))
        sp = ln.get("speaker", "")
        if sp not in SPEAKERS and not (sp.startswith("trait:") and sp[6:] in TRAITS):
            errs.append("%s: bad speaker %r" % (i, sp))
        if ln.get("to") not in TO:
            errs.append("%s: bad to %r" % (i, ln.get("to")))
        if ln.get("to") == "boss" and ln.get("ask") not in ASK:
            errs.append("%s: boss line needs ask in %s" % (i, sorted(ASK)))
        if ln.get("rep", "sometimes") not in REP:
            errs.append("%s: bad rep" % i)
        for w in ln.get("when", []):
            if w not in WHEN_FIXED and not WHEN_NUM.match(w) and w not in SEA_WHEN:
                errs.append("%s: unknown when %r" % (i, w))
        for n in ln.get("needs", []):
            if n not in NEEDS and n not in SEA_NEEDS:
                errs.append("%s: unknown needs %r" % (i, n))
        if c == "offshore":
            if ln.get("trigger") not in TRIGGERS:
                errs.append("%s: bad trigger %r" % (i, ln.get("trigger")))
            if ln.get("knowledge") not in KNOWLEDGE:
                errs.append("%s: bad knowledge %r" % (i, ln.get("knowledge")))
            if not any(n.startswith("sea:") for n in ln.get("needs", [])):
                errs.append("%s: offshore line needs a sea: knowledge requirement" % i)
        t = ln.get("text", "")
        if not t or len(t.split()) < 2 or len(t.split()) > 60:
            errs.append("%s: text length %d words" % (i, len(t.split())))
        if re.search(r"\{(?!listener\})", t):
            errs.append("%s: only {listener} placeholder allowed" % i)
        for r in ln.get("resp", []):
            if r not in ids:
                errs.append("%s: response %s missing" % (i, r))
            elif ids[r].get("to") not in ("pair", "group"):
                errs.append("%s: response %s must be pair/group" % (i, r))
    # duplicates
    seen = {}
    dup = 0
    for ln in lines:
        k = " ".join(norm(ln.get("text", "")))
        if k in seen:
            errs.append("exact duplicate text: %s = %s" % (ln["id"], seen[k]))
            dup += 1
        seen[k] = ln["id"]
    near = []
    sh = {}
    for ln in lines:
        w = norm(ln.get("text", ""))
        g = set(zip(w, w[1:], w[2:])) if len(w) >= 3 else {tuple(w)}
        sh[ln["id"]] = g
    by_cat = {}
    for ln in lines:
        by_cat.setdefault(ln.get("cat"), []).append(ln["id"])
    for c, idl in by_cat.items():
        for a, b in itertools.combinations(idl, 2):
            A, B = sh[a], sh[b]
            if len(A) >= 4 and len(B) >= 4:
                j = len(A & B) / len(A | B)
                if j >= 0.6:
                    near.append((a, b, round(j, 2)))
    # counts
    cat_n = {}
    spk_n = {}
    for ln in lines:
        cat_n[ln.get("cat")] = cat_n.get(ln.get("cat"), 0) + 1
        spk_n[ln.get("speaker")] = spk_n.get(ln.get("speaker"), 0) + 1
    print("LINES", len(lines))
    print("BY_CATEGORY", json.dumps(dict(sorted(cat_n.items()))))
    print("BY_SPEAKER", json.dumps(dict(sorted(spk_n.items()))))
    print("NEAR_DUPLICATES", len(near))
    for n in near[:40]:
        print("  NEAR", n)
    print("ERRORS", len(errs))
    for e in errs[:80]:
        print("  ERR", e)
    sys.exit(1 if errs else 0)


main()
