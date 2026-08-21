# Project Ironwright — Presentation Quality Gate

**Status:** Canonical pre-alpha production constraint

The current build is not release-ready merely because its systemic gameplay path is complete. The native presentation must be judged against the actual shipped frame, not against internal implementation breadth.

The current visual state is explicitly classified as **pre-alpha production prototype** until the following gates are met.

The shared model kit now has a high-detail baseline: curved primitives use denser radial/ring resolution, machine chassis and representative cutaway facades use original beveled core/rail/cap geometry, and organic shells receive layered surface panels, fasteners and material-break ridges. The opening Mechromancer equipment and full friendly machine roster use authored shells, and Veilstalker, the common Razorhound, Sporecaster, Broodmass, Burrower, Skitterling and the late Cistern Apex now have authored hostile shells. The five later organic families now add a second anatomy layer of wing spars, jaw/gill hardware, resonator ribs and root-route spines, with family-specific motion; the common Skitterling, Burrower, Sporecaster and Broodmass shells now add close-camera caps, flutes, ribs and socket hardware as well. Cathedral Quarter now also carries a secondary landmark layer of entry, tower, rose-window, choir and bell hardware. These are presentation-only details and do not change gameplay collision or introduce a per-unit maintenance burden. It is a production-facing pass, not a claim that final authored meshes have replaced the remaining procedural families.

## Immediate failures identified from the first full-game screenshot review

- Giant screen-fixed world labels can obscure most of the playfield.
- Camera placement can place foreground building geometry directly between the player and camera.
- Primitive silhouettes and broad flat surfaces still communicate greybox/procedural prototype rather than authored world art.
- Permanent control legends and healthy-state status panels create a dense mobile-game dashboard feeling.
- The Mechromancer and machines are visually too small relative to the amount of interface chrome.
- The Heartforge area lacks sufficient authored environmental hierarchy, material variation, damage detail and scene composition.
- Several systems are mechanically complete but lack animation, audio, feedback and visual staging appropriate to their importance.

The initial presentation-reset pass fixed the most disruptive screen-space labels, camera occlusion handling, and HUD clutter. The current Heartforge vertical-slice pass goes further by rebuilding the representative opening composition, silhouettes and environmental detail. The release camera now uses a tighter 16.8/10.0 tactical frame in the Heartforge district so the Mechromancer and companion carry more visual weight beside the Heartforge while retaining a readable escape route. Once the player travels through a sustained remote approach, the camera settles behind the travel direction and widens/higher-frames the district so authored landmarks do not fill the tactical frame or fall behind a fixed world-side view. The square character portrait remains in the asset/HUD contract but is deliberately withheld from the tactical frame after live review found that the anchored layout could expand it into a screen-fixed figure. Neither step by itself is proof of final quality.

The opening route now also has a bounded authored street-dressing pass: a collapsed transit shelter, flooded utility relay and organic breach marker establish civic history, infrastructure failure and ecological escalation beyond the plaza. These are presentation landmarks only; they do not add collision, wave scheduling or a new recurring management task.

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
- high-quality VFX and audio feedback for combat, salvage, fabrication, construction and organic threats; autonomous salvage and active outpost construction now expose restrained physical work signatures at their real targets;
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

The opening lighting/material pass now uses a lower-energy warm Heartforge key,
restrained cool route and facade fills, and a smaller glow/bloom budget. This
preserves the warm/cold hierarchy while keeping wet concrete, puddles and
damaged masonry from flattening into bright pools in the tactical frame. The
pass remains presentation-only and does not alter collision, progression or
autonomy workload.

The opening cast now also keeps the Bulwark protection field as a compact dark
cyan arc with a bounded emitter glow, while the Heartforge plaza pavers use a
rougher, darker wet-concrete family. The companion role stays readable without
letting its protection effect or the forge service surface dominate the frame.
The foreground route markers now use the same amber language promised by the
opening objective, keeping them distinct from cyan Heartforge service hardware.

Automated presence tests only prove the slice exists technically. Actual screenshot/gameplay review decides whether it clears the visual bar.

## Art production sequence

The presentation milestones proceed in this order:

1. camera, world-label and HUD cleanup — implemented, still subject to review;
2. authored Heartforge district composition — vertical slice implemented, with live review now confirming the forge service surface no longer blooms into a dominant white card; full opening composition acceptance is still outstanding;
3. production Mechromancer and Bulwark silhouettes — authored Mechromancer plus an authored Bulwark glTF shell with layered chassis, protection hardware, stable sockets and deterministic runtime animation; the Mechromancer now has a finished asymmetric field-kit pass with communications hardware, and the Bulwark retains its explicit shield-emitter/guard signature with a compact field arc and bounded glow, with further authored refinement expected;
4. one production-quality Warden/Scrapper/Pathfinder family pass — the Warden now has an authored high-definition guardian shell with protected autocannon and heat-exchanger language, the Scrapper now has an authored cargo/tool shell with salvage hardware, Pathfinder now has an authored survey shell with mast/dish/optic language, and Engineer now has an authored construction/tool shell; further refinement remains expected;
5. complete organic enemy families with authored movement and attack language — the full twelve-family roster now has authored glTF shells or the existing production shell contract, stable anatomy sockets and state-driven stalking/attack presentation; the five later-family shells now also carry smoother close-camera geometry and family-specific secondary surface details; live acceptance completed for representative opening frames, with broader hostile-family review still required;
6. cohesive urban modular kit with damaged facades, interiors, street furniture and vegetation — opening route set-piece pass implemented, every remote landmark now has a bounded presentation-only district apron, and West Grid, Riverworks, Cathedral Quarter, Observatory Ridge, Tram Graveyard, Buried Laboratories, Municipal Glasshouse, North Ruins, East Tenements, Flood Market and Root Cistern now have authored landmark shells; Flood Market additionally carries secondary canopy ribs, stall service framing, water-foam bands, crane wheel hardware and organic tendrils so its commercial identity reads beyond the primary ruin masses, Municipal Glasshouse now carries secondary roof ribs, glazing latches, climate actuators, bed service edges, grow-light housings and organic tendrils with restrained environmental motion so its cultivation identity reads beyond the frame and glass planes, East Tenements now carry window framing, balcony braces, laundry lines, roof-tank service hardware, light housings and organic tendrils so its residential identity reads beyond the block masses, North Ruins now carry civic window framing, layered vault-door details, records identity, beacon service hardware, shelf filing rails and organic tendrils so its archive identity reads beyond the primary facade masses, West Grid now carries turbine-hall framing, pressure-tank service hardware, transformer-yard caps and braces, pipe flanges, warning housings and organic tendrils so its industrial identity reads beyond the primary hall masses, Buried Laboratories now carry vessel ports and clamps, transfer-carriage hardware, layered sealed-door framing, warning-panel frames, cable clamps and organic tendrils so its containment identity reads beyond the primary hall masses, Observatory Ridge now carries dish ribs, actuator and feed hardware, cabin and console framing, service-deck posts, cable anchors and survey-light housings so its survey identity reads beyond the primary optics masses, Riverworks now carries pump service panels, impeller and valve hardware, sluice rail and latch details, flow-signal housing, cable clamps and organic tendrils so its waterworks identity reads beyond the primary pump masses, and Tram Graveyard now carries headlamp and window framing, belt rails, bogie plates, roof vents, pantograph hardware, pit rungs, signal housing, cable clamps, rail fasteners and seepage tendrils so its rail identity reads beyond the primary carriage masses, while Root Cistern now carries core plates, claws and veins, pylon collars and braces, capped signal pulses, cable clamps, basin spines and root tendrils so its final-basin identity reads beyond the primary organ masses; broader district breadth still required;
7. final lighting/material pass for the opening district — bounded first pass implemented and live-reviewed; final human acceptance remains outstanding;
8. human visual acceptance of representative opening gameplay;
9. repeat the accepted bar across mid- and late-game regions — representative Riverworks, Cathedral Quarter and Root Cistern live review now passes for the reviewed approach frames; live approach-frame inspection has now been exercised for West Grid, Observatory Ridge, Tram Graveyard, Buried Laboratories, Municipal Glasshouse, North Ruins, East Tenements and Flood Market, with the authored identities reading in the current tactical camera; formal human acceptance and broader remaining region-family review are still required;
10. only then expand asset breadth further.

Breadth must not outrun quality again.

See [`VERTICAL_SLICE_INTELLIGENCE.md`](VERTICAL_SLICE_INTELLIGENCE.md) for the concrete distributed-autonomy, ecology and opening-slice implementation contract.
