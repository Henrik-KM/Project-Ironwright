#!/usr/bin/env python3
"""Validate Project Ironwright's population-driven enemy escalation build."""

from __future__ import annotations

import json
from pathlib import Path

import validate_release as release
import validate_repo as legacy

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_TIER_PATHS = [
    "game/data/enemy_tier_progression.json",
    "game/data/enemy_tier_event_modifiers.json",
    "game/scripts/systems/enemy_tier_director_3d.gd",
    "game/scripts/systems/enemy_tier_event_bridge_3d.gd",
    "game/scripts/world/organic_nest_3d.gd",
    "game/scripts/enemies/organic_enemy_tiered_3d.gd",
    "game/scripts/ui/enemy_tier_hud_3d.gd",
    "game/scripts/main_world_tiered_3d.gd",
    "game/tests/enemy_tier_progression_test_runner.gd",
    "docs/ENEMY_TIER_PROGRESSION.md",
]


def load_json(relative: str) -> dict:
    try:
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise legacy.ValidationError(f"Invalid tier-system JSON {relative}: {exc}") from exc
    if not isinstance(value, dict):
        raise legacy.ValidationError(f"Tier-system JSON must be an object: {relative}")
    return value


def validate_tier_required_paths() -> None:
    release.validate_release_required_paths()
    missing = [relative for relative in REQUIRED_TIER_PATHS if not (ROOT / relative).is_file()]
    if missing:
        raise legacy.ValidationError("Missing enemy-tier implementation files:\n- " + "\n- ".join(missing))


def validate_tiered_entrypoint() -> None:
    scene = (ROOT / "game/scenes/main_3d.tscn").read_text(encoding="utf-8")
    if "res://scripts/main_world_tiered_3d.gd" not in scene:
        raise legacy.ValidationError("The native entrypoint must boot the tiered ecological world")
    world = (ROOT / "game/scripts/main_world_tiered_3d.gd").read_text(encoding="utf-8")
    for token in [
        "extends IronwrightReleaseWorld3D",
        "EnemyTierDirector3D",
        "EnemyTierEventBridge3D",
        "EnemyTierHUD3D",
        "_spawn_capped_operation_threat",
        'release["enemy_tiers"]',
        'release["enemy_tier_events"]',
        "enemy_tier_director.restore_from_dictionary",
    ]:
        if token not in world:
            raise legacy.ValidationError(f"Tiered world is missing integration token {token!r}")
    actor_scene = (ROOT / "game/scenes/actors/organic_enemy_3d.tscn").read_text(encoding="utf-8")
    if "organic_enemy_tiered_3d.gd" not in actor_scene:
        raise legacy.ValidationError("Organic enemy scene must use tier-aware intelligence")


def validate_tier_configuration() -> None:
    data = load_json("game/data/enemy_tier_progression.json")
    simulation = data.get("simulation")
    tiers = data.get("tiers")
    nests = data.get("nest_profiles")
    if not isinstance(simulation, dict) or not isinstance(tiers, dict) or not isinstance(nests, dict):
        raise legacy.ValidationError("Tier progression data needs simulation, tiers and nest_profiles objects")
    if set(tiers) != {"1", "2", "3", "4", "5"}:
        raise legacy.ValidationError("Enemy escalation must contain exactly tiers 1–5")
    if float(simulation.get("saturation_transfer_factor", 0.0)) != 0.1:
        raise legacy.ValidationError("Saturation transfer factor must remain exactly 0.1")
    if float(simulation.get("tier_1_rate_growth_per_minute_per_minute", 0.0)) != 1.0:
        raise legacy.ValidationError("Prototype Tier-1 rate growth must remain 1 unit/min per minute")
    if float(simulation.get("spawn_credit_cap", 99.0)) > 3.0:
        raise legacy.ValidationError("Spawn credit may not become a hidden army backlog")
    expected_caps = [100, 40, 16, 6, 2]
    actual_caps = [int(tiers[str(index)].get("unit_cap", 0)) for index in range(1, 6)]
    if actual_caps != expected_caps:
        raise legacy.ValidationError(f"Enemy tier caps must be {expected_caps}, got {actual_caps}")
    if tiers["1"].get("behaviour_profile") != "feral":
        raise legacy.ValidationError("Tier 1 must remain behaviorally primitive")
    if set(tiers["1"].get("species_weights", {})) != {"skitterling"}:
        raise legacy.ValidationError("Tier 1 must currently contain only the slow numerous Skitterling")
    supported = set()
    for profile in nests.values():
        if isinstance(profile, dict):
            supported.update(int(value) for value in profile.get("supported_tiers", []))
    if supported != {1, 2, 3, 4, 5}:
        raise legacy.ValidationError("Physical nest profiles must collectively support every tier")


def validate_species_mapping() -> None:
    data = load_json("game/data/enemy_archetypes.json")
    archetypes = data.get("archetypes", [])
    if data.get("tier_system") != "population_driven_enemy_escalation":
        raise legacy.ValidationError("Enemy archetype registry must identify the tier system")
    tiers = {int(entry.get("tier", 0)) for entry in archetypes if isinstance(entry, dict)}
    if tiers != {1, 2, 3, 4, 5}:
        raise legacy.ValidationError("Organic archetypes must cover every enemy tier")
    tier_one = [entry for entry in archetypes if isinstance(entry, dict) and int(entry.get("tier", 0)) == 1]
    if len(tier_one) != 1 or tier_one[0].get("runtime_species") != "skitterling":
        raise legacy.ValidationError("Tier 1 must be the single primitive prototype population")
    for entry in archetypes:
        combined = json.dumps(entry).lower()
        if "robot" in combined or "machine faction" in combined:
            raise legacy.ValidationError(f"Enemy tier mapping introduced a mechanical enemy: {entry.get('id')}")


def validate_runtime_contracts() -> None:
    director = (ROOT / "game/scripts/systems/enemy_tier_director_3d.gd").read_text(encoding="utf-8")
    for token in [
        "_process_saturation_transfers",
        "rate * saturation_transfer_factor",
        'state["replenishment_per_minute"] = 0.0',
        "range(tiers.size() - 2, -1, -1)",
        "spawn_credit_cap",
        "_choose_nest_for_tier",
        "nest.spawn_position",
        "apply_replenishment_delta",
        "apply_tier_one_growth_delta",
        "restore_from_dictionary",
    ]:
        if token not in director:
            raise legacy.ValidationError(f"Enemy-tier director is missing {token!r}")
    nest = (ROOT / "game/scripts/world/organic_nest_3d.gd").read_text(encoding="utf-8")
    for token in ["extends StaticBody3D", "nest_destroyed", "can_spawn_tier", "apply_damage", "destroy_replenishment_delta_per_minute"]:
        if token not in nest:
            raise legacy.ValidationError(f"Physical nest runtime is missing {token!r}")
    enemy = (ROOT / "game/scripts/enemies/organic_enemy_tiered_3d.gd").read_text(encoding="utf-8")
    for token in [
        "enemy_tier: int = 1",
        "configure_tier",
        "Tier 1 organisms wander without a strategic objective",
        "Tier 2 organisms patrol and defend",
        "Tier 3 organisms scout",
        "Tier 4 organisms intercept machine routes",
        "Tier 5 organisms act as regional apex threats",
        "_has_line_of_sight",
        "_strategic_interest_target",
    ]:
        if token not in enemy:
            raise legacy.ValidationError(f"Tier-aware enemy intelligence is missing {token!r}")


def validate_dynamic_modifiers() -> None:
    data = load_json("game/data/enemy_tier_event_modifiers.json")
    operations = data.get("operations", {})
    technologies = data.get("technologies", {})
    endgame = data.get("endgame", {})
    if len(operations) < 10:
        raise legacy.ValidationError("Major physical operations need ecological consequences")
    signed_deltas = [
        float(value)
        for effect in operations.values()
        if isinstance(effect, dict)
        for value in effect.get("replenishment_delta_per_minute", {}).values()
    ]
    if not any(value < 0.0 for value in signed_deltas):
        raise legacy.ValidationError("Suppression operations must be able to reduce replenishment")
    if not any(value > 0.0 for value in signed_deltas):
        raise legacy.ValidationError("Disruptive expeditions must be able to increase replenishment")
    for technology in ["tech.heartforge.tier_2", "tech.heartforge.tier_3", "tech.heartforge.tier_4", "tech.heartforge.tier_5"]:
        if technology not in technologies:
            raise legacy.ValidationError(f"Heartforge evolution lacks ecological effect {technology}")
    if set(endgame) != {"protocol.severance", "protocol.containment"}:
        raise legacy.ValidationError("Both final protocols need escalation effects")


def validate_no_wave_loop() -> None:
    paths = [
        "game/scripts/systems/enemy_tier_director_3d.gd",
        "game/scripts/systems/enemy_tier_event_bridge_3d.gd",
        "game/scripts/main_world_tiered_3d.gd",
    ]
    combined = "\n".join((ROOT / path).read_text(encoding="utf-8").lower() for path in paths)
    for token in ["wave_number", "wave_timer", "next_wave", "wave_countdown"]:
        if token in combined:
            raise legacy.ValidationError(f"Tier escalation introduced a recurring wave loop: {token}")


def validate_documents_and_tests() -> None:
    document = (ROOT / "docs/ENEMY_TIER_PROGRESSION.md").read_text(encoding="utf-8")
    if len(document.split()) < 1_500:
        raise legacy.ValidationError("Enemy tier design contract is unexpectedly short")
    for phrase in ["Saturation transfer", "Population suppression versus source suppression", "Tier 1 — Feral", "Tier 4 — Strategic", "Bounded spawn credit", "Autonomous suppression and anti-chore protection", "Acceptance criteria"]:
        if phrase not in document:
            raise legacy.ValidationError(f"Enemy tier design contract is missing {phrase!r}")
    tests = (ROOT / "game/tests/enemy_tier_progression_test_runner.gd").read_text(encoding="utf-8")
    for token in ["_test_exact_saturation_transfer", "_test_population_headroom", "_test_recursive_transfer", "_test_physical_nests", "_test_progression_modifiers", "_test_physical_spawn_source", "_test_intelligence_progression", "_test_persistence"]:
        if token not in tests:
            raise legacy.ValidationError(f"Enemy tier test suite is missing {token!r}")


def main() -> int:
    validators = [
        validate_tier_required_paths,
        release.validate_release_manifest,
        release.validate_localization_catalogs,
        release.validate_release_content_breadth,
        release.validate_release_assets,
        release.validate_release_services,
        release.validate_release_packaging,
        release.validate_release_documents,
        validate_tiered_entrypoint,
        validate_tier_configuration,
        validate_species_mapping,
        validate_runtime_contracts,
        validate_dynamic_modifiers,
        validate_no_wave_loop,
        validate_documents_and_tests,
        legacy.validate_autonomy_data,
        legacy.validate_enemy_data,
        legacy.validate_prototype_scope,
        legacy.validate_concept_art,
        legacy.validate_local_markdown_links,
    ]
    try:
        for validator in validators:
            validator()
        legacy.validate_manifest()
    except legacy.ValidationError as exc:
        print(f"TIERED RELEASE VALIDATION FAILED: {exc}")
        return 1
    print("Project Ironwright population-driven enemy tier validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
