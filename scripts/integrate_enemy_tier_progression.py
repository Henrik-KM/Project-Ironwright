#!/usr/bin/env python3
"""Integrate the enemy-tier runtime into the current Project Ironwright branch.

The repository has several stacked native world layers. This script deliberately
patches only stable integration surfaces: the main scene, validation command,
CI test list, and canonical design contracts. It is idempotent.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch_main_scene() -> None:
    path = ROOT / "game/scenes/main_3d.tscn"
    text = path.read_text(encoding="utf-8")
    script_path = "res://scripts/systems/enemy_tier_progression_bootstrap_3d.gd"
    if script_path in text and "EnemyTierProgressionBootstrap" in text:
        return
    match = re.search(r"\[gd_scene load_steps=(\d+) format=3\]", text)
    if not match:
        raise RuntimeError("Could not find main scene header")
    count = int(match.group(1)) + 1
    text = text[: match.start()] + f"[gd_scene load_steps={count} format=3]" + text[match.end() :]
    resource_id = "99_enemy_tiers"
    first_node = text.find("\n[node ")
    if first_node < 0:
        raise RuntimeError("Could not find main scene root node")
    resource = f'\n[ext_resource type="Script" path="{script_path}" id="{resource_id}"]\n'
    text = text[:first_node] + resource + text[first_node:]
    text = text.rstrip() + (
        "\n\n[node name=\"EnemyTierProgressionBootstrap\" type=\"Node\" parent=\".\"]\n"
        f"script = ExtResource(\"{resource_id}\")\n"
    )
    path.write_text(text, encoding="utf-8")


def patch_package() -> None:
    path = ROOT / "package.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    scripts = data.setdefault("scripts", {})
    validate = str(scripts.get("validate", ""))
    command = "python3 scripts/validate_enemy_tier_progression.py"
    if command not in validate:
        validate = f"{validate} && {command}" if validate else command
    scripts["validate"] = validate
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def patch_ci() -> None:
    path = ROOT / ".github/workflows/validate.yml"
    text = path.read_text(encoding="utf-8")
    if "enemy_tier_progression_test_runner.gd" in text:
        return
    step = (
        "\n      - name: Run population-driven enemy tier progression tests\n"
        "        run: godot --headless --path game --script res://tests/enemy_tier_progression_test_runner.gd\n"
    )
    text = text.rstrip() + step
    path.write_text(text + "\n", encoding="utf-8")


def append_section(relative: str, marker: str, section: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if marker.lower() in text.lower():
        return
    path.write_text(text.rstrip() + "\n\n" + section.strip() + "\n", encoding="utf-8")


def patch_contracts() -> None:
    append_section(
        "AGENTS.md",
        "population-driven ecological escalation",
        """
## 20. Population-driven ecological escalation

Enemy difficulty is population-driven rather than unlocked by a recurring timer.
Each organic tier has a population cap and replenishment rate. When a non-final
tier is saturated, its current replenishment allocation moves to the next tier
at 10:1 and becomes zero in the source tier. Process saturation from high tiers
downward so one update cannot instantly cascade the same pressure through the
whole ladder.

Tier I is numerous, slow and behaviorally primitive: roam, chase visible prey,
and attack. Higher tiers add territorial defense, patrol, scouting, hunting,
information sharing, route observation, infrastructure targeting, retreat, and
regional Apex behavior. Tier and species remain separate data.

All replenishment materializes through physical living nests. Killing organisms
creates population headroom; clearing nests removes long-term rate sources;
progression and operations may increase or suppress rates. Noise changes
attention, not permanent global reproduction. Mature machine society handles
routine Tier-I thinning without individual robot orders.

Read `docs/ENEMY_TIER_PROGRESSION.md` before changing enemy spawning, nests,
regional ecology, operation rewards, or autonomous suppression.
""",
    )
    append_section(
        "docs/DESIGN_LOCKS.md",
        "saturated tier",
        """
## 24. Ecological escalation is population-driven

Each enemy tier has a living population cap and a replenishment rate. A
saturated tier transfers its current replenishment upward at **10:1**, then has
zero replenishment of its own. Saturation is evaluated from high tiers downward.
There is no recurring wave timer hidden behind this system.

Killing organisms reduces population and creates headroom. Destroying physical
nests removes long-term replenishment sources wherever those sources have
evolved. Major machine progress may increase future reproduction; suppressive
world actions may reduce it. Tier I is slow, numerous and primitive. Higher
tiers gain qualitatively smarter behavior, not merely more health and damage.
Routine low-tier suppression must become autonomous rather than a personal
trash-mob chore.
""",
    )
    append_section(
        "docs/ENEMY_ECOLOGY.md",
        "enemy tier progression",
        """
## Enemy tier progression

The quantitative population, replenishment, nest-source and intelligence ladder
is specified in [`ENEMY_TIER_PROGRESSION.md`](ENEMY_TIER_PROGRESSION.md). This
system is the authoritative source for how organisms are replenished and how
population saturation evolves ecological pressure upward. Existing regional
pressure and noise systems describe attention and local conditions; they may
not independently create an unbounded or scheduled enemy population.
""",
    )


def patch_readme() -> None:
    append_section(
        "README.md",
        "Population-driven enemy escalation",
        """
## Population-driven enemy escalation

Organic difficulty now emerges from the physical world. Each tier has a living
unit cap and replenishment rate. Saturating a tier converts its replenishment
into the next tier at 10:1; killing weak organisms creates headroom and delays
that evolution, while clearing nests removes long-term reproductive sources.
Technology and deep operations can carry an ecological cost.

Tier-I organisms are numerous, slow and primitive wanderers. Territorial,
hunting, strategic, and Apex tiers progressively patrol nests, scout routes,
share detections, select vulnerable machines, attack infrastructure, retreat,
and constrain whole regions. All births originate at physical nests. After the
machine society matures, Wardens autonomously suppress dense feral clusters so
population control does not become repetitive player work.

Qualitative ecology intelligence appears on the command map. Exact rates remain
debug and balancing data. See [`docs/ENEMY_TIER_PROGRESSION.md`](docs/ENEMY_TIER_PROGRESSION.md).
""",
    )


def patch_changelog() -> None:
    path = ROOT / "CHANGELOG.md"
    text = path.read_text(encoding="utf-8")
    marker = "Population-driven enemy escalation"
    if marker.lower() in text.lower():
        return
    entry = """## Pre-alpha ecology progression

### Population-driven enemy escalation

- Added five organic difficulty tiers with independent population caps and replenishment rates.
- Added exact 10:1 upward rate transfer when a non-final tier reaches its cap.
- Added continuously growing Tier-I background pressure and bounded fractional spawn credit.
- Added eight physical reproductive nests with maturity, tier support, health, suppression, destruction, persistence, and slow causal regrowth.
- Added dynamic ecological costs and suppression effects for Heartforge evolution and long-range operations.
- Added primitive Tier-I roaming, territorial Tier-II patrols, Tier-III scouting and hunting, Tier-IV strategic targeting, and Tier-V regional Apex behavior.
- Added pack information sharing, last-known prey memory, retreat, route ambush, infrastructure targeting, and lower-tier Apex influence.
- Added qualitative command-map ecology intelligence.
- Added autonomous Warden suppression patrols after Heartforge Tier III.
- Added checksummed sidecar persistence and deterministic native/static tests.

"""
    if text.startswith("# Changelog"):
        insertion = text.find("\n", len("# Changelog")) + 1
        text = text[:insertion] + "\n" + entry + text[insertion:]
    else:
        text = entry + text
    path.write_text(text, encoding="utf-8")


def main() -> int:
    patch_main_scene()
    patch_package()
    patch_ci()
    patch_contracts()
    patch_readme()
    patch_changelog()
    print("Integrated population-driven enemy tier progression.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
