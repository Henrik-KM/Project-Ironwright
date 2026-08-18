# AGENTS.md — Project Ironwight

This file is the operating contract for Codex and other coding agents working in this repository.

## 1. Product identity

Project Ironwight is a single-player, long-form survival strategy game about defending one constrained Heartforge in a hostile organic world.

The player directly controls one Mechromancer. The machines gradually learn to gather, repair, defend, recover, and conduct expeditions without supervision. The game must become less operationally demanding as it becomes larger.

Before changing gameplay, read:

1. `docs/DESIGN_LOCKS.md`
2. `docs/GAME_DESIGN_DOCUMENT.md`
3. `docs/AUTONOMY_AND_ANTI_CHORE.md`
4. the document relevant to the system being changed

`docs/DESIGN_LOCKS.md` overrides older assumptions and convenient genre conventions.

## 2. Non-negotiable constraints

Do not add or imply any of the following unless the user explicitly changes the product direction:

- multiple player bases;
- territory claiming or map painting;
- forward outposts or permanent supply sites;
- production chains;
- more than one ordinary stockpiled resource;
- player-managed power grids;
- scheduled recurring waves;
- hostile robot factions;
- routine per-unit orders;
- individual robot loadouts;
- production queues requiring player maintenance;
- manual wall, turret, cable, or storage placement as the main build loop;
- hunger, thirst, sleep, hygiene, or similar survival meters;
- a short-run roguelite structure as the principal mode.

Enemies are organic. Large attacks must be causal and rare. The Heartforge remains the centre of the game.

## 3. Anti-chore rule

For every new system, answer in the implementation plan:

1. What meaningful strategic decision does this create?
2. What recurring task does it add?
3. Does that task increase with machine count, base age, or run length?
4. How is routine execution delegated permanently?
5. Can the same tension be represented with fewer inputs or one aggregated choice?

Reject designs whose routine workload scales with the number of robots, structures, attacks, objectives, or hours played.

Autonomy must remove categories of work. Do not “solve” micro-management with a larger macro-management menu.

## 4. Repository boundaries

- Godot project root: `game/`
- Gameplay scripts: `game/scripts/`
- Scenes: `game/scenes/`
- Machine-readable content: `game/data/`
- Design documentation: `docs/`
- Copy-ready Codex tasks: `prompts/`
- Repository validation: `scripts/validate_repo.py`

Do not place generated caches, imported engine state, build outputs, or downloaded asset archives in Git.

## 5. Implementation workflow

For each task:

1. Inspect existing files and relevant design documents.
2. Restate the observable goal and constraints in a short implementation plan.
3. Identify the smallest coherent vertical change.
4. Implement data and tests before broad content expansion where practical.
5. Run repository validation.
6. Run available Godot headless tests once the project has them.
7. Review the diff for accidental design drift.
8. Update documentation only when behaviour or a deliberate decision changed.
9. Report changed files, test results, and unresolved risks.

Do not claim a task is complete if validation or required tests fail.

## 6. Code standards

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

## 7. Robot intelligence

Preferred hierarchy:

```text
Run-level need
→ autonomy director
→ base routine, defence response, or expedition goal
→ group plan and role assignment
→ individual utility choice
→ execution state
→ actuator
```

Robot behaviour must be:

- deterministic where practical;
- inspectable;
- explainable in a short player-facing sentence;
- robust to save/load;
- consistent between active and aggregated simulation;
- capable of resolving routine work without player alerts.

Do not use a trained machine-learning model merely to make the fiction say “learning.” Utility scoring, planners, state machines, memory, and unlocked operators are preferred until a measured need proves otherwise.

## 8. Organic ecology

The ecology is a persistent simulation, not a wave generator.

A major incident requires explicit world-state causes and telegraphing. Tests should verify that the incident does not occur without its predicates.

Do not create a generic enemy army composition system. Species have motivations and relationships: scavenging, stalking, burrowing, infestation, pack hunting, territorial behaviour, migration, and predation.

## 9. Base evolution

The player chooses principles and trade-offs. Machines handle geometry and construction.

Start with authored layouts and modular sockets. Do not begin with unconstrained procedural base generation.

Any autonomous structural change must be visually and diagnostically legible:

- what problem it addresses;
- what approach was chosen;
- what trade-off it accepts;
- what area will change.

## 10. Persistence

Long-world save reliability is product-critical.

Every persistent feature must define:

- stable identifier;
- serialised state;
- default for missing older data;
- schema version impact;
- migration test when required;
- deterministic or recorded random state.

Use transactional saves and rotating backups once save implementation begins.

## 11. Tests

At minimum, add tests for:

- data parsing and invariants;
- autonomy-stage gates;
- robot decision reasons;
- ecology-event predicates;
- save/load equivalence;
- active/aggregated simulation transitions;
- no unbounded task or event growth.

Representative scenario testbeds are preferred over broad unverified systems.

## 12. Assets

No external runtime asset may be committed without an entry in `ATTRIBUTION.md` containing:

- exact asset or pack;
- creator/source;
- official URL;
- licence;
- date obtained;
- original licence file location;
- modifications;
- redistribution status.

Do not download assets automatically unless the task explicitly authorises it. Never substitute a robot enemy because an available asset pack contains one.

The images under `docs/concept-art/` are visual references, not runtime assets or exact UI specifications.

## 13. UI

Default to minimal HUD and exception-based notifications.

Do not add permanent dashboards of rates, budgets, worker counts, or queues. A late-game interface must not be denser merely because the simulation is larger.

## 14. Performance

Profile representative scenes before designing a custom optimisation architecture.

Begin with:

- staggered decision updates;
- spatial indexing;
- pooling where justified;
- reduced-detail remote simulation;
- Godot navigation;
- bounded logs and queues.

Introduce custom crowd systems, native extensions, or an ECS only after profiling identifies a concrete bottleneck.

## 15. Definition of task completion

A gameplay task is complete only when:

- the observable acceptance criteria are met;
- relevant tests pass;
- `python scripts/validate_repo.py` passes;
- the implementation respects `docs/DESIGN_LOCKS.md`;
- autonomous behaviour has a diagnostic reason;
- no new recurring player chore was introduced without explicit approval;
- the change survives save/load if it affects persistent state, once save support exists.
