# Long-Run Sandbox Design

## Purpose

Project Ironwight’s principal mode is one persistent world that may occupy the player for weeks of real time. This document defines pacing, persistence, failure, and how a long game avoids both grind and late-game chores.

---

## 1. Run promise

A world begins with almost nothing and ends only when the Heartforge is irreversibly lost or the player completes a final, voluntarily initiated survival objective.

The game does not divide the main experience into short scenarios. It does not reset after a wave sequence. It does not require the player to finish a run in one sitting.

Target duration hypotheses:

- first-hour collapse is possible and informative;
- many early worlds fail within 5–20 hours;
- advanced failed worlds may last 20–60 hours;
- a first victory may require 40–100 hours in one world;
- experienced players may win faster because they make better decisions.

Duration must come from discovery, changing threats, and consequential evolution—not from inflated costs, waiting, or repeated manual tasks.

---

## 2. Session structure

A player should be able to have a satisfying 20–45 minute session within a much longer world.

Possible session arcs:

- recover from the consequences of a previous attack;
- investigate one nearby signal;
- choose and observe a major evolution;
- accompany one machine expedition;
- rescue a trapped group;
- study an unfamiliar organism;
- prepare for and survive one causal ecological crisis;
- remain at the base and assess whether current autonomy is stable.

The game should support immediate save and exit outside of very short critical transitions.

---

## 3. Pacing through capability, not time gates

The world does not advance through a day counter that automatically spawns stronger waves. Progression follows interaction among:

- Heartforge activity;
- discoveries;
- local ecological disruption;
- machine capability;
- player-chosen evolutions;
- distance reached by excursions;
- unresolved threats.

A cautious player can delay some danger by remaining quiet, but cannot remain indefinitely static because local opportunities change, ordinary attrition continues, and long-term victory requires leaving safety.

A fast player can reach powerful discoveries sooner, but may provoke ecological systems before the machines can survive them.

---

## 4. World phases

Phases are descriptive states, not fixed chapters.

### 4.1 Embers

**Expected duration:** roughly 1–5 hours, highly variable.  
**Player burden:** direct survival, nearby recovery, first repairs.  
**World scale:** tens of metres reliably known.  
**Failure pattern:** death outside light, inability to restore the Heartforge, attracting a predator too early.

### 4.2 Shelter

**Expected duration:** roughly 5–15 hours.  
**Player burden:** choose first major trade-offs and begin trusting routine automation.  
**World scale:** nearby routes and one or two known objectives.  
**Failure pattern:** overconfidence in immature machines, insufficient response to a specialised threat.

### 4.3 Adaptation

**Expected duration:** roughly 10–30 hours.  
**Player burden:** decide which vulnerabilities to accept; undertake dangerous discovery objectives.  
**World scale:** a meaningful surrounding region, still not owned.  
**Failure pattern:** choosing an evolution combination that cannot answer a changing ecology.

### 4.4 Reach

**Expected duration:** roughly 20–50 hours.  
**Player burden:** authorise or accompany expeditions and resolve exceptional base crises.  
**World scale:** distant sites reached by machines.  
**Failure pattern:** expedition losses and base vulnerability reinforcing one another.

### 4.5 Siege ecology

**Expected duration:** roughly 30–80 hours.  
**Player burden:** manage rare strategic dilemmas, apex organisms, and irreversible preparation.  
**World scale:** broad knowledge without territorial ownership.  
**Failure pattern:** the Heartforge’s influence changes the ecology faster than its autonomy adapts.

### 4.6 Final understanding

The player has enough knowledge to attempt a permanent solution. The final process is chosen, not scheduled.

---

## 5. Avoiding long-run grind

### 5.1 No repeated unlock chores

Once a routine capability is learned, it stays learned for that world. The player should not repeatedly reassign, rebuild, or refresh it.

### 5.2 No inflated late costs

A major evolution should require a meaningful discovery and a plausible amount of Scrap. It should not require hours of passive accumulation merely to extend playtime.

### 5.3 No content checklist

The world should present a small number of meaningful current opportunities, not dozens of map icons. Some signals expire, move, or become irrelevant.

### 5.4 No mandatory daily maintenance

Returning after several real-world days should not require remembering a complex economic state. A clear world recap should summarise:

- current Heartforge condition;
- current unresolved strategic problem;
- active or proposed expedition;
- unfamiliar threats recently observed;
- next available major choices.

### 5.5 Strategic compression

As systems become familiar, the simulation aggregates them. The player does not repeat solved interactions at larger scale.

---

## 6. Persistent world generation

### 6.1 Authored rules, generated arrangement

The first version should use authored terrain modules, encounter spaces, ecological relationships, and objective templates arranged by seed.

Fully unconstrained procedural terrain is not required. The goal is replayable strategic variation with reliable navigation and encounter quality.

### 6.2 Starting area requirements

Every seed must provide:

- a damaged Heartforge location;
- a small defensible but imperfect local space;
- one nearby ordinary Scrap opportunity;
- one early unique lead;
- at least two plausible retreat routes;
- one stalking or scavenging pressure source;
- no immediate unavoidable major assault.

### 6.3 Regional variation

Regions differ through:

- terrain exposure;
- visibility;
- creature populations;
- burrow stability;
- weather;
- available unique discoveries;
- apex influence;
- route geometry.

They are not coloured ownership sectors.

---

## 7. Save system

Long-run reliability is a core feature, not technical polish.

### 7.1 Requirements

- automatic rotating saves;
- manual named saves where appropriate;
- transactional write and verification;
- schema version in every save;
- migration tests;
- recovery from interrupted write;
- world seed and deterministic random-stream state;
- event history sufficient for post-collapse diagnosis;
- optional compressed diagnostic snapshot.

### 7.2 Save cadence

Save automatically after:

- returning to the Heartforge;
- major evolution selection;
- expedition departure or return;
- rare ecological event resolution;
- unique discovery acquisition;
- significant recovery or loss state;
- regular safe intervals.

### 7.3 Simulation while offline

The world should not continue progressing while the application is closed. A weeks-long run refers to real-world play sessions, not forced real-time absence penalties.

---

## 8. Failure design

### 8.1 Failure must have a chain

A lost world should usually have an identifiable sequence:

1. a strategic weakness was accepted or overlooked;
2. the ecology exploited it;
3. recovery consumed reserves or machine capacity;
4. another pressure arrived before stability returned;
5. the Heartforge entered irreversible collapse.

### 8.2 Desperate recovery

Before final loss, the player may receive severe options:

- seal the core and abandon every outside machine;
- destroy a damaged Heartforge layer to stop infestation;
- recall an expedition and abandon its objective;
- sacrifice the Mechromancer’s current body to stabilise the core;
- activate a dangerous unfinished evolution;
- lure an apex creature through another population.

These options should create stories, not guarantee survival.

### 8.3 Post-collapse report

The report should include:

- world duration;
- major evolutions chosen;
- discovered species and behaviours;
- decisive strategic events;
- first sustained resource decline;
- machine-loss pattern;
- unresolved threat that caused final collapse;
- alternative responses the player had observed or unlocked;
- a timeline replay or concise causal summary.

The report avoids scolding the player for missing maintenance clicks.

---

## 9. Meta-progression

The preferred default is knowledge-rich and stat-light.

### 9.1 Persistent records

- bestiary observations;
- discovered evolution branches;
- encountered world phenomena;
- personal run history;
- cosmetic marks and Heartforge memorials;
- optional challenge modifiers.

### 9.2 Legacy memory

A limited optional system may allow one learned protocol to be carried into the next world. It should not erase the helpless opening.

Examples:

- the Scrapling recognises one common threat sooner;
- one previously discovered evolution appears as an early possibility;
- the map begins with one uncertain distant signal.

Avoid permanent percentage bonuses that make repeated failure a compulsory grind toward victory.

---

## 10. Endgame

The endgame remains base defence.

A successful run culminates in a player-initiated process that changes the Heartforge or the world. It should require:

- multiple unique discoveries;
- a mature autonomous machine population;
- at least one major unresolved ecological decision;
- the player to choose when the system is ready;
- an extended final period during which the Heartforge becomes the focus of world-scale pressure.

The final confrontation may resemble a horde in spectacle, but it is justified by the world and occurs once as culmination—not as the repeated pacing mechanism of the game.

Victory should visibly transform the same small place where the player began.

---

## 11. Long-run playtest metrics

Track:

- decisions requiring player acknowledgement per minute by game phase;
- time spent in management interfaces;
- number of routine alerts;
- percentage of attacks resolved without player input;
- percentage of Scrap handled automatically;
- time away from the Heartforge before and after autonomy upgrades;
- causes of run failure;
- save/load reliability across long simulated worlds;
- whether players remember their current strategic problem after several days away;
- whether late-game players describe pressure or chores as the main difficulty.

The most important qualitative question is:

> “When the game became larger, did it become more interesting or merely more demanding to operate?”
