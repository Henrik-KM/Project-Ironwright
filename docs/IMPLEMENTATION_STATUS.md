# Implementation status

## Native Godot 3D — complete end-to-end systemic alpha

The default scene is `game/scenes/main_3d.tscn`. It boots `IronwrightCompleteGameWorld3D`, which preserves the aesthetic, opening UX, progression, and outpost layers while adding the full start-to-victory systemic run.

## Connected game implemented

### Opening survival

- high-angle 3D camera with player, map and physical-group follow modes;
- weak automatic Mechromancer pistol;
- indispensable Bulwark companion;
- world-space wreck marker and route guidance;
- timed manual salvage that disables attack and emits ecological noise;
- timed manual early robot fabrication;
- Scrapper, Warden, Pathfinder, Engineer and Bulwark frames;
- three class-wide levels with rare-core gates;
- macro Defend, Salvage and Expedition focus;
- coordinated physical local salvage and North Ruins expedition.

### Heartforge and autonomy progression

- progression phases from Embers through Sovereignty;
- Heartforge tiers I–V;
- data-driven technology prerequisites, costs and effects;
- manual exposed Heartforge evolution;
- autonomous ordinary machine replacement after Forge Assistance;
- broad tier-based machine composition without a maintained production queue;
- optional Rapid March, Deep Operations, Signal Dampening and Distributed Continuity technologies.

### Autonomous outposts

- fixed physical sites discovered through real excursions;
- Resource, Defence, Scout and Repair roles;
- physical Engineer and escort construction groups;
- shared pace, cohesion and regrouping;
- automatic operation and self-repair;
- physical protected resource hauling;
- organic attacks, destruction and automatic escorted rebuilding;
- tier upgrades through another real construction journey;
- persistent discovery, role, tier, health, destruction and stored Scrap.

### Multi-region world

- seven persistent regions with stable IDs, physical centres, routes and landmarks;
- Heartforge District, North Ruins, West Grid, Flood Market, Cathedral Quarter, Buried Laboratories and Root Cistern;
- discovery, ecological pressure and suppression state;
- region-specific physical salvage after discovery;
- authored procedural visual identity for industrial, commercial, nest, laboratory and endgame districts.

### Long-range operations

- reusable operation data and director;
- role-based team selection without individual orders;
- physical outbound travel, exposed work and physical return;
- formation-relative roles, shared pace, cohesion and regrouping;
- escort response to nearby organisms;
- rewards retained locally until the group returns;
- West Grid survey;
- Vital Membrane recovery;
- Cathedral Brood suppression;
- Genome Prism excavation;
- Root Cistern mapping;
- optional Apex lure.

### Continuous organic ecology

- local noise-driven ecology retained;
- regional ecological capacity and pressure;
- disturbance memory and suppression;
- individual regional spawning rather than wave schedules;
- causal organic migrations from high-pressure districts;
- pressure reduction from important kills and successful suppression;
- Skitterling, Razorhound, Veilstalker, Burrower, Sporecaster, Broodmass and Apex forms;
- final-protocol escalation tied to deliberate player action.

### Endgame and first victory

- unique Vital Membrane, Choral Gland, Genome Prism and Root Map components;
- Severance research and ending;
- Containment research and ending;
- responsive final-protocol interface;
- player-triggered irreversible final crisis;
- sustained Heartforge defence without recurring numbered waves;
- optional Apex lure pressure reduction;
- first-victory end state;
- optional one-use Distributed Continuity recovery.

### Persistence and validation

- original world save;
- progression/outpost extension save;
- complete-alpha save for regions, operations, components, machine society, strategic ecology, endgame, continuity and victory;
- browser and repository contract tests;
- core native tests;
- aesthetic tests;
- first-session UX tests;
- outpost/progression tests;
- accelerated native start-to-victory complete-alpha test.

## Presentation implemented

- readable blue-hour environment and controlled fog;
- warm inhabited Heartforge sanctuary;
- wet streets, lights, windows, signs, clutter, vegetation, embers and smoke;
- procedural character, robot and organic animation;
- combat, interaction, construction and noise feedback;
- responsive forge, evolution, outpost, operation and endgame interfaces;
- physical region landmarks and discovery beacons;
- bounded transient notifications and clear objective hierarchy.

## Browser reference retained

The dependency-free browser implementation remains under `web/` for deterministic simulation regression. Godot is the production runtime.

## Commercial work still remaining

Version 0.6.0 is game-complete in systemic structure, not commercially final.

Remaining production work includes:

- authored production models, rigs, animations, VFX, sound and music;
- substantially more environmental detail and authored encounter spaces;
- true active/reduced-detail simulation for much larger world and entity scale;
- deeper navigation and route recovery;
- more robot families, organic species, technologies, operations and site variants;
- adaptive autonomous Heartforge geometry;
- one transactional versioned save with migration and rotating backups;
- full controller support, input remapping, accessibility and localization;
- performance profiling and optimization on agreed target hardware;
- environmental narrative and run variation;
- 30–100-hour balance and repeated full internal runs;
- external alpha, beta, packaging, store assets and release QA.

The roadmap now refines and expands an actual complete game loop rather than extrapolating from a disconnected prototype.
