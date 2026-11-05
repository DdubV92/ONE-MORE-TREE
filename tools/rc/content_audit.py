"""Phase 20: release-candidate content audit. Counts every required catalog
from the actual data files and checks that each reference resolves.

  python3 tools/rc/content_audit.py            # prints JSON
  python3 tools/rc/content_audit.py --md       # Markdown table

Counting rules (docs/PHASE20_RC_REPORT.md):
  crew lines        unique authored line ids in data/dialogue/crew (incl. offshore)
  internet units    unique unit ids in data/feed (unvoiced)
  accounts          entries in data/feed/accounts.json
  voice             required line/profile mappings (tools/voice), clips on disk,
                    index entries, validated vs flagged
  terror            data/terror/bank.json events / startles / foreman patterns
                    (families counted separately; no wrapper inflation)
  computer-linked   cl01..cl12 hooks referenced by feed units
  recordings        data/terror/recordings.json scenarios (distinct beats)
  interruptions     data/terror/sleep_interruptions.json sequences
  offshore          offshore category lines (Phase 19 addendum)
  sounds            audio/lib/manifest.json sources with existing files
"""
import glob, json, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def j(p):
    return json.load(open(os.path.join(ROOT, p), encoding="utf-8"))


def main():
    out = {}
    # Crew bank
    lines = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data/dialogue/crew/*.json"))):
        lines += json.load(open(f, encoding="utf-8"))["lines"]
    ids = {l["id"] for l in lines}
    cats = {}
    for l in lines:
        cats[l["cat"]] = cats.get(l["cat"], 0) + 1
    bad_resp = [l["id"] for l in lines for r in l.get("resp", []) if r not in ids]
    out["crew_lines"] = {"count": len(ids), "required": 1200, "by_category": cats, "offshore": cats.get("offshore", 0), "missing_responses": len(bad_resp)}
    # Internet
    units = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data/feed/days*.json"))):
        d = json.load(open(f, encoding="utf-8"))
        units += d["units"] if isinstance(d, dict) and "units" in d else d
    uid = {u["id"] for u in units}
    acc = j("data/feed/accounts.json")
    accounts = acc["accounts"] if isinstance(acc, dict) and "accounts" in acc else acc
    hooks = sorted({h for u in units for h in re.findall(r"\bcl\d\d\b", json.dumps(u))})
    out["internet"] = {"units": len(uid), "required": 5500, "accounts": len(accounts), "accounts_required": 80, "voiced": 0,
                       "computer_linked_hooks": hooks, "computer_linked_count": len(hooks), "computer_linked_required": 12}
    # Voices
    man = j("data/voice/manifest.json")["mappings"]
    idx = j("data/voice/index.json")["clips"]
    on_disk = sum(1 for k, v in man.items() if os.path.exists(os.path.join(ROOT, v["clip"])))
    imported = sum(1 for k, v in man.items() if os.path.exists(os.path.join(ROOT, v["clip"] + ".import")))
    req = subprocess.run([sys.executable, os.path.join(ROOT, "tools/voice/build_voices.py"), "--check"], capture_output=True, text=True).stdout.strip()
    m = re.search(r"REQUIRED_MAPPINGS (\d+)", req)
    flagged = sum(1 for v in man.values() if v["review"] != "validated")
    deliveries = {}
    for v in man.values():
        deliveries[v["delivery"]] = deliveries.get(v["delivery"], 0) + 1
    out["voice"] = {"required_mappings": int(m.group(1)) if m else None, "manifest": len(man), "clips_on_disk": on_disk, "imported": imported,
                    "index": len(idx), "validated": len(man) - flagged, "flagged": flagged, "by_delivery": deliveries, "auditioned_by_ear": 0,
                    "generator": "eSpeak NG (offline, original synthetic voices)"}
    # Terror bank
    b = j("data/terror/bank.json")
    out["terror"] = {"families": len(b["families"]), "events": len(b["events"]), "events_required": 1300, "startles": len(b["startles"]),
                     "startles_required": 312, "foreman_patterns": len(b["foreman"]), "foreman_required": 36,
                     "unique_event_ids": len({e["id"] for e in b["events"]}), "unique_startle_ids": len({s["id"] for s in b["startles"]})}
    rec = j("data/terror/recordings.json")["scenarios"]
    out["recordings"] = {"scenarios": len(rec), "required": 36, "distinct_beats": len({r["beat"] for r in rec}),
                         "cleared_alternatives": sum(1 for r in rec if r.get("cleared_alt")), "cameras": sorted({c for r in rec for c in r["cameras"]})}
    si = j("data/terror/sleep_interruptions.json")["sequences"]
    out["sleep_interruptions"] = {"sequences": len(si), "required": 24, "major": sum(1 for q in si if q["major"]),
                                  "max_gain_db": max(s[3] for q in si for s in q["steps"])}
    # Sound library
    lib = j("audio/lib/manifest.json")
    out["sounds"] = {"sources": len(lib), "files_present": sum(1 for v in lib.values() if os.path.exists(os.path.join(ROOT, v["file"].replace("res://", "")))),
                     "recordings_used": sum(1 for v in lib.values() if v.get("recording"))}
    # Every referenced sound event exists in the bank
    bank_src = open(os.path.join(ROOT, "scripts/audio/sound_bank.gd"), encoding="utf-8").read()
    events = set(re.findall(r'^\s*"([a-z]+\.[a-z0-9_.]+)": \{', bank_src, re.M))
    refs = {a[1] for r in rec for a in r["audio"]} | {s[1] for q in si for s in q["steps"]}
    out["references"] = {"sound_events_referenced": len(refs), "missing": sorted(refs - events)}
    prov = open(os.path.join(ROOT, "docs/ASSET_PROVENANCE.md"), encoding="utf-8").read()
    out["provenance_doc_rows"] = prov.count("\n|") - 2
    passes = (out["crew_lines"]["count"] >= 1200 and out["internet"]["units"] >= 5500 and out["internet"]["accounts"] >= 80
              and out["internet"]["computer_linked_count"] >= 12 and out["voice"]["clips_on_disk"] == out["voice"]["required_mappings"]
              and out["terror"]["events"] >= 1300 and out["terror"]["startles"] >= 312 and out["terror"]["foreman_patterns"] >= 36
              and out["recordings"]["scenarios"] >= 36 and out["sleep_interruptions"]["sequences"] >= 24 and out["crew_lines"]["offshore"] == 120
              and not out["references"]["missing"] and out["sounds"]["files_present"] == out["sounds"]["sources"])
    out["verdict"] = "pass" if passes else "fail"
    if "--md" in sys.argv:
        print("| Catalog | Count | Required |\n|---|---:|---:|")
        print("| Crew lines (authored) | %d | 1,200 |" % out["crew_lines"]["count"])
        print("| Offshore lines (Phase 19 addendum) | %d | 120 |" % out["crew_lines"]["offshore"])
        print("| Internet units (unvoiced) | %d | 5,500 |" % out["internet"]["units"])
        print("| Recurring accounts | %d | 80 |" % out["internet"]["accounts"])
        print("| Computer-linked patterns | %d | 12 |" % out["internet"]["computer_linked_count"])
        print("| Voice mappings / clips / imported | %s / %d / %d | all |" % (out["voice"]["required_mappings"], out["voice"]["clips_on_disk"], out["voice"]["imported"]))
        print("| Terror events / startles / Foreman patterns | %d / %d / %d | 1,300 / 312 / 36 |" % (out["terror"]["events"], out["terror"]["startles"], out["terror"]["foreman_patterns"]))
        print("| Missed-night recording scenarios | %d | 36 |" % out["recordings"]["scenarios"])
        print("| Sleep interruption sequences | %d | 24 |" % out["sleep_interruptions"]["sequences"])
        print("| Original sound sources (files present) | %d (%d) | - |" % (out["sounds"]["sources"], out["sounds"]["files_present"]))
        print("\nVerdict: **%s**" % out["verdict"])
    else:
        print(json.dumps(out, indent=1))


main()
