#!/usr/bin/env python3
"""Apply final enemy-tier runtime safety and cap-enforcement patches."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(relative: str, old: str, new: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old not in text:
        return
    path.write_text(text.replace(old, new), encoding="utf-8")


def insert_before(relative: str, marker: str, block: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if block.strip() in text:
        return
    index = text.find(marker)
    if index < 0:
        raise RuntimeError(f"Marker not found in {relative}: {marker!r}")
    path.write_text(text[:index] + block + text[index:], encoding="utf-8")


def main() -> int:
    replace(
        "game/scripts/systems/enemy_tier_progression_director_3d.gd",
        'var rates: Dictionary = raw_rates as Dictionary if raw_rates is Dictionary else {}',
        'var rates: Dictionary = {}\n    if raw_rates is Dictionary:\n        rates = (raw_rates as Dictionary).duplicate(true)',
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_director_3d.gd",
        'var nest := NEST_SCRIPT.new()\n        nest.configure(entry)',
        'var nest := NEST_SCRIPT.new() as EnemyTierNest3D\n        nest.configure(entry)',
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_director_3d.gd",
        'brain.configure(enemy, self, tier, home_nest_id)',
        'brain.call(&"configure", enemy, self, tier, home_nest_id)',
    )
    replace(
        "game/scripts/enemies/enemy_tier_brain_3d.gd",
        'enemy.add_to_group(&"enemy_tier_%d" % enemy_tier)',
        'enemy.add_to_group(StringName("enemy_tier_%d" % enemy_tier))',
    )
    replace(
        "game/scripts/enemies/enemy_tier_brain_3d.gd",
        'current_target = _validate_target(current_target)\n    if current_target != null:',
        'current_target = _validate_target(current_target)\n    if current_target != null:\n        var retention_radius := [16.0, 30.0, 58.0, 88.0, 145.0][enemy_tier - 1]\n        if enemy.global_position.distance_to(current_target.global_position) > retention_radius:\n            current_target = null\n    if current_target != null:',
    )
    replace(
        "game/scripts/world/enemy_tier_nest_3d.gd",
        'replenishment_per_minute = (data.get("replenishment_per_minute", {}) as Dictionary).duplicate(true)',
        'var raw_replenishment: Variant = data.get("replenishment_per_minute", {})\n    replenishment_per_minute = (raw_replenishment as Dictionary).duplicate(true) if raw_replenishment is Dictionary else {}',
    )
    replace(
        "game/tests/enemy_tier_progression_test_runner.gd",
        'signal killed(enemy: FakeEnemy, killer: Node)',
        'signal killed(enemy, killer)',
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
        'var map_mode := bool(world.get("map_mode"))',
        'var map_mode := bool(world.get("map_mode")) if _has_property(world, &"map_mode") else false',
    )

    insert_before(
        "game/scripts/systems/enemy_tier_progression_director_3d.gd",
        "func _simulation_tick(delta: float) -> void:\n",
        '''func _enforce_population_caps() -> void:\n    for tier in tier_order:\n        var cap := unit_cap(tier)\n        var members: Array[Node] = []\n        for enemy in get_tree().get_nodes_in_group(StringName("enemy_tier_%d" % tier)):\n            if enemy == null or not is_instance_valid(enemy) or enemy.is_in_group(&"enemy_tier_nests"):\n                continue\n            if enemy.has_method(&"is_alive") and not bool(enemy.call(&"is_alive")):\n                continue\n            members.append(enemy)\n        members.sort_custom(func(a: Node, b: Node) -> bool:\n            return a.get_instance_id() < b.get_instance_id()\n        )\n        if members.size() <= cap:\n            continue\n        for index in range(cap, members.size()):\n            var excess := members[index]\n            excess.set_meta(&"removed_by_tier_cap", true)\n            excess.queue_free()\n        population[tier] = cap\n        tier_population_changed.emit(tier, cap, cap)\n\n\n''',
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_director_3d.gd",
        'func _simulation_tick(delta: float) -> void:\n    _add_anonymous_rate(1, tier_1_growth_per_second * delta)',
        'func _simulation_tick(delta: float) -> void:\n    _enforce_population_caps()\n    _add_anonymous_rate(1, tier_1_growth_per_second * delta)',
    )
    print("Hardened enemy tier runtime and global caps.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
