# Project Ironwright

**Project Ironwright** is a single-player survival-strategy game about defending one vulnerable Heartforge in a hostile organic post-apocalyptic city. The player begins as a weak Mechromancer with a poor automatic pistol and one indispensable robot companion. Over a long run, machines learn to salvage, defend, repair and conduct expeditions without routine supervision.

> One home. One hostile city. Machines that learn to carry the burden.

## Play the native 3D version

The Godot build is the primary runtime. Install Godot 4.7.1 and place `godot` or `godot4` on your `PATH`.

Windows:

```text
PLAY_3D.bat
```

Linux or macOS:

```bash
./PLAY_3D.sh
```

Direct launch:

```bash
godot --path game
```

## Native controls

| Input | Action |
|---|---|
| `WASD` | Move the Mechromancer |
| Automatic | Fire the weak pistol at the nearest organic enemy in range |
| Hold `E` at wreckage | Perform loud manual salvage; movement and pistol are disabled |
| `E` at the Heartforge | Open manual fabrication and upgrades |
| `1` / `2` / `3` | Set machine focus to defend, salvage or expedition |
| `X` | Authorize the North Ruins expedition when the required robots exist |
| `F` | Follow the active physical robot group |
| `M` | Toggle the live command-map camera |
| Mouse wheel | Adjust tactical camera height |
| `F5` / `F9` | Save / load |
| `Esc` | Close an interface or pause |

## Playable native arc

1. Leave the Heartforge light while depending on the Bulwark companion.
2. Hold `E` at a wreck to salvage Scrap. Salvage takes time, disables the pistol, creates visible and audible disturbance, and attracts organic enemies.
3. Return to the Heartforge and manually fabricate a Scrapper while the companion protects you.
4. Set macro salvage focus. A coordinated robot group selects a wreck, physically travels there, salvages and physically returns.
5. Manually fabricate a Warden and Pathfinder.
6. Authorize the North Ruins expedition. The machines choose formation and route execution, remain cohesive, recover a Cognition Core and return through the same city.

## Aesthetic direction

The native build now uses a focused **beautiful, intense and cozy** presentation pass:

- readable blue-hour lighting rather than crushed near-black darkness;
- cool city ambience contrasted with warm Heartforge practical lights;
- ACES tonemapping, controlled fog, puddles and atmospheric depth;
- an inhabited Heartforge camp with tools, string lights, workbench clutter, crates, barrels, a bench, blanket, kettle, embers and smoke;
- lit windows, damaged shop signs, street furniture, weeds and distant organic growth;
- role-readable silhouette detail for the Mechromancer, robots and enemies;
- procedural walk cycles, breathing, recoil, channel poses, robot gait and organic locomotion;
- muzzle flashes, impact sparks, organic death effects, visible noise pulses and subtle camera response;
- a calmer cinematic HUD with a warm sanctuary status and damage vignette.

All current runtime art is original procedural Godot geometry and material work. It remains a production placeholder for later authored Blender/glTF models, but it is now designed to communicate the intended mood rather than merely prove systems.

See [`docs/AESTHETIC_OVERHAUL.md`](docs/AESTHETIC_OVERHAUL.md) for the implementation contract.

## Full-world simulation

Remote work is not represented by detached timers. Robots, enemies, wrecks and objectives retain physical positions in one simulation.

Expeditions and salvage groups:

- leave the Heartforge as real actors;
- travel through the same streets as the player;
- slow or stop when formation cohesion breaks;
- react locally to organic enemies;
- can be followed by the camera;
- return physically before cargo or objectives are credited.

## Browser reference prototype

The earlier deterministic 2D reference remains under `web/`:

```bash
npm run serve
```

Open `http://localhost:8000` and choose **New World**. It remains useful for fast simulation testing, while the Godot project is the production direction.

## Validate

Repository, browser and design-contract validation:

```bash
npm run validate
python3 scripts/validate_aesthetic.py
```

Native Godot validation:

```bash
godot --headless --path game --editor --quit
godot --headless --path game --script res://tests/test_runner.gd
godot --headless --path game --script res://tests/aesthetic_test_runner.gd
```

GitHub Actions runs both validation tracks on every push and pull request.

## Product contract

Read these before expanding the game:

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/DESIGN_LOCKS.md`](docs/DESIGN_LOCKS.md)
3. [`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md)
4. [`docs/AUTONOMY_AND_ANTI_CHORE.md`](docs/AUTONOMY_AND_ANTI_CHORE.md)
5. [`docs/ENEMY_ECOLOGY.md`](docs/ENEMY_ECOLOGY.md)
6. [`docs/AESTHETIC_OVERHAUL.md`](docs/AESTHETIC_OVERHAUL.md)
7. [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md)

The current native build is a playable systems-and-presentation vertical slice, not the final 30–100-hour production game.
