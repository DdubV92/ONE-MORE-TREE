"""Phase 19: the 120 authored offshore-survey crew lines (the addendum's
exact texts) -> data/dialogue/crew/offshore.json.

  python3 tools/content/offshore_lines.py

Each row: number (stable id suffix), speaker, to, trigger (beat), when
(live situation), needs (the speaker's knowledge), rep (cooldown), prio,
knowledge class (reported), directs (points the player's attention).

Speaker assignment follows the established cast (docs/editorial/CAST.md):
  Marta (EMP-01)  brisk, dry lead hand: work-first imperatives
  Dale  (EMP-02)  big, slow, warm skeptic: scale, plain explanations
  Priya (EMP-03)  observant, precise: details, bearings, comparisons
  Tomas (EMP-04)  young, timid, apologetic: noticing, worrying
  Joan  (EMP-05)  warm, chatty, sardonic: commentary, gossip
  trait:x         every worker with that trait (+ replacement voices)
  any             anyone (all seven voice profiles)
"""
import json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WHO = {"EMP-01": "marta", "EMP-02": "dale", "EMP-03": "priya", "EMP-04": "tomas", "EMP-05": "joan"}

M, D, P, T, J, A = "EMP-01", "EMP-02", "EMP-03", "EMP-04", "EMP-05", "any"
OBS, SOC, SKE, TIM, STR = "trait:observant", "trait:sociable", "trait:skeptical", "trait:timid", "trait:stronger"

SEE = ["sea:ship_seen"]
FS = ["sea:saw_ship_now"]                  # firsthand hull sighting
HR = ["sea:heard_rotor"]
FH = ["sea:saw_heli"]

# (n, text, speaker, to, trigger, when, needs, rep, prio, knowledge, directs)
ROWS = [
    # ---- Ship in sight (firsthand line of sight to the hull) ----
    (1, "Boss. Past the surf. Look at the size of that hull.", M, "self", "sight", SEE, FS, "rare", 4, "firsthand_sight", True),
    (2, "Something just came out of the haze beyond camp.", T, "self", "sight", SEE + ["sea:hazy", "where:camp"], FS, "rare", 4, "firsthand_sight", True),
    (3, "Take a look offshore while there's still a gap in the fog.", A, "self", "sight", SEE + ["sea:hazy"], FS, "rare", 4, "firsthand_sight", True),
    (4, "Big ship out there. You can see it between the trees.", SOC, "self", "sight", SEE + ["sea:among_trees"], FS, "rare", 4, "firsthand_sight", True),
    (5, "See the long dark line beyond the waves? That's a deck.", OBS, "self", "sight", SEE + ["sea:broadside"], FS, "rare", 4, "firsthand_sight", True),
    (6, "I thought that was a cloud bank until I saw the wake.", D, "self", "sight", SEE + ["sea:hazy"], FS, "rare", 3, "firsthand_sight", False),
    (7, "There's a ship broadside to us. Look up from the logs.", M, "self", "sight", SEE + ["sea:broadside", "where:camp"], FS, "rare", 4, "firsthand_sight", True),
    (8, "If you stand by me, you can see it over the yard fence.", A, "self", "sight", SEE + ["where:camp"], FS, "rare", 4, "firsthand_sight", True),
    (9, "That's farther out than it looks. The thing's enormous.", D, "self", "sight", SEE, FS, "rare", 3, "firsthand_sight", False),
    (10, "Hang on a second. There's a whole ship behind that swell.", T, "self", "sight", SEE + ["weather:wind"], FS, "rare", 4, "firsthand_sight", True),
    (11, "I can make out the bridge. Can't see a name from here.", P, "self", "sight", SEE + ["sea:near_view"], FS, "rare", 3, "visual_detail", False),
    (12, "Look where the water goes silver. It's just beyond that.", A, "self", "sight", SEE + ["sea:toward_sun"], FS, "rare", 4, "firsthand_sight", True),
    (13, "That ship would dwarf anything I've seen come up to our dock.", D, "self", "sight", SEE, FS, "rare", 3, "firsthand_sight", False),
    (14, "There's a square platform right at the back of it.", OBS, "self", "sight", SEE + ["sea:deck_seen", "sea:near_view"], FS, "rare", 3, "visual_detail", False),
    (15, "Wait for the next swell. The deck comes back into view.", A, "self", "sight", SEE + ["weather:wind"], FS, "rare", 3, "visual_detail", True),
    (16, "I caught it in the corner of my eye while I was stacking.", A, "self", "sight", SEE + ["act:yard"], FS, "rare", 3, "firsthand_sight", False),
    (17, "From here it looks like it's following the coast.", P, "self", "sight", SEE + ["sea:broadside"], FS, "rare", 3, "visual_detail", False),
    (18, "Get a look before it goes behind the point.", A, "self", "sight", SEE + ["sea:edge"], FS, "rare", 4, "firsthand_sight", True),
    (19, "That's a clean white wake for something moving that slowly.", OBS, "self", "sight", SEE + ["sea:slow"], FS, "rare", 3, "visual_detail", False),
    (20, "I can see its windows flashing in the sun.", A, "self", "sight", SEE + ["sea:toward_sun", "weather:dry"], FS, "rare", 3, "visual_detail", False),
    # ---- Camp-facing slow pass ----
    (21, "It was moving quicker a minute ago.", A, "self", "slow", SEE + ["sea:slow"], ["sea:saw_fast_then_slow"], "rare", 3, "visual_detail", False),
    (22, "There's the ship again. It's taking its time past our stretch.", A, "self", "slow", SEE + ["sea:slow", "sea:lap_late"], FS, "rare", 4, "firsthand_sight", True),
    (23, "You've got time to see it. The wake's dropped right off.", A, "self", "slow", SEE + ["sea:slow"], FS, "rare", 4, "firsthand_sight", True),
    (24, "I watched it ease down as it came level with us.", P, "pair", "slow", [], ["sea:saw_slowdown"], "rare", 3, "visual_detail", False),
    (25, "Still out there. I thought it'd have gone by now.", J, "self", "slow", SEE + ["sea:slow"], ["sea:saw_ship_long"], "rare", 3, "firsthand_sight", False),
    (26, "It hasn't turned in. It's just creeping along outside the bay.", P, "self", "slow", SEE + ["sea:slow", "sea:broadside"], FS, "rare", 3, "visual_detail", False),
    (27, "If you missed it earlier, look now. It's barely moving.", A, "self", "slow", SEE + ["sea:slow", "sea:player_missed"], FS, "rare", 4, "firsthand_sight", True),
    (28, "Whole lot of ocean out there and it chooses this bit to slow down.", J, "self", "slow", SEE + ["sea:slow"], ["sea:saw_slowdown"], "rare", 3, "visual_detail", False),
    (29, "Maybe the captain likes the view. I've seen better views.", D, "self", "slow", SEE + ["sea:slow"], FS, "rare", 2, "firsthand_sight", False),
    (30, "You could finish that stack before it gets past the point.", M, "self", "slow", SEE + ["sea:slow", "where:camp"], FS, "rare", 3, "firsthand_sight", False),
    (31, "I can see the back deck clearly now that it's slowed.", P, "self", "slow", SEE + ["sea:slow", "sea:deck_seen"], FS, "rare", 3, "visual_detail", False),
    (32, "No boat coming down from it that I can see.", A, "self", "slow", SEE + ["sea:slow"], FS, "rare", 2, "visual_detail", False),
    (33, "It'll pass the opening in the trees in a second. Watch.", A, "self", "slow", ["sea:ship_unseen", "sea:opening_soon", "sea:among_trees"], FS, "rare", 4, "firsthand_sight", True),
    (34, "Look at the gap it's keeping from shore.", OBS, "self", "slow", SEE + ["sea:slow"], FS, "rare", 3, "visual_detail", True),
    (35, "The bow's still pointed along the coast.", A, "self", "slow", SEE + ["sea:slow", "sea:broadside"], FS, "rare", 2, "visual_detail", False),
    (36, "Might be waiting on something out there.", A, "self", "slow", SEE + ["sea:slow"], FS, "rare", 2, "firsthand_sight", False),
    (37, "Wish I knew what counted as normal ship speed.", J, "self", "slow", SEE + ["sea:slow"], FS, "rare", 2, "firsthand_sight", False),
    (38, "If it's checking the coast, it's getting a long look at this yard.", J, "self", "slow", SEE + ["sea:slow", "where:camp"], FS, "rare", 3, "firsthand_sight", False),
    (39, "I didn't think I'd be able to hear it from this far out.", A, "self", "slow", SEE + ["sea:engine_heard"], FS, "rare", 3, "hearing", False),
    (40, "It's picking up again. That's the last clear look from here.", M, "self", "slow", SEE + ["sea:speeding"], FS, "rare", 4, "visual_detail", True),
    # ---- Rotor heard (hearing alone is enough) ----
    (41, "Kill the saw when you can. Hear that chopping sound?", M, "self", "rotor", ["sea:rotor", "sea:saw_running"], HR, "rare", 4, "hearing", True),
    (42, "Hold up. There's a thump coming in over the trees.", A, "self", "rotor", ["sea:heli_unseen_heard", "sea:among_trees"], HR, "rare", 4, "hearing", True),
    (43, "Anyone else hear something overhead?", T, "self", "rotor", ["sea:heli_unseen_heard"], HR, "rare", 4, "hearing", True),
    (44, "That's a rotor, isn't it?", T, "self", "rotor", ["sea:rotor"], HR, "rare", 3, "hearing", False),
    (45, "Listen for the beat underneath the wind.", OBS, "self", "rotor", ["sea:rotor", "weather:wind"], HR, "rare", 4, "hearing", True),
    (46, "Sounds like a helicopter coming closer.", A, "self", "rotor", ["sea:heli_unseen_heard", "sea:rotor_rising"], HR, "rare", 4, "hearing", True),
    (47, "I heard it between cuts. It kept getting louder.", A, "self", "rotor", ["sea:rotor", "act:cut", "sea:rotor_rising"], HR, "rare", 3, "hearing", False),
    (48, "That noise is moving. Look up if you get a clear patch.", A, "self", "rotor", ["sea:heli_unseen_heard", "sea:among_trees"], HR, "rare", 4, "hearing", True),
    (49, "For a second I thought something was loose on the truck.", D, "self", "rotor", ["sea:rotor", "sea:truck_near"], HR, "rare", 3, "hearing", False),
    (50, "Hear it? There's a low beat behind the engine noise.", A, "self", "rotor", ["sea:rotor", "sea:engine_noise"], HR, "rare", 4, "hearing", True),
    (51, "Whatever's overhead is drowning out the surf.", A, "self", "rotor", ["sea:rotor", "sea:rotor_close", "where:shore"], HR, "rare", 3, "hearing", False),
    (52, "I can hear it through the cabin wall.", A, "self", "rotor", ["sea:rotor", "where:cabin"], HR, "rare", 3, "hearing", False),
    (53, "Wait until this load's down. Then have a listen.", M, "self", "rotor", ["sea:rotor", "act:carry"], HR, "rare", 3, "hearing", True),
    (54, "That rumble's getting closer. I can't see what's making it.", T, "self", "rotor", ["sea:heli_unseen_heard", "sea:rotor_rising"], HR, "rare", 4, "hearing", False),
    (55, "Sounded like it came in off the water.", P, "self", "rotor", ["sea:rotor", "sea:from_water"], HR, "rare", 3, "hearing", False),
    (56, "I lost the sound behind the ridge. Might come round again.", A, "self", "rotor", ["sea:rotor_lost", "sea:heli_behind_ridge"], HR, "rare", 3, "hearing", False),
    (57, "It's still there when the wind drops.", A, "self", "rotor", ["sea:rotor", "weather:wind"], HR, "rare", 3, "hearing", False),
    (58, "I've got a better listen here away from the pit.", A, "self", "rotor", ["sea:rotor", "where:camp", "sea:away_from_pit"], HR, "rare", 3, "hearing", False),
    (59, "That's got a rhythm to it. Been hearing it for half a minute.", P, "self", "rotor", ["sea:rotor_long"], HR, "rare", 3, "hearing", False),
    (60, "It went quiet quick. Must be farther off now.", A, "self", "rotor", ["sea:rotor_lost"], HR, "rare", 2, "hearing", False),
    # ---- Helicopter in sight (visual contact required) ----
    (61, "Up over the treeline. You've got a helicopter coming past.", A, "self", "heli", ["sea:heli_seen", "where:camp"], FH, "rare", 4, "visual_detail", True),
    (62, "There it goes over camp. Look up.", A, "self", "heli", ["sea:heli_seen", "sea:over_camp"], FH, "rare", 4, "visual_detail", True),
    (63, "I can see it banking out over the water.", P, "self", "heli", ["sea:heli_seen", "sea:banking", "sea:over_water"], FH, "rare", 3, "visual_detail", True),
    (64, "It's crossing the clearing. You've got a few seconds.", A, "self", "heli", ["sea:heli_seen", "sea:over_cleared"], FH, "rare", 4, "visual_detail", True),
    (65, "I can see the underside from here. Can't read anything on it.", P, "self", "heli", ["sea:heli_seen", "sea:overhead"], FH, "rare", 3, "visual_detail", False),
    (66, "There it is, just above the ridge.", A, "self", "heli", ["sea:heli_seen", "sea:over_ridge"], FH, "rare", 4, "visual_detail", True),
    (67, "It turned after it passed the yard.", A, "pair", "heli", [], ["sea:saw_heli_camp", "sea:saw_heli"], "rare", 3, "visual_detail", False),
    (68, "It's making another sweep. Watch the open sky.", M, "self", "heli", ["sea:heli_seen", "sea:sweep"], FH, "rare", 4, "visual_detail", True),
    (69, "I saw it go over the far slope and turn back in.", A, "self", "heli", ["sea:heli_seen", "sea:turned", "sea:heli_far"], FH, "rare", 3, "visual_detail", False),
    (70, "It came across the whole stand we cleared yesterday.", J, "self", "heli", ["sea:heli_seen", "sea:over_cleared", "cleared>=5"], FH, "rare", 3, "visual_detail", False),
    (71, "I thought it was heading straight through. Then it banked.", P, "self", "heli", ["sea:heli_seen", "sea:banking", "sea:turned"], FH, "rare", 3, "visual_detail", False),
    (72, "It's holding out over the coast now.", A, "self", "heli", ["sea:heli_seen", "sea:over_water", "sea:heli_far"], FH, "rare", 3, "visual_detail", True),
    (73, "You can see it between those two tops.", A, "self", "heli", ["sea:heli_seen", "sea:among_trees"], FH, "rare", 4, "visual_detail", True),
    (74, "That's low enough to get a decent look at camp.", T, "self", "heli", ["sea:heli_seen", "sea:over_camp"], FH, "rare", 3, "visual_detail", False),
    (75, "I saw the tail vanish behind the ridge. Keep watching that gap.", A, "self", "heli", ["sea:heli_behind_ridge"], FH, "rare", 4, "visual_detail", True),
    (76, "Looks like the next pass is taking it farther inland.", A, "self", "heli", ["sea:heli_seen", "sea:sweep", "sea:inland_next"], FH, "rare", 3, "visual_detail", False),
    (77, "It went across the bay and curved back toward the island.", A, "self", "heli", ["sea:heli_seen", "sea:turned", "sea:inbound"], FH, "rare", 3, "visual_detail", False),
    (78, "I'd have missed it if the shadow hadn't moved.", T, "self", "heli", ["sea:heli_seen", "sea:heli_close", "weather:dry", "phase:day"], FH, "rare", 3, "visual_detail", False),
    (79, "I saw it pass the dock. It kept right on going.", A, "self", "heli", ["sea:heli_seen", "sea:near_dock"], FH, "rare", 3, "visual_detail", False),
    (80, "There it goes toward the water. You can see it against the haze.", A, "self", "heli", ["sea:heli_seen", "sea:seaward", "sea:hazy"], FH, "rare", 4, "visual_detail", True),
    # ---- Deck, departure and repeated sightings ----
    (81, "I saw it lift right off that square at the stern.", P, "pair", "deck", ["sea:heli_airborne"], ["sea:saw_launch"], "rare", 3, "visual_detail", False),
    (82, "Watch the back of the ship. The helicopter's coming down.", A, "self", "deck", ["sea:landing", "sea:deck_seen"], FS, "rare", 4, "visual_detail", True),
    (83, "It went back to the same deck it came from.", A, "pair", "deck", [], ["sea:saw_recover"], "rare", 3, "visual_detail", False),
    (84, "The whole ship's moving and it's lining up with the pad.", P, "self", "deck", ["sea:landing", "sea:deck_seen"], FS, "rare", 3, "visual_detail", False),
    (85, "It's over the ship now. Looks like they're bringing it in.", A, "self", "deck", ["sea:landing", "sea:deck_seen"], FS, "rare", 3, "visual_detail", True),
    (86, "I could see the rotor clear as anything against the deck.", OBS, "self", "deck", ["sea:near_view"], ["sea:saw_land"], "rare", 3, "visual_detail", False),
    (87, "I watched the ship come round to the same stretch of water.", A, "self", "slow", SEE + ["sea:lap_late"], ["sea:saw_ship_early"], "rare", 3, "visual_detail", False),
    (88, "It came back on the bearing where we first saw it.", P, "pair", "slow", SEE + ["sea:lap_late"], ["sea:saw_ship_early"], "rare", 3, "visual_detail", False),
    (89, "It made the whole round. I caught it on both sides of the island.", A, "pair", "depart", [], ["sea:both_sides"], "rare", 3, "visual_detail", False),
    (90, "Same hull as the one I saw a few days ago.", A, "self", "repeat", SEE, ["sea:two_passes"], "rare", 3, "two_passes", False),
    (91, "Last time I watched it slow down at this same stretch.", A, "self", "repeat", SEE + ["sea:slow"], ["sea:prev_slow", "sea:saw_ship_now"], "rare", 3, "two_passes", False),
    (92, "The first time I only saw the ship. Today I saw what was on it.", A, "self", "repeat", [], ["sea:prev_ship_only", "sea:saw_heli"], "once", 3, "two_passes", False),
    (93, "That helicopter took a different line over the ridge this time.", P, "self", "repeat", ["sea:heli_seen"], ["sea:prev_heli", "sea:saw_heli"], "rare", 3, "two_passes", False),
    (94, "I remember that big platform at the back. Saw it on the last pass too.", OBS, "self", "repeat", SEE + ["sea:deck_seen"], ["sea:prev_deck"], "rare", 3, "two_passes", False),
    (95, "The ship's heading away now. Wake's pointing straight out.", A, "self", "depart", SEE + ["sea:departing"], FS, "rare", 3, "visual_detail", True),
    (96, "I lost it after it turned seaward.", A, "self", "depart", ["sea:heli_lost_seaward"], FH, "rare", 3, "visual_detail", False),
    (97, "The rotor sound went with it after the helicopter came down.", A, "self", "deck", [], ["sea:heard_rotor", "sea:knows_recover"], "rare", 2, "hearing", False),
    (98, "Yesterday there was nothing on the horizon from this spot. I checked.", A, "self", "sight", SEE + ["sea:yesterday_quiet"], FS, "rare", 3, "firsthand_sight", False),
    (99, "It's gone around the point again. I wonder how far out it goes after.", A, "self", "depart", ["sea:ship_lost_point"], ["sea:two_passes"], "rare", 3, "two_passes", False),
    (100, "Next time we hear a rotor, somebody check the water.", M, "group", "later", ["sea:after"], ["sea:heard_rotor", "sea:knows_ship"], "rare", 3, "hearing", False),
    # ---- Later conversation and secondhand reports ----
    (101, "You saw the helicopter. Did you see where it came from?", SOC, "pair", "later", ["sea:after"], ["sea:heard_only"], "rare", 3, "secondhand", False),
    (102, "I heard it, sure. I couldn't tell you what was painted on it.", D, "pair", "later", ["sea:after"], ["sea:heard_only"], "rare", 3, "hearing", False),
    (103, "Someone said there was a ship. All I got was the noise overhead.", T, "pair", "later", ["sea:after"], ["sea:told", "sea:heard_rotor"], "rare", 3, "secondhand", False),
    (104, "How far out was it when you saw it slow down?", J, "pair", "later", ["sea:after"], ["sea:told"], "rare", 3, "secondhand", False),
    (105, "Maybe they're looking at the shoreline. People do that for work.", D, "pair", "later", ["sea:after"], ["sea:knows_any"], "rare", 3, "secondhand", False),
    (106, "If it was a survey, somebody's putting in some long days.", P, "pair", "later", ["sea:after"], ["sea:knows_any"], "rare", 3, "secondhand", False),
    (107, "I went out to look after you called. I only caught the wake.", A, "pair", "later", ["sea:after"], ["sea:wake_only"], "rare", 3, "secondhand", False),
    (108, "I've got nothing better than a guess about what they're doing.", A, "pair", "later", ["sea:after"], ["sea:knows_any"], "rare", 2, "secondhand", False),
    (109, "The way you describe it, I'd have sworn they were coming in.", A, "pair", "later", ["sea:after"], ["sea:told"], "rare", 3, "secondhand", False),
    (110, "Did it make one pass over the yard or did I hear the same pass twice?", T, "pair", "later", ["sea:after"], ["sea:heard_twice", "sea:no_heli_seen"], "rare", 3, "hearing", False),
    (111, "I wish I'd looked up when you called. The saw was going.", T, "pair", "later", ["sea:after"], ["sea:missed_saw"], "rare", 3, "secondhand", False),
    (112, "One person sees a boat and by supper we've got an expedition.", SKE, "group", "later", ["sea:after"], ["sea:knows_any"], "rare", 3, "secondhand", False),
    (113, "If they saw me from up there, they saw me dropping the same log twice.", T, "pair", "later", ["sea:after"], ["sea:knows_heli"], "rare", 2, "hearing", False),
    (114, "They had a view of every stump we left.", J, "pair", "later", ["sea:after", "cleared>=5"], ["sea:knows_heli"], "rare", 3, "hearing", False),
    (115, "I can't tell what anyone wants from a wake and a bit of noise.", SKE, "pair", "later", ["sea:after"], ["sea:knows_any"], "rare", 3, "secondhand", False),
    (116, "You can call it routine. I'd still like to know whose routine.", J, "pair", "later", ["sea:after"], ["sea:knows_any"], "rare", 3, "secondhand", False),
    (117, "Maybe we're the only interesting thing on this coast.", M, "group", "later", ["sea:after"], ["sea:knows_any"], "rare", 2, "secondhand", False),
    (118, "I'd rather it passed in daylight again.", T, "pair", "later", ["sea:after", "phase:dusk"], ["sea:knows_any"], "rare", 3, "secondhand", False),
    (119, "Next time, tell me before it gets behind the ridge.", A, "pair", "later", ["sea:after"], ["sea:missed"], "rare", 3, "secondhand", False),
    (120, "Funny how quiet the yard felt after it went.", J, "group", "later", ["sea:today", "where:camp"], ["sea:saw_ship_now"], "rare", 2, "firsthand_sight", False),
]

# Replies that make the later conversations real exchanges.
RESP = {
    101: [83, 81],
    103: [89, 112],
    104: [24],
    105: [116, 106],
    106: [113, 114],
    107: [100],
    108: [105, 117],
    110: [67],
    111: [119],
    89: [109],
    24: [109],
    112: [115],
    116: [117],
}
REPLY_ONLY = {109}


def line_id(n, sp):
    who = WHO.get(sp, "any")
    return "sea.%s.%03d" % (who, n)


def main():
    ids = {r[0]: line_id(r[0], r[2]) for r in ROWS}
    assert len(ROWS) == 120 and sorted(ids) == list(range(1, 121)), "need exactly lines 1..120"
    out = []
    for (n, text, sp, to, trig, when, needs, rep, prio, kn, directs) in ROWS:
        ln = {"id": ids[n], "cat": "offshore", "n": n, "speaker": sp, "to": to, "trigger": trig, "knowledge": kn,
              "when": ["mode:contract"] + list(when), "needs": list(needs), "rep": rep, "prio": prio, "text": text}
        if directs:
            ln["directs"] = True
        if n in RESP:
            ln["resp"] = [ids[r] for r in RESP[n]]
        if n in REPLY_ONLY:
            ln["reply"] = True
        out.append(ln)
    path = os.path.join(ROOT, "data/dialogue/crew/offshore.json")
    json.dump({"category": "offshore", "batch": "offshore-p19", "review": "authored (addendum texts verbatim)", "lines": out},
              open(path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    by = {}
    for ln in out:
        by[ln["speaker"]] = by.get(ln["speaker"], 0) + 1
    print("wrote", len(out), "lines", by)


main()
