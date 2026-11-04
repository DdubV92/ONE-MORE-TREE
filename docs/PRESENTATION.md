# Presentation (Phase 8): weather, light, water, animation, TV and sound

This is the reference for how the game looks, moves and sounds after Phase 8, and how each part is owned. Status in [PHASE_CHECKLIST.md](PHASE_CHECKLIST.md). Ordinary Terror sensory coverage: [coverage/phase8_sensory_matrix.md](coverage/phase8_sensory_matrix.md).

## Ownership: who writes what

| Concern | Owner | Notes |
|---|---|---|
| What the weather is | `WeatherService` (`scripts/weather/weather_service.gd`) | Pure function of world seed + day + authoritative clock (campaign `WorkdayClock` or the hunt clock). Preview/tests use `set_override`. |
| Sun, moon, sky, fog, ambient, exposure, shared shader globals (`wind_dir`, `wind_strength`, `wetness`, `rain_amount`, `sun_clarity`, `haze_strength`, `daylight`) | `EnvironmentController` | Single writer. Weather arrives through `set_weather()` (throttled to 5 Hz, or every frame only during a flash). |
| Rain particles | `RainView` (one per view) | Player view + one per remote camera that the TV is actually rendering. |
| Remote-view environment | `CameraWall._sync_env` | A copy of the live environment twice a second, scene-linear (see TV). |
| Ambience, birds, leaf wind, crowd steps, room response, music | `ambient_audio.gd` | Zone/filter/reverb model, not simulated acoustics. |
| Rain/roof/thunder audio | `WeatherService` | Follows the listener's shelter (interior zone or a roof above). |

Gameplay state never depends on presentation: weather, wetness, lightning, music, animation and TV image changes never touch wages, trees, cargo, lamps, safety, the contract, the director's pacing or any campaign RNG (weather has its own cosmetic RNG).

## Weather

States (cloud, rain, wind multiplier, distant storm): `clear` (0, 0, 1.0), `light_cloud` (0.3, 0, 1.1), `overcast` (0.82, 0, 1.25), `light_rain` (0.95, 0.62, 1.4), `storm` (1.0, 0.85, 1.7, lightning far out at sea).

Each campaign day picks one plan from a seeded table (weights in brackets): fair (30), fair with cloud (18), overcast clearing (12), afternoon shower (12), grey day (8), rainy evening (10), distant storm at dusk (8). Segment times get a ±60 s seeded jitter. Changes blend over 90 s (smoothstep); the morning blends in from the previous evening (a stormy evening wakes up overcast, not instantly clear). Day 1 is always fair. Over 35 days 3–18 days have any rain (test-bounded; the shipped seed gives a restrained count).

- **Save/load:** nothing is rerolled. The schedule is reconstructed from the restored clock; the save stores only the seed and the smoothed cosmetic wetness (`phase8.weather`, schema v8).
- **Wetness:** soaks in over ~70 s of rain, dries over ~5 min. Terrain darkens and turns glossier (upward faces first, hollows slightly more, dense canopy keeps the floor drier), rocks and bark darken. The swash band on beaches keeps its own wetness.
- **Rain:** GPU particles in a 26 × 26 m column around the view (spawned through the whole column so it is full immediately), falling along the shared wind. A `GPUParticlesCollisionHeightField3D` captured from above stops drops on roofs, truck cabs and canopies: no rain inside the camper, cabin, porch or a cab. Splash flecks on High/Ultra (player view only). Streaks are fixed-Y billboards, so slant shows as drift, not tilted streaks (documented approximation). Brightness follows daylight, so drops never glow at night.
- **Rain on water:** bounded procedural rings (one per 0.7 m / 0.45 m cell, no neighbour loops) on ponds, fainter on the moving river and the sea.
- **Lightning:** only in the `storm` state, 2.2–4.5 km out at sea every 18–55 s, thunder delayed by distance (capped at 12 s). Follows **Lightning / bright flashes**: `full` (quick double flash), `reduced` (default: a slow dim swell), `off` (no flash, thunder only). It lifts sky and ambient only. It never changes lamps or anything `SafetyService` reads, and emits no `SoundEvents` (no AI evidence, no Terror trigger).
- **Heat haze:** only over sunny, dry sand/rock and the burn pit. Cloud, rain and wet ground suppress it, as does night.
- **Wind:** one shared field. Prevailing direction per day (seeded) with a slow drift, strength = time-of-day preset × weather multiplier. Trees, grass, water detail normals, rain drift, cloud motion and the leaf-wind ambience all read it. Local variation comes from the travelling gust function, so trees do not sway in lockstep. Trunk bases stay anchored (sway grows with height).
- **Sky:** sun and moon discs sit behind the clouds and disappear under a full overcast.

## Quality profiles (actual runtime values)

| | Low | Medium | High (default) | Ultra |
|---|---|---|---|---|
| SSAO / SSIL / SDFGI | off / off / off | on / off / off | on / on / off | on / on / on |
| Sun shadow distance, splits | 80 m, 2 | 120 m, 4 | 160 m, 4 | 220 m, 4 |
| Volumetric fog | off | off | on | on (denser) |
| Tree near / mid range | 110 / 380 m | 140 / 480 m | 170 / 560 m | 220 / 700 m (mid shadows) |
| Ground cover density | 0.35 | 0.65 | 1.0 | 1.4 |
| Ocean grid | 160 | 240 | 320 | 400 |
| Player rain drops | 1,000 | 2,000 | 3,200 (+ splashes) | 4,200 (+ splashes) |
| Remote rain per feed (quad / focus) | 120 / 350 | 220 / 700 | 220 / 700 | 220 / 700 |
| Rain roof mask | 512² heightfield (player), 256² (remote) | same | same | same |
| TV quad feed | 320×180 @ 10 Hz | 384×216 @ 12 Hz | 384×216 @ 12 Hz | 448×252 @ 15 Hz |
| TV focus feed | 960×540 @ 24 Hz | 1280×720 @ 30 Hz | 1280×720 @ 30 Hz | 1600×900 @ 30 Hz |

Lower presets change presentation only. Tree count, NPC logic, safety, hunt evidence and the deadline are identical on every preset.

## Comfort and post controls (Settings → Esc)

| Control | Default | What it actually does |
|---|---|---|
| Head bob (toggle) + strength | on, 1.0 | Scales the walking camera bob. |
| Camera shake on hits (toggle) + strength | on, 1.0 | Scales the small axe-contact shake (capped at 4 cm). |
| Lightning / bright flashes | reduced | full / reduced / off (see Weather). |
| Horror intensity | 1.0 (0.4–1.0) | Playback loudness of Terror cues; below 0.7 a peak uses a breath instead of a stinger and a shorter withdrawal. AI evidence keeps the authored level, and event selection, count and rules are unchanged. |
| Depth of field | off | off / subtle (far only, 450 m) / cinematic (preview). Gameplay is never blurred by default. |
| Chromatic aberration | 0 | Edge-only, 0–1. |
| Vignette, film grain, colour grading, bloom, heat haze, tonemapper | 0.22, 0, 1.0, on, on, filmic | Independent. |
| Daytime music | on | Sparse phrases (see Sound). |
| Volumes | Master, Ambience, Work, Characters, Music, Horror, UI, TV | Each bus independently. |

Not implemented, so not offered: motion blur and automatic eye adaptation. Exposure is authored per time of day and eases 1.35× indoors (no pumping when you look at the TV or the fire).

## TV and live cameras

- Ten fixed cameras. Quad shows four distinct feeds and swaps one tile every 5 s through the fair shuffle bag. Focus locks one feed until you act. Entertainment keeps the four live insets.
- **Real cost difference:** quad renders four small viewports at a low rate; focus renders one viewport at the composite's full resolution at a higher rate (table above). The composite renders at the focus resolution with its 2D layout in 960×540 units, so a focused feed maps 1:1 and is never an upscaled tile. `CameraWall.pipeline_info()` publishes the live numbers (Tour station 8 shows them).
- **Bounded:** at most four remote renders in quad/entertainment, one in focus; hidden feeds stop; the pool is fixed and is only resized on a quality change (tested: 200 mode toggles plus 50 weather changes grow nothing).
- **One tone map:** remote renders are scene-linear HDR (linear tonemapper, no remote bloom or colour grading, outdoor exposure). The room camera tone-maps, blooms and grades the screen once. The screen shader applies a display gain (0.42) so the TV reads as a dim display, not a hole into daylight. The screen is on its own render layer, so feeds never capture the TV (no recursion). Remote views skip SSIL, SSR, SDFGI and volumetric fog, and SSAO in quad.
- **Same world:** feeds show the real terrain, removed trees, workers, Terrors and weather. Each rendered camera gets its own small rain volume at the mount.
- **Microphones:** one replay per world sound from the strongest displayed microphone (38 m, occlusion −8 dB), quiet in quad (−15 dB) and clearer in focus (−3 dB), deduped (120 ms), at most six replays. **New:** if the source is already naturally audible where you stand (within 30 m), the relay fades out (fully skipped within 7.5 m), so it is not doubled. TV output is never a `SoundEvent` (no feedback loop). TV mute affects only the relay.

## Sound

- **Buses and peaks:** Master (hard limiter −0.3 dB), Ambience (interior low-pass), Work, Characters (room reverb), Music, Horror (hard limiter −2 dB), UI, TV (transmission band-pass + limiter −3 dB). A focused TV relay plus a local scare cannot stack into an uncontrolled spike.
- **Space:** camper small room (wet 0.16), cabin larger (0.2), an enclosed rocky hollow gets a restrained echo (wet 0.07), woodland and shore stay dry. This is a zone/filter model, not physically simulated acoustics.
- **People:** your own footsteps by surface (centred). Workers' footsteps come from their walk-cycle foot plants, by surface (wood on decks/floors), from a 6-voice pool culled beyond 28 m.
- **Timber:** one clunk per settle per body, plus a global debounce (same impact kind within 3 m and 280 ms plays once).
- **Rain:** open-air hiss outdoors; roof patter under a roof or indoors (open rain fades to 18 %). Thunder is distant and quieter indoors.
- **Leaves and birds** follow the trees actually still standing within 22 m / 45 m. Cleared ground keeps only open-air wind and no phantom birdsong. Heavy rain quiets most birds.
- **Music:** three original plucked daytime phrases (about 12 s, mostly silence), one every 2.5–5.3 min in good daylight; never in rain, at night or during the hunt. A single soft pad as dusk begins. It never announces an encounter.
- **Foreman:** footsteps come from its actual foot plants (heavier when sprinting); the tags rattle only while it moves and are cut off when it stops to listen.

## Animation coverage

Humans (`HumanCharacter`, rigid-part rig, feet re-solved by planar IK at every key, head yaw bounded to ±1 rad):

| Clip | Used for |
|---|---|
| idle, walk (stride follows measured speed) | Navigation owns travel; the walk plays from measured velocity. |
| swing (contact frame synced to the work transaction) | Felling, bucking, stumps: one contact per cycle, tested under frame skips. |
| pickup, setdown (one-shot) | After the timber transaction succeeds (rack, truck tailgate, pick-up). Presentation only. |
| sit, lie | Benches, beds; truck passengers. |
| drive | The worker in a truck's driver seat; the boss's camera body when driving. |
| talk / talk_shaken | Conversations: loose for skeptics, guarded (arms folded, head low) when the worker has a confirmed firsthand memory. Same lines, no new knowledge. |
| fear (standing idle) | Distressed or worse while idle: knees soft, weight back. They still take valid tasks. |
| glance / grip / listen (trait idles, one-shot) | Timid / hard-working / observant, every 10–22 s between jobs, interrupted by any movement. |
| hide | The boss's camera-only body while hiding (workers are hidden inside the spot). |

Dog: idle, walk, trot, sit, pet, lie, alert, **sniff** (idle in the yard, now and then), **growl** (2.5 s after a genuine threat cue). Head and ear attention track the position of a sensed sound, never hidden Terror coordinates.

Foreman (`ForemanBody`): walk, sprint, listen (head offset bounded to ±1.1 rad from the torso, tags silent), low search, doorway fold, reach. Steps are emitted by the stride.

## Review tour (Preview → Tab → Phase 8 review stations)

1. Morning camper · 2. Busy camp (5 workers, preview crew) · 3. Dense forest · 4. River & pond · 5. Beach & dock at noon · 6. Sunset return (trucks) · 7. Rainy night camper · 8. TV quad/focus (shows the live feed resolutions) · 9. Horror previews (**forced, dev**) · 10. HUNT fixture (**forced, dev**) · 11. Cleared overlook (90 % of trees removed in memory).

F4 also has Weather buttons (clear, light cloud, overcast, light rain, storm, back to schedule). Forced stations preview assets and contact. They do not prove natural pacing, AI uncertainty or balance. Preview never writes saves.

Screenshots: `godot res://tools/capture_views.tscn -- night+light_rain:camper_night` (the `+weather` suffix is new).

## Assets: what is final and what is not

Everything is original and built in code: procedural meshes, procedural animation clips and synthesized audio, recorded in [ASSET_PROVENANCE.md](ASSET_PROVENANCE.md). These are **not** production-final art:

- Humans, dog and Foreman are rigid-part primitive rigs (no skinning, no face rig). Their distinct builds, palettes, faces and postures are readable at work distance; close-up quality remains the main art gap. No Mixamo or other external rig has been added; that choice is still open with the owner.
- Animation is procedural keyframes plus IK, not motion capture. The new clips cover the listed actions with transitions (0.15–0.3 s blends, interruptible one-shots). Truck entry and exit, door traversal, bed entry and wake are still cuts with blends, not authored traversals.
- All sounds are synthesized placeholders (rain, thunder and music included). Replace them with licensed recordings under the same file names.

## Performance (honest status)

Graphical performance is **unmeasured**: the container renders on a CPU software rasterizer (lavapipe). The 60 FPS at 1080p target on a midrange discrete GPU has not been checked. Renderer-independent counts, High preset (`tools/capture_views.tscn`), before (earlier phases, 1920×1080) → after Phase 8 (1280×720; draw calls and primitives barely depend on resolution):

| View | Draw calls | Primitives | Objects |
|---|---|---|---|
| forest (day, clear) | 785 → 819 | 4.30 M → 4.76 M | 907 → 1075 |
| camp (day; after = light rain) | 1906 → 2177 | 7.34 M → 8.13 M | 2616 → 3105 |

The "before" column comes from earlier phases' captures (PERFORMANCE.md), and later content (crew, dog, trucks, dock) also changed the scene since then. Read it as a magnitude check, not a controlled A/B. New per-frame costs: player rain (one GPU particle system, 3,200 drops on High) plus a 512² heightfield refreshed only when you move 2 m or more; per rendered remote feed, one 220–700-drop system with a static 256² heightfield; weather CPU work is O(1) per frame. Rain particles in remote views are counted in the TV budget above.
