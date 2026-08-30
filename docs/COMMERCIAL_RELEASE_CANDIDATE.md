# Project Ironwright — Commercial Release Candidate

**Version:** 1.0.0-rc.1
**Engine:** Godot 4.7.1
**Primary platforms:** Windows x86-64 and Linux x86-64
**Status:** Repository-complete commercial release candidate under final external playtest and distribution QA

Project Ironwright 1.0.0-rc.1 converts the complete start-to-victory systemic alpha into a packaged, localized, accessible and performance-bounded release candidate. The game retains the product identity established in the authoritative conversation: one weak Mechromancer, one run-critical Heartforge, organic enemies, physically travelling robot groups, bounded autonomous outposts, continuous causal pressure, and machine intelligence that removes work rather than opening more management screens.

This document distinguishes what is implemented in the repository from the final external activities required before publishing a paid commercial build. A repository can contain a complete release candidate, but no code change alone can substitute for representative hardware testing, store signing, age ratings, legal review, broad external playtesting, or a final business decision to publish.

## Integration contract

The canonical native entrypoint is `res://scenes/main_3d.tscn` → `main_world_tiered_3d.gd` → `main_world_release_3d.gd`. The tiered wrapper inherits the release world and installs the population-driven enemy progression bootstrap used by the production build. The release world inherits the production systemic chain and owns the current Heartforge vertical-slice camera, environment and actor presentation layer. Release saves use the versioned transactional service and retain local autonomy, outpost and long-range operation state; only an active player manual channel defers saving. Remote work remains physically resumable.

## Production assets

The release candidate includes an original runtime asset library created specifically for Project Ironwright. No third-party character, environment, texture, sound or music pack was inserted into the game.

The production texture set contains nine authored procedural texture families:

- rain-darkened asphalt;
- ruined brick;
- wet concrete;
- brushed machine metal;
- oxidized and painted steel;
- accumulated grime and damage;
- moss and post-collapse plant growth;
- organic chitin;
- living membrane.

Each family also ships with a generated tangent-space normal-relief companion.
The release art director applies those maps through the same world-space
triplanar materials, giving hard surfaces, chitin and membrane shells readable
micro-form under the tactical lighting without changing collision, simulation,
or actor budgets.

The release art director applies these textures through triplanar world-space materials to the existing procedural geometry. This is deliberate: the systems remain independent from the current art source, while the shipped world no longer presents as flat greybox geometry. Roads, buildings, vehicles, machinery, friendly robots and organisms receive materials appropriate to their role and construction.

Every persistent region also receives a distinct environment-dressing kit. The Heartforge District gains a denser inhabited perimeter, cable posts and warm practical lights. The West Grid receives tanks, pipework and industrial structures. East Tenements gain balconies, suspended cloth and vertical route language. The Municipal Glasshouse receives broken frames, overgrowth and luminous mycelium. Flood Market gains stalls, drowned concrete and membrane growth. Riverworks gains pump gantries and service decks. Tram Graveyard contains derailed vehicles and overhead infrastructure. Cathedral Quarter gains brood spines and resonant sacs. Observatory Ridge receives the surviving optics. Buried Laboratories gain consoles, cylinders and cold displays. Root Cistern receives root pylons, signal organs and the final basin.

The asset library is intentionally modular and generated from original source material. It can later be supplemented by externally commissioned models without rewriting the survival, autonomy, persistence or performance architecture.

## Animation

The previous procedural locomotion layer remains responsible for walking, recoil, breathing, work poses, hit reactions and organic movement. The release candidate adds a second animation layer for details that previously remained rigid.

Secondary motion is attached dynamically to relevant world subjects and supports:

- Engineer welding and assembly arms;
- outpost extraction, repair, sensor and defensive mechanisms;
- Glassmoth wings and Roofleaper membranes;
- Carrion Bell signal organs;
- Rootweaver appendages and Root Cistern pylons;
- observatory and scout sensor dishes;
- hanging cloth and environmental movement;
- pulsing biological signal lights.

The layer respects the reduced-motion accessibility setting. It also remains separate from simulation. A visual mechanism can be replaced with an authored skeletal animation later without changing the robot planner, outpost director or ecology.

Distant actors use visual level-of-detail states. Nearby organisms and robots retain full shadow and detail treatment. Medium-distance actors disable expensive shadows. Distant actors suppress small decorative geometry while preserving their physical positions, health, goals and consequences.

## Audio and music

The release candidate contains an original audio library rather than silent placeholder systems.

Ambient sound is layered continuously. Near the Heartforge, a warm mechanical sanctuary bed dominates. As the Mechromancer moves into the town, wind, distant structures and organic environmental sound become more prominent. The transition is spatial and continuous rather than tied to a loading screen.

Music uses four adaptive states:

- **Embers:** restrained opening music for vulnerability and small-scale survival;
- **Sanctuary:** a warm machine-family motif heard while the player is close to the Heartforge;
- **Pressure:** a more urgent layer used during dangerous ecological concentration and final-protocol escalation;
- **Sovereignty:** broader late-game music used as the machine society matures and after victory.

The audio director crossfades between states rather than restarting tracks on every event.

Effects cover the weak pistol, salvage cutting, Heartforge fabrication, organic impacts, machine reports, major danger, interface confirmation and first victory. Effects use a bounded player pool to avoid unbounded node creation.

Optional sound captions describe strategically meaningful sounds such as a weak pistol crack, loud metal cutting, Heartforge hammering, a nearby organic impact, an approaching major organism and a machine report. Captions follow the selected language and can be disabled independently.

Music, ambience and effects each have separate volume controls in addition to master volume.

## Substantially expanded content and environmental detail

The persistent town expands from seven to twelve authored regions:

1. Heartforge District;
2. North Ruins;
3. West Grid;
4. East Tenements;
5. Municipal Glasshouse;
6. Flood Market;
7. Riverworks;
8. Tram Graveyard;
9. Cathedral Quarter;
10. Observatory Ridge;
11. Buried Laboratories;
12. Root Cistern.

The operation catalogue now contains twenty-three authored physical objectives. The required start-to-victory chain remains intact, while optional operations add route knowledge, rare components, regional suppression, additional outpost foundations, civic archive recovery, residential rescue, transformer repair, secondary fixed-site approaches and the Root Signal purge. These include tracing the East Roofline, recovering the Tram Servo Bank, harvesting luminous Glasshouse mycelium, restarting a Riverworks pump, calibrating the Observatory array, reopening the West Canal Works, raising the Flood Market Crane, clearing the Buried Lab Airlock and a post-victory archive recovery.

The organic roster now contains fourteen families. Seven release families join the existing seven:

- Roofleapers use vertical ambush movement;
- Glassmoths form luminous spore swarms;
- Miremaws are heavy amphibious predators;
- Carrion Bells broadcast machine positions and support nearby organisms;
- Rootweavers control late-game routes and respond to remote infrastructure;
- Thornbacks hold narrow approaches as territorial broodline guardians;
- Ashmantles track forge heat and hunt machine routes.

These are organic additions, not a hostile machine faction. Regional ecology chooses species according to district identity and continues to respond to noise, pressure, suppression and migration.

The bounded outpost-site pool now contains twenty-four fixed foundations distributed
across the discovered regions. Optional exploration therefore creates a broad
set of meaningful strategic choices without introducing free placement,
territory painting or a logistics spreadsheet.

## Performance architecture

The release candidate adds a reusable spatial index for high-frequency targeting and perception. Friendly machines, organic enemies, outposts and salvage are partitioned into world-space cells. Radius queries inspect only relevant cells rather than scanning every entity in the world.

A performance director divides the physical world into three presentation and simulation bands around the current camera or followed operation:

- **active:** full physics, behaviour, geometry and shadows;
- **medium:** active behaviour with reduced visual cost;
- **reduced detail:** coarse deterministic movement and combat updates at a slower interval.

Reduced detail is not an abstract mission timer. Distant organisms retain positions, targets, health, aggression and physical movement. Returning to the area restores full simulation around the same state. Detail evaluation registers every actor but sorts only the active/medium neighborhood; actors beyond the medium radius are assigned the reduced state immediately, keeping distant population growth from expanding the per-evaluation sort workload.

The director also enforces bounded active and medium actor budgets, assigning the nearest actors first. Medium actors retain their targets and state but advance on a coarse cadence; reduced actors use deterministic coarse movement and combat ticks. Release actors outside the active visual tier use a shared lightweight silhouette proxy resource, and may defer construction of their authored high-definition shell until active promotion, so duplicate proxy and high-definition geometry do not multiply routine spawn or rendering cost. Physical collision and simulation state remain present while the authored presentation shell is deferred.

The active and medium radii, actor budgets and distant update intervals adapt conservatively to measured frame rate. When performance falls substantially below the selected target, the active radius contracts, budgets tighten and distant update intervals increase. When performance recovers, detail expands again within bounded limits.

Collections, effect pools, reports, save histories and telemetry remain bounded. The release tests verify that a distant organism enters reduced-detail simulation and continues moving causally.

The repository also carries a deterministic release-population benchmark. It boots the real release scene, adds 192 actors across active, medium and distant bands, warms the simulation, and emits a machine-readable report containing wall-clock simulation cost, actor-band counts, budget headroom and the candidate/sort population. CI requires that report to be emitted and that its structural invariants pass; it intentionally does not invent a universal FPS threshold for unknown target hardware. A signed target-hardware run can therefore compare the same report fields without changing the gameplay contract.

## Persistence and migration

The release candidate replaces the transitional multi-file save path with a unified schema-versioned snapshot.

A save contains four domains:

- base world state;
- progression and autonomous outposts;
- complete-game regions, operations, machine society, ecology and endgame;
- release balance, performance and audio state.

Every save is wrapped in an envelope containing schema version, build identifier, timestamp, metadata and a SHA-256 checksum of the payload.

Saving follows a transactional sequence:

1. write a temporary file;
2. flush and close it;
3. reopen and verify JSON structure and checksum;
4. rotate existing verified backups;
5. preserve the previous current save as backup 1;
6. atomically rename the verified temporary file into place.

If the current file is corrupt or incomplete, loading tries rotating verified backups in order. A bounded recovery report records every candidate, its validation or migration result, the selected source and whether migration or backup recovery was used. If no candidate is valid, the service fails closed, emits a localized diagnostic and retains the human-readable report for logs and tests. Regression coverage writes two revisions, corrupts the current file, verifies recovery of the previous valid revision and verifies total failure with all bounded candidates invalid.

The service also migrates the legacy base, full-game extension and complete-alpha save files into the unified schema. Existing alpha players therefore do not have to discard their world.

Active physical salvage, expedition, outpost and long-range operations are
serialized transactionally. Their stable robot names, route or assignment
state, formation anchor, progress clocks, cargo and pending rewards are restored
into the live runtime, so loading resumes the physical work rather than
teleporting or silently completing it. The only player save deferral is an
in-progress manual channel, because interrupting salvage or fabrication would
otherwise create an unsafe partial action.

## Controller and accessibility

The release candidate supports keyboard and mouse plus a standard gamepad input map.

Controller bindings cover movement, interaction, cancellation, pause, follow camera, command map, evolution, outposts, long-range operations, final protocols and the three macro machine focuses. Controller input is registered at runtime and protected against early-scene initialization order.

Keyboard and mouse command access remains available in the same release shell:
`T` opens Heartforge evolution and `O` opens autonomous outpost projects, while
the existing `P` operations and `V` final-protocol paths remain intact.

Damage can produce optional controller vibration. The response scales with the proportion of health lost and can be disabled.

Accessibility settings include:

- text scaling from 85% to 140%;
- high-contrast interface text;
- color-vision mode selection;
- reduced motion;
- reduced flashes;
- adjustable camera shake;
- hold or toggle behaviour for exposed interactions;
- controller vibration toggle;
- subtitles and sound captions;
- opening world-guidance toggle;
- configurable target frame rate;
- Story, Survival and Brutal difficulty profiles.

The settings screen is controller-focusable and accessible from title and pause menus. Settings are persisted transactionally in a separate verified settings file with a backup.

The native accessibility regression now checks the compact 800×520 floor, the
1024×576 release size and the 1280×720 review size at 1.35× text scale. The
opening HUD, forge, strategic command and operations surfaces keep their fixed
close actions inside the real viewport and keep scrollable content above those
footers. This is automated layout protection; professional accessibility and
affected-player review remain external release gates.

## Localization

The complete release shell and returning-world recap are localized into English,
Swedish and German.

Catalogs include title and pause menus, settings, difficulty descriptions, transactional-save reports, controller connection messages, sound captions, performance terminology, ecological-intelligence panels, autonomy markers, returning-world recap summaries, collapse-report section framing and first-victory messaging.

A static release gate verifies that every locale contains exactly the same keys and that no value is empty. A native runtime test switches between all three locales and verifies translated output.

Gameplay content that still exists as authored English prose inside the systemic alpha remains understandable but is not yet fully externalized. The release boundary therefore distinguishes complete release-shell localization from exhaustive localization of every historical diagnostic sentence. Before a final multilingual store launch, the remaining prose should be extracted and reviewed by professional translators.

## Balance and long-run QA

Three data-driven balance profiles are implemented.

**Story** reduces enemy health, damage, speed, pressure and operation threat while increasing Scrap recovery and outpost repair. It preserves the full survival and autonomy structure.

**Survival** is the intended first-victory profile. It targets continuous pressure, meaningful loss and a limited ability to recover.

**Brutal** increases health, damage, speed, pressure, enemy caps and operation danger while reducing Scrap and repair efficiency.

A bounded adaptive-relief system observes recent catastrophic machine loss and critical Heartforge integrity. It can temporarily reduce regional pressure within the maximum allowed by the selected profile. It does not grant resources, cancel consequences or silently make enemies harmless.

The balance director records a bounded history of machine loss, Heartforge crises and victory timing. This creates a durable foundation for external long-run balancing without introducing analytics that affect the player’s privacy or require an online service.

Automated testing includes the complete accelerated start-to-victory path. This confirms systemic connectivity but cannot replace human 30–100-hour balance runs. The release candidate must still undergo external endurance playtests before a final difficulty claim is made.

## Packaging and release QA

Godot export presets are committed for Windows x86-64 and Linux x86-64. Both presets exclude the generated `game/dist` review-output directory so local screenshots and other ignored artifacts cannot be pulled into an `all_resources` package. A release workflow installs Godot 4.7.1 export templates, validates assets and contracts, imports all resources, runs commercial release tests, runs the complete start-to-victory test, exports both platforms, packages the builds and produces SHA-256 checksums.

The pull-request workflow runs all earlier regression suites in addition to the new commercial release suite. Existing opening, aesthetics, outposts, persistence, complete-game progression and victory behaviour must remain green.

## Commercial-release boundary

This repository now targets a commercially distributable release candidate, but the final public release decision remains outside automated implementation.

Before describing a build as the final commercial 1.0, the following external gates remain necessary:

- representative Windows and Linux hardware testing;
- multi-hour and multi-day save endurance testing;
- controller testing across actual gamepads;
- professional language review for all player-facing prose;
- accessibility review with affected players;
- broad external balance and onboarding playtests;
- crash and performance profiling on target hardware;
- store account, signing and upload configuration;
- age-rating and regional legal review where required;
- privacy, licensing and trademark review;
- final screenshots, trailer and store copy;
- a release-support and rollback process.

The codebase must not claim that these human and commercial gates have happened when they have not. The appropriate status for this branch is therefore **1.0.0 release candidate**, not an unqualified final retail release.
