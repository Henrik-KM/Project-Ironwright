# First Codex Task — Build the “First Light” Greybox

## Goal

Turn the existing Godot scaffold into a small playable greybox that proves the opening emotion of Project Ironwight: one damaged Heartforge, one dependent Scrapling, and one organic predator in darkness.

Do not build the full game. Do not add conventional RTS systems.

## Required reading

Before editing code, read:

- `AGENTS.md`
- `docs/DESIGN_LOCKS.md`
- `docs/GAME_DESIGN_DOCUMENT.md`, especially sections 4, 5, 6, 7, 8, and 18
- `docs/ENEMY_ECOLOGY.md`, especially the Veilstalker design
- `game/data/prototype_scope.json`

## Observable player experience

A fresh run should take roughly 10–20 minutes to understand and complete.

1. The player wakes beside a visibly damaged Heartforge in a small dark environment.
2. One damaged Scrapling follows imperfectly but remains recognisably helpful.
3. The Heartforge’s light creates a small area of relative safety.
4. A wreck containing enough Scrap to perform one critical repair lies just outside comfortable safety.
5. One organic Veilstalker remains near the edge of visibility, tracks the player, and attacks only after a legible opportunity.
6. The player can recover the Scrap, retreat, and repair the Heartforge.
7. There is no wave timer, build menu, technology tree, territory map, production queue, or hostile robot.
8. The world can be saved and reloaded without losing the repaired state, collected Scrap, player state, Scrapling state, or Veilstalker state.

## Implementation constraints

- Use Godot primitives and simple authored materials. Do not download external assets.
- The Veilstalker placeholder must look organic rather than mechanical. A dark asymmetric body assembled from primitive meshes is acceptable.
- Keep the environment intentionally small. The player should see or sense the Heartforge from most of the initial playable area.
- Use typed GDScript.
- Keep simulation logic separate from presentation where reasonable.
- Seed any random behaviour.
- Every Scrapling and Veilstalker state transition must expose a short diagnostic reason in a debug overlay or log.
- Use a fixed or simple authored navigation space. Do not implement procedural world generation.
- Do not implement a recurring attack scheduler.

## Suggested scene structure

```text
FirstLight
├── WorldEnvironment
├── NavigationRegion3D
├── Terrain
├── Heartforge
├── Mechromancer
├── Scrapling
├── Veilstalker
├── SalvageWreck
├── Lighting
├── CameraRig
└── HUD
```

This is a suggestion, not a requirement. Prefer clear ownership over matching the tree exactly.

## Minimum systems

### Mechromancer

- WASD movement;
- mouse or movement-direction facing;
- one simple short-range tool attack;
- integrity/health;
- interaction with wreck and Heartforge;
- defeat/restart or safe recovery behaviour appropriate to the prototype.

### Heartforge

- damaged/repaired state;
- light radius;
- integrity display;
- repair interaction consuming the collected Scrap;
- obvious visual change when repaired.

### Scrapling

States:

- `FOLLOWING`;
- `WAITING_AT_HEARTFORGE`;
- `ATTACKING_NEARBY_THREAT`;
- `RETURNING`;
- `DISABLED`.

Allowed player signals:

- stay close;
- remain at Heartforge;
- return.

The Scrapling should not require individual targeting or a conventional unit-selection interface.

### Veilstalker

States:

- `HIDDEN`;
- `OBSERVING`;
- `STALKING`;
- `TESTING`;
- `ATTACKING`;
- `RETREATING`.

Behaviour requirements:

- prefers darkness and the edge of light;
- tracks an isolated or injured target;
- does not charge immediately on detection;
- retreats from strong Heartforge light or sufficient resistance;
- can be escaped without necessarily being killed;
- emits sound or motion cues before attacking.

### Save

Implement a minimal versioned JSON save sufficient for this scene. Use a temporary write followed by replacement. Keep the format simple and documented.

## HUD

Show only:

- Mechromancer integrity;
- Heartforge state;
- collected Scrap;
- one current objective line;
- minimal context prompt;
- optional developer-only AI-state overlay toggled by a key.

Do not add resource rates, minimap, wave counter, machine population, power, or build tabs.

## Tests

Add automated or headless-testable coverage for:

- design data loads;
- Veilstalker cannot enter `ATTACKING` without a valid opportunity;
- Veilstalker is discouraged by Heartforge light;
- Scrapling returns when too far from the Heartforge or player according to its current signal;
- repair cannot complete without enough Scrap;
- repair persists across save/load;
- save file includes a schema version;
- no wave scheduler exists in the First Light scene.

If full Godot test infrastructure is not yet available, add a small headless test runner as part of this task.

## Completion commands

Run and report:

```bash
python scripts/validate_repo.py
```

Also run the project’s Godot headless tests and a headless boot smoke test using the Godot executable available in the environment. Document the exact commands in `README.md`.

## Deliverable report

At completion, provide:

- files changed;
- how to run the scene;
- test commands and results;
- current controls;
- known limitations;
- a short statement confirming that no RTS economy, wave timer, territory system, or hostile robot was added.
