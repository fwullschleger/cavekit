---
created: "2026-03-17T00:00:00Z"
last_edited: "2026-03-17T00:00:00Z"
---

# Spec: Frontier Discovery and Tracking

## Scope
Finding frontier files, parsing their task structure, and tracking task completion from implementation files. This is the Blueprint-specific intelligence that claude-squad doesn't have.

## Requirements

### R1: Frontier Discovery
**Description:** Find frontier files in the project's `context/frontiers/` directory.
**Acceptance Criteria:**
- [ ] Scans `context/frontiers/` for `*.md` files containing "frontier" in the name
- [ ] Excludes files in `context/frontiers/archive/` subdirectory
- [ ] Returns list of frontier paths with derived names using the canonical derivation: strip `plan-`, `build-site-`, `feature-` prefixes, then strip `-frontier-` or `frontier` anywhere, then strip leading/trailing hyphens. Empty result defaults to `execute`
- [ ] Name derivation logic MUST be identical across all scripts that map frontier filenames to worktree paths (`setup-build.sh`, `blueprint-launch-session.sh`, `dashboard-progress.sh`). A single canonical sed chain: `sed -E 's/^(plan-|build-site-|feature-)//' | sed -E 's/-?frontier-?//' | sed -E 's/^-|-$//g'`
- [ ] Works from both project root and worktree paths — all path variables (`project_root`, `PROJECT_ROOT`) must be explicitly initialized via `git rev-parse --show-toplevel`, never assumed from undefined variables
**Dependencies:** none

### R2: Frontier Parsing
**Description:** Parse a frontier file to extract its task dependency graph.
**Acceptance Criteria:**
- [ ] Extracts all task IDs matching pattern `T-([A-Za-z0-9]+-)*[A-Za-z0-9]+`
- [ ] Parses tier structure (Tier 0, Tier 1, etc.) from markdown headers
- [ ] Extracts task title, spec reference, requirement, blockedBy, and effort from table rows
- [ ] Returns total task count and per-tier breakdown
**Dependencies:** R1

### R3: Task Status Tracking
**Description:** Determine which tasks are done, in-progress, or blocked by reading implementation tracking files.
**Acceptance Criteria:**
- [ ] Scans `context/impl/impl-*.md` files for task IDs with status markers (DONE, IN PROGRESS, PARTIAL, BLOCKED, DEAD END)
- [ ] Also scans worktree impl directories for cross-worktree awareness
- [ ] Task ID matching uses word boundaries to prevent prefix collisions (e.g., `T-1` must NOT match `T-10 DONE`)
- [ ] Returns per-task status map
- [ ] Computes aggregate: total, done, in-progress, blocked, remaining
**Dependencies:** R1, R2

### R4: Frontier Status Classification
**Description:** Classify each frontier's overall status for display.
**Acceptance Criteria:**
- [ ] "done" — all tasks complete
- [ ] "in-progress" — has an active worktree with Ralph Loop running
- [ ] "available" — has incomplete tasks, no active worktree
- [ ] Status detection checks for `.claude/ralph-loop.local.md` in the frontier's worktree
**Dependencies:** R3

### R5: Progress Summary
**Description:** Generate a compact progress string for status bar display.
**Acceptance Criteria:**
- [ ] Format: `{icon} {name} {done}/{total}` (e.g., `⟳ auth 3/12`)
- [ ] Icon: `⟳` for in-progress, `✓` for done, `·` for available
- [ ] Includes current task ID if in-progress
**Dependencies:** R3, R4

### R6: Frontier Selection (Multi-Candidate Ranking)
**Description:** When multiple frontiers exist, deterministically select the best one.
**Acceptance Criteria:**
- [ ] If `--filter` is set and matches zero frontiers, hard-fail with `exit 1` and list available frontiers — never silently fall back to unfiltered
- [ ] Ranking priority: active worktree with Ralph Loop (score 3) > worktree exists or has incomplete tasks (score 2) > base (score 1)
- [ ] Ties break deterministically: first candidate in alphabetical order wins (use `>` not `>=` in score comparison)
- [ ] All task ID grep patterns use `$TASK_ID_PATTERN` variable, never hardcoded subsets
- [ ] When listing candidates, mark the selected one with `→` for Claude visibility
**Dependencies:** R1, R3

## Back-Propagated

The following requirements were added after tracing manual bug fixes back to spec gaps (2026-03-17):

- **R1 (name derivation)**: Unified canonical sed chain after `blueprint-launch-session.sh` used a different derivation than `setup-build.sh` and `dashboard-progress.sh`, causing worktree lookup failures
- **R1 (variable initialization)**: Added explicit `git rev-parse` requirement after `dashboard-progress.sh` used undefined `$root` variable, silently breaking all worktree path lookups
- **R3 (word boundaries)**: Added after `T-1` false-matched `T-10 DONE` in done-count grep, inflating completion counts
- **R6 (filter fail-fast)**: Added after silent filter fallback caused wrong frontier selection on filter typos
- **R6 (deterministic ties)**: Added to prevent non-deterministic ranking when multiple candidates score equally

## Out of Scope
- Frontier creation (handled by `/bp:architect`)
- Frontier modification/updating
- Spec file parsing (frontier references specs but doesn't need their content)

## Cross-References
- See also: blueprint-session.md (sessions are tied to frontiers)
- See also: blueprint-tui.md (TUI displays frontier progress)
