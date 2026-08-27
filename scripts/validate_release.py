#!/usr/bin/env python3
"""Validate the Project Ironwright commercial release candidate.

This preserves all current product-contract checks while replacing the native
entrypoint assertion with the release runtime and adding release-specific
assets, localization, packaging, save, accessibility, performance and content
gates.
"""

from __future__ import annotations

import json
import wave
from pathlib import Path

import validate_repo as legacy
import validate_current_repo as current

ROOT = Path(__file__).resolve().parents[1]
_BASE_VALIDATE_REQUIRED_PATHS = legacy.validate_required_paths

RELEASE_REQUIRED_PATHS = [
    "game/data/release_manifest.json",
    "game/data/balance_profiles.json",
    "game/data/accessibility_defaults.json",
    "game/localization/en.json",
    "game/localization/sv.json",
    "game/localization/de.json",
    "game/scripts/main_world_release_3d.gd",
    "game/scripts/release/localization_service_3d.gd",
    "game/scripts/release/release_settings_service_3d.gd",
    "game/scripts/release/transactional_save_service_3d.gd",
    "game/scripts/release/spatial_index_3d.gd",
    "game/scripts/release/balance_director_3d.gd",
    "game/scripts/release/performance_director_3d.gd",
    "game/scripts/release/release_audio_director_3d.gd",
    "game/scripts/release/release_world_art_director_3d.gd",
    "game/scripts/release/release_animation_director_3d.gd",
    "game/scripts/release/release_secondary_motion_3d.gd",
    "game/scripts/release/release_front_end_3d.gd",
    "game/scripts/actors/mechromancer_release_3d.gd",
    "game/scripts/robots/robot_unit_release_3d.gd",
    "game/scripts/enemies/organic_enemy_release_3d.gd",
    "game/tests/release_test_runner.gd",
    "game/export_presets.cfg",
    "docs/COMMERCIAL_RELEASE_CANDIDATE.md",
    ".github/workflows/release.yml",
]

TEXTURE_NAMES = [
    "asphalt_wet.png",
    "brick_ruin.png",
    "chitin.png",
    "concrete_wet.png",
    "grime_decal.png",
    "membrane.png",
    "metal_brushed.png",
    "moss_growth.png",
    "rust_panel.png",
]

NORMAL_TEXTURE_NAMES = [
    "asphalt_wet_normal.png",
    "brick_ruin_normal.png",
    "chitin_normal.png",
    "concrete_wet_normal.png",
    "grime_decal_normal.png",
    "membrane_normal.png",
    "metal_brushed_normal.png",
    "moss_growth_normal.png",
    "rust_panel_normal.png",
]

AUDIO_NAMES = [
    "ambience_city.wav",
    "ambience_sanctuary.wav",
    "ambience_cistern.wav",
    "music_embers.wav",
    "music_pressure.wav",
    "music_sovereignty.wav",
    "sfx_danger.wav",
    "sfx_forge.wav",
    "sfx_machine_report.wav",
    "sfx_organic_hit.wav",
    "sfx_pistol.wav",
    "sfx_salvage.wav",
    "sfx_ui_confirm.wav",
    "sfx_victory.wav",
]


def _load_json(relative_path: str) -> dict:
    path = ROOT / relative_path
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise legacy.ValidationError(f"Invalid release JSON {relative_path}: {exc}") from exc
    if not isinstance(value, dict):
        raise legacy.ValidationError(f"Release JSON must contain an object: {relative_path}")
    return value


def validate_release_required_paths() -> None:
    _BASE_VALIDATE_REQUIRED_PATHS()
    missing = [relative for relative in RELEASE_REQUIRED_PATHS if not (ROOT / relative).is_file()]
    missing += [
        f"game/assets/release/textures/{name}"
        for name in TEXTURE_NAMES
        if not (ROOT / "game/assets/release/textures" / name).is_file()
    ]
    missing += [
        f"game/assets/release/textures/{name}"
        for name in NORMAL_TEXTURE_NAMES
        if not (ROOT / "game/assets/release/textures" / name).is_file()
    ]
    missing += [
        f"game/assets/release/audio/{name}"
        for name in AUDIO_NAMES
        if not (ROOT / "game/assets/release/audio" / name).is_file()
    ]
    if missing:
        raise legacy.ValidationError("Missing commercial-release files:\n- " + "\n- ".join(missing))


def validate_release_entrypoint() -> None:
    project = (ROOT / "game/project.godot").read_text(encoding="utf-8")
    if 'run/main_scene="res://scenes/main_3d.tscn"' not in project:
        raise legacy.ValidationError("Release project must boot scenes/main_3d.tscn")
    if 'config/version="1.0.0-rc.1"' not in project:
        raise legacy.ValidationError("Godot project version must match the release candidate")

    scene = (ROOT / "game/scenes/main_3d.tscn").read_text(encoding="utf-8")
    # The release scene may enter through the population-driven tier wrapper;
    # that wrapper inherits IronwrightReleaseWorld3D and is the canonical
    # production entrypoint when the tier bootstrap is present.
    valid_scene_scripts = {
        "res://scripts/main_world_release_3d.gd",
        "res://scripts/main_world_tiered_3d.gd",
    }
    if not any(script in scene for script in valid_scene_scripts):
        raise legacy.ValidationError("Native scene must boot the release world or its tiered production wrapper")
    if "res://scripts/main_world_tiered_3d.gd" in scene and "EnemyTierProgressionBootstrap" not in scene:
        raise legacy.ValidationError("Tiered production entrypoint must include the enemy progression bootstrap")

    world = (ROOT / "game/scripts/main_world_release_3d.gd").read_text(encoding="utf-8")
    for token in [
        "extends IronwrightProductionWorld3D",
        "ReleaseTransactionalSaveService3D",
        "ReleaseSettingsService3D",
        "LocalizationService3D",
        "SpatialIndex3D",
        "BalanceDirector3D",
        "PerformanceDirector3D",
        "ReleaseAudioDirector3D",
        "ReleaseWorldArtDirector3D",
        "ReleaseAnimationDirector3D",
        "ReleaseFrontEnd3D",
        "_collect_release_snapshot",
        "_restore_release_snapshot",
        "_migrate_legacy_saves",
    ]:
        if token not in world:
            raise legacy.ValidationError(f"Release world is missing integration token {token!r}")


def validate_release_manifest() -> None:
    manifest = _load_json("game/data/release_manifest.json")
    if manifest.get("display_version") != "1.0.0-rc.1":
        raise legacy.ValidationError("Release manifest version must be 1.0.0-rc.1")
    if manifest.get("release_channel") != "release_candidate":
        raise legacy.ValidationError("Release channel must remain release_candidate until external release QA")
    if manifest.get("save_schema_version") != 4:
        raise legacy.ValidationError("Transactional release save schema must be version 4")
    if set(manifest.get("supported_locales", [])) != {"en", "sv", "de"}:
        raise legacy.ValidationError("Release locales must include en, sv and de")
    services = set(manifest.get("production_services", []))
    required_services = {
        "transactional_save_service",
        "release_settings_service",
        "localization_service",
        "adaptive_audio_director",
        "release_world_art_director",
        "release_animation_director",
        "spatial_index",
        "performance_director",
        "balance_director",
        "release_front_end",
    }
    if not required_services.issubset(services):
        raise legacy.ValidationError(f"Release manifest is missing services: {sorted(required_services - services)}")


def validate_localization_catalogs() -> None:
    catalogs = {
        locale: _load_json(f"game/localization/{locale}.json")
        for locale in ("en", "sv", "de")
    }
    baseline = set(catalogs["en"].get("strings", {}))
    if len(baseline) < 50:
        raise legacy.ValidationError("English release catalog is unexpectedly small")
    for locale, data in catalogs.items():
        strings = data.get("strings")
        if not isinstance(strings, dict):
            raise legacy.ValidationError(f"Localization catalog {locale} needs a strings object")
        if set(strings) != baseline:
            missing = sorted(baseline - set(strings))
            extra = sorted(set(strings) - baseline)
            raise legacy.ValidationError(f"Localization parity failure for {locale}: missing={missing}, extra={extra}")
        for key, value in strings.items():
            if not isinstance(value, str) or not value.strip():
                raise legacy.ValidationError(f"Localization value {locale}:{key} is empty")


def validate_release_content_breadth() -> None:
    regions = _load_json("game/data/world_regions.json").get("regions", [])
    operations = _load_json("game/data/strategic_operations.json").get("operations", [])
    enemies = _load_json("game/data/enemy_archetypes.json").get("archetypes", [])
    sites = _load_json("game/data/world_sites.json").get("sites", [])
    profiles = _load_json("game/data/balance_profiles.json").get("profiles", {})
    if len(regions) < 12:
        raise legacy.ValidationError("Commercial release needs at least twelve persistent regions")
    if len(operations) < 16:
        raise legacy.ValidationError("Commercial release needs at least sixteen physical operations")
    if len(enemies) < 14:
        raise legacy.ValidationError("Commercial release needs at least fourteen organic enemy families")
    if len(sites) < 24:
        raise legacy.ValidationError("Commercial release needs at least twenty-four bounded outpost foundations")
    if set(profiles) != {"story", "survival", "brutal"}:
        raise legacy.ValidationError("Release balance profiles must be story, survival and brutal")
    for archetype in enemies:
        combined = json.dumps(archetype).lower()
        if "robot" in combined or "machine faction" in combined:
            raise legacy.ValidationError(f"Hostile release archetype appears mechanical: {archetype.get('id')}")


def validate_release_assets() -> None:
    texture_root = ROOT / "game/assets/release/textures"
    for name in [*TEXTURE_NAMES, *NORMAL_TEXTURE_NAMES]:
        path = texture_root / name
        data = path.read_bytes()
        if len(data) < 2_000 or not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise legacy.ValidationError(f"Release texture is invalid or trivial: {name}")

    audio_root = ROOT / "game/assets/release/audio"
    for name in AUDIO_NAMES:
        path = audio_root / name
        data = path.read_bytes()
        if len(data) < 5_000:
            raise legacy.ValidationError(f"Release audio is unexpectedly small: {name}")
        if name.endswith(".ogg") and not data.startswith(b"OggS"):
            raise legacy.ValidationError(f"Release OGG has no OggS signature: {name}")
        if name.endswith(".wav"):
            if not data.startswith(b"RIFF") or data[8:12] != b"WAVE":
                raise legacy.ValidationError(f"Release WAV has no RIFF/WAVE signature: {name}")
            with wave.open(str(path), "rb") as wav:
                if wav.getnchannels() not in (1, 2) or wav.getframerate() < 16_000 or wav.getnframes() < 1_000:
                    raise legacy.ValidationError(f"Release WAV metadata is invalid: {name}")


def validate_release_services() -> None:
    settings = (ROOT / "game/scripts/release/release_settings_service_3d.gd").read_text(encoding="utf-8")
    for token in [
        "ensure_input_map",
        "JOY_BUTTON_A",
        "controller_vibration",
        "text_scale",
        "high_contrast_ui",
        "hold_interactions",
        "target_fps",
    ]:
        if token not in settings:
            raise legacy.ValidationError(f"Release settings service is missing {token!r}")

    saves = (ROOT / "game/scripts/release/transactional_save_service_3d.gd").read_text(encoding="utf-8")
    for token in [
        "CURRENT_SCHEMA_VERSION: int = 4",
        "checksum_sha256",
        "_rotate_backups",
        "migrate_legacy_payload",
        "corrupt_current_for_test",
    ]:
        if token not in saves:
            raise legacy.ValidationError(f"Transactional save service is missing {token!r}")

    performance = (ROOT / "game/scripts/release/performance_director_3d.gd").read_text(encoding="utf-8")
    for token in ["reduced_detail_tick", "active_radius", "medium_radius", "_adapt_budgets"]:
        if token not in performance:
            raise legacy.ValidationError(f"Performance director is missing {token!r}")

    audio = (ROOT / "game/scripts/release/release_audio_director_3d.gd").read_text(encoding="utf-8")
    for token in ["ambience_city", "music_embers", "music_pressure", "music_sovereignty", "show_caption"]:
        if token not in audio:
            raise legacy.ValidationError(f"Release audio director is missing {token!r}")


def validate_release_packaging() -> None:
    presets = (ROOT / "game/export_presets.cfg").read_text(encoding="utf-8")
    for token in ['name="Windows Desktop"', 'name="Linux/X11"', "export_filter=\"all_resources\""]:
        if token not in presets:
            raise legacy.ValidationError(f"Release export presets are missing {token!r}")
    workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
    for token in ["include-templates: true", "upload-artifact"]:
        if token not in workflow:
            raise legacy.ValidationError(f"Release workflow is missing {token!r}")
    if not any(
        command in workflow
        for command in [
            "godot --headless --path game --export-release",
            "godot --headless --audio-driver Dummy --path game --export-release",
        ]
    ):
        raise legacy.ValidationError("Release workflow is missing a silent Godot export command")
    windows_archive = "(cd windows && zip -9 -r ../ProjectIronwright-1.0.0-rc.1-Windows.zip .)"
    linux_archive = "(cd linux && tar -czf ../ProjectIronwright-1.0.0-rc.1-Linux.tar.gz .)"
    checksum_line = "sha256sum windows/ProjectIronwright.exe windows/ProjectIronwright.pck linux/ProjectIronwright.x86_64 linux/ProjectIronwright.pck ProjectIronwright-1.0.0-rc.1-Windows.zip ProjectIronwright-1.0.0-rc.1-Linux.tar.gz > SHA256SUMS.txt"
    if windows_archive not in workflow or linux_archive not in workflow or checksum_line not in workflow:
        raise legacy.ValidationError("Release workflow must package both desktop archives and checksum every raw and packaged output")
    if workflow.index(checksum_line) < max(workflow.index(windows_archive), workflow.index(linux_archive)):
        raise legacy.ValidationError("Release checksums must be written after both desktop archives are created")


def validate_release_documents() -> None:
    current.validate_current_design_documents()
    document = (ROOT / "docs/COMMERCIAL_RELEASE_CANDIDATE.md").read_text(encoding="utf-8")
    if len(document.split()) < 1_200:
        raise legacy.ValidationError("Commercial release documentation is unexpectedly short")
    for heading in [
        "Production assets",
        "Animation",
        "Audio and music",
        "Persistence and migration",
        "Performance architecture",
        "Controller and accessibility",
        "Localization",
        "Balance and long-run QA",
        "Commercial-release boundary",
    ]:
        if heading not in document:
            raise legacy.ValidationError(f"Commercial release document is missing {heading!r}")


for relative in RELEASE_REQUIRED_PATHS:
    if relative not in legacy.REQUIRED_PATHS:
        legacy.REQUIRED_PATHS.append(relative)

legacy.validate_required_paths = validate_release_required_paths
legacy.validate_design_contracts = current.validate_current_design_contracts
legacy.validate_godot_scaffold = validate_release_entrypoint
legacy.validate_design_documents = validate_release_documents


if __name__ == "__main__":
    validators = [
        validate_release_required_paths,
        validate_release_entrypoint,
        validate_release_manifest,
        validate_localization_catalogs,
        validate_release_content_breadth,
        validate_release_assets,
        validate_release_services,
        validate_release_packaging,
        validate_release_documents,
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
        print(f"RELEASE VALIDATION FAILED: {exc}")
        raise SystemExit(1)
    print("Project Ironwright commercial release validation passed.")
