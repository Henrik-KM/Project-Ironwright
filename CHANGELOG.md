# Changelog

## Pre-alpha endgame protocol readability milestone

- Tuned the active Severance lattice and Heartforge core-light budget so the final crisis remains visually charged without obscuring the Heartforge, Mechromancer or Bulwark silhouettes.
- Tuned the completed sanctuary crown to read as a calm cyan capstone rather than a bloom-heavy flash.
- Added a native regression guard for the final-protocol light budget and live-reviewed both active and completed endgame frames.

## Pre-alpha authored hostile attack-motion milestone

- Added presentation-only family attack signatures for all twelve organic shells: loaded mandibles, jaws, drills, sacs, wings, gills, resonators, root arms and apex membranes now visibly communicate threat before impact.
- Added native regression coverage for every family signature and live-playtested the Sporecaster wind-up and organic impact feedback in the tactical frame.

## Pre-alpha authored region approach readability

- Added camera-facing opaque service windows and facade edge breaks to the East Tenements shell so its residential identity survives the tactical approach frame.
- Added camera-facing carriage windows, door hardware, service lamps and stronger teal/rust separation to Tram Graveyard so its rail identity survives the tactical approach frame.
- Completed a live approach-frame inspection sweep across the authored mid- and late-game landmarks; formal human acceptance remains an explicit release gate.

## Pre-alpha authored landmark continuity

- Corrected three authored parent-child landmark sockets that were using
  world-space offsets: the Tram Graveyard signal lamp, East Tenements
  fire-escape rail and Riverworks sluice ribs now remain attached to their
  parent structures.
- Added native aesthetic regression checks for those spatial relationships.

## Pre-alpha hostile shell socket continuity

- Corrected local authored offsets for the Cistern Apex crown plate,
  Broodmass maw hardware and Sporecaster sensory-cowl details so those
  high-definition hostile silhouettes remain coherent under their parent
  shells.
- Added organic-family regression checks for the three parent-child socket
  contracts.

## Pre-alpha ecology progression

### Population-driven enemy escalation

- Added five organic difficulty tiers with independent population caps and replenishment rates.
- Added exact 10:1 upward rate transfer when a non-final tier reaches its cap.
- Added continuously growing Tier-I background pressure and bounded fractional spawn credit.
- Added eight physical reproductive nests with maturity, tier support, health, suppression, destruction, persistence, and slow causal regrowth.
- Added dynamic ecological costs and suppression effects for Heartforge evolution and long-range operations.
- Added primitive Tier-I roaming, territorial Tier-II patrols, Tier-III scouting and hunting, Tier-IV strategic targeting, and Tier-V regional Apex behavior.
- Added pack information sharing, last-known prey memory, retreat, route ambush, infrastructure targeting, and lower-tier Apex influence.
- Added qualitative command-map ecology intelligence.
- Added autonomous Warden suppression patrols after Heartforge Tier III.
- Added checksummed sidecar persistence and deterministic native/static tests.


## 0.7.1 — 2026-08-20

### Mechromancer authored-model realism pass

- Rebuilt the player source around a human field-engineer silhouette instead of
  the earlier primitive mannequin blockout.
- Added rounded/tapered anatomy, hood drape and brim, visible facial forms,
  split coat tails, offset field pack, harness, belt pouches, gloves, tool
  attachments and a formed pistol grip/barrel.
- Added original deterministic wear textures for cloth, leather, metal and
  skin, plus authored normal relief, beveled edges and asymmetric practical
  lights.
- Reworked the rear-facing pack, hood drape and split coat so the production
  isometric camera reads the human field-engineer silhouette from behind.
- Replaced the placeholder portrait with a PNG rendered from the same Blender
  source model.
- Enlarged and flared the two coat tails, added rear pack buckles/canister and
  strengthened the visual-vs-collision scale contract for tactical-camera
  readability.
- Added deterministic UV projections and subdued woven/normal surface relief
  so the cloth and leather read as worn materials rather than a repeating
  high-frequency procedural grid.

## 0.7.0 — 2026-08-20

### Focused Mechromancer visual overhaul

- Replaced the procedural Mechromancer mannequin with the original
  `mechromancer.player.v1` glTF asset.
- Added the hooded field-engineer silhouette, visible face/visor, split coat,
  pack, shoulder light and weak sidearm.
- Added authored Idle, Walk, Fire, Work and Hit presentation clips with a
  typed presentation controller.
- Added socket-based player lighting, muzzle resolution and a matching HUD
  portrait without changing gameplay behavior.
- Added stable asset manifest validation and preserved the existing procedural
  robot and organic presentation paths.

## 0.6.0 — 2026-08-19

### Complete end-to-end systemic alpha

- Connected the opening, autonomous outposts, multi-region midgame, machine society, late objectives, final protocols and first victory into one playable run.
- Added seven persistent physical regions: Heartforge District, North Ruins, West Grid, Flood Market, Cathedral Quarter, Buried Laboratories and Root Cistern.
- Added authored procedural landmarks, discovery state, physical routes, regional pressure and suppression.
- Added a reusable physical long-range operation director with role requirements, shared pace, cohesion, escort screening, exposed work, causal noise, local threats, physical return and delayed reward delivery.
- Added West Grid survey, Vital Membrane recovery, Cathedral Brood suppression, Genome Prism excavation, Root Cistern mapping and optional Apex lure operations.
- Added four persistent unique biological components without introducing another recurring currency.
- Completed the Heartforge progression path through tiers III, IV and V.
- Added autonomous ordinary machine replacement after Forge Assistance, without a player-maintained production queue.
- Added continuous regional ecology, ecological capacity, disturbance memory, suppression, organic migration and additional Burrower, Sporecaster, Broodmass and Apex species.
- Added responsive long-range operations and final-protocol interfaces.
- Added player-triggered Severance and Containment endings.
- Added a causal sustained final response rather than a recurring numbered-wave loop.
- Added optional Distributed Continuity for one costly late Heartforge recovery.
- Added complete-alpha save state for regions, operations, components, machine society, strategic ecology, final protocols, continuity and first victory.
- Added a deterministic native start-to-victory systemic test.

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
