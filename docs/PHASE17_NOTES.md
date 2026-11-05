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

**[FEED NUMBERS FILLED IN AT THE END]**

## Computer-linked patterns

**[FILLED IN AT THE END]**

## Known limits (honest)

**[FILLED IN AT THE END]**
