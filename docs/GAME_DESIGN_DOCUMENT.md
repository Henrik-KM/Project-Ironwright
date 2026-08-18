# Project Ironwight
## Game Design Document

**Working codename:** Project Ironwight  
**Player archetype:** The Mechromancer  
**Document version:** 1.0 — survival-first redesign  
**Primary platform:** Windows PC  
**Perspective:** Isometric 3D with direct character control  
**Principal mode:** One persistent sandbox world  
**Recommended implementation:** Godot 4.7.1 with typed GDScript  
**Commercial model:** Premium single-player game; no microtransactions

> **Pitch:** Begin with one damaged Heartforge and one almost-useless robot. Survive a hostile organic wilderness, risk short expeditions for the discoveries that matter, and gradually teach a compact machine home to defend, repair, build, and venture without your supervision.

---

## 1. Executive product decision

Project Ironwight is a long-form survival strategy game whose entire design revolves around one transformation: the player begins personally responsible for almost everything that keeps the Heartforge alive, but gradually creates machines capable of carrying that responsibility themselves.

The game is centred on one constrained base. The base does not spread across the world, establish an empire, or grow into a network of production sites. The Heartforge remains the physical and emotional home of the run. It begins as a damaged shell in darkness and ends, if the player succeeds, as a dense autonomous fortress surrounded by machines that can defend it and conduct distant expeditions.

The player directly controls the Mechromancer. Combat, exploration, retreat, and physical danger are experienced at character scale rather than from the detached viewpoint of an RTS commander. The strategic layer consists of a limited number of high-consequence decisions:

- which major evolution to choose;
- when leaving the base is worth the risk;
- whether an objective should be attempted personally or delegated;
- which weakness can remain exposed;
- whether machines should be sacrificed to protect the Heartforge;
- when the world is understood well enough to begin the final process.

The game deliberately avoids producing strategy through administrative volume. There is no conventional production-chain economy, no territory system, no multiple bases, no routine unit micro-management, and no scheduled-wave cadence. Pressure instead emerges from a hostile biological ecology that exists continuously around the Heartforge.

A full successful world should be played over many sessions and may take approximately 30–100 hours. The player is expected to lose several worlds before achieving a first victory, but losses must be understandable and attributable to strategic choices rather than surprise timers or neglected chores.

The defining rule is:

> **The base must not become larger to manage. It must become better at managing itself.**

---

## 2. Product identity

### 2.1 Genre

**Primary genre:** Survival strategy  
**Secondary genre:** Base defence, action survival, autonomous-machine simulation  
**Not the primary genre:** RTS, tower defence, colony management, factory automation, roguelite arena survival

The term “survival” refers to danger, uncertainty, darkness, retreat, injury, dependence on a fragile home, and the consequences of leaving safety. It does not imply hunger, thirst, temperature, sleep, or crafting-menu bureaucracy.

The term “strategy” refers to long-term commitments and risk selection. It does not imply managing large numbers of units or resources.

### 2.2 Player fantasy

The intended fantasy has four stages:

1. **Helpless invention.** The Mechromancer has awakened beside a failing machine and one crude creation. The nearby dark is genuinely unsafe.
2. **Earned reliability.** Repeated actions become learned machine behaviours. The player notices that things continue working without direct attention.
3. **Delegated survival.** The machines defend and maintain the base while the player considers larger risks.
4. **Created autonomy.** The player has not conquered the world, but has built a machine society capable of holding one home against it.

The emotional payoff comes from contrast. A late autonomous formation is meaningful because the player remembers when one damaged Scrapling could barely follow them.

### 2.3 Experience goals

The game should consistently produce these feelings:

- **Home matters.** Returning to the Heartforge should feel relieving even when it is damaged and under pressure.
- **The outside is dangerous.** Distance from the base is a risk multiplier, not merely travel time.
- **Every evolution changes the relationship with the machines.** Progress should introduce behaviour, independence, or a new survival option rather than only percentages.
- **The player is barely coping, but not drowning in notifications.** Strategic insufficiency is desirable; administrative overload is not.
- **The world feels alive rather than scheduled.** Threats have causes, locations, behaviours, and ecological logic.
- **The same base tells the history of the run.** Its scars, repairs, adaptations, and additions show what happened.

### 2.4 Product non-goals

Project Ironwight is not intended to provide:

- freeform architectural creativity;
- competitive multiplayer balance;
- esports-style high actions per minute;
- a giant technology spreadsheet;
- a broad economic simulation;
- a campaign made of short independent maps;
- a conventional wave-survival loop;
- a grand strategic map-painting experience;
- individual robot character management;
- a crafting-survival inventory full of consumable parts.

These may be attractive features in other games. They would dilute this game’s central promise.

---

## 3. Design pillars

### Pillar 1 — One home against a living world

The Heartforge is the only permanent base and the centre of every meaningful system. All excursions begin there, all ordinary machines return there, and defeat ultimately means the home can no longer sustain itself.

**Test:** Would the feature still make sense if the player could build five bases? If it depends on multiple settlements, it is probably wrong for this game.

### Pillar 2 — Autonomy is the primary progression

The most valuable upgrades allow the machines to perceive, decide, coordinate, or recover without direct orders. More firepower matters, but it is secondary to removing burdens and expanding safe delegation.

**Test:** Does an upgrade permanently remove a task, permit a previously impossible delegation, or change the machines’ behaviour? If not, it is not a major autonomy upgrade.

### Pillar 3 — Few decisions, serious consequences

The player should not make hundreds of small optimisations. The game should instead ask a smaller number of difficult questions whose consequences unfold over time.

**Test:** Could the decision be collapsed into one meaningful choice without losing strategy? If yes, collapse it.

### Pillar 4 — Pressure is continuous, combat is not

The world is always moving against the Heartforge through predation, scouting, infestation, resource competition, migration, and adaptation. The player should rarely feel completely safe, but should not be interrupted by constant attack alerts.

**Test:** Does the system create tension even when no enemy is currently striking a wall? If not, it is too dependent on direct combat.

### Pillar 5 — The opening is frightening

The first hours are close, dark, and sparse. A single creature can be a major threat. The player cannot safely treat the surrounding map as available territory.

**Test:** Would an early screenshot be mistaken for a functioning base-building game? If yes, the opening is too grand.

### Pillar 6 — Scale without management inflation

Late-game spectacle comes from autonomous behaviour, density, and reach. It does not come from asking the player to operate more menus.

**Test:** Does the feature create more recurring decisions because there are more robots or structures? If yes, redesign it.

---

## 4. The core loop

The fundamental loop is deliberately compact:

1. **Endure.** The Heartforge and its machines absorb the continuing pressure of the surrounding world.
2. **Recognise a need.** A weakness, discovery, threat, or opportunity becomes strategically important.
3. **Choose a risk.** The player decides whether to remain, leave personally, authorise a machine excursion, or ignore the opportunity.
4. **Venture and return.** The objective is attempted in hostile space, then survivors and recovered material return home.
5. **Choose an evolution.** Scrap and unique discoveries enable one consequential improvement to the Mechromancer, machines, or Heartforge.
6. **Integrate automatically.** Machines perform the exact rebuilding, reorganisation, replacement, and routine adaptation.
7. **Face the changed world.** The new capability changes both what is possible and what the world notices.

This loop should remain recognisable throughout a 60-hour world. What changes is who performs each step.

### 4.1 Early-loop example

The Heartforge’s outer plate has been torn open. The player sees a derelict machine twenty metres beyond the reliable light radius. It may contain enough Scrap to seal the breach.

The player goes personally because the Scrapling cannot gather deliberately. They hear movement, retrieve part of the wreck, retreat, and repair the breach. The next major machine evolution teaches the Scrapling to identify and return nearby useful material.

The important outcome is not “gathering became 10% faster.” It is that the player never again has to retrieve ordinary nearby Scrap by hand.

### 4.2 Mid-loop example

The Heartforge has detected a biological residue that the current defences cannot classify. A nearby carcass may reveal how a burrowing species senses vibration.

The machines can perform a routine salvage excursion, but the carcass lies beyond the range they consider safe. The player may:

- go personally with a small escort;
- authorise the machines to accept elevated losses;
- wait and risk another burrow attack without the adaptation;
- choose a different evolution instead.

The decision is strategic because every option exposes a different vulnerability. The player does not choose the robots’ route, formation, or individual equipment.

### 4.3 Late-loop example

The machines propose a deep expedition to recover a component needed for the endgame. The system estimates that ordinary perimeter defence will remain stable, but the base will have little reserve if an apex creature approaches.

The player chooses whether to authorise the expedition, accompany it, delay it, or provoke the apex creature first. Once authorised, the machines select participants, replace missing roles, navigate, fight, retreat, and report.

The number of decisions is still small. Their scope has grown.

---

## 5. The Heartforge

### 5.1 Role

The Heartforge is simultaneously:

- the base;
- the fabrication origin of all machines;
- the place where the Mechromancer recovers;
- the repository of learned machine behaviour;
- the physical record of the run;
- the condition for long-term survival;
- the focal point of enemy attention.

It should never feel like one building among many.

### 5.2 Physical growth

The Heartforge grows through discrete structural evolutions rather than free placement. Each evolution produces a visible transformation carried out by robots over time.

A useful structural model is a compact centre plus a limited defensive envelope:

- **Core shell:** the original damaged chamber and cognition apparatus.
- **Work ring:** fabrication, repair, storage, and robot circulation integrated into the shell.
- **Defence ring:** adaptive barriers, weapon mounts, traps, and sensor organs.
- **Outer scar:** temporary, replaceable structures where the world repeatedly damages the base.

The exact layout is generated by an autonomous architect from the current terrain, available modules, attack history, and chosen evolutions. The player does not place repeated components.

The footprint expands slowly and has a hard practical ceiling. The endgame Heartforge should still be recognisable as the same home seen in the opening.

### 5.3 Evolution choices

Heartforge improvements should be qualitative and mutually constraining. Examples:

- **Sealed shell:** substantially resists parasites and weather, but reduces passive sensory reach.
- **Open lattice:** improves observation and weapon arcs, but is more vulnerable to infiltration.
- **Deep anchors:** protects against burrowers, but makes future structural reorganisation slower.
- **Self-healing weave:** rapidly restores routine damage, but consumes more Scrap after severe attacks.
- **Quiet core:** reduces the distance from which creatures detect the base, but slows advanced fabrication.
- **Resonant core:** accelerates machine learning and fabrication, but attracts species sensitive to vibration.

The player chooses the principle. The machines decide how to implement it.

### 5.4 Damage and repair

Damage must be visible and consequential without turning into repair management.

Robots automatically:

- triage structural failures;
- repair ordinary damage;
- salvage destroyed modules;
- reopen blocked circulation paths;
- rebuild known defensive elements;
- postpone nonessential work when Scrap is scarce.

The player intervenes only when a strategic trade-off exists. For example:

> “The machines cannot restore both the western barrier and the fabrication chamber before nightfall. Preserve the barrier / preserve fabrication / attempt both and risk incomplete work.”

There is no wall-by-wall repair clicking.

### 5.5 Base activity and exposure

The Heartforge’s activity affects the ecology, but exposure is not presented as a conventional resource meter to optimise every minute.

The world responds to broad states:

- dormant;
- quiet;
- active;
- resonant;
- catastrophic.

Major evolutions, intense fabrication, mass repair, and powerful defensive events may change the base’s signature. The player understands the trade-off through environmental cues and clear warnings, not through managing a power graph.

---

## 6. The Mechromancer

### 6.1 Role throughout the run

The Mechromancer remains physically important from beginning to end, but their function changes.

**Early:** primary gatherer, fighter, repairer, and explorer.  
**Mid:** specialist intervention, dangerous expedition leader, and source of new machine learning.  
**Late:** decisive force used at exceptional points while routine survival is delegated.

The player should never become a disembodied cursor. Equally, the game should not force the player to personally perform routine work after machines have learned it.

### 6.2 Core actions

The base character kit should remain small and readable:

- movement and evasive step;
- primary tool-weapon;
- close repair or stabilisation action;
- one defensive ability;
- one machine-link ability;
- one signature ability determined by evolution.

Additional complexity should come from how abilities combine with machines and the environment, not from a bar containing twenty cooldowns.

### 6.3 Survival model

The Mechromancer has integrity or health, can be injured, and becomes more vulnerable farther from the Heartforge. There are no hunger, thirst, sleep, or temperature chores.

Distance creates danger through:

- slower recovery;
- weaker machine-link reliability;
- reduced knowledge of nearby threats;
- fewer safe retreat options;
- longer exposure to pursuing creatures;
- inability to rely on the base’s weapons or repair field.

The player should frequently turn back because continuing feels unsafe, not because an arbitrary stamina ration reached zero.

### 6.4 Personal evolution

Mechromancer evolutions should enable different risk styles rather than simply producing a damage ladder.

Example branches:

- **Warden:** stronger near the Heartforge, capable of stabilising breaches and amplifying base defence.
- **Wayfarer:** better at deep excursions, evasion, concealment, and recovering isolated machines.
- **Binder:** directly links nearby machines into unusually coordinated temporary behaviour.
- **Reclaimer:** extracts more value from dangerous biological remains and can salvage under pressure.

A player who invests heavily in the Mechromancer can personally solve exceptional problems, but cannot replace the long-term need for autonomous machines.

### 6.5 Death and recovery

Death must remain frightening without making a long world arbitrarily fragile.

A proposed structure:

- The Mechromancer carries a recoverable cognition imprint.
- If killed close enough to the Heartforge, machines may retrieve the imprint and rebuild the body at serious cost.
- Early machines may be unable to perform retrieval, making early death close to a run-ending event.
- Later autonomy improves recovery range and success.
- Death in an extreme location may permanently lose part of the current personal evolution or create a rescue objective.

The Heartforge’s destruction or irreversible collapse remains the primary defeat condition.

---

## 7. Robots

### 7.1 Robot promise

Robots are not conventional RTS units. They are the visible expression of learned capability.

The player should care less about whether a robot has 12% more damage and more about whether the machine can:

- recognise useful material;
- protect something without being told where to stand;
- retreat before being destroyed;
- repair another robot;
- infer what role is missing;
- form a viable expedition;
- adapt the base after observing a new enemy;
- continue functioning when the Mechromancer is absent.

### 7.2 Population model

The machine population grows from one Scrapling to a large autonomous community. The player does not maintain a production queue.

The Heartforge automatically fabricates and replaces ordinary machines according to:

- available Scrap;
- known designs;
- recent losses;
- base needs;
- expedition commitments;
- chosen machine doctrine.

The player may make broad evolutionary choices such as “fewer durable frames” or “many replaceable frames,” but does not specify a target count for every role.

### 7.3 Chassis families

The production scope should favour a small modular family rather than dozens of bespoke units.

Possible core chassis:

- **Scrapling:** small generalist; first robot; cheap, expressive, and visibly limited.
- **Bearer:** hauling, shielding, and recovering damaged machines.
- **Mender:** repair, stabilisation, parasite removal, and structural work.
- **Sentry:** defensive observation and ranged response.
- **Stalker:** reconnaissance, pursuit, and threat marking.
- **Bulwark:** late heavy defensive body used against apex threats.

Roles can emerge from modular attachments and learned behaviour. The player does not manually equip each machine.

### 7.4 Autonomy progression

Autonomy develops through five broad stages.

#### Stage 0 — Dependent

The first Scrapling can follow, remain near the Heartforge, and attack an obvious nearby threat. It frequently hesitates or chooses poorly.

The player may use only a few direct signals:

- stay close;
- remain at home;
- return.

This stage is intentionally intimate but short enough not to become irritating.

#### Stage 1 — Routine

Machines learn ordinary local work:

- identify nearby Scrap;
- bring it home;
- repair known damage;
- defend obvious approaches;
- return when damaged;
- replace simple destroyed components.

The player stops performing basic upkeep.

#### Stage 2 — Cooperative

Machines understand complementary roles:

- protect a Mender while it repairs;
- carry a disabled robot home;
- avoid blocking defensive fire;
- shift toward an underdefended side;
- preserve at least one functioning observer;
- share detected threats.

The player no longer arranges local formations or assigns workers.

#### Stage 3 — Expeditionary

Machines can propose and conduct bounded excursions:

- evaluate a known objective;
- choose a viable group;
- carry enough recovery capacity;
- select a route;
- retreat when the situation no longer matches assumptions;
- return and integrate findings.

The player chooses whether the objective is worth the risk, not how to execute it.

#### Stage 4 — Adaptive

Machines learn from repeated outcomes:

- alter base defences after attack patterns;
- change expedition behaviour after losses;
- identify which organisms require avoidance rather than combat;
- revise role composition;
- preserve strategic reserves without explicit instructions;
- recognise when routine doctrine is failing and request a decision.

The player increasingly receives proposals and exceptions rather than tasks.

#### Stage 5 — Sovereign

The machine population can maintain ordinary survival indefinitely under familiar pressure. It conducts routine excursions, replaces losses, repairs the Heartforge, and manages local defence.

The player remains necessary for:

- unprecedented threats;
- irreversible evolution choices;
- interpretation of unique discoveries;
- exceptional personal interventions;
- initiating and surviving the endgame.

Sovereignty is not an idle-game state. The world has also become more dangerous and less familiar.

### 7.5 Explainable behaviour

Autonomy must be understandable. Selecting a robot, group, or base process should provide a short natural-language explanation:

- “Returning: escort damaged Mender.”
- “Holding position: unknown burrow vibration ahead.”
- “Expedition delayed: no viable recovery unit available.”
- “Western defences reinforced: three recent attacks originated there.”

The explanation is diagnostic, not a configuration menu.

### 7.6 Emergency intervention

The player may have a small number of exceptional commands:

- universal recall;
- defend the Mechromancer briefly;
- preserve the Heartforge at any cost;
- abandon an expedition;
- focus on a marked apex target.

These are emergency strategic signals, not routine control tools.

---

## 8. Base defence

### 8.1 Defence as the permanent centre

Base defence is always the primary context of the game. Even when the player is on an excursion, the reason for the excursion should usually connect back to the Heartforge’s survival.

The base is not defended through tower placement optimisation. It is defended through:

- chosen Heartforge evolutions;
- machine intelligence;
- knowledge of local species;
- whether the player has accepted or avoided certain risks;
- the timing of excursions;
- strategic personal intervention;
- adaptation to accumulated attack history.

### 8.2 Ordinary pressure

Most attacks are not announced as events. Small organisms probe the perimeter, predators attack isolated machines, burrowers test weak ground, and parasites exploit damaged components.

By mid-game, machines should resolve most ordinary incidents without requiring the player to stop what they are doing. The consequences remain visible:

- a damaged machine is carried home;
- the outer shell bears fresh scars;
- repair activity consumes Scrap;
- a route is temporarily abandoned;
- the machines become more cautious in a direction.

The player notices the cost of survival without clearing alerts.

### 8.3 Exceptional defence decisions

The player is interrupted only when a strategic decision cannot be resolved locally:

- two critical systems cannot both be saved;
- an unknown organism has bypassed current assumptions;
- an expedition must be recalled to protect the base;
- an apex threat can be diverted at a significant cost;
- the Heartforge can seal itself, sacrificing outside machines;
- the Mechromancer must choose where to intervene.

### 8.4 Defensive adaptation

The autonomous architect records attack vectors and outcomes. Between incidents, machines may reposition modular defences, reinforce damaged ground, alter light, change patrol behaviour, or build a countermeasure unlocked by research.

The player can inspect the proposal and, for major changes, approve one of a small number of approaches. The exact geometry is not the player’s burden.

### 8.5 Major assaults

Large assaults exist, but they are rare and causal. Examples:

- a breeding colony is disturbed;
- a large carcass draws multiple predators toward the Heartforge;
- a resonant evolution awakens a subterranean organism;
- a migration intersects the base;
- the player kills an apex creature’s young;
- the endgame process broadcasts an unavoidable signal.

These events should have strong environmental telegraphing: distant movement, altered creature calls, tremors, scent trails, scouts, fleeing lesser animals, or machine predictions. There is no recurring wave counter.

---

## 9. The organic enemy ecology

### 9.1 Core direction

Enemies are living creatures, alien organisms, or biologically transformed fauna. They should contrast sharply with the deliberate geometry and cold light of player machines.

The world is not a unified army. Different species have different needs and may compete, feed on one another, avoid apex predators, exploit the player, or be redirected.

This creates pressure that feels systemic rather than scheduled.

### 9.2 Ecological roles

The first production scope should use a small number of readable roles:

- **Scavengers:** attracted to damaged machinery and exposed Scrap; weak alone, persistent in groups.
- **Stalkers:** follow the Mechromancer or isolated robots, testing whether prey is separated from safety.
- **Burrowers:** approach below the surface and exploit repeated vibration or structural weakness.
- **Spore carriers:** contaminate damaged structures and create delayed problems rather than direct damage alone.
- **Pack hunters:** coordinate around retreat routes and injured targets.
- **Apex organisms:** rare territorial creatures that fundamentally alter local movement and risk.

A species may fill more than one role, but silhouettes and behaviour should remain legible.

### 9.3 Pressure sources

World pressure increases through understandable causes:

- the Heartforge becomes more active and detectable;
- local prey or carrion is displaced;
- robots repeatedly use the same route;
- the player harvests a creature’s nesting material;
- a regional population grows without predation;
- weather or migration changes movement patterns;
- the player kills or provokes a territorial organism;
- a new Heartforge evolution emits light, heat, sound, or vibration.

The game may use hidden simulation variables, but the player should receive environmental evidence rather than arbitrary difficulty spikes.

### 9.4 No mechanical mirror faction

There are no corrupted robot legions or enemy machine civilisation in the core game. Machine silhouettes must remain associated with the player’s created order.

Biological organisms may infest or temporarily disable machines, but they do not become generic enemy robots.

---

## 10. Excursions

### 10.1 Purpose

Excursions are the game’s main source of active risk and discovery. They extend outward from the Heartforge but do not create permanent ownership.

Objectives include:

- retrieving Scrap from a nearby wreck;
- recovering a unique component;
- examining tracks or biological residue;
- rescuing a disabled machine;
- destroying an immediate nest or feeding site;
- luring a creature away from the base;
- reaching an ancient site;
- observing an apex organism;
- recovering the Mechromancer’s lost imprint;
- completing an endgame preparation.

### 10.2 Early excursions

Early excursions are short and personal. The reliable world may extend only thirty to fifty metres beyond the Heartforge.

Key sensations:

- the base light remains visible and comforting;
- sounds beyond visibility create uncertainty;
- retreat is often the correct decision;
- one recovered object can materially change survival;
- the Scrapling is helpful but not trustworthy;
- the player cannot safely clear the area permanently.

### 10.3 Mid-game excursions

The Mechromancer can travel farther with machine support. Robots understand return conditions and basic recovery.

The player chooses among a small set of opportunities. The game should not fill the map with dozens of checklist markers. Signals are uncertain and may expire, move, or become more dangerous.

### 10.4 Autonomous excursions

Once expeditionary intelligence is unlocked, machines can propose objectives based on known needs:

> “A compatible repair organ may be recoverable from the northern carcass field. Estimated benefit: unlock parasite-resistant repair. Estimated risk: high. Heartforge reserve during absence: low.”

The player chooses:

- authorise;
- accompany;
- delay;
- decline.

The machines handle composition, routing, local tactics, recovery, and return.

### 10.5 Excursion resolution

Important expeditions should be simulated in the world and may be observed or joined. Very distant routine movement may use reduced-detail simulation, but outcomes must remain consistent with the same rules.

A machine expedition should not fail because of an opaque dice roll. The game should preserve enough event data to explain:

- what was encountered;
- why the machines fought or retreated;
- which assumption failed;
- what was lost;
- what was learned.

### 10.6 No claim-land loop

Excursions do not culminate in capturing a node, building an outpost, or converting the area into player territory. A route may become better understood, temporarily safer, or more dangerous, but the outside remains outside.

---

## 11. Economy and progression

### 11.1 Scrap

Scrap is the only ordinary stockpiled resource. It represents recoverable matter, machine parts, structural material, and routine fabrication input.

Scrap is automatically used for:

- ordinary repairs;
- robot replacement;
- Heartforge construction;
- routine defensive adaptation.

The player does not distribute it manually. The interface shows a simple total and, when relevant, a short forecast such as:

- stable;
- declining;
- critical;
- sufficient for proposed evolution;
- insufficient after current repairs.

There is no need to display multiple income rates unless a playtest proves a single aggregated trend is useful.

### 11.2 Unique discoveries

Major progression uses unique objects and knowledge rather than currencies. Examples:

- a cognition core that enables cooperative behaviour;
- a biological membrane that teaches vibration damping;
- an ancient fabrication lattice;
- a damaged autonomous scout memory;
- an apex creature organ that enables a new defensive response;
- a fragment that reveals the final objective.

A unique discovery is obtained once and creates a meaningful branch or capability.

### 11.3 Three evolution paths

The strategic progression is organised around three subjects:

1. **Mechromancer:** personal survival, excursion capability, intervention, and machine linkage.
2. **Machines:** cognition, cooperation, chassis capability, and expedition autonomy.
3. **Heartforge:** structural resilience, self-repair, detection, fabrication, and defence.

These are not three giant technology trees. The player encounters major evolution opportunities at deliberate intervals and chooses among a small number of visible transformations.

### 11.4 Evolution cadence

A full run may contain roughly 12–20 major evolutions, plus smaller automatic improvements derived from repeated machine experience.

Major choices should:

- be understandable without a spreadsheet;
- visibly alter the game;
- create a new strength and a persistent compromise;
- remain relevant for many hours;
- support different survival philosophies.

### 11.5 No research currency

The player does not earn generic science points over time. Knowledge comes from observation, recovered objects, repeated encounters, and unique sites.

The machines may learn gradually, but the player does not maintain laboratories or assign researchers.

---

## 12. Long-form sandbox structure

### 12.1 One persistent world

The main menu offers a new world, continue, settings, and records. There is no requirement for a campaign of discrete missions.

A world is generated from an authored set of ecological and terrain rules. The Heartforge begins in a constrained location with nearby opportunities and threats, but the surrounding world extends far beyond early perception.

The player saves and leaves at any time. Session length may vary from twenty minutes to several hours.

### 12.2 Run duration

The initial target is:

- early failed worlds: 1–10 hours;
- developing failed worlds: 10–40 hours;
- first successful world: approximately 40–100 hours;
- experienced successful worlds: potentially shorter through better judgment, not permanent stat inflation.

These ranges are balance hypotheses. The game should not artificially prolong itself through waiting, inflated costs, or repeated chores.

### 12.3 Phases without timers

The world evolves through capability and consequence rather than a fixed clock.

#### Embers

The Heartforge barely functions. The player stays close, learns the immediate area, and performs tasks machines cannot yet understand.

#### Shelter

Routine gathering, repair, and local defence become autonomous. The player can leave for short periods without immediate collapse.

#### Adaptation

The base learns from specialised threats. The player begins making difficult choices between personal capability, machine intelligence, and structural resilience.

#### Reach

Machines can conduct expeditions. The outside world becomes larger, but the base remains constrained and continuously pressured.

#### Siege ecology

The Heartforge is now a major presence in the local ecosystem. Apex organisms, migrations, and advanced infestations create strategic crises.

#### Final understanding

The player learns what must be done to achieve a permanent victory condition and chooses when to begin it.

No phase begins because a timer reached day 30.

### 12.4 Victory

Victory should require the player to understand and alter the source of the world’s escalating hostility. The exact narrative may change, but the final process should:

- require discoveries from distant objectives;
- depend on the chosen relationship among Mechromancer, machines, and Heartforge;
- be initiated voluntarily;
- create an unmistakable final ecological response;
- test the autonomous system built across the entire run;
- remain centred on defending the Heartforge.

Possible high-level outcomes include stabilising the Heartforge so it no longer provokes the ecology, sealing a world-scale biological network, or transforming the machine-home into a self-sustaining refuge.

### 12.5 Defeat

A world is lost when the Heartforge’s core is irreversibly destroyed, corrupted, or abandoned.

Defeat should generally emerge as a visible spiral rather than one instantaneous surprise. Warning states may include:

- repair demand consistently exceeds recovery;
- machine population cannot replace ordinary losses;
- repeated infestations are compromising the core;
- the player has provoked an apex threat without a viable answer;
- an essential unique component has been lost in an inaccessible area;
- the Heartforge can no longer maintain a safe recovery zone.

The player should often have desperate recovery options, but not guaranteed rescue.

### 12.6 Learning between worlds

The primary meta-progression is player knowledge. A post-collapse record explains the chain of failure and preserves discovered lore.

Optional persistent elements may include:

- a bestiary that retains observed behaviour;
- records of discovered evolution branches;
- cosmetic machine forms;
- a single limited legacy memory selected for the next world;
- additional world-generation modifiers.

Permanent numerical bonuses should be minimal or absent so that the opening remains frightening.

---

## 13. Difficulty and fairness

### 13.1 Intended difficulty

The default game should be difficult enough that first victory is unlikely on the first several worlds. Difficulty should arise from incomplete knowledge, long-term trade-offs, and a living ecology—not from hidden stat multipliers alone.

### 13.2 Fair failure

A player should be able to answer:

- What pressure did I underestimate?
- Which evolution left me exposed?
- Which excursion was mistimed?
- What warning did I ignore?
- What did the machines understand incorrectly?
- What could I do differently in the next world?

The game should record enough history to produce a useful post-collapse analysis.

### 13.3 Anti-save-loss safeguards

Because worlds are long, the save system is a product-critical feature.

Requirements:

- rolling automatic saves;
- multiple recoverable checkpoints;
- versioned migrations;
- validation before overwrite;
- deterministic world seeds where practical;
- event-log support for diagnosing corrupted or surprising states;
- no single-save-only design.

### 13.4 Difficulty options

Difficulty settings should change ecological aggression, recovery tolerance, and information clarity rather than add chores.

Possible options:

- creature perception and persistence;
- frequency of rare ecological crises;
- Scrap recovery efficiency;
- Mechromancer reconstruction cost;
- amount of warning before unfamiliar threats;
- severity of failed expeditions.

There should also be accessibility settings for pause, game speed, aim assistance, visual contrast, camera motion, text size, and input remapping.

---

## 14. User interface and information design

### 14.1 Minimal operational HUD

The ordinary HUD should show only information that can change the player’s immediate decision:

- Mechromancer integrity;
- Heartforge condition;
- total Scrap or simple Scrap trend;
- current exceptional objective;
- nearby danger cues;
- machine-link status;
- a small number of context actions.

There is no permanent display of ten resource types, worker counts, production rates, sectors, or supply routes.

### 14.2 Exception-based notifications

Routine events should not create alerts. Notifications are reserved for situations such as:

- unfamiliar threat;
- proposed major evolution;
- expedition requiring authorisation;
- strategic repair conflict;
- machine doctrine cannot resolve a situation;
- rare discovery;
- imminent irreversible loss.

The player should be able to trust silence.

### 14.3 Autonomy summaries

The player can inspect aggregated machine intent through a calm summary:

- maintaining Heartforge;
- defending perimeter;
- recovering Scrap;
- expedition preparing;
- reserve depleted;
- unknown behaviour observed.

This is not a command panel. It explains what the system is doing and why.

### 14.4 Camera progression

The camera can subtly reinforce growth:

- early game uses a closer, lower, more claustrophobic framing;
- mid-game permits a broader base view;
- late game allows a wider tactical view and an expedition overview when required.

The game should avoid beginning with a grand world map. Early mapping is uncertain and local.

### 14.5 Map design

The map is primarily a record of known routes, signals, losses, and observations. It is not a territory-control screen.

Early map information may be incomplete or approximate. Later machine sensing improves confidence and permits expedition proposals.

---

## 15. Art direction

### 15.1 Visual thesis

The visual identity comes from contrast:

- **Machines:** deliberate geometry, worn metal, articulated tools, small precise lights, repeated modular forms, and visible repair.
- **Organic world:** asymmetry, wet or fibrous surfaces, chitin, bone, membranes, burrows, spores, and movement that feels hungry or territorial.
- **Heartforge:** a mechanical hearth—cold cognition light surrounded by warm practical lamps and repaired industrial material.

### 15.2 Early game

The opening should be dominated by darkness and negative space.

- One weak pool of light.
- A damaged, partially buried Heartforge.
- One Scrapling with an imperfect gait.
- Sparse tools and exposed components.
- Creatures seen partially, briefly, or at the edge of light.
- Minimal interface.
- No complete walls or polished technology.

The early Heartforge should look like survival is improbable.

### 15.3 Mid-game

The Heartforge has become compact and busy rather than sprawling.

- Robots repair and circulate without instruction.
- Defensive elements are integrated into the shell.
- The outside remains close and threatening.
- Scars and mismatched repairs tell the history of attacks.
- The player can see routines continuing while considering an excursion.

### 15.4 Late game

The same base has become dense, coordinated, and formidable.

- Many robots operate with clear purpose.
- Large organic creatures test the perimeter.
- Expedition groups depart and return.
- The Heartforge contains layered defensive morphology.
- The scale is impressive, but the footprint remains bounded.

The late game should not resemble a city or industrial map covering the landscape.

### 15.5 Concept-art status

The included images are mood and progression references. They are not production-ready assets, exact UI specifications, or final layout commitments.

Any UI text visible in generated concept art is illustrative only. The design documents define the actual systems.

---

## 16. Audio direction

### 16.1 Survival through sound

The hostile world should often be heard before it is seen. Audio communicates:

- movement outside light;
- burrowing direction;
- distant migration;
- a stalker matching the player’s pace;
- changes in local creature calls;
- machine distress and recovery;
- the Heartforge’s health and activity.

### 16.2 Machine language

Robots should communicate status with compact, learnable tones and mechanical gestures rather than constant speech. As autonomy develops, their soundscape becomes more coordinated.

The first Scrapling may emit uncertain, isolated sounds. Late formations use layered confirmations, warning patterns, and repair rhythms.

### 16.3 Music

Music should preserve tension without exhausting the player across long sessions.

- sparse ambient texture near the opening;
- restrained mechanical motifs as the Heartforge stabilises;
- organic pulses or dissonance when the ecology changes;
- music reserved for truly exceptional confrontations rather than every routine attack;
- a strong late-game theme that transforms the fragile opening motif.

---

## 17. Technical design principles

### 17.1 Simulation over scripts

Threats should emerge from persistent world state rather than a list of timed wave scripts. The ecology may be simplified, but creatures should have locations, needs, awareness, and consequences.

### 17.2 Deterministic and inspectable autonomy

Robot intelligence should use understandable systems such as utility scoring, planners, state machines, and shared memory. It does not require opaque machine learning.

Every consequential action should be explainable from logged inputs and chosen goals.

### 17.3 Simulation levels of detail

The game must support many machines and creatures without simulating every detail everywhere.

- full simulation near the Mechromancer and Heartforge;
- reduced tactical simulation for visible distant groups;
- aggregated state transitions for remote expeditions and ecological populations;
- consistent rules across levels of detail;
- deterministic reconstruction when groups return to full simulation.

### 17.4 Save-first architecture

Every persistent system must be designed for serialisation, versioning, and migration from the beginning. Long worlds make save reliability more important than rapid addition of content.

### 17.5 Data-driven content

Robot roles, autonomy stages, enemy archetypes, unique discoveries, and evolution choices should be defined as data where practical. This allows Codex and designers to extend content without rewriting core logic.

### 17.6 No premature complexity

The first implementation should not begin with a custom ECS, procedural world generator, sophisticated navmesh replacement, or hundreds of units. Build representative testbeds, profile, and add complexity only after the central loop is enjoyable.

---

## 18. Initial production scope

The first playable proof should be a **First Night** experience lasting approximately 15–25 minutes:

- one damaged Heartforge;
- one Mechromancer;
- one dependent Scrapling;
- one ordinary resource;
- one short repair objective;
- one organic stalker species;
- darkness and a small reliable safety radius;
- no wave timer;
- a reason to retreat from the outside;
- one qualitative machine-learning unlock;
- a visible reduction in player burden after that unlock.

The first vertical slice should then extend to approximately two or three hours and demonstrate:

- routine autonomous gathering;
- autonomous repair;
- continuous ecological pressure;
- one rare causal major attack;
- one unique discovery;
- one major choice among Mechromancer, Machines, and Heartforge;
- one machine-led excursion proposal;
- a compact base capable of surviving briefly without the player;
- a clear early-to-mid visual transformation.

It should not contain:

- multiple resources;
- multiple bases;
- manual wall placement;
- territory capture;
- production queues;
- scheduled waves;
- hostile robots;
- a giant map;
- more than a small set of robot and creature archetypes.

---

## 19. Content plan for a complete game

A disciplined first commercial scope could contain:

- one principal world biome with meaningful local variation;
- one Heartforge with five or six structural stages;
- one Mechromancer model with several visible evolution states;
- five or six modular robot chassis;
- approximately six core organic species plus variants;
- two or three apex organisms;
- 12–20 major evolution decisions;
- 20–30 unique discoveries or objective types;
- one principal victory path with several strategic variants;
- procedural combinations of authored terrain and ecology rules;
- a bestiary and world record that survive between runs.

Additional biomes and victory paths are expansion opportunities, not prerequisites for proving the game.

---

## 20. Product acceptance criteria

Project Ironwight is on direction when all of the following are true:

1. A new player is afraid to leave the Heartforge’s light during the opening.
2. The player understands why returning home matters.
3. The first autonomy unlock permanently removes a task the player performed manually.
4. A base with 100 robots does not require roughly ten times the attention of a base with 10 robots.
5. Routine attacks can occur without forcing the player to stop and issue orders.
6. A major attack can be traced to world state or player action rather than a recurring timer.
7. The player can describe an important decision without mentioning placement, production ratios, or worker allocation.
8. The base remains compact and recognisably the original Heartforge.
9. Enemies read clearly as organic life rather than machines.
10. A failed world produces a useful explanation of the strategic chain that caused collapse.
11. The UI becomes calmer rather than busier as autonomy improves.
12. The late game delivers large autonomous-machine spectacle while preserving survival tension.

---

## 21. Open design questions

These questions should be resolved through prototypes rather than abstract debate:

- How long should the dependent-robot stage last before it becomes tedious?
- Should the Mechromancer’s death ever immediately end a world, or always create a recovery opportunity?
- How much exact information should an autonomous expedition provide before authorisation?
- How visible should hidden ecological pressure variables be?
- Can autonomous base reconfiguration remain legible without letting the player edit geometry?
- What is the smallest number of robot chassis that still creates convincing late-game variety?
- How large can the machine population become before individual simulation stops improving the experience?
- How frequently should rare major assaults occur in a 60-hour world?
- What final victory process best preserves base defence as the centre of the endgame?

These are valid uncertainties. The locked principles in `DESIGN_LOCKS.md` are not.
