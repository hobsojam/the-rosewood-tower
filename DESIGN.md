# The Rosewood Tower Design Spec

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
7. After each cleared non-final wave, the player chooses one city support bonus.
8. Player wins after wave 10 or loses when lives reach zero.

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
- Railgun: high-cost, slow-firing beam that pierces enemies in a line
- AAA flak turret: anti-air counter offered as the required support unlock before air threats appear
- Towers can expose weapon tags such as direct, blast, pierce, slow, or anti-air for enemy trait interactions.

### Enemies

- Standard unit: baseline health and speed
- Fast unit: lower health, higher speed
- Armored unit: higher health, lower speed
- Shield carrier: projects a damage-reducing bubble around nearby enemies
- Siege walker: very slow, very high health, costs two lives on breach
- Signal decoy: durable low-reward target that wastes unfocused tower fire
- Rotor drone: air enemy that resists non-anti-air damage and is immune to Foam and Mortar damage
- Enemies can expose traits such as armored, air, burrowed, heavy, support, or decoy. Traits should create resistance/counterplay rather than hard immunity.

### Progression

- Upgrades exist only within a match for the first milestone.
- Each tower should support at least one upgrade level in the first playable version.
- Between-wave city support choices grant money, repairs, or tower-specific match bonuses. Lives are clamped between 0 and 20, recent choices are temporarily filtered, and repeated tower-family bonuses have diminishing returns.
- Tower availability can change during a match. Rivets are available at start, most towers can unlock through support choices, and threat-critical counters such as AAA can become the required support choice before their matching threat appears.

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
