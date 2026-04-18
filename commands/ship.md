---
name: ck-ship
description: "One-shot end-to-end: describe a feature, get it built — sketch, map, make, check with no user gates. For tiny features and throwaways."
argument-hint: "<feature description> [--skip-check] [--peer-review] [--max-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-build.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh:*)", "Bash(git *)"]
---

**What this does:** Runs the full Cavekit pipeline (sketch → map → make → check) from a single feature description, with no stops for design review or user gates.
**When to use it:** Tiny features and throwaways. For anything non-trivial, use the guided `/ck:sketch` path — the design conversation is where the value is.

## Phase 0: Resolve Execution Profile

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" summary` and print that line once.
2. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" model reasoning` → `REASONING_MODEL`.
3. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" model execution` → `EXECUTION_MODEL`.
4. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" model exploration` → `EXPLORATION_MODEL`.

Use those exact model strings in every delegated phase.

## Parse Arguments

From `$ARGUMENTS`:
- **Feature description** — everything that isn't a flag (required)
- `--skip-check` — skip the check phase
- `--peer-review` — pass through to make
- `--max-iterations N` — pass through to make

If no description:

> Usage: `/ck:ship <describe what you want built>`
>
> Example: `/ck:ship add a REST API for user profiles with CRUD operations and JWT auth`

Stop and wait.

---

## Phase 1: Streamlined Sketch

No interactive Q&A. No approach proposals. No incremental presentation. Dispatch a `ck:drafter` subagent with `model: "{REASONING_MODEL}"`.

### 1a: Ensure Directories

Create if missing: `context/kits/`, `context/plans/`, `context/impl/`, `context/impl/archive/`, `context/refs/`.

### 1b: Explore Context (silent)

1. Check for existing `context/kits/`.
2. Read README, CLAUDE.md.
3. Scan codebase structure.
4. `git log --oneline -10`.
5. Check for `DESIGN.md` at project root.

### 1c: Decompose and Write Kits

1. Decompose into domains (prefer fewer — 1 is fine).
2. Write `context/kits/cavekit-{domain}.md` with standard format (frontmatter, R-numbered requirements, testable acceptance criteria, Out of Scope, cross-references).
3. Write `context/kits/cavekit-overview.md`.

**Rules:**
- YAGNI — only what the user described.
- Acceptance criteria must be testable.
- If `DESIGN.md` exists and feature is UI, reference design tokens in criteria.
- Skip the cavekit-reviewer loop — self-check inline: no TODOs, no placeholders, no implementation leakage.

### 1d: Report (brief)

```
--- Sketch ---
Domains: {count}
Requirements: {count}
Files: {list}
```

Proceed.

---

## Phase 2: Streamlined Map

Dispatch a `ck:map` subagent with `model: "{REASONING_MODEL}"`.

1. Read all cavekit files just written.
2. Decompose requirements into T-numbered tasks.
3. Organize into dependency tiers.
4. Write `context/plans/build-site.md` with standard format (tier tables + Mermaid graph + Coverage Matrix).

**Rules:**
- M-sized tasks.
- Every criterion maps to at least one task (inline Coverage Matrix check).
- Genuine blockers only.
- For UI tasks, include `Design Ref: DESIGN.md Section {N}` if DESIGN.md exists.
- Overwrite any existing site without asking.

### 2c: Report (brief)

```
--- Map ---
Tasks: {count}
Tiers: {count}
Tier 0 (parallel start): {count} tasks
```

Proceed.

---

## Phase 3: Make

Run the **full make phase** exactly as `/ck:make` defines it — no shortcuts:

1. Execute `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-build.sh"` with passthrough flags.
2. Run the execution loop (frontier → dispatch → merge → track → repeat).
3. All circuit breakers apply.
4. Uses `EXECUTION_MODEL`.

---

## Phase 4: Check (unless `--skip-check`)

Run the **full check phase** exactly as `/ck:check` defines it:

1. Dispatch `ck:surveyor` with `model: "{REASONING_MODEL}"` for gap analysis.
2. Dispatch `ck:inspector` with `model: "{REASONING_MODEL}"` for peer review.
3. Synthesize into inspect report with verdict (APPROVE / REVISE / REJECT).
4. Auto-revise kits and site if gaps found.

---

## Final Report

```markdown
# Ship — Complete

**Feature:** {original description}

## Pipeline
| Phase | Status | Details |
|-------|--------|---------|
| Sketch | Done | {n} domains, {n} requirements |
| Map    | Done | {n} tasks, {n} tiers |
| Make   | Done | {n} waves, {n}/{n} tasks |
| Check  | {Done/Skipped} | {verdict or "skipped"} |

## What was built
{2–3 sentence summary}

## Files changed
{list key files}
```

If check ran and verdict is REVISE/REJECT: `Next: /ck:make to address remaining tasks, or /ck:check for details.`
