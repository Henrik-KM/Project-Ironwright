# Implementation status

## Native Godot 3D — implemented vertical slice

The default Godot scene is now `game/scenes/main_3d.tscn`. It implements a complete First Light arc in a persistent urban 3D district.

Implemented:

- fixed high-angle 3D camera with player, map, and machine-group follow modes;
- oppressive low-light city, fog, ruined buildings, roads, wrecks, and limited practical lighting;
- weak automatic Mechromancer pistol;
- strong opening Bulwark companion and explicit dependence on it;
- timed manual salvage that disables movement/fire and emits ecological noise;
- timed manual robot fabrication at the Heartforge;
- Scrapper, Warden, Pathfinder, and Bulwark runtime 3D models;
- three robot levels per class, with rare-core gates at level 3;
- global Defend, Salvage, and Expedition focus choices;
- autonomous salvage groups that physically travel, work, return, and deposit cargo;
- coordinated formation movement with slowing and regrouping;
- physical North Ruins expedition and rare Cognition Core recovery;
- persistent organic enemies reacting to noise and nest pressure;
- single ordinary resource, no scheduled waves, no territory layer, and no hostile robots;
- minimal HUD, forge interface, objective progression, defeat, victory, and save/load;
- headless Godot tests for progression, formation cohesion, automatic firing, channel lockout, and scene boot.

## Browser reference — retained

The dependency-free browser implementation remains under `web/`. It is still useful for quick simulation iteration and comparison, but the Godot 3D project is now the primary runtime direction.

## Not yet production-complete

The current models are original procedural low-poly assets rather than final authored models. Animation, audio, navigation, VFX, save migration, accessibility, performance at large robot counts, and the complete long-run sandbox content remain production work. The vertical slice is intended to validate the new survival dependency and machine-autonomy loop before expensive asset production.
