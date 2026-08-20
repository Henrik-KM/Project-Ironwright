#!/usr/bin/env python3
"""Remove final Variant-return and built-in cast hazards in enemy-tier scripts."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(relative: str, old: str, new: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old in text:
        path.write_text(text.replace(old, new), encoding="utf-8")


def main() -> int:
    replace(
        "game/scripts/world/enemy_tier_nest_3d.gd",
        '''func _tier_config(tier: int) -> Dictionary:\n    var progression := get_tree().get_first_node_in_group(&"enemy_tier_progression")\n    if progression != null and progression.has_method(&"get_tier_data"):\n        return progression.call(&"get_tier_data", tier)\n    return {}''',
        '''func _tier_config(tier: int) -> Dictionary:\n    var progression := get_tree().get_first_node_in_group(&"enemy_tier_progression")\n    if progression != null and progression.has_method(&"get_tier_data"):\n        var raw: Variant = progression.call(&"get_tier_data", tier)\n        if raw is Dictionary:\n            return (raw as Dictionary).duplicate(true)\n    return {}''',
    )
    replace(
        "game/scripts/systems/autonomous_enemy_suppression_3d.gd",
        '''        var bucket: Dictionary = buckets[cell]\n        bucket["count"] = int(bucket["count"]) + 1\n        bucket["sum"] = (bucket["sum"] as Vector3) + position''',
        '''        var bucket: Dictionary = buckets[cell]\n        bucket["count"] = int(bucket["count"]) + 1\n        var accumulated: Vector3 = bucket.get("sum", Vector3.ZERO)\n        bucket["sum"] = accumulated + position''',
    )
    replace(
        "game/scripts/systems/autonomous_enemy_suppression_3d.gd",
        '''        result.append(entry["position"] as Vector3)''',
        '''        var position: Vector3 = entry.get("position", Vector3.ZERO)\n        result.append(position)''',
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_director_3d.gd",
        '''    var raw_rates: Variant = nest.call(&"effective_replenishment") if nest.has_method(&"effective_replenishment") else {}''',
        '''    var raw_rates: Variant = {}\n    if nest.has_method(&"effective_replenishment"):\n        raw_rates = nest.call(&"effective_replenishment")''',
    )
    replace(
        "game/scripts/systems/autonomous_enemy_suppression_3d.gd",
        '''    var raw: Variant = autonomy_node.call(&"living_robots", &"guardian") if autonomy_node.has_method(&"living_robots") else []''',
        '''    var raw: Variant = []\n    if autonomy_node.has_method(&"living_robots"):\n        raw = autonomy_node.call(&"living_robots", &"guardian")''',
    )
    print("Applied final GDScript safety patches to enemy-tier scripts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
