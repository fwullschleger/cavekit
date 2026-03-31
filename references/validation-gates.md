# Validation Gates Reference

Complete reference for the 6-gate validation pipeline. Covers gate definitions, implementation patterns, phase gates, and the validation-first design principle.

---

## 1. Overview

Validation-first design is a core Blueprint principle:

> **Every blueprint requirement must include testable validation criteria. If an agent cannot automatically validate a requirement, that requirement will not be met.**

This principle drives the entire validation architecture. Validation is not an afterthought -- it is designed into blueprints from the beginning, and every stage of implementation must pass through validation gates before proceeding.

---

## 2. The 6-Gate Pipeline

### Gate Summary

| Gate | Name | Purpose | Automated? |
|------|------|---------|-----------|
| 1 | Compilation Check | Project compiles without errors | Yes |
| 2 | Isolated Unit Verification | Individual units work correctly | Yes |
| 3 | Cross-Component Integration | Components work together | Yes |
| 4 | Resource and Speed Benchmarks | Performance benchmarks pass | Yes |
| 5 | Startup Smoke Test | Application starts and responds | Yes |
| 6 | Manual Audit | Quality iteration with human auditor | No |

### Gate Execution Order

Gates MUST be run in order. A failure at any gate blocks all subsequent gates.

```
Gate 1: Build
  |
  +-> PASS -> Gate 2: Unit Tests
  |              |
  +-> FAIL       +-> PASS -> Gate 3: E2E / Integration
  |  (fix build) |              |
  |              +-> FAIL       +-> PASS -> Gate 4: Performance
  |              (fix tests)    |              |
  |                             +-> FAIL       +-> PASS -> Gate 5: Launch
  |                             (fix integration)|         |
  |                                              |         +-> PASS -> Gate 6: Human Review
  |                                              |         |
  |                                              |         +-> FAIL
  |                                              |         (fix launch)
  |                                              +-> FAIL
  |                                              (fix perf)
  +-> If ANY gate fails: fix, then re-run from Gate 1
```

---

## 3. Gate 1: Compilation Check

**Purpose:** Verify the project compiles/transpiles without errors.

**Command:**
```bash
{BUILD_COMMAND}
```

**Pass Criteria:**
- Exit code 0
- No compilation errors
- No type errors (for typed languages)
- Warnings may be acceptable depending on project policy

**Generic Examples:**

| Framework | Build Command | Notes |
|-----------|--------------|-------|
| Node.js/TypeScript | `npm run build` | TypeScript compilation |
| Rust | `cargo build` | Includes borrow checker |
| Go | `go build ./...` | All packages |
| Python | `python -m py_compile *.py` | Syntax check |
| Java | `mvn compile` | Maven build |
| .NET | `dotnet build` | MSBuild |

**Common Failures:**
- Missing imports/dependencies
- Type mismatches
- Syntax errors
- Missing module declarations

**Agent Behavior on Failure:**
1. Read the error output
2. Identify the failing file and line
3. Fix the error
4. Re-run the build
5. Repeat until clean

---

## 4. Gate 2: Isolated Unit Verification

**Purpose:** Verify individual units (functions, classes, modules) work correctly in isolation.

**Command:**
```bash
{TEST_COMMAND}
```

**Pass Criteria:**
- All existing tests pass
- New/modified source files have corresponding tests
- No test regressions (tests that passed before still pass)
- Test coverage meets project minimum (if configured)

**Generic Examples:**

| Framework | Test Command | Notes |
|-----------|-------------|-------|
| Node.js | `npm test` | Jest, Vitest, Mocha |
| Rust | `cargo test` | Built-in test framework |
| Go | `go test ./...` | Built-in test framework |
| Python | `pytest` | pytest framework |
| Java | `mvn test` | JUnit |
| .NET | `dotnet test` | xUnit, NUnit |

**Test Generation Pattern:**

After modifying source files, generate tests for the changed files:

```markdown
For each modified source file:
1. Analyze the file's public API
2. Generate unit tests covering:
   - Happy path
   - Edge cases
   - Error cases
   - Boundary conditions
3. Run the generated tests
4. Fix any failures
```

**Common Failures:**
- Logic errors in implementation
- Missing edge case handling
- Broken contracts between modules
- State management issues

**Agent Behavior on Failure:**
1. Read the test failure output
2. Identify which test failed and why
3. Determine if the issue is in the code or the test
4. Fix the appropriate file
5. Re-run tests
6. Repeat until all pass

---

## 5. Gate 3: Cross-Component Integration

**Purpose:** Verify components work together correctly and the system behaves as expected from the user's perspective.

**Command:**
```bash
{TEST_COMMAND} --e2e
# or
{TEST_COMMAND} --integration
# or project-specific command
```

**Pass Criteria:**
- All integration test suites pass
- Cross-module interactions work correctly
- API contracts honored
- Data flows correctly between components

**Generic Examples:**

| Type | Tool | What It Tests |
|------|------|--------------|
| API Integration | supertest, httptest | HTTP endpoints respond correctly |
| Database Integration | testcontainers | Queries produce correct results |
| Service Integration | custom fixtures | Services communicate correctly |
| Browser E2E | Playwright, Cypress | Full user workflows in browser |
| CLI E2E | custom scripts | Command-line tool produces correct output |

**Integration Test Pattern:**

```markdown
For each blueprint requirement with cross-module dependencies:
1. Identify the components involved
2. Set up test fixtures (databases, services, mocks)
3. Execute the full workflow
4. Verify the end state matches blueprint acceptance criteria
5. Tear down fixtures
```

**Common Failures:**
- API contract mismatches
- Database schema/query issues
- Race conditions in async code
- Configuration differences between test and dev environments

**Agent Behavior on Failure:**
1. Read the integration test output
2. Identify which interaction failed
3. Check both sides of the interaction
4. Fix the contract violation
5. Re-run from Gate 1 (build may have changed)

---

## 6. Gate 4: Resource and Speed Benchmarks

**Purpose:** Verify the application meets performance requirements.

**Pass Criteria:**
- Benchmarks pass within acceptable thresholds
- No performance regressions from prior iterations
- Memory usage within bounds
- Response times within blueprint requirements

**Generic Examples:**

| Metric | Tool | Threshold Example |
|--------|------|------------------|
| Response time | k6, ab, wrk | p95 < 200ms |
| Memory usage | valgrind, heaptrack | < 512MB peak |
| Bundle size | webpack-bundle-analyzer | < 2MB gzipped |
| Build time | time command | < 30s |
| Test suite time | test runner | < 5 minutes |
| Startup time | custom measurement | < 3s to interactive |

**Performance Test Pattern:**

```markdown
For each blueprint requirement with performance criteria:
1. Identify the metric and threshold
2. Set up the benchmark environment
3. Run the benchmark N times for statistical significance
4. Compare against threshold
5. If regression detected, profile and fix
```

**Note:** Not all projects need Gate 4. If blueprints have no performance requirements, this gate is skipped.

**Agent Behavior on Failure:**
1. Identify which benchmark failed
2. Profile the slow/heavy code path
3. Optimize (algorithmic improvement, caching, lazy loading)
4. Re-run from Gate 1

---

## 7. Gate 5: Startup Smoke Test

**Purpose:** Verify the application starts up correctly and basic smoke tests pass.

**Pass Criteria:**
- Application starts without errors
- Application responds to basic health checks
- Critical user paths work end-to-end
- No crash within first 30 seconds of operation

**Generic Examples:**

| Application Type | Verification |
|-----------------|-------------|
| Web server | Start server, hit health endpoint, verify 200 |
| CLI tool | Run with `--help`, verify output |
| Library | Import in test harness, call basic API |
| Desktop app | Launch, verify main window renders |
| API service | Start, hit `/health`, verify response |
| Compiler/toolchain | Compile a known-good input, verify output |

**Launch Verification Pattern:**

```markdown
1. Start the application: `{DEV_COMMAND}`
2. Wait for ready signal (port open, log message, etc.)
3. Run smoke tests:
   - [ ] Health endpoint returns 200
   - [ ] Main page renders without errors
   - [ ] Login flow completes successfully
   - [ ] Basic CRUD operations work
4. Shut down the application
5. Verify clean shutdown (no orphan processes)
```

**Common Failures:**
- Missing environment variables
- Port conflicts
- Database connection failures
- Missing runtime dependencies
- Configuration errors

**Agent Behavior on Failure:**
1. Read startup logs
2. Identify the failure point
3. Fix configuration or code
4. Re-run from Gate 1

---

## 8. Gate 6: Manual Audit

**Purpose:** Quality iteration with a human auditor who reviews the agent's work and provides feedback.

**This is the only non-automated gate.**

**What the Human Reviews:**
- Code quality and style
- Architecture alignment with design intent
- Security considerations
- Edge cases the agent may have missed
- UX/UI quality (for user-facing features)
- Performance characteristics
- Test quality and coverage

**Human Review Process:**

```markdown
1. Agent presents summary of changes:
   - What was implemented
   - What tests were added
   - What issues were found and resolved
   - What dead ends were explored

2. Human reviews:
   - Source code diff
   - Test coverage
   - Implementation tracking
   - Running application

3. Human provides feedback:
   - Approve: Work is acceptable
   - Revise: Specific changes needed (feeds back into iteration)
   - Reject: Fundamental approach is wrong (feeds back into blueprint/plan)

4. If revisions needed:
   - Human documents feedback
   - Agent applies revisions
   - Re-run from Gate 1
```

**Key Insight:** Gate 6 is where the "human as auditor" principle manifests. The human reviews and steers but does not implement.

---

## 9. Phase Gates Between DABI Phases

Phase gates are broader than the 6-gate pipeline. They govern transitions between DABI phases.

### Blueprint -> Plan Phase Gate

```markdown
Before starting the Architect phase, verify:
- [ ] All domains identified and blueprint files created
- [ ] Every requirement has testable acceptance criteria
- [ ] Cross-references between blueprints are complete
- [ ] Scope defined (in-scope and out-of-scope)
- [ ] Human has reviewed and approved blueprints
```

### Plan -> Build Phase Gate

```markdown
Before starting the Build phase, verify:
- [ ] All blueprint requirements mapped to plan tasks
- [ ] Task dependencies defined and acyclic
- [ ] Test strategies defined for each feature
- [ ] Build site established
- [ ] Framework research complete
- [ ] Human has reviewed architecture decisions
```

### Implement -> Iterate Phase Gate

```markdown
Before starting the Iterate phase, verify:
- [ ] Gates 1-5 pass (build, test, integration, perf, launch)
- [ ] Implementation tracking is current
- [ ] All completed tasks verified with passing tests
- [ ] No P0 issues outstanding
```

### Iterate -> Monitor Phase Gate

```markdown
Before starting the Monitor phase, verify:
- [ ] All revision targets addressed
- [ ] Regression tests generated and passing
- [ ] Iteration loop re-run confirms fixes
- [ ] Implementation tracking updated
```

---

## 10. Validation-First Blueprint Design

The key principle that makes validation gates work:

> **If an agent cannot automatically validate a requirement, that requirement will not be met.**

### How to Write Validatable Requirements

**Bad (not validatable):**
```markdown
### R1: The UI should look good
```

**Good (validatable):**
```markdown
### R1: Navigation renders correctly
**Acceptance Criteria:**
- [ ] Navigation bar renders with all menu items visible
- [ ] Menu items match the list in blueprint-ui.md section 2.1
- [ ] Navigation is responsive (works at 320px, 768px, 1024px widths)
- [ ] All navigation links resolve to valid routes
```

### Mapping Requirements to Gates

Every blueprint requirement should map to at least one validation gate:

| Requirement Type | Primary Gate | Secondary Gate |
|-----------------|-------------|----------------|
| Data model correctness | Gate 2 (Unit) | Gate 3 (Integration) |
| API contract | Gate 2 (Unit) | Gate 3 (Integration) |
| User workflow | Gate 3 (Integration) | Gate 5 (Launch) |
| Performance target | Gate 4 (Performance) | - |
| Startup behavior | Gate 5 (Launch) | - |
| Visual quality | Gate 6 (Human) | Gate 3 (E2E screenshot) |
| Security constraint | Gate 2 (Unit) | Gate 3 (Integration) |

### Validation Coverage Matrix

For large projects, maintain a matrix mapping every blueprint requirement to its validation gates:

```markdown
| Blueprint | Requirement | Gate 1 | Gate 2 | Gate 3 | Gate 4 | Gate 5 | Gate 6 |
|-----------|------------|--------|--------|--------|--------|--------|--------|
| blueprint-auth | R1: Login | Build | Unit | E2E | - | Launch | Review |
| blueprint-auth | R2: Session | Build | Unit | E2E | - | - | Review |
| blueprint-data | R1: Schema | Build | Unit | Int | - | - | - |
| blueprint-data | R2: Query perf | Build | Unit | Int | Perf | - | - |
| blueprint-ui | R1: Navigation | Build | Unit | E2E | - | Launch | Review |
```

If a requirement has NO gate coverage, it is effectively unvalidated and is unlikely to be implemented correctly.

---

## 11. Merge Protocol Validation

When using agent teams, each merge triggers the full validation pipeline:

```markdown
## Merge Protocol

For each teammate's work (merge one at a time):

1. Merge the teammate's branch into main
2. Run Gate 1: {BUILD_COMMAND}
   - If FAIL: fix, rebuild, re-verify
3. Run Gate 2: {TEST_COMMAND}
   - If FAIL: fix, retest, re-verify
4. Run Gate 3: Integration/E2E tests
   - If FAIL: fix, retest, re-verify
5. Verify the merged feature works as expected
6. Clean up branch
7. ONLY proceed to next teammate after ALL gates pass
```

### Why One-at-a-Time

Merging one teammate at a time with validation between each merge:
- Isolates merge failures to a single teammate's changes
- Makes debugging merge issues straightforward
- Prevents cascading failures
- Provides a clean rollback point (revert last merge)

---

## 12. Completion Signal Integration

Gates integrate with the iteration loop through completion signals:

```markdown
## Completion Check

After running all validation gates:

If ALL gates pass AND all exit criteria are met:
  Emit: <all-tasks-complete>

If ANY gate fails:
  Do NOT emit completion signal
  Fix the failure
  Re-run from Gate 1
```

The iteration loop automation searches for the completion signal to decide whether to stop iterating or start another pass.

---

## 13. Gate Failure Patterns

### Cascading Failures

A single root cause can fail multiple gates. Always fix the earliest-failing gate first:
- If Gate 1 fails, do not look at Gate 2-6 results (they are meaningless)
- If Gate 2 fails, Gate 3-6 results may be affected
- Fix from the bottom up

### Flaky Tests

Tests that pass and fail non-deterministically:
- Identify and quarantine flaky tests
- Do not let flaky tests block the pipeline
- Fix flaky tests as priority work items
- Document known flaky tests in implementation tracking

### Environment-Dependent Failures

Tests that pass locally but fail in different environments:
- Ensure test fixtures are self-contained
- Avoid reliance on external services in automated gates
- Use mocks/stubs for external dependencies
- Document environment requirements

---

## 14. Validation Automation Commands

### Generic Validation Script Pattern

```bash
#!/bin/bash
set -e

echo "=== Gate 1: Build ==="
{BUILD_COMMAND}

echo "=== Gate 2: Unit Tests ==="
{TEST_COMMAND}

echo "=== Gate 3: Integration Tests ==="
{TEST_COMMAND} --integration

echo "=== Gate 4: Performance ==="
# Project-specific benchmarks
{BENCH_COMMAND}

echo "=== Gate 5: Launch Verification ==="
# Start app, run smoke tests, shut down
{DEV_COMMAND} &
APP_PID=$!
sleep 5  # Wait for startup
curl -f http://localhost:{PORT}/health || exit 1
kill $APP_PID

echo "=== All automated gates passed ==="
```

### Per-Gate Scripts

For more control, use separate scripts per gate:

```bash
scripts/
+-- validate-build.sh      # Gate 1
+-- validate-unit.sh        # Gate 2
+-- validate-integration.sh # Gate 3
+-- validate-perf.sh        # Gate 4
+-- validate-launch.sh      # Gate 5
```

Each script exits with code 0 on success, non-zero on failure.

---

## 15. Key Principles Summary

1. **Gates are ordered.** Always run from Gate 1 through Gate 6. Never skip gates.
2. **Fix the earliest failure first.** Later gate results are unreliable if earlier gates failed.
3. **One merge at a time.** Merge -> validate -> clean -> next merge.
4. **If the agent cannot validate it, it will not be met.** Design blueprints with automated validation in mind.
5. **The human is the final gate.** Gate 6 catches what automation cannot.
6. **Validation is not optional.** Every blueprint requirement must map to at least one gate.
7. **Completion signals require all gates passing.** Never emit `<all-tasks-complete>` with failing gates.
