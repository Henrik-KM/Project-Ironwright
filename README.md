# Project Ironwright

![Playable convoy moving through the persistent city](web/screenshots/smoke-convoy.png)

**Project Ironwright** is a single-player survival-strategy game about defending one vulnerable Heartforge in a hostile, organic, post-apocalyptic city. The player begins as a nearly helpless Mechromancer with one crude Scrapling. Machines gradually learn to salvage, repair, defend, cooperate, and conduct expeditions without routine supervision.

The repository now contains a **fully playable first vertical slice**, alongside the long-form game design and Godot production scaffold.

> One home. One hostile city. Machines that learn to carry the burden.

## Play the first version

Requirements: Node.js 22+, Python 3, and a current desktop browser.

```bash
npm run serve
```

Open `http://localhost:8000`, then choose **New world**.

The browser prototype has no package dependencies and does not download runtime assets. All visuals are rendered procedurally on Canvas.

### Controls

| Input | Action |
|---|---|
| `WASD` | Move the Mechromancer |
| Mouse | Aim |
| Left click | Fire the tool arc |
| `Shift` | Emergency dash |
| `E` | Salvage, restore, recover, or authorize the current contextual action |
| `Q` | Switch the one early Scrapling signal |
| `R` | Emergency recall for local machines |
| `F` | Follow or leave the physically travelling expedition |
| `M` | Open the live command map |
| `Tab` | Explain current machine decisions |
| `Esc` | Pause |
| `F5` | Save immediately |

World state also autosaves locally. Save/load retains exact positions, health, motives, route progress, dropped objects, ecology state, and autonomous decision reasons.

## What is playable

The first slice implements one complete survival arc:

1. Leave a weak pool of light to recover the only critical Scrap load.
2. Return to and restore the damaged Heartforge.
3. Observe the Heartforge automatically create routine salvage and defence roles.
4. Choose one meaningful evolution for the Mechromancer, machines, or home.
5. Let autonomous machines perform recurring work without queues or individual orders.
6. Authorize a North Ruins expedition whose robots physically leave the base and traverse the existing city.
7. Follow the convoy at any point or inspect its live positions on the command map.
8. Recover the Cognition Core, including a physical fallback if its carrier is disabled.
9. Survive the causal Cathedral Beast response and reach victory—or lose the only Heartforge.

There are no scheduled waves, hostile robots, power grids, production chains, territory capture, multiple bases, or per-unit loadout chores.

## Full-world simulation

The city is one persistent simulation. Remote missions are not timers or probability rolls. A robot sent to the North Ruins remains an entity with coordinates, health, route progress, a current state, and an explainable reason for its decision. It travels along the same streets the player can cross, can encounter the same organisms, can be followed by the camera, can be disabled at a precise location, and remains there through save/load.

The command map is therefore a view of the world, not a separate strategic layer.

![Live command map showing real machine positions](web/screenshots/smoke-command-map.png)

## Canonical product direction

- One constrained, evolving base centred on the original Heartforge.
- One ordinary stockpiled resource: **Scrap**.
- Organic predators, scavengers, burrowers, parasites, packs, and apex creatures. Enemy robots are outside the design.
- No scheduled-wave main loop. Major incidents are rare and caused by world state or player action.
- No territory claiming, outpost network, supply-line game, or production-chain economy.
- No routine individual robot orders, loadouts, repairs, building placement, or alert clearing.
- Autonomy must permanently remove work as the run grows.
- The eventual principal mode is one sandbox world played over many sessions, with repeated failed worlds expected before the first victory.

The complete non-negotiable contract is in [`docs/DESIGN_LOCKS.md`](docs/DESIGN_LOCKS.md).

## Implementation structure

The playable slice is a dependency-free browser reference implementation:

```text
web/
├── index.html
├── styles.css
├── src/
│   ├── sim.mjs      # deterministic persistent-world simulation
│   └── game.mjs     # input, rendering, HUD, command map, save/load
├── tests/
│   └── sim.test.mjs
└── screenshots/
```

The production-engine scaffold remains under `game/` and targets Godot 4.7.1-compatible APIs. The browser build exists to prove and iterate the survival/autonomy loop before spending heavily on 3D assets and a production port.

See [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md) for exact scope and known limitations.

## Validate

```bash
npm run validate
```

Validation covers JavaScript syntax, simulation behaviour, physical expedition movement, save/load equivalence, causal ecology, design-contract data, documentation links, the Godot scaffold, and repository checksums.

## Start here for further development

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/DESIGN_LOCKS.md`](docs/DESIGN_LOCKS.md)
3. [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md)
4. [`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md)
5. [`docs/AUTONOMY_AND_ANTI_CHORE.md`](docs/AUTONOMY_AND_ANTI_CHORE.md)
6. [`docs/ENEMY_ECOLOGY.md`](docs/ENEMY_ECOLOGY.md)
7. [`docs/PRODUCTION_ROADMAP.md`](docs/PRODUCTION_ROADMAP.md)

## Current limitations

This is a complete first playable version, not the full 30–100-hour game. The city is authored and compact; art is procedural rather than production 3D; sound is limited to generated interface tones; progression contains one major evolution choice; and the ecology represents the intended architecture at small scale. The implementation is deliberately narrow enough to test whether the core experience is worth expanding.

No third-party runtime art, audio, or code assets are included. Concept images under `docs/concept-art/` remain visual references rather than game assets.
