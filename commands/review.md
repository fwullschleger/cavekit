---
name: sdd-review
description: "Review the last loop: gap analysis against specs + adversarial code review for bugs, security, and quality"
argument-hint: "[--filter PATTERN]"
---

# SDD Review — Post-Loop Analysis

Run this after `/sdd:execute` completes (or is stopped). It does two things:

1. **Gap analysis** — compares what was built against what the specs require
2. **Adversarial review** — finds bugs, security issues, and quality problems in the code that was written

## Step 1: Gather Context

Read these files to understand what happened:

1. **Frontier** — find in `context/frontiers/` or `context/plans/` (apply `--filter` from `$ARGUMENTS` if set)
2. **Specs** — all `context/specs/spec-*.md` files (apply filter)
3. **Impl tracking** — all `context/impl/impl-*.md` files
4. **Loop log** — `context/impl/loop-log.md`
5. **Git history** — run `git log --oneline -30` to see recent commits from the loop
6. **Git diff** — run `git diff main...HEAD` (or appropriate base branch) to see all code changes

If no impl tracking or loop log exists, tell the user:
> No loop artifacts found. Run `/sdd:execute` first, then `/sdd:review` after it completes.

## Step 2: Gap Analysis

For every spec requirement (R-numbered) and its acceptance criteria, determine status:

| Status | Meaning |
|--------|---------|
| **COMPLETE** | All acceptance criteria met, code exists, tests pass |
| **PARTIAL** | Some criteria met, others missing or untested |
| **MISSING** | Not implemented at all |
| **OVER-BUILT** | Code exists that no spec requires |

**How to verify:**
- Don't trust impl tracking alone — check the actual code
- For each acceptance criterion, find the code that satisfies it
- Check if tests exist and whether they actually test the criterion
- Run the test suite if possible: `npm test`, `pytest`, `cargo test`, etc.

## Step 3: Adversarial Code Review

Review all code changes from the loop (`git diff` output) looking for:

**Bugs**
- Logic errors, off-by-one, null/undefined handling
- Race conditions, deadlocks
- Edge cases not covered
- Error handling that swallows failures silently

**Security**
- Input validation gaps (injection, XSS, path traversal)
- Auth/authz bypasses
- Data exposure in logs, errors, or API responses
- Hardcoded secrets

**Performance**
- O(n^2+) on unbounded data
- Missing pagination
- N+1 queries
- Synchronous blocking where async is needed
- Resource leaks

**Quality**
- Dead code, unused imports
- Unnecessary complexity or abstraction
- Inconsistency with existing codebase patterns
- Missing error handling on external calls

**Spec Gaps**
- Requirements that SHOULD exist but don't
- Edge cases the spec doesn't address
- Integration points between domains that are undefined

## Step 4: Generate Report

Present this to the user:

```markdown
# SDD Review Report

**Date:** {date}
**Loop iterations:** {from loop-log.md}
**Commits:** {count from git log}
**Files changed:** {count}

---

## Gap Analysis

### Coverage
| Status | Requirements | Acceptance Criteria | % |
|--------|-------------|--------------------|----|
| COMPLETE | {n} | {n} | {%} |
| PARTIAL | {n} | {n} | {%} |
| MISSING | {n} | {n} | {%} |
| OVER-BUILT | {n} | — | — |

### Progress Bar
[████████████████░░░░] 82% coverage

### Gaps Found

#### PARTIAL — needs more work
| Requirement | Spec | What's Done | What's Missing |
|------------|------|-------------|----------------|
| R{n}: {name} | spec-{domain}.md | {met criteria} | {unmet criteria} |

#### MISSING — not started
| Requirement | Spec | Why |
|------------|------|-----|
| R{n}: {name} | spec-{domain}.md | {not in frontier / blocked / dead end} |

#### OVER-BUILT — no spec for this
| Feature | Files | Recommendation |
|---------|-------|---------------|
| {feature} | {files} | Add spec / Remove code |

---

## Adversarial Review

### Findings: {total} ({P0 count} critical, {P1 count} high, {P2 count} medium, {P3 count} low)

#### P0 — Critical (blocks release)
**F-001: {title}**
- File: {path}:{lines}
- Issue: {what's wrong}
- Evidence: {code snippet or test result}
- Fix: {specific action}

#### P1 — High (should fix before merge)
...

#### P2 — Medium
...

#### P3 — Low
...

---

## Verdict

**{APPROVE / REVISE / REJECT}**

- APPROVE: No P0/P1 findings, coverage > 90%
- REVISE: P1 findings or coverage 70-90%
- REJECT: P0 findings or coverage < 70%

## Recommended Next Steps
1. {highest priority action}
2. {next action}
3. {if gaps exist: run `/sdd:execute` again to address remaining work}
4. {if spec gaps found: specs will be updated below, then `/sdd:plan` + `/sdd:execute`}
```

## Step 5: Back-Propagate

After presenting the report, **automatically update specs and frontier** based on findings. Do not ask — just do it.

### Update Specs

For each finding that reveals a spec gap:

- **Missing requirement** — add it to the appropriate spec file as a new R-number with acceptance criteria
- **Ambiguous criterion** — rewrite the criterion to be specific and testable
- **Untestable criterion** — rewrite to be automatically verifiable, or flag with `[HUMAN REVIEW]`
- **Over-built feature worth keeping** — add a new requirement to formalize it
- **Over-built feature not worth keeping** — note in the report but don't add to spec
- **Security/bug finding that exposes a spec gap** — add a requirement that would have caught it (e.g. "R7: Input Validation — all user input is sanitized before database queries")

When modifying a spec file:
- Update the `last_edited` date in frontmatter
- Add new requirements at the end of the existing requirements list
- Add a `## Changes` section at the bottom noting what was added and why:

```markdown
## Changes
- {date}: Added R{n} ({title}) — discovered during review (finding F-{n})
```

### Update Frontier

If new requirements were added to specs, add corresponding tasks to the frontier:

1. Read `context/frontiers/feature-frontier.md`
2. For each new requirement, create task(s) with T-numbers continuing from the last existing task
3. Place tasks in the appropriate tier based on dependencies
4. Update the `last_edited` date in frontmatter
5. Update the summary table at the bottom

### Update Impl Tracking

For each adversarial finding (bugs, security, performance):

1. Read or create `context/impl/impl-review-findings.md`
2. Log each finding with status NEW:

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Review Findings

| Finding | Severity | File | Status |
|---------|----------|------|--------|
| F-001: {title} | P0 | {path} | NEW |
| F-002: {title} | P1 | {path} | NEW |
```

These findings will be picked up by the next `/sdd:execute` loop — the execute prompt reads impl tracking and prioritizes P0 issues first.

### Report What Changed

After back-propagation, tell the user:

```markdown
## Back-Propagation Summary

### Specs Updated
| Spec | Changes |
|------|---------|
| spec-{domain}.md | Added R{n}: {title} |

### Frontier Updated
| Task | Title | Tier | From Finding |
|------|-------|------|-------------|
| T-{n} | {title} | {tier} | F-{n} |

### Findings Logged
{n} findings written to context/impl/impl-review-findings.md

Ready for next cycle: `/sdd:execute`
```
