# Reference cove: handoff

The owner's target painting (`reference_target.png`) built as one small, real, walkable place on island r2, before the style is applied across the island.

## How to open it
- **Title screen:** **Reference Match** or **First-Person Shoreline**. Both start a preview, and a preview never writes saves.
- **Review tour (Phase 24 stations):** `p24_ref_match`, `p24_ref_fp`.
- **Captures:** `godot res://tools/capture_views.tscn -- golden:ref_match golden:ref_fp`. In a container, use xvfb-run with Mesa lavapipe (see CLAUDE.md).
- **Uncut walk:**
  ```bash
  godot --write-movie ref_walk.avi --fixed-fps 24 --resolution 1280x720 res://tools/reference/walk_clip.tscn
  ```
- **First-person still at gameplay settings:** run the same scene with `REF_FP_SHOT=1`. It writes `captures/ref_fp_gameplay.png`.

## What is in the scene
- **Site:** the r2 cove at (-566, -281), heading 305°. The camp sits in front of the forest, the sea and beach are on the right, and the golden-hour sun is ahead-right.
- **Beach:** the real shore here is a 1:2 rock bank. `ReferenceCove._raise_beach()` fills it in memory and never lowers anything, so trees, undergrowth and rocks stay grounded. The fill creates:
  - a curving dry beach;
  - a wet swash band;
  - a shallow turquoise shelf.

  Terrain rendering, collision (`TerrainSystem.refresh_collision`), water depth, swash and surf (`SurfSystem.rebuild`) all read the same heights, so the beach is walkable and the surf breaks on the new contour. Shrubs and grass from the old bank give way to sand (undergrowth exclusion, ground-cover rebuild). The frozen `data/world` files are untouched, and everything is restored when the fixture leaves.
- **Camp:**
  - weathered cream-and-rust trailer (`worn_paint` shader) with amber windows, warm light pools, a lantern and stovepipe smoke;
  - plaid chair, campfire, stump and strapped log stack;
  - split-rail fence with a walk-through gap;
  - two foreground conifers, ferns and mossy rocks;
  - dark shore boulders at the waterline and in the shallows.
- **Characters:** the worker (EMP-01 look, swinging) and the dog are directional pixel sprites, baked at runtime from their 3D rigs. The rigs stay as shadow casters, so the sprites have contact shadows.
- **First-person axe and hands:** real pixel art. The viewmodel renders on its own layer into a 200-row SubViewport that mirrors the player camera, lit by the same sun and lamps. It is then shown with nearest texels, a one-texel dark outline and a slight posterise, under the colour grade and HUD. At rest it sits low in the lower-right corner, and the swing keyframes still land the head on the crosshair at contact.
- **Terror:**
  - In Reference Match, the comparison figure stands in the treeline.
  - In play, `TerrorDirector.reserve("REF-COVE", 0, "treeline_glimpse")` decides when it appears (4.5 s glimpses with a 900 s cooldown).

## Three largest visible differences (and the fix for each)
1. **Water optics at the shore.** The painting shows clear turquoise shallows with visible stones, caustic light and thick white foam lace around every rock. The game shows a flat cyan swash band with sun glare, because at this grazing golden-hour angle the Fresnel reflection dominates.
   - Fix: a shallow-water pass keyed to the beach mask.
     - Cap the reflection by depth (under about 0.8 m).
     - Raise transmission so the sand and stones read through the water.
     - Add projected caustics on the wet sand and seabed.
     - Thicken the contact-foam ring around rock silhouettes.
2. **Foliage density and painterly light in the forest.** The painting layers ferns, berry bushes and sunlit trunks, with warm rim light on every fern tip and readable detail in the dark forest. The game's forest interior is darker and flatter, and its card-based crowns read as clumps.
   - Fix:
     - Denser, larger fern and bush clusters along the camp edge and fence.
     - Back-lit translucency (SSS-style wrap) on fronds and needles toward the low sun.
     - A small fill light under the canopy.
     - Painted crown cards with lit edges in place of the current clumps.
3. **Hero detail on the trailer and the people.** The painting's trailer is highly detailed: door, lantern glow, trim, a strong rust band and a glowing interior. The worker and dog are large, chunky pixel characters. In the game, the trailer reads as a smooth capsule, and the sprites are small and dim at this distance.
   - Fix:
     - Model the trailer trim, door frame, wheel well and window frames.
     - Add a lit interior card behind the windows.
     - Raise the sprite bake resolution (cell size) for hero actors.
     - Add a warm key light on the chopping area so the worker and dog pop like the painting.

## Known gaps
- Every image here was rendered by a software renderer (Mesa lavapipe) in the build container. Real-GPU colour, shadows, TAA and frame time have not been seen.
- The local container has Windows export templates only. The native test build is Windows (local export, plus CI's artifact for each push). CI also exports Linux.
- The fixture is a comparison place, not a campaign location. A campaign never builds it.
