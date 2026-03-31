# Agent Team Patterns Reference

Coordination patterns for multi-agent development. Covers team structure, batching, delegation, file ownership, merge protocol, and shutdown procedures.

---

## 1. Overview

Agent teams decompose work into parallel sub-tasks, each handled by a separate AI agent instance with its own context window. This enables parallelism, context isolation, and coordinated development of complex systems that exceed what a single context window can hold.

**When to Use Agent Teams:**
- Work spans multiple domains that can be developed in parallel
- Total context (specs + plans + code) exceeds a single context window
- Tasks have limited interdependencies
- You need to finish faster through parallelism

**When NOT to Use Agent Teams:**
- Work is small enough for a single agent
- Tasks are highly interdependent (serial is better)
- The codebase has extensive shared state that cannot be cleanly partitioned

---

## 2. Team Structure

### Roles

| Role | Responsibility | Code Writing |
|------|---------------|-------------|
| **Team Lead** | Orchestrate, coordinate, summarize | Never -- delegate mode |
| **Teammate** | Implement assigned domain | Yes, within owned files |
| **Sub-agent** | Discrete subtask for teammate | Limited, reports to teammate |

### The Lead Stays in Coordination Mode

This is a critical rule. The team lead operates exclusively as an orchestrator -- it:
- Creates and assigns tasks
- Spawns teammates with complete context
- Monitors progress
- Coordinates merge order
- Resolves conflicts between teammates
- Summarizes results

The lead does NOT:
- Write code directly
- Modify source files
- Run build/test commands on production code
- Make implementation decisions without delegating

**Why:** Delegate mode forces proper decomposition. If the lead wrote code, it would accumulate implementation details in its context window, reducing its ability to coordinate. The lead's context window is reserved for orchestration.

---

## 3. Concurrency Cap: 3 Teammates per Batch

### The Rule

Limit each batch to at most 3 simultaneously active teammates. This cap exists because:

1. **System resource limits:** Each teammate uses CPU, memory, and API quota that compounds quickly
2. **Session management overhead:** Running more than 3 parallel terminal sessions introduces coordination race conditions
3. **Coordination cost growth:** The overhead of managing parallel agents grows faster than the throughput gain
4. **Integration risk:** More teammates working at once means more potential for conflicting changes at merge time

### The Execution Cycle

```
Batch 1: Launch A, B, C  ->  Await completion  ->  Terminate sessions  ->  Integrate
Batch 2: Launch D, E, F  ->  Await completion  ->  Terminate sessions  ->  Integrate
Batch 3: Launch G         ->  Await completion  ->  Terminate sessions  ->  Integrate
```

### Sub-Agent Limit

Each teammate can spawn up to 3 sub-agents. This gives a maximum hierarchy of:

```
Lead (1)
+-- Teammate A (1) + sub-agents (up to 3)
+-- Teammate B (1) + sub-agents (up to 3)
+-- Teammate C (1) + sub-agents (up to 3)
```

Maximum simultaneous agents: 1 lead + 3 teammates + 9 sub-agents = 13

In practice, sub-agents are short-lived and rarely all active simultaneously.

---

## 4. Batch Phases

Work is divided into batches. Each batch goes through a complete lifecycle.

### Batch Lifecycle

```
1. PLAN
   - Lead identifies tasks for this batch
   - Lead assigns tasks to teammates
   - Lead creates file ownership table
   - Lead prepares spawn prompts

2. SPAWN
   - Lead dispatches teammates as subagents with `isolation: "worktree"` via the Agent tool
   - Lead spawns teammates with complete context
   - Maximum 3 teammates per batch

3. EXECUTE
   - Teammates work in parallel in their isolated environments
   - Each teammate modifies only files they own
   - Teammates commit frequently
   - Teammates update implementation tracking

4. COMPLETE
   - Teammates report completion to lead
   - Lead verifies all teammates are done

5. SHUTDOWN
   - All teammates in the batch are shut down
   - Their context windows are released

6. MERGE
   - Lead merges one teammate at a time
   - After each merge: build -> test -> verify
   - Fix any issues before merging next teammate
   - Clean up branches

7. TRANSITION
   - Lead assesses remaining work
   - Lead plans next batch (if needed)
   - Repeat from step 1
```

### Why Shutdown Between Batches

Teammates must be shut down between batches because:
- Their context windows are stale after merge (code has changed)
- Resource cleanup prevents accumulation
- Clean slate for next batch prevents confusion
- Merge results may change the task plan for the next batch

---

## 5. Agent Isolation

Every teammate runs in an isolated environment. When dispatching subagents via the Agent tool, use `isolation: "worktree"` to get Claude Code's built-in transparent worktree isolation. This prevents file conflicts entirely at the filesystem level without any manual worktree management.

### Rules for Teammates

1. Work ONLY within your assigned files
2. Do NOT access other teammates' files
3. Commit to your branch frequently
4. Do NOT push to remote
5. Do NOT merge your branch into main

---

## 6. Explicit File Ownership

File ownership eliminates merge conflicts by ensuring exactly one teammate can modify any given file.

### Ownership Table Format

```markdown
| Path Pattern | Assigned To | Context |
|-------------|-------------|---------|
| `src/auth/*` | auth-teammate | Authentication module |
| `src/api/*` | api-teammate | API endpoints |
| `src/ui/*` | ui-teammate | UI components |
| `src/shared/types.ts` | auth-teammate | Shared type definitions |
| `src/shared/config.ts` | api-teammate | Configuration |
| `src/shared/constants.ts` | ui-teammate | UI constants |
| `package.json` | LEAD ONLY | Updated only during merge phase |
| `tsconfig.json` | LEAD ONLY | Updated only during merge phase |
```

### Ownership Rules

1. **Every modifiable file has exactly one owner**
2. **Non-owners may READ any file** but must NOT modify
3. **Shared configuration files** (package.json, build configs) are owned by the lead and modified only during merge phases
4. **If a teammate needs a change in a file they do not own**, they must:
   - Document the needed change in their implementation tracking
   - The lead coordinates the change during merge phase
5. **Test files follow source ownership** -- if you own `src/auth/*`, you own `tests/auth/*`

### Cross-Plan Ownership

When work spans multiple plans, the ownership table must map files to plans:

```markdown
| File | Plan Owner | Teammate |
|------|-----------|----------|
| `src/rpc/types.ts` | plan-auth | auth-teammate |
| `src/rpc/client.ts` | plan-api | api-teammate |
| `src/rpc/server.ts` | plan-api | api-teammate |
```

---

## 7. Merge Protocol

Merging is the most critical phase of agent team coordination. Errors here can undo all parallel work.

### The Protocol

```
Process each teammate sequentially, ordered by dependency depth (foundations first):

1. INTEGRATE
   git checkout main
   git merge feat/impl/{teammate-name} --no-ff

2. COMPILE
   {BUILD_COMMAND}
   On failure -> diagnose, fix, rebuild until clean

3. VALIDATE
   {TEST_COMMAND}
   On failure -> diagnose, fix, retest until green

4. CONFIRM
   Verify the integrated feature behaves as expected
   Cross-check against implementation tracking

5. TEARDOWN
   git branch -d feat/impl/{teammate-name}

6. ADVANCE
   Proceed to the next teammate only after all checks pass
```

### Merge Order

Merge in dependency order:
1. Foundation/infrastructure teammates first (shared types, config)
2. Core domain teammates next (business logic, data models)
3. Dependent teammates last (UI, integration layers)

### Conflict Resolution

If a merge conflict occurs:
1. The lead resolves the conflict (it owns the merge process)
2. After resolution: build -> test -> verify before proceeding
3. Document the conflict and resolution in implementation tracking
4. Consider whether the file ownership table needs updating

### Post-Merge Validation Checklist

```markdown
- [ ] `{BUILD_COMMAND}` passes with zero errors
- [ ] `{TEST_COMMAND}` passes with zero failures
- [ ] No regressions in previously passing tests
- [ ] Implementation tracking updated with merge results
- [ ] Branch deleted
```

---

## 8. Shutdown Protocol

Shutdown happens between batch phases and at session end.

### Between Batches

1. Wait for all teammates in the batch to report completion
2. Collect status reports from each teammate
3. Shut down all teammate sessions
4. Proceed to merge phase

### Graceful Shutdown

When shutting down a teammate:
1. Teammate commits all work in progress
2. Teammate updates implementation tracking with final status
3. Teammate reports completion to lead
4. Lead terminates the teammate session

### Emergency Shutdown

If a teammate is stuck or producing bad output:
1. Lead sends stop signal
2. Teammate commits whatever work is salvageable
3. Lead terminates the session
4. Lead documents the failure in implementation tracking
5. Work may be re-assigned to a new teammate in the next batch

---

## 9. Communication Patterns

### Lead -> Teammate (Spawn)

The spawn prompt is the only communication from lead to teammate at creation time. It must be self-contained.

### Teammate -> Lead (Report)

Teammates report back to the lead:
- When they complete all assigned tasks
- When they hit a blocker they cannot resolve
- When they need a change in a file they do not own

### Teammate -> Teammate

Teammates do NOT communicate directly. All coordination goes through the lead. This prevents:
- Race conditions in communication
- Context pollution between teammates
- Uncoordinated changes

### Lead -> Sub-agent (via Teammate)

Teammates can spawn sub-agents for discrete tasks. Sub-agents report to their spawning teammate, not to the lead.

---

## 10. Team Sizing Guidelines

### Small Project (3-5 domains)

```
Lead
+-- Teammate A: domain-1 + domain-2
+-- Teammate B: domain-3
+-- Teammate C: domain-4 + domain-5
```

One batch, 3 teammates, each handling 1-2 domains.

### Medium Project (6-12 domains)

```
Batch 1:
  Lead
  +-- Teammate A: domain-1, domain-2
  +-- Teammate B: domain-3, domain-4
  +-- Teammate C: domain-5, domain-6

Batch 2:
  Lead
  +-- Teammate D: domain-7, domain-8
  +-- Teammate E: domain-9, domain-10
  +-- Teammate F: domain-11, domain-12
```

Two batches, 3 teammates each.

### Large Project (12+ domains)

Multiple batches with dependency-ordered execution:

```
Batch 1 (Foundation): Shared types, config, core models
Batch 2 (Core): Business logic, data access, API
Batch 3 (Features): UI, integrations, advanced features
Batch 4 (Polish): Performance, edge cases, documentation
```

---

## 11. Common Failure Modes

### Teammate Modifies Unowned File

**Symptom:** Merge conflict during merge phase.
**Prevention:** Strict file ownership table in spawn prompt.
**Recovery:** Resolve conflict, update ownership table, re-spawn if needed.

### Lead Writes Code Directly

**Symptom:** Lead's context window fills with implementation details.
**Prevention:** Delegate mode enforcement in the prompt.
**Recovery:** Move code writing to a teammate in the next batch.

### Too Many Concurrent Teammates

**Symptom:** System slowdown, API rate limits, race conditions.
**Prevention:** Max 3 concurrent teammates, batch phases.
**Recovery:** Shut down excess teammates, re-batch.

### Teammate Ignores Time Guards

**Symptom:** Teammate spends 2 hours on one task.
**Prevention:** Explicit time guards in spawn prompt.
**Recovery:** Lead sends stop signal, re-assigns task.

### Stale Isolation After Merge

**Symptom:** Teammate continues working with outdated code.
**Prevention:** Shutdown between batches, fresh subagent dispatch.
**Recovery:** Shut down stale teammate, dispatch a fresh subagent.

---

## 12. Integration with Iteration Loops

Agent teams can be used within iteration loops. Each iteration of the loop:

1. Lead reads git state and implementation tracking
2. Lead plans the next batch of work
3. Lead spawns teammates
4. Teammates execute
5. Lead merges
6. Lead updates tracking
7. Lead checks exit criteria
8. If not complete, emit status and wait for next iteration

### Convergence in Team Context

Convergence metrics for teams:
- **Per-teammate:** Lines changed per iteration should decrease
- **Per-merge:** Number of conflicts should decrease
- **Overall:** Total remaining tasks should decrease monotonically
- **Test health:** Test count should increase, failure count should decrease

### When Teams Are Overkill in Later Iterations

As the project converges, the remaining work may be small enough for a single agent. The lead should recognize this and switch from team mode to single-agent mode when:
- Remaining tasks are in a single domain
- Changes are minor fixes or polishing
- Team overhead exceeds the parallelism benefit
