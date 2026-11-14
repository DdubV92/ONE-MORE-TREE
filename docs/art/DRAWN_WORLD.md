# Drawn world: the anime-illustration look (Phase 24)

Art direction: the owner's painting, `reference_target.png`. The world should read as a hand-drawn, painted illustration that the player walks through in 3D, with the pixel-art characters living inside it.

## The hand-drawn pixel world (current default, 14 Nov 2026)

Owner request: the world should look more anime and pixel-drawn so it matches the pixel-art characters, as if hand-drawn in a 3D space, and it must stay **sharp and easy on the eyes**. Effects that blur the picture were dialled back.

`world_style: "drawn"` is now the default. The earlier smooth painted look is still there as `"anime"`, and `"3d"` is the plain render.

| What changed | How | Why |
|---|---|---|
| The world is drawn on the characters' pixel grid | The 3D world renders at about 450 art-pixel rows (`drawn_rows`): 2 screen pixels per art pixel at 720p and 1080p, 3 at 1440p. Each art pixel is shown as a crisp block (no smoothing, no temporal or FXAA anti-aliasing) | The crew, dog, deer and gulls are pixel sprites. On one grid they belong to the scene instead of standing in front of a smooth painting |
| Firm ink lines | The line pass works in whole art pixels: one hard pixel wide, colour-tinted, on silhouettes and close strong creases only | Line art that reads as drawn, without filling near objects with ink |
| Flat cel tones | Four hard tone steps instead of five soft ones | The few-tone shading of drawn backgrounds |
| Sharp first | The paint brush is the smallest size and keeps 45% of the surface detail under it (was a broad brush keeping 30%); bloom haze is off and glow is at 35%; sun shadows have hard edges; the vignette is halved | Nothing in this style should smear the picture |
| No moving patterns | The optional line wobble is **off** by default (`ANIME_BOIL` for captures). Pencil hatching only appears in the very darkest tones, its threshold falls with the daylight so dusk is not hatched all over, and it is anchored to the view direction so it turns with the world | Flicker and screen-stuck textures tire the eyes |
| Menus and text | Unchanged: the HUD, Journal and prompts draw at full resolution above the world | Reading must stay crisp |

Before and after (software-rendered at 720p; `pixel_camp_day_1080p.jpg` shows the real grid at 1080p): `drawn_world/pixel_camp_day_before_after.jpg`, `pixel_forest_day_before_after.jpg`, `pixel_deer_day_before_after.jpg`, `pixel_camp_night_before_after.jpg`, `pixel_beach_day_before_after.jpg`, `pixel_camp_sunset.jpg`.

Known limits:
- Judged from still images only. Nobody has watched it in motion on a real GPU; thin things at a distance (the chain-link fence, far foliage) may shimmer as you move, which is the main comfort risk left. If they do, raise `drawn_rows` (Settings → Drawn world pixel rows, up to 540) or switch World art style to `anime`.
- Painted signs in the world (for example the lamp locker's lettering) are not readable from far away at this grid. Prompts and the Journal are unaffected.
- Water, smoke and glass are drawn after the ink pass: they are on the pixel grid but not tone-stepped.
- Revert point: commit `3a0c439` (local tag `pre-handdrawn-pass`), archive `/home/user/backups/one-more-tree-phase-28c.tar.gz`. Without reverting: Settings → World art style → `anime`.

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
- `world_style`: `drawn` (default, the hand-drawn pixel world), `anime` (the earlier smooth painted world), `3d` (plain render), `hd2d` (the pixel filter alone).
- The review build enforces `drawn` with pixel characters. **F8** flips the world to the plain 3D render and back for comparison; it is never saved.
- Low quality uses a smaller brush. Tuning for captures: `ANIME_<PARAM>=value` (for example `ANIME_INK_STRENGTH=0.6`).

## Sources checked
Technique survey (Godot 4 toon shading, depth/normal post-process outlines, Kuwahara painterly filters): godotshaders.com listings and Godot forum threads found by search. The Godot documentation site and godotshaders.com pages themselves were not reachable from the build container, so the shader here is an own implementation of those standard techniques.

## Reverting
- Revert point: commit `85efd32` (the island rollout), archive `/home/user/backups/one-more-tree-pre-anime-style.tar.gz` in the build container.
- Turn it off without reverting: set `"world_style"` default to `"3d"` and stop enforcing it in `Settings.sanitize()`; or press F8 in the review build.
