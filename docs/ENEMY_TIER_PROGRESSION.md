# Project Ironwright — Enemy Tier Progression

**Status:** Canonical implemented system
**Authority:** The current Project Ironwright conversation with Henrik  
**Purpose:** Make organic escalation emerge from physical population pressure, nest survival, and player activity rather than a recurring wave schedule.

## 1. Core rule

Each organic difficulty tier has:

- a current living population;
- a global living-unit cap;
- a replenishment rate measured in units per minute;
- a bounded fractional spawn credit;
- one or more physical nests capable of producing it.

When a non-final tier reaches its unit cap, the tier’s entire current replenishment allocation moves to the next tier at a `0.10` factor and the saturated tier’s rate becomes zero.

```text
if population[tier] >= cap[tier]:
    replenish[tier + 1] += replenish[tier] × 0.10
    replenish[tier] = 0
```

Saturation is processed from the highest non-final tier down to Tier 1. One evaluation therefore cannot instantly cascade the same replenishment through several already-full tiers.

Tier 5 is the final tier. At its cap, spawning pauses without discarding its rate.

## 2. Prototype values

The initial implementation deliberately uses accelerated balancing values:

| Tier | Name | Cap | Intended role |
|---|---|---:|---|
| I | Feral | 100 | Numerous, slow, primitive population |
| II | Territorial | 40 | Nest guards and patrol organisms |
| III | Hunter | 16 | Scouts, route observers, coordinated hunters |
| IV | Strategic | 6 | Ambush and infrastructure predators |
| V | Apex | 2 | Rare regional constraints |

Tier 1 starts at `1.0 unit/minute`. Its replenishment rate grows by `+1.0 unit/minute per minute` during the accelerated prototype.

These values are data, not code locks. Long-run balancing will almost certainly slow the growth substantially. The population-driven relationship is canonical; the exact numbers are not.

## 3. Replenishment-source model

The implementation distinguishes anonymous replenishment pressure from named physical sources.

### Anonymous pressure

Anonymous pressure includes:

- the continuously increasing Tier-1 background pressure;
- permanent ecological costs from Heartforge evolution;
- ecological consequences of technology and recovery operations;
- broad suppressive effects from major world actions.

### Named sources

Every physical nest contributes one or more named rates. A source stores:

- source identifier;
- owner/nest identifier;
- base tier and base rate;
- current evolved tier;
- current converted rate.

When a tier saturates, every named source currently allocated there moves upward and is multiplied by `0.10`. If its physical nest is later destroyed, the source is removed from whatever tier it has evolved into. This keeps nest clearing meaningful even after ecological escalation.

New Tier-1 growth enters Tier 1 when there is population headroom. If Tier 1 is still saturated, each new increment is routed upward immediately at 10:1. Previously evolved pressure does not move backward when casualties create headroom.

This produces the intended strategic result:

- killing low-tier organisms creates population headroom and makes new pressure refill weaker tiers;
- clearing nests removes long-term replenishment sources;
- allowing saturation permanently evolves existing pressure upward.

## 4. Spawn-credit rules

Each tier accumulates fractional spawn credit:

```text
spawn_credit += replenishment_per_minute × elapsed_seconds / 60
```

Credit is capped at `3.0` organisms. A missing, destroyed, or unsuitable nest therefore cannot build a hidden army of hundreds of births.

An organism is materialized only if:

- its tier is below cap;
- spawn credit is at least one;
- a living physical nest supports the tier;
- the persistent world can instantiate the organism.

It then spawns at a deterministic physical point around that nest and remains in the world. Distant simulation may reduce update detail but cannot replace the organism with a mission timer.

## 5. Physical nests

The initial world contains eight authored reproductive sources across the town, from small feral burrows near the Heartforge to the Root Cistern organ.

A nest defines:

- stable ID and physical position;
- region;
- maturity;
- health;
- supported tiers;
- per-tier replenishment contributions;
- delayed regrowth time.

Nests are targetable organic structures. Destroying one removes its active replenishment contributions immediately. A destroyed source remains physically visible and can show long-term regrowth evidence. Regrowth is slow, causal, and saved.

Regional suppression reduces effective nest contribution. Noise does not permanently increase replenishment; it changes attention and behavior of organisms already present.

## 6. Tier intelligence

Tier and species are separate. Several species can occupy a tier, while tier defines the maximum sophistication available to their behavior.

### Tier I — Feral

Tier I has only three purposeful states:

- random roaming;
- chasing a visible machine or Mechromancer;
- attacking.

It does not guard nests, scout, flank, observe routes, select infrastructure, or coordinate. Its threat comes from slow numerical density.

### Tier II — Territorial

Tier II can:

- protect a threatened home nest;
- patrol a repeatable territory ring;
- investigate disturbance;
- drive intruders from its territory;
- participate in primitive packs.

### Tier III — Hunter

Tier III can:

- scout beyond home territory;
- observe machine routes;
- prioritize exposed Scrappers, Engineers, Pathfinders, and channeling Mechromancers;
- retain last-known positions;
- share detections with pack members;
- retreat from an unfavorable engagement and return.

### Tier IV — Strategic

Tier IV can:

- target outposts and remote support infrastructure;
- prioritize vulnerable work frames;
- probe defensive coverage;
- move ahead of known routes to ambush;
- reinforce nests;
- abandon bad fights instead of attacking to death.

### Tier V — Apex

Tier V can:

- maintain a large territory;
- select Heartforge and remote infrastructure as regional strategic constraints;
- influence aggression and movement of nearby lower tiers;
- investigate major machine developments;
- alter route planning before direct combat begins.

Every enemy stores its tier, home nest, territory, behavior, goal, awareness, pack identity, and last-known prey information separately.

## 7. Dynamic world modifiers

Heartforge evolution and long-range operations can add or remove replenishment through data-configured effects.

`game/data/enemy_tier_event_modifiers.json` is the single authoritative table
for these permanent ecological effects. It owns operation, technology and
endgame replenishment deltas, Tier-I growth changes, bounded immediate spawn
credit, and the causal reason available to presentation and diagnostics. The base population file
`game/data/enemy_tier_progression.json` must not carry a second modifier table;
otherwise balancing changes could silently depend on which loader won.

Examples:

- loud technology recovery may increase Tier-I and Tier-II replenishment;
- clearing the Cathedral Brood reduces multiple tiers;
- restarting Riverworks drainage reduces local ecological throughput;
- mapping the Root Cistern increases late-game attention;
- luring the Apex reduces Tier-IV and Tier-V pressure.

The game reports whether a completed action increased or suppressed future reproduction. This is a strategic trade-off, not a hidden percentage difficulty increase.

## 8. Autonomous suppression

The design must not turn Tier-I control into a personal trash-mob chore.

After Heartforge Tier III, the machine society can identify dense Tier-I clusters close to the Heartforge and functioning outposts. Available Wardens autonomously form bounded suppression patrols when:

- Tier-I population exceeds the configured threshold;
- a real local concentration exists;
- Wardens are not needed for salvage, construction, expedition, or escort work.

They divide across separate population cells and return to reserve when pressure falls. The player chooses broader priorities and risky nest-clearing operations; the machines perform routine thinning.

Routine patrol reevaluation is ambient. Its current coverage remains visible
in command-map ecology intelligence, but an unchanged patrol does not create a
notification every eight seconds. A patrol standing down remains a legible
one-time transition because it can indicate either successful thinning or that
Wardens were reclaimed for a higher-priority commitment.

## 9. Player-facing intelligence

Exact population and rate tables remain available for tests and diagnostics. Normal play receives qualitative command-map intelligence:

- Tier-I density: low, sparse, present, dense, or saturated;
- highest confirmed tier;
- number of active reproductive nests;
- ecological trend;
- confirmed saturation transfer;
- current autonomous suppression activity.

The command map does not expose spawn sliders, budgets, per-nest workers, or another management economy.

## 10. Persistence

Enemy-tier state includes:

- populations;
- anonymous rates;
- fractional spawn credits;
- saturation states;
- named source locations and converted rates;
- applied world events;
- Heartforge progression already accounted for;
- nest health, maturity, destruction, and regrowth state;
- deterministic spawn serial.
- the in-progress simulation, population-reconciliation, and intelligence phase clocks;
- each living organism's decision, reduced-detail, and behaviour-state clocks plus deterministic roam and scout serials.

Current saves store this state once, inside the checksummed transactional world
snapshot under the unified `enemy_tier_progression` release payload. Tier
state, physical actors, nests and the world therefore come from the same save
generation and recover through the same rotating world backup.

Release-candidate 1 saves may have a separate `*.enemy_tiers.json` sidecar. It
is a read-only migration source only when the loaded world has no unified tier
payload. A valid unified payload always wins, including when an older sidecar
still exists beside it. New saves never create, overwrite or rotate the legacy
sidecar; after migration, the next transactional world save carries the state
in the unified payload.

## 11. Acceptance criteria

The implementation must prove that:

1. no upward transfer occurs below cap;
2. `10/min` at a saturated tier becomes exactly `1/min` in the next tier;
3. the source tier becomes zero after transfer;
4. processing high-to-low prevents same-tick multi-tier cascades;
5. casualties create headroom for new weak-tier growth;
6. no tier spawns beyond its cap;
7. spawn credit remains bounded;
8. destroyed nests stop contributing wherever their sources evolved;
9. technology and operation effects change the configured rates;
10. Tier-I organisms roam without purposeful nest defense;
11. Tier-II organisms patrol and guard;
12. Tier-III organisms scout, hunt, remember, and share detections;
13. Tier-IV organisms target routes, work frames, and infrastructure;
14. Tier-V organisms operate at a regional strategic level;
15. all tier-generated organisms emerge from valid physical nests;
16. remote organisms remain causal physical entities;
17. no recurring wave timer is introduced;
18. mature machine society suppresses routine low-tier concentrations without per-unit commands.
19. unchanged autonomous suppression patrols remain ambient command-map status, while a patrol standing down is reported once.

## 12. Design result

The world becomes more dangerous because the player allowed biological populations to saturate, left reproductive sources active, or accepted ecological costs for machine progress.

Seeing the first purposeful nest patrol, route scout, strategic predator, or Apex is therefore evidence of what has happened in the simulation. It is not merely a timer unlocking a stronger stat block.
