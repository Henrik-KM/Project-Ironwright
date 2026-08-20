# Project Ironwright

**Project Ironwright** is a single-player, long-form survival-strategy sandbox about defending one vulnerable Heartforge in a hostile organic post-apocalyptic town.

The player begins as a weak Mechromancer with a poor automatic pistol and one indispensable Bulwark companion. Early salvage and robot fabrication are loud, timed commitments that disable attack. Over a run lasting many sessions, machines learn to salvage, defend, scout, repair, escort, construct, haul, rebuild, replace ordinary losses, and conduct long-range operations without routine supervision.

> One primary home. One hostile town. Machines that learn to carry the burden.

The current Project Ironwright conversation with Henrik is the highest product authority. Repository contracts must be updated when a current explicit instruction changes an older direction.

## Current status

Version **0.6.0** is a complete end-to-end systemic alpha.

A run can now progress from the frightening first salvage through:

- the first autonomous robot loop;
- the North Ruins expedition;
- Heartforge tiers II–V;
- autonomous outposts;
- seven persistent town regions;
- physical long-range operations;
- unique biological components;
- autonomous ordinary robot replacement;
- continuous regional organic pressure and migration;
- two player-triggered final protocols;
- a causal final crisis;
- first victory.

This is game-complete in systemic structure, not yet commercially content-complete. Final authored assets, audio, animation, performance scaling, save migration, accessibility, controller support, balance, narrative breadth, localization, and external playtesting remain on the roadmap.

See [`docs/COMPLETE_GAME_ALPHA.md`](docs/COMPLETE_GAME_ALPHA.md) and [`docs/FULL_GAME_ROADMAP.md`](docs/FULL_GAME_ROADMAP.md).

## Run the native Godot game

Install Godot 4.7.1 and place `godot` or `godot4` on `PATH`.

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

The runtime uses an original authored Mechromancer glTF asset alongside procedural low-poly robot and organic placeholder geometry, a readable blue-hour ruined-town presentation, warm Heartforge lighting, typed player animation feedback, particles, combat feedback, world-space objective cues, and cinematic modal interfaces. The remaining procedural actors are production-facing placeholders for later authored asset passes.

## Controls

| Input | Action |
|---|---|
| `WASD` | Move the Mechromancer |
| Automatic | Fire the weak pistol at the nearest organic enemy in range |
| Hold `E` at wreckage | Loud manual salvage; movement and pistol are disabled |
| `E` at the Heartforge | Manual fabrication, class upgrades, and Heartforge evolution |
| `1` / `2` / `3` | Machine focus: defend, salvage, expedition |
| `X` | Authorize the first North Ruins expedition |
| `T` | Major technology, doctrine, and ending research |
| `O` | Autonomous outpost projects |
| `P` | Long-range physical operations |
| `V` | Final protocols |
| Left/right | Change the selected strategic option |
| `,` / `.` | Change proposed outpost role |
| Enter/Space | Authorize the selected strategic choice |
| `B` / `U` | Build or upgrade the selected outpost project |
| `F` | Follow the active physical machine group |
| `M` | Command-map camera |
| Mouse wheel | Adjust tactical camera height |
| `F5` / `F9` | Save / load |
| `Esc` | Close an interface or pause |

## Complete connected run

### Opening: dependence

1. Follow the amber world route to a real salvage wreck.
2. Hold `E`; the pistol goes offline and the noise attracts organisms.
3. Depend on the Bulwark to survive.
4. Return along the cyan route and manually build the first Scrapper.
5. Delegate routine local salvage.
6. Build a Warden and Pathfinder.
7. Authorize the North Ruins expedition and follow the group physically.

### Network: autonomous support

8. Recover the first Cognition Core.
9. Evolve the Heartforge to tier 2.
10. Build an Engineer.
11. Choose a discovered fixed site and broad outpost role.
12. Machines choose the Engineer, escorts, route, formation, construction, repair, hauling, and rebuilding.
13. Use Recovery, Defence, Scout, and Repair posts without managing workers, power, queues, ammunition, or supply lines.

### Frontier: long-range operations

14. Press `P` to survey the West Grid.
15. Evolve the Heartforge to tier 3.
16. Research Forge Assistance so ordinary robot replacement becomes autonomous.
17. Recover the Vital Membrane from the Flood Market.
18. Maintain two support posts and silence the Cathedral Brood.
19. Evolve the Heartforge to tier 4.
20. Excavate the Genome Prism from the Buried Laboratories.
21. Maintain three support posts and map the Root Cistern.
22. Evolve the Heartforge to tier 5.

Every strategic operation uses a real coordinated group. Rewards remain at the objective until the group physically returns.

### Endgame: deliberate final crisis

23. Research Severance, Containment, or both through `T`.
24. Optionally lure away the Cistern Apex to reduce final pressure.
25. Press `V` and deliberately initiate one final protocol.
26. Defend the Heartforge while regional organic pressure converges causally.
27. Complete the protocol and achieve first victory.

There is no recurring numbered-wave main loop. The final large response exists because the player knowingly initiated an irreversible process.

## Persistent world and ecology

The complete alpha contains seven physical regions:

- Heartforge District;
- North Ruins;
- West Grid;
- Flood Market;
- Cathedral Quarter;
- Buried Laboratories;
- Root Cistern.

Regions retain discovery, pressure, suppression, routes, and physical landmarks. Organic populations respond continuously to local ecological capacity, noise, operations, construction, kills, and suppression. High-pressure regions can produce migrations into connecting streets without a wave countdown.

The hostile roster remains wholly organic and now includes Skitterlings, Razorhounds, Veilstalkers, Burrowers, Sporecasters, Broodmasses, and Apex organisms.

## Machine society

After Forge Assistance, ordinary missing frames are replaced automatically according to a broad Heartforge-tier composition. There is no maintained production queue.

The machine society explains why it fabricated a replacement, spends Scrap, creates causal noise, and returns the new unit to the existing autonomy system. The player retains strategic choices and exceptional interventions rather than routine production work.

## Save state

The transitional alpha save retains:

- base world actors and positions;
- progression and Heartforge tier;
- outpost discovery, role, tier, integrity, destruction, and stored Scrap;
- region discovery, pressure, and suppression;
- completed long-range operations;
- unique biological components;
- autonomous replacement state;
- strategic ecology state;
- active or completed final protocol;
- continuity use and first victory.

Active long-range operations still defer saving. A later production milestone consolidates the transitional files into one transactional, versioned save with migration and rotating backups.

## Browser reference prototype

The deterministic browser build remains available for fast simulation regression:

```bash
npm run serve
```

Open `http://localhost:8000`.

## Validation

Repository and browser contracts:

```bash
npm run validate
python3 scripts/validate_aesthetic.py
```

Native Godot suites:

```bash
godot --headless --path game --editor --quit
godot --headless --path game --script res://tests/test_runner.gd
godot --headless --path game --script res://tests/aesthetic_test_runner.gd
godot --headless --path game --script res://tests/full_game_test_runner.gd
godot --headless --path game --script res://tests/first_session_ux_test_runner.gd
godot --headless --path game --script res://tests/complete_game_test_runner.gd
godot --headless --path game --script res://tests/persistence_test_runner.gd
```

The final suite executes an accelerated but real start-to-victory systemic path, including Heartforge tiers II–V, physical operations, components, autonomous replacement, region suppression, Root Cistern discovery, final-protocol initiation, victory, and save-state restoration.

## Canonical contracts

Read before changing gameplay:

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/DESIGN_LOCKS.md`](docs/DESIGN_LOCKS.md)
3. [`docs/COMPLETE_GAME_ALPHA.md`](docs/COMPLETE_GAME_ALPHA.md)
4. [`docs/FULL_GAME_ROADMAP.md`](docs/FULL_GAME_ROADMAP.md)
5. [`docs/FIRST_SESSION_UX.md`](docs/FIRST_SESSION_UX.md)
6. [`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md)
7. [`docs/AUTONOMY_AND_ANTI_CHORE.md`](docs/AUTONOMY_AND_ANTI_CHORE.md)
8. [`docs/ENEMY_ECOLOGY.md`](docs/ENEMY_ECOLOGY.md)
9. [`docs/AESTHETIC_OVERHAUL.md`](docs/AESTHETIC_OVERHAUL.md)
