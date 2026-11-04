# Phase 11: cast, dog, larger camper and the desk computer

Status key: **observed** = automated test or software-renderer capture · **unrun** = implemented, not exercised · **gap** = not done. Nothing here has been seen on a real GPU or played by a person.

## Camper: measured +25 % usable floor

Usable floor = the interior floor inside the walls (furniture included, wall thickness excluded), measured from `CampLayout` (the single source of truth the builder uses).

| | Width | Length | Usable floor |
|---|---|---|---|
| Before (Phases 0–10) | 3.00 m | 9.40 m | 28.20 m² |
| After (Phase 11) | 3.26 m (+8.7 %) | 10.81 m (+15 %) | **35.24 m² (×1.2496)** |

- **Kept in place:** the bedroom end (north wall), the entrance door and steps (so the dog's flap route and the hunt approach are unchanged), the kitchen, the bathroom, the bedroom, the player bed, both hiding spots (under the bed, wardrobe) and the dog bed. All extra length went to the lounge.
- **New lounge:** a desk station in the west corner and a couch facing the entertainment TV in the east half, with a small coffee table.
  - Circulation from the door to the desk runs between the fridge and the couch (about 0.9 m wide).
  - The chair has 0.55 m of pullback space.
- **New west window** beside the desk, to the right of a seated player. The window that overlapped the fridge moved forward.
- **Rebuilt together with the size change:**
  - Shell, roof, trim, stripes, chassis, wheels, stabilizer jacks, hitch and propane.
  - The interior safety zone, crew-navigation footprint, audit footprint and Terror placement box.
  - The camera 2 mount, which follows the wider wall.
- **Safety:** the whole new lounge is inside the absolute camper safety zone (tested), and camper safety does not leak past the new front wall (tested).
- **Event staging:** three staging markers outside the desk window (ground-supported, never populated by themselves) are reserved for Phase 19.

## Desk computer (CampOS)

- **Seat:** E at the chair sits you down facing the monitor.
- **Overlay:** the desktop is drawn on the in-world monitor and, while you sit, as a readable overlay on the left 70 % of the screen. The window on your right stays visible.
- **Controls while seated:**
  - **Glance:** D (move right) glances out of the window and A (move left) looks back. While glancing, the overlay hides and the mouse looks around.
  - **Standing up:** E or Space stands up at once, behind the chair. This works during the hunt too: there is no locking animation.
- **Time:** the computer is live (time keeps running); only the real pause menu pauses.
- **Input:** desk clicks are forwarded only into the desktop. They can't swing the axe or reach the bed.

| App | Status |
|---|---|
| Cameras | **Working (rehosted):** the same ten cameras, four distinct feeds with one tile swapping about every 5 s (shuffled), click a feed to focus (higher resolution), right-click or "Wall (4)" to go back, previous/next, swap speed or freeze, microphones, volume, feeds on/off. The relay plays from the **desk speakers**. Cameras render only within 6 m of the desk or while seated; switching the monitor off stops them. A small quad inset shows in other apps (the same four feeds, no extra renders). |
| Shop | **Working (rehosted):** medium/large axes through the real `Equipment`/`Wallet` (×1.40 / ×1.96 cutting rate, ownership, equip) and the pickup order through the real `VehicleService` (3 seats, 3 trees' worth, two maximum, unlock condition shown). Gloves, boots, helmets and chainsaws are listed as "not stocked yet". |
| Mail, News, Forums, Recordings | **Labelled placeholders** for Phases 14, 17 and 19. No fake content, orders or recordings. |

- **TV:** the camper TV is entertainment only. It shows the original procedural channel in its own small viewport (renders only when switched on and you are near) with its own speaker. There is no hidden surveillance on the TV.
- **Blank-screen fix (after build 50):** `BuildKit.batch_static` merges static meshes that share a material. Phase 11 made the TV and the monitor share the "screen" material, so both quads were merged into a plain glossy mesh and the live displays vanished (headless tests only checked materials). Both quads are now `no_batch`, the Phase 11 test asserts each display keeps its own mesh and live material, and the desk/couch captures were re-taken with the TV on.
- **Saves:** a desk session saves as standing behind the chair. A legacy couch seat still restores on the couch.

## The five employees (authored looks by persistent ID)

| ID | Name | Look |
|---|---|---|
| EMP-01 | Marta Kell | 1.70 m, auburn bun, rust jacket, upright |
| EMP-02 | Dale Ostrow | 1.88 m broad, greying full beard, navy jacket, strong nose/jaw |
| EMP-03 | Priya Lund | 1.65 m slim, dark ponytail, olive jacket |
| EMP-04 | Tomas Reyner | 1.77 m, beanie, stubble, mustard jacket, slouched |
| EMP-05 | Joan Abernathy | 1.72 m, cap over curls, teal jacket |

Replacements and legacy crew use the deterministic seed path with the same controls. The look never touches beds, wages, tools, skills, fear or history (`HumanAppearance.for_employee`).

**What changed on the body:**
- **Hands:** gloved, with a palm, four two-segment curled fingers, a thumb and a cuff (no more mitten blocks).
- **Faces:** jaw angle and chin, nose bridge and tip, eyelid shelves (gaze), cheek and ear proportions.
- **Hair:** seven styles, including curls under a cap, a ponytail and a buzz with a side part. Facial hair includes stubble, a full beard and a moustache.
- **Trunk:** two overlapping tapered capsules (ribcage and waist) instead of stacked balls.
- **Workwear:** zip placket, hem band, a restrained hi-vis back band, knee patches, boot toe caps and laces.

**Rig and attachments (unchanged contracts):**
- Pivots: Hips, Spine, Chest, Neck, Head, UpperArm/Forearm/Hand ×2, Thigh/Shin/Foot ×2.
- Attachments: `Hand*/Grip`, `Chest/LogCarry`, `Head/LookAt`, and AxeRig with RightGrip/LeftGrip.
- Navigation owns travel; clips play in place, and the walk stride scales with measured speed.
- Work contacts stay exactly-once (Phase 8 test).

## Dog

Same single identity and the same IK rig, so gait, contacts and the dock/rescue behaviour are unchanged. New shape:
- Deep ribcage keel, shoulder blades and a tucked-up waist.
- Collar and tag.
- Defined stop, a longer muzzle with flews and nostrils, and folded ears with tips.
- Upper arm and pastern on the front legs.
- Gaskin and hock on the hind legs, so they read canine rather than human-kneed.
- Four toe beads and a pad on every paw.
- Fewer, flatter scruff tufts.

## Character art style (Settings → Character art style)

- **clean (default):** the stylized PBR materials.
- **pixel:** a multiply next-pass on the same character materials:
  - colour cells in each part's own metric space (1.6 cm), so they move with the body without crawling;
  - a 3-band light ramp with ordered-dither edges;
  - nearest-filtered cloth texture.

  Strength is adjustable. Water, terrain, sky, fog, shadows, UI and camera feeds are untouched; only characters change. The default stays **clean** because nobody has reviewed the pixel version on real hardware. The comparison images are in `docs/screenshots/phase11_cast_*`.

## Review tour

Preview → Tab → **Phase 11 cast, dog & camper**: cast lineup (Character Preview), clean/pixel toggle, work loop, truck seats, dog close-up, camper tour (shows the measured area), sit at the desk, cast on the cameras, a light cycle, and a hide/camper-search fixture (forced, dev). Captures: `godot res://tools/capture_cast.tscn` (lineup, faces, hands and dog in both styles).

## Asset provenance

Everything new is original and generated in code: camper and furniture geometry (`camp_builder.gd`), characters and dog (`human_character.gd`, `human_appearance.gd`, `dog_character.gd`, `mesh_kit.gd`), and shaders (`char_pixel.gdshader`, `tv_screen.gdshader`). No imported models, no Blender files, no plugins. The existing Poly Haven (CC0) props and textures are reused (the thermos and the denim cloth texture).

## Honest remaining gaps

- **Not sculpted or skinned:** the characters are still rigid-part primitive models. The silhouettes, hands, faces and workwear are clearly better, but this is not the quality of a professionally sculpted, skinned and face-rigged character. A licensed rigged GLB route remains open behind the same rig contract.
- **Fingers:** they are posed, not individually animated; grips are set by IK and the finger curl.
- **Pixel style:** reviewed only in software-renderer captures.
- **Seated pose:** there is no full-body boss model in first person; the seated desk pose uses the camera-only body as before.
- **Performance:** about 35 more mesh parts per human (hands, face, workwear) and about 30 more per dog (anatomy, toes; 12 fewer tufts). The Phase 8 draw-call counts rise a little in busy camp views; this hasn't been measured on a GPU.
