# Production Roadmap

## Overview

The roadmap proves the emotional and autonomy arc before investing in broad content. Each milestone has a gate. A later milestone should not begin merely because the calendar says so.

---

## Milestone 0 — Repository foundation

**Goal:** a reproducible project that Codex can change safely.

Deliverables:

- Godot 4.7.1 project opens and boots;
- typed GDScript conventions established;
- data schemas load;
- Python repository validation passes;
- GitHub Actions runs validation;
- save-service skeleton and test plan documented;
- asset-provenance rules established;
- representative issue and pull-request templates present.

Gate:

- clean checkout validates without manual repair;
- no undocumented third-party runtime assets;
- all contributors and agents can identify the canonical design locks.

---

## Milestone 1 — First Light

**Target experience:** 15–25 minutes.

Deliverables:

- small dark greybox around a damaged Heartforge;
- direct Mechromancer movement and camera;
- simple integrity and recovery;
- one dependent Scrapling with “stay close / remain home / return” behaviour;
- one Veilstalker that stalks outside light and attacks vulnerability;
- one nearby wreck containing Scrap;
- one required Heartforge repair;
- save/load of the scene;
- no wave timer;
- minimal HUD.

Design questions:

- Is leaving the light frightening?
- Does one creature create enough pressure?
- Is the Scrapling endearing rather than irritating?
- Does returning home feel relieving?

Gate:

- most playtesters retreat at least once without being explicitly told to;
- the opening screenshot reads as fragile survival, not an RTS base;
- no management menu is needed.

---

## Milestone 2 — First Delegation

**Target experience:** 30–45 minutes.

Deliverables:

- player initially identifies and retrieves ordinary Scrap;
- one machine-learning discovery unlocks material recognition;
- Scrapling gathers nearby ordinary Scrap automatically thereafter;
- machines repair familiar damage automatically;
- a visible routine continues while the player is elsewhere;
- exception-based notification system begins;
- event log records robot decision reasons.

Gate:

- the player permanently stops performing at least one early task;
- autonomy is visibly useful and understandable;
- the new capability does not create a configuration screen.

---

## Milestone 3 — Living Pressure

**Target experience:** 60–90 minutes.

Deliverables:

- Gleaner and Veilstalker behaviours;
- persistent local awareness and route memory;
- routine pressure occurs without attack waves;
- carcasses, damage, and repeated routes affect creature behaviour;
- routine incidents can resolve without player input;
- one rare causal incident with environmental telegraphing;
- accelerated simulation test for ecological stability.

Gate:

- players can explain why the rare incident occurred;
- tension exists during periods without direct combat;
- alerts do not become frequent.

---

## Milestone 4 — Compact Heartforge Evolution

**Target experience:** 90–150 minutes.

Deliverables:

- one major three-way choice: Mechromancer, Machines, or Heartforge;
- two or three Heartforge structural responses selected by principle, not placement;
- robots carry out exact construction and repair;
- attack history influences one autonomous adaptation;
- base remains within a constrained footprint;
- visual state communicates accumulated damage and repair.

Gate:

- players feel ownership over the result without placing structures;
- different choices create materially different survival problems;
- no repeated building interaction appears.

---

## Milestone 5 — First Expedition

**Target experience:** 2–3 hour vertical slice.

Deliverables:

- one unique distant discovery;
- machine proposal with benefit and risk summary;
- authorise / accompany / delay / decline interaction;
- autonomous group formation and route selection;
- retreat and casualty recovery;
- active-to-aggregated simulation transition if required;
- debrief explaining outcomes;
- Heartforge remains under routine pressure during absence;
- one causal major defence event, not a recurring wave.

Gate:

- the player makes a strategic expedition decision without selecting units;
- machines handle execution credibly;
- the base can survive briefly without the player;
- the full early-to-mid emotional arc is compelling.

This is the decisive vertical-slice gate. Do not expand content until it passes.

---

## Milestone 6 — Long-world simulation

**Goal:** prove that the design survives many hours.

Deliverables:

- regional ecology model;
- multiple simulation levels of detail;
- rolling saves and migrations;
- accelerated 20–50 hour simulation runs;
- machine replacement and population stability;
- post-collapse causal report;
- session recap after simulated absence;
- performance test with representative machine and creature counts.

Gate:

- no unbounded queues, memory growth, or save corruption;
- player decisions per minute do not rise with machine population;
- long-world failure is explainable;
- routine systems remain autonomous.

---

## Milestone 7 — Production alpha

Deliverables:

- full first-biome world generation;
- five or six robot chassis;
- six organic enemy families;
- two apex organisms;
- 12–20 major evolutions;
- complete victory and defeat paths;
- art pipeline operating with production assets;
- accessibility and difficulty settings;
- complete save migration suite;
- internal beginning-to-end playtests.

Gate:

- complete worlds can be won and lost;
- late game remains strategic rather than managerial;
- first-time failure and experienced success both feel fair;
- no placeholder system is masking a chore problem.

---

## Milestone 8 — External test

Sequence:

1. closed trusted playtests;
2. larger private test with telemetry and long-run diaries;
3. public demo only after the first two or three hours are polished;
4. broader testing of save reliability and long-session pacing.

Focus areas:

- why players abandon worlds;
- whether autonomy is trusted;
- whether pressure feels causal;
- whether late-game interaction becomes work;
- whether early darkness and vulnerability remain compelling after repeat runs.

---

## Explicitly deferred

Do not schedule these before the first vertical slice and long-world gates pass:

- multiplayer;
- additional biomes;
- multiple Heartforges;
- territory control;
- user-programmable robot code;
- procedural freeform base architecture;
- large narrative campaign;
- mod tools;
- console ports;
- advanced native performance rewrite;
- extensive cosmetic system.
