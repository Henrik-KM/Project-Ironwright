# Project Ironwright — First Light 3D

## Purpose

This is the first native Godot 3D implementation of the survival-strategy loop. It is deliberately a vertical slice rather than a claim that the complete 30–100-hour sandbox is finished. The browser prototype remains under `web/` as a fast reference implementation.

## Playable arc

The Mechromancer begins in a dark, ruined urban district with 24 Scrap, a weak automatic pistol, and one Bulwark companion. The pistol does four damage per shot and is inadequate against sustained contact. The Bulwark is the opening combat power and automatically intercepts organic threats.

The first nearby wreck must be salvaged manually. Holding `E` commits the Mechromancer to a multi-second dismantling channel. Movement and pistol fire stop. Noise pulses radiate through the ecology, alert nearby organisms, and can cause a nest to send another creature toward the source. Taking damage interrupts the action, but the noise already emitted is not undone.

The recovered Scrap is enough to return to the Heartforge and manually build the first Scrapper. Fabrication is also a timed, noisy, attack-disabling action. Early robot production is therefore personal and dangerous; there is no production queue and no automatic forge.

After a Scrapper exists, the player can set the global machine focus to Salvage. The autonomy director forms a physical group, selects a wreck, maintains formation, dismantles it, carries the cargo home, and deposits Scrap. The player does not select individual robots, draw routes, or assign escorts.

The player then manually forges a Warden and Pathfinder. With all three roles available, `X` authorizes the North Ruins expedition. Those robots remain real actors in the same world. They traverse the actual streets, slow or stop when formation cohesion breaks, hold when organisms approach, recover the Cognition Core, and physically return.

## Controls

| Input | Action |
|---|---|
| `WASD` | Move the Mechromancer |
| automatic | Fire the weak pistol at the nearest organic enemy in range |
| hold `E` | Salvage a nearby wreck; movement and pistol disabled |
| `E` at Heartforge | Open manual fabrication and class-upgrade menu |
| `1` | Global focus: defend |
| `2` | Global focus: salvage |
| `3` | Global focus: expedition |
| `X` | Authorize North Ruins expedition when roles exist |
| `F` | Follow the active physical machine group |
| `M` | Toggle high command-map camera |
| mouse wheel | Camera distance |
| `F5` / `F9` | Save / load when no remote operation is active |
| `Esc` | Close forge or pause |

Inside the forge menu, `1–3` build Scrapper, Warden, or Pathfinder. `4–6` upgrade those entire robot classes. Level 2 requires Scrap. Level 3 requires additional Scrap and one rare Cognition Core.

## Anti-chore implementation

The player makes only aggregated choices:

- whether to risk a manual action now;
- what robot class to fabricate;
- which global machine focus matters most;
- when the world is ready for a remote expedition;
- which class deserves a permanent upgrade.

Machines handle exact group composition, local positioning, target selection, formation slots, route movement, salvage execution, cargo return, and ordinary defence. The first forge is intentionally manual, but forge automation is reserved for a later progression stage rather than granted at the opening.

## Art implementation

The current runtime combines the original authored Mechromancer glTF asset with original procedural low-poly geometry for the remaining actors and world dressing. It includes:

- authored Mechromancer hood, face/visor, split coat, field pack, shoulder lamp, and weak pistol;
- Bulwark, Scrapper, Warden, and Pathfinder silhouettes;
- chitinous organic enemies with multiple legs, mandibles, and emissive eyes;
- the Heartforge and its manual assembly plate;
- wrecked machinery and live salvage cables;
- ruined buildings, roads, street lamps, vehicle wrecks, rubble, and North Ruins.

These are actual runtime 3D assets and collision structures, not concept images. The Mechromancer asset contract is documented in `game/data/mechromancer_asset_manifest.json`; the remaining procedural actors are designed to be replaced incrementally by authored Blender/GLTF assets without changing the gameplay architecture.

## Known limits

The district is authored and compact. Navigation uses street-aware waypoints and steering rather than a baked citywide navigation mesh. Audio is not yet production-ready. Active remote operations are intentionally required to finish before saving in this slice; actor positions and ecology are otherwise persisted. The next production pass should add authored animation, sound, richer melee reactions, better obstacle avoidance, and persistent serialization of in-flight operations.
