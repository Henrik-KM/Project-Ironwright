# Project Ironwright — Complete Game Alpha

**Status:** End-to-end systemic alpha  
**Version:** 0.6.0  
**Authority:** The current Project Ironwright conversation with Henrik.

This milestone connects the frightening opening, autonomous outposts, long-run progression, multi-region world, machine society, continuous regional ecology, late-game objectives, final protocols, and first victory into one playable systemic run.

It is a complete game-shaped alpha: the player can start weak, develop autonomy, cross the whole town, reach Heartforge tier 5, choose an ending, survive the causal final response, and win. It is not yet the final commercial content, asset, animation, audio, balance, accessibility, localization, or performance pass described in `FULL_GAME_ROADMAP.md`.

## 1. Complete run structure

The connected run now follows this arc:

1. Recover the first Scrap manually while the pistol is disabled.
2. Build the first Scrapper manually.
3. Delegate routine local salvage.
4. Build the Warden and Pathfinder required for the North Ruins expedition.
5. Recover the first Cognition Core and discover fixed support sites.
6. Evolve the Heartforge to tier 2.
7. Build an Engineer and establish autonomous outposts.
8. Upgrade an outpost and complete the initial network milestone.
9. Survey the West Grid through a physical long-range operation.
10. Evolve the Heartforge to tier 3.
11. Unlock Forge Assistance so ordinary machine replacement becomes autonomous.
12. Recover the Vital Membrane from the Flood Market.
13. Maintain two functioning support posts.
14. Silence the Cathedral Brood and recover its Choral Gland.
15. Evolve the Heartforge to tier 4.
16. Excavate the Genome Prism from the Buried Laboratories.
17. Maintain three functioning support posts.
18. Map the Root Cistern and recover the final Root Map.
19. Evolve the Heartforge to tier 5.
20. Research Severance, Containment, or both.
21. Deliberately initiate one final protocol.
22. Defend the Heartforge while pressure rises continuously from the persistent regions.
23. Complete the protocol and achieve the first victory.

The game does not end after the North Ruins. That expedition is now the bridge between the opening survival phase and the long strategic run.

## 2. Multi-region world

Seven physically present regions define the complete alpha world:

- Heartforge District;
- North Ruins;
- West Grid;
- Flood Market;
- Cathedral Quarter;
- Buried Laboratories;
- Root Cistern.

Every region has:

- a stable identifier;
- a physical centre and radius;
- a route from the Heartforge;
- authored procedural landmark geometry;
- a region type;
- ecological pressure;
- suppression state;
- discovery state;
- save data.

The full world exists from the beginning. Discovery reveals knowledge and guidance rather than causing the location to appear from nowhere.

The physical landmarks retain the grounded ruined-town language. Later regions introduce increasingly strange biological and machine detail without making the opening prematurely futuristic.

## 3. Long-range operations

Press `P` to inspect available long-range operations.

Operations are reusable physical group plans, not mission timers. Each operation defines:

- a real target region;
- prerequisites;
- required robot roles;
- Scrap commitment;
- exposed work duration;
- noise and ecological threat;
- unique rewards;
- region discovery and suppression effects.

When authorized, the system:

1. selects the required machines;
2. reserves them from other routines;
3. forms a coordinated group;
4. keeps work frames behind escorts;
5. follows the physical route through the town;
6. slows and regroups when cohesion breaks;
7. holds when nearby organisms threaten the formation;
8. performs loud work at the actual target;
9. secures rewards locally;
10. carries those rewards home;
11. credits them only after physical return.

The implemented chain includes:

- West Grid survey;
- Vital Membrane recovery;
- Cathedral Brood suppression;
- Genome Prism excavation;
- Root Cistern mapping;
- optional Cistern Apex lure.

The optional Apex lure reduces pressure during the final protocol rather than providing a simple damage bonus.

## 4. Unique components

Late Heartforge evolution uses discrete recovered objects rather than adding recurring resource bars:

- Vital Membrane;
- Choral Gland;
- Genome Prism;
- Root Map.

These are progression evidence, not stockpiled currencies. They are recovered once, retained in save state, and used as prerequisites for major decisions.

Scrap remains the only ordinary construction resource.

## 5. Machine society

Forge Assistance unlocks autonomous ordinary replacement.

The system maintains a broad class composition appropriate to the current Heartforge tier. It does not expose a production queue, per-unit priority list, or worker screen.

When an ordinary class falls below its broad target and sufficient Scrap is available, the machine society:

- waits for operation capacity;
- chooses the missing class;
- spends Scrap;
- fabricates one replacement at the Heartforge;
- emits causal noise;
- registers the new robot with the existing autonomy system;
- explains why it acted.

The target composition expands by Heartforge tier, but the number of player inputs does not.

## 6. Continuous regional ecology

The existing local noise ecology is complemented by a persistent regional layer.

Every region tracks ecological pressure and suppression. The system continuously:

- measures active organisms in each region;
- compares them with region pressure and ecological capacity;
- adds individual organisms when local populations are below pressure-supported levels;
- lets disturbed regions remain dangerous;
- lets successful suppression create real lulls;
- produces causal migrations from high-pressure regions into connecting streets;
- reacts to salvage, construction, evolution, long-range operations, and final protocols;
- reduces local pressure when important organisms are killed.

This is not a scheduled-wave system. There is no recurring wave counter or preparation timer. Migration and concentration emerge from region pressure and disturbance.

Additional organic forms support the broader run:

- Burrowers;
- Sporecasters;
- Broodmasses;
- Apex organisms.

They remain biological in visuals, statistics, behaviour, and narrative role.

## 7. Heartforge tiers III–V

The progression tree now has a complete Heartforge path.

### Tier III

Requires the West Grid survey and at least one functioning outpost. It unlocks deeper autonomous planning and permits Forge Assistance research.

### Tier IV

Requires two biological components, two functioning outposts, and Cathedral Brood suppression. It represents adaptive multi-region awareness.

### Tier V

Requires three recovered biological components, three functioning outposts, and the Buried Laboratories excavation. It prepares the Heartforge to project a final protocol into the Root Cistern.

Every tier is still performed manually at the Heartforge as a loud, exposed, interruptible commitment. The player chooses the evolution; machines absorb the resulting routine work.

## 8. Final protocols

Press `V` after completing tier 5 research and Root Cistern mapping.

The player chooses between two endgame approaches.

### Severance

A shorter, more violent overload that cuts the town away from the coordinating root signal. It provokes higher concentrated pressure around the Heartforge.

### Containment

A longer, more expensive resonant lattice that cages the root intelligence while leaving local organisms alive. It requires a mature support network and rises more gradually.

The final crisis is:

- deliberately initiated by the player;
- causally linked to the chosen protocol;
- sustained rather than divided into arbitrary numbered waves;
- supported by autonomous outposts and machine replacement;
- completed only if the Heartforge survives the protocol duration.

The optional Apex lure can reduce the final response, giving long-range preparation strategic value.

Completing either protocol is the first victory, not a forced restart. Press
Enter or Space on the victory panel to continue the surviving sanctuary. The
post-victory archive then becomes available through `P`; its autonomous group
travels to the North Ruins and returns with civil records and machine names.

## 9. Continuity

Distributed Continuity is an optional late technology.

Once per run, it can convert catastrophic Heartforge failure into a costly recovery:

- the Heartforge returns at partial integrity;
- a substantial Scrap reserve is lost;
- the continuity reserve is permanently consumed;
- the run continues.

This protects very long saves from one isolated late-game failure without weakening the frightening opening.

## 10. Save state

The complete alpha now uses one transactional, versioned run envelope rather than
separate world, progression and complete-game save domains.

It retains:

- region discovery;
- region pressure and suppression;
- completed long-range operations;
- unique recovered components;
- Apex-lure pressure reduction;
- autonomous replacement status;
- strategic ecology state;
- active or completed final protocol;
- continuity consumption;
- first-victory state;
- whether the player continued beyond first victory;
- the recovered post-victory town archive component;
- which regions have received persistent salvage content.

Active long-range operations still defer saving because their live robot references
and formation state are not yet transactionally serialized. Active final protocols
are serialized in the unified envelope.

The save service writes to a temporary file, promotes it atomically, and keeps two
bounded rotating backups. Older foundation and full-game extension files are read
through a migration path and are never treated as the current write format.

## 11. UI and controls

New controls:

- `P`: long-range operations;
- `V`: final protocols;
- left/right: select available operation or protocol;
- Enter/Space: authorize;
- `F`: follow the active physical machine group;
- `M`: command-map camera.

Both new screens are responsive, centred, scrollable, and explicit when no action is available. They show only consequential choices, costs, required team roles, exposure, and threat.

They do not expose per-unit commands, queues, logistics throughput, workers, power, ammunition, or route editing.

## 12. Validation

The complete alpha adds a deterministic native scenario test that accelerates the systemic prerequisites while still exercising the real directors.

It validates:

- complete-world entrypoint;
- seven persistent regions;
- opening operation gates;
- Heartforge tiers II–V;
- fixed outpost support requirements;
- physical outbound, working, returning, and delivery states;
- region and site discovery;
- unique components;
- region suppression;
- autonomous ordinary replacement;
- Root Cistern mapping;
- final protocol research and initiation;
- sustained final-protocol completion;
- first victory;
- persistence of regions, components, operations, machine society, ecology, and ending state.

## 13. What remains before commercial release

The end-to-end systemic alpha is game-complete in structure, but not content-complete or production-complete.

The roadmap still requires:

- authored production models, rigs, animations, VFX, audio, and music;
- a larger and more detailed urban environment;
- active/reduced-detail simulation for much larger entity counts;
- more organic species and robot families;
- full controller and accessibility support;
- transactional saves and migration;
- performance profiling on target hardware;
- narrative and environmental storytelling;
- 30–100-hour economy and pressure balancing;
- repeated full internal runs;
- external alpha and beta testing;
- localization, packaging, store assets, and release QA.

The important change is that these tasks now refine and expand a complete start-to-victory game loop instead of trying to infer the product from a disconnected prototype.
