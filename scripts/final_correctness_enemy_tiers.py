#!/usr/bin/env python3
"""Apply final correctness patches to the enemy-tier ecological runtime.

This pass preserves permanent suppression as an offset rather than mutating
physical nest sources, recreates nests before save restoration, and prevents
legacy spawn/behaviour/performance systems from fighting the tier authority.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(relative: str, old: str, new: str, required: bool = False) -> None:
    path = ROOT / relative
    if not path.is_file():
        if required:
            raise RuntimeError(f"Missing required file: {relative}")
        return
    text = path.read_text(encoding="utf-8")
    if old not in text:
        if required and new not in text:
            raise RuntimeError(f"Pattern not found in {relative}: {old[:120]!r}")
        return
    path.write_text(text.replace(old, new), encoding="utf-8")


def insert_after(relative: str, marker: str, block: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if block.strip() in text:
        return
    index = text.find(marker)
    if index < 0:
        raise RuntimeError(f"Marker not found in {relative}: {marker!r}")
    index += len(marker)
    path.write_text(text[:index] + block + text[index:], encoding="utf-8")


def patch_director() -> None:
    relative = "game/scripts/systems/enemy_tier_progression_director_3d.gd"
    insert_after(relative, "var spawn_credit: Dictionary = {}\n", "var suppression_offsets: Dictionary = {}\n")
    replace(
        relative,
        "    spawn_credit.clear()\n    saturated.clear()",
        "    spawn_credit.clear()\n    suppression_offsets.clear()\n    saturated.clear()",
        True,
    )
    replace(
        relative,
        "        spawn_credit[tier] = 0.0\n        saturated[tier] = false",
        "        spawn_credit[tier] = 0.0\n        suppression_offsets[tier] = 0.0\n        saturated[tier] = false",
        True,
    )
    replace(
        relative,
        "    if anonymous > 0.0:\n        anonymous_rates[tier] = 0.0\n        anonymous_rates[next_tier] = float(anonymous_rates.get(next_tier, 0.0)) + anonymous * transfer_factor\n    for raw_source_id in rate_sources.keys():",
        "    if anonymous > 0.0:\n        anonymous_rates[tier] = 0.0\n        anonymous_rates[next_tier] = float(anonymous_rates.get(next_tier, 0.0)) + anonymous * transfer_factor\n    var suppression := maxf(0.0, float(suppression_offsets.get(tier, 0.0)))\n    suppression_offsets[tier] = 0.0\n    suppression_offsets[next_tier] = maxf(0.0, float(suppression_offsets.get(next_tier, 0.0)) + suppression * transfer_factor)\n    for raw_source_id in rate_sources.keys():",
        True,
    )

    start = "func _remove_rate_from_tier(tier: int, amount: float) -> void:\n"
    end = "\n\nfunc _accumulate_and_spawn(tier: int, delta: float) -> void:\n"
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if "suppression_offsets[tier] = maxf" not in text[text.find(start):text.find(end) if end in text else None]:
        begin = text.find(start)
        finish = text.find(end, begin)
        if begin < 0 or finish < 0:
            raise RuntimeError("Could not replace replenishment reduction implementation")
        replacement = '''func _remove_rate_from_tier(tier: int, amount: float) -> void:\n    var current_net := replenishment_rate(tier)\n    var reduction := minf(maxf(0.0, amount), current_net)\n    if reduction <= 0.000001:\n        return\n    suppression_offsets[tier] = maxf(0.0, float(suppression_offsets.get(tier, 0.0)) + reduction)\n    tier_replenishment_changed.emit(tier, replenishment_rate(tier))\n'''
        text = text[:begin] + replacement + text[finish:]
        path.write_text(text, encoding="utf-8")

    replace(
        relative,
        "func replenishment_rate(tier: int) -> float:\n    var total := maxf(0.0, float(anonymous_rates.get(tier, 0.0)))\n    for source in rate_sources.values():\n        if source is Dictionary and int(source.get(\"current_tier\", -1)) == tier:\n            total += maxf(0.0, float(source.get(\"current_rate\", 0.0)))\n    return total",
        "func replenishment_rate(tier: int) -> float:\n    var total := maxf(0.0, float(anonymous_rates.get(tier, 0.0)))\n    for source in rate_sources.values():\n        if source is Dictionary and int(source.get(\"current_tier\", -1)) == tier:\n            total += maxf(0.0, float(source.get(\"current_rate\", 0.0)))\n    return maxf(0.0, total - maxf(0.0, float(suppression_offsets.get(tier, 0.0))))",
        True,
    )
    replace(
        relative,
        "func debug_set_anonymous_rate(tier: int, value: float) -> void:\n    anonymous_rates[tier] = maxf(0.0, value)",
        "func debug_set_anonymous_rate(tier: int, value: float) -> void:\n    anonymous_rates[tier] = maxf(0.0, value)\n    suppression_offsets[tier] = 0.0",
        True,
    )
    replace(
        relative,
        '        "spawn_credit": _stringify_numeric_dictionary(spawn_credit),\n        "saturated": _stringify_numeric_dictionary(saturated),',
        '        "spawn_credit": _stringify_numeric_dictionary(spawn_credit),\n        "suppression_offsets": _stringify_numeric_dictionary(suppression_offsets),\n        "saturated": _stringify_numeric_dictionary(saturated),',
        True,
    )
    replace(
        relative,
        '    _restore_numeric_dictionary(spawn_credit, data.get("spawn_credit", {}), false)\n    _restore_numeric_dictionary(saturated, data.get("saturated", {}), false)',
        '    _restore_numeric_dictionary(spawn_credit, data.get("spawn_credit", {}), false)\n    _restore_numeric_dictionary(suppression_offsets, data.get("suppression_offsets", {}), false)\n    _restore_numeric_dictionary(saturated, data.get("saturated", {}), false)',
        True,
    )
    replace(
        relative,
        "func restore_from_dictionary(data: Dictionary) -> void:\n    elapsed_seconds =",
        "func restore_from_dictionary(data: Dictionary) -> void:\n    _spawn_configured_nests()\n    elapsed_seconds =",
        True,
    )


def patch_brain() -> None:
    relative = "game/scripts/enemies/enemy_tier_brain_3d.gd"
    insert_after(
        relative,
        "func _ready() -> void:\n    process_mode = Node.PROCESS_MODE_PAUSABLE\n    call_deferred(\"_initialize\")\n",
        '''\n\nfunc _process(delta: float) -> void:\n    # Release LOD systems may try to re-enable the parent enemy's legacy\n    # physics loop. Tier intelligence remains the single movement authority.\n    if enemy != null and is_instance_valid(enemy) and enemy.is_physics_processing():\n        enemy.set_physics_process(false)\n''',
    )


def patch_bootstrap() -> None:
    relative = "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd"
    replace(
        relative,
        '        class_name_text in ["EcologyDirector3D", "StrategicEcologyDirector3D"]\n        or node.has_method(&"_spawn_regional_organism")',
        '        class_name_text in ["EcologyDirector3D", "StrategicEcologyDirector3D", "OrganicBehaviourDirector3D"]\n        or node.has_method(&"_spawn_regional_organism")\n        or node.has_method(&"_assign_organic_behaviour")',
        True,
    )
    replace(
        relative,
        '        node.set_meta(&"population_controlled_by_enemy_tiers", true)\n        if _has_property(node, &"active_enemy_cap"):',
        '        node.set_meta(&"population_controlled_by_enemy_tiers", true)\n        node.set_process(false)\n        node.set_physics_process(false)\n        if _has_property(node, &"active_enemy_cap"):',
        True,
    )


def patch_optional_performance() -> None:
    relative = "game/scripts/release/performance_director_3d.gd"
    path = ROOT / relative
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")
    marker = "            var enemy := raw_enemy as OrganicEnemyRelease3D\n"
    block = '''            if enemy.has_node("EnemyTierBrain"):\n                if distance <= active_radius:\n                    enemy.set_visual_lod(0)\n                    active_entities += 1\n                elif distance <= medium_radius:\n                    enemy.set_visual_lod(1)\n                    medium_entities += 1\n                else:\n                    enemy.set_visual_lod(2)\n                    reduced_entities += 1\n                enemy.set_physics_process(false)\n                continue\n'''
    if marker in text and block.strip() not in text:
        text = text.replace(marker, marker + block)
        path.write_text(text, encoding="utf-8")


def patch_tests() -> None:
    relative = "game/tests/enemy_tier_progression_test_runner.gd"
    replace(
        relative,
        '    _expect(director.replenishment_rate(1) < before, "Brood suppression must decrease future replenishment.")',
        '    _expect(director.replenishment_rate(1) < before, "Brood suppression must decrease future replenishment.")\n    director._refresh_nest_sources()\n    _expect(director.replenishment_rate(1) < before, "Permanent suppression must remain after physical nest-source refresh.")',
        True,
    )
    replace(
        relative,
        '    _expect(bool(director.applied_events.get(&"test.event", false)), "Applied ecological events must survive save and restore.")',
        '    _expect(bool(director.applied_events.get(&"test.event", false)), "Applied ecological events must survive save and restore.")\n    _expect(director.suppression_offsets.has(1), "Persistent ecological suppression offsets must survive the release save domain.")',
        True,
    )


def main() -> int:
    patch_director()
    patch_brain()
    patch_bootstrap()
    patch_optional_performance()
    patch_tests()
    print("Applied final enemy-tier ecological correctness and authority patches.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
