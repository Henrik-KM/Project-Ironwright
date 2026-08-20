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
- high-definition pressure vessels, service gauges, a routed coolant manifold,
  rear service rail and warm/cool practical lights that make maintenance work
  legible around the forge;
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
- persistent region landmarks use beveled ruin shells, layered window frames,
  roof caps and identity-specific industrial, commercial, research, nest and
  endgame details rather than one primitive block per district.
- the systemic city grid carries a shared curb and facade-edge kit, while
  vehicle wrecks use layered glass, wheel and body treatment without changing
  their collision or salvage contracts.
- persistent archive, tenement, greenhouse, waterfront, rail and observatory
  regions now carry their own structural landmark signatures instead of
  falling back to generic urban ruin geometry.
- each non-sanctuary region now receives a discovery-driven encounter vignette:
  archive records, substation tanks, tenement laundry, greenhouse beds,
  market awnings, dock service decks, rail signals, brood ribs, survey optics,
  lab cases and cistern protocol pylons.
- every non-sanctuary landmark now also carries a bounded authored surface
  finish: ruin service spines use louvered panels, inset plates, cable runs and
  scar rails, while the bespoke regions use distinct facade, utility, signal or
  organic-growth signatures. These details remain presentation-only and under
  the landmark LOD boundary.
- the release material pass remains live for late-created robots, organic
  families, outpost upgrades and discovered-region dressing, so the visual
  language does not regress after the opening scene.
- friendly frames share a final inset-panel, fastener, cable-run and joint
  collar finish while cargo, weapon, sensor and construction silhouettes
  remain role-specific.
- Warden, Scrapper and Pathfinder now carry dedicated heat-exchanger,
  salvage-intake and sensor-pod hardware so the role read survives the
  tactical camera instead of relying on color alone.
- the tactical HUD now treats control help and healthy sanctuary status as
  contextual onboarding cues: they fade from settled play while objectives,
  reserves, health, operation state, direct interaction prompts and map mode
  remain legible.
- level 2 and level 3 machine frames now visibly evolve with raised shoulder
  rails, signal strips, dorsal service panels and a final crown/status assembly,
  so late autonomous capability changes the town's material language instead
  of remaining a hidden stat multiplier.

Clutter must leave important routes readable from the high-angle camera.

## Actor presentation

The Mechromancer now uses a regenerated authored glTF character asset with
denser cloth, face and equipment forms. The first friendly robot family pass
now uses higher-resolution modular geometry with role-readable silhouettes;
organic enemies remain procedural until their own production asset milestones.

### Mechromancer

- coat, hood, field pack and shoulder light;
- clearly visible weak pistol;
- visible face/visor and layered field gear;
- asymmetrical shoulder guard, cyan field-comms panel and antenna beacon;
- worn boot cuffs and wrist tool loop that reinforce the technician fantasy;
- the finish remains presentation-only and preserves the authored model sockets,
  gameplay capsule and weak-pistol contract.
- charcoal cloth, worn leather, oxidized metal and skin hierarchy with authored
  normal relief for close camera detail;
- smoother cloth panels, curved hood/scarf transitions, cheek and mouth forms,
  layered pack construction, refined boots and heavier split coat tails;
- rear-camera readability through the asymmetrical pack, hood drape and split
  coat tails;
- authored idle, walk, fire, work and hit clips;
- socket-based shoulder lighting and pistol muzzle;
- HUD portrait sourced from the same character design;
- compact silhouette that remains readable beside machines;
- 1.28 runtime presentation scale with the gameplay collision capsule kept
  unchanged, so camera readability does not alter combat or movement logic.

### Friendly robots

- shared layered chassis language with shoulder plates, armour bands, optics,
  joints and exposed service cabling;
- the opening Bulwark now uses an original authored glTF shell with layered
  chassis plates, service fasteners, protected optics, twin weapon housings,
  rear shield hardware and a raised protection emitter; its stable node and
  animation contract is recorded in `game/data/bulwark_asset_manifest.json`;
- the Warden guardian now uses a separate original authored glTF shell with
  broad escort armour, counterweight, protected autocannon breech,
  heat-exchanger louvers and a sensor mast; its stable contract is recorded in
  `game/data/warden_asset_manifest.json`;
- the Scrapper salvager now uses an original authored glTF shell with a deep
  cargo hopper, paired dismantler arms, magnetic claws, intake head and salvage
  drum; its stable contract is recorded in `game/data/scrapper_asset_manifest.json`;
- role-specific salvager cargo and dismantler tooling, guardian weapon and
  shield forms, scout fins and sensor mast, and engineer cradle, pistons and
  forge tooling;
- higher-resolution cylinders, spheres and capsules for close-camera
  readability;
- walking gait, foot lift, body weight, sensor movement, tool motion and recoil;
- warm or cyan friendly lights distinct from organic enemies.

### Organic enemies

- species-specific carapace, muzzle, feeler, drill, sac, lobe and crown
  silhouettes across all seven current organic families;
- shared segmented torso shells with wet cores, overlapping edge plates and
  lateral seams across the full organic roster;
- species-specific sensory fans, gill membranes, cheek plates, drill rings and
  dorsal frills for stronger close-camera silhouettes;
- a ribbed, layered Veilstalker thorax and plated dorsal construction for the
  first focused hostile-family quality pass;
- asymmetrical chitin, flesh, spines and tails;
- twitching idle movement and multi-leg locomotion;
- head probing, mandible movement, pack movement and species-specific idle
  motion;
- red organic emissives used sparingly as threat cues.
- organic attacks expose a short warning window with a ground telegraph,
  anticipation pose and a real miss opportunity before damage resolves.

## Feedback and VFX

Combat and survival actions should have a clear visual grammar: direction for
projectiles, anticipation for threats, and a distinct active field for manual
work. The current runtime provides bounded weapon tracers, organic attack
telegraphs and impact bursts, plus a three-ring channel field for salvage and
fabrication. These effects are presentation-only and do not introduce a new
resource, queue or recurring player task.

The presentation layer may improve feel without changing simulation outcomes.

Implemented feedback includes:

- muzzle flashes and projectile impacts;
- sparks during salvage and fabrication;
- organic death bursts;
- visible expanding noise pulses;
- subtle camera impact;
- actor hit reactions;
- persistent forge embers and smoke;
- HUD damage flash and sanctuary-integrity status;
- spatial sound cues for weapons, salvage, fabrication, organic contact,
  causal noise and Heartforge damage.

## Focused final-protocol capstone milestone

- the player-triggered final crisis now raises a bounded Heartforge protocol
  lattice with staged rings, spines and emissive organic-signal colours;
- progress continuously changes the lattice scale, pulse, visible stages and
  local light, making the causal escalation readable without adding a new
  dashboard or recurring maintenance task;
- completion resolves the crisis lattice into a cyan-and-gold sanctuary crown,
  while failure clears the presentation without changing the underlying
  protocol state;
- dedicated start, stage, completion and failure cues extend the existing
  generated spatial sound vocabulary;
- the presentation director rehydrates active or completed capstones after
  save/load, while all protocol costs, pressure, spawning and victory rules
  remain owned by `EndgameDirector3D`.

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
        ├── MechromancerPresentation3D for the authored player asset
        └── ProceduralAnimator3D per procedural actor
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

## Focused Mechromancer milestone

The runtime asset contract is defined by
`game/data/mechromancer_asset_manifest.json`. The original Blender source lives
under `game/assets/mechromancer/source/`, exports the textured glTF runtime
asset, normal maps and baked portrait, and exposes stable sockets for the
weapon, shoulder lamp, face and field equipment. This is a presentation-only change: the
existing player collision, weak pistol, channels, health and autonomy
interfaces remain authoritative.

## Focused Bulwark protection milestone

The opening companion now carries a dedicated shield language: a low cyan
protection arc, raised emitter spine and side guard panels. These additions
make the Bulwark's personal-interception role readable before an attack starts,
while remaining presentation-only and leaving the existing protection rules,
collision and autonomous workload unchanged.
