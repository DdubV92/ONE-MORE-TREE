# Phase checklist

Legend: ✅ implemented and checked (test, smoke or render) · 🟡 implemented, only partially verified · ⛔ not done

## Phase 0: Build the island we want to live on

### A. Technical foundation and scale

| Item | Status | Notes |
|---|---|---|
| Godot 4.5.1, Forward+, typed GDScript, meters, +Y up | ✅ | Pinned in project.godot, CI and ARCHITECTURE.md |
| CI: import, determinism, tests, bounded smoke test | ✅ | First run green on GitHub Actions |
| Windows x86_64 export with matching templates, ZIP artifact | ✅ | CI run #1 produced `OneMoreTree-windows-x86_64-phase-0-island-1` (242 MB). Not launched on real Windows by me. |
| No engine binaries or `.godot` cache committed; no Blender dependency | ✅ | |
| Deterministic, idempotent generation; frozen world manifest | ✅ | `--check` verifies hashes in CI |
| Title screen, Preview Tour (Camp, Beach, Forest, River/Pond, Character Preview; Day/Sunset/Night) | ✅ | Plus camper, cabin, shallows, rapids, pond 2, ridge, coast, and a benchmark |
| Standalone character preview (orbit, zoom, playback) | ✅ | |
| Preview never writes saves or alters campaign state | ✅ | Tested |
| Diagnostic report (build, engine, preset, errors, sanitized paths) | ✅ | Tested |
| Exploration controller: pause, mouse capture, sensitivity, collision, slopes, steps, reset-to-safe | ✅ | Bridge/wading bug found by the traversal tool and fixed |
| Island: ~1,600×1,200 m footprint, 0.9–1.2 km² land, ~12,000 trees | ✅ | 1,552×1,060 m, 1.17 km², exactly 12,000 trees |
| Terrain: landing beach, camp approach, rises, rocky ridge, fern lowland, pond basins, river corridor; no cliff ring; no square water edge | ✅ | Ocean mesh runs to a 30 km horizon |
| Elevation service shared by placement, water, physics, footsteps | ✅ | Triangle-exact; tested |

### B. Water

| Item | Status | Notes |
|---|---|---|
| Vertex-displaced Gerstner ocean, LOD tessellation, shared time/wind, CPU height mirror | ✅ | |
| Depth absorption, fresnel, guarded refraction, sky reflections, caustics, restrained glints | 🟡 | Rendered on a software GPU. Needs a real-GPU look. |
| Shoreline swash, broken foam (swash edge, breaking band, rocks, flecks), beach masks | 🟡 | Visible in renders. Motion is best judged live. |
| Wet sand driven by the swash function, with drying lag | 🟡 | Same function as the water. Judge in motion. |
| Two ponds and a downhill river with flow and whitewater at grade changes | ✅ | River/pond invariants tested; renders checked |
| Ripples from wading and the F7 test, pooled and rate-limited | 🟡 | Logic verified headless; visual not captured |
| Wading limit with gentle push-back, no dry-land walls; bridges | ✅ | |
| Timber-recovery interface reserved | ✅ | `WaterSystem.surface_height_at` / `depth_at` |

### C. Woodland and ground

| Item | Status | Notes |
|---|---|---|
| Three species × three variants, stable IDs and metadata | ✅ | |
| Clustered distribution, exclusions (camp, trails, water, bridges, rocks) | ✅ | Tested |
| Instanced chunks, LOD, limited shadows, wind, removal by ID | ✅ | Removal tested |
| Chunk-managed trunk collision | ✅ | |
| Tree inspector (F6) | ✅ | |
| Ground: sand, damp/wet sand, grass, needles, leaf litter, dirt, moss rock, rock, gravel, pebbles, mud; multi-scale anti-tiling | ✅ | |
| Streamed grass, ferns, bushes, reeds, dune grass, pebbles | ✅ | |

### D. Camp

| Item | Status | Notes |
|---|---|---|
| Clearing, ~2 m chain-link fence, wide forest entrance, exterior lamps | ✅ | |
| Camper: kitchen, bathroom (with door), bedroom with player bed, dog bed, woods-facing windows, real entrance | ✅ | |
| Cabin: exactly four beds with storage, table, clutter zones, arcade corner, porch | ✅ | |
| Burn pit: stones, ash, loading approach, particle fire, light, sound, placeholder interaction | ✅ | Prompt 2 adds fuel |
| Tool rack with small/medium/large axes, props, anchors for payroll/shop/workers | ✅ | |

### E. Light, atmosphere, post, sound

| Item | Status | Notes |
|---|---|---|
| Day, sunset, night, overcast, dawn/dusk, and warm-interior blend; time slider | ✅ | |
| Dynamic GI strategy: sky + SSAO + SSIL; SDFGI on Ultra; no lightmaps | ✅ | |
| Tone mapping, bloom, AA (TAA + FXAA), optional DOF, CA (default 0), vignette, grading, separate toggles | ✅ | |
| Local heat haze over the fire | ✅ | |
| Heat haze over hot sand at midday | 🟡 | Up to 24 bounded shimmer quads on dry beach sand, scaled by the preset's `heat_haze` (Day = 1, others 0) and the comfort toggle. Subtle by design; judge on a real GPU. |
| Spatial audio: listener on camera, nearest-shore ocean, river/pond, wind/leaves, pooled birds with silence, fire, creaks, room tone, buses, interior filtering | 🟡 | Logic runs. Sounds are procedural placeholders, and direction and quality were not listened to (no audio device here). |

### F. Characters

| Item | Status | Notes |
|---|---|---|
| Human rig spec and four distinct worker looks | ✅ | Rigid-part articulation (not skinned) |
| Dog rig: articulated legs, head, ears, tail | ✅ | |
| Human idle, walk, axe-swing preview; dog idle, walk, lie/sleep | ✅ | Foot contact tested |
| Attachment points; in-place convention; frame-rate independent | ✅ | |
| Dog in camp by day, inside at night, cannot be harmed or lost | ✅ | |

### G. Completion gates

| Item | Status | Notes |
|---|---|---|
| Representative screenshots | ✅ | `docs/screenshots/`, software-rendered |
| 10-minute walkthrough | ✅ | REVIEW_GUIDE.md |
| Repeatable performance route | ✅ | Benchmark button |
| 60 FPS measured on a midrange GPU | ⛔ | Not measurable here. Please run the benchmark. |

## Known limitations (exact)

1. **No real-GPU verification.** Everything visual was checked on a software renderer. Frame rate, shader cost, TAA ghosting, and the exact look of water, foam and heat haze still need your review on real hardware.
2. **Audio is synthetic.** All sounds are procedural placeholders. 3D direction (left/right, front/back) is set up through `AudioStreamPlayer3D` on a camera-mounted listener, but nobody has listened to it yet.
3. **Characters are stylized primitives.** They use rigid parts, not a skinned mesh. Faces have eyes, brows and a mouth, but no facial animation beyond blinking. A licensed rigged GLB can replace them later behind the same API.
4. **Trees use cards.** Pine crowns read as clumpy up close, and the far LOD is a solid silhouette.
5. **Sand heat haze is placement-based.** It appears only near the placed beach quads, not on every hot surface.
6. **No planar or SSR water reflections.** Water reflects sky radiance only, so trees and the camp aren't mirrored in ponds.
7. **Dog movement ignores physics.** The dog walks straight lines between authored camp points, avoiding a few obstacle circles. It is visual only.
8. **Windows SmartScreen.** The Windows build is unsigned and will show a SmartScreen warning.
9. **First launch may stutter.** Shader compilation on first launch can stutter for a few seconds (Godot's shader cache warms after that).
