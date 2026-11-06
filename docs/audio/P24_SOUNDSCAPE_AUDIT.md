# Phase 24 soundscape audit: the loud "wash"

Route (same weather, day, island r2): beach, inland trail (`forest`), veteran grove (`p12_grove`), thick brush (`p12_thicket`), camper.

## How to reproduce

```bash
AUDIT_OUT=/tmp/audit.json godot --headless res://tools/audio/ambience_audit.tscn
```

```bash
python3 tools/audio/ambience_rms.py /tmp/audit.json report.md
```

The first command lists every playing player at each stop: event, file, bus, player dB, distance and distance attenuation. The second adds each file's measured RMS and sums the layers. "At ear" is an estimate in dBFS before the master bus.

## Finding
On the trail, in the grove and in the thick brush, the mix was the same four broadband layers at the same level, about -33 dBFS each and about -27.5 dBFS summed:

| Layer | Source | Why it read as a wash |
|---|---|---|
| `amb.forest.air` | noise room tone 2 m above the head | no distance falloff; never changes |
| `amb.insects.day` | broadband loop at the head | everywhere inland, including the grove |
| `amb.wind.pines` ×2 | loops parked 9 m left and right | inside the 12 m unit size, so full level even when calm |

None of these depended on the place, so a thicket sounded like an open trail.

## Changes
- **Wind:** follows the real wind with a square law (`0.03 + 0.75·ws²`) instead of `0.08 + 0.7·ws`, so calm days are about 6 dB quieter. It is 5 dB more sheltered inside thick brush.
- **Place beds:** chosen from the real surroundings: shore (near surf emitters), brush (soft-cover density > 0.4), grove (≥ 14 standing trees within 22 m), forest (≥ 4) or open.
  - Air beds are 6–7 dB lower.
  - New `amb.bed.brush` (close leaf movement, follows the wind) and `amb.bed.grove` (low, still).
- **Insects:** only at edges and in undergrowth. Louder in brush, absent in the grove and on the shore.
- **Footsteps:** new surfaces, each with 5 variants:
  - needles (conifer floor);
  - gravel (mill pad);
  - wet grass and mud (wetness > 0.45);
  - puddles in fixed hollows (wetness > 0.7, per 1.6 m cell, so the same spot always splashes).
- **Plant contact** (`CoverService`), by family from the real shrub kind:
  - grass/sedge: quiet, and only above a walk;
  - fern, bracken and hazel: leafy swish;
  - juniper, bramble and deadwood: dry scrape, then release;
  - any foliage when wet: damp, softer.

  Level follows density and speed. Each actor has its own cooldown, and a shared 0.26 s per-cell cooldown stops two actors in one bush from doubling up. Standing still in a bush makes no sound. Contacts go through SoundService, so they are occluded, recorded and hearable as evidence ("brush").
- **Music:** one original motif (`tools/content/soundscape24.py`, note lists editable in the file) in three arrangements:
  - day: warm pluck, pad and bass, with rests;
  - dusk: slower, no bass, settles on G;
  - night: minor colour, drifting tuning, unresolved on E, once per night between 21:30 and 23:00, never during the hunt or rain. It is scheduled by the clock only, so it never marks a threat.

  Pitch is verified: every plucked note is within 2 cents after the Karplus-Strong delay correction.

## Result (sum of layers at the ear)
| Stop | Before | After |
|---|---|---|
| Beach | -20.1 | -20.6 (surf dominates, as it should) |
| Inland trail | -27.5 | -33.5 |
| Veteran grove | -27.6 | -36.1 (grove bed; no insects) |
| Thick brush | -27.6 | -36.2 (brush bed, close insects, sheltered wind) |
| Camper | -34.6 | -38.5 |

Listening checks (awaiting hands-on review; this container has no audio output):
- the A/B walk on the same route;
- the motif on speakers;
- plant contact while sprinting through bracken versus bramble.

## Full tables

### Before

### beach

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.surf.near | surf_near_loop.ogg | Ambience | 15.2 | -2.0 | -2.0 | -16.4 | -21.9 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 39.4 | -2.0 | -10.3 | -16.4 | -30.1 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 43.7 | -2.0 | -11.2 | -16.4 | -31.0 |
| amb.wind.cleared | wind_cleared_loop.ogg | Ambience | 9.8 | -17.3 | 0.0 | -14.3 | -33.1 |
| amb.wind.cleared | wind_cleared_loop.ogg | Ambience | 9.8 | -17.3 | 0.0 | -14.3 | -33.1 |
| amb.field.air | field_air_loop.ogg | Ambience | 2.0 | -18.0 | 0.0 | -13.8 | -33.2 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience | 113.9 | -7.2 | -80.0 | -13.4 | -102.0 |
| amb.river.slow | water_slow_loop.ogg | Ambience | 220.6 | -6.0 | -80.0 | -17.0 | -104.4 |
| amb.river.fast | water_fast_loop.ogg | Ambience_O2 | 226.8 | -17.0 | -80.0 | -15.7 | -112.7 |
| home.fridge | fridge_hum_loop.ogg | Ambience | 100.3 | -24.0 | -80.0 | -9.5 | -114.9 |
| home.fan | fan_hum_loop.ogg | Ambience | 93.4 | -24.0 | -80.0 | -14.1 | -119.5 |

**Sum of layers: -20.1 dBFS**

### camper

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.wind.cleared | wind_cleared_loop.ogg | Ambience_O1 | 9.8 | -23.8 | 0.0 | -14.3 | -38.1 |
| amb.wind.cleared | wind_cleared_loop.ogg | Ambience_O2 | 9.8 | -27.7 | 0.0 | -14.3 | -42.0 |
| amb.field.air | field_air_loop.ogg | Ambience_O2 | 2.0 | -28.4 | 0.0 | -13.8 | -42.2 |
| home.fan | fan_hum_loop.ogg | Ambience | 4.4 | -24.0 | -6.1 | -14.1 | -45.6 |
| home.fridge | fridge_hum_loop.ogg | Ambience_O2 | 2.9 | -34.4 | -2.4 | -9.5 | -46.3 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 117.0 | -14.4 | -19.8 | -16.4 | -50.5 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience_O2 | 20.1 | -20.3 | -19.2 | -13.4 | -52.9 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 110.2 | -20.2 | -19.3 | -16.4 | -55.9 |
| fire.bed.large | fire_bed_large_loop.ogg | Ambience_O2 | 20.1 | -25.2 | -19.2 | -12.7 | -57.1 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 108.9 | -22.1 | -19.2 | -16.4 | -57.7 |
| amb.river.fast | water_fast_loop.ogg | Ambience_O2 | 227.3 | -27.4 | -80.0 | -15.7 | -123.1 |
| amb.river.slow | water_slow_loop.ogg | Ambience_O2 | 224.2 | -26.8 | -80.0 | -17.0 | -123.8 |

**Sum of layers: -34.6 dBFS**

### forest

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.forest.air | forest_air_loop.ogg | Ambience | 2.0 | -18.0 | 0.0 | -13.8 | -33.2 |
| amb.insects.day | insects_day_loop.ogg | Ambience | 2.0 | -22.0 | 0.0 | -10.4 | -33.8 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -17.3 | 0.0 | -15.1 | -33.9 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -17.3 | 0.0 | -15.1 | -33.9 |
| amb.bird.day | bird_thrush.wav | Ambience_O1 | 40.7 | -8.6 | -20.2 | -13.7 | -42.5 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 304.2 | -2.0 | -80.0 | -16.4 | -99.8 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 308.8 | -2.0 | -80.0 | -16.4 | -99.8 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 310.7 | -2.0 | -80.0 | -16.4 | -99.8 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience | 269.1 | -6.0 | -80.0 | -13.4 | -100.8 |
| amb.river.fast | water_fast_loop.ogg | Ambience | 414.7 | -4.0 | -80.0 | -15.7 | -101.1 |
| amb.river.slow | water_slow_loop.ogg | Ambience | 413.2 | -6.0 | -80.0 | -17.0 | -104.4 |
| fire.bed.large | fire_bed_large_loop.ogg | Ambience | 269.1 | -12.8 | -80.0 | -12.7 | -106.9 |
| fire.pop | fire_embers_settle.wav | Ambience | 269.1 | -8.0 | -80.0 | -23.9 | -113.3 |
| home.fridge | fridge_hum_loop.ogg | Ambience | 270.9 | -24.0 | -80.0 | -9.5 | -114.9 |
| dog.paw.dirt | paw_dirt_0.wav | Characters | 276.6 | -16.0 | -80.0 | -20.3 | -117.2 |
| home.fan | fan_hum_loop.ogg | Ambience | 276.3 | -24.0 | -80.0 | -14.1 | -119.5 |

**Sum of layers: -27.5 dBFS**

### p12_grove

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.forest.air | forest_air_loop.ogg | Ambience | 2.0 | -18.0 | 0.0 | -13.8 | -33.2 |
| amb.insects.day | insects_day_loop.ogg | Ambience | 2.0 | -22.0 | 0.0 | -10.4 | -33.8 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -17.3 | 0.0 | -15.1 | -33.9 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -17.3 | 0.0 | -15.1 | -33.9 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 168.7 | -15.0 | -23.0 | -16.4 | -54.4 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 182.9 | -15.0 | -23.7 | -16.4 | -55.1 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 188.6 | -15.0 | -23.9 | -16.4 | -55.3 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience | 167.3 | -6.0 | -80.0 | -13.4 | -100.8 |
| amb.river.slow | water_slow_loop.ogg | Ambience | 370.8 | -6.0 | -80.0 | -17.0 | -104.4 |
| fire.bed.large | fire_bed_large_loop.ogg | Ambience | 167.3 | -10.9 | -80.0 | -12.7 | -105.0 |
| fire.pop | fire_hiss_sap.wav | Ambience | 167.1 | -8.0 | -80.0 | -19.3 | -108.7 |
| amb.river.fast | water_fast_loop.ogg | Ambience | 373.5 | -16.0 | -80.0 | -15.7 | -113.1 |
| home.fridge | fridge_hum_loop.ogg | Ambience | 161.5 | -24.0 | -80.0 | -9.5 | -114.9 |
| dog.paw.dirt | paw_dirt_1.wav | Characters | 172.1 | -16.0 | -80.0 | -21.4 | -118.3 |
| home.fan | fan_hum_loop.ogg | Ambience | 164.8 | -24.0 | -80.0 | -14.1 | -119.5 |

**Sum of layers: -27.6 dBFS**

### p12_thicket

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.forest.air | forest_air_loop.ogg | Ambience | 2.0 | -18.0 | 0.0 | -13.8 | -33.2 |
| amb.insects.day | insects_day_loop.ogg | Ambience | 2.0 | -22.0 | 0.0 | -10.4 | -33.8 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -17.3 | 0.0 | -15.1 | -33.9 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -17.3 | 0.0 | -15.1 | -33.9 |
| amb.bird.day | bird_crow.wav | Ambience | 39.5 | -6.0 | -19.9 | -18.7 | -46.0 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 138.5 | -15.0 | -21.2 | -16.4 | -52.6 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 149.8 | -15.0 | -21.9 | -16.4 | -53.3 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 158.0 | -15.0 | -22.4 | -16.4 | -53.8 |
| amb.river.slow | water_slow_loop.ogg | Ambience_O2 | 182.5 | -19.0 | -23.6 | -17.0 | -59.6 |
| amb.river.fast | water_fast_loop.ogg | Ambience_O2 | 185.9 | -29.0 | -23.8 | -15.7 | -68.5 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience | 54.8 | -6.0 | -80.0 | -13.4 | -100.8 |
| fire.bed.large | fire_bed_large_loop.ogg | Ambience | 54.8 | -10.9 | -80.0 | -12.7 | -105.0 |
| home.fridge | fridge_hum_loop.ogg | Ambience | 73.0 | -24.0 | -80.0 | -9.5 | -114.9 |
| dog.paw.dirt | paw_dirt_0.wav | Characters | 57.2 | -16.0 | -80.0 | -20.3 | -117.2 |
| home.fan | fan_hum_loop.ogg | Ambience | 78.7 | -24.0 | -80.0 | -14.1 | -119.5 |

**Sum of layers: -27.6 dBFS**
### After

### beach

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.surf.near | surf_near_loop.ogg | Ambience | 15.2 | -2.0 | -2.0 | -16.4 | -21.9 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 39.4 | -2.0 | -10.3 | -16.4 | -30.1 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 43.7 | -2.0 | -11.2 | -16.4 | -31.0 |
| amb.wind.cleared | wind_cleared_loop.ogg | Ambience | 9.8 | -23.3 | 0.0 | -14.3 | -39.0 |
| amb.wind.cleared | wind_cleared_loop.ogg | Ambience | 9.8 | -23.3 | 0.0 | -14.3 | -39.0 |
| amb.field.air | field_air_loop.ogg | Ambience | 2.0 | -24.0 | 0.0 | -13.8 | -39.2 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience | 113.9 | -7.2 | -80.0 | -13.4 | -102.0 |
| amb.river.slow | water_slow_loop.ogg | Ambience | 220.6 | -6.0 | -80.0 | -17.0 | -104.4 |
| amb.river.fast | water_fast_loop.ogg | Ambience_O2 | 226.8 | -17.0 | -80.0 | -15.7 | -112.7 |
| home.fridge | fridge_hum_loop.ogg | Ambience | 100.3 | -24.0 | -80.0 | -9.5 | -114.9 |
| home.fan | fan_hum_loop.ogg | Ambience | 93.4 | -24.0 | -80.0 | -14.1 | -119.5 |

**Sum of layers: -20.6 dBFS**

### camper

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.wind.cleared | wind_cleared_loop.ogg | Ambience_O1 | 9.8 | -29.8 | 0.0 | -14.3 | -44.1 |
| home.fan | fan_hum_loop.ogg | Ambience | 4.4 | -24.0 | -6.1 | -14.1 | -45.6 |
| home.fridge | fridge_hum_loop.ogg | Ambience_O2 | 2.9 | -34.4 | -2.4 | -9.5 | -46.3 |
| amb.wind.cleared | wind_cleared_loop.ogg | Ambience_O2 | 9.8 | -33.7 | 0.0 | -14.3 | -48.0 |
| amb.field.air | field_air_loop.ogg | Ambience_O2 | 2.0 | -34.4 | 0.0 | -13.8 | -48.2 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 117.0 | -14.4 | -19.8 | -16.4 | -50.5 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience_O2 | 20.1 | -20.3 | -19.2 | -13.4 | -52.9 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 110.2 | -20.2 | -19.3 | -16.4 | -55.9 |
| fire.bed.large | fire_bed_large_loop.ogg | Ambience_O2 | 20.1 | -25.2 | -19.2 | -12.7 | -57.1 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 108.9 | -22.1 | -19.2 | -16.4 | -57.7 |
| amb.river.fast | water_fast_loop.ogg | Ambience_O2 | 227.3 | -27.4 | -80.0 | -15.7 | -123.1 |
| amb.river.slow | water_slow_loop.ogg | Ambience_O2 | 224.2 | -26.8 | -80.0 | -17.0 | -123.8 |

**Sum of layers: -38.5 dBFS**

### forest

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -23.3 | 0.0 | -15.1 | -39.8 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -23.3 | 0.0 | -15.1 | -39.8 |
| amb.forest.air | forest_air_loop.ogg | Ambience | 2.0 | -25.0 | 0.0 | -13.8 | -40.2 |
| amb.insects.day | insects_day_loop.ogg | Ambience | 2.0 | -29.0 | 0.0 | -10.4 | -40.8 |
| amb.bird.day | bird_thrush.wav | Ambience_O1 | 40.7 | -8.6 | -20.2 | -13.7 | -42.5 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 304.2 | -2.0 | -80.0 | -16.4 | -99.8 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 308.8 | -2.0 | -80.0 | -16.4 | -99.8 |
| amb.surf.near | surf_near_loop.ogg | Ambience | 310.7 | -2.0 | -80.0 | -16.4 | -99.8 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience | 269.1 | -6.0 | -80.0 | -13.4 | -100.8 |
| amb.river.fast | water_fast_loop.ogg | Ambience | 414.7 | -4.0 | -80.0 | -15.7 | -101.1 |
| amb.river.slow | water_slow_loop.ogg | Ambience | 413.2 | -6.0 | -80.0 | -17.0 | -104.4 |
| fire.bed.large | fire_bed_large_loop.ogg | Ambience | 269.1 | -10.9 | -80.0 | -12.7 | -105.0 |
| fire.pop | fire_embers_settle.wav | Ambience | 269.1 | -8.0 | -80.0 | -23.9 | -113.3 |
| home.fridge | fridge_hum_loop.ogg | Ambience | 270.9 | -24.0 | -80.0 | -9.5 | -114.9 |
| home.fan | fan_hum_loop.ogg | Ambience | 276.3 | -24.0 | -80.0 | -14.1 | -119.5 |

**Sum of layers: -33.5 dBFS**

### p12_grove

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -23.3 | 0.0 | -15.1 | -39.8 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -23.3 | 0.0 | -15.1 | -39.8 |
| amb.bed.grove |  | Ambience | 2.0 | -24.0 | 0.0 | ? | -45.4 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 168.7 | -15.0 | -23.0 | -16.4 | -54.4 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 182.9 | -15.0 | -23.7 | -16.4 | -55.1 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 188.6 | -15.0 | -23.9 | -16.4 | -55.3 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience | 167.3 | -6.0 | -80.0 | -13.4 | -100.8 |
| amb.river.slow | water_slow_loop.ogg | Ambience | 370.8 | -6.0 | -80.0 | -17.0 | -104.4 |
| fire.bed.large | fire_bed_large_loop.ogg | Ambience | 167.3 | -10.9 | -80.0 | -12.7 | -105.0 |
| amb.river.fast | water_fast_loop.ogg | Ambience | 373.5 | -16.0 | -80.0 | -15.7 | -113.1 |
| fire.pop | fire_pop_0.wav | Ambience | 167.1 | -8.0 | -80.0 | -24.6 | -114.0 |
| home.fridge | fridge_hum_loop.ogg | Ambience | 161.5 | -24.0 | -80.0 | -9.5 | -114.9 |
| home.fan | fan_hum_loop.ogg | Ambience | 164.8 | -24.0 | -80.0 | -14.1 | -119.5 |

**Sum of layers: -36.1 dBFS**

### p12_thicket

| Layer (event) | File | Bus | Dist m | Player dB | Distance dB | File RMS dBFS | At ear dBFS |
|---|---|---|---|---|---|---|---|
| amb.insects.day | bees_loop.ogg | Ambience | 2.0 | -24.0 | 0.0 | -13.9 | -39.3 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -28.3 | 0.0 | -15.1 | -44.8 |
| amb.wind.pines | wind_pines_loop.ogg | Ambience | 9.8 | -28.3 | 0.0 | -15.1 | -44.8 |
| amb.bird.day | bird_woodpecker.wav | Ambience | 39.5 | -6.0 | -19.9 | -19.1 | -46.4 |
| amb.bed.brush |  | Ambience | 2.0 | -26.5 | 0.0 | ? | -47.9 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 138.5 | -15.0 | -21.2 | -16.4 | -52.6 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 149.8 | -15.0 | -21.9 | -16.4 | -53.3 |
| amb.surf.near | surf_near_loop.ogg | Ambience_O2 | 158.0 | -15.0 | -22.4 | -16.4 | -53.8 |
| amb.river.slow | water_slow_loop.ogg | Ambience_O2 | 182.5 | -19.0 | -23.6 | -17.0 | -59.6 |
| amb.river.fast | water_fast_loop.ogg | Ambience_O2 | 185.9 | -29.0 | -23.8 | -15.7 | -68.5 |
| fire.bed.small | fire_bed_small_loop.ogg | Ambience | 54.8 | -6.0 | -80.0 | -13.4 | -100.8 |
| fire.bed.large | fire_bed_large_loop.ogg | Ambience | 54.8 | -10.9 | -80.0 | -12.7 | -105.0 |
| home.fridge | fridge_hum_loop.ogg | Ambience | 73.0 | -24.0 | -80.0 | -9.5 | -114.9 |
| dog.paw.dirt | paw_dirt_0.wav | Characters | 57.2 | -16.0 | -80.0 | -20.3 | -117.2 |
| home.fan | fan_hum_loop.ogg | Ambience | 78.7 | -24.0 | -80.0 | -14.1 | -119.5 |

**Sum of layers: -36.2 dBFS**