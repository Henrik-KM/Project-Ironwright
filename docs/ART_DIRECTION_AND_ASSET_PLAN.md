# Art Direction and Asset Production Plan

## 1. Purpose

The concept art establishes an emotional and visual progression, but it does not solve production. Codex can assemble, import, configure, optimise, and validate assets; it cannot replace the modelling, rigging, animation, VFX, composition, and art-direction work needed for a coherent commercial game.

The realistic plan is:

1. use legally clean placeholder and prototype assets to prove the game;
2. develop a compact modular visual language;
3. commission bespoke production assets only after the survival-and-autonomy loop is validated;
4. keep the final asset count deliberately small by reusing rigs, modules, materials, and morphology systems.

---

## 2. Visual thesis

Project Ironwight is built around the contrast between created order and hostile life.

### 2.1 Friendly machines

- worn industrial metal rather than pristine military hardware;
- practical, exposed mechanisms and repair scars;
- small concentrated lights used as readable identity;
- modular parts whose relationship can be understood at a glance;
- purposeful movement that becomes increasingly coordinated;
- a limited palette centred on dark metal, oxidised warm tones, and cool cognition light.

### 2.2 The organic world

- chitin, bone, tendon, membrane, fungal threads, sacs, and wet surfaces;
- asymmetry and imperfect repetition;
- motion driven by hunger, caution, territorial display, or pack communication;
- forms that can hide partially in darkness;
- silhouettes that cannot be confused with friendly robots.

### 2.3 The Heartforge

The Heartforge is a mechanical hearth, not a generic command centre.

- cold inner cognition light;
- warmer work lamps and sparks around practical repair;
- visible accumulation of plates, braces, grafts, and adaptations;
- persistent scars from attacks;
- recognisable core silhouette at every stage;
- growth by density and layered morphology rather than urban sprawl.

---

## 3. Progression target

### 3.1 Early game

The early game should be almost empty.

Required visual ingredients:

- one damaged Heartforge shell;
- one weak light source;
- one damaged Scrapling;
- the Mechromancer with a crude tool;
- darkness close to the base;
- a small amount of loose wreckage;
- one organic threat visible only partly or briefly;
- no complete perimeter;
- no polished holographic command centre;
- minimal HUD.

The player should read vulnerability before reading genre.

### 3.2 Mid game

The base is compact, repaired, and active.

- robots perform visible routines;
- defences are integrated rather than individually placed;
- the Heartforge has a coherent outer shell;
- the nearby world remains oppressive and close;
- organic remains, damage, and repairs show continuing pressure;
- one or two machine groups may depart or return;
- the UI summarises rather than manages.

### 3.3 Late game

The base has become a dense autonomous machine fortress.

- large numbers of machines move with purpose;
- the same original Heartforge remains identifiable;
- large organic organisms test the defensive envelope;
- expedition groups operate beyond the walls;
- machines repair, recover, and respond without visible player orders;
- the footprint is bounded even when the visual density is high.

The late game must not resemble a city-builder or a map covered in production buildings.

---

## 4. Concept art in this repository

Files under `docs/concept-art/` are direction references:

- `progression-board.png` — full-resolution early/mid/late progression board;
- `progression-board-web.png` — README-sized version;
- `early-game.png` — cropped early panel;
- `mid-game.png` — cropped mid panel;
- `late-game.png` — cropped late panel.

Important caveats:

- Generated UI text is illustrative and not a design specification.
- Some late-game density may still be above the ideal final footprint and should be treated as an upper bound.
- The organic enemy direction is canonical; any mechanical-looking hostile form should be replaced.
- These images are not meshes, rigs, textures, animations, or shipping UI.

---

## 5. Prototype asset strategy

No third-party art asset is currently included. Before import, verify the current licence on the official source and record the exact asset, version, source URL, licence, and modifications in `ATTRIBUTION.md`.

The following official libraries are strong prototype candidates as of 18 August 2026:

### 5.1 Quaternius

Candidate uses:

- modular science-fiction environment pieces for temporary Heartforge construction;
- generic props, crates, tools, and screens;
- temporary humanoid and robot animation support;
- organic monster or alien placeholders, not robot enemies.

Official candidate packs:

- [Sci-Fi Essentials Kit](https://quaternius.com/packs/scifiessentialskit.html) — 65 models, glTF support, CC0, and a Godot implementation in the source version.
- [Modular Sci-Fi MegaKit](https://quaternius.com/packs/modularscifimegakit.html) — more than 270 modular environment pieces, glTF support, CC0, and Godot-ready source material.
- [Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html) — 50 animated monster models, glTF support, CC0.
- [Animated Alien Pack](https://quaternius.com/packs/animatedalien.html) — a small animated organic-alien placeholder set, CC0.
- [Easy Enemy Pack](https://quaternius.com/packs/easyenemy.html) — simple animated creature placeholders, CC0.

The art style of these packs is not the intended final style. Their purpose is functional prototyping and animation-system validation.

### 5.2 Poly Haven

Candidate uses:

- terrain materials;
- rock and debris models;
- environmental textures;
- HDRIs for lighting studies;
- surface-reference material during look development.

Poly Haven’s official licence page states that its HDRIs, textures, and 3D models are CC0 and may be used for commercial purposes. See [Poly Haven’s licence](https://polyhaven.com/license).

### 5.3 Kenney

Candidate uses:

- temporary UI panels and icons;
- input prompts;
- debug visual language;
- temporary effects and simple props.

Kenney’s official support page states that game assets on its asset pages are CC0 and may be used in commercial projects. See [Kenney support](https://kenney.nl/support).

### 5.4 Prototype rules

- Do not import an entire pack when only a few assets are needed.
- Keep all third-party imports under `game/assets/third_party/<source>/<pack>/`.
- Preserve original licence files.
- Record hashes and source dates.
- Create project-specific material overrides rather than modifying source files destructively.
- Never use robot assets as hostile units merely because they are available.
- Replace visually misleading placeholders as soon as they begin influencing design decisions.

---

## 6. Bespoke production set

A viable final game should be built from a deliberately compact bespoke set.

### 6.1 Mechromancer

- one base character model;
- four or five visible evolution layers or interchangeable components;
- one main skeleton;
- locomotion, tool-combat, repair, machine-link, injury, and death/recovery animation sets;
- cloth or coat treatment that remains readable from isometric distance;
- strong silhouette separating the player from all robots.

The focused first authored milestone is represented in
`game/assets/mechromancer/`. It establishes the hooded field-engineer
silhouette, stable glTF sockets, five presentation clips and a matching HUD
portrait without introducing later personal evolution variants.

### 6.2 Heartforge

- one persistent core;
- five or six structural evolution states;
- modular braces, plates, vents, weapon sockets, sensor forms, and repair scaffolds;
- damaged and repaired variants;
- materials capable of showing heat, stress, infestation, and active cognition;
- procedural or rule-based assembly support.

The Heartforge is the most important environment asset in the game and should receive more bespoke attention than a large catalogue of secondary buildings.

### 6.3 Friendly robots

- approximately five core chassis;
- shared joint conventions and compatible attachment points;
- modular tools, sensors, weapons, carriers, and armour forms;
- one coherent material family;
- a small shared animation library where anatomy allows;
- damage states and repair animation;
- readable role silhouette without colour alone.

A small modular family can produce much more variety than dozens of unrelated units.

### 6.4 Organic enemies

- approximately six core rigs for the first full game;
- modular heads, limbs, crests, sacs, growths, and armour plates;
- species-specific locomotion and communication animation;
- damaged, juvenile, mature, and adapted variants where useful;
- two or three bespoke apex rigs;
- material systems for chitin, membrane, spores, blood, and contamination.

Enemy diversity should come from behaviour and morphology, not simple recolours.

### 6.5 Environment

- one primary wilderness biome kit;
- terrain materials and decals;
- modular rock, carcass, burrow, ruin, and wreck sets;
- vegetation or fungal forms supporting visibility and threat cues;
- weather and time-of-day effects;
- landmark pieces for unique objectives.

A second biome should not be commissioned before the first long-form world proves enjoyable.

### 6.6 VFX and UI

- cognition light and machine-link language;
- repair, fabrication, damage, contamination, and biological impact effects;
- restrained defensive weapon effects readable at scale;
- minimal UI shell designed around exception-based information;
- icon family for the three evolution paths and major organism behaviours.

---

## 7. Production pipeline

Recommended flow:

1. concept and silhouette sheet;
2. blockout in Blender;
3. in-engine scale and camera test;
4. high/low modelling as needed;
5. UV and material development;
6. rigging and modular-attachment validation;
7. animation or retargeting;
8. glTF export;
9. Godot import preset and material override;
10. collision, navigation, LOD, and visibility setup;
11. automated asset validation;
12. performance and readability review in representative scenes.

Codex can help create Blender batch scripts, Godot import tools, naming validators, LOD configuration, attachment metadata, and asset manifests. Human artists remain responsible for quality and final visual judgment.

---

## 8. Repository asset rules

Every production asset must have:

- unique stable identifier;
- source or creator;
- licence and proof;
- date acquired;
- original file preserved where permitted;
- exported runtime file;
- scale and orientation metadata;
- material assignment;
- collision status;
- LOD status;
- rig or skeleton identifier if animated;
- modification notes.

Do not commit unverified downloads or files whose redistribution terms are unclear.

---

## 9. First art milestone

The first art milestone is not “make the late game look like the concept art.” It is:

> Make one damaged Heartforge, one Mechromancer, one Scrapling, and one Veilstalker readable and frightening in a small dark greybox.

Acceptance criteria:

- the base reads as fragile from a still image;
- the player can distinguish all four silhouettes instantly;
- the Veilstalker is threatening when only partly visible;
- the light radius creates emotional safety without an explicit safe-zone wall;
- the Scrapling looks useful but unreliable;
- no visual element implies a functioning RTS economy.
