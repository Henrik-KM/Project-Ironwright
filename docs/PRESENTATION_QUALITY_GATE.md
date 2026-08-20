# Project Ironwright — Presentation Quality Gate

**Status:** Canonical pre-alpha production constraint

The current build is not release-ready merely because its systemic gameplay path is complete. The native presentation must be judged against the actual shipped frame, not against internal implementation breadth.

The current visual state is explicitly classified as **pre-alpha production prototype** until the following gates are met.

The shared model kit now has a high-detail baseline: curved primitives use denser radial/ring resolution, while machine chassis and organic shells receive layered surface panels, fasteners and material-break ridges. This improves tactical readability and material separation across the cast without changing gameplay collision or introducing a per-unit maintenance burden. It is a production-facing procedural quality pass, not a claim that final authored meshes have replaced the remaining procedural families.

## Immediate failures identified from the first full-game screenshot review

- Giant screen-fixed world labels can obscure most of the playfield.
- Camera placement can place foreground building geometry directly between the player and camera.
- Primitive silhouettes and broad flat surfaces still communicate greybox/procedural prototype rather than authored world art.
- Permanent control legends and healthy-state status panels create a dense mobile-game dashboard feeling.
- The Mechromancer and machines are visually too small relative to the amount of interface chrome.
- The Heartforge area lacks sufficient authored environmental hierarchy, material variation, damage detail and scene composition.
- Several systems are mechanically complete but lack animation, audio, feedback and visual staging appropriate to their importance.

The initial presentation-reset pass fixed the most disruptive screen-space labels, camera occlusion handling, and HUD clutter. The current Heartforge vertical-slice pass goes further by rebuilding the representative opening composition, silhouettes and environmental detail. Neither step by itself is proof of final quality.

## Release-readiness rule

No agent may describe Project Ironwright as commercially finished, release-ready, or a release candidate based solely on:

- a complete start-to-victory loop;
- passing automated tests;
- procedural asset generation;
- exportable binaries;
- broad system count;
- placeholder textures, music, animation or UI polish;
- one improved vertical slice without representative human review.

A release-quality claim requires explicit human visual approval of representative screenshots and gameplay capture in addition to technical validation.

## Required visual bar

Before release-candidate status, representative opening, mid-game and late-game captures must show:

- authored composition with no dominant debug/prototype labels;
- unobstructed tactical camera framing;
- coherent scale and silhouettes for player, robots, enemies and structures;
- every friendly robot archetype has a distinct readable tool, sensor or cargo
  silhouette at tactical-camera distance;
- environment art that reads as an actual ruined urban place rather than isolated primitives;
- strong material separation and lighting hierarchy;
- animation that communicates weight, function and threat;
- restrained desktop HUD with world visibility taking visual priority;
- clear but non-intrusive objective and interaction communication;
- high-quality VFX and audio feedback for combat, salvage, fabrication, construction and organic threats;
- consistent art direction from grounded early game toward more futuristic late-game machines.

## Camera rule

The tactical camera must never accept a nominal isometric position when a solid building blocks the target. It must probe alternate higher/closer positions and preserve line of sight to the current focus.

The representative Heartforge slice may lead the subject slightly in the direction of movement and pull higher under nearby threat so the player can read the autonomous defensive envelope. Camera spectacle must never hide tactical information.

## World-label rule

World labels are annotations, not billboards. District names belong primarily to command-map mode. Objective labels use physical world scale and may not maintain a giant fixed screen size while the camera changes distance.

## HUD rule

Permanent interface chrome must be minimized. Healthy-state status banners and duplicate control legends should not occupy the tactical playfield. The player should see the world first and interface second.

Reducing HUD dominance may not reduce essential reserve legibility or violate the established bounded-notification and constrained-resolution acceptance tests.

## Autonomy presentation rule

Robot intelligence must be visible through coordinated behaviour rather than explained only in text.

During Salvage focus:

- Scrappers must distribute across useful physical wrecks when enough sites exist;
- each Scrapper chooses and re-evaluates its own assignment;
- machines may not dog-pile one wreck merely because Salvage focus is active;
- cargo returns physically and independently;
- Wardens distribute across the active salvage cells and the Mechromancer;
- the Bulwark remains the guaranteed close personal interceptor;
- Pathfinders screen the wider salvage network when available.

The player observes this behaviour but does not configure it per robot.

## Organic-behaviour rule

Organic enemies may not exist only as stationary targets waiting for a detection trigger.

Outside combat they need a readable ecological purpose. Depending on species and world state they may:

- guard a nest;
- patrol territory;
- roam between local interests;
- scout outward and return;
- hunt likely prey or last-known positions;
- forage;
- investigate noise;
- coordinate or share information with nearby pack members.

These behaviours must happen in the persistent physical world and remain tied to territory, nests, noise and pressure. They are not decorative animations layered over a wave scheduler.

## Heartforge vertical-slice rule

The Heartforge district is the first representative art target. It should establish the visual grammar before that grammar is copied across the entire town.

The current slice must include:

- broken readable facades instead of nearby opaque building cubes;
- recognisable urban identities and human-scale structural detail;
- a materially varied municipal plaza;
- improvised sanctuary construction with an open route outward;
- Heartforge maintenance infrastructure and environmental storytelling;
- visible organic nest landmarks;
- weather and atmospheric motion;
- stronger Mechromancer, Bulwark and machine silhouettes;
- a restrained warm/cold lighting hierarchy;
- quieter desktop HUD composition.

Automated presence tests only prove the slice exists technically. Actual screenshot/gameplay review decides whether it clears the visual bar.

## Art production sequence

The presentation milestones proceed in this order:

1. camera, world-label and HUD cleanup — implemented, still subject to review;
2. authored Heartforge district composition — vertical slice implemented, awaiting visual review;
3. production Mechromancer and Bulwark silhouettes — authored Mechromancer plus procedural vertical-slice pass, with shared high-detail surface treatment implemented; further authored refinement expected;
4. one production-quality Warden/Scrapper/Pathfinder family pass — procedural vertical-slice pass with shared high-detail machine panels implemented, further authored refinement expected;
5. one complete organic enemy family with authored movement and attack language — Veilstalker layered silhouette and state-driven stalking/attack presentation implemented, still awaiting human visual acceptance;
6. cohesive urban modular kit with damaged facades, interiors, street furniture and vegetation;
7. final lighting/material pass for the opening district;
8. human visual acceptance of representative opening gameplay;
9. repeat the accepted bar across mid- and late-game regions;
10. only then expand asset breadth further.

Breadth must not outrun quality again.

See [`VERTICAL_SLICE_INTELLIGENCE.md`](VERTICAL_SLICE_INTELLIGENCE.md) for the concrete distributed-autonomy, ecology and opening-slice implementation contract.
