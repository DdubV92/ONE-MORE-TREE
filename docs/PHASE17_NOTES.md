# Phase 17: crew conversations and the camper internet

Status key:
- **observed:** an automated test, a validator, or a headless simulation.
- **unrun:** implemented but not exercised.
- **gap:** not done.

Counts below come from the parsed data files (`tools/content/manifest.py`). They are not estimates.

## What the crew says, and when

- **The bank.** The crew dialogue bank (`data/dialogue/crew/*.json`) holds **1,676 authored lines** in 12 category files.

  | Category | Lines |
  |---|---:|
  | cutting | 131 |
  | hauling | 131 |
  | tools | 128 |
  | ethic | 129 |
  | weather | 120 |
  | pair banter | 157 |
  | group | 134 |
  | boss | 243 |
  | camp | 122 |
  | wages | 127 |
  | dusk | 127 |
  | survival | 127 |

  Character-specific lines:

  | Worker | Lines |
  |---|---:|
  | Marta Kell | 285 |
  | Dale Ostrow | 289 |
  | Priya Lund | 278 |
  | Tomas Reyner | 277 |
  | Joan Abernathy | 278 |

  The other 146 lines are role lines (`any`) and 123 are trait lines. Each authored text is counted once.

  The validator reports 0 errors, 0 exact duplicates and 0 near-duplicates (word-trigram Jaccard ≥ 0.6 within a category). Every response link resolves. The older Phase 4 functional lines (about 90, `crew_dialogue.gd`) remain as fallbacks and are **not** counted.
- **Line records.** Each line has:
  - a stable id (Phase 18 voice key: `res://audio/voice/<voice>/<id>.ogg`) and a voice profile per worker;
  - a category and speaker (a worker, a role or a trait);
  - the listener type (pair/group/boss/self) and, for boss lines, the talk-menu topic;
  - situation predicates, knowledge needs and response edges;
  - priority, repetition class and interruption policy;
  - the text.

  The format and vocabulary are in [editorial/CREW_SCHEMA.md](editorial/CREW_SCHEMA.md); the cast sheet is [editorial/CAST.md](editorial/CAST.md).
- **Runtime** (`ConversationService`, one owner per camp):
  - About every 25–70 s, a worker and the people actually beside them (6 m for a pair, 8 m for a group of up to 4) are offered the eligible openers.
  - Choice is seeded per campaign and weighted towards specific, higher-priority lines.
  - **Before every turn** it re-checks:
    - that everyone is still there, able and within range;
    - that the line still fits the situation (activity, phase, place, weather, mood, belief, trust, wages, the Phase 16 idle cause, level, tools, clearing progress, crew size, the boss's rest);
    - that the speaker still has the knowledge it needs.
  - A response comes from a different participant only when its own conditions hold, up to 4 turns.
  - Gaps between lines vary.
  - **Cooldowns:** per line (10 min / about a day / about 5 days / once), per category (60 s) and per group (150 s). They survive save/load (observed).
- **Suppression** (observed for interruption):
  - near a running chainsaw (12 m);
  - within 30 m of a tree that just gave its fall warning;
  - during a two-person carry;
  - during the hunt when the hunter is within 45 m (except whispers from hiding);
  - when anyone has left, died or gone into hiding.

  An interrupted exchange is dropped, or resumes within 20 s if the line allows it.
- **Knowledge.**
  - Firsthand memories (what they saw or heard themselves) are kept apart from things they were *told*. A told claim is now recorded with its source, a lower confidence and the time.
  - A firsthand-only line is ineligible until the worker really has evidence (observed).
  - When a witness speaks such a line, the listeners gain a *told* claim, never firsthand evidence (rumor transfer, observed).
  - Praise, level-ups, colleague progress, team carries, waiting frustration and owed wages come from the Phase 16 context facts, including who was there to know them.
- **Hearing.** Subtitles reach the player only within hearing: about 14 m with a clear line, 6 m through a wall, 4 m for whispers. The "Subtitles" setting hides them, and a new "Crew subtitle duration" setting scales how long they stay. Duration follows the text length.
- **The boss.** The talk menu answers work, blockers, strange events and wages, and adds "Anything holding you up?" and "Good work today". "Good work today" thanks a real contribution through Phase 16 recognition, once each. Replies use the most specific authored line that is true for that worker, falling back to the older line.
- **Workers call out to the boss** with short reports and observations when nearby, rate-limited.
- **Phase 18 hook.** If a clip exists for a line it plays from the speaker's mouth and its length times the turn. None exist yet, so the game is text only.

## The camper internet

- **The bank.** The fictional internet (`data/feed/*.json`, accounts in `data/feed/accounts.json`) holds **__FEED__ authored units** in 11 day-range batches. Every unit is one substantive email, news paragraph or live update, forum post, advisory or archive entry.

  | Kind | Units | Minimum |
  |---|---:|---:|
  __KINDS__

  - **Accounts:** **94 recurring fictional accounts**, each with an occupation, region, time zone, posting window, voice, knowledge, claims, relations and a trajectory. They include moderators, skeptics, night workers in six other time zones, Dellow Court residents, harbour and ferry crew, linemen, recordists, historians, and the boss's mailbox cast.
  - **Validator** (`tools/content/validate_feed.py`):
    - 0 errors;
    - every author exists;
    - every reply follows a published parent in the same thread and branch;
    - every quote and link points to an earlier unit;
    - titles are present, slots and flags are valid;
    - no exact or near-duplicates (word-trigram Jaccard ≥ 0.5, across the whole bank).
  - **Editorial bible:** [editorial/FEED_BIBLE.md](editorial/FEED_BIBLE.md), covering the world, sites, the ten arcs A–J with day beats, and the rules. The calendar is [editorial/FEED_CALENDAR.md](editorial/FEED_CALENDAR.md) and the batch manifest is [editorial/CONTENT_MANIFEST.md](editorial/CONTENT_MANIFEST.md).
- **Publication** (`FeedService`), from the authoritative clock:
  - daytime units appear at their second of the workday, dusk units after 900 s, and night units as the boss stays awake into the bounded night;
  - **whatever is left of a day publishes when the day ends at sleep**, so the next morning brings a short "since you last looked" digest rather than a burst of alerts;
  - survival days 31–35 follow the continuous hunt clock and only appear in a failed contract (`if:hunt`);
  - at most 240 units count against one day; extras roll over;
  - `mx:` alternatives are fixed per campaign;
  - `if:`/`unless:` flags (wages owed, a worker left, dog rescued, truck or saw owned, clearing progress, late reading, a night event, hunt, rescue) are decided once, when the unit falls due;
  - replies whose parent wasn't published are skipped with it;
  - refreshing never rerolls anything;
  - edits apply after their delay, and removed posts show a moderation note.
- **Simulation results:**
  - **Calendar** (`tools/content/feed_calendar.py`): __CAL__.
  - **Unit test:** early sleep and live late-night reading end each day with the same published set (observed). A mid-campaign save/load republishes nothing. Repeated refresh adds nothing. No day exceeds the cap, no reply appears before its parent, and no quote spoils an unpublished post.
- **Reading** (camper computer: **Mail, News, Forums, Archives**; Recordings stays a labelled Phase 19 placeholder):
  - unread counts on the app buttons;
  - a catch-up digest;
  - bounded pages of 30 threads;
  - bookmarks;
  - reply depth;
  - quoted context;
  - edit and moderation notes;
  - back navigation and restored scroll position.

  Mail also shows the live supplier order status from the real order records (company and personal mail is authored, and flag-gated where it depends on state). Reading is live time and optional: it never blocks wages, bedtime, completion or rescue. A gentle "new messages" notice appears at most every 3 minutes while you are in the camper.

## Computer-linked patterns (handoff to Phase 19)

| Hook | Status |
|---|---|
| cl01, the window warning | **Implemented.** |
| cl02 – cl12 | Authored once each (__HOOKS__). Recorded as opportunities through `TerrorDirector.computer_hint()` for the Phase 19 catalog; they never trigger anything by themselves. |

How cl01 works:
- The Lamp Hours thread turns over days 22–24 on one campaign side (`mx:window:a`). The other side ends ordinarily.
- At the moment the final message is due, `FeedService.window_reservation()` checks:
  - the boss is reading at the desk;
  - they are not already glancing out;
  - it is contract night;
  - the curtains are open;
  - a Phase 11 staging spot outside the right-hand window exists;
  - it isn't a camper interior;
  - no awake worker within 25 m would plainly see it;
  - the director is free and the global pacing allows it.
- The director then has to really start an **ordinary** camper-context window event (intensity ≤ 2) through its normal placement and reservation.
- Only then is the warning published. Otherwise the authored fallback continuation ("Sorry. That was a stupid thing to post…") appears instead.
- Unit test: without a valid reservation the warning never publishes (observed). The camera is never moved, nothing spawns inside the camper, and camper immunity is unchanged.

## Preview review route

Preview → Tab → **"Phase 17 crew talk & the camper internet"**:

| # | Stop | What it does |
|---|---|---|
| 1 | Start a crew conversation | Two workers in front of you; the opening line id is shown |
| 2 | Conversation inspector | Why the nearest worker can or can't say lines right now |
| 3 | Feed: publish next day | Preview only |
| 4 | Feed counts & digest | |
| 5 | Window-warning check | The live reservation answer and reason |
| 6 | How to read the feed | |

## Known limits (honest)

- **No voices yet.** Lines are text only. Stable ids and the `SoundService.speak` hook are ready for Phase 18.
- **Simplified knowledge.** Knowledge comes from WorkerMind memories plus the Phase 16 context facts, so a worker can't yet discuss specific internet posts (nobody reads the boss's computer).
- **Hearing** is distance plus one ray, not the full acoustic path.
- **One conversation at a time.** Only one conversation runs per camp (deliberately sparse). Groups are capped at 4.
- **Unplayed by a person.** The reader UI was built and exercised headless only (no human playtest, no screenshot pass). Long reading sessions at 5,000+ published units were not profiled on real hardware.
- **Phase 19 hooks.** cl02 – cl12 are authored hooks only; Phase 19 executes them.
- **Archived posts** are not searchable.
