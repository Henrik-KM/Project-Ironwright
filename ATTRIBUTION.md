# Attribution and asset provenance

Project Ironwright 1.0.0-rc.1 does not currently include third-party runtime art, music, ambience, sound effects, fonts, models, animations, shaders, or texture packs.

## Original release asset library

The committed files under:

```text
game/assets/release/textures/
game/assets/release/audio/
```

are original assets generated specifically for Project Ironwright from the reviewable source script:

```text
scripts/generate_release_assets.py
```

The source generator uses only Python's standard library and deterministic mathematical/noise synthesis. It does not sample, remix, download, trace, or embed third-party audiovisual material.

Generated texture families:

- wet asphalt;
- ruined brick;
- wet concrete;
- brushed machine metal;
- oxidized steel;
- grime and damage;
- moss and post-collapse growth;
- organic chitin;
- living membrane.

Generated audio families:

- city ambience;
- Heartforge sanctuary ambience;
- Embers, Pressure, and Sovereignty adaptive music layers;
- weak pistol;
- salvage cutting;
- forge operation;
- organic impact;
- machine report;
- major danger;
- interface confirmation;
- first-victory cue.

These assets are part of the Project Ironwright repository and are governed by the repository owner's chosen project licensing and distribution terms. No separate third-party attribution is required for them.

## Procedural runtime geometry and animation

The Mechromancer, machines, organic creatures, Heartforge, outposts, environment dressing, particles, secondary mechanisms, and current animation layers are authored in repository code using Godot geometry, materials, particles, transforms, and animation logic. They do not contain imported third-party model or motion data.

## Concept art

Images under `concept art/` and `docs/concept-art/` are design references. They are not loaded by the release runtime and are not represented as production-ready game assets.

## Engine and tooling

Project Ironwright is built with Godot Engine. Godot's own license and third-party notices are distributed according to the engine's packaging requirements; the project does not claim ownership of the engine.

GitHub Actions used for validation and packaging are development infrastructure and are not embedded as runtime game content.

## Future third-party additions

Any future externally sourced runtime asset must be recorded here before merge with:

- exact asset or pack name;
- creator and official source;
- license and date obtained;
- original license-file location;
- modifications;
- whether redistribution is permitted;
- exact repository paths using the asset.

No future asset may be introduced merely because it is convenient if it conflicts with the organic-enemy rule, the grounded-to-futuristic art progression, or the commercial distribution rights required by the project.
