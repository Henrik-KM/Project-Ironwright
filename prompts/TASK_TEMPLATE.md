# Codex Task Template

## Goal

Describe one observable player or developer outcome.

## Why it matters

Connect the task to one design pillar and one current milestone.

## Required reading

List only relevant files, always including `AGENTS.md` and `docs/DESIGN_LOCKS.md` for gameplay work.

## In scope

- Specific behaviours or files.
- Data/schema changes.
- Tests.
- Documentation updates caused by actual behaviour changes.

## Out of scope

Explicitly name tempting adjacent systems that must not be added.

## Product constraints

Answer:

1. What strategic decision does this create?
2. What recurring work does it add?
3. How is routine execution delegated?
4. Why does it not increase workload with scale?

## Acceptance criteria

Use observable, binary criteria. Include save/load, diagnostic reasons, and design-lock compliance where relevant.

## Validation

```bash
python scripts/validate_repo.py
```

Add the exact Godot test and smoke-test commands available in the repository.

## Deliverable report

- changed files;
- test results;
- controls or reproduction steps;
- limitations;
- design decisions made;
- no-go systems explicitly not introduced.
