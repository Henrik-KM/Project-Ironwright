#!/usr/bin/env python3
"""Validate the Project Ironwight repository scaffold and design contracts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_PATHS = [
    "README.md",
    "AGENTS.md",
    "ATTRIBUTION.md",
    "docs/DESIGN_LOCKS.md",
    "docs/GAME_DESIGN_DOCUMENT.md",
    "docs/AUTONOMY_AND_ANTI_CHORE.md",
    "docs/ENEMY_ECOLOGY.md",
    "docs/LONG_RUN_SANDBOX.md",
    "docs/ART_DIRECTION_AND_ASSET_PLAN.md",
    "docs/TECHNICAL_ARCHITECTURE.md",
    "docs/PRODUCTION_ROADMAP.md",
    "docs/PLAYTEST_PLAN.md",
    "docs/concept-art/progression-board.png",
    "docs/concept-art/early-game.png",
    "docs/concept-art/mid-game.png",
    "docs/concept-art/late-game.png",
    "game/project.godot",
    "game/scenes/bootstrap.tscn",
    "game/scripts/bootstrap.gd",
    "game/data/design_contracts.json",
    "game/data/autonomy_stages.json",
    "game/data/enemy_archetypes.json",
    "game/data/prototype_scope.json",
    "prompts/FIRST_CODEX_TASK.md",
    ".github/workflows/validate.yml",
]

JSON_FILES = [
    "game/data/design_contracts.json",
    "game/data/autonomy_stages.json",
    "game/data/enemy_archetypes.json",
    "game/data/prototype_scope.json",
]

CONCEPT_ART_DIMENSIONS = {
    "docs/concept-art/progression-board.png": (1536, 1024),
    "docs/concept-art/early-game.png": (1536, 341),
    "docs/concept-art/mid-game.png": (1536, 323),
    "docs/concept-art/late-game.png": (1536, 358),
}

LOCAL_LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


class ValidationError(RuntimeError):
    """Raised for a repository validation failure."""


def load_json(relative_path: str) -> dict[str, Any]:
    path = ROOT / relative_path
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValidationError(f"Missing JSON file: {relative_path}") from exc
    except json.JSONDecodeError as exc:
        raise ValidationError(f"Invalid JSON in {relative_path}: {exc}") from exc

    if not isinstance(data, dict):
        raise ValidationError(f"Top-level JSON value must be an object: {relative_path}")
    return data


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        signature = handle.read(8)
        if signature != b"\x89PNG\r\n\x1a\n":
            raise ValidationError(f"Not a valid PNG: {path.relative_to(ROOT)}")
        length = struct.unpack(">I", handle.read(4))[0]
        chunk_type = handle.read(4)
        if chunk_type != b"IHDR" or length < 8:
            raise ValidationError(f"PNG has no valid IHDR: {path.relative_to(ROOT)}")
        width, height = struct.unpack(">II", handle.read(8))
        return width, height


def validate_required_paths() -> None:
    missing = [path for path in REQUIRED_PATHS if not (ROOT / path).exists()]
    if missing:
        raise ValidationError("Missing required paths:\n- " + "\n- ".join(missing))


def validate_design_contracts() -> None:
    contracts = load_json("game/data/design_contracts.json")
    hard_limits = contracts.get("hard_limits")
    required = contracts.get("required")
    forbidden = contracts.get("forbidden")

    if not isinstance(hard_limits, dict) or not isinstance(required, dict) or not isinstance(forbidden, dict):
        raise ValidationError("design_contracts.json must contain hard_limits, required, and forbidden objects")

    expected_limits = {
        "permanent_player_bases_max": 1,
        "ordinary_stockpiled_resources_max": 1,
        "ordinary_resource_id": "scrap",
    }
    for key, expected in expected_limits.items():
        if hard_limits.get(key) != expected:
            raise ValidationError(f"Design hard limit {key!r} must equal {expected!r}")

    if int(hard_limits.get("principal_run_duration_hours_min", 0)) < 30:
        raise ValidationError("Principal run minimum must remain at least 30 hours")
    if int(hard_limits.get("principal_run_duration_hours_max", 0)) < 60:
        raise ValidationError("Principal run maximum target must remain at least 60 hours")

    required_true = [
        "base_defence_is_primary",
        "base_is_constrained",
        "base_evolves_automatically",
        "robot_autonomy_removes_work",
        "continuous_ecological_pressure",
        "rare_major_attacks_are_causal",
        "early_game_is_small_dark_and_frightening",
        "excursions_return_to_heartforge",
        "repeated_failure_before_first_victory_is_expected",
        "save_is_persistent_across_many_sessions",
    ]
    for key in required_true:
        if required.get(key) is not True:
            raise ValidationError(f"Required design contract {key!r} must be true")

    if required.get("enemy_origin") != "organic":
        raise ValidationError("Enemy origin must remain organic")

    forbidden_true = [
        "territory_claiming",
        "permanent_outposts",
        "multiple_base_network",
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
            raise ValidationError(f"Forbidden design contract {key!r} must remain true")


def validate_autonomy_data() -> None:
    data = load_json("game/data/autonomy_stages.json")
    stages = data.get("stages")
    if not isinstance(stages, list):
        raise ValidationError("autonomy_stages.json must contain a stages array")

    expected_ids = [
        "dependent",
        "routine",
        "cooperative",
        "expeditionary",
        "adaptive",
        "sovereign",
    ]
    actual_ids = [stage.get("id") for stage in stages if isinstance(stage, dict)]
    if actual_ids != expected_ids:
        raise ValidationError(f"Autonomy stages must be ordered as {expected_ids}; got {actual_ids}")

    previous_removed: set[str] = set()
    for stage in stages:
        if not isinstance(stage, dict):
            raise ValidationError("Every autonomy stage must be an object")
        removed = stage.get("work_removed")
        if not isinstance(removed, list):
            raise ValidationError(f"Autonomy stage {stage.get('id')} must contain work_removed")
        current_removed = set(str(value) for value in removed)
        if stage.get("id") != "dependent" and not current_removed:
            raise ValidationError(f"Autonomy stage {stage.get('id')} must remove player work")
        previous_removed |= current_removed

    if len(previous_removed) < 10:
        raise ValidationError("Autonomy ladder must explicitly remove a substantial set of player chores")


def validate_enemy_data() -> None:
    data = load_json("game/data/enemy_archetypes.json")
    if data.get("enemy_origin") != "organic":
        raise ValidationError("enemy_archetypes.json must declare organic enemy origin")

    archetypes = data.get("archetypes")
    if not isinstance(archetypes, list) or len(archetypes) < 5:
        raise ValidationError("At least five organic enemy archetypes are required")

    for archetype in archetypes:
        if not isinstance(archetype, dict):
            raise ValidationError("Every enemy archetype must be an object")
        identifier = str(archetype.get("id", ""))
        if not identifier.startswith("enemy."):
            raise ValidationError(f"Invalid enemy identifier: {identifier!r}")
        combined = json.dumps(archetype).lower()
        if "robot" in combined or "machine faction" in combined:
            raise ValidationError(f"Enemy archetype appears mechanical: {identifier}")


def validate_prototype_scope() -> None:
    data = load_json("game/data/prototype_scope.json")
    out_of_scope = data.get("explicitly_out_of_scope")
    if not isinstance(out_of_scope, list):
        raise ValidationError("prototype_scope.json must contain explicitly_out_of_scope")

    required_exclusions = {
        "scheduled_waves",
        "manual_structure_placement",
        "territory_map",
        "production_queue",
        "power_management",
        "multiple_resources",
        "hostile_robots",
    }
    missing = required_exclusions.difference(str(value) for value in out_of_scope)
    if missing:
        raise ValidationError(f"Prototype scope is missing exclusions: {sorted(missing)}")


def validate_concept_art() -> None:
    for relative_path, expected in CONCEPT_ART_DIMENSIONS.items():
        actual = png_dimensions(ROOT / relative_path)
        if actual != expected:
            raise ValidationError(
                f"Unexpected dimensions for {relative_path}: expected {expected}, got {actual}"
            )


def validate_godot_scaffold() -> None:
    project_text = (ROOT / "game/project.godot").read_text(encoding="utf-8")
    if 'run/main_scene="res://scenes/bootstrap.tscn"' not in project_text:
        raise ValidationError("Godot project must boot scenes/bootstrap.tscn")

    scene_text = (ROOT / "game/scenes/bootstrap.tscn").read_text(encoding="utf-8")
    if 'res://scripts/bootstrap.gd' not in scene_text:
        raise ValidationError("Bootstrap scene must reference bootstrap.gd")

    script_text = (ROOT / "game/scripts/bootstrap.gd").read_text(encoding="utf-8")
    if "res://data/prototype_scope.json" not in script_text:
        raise ValidationError("Bootstrap script must load prototype scope data")


def validate_design_documents() -> None:
    design_locks = (ROOT / "docs/DESIGN_LOCKS.md").read_text(encoding="utf-8").lower()
    required_phrases = [
        "one home",
        "one ordinary resource",
        "no scheduled-wave main loop",
        "enemies are organic",
        "one long sandbox mode",
        "anti-chore acceptance test",
    ]
    for phrase in required_phrases:
        if phrase not in design_locks:
            raise ValidationError(f"DESIGN_LOCKS.md is missing canonical phrase: {phrase!r}")

    gdd = (ROOT / "docs/GAME_DESIGN_DOCUMENT.md").read_text(encoding="utf-8")
    if len(gdd.split()) < 5000:
        raise ValidationError("Game design document is unexpectedly short")


def validate_local_markdown_links() -> None:
    failures: list[str] = []
    for markdown_path in ROOT.rglob("*.md"):
        text = markdown_path.read_text(encoding="utf-8")
        for raw_target in LOCAL_LINK_RE.findall(text):
            target = raw_target.strip().split("#", 1)[0]
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            target = target.split(" ", 1)[0].strip("<>")
            resolved = (markdown_path.parent / target).resolve()
            try:
                resolved.relative_to(ROOT.resolve())
            except ValueError:
                failures.append(f"{markdown_path.relative_to(ROOT)} -> outside repo: {raw_target}")
                continue
            if not resolved.exists():
                failures.append(f"{markdown_path.relative_to(ROOT)} -> missing: {raw_target}")
    if failures:
        raise ValidationError("Broken local Markdown links:\n- " + "\n- ".join(failures))


def iter_manifest_files() -> list[Path]:
    files: list[Path] = []
    excluded_names = {"MANIFEST.sha256", "project_ironwight_survival_repo.zip"}
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if path.name in excluded_names:
            continue
        if any(part in {".git", ".godot", "__pycache__"} for part in path.parts):
            continue
        files.append(path)
    return sorted(files, key=lambda item: item.relative_to(ROOT).as_posix())


def write_manifest() -> None:
    lines: list[str] = []
    for path in iter_manifest_files():
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.relative_to(ROOT).as_posix()}")
    (ROOT / "MANIFEST.sha256").write_text("\n".join(lines) + "\n", encoding="utf-8")


def validate_manifest() -> None:
    path = ROOT / "MANIFEST.sha256"
    if not path.exists():
        return

    recorded: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        digest, relative_path = line.split("  ", 1)
        recorded[relative_path] = digest

    expected_files = iter_manifest_files()
    expected_paths = {item.relative_to(ROOT).as_posix() for item in expected_files}
    if set(recorded) != expected_paths:
        missing = sorted(expected_paths.difference(recorded))
        extra = sorted(set(recorded).difference(expected_paths))
        raise ValidationError(f"Manifest file set mismatch. Missing={missing}, extra={extra}")

    for file_path in expected_files:
        relative = file_path.relative_to(ROOT).as_posix()
        digest = hashlib.sha256(file_path.read_bytes()).hexdigest()
        if recorded.get(relative) != digest:
            raise ValidationError(f"Manifest checksum mismatch: {relative}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--write-manifest",
        action="store_true",
        help="Write MANIFEST.sha256 after all other validation succeeds.",
    )
    args = parser.parse_args()

    validators = [
        validate_required_paths,
        validate_design_contracts,
        validate_autonomy_data,
        validate_enemy_data,
        validate_prototype_scope,
        validate_concept_art,
        validate_godot_scaffold,
        validate_design_documents,
        validate_local_markdown_links,
    ]

    try:
        for validator in validators:
            validator()
        if args.write_manifest:
            write_manifest()
        validate_manifest()
    except ValidationError as exc:
        print(f"VALIDATION FAILED: {exc}", file=sys.stderr)
        return 1

    file_count = len(iter_manifest_files())
    print(f"Project Ironwight repository validation passed ({file_count} files checked).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
