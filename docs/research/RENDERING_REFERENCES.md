# Rendering references (owner-supplied)

## "Why 3D Games Look Bad in Godot" (Coding Quests, YouTube)
- **Link:** https://www.youtube.com/watch?v=0792U-wuwjA (supplied by the owner on 6 Nov 2026 "for the future").
- **Access status:** the title and channel came from YouTube's public oEmbed endpoint. The watch page itself returned a captcha to this cloud container, so the video and its captions were **not** seen. Its specific recommendations are not recorded here, and nothing below claims to come from it.
- **Follow-up:** when the owner shares the key points, or a transcript is reachable, compare them item by item with the audit below and record any changes here.

## Audit against the common Godot 3D quality checklist (6 Nov 2026)
| Area | Project state | Where |
|---|---|---|
| Renderer | Forward+ | `project.godot` |
| Tonemapping | Filmic, with AgX selectable in settings; colour adjustment on | `scripts/lighting/environment_controller.gd` |
| Ambient occlusion and indirect light | SSAO from Medium up; SSIL from High; SDFGI on Ultra | `environment_controller.gd` (quality tiers) |
| Fog | Depth and height fog; volumetric fog on High and Ultra | `environment_controller.gd` |
| Glow / bloom | On (bloom setting) | `environment_controller.gd` |
| Directional shadows | 4096 atlas, soft-shadow filter quality 3 (highest) | `project.godot` |
| Positional shadows | 4096 atlas | `project.godot` |
| Anti-aliasing | TAA plus FXAA; MSAA off (foliage alpha) | `project.godot` |
| Texture filtering | Anisotropic 8x (level 3) | `project.godot` |
| Sky and ambient | Custom sky shader; ambient from sky; time-of-day exposure profiles | `shaders/sky.gdshader`, `environment_controller.gd` |
| Water | Phase 24 stylized optics (see `STYLIZED_WATER.md`) | `shaders/include/water_shading.gdshaderinc` |
| Characters | Phase 24 HD-2D baked directional sprites lit by scene lights | `scripts/characters/pixel_actor.gd` |

Captures in this container use a software renderer (Mesa lavapipe), so final visual judgements need the owner's GPU.
