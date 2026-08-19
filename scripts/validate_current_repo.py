#!/usr/bin/env python3
"""Run repository validation against the current production Godot entrypoint.

The legacy validator still provides useful browser, content, link, image and
manifest checks. This wrapper replaces only contracts that were deliberately
superseded by the authoritative conversation and the native full-game build.
"""

from __future__ import annotations

import json
from pathlib import Path

import validate_repo as legacy

ROOT = Path(__file__).resolve().parents[1]

NEW_REQUIRED_PATHS = [
    "docs/FULL_GAME_ROADMAP.md",
    "game/data/full_game_manifest.json",
    "game/data/progression_phases.json",
    "game/data/technology_tree.json",
    "game/data/world_sites.json",
    "game/data/outpost_archetypes.json",
    "game/scripts/main_world_full_game_3d.gd",
    "game/scripts/main_world_production_3d.gd",
    "game/scripts/systems/progression_director_3d.gd",
    "game/scripts/systems/outpost_director_3d.gd",
    "game/scripts/world/outpost_site_3d.gd",
    "game/scripts/world/outpost_3d.gd",
    "game/scripts/ui/strategic_command_hud_3d.gd",
    "game/scripts/enemies/organic_enemy_full_game_3d.gd",
    "game/tests/full_game_test_runner.gd",
]
for relative in NEW_REQUIRED_PATHS:
    if relative not in legacy.REQUIRED_PATHS:
        legacy.REQUIRED_PATHS.append(relative)


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
    if forbidden.get("permanent_outposts") is True:
        raise legacy.ValidationError("The obsolete blanket ban on autonomous outposts must not return")

    manifest = _load("game/data/full_game_manifest.json")
    if manifest.get("principal_mode") != "persistent_survival_sandbox":
        raise legacy.ValidationError("Full-game manifest must retain the persistent survival sandbox")
    milestones = manifest.get("production_milestones")
    if not isinstance(milestones, list) or len(milestones) < 10:
        raise legacy.ValidationError("Full-game manifest must contain the end-to-end milestone sequence")

    progression = _load("game/data/progression_phases.json")
    phases = progression.get("phases")
    expected_phases = ["embers", "foothold", "network", "frontier", "machine_war", "sovereignty"]
    if not isinstance(phases, list) or [phase.get("id") for phase in phases] != expected_phases:
        raise legacy.ValidationError(f"Progression phases must be ordered as {expected_phases}")

    technologies = _load("game/data/technology_tree.json").get("technologies")
    if not isinstance(technologies, list) or len(technologies) < 8:
        raise legacy.ValidationError("Technology registry is too small for the production foundation")
    technology_ids = {entry.get("id") for entry in technologies if isinstance(entry, dict)}
    for identifier in [
        "tech.machine.group_coordination",
        "tech.heartforge.tier_2",
        "tech.machine.field_engineering",
        "tech.outpost.resource",
    ]:
        if identifier not in technology_ids:
            raise legacy.ValidationError(f"Missing required technology {identifier}")

    sites = _load("game/data/world_sites.json").get("sites")
    if not isinstance(sites, list) or len(sites) < 4:
        raise legacy.ValidationError("The full-game foundation needs fixed discoverable world sites")
    for site in sites:
        if not isinstance(site, dict) or not str(site.get("id", "")).startswith("site."):
            raise legacy.ValidationError("Every world site needs a stable site.* identifier")

    outposts = _load("game/data/outpost_archetypes.json")
    if outposts.get("ordinary_resource") != "scrap":
        raise legacy.ValidationError("Outposts may not introduce another ordinary resource")
    roles = outposts.get("roles")
    if not isinstance(roles, dict) or set(roles) != {"resource", "defence", "scout", "repair"}:
        raise legacy.ValidationError("Outpost roles must be resource, defence, scout and repair")


def validate_native_godot_entrypoint() -> None:
    project_text = (ROOT / "game/project.godot").read_text(encoding="utf-8")
    if 'run/main_scene="res://scenes/main_3d.tscn"' not in project_text:
        raise legacy.ValidationError("Godot project must boot scenes/main_3d.tscn")

    scene_text = (ROOT / "game/scenes/main_3d.tscn").read_text(encoding="utf-8")
    if "res://scripts/main_world_production_3d.gd" not in scene_text:
        raise legacy.ValidationError("The native main scene must boot the production full-game world")

    production = (ROOT / "game/scripts/main_world_production_3d.gd").read_text(encoding="utf-8")
    full_game = (ROOT / "game/scripts/main_world_full_game_3d.gd").read_text(encoding="utf-8")
    for token in ["extends IronwrightFullGameWorld3D", "engineer_build_available"]:
        if token not in production:
            raise legacy.ValidationError(f"Production entrypoint is missing {token!r}")
    for token in [
        "ProgressionDirector3D",
        "OutpostDirector3D",
        "StrategicCommandHUD3D",
        "discover_sites_by",
        "heartforge_evolution",
        "EXTENSION_SAVE_PATH",
    ]:
        if token not in full_game:
            raise legacy.ValidationError(f"Full-game integration is missing {token!r}")

    hud_scene = (ROOT / "game/scenes/ui/ironwright_hud_3d.tscn").read_text(encoding="utf-8")
    if "ironwright_beautiful_hud_3d.gd" not in hud_scene:
        raise legacy.ValidationError("Native HUD must retain the cinematic skin")


def validate_current_design_documents() -> None:
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8").lower()
    if "conversation with henrik is the highest product authority" not in agents:
        raise legacy.ValidationError("AGENTS.md must state that the authoritative conversation overrides stale files")

    locks = (ROOT / "docs/DESIGN_LOCKS.md").read_text(encoding="utf-8").lower()
    required_phrases = [
        "one primary home",
        "autonomous outposts are canonical",
        "one ordinary resource",
        "no scheduled-wave main loop",
        "enemies are organic",
        "the full world always exists",
        "anti-chore acceptance test",
    ]
    for phrase in required_phrases:
        if phrase not in locks:
            raise legacy.ValidationError(f"DESIGN_LOCKS.md is missing current phrase {phrase!r}")
    if "forward bases or permanent outposts" in locks:
        raise legacy.ValidationError("DESIGN_LOCKS.md still contains the obsolete blanket outpost ban")

    roadmap = (ROOT / "docs/FULL_GAME_ROADMAP.md").read_text(encoding="utf-8")
    if len(roadmap.split()) < 2500:
        raise legacy.ValidationError("Full-game roadmap is unexpectedly short")
    if "Milestone 13 — Release candidate and launch" not in roadmap:
        raise legacy.ValidationError("Full-game roadmap must extend through release")

    gdd = (ROOT / "docs/GAME_DESIGN_DOCUMENT.md").read_text(encoding="utf-8")
    if len(gdd.split()) < 5000:
        raise legacy.ValidationError("Game design document is unexpectedly short")


legacy.validate_design_contracts = validate_current_design_contracts
legacy.validate_godot_scaffold = validate_native_godot_entrypoint
legacy.validate_design_documents = validate_current_design_documents


if __name__ == "__main__":
    raise SystemExit(legacy.main())
