# First Playable Implementation Status

## Status

The `web/` directory contains the first complete playable vertical slice of Project Ironwright. It is a dependency-free browser implementation used to validate the survival, autonomy, physical-world, and anti-chore principles before a production-scale Godot port.

## Implemented player arc

A new world begins with one damaged Heartforge, one dependent Scrapling, one critical wreck, and organic organisms already moving elsewhere in the city. The player can complete the following uninterrupted arc:

1. Recover the critical Scrap load and return it physically to the Heartforge.
2. Restore the Heartforge.
3. Survive while it automatically fabricates a Scrapper and Sentry.
4. Select one evolution: Quiet Minds, Iron Shell, or Live Coil.
5. Observe autonomous salvage, defence, retreat, repair, and replacement behaviour.
6. Authorize a machine-proposed North Ruins expedition.
7. Follow the real convoy through the world or observe it on the live command map.
8. Recover a Cognition Core from the North Ruins.
9. Handle machine casualties and physically recover a dropped core when necessary.
10. Defeat the Cathedral Beast before it destroys the Heartforge.
11. Reach a victory or failure screen and retain the world through save/load.

## Persistent-world contract

The prototype has no abstract expedition simulation. The following objects remain in one world state at all times:

- the Mechromancer;
- every active or disabled friendly machine;
- every living organic creature;
- nests and their biomass/activity state;
- wrecks and remaining Scrap;
- the Cognition Core and its carrier or dropped position;
- projectiles and short-lived effects while active;
- the Heartforge;
- the North Ruins;
- the expedition route and each robot’s route index.

Remote robots continue making decisions and moving when they are outside the camera. Save/load preserves their exact positions and autonomous reasons.

## Autonomy demonstrated

The slice intentionally teaches only a small amount of manual work before removing it:

- The player performs the first critical salvage action; the Scrapper later performs routine salvage without orders.
- The player initially protects the weak base; the Sentry and Heartforge later resolve routine perimeter threats.
- The player chooses whether to authorize an expedition; machines select roles, route, spacing, retreat, and combat responses.
- Escorts regroup when convoy cohesion falls below a learned threshold.
- The core remains physically recoverable if autonomy fails.

There is no per-unit command interface, production queue, worker allocation screen, power budget, or construction placement loop.

## Organic pressure demonstrated

Pressure is produced by individual organisms and persistent nests. Nests accumulate biomass, react to disturbance, and create organisms only when ecological predicates are satisfied. The Cathedral Beast appears only after the Cognition Core is disturbed. There is no wave counter or recurring wave scheduler.

## Technical implementation

- Deterministic fixed-step simulation in `web/src/sim.mjs`.
- Canvas rendering and browser input in `web/src/game.mjs`.
- Versioned local save snapshots.
- Bounded event logs, notifications, particles, and dead-organism retention.
- Explainable robot and enemy state reasons.
- Live command map derived from current entity positions.
- Node test suite using the built-in test runner.
- No runtime dependencies and no external assets.

## Known limitations

- The visual layer is a polished greybox rendered from geometric primitives, not final 3D art.
- The world is one compact authored urban district rather than the eventual large sandbox.
- Only one expedition objective and one apex event are implemented.
- Robot learning is represented through unlocked deterministic behaviours rather than a broader long-run adaptation system.
- Browser local storage is suitable for prototype saves, not the eventual transactional multi-backup save format.
- The Godot directory remains a production scaffold; gameplay currently runs from `web/`.

## Definition of completion for this milestone

The milestone is accepted when:

- a player can start, win, lose, save, and resume;
- all enemies are organic;
- the Heartforge is the only permanent base;
- Scrap is the only ordinary resource;
- the expedition moves physically and can be followed;
- remote positions survive save/load;
- autonomy removes recurring work;
- major pressure is causal rather than scheduled;
- `npm run validate` passes.
