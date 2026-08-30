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
    "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
    "game/scripts/systems/enemy_tier_progression_director_3d.gd",
    "game/scripts/world/organic_nest_3d.gd",
    "game/scripts/world/enemy_tier_nest_3d.gd",
    "game/scripts/enemies/organic_enemy_tiered_3d.gd",
    "game/scripts/enemies/enemy_tier_brain_3d.gd",
    "game/scripts/ui/enemy_tier_intel_hud_3d.gd",
    "game/scripts/main_world_tiered_3d.gd",
    "game/tests/enemy_tier_progression_test_runner.gd",
    "game/tests/ecology_runtime_integration_test_runner.gd",
    "docs/ENEMY_TIER_PROGRESSION.md",
]

LEGACY_RUNTIME_TOKENS = [
    "EnemyTierDirector3D",
    "EnemyTierEventBridge3D",
    "EnemyTierHUD3D",
    "res://scripts/systems/enemy_tier_director_3d.gd",
    "res://scripts/systems/enemy_tier_event_bridge_3d.gd",
    "res://scripts/ui/enemy_tier_hud_3d.gd",
    'release["enemy_tiers"]',
    'release["enemy_tier_events"]',
    'release.get("enemy_tiers"',
    'release.get("enemy_tier_events"',
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
    bootstrap_path = "res://scripts/systems/enemy_tier_progression_bootstrap_3d.gd"
    if scene.count(bootstrap_path) != 1:
        raise legacy.ValidationError("The native entrypoint must install exactly one canonical enemy-tier bootstrap")
    if scene.count('[node name="EnemyTierProgressionBootstrap"') != 1:
        raise legacy.ValidationError("The native entrypoint must contain exactly one EnemyTierProgressionBootstrap node")
    for token in LEGACY_RUNTIME_TOKENS[:6]:
        if token in scene:
            raise legacy.ValidationError(f"Native scene must not install legacy enemy-tier runtime {token!r}")

    world = (ROOT / "game/scripts/main_world_tiered_3d.gd").read_text(encoding="utf-8")
    for token in [
        "extends IronwrightReleaseWorld3D",
        "EnemyTierProgressionDirector3D",
        "_canonical_enemy_tier_director",
        "_spawn_capped_operation_threat",
        "canonical_tier_director.request_causal_threat",
        'release["enemy_tier_progression"]',
        'release.get("enemy_tier_progression", {})',
        "canonical_tier_director.restore_from_dictionary",
        "canonical_tier_director.assign_enemy_tier",
        'set_meta(&"enemy_tier_progression_restored_from_unified", false)',
        'set_meta(&"enemy_tier_progression_restored_from_unified", true)',
        'long_operation_director.spawn_enemy_callback = Callable(self, "_spawn_capped_operation_threat")',
        'endgame_director.spawn_enemy_callback = Callable(self, "_spawn_capped_operation_threat")',
    ]:
        if token not in world:
            raise legacy.ValidationError(f"Tiered world is missing integration token {token!r}")
    for token in LEGACY_RUNTIME_TOKENS:
        if token in world:
            raise legacy.ValidationError(
                f"Tiered world must not integrate the retired parallel enemy-tier runtime token {token!r}"
            )
    if world.count('release["enemy_tier_progression"]') != 1:
        raise legacy.ValidationError("Tiered release snapshots must write one unified enemy_tier_progression payload")
    if world.count('release.get("enemy_tier_progression", {})') != 1:
        raise legacy.ValidationError("Tiered release restore must read the unified enemy_tier_progression payload once")
    if "return _spawn_enemy(position, species)" in world:
        raise legacy.ValidationError("Causal operation threats must not bypass physical nests with a direct world spawn")

    bootstrap = (ROOT / "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd").read_text(encoding="utf-8")
    for token in [
        "class_name EnemyTierProgressionBootstrap3D",
        "director = EnemyTierProgressionDirector3D.new()",
        "suppression = AutonomousEnemySuppression3D.new()",
        "intel_hud = EnemyTierIntelHUD3D.new()",
        "_disable_legacy_population_generators",
        'node.call(&"set_external_population_control", true)',
        'node.set("spawn_enemy_callable", Callable())',
        'node.set("spawn_enemy_callback", Callable())',
        'if not bool(world.get_meta(&"enemy_tier_progression_restored_from_unified", false))',
        'world.set_meta(&"enemy_tier_progression_migrated_from_sidecar", true)',
    ]:
        if token not in bootstrap:
            raise legacy.ValidationError(f"Canonical enemy-tier bootstrap is missing {token!r}")
    if bootstrap.count("EnemyTierProgressionDirector3D.new()") != 1:
        raise legacy.ValidationError("The canonical bootstrap must create exactly one population director")
    if bootstrap.count("EnemyTierIntelHUD3D.new()") != 1:
        raise legacy.ValidationError("The canonical bootstrap must create exactly one ecology-intelligence HUD")
    if "func _save_sidecar" in bootstrap or "_save_sidecar()" in bootstrap:
        raise legacy.ValidationError("Canonical saves must not create a second enemy-tier sidecar generation")
    for token in [
        "node.set_process(false)",
        "node.set_physics_process(false)",
        'node.set("active_enemy_cap", 0)',
        'node.set("spawn_interval", 999999.0)',
    ]:
        if token in bootstrap:
            raise legacy.ValidationError(f"Population handoff must not freeze the living ecology with {token!r}")
    for token in LEGACY_RUNTIME_TOKENS[:6]:
        if token in bootstrap:
            raise legacy.ValidationError(f"Canonical bootstrap must not construct or reference legacy runtime {token!r}")

    actor_scene = (ROOT / "game/scenes/actors/organic_enemy_3d.tscn").read_text(encoding="utf-8")
    if "organic_enemy_tiered_3d.gd" not in actor_scene:
        raise legacy.ValidationError("Organic enemy scene must use tier-aware intelligence")


def validate_tier_configuration() -> None:
    data = load_json("game/data/enemy_tier_progression.json")
    tiers = data.get("tiers")
    nests = data.get("nest_archetypes")
    if not isinstance(tiers, list) or not isinstance(nests, list):
        raise legacy.ValidationError("Canonical tier progression needs ordered tiers and physical nest_archetypes arrays")
    if data.get("system_id") != "population_driven_organic_escalation":
        raise legacy.ValidationError("Enemy tier configuration must identify the canonical population-driven system")
    if [entry.get("tier") for entry in tiers if isinstance(entry, dict)] != [1, 2, 3, 4, 5]:
        raise legacy.ValidationError("Enemy escalation must contain exactly tiers 1–5 in order")
    if abs(float(data.get("transfer_factor", 0.0)) - 0.1) > 1e-9:
        raise legacy.ValidationError("Saturation transfer factor must remain exactly 0.1")
    if abs(float(data.get("tier_1_rate_growth_per_minute_per_minute", 0.0)) - 1.0) > 1e-9:
        raise legacy.ValidationError("Prototype Tier-1 rate growth must remain 1 unit/min per minute")
    if float(data.get("spawn_credit_cap", 99.0)) > 3.0:
        raise legacy.ValidationError("Spawn credit may not become a hidden army backlog")
    expected_caps = [100, 40, 16, 6, 2]
    actual_caps = [int(entry.get("unit_cap", 0)) for entry in tiers]
    if actual_caps != expected_caps:
        raise legacy.ValidationError(f"Enemy tier caps must be {expected_caps}, got {actual_caps}")
    if tiers[0].get("behaviours") != ["roam", "chase_visible_target", "attack"]:
        raise legacy.ValidationError("Tier 1 must remain behaviorally primitive")
    supported = set()
    for profile in nests:
        if isinstance(profile, dict):
            supported.update(int(value) for value in profile.get("supported_tiers", []))
    if supported != {1, 2, 3, 4, 5}:
        raise legacy.ValidationError("Physical nest archetypes must collectively support every tier")


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
    director = (ROOT / "game/scripts/systems/enemy_tier_progression_director_3d.gd").read_text(encoding="utf-8")
    for token in [
        'add_to_group(&"enemy_tier_progression")',
        "EVENT_MODIFIERS_PATH",
        "_load_detailed_event_effects",
        'endgame_node.connect(&"endgame_started"',
        "_apply_detailed_event_effect",
        "_process_saturation_high_to_low",
        "descending.reverse()",
        "anonymous_rates[tier] = 0.0",
        'source["current_rate"] = float(source.get("current_rate", 0.0)) * transfer_factor',
        "spawn_credit_cap",
        "_enforce_population_caps",
        "_select_spawn_nest",
        "_materialize_from_nest",
        'nest.call(&"next_spawn_position"',
        "request_causal_threat",
        "_materialize_from_nest(tier, nest, species)",
        "_redirect_causal_actor",
        "assign_enemy_tier",
        "to_dictionary",
        "restore_from_dictionary",
    ]:
        if token not in director:
            raise legacy.ValidationError(f"Canonical enemy-tier director is missing {token!r}")

    nest = (ROOT / "game/scripts/world/enemy_tier_nest_3d.gd").read_text(encoding="utf-8")
    for token in [
        "class_name EnemyTierNest3D",
        "extends StaticBody3D",
        'add_to_group(&"enemy_tier_nests")',
        "can_spawn_tier",
        "effective_replenishment",
        "next_spawn_position",
        "apply_damage",
        "to_dictionary",
        "restore_from_dictionary",
    ]:
        if token not in nest:
            raise legacy.ValidationError(f"Canonical physical nest runtime is missing {token!r}")

    enemy = (ROOT / "game/scripts/enemies/enemy_tier_brain_3d.gd").read_text(encoding="utf-8")
    for token in [
        "class_name EnemyTierBrain3D",
        "func configure(",
        "_decide_tier_one",
        "_decide_tier_two",
        "_decide_tier_three",
        "_decide_tier_four",
        "_decide_tier_five",
        "receive_migration_goal",
        "receive_causal_threat_goal",
    ]:
        if token not in enemy:
            raise legacy.ValidationError(f"Canonical tier-aware enemy intelligence is missing {token!r}")


def validate_dynamic_modifiers() -> None:
    progression = load_json("game/data/enemy_tier_progression.json")
    if "event_modifiers" in progression:
        raise legacy.ValidationError(
            "enemy_tier_progression.json must not duplicate the canonical ecological event table"
        )
    data = load_json("game/data/enemy_tier_event_modifiers.json")
    if data.get("schema_version") != 2:
        raise legacy.ValidationError("Canonical ecological event modifiers must use schema version 2")
    if data.get("authority") != "canonical_ecological_event_modifiers":
        raise legacy.ValidationError("Ecological event modifiers must declare one canonical authority")
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
    if set(endgame) != {"protocol.severance", "protocol.containment", "protocol.transformation"}:
        raise legacy.ValidationError("All three final protocols need escalation effects")


def validate_no_wave_loop() -> None:
    paths = [
        "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
        "game/scripts/systems/enemy_tier_progression_director_3d.gd",
        "game/scripts/enemies/enemy_tier_brain_3d.gd",
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
    phrase_groups = [
        ["Saturation transfer", "When a tier saturates"],
        ["Population suppression versus source suppression", "killing low-tier organisms"],
        ["Tier 1 — Feral", "Tier I — Feral"],
        ["Tier 4 — Strategic", "Tier IV — Strategic"],
        ["Bounded spawn credit", "Spawn-credit rules"],
        ["Autonomous suppression and anti-chore protection", "Autonomous suppression"],
        ["Acceptance criteria"],
    ]
    for alternatives in phrase_groups:
        if not any(phrase in document for phrase in alternatives):
            raise legacy.ValidationError(f"Enemy tier design contract is missing one of {alternatives!r}")
    tests = (ROOT / "game/tests/enemy_tier_progression_test_runner.gd").read_text(encoding="utf-8")
    test_groups = [
        ["_test_exact_saturation_transfer", "_test_exact_ten_to_one_transfer"],
        ["_test_population_headroom", "_test_casualty_headroom_and_growth"],
        ["_test_recursive_transfer", "_test_high_to_low_no_same_tick_cascade"],
        ["_test_physical_nests", "_test_physical_nest_spawning_and_cap"],
        ["_test_progression_modifiers", "_test_dynamic_event_modifiers"],
        ["_test_physical_spawn_source", "_test_physical_nest_spawning_and_cap"],
        ["_test_intelligence_progression", "_test_tier_behaviour_progression"],
        ["_test_persistence", "_test_serialization_round_trip"],
    ]
    for alternatives in test_groups:
        if not any(token in tests for token in alternatives):
            raise legacy.ValidationError(f"Enemy tier test suite is missing one of {alternatives!r}")

    integration_tests = (ROOT / "game/tests/ecology_runtime_integration_test_runner.gd").read_text(encoding="utf-8")
    for token in [
        "_test_single_population_authority",
        "_test_single_command_map_hud",
        "_test_birth_handoff",
        "_test_local_attention_process",
        "_test_strategic_state_process",
        "_test_physical_migration_without_birth",
        "_test_canonical_caps",
    ]:
        if token not in integration_tests:
            raise legacy.ValidationError(f"Live ecology integration test suite is missing {token!r}")

    release_tests = (ROOT / "game/tests/release_test_runner.gd").read_text(encoding="utf-8")
    for token in [
        "_test_enemy_tier_unified_persistence",
        'release_data.has(key)',
        '"enemy_tier_progression"',
        "A stale RC1 sidecar must never overwrite canonical tier state",
        "New saves must not write or rotate the legacy enemy-tier sidecar",
    ]:
        if token not in release_tests:
            raise legacy.ValidationError(f"Unified enemy-tier persistence coverage is missing {token!r}")

    soak_tests = (ROOT / "game/tests/long_run_soak_test_runner.gd").read_text(encoding="utf-8")
    if "not FileAccess.file_exists(TEST_SIDECAR_PATH)" not in soak_tests:
        raise legacy.ValidationError("Long-run save coverage must reject creation of a second enemy-tier sidecar generation")


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
