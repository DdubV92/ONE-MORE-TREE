# Phase 7 issue ledger

Stable ids. Severity: blocker (mandatory target, route or support broken), major, minor. Disposition: fixed / exception / false positive / open (with reason). Evidence points at the audit run (`tools/island_audit.tscn`, report in `docs/audit/ISLAND_AUDIT.md` + `island_audit.json`) or a test.

| Id | Severity | Area | Problem (reproduction) | Fix | Evidence | Disposition |
|---|---|---|---|---|---|---|
| P7-B01 | blocker | Navigation, bridges | Workers and the dog crossing the two trail bridges followed the **riverbed height** under the deck: the crew grid marked bridge cells walkable but had no deck heights. | `CrewNav` now records deck and ramp heights per bridge cell (`BridgeBuilder.surface_at_distance`). | Audit path samples; `phase 7` test checks the surface on the deck | fixed |
| P7-B02 | blocker | Trucks, east of the river | The outer east / south-east (about 2,400 trees) had **no truck route**: the 2.4 m footbridges were not drivable and only cells within 1.8 m of the axis counted. | Bridges are now 3.6 m wide with ramps no steeper than 22 %; `DriveNav` lays drivable cells along each bridge axis; trucks ride the recorded deck height. | Trees within 25 m of a truck route: **11,898 / 12,000** (was 7,995) | fixed |
| P7-B03 | blocker | Contract completion | Stumps are required contract targets but **only the player** could remove them: 12,000 stumps would need the boss's axe. | Workers chop out stumps (processing job, and automatic mode before felling more) through shared `stump:<id>` claims with the normal swing/work rate. | Phase 7 test + crew sim | fixed |
| P7-B04 | major | Final items | No way to find the last tree/stump/log on a 1.5 km island. | Journal → Contract → **Locate the nearest remaining work**: distance + compass for the nearest standing tree, stump and undelivered log, and a 60 s light column on the nearest. | Manual | fixed |
| P7-B05 | major | Trucks, dynamic recovery | A worker-driven truck could orbit a waypoint inside its turning circle for minutes ("driving out" at the same spot for 5+ min in the `full5` trace). | Progress guard: if the distance to the current waypoint stops shrinking for 12 s (and nothing is in the road) the waypoint is skipped; tight turns near a waypoint slow to 1.2 m/s. | `full5` re-run: day throughput 3.37 → 7.01 tree-eq | fixed |
| P7-B06 | major | Truck teams | Team members who had not boarded when the truck left stood idle in camp all day (2 of 5 workers in the `full5` trace). | They are released from the team and return to ordinary jobs. | `full5` re-run | fixed |
| P7-0001 | minor | Ground cover | 11 pebble instances read back at the cell origin in headless runs. | Verified with the Vulkan renderer: the same cell has 0 instances at the origin (real transforms). Headless dummy-renderer readback; the audit now skips identity readbacks. | `tools/_q8` probe (Vulkan vs headless) | false positive |
| P7-0002 | minor | Anchors | `DockPickup` marker sits on the water surface 1.46 m above the seabed. | It is the skiff berth anchor (water-level, buoyant boat), not a standing point; nothing walks to it. | Audit | exception |
| P7-0003 | minor | Audit tool | "Bridge ends" were compared against the riverbed height at the bridge centre. | Compared against the deck and the measured ramp reach. | Audit | fixed (tool) |
| P7-0004 | minor | Audit tool | Tree colliders counted after a full clear without rebuilding the streamed collision cells. | The fixture now rebuilds the collision cells from the cleared data before counting. | Audit fixture | fixed (tool) |

## Checked and clean (no issues)

- 12,000 tree roots: 0 floating, 0 in water, 0 over-buried, 0 on rocks, 0 without a cutting stand.
- 598 rocks: 0 floating.
- 43 grounded anchors (beds, seats, couch, arcade, hiding, dog bed/refuge/approach, ship boarding, safe reset, footlockers, worker spawns): all supported.
- 10 camera mounts: supported; rock mounts sit on grounded rocks.
- Ground cover near camp: 0 instances inside buildings, 0 in deep water.
- Reachability: every original tree has a cutting stand plus a retreat cell connected to camp (stumps share the stand) in the original forest and at 25/50/90/99/100 % cleared.
- Facilities from the camp yard: all six cabin beds, both arcade spots, the table seats, footlockers, the rack/drop-off, the dock gangway and the dog refuge approach; every hiding entry (authored routes for the private camper and utility building).
- Dog: the camper flap route and a valid 60–150 m rescue spot exist.
