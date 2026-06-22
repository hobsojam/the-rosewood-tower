# The Rosewood Tower — Claude Code Instructions

## Project Overview

Windows-native tower defence prototype built with Godot 4.4 and GDScript. Data-driven: maps, waves, towers, and enemies are defined in JSON files under `data/`. Core logic lives in `scripts/Game.gd`, `scripts/WaveManager.gd`, and `scripts/Map.gd`.

## Architecture

- `data/` — JSON config for enemies, towers, waves, and maps
- `scripts/Game.gd` — main controller, HUD, tower placement
- `scripts/WaveManager.gd` — wave spawning and enemy lifecycle
- `scripts/Map.gd` — map loading and rendering
- `scenes/` — Godot scene files

## Development Commands

Validate data after any change to `data/`:

```
python scripts/ci/validate_data.py
```

Godot parser check:

```
C:\dev\Godot\Godot_v4.4-stable_win64_console.exe --headless --path . --check-only --quit
```

## Testing

Run both commands above before committing. Manual playtesting in Godot is required for changes to input, UI layout, HUD, tower placement, wave flow, or audio.

## Git Workflow

**Never push directly to `main`.** All changes must go through a branch and PR, including single-line fixes. The only exception is the initial commit when creating a new repo.

Branch prefixes: `fix/`, `feature/`, `balance/`, `content/`, `chore/`.
