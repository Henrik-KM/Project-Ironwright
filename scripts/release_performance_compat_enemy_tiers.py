#!/usr/bin/env python3
"""Preserve existing release LOD state and tests for tier-brained enemies.

The release performance director may continue toggling the enemy's documented
`reduced_detail` state and visual LOD. EnemyTierBrain disables the legacy parent
physics loop each frame and supplies the actual active/remote movement logic.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

BLOCK = '''            if enemy.has_node("EnemyTierBrain"):\n                if distance <= active_radius:\n                    enemy.set_visual_lod(0)\n                    active_entities += 1\n                elif distance <= medium_radius:\n                    enemy.set_visual_lod(1)\n                    medium_entities += 1\n                else:\n                    enemy.set_visual_lod(2)\n                    reduced_entities += 1\n                enemy.set_physics_process(false)\n                continue\n'''


def main() -> int:
    path = ROOT / "game/scripts/release/performance_director_3d.gd"
    if not path.is_file():
        return 0
    text = path.read_text(encoding="utf-8")
    if BLOCK in text:
        path.write_text(text.replace(BLOCK, ""), encoding="utf-8")
    print("Preserved release reduced-detail state while tier brains retain movement authority.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
