# Project Ironwright — Presentation Quality Gate

**Status:** Canonical pre-alpha production constraint

The current build is not release-ready merely because its systemic gameplay path is complete. The native presentation must be judged against the actual shipped frame, not against internal implementation breadth.

The current visual state is explicitly classified as **pre-alpha production prototype** until the following gates are met.

## Immediate failures identified from the first full-game screenshot review

- Giant screen-fixed world labels can obscure most of the playfield.
- Camera placement can place foreground building geometry directly between the player and camera.
- Primitive silhouettes and broad flat surfaces still communicate greybox/procedural prototype rather than authored world art.
- Permanent control legends and healthy-state status panels create a dense mobile-game dashboard feeling.
- The Mechromancer and machines are visually too small relative to the amount of interface chrome.
- The Heartforge area lacks sufficient authored environmental hierarchy, material variation, damage detail and scene composition.
- Several systems are mechanically complete but lack animation, audio, feedback and visual staging appropriate to their importance.

The branch that introduced this document fixes the most disruptive screen-space labels, camera occlusion handling, and HUD clutter. Those are corrective steps, not proof of final quality.

## Release-readiness rule

No agent may describe Project Ironwright as commercially finished, release-ready, or a release candidate based solely on:

- a complete start-to-victory loop;
- passing automated tests;
- procedural asset generation;
- exportable binaries;
- broad system count;
- placeholder textures, music, animation or UI polish.

A release-quality claim requires explicit human visual approval of representative screenshots and gameplay capture in addition to technical validation.

## Required visual bar

Before release-candidate status, representative opening, mid-game and late-game captures must show:

- authored composition with no dominant debug/prototype labels;
- unobstructed tactical camera framing;
- coherent scale and silhouettes for player, robots, enemies and structures;
- environment art that reads as an actual ruined urban place rather than isolated primitives;
- strong material separation and lighting hierarchy;
- animation that communicates weight, function and threat;
- restrained desktop HUD with world visibility taking visual priority;
- clear but non-intrusive objective and interaction communication;
- high-quality VFX and audio feedback for combat, salvage, fabrication, construction and organic threats;
- consistent art direction from grounded early game toward more futuristic late-game machines.

## Camera rule

The tactical camera must never accept a nominal isometric position when a solid building blocks the target. It must probe alternate higher/closer positions and preserve line of sight to the current focus.

## World-label rule

World labels are annotations, not billboards. District names belong primarily to command-map mode. Objective labels use physical world scale and may not maintain a giant fixed screen size while the camera changes distance.

## HUD rule

Permanent interface chrome must be minimized. Healthy-state status banners and duplicate control legends should not occupy the tactical playfield. The player should see the world first and interface second.

## Autonomy presentation rule

Robot intelligence must be visible through coordinated behaviour rather than explained only in text. During Salvage focus, Wardens must distribute themselves across the salvage core and the Mechromancer instead of clustering at one point or remaining unused at the Heartforge.

## Art production sequence

The next presentation milestones should proceed in this order:

1. camera, world-label and HUD cleanup;
2. authored Heartforge district composition;
3. production Mechromancer and Bulwark silhouettes;
4. one production-quality Warden/Scrapper/Pathfinder family pass;
5. one complete organic enemy family with authored movement and attack language;
6. cohesive urban modular kit with damaged facades, interiors, street furniture and vegetation;
7. final lighting/material pass for the opening district;
8. repeat the same bar across mid- and late-game regions;
9. only then expand asset breadth further.

Breadth must not outrun quality again.
