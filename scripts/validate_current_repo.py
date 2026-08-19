#!/usr/bin/env python3
"""Run the repository validators against the current native Godot entrypoint.

The original repository validator predates the playable 3D build and still
expects the retired bootstrap scene. Keep its design, data, link, image, and
manifest checks, while replacing only that obsolete entrypoint assertion.
"""

from __future__ import annotations

from pathlib import Path

import validate_repo as legacy

ROOT = Path(__file__).resolve().parents[1]


def validate_native_godot_entrypoint() -> None:
    project_text = (ROOT / "game/project.godot").read_text(encoding="utf-8")
    expected_scene = 'run/main_scene="res://scenes/main_3d.tscn"'
    if expected_scene not in project_text:
        raise legacy.ValidationError("Godot project must boot scenes/main_3d.tscn")

    scene_text = (ROOT / "game/scenes/main_3d.tscn").read_text(encoding="utf-8")
    expected_script = 'res://scripts/main_world_beautiful_3d.gd'
    if expected_script not in scene_text:
        raise legacy.ValidationError(
            "The native main scene must reference the aesthetic-overhaul world"
        )

    world_text = (ROOT / "game/scripts/main_world_beautiful_3d.gd").read_text(
        encoding="utf-8"
    )
    required_tokens = [
        "extends IronwrightWorld3D",
        "AestheticDirector3D",
        "aesthetic.configure",
    ]
    for token in required_tokens:
        if token not in world_text:
            raise legacy.ValidationError(
                f"Native aesthetic entrypoint is missing required token: {token}"
            )

    hud_scene = (ROOT / "game/scenes/ui/ironwright_hud_3d.tscn").read_text(
        encoding="utf-8"
    )
    if "ironwright_beautiful_hud_3d.gd" not in hud_scene:
        raise legacy.ValidationError("Native HUD must boot the cinematic HUD skin")


legacy.validate_godot_scaffold = validate_native_godot_entrypoint


if __name__ == "__main__":
    raise SystemExit(legacy.main())
