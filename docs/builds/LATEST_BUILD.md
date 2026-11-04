# ONE MORE TREE LATEST BUILD PHASE 7 - build 32 (Windows)

**Download:** https://github.com/DdubV92/ONE-MORE-TREE/actions/runs/41789031498/artifacts/13302508628
(Sign in to GitHub. The title screen footer shows the same label.)

Extract the zip to a new folder (this replaces the Phase 6 build) and run `OneMoreTree.exe`. If SmartScreen warns, choose More info, then Run anyway.

## New in Phase 7

- **Bridges:** both trail bridges are wider (3.6 m), have gentler ramps, and trucks can drive over them. Workers and the dog now walk on the deck instead of the riverbed under it.
- **Truck coverage:** trucks can now reach 11,898 of the 12,000 trees, including the far east side of the river.
- **Stumps:** workers chop out stumps on their own.
- **Locate the nearest remaining work:** a new button in Journal (J), Contract tab, with a light marker on the spot.
- **Truck teams:** a truck no longer circles a waypoint forever, and loaders who miss the truck go back to work.
- **Island audit tools:** in Preview Tour (Tab), under "Phase 7 island audit": a support/navigation overlay, the bridges, truck height view, locator, and the dock.

Checks: 47/47 tests pass, the smoke test is clean, and the CI build succeeded. Nothing has been checked on a real GPU.

The 30-day contract is still out of reach at the current pace (about 7 trees a day against 400). The faster cutting and longer days you're planning will be re-measured with `tools/workload_sim.tscn` once they land.
