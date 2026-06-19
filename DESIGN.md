# Industrial City Defense Design Spec

## Product Goal

Build a compact, playable tower defence vertical slice for Windows desktop. The first goal is mechanical clarity: enemies follow readable industrial routes, towers make distinct tactical choices, and the player can complete a 10-wave match.

## Theme

The game is set in an industrial city district of service roads, rail sidings, power substations, pipes, warehouses, and security checkpoints. The player defends key infrastructure from hostile drones, raiders, or rogue machines moving through the district.

## Core Loop

1. Player starts or prepares for a wave.
2. Enemies spawn and follow fixed paths.
3. Player places or upgrades towers on valid grid slots.
4. Towers attack enemies automatically.
5. Defeated enemies award currency.
6. Enemies that reach the exit reduce lives.
7. Player wins after wave 10 or loses when lives reach zero.

## Initial Mechanics

### Map

- Top-down 2D view
- Fixed path or paths
- Grid slots for tower placement
- Invalid placement on roads, exits, spawns, and occupied slots

### Towers

- Basic turret: reliable single-target damage
- Cryo/foam sprayer: low damage, applies slow
- Mortar: slower fire rate, splash damage

### Enemies

- Standard unit: baseline health and speed
- Fast unit: lower health, higher speed
- Armored unit: higher health, lower speed

### Progression

- Upgrades exist only within a match for the first milestone.
- Each tower should support at least one upgrade level in the first playable version.

## Godot Architecture

Planned scene/script layout:

- `scenes/Game.tscn`: top-level game orchestration
- `scenes/Map.tscn`: map visuals, path, placement slots
- `scenes/enemies/Enemy.tscn`: base enemy scene
- `scenes/towers/Tower.tscn`: base tower scene
- `scenes/projectiles/Projectile.tscn`: projectile behavior
- `scripts/WaveManager.gd`: wave spawning and completion
- `scripts/PlacementManager.gd`: tower placement validation
- `scripts/data/TowerData.gd`: tower stats
- `scripts/data/EnemyData.gd`: enemy stats
- `data/waves.json`: initial 10-wave tuning

## First Milestone Acceptance Criteria

- A player can launch the game on Windows from Godot.
- A single map loads with a visible industrial path and placement zones.
- The player can place at least one tower type with the mouse.
- Enemies spawn, follow the path, take damage, and either die or reduce lives at the exit.
- Currency, lives, and wave number are visible.
- The game reaches a win state after 10 waves or a lose state at 0 lives.

