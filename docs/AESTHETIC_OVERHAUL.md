# Native aesthetic-overhaul contract

## Purpose

The native Project Ironwright slice must be beautiful, intense and cozy without sacrificing gameplay readability or the frightening opening. Darkness is atmosphere, not a visibility tax.

The presentation should communicate one central contrast:

> The ruined city is cold, wet and biologically hostile. The Heartforge is a small warm machine refuge that feels increasingly inhabited.

## Lighting hierarchy

The world uses readable blue hour rather than pitch black night.

- Cool sky and moonlight establish the hostile exterior.
- Warm orange practical lights identify sanctuary, work and human-scale life.
- Cyan machine emissives communicate friendly technology and intent.
- Red organic emissives remain limited to hostile life and threat.
- Fog shapes depth but does not hide nearby navigable streets or actors.
- Exposure is controlled through ACES tonemapping rather than simply raising every light.

## Heartforge sanctuary

The immediate Heartforge area must read as an improvised home and workshop, not an isolated debug prop. The current procedural pass contains:

- a workshop canopy and posts;
- workbench, tool wall and hanging tools;
- crates, barrels and exposed materials;
- a small bench, folded blanket and kettle;
- string lights and local practical lights;
- wet pavement and puddles;
- forge embers and smoke;
- lighting response to Heartforge integrity.

Later authored assets should preserve this lived-in density and warm composition.

## Ruined city

The city remains grounded and relatively low-tech in the opening. It gains visual richness through ordinary urban remnants rather than futuristic megastructures:

- wet streets and reflected practical light;
- lit or flickering windows;
- damaged storefront signs;
- benches, bins, wrecks and municipal clutter;
- weeds and opportunistic vegetation;
- distant organic growth near nest territories;
- suspended dust, drizzle or atmospheric motes.

Clutter must leave important routes readable from the high-angle camera.

## Actor presentation

The procedural models remain placeholders but require strong role readability.

### Mechromancer

- coat, hood, field pack and shoulder light;
- clearly visible weak pistol;
- breathing, walk cycle, coat motion, recoil and exposed work pose;
- compact silhouette that remains readable beside machines.

### Friendly robots

- shared machine family language;
- role-specific armor, tools, optics and cargo forms;
- walking gait, foot lift, body weight, sensor movement and recoil;
- warm or cyan friendly lights distinct from organic enemies.

### Organic enemies

- asymmetrical chitin, flesh, spines and tails;
- twitching idle movement and multi-leg locomotion;
- head probing, mandible movement and aggressive acceleration;
- red organic emissives used sparingly as threat cues.

## Feedback and VFX

The presentation layer may improve feel without changing simulation outcomes.

Implemented feedback includes:

- muzzle flashes and projectile impacts;
- sparks during salvage and fabrication;
- organic death bursts;
- visible expanding noise pulses;
- subtle camera impact;
- actor hit reactions;
- persistent forge embers and smoke;
- HUD damage flash and sanctuary-integrity status.

Effects must remain restrained enough for long sessions and large machine populations.

## UI

The UI supports survival strategy rather than an RTS dashboard.

- Existing information is preserved, but panels are quieter and more translucent.
- Warm/cool accents communicate sanctuary and machine state.
- The objective, current interaction and exceptional machine activity remain prominent.
- The late game must not add permanent rate charts, worker lists or per-unit controls.
- Atmospheric vignette and damage feedback may frame the scene but must not obscure play.

## Technical architecture

The aesthetic pass deliberately wraps the existing simulation rather than mixing presentation into autonomy logic.

```text
IronwrightBeautifulWorld3D
├── IronwrightWorld3D simulation and gameplay
└── AestheticDirector3D
    ├── SanctuaryDecorator3D
    ├── UrbanDecorator3D
    └── PresentationFeedback3D
        └── ProceduralAnimator3D per actor
```

This separation allows authored Blender/glTF assets and animation libraries to replace procedural geometry later without rewriting the game loop.

## Acceptance criteria

The aesthetic pass is acceptable when:

1. nearby streets and actors are readable without increasing global brightness to daylight;
2. the Heartforge reads immediately as warmer and safer than the city;
3. the scene contains deliberate practical lighting rather than one global ambient value;
4. player, robot and enemy movement no longer looks completely rigid;
5. firing, damage, salvage and noise have visible response;
6. the HUD feels like a game interface rather than debug output;
7. the existing gameplay and deterministic tests continue to pass.
