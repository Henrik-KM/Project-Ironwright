# Changelog

## 0.5.0 — 2026-08-19

### First-session UX and world guidance

- Rebuilt the forge as a centred responsive modal with viewport-safe margins and scrollable content, preventing fabrication options from clipping at constrained resolutions.
- Separated the persistent objective, immediate contextual interaction, material reserves and transient machine reports into distinct HUD regions.
- Replaced the permanent notification paragraph stack with at most three short-lived machine-report toasts.
- Enlarged and spaced Scrap, Cognition Core, focus and operation text to eliminate visual collisions.
- Added a physical amber wreck beacon, ground route cues, distance/direction text and an explicit `HOLD E · LOUD` interaction for the first salvage objective.
- Added continued cyan guidance back to the Heartforge for the first Scrapper and expedition-group fabrication steps.
- Clarified the empty evolution state by hiding meaningless Previous/Next controls and disabling a clearly labelled `NO EVOLUTION AVAILABLE` action.
- Added responsive strategic-screen layout and full-screen modal backdrops.
- Added native first-session UX regression tests at an 800×520 constrained viewport.
- Removed obsolete self-modifying patch-expansion infrastructure that had been accidentally merged into the repository.

## 0.4.0 — 2026-08-19

### Full-game production foundation

- Made the current Project Ironwright conversation explicitly authoritative over stale repository contracts and prompts.
- Added the end-to-end roadmap from the current playable build through persistent regions, autonomous machine society, adaptive Heartforge construction, deep ecology, midgame, late game, endgame, production assets, alpha, beta and launch.
- Replaced the obsolete blanket prohibition on outposts with bounded autonomous support posts on fixed discovered sites.
- Added machine-readable full-game, progression, technology, world-site and outpost registries.
- Added persistent progression phases, technology prerequisites and Heartforge tiers.
- Added the Engineer robot family with three class-wide levels.
- Added a minimal strategic evolution interface that preserves limited high-consequence choices.
- Added four autonomous outpost roles: resource recovery, proxy defence, early warning and field repair.
- Added physical escorted construction, upgrades, resource hauling, destruction, self-repair and automatic rebuilding.
- Extended the native objective flow beyond the North Ruins Cognition Core rather than ending the run.
- Added full-game extension persistence for progression, site discovery, outpost role, tier, health, destruction and stored Scrap.
- Added organic outpost targeting and native full-game scenario tests.

## 0.3.0 — 2026-08-19

### Native aesthetic overhaul

- Regraded the native 3D world to readable blue hour with ACES tonemapping, cool ambient light, warm horizon fill and lighter controlled fog.
- Added a cozy inhabited Heartforge camp with practical lights, workshop clutter, wet surfaces, embers and smoke.
- Added wet-street reflections, warm windows, damaged signs, street furniture, weeds, distant organic silhouettes and atmospheric motes.
- Added silhouette detail for the Mechromancer, friendly robot roles and organic enemies.
- Added procedural movement, breathing, recoil, channel poses, robot gait, creature motion and hit reactions.
- Added muzzle flashes, impacts, organic death bursts, salvage/fabrication sparks, visible noise rings and camera feedback.
- Re-skinned the native HUD with cinematic panels, stronger hierarchy, sanctuary status, vignette and damage feedback.
- Added static aesthetic validation and a native Godot acceptance test.

## 0.2.0 — 2026-08-19

- Restored the complete browser launch surface and every segmented source file.
- Added the playable First Light browser implementation.
- Changed the Mechromancer to automatically target and shoot the nearest organic enemy within range.
- Added deterministic browser simulation tests and launch smoke validation.
- Added the first native Godot 3D survival-strategy slice with weak pistol, companion dependence, noisy salvage, manual fabrication, coordinated groups and physical North Ruins travel.

## 0.1.0 — 2026-08-18

- Rebuilt the product around long-form survival strategy rather than RTS expansion.
- Locked one run-critical Heartforge, one ordinary resource, organic enemies and no scheduled-wave main loop.
- Defined autonomy as permanent removal of player work.
- Added the revised GDD, ecology, sandbox, art, architecture, roadmap and playtest documents.
