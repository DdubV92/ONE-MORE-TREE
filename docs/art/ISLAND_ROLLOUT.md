# Island rollout of the reference cove's detail (Phase 24)

The look the owner chose in the reference cove (a rich, detailed, full-resolution world with pixel-art characters) is applied island-wide. The before/after previews are in `island_before_after/`. Each image has the previous look on top and the new look underneath.

## What changed
| Area | Change | Where |
|---|---|---|
| Daylight | Richer colour and contrast, slightly warmer, less haze, more cloud, a deeper blue sky | `config/lighting/day.tres` |
| Sunset | Deeper orange horizon, more saturation and contrast, less haze, more lit cloud | `config/lighting/sunset.tres` |
| Golden hour | As tuned for the cove | `config/lighting/golden.tres` |
| Sea everywhere | Clear, saturated turquoise shallows; a caustic light net on shallow sand and stones; wider foam where water meets rock; soft, frothy foam (no flat cel slabs) | `shaders/ocean.gdshader`, `water_shading.gdshaderinc`, `water_system.gd` |
| Shores | Dark stones in the shallows and on wet sand along sandy and rocky coasts. They are visual only (never block walking or boats) and stay clear of the dock | `scripts/vegetation/ground_cover.gd` |
| Forest edges | Fuller, layered ferns and red-berry bushes | `ground_cover.gd` |
| Camp trailer | Cream body with the painting's red stripe (was teal) | `scripts/camp/build_kit.gd` |
| Characters | Pixel-art crew, dog and first-person axe enforced; F8 compares the old characters | `scripts/core/settings.gd` |

Frozen world data (`data/world/*`, `data/world/r2/*`) is untouched. Everything above is runtime dressing, materials or lighting.

## Reverting
The revert point is commit `2edca55` (pushed on `phase-24-hd2d-mill`), the state the owner reviewed before the rollout. A full archive of that state is also at `/home/user/backups/one-more-tree-pre-island-rollout.tar.gz` (in the build container), and a local tag `backup/pre-island-rollout` points to it.
- **Undo only the rollout,** keeping any later work:
  ```bash
  git revert <rollout commit>
  ```
- **Return the whole tree to the reviewed state:**
  ```bash
  git checkout 2edca55 -- .
  ```
  Then commit.
- **Keep the rollout but turn off the enforced pixel characters:** set `Settings.REVIEW_ENFORCE_HD2D = false`.
