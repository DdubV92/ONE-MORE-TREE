# Phase 18: the crew speaks

Status key:
- **observed:** an automated test, a validator, a measurement, or a decode check.
- **unrun:** implemented but not exercised.
- **gap:** not done.

**Nobody has listened to these voices.** This environment has no audio output device, so nothing below is an audition by ear. "Audition" in this document means mechanical checks plus the preview listening route, which is provided for a person to use.

## Counts (from the parsed data)

| What | Count |
|---|---:|
| Unique authored crew lines (Phase 17 bank) | **1,676** |
| Required line/profile mappings | **2,828** |
| Generated clip files (`audio/voice/<profile>/<line>.ogg`) | **2,828** |
| Imported by Godot and linked in the runtime index | **2,828** |
| Mechanically validated | **2,824** |
| Flagged for review (`source_clipped`, kept in the bank) | 4 |
| Auditioned by ear | **0** |
| Missing / blocked / stale mappings | 0 / 0 / 0 |

How the 2,828 mappings arise:
- 1,407 character lines need one clip each, in that worker's own voice.
- 146 role lines need all 7 profiles: the five starting workers plus the two replacement voices.
- 123 trait lines need the starting workers who have that trait, plus the two replacement voices.

Clips per profile:

| Profile | Clips |
|---|---:|
| marta | 463 |
| dale | 463 |
| priya | 456 |
| tomas | 454 |
| joan | 454 |
| crew_m | 269 |
| crew_f | 269 |

Clips run from 1.1 to 16.1 s (average 5.0 s), about 236 minutes of speech in total. The fictional internet (5,946 units) stays **text only** (observed: no feed voice directory).

## How it was made

- **Generator:** offline eSpeak NG formant synthesis, run by `python3 tools/voice/build_voices.py`. Use `--only <line_id>` for one line or `--check` to report without rendering.
- **Cast:** [editorial/VOICE_CAST.md](editorial/VOICE_CAST.md) has the profiles, deliveries, pronunciation, processing and provenance.
- **Cache key:** each mapping is keyed by its normalized spoken text, profile and delivery settings, generator version and preset. Runs are resumable, and only affected clips are re-rendered after a text or profile change. Stale mappings are dropped.
- **Manifest:** `data/voice/manifest.json` records, per mapping:
  - line id, profile, delivery, text hash and spoken text;
  - clip path, duration, codec, channels and rate;
  - content hash, settings and generator version;
  - provenance and review status;
  - the mouth envelope.
- **Runtime index:** `data/voice/index.json` (388 KB) holds duration, delivery and envelope only.
- **The first exact line** proved the path end to end before the bank was built: `cut.marta.019`, "Pinched the cut. Wedge it, don't wrestle it." It was rendered, decoded, imported and played through `SoundService.speak` in the game (headless, dummy audio driver: the voice was active and decoded at its manifest length).
- **Why eSpeak NG and not a neural voice.**
  - Hugging Face is unreachable from here.
  - Downloading and running the Kokoro-82M ONNX release (Apache-2.0) was refused by this session's safety check, so it was not used.
  - The pipeline is generator-agnostic: swapping `render()` and re-running regenerates every mapping under a new preset. The formant voices are distinct and intelligible but clearly synthetic.

## In the game

- **Playback.**
  - A line is spoken only after Phase 17 picks it and re-checks it. The game then looks up the speaker's own profile.
  - If a clip exists, it plays through `SoundService.speak` from the speaker's head as one moving positional source (Phase 15 distance, occlusion, rooms, doors).
  - Its real length drives the caption duration (clip + 0.6 s) and the next turn.
  - Whispers play about 9 dB below ordinary talk. A missing clip keeps the text presentation (observed).
- **Interruption.** If the speaker or listener leaves, the line becomes ineligible, a nearby fall warning sounds, a save loads, or a new boss reply starts, the speech stops at once (`SoundService.stop_speech`) and the mouth closes (observed: no lingering audio or mouth). Cooldowns and knowledge are unchanged from Phase 17.
- **Mouth motion.** The lip and chin meshes follow each clip's 20 Hz amplitude envelope: smoothed opening, fast closure, slight jaw drop. Faces update only within 30 m of the camera.
- **Camera relay.** Speech is an ordinary world sound (`SoundEvents`, category speech). The Phase 15 camera microphones relay it through the desk speakers only when it isn't already naturally audible where you are, so it is never doubled. Relay never re-captures.
- **Muted voices.** If the Characters bus is muted or near silent, captions fall back to text timing. The subtitle setting and the duration slider from Phase 17 still apply.
- **Talk menu.** Boss replies are voiced too.

## Budget (measured, headless)

| Measure | Value |
|---|---|
| On disk | ~81 MB (`audio/voice`, 2,828 Ogg Vorbis clips at 16 kHz mono) |
| Index load | 11 ms, once |
| Clip load (on demand, imported) | median 0.7 ms, max 1.2 ms over 101 sampled clips |
| Resident memory | about 26 KB per loaded clip |

Nothing is front-loaded. At most one conversation speaks at a time, plus boss replies and audition stops. Real audio latency and CPU on target hardware are **unrun**.

## Preview audition route

Preview → Tab → **"Phase 18 crew voices"**:

| # | Stop | What it plays |
|---|---|---|
| 1–5 | Each worker | An ordinary line, a work callout and a whispered or uneasy line, from real bank lines |
| 6 | A real two-person exchange | |
| 7 | Distance ladder | 3 / 12 / 30 m |
| 8 | Five-voice lineup | Matched levels |
| 9 | Coverage counts | |

## Tests (observed passing)

- **`phase 18 units`:**
  - every required mapping has an imported clip and the index has no extras;
  - 61 sampled clips decode at their manifest length (±0.08 s);
  - all deliveries are valid;
  - replacement voices are persistent and never a roster voice;
  - the internet is unvoiced.
- **`phase 18 world`:**
  - a voiced line plays from the speaker (exactly one speech voice), the mouth moves, and turn timing uses the clip length;
  - interruption stops audio and mouth;
  - a missing clip produces no audio;
  - the boss greeting is voiced.

## Known limits (honest)

- **Not heard.** Formant voices are clearly synthetic. Words were not machine-transcribed back, though the clips are rendered deterministically from the exact canonical text.
- **Flagged clips.** 4 clips are flagged `source_clipped` and still in use.
- **One delivery per line.** No alternate takes.
- **Interrupted lines** end; they do not resume mid-sentence.
- **Mouth motion** is amplitude-based, with no phonemes.
- **Packaged build.** Exported-build playback is checked by CI's import and export of the clips; not listened to.
