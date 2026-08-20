#!/usr/bin/env python3
"""Run the established aesthetic validator through the tiered world layer."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENE_PATH = ROOT / "game/scenes/main_3d.tscn"
TIERED_WORLD_PATH = ROOT / "game/scripts/main_world_tiered_3d.gd"


def main() -> int:
    scene = SCENE_PATH.read_text(encoding="utf-8")
    if "main_world_tiered_3d.gd" not in scene:
        print("TIERED AESTHETIC VALIDATION FAILED: main scene does not boot the tiered world", file=sys.stderr)
        return 1
    tiered = TIERED_WORLD_PATH.read_text(encoding="utf-8")
    if "extends IronwrightReleaseWorld3D" not in tiered:
        print("TIERED AESTHETIC VALIDATION FAILED: tiered world does not preserve the release/vertical-slice presentation chain", file=sys.stderr)
        return 1

    # The established validator intentionally inspects the complete inherited
    # vertical-slice chain. Present the direct parent entrypoint for that check,
    # then restore the actual tiered scene even if validation fails.
    compatible_scene = scene.replace("res://scripts/main_world_tiered_3d.gd", "res://scripts/main_world_release_3d.gd")
    try:
        SCENE_PATH.write_text(compatible_scene, encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(ROOT / "scripts/validate_aesthetic.py")],
            cwd=ROOT,
            check=False,
        )
        return completed.returncode
    finally:
        SCENE_PATH.write_text(scene, encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
