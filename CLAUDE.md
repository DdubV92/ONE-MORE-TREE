# One More Tree: notes for coding agents

- **Engine:** Godot **4.5.1-stable**, Forward+, Jolt, typed GDScript. Do not upgrade without a migration pass (see docs/ARCHITECTURE.md).
- **Read first:** the charter lives in docs/PROJECT_BRIEF.md. Status and limitations live in docs/PHASE_CHECKLIST.md. Update both when behaviour changes.
- **World data:** `data/world/*` is generated and frozen. Never hand-edit it. After changing `config/world_config.tres` or `scripts/world/island_generator.gd`:
  1. Bump `generation_version`.
  2. Run `godot --headless --script res://tools/generate_world.gd`.
  3. Commit the new data.
  CI fails if regeneration no longer matches the committed hashes.
- **Camp placement:** `scripts/camp/camp_layout.gd` is the single source of truth for camp positions.
- **Night safety:** `SafetyService.query()` is authoritative. Never grant safety from lighting or emissives.
- **Preview mode:** must never write saves or change campaign state. Use `Game.can_write_campaign_save()`.
- **Before committing, run:**

```bash
godot --headless --import
```

```bash
godot --headless res://tests/test_runner.tscn
```

```bash
godot --headless res://tests/smoke_test.tscn
```

- **Screenshots** need a real renderer (not `--headless`): `godot res://tools/capture_views.tscn -- day:camp`. In a container, use `xvfb-run` with Mesa lavapipe.
- **New `class_name` scripts** need `godot --headless --import` once before other scripts can reference them headlessly.
- **GDScript gotchas:**
  - Packed arrays are values. Mutating `dict[key]` packed arrays through a cast does nothing, so use `Array` for growable indexes.
  - Godot front faces are clockwise when seen from the viewer.
  - Visibility ranges are measured from the instance origin, so center chunk nodes.
