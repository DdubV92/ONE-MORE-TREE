# Asset provenance

Every asset in this repository is either **CC0 from Poly Haven** or **original to this project**, generated procedurally by code in this repository. Nothing requires Blender or any external DCC tool at build time, and there are no `.blend` files.

## Poly Haven (CC0 1.0, https://polyhaven.com/license)

- **Machine-readable record:** `assets/polyhaven/provenance.json` lists the asset, kind, authors, license, source URL and files.
- **Re-fetch:** `tools/fetch_polyhaven.py` downloads the set again (developer tool; players never run it).

**Models** (glTF, 1k textures), in `assets/polyhaven/models/`:

| Group | Assets |
|---|---|
| Fire and tools | stone_fire_pit, hatchet (small axe), wooden_axe_03 (medium axe), wooden_axe_02 (large axe) |
| Storage | wooden_crate_01, wooden_crate_02, wooden_bucket_01, Barrel_02, propane_tank, plastic_jerrycan |
| Furniture | Rockingchair_01, folding_wooden_stool, wooden_picnic_table, painted_wooden_chair_01, painted_wooden_cabinet, painted_wooden_nightstand, wooden_bookshelf_worn, old_bed_frame |
| Kitchen and clutter | pot_enamel_01, plastic_thermos, wall_clock, carved_wooden_plate, wooden_cutting_board, russian_food_cans_01, throw_pillows_01 |
| Tools and gear | rubber_boots, rusted_spade_01, sledgehammer_01, metal_toolbox, steel_frame_shelves_01 (authored at 10× scale; instanced at 0.09) |
| Lighting | wooden_lantern_01, security_light, industrial_wall_lamp |
| Outdoors | ocean_buoy, tree_stump_01, fern_02; Phase 12: dry_branches_medium_01 (forest-floor deadwood) |
| Phase 12 furniture | sofa_02 (camper couch) |

**Surface textures** (1k, diffuse + OpenGL normal + AO/roughness/metal):
- Used directly: pine_bark, bark_brown_02, weathered_planks, weathered_plank_siding, wood_floor_worn, denim_fabric, fabric_leather_01, gingham_check.
- **Phase 12 fabrics:** poly_wool_herringbone, caban, stretch_poplin, rough_linen, polar_fleece, knitted_fleece and fabric_leather_02.
  - `tools/bake_fabrics.py` bakes neutral-grey versions of these, plus denim, into `assets/generated/fabrics/*_grey.jpg`, so code can tint them to the real colour. The originals' normal and AO/roughness maps are used as-is.
  - These replace the denim stand-ins on furniture, bedding, curtains and jackets.
- **Baked into the terrain texture arrays** (`assets/generated/terrain/terrain_{albedo,normal,arm}.jpg`) by `tools/bake_terrain_arrays.py`: coast_sand_01, damp_beach_sand, leafy_grass, sparse_grass, forest_leaves_02, dry_decay_leaves, dirt, mossy_rock, rock_face, gravel, river_small_rocks, brown_mud_leaves_01. The originals are not committed.

**Foliage cards:**
- Source: the twig/leaf texture maps of pine_tree_01, fir_tree_01 and tree_small_02. The full 8–17 M-polygon tree models are not used.
- Composited into `assets/generated/foliage/{pine,spruce,birch}_card.png` by `tools/bake_foliage_cards.py`.
- These are derived works of CC0 sources and remain free to use.

## Original procedural assets (this project)

| Asset | Made by |
|---|---|
| Island terrain, rivers, ponds, masks, tree/rock layout | `scripts/world/island_generator.gd` → `data/world/` |
| Tree meshes (3 species × 3 variants × 2 LODs + far silhouettes) | `scripts/vegetation/tree_builder.gd` (built at runtime) |
| Rocks, grass/reed/dune blades | `rock_builder.gd`, `ground_cover.gd` |
| Buildings (camper, cabin, fence, lean-to, bridges, notice board, arcade cabinets) | `camp_builder.gd`, `bridge_builder.gd`, `build_kit.gd` |
| Human and dog characters plus all animation clips | `scripts/characters/*` |
| Sky, water, foam, caustics, fire, smoke, heat haze, chain-link, arcade screens, post grade | `shaders/*` |
| **All sounds** in `audio/generated/` (surf, river, pond, wind in leaves, fire crackle, room tone, 5 bird calls, metal creak, footsteps on 7 surfaces, UI click; Phase 8: `rain_open`, `rain_roof`, `thunder_far_0/1`, `music_day_0..2` (Karplus-Strong plucked phrases, original melodies), `music_dusk`, `log_settle`; Phase 14: `saw_start`, `saw_idle`, `saw_rev`, `saw_load`, `saw_stop`) | `tools/generate_audio.gd` (filtered noise, FM and Karplus-Strong synthesis, seed 808 for Phase 8; Phase 14 chainsaw: two-stroke pulse train exciting housing resonances + exhaust noise + chain whir + tooth-rate wood rasp, seed 1414; `-- chainsaw` regenerates only those) |
| Phase 14 chainsaw model, parcel locker, helmets/visor/ear muffs, gear tints | `scripts/logging/chainsaw_model.gd`, `scripts/camp/parcel_locker.gd`, `HumanCharacter.set_gear` (original primitive builds, no brand) |
| **Phase 15 sound library**: 200 sources in `audio/lib/` (work, vehicle, movement, env, domestic, horror) + `audio/lib/manifest.json` | `tools/audio_lib/` (`build.py`, `library.py`, `dsp.py`; numpy/scipy synthesis: modal bodies, stick-slip, firing-pulse engines, grain clouds, formant voices; seed = crc32(name); original, no recordings, no third-party samples). QA: `tools/audio_lib/qa.py` |
| **Phase 19 sounds**: `audio/lib/vehicle/ship_diesel_far_loop.ogg`, `rotor_beat_loop.ogg` | Original procedural synthesis (`tools/audio_lib/library.py`: `ship_diesel`, `rotor_beat`), deterministic seeds; no recordings |
| **Phase 19 models**: survey vessel, helicopter, field sheds, dock gear chest | Original procedural geometry (`scripts/offshore/*`, `scripts/world/survival_cover.gd`); no affiliation markings, names or logos |
| **Phase 19 voice clips**: 488 more clips for the 120 offshore lines | Same Phase 18 pipeline (eSpeak NG, offline) |
| **Phase 18 crew voices**: 2,828 clips in `audio/voice/` + `data/voice/manifest.json` | Generated offline by `tools/voice/build_voices.py` with eSpeak NG 1.51 (GPL-3.0+ tool, not shipped; output unrestricted), original synthetic voices, no recorded or cloned person; settings in `tools/voice/profiles.json`, see docs/editorial/VOICE_CAST.md |
| Rain streaks, TV screen, sky cloud occlusion (Phase 8) | `shaders/rain.gdshader`, `shaders/tv_screen.gdshader`, `shaders/sky.gdshader` |
| Phase 8 animation clips (pickup, setdown, talk, talk_shaken, fear, listen, glance, grip, drive, hide; dog sniff/growl) | `HumanCharacter.CLIPS` / `DogCharacter._make_head_pose` (procedural keyframes + IK) |

## Motion capture (owner-supplied, Phase 12)

- **Source:** five Adobe Mixamo animations (walk, run, two seated idles, lying with a nod), supplied by the project owner as FBX files.
- **Where they live:** the raw FBX files sit in `assets/mixamo_src/`, which is **git-ignored**. Mixamo content may be used in projects, but not redistributed as standalone files.
- **What the game ships:** only `data/anim/mixamo_retarget.json`, the retargeted per-joint rotations for this game's own rig, produced by `tools/bake_mixamo.gd`.

## Known asset gaps (deliberate temporary substitutes)

- **Audio:** no licensed field recordings yet. All ambience and footsteps are procedural placeholders. They are clearly synthetic, and the birds especially read as simple chirps. Replace them with licensed recordings (record source, author and license here) without changing the emitter code: swap the `.wav` files under the same names.
- **Characters:** stylized rigid-part models built from primitives. They are not Blender-quality sculpted, skinned or face-rigged characters. A licensed, ready-rigged GLB can replace them later behind the same API.
- **Trees:** card-based procedural trees. Pines read stylized ("clumpy") up close.
- **Missing assets:** if any Poly Haven prop is missing at runtime, `BuildKit.prop` shows a teal placeholder box and logs a warning, so missing files are never silent.
