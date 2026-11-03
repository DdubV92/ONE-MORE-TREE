# Review guide (Phases 0-2, about 15 minutes)

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
| 9 | Lighting → **Sunset**, then **Night** (or F4 for the full time slider and Overcast) | Warm low sun and long shadows, then moonlit night with readable silhouettes and lit camp lamps. Camper and cabin windows readable from inside. F3 shows the night-safety status where you stand. |
| 9b | Tour → **Logging Test**, then **Next test tree** | Chop with the left mouse button (hold to keep going). Watch the notch open on your side, the creak warning, the hinge and fall away from you, the landing and the stump. Cases: flat, slope, rock, neighbour, small birch, large pine, closest to camp. Try 1/2/3 to compare axe tiers. |
| 9c | Tour → **Logging Loop** | Fell the tree nearest camp. Aim at the **orange marks** on the trunk to buck it into logs (the crown drops off as brush). Press **E** on a log to shoulder it, then E on more logs to add them until the hand load is full. **G** sets one down at a checked spot, **X** drops all. Carry to the **delivery rack** beside the fire and press E. Watch the stack, the meter, and logs charring in the pit. **F2** shows the ledger and the exact $100 per tree. **Snapshot / Restore snap** exercise the save path in memory. **Reset logging** restores the trees. |
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
