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
| Outdoors | ocean_buoy, tree_stump_01, fern_02 |

**Surface textures** (1k, diffuse + OpenGL normal + AO/roughness/metal):
- Used directly: pine_bark, bark_brown_02, weathered_planks, weathered_plank_siding, wood_floor_worn, denim_fabric, fabric_leather_01.
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
| **All sounds** in `audio/generated/` (surf, river, pond, wind in leaves, fire crackle, room tone, 5 bird calls, metal creak, footsteps on 7 surfaces, UI click; Phase 8: `rain_open`, `rain_roof`, `thunder_far_0/1`, `music_day_0..2` (Karplus-Strong plucked phrases, original melodies), `music_dusk`, `log_settle`) | `tools/generate_audio.gd` (filtered noise, FM and Karplus-Strong synthesis, seed 808 for Phase 8) |
| Rain streaks, TV screen, sky cloud occlusion (Phase 8) | `shaders/rain.gdshader`, `shaders/tv_screen.gdshader`, `shaders/sky.gdshader` |
| Phase 8 animation clips (pickup, setdown, talk, talk_shaken, fear, listen, glance, grip, drive, hide; dog sniff/growl) | `HumanCharacter.CLIPS` / `DogCharacter._make_head_pose` (procedural keyframes + IK) |

## Known asset gaps (deliberate temporary substitutes)

- **Audio:** no licensed field recordings yet. All ambience and footsteps are procedural placeholders. They are clearly synthetic, and the birds especially read as simple chirps. Replace them with licensed recordings (record source, author and license here) without changing the emitter code: swap the `.wav` files under the same names.
- **Characters:** stylized rigid-part models built from primitives. They are not Blender-quality sculpted, skinned or face-rigged characters. A licensed, ready-rigged GLB can replace them later behind the same API.
- **Trees:** card-based procedural trees. Pines read stylized ("clumpy") up close.
- **Missing assets:** if any Poly Haven prop is missing at runtime, `BuildKit.prop` shows a teal placeholder box and logs a warning, so missing files are never silent.
