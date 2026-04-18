---
name: ck-init
description: "Bootstrap the context hierarchy and runtime — creates context/, .cavekit/ state dir, detects capabilities, writes .gitignore entries. Use --tools-only to just re-detect available tools."
argument-hint: "[--tools-only [--summary-only]]"
allowed-tools: ["Bash(node ${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs:*)", "Bash(cat .cavekit/capabilities.json)", "Bash(git *)", "Read(*)", "Write(*)", "Edit(*)", "Glob(*)"]
---

**What this does:** Creates the full context hierarchy AND the autonomous-runtime state directory for a Cavekit project. With `--tools-only`, only re-detects available CLI tools, MCP servers, and plugins.
**When to use it:** Once at the start of a project. Re-run any time — idempotent. Re-run with `--tools-only` after installing a new tool or when a task fails with "command not found".

## Mode: `--tools-only` (capability discovery only)

When `--tools-only` is passed, skip the context-hierarchy setup and only re-run capability discovery:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs" discover
```

This writes `.cavekit/capabilities.json`. Read it back and summarize:

```bash
cat .cavekit/capabilities.json
```

Print a short, human-readable table:

```
═══ Cavekit Capabilities ═══

CLI tools:
  ✓ git, gh, node, python3, docker
  ✗ codex, graphify, supabase

MCP servers:
  (none detected)

Codex peer review: UNAVAILABLE (install `codex` on $PATH to enable /ck:review --codex)
Knowledge graph:   UNAVAILABLE (run `graphify build .` to enable graph-backed routing)
```

With `--summary-only`, skip writing the JSON file and only print the summary.

### Recommendations

After the summary, offer a short list of optional upgrades based on what is missing:

- If `codex` is missing: mention the peer-review workflows that would unlock (`/ck:review --codex`, tier gate).
- If `graphify` is missing: mention the `graphify-integration` skill.
- If `gh` is missing: mention that `/ck:check` can post gap reports as GitHub issues when `gh` is present.

Do not install anything. Just recommend.

### Critical rules (`--tools-only`)

- Capabilities are advisory, never prescriptive. A missing tool is not an error — it is information for `/ck:sketch` to consider.
- Do not store credentials. Availability ≠ reachability.
- The default `/ck:init` path already runs discovery — `--tools-only` is for re-detection.

Then exit without touching `context/` or `.gitignore`.

---

## Default mode — full bootstrap

Creates the full context hierarchy and the runtime state directory.

## Properties

- **Idempotent** — creates only what's missing. Safe to re-run.
- **Non-destructive** — never overwrites existing files.
- **No questions** — does not ask what you're building (that's `/ck:sketch`).

## Step 0: Initialize Runtime State

Run the runtime initializers. These are no-ops if `.cavekit/` already exists.

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs" init
node "${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs" discover
```

After this:
- `.cavekit/config.json` — runtime config (session budget, task budgets, parallelism, etc.)
- `.cavekit/state.md` — phase state machine (`phase: idle` to start)
- `.cavekit/token-ledger.json` — session + per-task token accounting
- `.cavekit/capabilities.json` — detected CLI tools, MCP servers, plugins
- `.cavekit/history/` — backprop audit trail (created on first entry)

### Ensure `.gitignore` covers runtime state

If the repo has a `.gitignore` and it does not already mention `.cavekit/`, append this block (read the file first and only append if missing):

```
# Cavekit runtime — transient state
.cavekit/.loop.json
.cavekit/.loop.lock
.cavekit/.progress.json
.cavekit/.auto-backprop-pending.json
.cavekit/.debug.log
.cavekit/tool-cache/
.cavekit/state.md
.cavekit/token-ledger.json
.cavekit/task-status.json
.cavekit/tasks.json
.cavekit/capabilities.json
```

Commit `.cavekit/config.json` and `.cavekit/history/` intentionally — they are the user's tunables and the audit log.

## Step 1: Scan Existing Project Structure

Detect top-level directories that contain source code or other project artifacts:
- `src/`, `lib/`, `app/`, `pkg/`, `cmd/`, `internal/` (source directories)
- `tests/`, `test/`, `spec/` (test directories)
- `scripts/` (utility scripts)
- Any other directories that contain code files (`.ts`, `.js`, `.py`, `.go`, `.rs`, `.java`, etc.)

Record which directories exist — you'll create CLAUDE.md files for them in Step 3.

## Step 2: Create Context Directories

Create these directories if they don't exist:
- `context/`
- `context/refs/`
- `context/kits/`
- `context/designs/`
- `context/plans/`
- `context/impl/`
- `context/impl/archive/`

## Step 3: Create CLAUDE.md Files

Create each file below **only if it does not already exist**. Never overwrite.

### `context/CLAUDE.md`

```markdown
# Context Hierarchy

This project uses Cavekit's context hierarchy.

## Tiers
- refs/ — Source material (Tier 1: what IS). Read-only.
- kits/ — Requirements (Tier 2: what MUST BE). Start at cavekit-overview.md.
- designs/ — Visual design system (cross-cutting constraint). Start at DESIGN.md.
- plans/ — Task graphs (Tier 3: HOW). Start at plan-overview.md.
- impl/ — Progress tracking (Tier 4: what WAS DONE). Start at impl-overview.md.

## Navigation
Start at the overview file in whichever tier is relevant to your task.
Only load domain-specific files when the overview points you there.
For UI work, always read DESIGN.md at the project root first.
```

### `context/refs/CLAUDE.md`

```markdown
# Reference Materials

Source of truth that kits are derived from. Read-only.

## Conventions
- Organized by source in subdirectories (e.g., prd/, old-code-docs/, api-spec/)
- Agents read but never modify these files
- Kits reference specific files and sections via file:line
```

### `context/kits/CLAUDE.md`

```markdown
# Kits

Kits define WHAT needs implementing. They are implementation-agnostic.

## Conventions
- Start with cavekit-overview.md for the domain index
- R-numbered requirements (R1, R2, R3...)
- Every requirement has testable acceptance criteria
- Never prescribe HOW — that belongs in plans/
- Cross-reference related domains
- Decompose into subdirectories when a domain covers multiple independent concerns
```

### `context/plans/CLAUDE.md`

```markdown
# Plans

Plans define HOW to implement kits. They contain task dependency graphs.

## Conventions
- Start with plan-overview.md for the build site index
- Build sites use T-numbered tasks organized into dependency tiers
- Each task references cavekit requirements by ID
- build-site.md is the primary build site
- build-site-{feature}.md for feature-specific sites
```

### `context/impl/CLAUDE.md`

```markdown
# Implementation Tracking

Impls record what was built, what is pending, what failed.

## Conventions
- Start with impl-overview.md for current status across all domains
- impl-{domain}.md for per-domain tracking
- dead-ends.md for failed approaches (critical — prevents retrying failures)
- archive/ for compacted history
- Update after every implementation session
```

### `context/designs/CLAUDE.md`

```markdown
# Design System

The project's visual design system in DESIGN.md format (9-section Google Stitch).

## Conventions
- DESIGN.md at project root is the canonical source
- All UI implementation must reference DESIGN.md tokens and patterns
- Updated via /ck:design or automatically during /ck:check and /ck:revise
- Agents read this before implementing any user-facing component
- design-changelog.md tracks all design system changes
```

### Source-tree CLAUDE.md files

For each detected source directory from Step 1 (e.g., `src/`, `tests/`, `scripts/`), create a minimal CLAUDE.md **only if one does not already exist**:

**`src/CLAUDE.md`** (or equivalent source directory):
```markdown
# Source Code

See context/kits/ for requirements this code implements.
See context/plans/ for task dependency graphs.
```

**`tests/CLAUDE.md`** (or equivalent test directory):
```markdown
# Tests

Test conventions for this project.
See context/impl/ for test health tracking.
```

**`scripts/CLAUDE.md`** (if scripts/ exists):
```markdown
# Scripts

Utility scripts for this project.
```

## Step 4: Create Empty Index Files

Create these **only if they don't already exist**:

### `context/kits/cavekit-overview.md`

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Cavekit Overview

## Project
{Project name — read from README.md, package.json, or directory name}

## Domain Index
| Domain | File | Summary | Status |
|--------|------|---------|--------|

## Cross-Reference Map
| Domain A | Interacts With | Interaction Type |
|----------|---------------|-----------------|

## Dependency Graph
No domains defined yet. Run `/ck:sketch` to create kits.
```

### `context/plans/plan-overview.md`

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Plan Overview

## Build Sites
| Site | File | Tasks | Done | Status |
|------|------|-------|------|--------|

No build sites yet. Run `/ck:map` to generate one.
```

### `context/impl/impl-overview.md`

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Implementation Overview

## Domain Status
| Domain | Tasks Done | Tasks Total | Status |
|--------|-----------|-------------|--------|

No implementations tracked yet. Run `/ck:make` to start building.
```

## Step 5: Detect Legacy Layout

If `context/sites/` exists and contains build site files:

```
Found context/sites/ (legacy layout). Migrate to context/plans/?
This moves build-site files and updates internal references.
[Y/n]
```

If the user accepts:
1. Move all `*.md` files from `context/sites/` to `context/plans/` (skip `archive/` subdirectory)
2. If `context/sites/archive/` exists, move it to `context/impl/archive/` (merge, don't overwrite)
3. Remove `context/sites/` if now empty
4. Report which files were moved

If the user declines:
- Log: "Keeping context/sites/. Cavekit commands will check both locations."
- Do NOT migrate. The fallback is permanent.

## Step 6: Report and Commit

Report what was created:

```markdown
## Init Report

### Runtime (.cavekit/)
- {list new files: config.json, state.md, token-ledger.json, capabilities.json}

### Directories Created
- {list of new directories}

### CLAUDE.md Files Created
- {list of new CLAUDE.md files}

### Index Files Created
- {list of new index files}

### Capabilities detected
- CLI: {list tools found: gh, git, node, codex, …}
- MCP: {list servers from .mcp.json if present, else "none"}

### Legacy Migration
- {migration status if applicable}

### Next Step
Run `/ck:sketch` to start writing kits.
```

Then commit the scaffolding with message: "Initialize Cavekit context hierarchy"
