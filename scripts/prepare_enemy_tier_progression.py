#!/usr/bin/env python3
"""Run every idempotent preparation step for enemy tier progression."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(script: str) -> None:
    subprocess.run([sys.executable, str(ROOT / "scripts" / script)], cwd=ROOT, check=True)


def main() -> int:
    run("integrate_enemy_tier_progression.py")
    run("finalize_enemy_tier_progression.py")
    run("harden_enemy_tier_runtime.py")
    print("Prepared complete enemy tier progression integration.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
