#!/usr/bin/env python3
"""Validate the native aesthetic and pre-alpha presentation integration."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "game/scripts/main_world_beautiful_3d.gd",
    "game/scripts/main_world_full_game_3d.gd",
    "game/scripts/main_world_production_3d.gd",
    "game/scripts/main_world_complete_3d.gd",
    "game/scripts/main_world_prealpha_3d.gd",
    "game/scripts/presentation/aesthetic_director_3d.gd",
    "game/scripts/presentation/sanctuary_decorator_3d.gd",
    "game/scripts/presentation/urban_decorator_3d.gd",
    "game/scripts/presentation/presentation_feedback_3d.gd",
    "game/scripts/presentation/procedural_animator_3d.gd",
    "game/scripts/presentation/objective_guidance_3d.gd",
    "game/scripts/ui/ironwright_beautiful_hud_3d.gd",
    "game/scripts/ui/ironwright_prealpha_hud_3d.gd",
    "game/scripts/ui/operations_command_hud_3d.gd",
    "game/tests/aesthetic_test_runner.gd",
    "game/tests/presentation_and_salvage_escort_test_runner.gd",
    "docs/PRESENTATION_QUALITY_GATE.md",
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
        if "main_world_prealpha_3d.gd" not in main_scene:
            fail("The native entrypoint must boot the pre-alpha presentation-reset world.")

        prealpha = (ROOT / "game/scripts/main_world_prealpha_3d.gd").read_text(encoding="utf-8")
        complete = (ROOT / "game/scripts/main_world_complete_3d.gd").read_text(encoding="utf-8")
        production = (ROOT / "game/scripts/main_world_production_3d.gd").read_text(encoding="utf-8")
        full_game = (ROOT / "game/scripts/main_world_full_game_3d.gd").read_text(encoding="utf-8")
        beautiful = (ROOT / "game/scripts/main_world_beautiful_3d.gd").read_text(encoding="utf-8")
        if "extends IronwrightCompleteGameWorld3D" not in prealpha:
            fail("Presentation-reset world must preserve the complete systemic game.")
        if "_resolve_camera_occlusion" not in prealpha or "set_map_emphasis" not in prealpha:
            fail("Presentation-reset world must handle camera occlusion and tactical/map label separation.")
        if "extends IronwrightProductionWorld3D" not in complete:
            fail("Complete-game world must preserve production UX and guidance.")
        if "extends IronwrightFullGameWorld3D" not in production:
            fail("Production world must preserve the full-game layer.")
        if "extends IronwrightBeautifulWorld3D" not in full_game:
            fail("Full-game world must preserve the aesthetic layer.")
        if "AestheticDirector3D" not in beautiful:
            fail("Beautiful world must still install the aesthetic director.")

        hud_scene = (ROOT / "game/scenes/ui/ironwright_hud_3d.tscn").read_text(encoding="utf-8")
        if "ironwright_prealpha_hud_3d.gd" not in hud_scene:
            fail("The native HUD scene must use the quieter desktop pre-alpha skin.")

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

        guidance = (ROOT / "game/scripts/presentation/objective_guidance_3d.gd").read_text(encoding="utf-8")
        if "marker_label.fixed_size = false" not in guidance:
            fail("Objective labels may not return to giant fixed-size screen billboards.")

        landmark = (ROOT / "game/scripts/world/region_landmark_3d.gd").read_text(encoding="utf-8")
        for token in ["_label.fixed_size = false", "set_map_emphasis", "_label.visible = false"]:
            if token not in landmark:
                fail(f"Region label reset is missing {token}")

        prealpha_hud = (ROOT / "game/scripts/ui/ironwright_prealpha_hud_3d.gd").read_text(encoding="utf-8")
        for token in ["CommandHelpPanel", "help_label.visible = false", "sanctuary_integrity < 0.78"]:
            if token not in prealpha_hud:
                fail(f"Desktop HUD reset is missing {token}")

        operations_hud = (ROOT / "game/scripts/ui/operations_command_hud_3d.gd").read_text(encoding="utf-8")
        for token in ["LONG-RANGE OPERATIONS", "FINAL PROTOCOLS", "persistent world", "apply_safe_layout"]:
            if token not in operations_hud:
                fail(f"Complete-game command presentation is missing {token}")

        quality_gate = (ROOT / "docs/PRESENTATION_QUALITY_GATE.md").read_text(encoding="utf-8").lower()
        for phrase in ["pre-alpha production prototype", "release-readiness rule", "world-label rule", "hud rule"]:
            if phrase not in quality_gate:
                fail(f"Presentation quality gate is missing {phrase!r}")

        print("Project Ironwright aesthetic integration validation passed.")
        return 0
    except Exception as exc:
        print(f"AESTHETIC VALIDATION FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
