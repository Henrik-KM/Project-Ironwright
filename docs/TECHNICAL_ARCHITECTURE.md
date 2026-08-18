# Technical Architecture

## 1. Goals

The technical architecture must support:

- one persistent world saved across many sessions;
- a directly controlled Mechromancer;
- a compact but evolving Heartforge;
- progressively autonomous robots;
- organic creatures with persistent ecological effects;
- continuous pressure without scheduled wave scripts;
- hundreds of late-game actors through simulation levels of detail;
- deterministic diagnosis of robot and world decisions;
- repository workflows suitable for Codex and automated validation.

The architecture should begin simply. Complexity is introduced only after representative profiling or design proof.

---

## 2. Engine and language

Recommended baseline:

- Godot 4.7.1 as the repository baseline;
- typed GDScript for most gameplay systems;
- glTF for 3D runtime assets;
- JSON or Godot Resources for content data;
- Python for repository validation and content tooling;
- GitHub Actions for static validation and later headless tests.

Native code or an ECS is not part of the initial implementation. Introduce native extensions only for measured bottlenecks.

---

## 3. Architectural boundaries

### 3.1 Presentation layer

Responsible for:

- rendering;
- animation;
- VFX;
- audio;
- UI;
- camera;
- player input;
- visual interpolation.

Presentation reads simulation state and submits player intent. It should not own persistent rules.

### 3.2 Active simulation layer

Responsible for entities near the Mechromancer or Heartforge:

- movement and navigation;
- perception;
- combat;
- repair;
- local robot planning;
- creature behaviour;
- projectiles and hazards;
- detailed interaction.

### 3.3 Strategic simulation layer

Responsible for distant or aggregated state:

- remote expedition progress;
- regional creature populations;
- migration;
- nest and feeding pressure;
- route familiarity;
- world signals;
- off-screen machine groups;
- causal major-event formation.

### 3.4 Persistence layer

Responsible for:

- save schema;
- version migrations;
- transactional writes;
- deterministic random streams;
- entity identity;
- event history;
- recovery checkpoints;
- diagnostic exports.

---

## 4. Core runtime services

### 4.1 `SimulationClock`

Provides:

- pause and time scale;
- fixed simulation ticks;
- separate schedules for active and strategic simulation;
- stable timestamps for saves and event logs.

No ecological escalation should depend only on elapsed time. The clock schedules simulation; world state creates pressure.

### 4.2 `RunState`

Owns high-level persistent state:

- world seed;
- current phase descriptor;
- Heartforge state;
- Mechromancer state;
- machine population summaries;
- discovered unique components;
- known organism observations;
- current and historical expeditions;
- victory and defeat state.

### 4.3 `WorldState`

Owns:

- generated terrain regions;
- known and unknown routes;
- objective sites;
- regional ecology;
- weather state;
- active-area boundaries;
- persistent physical changes.

### 4.4 `HeartforgeController`

Owns:

- structural modules and damage;
- evolution configuration;
- autonomous repair priorities;
- fabrication and replacement;
- base signature;
- architect proposals;
- local safe-light and recovery effects.

### 4.5 `AutonomyDirector`

Coordinates machine goals at multiple levels:

- local individual execution;
- cooperative group formation;
- base routines;
- expedition proposals;
- exceptional decision escalation;
- explanation generation.

It must not become a player-facing policy spreadsheet.

### 4.6 `EcologyDirector`

Owns persistent organic pressure:

- population updates;
- awareness of Heartforge signals;
- movement among regions;
- inter-species interaction;
- materialisation into active encounters;
- major-event conditions;
- environmental telegraphing.

It explicitly does not schedule recurring waves.

### 4.7 `ExpeditionDirector`

Owns:

- candidate objective evaluation;
- machine proposal generation;
- group composition;
- route planning;
- active/aggregated transition;
- retreat and recovery;
- debrief and explanation.

### 4.8 `SaveService`

Owns:

- save snapshots;
- validation;
- rolling backups;
- schema migration;
- recovery from interrupted writes;
- diagnostic event history.

---

## 5. Robot intelligence architecture

Use a hierarchical, inspectable structure:

```text
Run-level needs
    ↓
Autonomy Director
    ↓
Base routine / defence response / expedition objective
    ↓
Group plan and role assignment
    ↓
Individual utility choice
    ↓
Finite execution state
    ↓
Navigation, movement, tool, and weapon actuators
```

### 5.1 Shared blackboard

Machines share bounded knowledge:

- known threats;
- damaged allies;
- current Heartforge needs;
- route confidence;
- discovered material;
- active group commitments;
- unknown observations.

Knowledge has source, age, and confidence. It should not become omniscient merely because one robot exists somewhere on the map.

### 5.2 Utility selection

At an individual level, robots score a small set of valid actions. Inputs may include:

- current group goal;
- distance;
- threat;
- role capability;
- ally need;
- retreat condition;
- Heartforge priority;
- confidence.

Store the top factors for explanation and debugging.

### 5.3 Group planning

Groups are formed dynamically around needs, not permanent player-created squads. A group plan specifies roles and completion conditions; machines fill roles according to capability.

### 5.4 Learning

“Learning” is represented through unlocked perceptions, memories, scoring factors, and planner operators. A trained ML model is not required.

This gives deterministic behaviour, testability, and designer control while still supporting the fantasy of machines becoming smarter.

---

## 6. Heartforge architect

### 6.1 Inputs

- current module graph;
- terrain occupancy;
- structural support;
- attack heatmap;
- creature-capability observations;
- player-chosen evolution;
- known modules;
- Scrap forecast;
- navigation and fire-line requirements.

### 6.2 Outputs

- proposed structural changes;
- build dependencies;
- affected area preview;
- expected defence benefit;
- accepted trade-off;
- construction tasks.

### 6.3 Implementation stages

1. authored fixed layouts for early prototype;
2. modular sockets and rule-based replacement;
3. local procedural selection from templates;
4. attack-history-driven adaptation;
5. more expressive generated morphology if playtests justify it.

Do not begin with unconstrained procedural architecture.

---

## 7. Organic ecology implementation

### 7.1 Regional model

Each region stores compact data:

- species populations;
- feeding value;
- nest state;
- awareness by signal type;
- migration pressure;
- apex influence;
- recent machine activity;
- recent casualties and carrion;
- environmental modifier.

### 7.2 Active encounter conversion

When a population enters the active area, create individual entities whose composition and condition derive from regional state.

When entities leave active simulation, aggregate survivors and outcomes back into the region.

### 7.3 Causal events

Major events are triggered by predicates over world state, for example:

```text
undermaw_awareness > threshold
AND heartforge_vibration_state == resonant
AND no_recent_undermaw_event
```

The event then generates telegraphing before materialising. There is no repeating wave index.

---

## 8. Navigation and movement

Start with Godot navigation for active actors and simple steering/avoidance.

Requirements:

- robust return-to-Heartforge paths;
- group congestion control;
- fallback when path unavailable;
- navigation-state explanation;
- test scenes for gates, narrow passages, dynamic debris, and many agents;
- predictable behaviour near the defensive shell.

Remote expeditions use graph routes rather than full navmesh traversal until entering active simulation.

Flow fields or custom crowd navigation should be added only if profiling representative late-game scenes shows a need.

---

## 9. Simulation levels of detail

### Level A — Full

Near player/base:

- physics movement;
- per-actor perception;
- attacks;
- animation;
- detailed utility decisions.

### Level B — Tactical aggregate

Visible but distant:

- simplified positions;
- group-level combat resolution;
- lower-frequency decisions;
- reduced animation and perception.

### Level C — Strategic aggregate

Remote:

- route-node progress;
- group condition;
- probabilistic or deterministic encounter resolution from explicit inputs;
- event log;
- no individual frame simulation.

Transitions must preserve identity of important machines and make outcomes explainable.

---

## 10. Data model

Initial machine-readable design data is in `game/data/`:

- `design_contracts.json`;
- `autonomy_stages.json`;
- `enemy_archetypes.json`;
- `prototype_scope.json`.

Future content should prefer stable identifiers and explicit schema versions.

Example identifiers:

- `robot.scrapling`;
- `enemy.veilstalker`;
- `evolution.machine.routine_salvage`;
- `discovery.cognition.cooperative_retreat`;
- `event.undermaw_resonance`.

Do not use display names as persistence keys.

---

## 11. Save architecture

### 11.1 Snapshot contents

- schema version;
- run metadata;
- world seed and random states;
- persistent entities;
- Heartforge module graph;
- autonomy and discovery state;
- regional ecology;
- active expeditions;
- unique-object state;
- recent event log;
- presentation-independent state only.

### 11.2 Transactional process

1. serialise to temporary file;
2. validate schema and required invariants;
3. calculate checksum;
4. rotate previous valid save;
5. atomically replace active save;
6. retain diagnostics on failure.

### 11.3 Migrations

Every schema change must include:

- migration function;
- representative old-save fixture;
- automated migration test;
- version bump;
- release note.

---

## 12. Testing strategy

### 12.1 Unit tests

- utility scores;
- proposal generation;
- ecology predicates;
- save serialisation;
- schema migrations;
- resource invariants;
- unique-discovery state;
- autonomy-stage gates.

### 12.2 Simulation tests

- run 10,000 fixed ticks with no input;
- routine base survives familiar low pressure after Stage 1;
- machine workload does not produce unbounded tasks;
- regional population transition conserves expected state;
- expedition return conditions work;
- major event does not occur without its causal predicates;
- save/load yields equivalent continued outcomes.

### 12.3 Scenario testbeds

- First Night;
- one stalker outside light;
- routine Scrap gathering;
- damaged-machine recovery;
- burrow attack and architect response;
- 10 versus 100 robot workload comparison;
- remote expedition active/aggregate transition;
- long-run accelerated ecology simulation.

### 12.4 Visual and performance tests

- silhouette readability at target camera distance;
- late-game combat clarity;
- actor-count benchmarks;
- navigation congestion;
- UI density snapshots by phase;
- memory growth over accelerated multi-hour simulation.

---

## 13. Performance targets

Initial proof targets:

- 60 frames per second in the First Night greybox on an agreed mid-range PC;
- stable simulation with 30 friendly machines and 60 active creatures in a representative mid-game test;
- architectural path to hundreds of machines through levels of detail;
- no unbounded task queues or event logs;
- save/load under a few seconds for representative long-world snapshots.

These are engineering targets, not marketing promises. Profile before optimising.

---

## 14. Codex-friendly repository practices

- root `AGENTS.md` contains product and engineering rules;
- each task has explicit acceptance criteria;
- small changes with tests are preferred over broad speculative systems;
- design data is machine-readable;
- validation runs locally and in GitHub Actions;
- third-party assets require provenance entries;
- generated code must not silently add design systems outside `DESIGN_LOCKS.md`;
- implementation plans and decisions are committed with code.

---

## 15. First implementation boundary

The first implementation should prove:

- direct movement;
- damaged Heartforge state;
- one dependent Scrapling;
- one organic Veilstalker;
- darkness and safe-light radius;
- one nearby Scrap recovery;
- one qualitative autonomy unlock;
- no wave timer;
- save and reload of the tiny world.

Do not implement the full ecology, procedural Heartforge, large population, or long-run generator before this scene is compelling.
