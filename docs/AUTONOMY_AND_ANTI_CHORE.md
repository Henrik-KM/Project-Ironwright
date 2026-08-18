# Autonomy and Anti-Chore Design

## Purpose

This document defines how Project Ironwight can become larger and more strategically demanding without becoming busier to operate.

The central requirement is not merely that robots act automatically. The requirement is that **player workload does not scale with machine population, base complexity, run length, or attack frequency**.

Automation is successful only when it removes recurring work from the player’s future.

---

## 1. Workload budget

The game should target a relatively stable rhythm of meaningful input:

- ordinary play: one consequential decision every few minutes;
- dangerous excursion: faster direct survival input, but little administrative input;
- exceptional base crisis: a short cluster of high-stakes decisions;
- stable late game: long periods in which the player watches, explores, or considers proposals without servicing systems.

The player may be mechanically active while fighting or evading. The forbidden form of busyness is operational administration.

### 1.1 What may scale

The following can grow dramatically:

- number of robots visible;
- number of simultaneous autonomous activities;
- distance reached by expeditions;
- sophistication of enemy behaviour;
- physical density of the Heartforge;
- consequences of a strategic choice;
- spectacle of a crisis.

### 1.2 What must not scale linearly

The following must remain flat or decline:

- number of routine orders;
- number of maintenance actions;
- number of production decisions;
- number of unit configuration decisions;
- number of alerts requiring acknowledgement;
- number of repeated construction actions;
- number of resource transfers;
- number of map regions requiring inspection.

---

## 2. Teach once, automate forever

Every early manual action should be evaluated as a candidate for permanent delegation.

| Early experience | Learned capability | Permanent consequence |
|---|---|---|
| Player identifies useful wreckage | Material recognition | Nearby ordinary Scrap is gathered automatically |
| Player repairs a damaged robot | Mutual repair | Machines stabilise and recover one another |
| Player defends one side of the Heartforge | Threat response | Machines reposition toward observed danger |
| Player escorts a hauler | Cooperative protection | Vulnerable roles receive automatic escorts |
| Player retreats from a predator | Risk memory | Machines avoid or disengage from that organism |
| Player retrieves a disabled machine | Recovery protocol | Bearers recover disabled machines automatically |
| Player demonstrates a short excursion | Expedition model | Machines can propose and execute similar trips |

The player should not need to demonstrate every action literally. A recovered cognition core, observation, or major evolution may teach it. The key is that the resulting capability removes a recurring burden.

---

## 3. The autonomy ladder

### 3.1 Dependent

**Player experience:** one flawed companion.  
**Allowed direct inputs:** stay close, remain home, return.  
**Why it exists:** establish contrast and emotional attachment.  
**Maximum duration:** long enough to make the first improvement meaningful; short enough that incompetence does not become a chore.

Failure patterns should be expressive and legible. The Scrapling may hesitate, misunderstand distance, or pursue an obvious target too far. It should not fail because of broken pathfinding or arbitrary randomness.

### 3.2 Routine

**New machine responsibilities:** local gathering, known repairs, ordinary replacement, obvious perimeter defence.  
**Player burden removed:** maintenance and local material collection.

The player should be able to leave the Heartforge briefly and return to find that ordinary work continued.

### 3.3 Cooperative

**New machine responsibilities:** role assignment, escorts, casualty recovery, local defensive redistribution, shared detection.  
**Player burden removed:** worker assignment, formations, and per-role coordination.

The machine population becomes a system rather than a crowd.

### 3.4 Expeditionary

**New machine responsibilities:** objective evaluation, group composition, route selection, retreat, return, and debrief.  
**Player burden removed:** unit selection, supply preparation, and route drawing.

The player authorises risk. Machines execute it.

### 3.5 Adaptive

**New machine responsibilities:** update local doctrine from outcomes, alter defensive geometry, revise expedition assumptions, preserve reserves, and request input when doctrine conflicts.  
**Player burden removed:** repeated reconfiguration after familiar problems.

### 3.6 Sovereign

**New machine responsibilities:** maintain ordinary survival under familiar pressure and conduct routine distant activity.  
**Player responsibility retained:** unprecedented problems, evolution, moral or strategic sacrifice, and endgame initiation.

The game does not become idle. The player’s attention moves to exceptional decisions.

---

## 4. Intent without command interfaces

Project Ironwight should avoid solving micro-management with a complicated macro-management panel. A menu containing budgets, zones, priorities, ratios, and rules is still management.

The preferred interaction model is **proposal and commitment**.

### 4.1 Machine proposal

A proposal contains only information needed for a strategic decision:

> **Recover the buried cognition core**  
> Expected benefit: unlock coordinated retreat  
> Risk to expedition: high  
> Risk to Heartforge during absence: moderate  
> Machines expect to return before local weather changes  
> **Authorise / Accompany / Delay / Decline**

The player does not choose:

- exact participants;
- individual equipment;
- route waypoints;
- marching formation;
- repair supplies;
- engagement ranges;
- which robot carries the object.

### 4.2 Strategic overrides

A small set of global emergency signals may exist:

- recall all excursions;
- protect the Heartforge regardless of losses;
- preserve machines and concede outer damage;
- converge on the Mechromancer;
- abandon a trapped group;
- focus an explicitly marked apex organism.

These signals should be costly, exceptional, or cooldown-limited so they do not become routine orders.

### 4.3 No policy configurator

Avoid screens that ask the player to set:

- repair percentages;
- desired worker counts;
- target inventories;
- patrol radii;
- engagement distance;
- acceptable casualties as a numeric slider;
- priority weights for every behaviour.

When a genuine strategic doctrine is needed, present a discrete, understandable choice:

- **Preservation doctrine:** machines retreat early and protect experienced frames.
- **Defiance doctrine:** machines accept higher losses to prevent structural damage.
- **Predation doctrine:** machines pursue wounded threats to reduce future pressure.

A doctrine should be rare, broad, and visible—not a tuning panel.

---

## 5. Autonomous base evolution

### 5.1 Inputs to the architect

The Heartforge’s autonomous architect uses:

- current structural shell;
- terrain immediately around the base;
- attack history;
- observed creature capabilities;
- chosen Heartforge evolutions;
- available known modules;
- current Scrap constraints;
- movement and fire-line requirements.

### 5.2 Player interaction

For routine changes, the architect acts automatically.

For a major structural adaptation, it may offer two or three approaches:

> Burrow damage is increasing beneath the southern shell.
>
> - **Anchor deeply:** best protection, slows future restructuring.
> - **Create a sacrificial hollow:** cheaper, accepts recurring outer damage.
> - **Reduce vibration:** lowers burrow attention, slows fabrication.

The player chooses the principle. The robots place and build the result.

### 5.3 Visual legibility

Autonomous building must not feel arbitrary. Before major work begins, the game may briefly show:

- the intended affected area;
- what problem is being addressed;
- which trade-off the selected plan accepts;
- approximate time and Scrap consequence.

The player can understand the change without editing it.

### 5.4 No perfect optimisation requirement

The architect does not need to create mathematically ideal layouts. It needs to produce coherent, readable, and sufficiently effective structures whose quality improves through evolution.

Early machine construction may look improvised and inefficient. Late construction is organised, redundant, and adaptive. This visible improvement is part of the fantasy.

---

## 6. Exception-based information

### 6.1 Routine events remain ambient

Do not notify the player when:

- one robot collects Scrap;
- a small attack is repelled;
- a common robot is replaced;
- a known wall section is repaired;
- a routine excursion departs or returns successfully;
- a common creature is detected at normal distance.

These events should be visible in the world or available in an optional log.

### 6.2 Notify only when a decision exists

Notify the player when:

- a unique discovery is available;
- an unfamiliar organism invalidates known doctrine;
- the system cannot satisfy two critical needs;
- an expedition carries unusual risk;
- the Heartforge is approaching irreversible failure;
- a major evolution is available;
- a rare causal assault is forming;
- an autonomous system has low confidence and requests guidance.

### 6.3 Trustworthy silence

Silence must mean that routine survival is being handled. The player should not feel compelled to open management screens to confirm that nothing is secretly failing.

If a system can deteriorate catastrophically without a prior exception notification, the notification model is broken.

---

## 7. Explainability without debugging overload

The player needs concise reasons, not developer telemetry.

### 7.1 Normal explanation

Selecting an entity or proposal shows one sentence:

- “Waiting because the route is occupied by an unknown burrower.”
- “Returning because the group has lost its only recovery machine.”
- “Reinforcing the east shell after repeated climbing attacks.”
- “Not rebuilding the outer lamp because Scrap is reserved for core repair.”

### 7.2 Deep inspection

An optional advanced panel may expose more detail for interested players and debugging:

- current goal;
- evaluated alternatives;
- top utility factors;
- known threats;
- confidence;
- source of the objective;
- relevant remembered event.

Deep inspection is never required for ordinary play.

### 7.3 Determinism

Given the same world state and random seed, an autonomous decision should be reproducible where practical. This supports player trust, testing, and diagnosis of long-world failures.

---

## 8. Anti-chore feature review

Before implementation, every system must complete this table.

| Question | Required answer |
|---|---|
| What meaningful decision does the system create? | One clear strategic decision |
| What recurring work does it add? | None, or work that is later permanently removed |
| Does workload grow with robot count? | No |
| Does workload grow with base age? | No |
| Can routine outcomes resolve without an alert? | Yes |
| Can the player understand failure without configuring the system? | Yes |
| Is there a simpler aggregated representation? | Use it if possible |

### 8.1 Immediate rejection examples

Reject or redesign features such as:

- assigning each robot a role;
- choosing exact robot production ratios;
- resupplying ammunition;
- repairing individual wall pieces;
- drawing patrol routes;
- placing power links;
- setting storage priorities;
- clearing repeated “enemy detected” messages;
- manually launching every routine expedition;
- re-equipping replacements after each loss.

---

## 9. Prototype tests

### Test A — Ten versus one hundred robots

Give a playtester a base with 10 robots and another with 100 robots under proportionally scaled routine pressure.

Success condition: the 100-robot state requires no more routine decisions per minute than the 10-robot state.

### Test B — Leave the base

Ask the player to take a ten-minute excursion after routine autonomy is unlocked.

Success condition: the base continues operating, and the player is interrupted only if a genuine strategic exception occurs.

### Test C — Unknown enemy

Introduce a creature that defeats current doctrine.

Success condition: the player receives one clear strategic problem, not dozens of local failure alerts.

### Test D — Recover from damage

Apply severe but familiar damage to the Heartforge.

Success condition: machines execute triage and reconstruction automatically. The player chooses only if competing critical needs cannot both be met.

### Test E — Interface regression

Compare screenshots of early, mid, and late HUDs.

Success condition: the late HUD is not denser than the mid HUD merely because more systems exist.

---

## 10. Definition of done for autonomy

An autonomy stage is complete only when:

- its newly delegated behaviours work under representative pressure;
- the player no longer needs the superseded manual action;
- failures produce understandable reasons;
- the behaviour survives save/load;
- off-screen and on-screen outcomes are consistent;
- it does not require a new routine configuration screen;
- playtests show a measurable reduction in player maintenance input.
