#!/usr/bin/env python3
"""Keep legacy organic diagnostics running without restoring movement authority.

The tier brain disables each parent enemy's legacy physics loop. Older behavior
directors may remain active for compatibility and diagnostics, but cannot move a
tier-brained organism. Only legacy population generators are disabled.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    path = ROOT / "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd"
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        'class_name_text in ["EcologyDirector3D", "StrategicEcologyDirector3D", "OrganicBehaviourDirector3D"]\n        or node.has_method(&"_spawn_regional_organism")\n        or node.has_method(&"_assign_organic_behaviour")',
        'class_name_text in ["EcologyDirector3D", "StrategicEcologyDirector3D"]\n        or node.has_method(&"_spawn_regional_organism")',
    )
    path.write_text(text, encoding="utf-8")
    print("Preserved legacy organic diagnostics while retaining tier-brain movement authority.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
