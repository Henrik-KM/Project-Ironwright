# Implementation status

## Native Godot 3D — full-game production foundation

The default Godot scene is `game/scenes/main_3d.tscn`. It now boots `IronwrightProductionWorld3D`, preserving the aesthetic and opening-survival layers while adding the first persistent full-game systems.

## Gameplay implemented

### Opening survival

- high-angle 3D camera with player, map and machine-group follow modes;
- weak automatic Mechromancer pistol;
- strong opening Bulwark companion and explicit dependence on it;
- timed manual salvage that disables movement/fire and emits ecological noise;
- timed manual robot fabrication at the Heartforge;
- Scrapper, Warden, Pathfinder, Engineer and Bulwark runtime models;
- three robot levels per class, with rare-core gates at level 3;
- global Defend, Salvage and Expedition focus choices;
- coordinated physical salvage and North Ruins operations;
- persistent organic enemies reacting to noise and nest pressure.

### Full-game progression

- machine-readable progression phases from Embers through Sovereignty;
- technology registry with prerequisites, Scrap/core costs and effects;
- persistent unlocked technologies and Heartforge tier;
- Task Memory, Group Coordination, Heartforge Tier II and Field Engineering path;
- strategic evolution interface that excludes routine unit control;
- manual exposed Heartforge evolution at the forge;
- Engineer fabrication gated behind tier 2.

### Autonomous outposts

- fixed physical sites loaded from authored data;
- sites hidden until discovered through a real expedition;
- Resource, Defence, Scout and Repair roles;
- physical Engineer and escort construction groups;
- shared pace, formation cohesion and regrouping;
- construction only after group arrival;
- physical return after work;
- autonomous operation and self-repair using Scrap;
- physical protected hauling from forward storage;
- organic enemies able to attack outposts;
- destruction and automatic escorted rebuilding;
- player-authorized tier upgrades through another physical operation;
- save state for discovery, role, tier, health, destruction and stored Scrap.

### Persistence and tests

- original native world save retained;
- full-game extension save for progression and outposts;
- repository/browser contract validation;
- core native gameplay tests;
- native aesthetic acceptance tests;
- native full-game tests for progression, site discovery, construction travel, repair, hauling, destruction, rebuild and persistence.

## Presentation implemented

- readable blue-hour environment, ACES tonemapping and controlled fog;
- cool exterior light contrasted with a warm inhabited Heartforge sanctuary;
- wet streets, puddles, practical lights, windows, signage, clutter and vegetation;
- embers, smoke and atmospheric motes;
- stronger player, robot and enemy silhouettes;
- procedural actor movement, recoil, work poses and hit response;
- muzzle flashes, impacts, sparks, death effects, visible noise pulses and camera response;
- cinematic HUD skin, vignette, damage flash and sanctuary-integrity status;
- strategic interface consistent with the established presentation.

## Browser reference — retained

The dependency-free browser implementation remains under `web/`. It is useful for deterministic simulation iteration and regression tests, but Godot is the production runtime.

## Production roadmap

The end-to-end sequence through persistent regions, reduced-detail remote simulation, deeper autonomy, adaptive Heartforge construction, full ecology, midgame, late machine war, endgame, production assets, alpha, beta and launch is maintained in `docs/FULL_GAME_ROADMAP.md`.

## Not yet production-complete

Version 0.4.0 starts full-game implementation; it is not the finished 30–100-hour product.

Major remaining work includes:

- a larger multi-region persistent town;
- active/reduced-detail simulation transitions;
- deep route planning and navigation;
- broader ecology and species content;
- more robot families and technologies;
- adaptive autonomous Heartforge construction;
- late-game doctrines and simultaneous operations;
- complete endgame and first-victory path;
- release-grade transactional saves and migration;
- authored production models, rigs, animation and audio;
- accessibility, localization, controller support and performance at target scale;
- long-run balance and external playtesting.
