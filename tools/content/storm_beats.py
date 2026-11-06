#!/usr/bin/env python3
"""Phase 23 (pack Phase 21 section 4): the authored storm encounter catalog.
Writes data/terror/storm_beats.json. Every beat is a variant or presentation
of an EXISTING Terror family (data/terror/bank.json) and says how it relates:
  authored_variant  new staging written for the storm, family identity kept
  reused_event      an existing bank event re-presented by the storm
  natural_outcome   produced by ordinary systems (recorder, feed) from what
                    really happened in a storm
Fields: id, title, family, executor, kind, reuse_event, profiles, phases,
min_lightning, rain (min, max), gust_min, viewer, location, evidence, setup_s,
cancel, outcome, intensity, weight, per_visit, per_campaign.
"""
import json, os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
bank = json.load(open(os.path.join(ROOT, "data", "terror", "bank.json")))

def first_event(family, ctx, prim):
    for e in bank["events"]:
        if int(e["family"]) == family and e["context"] == ctx and any(s["p"] == prim for s in e["steps"]):
            return e["id"]
    raise SystemExit("no event for family %d %s %s" % (family, ctx, prim))

STORMY = ["thunderstorm", "severe_coastal"]
WET = ["steady_rain", "squall", "thunderstorm", "severe_coastal"]

BEATS = [
    dict(id="sb01", title="The borrowed shadow", family=7, executor="borrowed_shadow", kind="authored_variant",
         profiles=STORMY, phases=["build", "peak"], min_lightning=0.4, viewer="inside_camper", location="camper window (exterior)",
         evidence=["player inside the camper", "an exterior flash source beyond a window"], setup_s=6,
         cancel=["player leaves the camper", "no strike within 40 s"], outcome="a human-shaped shadow crosses the window on one flash; the next flash shows the empty patch",
         intensity=1, weight=1.0, per_visit=1, per_campaign=2),
    dict(id="sb02", title="Thunder Walker", family=5, executor="thunder_walker", kind="authored_variant",
         profiles=STORMY, phases=["build", "peak"], min_lightning=0.5, viewer="either", location="treeline, stump corridor, fence corner or shoreline break",
         evidence=["grounded, reachable waypoints", "line of sight from the player or a shown camera", "strikes ahead (setup time)"], setup_s=6,
         cancel=["route becomes invalid", "storm runs out of thunder", "director reservation lost"], outcome="revealed at successive waypoints; moves only inside thunder masking windows; withdraws unseen",
         intensity=2, weight=1.4, per_visit=1, per_campaign=3),
    dict(id="sb03", title="Between the trunks", family=1, executor="between_trunks", kind="reused_event", reuse=(1, "woods", "figure"),
         profiles=STORMY + ["squall"], phases=["approach", "onset", "build", "peak"], min_lightning=0.1, viewer="player", location="two trunks 30-60 m out (stump or rock on cleared land)",
         evidence=["a trunk pair or stump/rock visible from the player", "a low (mid/far) flash"], setup_s=4,
         cancel=["no valid pair", "player closes within 15 m"], outcome="already standing there at the flash; retreats behind terrain while unseen",
         intensity=1, weight=1.0, per_visit=1, per_campaign=3),
    dict(id="sb04", title="Fence-step", family=13, executor="fence_step", kind="reused_event", reuse=(13, "camp", "sound"),
         profiles=STORMY, phases=["build", "peak"], min_lightning=0.5, viewer="player", location="outside the camp fence",
         evidence=["player inside or near the fence", "a heavy roll that masks steps at the player"], setup_s=3,
         cancel=["no masking window at the player"], outcome="steps along the fence covered by the roll; one final contact exposed in the lull at the real endpoint",
         intensity=1, weight=1.0, per_visit=1, per_campaign=3),
    dict(id="sb05", title="The porch count", family=8, executor="porch_count", kind="authored_variant",
         profiles=WET, phases=["peak", "recovery"], min_lightning=0.0, rain=[0.35, 1.0], viewer="near_camper", location="camper porch rail",
         evidence=["player within 14 m of the camper porch", "drips audible (rain)"], setup_s=8,
         cancel=["player leaves", "rain stops"], outcome="near-regular drips; one distinct tap from the exterior rail after a worker stops talking (or a lull); fixed in place",
         intensity=1, weight=0.9, per_visit=1, per_campaign=2),
    dict(id="sb06", title="The wrong wake", family=11, executor="wrong_wake", kind="authored_variant",
         profiles=["squall", "thunderstorm", "severe_coastal"], phases=["build", "peak", "recovery"], min_lightning=0.0, viewer="camera", location="shallow water off the beach, seen by a shore camera",
         evidence=["a shown camera with shallow water in view", "a valid shallow route (0.3-1.5 m)"], setup_s=5,
         cancel=["no shore camera shown", "route leaves shallow water"], outcome="a moving break in the foam along a shallow route on the feed; never the survey ship or the rescue vessel",
         intensity=1, weight=0.8, per_visit=1, per_campaign=2),
    dict(id="sb07", title="Two windows", family=7, executor="two_windows", kind="reused_event", reuse=(7, "camper", "figure"),
         profiles=STORMY, phases=["build", "peak"], min_lightning=0.5, viewer="inside_camper", location="outside the camper's right-hand window",
         evidence=["player inside the camper", "valid ground outside the right window"], setup_s=6,
         cancel=["player leaves the camper"], outcome="a shape caught through the right window by a flash; a second angle through the other window only where geometry supports it",
         intensity=2, weight=0.8, per_visit=1, per_campaign=2),
    dict(id="sb08", title="Still in the gust", family=20, executor="still_in_gust", kind="authored_variant",
         profiles=["squall", "thunderstorm", "severe_coastal"], phases=["build", "peak"], min_lightning=0.0, gust_min=0.55, viewer="player", location="treeline 20-45 m",
         evidence=["gusts bending the trees", "line of sight from the player"], setup_s=4,
         cancel=["gusts drop", "route out invalid"], outcome="a motionless silhouette among bending branches; leaves along a supported path during a later roll",
         intensity=1, weight=1.0, per_visit=1, per_campaign=3),
    dict(id="sb09", title="Camera desync rumor", family=25, executor="feed_rumor", kind="natural_outcome",
         profiles=STORMY, phases=["any"], min_lightning=0.0, viewer="none", location="the fictional internet (a night-shift camera thread)",
         evidence=["generic post: any stormy night", "local claim: only after a real camera-seen storm encounter at this camp"], setup_s=0,
         cancel=["already posted this campaign"], outcome="a thread about shapes that arrive with the flash; the local reply only after a recorded/relayed camera event",
         intensity=1, weight=0.6, per_visit=1, per_campaign=1),
    dict(id="sb10", title="Unanswered call", family=2, executor="unanswered_call", kind="reused_event", reuse=(2, "woods", "voice"),
         profiles=WET, phases=["peak", "recovery"], min_lightning=0.0, viewer="either", location="treeline 30-60 m from people",
         evidence=["a lull between rolls (masking low)", "a plausible exterior spot"], setup_s=4,
         cancel=["no lull within 30 s"], outcome="a voice between rolls; a worker who actually heard it may comment without naming the speaker",
         intensity=1, weight=1.0, per_visit=1, per_campaign=3),
    dict(id="sb11", title="The missed flash", family=15, executor="missed_flash", kind="natural_outcome",
         profiles=STORMY, phases=["any"], min_lightning=0.0, viewer="camera", location="a camp camera, overnight",
         evidence=["a strike scheduled in the part of the night you slept through", "a camera with a valid treeline view"], setup_s=0,
         cancel=["another recording already took that night"], outcome="a short recording: one flash, one ambiguous silhouette; morning review in Recordings with the strike's identity",
         intensity=1, weight=1.0, per_visit=1, per_campaign=3),
    dict(id="sb12", title="After the rain", family=6, executor="after_the_rain", kind="authored_variant",
         profiles=WET, phases=["recovery"], min_lightning=0.0, rain=[0.0, 0.35], viewer="player", location="edge of a clearing 25-45 m",
         evidence=["rain softening (recovery)", "ordinary ambience returning"], setup_s=4,
         cancel=["rain returns", "no valid clearing edge"], outcome="one exposed step or movement at the clearing edge breaks the returning ambience; a quiet withdrawal",
         intensity=1, weight=1.0, per_visit=1, per_campaign=3),
]

for b in BEATS:
    if "reuse" in b:
        fam, ctx, prim = b.pop("reuse")
        b["reuse_event"] = first_event(fam, ctx, prim)
    else:
        b["reuse_event"] = ""
    b.setdefault("rain", [0.0, 1.0])
    b.setdefault("gust_min", 0.0)
    b["family_name"] = next(f["name"] for f in bank["families"] if int(f["id"][1:]) == b["family"])

out = dict(version=1, generator="tools/content/storm_beats.py", beats=BEATS)
with open(os.path.join(ROOT, "data", "terror", "storm_beats.json"), "w") as f:
    json.dump(out, f, indent=1)
print("wrote", len(BEATS), "beats:", {k: sum(1 for b in BEATS if b["kind"] == k) for k in ["authored_variant", "reused_event", "natural_outcome"]})
