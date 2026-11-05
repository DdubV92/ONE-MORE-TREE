# ONE MORE TREE LATEST BUILD PHASE 22 (longer workdays)

The download link is in the session message (GitHub Actions artifact "ONE MORE TREE LATEST BUILD PHASE 22 - build N (Windows)").

Extract the zip to a new folder and run `OneMoreTree.exe`. `OneMoreTree.console.exe` is the same game with a console window, useful for logs. If SmartScreen warns, choose More info, then Run anyway. `NOTICES.txt` lists the attributions and the synthetic-voice notice.

## New in Phase 22

- **Longer workdays:** 20 minutes of daylight (was 15) plus 5 minutes of dusk. The contract is still 30 days.
- Everything timed within the day moves with it: the midday break, the weather (afternoon showers stay in the afternoon), the internet's posting times, the supplier's hours and the lighting.
- A full day doesn't tire you more than before. The hunt nights are unchanged.
- Older saves: a save made at night stays night; a daytime save simply has more daylight left.

## Phase 21 (previous build): your payroll request

- **Cheaper, negotiated wages.** Each worker has their own daily rate, from a **$100 minimum** (was a flat $300). New campaigns start everyone at $100; older saves keep $300 so nobody's pay is cut.
- **Payroll app** on the camper computer (sit at the desk → Payroll):
  - **The crew table:** each worker's pay mood, useful work and work done today, what that work is worth, their rate, bonus, performance bonus and tonight's pay.
  - **Click a worker for the details:**
    - the pay they think is fair;
    - how many nights they have been on the minimum;
    - **+/- $25** rate buttons, a one-day bonus and a performance bonus (10 / 25 / 50% of the value of the work they really did).
  - **Last night:** that night's pay report.
  - **Campaign report:** the end-of-game pay report (who earned what, the value of their work, who left and why).
- **Pay mood and quitting:**
  - Everyone has a fair wage in their own eyes, from their personality, level and gear.
  - Paid below it, their mood drops. A patient, modest worker puts up with the minimum for about a week; a demanding one leaves after a few nights, and sometimes even +$50 is not enough.
  - You always get at least one day of "on the verge of quitting" warning first.
  - Unhappy workers also take longer breaks.
- **Raise requests:** after better gear or a level-up, a worker may ask for a raise. Give it, pay a one-day bonus instead, or decline: some take a refusal harder than others.
- **Review:** Preview → Tab → "Phase 21 payroll" (open the app, a worker about to quit, a raise request, simulate a pay night).
- **Still true:** the contract math (blocker B1) is unchanged. Cheaper wages keep your cash alive much longer, but the crew still cannot fell 10,000 trees in 30 days.

## Phase 20 (previous build)

- **Nights you sleep through can leave evidence.**
  - Sometimes a camp camera flags something while you sleep (36 different incidents).
  - In the morning you get a notice, and sometimes a harmless mark: wet prints, a moved chain, a branch at the gate. It is gone by midday.
  - Watch it on the camper computer under **Recordings**: a reconstruction of that night, labelled PLAYBACK, with play/pause, seek and previous/next.
- **Rare sleep interruptions** (24 kinds, many nights stay quiet):
  - a heavy blow on the door, something brushing the wall, a call outside, and more;
  - you are always safe in the camper, and you can go back to sleep right after.
- **The forest entrance has a real gate now:** a galvanized tube gate standing open against the fence, with its chain. The night recordings and sounds about "the gate" use it.
- **Prepared saves for testing** (in `prepared_saves/`, with a README): day 30 just before the deadline, day 3 just before the survey ship, and hunt night 35 just before the rescue. Copy one to save slot 2 and load it.
- **Fixes:**
  - a late attack can no longer undo a successful escape;
  - a crash during saving no longer loses your newest save;
  - recording playback is no longer blocked by the camera's own housing, and the live-camera inset no longer covers the playback buttons.
- **Verified:** this exact build launched on a clean Windows machine and a clean Linux machine. It booted, kept settings, started a 10,000-tree campaign with five employees, walked, saved and loaded.
- **Review:** Preview → Tab → "Phase 20 …" (stage a recording, play an interruption, the release checklist).

**Honest status: TEST CANDIDATE.** The 30-day contract cannot currently be completed under the fixed rules: the crew manages a few trees a day, not the ~333 a day the contract needs. Every campaign ends in the five-night survival. This needs your decision; see docs/PHASE20_RC_REPORT.md. Not yet seen on a real GPU or heard on real audio.

## Phase 19 (previous build)

- **A crew day has a shape.**
  - Each worker gets a role for the day (felling, sawing, hauling, the yard), chosen from their tools, traits and what is waiting. Jobs you assign still win.
  - A transport plan: carry, handcart or truck runs, depending on how far out the work is.
  - **A midday break:** everyone near camp sits at the fire and talks, about each other's actual work. Somebody calls Biscuit over.
- **Hiding during the five nights is fairer and harder.**
  - Dense thickets you can crouch into, two field sheds out in the far logging areas (with a back hatch), and a gear chest at the dock.
  - Nothing is a safe zone. If the Foreman sees you go in, it knows where to look; up close, brush won't hide you.
  - When you leave a hide, you take the way out away from it.
- **Something offshore.**
  - Every third day a large ship comes out of the haze, slows as it passes camp, makes one full lap of the island and leaves.
  - Its helicopter takes off from the stern, sweeps the island and passes over camp, then lands back on the moving ship.
  - The crew notice it in their own ways, based only on what each of them actually saw or heard.
  - There is nothing to do about it.
- **Review:** Preview → Tab → "Phase 19 …" (the ship, the helicopter, each new hide, the cover audit, the gathering, roles).

**Honest limits:** checked headless only. Not seen on a real GPU, and the new ship and rotor sounds have not been heard.

## Phase 18 (previous build) (headphones recommended)

- **The crew speaks.**
  - Every crew line is voiced: five distinct voices for Marta, Dale, Priya, Tomas and Joan, plus two for anyone you hire later.
  - Lines are calm, strained while working, uneasy, frightened, or whispered when hiding.
- **Voices come from the speaker** and move with them, through doors and walls like other sounds.
- **Subtitles** stay up exactly as long as the line.
- **Mouths move** while workers speak.
- **Camera microphones** pick up speech on the desk computer, without doubling what you already hear.
- **Review:** Preview → Tab → "Phase 18 crew voices" (each worker, an exchange, a distance ladder, a lineup).

**Honest limits:** the voices are computer-generated (eSpeak NG), clearly synthetic, and **not yet listened to** (no audio output on the build machine). Please report any line that sounds wrong.

## Phase 17 (previous build)

- **The crew talks.**
  - Nearly 1,700 written lines in five distinct personalities: work, tools, weather, banter, groups, camp life, wages, dusk, strange things and survival.
  - Workers talk when they are actually together and it fits what they are doing and what they know. A rumor stays a rumor; only someone who saw something describes it.
  - They go quiet around a running saw, a falling tree or danger.
  - Subtitles show only when you could hear them. Settings → "Crew subtitle duration" controls how long they stay up.
- **Talking to a worker** now uses these lines, with "Anything holding you up?" and "Good work today" (which thanks a real piece of work, once).
- **The camper computer** has **Mail, News, Forums and Archives**: an offline fictional internet of over 5,500 posts, articles, emails, notices and archive entries.
  - New material arrives by day, at dusk and at night; anything you miss is waiting the next morning with a short digest.
  - Bookmarks and unread marks; your place in a thread is remembered.
  - Reading is optional and live time.
- **Review:** Preview → Tab → "Phase 17 crew talk & the camper internet".

**Not yet:** voices (Phase 18). Simulated and validated, not yet played by a person.

## Phase 16 (previous build)

- **Your crew grows through real work.**
  - Each tree is worth up to 1,000 "merit", shared by whoever felled, sectioned, de-stumped, carried, drove, stacked or fed it. Your own work stays yours.
  - Merit raises a career level (1–20) and four skills: cutting, handling, driving and teamwork. Each skill has a small, real, capped effect.
  - Merit never pays money and never changes wages.
- **Journal → Crew** shows, for each worker:
  - level and merit to the next level;
  - each skill's effect;
  - today's time split, with the real reasons for waiting (a full yard is a logistics problem, not laziness);
  - a suggestion;
  - "Thank them" buttons for specific work (once each).

  Each end-of-day report now includes a short crew review.
- **Your restedness.**
  - A workday costs about a third of your rest.
  - Staying up after nightfall costs more and makes tonight's sleep less restful.
  - The bed shows what tomorrow will be like before you sleep. Journal → Rest has the full forecast.
  - When tired you walk up to 15 % slower and cut up to 20 % weaker, and the clock line says "Tired". Going to bed before nightfall fully restores you.
  - Tiredness never hurts you or makes the camper unsafe.
- **Survival days.** Sitting still on the couch or hiding recovers a little rest while time keeps running.
- **Review.** Preview (title screen) → Tab → "Phase 16 crew growth & restedness" (8 stops).

**Checks:** see PHASE16_NOTES.md. Simulated, not yet played by a person.

## Phase 15 (previous build): sound

- **About 200 new sounds:**
  - axe bites by species and thickness;
  - trunk strain and hinge cracks;
  - falls sized by the tree;
  - logs on ground, rack, cart and decks;
  - a layered chainsaw;
  - a truck with engine, tyres and cargo;
  - the dog's paws, tags and voice;
  - doors, the fridge and the computer;
  - surf, rivers, frogs, wind by vegetation, rain on each roof, thunder from the flash;
  - night insects and owls;
  - more physical night encounters.
- **Every sound comes from where it happens** and turns with your head.
- **Walls muffle each sound separately.** In the camper with the door closed, outside sounds are muffled while your desk stays clear. With the door open, they come through the doorway.
- **Small rooms** (camper, cabin) have their own short reverb. Far sounds arrive late, at the speed of sound.
- **New Relay volume slider:** the desk camera microphones now have their own slider, separate from TV.
- **Audition route:** Preview (title screen) -> Tab -> "Phase 15 sound audition" (distance, rotation, door, indoor/outdoor, work, chainsaw, truck and dog, ambience, relay, replay, quiet night, worst overlap).

**Honest limits:** every sound is an original procedural approximation. There are no recordings, and **none of them has been listened to yet**, because this build machine has no audio output. A few older sounds remain (footsteps, music, some night families). There is no HRTF, only stereo panning. Please report anything that sounds wrong, too loud, or comes from the wrong place.

Extract the zip to a new folder and run `OneMoreTree.exe`. If SmartScreen warns, choose More info, then Run anyway.

## Phase 14 (previous build)

- **Axes feel different:** all three swing at the same rhythm; bigger axes bite deeper per hit (x1.00 / x1.40 / x1.96).
- **Chainsaw:**
  - `4` to hold it, `R` (or squeezing the attack button) to start it, hold the attack button for throttle, and `R` to stop.
  - It cuts only while the running chain is in the wood: about 3x a hatchet over whole trees.
  - Hiding, sitting, driving, sleeping or picking up logs stops it at once.
- **Gear:** boots (+3/6/9 % walking), gloves (+2/4/6 % axe rhythm, quicker saw start) and helmets (+2/4/6 % axe work per hit). One of each is worn, and a better tier replaces a worse one.
- **Supplier on the camper computer:**
  - order tools and gear with the exact benefit shown, see your cash after the order and a payroll warning, and confirm;
  - the supply boat (about 10:30 and 15:00) brings orders to the **parcel locker** by the payroll board;
  - collect them into camp storage, then equip them or hand them to a worker at the tool rack or in the computer's **Gear** app;
  - orders are prepaid and refunded if the contract ends before delivery. The computer's **Mail** app lists your order notices.
- **Crew:** workers wear and use the gear and saws you give them (changes happen between jobs). Fellers keep everyone else out of each tree's fall line. Two workers carry a heavy log together when someone is free.
- **Saves:** older campaigns keep their axes (now item records) and their progress.
- **Review:** Preview (title screen) -> Tab -> "Phase 14 tools, gear, supplier & teamwork".

**Checks:** see PHASE14_NOTES.md. Visuals were checked on a software renderer only. The chainsaw sounds are interim procedural placeholders (Phase 15 replaces the audio).

## Phase 13

- **Longer logs (new campaigns):** about 7 logs per tree instead of 9, each about 1.7 m. Every tree still pays exactly $100.
- **Dragging:** a log too heavy to lift can be dragged by one end. You walk slowly and can't jump.
- **Logging yard:**
  - a receiving cradle by the fire (12 logs);
  - three log decks outside the north-east fence;
  - the fire's own loading pile (12 logs).
- **Paid when the yard takes it:** if the cradle or a deck is full, the delivery is refused and not paid until there is room. The log stays with you.
- **Feed the fire:** it burns only from its loading pile. Carry paid logs from the cradle or decks to the fire (E at the pit).
- **Handcart:** load up to 4 logs, grab the handle and push it to the cradle or a deck, then unload. Only what fits is accepted.
- **Crew:** Journal → Crew → **Yard** puts a worker on stacking and feeding. Workers on Auto help when the yard is getting full or the fire is low.
- **Trucks:** they unload what fits and keep the rest.
- **Daily report:** shows wood processed, accepted (by hand, cart or truck), burned, and the yard stock.
- **Saves:** existing campaigns keep their logs and rules. On first load, an old save's big fire backlog moves onto the decks (no change to money).
- **Review:** Preview (title screen) → Tab → "Phase 13 logging yard, longer logs & cart".

**Checks:** see PHASE13_NOTES.md. Visuals were checked on a software renderer only.

## Phase 12 (earlier)

The dense 10,000-tree island, the owner's Mixamo clips and proper fabrics. See PHASE12_NOTES.md.
