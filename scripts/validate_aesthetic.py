#!/usr/bin/env python3
"""Validate the native aesthetic-overhaul integration without requiring Godot."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "game/scripts/main_world_beautiful_3d.gd",
    "game/scripts/presentation/aesthetic_director_3d.gd",
    "game/scripts/presentation/sanctuary_decorator_3d.gd",
    "game/scripts/presentation/urban_decorator_3d.gd",
    "game/scripts/presentation/presentation_feedback_3d.gd",
    "game/scripts/presentation/procedural_animator_3d.gd",
    "game/scripts/ui/ironwright_beautiful_hud_3d.gd",
    "game/tests/aesthetic_test_runner.gd",
]


def fail(message: str) -> None:
    raise RuntimeError(message)


def main() -> int:
    try:
        for relative in REQUIRED:
            path = ROOT / relative
            if not path.is_file() or path.stat().st_size < 100:
                fail(f"Missing or unexpectedly empty aesthetic file: {relative}")

        main_scene = (ROOT / "game/scenes/main_3d.tscn").read_text(encoding="utf-8")
        if "main_world_beautiful_3d.gd" not in main_scene:
            fail("The native entrypoint does not use the aesthetic world.")

        hud_scene = (ROOT / "game/scenes/ui/ironwright_hud_3d.tscn").read_text(encoding="utf-8")
        if "ironwright_beautiful_hud_3d.gd" not in hud_scene:
            fail("The native HUD scene does not use the aesthetic skin.")

        presentation_sources = "\n".join(
            (ROOT / relative).read_text(encoding="utf-8")
            for relative in [
                "game/scripts/presentation/aesthetic_director_3d.gd",
                "game/scripts/presentation/sanctuary_decorator_3d.gd",
                "game/scripts/presentation/urban_decorator_3d.gd",
                "game/scripts/presentation/presentation_feedback_3d.gd",
            ]
        )
        required_tokens = [
            "ambient_light_energy = 0.56",
            "fog_density = 0.0085",
            "CozyHeartforgeCamp",
            "UrbanAestheticPass",
            "HeartforgeEmbers",
            "ProceduralAnimator3D",
            "_spawn_noise_ring",
            "_add_actor_details",
        ]
        for token in required_tokens:
            if token not in presentation_sources:
                fail(f"Presentation layer is missing required behaviour: {token}")

        animator = (ROOT / "game/scripts/presentation/procedural_animator_3d.gd").read_text(encoding="utf-8")
        for token in ["_animate_mechromancer", "_animate_robot", "_animate_organic", "recoil", "hit_impulse"]:
            if token not in animator:
                fail(f"Procedural animator is missing {token}")

        hud = (ROOT / "game/scripts/ui/ironwright_beautiful_hud_3d.gd").read_text(encoding="utf-8")
        for token in ["AtmosphericVignette", "SanctuaryBadge", "flash_damage"]:
            if token not in hud:
                fail(f"Beautiful HUD is missing {token}")

        print("Project Ironwright aesthetic integration validation passed.")
        return 0
    except Exception as exc:
        print(f"AESTHETIC VALIDATION FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
