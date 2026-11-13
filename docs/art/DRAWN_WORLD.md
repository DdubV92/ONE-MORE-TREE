# Drawn world: the anime-illustration look (Phase 24)

Art direction: the owner's painting, `reference_target.png`. The world should read as a hand-drawn, painted illustration that the player walks through in 3D, with the pixel-art characters living inside it.

## Previews
`drawn_world/` holds the comparison images (software-rendered): `cove_compare.jpg` (the painting, the cove before, the cove drawn), `cove_first_person.jpg`, `cove_gameplay.jpg` (in game, with the pixel axe and HUD), and before/drawn pairs for the camp by day and at sunset, the beach, shallows, coast, forest and river.

## How it works
The world is still lit and rendered as normal 3D. One extra pass then redraws each frame as an illustration. It is a full-screen quad placed in the 3D scene (`scripts/lighting/anime_pass.gd`, `shaders/anime_ink.gdshader`), because only a 3D shader can read the depth and surface-direction buffers that line drawing needs.

| Step | What it does | Why |
|---|---|---|
| Paint | An edge-preserving brush filter (Kuwahara): of the four quadrants around a pixel, keep the average of the calmest. A share of the original detail (30%) is kept under it | Texture noise melts into brush-sized colour fills without blurring edges, and surfaces keep some richness |
| Tones | Light is gathered into five soft steps placed at band centres; shadows lean cool and gain a little colour | The few-tone shading of drawn backgrounds; shadows stay readable instead of going black |
| Ink | Dark, colour-tinted contour lines where depth breaks (silhouettes) or surface direction breaks (creases, edges). Lines thin and fade with distance | The line art |
| Sky | Clouds get a clean edge, a lit side facing the sun and a shaded body (`shaders/sky.gdshader`, `drawn`) | Shaped, drawn clouds |
| Shadows | Sun shadows are crisper | Clean shadow shapes |

Two markers keep the pass from damaging things:
- **Pixel-art actors** write roughness 0 (`pixel_actor.gdshader`). The pass leaves those pixels exactly as drawn, so sprites stay crisp.
- **Tree crowns** write roughness 0.04 with no specular (`tree_foliage.gdshader`, `tree_far.gdshader`). They get a silhouette line only, not ink on every leaf.

The pass draws before water, glass, smoke and other transparent things, so those keep their own shading on top of the painted world. Security-camera feeds skip it (own render layer). The first-person pixel axe is a separate overlay and is not touched.

## Settings
- `world_style`: `anime` (default, the drawn world), `3d` (plain render), `hd2d` (the optional pixel-world filter).
- The review build enforces `anime` with pixel characters. **F8** flips the world to the plain 3D render and back for comparison; it is never saved.
- Low quality uses a smaller brush. Tuning for captures: `ANIME_<PARAM>=value` (for example `ANIME_INK_STRENGTH=0.6`).

## Sources checked
Technique survey (Godot 4 toon shading, depth/normal post-process outlines, Kuwahara painterly filters): godotshaders.com listings and Godot forum threads found by search. The Godot documentation site and godotshaders.com pages themselves were not reachable from the build container, so the shader here is an own implementation of those standard techniques.

## Reverting
- Revert point: commit `85efd32` (the island rollout), archive `/home/user/backups/one-more-tree-pre-anime-style.tar.gz` in the build container.
- Turn it off without reverting: set `"world_style"` default to `"3d"` and stop enforcing it in `Settings.sanitize()`; or press F8 in the review build.
