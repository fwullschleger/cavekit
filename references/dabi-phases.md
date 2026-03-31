# DABI Phases Reference

Complete reference for the four-phase Blueprint lifecycle: **D**raft, **A**rchitect, **B**uild, **I**nspect.

---

## 1. Overview

DABI is the four-phase lifecycle of Blueprint. Each phase has dedicated prompts that drive it, explicit inputs and outputs, and defined roles for both the AI agent and the human engineer.

The core principle that governs all phases:

> **Specify before building — never jump from raw requirements directly to implementation.**

Blueprints sit between intent and implementation. Every project — whether greenfield or rewrite — must pass through a blueprint stage before any code is written.

| Project Type | Starting Point | Blueprints | Deliverable |
|---|---|---|---|
| **Greenfield** | PRDs, design docs, domain knowledge | Technical blueprints decomposed from source materials | Working application with tests |
| **Rewrite** | Existing application source code | Implementation-agnostic blueprints extracted from current behavior | New application in target stack |

---

## 2. Phase Table

| Phase | Input | Output | AI Role | Human Role |
|-------|-------|--------|---------|------------|
| **Draft** | Old code, reference docs, research | Implementation-agnostic blueprints | Extract, structure, decompose | Verify blueprints capture all requirements |
| **Architect** | Blueprints + framework research | Framework-specific implementation plans | Architect, sequence, define dependencies | Approve technical direction |
| **Build** | Plans + blueprints | Working code + tests + tracking docs | Implement, verify, generate coverage, track progress | Observe execution and flag deviations |
| **Inspect** | Failed validations, gaps, manual fixes | Updated blueprints/plans, regression tests, progress reports | Root-cause failures, propagate fixes upstream, surface metrics | Evaluate outcomes, set priorities, initiate revision |

---

## 3. Phase Details

### 3.1 Draft Phase

**Purpose:** Transform source material into implementation-agnostic blueprints that define WHAT needs to be built.

**Inputs:**
- Reference materials (PRDs, language specs, old code docs, design documents)
- Feature scope documents (what is in/out of scope)
- Existing codebase (for brownfield/rewrite projects)

**Outputs:**
- Domain-specific blueprint files (`blueprints/blueprint-{domain}.md`)
- Blueprint overview/index file (`blueprints/blueprint-overview.md`)
- Cross-references between related blueprints

**AI Role:**
- Read and analyze all reference materials
- Decompose into domain-specific blueprints
- Write blueprints with testable acceptance criteria
- Cross-reference blueprints where domains interact

**Human Role:**
- Review blueprints for completeness and accuracy
- Verify acceptance criteria are testable
- Ensure scope is correct (not too broad, not too narrow)
- Validate domain decomposition makes sense

**Key Principles:**
- Blueprints are implementation-agnostic -- they describe WHAT, not HOW
- Every requirement must include testable acceptance criteria
- Blueprints must be hierarchical -- one index file linking to domain-specific sub-blueprints
- Blueprints must be cross-referenced -- related blueprints link to each other

**Blueprint Format Template:**
```markdown
# Blueprint: {Domain Name}

## Scope
{What this blueprint covers}

## Requirements

### R1: {Requirement Name}
**Description:** {What must be true}
**Acceptance Criteria:**
- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}
**Dependencies:** {Other blueprints/requirements this depends on}

### R2: ...

## Out of Scope
{Explicit exclusions}

## Cross-References
- See also: blueprint-{related-domain}.md
```

**Greenfield Pattern:**
- Reference material -> blueprints (single prompt, e.g., `001-generate-blueprints-from-refs.md`)
- Agent reads `context/refs/` and produces `context/blueprints/`

**Rewrite Pattern:**
- Old code -> reference docs -> blueprints (multiple prompts)
- `001`: Generate reference materials from old code
- `002`: Generate blueprints from reference + feature scope
- `003`: Validate blueprints against codebase

---

### 3.2 Architect Phase

**Purpose:** Transform implementation-agnostic blueprints into framework-specific implementation plans that define HOW to build.

**Inputs:**
- Blueprints from the Draft phase
- Framework documentation and research
- Existing implementation tracking (if any)

**Outputs:**
- Domain-specific plan files (`plans/plan-{domain}.md`)
- Build site document (`plans/plan-build-site.md`)
- Known issues backlog (`plans/plan-known-issues.md`)

**AI Role:**
- Read blueprints and research framework patterns
- Architect the implementation approach
- Decompose into tasks with dependencies
- Sequence implementation order
- Define test strategies per feature

**Human Role:**
- Validate architecture decisions
- Review framework choices
- Approve dependency ordering
- Verify test strategy coverage

**Key Principles:**
- Plans are framework-specific -- they describe HOW to implement
- Plans reference blueprints for the WHAT
- Plans include feature dependencies (what must be built first)
- Plans include test strategies (how each feature will be validated)
- Plans include acceptance criteria (runnable checks)

**Plan Format Template:**
```markdown
# Plan: {Domain Name}

## Framework
{FRAMEWORK} — {version and key dependencies}

## Implementation Sequence

### Task T-1: {Task Name}
**Blueprint Reference:** blueprint-{domain}.md R1
**Dependencies:** None
**Files:** {files to create/modify}
**Approach:** {How to implement}
**Tests:** {Test strategy}
**Acceptance:** {BUILD_COMMAND} passes, tests pass

### Task T-2: {Task Name}
**Blueprint Reference:** blueprint-{domain}.md R2
**Dependencies:** T-1
**Files:** {files to create/modify}
...

## Build Site
| Tier | Features | Dependencies |
|------|----------|-------------|
| 1 (Foundation) | Core data models, basic routing | None |
| 2 (Core) | Business logic, API integration | Tier 1 |
| 3 (Advanced) | Performance, polish, edge cases | Tier 2 |

## Known Issues
| Priority | Issue | Workaround |
|----------|-------|------------|
| P0 | {Critical blocker} | {Temporary fix} |
| P1 | {High priority} | {Approach} |
```

**Bidirectional Flow:**
Plans and implementation tracking files update each other. The Architect phase reads `impl/` for feedback from prior build passes, and the Build phase updates plans when it discovers new information. This bidirectional flow is expected and healthy -- it is how the system self-corrects.

---

### 3.3 Build Phase

**Purpose:** Build working code from plans and blueprints, with full validation.

**Inputs:**
- Plans from the Architect phase
- Blueprints from the Draft phase
- Implementation tracking from prior iterations

**Outputs:**
- Source code (`src/`)
- Tests (`tests/`)
- Implementation tracking documents (`impl/impl-{domain}.md`)

**AI Role:**
- Read plans and identify highest-priority unblocked task
- Implement the task
- Generate and run tests on changed files
- Update implementation tracking
- Commit progress frequently

**Human Role:**
- Monitor progress
- Review implementation tracking for anomalies
- Intervene if agent is stuck or going in wrong direction

**Key Principles:**
- Always implement the highest-priority unblocked task
- Run validation gates after each significant change (build -> test -> verify)
- Generate tests for all changed source files
- Update implementation tracking with: files created/modified, issues found, dead ends
- Commit frequently, never push (git as working memory)
- Use sub-agents for discrete subtasks to preserve context window

---

### 3.4 Inspect Phase

**Purpose:** Identify gaps, trace failures back to blueprints/plans, and observe the running system to steer direction.

**Inputs:**
- Failed validations from the Build phase
- Gaps identified during monitoring
- Manual fixes made by humans
- Running application, git history, agent activity

**Outputs:**
- Updated blueprints with missing requirements/validation
- Updated plans with corrected approaches
- Regression tests
- Systemic prompt improvements
- Issues, anomalies, progress reports
- Convergence metrics

**AI Role:**
- Diagnose the root cause of failures
- Trace issues back to blueprint or plan gaps
- Update blueprints (not just code) with missing requirements
- Generate regression tests
- Re-run validation to verify the fix emerges from updated blueprints alone
- Periodically scan git history and context changes
- Report on convergence metrics (test pass rate, change velocity)

**Human Role:**
- Serve as **reviewer and decision-maker**, not hands-on coder
- Review proposed blueprint changes
- Make systemic improvements to prompts when issues represent patterns
- Steer direction of revision
- Make go/no-go decisions on phase transitions

**The Revision Process:**
1. **Surface and resolve the defect** — identify the issue in the running application and fix it through a standard agent debugging session
2. **Trace the gap in the blueprint chain** — determine where in the blueprint/plan/prompt hierarchy the requirement slipped through
3. **Patch the blueprint with the missing requirement** — update the blueprint to capture the requirement or validation rule that was absent
4. **Propagate changes to plans and tracking documents** — map the fix back into the relevant context files so downstream artifacts stay consistent
5. **Apply systemic prompt corrections if the issue represents a pattern** — when a defect class recurs, update prompts to prevent the category of error
6. **Re-execute the loop and add regression coverage** — confirm the fix emerges from updated blueprints without manual intervention, and expand tests to guard against recurrence

**Key Metrics:**
- Test pass rate (approaching 100%)
- Change velocity (decreasing = converging)
- Forward progress (% of blueprint requirements with passing tests)
- Dead end accumulation (increasing = possible blueprint problem)

**Key Insight:** A code-only fix that can't be traced to a blueprint gap means the blueprints need strengthening. The goal is that blueprints plus the execution loop can reproduce any fix autonomously.

---

## 4. The Human is an Auditor, Not an Implementer

This is a critical principle throughout DABI:

> The human monitors the process, requests changes as needed, and makes systemic improvements to blueprints and prompts. The human does NOT write code.

**What the human does:**
- Reviews blueprints for completeness and accuracy
- Validates architecture decisions in plans
- Monitors execution progress
- Audits review results
- Steers direction when agents are off track
- Makes systemic improvements to prompts
- Triggers revision for discovered issues
- Makes go/no-go decisions at phase gates

**What the human does NOT do:**
- Write code directly
- Fix bugs by editing source files
- Implement features
- Write tests manually

When the human discovers a bug, the correct action is to trace it back to a blueprint gap and fix the blueprint, not to fix the code. The execution loop should then reproduce the fix autonomously from the updated blueprints.

---

## 5. Phase Gates (Transition Criteria)

Phase gates are mandatory verification checkpoints between phases. No phase transition occurs without passing its gate.

### 5.1 Draft -> Architect Gate

| Criterion | Verification |
|-----------|-------------|
| All domains identified and blueprint files created | Blueprint overview lists all domains |
| Every requirement has testable acceptance criteria | Review each `R-` requirement for `[ ]` criteria |
| Cross-references are complete | Each blueprint links to related blueprints |
| Scope is defined (in-scope and out-of-scope) | Each blueprint has explicit exclusions |
| Human has reviewed and approved blueprints | Human sign-off |

### 5.2 Architect -> Build Gate

| Criterion | Verification |
|-----------|-------------|
| All blueprint requirements mapped to plan tasks | Cross-reference check |
| Task dependencies are defined and acyclic | Dependency graph review |
| Test strategies defined for each feature | Each task has test approach |
| Build site established | Tier system documented |
| Framework research complete | Plan references framework docs |
| Human has reviewed architecture decisions | Human sign-off |

### 5.3 Build -> Inspect Gate

| Criterion | Verification |
|-----------|-------------|
| Build passes | `{BUILD_COMMAND}` exits cleanly |
| Unit tests pass | `{TEST_COMMAND}` exits cleanly |
| Implementation tracking is current | `impl/` files reflect actual state |
| All completed tasks verified | Each DONE task has passing tests |
| No P0 issues outstanding | `plan-known-issues.md` check |

### 5.4 Inspect -> Draft Gate (Cycle Back)

| Criterion | Verification |
|-----------|-------------|
| All revision targets addressed | Blueprint changes committed |
| Regression tests generated and passing | Test suite expanded |
| Execution loop re-run confirms fixes | Clean iteration pass |
| Implementation tracking updated | Dead ends documented |
| Convergence detected or ceiling diagnosed | Change velocity analysis |
| Gap analysis complete | Built vs intended comparison |
| New requirements or scope changes identified | Blueprint updates needed |
| Human decision to cycle back | Explicit go/no-go |

---

## 6. The CI Pipeline Analogy

The Blueprint lifecycle mirrors a build pipeline — each stage transforms inputs into verified outputs:

**Traditional CI/CD:**
```
Code -> Build -> Test -> Deploy
```

**Blueprint AI Pipeline:**
```
Blueprint Change (Draft)
  -> Generate Plans (Architect)
    -> Generate Implementation (Build)
      -> Validate (Tests + Inspect)
        -> Human Audit (Inspect & Steer)
          -> [Gap Found]
            -> Revise (Inspect)
              -> Blueprint Change (cycle back to Draft)
```

Each stage feeds the next. Failures at any stage propagate back to the appropriate source (blueprint, plan, or prompt) rather than being patched at the code level.

---

## 7. When to Use Full DABI vs. Lightweight Blueprint

### Full DABI

Use when:
- The project spans multiple modules or has significant architectural surface area
- Requirements are expected to shift, requiring blueprints and code to evolve together
- The workflow involves coordinating multiple agents or chained prompt stages
- You are working on production or brownfield systems where change traceability is essential
- Multiple teams collaborate and need a shared blueprint layer to stay aligned
- The codebase handles sensitive operations where validation gates reduce risk
- Agents will run extended autonomous sessions without continuous human oversight

### Lightweight Blueprint

Use when:
- The task is focused but non-trivial
- You want blueprint benefits without full pipeline overhead

**Lightweight approach:**
1. Write a focused `context/blueprints/blueprint-task.md` capturing requirements
2. Add a `context/plans/plan-task.md` sequencing the implementation
3. Skip full DABI; just run the execution loop against the plan

This minimal approach captures the key advantages — clear intent, reproducible outcomes, traceable decisions — without a full multi-phase setup.

### Skip Blueprint

When:
- The task is small and self-contained (~5 files, clear requirements, single session)
- One-off standalone tools with well-defined scope
- Exploratory prototyping where requirements are completely unknown
- Simple bug fixes or small feature additions

**Heuristic:** If the entire task fits comfortably in a single agent session, full Blueprint adds unnecessary ceremony.

---

## 8. Prompt Pipeline Patterns

### Greenfield Pattern (3-Prompt)

| Prompt File | Lifecycle Stage | Reads From | Produces |
|--------|-------------|-------|--------|
| `001-generate-blueprints-from-refs.md` | **Draft** | `context/refs/` | `context/blueprints/` |
| `002-generate-plans-from-blueprints.md` | **Architect** | `context/blueprints/` | `context/plans/` |
| `003-generate-impl-from-plans.md` | **Build** | `context/plans/` + `context/blueprints/` | `src/`, `tests/`, `context/impl/` |

### Rewrite Pattern (6-9 Prompts)

| Prompt File | Lifecycle Stage | Reads From | Produces |
|--------|-------------|-------|--------|
| `001-generate-refs-from-code.md` | **Draft** (prep) | Old app source | `shared-context/reference/` |
| `002-generate-blueprints.md` | **Draft** | Feature scope + reference | `shared-context/blueprints/` |
| `003-validate-blueprints.md` | **Draft** (verify) | Reference + blueprints | Validation report |
| `004-create-plans.md` | **Architect** | Blueprints + framework research | `context/plans/` |
| `005-implement.md` | **Build** | Plans + blueprints | `src/` + `tests/` |
| `006-update-blueprints.md` | **Inspect** | Working prototype | Updated blueprints |

The final prompt (006) feeds corrections back into prompt 002, closing the loop.

### Shared Principles Across All Pipelines

| Principle | Description |
|-----------|-------------|
| Single prompt per lifecycle stage | Each phase boundary is a clean handoff point |
| Declared read/write paths | Every prompt has an explicit contract for its inputs and outputs |
| Git as session memory | Agents reconstruct state from commit history across iterations |
| Deterministic exit conditions | A structured signal (`<all-tasks-complete>`) marks completion |
| Two-way blueprint/plan synchronization | Implementation feedback flows back into plans and vice versa |
| Automatic coverage on touched files | Any source file change triggers corresponding test generation |

---

## 9. Context Directory Structure

Every Blueprint project follows this standard structure:

```
context/
+-- refs/              # Source of truth (language specs, PRDs, old code docs)
+-- blueprints/        # Implementation-agnostic blueprints
|   +-- CLAUDE.md      # "Blueprints define WHAT needs implementing"
+-- plans/             # Framework-specific implementation plans
|   +-- CLAUDE.md      # "Plans define HOW to implement something"
+-- impl/              # Living implementation tracking
|   +-- CLAUDE.md      # "Impls record implementation progress"
+-- prompts/           # DABI pipeline prompts (001, 002, 003...)
```

Each subdirectory gets a `CLAUDE.md` that describes its conventions. Agents automatically load these when working in that directory. CLAUDE.md is hierarchical -- it loads from the directory AND all parent directories.

---

## 10. Why Blueprints Matter

> Robust blueprints with comprehensive validation make the entire application rebuildable from documentation alone.

This principle underpins the Blueprint approach to durability. Blueprints are:
- **Structured** — organized as a navigable tree, enabling agents to load only what they need
- **Human-legible** — engineers can audit at a higher level than code
- **Stack-independent** — decoupled from any single framework or language
- **Independently evolvable** — blueprints can be refined without touching implementation
- **Verifiable** — every requirement includes acceptance criteria agents can check

The same blueprints can drive implementations across different frameworks, enabling apples-to-apples comparison of technology choices.
