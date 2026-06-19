# The Rosewood Tower

A Windows-native tower defence game built with Godot 4 and GDScript.

## Direction

The Rosewood Tower is a top-down 2D tower defence game set in a dense industrial district. The player protects critical city infrastructure by placing defensive towers along fixed enemy routes and surviving escalating waves.

## First Playable Scope

- One map with fixed enemy paths
- Grid-based tower placement
- Four tower types: basic, slow, splash, railgun
- Three enemy types: standard, fast, armored
- Ten waves
- Per-level tower upgrades
- Mouse-first controls
- Basic UI for money, lives, wave state, and selected tower
- Win and lose states

## Tech Stack

- Engine: Godot 4.x
- Language: GDScript
- Target: Windows x86_64 desktop export
- Art style: clean top-down 2D placeholders first, then replace with industrial city assets

## Running Locally

1. Install Godot 4.x.
2. Open this folder as a Godot project.
3. Run the main scene: `res://scenes/Game.tscn`.

The current scaffold includes a code-driven map, placement slots, four tower definitions, three enemy definitions, 10 waves, and basic HUD state.

## Current Controls

- Select a tower type from the right-side HUD.
- Hover a green build pad to preview the selected tower's range.
- Click a green build pad to place the selected tower.
- Click a placed tower to inspect it.
- Use the selected tower panel to cycle targeting, upgrade, or sell it.
- Press Start Wave to launch the next wave.
- Use Pause, 1x, and 2x to control game speed during playtests.
- Use Settings to adjust procedural sound volume or mute audio.
- Use Restart on the victory/defeat overlay to reset the match.

The HUD shows active and queued enemies remaining for the current wave, plus a preview of the next wave composition.
The map reserves the right side for UI, so build pads stay in the left playfield.
Wave starts, wave clears, enemy deaths, and life loss now have simple visual feedback.
Placeholder procedural sound effects are generated in code for tower fire, enemy death, breaches, wave events, upgrades, sells, victory, and defeat.
Armored enemies use a distinct top-down tank-style placeholder drawing.
Standard and fast enemies now have distinct crawler/drone silhouettes, and each tower type has a unique placeholder shape.
Tower upgrades now offer tower-specific choices: Rivet chooses rapid fire or sharper damage, Foam chooses stronger slow or wider range, Mortar chooses heavy shells or larger blasts, and Railgun chooses stronger capacitors or a wider bore.
Tower weapon parts now aim toward their current target.
Placed towers can target nearest, first, last, strongest, or weakest enemies.
The next-wave preview includes compact C/D/T counts for crawler, drone, and tank enemies.
Maps are loaded from `data/maps.json`; the title screen can switch between Factory Approach and Pipeworks Loop.

## Windows Export

The project includes a Windows Desktop export preset at `builds/windows/TheRosewoodTower.exe`.

From the project folder, export with:

```powershell
C:\dev\Godot\Godot_v4.4-stable_win64_console.exe --headless --path . --export-release "Windows Desktop"
```

Godot export templates must be installed before the export command will produce an `.exe`.
