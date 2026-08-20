#!/usr/bin/env python3
"""Validate the authoritative complete-game Godot implementation."""

from __future__ import annotations

import json
from pathlib import Path

import validate_repo as legacy

ROOT = Path(__file__).resolve().parents[1]

NEW_REQUIRED_PATHS = [
    "docs/FULL_GAME_ROADMAP.md",
    "docs/FIRST_SESSION_UX.md",
    "docs/COMPLETE_GAME_ALPHA.md",
    "docs/PRESENTATION_QUALITY_GATE.md",
    "docs/PERSISTENCE_AND_SAVE_SCHEMA.md",
    "game/data/full_game_manifest.json",
    "game/data/progression_phases.json",
    "game/data/technology_tree.json",
    "game/data/world_sites.json",
    "game/data/outpost_archetypes.json",
    "game/data/world_regions.json",
    "game/data/strategic_operations.json",
    "game/data/endgame_protocols.json",
    "game/scripts/main_world_full_game_3d.gd",
    "game/scripts/main_world_production_3d.gd",
    "game/scripts/main_world_complete_3d.gd",
    "game/scripts/main_world_prealpha_3d.gd",
    "game/scripts/systems/transactional_save_service_3d.gd",
    "game/scripts/systems/progression_director_3d.gd",
    "game/scripts/systems/outpost_director_3d.gd",
    "game/scripts/systems/world_region_director_3d.gd",
    "game/scripts/systems/long_range_operation_director_3d.gd",
    "game/scripts/systems/machine_society_director_3d.gd",
    "game/scripts/systems/strategic_ecology_director_3d.gd",
    "game/scripts/systems/endgame_director_3d.gd",
    "game/scripts/world/outpost_site_3d.gd",
    "game/scripts/world/outpost_3d.gd",
    "game/scripts/world/region_landmark_3d.gd",
    "game/scripts/ui/strategic_command_hud_3d.gd",
    "game/scripts/ui/operations_command_hud_3d.gd",
    "game/scripts/ui/ironwright_prealpha_hud_3d.gd",
    "game/scripts/presentation/objective_guidance_3d.gd",
    "game/scripts/enemies/organic_enemy_full_game_3d.gd",
    "game/tests/full_game_test_runner.gd",
    "game/tests/first_session_ux_test_runner.gd",
    "game/tests/complete_game_test_runner.gd",
    "game/tests/presentation_and_salvage_escort_test_runner.gd",
    "game/tests/persistence_test_runner.gd",
    "game/assets/mechromancer/mechromancer.gltf",
    "game/assets/mechromancer/mechromancer.bin",
    "game/assets/mechromancer/source/mechromancer.blend",
    "game/assets/mechromancer/mechromancer_portrait.png",
    "game/assets/mechromancer/mechromancer_coat.png",
    "game/assets/mechromancer/mechromancer_leather.png",
    "game/assets/mechromancer/mechromancer_metal.png",
    "game/assets/mechromancer/mechromancer_skin.png",
    "game/assets/mechromancer/mechromancer_coat_normal.png",
    "game/assets/mechromancer/mechromancer_leather_normal.png",
    "game/assets/mechromancer/mechromancer_metal_normal.png",
    "game/assets/mechromancer/mechromancer_skin_normal.png",
    "game/assets/mechromancer/source/build_mechromancer_blend.py",
    "game/assets/mechromancer/source/build_mechromancer_asset.py",
    "game/assets/mechromancer/source/README.md",
    "game/data/mechromancer_asset_manifest.json",
]
for relative in NEW_REQUIRED_PATHS:
    if relative not in legacy.REQUIRED_PATHS:
        legacy.REQUIRED_PATHS.append(relative)

OBSOLETE_PATCH_PATHS = [
    ".github/workflows/apply-aesthetic-patch.yml",
    "scripts/apply_patch_payload.py",
    "scripts/.aesthetic_patch",
]


def _load(relative: str) -> dict:
    path = ROOT / relative
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise legacy.ValidationError(f"Invalid or missing JSON {relative}: {exc}") from exc
    if not isinstance(data, dict):
        raise legacy.ValidationError(f"Top-level JSON must be an object: {relative}")
    return data


def validate_current_design_contracts() -> None:
    contracts = _load("game/data/design_contracts.json")
    limits = contracts.get("hard_limits")
    required = contracts.get("required")
    forbidden = contracts.get("forbidden")
    if not isinstance(limits, dict) or not isinstance(required, dict) or not isinstance(forbidden, dict):
        raise legacy.ValidationError("Current design contracts need hard_limits, required and forbidden objects")

    expected_limits = {
        "player_operated_primary_bases_max": 1,
        "ordinary_stockpiled_resources_max": 1,
        "ordinary_resource_id": "scrap",
        "outpost_sites_are_bounded": True,
    }
    for key, expected in expected_limits.items():
        if limits.get(key) != expected:
            raise legacy.ValidationError(f"Current hard limit {key!r} must equal {expected!r}")
    if int(limits.get("principal_run_duration_hours_min", 0)) < 30:
        raise legacy.ValidationError("Principal run minimum must remain at least 30 hours")
    if int(limits.get("principal_run_duration_hours_max", 0)) < 60:
        raise legacy.ValidationError("Principal run maximum target must remain at least 60 hours")

    required_true = [
        "base_defence_is_primary",
        "heartforge_is_only_player_operated_home",
        "robot_autonomy_removes_work",
        "continuous_ecological_pressure",
        "rare_major_attacks_are_causal",
        "mechromancer_begins_with_weak_automatic_pistol",
        "early_survival_depends_on_companion",
        "manual_salvage_is_loud_timed_and_disables_attack",
        "early_robot_fabrication_is_manual_timed_and_disables_attack",
        "full_world_exists_at_all_times",
        "remote_entities_keep_physical_positions",
        "expeditions_physically_traverse_world",
        "remote_groups_use_cohesion_and_regrouping",
        "autonomous_outposts_on_discovered_fixed_sites",
        "outpost_builders_and_escorts_physically_travel",
        "outposts_self_repair",
        "destroyed_outposts_rebuild_automatically",
        "resource_output_is_physically_hauled",
    ]
    for key in required_true:
        if required.get(key) is not True:
            raise legacy.ValidationError(f"Required current design contract {key!r} must be true")
    if required.get("enemy_origin") != "organic":
        raise legacy.ValidationError("Enemy origin must remain organic")

    forbidden_true = [
        "territory_claiming",
        "freeform_outpost_placement",
        "multiple_player_operated_base_network",
        "per_outpost_worker_assignment",
        "per_outpost_production_queues",
        "manual_supply_line_management",
        "production_chain_economy",
        "player_managed_power_grid",
        "scheduled_recurring_wave_loop",
        "hostile_robot_faction",
        "routine_individual_robot_orders",
        "routine_individual_robot_loadouts",
        "routine_manual_wall_placement",
        "hunger_thirst_sleep_management",
        "short_run_roguelite_as_principal_mode",
    ]
    for key in forbidden_true:
        if forbidden.get(key) is not True:
            raise legacy.ValidationError(f"Forbidden current design contract {key!r} must remain true")

    manifest = _load("game/data/full_game_manifest.json")
    if manifest.get("principal_mode") != "persistent_survival_sandbox":
        raise legacy.ValidationError("Full-game manifest must retain the persistent survival sandbox")

    progression = _load("game/data/progression_phases.json")
    phases = progression.get("phases")
    expected_phases = ["embers", "foothold", "network", "frontier", "machine_war", "sovereignty"]
    if not isinstance(phases, list) or [phase.get("id") for phase in phases] != expected_phases:
        raise legacy.ValidationError(f"Progression phases must be ordered as {expected_phases}")

    technologies = _load("game/data/technology_tree.json").get("technologies")
    if not isinstance(technologies, list) or len(technologies) < 16:
        raise legacy.ValidationError("The complete alpha needs the full Heartforge and endgame technology path")
    technology_ids = {entry.get("id") for entry in technologies if isinstance(entry, dict)}
    for identifier in [
        "tech.heartforge.tier_2",
        "tech.heartforge.tier_3",
        "tech.heartforge.tier_4",
        "tech.heartforge.tier_5",
        "tech.machine.forge_assistance",
        "tech.doctrine.deep_operations",
        "tech.endgame.severance",
        "tech.endgame.containment",
    ]:
        if identifier not in technology_ids:
            raise legacy.ValidationError(f"Missing complete-game technology {identifier}")

    regions = _load("game/data/world_regions.json").get("regions")
    if not isinstance(regions, list) or len(regions) < 12:
        raise legacy.ValidationError("The complete alpha needs all twelve persistent regions")
    region_ids = {entry.get("id") for entry in regions if isinstance(entry, dict)}
    for identifier in ["region.heartforge_district", "region.root_cistern"]:
        if identifier not in region_ids:
            raise legacy.ValidationError(f"Missing required region {identifier}")

    operations = _load("game/data/strategic_operations.json").get("operations")
    if not isinstance(operations, list) or len(operations) < 6:
        raise legacy.ValidationError("The complete alpha needs the long-range operation chain")
    operation_ids = {entry.get("id") for entry in operations if isinstance(entry, dict)}
    for identifier in [
        "operation.west_grid_survey",
        "operation.flood_market_recovery",
        "operation.cathedral_brood_suppression",
        "operation.buried_lab_excavation",
        "operation.root_cistern_mapping",
    ]:
        if identifier not in operation_ids:
            raise legacy.ValidationError(f"Missing required operation {identifier}")

    protocols = _load("game/data/endgame_protocols.json").get("protocols")
    if not isinstance(protocols, list) or {entry.get("id") for entry in protocols if isinstance(entry, dict)} != {
        "protocol.severance",
        "protocol.containment",
    }:
        raise legacy.ValidationError("The complete alpha must expose Severance and Containment endings")

    serialized_content = json.dumps({
        "regions": regions,
        "operations": operations,
        "protocols": protocols,
    }).lower()
    if "hostile robot" in serialized_content or "enemy robot" in serialized_content:
        raise legacy.ValidationError("Complete-game content may not introduce hostile robots")


def validate_native_godot_entrypoint() -> None:
    project_text = (ROOT / "game/project.godot").read_text(encoding="utf-8")
    if 'run/main_scene="res://scenes/main_3d.tscn"' not in project_text:
        raise legacy.ValidationError("Godot project must boot scenes/main_3d.tscn")

    scene_text = (ROOT / "game/scenes/main_3d.tscn").read_text(encoding="utf-8")
    if "res://scripts/main_world_release_3d.gd" not in scene_text and "res://scripts/main_world_tiered_3d.gd" not in scene_text:
        raise legacy.ValidationError("The native main scene must boot the commercial release or tiered world")

    release = (ROOT / "game/scripts/main_world_release_3d.gd").read_text(encoding="utf-8")
    for token in ["extends IronwrightProductionWorld3D", "ReleaseTransactionalSaveService3D", "ReleaseWorldArtDirector3D", "_collect_release_snapshot", "_restore_release_snapshot"]:
        if token not in release:
            raise legacy.ValidationError(f"Release entrypoint integration is missing {token!r}")

    if "res://scripts/main_world_tiered_3d.gd" in scene_text:
        tiered = (ROOT / "game/scripts/main_world_tiered_3d.gd").read_text(encoding="utf-8")
        for token in ["extends IronwrightReleaseWorld3D", "EnemyTierDirector3D", "EnemyTierEventBridge3D", "EnemyTierHUD3D"]:
            if token not in tiered:
                raise legacy.ValidationError(f"Tiered entrypoint integration is missing {token!r}")

    prealpha = (ROOT / "game/scripts/main_world_prealpha_3d.gd").read_text(encoding="utf-8")
    for token in ["extends IronwrightProductionWorld3D", "_resolve_camera_occlusion", "set_map_emphasis", "pre-alpha production prototype"]:
        if token not in prealpha:
            raise legacy.ValidationError(f"Pre-alpha presentation-reset integration is missing {token!r}")

    complete = (ROOT / "game/scripts/main_world_complete_3d.gd").read_text(encoding="utf-8")
    required_complete_tokens = [
        "extends IronwrightFullGameWorld3D",
        "WorldRegionDirector3D",
        "LongRangeOperationDirector3D",
        "MachineSocietyDirector3D",
        "StrategicEcologyDirector3D",
        "EndgameDirector3D",
        "OperationsCommandHUD3D",
        "_save_extension_data",
        "_restore_extension_data",
        "_update_complete_game_objective",
        "_on_endgame_completed",
    ]
    for token in required_complete_tokens:
        if token not in complete:
            raise legacy.ValidationError(f"Complete-game integration is missing {token!r}")

    progression_source = (ROOT / "game/scripts/systems/progression_director_3d.gd").read_text(encoding="utf-8")
    for token in ["context_provider", "completed_operation", "components_min", "functioning_outposts_min"]:
        if token not in progression_source:
            raise legacy.ValidationError(f"Long-run progression context is missing {token!r}")

    long_operation_source = (ROOT / "game/scripts/systems/long_range_operation_director_3d.gd").read_text(encoding="utf-8")
    for token in ["pending_rewards", "returning", "FormationRules3D", "component_recovered"]:
        if token not in long_operation_source:
            raise legacy.ValidationError(f"Physical long-range operations are missing {token!r}")

    autonomy_source = (ROOT / "game/scripts/systems/autonomy_director_3d.gd").read_text(encoding="utf-8")
    for token in ["_refresh_salvage_escort_assignments", "salvage_guardians", "player_guardians", "salvage_escort", "mechromancer_escort"]:
        if token not in autonomy_source:
            raise legacy.ValidationError(f"Salvage protection doctrine is missing {token!r}")

    endgame_source = (ROOT / "game/scripts/systems/endgame_director_3d.gd").read_text(encoding="utf-8")
    for token in ["initiate", "endgame_escalation", "endgame_completed", "player-triggered"]:
        if token not in endgame_source:
            raise legacy.ValidationError(f"Complete victory path is missing {token!r}")

    hud_scene = (ROOT / "game/scenes/ui/ironwright_hud_3d.tscn").read_text(encoding="utf-8")
    if "ironwright_prealpha_hud_3d.gd" not in hud_scene:
        raise legacy.ValidationError("Native HUD must use the quieter desktop pre-alpha layer")

    for obsolete in OBSOLETE_PATCH_PATHS:
        if (ROOT / obsolete).exists():
            raise legacy.ValidationError(f"Obsolete self-modifying patch infrastructure must be absent: {obsolete}")

    manifest = json.loads((ROOT / "game/data/mechromancer_asset_manifest.json").read_text(encoding="utf-8"))
    gltf = json.loads((ROOT / "game/assets/mechromancer/mechromancer.gltf").read_text(encoding="utf-8"))
    if manifest.get("asset_id") != "mechromancer.player.v1":
        raise legacy.ValidationError("Mechromancer asset manifest has an unexpected stable asset ID")
    if manifest.get("runtime_model") != "res://assets/mechromancer/mechromancer.gltf":
        raise legacy.ValidationError("Mechromancer manifest points at an unexpected runtime model")
    if manifest.get("runtime_buffer") != "res://assets/mechromancer/mechromancer.bin":
        raise legacy.ValidationError("Mechromancer manifest must document the glTF buffer")
    node_names = {str(node.get("name")) for node in gltf.get("nodes", [])}
    missing_nodes = set(manifest.get("required_nodes", [])).difference(node_names)
    if missing_nodes:
        raise legacy.ValidationError(f"Mechromancer glTF is missing required nodes: {sorted(missing_nodes)}")
    animation_names = {str(animation.get("name")) for animation in gltf.get("animations", [])}
    missing_animations = set(manifest.get("animation_clips", [])).difference(animation_names)
    if missing_animations:
        raise legacy.ValidationError(f"Mechromancer glTF is missing required clips: {sorted(missing_animations)}")


def validate_current_design_documents() -> None:
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8").lower()
    if "conversation with henrik is the highest product authority" not in agents:
        raise legacy.ValidationError("AGENTS.md must preserve authoritative-chat precedence")

    locks = (ROOT / "docs/DESIGN_LOCKS.md").read_text(encoding="utf-8").lower()
    for phrase in [
        "one primary home",
        "autonomous outposts are canonical",
        "one ordinary resource",
        "no scheduled-wave main loop",
        "enemies are organic",
        "the full world always exists",
        "anti-chore acceptance test",
    ]:
        if phrase not in locks:
            raise legacy.ValidationError(f"DESIGN_LOCKS.md is missing current phrase {phrase!r}")

    roadmap = (ROOT / "docs/FULL_GAME_ROADMAP.md").read_text(encoding="utf-8")
    if len(roadmap.split()) < 2500 or "Milestone 13 — Release candidate and launch" not in roadmap:
        raise legacy.ValidationError("The full-game roadmap must remain end-to-end")

    complete_alpha = (ROOT / "docs/COMPLETE_GAME_ALPHA.md").read_text(encoding="utf-8").lower()
    for phrase in [
        "multi-region world",
        "long-range operations",
        "machine society",
        "continuous regional ecology",
        "final protocols",
        "first victory",
    ]:
        if phrase not in complete_alpha:
            raise legacy.ValidationError(f"COMPLETE_GAME_ALPHA.md is missing {phrase!r}")

    quality_gate = (ROOT / "docs/PRESENTATION_QUALITY_GATE.md").read_text(encoding="utf-8").lower()
    for phrase in [
        "pre-alpha production prototype",
        "release-readiness rule",
        "world-label rule",
        "hud rule",
        "autonomy presentation rule",
    ]:
        if phrase not in quality_gate:
            raise legacy.ValidationError(f"PRESENTATION_QUALITY_GATE.md is missing {phrase!r}")

    gdd = (ROOT / "docs/GAME_DESIGN_DOCUMENT.md").read_text(encoding="utf-8")
    if len(gdd.split()) < 5000:
        raise legacy.ValidationError("Game design document is unexpectedly short")


legacy.validate_design_contracts = validate_current_design_contracts
legacy.validate_godot_scaffold = validate_native_godot_entrypoint
legacy.validate_design_documents = validate_current_design_documents


if __name__ == "__main__":
    raise SystemExit(legacy.main())
