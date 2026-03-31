# Prompt Engineering Reference

Best practices for designing prompts that drive DABI phases. Covers runtime inputs, agent team structures, batching, file ownership, exit criteria, completion signals, spawn templates, halting conditions, sub-agent delegation, task templates, and time guards.

---

## 1. Overview

Prompts in Blueprint are carefully structured markdown files that instruct AI agents to perform specific phases of DABI. Well-designed prompts are the difference between agents that converge on correct solutions and agents that thrash endlessly.

**Core Principles:**
- Prompts should be as lightweight and systemic as possible
- Detailed information belongs in blueprints, plans, and reference materials -- not in the prompt itself
- Prompts define the process; blueprints and plans define the content
- One prompt per DABI phase

---

## 2. Runtime Inputs

Runtime inputs make prompts project-agnostic. Use placeholder variables that are resolved at execution time.

### Standard Runtime Variables

| Variable | Purpose | Example Values |
|----------|---------|---------------|
| `{FRAMEWORK}` | Target framework/language | `React`, `Tauri`, `Django`, `Go` |
| `{BUILD_COMMAND}` | How to build the project | `npm run build`, `cargo build`, `go build ./...` |
| `{TEST_COMMAND}` | How to run tests | `npm test`, `cargo test`, `pytest` |
| `{LINT_COMMAND}` | How to lint | `npm run lint`, `cargo clippy`, `ruff check .` |
| `{DEV_COMMAND}` | How to start dev server | `npm run dev`, `cargo run`, `python manage.py runserver` |
| `{PROJECT_ROOT}` | Root directory of the project | `/path/to/project` |
| `{CONTEXT_DIR}` | Path to context directory | `context/` or `shared-context/` |

### Usage in Prompts

```markdown
## Validation

After each significant change, run the validation pipeline:

1. Build: `{BUILD_COMMAND}`
2. Test: `{TEST_COMMAND}`
3. Lint: `{LINT_COMMAND}`

If any gate fails, fix the issue before proceeding.
```

### Benefits

- The same prompt works across different projects without modification
- Framework-specific details stay in plans, not prompts
- Prompts can be shared across teams and repositories
- Reduces prompt maintenance burden

---

## 3. Agent Team Structure

When a prompt uses agent teams, it must define the team hierarchy clearly. Agents need to understand their role in the team.

### ASCII Tree Format

```
Team Lead (delegate mode -- never writes code directly)
+-- Teammate A: {auth-service}
|   Isolation: worktree (via Agent tool)
|   Branch: feat/impl/{auth-service}
|   Owns: src/auth-service/*, tests/auth-service/*
|
+-- Teammate B: {data-layer}
|   Isolation: worktree (via Agent tool)
|   Branch: feat/impl/{data-layer}
|   Owns: src/data-layer/*, tests/data-layer/*
|
+-- Teammate C: {frontend-ui}
    Isolation: worktree (via Agent tool)
    Branch: feat/impl/{frontend-ui}
    Owns: src/frontend-ui/*, tests/frontend-ui/*
```

### What Must Be in the Team Structure

| Element | Purpose |
|---------|---------|
| Role designation | "delegate mode" for lead, domain name for teammates |
| Isolation mode | `isolation: "worktree"` when dispatching via the Agent tool |
| Branch name | Git branch for the teammate's work |
| File ownership | Exactly which files/directories this teammate owns |

### Lead Never Writes Code

The team lead operates in "delegate mode" -- it creates tasks, assigns them to teammates, coordinates work, and summarizes results. It never writes code directly. This forces proper decomposition and prevents the lead from accumulating implementation debt in its context window.

---

## 4. Batching Rules

### Max 3 Concurrent Teammates

Keeping the concurrency cap at three prevents common failure modes:
- Multiplexed terminal sessions interfere with each other when too many run at once
- System resources (CPU, RAM, API quotas) degrade under heavy parallel load
- The communication cost between agents outweighs any speed gain beyond three

### Batch Phases

```
Phase 1: Spawn teammates A, B, C
         Wait for all to complete
         Shutdown all teammates
         Merge results (one at a time)

Phase 2: Spawn teammates D, E, F
         Wait for all to complete
         Shutdown all teammates
         Merge results (one at a time)
```

### Sub-Agent Batching

Each teammate can also spawn sub-agents (lightweight agents for discrete subtasks). The same rule applies: max 3 sub-agents per teammate.

```
Teammate A
+-- Sub-agent A1: Read and analyze docs
+-- Sub-agent A2: Generate test fixtures
+-- Sub-agent A3: Research framework API
```

---

## 5. File Ownership Tables

File ownership prevents merge conflicts entirely. Every shared file must be assigned to exactly one teammate.

### Format

```markdown
## File Ownership

| File/Directory | Owner | Notes |
|---------------|-------|-------|
| `src/auth/*` | Teammate A (auth) | Authentication module |
| `src/api/*` | Teammate B (api) | API layer |
| `src/ui/*` | Teammate C (ui) | UI components |
| `src/shared/types.ts` | Teammate A (auth) | Shared types -- only auth modifies |
| `src/shared/utils.ts` | Teammate B (api) | Shared utilities -- only api modifies |
| `tests/auth/*` | Teammate A (auth) | Auth tests |
| `tests/api/*` | Teammate B (api) | API tests |
| `tests/ui/*` | Teammate C (ui) | UI tests |
```

### Rules

1. Every file that might be touched by more than one teammate must have an explicit owner
2. Non-owners can READ any file but must NOT MODIFY files they do not own
3. If a teammate needs a change in a file it does not own, it must request the change from the owner (via the team lead)
4. Shared configuration files (e.g., `package.json`, `tsconfig.json`) should be owned by the team lead and modified only during merge phases

---

## 6. Exit Criteria Checklists

Agents do not know when they are done without explicit exit criteria. Every prompt must include a checklist.

### Format

```markdown
## Exit Criteria

You are DONE when ALL of the following are true:

- [ ] All tasks in the plan marked DONE in implementation tracking
- [ ] `{BUILD_COMMAND}` passes with no errors
- [ ] `{TEST_COMMAND}` passes with no failures
- [ ] No P0 or P1 issues remaining in known-issues
- [ ] Implementation tracking document is current
- [ ] All new/modified source files have corresponding tests

When all criteria are met, emit the completion signal.
```

### Why Checklists Matter

- Without exit criteria, agents either stop too early (leaving work incomplete) or loop forever (making trivial changes endlessly)
- Checklists give the iteration loop a deterministic signal for "done"
- Each criterion should be objectively verifiable (not subjective like "code is clean")

---

## 7. Completion Signals

A completion signal is a specific string that agents emit when all exit criteria are met. The iteration loop automation searches for this exact string to detect when to stop iterating.

### Standard Signal

```
<all-tasks-complete>
```

### Usage in Prompts

```markdown
## Completion

When ALL exit criteria are satisfied:
1. Verify each criterion one final time
2. Emit the completion signal on its own line:

<all-tasks-complete>

The iteration loop will detect this signal and stop.
```

### Rules

- The signal must be an exact string match (no variations)
- The signal should appear only when ALL criteria are met
- If any criterion fails, do NOT emit the signal -- instead, continue working
- The signal should be distinctive enough that it cannot appear accidentally in normal output

---

## 8. Phase Gates

Phase gates are mandatory verification checkpoints. They appear in prompts as post-merge validation steps.

### Format in Prompts

```markdown
## Phase Gate: Post-Merge Validation

After merging each teammate's work:

1. **Build gate:** Run `{BUILD_COMMAND}` -- must pass with zero errors
2. **Test gate:** Run `{TEST_COMMAND}` -- must pass with zero failures
3. **Verification gate:** Verify the merged feature works as expected

If ANY gate fails:
- Do NOT proceed to merging the next teammate
- Fix the issue in the merged code
- Re-run all gates
- Only proceed when all gates pass

Gate order matters: build before test, test before verify.
```

### Between DABI Phases

```markdown
## Transition Gate: Architect -> Build

Before starting implementation, verify:

- [ ] All blueprint requirements are mapped to plan tasks
- [ ] Task dependencies are defined and acyclic
- [ ] Test strategies defined for each feature
- [ ] Build site established
- [ ] Framework research complete

Do NOT proceed to implementation until all items are checked.
```

---

## 9. Spawn Templates

When the team lead spawns a teammate, the teammate is a fresh process with NO inherited conversation history. The spawn prompt must include ALL necessary context.

### Spawn Template Structure

```markdown
## Your Role
You are Teammate {NAME}, responsible for implementing {DOMAIN}.

## Your Branch
Branch: `feat/impl/{name}`

## Your Files
You own these files (only modify files you own):
{FILE_OWNERSHIP_TABLE}

## Context
Read these files to understand what to build:
- `context/blueprints/blueprint-{domain}.md` -- WHAT to build
- `context/plans/plan-{domain}.md` -- HOW to build it
- `context/impl/impl-{domain}.md` -- What has been done so far

## Tasks
{TASK_LIST_WITH_DEPENDENCIES}

## Validation
After each task:
1. `{BUILD_COMMAND}`
2. `{TEST_COMMAND}`

## Rules
- Commit frequently to your branch
- Do NOT push to remote
- Do NOT modify files outside your ownership
- Update `context/impl/impl-{domain}.md` with progress
- When all tasks complete, report back to lead

## Exit Criteria
{EXIT_CRITERIA_CHECKLIST}
```

### Key Principles

1. **Self-contained:** The spawn prompt must contain everything the teammate needs
2. **No assumptions:** Do not assume the teammate knows anything about the project
3. **Explicit constraints:** File ownership and branch must all be stated
4. **Context references:** Point to blueprint/plan/impl files, do not copy their content into the prompt
5. **Validation commands:** Include the exact commands to run

---

## 10. Halting Conditions

Halting conditions prevent agents from taking irreversible or destructive actions.

### Standard Halting Conditions

```markdown
## Halting Conditions

- Do NOT push to remote unless explicitly asked by the human
- Do NOT delete branches that were not created in this session
- Do NOT modify files outside your assigned ownership
- Do NOT install new dependencies without documenting them
- Do NOT make breaking changes to public APIs without updating blueprints first
- If you hit a blocker you cannot resolve in 15 minutes, STOP and document the blocker
- If you are unsure about an architecture decision, STOP and ask
```

### Why Halting Conditions Matter

Without explicit halting conditions, agents may:
- Push untested code to shared remotes
- Delete important branches or files
- Make breaking changes that cascade to other modules
- Spend hours on an approach that is fundamentally wrong
- Take actions that are difficult or impossible to reverse

---

## 11. Sub-Agent Delegation

Sub-agents are lightweight agents spawned by teammates to handle discrete subtasks. They preserve the teammate's context window for higher-level work.

### When to Delegate

| Task Type | Delegate? | Rationale |
|-----------|-----------|-----------|
| Reading large documentation | Yes | Frees context window |
| Generating test fixtures | Yes | Mechanical work |
| Researching framework APIs | Yes | Exploratory work |
| Complex implementation logic | No | Needs full context |
| Architecture decisions | No | Needs conversation history |
| Debugging failures | Maybe | Depends on complexity |

### Delegation Format

```markdown
Use a sub-agent for this task:
- Read all files in `context/refs/` related to {topic}
- Summarize the key patterns and constraints
- Report back with: {specific deliverable}
```

### Rules

- Max 3 sub-agents per teammate
- Sub-agents should have clear, bounded tasks
- Sub-agents report results back to the teammate
- Sub-agents do NOT update implementation tracking directly
- Sub-agents do NOT commit to git directly

---

## 12. Task Templates

Tasks use a standardized format with IDs, dependencies, and conditional markers.

### T- Prefix Convention

Every task gets a unique ID with the `T-` prefix:

```markdown
### T-1: Set up project scaffolding
**Blueprint:** blueprint-core.md R1
**blockedBy:** None
**Files:** package.json, tsconfig.json, src/index.ts
**Effort:** S
**Description:** Initialize project with build configuration

### T-2: Implement data models
**Blueprint:** blueprint-data.md R1, R2
**blockedBy:** T-1
**Files:** src/models/*.ts
**Effort:** M
**Description:** Create TypeScript interfaces and validation

### T-3: Add API layer
**Blueprint:** blueprint-api.md R1
**blockedBy:** T-2
**Files:** src/api/*.ts
**Effort:** L
**Description:** Implement REST endpoints with validation
```

### Dependency Tracking with `blockedBy`

```markdown
### T-5: Integration tests
**blockedBy:** T-3, T-4
```

This means T-5 cannot start until BOTH T-3 and T-4 are complete. The agent must respect dependency ordering.

### [CONDITIONAL] Skip Conditions

Tasks marked `[CONDITIONAL]` may be skipped based on runtime conditions:

```markdown
### T-7: Database migration [CONDITIONAL]
**Condition:** Only if `context/plans/plan-data.md` indicates a database change
**blockedBy:** T-6
**Description:** Run migration if schema changed
```

The agent evaluates the condition at runtime and skips the task if the condition is not met.

### [DYNAMIC] Runtime Task Creation

Tasks marked `[DYNAMIC]` are created at runtime based on discovered work:

```markdown
### T-10: Fix discovered issues [DYNAMIC]
**Description:** For each P0/P1 issue discovered during implementation,
create a sub-task to fix it. Priority: P0 before P1.
```

The agent creates concrete sub-tasks (T-10a, T-10b, etc.) as issues are discovered.

---

## 13. Time Guards

Per-task time budgets prevent agents from spending disproportionate time on any single task.

### Budget Categories

| Category | Time Limit | Examples |
|----------|-----------|---------|
| Mechanical | 10 minutes | File creation, config changes, simple refactors |
| Investigation | 20 minutes | Debugging, research, understanding unfamiliar code |
| Category budget | 20 minutes | Total time for all tasks in a category before escalating |

### Hard Stops

When a time guard is hit:

```markdown
## Time Guards

- If a mechanical task takes more than 10 minutes, STOP.
  Document what is blocking you and move to the next task.

- If an investigation takes more than 20 minutes, STOP.
  Document your findings so far, what you tried, and what you think
  the issue is. Move to the next task.

- If all tasks in a category have consumed 20 minutes without
  progress, STOP the category entirely. Document the blocker
  and report to lead.

When you hit a time guard:
1. Commit any work in progress
2. Update implementation tracking with findings
3. Add the blocker to known-issues
4. Proceed to the next unblocked task
```

### Why Time Guards Matter

Without time guards, agents can spend hours on a single issue that requires human intervention or a blueprint change. Time guards force the agent to document findings and move on, which:
- Preserves forward progress on other tasks
- Surfaces blockers early for human review
- Prevents context window exhaustion on dead ends

---

## 14. Work Queue Handoff Format

The work queue handoff is a structured document that prepares the next session (human or agent) to start productively without discovery overhead.

### Format: `plan-next-session.md`

```markdown
# Next Session Work Queue

Generated: {timestamp}
Based on: impl tracking, git log, test results

## WI-1: {Title}
- **Category:** feature | bugfix | refactor | test
- **Size:** S | M | L | XL
- **Priority:** high | medium | low
- **Blueprint reference:** plan-{domain}.md
- **What to do:** {Clear description of what needs to happen}
- **Files to modify:** {List of specific files}
- **Acceptance criteria:**
  - [ ] {Runnable check 1}
  - [ ] {Runnable check 2}

## WI-2: {Title}
- **Category:** bugfix
- **Size:** S
- **Priority:** high
- **Blueprint reference:** plan-{domain}.md
- **What to do:** {Description}
- **Files to modify:** {List}
- **Acceptance criteria:**
  - [ ] {Check}

## WI-3: {Title}
...

## WI-4: {Title}
...

## WI-5: {Title}
...
```

### Rules

- 3-5 work items per handoff
- Ordered by priority (highest first)
- Each work item is self-contained (can be executed without reading the full context)
- Acceptance criteria must be runnable (commands that return pass/fail)
- Effort estimates help the next session plan its time
- This removes the startup cost of each session — agents begin productive work immediately instead of spending time on orientation

---

## 15. Prompt Structure Template

A complete prompt follows this structure:

```markdown
# {Phase Name}: {Description}

## Runtime Configuration
- Framework: {FRAMEWORK}
- Build: {BUILD_COMMAND}
- Test: {TEST_COMMAND}

## Objective
{One paragraph describing what this prompt achieves}

## Context
Read these files to understand the current state:
- {list of context files to read}

## Agent Team Structure
{ASCII tree if using teams}

## File Ownership
{Ownership table if using teams}

## Tasks
{Task list with T- IDs, blockedBy, conditions}

## Validation Pipeline
{Build, test, verify steps}

## Time Guards
{Per-category budgets}

## Halting Conditions
{What NOT to do}

## Exit Criteria
{Checklist}

## Completion Signal
When all exit criteria are met:
<all-tasks-complete>
```

---

## 16. Common Anti-Patterns

### Prompt Too Long

**Problem:** Putting all blueprint/plan content directly in the prompt.
**Fix:** Reference blueprint/plan files. Let agents read them on demand.

### No Exit Criteria

**Problem:** Agent loops forever making trivial changes.
**Fix:** Add explicit exit criteria checklist with completion signal.

### Missing File Ownership

**Problem:** Two teammates modify the same file, creating merge conflicts.
**Fix:** Add file ownership table. Every shared file has exactly one owner.

### No Time Guards

**Problem:** Agent spends 2 hours debugging one issue.
**Fix:** Add time guards (10 min mechanical, 20 min investigation).

### Inherited Context Assumption

**Problem:** Spawn prompt assumes teammate knows project history.
**Fix:** Spawn prompts must be self-contained with all necessary context.

### No Halting Conditions

**Problem:** Agent pushes untested code to remote.
**Fix:** Add explicit halting conditions for destructive actions.

### Hardcoded Commands

**Problem:** Prompt contains `npm run build` instead of `{BUILD_COMMAND}`.
**Fix:** Use runtime variables for all project-specific commands.

### Too Many Concurrent Agents

**Problem:** Spawning 8 teammates simultaneously crashes the system.
**Fix:** Batch in groups of 3 with shutdown between batches.

---

## 17. Iteration Loop Integration

Prompts are designed to be run repeatedly by the iteration loop. Each iteration:

1. Agent starts fresh (no conversation history from prior iterations)
2. Agent reads git state (`git log`, `git status`, `git diff`) to understand current position
3. Agent reads implementation tracking to see what is done, pending, and blocked
4. Agent works through tasks from the plan
5. Agent updates implementation tracking
6. Agent commits progress
7. Agent emits completion signal if all exit criteria are met
8. Iteration loop checks for completion signal
9. If not complete, loop starts the next iteration

### What Changes Between Iterations

| Artifact | Changes? | How |
|----------|----------|-----|
| Prompt | No | Same prompt each iteration |
| Blueprints | Rarely | Only via revision |
| Plans | Sometimes | Updated during implementation |
| Source code | Yes | Implementation progress |
| Tests | Yes | New tests added |
| Implementation tracking | Yes | Updated each iteration |
| Git history | Yes | New commits each iteration |

### Convergence Signal

Changes should decrease exponentially:
- Iteration 1: 300 lines changed
- Iteration 2: 120 lines changed
- Iteration 3: 40 lines changed
- Iteration 4: ~10 lines (minor adjustments)

If changes are NOT decreasing, the prompt or blueprints need improvement, not more iterations.
