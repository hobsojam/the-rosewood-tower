# The Rosewood Tower — Claude Code Instructions

## Project Overview

Windows-native tower defence prototype built with Godot 4.7 and GDScript. Data-driven: maps, waves, towers, and enemies are defined in JSON files under `data/`. Core logic lives in `scripts/Game.gd`, `scripts/WaveManager.gd`, and `scripts/Map.gd`.

## Architecture

- `data/` — JSON config for enemies, towers, waves, and maps
- `scripts/Game.gd` — main controller, HUD, tower placement
- `scripts/WaveManager.gd` — wave spawning and enemy lifecycle
- `scripts/Map.gd` — map loading and rendering
- `scenes/` — Godot scene files

## Setup

Install Godot 4.7 and open the project folder in the editor (or run headless via the console executable below, from your Godot install directory or with it on `PATH`). No package manager or dependency install step is required.

## Development Commands

Validate data after any change to `data/`:

```
python scripts/ci/validate_data.py
```

Godot parser check:

```
Godot_v4.7.1-stable_win64_console.exe --headless --path . --check-only --quit
```

## Build

Export the Windows build (requires Godot export templates installed):

```
Godot_v4.7.1-stable_win64_console.exe --headless --path . --export-release "Windows Desktop"
```

## Testing

Run both commands above before committing. Manual playtesting in Godot is required for changes to input, UI layout, HUD, tower placement, wave flow, or audio.

## Git Workflow

**Never push directly to `main`.** All changes must go through a branch and PR, including single-line fixes. The only exception is the initial commit when creating a new repo.

Branch prefixes: `fix/`, `feature/`, `balance/`, `content/`, `chore/`.
