# Stylized water research (Phase 24)

Source studied (owner request): "Creating a Stylized 3D Water Shader", gameidea.org, 1 Feb 2026 (Godot 4.6 spatial shader tutorial; the finished shader is also sold on the author's asset store). Read on 6 Nov 2026.

## Provenance and licence decision
- We use the **techniques**, not the code. The shader is written from scratch for our ocean and inland water.
- The tutorial's wave/height function (`sea_octave` with `octave_m`) is a known adaptation of a Shadertoy sea shader licensed CC BY-NC-SA. We do **not** use it. Our ocean keeps its own swell, Phase 8 shore breakers and Phase 23 `sea_state`.

## Techniques adopted
| Technique | What it does | Our use |
|---|---|---|
| Linear depth behind the surface | `bg_linear_depth - water_linear_depth` gives the water thickness a ray travels through. | Drives everything below (shallow vs deep, foam, caustics, absorption). |
| Screen-texture refraction | Offsets `SCREEN_UV` by the detail normal minus the base normal, scaled down with distance and with thin water. | Crystalline shallows. Ghosting fix: when the distorted sample's depth is in front of the water, fall back to the undistorted UV. |
| Beer-Lambert absorption | `transmittance = exp(-thickness * absorption_rgb)`. Red is absorbed first. | Turquoise shallows to deep teal, tuned to the reference art. |
| Seabed caustics | Reconstruct the seabed world position from depth; two scrolling patterns multiplied; fade with thickness. | Procedural caustics (no texture), shown only in direct sun (our `daylight`, `sun_clarity`, rain). |
| Voronoi foam | Warped, animated Voronoi FBM; shoreline (thin water) plus crests (normal.y below a threshold); an offset sample gives a darker foam edge; inner Voronoi bubbles. | Shoreline and rock foam, whitecaps rising with `sea_state`. |
| Normal LOD | Detail-normal epsilon grows with distance; blends to the base normal far away. | Kills distant shimmer and specular aliasing. |
| Underwater quad | Full-screen effect below the surface. | Not needed: the player never dives. Noted for later. |

## Pixel-art fit (HD-2D direction)
- Quantize the foam and caustic masks to a few levels (cel bands) so they read as hand-placed clusters.
- Keep refraction and absorption smooth: the reference image's water is crisp, clear and turquoise, not posterized.

## Implementation (Phase 24, done before the HD-2D art conversion)
All in `shaders/include/water_shading.gdshaderinc` (shared by `ocean.gdshader` and `inland_water.gdshader`):

| Piece | Function | Notes |
|---|---|---|
| Vertical thickness | `scene_world_at()` | Reconstructs the world position behind the water from the depth buffer (`INV_PROJECTION_MATRIX`, `INV_VIEW_MATRIX`). Sampled at the refracted UV for colour and at the plain UV for contact foam. |
| Crystal shallows | `stylized_body()` | Beer-Lambert on the view path, plus a `shallow_tint` that settles in over `shallow_depth` metres and an inscatter ramp from `shallow_scatter` (aqua) to `scatter_color` (deep) over `scatter_ramp_depth`. |
| Contact foam | `contact_foam_at()` | Warped, drifting Voronoi network; the dissolve threshold rises with depth, so foam breaks into lace instead of fading as a band. A sample offset along the sun gives the darker foam-edge rim on the water body. Ocean beaches use 25 % of the width (their swash foam already covers the waterline). |
| Cel foam | `foam_cel()` | Three flat tones (0, 0.55, 1) with narrow smooth steps to avoid aliasing. `foam_bands = 0` restores smooth foam. |
| Sparkles | `sun_sparkle()` | Sharp sun-mirror lobe gated by a cell hash; daylight, sun clarity and distance limited. |
| Crest glow (ocean) | in `ocean.gdshader` | Looking toward the sun through raised crests adds `crest_glow` translucency. |
| Backwash lace (ocean) | in `ocean.gdshader` | A two-octave warped Voronoi bubble net. It replaces ridge noise, which filled in as solid paper-white scraps on calm shallows (found with a per-term colour-channel debug render). |

Seabed caustics were already drawn by `terrain.gdshader` and `rock.gdshader` underwater, so the refraction carries them; the water shader does not add a second copy.

Per-material looks are set in `scripts/water/water_system.gd`:
- Ocean: shader defaults (turquoise shallows, teal deep).
- Ponds: clearer, green-tinted; foam is a thin line at the reeds and banks.
- River: clear aqua; foam at stones and banks.

Cost: two extra depth reads per water pixel. Contact foam (two Voronoi evaluations) runs only within 160 m (ocean) or 120 m (inland), and only where the water is thinner than the foam width.

Before/after captures (lavapipe, `day:shallows@40`, `day:pond@40`, `day:river@40`, `day:coast_day@40`, `sunset:surf@40`) are listed in the Phase 24 notes.
