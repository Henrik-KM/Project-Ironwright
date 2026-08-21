# Project Ironwright — Full-Game Roadmap

**Status:** Active production plan  
**Authority:** The current Project Ironwright conversation with Henrik is authoritative.  
**Product target:** A polished, single-player, long-form survival-strategy sandbox in Godot 4.7.1, built around one vulnerable Mechromancer, one run-critical Heartforge, an increasingly autonomous machine population, bounded autonomous outposts, and a persistent organic world.

This roadmap started from the playable native 3D slice. The repository now
contains a complete start-to-victory systemic run and a 1.0.0 release-candidate
shell; this document remains the plan for closing the remaining content,
production-art, scale, balance and external-release gates rather than a claim
that those gates have already happened.

## 1. Definition of the finished game

A finished Project Ironwright run should support roughly 30–100 hours of play across many sessions. The player begins in a ruined urban district with a damaged Heartforge, a weak automatic pistol, and one indispensable companion robot. Early manual salvage and fabrication are dangerous commitments that emit noise and disable attack.

Over the run, the player makes a limited number of high-consequence choices about:

- the Mechromancer’s survival, command, and intervention abilities;
- robot families and class-wide upgrades;
- machine intelligence and autonomy;
- Heartforge evolution;
- discovered outpost sites and strategic purposes;
- doctrines governing risk, cohesion, retreat, sacrifice, and recovery;
- major excursions and irreversible world interactions;
- when and how to initiate the endgame.

Machines gradually assume routine work. They salvage, defend, repair, scout, fabricate, escort, construct, haul, rebuild, and conduct expeditions. The player does not select individual robots for routine orders or maintain an RTS economy.

The hostile world is organic. Pressure is continuous and causal rather than organized around recurring timed waves. Large attacks occur because the player disturbed a colony, produced sustained noise, activated a detectable technology, built in a dangerous location, displaced a predator, or initiated the final process.

The emotional arc is:

> one frightened inventor and one protector in a warm pool of light → a compact machine refuge barely holding → coordinated autonomous expeditions and support posts → a self-maintaining machine society defending the same vulnerable home against a world-scale biological threat.

## 2. Production principles

### 2.1 Vertical completeness before breadth

Every milestone must produce a coherent playable arc. Do not add ten robot classes before one complete robot family has animation, audio, progression, save support, autonomous behaviour, UI explanation, and balance data.

### 2.2 Systems earn content

Content production should accelerate only after the relevant systems are stable. Enemy art should not outpace ecology behaviour. New outpost visuals should not outpace save/load and automatic rebuilding. New biomes should not outpace world streaming and navigation.

### 2.3 Autonomy is the main progression

Each major progression stage must remove work, not merely add capability. Late-game scope is achieved by broader machine action, not by asking the player to operate more menus.

### 2.4 One world, physically simulated

Robots, creatures, outposts, wrecks, objectives, and expeditions retain physical positions. Reduced-detail simulation is an optimisation of the same state, not a detached mission system.

### 2.5 Readable pressure

The game should often feel close to collapse, but the cause of pressure and the available responses must remain legible. Unexplained failure is not difficulty.

## 3. Current baseline

The repository currently demonstrates the complete game-shaped systemic arc:

- a native Godot 3D release entrypoint with a readable blue-hour ruined town;
- a warm, inhabited Heartforge and the weak Mechromancer/Bulwark opening;
- loud manual salvage and fabrication followed by autonomous machine society;
- class-wide robot progression, physical salvage, expeditions and outposts;
- persistent multi-region ecology, causal pressure and reduced-detail continuity;
- both canonical sustained endgame protocols, first victory and explicit
  post-victory sanctuary continuation;
- transactional unified saves, backups, legacy migration and active remote-work
  restoration;
- controller/accessibility/localization release shell, original audio feedback,
  release assets and Windows/Linux export configuration;
- browser, repository, Godot import, native gameplay, persistence, aesthetic,
  release and complete-run validation.

The current baseline is therefore a complete systemic alpha and commercial
release candidate, not a final retail content or external-QA claim. Remaining
work is tracked in the release boundary and the milestones below.

## 4. Milestone map

## Milestone 0 — Canonical full-game foundation

**Goal:** Replace prototype assumptions with production contracts and data-driven run structure.

Deliverables:

- authoritative conversation rule in `AGENTS.md`;
- current design locks including bounded autonomous outposts;
- this end-to-end roadmap;
- machine-readable full-game manifest;
- progression phases and technology definitions;
- stable content identifiers;
- production save schema with extension points;
- CI checks for the new contracts.

Exit gate:

- all old blanket outpost prohibitions are removed;
- the main scene boots the full-game foundation layer;
- progression and new persistent systems survive save/load;
- existing opening gameplay remains intact.

## Milestone 1 — First two hours: fear, dependence, and proof of autonomy

**Goal:** Turn the current opening into a polished first-session experience.

Player arc:

1. wake beside a damaged Heartforge;
2. learn that the pistol cannot carry sustained combat;
3. depend on the Bulwark;
4. risk one or more loud salvage operations;
5. manually fabricate the first Scrapper;
6. delegate routine local salvage;
7. manually fabricate a Warden and Pathfinder;
8. authorize the North Ruins expedition;
9. recover the first Cognition Core;
10. choose the first major Heartforge evolution.

Systems:

- onboarding through world events rather than a large tutorial overlay;
- robust interaction prompts and input remapping;
- authored opening encounter pacing;
- companion rescue and recovery rules;
- first collapse analysis;
- accessibility options for contrast, camera movement, text size, automatic targeting, and hold/toggle interactions;
- checkpoint-safe save behaviour.

Content target:

- one dense starting district;
- 4–6 organic enemy behaviours;
- 4 robot families including Engineer;
- 8–12 early discoveries;
- 6–10 meaningful opening technologies;
- 2–3 causal major incidents.

Exit gate:

- new players understand the core loop without external instructions;
- the first delegated salvage feels like a meaningful reduction in work;
- the companion is emotionally and mechanically indispensable;
- the opening is frightening but not visually unreadable or unfair.

## Milestone 2 — Heartforge tier 2 and autonomous outposts

**Goal:** Prove bounded remote support without creating an empire layer.

Systems:

- fixed discoverable outpost sites;
- Engineer robot family;
- physical escorted construction and upgrade operations;
- Resource, Defence, Scout, and Repair outpost purposes;
- automatic operation, repair, and rebuilding;
- physical resource hauling;
- organic enemies able to discover and attack outposts;
- outpost status summarized through exceptions rather than constant alerts;
- save/load for discovery, role, tier, health, destruction, cargo, and rebuild state.

Strategic decisions:

- which discovered site solves the current weakness;
- which purpose is worth exposing machines and Scrap;
- whether to rebuild immediately after destruction or preserve reserves;
- whether an outpost should remain expendable.

Exit gate:

- a player can authorize, follow, lose, and automatically rebuild an outpost without selecting individual robots;
- resource output is never teleported;
- player workload does not increase linearly with outpost count;
- the Heartforge remains the primary defence problem.

## Milestone 3 — Persistent town and reduced-detail simulation

**Goal:** Expand from one compact district to a world large enough for multi-session exploration while retaining physical continuity.

Systems:

- authored world regions connected by streets, tunnels, industrial corridors, and ruins;
- navigation data per region;
- active simulation bubble around the camera and important conflicts;
- reduced-detail remote simulation preserving positions, health, objectives, cargo, encounters, and causality;
- deterministic transitions between active and reduced detail;
- route graph and travel-time validation;
- world seed and authored variation system, with persisted weather-condition
  profiles that alter the town's atmosphere without adding player chores;
- region discovery and sensor uncertainty;
- remote-operation follow camera and command map.

Performance targets:

- agreed mid-range Windows PC target established through representative hardware;
- 60 fps in active combat scenes under the current content budget;
- hundreds of remote entities simulated at reduced detail;
- bounded decision updates and event logs;
- no save-size growth caused by unbounded histories.

Exit gate:

- a robot group can leave the active area, continue through reduced-detail simulation, re-enter active simulation, and preserve equivalent state;
- following a remote group reveals its actual path and encounters;
- save/load is equivalent across transitions.

## Milestone 4 — Autonomous machine society

**Goal:** Make the machine population the primary executor of the survival loop.

Autonomy stages:

1. **Dependency:** companion protection; manual salvage and fabrication.
2. **Task memory:** local salvage, return, repair, and standing defence.
3. **Group coordination:** escorts, formations, shared threat response, regrouping.
4. **Expeditionary autonomy:** long-distance objectives, field repair, recovery, retreat.
5. **Adaptive autonomy:** machine composition, replacement, local structural response, outpost recovery.
6. **Sovereign autonomy:** broad priorities and doctrines replace operational task assignment.

Systems:

- utility-based task allocation;
- machine memory and learned route risk;
- casualty recovery and disabled-machine retrieval;
- automatic ordinary replacement after unlocked progression;
- class quotas or broad composition intentions rather than build queues;
- exception-based alerts;
- doctrine system for cohesion, acceptable loss, retreat, pursuit, and reserve behaviour;
- short player-facing explanation for every consequential choice.

Exit gate:

- ordinary salvage, repair, defence, replacement, hauling, and rebuilding can continue for an extended period without player input;
- the player remains strategically necessary because they choose priorities and interventions;
- late-game UI is calmer than mid-game UI.

## Milestone 5 — Heartforge evolution and adaptive defence

**Goal:** Deliver base building without placement chores.

Systems:

- authored Heartforge tiers with modular sockets;
- machine-generated upgrade plans based on selected function and observed threats;
- visual preview explaining purpose and trade-off;
- automatic construction sequence;
- automatic wall, shelter, firing position, sensor, and repair-layout adaptation within a bounded footprint;
- damage-state visuals and reconstruction;
- base evolution history retained in save state;
- attack-pattern memory informing later proposals.

Player choices:

- strengthen shell versus improve machine production;
- improve sensors versus reduce detectability;
- specialize against burrowers versus aerial/spore threats;
- preserve redundancy versus maximize immediate output;
- accept temporary vulnerability during a major rebuild.

Exit gate:

- no repeated wall-segment or turret placement is required;
- the base visibly changes because of player strategy and enemy behaviour;
- a player can understand why the machines proposed a structural change.

## Milestone 6 — Ecology depth and continuous world pressure

**Goal:** Replace generic spawning with a living hostile ecology.

Species behaviours:

- scavengers attracted to salvage and corpses;
- pack hunters testing isolated machines;
- stalkers observing routes before attacking;
- burrowers bypassing static perimeter assumptions;
- parasites disabling or contaminating machines;
- nest-builders expanding toward noise and resources;
- predators hunting other organisms as well as machines;
- migratory creatures crossing the town because of world conditions;
- apex organisms responding to large-scale player activity.

Systems:

- nests with population, hunger, territory, and disturbance;
- scent/noise/heat or equivalent abstract signals;
- predator–prey relationships;
- local depletion and migration;
- creature memory of machine routes and defences;
- causal incident scheduler;
- telegraphing through tracks, sounds, machine reports, and sensor evidence;
- adaptive but bounded counter-pressure that avoids arbitrary hard counters.

Exit gate:

- the world produces meaningful pressure without a recurring wave timer;
- destroying or disturbing a nest has understandable consequences;
- successful offensive action can buy a real lull;
- ecology behaviour remains reproducible enough to diagnose failures.

## Milestone 7 — Mid-game strategic sandbox

**Goal:** Sustain 10–30 hours of meaningful play without management inflation.

Content and systems:

- multiple discovered districts with different organic risks;
- 6–8 mature robot families or modular chassis families;
- 4 outpost roles with three tiers and role variants;
- 25–40 consequential technologies;
- rare materials tied to specific objectives rather than generic farming;
- 15–25 expedition templates generated from world state;
- dynamic rescue, recovery, suppression, survey, hunt, and retrieval objectives;
- machine doctrine choices, with one rare mutually exclusive commitment shaping
  cohesion, retreat, obstruction tolerance and remote-operation pace;
- meaningful trade-offs between Mechromancer, machines, and Heartforge development;
- long-run pressure tuning and recovery windows;
- improved failure analysis.

Exit gate:

- a 20-hour save remains stable, legible, and enjoyable;
- the player makes strategic choices rather than servicing the simulation;
- no single technology path dominates all situations;
- expansion remains constrained and expeditionary.

## Milestone 8 — Late-game machine war

**Goal:** Deliver the dramatic contrast promised by the opening.

Systems:

- large coordinated machine groups;
- multiple simultaneous remote operations handled by autonomy;
- deep expeditions lasting substantial in-game time;
- stronger remote repair and continuity systems;
- distributed sensor knowledge without territory ownership;
- late robot levels and rare chassis transformations;
- advanced doctrines for speed versus cohesion, rescue versus abandonment, and preservation versus decisive force;
- world-scale organic reactions;
- partial Heartforge continuity or backup technology earned late enough not to trivialize early survival.

Presentation:

- later machines become visibly more futuristic while retaining industrial lineage;
- the same ruined urban world is increasingly threaded with machine light and movement;
- large operations are observable without requiring individual control;
- audio communicates distant activity and machine confidence.

Exit gate:

- hundreds of machines can act coherently without a matching increase in player inputs;
- the Heartforge remains vulnerable enough that the player cannot ignore defence;
- late game feels powerful, not bureaucratic.

## Milestone 9 — Endgame and first victory

**Goal:** Provide a difficult, legible conclusion to the long sandbox.

Possible victory structure:

- identify the source or governing mechanism of the hostile ecology;
- obtain several unique components through deep expeditions and apex encounters;
- choose a final strategic approach such as destruction, containment, severance, or transformation;
- prepare the Heartforge and machine society for an irreversible process;
- initiate the process when the player chooses;
- survive a causal world-scale response;
- complete a final remote and home-front operation whose success depends on prior choices.

The endgame is not a recurring horde schedule. It is a player-triggered culmination with clear prerequisites and consequences.

Failure should identify which preparation, doctrine, reserve, route, outpost, or technology choice proved insufficient.

Exit gate:

- a first victory is possible without meta-stat grinding;
- the final crisis exercises the whole game rather than only combat damage;
- the ending reflects major strategic choices and machine autonomy development.

## Milestone 10 — Production art, animation, audio, and narrative

**Goal:** Replace procedural placeholders with a cohesive production identity while preserving rapid iteration.

Art production set:

- one production Mechromancer with visible progression states;
- one Bulwark companion with strong emotional readability;
- modular shared robot component library;
- production versions of each robot family and level transformation;
- modular organic creature families with reusable rigs;
- Heartforge tier kit and damage states;
- outpost role/tier kit;
- ruined urban environment kit;
- industrial props, wrecks, vegetation, nests, and organic contamination;
- VFX library for machine, forge, salvage, weather, and organic effects;
- icon and UI illustration set.

Animation production:

- shared locomotion and hit libraries;
- role-specific robot work animation;
- coordinated formation and regroup feedback;
- Mechromancer interaction and upgrade animation;
- organic locomotion, attacks, feeding, nesting, retreat, and death;
- procedural layers retained for variation and responsiveness.

Audio production:

- warm Heartforge ambience;
- cold town ambience by region and condition;
- robot family identity and status language;
- organic species vocal signatures;
- distance-aware operation sounds;
- salvage and construction risk escalation;
- adaptive music that reflects pressure without imitating a wave countdown.

Narrative:

- environmental history of the town and Heartforge;
- machine naming and relationship moments without per-unit management;
- discoveries that explain technologies and ecology;
- sparse run-level story arcs compatible with systemic replay, including the
  persisted Town Archive recovered through real region and component discoveries;
- endings linked to strategic choices.

Exit gate:

- representative vertical slices meet the final visual and audio bar;
- assets are optimized, licensed, attributed, and replaceable through stable scene interfaces;
- gameplay readability is not sacrificed for detail.

## Milestone 11 — Alpha

**Goal:** Complete all principal systems and the full victory path.

Alpha requirements:

- complete start-to-victory run;
- all production save schemas and migrations;
- all major robot, Heartforge, outpost, ecology, and endgame systems;
- representative full content breadth;
- first-pass balance for all major paths;
- keyboard/mouse and controller support;
- accessibility baseline;
- crash reporting and diagnostics;
- performance budgets enforced;
- no known save-corruption path.

Testing:

- automated simulation soak tests;
- long-save migration tests;
- deterministic scenario tests;
- playtest telemetry focused on failure causes and player workload;
- repeated 20+ hour internal runs;
- hardware coverage.

## Milestone 12 — Beta and external playtest

**Goal:** Validate endurance, clarity, balance, and emotional arc with external players.

Sequence:

1. small confidential playtest;
2. expanded invitation-only test;
3. Steam Playtest or equivalent controlled public test;
4. polished public demo only after the opening experience represents the intended product.

Questions to answer:

- Does the opening feel frightening but fair?
- Is the Bulwark dependency understood?
- Does each autonomy stage visibly remove work?
- Do players understand why remote groups behave as they do?
- Does base defence remain central after outposts unlock?
- Does continuous pressure avoid both boredom and alert fatigue?
- Do 20–50 hour saves remain comprehensible?
- Are failures attributable and motivating?
- Does late-game scale feel powerful rather than bureaucratic?

Beta exit gate:

- stable full-run completion rate within target difficulty bands;
- no critical save issues;
- acceptable performance on target hardware;
- no major progression dead ends;
- player workload does not scale linearly with game size;
- content and balance changes no longer require architectural rewrites.

## Milestone 13 — Release candidate and launch

Release requirements:

- final content lock;
- final save migration policy;
- localization-ready text extraction and supported languages selected;
- accessibility review;
- legal/licence/attribution review;
- platform packaging and controller certification where applicable;
- crash-free and save-integrity targets met;
- store assets, trailer, screenshots, demo, and documentation prepared;
- post-launch telemetry and support process ready;
- rollback plan for critical update regressions.

The Early Access decision should be made only after the core survival/autonomy loop is proven and the product can support durable long saves. Early Access must not be used to discover the fundamental game identity.

## 5. Cross-cutting workstreams

## 5.1 Persistence and migration

- version every save domain;
- use stable IDs for content;
- provide defaults for missing data;
- write migration tests before changing schemas;
- use atomic temporary-file replacement;
- keep rotating backups;
- preserve remote positions and operation state;
- include a human-readable recovery report for failed loads.

## 5.2 Performance

- establish representative stress scenes;
- profile before introducing custom architecture;
- stagger AI decisions;
- use spatial indexes for targeting and perception;
- pool high-volume transient VFX;
- transition distant entities to reduced detail;
- keep important conflicts active even when off-camera;
- enforce bounded logs, projectiles, tasks, and event histories.

## 5.3 Tooling

- data validators for every content schema;
- editor tools for world sites, routes, nests, and Heartforge sockets;
- replayable scenario testbeds;
- save inspector and migration harness;
- automated screenshot scenes for art review;
- performance capture scenes;
- content manifest reporting missing IDs, art, audio, or tests.

## 5.4 Accessibility

- full input remapping;
- hold/toggle alternatives;
- text scaling;
- high-contrast target and interactable options;
- camera shake and flash reduction;
- color-independent role markers;
- pause-friendly play;
- adjustable game speed when not in irreversible interactions;
- readable subtitles and audio cues;
- difficulty settings that alter pressure and recovery without adding chores.

## 5.5 Quality gates

Every production milestone must pass:

- static repository validation;
- Godot headless import;
- relevant native scenario tests;
- save/load equivalence tests;
- anti-chore review;
- performance smoke test;
- visual readability review;
- documentation and changelog update.

## 6. Content budget targets

These are planning ranges, not promises:

- 6–8 core robot families, each with three major levels and role-readable variants;
- 12–18 organic species/behaviour families plus nests, parasites, and apex forms;
- 4 primary outpost roles with three tiers and contextual variants;
- 4–6 Heartforge tiers or equivalent major structural stages;
- 35–60 consequential technologies, many mutually exclusive or path-shaping;
- 20–35 fixed discovered support sites across the full world;
- 5–8 major urban regions with authored identity;
- 30–60 expedition/objective templates driven by world state;
- several unique late-game objectives and 3–4 endgame strategic approaches;
- enough environmental and systemic variation to support repeated failed worlds without requiring procedural map noise everywhere.

## 7. Immediate implementation sequence

The next repository changes should occur in this order:

1. add the machine-readable full-game content manifest and progression phases;
2. add a progression director with stable save state;
3. add Heartforge tiers and the Engineer robot family;
4. add fixed discoverable outpost sites;
5. add physical escorted outpost construction, upgrade, hauling, repair, destruction, and rebuilding;
6. extend the current objective flow beyond the North Ruins core;
7. add full-game extension save/load tests;
8. add reduced-detail world-region architecture;
9. add deeper ecology and additional content only after the foundation passes.

This sequence begins full-game production without discarding the working opening slice or prematurely expanding content on unstable systems.
