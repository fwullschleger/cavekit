---
name: sdd-plan
description: "Generate a feature frontier from specs — the task dependency graph that drives execution"
argument-hint: "[--filter PATTERN]"
---

# SDD Plan — Generate Feature Frontier

This is the second phase of SDD. You read specs and generate a feature frontier — a dependency-ordered task graph that tells the executor what to build and in what order.

No domain plans. No file ownership. No time budgets. Just: tasks, what spec requirement they implement, and what blocks what.

## Step 1: Validate Specs Exist

Check `context/specs/` for spec files. If none found, tell the user:
> No specs found. Run `/sdd:brainstorm` first.

If `--filter` is set, only include specs matching the filter pattern.

## Step 2: Read All Specs

1. Read `context/specs/spec-overview.md` if it exists (for dependency graph)
2. Read all `context/specs/spec-*.md` files (apply filter if set)
3. Catalog every requirement (R-numbered) with its acceptance criteria and dependencies

## Step 3: Decompose Requirements into Tasks

Break each requirement into one or more implementable tasks:
- Simple requirements (1-2 acceptance criteria) → 1 task
- Complex requirements (3+ acceptance criteria, multiple concerns) → multiple tasks
- Each task should be completable in one loop iteration

Use T-numbered task IDs (T-001, T-002, ...) across all domains.

## Step 4: Build Dependency Graph

For each task, determine what it's blocked by:
- Explicit dependencies from spec (R2 depends on R1)
- Implicit dependencies (can't test an API endpoint before the data model exists)
- Cross-domain dependencies (notifications depend on the events they notify about)

Organize tasks into tiers:
- **Tier 0**: tasks with no dependencies (start here)
- **Tier 1**: tasks that depend only on Tier 0 tasks
- **Tier 2**: tasks that depend on Tier 0 or Tier 1 tasks
- etc.

## Step 5: Write the Frontier

Create the `context/frontiers/` directory if it doesn't exist.

Write `context/frontiers/feature-frontier.md`:

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Feature Frontier

{Total tasks} tasks across {total tiers} tiers from {spec count} specs.

---

## Tier 0 — No Dependencies (Start Here)

| Task | Title | Spec | Requirement | Effort |
|------|-------|------|------------|--------|
| T-001 | {title} | spec-{domain}.md | R1 | {S/M/L} |
| T-002 | {title} | spec-{domain}.md | R1 | {S/M/L} |

---

## Tier 1 — Depends on Tier 0

| Task | Title | Spec | Requirement | blockedBy | Effort |
|------|-------|------|------------|-----------|--------|
| T-003 | {title} | spec-{domain}.md | R2 | T-001 | {S/M/L} |

---

## Tier 2 — Depends on Tier 1
...

---

## Summary

| Tier | Tasks | Effort |
|------|-------|--------|
| 0 | {n} | {breakdown} |
| 1 | {n} | {breakdown} |
| ... | | |

**Total: {n} tasks, {n} tiers**
```

If a frontier already exists, ask the user whether to overwrite or keep the existing one.

## Step 6: Report

```markdown
## Plan Report

### Specs Read: {count}
### Tasks Generated: {count}
### Tiers: {count}
### Tier 0 Tasks: {count} (can start immediately)

### Next Step
Run `/sdd:execute` to start the implementation loop.
Run `/sdd:execute --adversarial` to add Codex review.
```

### Rules

- Every spec requirement MUST map to at least one task
- Tasks should be small — prefer M over XL
- Dependencies must be genuine blockers, not just ordering preferences
- The frontier is the ONLY planning artifact — no domain plans, no file ownership
- Update `last_edited` if modifying an existing frontier
