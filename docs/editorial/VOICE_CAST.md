# Voice cast sheet

## Phase 24: current voices (CMU Flite)
Owner feedback: the Phase 18 voices were "awful and robotic". Diagnosis:
- eSpeak NG is formant synthesis: buzzy, with no recorded-speech texture.
- Its female profiles had a narrow pitch range of 4–6 semitones.

The bank is now rendered with **CMU Flite 2.2** (Ubuntu `libflite1`, already installed; called through ctypes, so no model download). Its clustergen voices are statistical models trained on recorded speakers:

| Flite voice | Speaker | Used by |
|---|---|---|
| `cmu_us_slt` | US female | Marta, Priya, Joan, crew_f |
| `cmu_us_awb` | Scottish male | Dale, crew_m |
| `cmu_us_rms` | US male | Tomas |

**Licence:** permissive CMU terms: free use, modification and redistribution; keep the notice; mark modifications. Our modifications are listed below. No person was recorded or cloned for this project.

**Per-profile settings** (`tools/voice/profiles.json`, preset `p24-flite-v2`):
- target pitch and intonation spread, tuned so every character speaks with a natural 5.4–8.8 semitone range (measured);
- tempo;
- a small post-synthesis resample (`shift`), which acts like a slightly bigger or smaller speaker.

**Deliveries:**
- calm, effort, uneasy and frightened scale pitch, spread and tempo;
- whisper is an LPC noise-excited re-synthesis of the line (measured periodicity 0.34 against 0.87 for voiced speech, so genuinely unvoiced).

**Cleanup chain:**
- 80 Hz high-pass, a +3 dB presence band at 2–4.2 kHz for intelligibility, a 7.2 kHz soft top and light 2:1 compression;
- then the existing trim, per-delivery loudness, -1 dBFS peak limit and fades.

**QC:** every one of the 3,316 mappings validated (no empty, silent, clipped, too-short or too-long clips).

**In-game mix:**
- While a crew member speaks within 16 m (and not behind heavy occlusion), ambience dips 6 dB and work noise 3 dB. This uses an Amplify effect on those buses, so the player's sliders are untouched. Attack takes about 0.25 s and release about 1.1 s.
- Captions and mouth motion use the new durations from `data/voice/index.json`.

**Trade-off:** Flite's voices speak US English, apart from awb's Scottish speaker, while the cast notes below describe British accents. Intelligibility and a human sound were chosen over accent. The neural route (for example Kokoro) remains a possible later upgrade that needs the owner's go-ahead.

**Listening review:** awaiting the owner. The A/B pack (old, then new, for each profile) was delivered with the Phase 24 progress update.

## Phase 18: original eSpeak cast (kept for provenance)

All voices are **original synthetic voices** generated offline with **eSpeak NG 1.51** (Ubuntu package `espeak-ng 1.51+dfsg-12build1`), a formant speech synthesizer:
- No recorded performer and no cloned or imitated real person.
- eSpeak NG is GPL-3.0-or-later. It is a development tool only: it is **not** shipped with the game. Speech it renders is program output and carries no licence restriction.
- The neural route (Kokoro-82M, Apache-2.0) was considered but not used. Downloading and running outside model files was blocked by this session's safety check, so it is a possible later upgrade that needs the owner's go-ahead.

Settings live in `tools/voice/profiles.json` (preset `p18-v2-16k`).

| Profile | Worker | Accent (eSpeak voice + variant) | Pitch | Speed (wpm) | Gap | Character |
|---|---|---|---:|---:|---:|---|
| `marta` | EMP-01 Marta Kell | Lancaster (`en-gb-x-gbclan` + f4) | 40 | 168 | 3 | Brisk, dry lead hand; clipped rhythm |
| `dale` | EMP-02 Dale Ostrow | Southern British (`en-gb` + m3) | 26 | 148 | 5 | Big, slow, warm; pauses before the punchline |
| `priya` | EMP-03 Priya Lund | Received Pronunciation (`en-gb-x-rp` + f2) | 56 | 160 | 3 | Precise, calm, measured |
| `tomas` | EMP-04 Tomas Reyner | American (`en-us` + m7) | 60 | 176 | 2 | Young, quick, apologetic |
| `joan` | EMP-05 Joan Abernathy | West Midlands (`en-gb-x-gbcwmd` + f3) | 44 | 156 | 4 | Warm, chatty, sardonic |
| `crew_m` | replacement hires | Scottish (`en-gb-scotland` + m2) | 35 | 160 | 4 | Neutral workmanlike |
| `crew_f` | replacement hires | Caribbean (`en-029` + f1) | 50 | 160 | 4 | Neutral workmanlike |

**Assignment policy.**
- The five starting workers keep their profile for life.
- A replacement hire gets `crew_m` or `crew_f`, chosen from a hash of their employee id. It is persistent (save/load never changes it), and replacements never take a starting worker's voice.

**Deliveries.** Each line gets exactly one delivery, decided from its own situation by `delivery_for()` in `tools/voice/build_voices.py`. The runtime reads the delivery from the index.

| Delivery | When | Settings | Level | Lines (all profiles) |
|---|---|---|---:|---:|
| calm | Default | Profile settings | −20 dBFS RMS | 1,721 |
| effort | Short lines during cutting, carrying or yard work | +6 % speed, +2 pitch | −18.5 | 693 |
| uneasy | `mood:uneasy`, strange-event knowledge, survival, dusk nights | −7 % speed, −3 pitch | −21.5 | 322 |
| frightened | `mood:shaken` / `mood:refusing` | +10 % speed, +8 pitch | −19 | 51 |
| whisper | `act:hide` | eSpeak NG's own `whisper` / `whisperf` voices | −28 | 41 |

**Pronunciation overrides** (spoken only; subtitles keep the written text): Priya → Preeya, Abernathy → Abbernathy, Reyner → Rayner, Ostrow → Osstroh, Holm → Hohm, Lund → Lunnd. Lines that address the listener by name (`{listener}`, 37 lines) are voiced as "you", and their caption also says "you" so the words match.

**Processing.** Each clip is:
- trimmed of silence below −45 dB, keeping 40 ms pads;
- levelled per delivery and peak-limited at −1 dBFS;
- given 8 ms fades;
- resampled to 16 kHz;
- encoded as mono Ogg Vorbis.

Clips are flagged when empty, silent, clipped at the source, too short (< 0.35 s) or too long (> 2.6× the text estimate + 1 s).
