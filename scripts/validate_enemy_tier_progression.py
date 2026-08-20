#!/usr/bin/env python3
"""Validate Project Ironwright's population-driven organic escalation system."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "docs/ENEMY_TIER_PROGRESSION.md",
    "game/data/enemy_tier_progression.json",
    "game/scripts/systems/enemy_tier_progression_director_3d.gd",
    "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
    "game/scripts/systems/autonomous_enemy_suppression_3d.gd",
    "game/scripts/world/enemy_tier_nest_3d.gd",
    "game/scripts/enemies/enemy_tier_brain_3d.gd",
    "game/scripts/ui/enemy_tier_intel_hud_3d.gd",
    "game/tests/enemy_tier_progression_test_runner.gd",
]


class ValidationError(RuntimeError):
    pass


def load_json(relative: str) -> dict:
    path = ROOT / relative
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValidationError(f"Invalid JSON {relative}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValidationError(f"Top-level JSON must be an object: {relative}")
    return value


def validate_required() -> None:
    missing = [relative for relative in REQUIRED if not (ROOT / relative).is_file()]
    if missing:
        raise ValidationError("Missing enemy-tier files:\n- " + "\n- ".join(missing))


def validate_config() -> None:
    data = load_json("game/data/enemy_tier_progression.json")
    if data.get("system_id") != "population_driven_organic_escalation":
        raise ValidationError("Enemy-tier system ID is wrong")
    if abs(float(data.get("transfer_factor", 0.0)) - 0.1) > 1e-9:
        raise ValidationError("Saturation transfer factor must be exactly 0.10")
    if float(data.get("spawn_credit_cap", 0.0)) > 3.0:
        raise ValidationError("Spawn-credit cap may not exceed the designed three-organism backlog")
    if abs(float(data.get("tier_1_rate_growth_per_minute_per_minute", 0.0)) - 1.0) > 1e-9:
        raise ValidationError("Prototype Tier-I growth must begin at +1 unit/min per minute")
    tiers = data.get("tiers")
    if not isinstance(tiers, list) or [entry.get("tier") for entry in tiers] != [1, 2, 3, 4, 5]:
        raise ValidationError("Enemy tiers must be ordered I through V")
    expected_caps = [100, 40, 16, 6, 2]
    if [entry.get("unit_cap") for entry in tiers] != expected_caps:
        raise ValidationError(f"Prototype tier caps must remain {expected_caps} until explicit balancing changes")
    if tiers[0].get("behaviours") != ["roam", "chase_visible_target", "attack"]:
        raise ValidationError("Tier I must have only primitive roam/chase/attack behaviour")
    for entry in tiers[1:]:
        if len(entry.get("behaviours", [])) < 4:
            raise ValidationError(f"Higher tier {entry.get('tier')} lacks qualitative intelligence progression")
    nests = data.get("nest_archetypes")
    if not isinstance(nests, list) or len(nests) < 8:
        raise ValidationError("At least eight physical reproductive sources are required")
    nest_ids: set[str] = set()
    for nest in nests:
        identifier = nest.get("id")
        if not isinstance(identifier, str) or not identifier.startswith("nest.") or identifier in nest_ids:
            raise ValidationError(f"Invalid or duplicate physical nest ID: {identifier!r}")
        nest_ids.add(identifier)
        if not nest.get("supported_tiers") or not nest.get("replenishment_per_minute"):
            raise ValidationError(f"Nest {identifier} needs supported tiers and replenishment contributions")
    modifiers = data.get("event_modifiers")
    if not isinstance(modifiers, dict) or len(modifiers) < 10:
        raise ValidationError("Progression and operation ecological modifiers are incomplete")
    if not any(any(float(value) < 0 for value in event.values()) for event in modifiers.values()):
        raise ValidationError("At least one world action must reduce long-term replenishment")
    if not any(any(float(value) > 0 for value in event.values()) for event in modifiers.values()):
        raise ValidationError("At least one progression action must carry an ecological cost")


def validate_runtime() -> None:
    director = (ROOT / "game/scripts/systems/enemy_tier_progression_director_3d.gd").read_text(encoding="utf-8")
    for token in [
        "_process_saturation_high_to_low",
        "_transfer_tier_rate",
        "transfer_factor",
        "spawn_credit_cap",
        "_select_spawn_nest",
        "_spawn_from_nest",
        "reduce_replenishment",
        "rate_sources",
        "apply_event",
        "intelligence_summary",
        "to_dictionary",
        "restore_from_dictionary",
    ]:
        if token not in director:
            raise ValidationError(f"Enemy-tier director is missing {token!r}")
    if "wave" in director.lower() and "scheduled" in director.lower():
        raise ValidationError("Enemy-tier implementation appears to introduce a scheduled-wave concept")

    brain = (ROOT / "game/scripts/enemies/enemy_tier_brain_3d.gd").read_text(encoding="utf-8")
    for token in [
        "_decide_tier_one",
        "_decide_tier_two",
        "_decide_tier_three",
        "_decide_tier_four",
        "_decide_tier_five",
        "guard_nest",
        "hunt_vulnerable",
        "route_ambush",
        "regional_predation",
        "_share_detection",
    ]:
        if token not in brain:
            raise ValidationError(f"Tier intelligence is missing {token!r}")

    nest = (ROOT / "game/scripts/world/enemy_tier_nest_3d.gd").read_text(encoding="utf-8")
    for token in ["effective_replenishment", "can_spawn_tier", "next_spawn_position", "destroyed", "regrowth_seconds"]:
        if token not in nest:
            raise ValidationError(f"Physical nest runtime is missing {token!r}")

    suppression = (ROOT / "game/scripts/systems/autonomous_enemy_suppression_3d.gd").read_text(encoding="utf-8")
    for token in ["tier_1_density_threshold", "enemy_suppression_assignment", "living_robots", "guardian"]:
        if token not in suppression:
            raise ValidationError(f"Autonomous suppression is missing {token!r}")


def validate_integration() -> None:
    scene = (ROOT / "game/scenes/main_3d.tscn").read_text(encoding="utf-8")
    if "enemy_tier_progression_bootstrap_3d.gd" not in scene or "EnemyTierProgressionBootstrap" not in scene:
        raise ValidationError("The production main scene does not install enemy-tier progression")
    package = load_json("package.json")
    validate_command = str(package.get("scripts", {}).get("validate", ""))
    if "validate_enemy_tier_progression.py" not in validate_command:
        raise ValidationError("npm validation does not include enemy-tier contracts")
    workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
    if "enemy_tier_progression_test_runner.gd" not in workflow:
        raise ValidationError("Native CI does not run enemy-tier progression tests")
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8").lower()
    if "population-driven ecological escalation" not in agents:
        raise ValidationError("AGENTS.md does not preserve the enemy-tier design contract")
    locks = (ROOT / "docs/DESIGN_LOCKS.md").read_text(encoding="utf-8").lower()
    if "saturated tier" not in locks or "10:1" not in locks:
        raise ValidationError("DESIGN_LOCKS.md does not lock the saturation-transfer rule")


def validate_tests() -> None:
    tests = (ROOT / "game/tests/enemy_tier_progression_test_runner.gd").read_text(encoding="utf-8")
    for token in [
        "_test_transfer_below_cap",
        "_test_exact_ten_to_one_transfer",
        "_test_high_to_low_no_same_tick_cascade",
        "_test_casualty_headroom_and_growth",
        "_test_bounded_spawn_credit",
        "_test_physical_nest_spawning_and_cap",
        "_test_nest_source_removal_after_evolution",
        "_test_dynamic_event_modifiers",
        "_test_tier_behaviour_progression",
        "_test_serialization_round_trip",
    ]:
        if token not in tests:
            raise ValidationError(f"Enemy-tier test suite is missing {token!r}")


def main() -> int:
    try:
        validate_required()
        validate_config()
        validate_runtime()
        validate_integration()
        validate_tests()
    except ValidationError as exc:
        print(f"ENEMY TIER VALIDATION FAILED: {exc}", file=sys.stderr)
        return 1
    print("Project Ironwright enemy tier progression validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
