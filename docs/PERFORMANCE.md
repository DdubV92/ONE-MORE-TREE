# Performance

**Target:** 60 FPS at 1080p on a midrange desktop (High preset). This is a target, **not a measured result**. Development happened in a cloud container with a software Vulkan renderer (Mesa llvmpipe/lavapipe, CPU only). Frame rates there run at about 1 FPS and say nothing about real GPUs, so no FPS claim is made here.

## What was measured (renderer-independent counts, 1920×1080, High preset)

Counts come from `tools/capture_views.tscn` using Godot's `Performance` monitors, after static camp batching. Draw calls include shadow passes.

| Viewpoint | Draw calls | Primitives | Objects | Tree colliders active | Physics active bodies |
|---|---|---|---|---|---|
| coast_day (beach looking along the coast) | 367 | 2.09 M | 506 | 31 | 0 |
| shallows (looking out to sea) | 52 | 1.53 M | 85 | 9 | 0 |
| forest (dense woodland) | 785 | 4.30 M | 907 | 339 | 0 |
| river + bridge | 1527 | 6.55 M | 2033 | 200 | 0 |
| camp (clearing, buildings, lamps) | 1906 | 7.34 M | 2616 | 154 | 0 |

Before batching, the camp view issued 3667 draw calls. Merging static camp/bridge primitives by material (`BuildKit.batch_static`) removed 531 separate meshes.

- **VRAM in use:** about 0.92 GB, reported by the software renderer. Expect a similar texture footprint on GPUs.
- **Build time on this container's 4-core CPU:** world data load about 0.04 s; terrain 0.6 s; water 0.25 s; vegetation (12,000 trees into MultiMeshes) 1.1–1.4 s; camp 3.7–4 s; total about 6–7 s behind the "Building the island..." screen.

## Traversal (measured with the real player controller, headless, 60 Hz physics)

`tools/measure_traversal.tscn` walks the player along fixed routes. Collision with trunks, rocks and bridges is active.

| Route | Distance walked | Time at walk speed (4.2 m/s) |
|---|---|---|
| Camp → western pond (trail 1) | 419 m | 1.7 min |
| Camp → east bridge (trail 2, crosses the river on the bridge) | 406 m | 1.6 min |
| West coast → east coast (long axis, cross-country) | 1473 m | 6.6 min |

## How to measure on your machine

- **Live stats:** press **F3** in game for FPS, avg/p95/p99 frame time, draw calls, primitives, physics and VRAM.
- **Benchmark:** Preview Tour → **Run 60 s benchmark route** (coast → shallows → river → forest → camp → camper). The result goes into a diagnostic report with the average, p50/p95/p99 and worst frame time, plus average draw calls. Send that report back.

## Budget levers by preset (none change the island seed, tree count or rules)

| Lever | Low | Medium | High | Ultra |
|---|---|---|---|---|
| Sun shadow distance / splits | 80 m / 2 | 120 m / 4 | 160 m / 4 | 220 m / 4 |
| SSAO / SSIL / SDFGI | off/off/off | on/off/off | on/on/off | on/on/on |
| Tree near / mid LOD range | 110 / 380 m | 140 / 480 m | 170 / 560 m | 220 / 700 m |
| Mid-LOD tree shadows | off | off | off | on |
| Terrain LOD range scale | 0.7 | 0.85 | 1.0 | 1.3 |
| Ground-cover density | 0.35 | 0.65 | 1.0 | 1.4 |
| Ocean grid (vertices per side) | 160 | 240 | 320 | 400 |
| Fire light shadows | off | on | on | on |

Render scale (0.5–1.0) is a separate setting.

## Known costs and next optimisations (if real-GPU numbers demand them)

| Area | Cost | Possible fix |
|---|---|---|
| Water | Ocean, river and ponds sit in the transparent pass with screen/depth reads, roughly 1–2 full-screen texture fetches when water fills the view | — |
| Shadows | Near trees cast alpha-scissored card shadows across 4 PSSM splits, the biggest shadow cost in forest views | Fewer splits or a shorter distance at Medium |
| Post | SSAO + SSIL at High; TAA always on | — |
| Ground cover | About 37 streamed 32 m cells × up to 6 MultiMeshes; Poly Haven ferns are about 6k triangles each (range trimmed to 50 m) | A card-based fern |
| Terrain | 3 LOD MeshInstances per 64 m chunk, about 400 chunks (culled by visibility range) | Merge far LOD into fewer, larger meshes |
| Props | glTF props remain separate objects | Atlas or merge |
