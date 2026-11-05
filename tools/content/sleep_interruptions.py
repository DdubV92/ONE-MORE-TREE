"""Phase 20 (repairs the Phase 19 expansion gap): 24 authored rare
sleep-interruption sequences -> data/terror/sleep_interruptions.json.

  python3 tools/content/sleep_interruptions.py

Each sequence plays while the boss settles into sleep inside the camper
during the contract: sounds at real points around the camper (anchors),
an optional visual beyond the window, a caption for muted play, then it
withdraws and sleep is available again (SleepInterrupts state machine).
Never inside the protected room, never an exit, never harm.

Anchors: camper_door, camper_window_r, camper_window_l, camper_wall_n,
camper_roof, camper_under, camper_porch, around_camper (4 points), desk,
gate, fence, yard, cabin, truck, outside_far, outside_far2.
Steps: [t, event_id, anchor, db_offset]  (db offset <= +2: bounded gain)
"""
import json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
Q = []


def si(n, title, steps, caption, dur, requires=None, visual=None, morning="", cooldown=6, weight=1.0, rest_cost=2.0, major=False):
    for s in steps:
        assert s[3] <= 2.0, "bounded gain"
    Q.append({"id": "si%02d" % n, "n": n, "title": title, "steps": steps, "caption": caption, "duration": dur, "requires": requires or [],
              "visual": visual or "", "morning": morning, "cooldown": cooldown, "weight": weight, "rest_cost": rest_cost, "major": major})


si(1, "The door", [[0.6, "night.door.impact", "camper_door", 2.0]], "[A heavy blow on the camper door]", 9.0,
   visual="door_shudder", cooldown=12, weight=0.6, rest_cost=3.0, major=True,
   morning="There is no mark on the camper door.")
si(2, "Low vibration in the glass", [[0.5, "window.rattle", "camper_window_r", 0.0], [2.2, "window.rattle", "camper_window_r", -2.0], [4.0, "window.rattle", "camper_window_r", -4.0]],
   "[The window buzzes in its frame]", 8.0)
si(3, "A camera alert", [[0.4, "desk.cam.alert", "desk", 0.0]], "[The desk chimes: camera alert]", 6.0,
   morning="The alert left no recording worth keeping.")
si(4, "A muffled call", [[0.8, "night.call.far", "cabin", 0.0]], "[A muffled call from the direction of the cabin]", 8.0,
   requires=["cabin_occupied"], morning="Nobody in the cabin called out; they all slept straight through.")
si(5, "Brushing the wall", [[0.5, "terror.scrape", "camper_wall_n", 0.0], [2.5, "terror.scrape", "camper_wall_n", -2.0]],
   "[Something brushes along the outer wall]", 8.0)
si(6, "A bang, then nothing", [[0.5, "terror.thud.far", "outside_far", 2.0]], "[A distant bang. Then silence]", 10.0, visual="hush", major=True, cooldown=10, weight=0.7)
si(7, "On the roof", [[0.8, "terror.knock.wood", "camper_roof", -2.0], [4.0, "terror.knock.wood", "camper_roof", -4.0]], "[Two slow taps on the roof]", 8.0)
si(8, "The gate", [[0.6, "camp.gate.clank", "gate", 0.0]], "[The gate clanks once]", 7.0, morning="The gate was latched.")
si(9, "Biscuit whines", [[0.5, "dog.whine", "camper_porch", -2.0]], "[Biscuit whines once at the door, then settles]", 7.0, requires=["dog"])
si(10, "Round the camper", [[0.5, "terror.steps.gravel", "around_camper:0", 0.0], [2.0, "terror.steps.gravel", "around_camper:1", 0.0], [3.5, "terror.steps.gravel", "around_camper:2", 0.0], [5.0, "terror.steps.gravel", "around_camper:3", 0.0]],
   "[Footsteps on gravel, all the way round the camper]", 9.0, cooldown=10, major=True, weight=0.6)
si(11, "Past the window", [[1.2, "terror.step.wet", "camper_window_r", -4.0]], "[Something moves past the window]", 7.0, visual="window_shape")
si(12, "The handle", [[0.6, "door.latch", "camper_door", 0.0], [1.4, "door.latch", "camper_door", -2.0]], "[The door handle moves. The lock holds]", 8.0, visual="handle", major=True, cooldown=10, weight=0.6)
si(13, "Tapping on the glass", [[0.5, "terror.knock.glass", "camper_window_l", -4.0], [1.0, "terror.knock.glass", "camper_window_l", -4.0], [1.5, "terror.knock.glass", "camper_window_l", -4.0]], "[Three light taps on the glass]", 7.0)
si(14, "The fence", [[0.5, "camp.fence.rattle", "fence", 0.0]], "[The fence rattles somewhere along the yard]", 6.0)
si(15, "Under the floor", [[0.6, "terror.knock.metal", "camper_under", -2.0]], "[A metallic knock from under the camper]", 7.0)
si(16, "A truck door", [[0.6, "truck.door.close", "truck", 0.0]], "[A truck door shuts across the yard]", 7.0, requires=["truck"], morning="Both truck doors were shut and latched.")
si(17, "A branch snaps", [[0.5, "tree.branch.snap", "camper_wall_n", 0.0]], "[A branch snaps just outside]", 6.0)
si(18, "Steps to the door", [[0.5, "terror.step.wet", "around_camper:2", -2.0], [1.7, "terror.step.wet", "camper_porch", -1.0], [2.9, "terror.step.wet", "camper_door", 0.0]], "[Wet steps come to the door and stop]", 9.0, major=True, cooldown=10, weight=0.6)
si(19, "The porch step", [[0.8, "home.floor.creak", "camper_porch", 0.0]], "[The porch step creaks under a weight]", 7.0)
si(20, "Growling at the window", [[0.6, "dog.growl", "desk", -2.0]], "[Biscuit growls low at the window]", 7.0, requires=["dog"])
si(21, "One knock, then another", [[0.5, "terror.knock.wood", "camper_door", 0.0], [7.0, "terror.knock.wood", "camper_door", 0.0]], "[A knock on the door... and, much later, another]", 11.0, major=True, cooldown=10, weight=0.6)
si(22, "Something set down", [[0.6, "log.drop.rack", "yard", 0.0]], "[Something heavy is set down in the yard]", 7.0, morning="The yard count matches yesterday's report.")
si(23, "Past the other window", [[0.9, "window.rattle", "camper_window_l", -4.0]], "[A shape crosses the far window]", 7.0, visual="window_shape_l")
si(24, "Calls from two sides", [[0.6, "night.call.far", "outside_far", -2.0], [4.0, "night.call.far", "outside_far2", -2.0]], "[A faint call from one side... then from the other]", 9.0, major=True, cooldown=12, weight=0.5)


def main():
    assert len(Q) == 24 and len({q["id"] for q in Q}) == 24
    out = {"version": 1, "_doc": "Phase 20: rare sleep interruptions (docs/PHASE20_NOTES.md). Generated by tools/content/sleep_interruptions.py.", "sequences": Q}
    json.dump(out, open(os.path.join(ROOT, "data/terror/sleep_interruptions.json"), "w", encoding="utf-8"), indent=1)
    print("wrote", len(Q), "sequences;", sum(1 for q in Q if q["major"]), "major")


main()
