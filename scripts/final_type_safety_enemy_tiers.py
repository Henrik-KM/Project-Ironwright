#!/usr/bin/env python3
"""Remove GDScript typing patterns that can create cyclic parser dependencies."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(relative: str, old: str, new: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old in text:
        path.write_text(text.replace(old, new), encoding="utf-8")


def main() -> int:
    replace(
        "game/scripts/enemies/enemy_tier_brain_3d.gd",
        "var director: EnemyTierProgressionDirector3D",
        "var director",
    )
    replace(
        "game/scripts/enemies/enemy_tier_brain_3d.gd",
        "        next_director: EnemyTierProgressionDirector3D,",
        "        next_director,",
    )
    replace(
        "game/tests/enemy_tier_progression_test_runner.gd",
        "    var spawned: Array[FakeEnemy] = []",
        "    var spawned: Array = []",
    )
    replace(
        "game/tests/enemy_tier_progression_test_runner.gd",
        "    func _spawn_enemy(position: Vector3, species: StringName) -> FakeEnemy:",
        "    func _spawn_enemy(position: Vector3, species: StringName):",
    )
    replace(
        "game/tests/enemy_tier_progression_test_runner.gd",
        "var world: FakeWorld",
        "var world",
    )
    replace(
        "game/tests/enemy_tier_progression_test_runner.gd",
        "func _make_brained_enemy(tier: int, position: Vector3, nest_id: StringName = &\"\") -> FakeEnemy:",
        "func _make_brained_enemy(tier: int, position: Vector3, nest_id: StringName = &\"\"):",
    )
    replace(
        "game/scripts/world/enemy_tier_nest_3d.gd",
        'replenishment_per_minute = (raw_replenishment as Dictionary).duplicate(true) if raw_replenishment is Dictionary else {}',
        'replenishment_per_minute = {}\n    if raw_replenishment is Dictionary:\n        replenishment_per_minute = (raw_replenishment as Dictionary).duplicate(true)',
    )
    print("Applied final enemy-tier GDScript type safety patches.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
