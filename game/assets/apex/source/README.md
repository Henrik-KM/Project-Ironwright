# Cistern Apex authored asset

This is an original, dependency-free glTF shell for the late-game Cistern
Apex. It uses layered carapace segments, a crowned sensory head, articulated
jaws, flank roots and membrane fins so the threat reads as a territorial
organic landmark at the tactical camera distance.

The builder is intentionally reproducible and has no external runtime asset
dependency. Gameplay collision, health, ecology, operations and threat pacing
remain owned by `OrganicEnemy3D`; this file supplies presentation and stable
socket names only.

The authored clips carry restrained secondary motion for the Apex jaw pair and
membrane fins: a slow living flex in `Idle`, a stronger flare in `Attack`, a
feeding bite, and a folded withdrawal in `Retreat`.
