# Project Ironwright — Enemy Tier Progression and Ecological Escalation

**Status:** Canonical implemented design contract  
**Authority:** The current Project Ironwright conversation with Henrik  
**Runtime data:** `game/data/enemy_tier_progression.json`  
**Runtime director:** `game/scripts/systems/enemy_tier_director_3d.gd`

## 1. Product purpose

Enemy escalation is driven by the physical population of the ecology, not by a recurring wave timer or an arbitrary global difficulty level.

The central rule is:

> When a lower enemy tier saturates, its future reproductive throughput is converted into a much smaller replenishment rate for the next, more dangerous and more intelligent tier.

This makes active suppression strategically meaningful. Killing weak organisms creates population headroom and forces the ecology to spend its incoming capacity replacing those weak organisms. Clearing physical nests reduces the long-term replenishment source itself. Progression can disturb the world and increase future replenishment.

The player can therefore influence how quickly the world evolves upward.

## 2. Tier state

Every enemy tier `T` owns:

- `N[T]`: current living physical population;
- `C[T]`: unit cap;
- `R[T]`: replenishment rate in organisms per minute;
- `S[T]`: bounded fractional spawn credit.

The prototype values are data, not permanent balance locks:

| Tier | Name | Prototype cap | Primary pressure |
|---|---|---:|---|
| 1 | Feral | 100 | numerous, slow, primitive organisms |
| 2 | Territorial | 40 | nest defence and patrol |
| 3 | Predatory | 16 | scouting, hunting and pack memory |
| 4 | Strategic | 6 | route interception and priority targeting |
| 5 | Apex | 2 | rare regional strategic threats |

Scrap remains the only ordinary player resource. Enemy replenishment is a simulation state, not a player currency.

## 3. Tier-1 growth

Tier 1 is the root input to the ecological escalation ladder.

The accelerated prototype values are:

```text
initial R1 = 1 organism/minute
R1 growth = +1 organism/minute per elapsed minute
C1 = 100
```

This is deliberately fast enough to exercise the system during development. Long-run balance is expected to reduce or reshape the growth curve.

The invariant is more important than the placeholder number:

> Unless the player suppresses the ecology, the underlying Tier-1 replenishment pressure grows over time.

## 4. Saturation transfer

When a non-final tier is at cap and still owns a positive replenishment rate:

```text
if N[T] >= C[T] and R[T] > 0:
    R[T + 1] += R[T] × 0.10
    R[T] = 0
    S[T] = 0
```

The conversion is processed from high tiers downward. One Tier-1 saturation event therefore cannot cascade through several already-full tiers in the same simulation tick.

The 10:1 conversion creates a natural pyramid: many primitive organisms support progressively fewer advanced organisms.

At the final tier, replenishment becomes dormant while the tier is at cap and resumes when population headroom returns. It is not converted into an invisible sixth difficulty meter.

## 5. Why killing weak organisms matters

Suppose Tier 1 is saturated at 100/100. Its replenishment has begun flowing into Tier 2.

If machines kill 25 Tier-1 organisms, Tier 1 becomes 75/100. New Tier-1 replenishment is now spent filling those 25 slots rather than being promoted upward.

The player has therefore achieved two effects:

1. immediate tactical relief;
2. delayed advanced-tier escalation.

Ordinary organisms need no experience drop or second currency. Their removal is strategically valuable because it changes the ecology’s future allocation.

## 6. Population suppression versus source suppression

Killing an organism reduces population `N[T]`.

Destroying a nest reduces one or more replenishment rates `R[T]`, reduces Tier-1 rate growth, or both.

These are intentionally different actions:

- combat creates temporary population headroom;
- nest clearing changes long-term ecological throughput.

A player may be able to hold a high replenishment rate down for a while with machines, but eventually need to risk a physical nest-clearing operation to create durable relief.

## 7. Physical nests

Every replenishment spawn originates at a functioning `OrganicNest3D`.

A nest has:

- stable identifier;
- physical position;
- region;
- health and destruction state;
- maturity;
- supported enemy tiers;
- territory radius;
- spawn weight;
- replenishment reductions granted when destroyed.

Local Heartforge nests support early tiers. Regional mature nests support progressively higher tiers. The Root Cistern birth organ can support the complete ladder.

Enemies appear around these structures and continue to exist in the same persistent world. Remote simulation may reduce detail, but it may not replace them with detached timers.

## 8. Bounded spawn credit

Fractional replenishment is accumulated as spawn credit. Credit is capped at three organisms per tier in the prototype.

If no valid nest can produce a tier, the rate remains but credit does not grow into a hidden mega-spawn backlog. When an appropriate nest becomes available, production resumes at the current rate.

A small per-tick materialization limit prevents frame spikes and keeps population entry legible.

## 9. Intelligence progression

Tier is not merely a health multiplier. It defines the maximum sophistication available to an organism.

### Tier 1 — Feral

Tier 1 organisms:

- spawn near nests;
- move slowly;
- choose random roaming destinations;
- have no strategic objective;
- ignore ordinary noise as a purposeful signal;
- do not defend nests, scout routes, share information or choose infrastructure targets;
- attack the Mechromancer or machines only when directly detected with line of sight.

Their threat is density, not intelligence.

### Tier 2 — Territorial

Tier 2 organisms can:

- remain associated with a physical nest;
- patrol the territory and nest rim;
- protect brood sites from nearby intruders;
- respond to strong local disturbance;
- form primitive local packs.

They do not yet reason about the wider machine network.

### Tier 3 — Predatory

Tier 3 organisms can:

- scout beyond their territory;
- remember a last-known prey location;
- share detections with compatible pack members;
- hunt likely machine routes;
- prioritize exposed Scrappers, Pathfinders or the Mechromancer;
- withdraw and return rather than simply standing idle.

Seeing one can mean the machine society has been observed.

### Tier 4 — Strategic

Tier 4 organisms can:

- intercept known machine routes;
- prioritize Scrappers and Engineers;
- attack outpost service zones;
- reinforce threatened brood sites;
- choose flanking approach points;
- redirect existing organisms toward operation disturbances;
- abandon poor local engagements for more valuable targets.

### Tier 5 — Apex

Tier 5 organisms are rare regional constraints. They can prioritize critical infrastructure, maintain large territories and alter strategic planning before direct combat begins.

## 10. Species and tiers

Tier and species are separate concepts. Several species may occupy one tier, but every species has a canonical tier assignment in `enemy_archetypes.json`.

The ecology does not upgrade one model by silently increasing health. New tiers introduce new silhouettes, roles and behavior vocabularies.

The implemented mapping is:

- Tier 1: Skitterling;
- Tier 2: Razorhound, Roofleaper, Glassmoth;
- Tier 3: Veilstalker, Undermaw, Sporecaster;
- Tier 4: Broodmass, Miremaw, Carrion Bell, Rootweaver;
- Tier 5: Crownbeast.

## 11. Dynamic modifiers

Replenishment changes through world events.

### Nest clearing

A destroyed nest applies its configured long-term reductions immediately. Mature regional nests affect more than one tier.

### Technology and Heartforge evolution

Major technology and Heartforge upgrades can increase replenishment because they make the machine society louder, more detectable or biologically disruptive.

### Physical expeditions

Technology recovery and excavation operations can increase replenishment. Suppression operations such as clearing the Cathedral Brood or draining Riverworks can reduce it.

The exact effects are data-driven in `enemy_tier_event_modifiers.json` and applied once per completed event.

### Noise

Ordinary salvage, fabrication and combat noise does not permanently increase replenishment. Noise changes attention: existing organisms investigate, share information and converge. This preserves the distinction between ecological capacity and current local attention.

## 12. Operations and final protocols

Operation and endgame encounter requests may materialize an organism only while its tier is below cap. If the tier is already at cap, the disturbance redirects a nearby existing organism rather than creating one above the cap.

Starting a final protocol applies a configured high-tier ecological effect, but there is still no numbered wave schedule.

## 13. Autonomous suppression and anti-chore protection

This system must not turn into a demand that the Mechromancer personally farm Tier-1 organisms.

As machine autonomy grows:

- Wardens suppress dangerous low-tier concentrations;
- patrol and defence groups keep routes usable;
- outposts create local suppression and early warning;
- the machine society proposes or undertakes routine responses;
- the player chooses whether to commit capacity to a region or protect the Heartforge.

The strategic choice is where to accept pressure, not which of 43 weak organisms to click next.

## 14. Player-facing intelligence

Exact simulation rates are available to tests and diagnostics. Normal play exposes qualitative intelligence through the command map:

- density by confirmed tier;
- highest confirmed tier;
- active brood-site count;
- broad replenishment description;
- saturation warning;
- overall ecological trend.

The interface does not become a real-time strategy economy dashboard.

## 15. Persistence

The unified world save retains:

- tier rates;
- spawn credit;
- total transferred throughput;
- observed tiers;
- Tier-1 growth rate;
- physical nest health, maturity and destruction state;
- applied one-time progression modifiers;
- every living enemy’s tier, territory and ecological directive.

Older saves without these fields receive safe defaults and species-derived tier assignments.

## 16. Acceptance criteria

The implementation is acceptable only when deterministic tests demonstrate:

1. no upward transfer below cap;
2. exact 10:1 transfer at saturation;
3. population headroom prevents transfer;
4. recursive tiers transfer independently;
5. no tier exceeds its cap;
6. no destroyed nest produces organisms;
7. nest destruction reduces the configured rates;
8. progression effects alter rates once, not repeatedly;
9. Tier 1 is slow and restricted to feral roaming/direct engagement;
10. Tier 2 patrols or protects territories;
11. Tier 3 scouts or hunts purposefully;
12. Tier 4 chooses strategic machine/infrastructure targets;
13. all replenishment spawns originate near a valid physical nest;
14. save/load preserves rates, nests, tiers and applied events;
15. there is no recurring wave timer.

## 17. Design locks

The canonical locks are:

- escalation is population-driven, not wave-timer-driven;
- Tier 1 owns the fundamental growing replenishment pressure;
- saturation converts replenishment upward at 10:1 and zeros the lower rate;
- combat creates headroom, while nest clearing reduces sources;
- progression can impose ecological costs;
- intelligence increases qualitatively by tier;
- every birth has a physical nest source;
- spawn backlog is bounded;
- the top tier becomes dormant at cap;
- routine suppression becomes autonomous;
- Scrap remains the only ordinary player resource;
- all enemies remain organic.
