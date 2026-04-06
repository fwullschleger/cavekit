# Convergence Patterns Reference

Detecting whether agent iterations are converging toward a solution or hitting a ceiling. Covers the exponential decay curve, convergence vs ceiling distinction, non-convergence diagnosis, test pass rate as signal, and forward progress metrics.

---

## 1. Overview

Convergence is the central feedback signal in Cavekit. It tells you whether the iteration loop is working -- whether the agent is approaching a stable solution that satisfies all kits and validation gates.

> **Convergence indicates the agent's output is settling into a stable state. You don't need a zero-diff — you need the remaining modifications to be inconsequential.**

Understanding convergence is critical because it answers the most important question in any iterative AI workflow: **when are we done?**

---

## 2. The Exponential Decay Curve

Healthy convergence follows an exponential decay pattern in the volume of changes per iteration:

```
Changes (lines)
    ^
350 |*
    |
280 |  *
    |
180 |
    |     *
100 |
    |        *
 40 |
    |           *
 15 |              * *      <-- convergence zone
  0 +--|--|--|--|--|--|--|-->  Iteration
    1  2  3  4  5  6  7
```

### Typical Progression

| Iteration | Lines Changed | Nature of Work |
|-----------|--------------|----------------|
| 1 | 300-350 | Core structure and primary implementation |
| 2 | 150-250 | Addressing gaps, resolving test failures |
| 3 | 80-130 | Boundary conditions, error paths |
| 4 | 30-60 | Refinement, minor corrections |
| 5 | 10-30 | Cosmetic tweaks, nearly settled |
| 6 | 5-15 | Convergence zone -- output is stable |
| 7 | 0-8 | Converged -- only negligible diffs remain |

### What "Convergence Zone" Means

You have entered the convergence zone when:
- Diff volume per iteration drops below roughly 15-20 lines
- Modifications are superficial — whitespace, comments, variable renames
- The agent is no longer introducing new behavior or logic
- No additional test cases are being created
- All previously passing tests continue to pass

**A perfectly empty diff is uncommon and not the goal.** What matters is that modifications are shrinking in both volume and significance.

---

## 3. Convergence vs. Ceiling

Both convergence and ceiling produce small diffs, but they have fundamentally different implications.

### Convergence

**Definition:** The agent has fulfilled every requirement and all validation gates are green. Any remaining diffs are negligible polish.

**Indicators:**
- Every test in the suite passes
- The build completes without errors or warnings
- All tasks in the implementation tracker are marked DONE
- Diffs consist only of trivial edits — whitespace, comments, naming tweaks
- The agent signals that it considers the work complete
- Every item on the exit criteria checklist is satisfied

**Action:** Iteration is complete. Proceed to the next phase or finalize delivery.

### Ceiling

**Definition:** The agent has hit an obstacle it cannot resolve on its own. It is stalled, not finished.

**Indicators:**
- The same subset of tests fails on every pass
- The build carries persistent errors or unresolved warnings
- Implementation tracker shows tasks lingering at IN_PROGRESS or BLOCKED
- The agent keeps applying the same patch or approach repeatedly
- No completion signal is emitted
- One or more exit criteria remain unchecked
- The agent may explicitly call out a blocking issue

**Action:** Diagnose the obstacle. The agent requires intervention — a specification revision, a dependency resolution, a tooling change, or direct human input.

### Comparison Table

| Attribute | Convergence | Ceiling |
|-----------|-------------|---------|
| Change volume | Shrinking progressively | Stable but non-zero |
| Test pass rate | At or approaching 100% | Plateaued below 100% |
| Task status | All completed | Some stuck or blocked |
| Nature of diffs | Cosmetic polish | Repetitive rework |
| Completion signal | Present | Absent |
| Underlying cause | Requirements met | External blocker |
| Recommended action | Finalize and move on | Investigate and unblock |

---

## 4. Detecting Convergence

### Method 1: Change Volume Tracking

Track the total lines changed per iteration:

```bash
# After each iteration, measure changes
git diff HEAD~1 --stat | tail -1
# Output: "15 files changed, 450 insertions(+), 120 deletions(-)"
```

Plot or log these numbers. Convergence = monotonically decreasing volume.

### Method 2: Test Pass Rate

Track the test pass rate across iterations:

| Iteration | Tests | Pass | Fail | Skip | Pass Rate |
|-----------|-------|------|------|------|-----------|
| 1 | 50 | 30 | 15 | 5 | 60% |
| 2 | 75 | 55 | 12 | 8 | 73% |
| 3 | 90 | 78 | 8 | 4 | 87% |
| 4 | 95 | 90 | 3 | 2 | 95% |
| 5 | 98 | 96 | 1 | 1 | 98% |
| 6 | 100 | 99 | 0 | 1 | 99% |

Healthy convergence shows:
- Test count increasing (more coverage)
- Pass rate approaching 100%
- Fewer failures per iteration
- Skip count decreasing

### Method 3: Task Completion Rate

Track completion of cavekit requirements:

```markdown
Iteration 1: 3/20 requirements satisfied (15%)
Iteration 2: 8/20 requirements satisfied (40%)
Iteration 3: 14/20 requirements satisfied (70%)
Iteration 4: 18/20 requirements satisfied (90%)
Iteration 5: 19/20 requirements satisfied (95%)
Iteration 6: 20/20 requirements satisfied (100%)
```

### Method 4: Implementation Tracking

Read the implementation tracking document for task status progression:

```markdown
After iteration 1: 3 DONE, 12 IN_PROGRESS, 5 TODO
After iteration 2: 8 DONE, 9 IN_PROGRESS, 3 TODO
After iteration 3: 14 DONE, 5 IN_PROGRESS, 1 TODO
After iteration 4: 18 DONE, 2 IN_PROGRESS, 0 TODO
After iteration 5: 19 DONE, 1 IN_PROGRESS, 0 TODO
After iteration 6: 20 DONE, 0 IN_PROGRESS, 0 TODO
```

---

## 5. Non-Convergence Diagnosis

When diff volume is not declining from one iteration to the next, the loop itself is not at fault — the inputs driving the loop are. Below are the four most common root causes.

### Cause 1: Ambiguous Specifications

**Symptom:** The agent takes a different approach on each pass. Code alternates between competing implementations.

**Diagnosis:** The cavekit leaves room for multiple valid interpretations. Without a single unambiguous reading, the agent picks a different path every time.

**Examples:**
- "Search should be intuitive" — What does intuitive mean? Autocomplete? Faceted filters? Fuzzy matching?
- "Data should be secure" — Encrypted at rest? In transit? Role-based access? Audit logging?
- "Support high availability" — What uptime target? What failover strategy? Which components?

**Fix:** Replace ambiguous language with concrete, testable acceptance criteria:

```markdown
# Bad
R1: The file processor should be efficient

# Good
R1: File Processing Throughput
**Acceptance Criteria:**
- [ ] Process a 50 MB CSV file in under 10 seconds on a 4-core machine
- [ ] Memory usage stays below 512 MB during processing
- [ ] No individual record takes longer than 5ms to transform
```

### Cause 2: Insufficient Validation

**Symptom:** The agent applies changes without a clear signal about whether they help or hurt. Fixes appear random rather than targeted.

**Diagnosis:** Validation gates are too weak or absent. The agent cannot determine whether a given change moves the system closer to or further from the goal.

**Examples:**
- A requirement has no corresponding test (the agent has no way to confirm correctness)
- Tests are overly permissive (they pass regardless of actual behavior)
- The build succeeds but the application crashes on startup
- No smoke check verifies that core workflows function end-to-end

**Fix:** Ensure every specification requirement maps to at least one automated check:

```markdown
# Each requirement links to concrete validations
R1: Order placement
  -> Unit test: calculateTotal returns correct sum with tax
  -> Integration test: POST /orders with valid payload returns 201
  -> E2E test: User completes checkout flow in the browser
  -> Smoke test: Order confirmation page loads after app startup
```

### Cause 3: Conflicting Agents

**Symptom:** Diffs oscillate — one iteration introduces code that the next iteration removes. Change volume remains flat or grows.

**Diagnosis:** Two or more agents (or teammates within an agent team) are producing contradictory changes. Each agent undoes part of what the other accomplished.

**Examples:**
- Agent X restructures a shared module; Agent Y overwrites it with the original layout
- Pass N introduces a caching layer; pass N+1 strips it out because it conflicts with another feature
- Two specification sections impose mutually exclusive requirements on the same component

**Fix:**
1. Review file ownership tables — confirm no file is written by more than one agent
2. Audit kits for contradictions — reconcile any conflicting requirements
3. Verify task ordering — ensure dependencies flow in one direction
4. When running agent teams, dispatch subagents with `isolation: "worktree"` via the Agent tool

### Cause 4: Unresolved External Dependencies

**Symptom:** The agent retries the same strategy on every pass and fails identically each time.

**Diagnosis:** Something the agent depends on is unavailable — a package, a running service, a configuration file, or a system tool.

**Examples:**
- Tests expect a message queue that has not been provisioned
- The implementation calls a third-party service that is unreachable in the build environment
- The build toolchain requires a binary that is not on the PATH

**Fix:** Identify what is missing and choose one of:
- Provision or install the dependency
- Provide a stub or mock that satisfies the interface
- Narrow the cavekit scope to exclude the dependency for now
- Record the dependency as a blocker in the implementation tracker

---

## 6. Non-Convergence is a Signal to Improve Kits

This is a critical principle:

> **When the loop isn't stabilizing, adding more iterations won't help — the problem is in the kits, validation, or coordination.**

Continuing to iterate on a non-converging system is wasted effort. The agent will repeat the same missteps because the root cause lives outside the loop — in ambiguous kits, missing validation, or unresolved conflicts between agents.

### Decision Tree

```
Are changes decreasing iteration-over-iteration?
  |
  YES -> Continue iterating. Convergence is working.
  |
  NO  -> Stop. Diagnose the cause:
         |
         +-> Are kits ambiguous? -> Fix kits, restart
         |
         +-> Is validation weak? -> Add tests/gates, restart
         |
         +-> Are agents fighting? -> Fix ownership/deps, restart
         |
         +-> Is there a missing dep? -> Fix or mock it, restart
```

---

## 7. Test Pass Rate as First-Class Convergence Signal

Test pass rate is the most reliable convergence signal because it is:
- **Objective:** Tests either pass or fail
- **Quantitative:** Easily tracked as a number
- **Incremental:** Shows progress between 0% and 100%
- **Granular:** Individual test failures point to specific issues

### Tracking Test Health

```markdown
## Test Health Dashboard

| Iteration | Total | Pass | Fail | Skip | New Tests | New Passes |
|-----------|-------|------|------|------|-----------|------------|
| 1 | 40 | 22 | 14 | 4 | 40 | 22 |
| 2 | 65 | 48 | 11 | 6 | 25 | 26 |
| 3 | 82 | 72 | 6 | 4 | 17 | 24 |
| 4 | 88 | 83 | 3 | 2 | 6 | 11 |
| 5 | 92 | 90 | 1 | 1 | 4 | 7 |
```

### Healthy Signals

- Test suite size grows over iterations (the agent is expanding coverage)
- Pass count climbs faster than total count (existing failures are being fixed alongside new passing tests)
- Failure count drops steadily from one pass to the next
- Skipped tests diminish as deferred issues get resolved

### Unhealthy Signals

- Pass rate swings up and down (previously green tests go red, indicating regressions)
- Test suite size stays constant (agent is not writing new tests)
- The same tests remain red on every pass (ceiling — the agent cannot resolve them)
- Total test count shrinks (agent is removing tests rather than fixing them)

---

## 8. Forward Progress Metrics

For large projects with many cavekit requirements, track the percentage of requirements with passing tests.

### Forward Progress Calculation

```
Forward Progress = (Requirements with ALL acceptance criteria passing)
                   / (Total requirements)
                   * 100%
```

### Example Tracking

```markdown
## Forward Progress

| Domain | Total Reqs | Passing | Progress |
|--------|-----------|---------|----------|
| Auth | 8 | 7 | 87.5% |
| API | 12 | 10 | 83.3% |
| UI | 15 | 9 | 60.0% |
| Data | 6 | 6 | 100% |
| Perf | 4 | 2 | 50.0% |
| **Total** | **45** | **34** | **75.6%** |
```

### Using Forward Progress

- Track per domain to identify which areas need more iteration
- 100% in a domain means that domain has converged
- Domains below 50% may have cavekit or validation issues
- Overall forward progress should increase monotonically
- Plateaus indicate ceiling -- investigate the blocked domains

---

## 9. Convergence Monitoring in Practice

### Manual Monitoring

After each iteration:
1. Check `git diff --stat` for change volume
2. Run `{TEST_COMMAND}` and record pass/fail counts
3. Read implementation tracking for task status
4. Log the results in a convergence tracking file

### Automated Monitoring

A convergence monitor agent can automate this:

```markdown
## Convergence Monitor

Every N minutes (or after each iteration):
1. Read git log for recent commits
2. Calculate change volume (insertions + deletions)
3. Run test suite and record results
4. Read implementation tracking
5. Report:
   - Change trend (decreasing/flat/increasing)
   - Test trend (pass rate direction)
   - Task trend (completion direction)
   - Diagnosis (converging/ceiling/non-converging)
6. If non-converging: alert human with diagnosis
```

---

## 10. Iteration Count Guidelines

While convergence is the true "done" signal, practical iteration limits prevent runaway loops:

| Project Size | Typical Iterations to Convergence | Max Iterations |
|-------------|----------------------------------|----------------|
| Small (< 15 files) | 2-4 | 8 |
| Medium (15-60 files) | 4-7 | 14 |
| Large (60-150 files) | 7-12 | 22 |
| Very large (150+ files) | 10-18 | 30 |

### When Max Is Reached Without Convergence

If the iteration limit is reached and the system has not converged:
1. Stop iterating
2. Analyze the convergence metrics
3. Diagnose the cause (fuzzy kits, weak validation, fighting agents, missing deps)
4. Fix the root cause
5. Reset the iteration counter
6. Resume iterating

Never increase the iteration limit to compensate for non-convergence.

---

## 11. Convergence in Multi-Agent Context

When using agent teams, convergence has additional dimensions:

### Per-Teammate Convergence

Each teammate should converge independently within their domain:
- Changes to their files should decrease per iteration
- Tests in their domain should approach 100% pass rate
- Their tasks should progress toward DONE

### Cross-Team Convergence

After merging all teammates' work:
- The combined build should pass
- The combined test suite should pass
- Integration tests should show increasing pass rate
- Merge conflicts should decrease or disappear

### Team-Level Non-Convergence

If the team as a whole is not converging despite individual teammates converging:
- Check for integration issues at merge boundaries
- Verify file ownership is correct (no conflicts)
- Check for specification contradictions across domains
- Verify task dependencies are correct

---

## 12. Convergence Patterns Summary

| Pattern | Change Volume | Test Pass Rate | Action |
|---------|--------------|----------------|--------|
| Healthy convergence | Dropping exponentially | Climbing toward 100% | Stay the course — nearly finished |
| Slow convergence | Declining linearly | Rising gradually | More passes required, but progress is real |
| Ceiling | Low and flat | Stuck below full pass | Diagnose the blocker |
| Non-convergence | Flat or growing | Fluctuating or stalled | Halt iterations, revise kits or validation |
| Divergence | Rising | Falling | Stop immediately — fundamental problem |

### The Cardinal Rules

1. **Convergence — not elapsed time or iteration count — determines when work is complete.**
2. **A non-converging loop means the kits, validation, or coordination need attention — not more passes.**
3. **Test pass rate is the single most dependable indicator of convergence.**
4. **Small diffs can mean success or stagnation — always check whether tests are green before concluding.**
5. **On larger projects, measure forward progress as the share of cavekit requirements whose acceptance criteria all pass.**
