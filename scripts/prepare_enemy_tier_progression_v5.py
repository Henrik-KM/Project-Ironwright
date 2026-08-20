#!/usr/bin/env python3
"""Run every idempotent integration, correctness, and type-safety pass."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(script: str) -> None:
    subprocess.run([sys.executable, str(ROOT / "scripts" / script)], cwd=ROOT, check=True)


def main() -> int:
    for script in [
        "integrate_enemy_tier_progression.py",
        "finalize_enemy_tier_progression.py",
        "harden_enemy_tier_runtime.py",
        "final_type_safety_enemy_tiers.py",
        "final_correctness_enemy_tiers.py",
        "final_gdscript_safety_enemy_tiers.py",
    ]:
        run(script)
    print("Prepared final type-safe population-driven enemy-tier progression.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
