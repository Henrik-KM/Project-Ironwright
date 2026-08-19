# Project Ironwright

**Project Ironwright** is a survival-strategy game about defending one vulnerable Heartforge in a hostile, organic, post-apocalyptic city. You begin as a nearly helpless Mechromancer with one crude Scrapling. Machines gradually learn to salvage, repair, defend, cooperate, and conduct expeditions without routine supervision.

This repository contains the playable **First Light** browser prototype, the Godot production scaffold, the complete design documents, and the concept-art library.

> One home. One hostile city. Machines that learn to carry the burden.

## Play First Light

Requirements: Python 3 and a current desktop browser. Node.js 22+ is required only for validation.

From the repository root:

```bash
npm run serve
```

Open `http://localhost:8000`, then select **New World**.

The browser build has no package dependencies and downloads no runtime assets. Its visuals are rendered procedurally on Canvas.

## Controls

| Input | Action |
|---|---|
| `WASD` / arrows | Move the Mechromancer |
| Automatic | Shoot the nearest organic enemy in range |
| Mouse | Orient when no enemy is in firing range |
| `Shift` or `Space` | Emergency evade |
| `E` | Salvage, restore, evolve, recover, or install the contextual objective |
| `X` | Authorize the North Ruins expedition when ready |
| `R` | Emergency recall for local machines |
| `F` | Cycle between player, Heartforge, and physical-expedition cameras |
| `M` | Open the live command map |
| `Tab` | Explain current machine decisions |
| `H` | Show controls |
| `F5` / `F9` | Save / load |
| `Esc` | Pause or close an interface |

The Mechromancer now fires automatically. Combat does not require constant clicking or individual target micro-management: the simulation selects the nearest valid enemy within the current firing range, displays that target, and fires according to weapon cooldown.

## Playable arc

1. Leave the weak Heartforge light to recover critical Scrap.
2. Return and restore the only permanent base.
3. Watch machines take over routine salvage and local defence.
4. Choose one consequential evolution: Mechromancer, machines, or Heartforge.
5. Authorize a North Ruins expedition.
6. Follow the robots as they physically cross the persistent city, reach the ruins, recover the Cognition Core, and return through the same streets.
7. Install the core and survive the causally triggered Cathedral Beast attack.

The city remains one simulation. Expeditions are not timers or probability rolls: every robot retains coordinates, health, state, cargo, route progress, and a player-readable reason for its current decision. The command map is a view of those physical entities, not a separate strategic layer.

There are no scheduled waves, hostile robots, power grids, production chains, territorial capture, multiple bases, individual loadouts, or recurring production-queue maintenance.

## Browser implementation

```text
web/
├── index.html
├── styles.css
├── src/
│   └── loader.mjs
├── source/
│   ├── sim/
│   │   ├── manifest.json
│   │   └── part-*.txt
│   └── game/
│       ├── manifest.json
│       └── part-*.txt
└── tests/
    ├── browser_smoke.py
    ├── sim.test.mjs
    └── source_loader.mjs
```

The segmented source layout keeps individual Git objects modest while still assembling normal JavaScript modules at launch. All files referenced by both manifests are committed and verified by the smoke test.

## Validate

```bash
npm run validate
```

Validation checks:

- browser launch files and every segmented source part exist and are non-empty;
- assembled simulation and presentation modules parse;
- automatic targeting fires at the nearest in-range enemy and remains silent out of range;
- enemies are organic and no scheduled-wave state exists;
- routine gathering becomes autonomous after Heartforge restoration;
- expedition robots travel physically to the North Ruins and back;
- save/load preserves remote positions and decision reasons;
- the Cathedral Beast appears only after the returned core is installed;
- Scrap remains the only ordinary stockpiled resource;
- repository design contracts remain valid.

## Product contract

Read these before expanding the game:

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/DESIGN_LOCKS.md`](docs/DESIGN_LOCKS.md)
3. [`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md)
4. [`docs/AUTONOMY_AND_ANTI_CHORE.md`](docs/AUTONOMY_AND_ANTI_CHORE.md)
5. [`docs/ENEMY_ECOLOGY.md`](docs/ENEMY_ECOLOGY.md)

The browser prototype is a playable reference implementation, not the final 30–100-hour production game. The production-engine scaffold remains under `game/` and targets Godot 4.7.1-compatible APIs.
