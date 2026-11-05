# Phase 15: sound library, source-based spatial audio, occlusion and rooms

Status key:
- **observed:** an automated test, a headless probe, or generator QA.
- **unrun:** implemented but not exercised.
- **gap:** not done.

**Nobody has listened to any of this.** This environment has no audio output device, so every "how it sounds" statement below describes intent and measurement, not audition.

## What now sounds different, and why its location is believable

- **Every world sound comes from where it happens.** It is a SoundService voice at the real source:
  - the axe at the accepted contact point;
  - the strain and crack on the actual trunk;
  - the fall at the crown's landing point;
  - logs at the rack, deck, cart or ground they hit;
  - the saw at the tool;
  - the truck at its body;
  - the dog's paws and tags at the dog;
  - doors at their panel;
  - the Foreman's feet at its feet;
  - rain on the roof above you;
  - surf at the nearest coastline, rivers at the nearest reach and riffle, frogs at the pond edges.

  Turning your head changes their direction, because it is one positional listener on the player camera.
- **Walls, doors and rock muffle each source on its own.** A few rays from you to each audible source add up the acoustic loss of what they cross:

  | Material | Loss |
  |---|---|
  | Wood wall | 13 dB |
  | Door | 10 dB |
  | Glass | 7 dB |
  | Metal | 16 dB |
  | Rock | 22 dB |
  | Terrain | 20 dB |
  | Trunk | 4 dB |
  | Fabric | 5 dB |

  The clearest ray wins. The source then routes itself to a 2.4 kHz or a 750 Hz low-pass tier of its own category and drops in level.
  - Inside the camper with the door closed, the surf and anything knocking outside are muffled, while the keyboard at your desk stays clear (observed in a test, simultaneously).
  - The old Phase 8 trick, a single low-pass on the whole Ambience bus whenever you were indoors, is gone.
- **Open doors are paths.** If you and the source are on different sides of a room boundary and an open door gives a better path than the wall, the sound comes through the doorway. Its emitted position is pulled toward the opening (bounded), so it is heard from the door's direction (observed: a source around the corner of the camper is routed via the open door).
  - Tier switches go through a 30 ms dip, so moving through a doorway doesn't zipper.
- **Rooms.** The camper and the cabin send only the sources inside them to their own short reverbs (RoomCamper, RoomCabin). Woodland and shore stay dry; a rocky hollow keeps a restrained echo.
- **Distance.** Each event has a distance class:

  | Class | Examples | Range |
  |---|---|---|
  | tiny | tags, clicks, cloth | ~22 m |
  | step | footsteps | ~34 m |
  | contact | axe, knocks, logs | 110 m |
  | impact | falls | 380 m |
  | engine | saws, trucks | 230 m |
  | voice | dog, calls | 70 m |
  | domestic | camper/cabin sounds | 26 m |
  | ambient | surf, river, wind | 220 m |
  | distant | far thunder, far cracks | 900 m |

  Each class has a near-field cap (`max_db`), so walking up to a quiet knock never booms.
  - Far transients (over 40 m) arrive after distance / 343 s.
  - The delay queue only advances while the game runs, so a pause never releases a burst afterwards (observed).
  - Doppler is off everywhere: no pitch swings from teleports, seat snaps or camera cuts.
- **The logging loop by material.**
  - Axe bites are chosen by species (pine, spruce, birch) and diameter (thin or thick): bark bite, woody modal body and fibre ticks.
  - Bucking, stumps and hard surfaces each have their own source.
  - The trunk strains from 60 % notch depth, louder as the hinge thins (driven by the real work), then the hinge crack.
  - The crown rustles when it starts to go, and the landing is sized by the tree's height.
  - Logs thud on ground, logs, rack, cart and deck with different modes.
  - The fire's bed follows its real fuel (embers, small, large), with occasional pops.
- **Chainsaw.** Five original layers driven by the Phase 14 engine machine:
  - start (two pulls, a cough, the catch), once per start;
  - idle, free-rev and loaded-cut loops, crossfaded by chain speed and real wood contact;
  - a chip spray when the chain bites;
  - a wind-down on stop, or a cut-out when killed.

  The loops are owned handles: stowing or killing the saw ends them, and a freed tool can never leave an orphan engine (observed).
- **Trucks.**
  - Four engine layers crossfaded by engine speed.
  - Tyres follow the real surface (gravel, dirt or grass) and road speed.
  - The cargo rattles only when loaded and moving.
  - Start and stop play once; doors, tailgate and cargo thuds play at the truck.
- **Handcart.** Wheels on dirt or boards by speed, with an occasional squeak.
- **Camper and computer.**
  - Fridge hum at the kitchen and the computer fan at the desk (domestic class, so they fade within the camper).
  - A quiet mouse click on the desk.
  - A chime from the computer speaker when a supply order arrives.
  - Door hinges and latches at the doors.
- **Night.** Mostly quiet, by design:
  - crickets after dark;
  - frogs only at the ponds;
  - an owl or a far branch every 25–70 s from a standing tree;
  - fence rattles at the real fence.
- **Ordinary encounters.** Knocks, steps, scrapes, breath, creaks and calls now use specific physical sources from the authored spot. They are occluded and roomed like any world sound, and captured by the cameras as world sounds. Families without a better source keep their Phase 6 sound (see gaps).
- **Foreman.** Footfalls come from its feet: heavy, or wet on sand and water. They are muffled by walls and closed doors and clear through an open one. Its breath plays from its head.

## Architecture (one tested backend: Godot native)

- **SoundService** (`scripts/audio/sound_service.gd`):
  - stable event IDs from `SoundBank`;
  - a pool of 40 one-shots, with lower-priority distant voices stolen first;
  - explicit loop handles (start, set, stop, owner-freed cleanup);
  - per-source occlusion with round-robin updates (8 voices per frame, each at most every 0.2 s);
  - door portals, travel delay, a no-immediate-repeat file choice and per-event debounce;
  - a recorder ring for replay.
- **Origin kinds:**
  - **world:** positional, occluded, heard by the camera microphones and recorded;
  - **internal:** authored psychological cue, at the listener, never captured;
  - **relay:** desk speakers;
  - **recording:** replay at the desk;
  - **ui** and **music.**

  `SoundEvents.emit` refuses every non-world origin (the hop rule), so desk or TV output can never be re-captured into a loop (observed).
- **Gameplay owns results; sound follows.** Callers commit work, payment or cargo first and then ask for the sound. A stolen, missing or virtualized voice never changes a result. One contact plays exactly one sound (observed).
- **AI hearing stays separate from the mix.**
  - `Game.hunt.noise` and SoundEvents use the authored strength, never bus volume.
  - Muting the master bus changes nothing in world evidence: camera captures, the recorder and Foreman hearing are unaffected (observed).
  - Environment sounds (surf, wind, rain, thunder, birds, fire bed, appliance hum: the Ambience bus) are not evidence by default: the Foreman, the dog and the camera registry only hear what something did. An event can opt in with `emit`. (A Phase 8 test caught the first build emitting thunder as evidence.)
- **Buses.**

  | Bus | Purpose |
  |---|---|
  | Master, Ambience, Work, Characters, Music, Horror, UI, TV | Existing mix buses |
  | **Relay** | New: computer camera audio, separate from TV entertainment, with its own slider |
  | `<category>_O1/_O2` | Per-source occlusion tiers for Ambience, Work, Characters and Horror |
  | RoomCamper, RoomCabin, RockHollow | Room response |

- **Steam Audio, FMOD and Wwise were not integrated.**
  - The pinned build has none of them installed.
  - The network policy here blocks most third-party downloads.
  - The brief warns against a destabilizing middleware swap.

  What is delivered is a ray/portal approximation with native filters. It is **not** HRTF binaural rendering, not diffraction and not a wave solver. Headphones get Godot's stereo panning, not true binaural rendering.
- **Speech interface (reserved).** `SoundService.speak(actor, {id, voice, text, priority})` plays `res://audio/voice/<voice>/<id>.ogg` from the mouth when a file exists. None exist yet; Phases 17/18 produce them.
- **Replay.**
  - `SoundService.replay(records, speaker, from_t, to_t)` plays recorded world events at their original offsets through the desk speakers.
  - Its origin is recording: no camera capture, no recorder entry, no gameplay (observed).
  - The full recording archive and scenarios are Phase 19.

## The sound library: 200 original sources (`audio/lib`)

`tools/audio_lib/build.py` uses numpy and scipy and is deterministic. It writes:
- mono 32 kHz files: WAV for one-shots, Ogg Vorbis for loops;
- a manifest with model, seconds, seed and provenance;
- a runtime index (`scripts/audio/sound_lib_index.gd`).

The library is about 13 MB.

| Category | Sources | Models (examples) |
|---|---|---|
| Work, wood, fire, tools | 60 | Modal wood bodies by species/size, bark-bite noise, fibre-tear grains, stick-slip strain, crown grains, ground boom, two-stroke saw, combustion bed + pops |
| Vehicles, cart, cargo | 25 | 4-stroke firing model at 4 speeds, starter crank, latch/hinge/thunk modes, chain rattle, tyre contact by surface, horn, cart wheels |
| Movement, cloth, dog | 25 | Cloth band noise, gear jingle, boot scuffs, paws (with claws on wood), tags, shake, drink, sniff, formant bark/whine/growl/yawn/pant |
| Environment | 45 | Surf swells near/far, swash fizz, bubble-grain water, wind beds per vegetation, gusts, rain grains on six surfaces, thunder, six bird grammars, crickets, frogs, owls, nightjar, insects, air beds |
| Camper, cabin, computer, fence | 20 | Door hinge/latch/thunk, window, fridge, fan, lamp hum, typing, click, chime, kettle, floor creaks, heater ticks, fence and gate |
| Horror | 25 | Knocks (wood/metal/glass), slow gravel steps, green-branch snap, noise-formant whispers, drones, breath, drag, scrapes, groans, scratching, far thud, wet steps, distant call, tags, glass taps |

- **All 200 are bound to events** (test).
- **QA** (`tools/audio_lib/qa.py`): no silent or invalid files and no loop seams.
- **Near-duplicates:** a crude spectral and envelope similarity check flags pairs above 0.985. The 4 remaining flags are all axe-on-wood relatives (pine vs spruce deep cuts, a deep cut vs a stump hit). The tailgate was rebuilt as ringing pressed steel after it scored as a near-copy of a log drop.
- **Hinge crack timing:** the snap now lands 0.26–0.36 s into the sound, not ~0.8 s, so the break is heard when the hinge fails.
- **Copies removed:** the build first contained copies that were only filtered or gain-changed versions of another source: `cupboard_close`, `cargo_log_thud`, `fence_rattle_unseen`, `distant_branch_crack`, `tags_far`, `branch_snap_near` and the second `log_stack`. Each got its own model before counting.
- **Honest count:**
  - 200 generated sources from about 70 distinct synthesis models, many with material parameters;
  - **0 recordings**;
  - **0 auditioned.**

  These are original procedural approximations. They are better structured than the Phase 0–8 placeholders, but they are not recordings and will not sound like a professional library. Replacing the most important ones with licensed recordings is the clear next step: axe bites, the saw, the truck, footsteps, the dog and surf.
- **Why no recordings.** The network policy here blocks Freesound, Kenney, OpenGameArt and Sonniss (HTTP 403 at the proxy). The few "CC0 pack" repositories reachable on GitHub have unverifiable provenance, which the brief rules out ("free download alone doesn't establish redistribution rights").

Full matrix: [audio/SOUND_COVERAGE.md](audio/SOUND_COVERAGE.md) (156 events, 205 bound sources: 200 new + 5 legacy).

## Still on legacy (Phase 0–8) sources (gaps)

- **Footsteps** for the player and crew: 7 surfaces × 5 variants of the old placeholders.
- **Music:** sparse plucked phrases.
- **Some terror families:** wing, bells, choir, lantern and voice fragments.
- **Foreman:** dry footfalls (`f_step`), tags and intake breath.
- **Dog-rescue whines** and the rescue **ship horn.**
- **The cameras' continuous ambience bed.**

All of these still play and none is silent.

## Measured (headless, dummy audio driver)

- **Busy camp:** five workers with chainsaws for 60 s (preview), plus ambience.
  - Peak 14 one-shot voices and 18 loops.
  - About 117 occlusion checks per second, each at most 3 rays × 3 hops.
  - 72 duplicate bursts merged by debounce; 50 low-priority one-shots stolen.
  - No errors.
- **Audition probe.** All 12 stops plus the active-voice list ran without errors. Replay scheduled the last 20 s at their original timing.
- **Not measured.** Real audio CPU, voice cost, memory growth and output latency need a machine with audio output. They are **unrun.**

## Tests (all observed passing)

- **`phase 15 units`** checks:
  - 200+ sources, all bound, category budgets met (60/25/25/45/20/25);
  - no missing files;
  - valid bus and distance class per event;
  - loop events use loop sources;
  - the hop rule: only world reaches microphones;
  - occlusion and room buses wired.
- **`phase 15 world`** checks:
  - exactly one current 3D listener;
  - one chop = one sound;
  - debounce;
  - the far transient is delayed and the delay is frozen by a true pause;
  - a loop dies with its owner and after a stop;
  - saw loops end on kill;
  - indoor vs outdoor occlusion at the same time;
  - a closed door filters and an open door clears;
  - a source around the corner is routed through the open doorway;
  - muting the mix keeps world evidence;
  - replay never becomes live evidence.

## Audition route

Preview → Tab → **"Phase 15 sound audition"**. Headphones are recommended.

| # | Stop | What it shows |
|---|---|---|
| 1 | Distance ladder | 3 / 12 / 40 / 120 m (the far ones arrive late) |
| 2 | Rotation and elevation | An orbiting engine |
| 3 | Camper door | A knock outside while the door cycles closed and open |
| 4 | Indoor + outdoor | Typing at the desk plus footsteps outside |
| 5 | Work material sequence | Bites, buck, stump, rack, cart, deck, fire, strain, crack, fall |
| 6 | Chainsaw states | Start, idle, rev, cut, release, stop |
| 7 | Truck & dog | Truck ramp, then paws, tags and a bark |
| 8 | Ambience in place | Day air and wind, then night |
| 9 | Desk relay | How to use the camera mics |
| 10 | Replay | The last 20 s through the desk speakers |
| 11 | Quiet night | Silence, then one fence rattle and a far branch |
| 12 | Worst overlap | Saw, chopping, fall, thunder and a knock at once |

There is also an **active voices** list (dev): event, distance, bus/tier, level and "via door".

## Fixes found while testing

- **Thunder and other environment sounds were emitted as AI evidence** by the first SoundService build. Caught by the Phase 8 test; Ambience events no longer emit by default.
- **The crew's door auto-close could shut a door the player had opened.** A worker passing through earlier left a stale record, so the door closed again as soon as the player stepped away. The crew now only closes doors it opened that are still open, and never a door the player opened by hand. Found by reading the door code while chasing a test failure.
- **Test harness (pre-existing since Phase 5): the "camp built" test had been silently aborting halfway.**
  - **Cause:** the dock's plain light was in the `camp_lamps` group, and setting `working` on it raised a script error. An aborted test returned nothing, which the runner counted as a pass.
  - **What was skipped:** the lamp-safety and camper-doorway checks never ran.
  - **What leaked:** the test's world never closed and stayed alive for the rest of the suite. Its closed camper door blocked the Phase 15 door check, and its weather pushes made a Phase 8 check flaky on CI.
  - **Fixes:**
    - the dock light now has its own `dock_lamps` group (safety never counted it: SafetyService only accepts real CampLamps);
    - the runner now reports an aborted test as a failure;
    - the skipped checks run and pass;
    - no world leaks between tests.
- **Rain layers churned audio players** on every weather change (each stop left a fading player). They now idle silently and are released after 4 s of continuous silence, which keeps the node count bounded (Phase 8 presentation test). The roof-material check also ran per frame instead of 4× per second; it is now time-based.
- **Hinge crack snap arrived about 0.8 s after the break**, and the **tailgate sounded like a wooden log.** Both models were rebuilt.

## Known limits (honest)

- **Not auditioned** on headphones or speakers.
- **No recordings.** The library is procedural.
- **No HRTF, no diffraction.** Occlusion is ray-based with door portals. Windows are glass loss only, not openings. Vegetation counts only trunks (4 dB); foliage is not an obstacle.
- **Masking.** No ducking or dynamic masking beyond levels; critical cues rely on the bounded mix and captions.
- **Phase 19 work.** The 1,200-line voice bank, the recording archive and the sleep-interruption catalog are not produced here (interfaces only).
