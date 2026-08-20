#!/usr/bin/env python3
"""Apply deterministic compile/runtime hardening to enemy-tier source files."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(relative: str, old: str, new: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old not in text:
        return
    path.write_text(text.replace(old, new), encoding="utf-8")


def main() -> int:
    replace(
        "game/scripts/world/enemy_tier_nest_3d.gd",
        "ModelKit3D.add_collision_cylinder(self, 2.6, 2.2, Vector3(0.0, 1.1, 0.0))",
        "ModelKit3D.add_collision_capsule(self, 2.1, 1.6, Vector3(0.0, 1.1, 0.0))",
    )
    replace(
        "game/scripts/world/enemy_tier_nest_3d.gd",
        'return "%s · %d%% mature · supports tiers %s" % [display_name, int(round(maturity * 100.0)), ", ".join(supported_tiers.map(func(value: int) -> String: return str(value)))]',
        'var tier_labels: Array[String] = []\n        for tier in supported_tiers:\n            tier_labels.append(str(tier))\n        return "%s · %d%% mature · supports tiers %s" % [display_name, int(round(maturity * 100.0)), ", ".join(tier_labels)]',
    )
    replace(
        "game/scripts/enemies/enemy_tier_brain_3d.gd",
        'home_nest = director.nests.get(home_nest_id, null) as Node3D if director != null else null',
        'home_nest = null\n    if director != null:\n        var raw_home_nest: Variant = director.nests.get(home_nest_id, null)\n        if raw_home_nest is Node3D:\n            home_nest = raw_home_nest as Node3D',
    )
    replace(
        "game/scripts/enemies/enemy_tier_brain_3d.gd",
        'decision_clock += delta\n    state_elapsed += delta',
        'decision_clock += delta\n    state_elapsed += delta\n    enemy.set("attack_cooldown", maxf(0.0, float(enemy.get("attack_cooldown")) - delta))',
    )
    replace(
        "game/scripts/systems/autonomous_enemy_suppression_3d.gd",
        'target_cells = clusters.slice(0, mini(clusters.size(), maximum_wardens))',
        'target_cells.clear()\n    var target_count := mini(clusters.size(), maximum_wardens)\n    for index in range(target_count):\n        target_cells.append(clusters[index])',
    )
    replace(
        "game/scripts/systems/autonomous_enemy_suppression_3d.gd",
        'for index in range(mini(wardens.size(), target_cells.size(), maximum_wardens)):',
        'for index in range(mini(mini(wardens.size(), target_cells.size()), maximum_wardens)):',
    )
    replace(
        "game/tests/enemy_tier_progression_test_runner.gd",
        '    _clear_fake_actors()\n    var target := FakeFriendly.new()',
        '    _clear_fake_actors()\n    await process_frame\n    var target := FakeFriendly.new()',
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
        'class_name_text = str(script.get_global_name())',
        'if script.has_method(&"get_global_name"):\n            class_name_text = str(script.call(&"get_global_name"))',
    )
    print("Finalized enemy tier progression scripts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
