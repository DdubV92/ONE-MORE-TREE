"""Validates the fictional internet bank (data/feed/*.json + accounts.json).

  python3 tools/content/validate_feed.py [batch.json ...]   # default: all
Checks schema, ids, authors, sites, thread/parent/quote/ref ordering,
branch/flag/hook syntax, text length, exact and near duplicates, and
prints counts per kind, per day and per batch. Exit 1 on hard errors."""
import json, os, re, sys, glob, itertools

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KINDS = {"mail": "ml", "news": "nw", "forum": "fo", "advisory": "ad", "archive": "ar"}
SITES = {"forum": {"soundboard", "lamphours", "lowband", "dellow", "harbour"},
         "news": {"courier", "soundfm", "weypost", "tradejournal"},
         "advisory": {"met", "ferry", "power", "council", "coast"},
         "archive": {"history", "fieldnotes", "courierarchive", "lowbandarchive"},
         "mail": {"mail"}}
SLOTS = {"day": 900, "dusk": 300, "night": 480}
SLOT_ORDER = {"day": 0, "dusk": 1, "night": 2}
FLAGS = {"wages_owed", "worker_left", "dog_rescued", "truck_owned", "saw_owned", "cleared25", "cleared50", "cleared75",
         "late_reader", "night_event", "hunt", "rescue"}
STATUS = {"ok", "edited", "retracted", "removed", "locked"}
HOOKS = {"cl%02d" % i for i in range(1, 13)}
ID_RE = re.compile(r"^(ml|nw|fo|ad|ar)\.(\d\d)\.[a-z0-9-]+\.\d\d+$")


def words(t):
    return re.sub(r"[^a-z0-9 ]", " ", t.lower()).split()


def key(u):
    return (int(u.get("day", 0)), SLOT_ORDER.get(u.get("slot"), 9), int(u.get("at", 0)))


def main():
    files = sys.argv[1:] or sorted(f for f in glob.glob(os.path.join(ROOT, "data/feed/*.json")) if not f.endswith("accounts.json"))
    errs = []
    acc_path = os.path.join(ROOT, "data/feed/accounts.json")
    accounts = {}
    try:
        for a in json.load(open(acc_path, encoding="utf-8"))["accounts"]:
            accounts[a["id"]] = a
    except Exception as e:
        errs.append("accounts.json: %s" % e)
    all_units = {}
    # Load every batch for cross-file references, but validate the requested ones.
    for f in sorted(glob.glob(os.path.join(ROOT, "data/feed/*.json"))):
        if f.endswith("accounts.json"):
            continue
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception as e:
            errs.append("%s: invalid JSON: %s" % (os.path.basename(f), e))
            continue
        for u in d.get("units", []):
            u["_file"] = os.path.basename(f)
            if u.get("id") in all_units:
                errs.append("duplicate id %s (%s, %s)" % (u.get("id"), all_units[u["id"]]["_file"], u["_file"]))
            all_units[u.get("id")] = u
    targets = [u for u in all_units.values() if any(os.path.basename(f) == u["_file"] for f in files)]
    threads_first = {}
    for u in sorted(all_units.values(), key=key):
        threads_first.setdefault((u.get("site"), u.get("thread")), u)
    for u in targets:
        i = u.get("id", "?")
        k = u.get("kind")
        if k not in KINDS:
            errs.append("%s: bad kind" % i)
            continue
        m = ID_RE.match(i)
        if not m or m.group(1) != KINDS[k]:
            errs.append("%s: id must be %s.<dd>.<slug>.<nn>" % (i, KINDS[k]))
        elif int(m.group(2)) != int(u.get("day", -1)):
            errs.append("%s: id day != day %s" % (i, u.get("day")))
        if u.get("site") not in SITES[k]:
            errs.append("%s: site %r not valid for %s" % (i, u.get("site"), k))
        if not u.get("thread"):
            errs.append("%s: missing thread" % i)
        a = u.get("author", "")
        if k in ("news", "advisory"):
            if a != u.get("site") and a not in accounts:
                errs.append("%s: author must be the site id or an account" % i)
        elif a not in accounts:
            errs.append("%s: unknown author %r" % (i, a))
        if k == "mail" and not u.get("to"):
            errs.append("%s: mail needs to" % i)
        d = u.get("day")
        if not isinstance(d, int) or d < 1 or d > 35:
            errs.append("%s: bad day" % i)
        s = u.get("slot")
        if s not in SLOTS:
            errs.append("%s: bad slot" % i)
        elif not isinstance(u.get("at"), int) or not 0 <= u["at"] < SLOTS[s]:
            errs.append("%s: at out of range for %s" % (i, s))
        if u.get("status", "ok") not in STATUS:
            errs.append("%s: bad status" % i)
        b = u.get("branch", "")
        if b:
            if b.startswith("mx:"):
                if not re.match(r"^mx:[a-z0-9-]+:[ab]$", b):
                    errs.append("%s: bad mx branch %s" % (i, b))
            elif b.startswith("if:") or b.startswith("unless:"):
                if b.split(":", 1)[1] not in FLAGS:
                    errs.append("%s: unknown flag %s" % (i, b))
            elif b != "fallback:cl01":
                errs.append("%s: bad branch %s" % (i, b))
        if u.get("hook") and u["hook"] not in HOOKS:
            errs.append("%s: bad hook" % i)
        t = u.get("text", "")
        n = len(words(t))
        if n < 12 or n > 160:
            errs.append("%s: text %d words (15-140)" % (i, n))
        if u.get("edit"):
            et = u["edit"].get("text", "")
            if len(words(et)) < 12:
                errs.append("%s: edit text too short" % i)
        first = threads_first.get((u.get("site"), u.get("thread")))
        if first is u and not u.get("title") and k != "advisory":
            errs.append("%s: first unit of thread %s needs a title" % (i, u.get("thread")))
        for fld in ("parent", "quote"):
            p = u.get(fld)
            if p:
                pu = all_units.get(p)
                if pu is None:
                    errs.append("%s: %s %s missing" % (i, fld, p))
                elif key(pu) > key(u):
                    errs.append("%s: %s %s is published later" % (i, fld, p))
                elif fld == "parent" and (pu.get("thread") != u.get("thread") or pu.get("site") != u.get("site")):
                    errs.append("%s: parent %s in another thread" % (i, p))
                elif pu.get("branch") and pu.get("branch") != u.get("branch"):
                    errs.append("%s: %s %s is on branch %s" % (i, fld, p, pu.get("branch")))
        for r in u.get("refs", []):
            ru = all_units.get(r)
            if ru is None:
                errs.append("%s: ref %s missing" % (i, r))
            elif key(ru) > key(u):
                errs.append("%s: ref %s is published later" % (i, r))
    # duplicates (within targets vs all)
    seen = {}
    for u in all_units.values():
        kx = " ".join(words(u.get("text", "")))
        if kx in seen and (u in targets or seen[kx] in targets):
            errs.append("exact duplicate: %s = %s" % (u["id"], seen[kx]["id"]))
        seen[kx] = u
    near = []
    sh = {}
    index = {}
    for u in all_units.values():
        w = words(u.get("text", ""))
        g = set(zip(w, w[1:], w[2:]))
        sh[u["id"]] = g
        for x in g:
            index.setdefault(x, []).append(u["id"])
    tset = set(u["id"] for u in targets)
    for a in tset:
        A = sh[a]
        if len(A) < 5:
            continue
        cnt = {}
        for x in A:
            lst = index[x]
            if len(lst) > 200:
                continue          # a stock phrase, not evidence of copying
            for b in lst:
                if b != a:
                    cnt[b] = cnt.get(b, 0) + 1
        for b, c in cnt.items():
            if b in tset and b < a:
                continue
            B = sh[b]
            if len(B) < 5 or c < 0.3 * min(len(A), len(B)):
                continue
            j = len(A & B) / len(A | B)
            if j >= 0.5:
                near.append((a, b, round(j, 2)))
    for a, b, j in near:
        errs.append("near duplicate %s ~ %s (%.2f)" % (a, b, j))
    # counts
    by_kind, by_day, by_file = {}, {}, {}
    for u in targets:
        by_kind[u.get("kind")] = by_kind.get(u.get("kind"), 0) + 1
        by_day[u.get("day")] = by_day.get(u.get("day"), 0) + 1
        by_file[u["_file"]] = by_file.get(u["_file"], 0) + 1
    hooks = sorted({u.get("hook") for u in all_units.values() if u.get("hook")})
    print("UNITS", len(targets), "(all files: %d)" % len(all_units))
    print("BY_KIND", json.dumps(dict(sorted(by_kind.items()))))
    print("BY_DAY", json.dumps({str(k): v for k, v in sorted(by_day.items(), key=lambda x: (x[0] or 0))}))
    print("BY_FILE", json.dumps(by_file))
    print("ACCOUNTS", len(accounts), "HOOKS", ",".join(hooks))
    print("ERRORS", len(errs))
    for e in errs[:100]:
        print("  ERR", e)
    sys.exit(1 if errs else 0)


main()
