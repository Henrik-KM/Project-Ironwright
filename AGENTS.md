# AGENTS.md — Project Ironwright

This file is the operating contract for Codex and other coding agents working in this repository.

## 1. Authority order

The current Project Ironwright conversation with Henrik is the highest product authority.

When an explicit instruction in that conversation conflicts with repository documentation, machine-readable contracts, old prompts, prototypes, or genre conventions:

1. follow the most recent explicit user instruction;
2. update the conflicting repository contracts in the same change;
3. preserve earlier decisions that are not actually contradicted;
4. record the deliberate direction change in the changelog or relevant design document.

Do not reject an explicit current instruction merely because an older file says otherwise. The repository exists to preserve the conversation’s current design, not to overrule it.

## 2. Product identity

Project Ironwright is a single-player, long-form survival-strategy sandbox about defending one vulnerable Heartforge in a hostile organic post-apocalyptic town.

The player directly controls one weak Mechromancer. The opening depends on one indispensable machine companion. Over a run lasting many sessions, robots learn to salvage, defend, scout, repair, fabricate, escort, construct, rebuild, and conduct expeditions without routine supervision.

The game must become less operationally demanding as it becomes larger. The primary fantasy is not commanding individual units. It is watching a machine society gradually assume the burden of survival while the player makes a small number of consequential strategic choices.

Before changing gameplay, read:

1. this file;
2. `docs/DESIGN_LOCKS.md`;
3. `docs/FULL_GAME_ROADMAP.md`;
4. `docs/GAME_DESIGN_DOCUMENT.md`;
5. `docs/AUTONOMY_AND_ANTI_CHORE.md`;
6. the document relevant to the system being changed.

## 3. Non-negotiable constraints

Do not add or imply any of the following unless Henrik explicitly changes the direction:

- more than one player-operated run-critical home;
- territory claiming or map painting;
- freely placed colonies or outposts;
- manually managed supply lines;
- per-outpost worker assignment, queues, power grids, or ammunition;
- production-chain economy;
- more than one ordinary stockpiled construction resource;
- player-managed power networks;
- scheduled recurring waves as the main loop;
- hostile robot factions as the normal enemy fantasy;
- routine per-unit movement or attack orders;
- individual robot loadouts as recurring work;
- production queues that require regular maintenance;
- manual wall, turret, cable, storage, or module placement as the main base loop;
- hunger, thirst, sleep, hygiene, temperature, or similar maintenance meters;
- a short-run roguelite structure as the principal product.

Enemies are organic. Major attacks must be causal, legible, and rare. Base defence remains the centre of play even when robots travel far away.

## 4. Autonomous outposts

Bounded autonomous outposts are canonical.

Outposts are unlocked through Heartforge progression and may only be created on fixed sites that were discovered through real excursions. The player chooses a discovered site, a broad purpose, and whether to authorize construction or an upgrade.

The machines handle:

- builder and escort selection;
- physical travel through the persistent world;
- route execution and formation cohesion;
- exact construction geometry;
- automatic operation;
- routine repair;
- resource collection and hauling;
- rebuilding after destruction;
- local defence and retreat decisions.

Valid outpost purposes include resource recovery, proxy defence, early warning/scouting, and field repair.

Outposts are not secondary player bases. The player does not move the Heartforge to them, operate production queues there, assign workers, place modules, wire power, or manage a logistics spreadsheet. Their number is bounded by authored discovered sites.

## 5. Anti-chore rule

For every new system, answer:

1. What meaningful strategic decision does this create?
2. What recurring task does it add?
3. Does that task become more frequent with robot count, outpost count, base age, or run length?
4. How is routine execution delegated permanently?
5. Can the same tension be represented with one aggregated choice?

Reject designs whose routine workload scales roughly with robots, structures, outposts, attacks, objectives, or hours played.

Autonomy must remove categories of work. Do not “solve” micro-management with a larger macro-management dashboard.

## 6. Opening survival rules

The opening must remain oppressive but visually readable:

- the Mechromancer has a weak automatic pistol;
- the companion is the primary protection;
- manual salvage takes time, emits noise, disables attack, and can be interrupted;
- early robot construction is performed manually at the Heartforge;
- fabrication takes time, emits noise, and disables attack;
- early excursions are short and frightening;
- the Heartforge is warm and inhabited, while the surrounding town is cold and dangerous;
- weapon strength and fabrication automation are later progression.

## 7. Repository boundaries

- Godot project root: `game/`
- Gameplay scripts: `game/scripts/`
- Scenes: `game/scenes/`
- Machine-readable content: `game/data/`
- Native tests: `game/tests/`
- Design documentation: `docs/`
- Copy-ready tasks and historical prompts: `prompts/`
- Repository validation: `scripts/`
- Browser reference prototype: `web/`

Do not place generated caches, imported engine state, build outputs, or downloaded asset archives in Git.

## 8. Implementation workflow

For each task:

1. inspect existing files and relevant product contracts;
2. define the observable gameplay or production goal;
3. identify the smallest coherent vertical change that advances the full game;
4. implement data and tests before broad content expansion where practical;
5. run repository validation;
6. run Godot headless import and relevant native tests;
7. review the diff for accidental design drift;
8. update documentation when behaviour or a deliberate decision changed;
9. report changed files, test results, and unresolved risks.

Do not claim completion when required validation fails.

## 9. Code standards

- Use Godot 4.7.1-compatible APIs.
- Use typed GDScript for gameplay code.
- Prefer small composable nodes and plain data over deep inheritance.
- Keep simulation state independent from presentation where practical.
- Use stable identifiers for persistent content.
- Do not use display strings as save keys.
- Avoid global singletons unless they represent a genuine run-level service.
- Keep random behaviour seedable and diagnosable.
- Log reasons for consequential autonomous decisions.
- Handle missing data and corrupt files explicitly.
- Avoid silent fallbacks that hide broken content.
- Keep collections, logs, queues, and event histories bounded.

## 10. Full-game architecture

The production game should be assembled from durable run-level services rather than one monolithic scene script.

Preferred top-level flow:

```text
Persistent world state
→ progression director
→ ecology and threat simulation
→ strategic need
→ autonomy / operation director
→ coordinated group plan
→ individual execution state
→ presentation and player-facing explanation
```

New content should be data-driven where it meaningfully enables balancing, save migration, content production, and automated validation. Do not move trivial constants into data merely for abstraction.

## 11. Robot intelligence

Robot behaviour must be:

- deterministic where practical;
- inspectable;
- explainable in a short player-facing sentence;
- robust to save/load;
- consistent between active and reduced-detail simulation;
- capable of resolving routine work without player alerts.

Use utility scoring, planners, state machines, memory, and unlocked operators. Do not use a trained model merely to make the fiction say “learning.”

Remote groups must use formation-relative roles, pace limits, regrouping, escort behaviour, retreat conditions, and real physical positions. Independent maximum-speed rushing is not the default.

## 12. Organic ecology

The ecology is a persistent simulation, not a wave generator.

A major incident requires explicit world-state causes and telegraphing. Tests should verify that the incident does not occur without its predicates.

Species need motivations and relationships: scavenging, stalking, burrowing, infestation, pack hunting, territorial behaviour, migration, predation, attraction to noise, and response to machine activity.

## 13. Heartforge and outpost evolution

The player chooses principles, strategic functions, and costly commitments. Machines handle geometry and execution.

Start with authored layouts, modular sockets, and fixed discovered sites. Do not begin with unconstrained procedural construction.

Every autonomous structural change must communicate:

- what problem it addresses;
- what role or doctrine was chosen;
- what trade-off it accepts;
- where machines are travelling;
- whether construction, repair, hauling, or rebuilding is underway.

## 14. Persistence

Long-world save reliability is product-critical.

Every persistent feature must define:

- stable identifier;
- serialized state;
- default for missing older data;
- schema version impact;
- migration test when required;
- deterministic or recorded random state.

Outpost saves must retain site discovery, purpose, tier, health, destruction state, stored Scrap, and rebuild-relevant state.

Use transactional saves and rotating backups before public testing.

## 15. Tests

At minimum, maintain tests for:

- data parsing and invariants;
- opening pistol behaviour and channel lockout;
- autonomy and progression gates;
- robot decision reasons;
- formation cohesion and regrouping;
- ecology-event predicates;
- physical expedition and construction movement;
- outpost unlock, operation, repair, destruction, rebuilding, and hauling;
- save/load equivalence and migration;
- active/reduced-detail transitions when implemented;
- no unbounded task or event growth;
- aesthetic readability and presentation attachment.

Representative scenario testbeds are preferred over broad unverified systems.

## 16. Assets

No external runtime asset may be committed without an entry in `ATTRIBUTION.md` containing:

- exact asset or pack;
- creator/source;
- official URL;
- licence;
- date obtained;
- original licence file location;
- modifications;
- redistribution status.

The current procedural models are original placeholders. Concept images are references, not runtime assets or exact UI specifications.

## 17. UI

Default to minimal HUD and exception-based notifications.

Strategic interfaces may expose major evolution choices, machine focus, discovered site, outpost purpose, and authorization. Do not add permanent dashboards of workers, queues, route throughput, budgets, ammunition, repair assignments, or dozens of rates.

Late-game UI should be calmer than early-game UI because machines handle more work.

## 18. Performance

Profile representative scenes before designing custom optimisation architecture.

Begin with:

- staggered decision updates;
- spatial indexing;
- pooling where justified;
- reduced-detail remote simulation;
- Godot navigation;
- bounded logs and queues.

Introduce custom crowd systems, native extensions, or an ECS only after profiling identifies a concrete bottleneck.

## 19. Definition of task completion

A gameplay task is complete only when:

- observable acceptance criteria are met;
- relevant tests pass;
- repository validation passes;
- Godot imports the project headlessly;
- the implementation follows the authoritative conversation and current design locks;
- autonomous behaviour has a diagnostic reason;
- no recurring chore was introduced without explicit approval;
- persistent state survives save/load where applicable.

## 20. Population-driven ecological escalation

Enemy difficulty is population-driven rather than unlocked by a recurring timer.
Each organic tier has a population cap and replenishment rate. When a non-final
tier is saturated, its current replenishment allocation moves to the next tier
at 10:1 and becomes zero in the source tier. Process saturation from high tiers
downward so one update cannot instantly cascade the same pressure through the
whole ladder.

Tier I is numerous, slow and behaviorally primitive: roam, chase visible prey,
and attack. Higher tiers add territorial defense, patrol, scouting, hunting,
information sharing, route observation, infrastructure targeting, retreat, and
regional Apex behavior. Tier and species remain separate data.

All replenishment materializes through physical living nests. Killing organisms
creates population headroom; clearing nests removes long-term rate sources;
progression and operations may increase or suppress rates. Noise changes
attention, not permanent global reproduction. Mature machine society handles
routine Tier-I thinning without individual robot orders.

Read `docs/ENEMY_TIER_PROGRESSION.md` before changing enemy spawning, nests,
regional ecology, operation rewards, or autonomous suppression.
