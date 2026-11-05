"""Phase 20 (repairs the Phase 19 expansion gap): 36 authored missed-night
recording scenarios -> data/terror/recordings.json.

  python3 tools/content/night_recordings.py

Each scenario is a short harmless night incident captured by a real camp
camera while the boss sleeps (docs/PHASE20_NOTES.md). Coordinates are in
the CAMERA's view frame: x = metres to the right, z = metres ahead; the
runtime converts them to world points on the real terrain at capture time
and rejects the scenario if its prerequisites or sight lines fail.

Fields:
  cameras      candidate camera ids, first valid wins
  requires     prerequisite tokens (see NightRecorder.prereq_ok)
  hour         clock hour of the event (night), duration seconds
  actor        {kind: figure|dog|none, track: [[t, x, z], ...], hidden: [[t0, t1]...]}
  props        [{kind, ...}] visual reconstruction elements
  audio        [[t, event_id, x, z, y(, anchor)]]   (y = height above ground; optional anchor overrides the actor anchor)
  consequence  {kind: notice|marks|prop, text, mark}
  cooldown     nights before it may recur;  weight  selection weight
  beat         the distinct dramatic beat (editorial)
"""
import json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PERIM = ["CAM_04", "CAM_05", "CAM_06", "CAM_07"]
TRAIL = ["CAM_08", "CAM_09", "CAM_10"]

S = []


def sc(n, title, cameras, hour, dur, beat, actor=None, props=None, audio=None, requires=None, consequence=None, cooldown=8, weight=1.0, cleared_alt=False):
    S.append({"id": "rec%02d" % n, "n": n, "title": title, "cameras": cameras, "requires": requires or [], "hour": hour, "duration": dur,
              "actor": actor or {"kind": "none", "track": []}, "props": props or [], "audio": audio or [],
              "consequence": consequence or {"kind": "notice", "text": ""}, "cooldown": cooldown, "weight": weight,
              "cleared_alt": cleared_alt, "beat": beat})


# ---------------------------------------------------------------- seeds 1-12
# The gate is the real leaf at the west post of the forest entrance
# (CampLayout.GATE_*), seen along the north fence by the corner cameras.
sc(1, "One swing of the gate", ["CAM_04", "CAM_05"], 23.9, 8.0,
   "The gate swings once; the chain never goes slack.",
   props=[{"kind": "gate_swing", "anchor": "gate_hinge", "track": [[0.0, 0.0], [2.0, 0.0], [3.2, 0.35], [5.0, 0.0]]}],
   audio=[[2.1, "camp.gate.clank", 0.0, 0.0, 0.0, "gate"], [5.0, "camp.gate.clank", 0.0, 0.0, 0.0, "gate"]],
   consequence={"kind": "notice", "text": "The gate is latched the way you left it."})
sc(2, "Behind the cabin window", ["CAM_02"], 0.4, 9.0,
   "A worker-shaped silhouette crosses behind the sleeping cabin's window, never inside.",
   requires=["cabin_occupied"],
   actor={"kind": "figure", "track": [[0.0, -4.5, 0.0], [9.0, 4.5, 0.0]], "anchor": "cabin_front"},
   consequence={"kind": "notice", "text": "Everyone in the cabin slept through the night."})
sc(3, "Branches against the wind", TRAIL, 1.2, 10.0,
   "A trail camera records branches bending against the wind, then normal motion resumes.",
   requires=["trees_near"],
   props=[{"kind": "branches", "track": [[0.0, 0.0], [3.0, 1.0], [6.0, 1.0], [7.5, 0.0]], "against_wind": True}],
   audio=[[3.0, "terror.branch", 2.0, 12.0, 4.0]])
sc(4, "The dog at the door", ["CAM_01"], 2.1, 9.0,
   "Biscuit pauses at the camper door glass, then goes back to bed (seen through the door pane).",
   requires=["dog"],
   actor={"kind": "dog", "track": [[0.0, 0.6, -1.0], [2.0, 0.0, 0.0], [6.0, 0.0, 0.0], [8.5, 0.6, -1.0]], "anchor": "camper_door"},
   audio=[[2.2, "dog.tags", 0.0, 0.0, 0.5]],
   consequence={"kind": "notice", "text": "Biscuit was asleep in her bed when you woke."})
sc(5, "Something in the pane", ["CAM_02", "CAM_01"], 1.5, 7.0,
   "A pale reflection moves across an exterior pane with no matching figure in direct view (authored anomaly).",
   props=[{"kind": "reflection", "anchor": "facing_window", "track": [[0.0, -0.6], [4.0, 0.6]]}])
sc(6, "Stacking sounds at the pit", ["CAM_04", "CAM_05", "CAM_06", "CAM_07", "CAM_01", "CAM_02", "CAM_03"], 23.4, 8.0,
   "Burn-pit audio briefly sounds like timber being stacked; the yard count is unchanged.",
   audio=[[1.5, "log.drop.rack", 0.0, 0.0, 0.5], [3.2, "log.drop.rack", 0.5, 0.0, 0.5], [4.6, "tree.branch.snap", 0.0, 0.0, 0.4]], props=[{"kind": "pit_glow"}],
   requires=["pit_view"], consequence={"kind": "notice", "text": "The yard count matches yesterday's report."})
sc(7, "The long shadow", TRAIL, 3.0, 12.0,
   "A rock-camera shadow lengthens while cloud cover and lights stay otherwise coherent.",
   props=[{"kind": "shadow", "x": 0.0, "z": 9.0, "track": [[0.0, 1.0], [8.0, 6.0], [12.0, 6.0]]}])
sc(8, "A greeting at the gate", ["CAM_03"], 0.9, 6.0,
   "The gate microphone captures a quiet greeting from outside its frame.",
   audio=[[2.4, "night.call.far", -9.0, 6.0, 1.6]],
   consequence={"kind": "notice", "text": "Nobody was at the gate this morning."})
sc(9, "Three steps on the porch", ["CAM_01"], 1.8, 8.0,
   "An empty porch receives three discrete footstep sounds, each sourced to a recorded point.",
   actor={"kind": "none", "track": [], "anchor": "camper_door"},
   audio=[[1.0, "terror.step.wet", -1.2, 1.4, 0.0], [2.3, "terror.step.wet", -0.4, 1.0, 0.0], [3.5, "terror.step.wet", 0.4, 0.6, 0.0]],
   consequence={"kind": "marks", "mark": "wet_prints", "anchor": "camper_door", "text": "Three damp marks on the camper step dried by mid-morning."})
sc(10, "Behind the crest", TRAIL + ["CAM_03"], 2.6, 14.0,
   "A distant figure waits behind a terrain crest and leaves by a route the camera cannot see.",
   actor={"kind": "figure", "track": [[0.0, 3.0, 70.0], [8.0, 3.0, 70.0], [14.0, 12.0, 82.0]], "end_occluded": True, "search": True},
   requires=["crest"])
sc(11, "A knock in the quiet", PERIM, 3.4, 9.0,
   "A gap in the wind noise lets a far mechanical knock be heard.",
   requires=["wind"], props=[{"kind": "wind_gap", "track": [[0.0, 1.0], [2.0, 0.1], [6.0, 0.1], [7.5, 1.0]]}],
   audio=[[3.5, "terror.knock.metal", 25.0, 60.0, 1.0]])
sc(12, "The rack cover", ["CAM_05", "CAM_04"], 0.2, 8.0,
   "An exterior tool-rack cover lifts, revealing nothing changed underneath.",
   requires=["tool_view"], props=[{"kind": "rack_cover", "anchor": "tool_area", "track": [[0.0, 0.0], [2.5, 0.0], [3.5, 0.6], [6.0, 0.0]]}],
   audio=[[3.4, "door.creak", 0.0, 0.0, 1.0]],
   consequence={"kind": "notice", "text": "Nothing is missing from the tool rack."})
# ---------------------------------------------------------------- 13-36
sc(13, "The fence shivers", ["CAM_06", "CAM_07"], 1.1, 7.0,
   "The fence wire shivers along one run and a single post rattles with nothing touching it.",
   props=[{"kind": "fence_shiver", "x": -4.0, "z": 9.0, "track": [[0.0, 0.0], [2.0, 1.0], [4.0, 0.0]]}],
   audio=[[2.1, "camp.fence.rattle", -4.0, 9.0, 1.0]])
sc(14, "Glass at the cabin", ["CAM_02"], 2.9, 6.0,
   "Two knocks on the cabin window glass from just outside the frame; the sleepers do not stir.",
   requires=["cabin_occupied"], audio=[[1.5, "terror.knock.glass", 3.5, 28.0, 1.4], [3.0, "terror.knock.glass", 3.5, 28.0, 1.4]],
   consequence={"kind": "notice", "text": "The cabin windows are intact and latched."})
sc(15, "Standing at the treeline", ["CAM_03"], 0.6, 10.0,
   "A figure stands at the edge of the trail opening, then is gone between two frames.",
   actor={"kind": "figure", "track": [[0.0, 2.0, 26.0], [6.0, 2.0, 26.0]], "hidden": [[6.0, 10.0]]})
sc(16, "Tags with no dog", ["CAM_01"], 3.7, 6.0,
   "The dog's tags jingle by the camper door although the dog is curled in her bed.",
   requires=["dog"], audio=[[2.0, "dog.tags", 0.3, 0.4, 0.4]], actor={"kind": "none", "track": [], "anchor": "camper_door"},
   consequence={"kind": "notice", "text": "Biscuit's collar was on her, as always."})
sc(17, "Prints across the yard", ["CAM_04", "CAM_05"], 1.4, 12.0,
   "Wet prints appear one by one across the yard dirt with nobody making them.",
   props=[{"kind": "prints", "track": [[1.0, -3.0, 14.0], [2.2, -1.8, 13.5], [3.4, -0.6, 13.0], [4.6, 0.6, 12.5], [5.8, 1.8, 12.0], [7.0, 3.0, 11.5]]}],
   audio=[[1.0, "terror.step.wet", -3.0, 14.0, 0.0], [3.4, "terror.step.wet", -0.6, 13.0, 0.0], [5.8, "terror.step.wet", 1.8, 12.0, 0.0]],
   consequence={"kind": "marks", "mark": "wet_prints", "anchor": "yard", "text": "Dried prints near the yard, already fading."})
sc(18, "Along the cabin wall", ["CAM_02"], 2.2, 9.0,
   "Something drags slowly along the cabin's outer wall from one corner to the other.",
   audio=[[1.0, "terror.scrape", -3.0, 27.0, 1.0], [4.0, "terror.scrape", 0.0, 27.0, 1.0], [7.0, "terror.scrape", 3.0, 27.0, 1.0]])
sc(19, "Closer between flickers", ["CAM_09", "CAM_08"], 3.1, 9.0,
   "The trail camera's infrared flickers; between flickers a figure stands a little closer each time.",
   requires=["trees_near"], props=[{"kind": "ir_flicker", "times": [2.0, 4.0, 6.0]}],
   actor={"kind": "figure", "track": [[0.0, 1.0, 42.0], [2.0, 1.0, 42.0], [2.01, 0.6, 34.0], [4.0, 0.6, 34.0], [4.01, 0.3, 27.0], [6.0, 0.3, 27.0]], "hidden": [[6.0, 9.0]]},
   cooldown=14)
sc(20, "The chain moved", ["CAM_04", "CAM_05"], 1.9, 7.0,
   "The gate chain is lifted and set down again on the other side of the post.",
   props=[{"kind": "chain", "anchor": "gate", "track": [[0.0, 0.0], [2.0, 0.0], [3.0, 1.0], [7.0, 1.0]]}],
   audio=[[2.2, "camp.gate.clank", 0.0, 0.0, 0.0, "gate"], [3.0, "camp.gate.clank", 0.0, 0.0, 0.0, "gate"]],
   consequence={"kind": "prop", "mark": "gate_chain", "anchor": "gate", "text": "The gate chain hangs on the other side of the post."})
sc(21, "The lamp dims", ["CAM_06", "CAM_07", "CAM_05"], 0.8, 8.0,
   "A camp-edge lamp dims as if something stood in front of it, then brightens again.",
   requires=["lamp_view"], props=[{"kind": "lamp_occlude", "track": [[0.0, 1.0], [3.0, 0.25], [5.0, 0.25], [6.5, 1.0]]}])
sc(22, "In the stump field", TRAIL + PERIM, 2.4, 12.0,
   "Across a cleared stump field a figure walks between stumps and kneels beside one.",
   requires=["cleared>=40", "open_ground"], cleared_alt=True,
   actor={"kind": "figure", "track": [[0.0, -12.0, 50.0], [6.0, -2.0, 48.0], [8.0, -2.0, 48.0], [12.0, -2.0, 48.0]], "kneel": [[7.0, 12.0]]})
sc(23, "A shadow with no one", TRAIL + PERIM, 3.5, 10.0,
   "On open cleared ground a long moonlit shadow crosses the frame with no figure to cast it.",
   requires=["cleared>=40", "open_ground"], cleared_alt=True,
   props=[{"kind": "shadow_walk", "track": [[0.0, -10.0, 30.0], [10.0, 10.0, 30.0]]}])
sc(24, "Two at the door, one at the glass", ["CAM_01"], 2.0, 7.0,
   "Two knocks on the camper door, then a third from the window side.",
   requires=["day>=6"], actor={"kind": "none", "track": [], "anchor": "camper_door"},
   audio=[[1.0, "terror.knock.wood", 0.0, 0.0, 1.3], [2.0, "terror.knock.wood", 0.0, 0.0, 1.3], [4.5, "terror.knock.glass", 2.6, 1.0, 1.4]],
   cooldown=12)
sc(25, "Through the puddles", ["CAM_06", "CAM_07"], 1.6, 10.0,
   "In the rain, someone walks through the puddles at the edge of the yard.",
   requires=["rain"], actor={"kind": "figure", "track": [[0.0, -9.0, 20.0], [10.0, 9.0, 21.0]]},
   audio=[[1.0, "terror.step.wet", -7.0, 20.0, 0.0], [3.0, "terror.step.wet", -3.0, 20.3, 0.0], [5.0, "terror.step.wet", 1.0, 20.5, 0.0], [7.0, "terror.step.wet", 5.0, 20.7, 0.0]])
sc(26, "A branch at the gate", ["CAM_03"], 0.3, 7.0,
   "A branch is thrown into frame at the trail entrance; nothing follows.",
   props=[{"kind": "branch_land", "x": 0.8, "z": 7.0, "t": 2.0}], audio=[[2.0, "tree.branch.snap", 0.8, 7.0, 0.3]],
   consequence={"kind": "prop", "mark": "branch", "anchor": "gate_out", "text": "A broken branch lies outside the gate."})
sc(27, "A truck door", PERIM, 1.3, 6.0,
   "A pickup's door opens and closes on its own; in the morning it is latched.",
   requires=["truck_view"], audio=[[1.5, "truck.door.open", 0.0, 0.0, 1.0], [4.0, "truck.door.close", 0.0, 0.0, 1.0]], props=[{"kind": "truck_door", "anchor": "truck"}],
   consequence={"kind": "notice", "text": "Both truck doors were shut and latched."})
sc(28, "Out of the water", ["CAM_07", "CAM_06"], 3.9, 12.0,
   "A figure walks up from the shore below the beach gate, stands, and walks back into the dark.",
   actor={"kind": "figure", "track": [[0.0, 2.0, 40.0], [5.0, 2.0, 30.0], [8.0, 2.0, 30.0], [12.0, 2.0, 42.0]]},
   audio=[[3.0, "terror.step.wet", 2.0, 33.0, 0.0], [10.0, "terror.step.wet", 2.0, 38.0, 0.0]], requires=["shore_view"])
sc(29, "The cabin porch boards", ["CAM_02"], 2.7, 8.0,
   "The cabin porch boards creak in a slow sequence toward the door and stop.",
   audio=[[1.0, "home.floor.creak", -2.0, 25.0, 0.4], [2.6, "home.floor.creak", -1.0, 25.5, 0.4], [4.2, "home.floor.creak", 0.0, 26.0, 0.4], [5.8, "home.floor.creak", 0.6, 26.2, 0.4]])
sc(30, "Across the lens", PERIM + ["CAM_03"], 1.0, 5.0,
   "Something dark passes very close across the lens itself.",
   props=[{"kind": "lens_pass", "track": [[1.5, -1.0], [2.4, 1.0]]}], cooldown=12)
sc(31, "A circle round the pit", ["CAM_04", "CAM_05", "CAM_06", "CAM_07", "CAM_01", "CAM_02", "CAM_03"], 0.5, 11.0,
   "Footsteps on gravel circle the burn pit once; the ash ring shows a neat ring of prints at dawn.",
   requires=["pit_view"], actor={"kind": "none", "track": [], "anchor": "pit"},
   audio=[[1.0, "terror.steps.gravel", 2.4, 0.0, 0.0], [3.5, "terror.steps.gravel", 0.0, 2.4, 0.0], [6.0, "terror.steps.gravel", -2.4, 0.0, 0.0], [8.5, "terror.steps.gravel", 0.0, -2.4, 0.0]],
   consequence={"kind": "marks", "mark": "pit_ring", "anchor": "pit", "text": "A ring of prints in the ash around the pit."})
sc(32, "Biscuit growls", ["CAM_01"], 2.3, 6.0,
   "From inside the camper, the dog growls once at the dark perimeter.",
   requires=["dog"], actor={"kind": "none", "track": [], "anchor": "camper_door"},
   audio=[[2.0, "dog.growl", 0.0, -1.5, 0.6]],
   consequence={"kind": "notice", "text": "Biscuit spent the morning watching the north fence."})
sc(33, "Behind the locker", ["CAM_04", "CAM_06", "CAM_05", "CAM_07", "CAM_02"], 3.2, 9.0,
   "A tall figure stands mostly hidden behind the parcel locker, then is not there.",
   requires=["locker_view"], actor={"kind": "figure", "anchor": "locker_behind", "track": [[0.0, 0.7, 0.0], [6.0, 0.7, 0.0]], "hidden": [[6.0, 9.0]], "vis_h": 1.5},
   consequence={"kind": "notice", "text": "The parcel locker was undisturbed."})
sc(34, "Echo over the clearing", TRAIL + PERIM, 0.7, 10.0,
   "Over cleared ground two far knocks echo; a figure stands far out on the open slope.",
   requires=["cleared>=40", "open_ground"], cleared_alt=True,
   actor={"kind": "figure", "track": [[0.0, 6.0, 85.0], [10.0, 6.0, 85.0]]},
   audio=[[2.0, "terror.thud.far", 6.0, 85.0, 1.0], [5.0, "terror.thud.far", 6.0, 85.0, 1.0]])
sc(35, "A rattle in still air", ["CAM_01"], 1.7, 6.0,
   "The camper window rattles though the air is perfectly still.",
   requires=["calm"], actor={"kind": "none", "track": [], "anchor": "camper_door"},
   audio=[[2.0, "window.rattle", 2.4, 0.6, 1.4], [2.6, "window.rattle", 2.4, 0.6, 1.4]])
sc(36, "A light between the trunks", ["CAM_10", "CAM_08", "CAM_09"], 2.0, 12.0,
   "The trail camera catches a small light moving between the trunks at head height.",
   requires=["trees_near"], props=[{"kind": "light_bob", "track": [[0.0, -8.0, 26.0], [6.0, 0.0, 24.0], [12.0, 9.0, 27.0]]}])


def main():
    assert len(S) == 36 and len({s["id"] for s in S}) == 36
    beats = [s["beat"] for s in S]
    assert len(set(beats)) == 36, "beats must be distinct"
    out = {"version": 1, "_doc": "Phase 20: missed-night recording scenarios (docs/PHASE20_NOTES.md). Generated by tools/content/night_recordings.py.", "scenarios": S}
    path = os.path.join(ROOT, "data/terror/recordings.json")
    json.dump(out, open(path, "w", encoding="utf-8"), indent=1)
    print("wrote", len(S), "scenarios;", sum(1 for s in S if s["cleared_alt"]), "cleared-island alternatives;",
          len({c for s in S for c in s["cameras"]}), "cameras used")


main()
