# Voice cast sheet (Phase 18)

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
