# Review guide (Phases 0-4, about 30 minutes)

Start a test build (README → "Play a test build"), then choose **Preview Tour** on the title screen.

- The **Tour panel** opens on the left. Press **Tab** to toggle it, and click in the world to recapture the mouse.
- Press **V** for fly mode if you want to look around freely.
- Preview mode never writes saves, wages, tree damage or horror exposure.

| # | Do | Look for |
|---|---|---|
| 1 | Tour → **Camp** (lighting: Day) | 42×34 m dirt clearing, chain-link fence with a wide north entrance and a small beach gate, lamps, burn pit with fire/embers/smoke/heat shimmer, picnic table, tool lean-to with small/medium/large axes, notice board, cabin and camper. Walk around: collision, slopes, steps. |
| 2 | Walk into the **camper** (E opens doors) | Kitchen (stove, sink, fridge, cabinets), lounge with couch and TV, bathroom behind its own door, bedroom with player bed and window to the woods, dog bed by the door. Lights are warm and outdoor sound is muffled. |
| 3 | Tour → **Cabin** | Four beds with footlockers and shelves, table and four chairs, two arcade cabinets (E for the placeholder), porch lamp. |
| 4 | Tour → **Beach**, then **Shallows** | Waves rolling in and thinning across the sand, broken foam at the swash edge and around rocks, wet sand darkening and glistening as water withdraws, clear turquoise shallows with sand and caustics underneath. Wade in until the "Too deep" push-back starts. Buoys mark the depth. Press F7 for a ripple. |
| 5 | Tour → **Forest** | Pine, spruce and birch silhouettes with variants, clustered pockets and gaps, ferns/grass/bushes, wind sway. Press F6 on a trunk to inspect its record (stable ID). |
| 6 | Tour → **River**, **Rapids** | River following the valley downhill to the sea, footbridge, whitewater only at riffles. Walk across the bridge. |
| 7 | Tour → **Pond**, **Pond 2** | Calmer water, reeds at the edge, muddy banks. Step in for ripples. |
| 8 | Tour → **Ridge** | Island scale and landmarks: the long axis is about 1.55 km, roughly a 6-minute walk. |
| 9 | Lighting → **Sunset**, then **Dark night** and **Full moon** (or F4 for the full time slider and Overcast) | Warm low sun and long shadows. On a dark (new-moon) night the forest fades to black within a few dozen metres and only the lamp pools, fire and windows show. A full moon lets you read silhouettes further out. Mist sits low on the ground. Camper and cabin windows readable from inside. F3 shows the night-safety status where you stand. |
| 9b | Tour → **Logging Test**, then **Next test tree** | Chop with the left mouse button (hold to keep going). Watch the notch open on your side, the creak warning, the hinge and fall away from you, the landing and the stump. Cases: flat, slope, rock, neighbour, small birch, large pine, closest to camp. Try 1/2/3 to compare axe tiers. |
| 9c | Tour → **Logging Loop** | Fell the tree nearest camp. Aim at the **orange marks** on the trunk to buck it into logs (the crown drops off as brush). Press **E** on a log to shoulder it, then E on more logs to add them until the hand load is full. **G** sets one down at a checked spot, **X** drops all. Carry to the **delivery rack** beside the fire and press E. Watch the stack, the meter, and logs charring in the pit. **F2** shows the ledger and the exact $100 per tree. **Snapshot / Restore snap** exercise the save path in memory. **Reset logging** restores the trees. |
| 9d | Tour → **Day & Economy Test → Start session** (in memory, never saved) | The top of the screen shows the day, phase and countdown in words, plus cash. Deliver a log at the rack: **+$ credited** at once. **J** opens the journal (contract, payroll fixtures, ledger). Press **Open shop**, buy the medium axe, then press 2 and chop to feel x1.40. **Jump to dusk** shows the dusk warning and lighting change. **Sleep now** (or E on the camper bed after dusk) gives one report and then morning. **Unpaid wages** then sleeping twice shows arrears and one quit request. **Day 30 dusk** / **Prepared loss** let the contract close at nightfall without sleeping, showing the honest Phase 6 handoff. **Prepared win** shows the fulfilled screen. |
| 9e | Title → **Play the contract** → a slot → **New contract** | A real campaign: exact 15 + 5 minute days, $2,000 starting cash (provisional), two crew records waiting for Phase 4 (no wages yet), axes at the tool rack, and sleep in the camper bed. Quit and **Continue** the slot: trees, logs, money, time and day are kept. |
| 9f | Tour → **Crew Demonstration → Start crew demo** (in memory) | The two starters leave the cabin and work. You can watch a full fell → buck → carry → rack cycle: they retreat before a fall and the money credits when a log reaches the rack. Three hires (timid + observant, level-headed + sociable, skeptical + hard-working) arrive by skiff at the dock. Press **E** on a worker to talk. Try **Figure at trees** or **Voice mimic**, then ask "Noticed anything strange?": the skeptic only changes their mind after seeing it themselves. Compare the timid and level-headed reactions. **Jump to dusk** shows the return warnings and walk home; at night they lie in their beds (two are in the new extension bedroom). **J → Crew**: assign jobs, work near me, hire, fire (confirmation, then a real walk to the boat). |
| 10 | Tour → **Character Preview** | Human: Idle, Walk, Axe swing, Walk a circle, Next look (4 workers). Dog: Idle, Walk, Lie & sleep. Speed slider, joint/foot-contact debug, Day/Sunset/Night. |

Optional:
- **Run 60 s benchmark route** (Tour panel) writes frame-time results into a diagnostic report.
- **Explore the island** starts the campaign mode, which saves on quit and from the pause menu.

## Screenshot viewpoints

These names match `Viewpoints.all()` and the tour buttons:
- `camp`, `camp_sunset`, `camper`, `camper_night`, `cabin`
- `beach`, `shallows`, `coast_day`
- `forest`, `river`, `rapids`, `pond`, `pond2`, `ridge`

Developers can render any of them with:

```bash
godot res://tools/capture_views.tscn -- day:coast_day day:shallows day:river day:forest sunset:camp_sunset night:camper_night
```

## What to report back

- Screenshots or clips, plus the **diagnostic report** (F12).
- Anything that looks wrong at a specific viewpoint name.
- Frame rate from F3 or the benchmark, with your preset (Settings → Quality).
