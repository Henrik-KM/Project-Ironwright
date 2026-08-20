# Project Ironwright 1.0.0-rc.1

Project Ironwright 1.0.0-rc.1 is the first repository-complete commercial release candidate. It contains the full start-to-victory survival-strategy game, the production release shell, original audiovisual assets, desktop packaging, transactional persistence, localization, accessibility, controller support and large-world performance systems.

## Core game

- Begin as a weak Mechromancer with a poor automatic pistol and one indispensable Bulwark companion.
- Risk loud, timed manual salvage while movement and attack are disabled.
- Build the first machines personally at the Heartforge.
- Shift routine salvage, defence, repair, replacement, outpost operation, hauling and rebuilding to autonomous robots.
- Follow real coordinated groups through one persistent physical world.
- Establish bounded outposts on discovered sites without manual layout, worker assignment or logistics management.
- Develop the Heartforge through five tiers.
- Explore twelve persistent urban regions.
- Complete twelve physical strategic operations.
- Confront twelve organic enemy families and their interacting ecology.
- Recover unique biological components.
- Choose Severance or Containment and complete a player-triggered endgame.

## Production presentation

- Original wet urban, industrial and organic texture library.
- Region-specific environment dressing throughout the full town.
- Warm Heartforge sanctuary contrasted with a cold blue-hour city.
- Procedural character movement plus release secondary animation.
- Adaptive ambience and three-state original music system.
- Original weapon, salvage, forge, organic, interface and victory effects.
- Optional localized sound captions.
- Cinematic HUD, responsive forge and strategic interfaces.
- Physical first-session wreck markers and route guidance.

## Performance

- Spatial indexing for target and perception queries.
- Active, medium and reduced-detail simulation bands.
- Causal remote movement and combat rather than detached mission timers.
- Visual LOD and shadow reduction for distant actors.
- Adaptive simulation budgets based on the selected frame-rate target.
- Bounded effects, reports, histories and telemetry.

## Persistence

- Unified schema-versioned release save.
- SHA-256 payload verification.
- Temporary-file verification before replacement.
- Rotating backups.
- Recovery from a corrupt current save.
- Migration from the earlier alpha save domains.
- Separate verified settings persistence.

## Input and accessibility

- Keyboard and mouse support.
- Standard gamepad mappings for movement, interaction, menus, macro focuses and strategic systems.
- Optional controller vibration.
- Text scaling.
- High-contrast interface mode.
- Color-vision options.
- Reduced motion and reduced flashes.
- Camera-shake adjustment.
- Hold/toggle interaction choice.
- Subtitles and sound captions.
- Optional opening guidance.
- Story, Survival and Brutal balance profiles.

## Localization

The release shell is localized into:

- English;
- Swedish;
- German.

All catalogs are checked automatically for key parity and empty values.

## Packages

The release workflow builds and packages:

- Windows x86-64;
- Linux x86-64.

Every package receives SHA-256 checksums. The certification workflow commits `docs/RELEASE_CERTIFICATION.json` only after all native and static tests pass and both desktop exports succeed.

## Release-candidate status

This build is suitable for controlled commercial-release testing. The following external publication gates are not represented as completed merely because the repository is complete:

- representative hardware and driver coverage;
- multi-day endurance playtests;
- professional review of translated prose;
- accessibility review with affected players;
- final store signing and submission;
- age ratings and legal review;
- final marketing capture and release-support preparation.

Those items remain explicitly tracked in the certification file and release documentation.
