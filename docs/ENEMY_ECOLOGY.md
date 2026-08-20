# Organic Enemy Ecology

## Purpose

Project Ironwight’s pressure comes from a hostile living world, not a wave scheduler and not an opposing robot faction. This document defines the first ecological model, creature roles, and rules for continuous pressure.

---

## 1. Core principles

1. **Enemies are organic.** Their forms use chitin, bone, membrane, muscle, roots, spores, and other biological materials.
2. **The world is not one army.** Species have different behaviours and may compete, flee, feed, or exploit one another.
3. **Threats exist in space.** A creature or population has a location, awareness, motivation, and route.
4. **Pressure has causes.** Activity, noise, vibration, carrion, repeated routes, and ecological disruption change risk.
5. **Large attacks are consequences.** They do not recur because a wave timer reached zero.
6. **Continuous pressure is often indirect.** Stalking, infestation, resource loss, changed routes, and damaged machines can create tension without constant wall combat.
7. **The player can learn.** Behaviour is discoverable through tracks, sound, remains, machine reports, and repeated outcomes.

---

## 2. Ecological simulation layers

### 2.1 Local full simulation

Near the Mechromancer and Heartforge, individual creatures use full movement, perception, combat, and interaction logic.

### 2.2 Regional population simulation

Beyond the active area, the world tracks populations and pressures rather than every individual:

- population size and health;
- nest or feeding areas;
- hunger or reproductive pressure;
- territory and migration tendency;
- awareness of the Heartforge;
- recent losses;
- nearby competing species;
- environmental conditions.

The complete-game regional director implements this layer as one bounded state
record per authored region. Each record persists population, health, food,
hunger, territory, nesting, disturbance and migration tendency. Active
organisms are materialised from that state and regional pressure; they are not
created by a recurring wave counter. Signals, kills and migration update the
same state, so the reason for a later concentration remains inspectable and
survives save/load.

### 2.3 Event materialisation

When a regional state enters the active area, it materialises as a consistent group or event. A migration is not spawned from nowhere; it represents a population that moved through the regional simulation.

### 2.4 Ecological memory

The world remembers:

- repeated robot routes;
- recent kills and carcasses;
- locations where creatures successfully fed;
- dangerous machine defences;
- noise and vibration sources;
- the Mechromancer’s repeated presence;
- abandoned objects or disabled robots.

This memory can decay and need not be individually simulated forever.

---

## 3. Initial creature families

The first commercial scope should favour six strongly differentiated families over dozens of minor variants.

### 3.1 Gleaners

**Role:** scavengers and perimeter nuisance  
**Silhouette:** low, many-legged, hooked mouthparts, reflective sensory patches  
**Motivation:** exposed Scrap, damaged robots, fresh carcasses  
**Behaviour:** approach cautiously, pull loose components away, flee from strong resistance, return in greater numbers to successful feeding sites

Gleaners create attrition without functioning as a direct army. If ignored, they reduce recovered Scrap and interfere with damaged-machine rescue.

**Player learning:** secure disabled machines quickly; avoid leaving biological carcasses against the shell; some deterrents are more efficient than killing every Gleaner.

### 3.2 Veilstalkers

**Role:** early-game fear and excursion predator  
**Silhouette:** long asymmetrical limbs, low head, dark hide broken by a few sensory membranes  
**Motivation:** isolated moving prey  
**Behaviour:** remain outside direct light, match the target’s movement, test retreat routes, attack when prey is injured or separated

The first Veilstalker should often be heard or partially seen before it is fought. It teaches the player that leaving the Heartforge is a risk rather than an invitation to clear the map.

**Player learning:** maintain sightlines to home; avoid returning along a predictable narrow route; the creature can sometimes be discouraged without being killed.

### 3.3 Undermaws

**Role:** subterranean base pressure  
**Silhouette:** rarely seen whole; armoured digging head, sensory filaments, circular mouth  
**Motivation:** vibration, warmth, and compacted ground  
**Behaviour:** investigate repeated mechanical activity, undermine structures, surface briefly at weak or resonant points, retreat when exposed

Undermaws make the ground itself strategically relevant without creating a building-placement puzzle. The Heartforge architect learns damping, anchoring, or sacrificial-hollow responses.

**Player learning:** fabrication intensity and repeated routes can draw attention; different Heartforge evolutions change the solution.

### 3.4 Pallid Bloom

**Role:** infestation and delayed failure  
**Silhouette:** pale fungal membranes, threadlike growth, spore sacs, infected organic carriers  
**Motivation:** damaged warm machinery and enclosed cavities  
**Behaviour:** spores attach during attacks or excursions, remain unnoticed, then impair sensors, joints, or repair material

The Bloom creates tension that is not direct hit-point damage. Machines may learn inspection and sterilisation routines. The player is asked to make a decision only when infestation exceeds familiar capability.

**Player learning:** some victories bring contamination home; sealed and open Heartforge architectures have different vulnerabilities.

### 3.5 Rakepacks

**Role:** coordinated mid-game hunters  
**Silhouette:** lean quadrupeds with bone hooks and lateral signalling crests  
**Motivation:** machines travelling in small groups, injured defenders, exposed retreat paths  
**Behaviour:** one group pressures the front while others circle; they disengage from strong static defence but pursue retreating targets

Rakepacks test machine cooperation and casualty recovery. They should punish isolated robots without requiring the player to form squads manually.

**Player learning:** expeditionary groups need complementary roles; wounded creatures may call or lead others.

### 3.6 Crownbeasts

**Role:** apex organisms and regional strategic threats  
**Silhouette:** enormous, unmistakable, biologically extravagant; each individual may have unique scars or morphology  
**Motivation:** territory, nesting, feeding, reaction to Heartforge signature  
**Behaviour:** not constantly hostile; alter the movement of all lesser species; may ignore the base until provoked or attracted

Crownbeasts are not conventional bosses waiting in arenas. Their presence changes the world. A nearby Crownbeast may suppress smaller predators while making one route impossible. Killing it can remove one threat and create a population surge elsewhere.

**Player learning:** ecological intervention has second-order consequences.

---

## 4. Pressure model

The pressure model should be a simulation of attention and ecological stress, not a single visible difficulty bar.

### 4.1 Heartforge signals

The Heartforge emits broad signals:

- light;
- sound;
- vibration;
- heat;
- chemical residue;
- carrion and machine damage;
- repeated robot movement.

Different species perceive different combinations. A quiet base is not universally safe; reducing one signal may increase another vulnerability.

### 4.2 Local ecological state

Each nearby region tracks:

- dominant species;
- available food;
- nesting state;
- population pressure;
- awareness of the Heartforge;
- recent conflict;
- weather effects;
- apex influence.

The game does not show these as resource bars. It translates them into evidence:

- tracks becoming more common;
- distant calls disappearing;
- lesser creatures fleeing;
- new burrow mounds;
- machines reporting repeated observation;
- carcasses appearing along a route;
- environmental colour or spore changes.

### 4.3 Pressure without attacks

The player should feel pressure through:

- routes becoming unsafe;
- machines returning damaged;
- Scrap recovery declining;
- a predator waiting outside light;
- a trapped machine rescue opportunity;
- contamination detected after an excursion;
- a distant migration forcing postponement;
- defensive routines consuming more replacement material;
- the Heartforge changing its behaviour to remain quiet.

Direct attacks are only one expression.

---

## 5. Rare major events

Major events are allowed when they are causal, uncommon, and meaningful.

### 5.1 Migration

A regional population crosses the Heartforge’s location because of season, weather, predation, or displacement. The player may endure, divert, conceal, or exploit it.

### 5.2 Nest retaliation

An excursion disturbs a breeding site. Surviving organisms track the machines home or gather before approaching.

### 5.3 Apex approach

A Crownbeast becomes interested in the Heartforge due to a major evolution, repeated hunting, or loss of territory.

### 5.4 Bloom outbreak

An unnoticed infestation reaches a critical stage and changes from routine maintenance into a strategic crisis.

### 5.5 Endgame convergence

The final player-initiated process produces a world-scale signal. This is the one moment when an enormous sustained assault may be appropriate, because it is the culmination of the run rather than a recurring rhythm.

### 5.6 Event telegraphing

Major events should be signalled through multiple channels:

- environmental changes;
- machine observations;
- sound;
- tracks and movement;
- altered behaviour of other species;
- approximate machine predictions.

A player may still misjudge the event, but should not feel that it appeared from a timer hidden by the designer.

---

## 6. Interaction among species

Simple inter-species relationships create a convincing ecology:

- Crownbeasts displace Rakepacks.
- Gleaners follow the aftermath of larger attacks.
- Pallid Bloom grows rapidly in carcass-rich zones.
- Veilstalkers avoid active Undermaw ground.
- Rakepacks may attack Gleaner concentrations.
- A migration can force normally distant species toward the Heartforge.

These relationships need not be biologically exhaustive. They need to create visible cause and effect.

---

## 7. Adaptation and learning

### 7.1 Player learning

The player learns species through experience and observation. The bestiary records reliable knowledge, uncertain hypotheses, and exceptions.

### 7.2 Machine learning

Machines can learn operational responses:

- safe retreat distance;
- which sound predicts attack;
- whether an organism pursues beyond light;
- which defensive response is effective;
- whether a carcass should be destroyed, harvested, or avoided;
- what expedition composition survives a route.

This is deterministic game logic, not required to use a trained neural network.

### 7.3 Enemy adaptation

Enemies should not simply gain universal stat bonuses. Adaptation may occur through selection or behaviour:

- Gleaners approach from darker angles after repeated losses;
- Rakepacks stop charging a known defensive opening;
- Bloom uses returning machines as carriers;
- Undermaws shift toward less reinforced ground;
- a Crownbeast becomes conditioned to a particular signal.

Adaptation must remain readable and species-specific.

---

## 8. Encounter design rules

- Early creatures should be dangerous in small numbers.
- A creature may retreat; not every contact becomes a fight to the death.
- Killing everything should rarely be the most efficient long-term strategy.
- Base pressure should continue when the player is away, but routine incidents should resolve autonomously.
- No encounter should exist only to fill a wave composition.
- Organic silhouettes must remain distinct from friendly machines at a glance.
- Creature audio must communicate behaviour, not merely atmosphere.
- Major creatures should change local strategy before direct combat begins.

---

## 9. Prototype sequence

### Prototype 1 — The unseen stalker

One Veilstalker remains outside the Heartforge light, follows the player during a short Scrap recovery, and attacks only after clear vulnerability.

Goal: make a thirty-metre excursion frightening without using many enemies.

### Prototype 2 — Routine perimeter pressure

Gleaners approach damaged machines and loose Scrap. The Scrapling initially responds poorly; after a learning unlock, machines recover assets automatically.

Goal: demonstrate pressure and autonomy in one system.

### Prototype 3 — Burrow consequence

Repeated fabrication activity attracts an Undermaw. The event has environmental warning and creates a Heartforge evolution choice.

Goal: demonstrate a causal major incident without a wave timer.

### Prototype 4 — Small ecology

Run Veilstalkers, Gleaners, and one regional apex influence together.

Goal: prove that changing one population affects another and produces non-scripted pressure.
