#!/usr/bin/env python3
"""Keep physical nests out of unit groups while making them valid combat targets."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(relative: str, old: str, new: str) -> None:
    path = ROOT / relative
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")
    if old in text:
        path.write_text(text.replace(old, new), encoding="utf-8")


def inject_before_return(relative: str, function_name: str, marker: str, block: str) -> None:
    path = ROOT / relative
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")
    if block.strip() in text:
        return
    start = text.find(f"func {function_name}")
    if start < 0:
        raise RuntimeError(f"Function {function_name} not found in {relative}")
    next_func = text.find("\nfunc ", start + 1)
    end = len(text) if next_func < 0 else next_func
    return_index = text.rfind(marker, start, end)
    if return_index < 0:
        raise RuntimeError(f"Return marker not found in {function_name} within {relative}")
    text = text[:return_index] + block + text[return_index:]
    path.write_text(text, encoding="utf-8")


def patch_base_targeting() -> None:
    nest_loop = '''    for candidate in get_tree().get_nodes_in_group(&"enemy_tier_nests"):\n        if not is_instance_valid(candidate) or not (candidate is Node3D):\n            continue\n        if candidate.has_method(&"is_alive") and not bool(candidate.call(&"is_alive")):\n            continue\n        var nest_distance := global_position.distance_to(candidate.global_position)\n        if nest_distance < best_distance:\n            best = candidate\n            best_distance = nest_distance\n'''
    inject_before_return(
        "game/scripts/actors/mechromancer_3d.gd",
        "_nearest_enemy_in_range(",
        "    return best",
        nest_loop,
    )
    inject_before_return(
        "game/scripts/robots/robot_unit_3d.gd",
        "_nearest_enemy(",
        "    return best",
        nest_loop,
    )


def patch_release_targeting() -> None:
    replace(
        "game/scripts/release/spatial_index_3d.gd",
        '''    &"organic_enemies",\n    &"friendly_robots",''',
        '''    &"organic_enemies",\n    &"enemy_tier_nests",\n    &"friendly_robots",''',
    )
    release_mech = ROOT / "game/scripts/actors/mechromancer_release_3d.gd"
    if release_mech.is_file():
        text = release_mech.read_text(encoding="utf-8")
        old = '''func _nearest_enemy_in_range(maximum_range: float) -> Node3D:\n    if _spatial_index == null or not is_instance_valid(_spatial_index):\n        _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D\n    if _spatial_index != null:\n        return _spatial_index.nearest(&"organic_enemies", global_position, maximum_range)\n    return super._nearest_enemy_in_range(maximum_range)'''
        new = '''func _nearest_enemy_in_range(maximum_range: float) -> Node3D:\n    if _spatial_index == null or not is_instance_valid(_spatial_index):\n        _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D\n    if _spatial_index == null:\n        return super._nearest_enemy_in_range(maximum_range)\n    var unit_target := _spatial_index.nearest(&"organic_enemies", global_position, maximum_range)\n    var nest_target := _spatial_index.nearest(&"enemy_tier_nests", global_position, maximum_range)\n    if unit_target == null:\n        return nest_target\n    if nest_target == null:\n        return unit_target\n    return nest_target if global_position.distance_to(nest_target.global_position) < global_position.distance_to(unit_target.global_position) else unit_target'''
        if old in text:
            release_mech.write_text(text.replace(old, new), encoding="utf-8")
    release_robot = ROOT / "game/scripts/robots/robot_unit_release_3d.gd"
    if release_robot.is_file():
        text = release_robot.read_text(encoding="utf-8")
        old = '''func _nearest_enemy(maximum_range: float) -> Node3D:\n    if _spatial_index == null or not is_instance_valid(_spatial_index):\n        _resolve_spatial_index()\n    if _spatial_index != null:\n        return _spatial_index.nearest(&"organic_enemies", global_position, maximum_range)\n    return super._nearest_enemy(maximum_range)'''
        new = '''func _nearest_enemy(maximum_range: float) -> Node3D:\n    if _spatial_index == null or not is_instance_valid(_spatial_index):\n        _resolve_spatial_index()\n    if _spatial_index == null:\n        return super._nearest_enemy(maximum_range)\n    var unit_target := _spatial_index.nearest(&"organic_enemies", global_position, maximum_range)\n    var nest_target := _spatial_index.nearest(&"enemy_tier_nests", global_position, maximum_range)\n    if unit_target == null:\n        return nest_target\n    if nest_target == null:\n        return unit_target\n    return nest_target if global_position.distance_to(nest_target.global_position) < global_position.distance_to(unit_target.global_position) else unit_target'''
        if old in text:
            release_robot.write_text(text.replace(old, new), encoding="utf-8")


def patch_nest_groups() -> None:
    replace(
        "game/scripts/world/enemy_tier_nest_3d.gd",
        '''    add_to_group(&"enemy_tier_nests")\n    add_to_group(&"organic_enemies")\n    add_to_group(&"organic_ecology_sources")''',
        '''    add_to_group(&"enemy_tier_nests")\n    add_to_group(&"organic_structures")\n    add_to_group(&"organic_ecology_sources")''',
    )


def patch_tests() -> None:
    relative = "game/tests/enemy_tier_progression_test_runner.gd"
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    marker = '''    _expect(int(director.population.get(1, 0)) == director.unit_cap(1), "No replenishment source may spawn beyond a tier cap.")'''
    addition = '''\n    _expect(not nest.is_in_group(&"organic_enemies"), "Physical nests must not inflate organic unit populations or legacy enemy counts.")\n    _expect(nest.is_in_group(&"enemy_tier_nests"), "Physical nests must remain addressable as a separate combat-target group.")'''
    if marker in text and addition.strip() not in text:
        path.write_text(text.replace(marker, marker + addition), encoding="utf-8")


def main() -> int:
    patch_nest_groups()
    patch_base_targeting()
    patch_release_targeting()
    patch_tests()
    print("Integrated physical nest combat targeting without polluting enemy-unit populations.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
