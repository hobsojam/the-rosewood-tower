import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data"
PLAYFIELD_WIDTH = 960
VIEW_HEIGHT = 720


def load_json(name):
    path = DATA / name
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def assert_true(condition, message):
    if not condition:
        raise AssertionError(message)


def validate_enemies(enemies):
    required = {"standard", "fast", "armored", "shield", "siege", "decoy"}
    assert_true(required.issubset(enemies.keys()), "Missing required enemy definitions")
    for enemy_id, enemy in enemies.items():
        for field in ["name", "health", "speed", "reward", "color"]:
            assert_true(field in enemy, f"Enemy {enemy_id} missing {field}")
        assert_true(enemy["health"] > 0, f"Enemy {enemy_id} health must be positive")
        assert_true(enemy["speed"] > 0, f"Enemy {enemy_id} speed must be positive")
        assert_true(enemy["reward"] >= 0, f"Enemy {enemy_id} reward must be non-negative")
        if "shield_radius" in enemy:
            assert_true(enemy["shield_radius"] > 0, f"Enemy {enemy_id} shield radius must be positive")
        if "shield_reduction" in enemy:
            assert_true(0 <= enemy["shield_reduction"] < 1, f"Enemy {enemy_id} shield reduction must be less than 1")
        if "breach_damage" in enemy:
            assert_true(isinstance(enemy["breach_damage"], int) and enemy["breach_damage"] > 0, f"Enemy {enemy_id} breach damage must be a positive integer")
        assert_true(isinstance(enemy.get("traits", []), list), f"Enemy {enemy_id} traits must be a list")


def validate_towers(towers):
    required = {"basic", "slow", "splash", "railgun"}
    assert_true(required.issubset(towers.keys()), "Missing required tower definitions")
    for tower_id, tower in towers.items():
        for field in ["name", "cost", "damage", "range", "fire_rate", "splash_radius", "slow", "color"]:
            assert_true(field in tower, f"Tower {tower_id} missing {field}")
        assert_true(tower["cost"] > 0, f"Tower {tower_id} cost must be positive")
        assert_true(tower["damage"] >= 0, f"Tower {tower_id} damage must be non-negative")
        assert_true(tower["range"] > 0, f"Tower {tower_id} range must be positive")
        assert_true(tower["fire_rate"] > 0, f"Tower {tower_id} fire rate must be positive")
        assert_true(0 <= tower["slow"] <= 1, f"Tower {tower_id} slow must be between 0 and 1")
        assert_true(isinstance(tower.get("tags", []), list), f"Tower {tower_id} tags must be a list")


def validate_waves(waves, enemy_ids):
    assert_true(len(waves) == 10, "Expected exactly 10 waves")
    for index, wave in enumerate(waves, start=1):
        assert_true(wave, f"Wave {index} must not be empty")
        for enemy_id, count in wave.items():
            assert_true(enemy_id in enemy_ids, f"Wave {index} references unknown enemy {enemy_id}")
            assert_true(isinstance(count, int) and count >= 0, f"Wave {index} count for {enemy_id} must be a non-negative integer")
        assert_true(sum(wave.values()) > 0, f"Wave {index} must spawn at least one enemy")


def point(value, context):
    assert_true(isinstance(value, list) and len(value) == 2, f"{context} must be [x, y]")
    x, y = value
    assert_true(isinstance(x, (int, float)) and isinstance(y, (int, float)), f"{context} coordinates must be numeric")
    return float(x), float(y)


def validate_maps(maps):
    assert_true(len(maps) >= 2, "Expected at least two maps")
    names = set()
    for index, game_map in enumerate(maps):
        name = game_map.get("name")
        assert_true(name and name not in names, f"Map {index} needs a unique name")
        names.add(name)

        path = game_map.get("path", [])
        pads = game_map.get("pads", [])
        props = game_map.get("props", [])
        assert_true(len(path) >= 4, f"Map {name} needs at least four path points")
        assert_true(len(pads) >= 8, f"Map {name} needs at least eight build pads")

        first_x, _ = point(path[0], f"Map {name} first path point")
        last_x, _ = point(path[-1], f"Map {name} last path point")
        assert_true(first_x < 0, f"Map {name} path should enter from off-screen left")
        assert_true(last_x >= PLAYFIELD_WIDTH, f"Map {name} path should exit at the playfield edge")

        for path_index, path_point in enumerate(path):
            x, y = point(path_point, f"Map {name} path point {path_index}")
            assert_true(-120 <= x <= 1000, f"Map {name} path point {path_index} x is out of bounds")
            assert_true(0 <= y <= VIEW_HEIGHT, f"Map {name} path point {path_index} y is out of bounds")

        seen_pads = set()
        for pad_index, pad in enumerate(pads):
            x, y = point(pad, f"Map {name} pad {pad_index}")
            assert_true(0 <= x < PLAYFIELD_WIDTH, f"Map {name} pad {pad_index} must stay inside playfield")
            assert_true(0 <= y <= VIEW_HEIGHT, f"Map {name} pad {pad_index} y is out of bounds")
            key = (round(x), round(y))
            assert_true(key not in seen_pads, f"Map {name} has duplicate pad {key}")
            seen_pads.add(key)

        for prop_index, prop in enumerate(props):
            prop_type = prop.get("type")
            assert_true(prop_type in {"warehouse", "tank", "pipe", "barrier"}, f"Map {name} prop {prop_index} has invalid type")
            if prop_type == "warehouse":
                for field in ["x", "y", "w", "h"]:
                    assert_true(field in prop, f"Map {name} warehouse prop {prop_index} missing {field}")
                assert_true(prop["w"] > 0 and prop["h"] > 0, f"Map {name} warehouse prop {prop_index} size must be positive")
            elif prop_type == "tank":
                assert_true(prop.get("r", 0) > 0, f"Map {name} tank prop {prop_index} radius must be positive")
            elif prop_type == "pipe":
                assert_true(len(prop.get("points", [])) >= 2, f"Map {name} pipe prop {prop_index} needs at least two points")
                for pipe_index, pipe_point in enumerate(prop["points"]):
                    point(pipe_point, f"Map {name} pipe {prop_index} point {pipe_index}")


def main():
    enemies = load_json("enemies.json")
    towers = load_json("towers.json")
    waves = load_json("waves.json")
    maps = load_json("maps.json")

    validate_enemies(enemies)
    validate_towers(towers)
    validate_waves(waves, set(enemies.keys()))
    validate_maps(maps)
    print("Project data validation passed.")


if __name__ == "__main__":
    main()
