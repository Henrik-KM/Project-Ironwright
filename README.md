# Project Ironwright

**Project Ironwright** is a single-player, long-form survival-strategy sandbox about defending one vulnerable Heartforge in a hostile organic post-apocalyptic town.

The player begins as a weak Mechromancer with a poor automatic pistol and one indispensable Bulwark companion. Early salvage and robot fabrication are loud, timed commitments that disable attack. Over a run lasting many sessions, machines learn to salvage, defend, scout, repair, escort, construct, haul, rebuild, and conduct expeditions without routine supervision.

> One primary home. One hostile town. Machines that learn to carry the burden.

The current Project Ironwright conversation with Henrik is the highest product authority. Repository contracts must be updated when an explicit current instruction changes an older direction.

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

The current runtime uses original procedural low-poly geometry, a readable blue-hour ruined-town presentation, warm Heartforge lighting, procedural animation, particles, combat feedback, world-space objective cues, and a cinematic HUD. These are production-facing placeholders for a later authored Blender/glTF asset pass.

## Native controls

| Input | Action |
|---|---|
| `WASD` | Move the Mechromancer |
| Automatic | Fire the weak pistol at the nearest organic enemy in range |
| Hold `E` at wreckage | Perform loud manual salvage; movement and pistol are disabled |
| `E` at the Heartforge | Open manual fabrication and class upgrades |
| `1` / `2` / `3` | Set machine focus to defend, salvage, or expedition |
| `X` | Authorize the North Ruins expedition when the required robot classes exist |
| `T` | Open consequential machine/doctrine evolution choices |
| `O` | Open autonomous outpost projects after Heartforge tier 2 and site discovery |
| Left/right in strategic UI | Change technology or discovered site |
| `,` / `.` in outpost UI | Change proposed outpost role |
| `Enter` / `Space` | Authorize the selected strategic choice |
| `B` / `U` in outpost UI | Authorize build or upgrade |
| `F` | Follow the active physical robot group |
| `M` | Toggle the high command-map camera |
| Mouse wheel | Adjust tactical camera height |
| `F5` / `F9` | Save / load |
| `Esc` | Close interface or pause |

## First-session guidance and HUD

The opening now identifies the concrete next interaction without making the world less threatening.

- An amber beacon marks a real nearby municipal wreck.
- A pulsing ground route leads from the Mechromancer to that wreck.
- The objective includes approximate distance and cardinal direction.
- The marker states `HOLD E · LOUD`.
- The immediate prompt warns that the pistol will be disabled and organisms will be alerted.
- After salvaging, cyan guidance leads back to the Heartforge and names the first Scrapper fabrication action.
- Guidance continues through preparation of the first Warden and Pathfinder, then removes itself once the player understands the physical loop.

HUD information is separated by function:

- objective at top-left;
- contextual interaction at bottom-centre;
- large resources, focus and operation status at top-right;
- transient machine reports below the resource panel;
- health at bottom-left;
- macro controls at bottom-right.

The forge and strategic interfaces are responsive centred modals with safe margins and scrollable content. Empty evolution states hide meaningless navigation and say clearly that no decision is currently available.

See [`docs/FIRST_SESSION_UX.md`](docs/FIRST_SESSION_UX.md).

## Current playable production arc

The repository has moved beyond a self-contained prototype ending. The current connected arc is:

1. Follow the visible amber route out of the weak Heartforge light while depending on the Bulwark.
2. Hold `E` at the highlighted wreck. Salvage takes time, disables the pistol, emits repeated noise, and attracts organisms.
3. Follow cyan guidance home and manually fabricate a Scrapper.
4. Set a macro salvage focus and let a coordinated group physically recover Scrap.
5. Manually fabricate a Warden and Pathfinder.
6. Authorize the North Ruins expedition and follow the group through the persistent town.
7. Recover a Cognition Core and discover fixed viable outpost foundations.
8. Authorize Group Coordination through the evolution interface.
9. Manually evolve the Heartforge to tier 2 at the forge.
10. Manually fabricate an Engineer.
11. Choose a discovered site and broad outpost role.
12. Watch an Engineer, Warden escort, and optional Pathfinder physically travel, construct, and return.
13. Let the outpost operate, repair itself, store resources, defend, scout, or repair remote machines according to its role.
14. Physically haul resource output to the Heartforge.
15. Lose and automatically rebuild an outpost through another escorted Engineer operation.
16. Upgrade an outpost through a real protected construction journey.

The game continues after this foundation milestone. The North Ruins are an early progression event rather than a forced ending.

## Full-game foundation systems

### Persistent progression

The native game has stable progression phases, Heartforge tiers, technology prerequisites, effects, and save state. The first implemented path includes Task Memory, Group Coordination, Heartforge Tier II, Field Engineering, and four outpost roles.

### Engineer robot

Engineer frames are manually fabricated after the relevant Heartforge evolution. They build, upgrade, and rebuild outposts under escort. The player never selects individual builders.

### Autonomous outposts

Outposts are bounded support installations on fixed sites discovered through excursions. They do not claim territory and are not secondary player bases.

- **Recovery Post:** gathers local Scrap into forward storage; a protected hauler group physically returns it.
- **Proxy Defence Post:** automatically attacks nearby organic threats.
- **Early Warning Post:** reports organic contacts around its sensor envelope.
- **Field Repair Post:** repairs friendly machines passing through its service radius.

Machines handle team composition, route execution, formation cohesion, construction, upgrades, local action, routine repair, hauling, and rebuilding. The player chooses only site, role, technology, and authorization.

### Full-world operations

Salvage groups, expeditions, construction teams, upgrade teams, rebuild teams, and haul convoys retain real positions. Cargo is credited only after physical return. Groups share pace, slow when cohesion breaks, and hold while escorts address nearby threats.

### Organic pressure

Enemies remain organic and can discover and attack remote outposts. Construction and salvage create noise. There is no scheduled recurring-wave main loop.

## Full roadmap

The complete production sequence—from the current foundation through persistent regions, reduced-detail simulation, autonomous machine society, adaptive Heartforge construction, deep ecology, midgame, late machine war, endgame, production assets, alpha, beta, and launch—is documented in:

[`docs/FULL_GAME_ROADMAP.md`](docs/FULL_GAME_ROADMAP.md)

The roadmap is a production order with measurable gates, not a claim that the present repository already contains the final 30–100-hour content set.

## Browser reference prototype

The deterministic browser prototype remains available as a reference implementation and fast simulation testbed:

```bash
npm run serve
```

Open `http://localhost:8000` and choose **New World**.

## Validate

Repository, browser, and current product contracts:

```bash
npm run validate
python3 scripts/validate_aesthetic.py
```

Native Godot validation:

```bash
godot --headless --path game --editor --quit
godot --headless --path game --script res://tests/test_runner.gd
godot --headless --path game --script res://tests/aesthetic_test_runner.gd
godot --headless --path game --script res://tests/full_game_test_runner.gd
godot --headless --path game --script res://tests/first_session_ux_test_runner.gd
```

GitHub Actions runs all validation tracks on pushes and pull requests.

The first-session regression test verifies:

- the full forge fits inside an 800×520 viewport;
- tall forge content remains scrollable;
- objective and notification panels never overlap;
- only three transient machine reports can remain visible;
- reports expire rather than burying objectives;
- resource, focus and operation text have explicit spacing;
- empty evolution screens hide Previous and Next;
- a real wreck is marked from the opening frame;
- route lights and the `HOLD E` interaction are visible;
- guidance returns the player to the Heartforge after first salvage.

## Product contracts

Read these before changing gameplay:

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/DESIGN_LOCKS.md`](docs/DESIGN_LOCKS.md)
3. [`docs/FULL_GAME_ROADMAP.md`](docs/FULL_GAME_ROADMAP.md)
4. [`docs/FIRST_SESSION_UX.md`](docs/FIRST_SESSION_UX.md)
5. [`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md)
6. [`docs/AUTONOMY_AND_ANTI_CHORE.md`](docs/AUTONOMY_AND_ANTI_CHORE.md)
7. [`docs/ENEMY_ECOLOGY.md`](docs/ENEMY_ECOLOGY.md)
8. [`docs/AESTHETIC_OVERHAUL.md`](docs/AESTHETIC_OVERHAUL.md)

## Current status

Version `0.5.0` is the **guided first-session production milestone** on top of the full-game foundation. It fixes critical onboarding and HUD readability defects while adding a reusable world-space guidance system. The next major development target remains the larger persistent town with active/reduced-detail region simulation, deeper ecology, broader technology content, and longer autonomous operations.
