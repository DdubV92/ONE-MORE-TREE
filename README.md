# One More Tree

A first-person, single-player, cozy logging game on a large, finite island, built with **Godot 4.5.1 (Forward+), typed GDScript, desktop**.

**Current state: Phase 5, "Two pickups, a living camp, dock and dog, couch TV and ten live cameras".** Everything from Phases 0–4 is in (the island, felling, bucking and carrying, the 30-day contract, pay and wages, the working crew). New: two drivable logging pickups ($9,000 each after 50 delivered tree-equivalents) that you or a worker team drive, load and unload for pay through the same ledger; a finished service dock with a utility building and beacon console; Biscuit the dog, who lives a day in camp and walks home through the flap in the camper door at dusk; a couch TV with ten real security cameras on a rotating 2×2 wall, focus mode and remote microphones played through the TV; camper lights, curtains and coffee; two original arcade games that pause the world. The night director and the survival hunt (Phase 6) come next.

## Play a test build (recommended)

1. On GitHub, open **Actions → "Validate and build"**. Pick the latest green run on `main` or a `phase-*` branch.
2. At the bottom of the run page, under **Artifacts**, download `OneMoreTree-windows-x86_64-…` (a ZIP).
3. Extract the whole ZIP into its own folder. Keep `OneMoreTree.exe` and `OneMoreTree.pck` together.
4. Run `OneMoreTree.exe`. Windows SmartScreen may warn that the app is unsigned: choose *More info → Run anyway*.
5. On the title screen, pick **Preview Tour** for a quick review, or **Explore the island**.

You need a GPU with Vulkan support, because the game uses the Forward+ renderer.

## Fallback: run from source

1. Download the repository (green **Code** button → *Download ZIP*) and extract it.
2. Install **Godot 4.5.1-stable**, the standard build (not .NET), from godotengine.org.
3. In Godot's Project Manager, choose **Import**, select `project.godot`, and open it. The first import takes a minute.
4. Press **F5** to run.

## Sending feedback

- Send screenshots and short clips.
- Send a diagnostic report. Press **F12** in game, or open the pause menu and choose **Write diagnostic report**. On Windows, reports are saved to `%APPDATA%\Godot\app_userdata\One More Tree\diagnostics\`, and the latest is always `diagnostics_latest.txt`. Reports include the build commit, engine version, quality preset, GPU, frame-time stats and errors. Home folders are stripped and no credentials are included.

## Documentation

| File | Contents |
|---|---|
| [docs/PROJECT_BRIEF.md](docs/PROJECT_BRIEF.md) | The game in one page: rules, safety, night |
| [docs/PHASE_CHECKLIST.md](docs/PHASE_CHECKLIST.md) | Phase completion status and known limitations |
| [docs/CONTROLS.md](docs/CONTROLS.md) | Controls and debug keys |
| [docs/REVIEW_GUIDE.md](docs/REVIEW_GUIDE.md) | 10-minute review walkthrough and viewpoints |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Modules, axes, frozen world data, save schema, safety rules |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | Budgets, presets, what has and hasn't been measured |
| [docs/ASSET_PROVENANCE.md](docs/ASSET_PROVENANCE.md) | Every asset and its license |

## Developer commands

Run these from the project folder, with `godot` being the 4.5.1 editor binary:

```bash
godot --headless --import
```

```bash
godot --headless res://tests/test_runner.tscn
```

```bash
godot --headless res://tests/smoke_test.tscn
```

```bash
godot --headless --script res://tools/generate_world.gd -- --check
```

```bash
godot res://tools/capture_views.tscn -- day:camp night:camper_night
```
