# Implementation status

## Native Godot 3D — primary playable vertical slice

The default Godot scene is `game/scenes/main_3d.tscn`. It implements a connected First Light arc in a persistent urban 3D district.

### Gameplay implemented

- high-angle 3D camera with player, map and machine-group follow modes;
- weak automatic Mechromancer pistol;
- strong opening Bulwark companion and explicit dependence on it;
- timed manual salvage that disables movement/fire and emits ecological noise;
- timed manual robot fabrication at the Heartforge;
- Scrapper, Warden, Pathfinder and Bulwark runtime models;
- three robot levels per class, with rare-core gates at level 3;
- global Defend, Salvage and Expedition focus choices;
- autonomous salvage groups that physically travel, work, return and deposit cargo;
- coordinated formation movement with slowing and regrouping;
- physical North Ruins expedition and rare Cognition Core recovery;
- persistent organic enemies reacting to noise and nest pressure;
- single ordinary resource, no scheduled waves, no territory layer and no hostile robots;
- HUD, forge interface, objective progression, defeat, victory and save/load;
- headless Godot tests for progression, cohesion, automatic firing, channel lockout and scene boot.

### Presentation implemented

- readable blue-hour environment, ACES tonemapping and controlled fog;
- cool exterior light contrasted with a warm inhabited Heartforge sanctuary;
- wet streets, puddles, practical lights, windows, signage, clutter and vegetation;
- embers, smoke and atmospheric motes;
- stronger player, robot and enemy silhouettes;
- procedural actor movement, recoil, work poses and hit response;
- muzzle flashes, impacts, sparks, death effects, visible noise pulses and camera response;
- cinematic HUD skin, vignette, damage flash and sanctuary-integrity status;
- static and native aesthetic acceptance tests.

## Browser reference — retained

The dependency-free browser implementation remains under `web/`. It is useful for quick deterministic simulation iteration and comparison, but the Godot project is the production runtime direction.

## Not yet production-complete

The current models are original procedural low-poly assets rather than final authored Blender/glTF models. Final rigged animation, authored sound design, navigation for a larger world, save migration, accessibility, performance at large robot counts, autonomous outposts and the complete long-run sandbox remain production work.
