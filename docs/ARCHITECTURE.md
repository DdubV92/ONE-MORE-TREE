# Architecture

## Engine pin

- Godot **4.5.1-stable**, renderer **Forward+**, physics **Jolt**. The pin lives in `project.godot`, `.github/workflows/ci.yml` (`GODOT_VERSION`), and here.
- Do not upgrade mid-pack. An upgrade needs a demonstrated need plus a migration pass: re-import, tests, smoke test, and screenshot comparison.

## Units and axes

Meters. **+Y up, +X east, +Z south (toward the landing beach), −Z north (forest entrance).** Characters face −Z, and their left is −X.

## Modules (ownership)

| Area | Script(s) | Owns |
|---|---|---|
| Autoloads | `core/game.gd` (Game), `core/settings.gd` (Settings), `core/diagnostics.gd` (Diag), `world/world_data.gd` (World) | Mode, shared `world_time`; options plus audio buses; error log and reports; frozen world data and the elevation/water/mask query API |
| World generation | `world/world_config.gd` + `config/world_config.tres`, `world/island_generator.gd`, `tools/generate_world.gd` | Authored island description, then deterministic data in `data/world/` |
| Terrain | `world/terrain_system.gd`, `shaders/terrain.gdshader` | Chunked GPU-displaced terrain, 3 LODs with skirts, `HeightMapShape3D` collision from the same samples |
| Water | `water/water_system.gd`, `shaders/ocean.gdshader`, `shaders/inland_water.gdshader`, `shaders/include/*` | Ocean (Gerstner), swash/foam, river ribbon, ponds, ripple pool, CPU wave mirror, depth queries |
| Bridges | `world/bridge_builder.gd` | Walkable crossings at reserved sites |
| Vegetation | `vegetation/tree_builder.gd`, `vegetation/vegetation_system.gd`, `vegetation/ground_cover.gd`, `vegetation/rock_builder.gd` | Tree meshes; per-chunk MultiMesh LODs; collision streaming; removal by ID; ground-cover streaming; rocks |
| Camp | `camp/camp_layout.gd` (single source of placement), `camp/camp_builder.gd`, `camp/fire_pit.gd`, `camp/camp_lamp.gd`, `camp/interior_zone.gd`, `camp/build_kit.gd` | Fence, lamps, burn pit, camper, cabin, tool area, anchors, interior zones |
| Lighting | `lighting/environment_controller.gd`, `lighting/lighting_preset.gd`, `config/lighting/*.tres`, `shaders/sky.gdshader` | Sun/moon/sky/ambient/fog/exposure/wind/post; keyframe blending by hour |
| Audio | `audio/ambient_audio.gd`, `tools/generate_audio.gd` | Emitter pools, zone filtering, footsteps; generated placeholder sounds |
| Player and UI | `player/player.gd`, `ui/*` | Controller, HUD, pause/settings, Preview Tour, benchmark, title |
| Characters | `characters/*` | Human and dog rigs, clip generation, preview scene, camp dog |
| Systems | `systems/safety_service.gd`, `systems/later_interfaces.gd`, `save/save_service.gd` | Authoritative safety; documented future interfaces; versioned saves |

| Logging (Phase 1) | `logging/tree_service.gd`, `logging/tree_actor.gd`, `logging/tree_work_config.gd` + `config/tree_work.tres`, `logging/logging_fx.gd`, `logging/logging_test.gd` | Tree states, work, TreeFelled, actor handoff, notch/fall/stump, pooled sounds/particles |
| Player tools | `player/axe_controller.gd`, `player/view_model.gd` | Swing state machine, contact-timed probe, first-person arms + axe |
| Placement | `systems/placement_validator.gd` | Grounding audit, cutting stands |
| Campaign data | `systems/campaign_rules.gd`, `crew/*`, `config/traits/*.tres` | Fixed contract numbers, trait/employee data (no behaviour yet) |
| Reservations | `camp/camp_reservations.gd` | Camera mounts, footprints, dock |

`world/world.gd` (IslandWorld) builds everything in order and registers services on `Game`.

## Frozen world layout

- The generator is deterministic. It uses `FastNoiseLite` with fixed seeds, integer hashing, and output quantized to 1 cm / 1 mm.
- Its output is **committed** in `data/world/` as zstd-compressed binaries plus `manifest.json` (seed, generation version, config fingerprint, content hashes, measured stats) and `layout.json` (river samples, ponds, bridges, shore audio points).
- The runtime only loads this data. CI regenerates it in memory and fails if any hash differs. Cosmetic code edits therefore can never silently move trees.
- To change the island intentionally:
  1. Edit `config/world_config.tres` or the generator.
  2. Bump `generation_version`.
  3. Regenerate.
  4. Accept that save files store felled tree IDs against the old version. A migration is required before shipping.
- **Tree records:** `id` (stable, sorted by vegetation chunk then z/x), `species` (0 pine, 1 spruce, 2 birch), `variant`, `chunk` (128 m cells), `x`, `z` (height comes from the elevation service), `rot`, `height`, `radius`, `lean_x`/`lean_z`, `logs` (future wood budget), `seed`.
- **Elevation service:** `World.height_at(x, z)` is triangle-exact against the LOD0 mesh (diagonal `(i,j)-(i+1,j+1)`). Rendering, collision, tree placement, water depth, footsteps and future logging all use it.

## Water regions

- **Ocean:** sea level 0.
- **River:** `layout.json → river.samples` hold x, z, level, width, rapid, arc. Levels are a running minimum of (ground − 1.05 m), with authored riffle steps. They never rise downstream and reach the sea at 0.04 m.
- **Ponds:** each has a fixed level and a closed rim (tested).
- **Region map:** `water_region.bin` marks 0 = ocean/none, 1 = river, 2+ = pond.
- **Shared wave model:** the Gerstner sum lives in `ocean.gdshader`, with a CPU mirror in `WaterSystem.ocean_height_at`. The swash (run-up) function lives in `world_common.gdshaderinc` and is used by both the ocean and the terrain wetness.
- **Reserved:** `WaterSystem.surface_height_at` / `depth_at` serve the future TimberRecoveryService.

## Rendering strategy and limits

- **Indirect light:** sky ambient + SSAO + SSIL (dynamic, nothing baked), with SDFGI on Ultra only. No lightmaps, because the forest is removable.
- **Water reflections:** sky radiance only. Screen-space reflections don't apply to transparent water, and there is no planar reflection.
- **Refraction:** screen texture with a depth guard that rejects samples of anything in front of the water.
- **Trees:** per 128 m chunk MultiMeshes, one per species/variant.
  - Near LOD: alpha-scissored needle/leaf cards, casting shadows.
  - Mid LOD: fewer cards, no shadows.
  - Far LOD: solid silhouettes.
  - Visibility ranges cross-fade the LODs, and chunk nodes sit at chunk centers because ranges are measured from the instance origin.
- **Grass/ferns/bushes:** streamed in 32 m cells within about 96 m.

## Characters

- **Rigid-part articulation, not skinning.** Each body part is a mesh attached to a pivot at an anatomical joint, and overlapping rounded limb ends prevent gaps. No `Skeleton3D`/`Skin`.
- **API** (stable for later AI): `play(name, blend)`, `set_locomotion(speed)`, `attachment("hand_r" | "hand_l" | "log" | "look")`, `bones` dictionary.
- **Clips:** generated in code into an `AnimationLibrary` and played by an `AnimationPlayer` advanced manually each frame, which keeps them frame-rate independent.
  - Human: `idle`, `walk`, `swing` (preview, non-functional).
  - Dog: `idle`, `walk`, `lie`.
  - Walk legs are IK-baked so stance feet stay planted and stride matches the nominal speed (tested).
  - Swing moves an axe along a designed arc and solves both arms to its grips at runtime.
- **In-place convention:** the mover translates at `WALK_NOMINAL_SPEED × playback_scale`.
- **AnimationTree is not used yet.** Crossfades come from `AnimationPlayer` blend times. A state machine can wrap the same clips later without changing the API.

## Safety rules (published = implemented)

`SafetyService.query(point)`:
1. Inside the camper interior zone (`always_safe`) → **safe** (`CAMPER_INTERIOR`), regardless of lamps.
2. Otherwise, inside the camp fence **and** within `safe_radius` of a `CampLamp` whose `working == true` → **safe** (`CAMP_LAMP`).
3. Everything else → **unsafe**.

The fire, flashlights, moonlight, emissive objects and screen brightness are never consulted. The cabin is not an automatic refuge, but a lamp covers its porch and most of its interior. Lamp positions and radii live in `CampLayout.LAMPS`. Tests cover the camper with every lamp broken, the yard with lamps broken and working, the forest and the beach.

## Anchors for later prompts

Marker3D nodes in these groups:
- `worker_bed` (4), `worker_seat` (4), `worker_spawn` (4)
- `arcade_spot` (2), `clutter_zone` (4), `worker_storage` (4)
- `player_bed`, `dog_bed`
- `shop_counter`, `payroll_anchor`, `burn_pit_load_point`
- `safe_reset`, `player_spawn`, `camp_entrance`
- Axes on the rack are in group `rack_axes`.

## Modes and saves

- `Game.Mode`: `MENU`, `CAMPAIGN`, `PREVIEW`. Preview Tour, the Character Preview and the benchmark run in PREVIEW, and `SaveService.save_campaign` refuses to write in any mode except CAMPAIGN (tested).
- **Save schema v2** (Phase 1) adds `trees` (modified trees by ID: state, work, cut side, fall direction, felled guard, trunk pose/velocity), `equipment`, and reserved `campaign` / `economy` / `timber` blocks. v1 saves migrate to a labeled **legacy** campaign. Saving keeps the previous good file as `.bak`; an unreadable main save falls back to the backup and is left on disk.
- **Save schema v1** (Phase 0) (`user://saves/campaign.json`, written atomically through a `.tmp` + rename):

```json
{
  "schema": 1,
  "world": {"seed": 20261103, "generation_version": 1},
  "player": {"position": [x, y, z], "yaw": 0.0},
  "time_of_day": 13.0,
  "felled_trees": [ids...],
  "economy": {"funds": 0, "axe_tier": "small", "workers": []},
  "timber": {"logs": [], "burned": 0},
  "horror": {"exposure": 0.0},
  "build": "0.0.1-phase0 (commit)"
}
```

Migration lives in `SaveService.migrate`: v0 dev saves are upgraded, and future schemas are rejected (an empty result is treated as "no save").
