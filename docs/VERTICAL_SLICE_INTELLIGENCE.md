# Project Ironwright — Vertical Slice and Living-World Intelligence

**Status:** canonical pre-alpha implementation contract  
**Scope:** Heartforge opening district, distributed Salvage focus, local and regional organic behaviour

This milestone addresses three failures visible in actual play rather than adding another layer of abstract systems: Scrappers converging on one wreck, organic enemies waiting passively for combat, and an opening frame that still reads as a procedural prototype.

## 1. Distributed Salvage focus

Salvage focus is a machine **network**, not a squad order to one destination.

Every available Scrapper evaluates physical wrecks independently. A site score considers:

- travel distance from the machine;
- distance from the Heartforge for eventual return;
- remaining Scrap value;
- nearby organic danger;
- whether another Scrapper already reserved the site;
- crowding around other active salvage cells.

When enough viable wrecks exist, different Scrappers must select different sites. A machine that cannot find a useful unclaimed site waits rather than dog-piling another Scrapper's wreck merely to appear busy.

A Scrapper travels physically to its assignment, works there, carries its own cargo, and returns its own cargo to the Heartforge. Other Scrappers continue their work during that return. Cargo is credited only after physical deposit.

After each extraction, the Scrapper re-evaluates. It may continue the current wreck, leave because danger has become unacceptable, return because capacity is reached, or switch to a materially better unclaimed wreck. A depleted or invalid site may never remain the active target.

The player makes none of these decisions individually.

### Protection follows the work

Wardens no longer protect an abstract salvage-group centroid while Scrappers disperse.

The autonomy system derives active protection points from the real Scrapper cells. Wardens distribute across those points and maintain broad local coverage. If the Mechromancer separates from the working cells, some Wardens peel away automatically while at least one remains with vulnerable salvage work whenever possible. The Bulwark remains the Mechromancer's guaranteed close interceptor.

Pathfinders screen ahead of the distributed cells. Follow mode tracks the currently most exposed Scrapper rather than always following the first machine created.

This remains macro-level strategy: there is no worker assignment, site pinning, escort selector, route drawing, priority list or per-robot order interface.

## 2. Organic creatures are actors, not combat triggers

An organism exists before it sees the player. It has:

- a territory origin;
- a territory radius;
- an ecological directive;
- a current behaviour target;
- remembered prey/noise information;
- species-specific target preferences;
- an ability to change behaviour without a scripted wave event.

Implemented ecological directives are:

### Protect nest

The organism stays close enough to its nest or regional core to perform an actual territorial role. It alternates between inner guarding and perimeter patrol. It does not chase indefinitely simply because something crossed its detection radius.

### Patrol

The organism moves through changing points around its territory. Patrol exists continuously without the Mechromancer entering combat range.

### Roam

The organism wanders across a larger local envelope. Roaming prevents the city from becoming a set of motionless spawn points while preserving spatial causality.

### Scout

The organism makes proactive outward excursions toward likely machine approaches, then turns back toward its territory. Veilstalkers use this heavily. Scouting can therefore reveal an approaching threat before either side is committed to combat.

### Hunt

The organism follows probable prey routes, last-known positions, noise and vulnerable targets. Razorhounds can share prey/noise information with nearby pack members. Hunting continues for a limited time after direct contact is lost rather than switching instantly to idle.

### Feed

Scavenging organisms can investigate nearby wreckage and other material interest. Their presence can therefore intersect naturally with the robot salvage network.

## 3. Nest-level behaviour

Local nests have broad activity states: guard, patrol, roam, scout and hunt.

Nest activity changes from world state rather than a repeating encounter schedule. Inputs include:

- current ecological pressure;
- distance of the Mechromancer from the nest;
- recent noise position and intensity;
- accumulated noise pressure;
- species composition.

A loud salvage event can therefore cause a nearby nest to move from ordinary territory behaviour into investigation or hunting. A quiet nest can remain defensive while another sends scouts.

Visible nest geometry is part of the Heartforge vertical slice. The things organisms patrol and protect must exist in the same world rather than only as hidden spawn coordinates.

## 4. Regional ecology

The long-run regional ecology now assigns territory and directive to materialised organisms as well.

Regional spawns use the region center as ecological home, with a territory sized from that region. Region identity influences broad behaviour: nest/endgame regions favour protection and hunting, industrial/research regions favour patrol and scouting, and commercial areas permit more foraging behaviour.

A causal migration enters explicit hunting behaviour because it represents a population leaving one region toward another, not an ambient decorative spawn.

## 5. Heartforge vertical presentation slice

The opening district is the representative art target. The rest of the world is **not** declared production-quality because this slice exists.

The slice replaces the most damaging prototype cues around the Heartforge:

- four central opaque building cubes receive cutaway ruined facades while retaining their collision volumes;
- each central block gains a distinct urban identity rather than another generic box;
- facade structure includes exposed slabs, piers, dark interior depth, balconies, signage, fire escapes and roof failure;
- the plaza gains individual broken pavers, drains, utility cuts, old municipal markings and wet puddles;
- the sanctuary perimeter becomes visibly improvised and remains physically open rather than resembling an RTS wall ring;
- the Heartforge gains a maintenance gantry, hoist, service boom, external pipework and power umbilicals;
- environmental story includes evacuation remains, municipal machinery and routed field cables;
- organic nests become visible landmarks;
- local rain, steam and practical lighting create motion and depth;
- the tactical camera uses tighter framing, movement lead, threat-aware height and line-of-sight recovery;
- Mechromancer and machine silhouettes gain layered functional parts rather than relying only on symmetric primitive bodies;
- HUD density is reduced while the established legibility and notification bounds remain intact.

## 6. Visual direction of the slice

The opening should communicate:

**Grounded world first.** It is still recognisably a damaged town: masonry, municipal paving, shutters, drains, evacuation equipment, old signage and ordinary infrastructure.

**Machine technology is improvised.** The Heartforge and early robots should look assembled, repaired and adapted from existing industrial parts. Clean futuristic forms belong to later progression.

**Warmth is local and earned.** The Heartforge has practical amber warmth. The surrounding town remains cold, wet and threatening. The base should feel worth protecting without looking safe.

**The player is small.** The Mechromancer is a field mechanic with a weak weapon, not a glowing superhero. The Bulwark's mass should visually explain why the player depends on it.

**Organisms belong to places.** A nest, patrol route, scouting movement or feeding site should be readable in the environment before it becomes an attack.

## 7. Acceptance gates

Automated regression must verify that:

- multiple Scrappers receive independent assignments;
- their active wreck reservations are unique while enough sites exist;
- exhausted wrecks cause valid autonomous re-planning;
- Salvage focus spans multiple physical sites;
- protection remains distributed across salvage cells and the Mechromancer;
- an unprovoked patrol organism moves through its territory;
- nest guards remain constrained to a meaningful defensive envelope;
- scouts proactively travel outward;
- hunting packs share information;
- visible nest structures exist;
- the central building cubes are visually replaced by cutaway facades;
- the vertical-slice environment and actor-detail layers are present;
- established first-session and full start-to-victory tests still pass.

Automated tests are necessary but not sufficient for the presentation bar. The slice still requires human screenshot and gameplay review before its art language should be propagated across the wider town.
