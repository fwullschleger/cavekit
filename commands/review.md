---
name: ck-review
description: "Review the current branch end-to-end — kit compliance and code quality, with optional Codex second opinion. Modes: full (default), --mode gap, --codex, --tier."
argument-hint: "[--base REF] [--codex] [--mode gap|full] [--tier] [--strict]"
allowed-tools: ["Bash(git *)", "Bash(node ${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh:*)", "Read(*)", "Grep(*)", "Glob(*)", "Agent(ck:inspector,ck:surveyor,ck:verifier,ck:researcher)"]
---

**What this does:** Reviews the current branch against kits and code-quality standards. Two passes by default: kit compliance (Karpathy guardrails) then code quality. Flags narrow the scope.
**When to use it:** Before merging to main. As a tier gate inside `/ck:make`. Or on demand to get a second opinion on a diff.

## Modes

| Flag | Behavior |
|------|----------|
| (default) | Two-pass branch review: kit compliance (Pass 1) then code quality (Pass 2). |
| `--mode gap` | Gap analysis only — built vs kits, no code-quality pass. Dispatches `ck:surveyor`. |
| `--codex` | Codex-only adversarial review on the diff. Calls `scripts/codex-review.sh`. Can combine with other modes for a second opinion. |
| `--tier` | Tier-gate mode: on BLOCKED, emits fix tasks back into the loop (see Fix Cycle below). |
| `--strict` | Any IMPORTANT finding blocks merge. Default gates only on CRITICAL. |
| `--base REF` | Override the diff base. Default is upstream tracking branch, falling back to `main`/`master`/`develop`. |

## Setup

1. Compute base ref:
   ```bash
   BASE="${ARGUMENTS_BASE:-$(git merge-base HEAD $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'))}"
   git diff "$BASE"...HEAD --stat
   ```
2. Resolve model:
   ```bash
   REASONING_MODEL=$("${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" model reasoning)
   ```

## `--mode gap` path (dispatches ck:surveyor)

Compare kits against code to identify gaps. Dispatch a `ck:surveyor` subagent with `model: "{REASONING_MODEL}"`:

### Phase 1: Read Kits
1. Read `context/kits/cavekit-overview.md`.
2. Read every `context/kits/cavekit-*.md`.
3. Catalog every requirement and acceptance criterion.

### Phase 2: Read Implementation
1. Read all impl tracking files in `context/impl/`.
2. Read `context/plans/plan-build-site.md`.
3. Read `context/plans/plan-known-issues.md` if present.
4. Optionally run the test suite.

### Phase 3: Classify
For each criterion: **COMPLETE**, **PARTIAL**, **MISSING**, **OVER-BUILT**, **UNTESTABLE**.

### Phase 4: Root-Cause Gaps
| Root Cause | Fix Target |
|-----------|------------|
| **Cavekit gap** | Update cavekit |
| **Plan gap** | Update plan |
| **Implementation gap** | Continue implementing |
| **Validation gap** | Add tests |
| **Scope creep** | Add cavekit or remove code |

### Phase 5: Report

```markdown
## Gap Analysis Report

### Summary
| Status | Count | Percentage |
|--------|-------|-----------|
| COMPLETE | {n} | {%} |
| PARTIAL | {n} | {%} |
| MISSING | {n} | {%} |
| OVER-BUILT | {n} | {%} |
| UNTESTABLE | {n} | {%} |

### Overall Coverage: {complete + partial} / {total requirements}

### Detailed Findings

#### Complete
| Requirement | Cavekit | Evidence |
|------------|------|----------|
| R1: {name} | cavekit-{domain}.md | {test file or impl reference} |

#### Partial
| Requirement | Cavekit | Met | Missing | Root Cause |
|------------|------|-----|---------|-----------|
| R2: {name} | cavekit-{domain}.md | {criteria met} | {criteria missing} | {cavekit/plan/impl/validation gap} |

#### Missing
| Requirement | Cavekit | Root Cause | Suggested Action |
|------------|------|-----------|-----------------|

#### Over-Built
| Feature | Files | Cavekit Coverage | Suggested Action |
|---------|-------|--------------|-----------------|

#### Untestable
| Requirement | Cavekit | Why Untestable | Suggested Action |
|------------|------|---------------|-----------------|

### Revision Targets
| Priority | Target File | Change Needed | Affected Requirements |
|----------|------------|--------------|----------------------|
| P0 | cavekit-{domain}.md | {what to update} | R{n}, R{n} |

### Recommended Next Steps
1. Run `/ck:revise --trace` to trace gaps into context files
2. {Specific cavekit updates needed}
3. {Specific plan updates needed}
4. {Implementation work remaining}
```

Present this report to the user.

Next: `/ck:revise --trace` if the surveyor recommends kit amendments.

## `--codex` path (pure Codex adversarial review)

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh" $ARGUMENTS
```

- Diffs the current tier's changes against the worktree base (or `--base` override).
- Findings printed in Cavekit format (`F-NNN`, `P0`–`P3`, `source: codex`).
- Appended to `context/impl/impl-review-findings.md`.
- If `codex` is not installed, the script exits gracefully — no error.

After the script:
1. If findings: summarize by severity, highlight P0/P1, name the findings file.
2. If clean: confirm.
3. If Codex unavailable: note that `npm install -g @openai/codex` enables this mode.

## Default path — two-pass branch review

### Pass 1 — Kit Compliance (Karpathy)

Invoke the `karpathy-guardrails` skill. For each file in the diff:
- Does every diff line trace to a kit acceptance criterion? List `kit / R-ID / AC-ID` per hunk.
- Silent assumptions? "While I'm here" edits? Out-of-scope files?
- Are acceptance criteria verifiable, and did the author verify them?

Severity: **CRITICAL** (blocks merge) / **IMPORTANT** (should fix) / **MINOR** (optional).

If Pass 1 has any CRITICAL finding, **do not run Pass 2**. Report Pass 1 only and stop.

### Pass 2 — Code Quality

Only runs if Pass 1 is clean of CRITICAL findings. Dispatch `ck:inspector` with `model: "{REASONING_MODEL}"`. Check:
- Naming, structure, API shape.
- Test quality: assertions on behavior, not implementation details.
- Error handling at system boundaries; no bare `try/except`.
- Security: input validation, secrets, authn/authz, injection.
- Observability: logs/metrics for new code paths.

### Optional Codex second pass

If `--codex` is also passed and `codex` is on `$PATH`:

```bash
if [[ -x "${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh" ]]; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/codex-review.sh" --base "$BASE"
fi
```

Diff the two findings sets. Unique-to-Codex items surface as IMPORTANT. Agreement across both reviewers raises confidence tier.

## Report shape

```
═══ Branch Review ═══
Base: <sha>  →  HEAD: <sha>
Files: {N}   Tests: {N}   Diff lines: +{a} -{b}

Pass 1 — Kit Compliance
  CRITICAL: {n}
  IMPORTANT: {n}
  MINOR: {n}

Pass 2 — Code Quality     {skipped if Pass 1 blocked}
  CRITICAL: {n}
  IMPORTANT: {n}
  MINOR: {n}

Verdict: {PROCEED | BLOCKED}
```

With `--strict`, any IMPORTANT finding also blocks.

## Fix Cycle (`--tier` mode)

When `/ck:review --tier` runs as a tier gate during `/ck:make` and the verdict is `BLOCKED`:

1. Turn each blocking finding into a fix task:
   ```
   FIX-{n}: {finding summary}
     Cite: {file:line}
     Kit: {kit}:R{id}{.AC-id?}
     Severity: CRITICAL|IMPORTANT
   ```
2. Hand fix tasks back to the loop. Stop-hook routes the next wave with these as additional `ck:task-builder` prompts (same model tier as the original task).
3. Track `review_fix_cycle` in `.cavekit/state.md`. After each fix wave, re-run `/ck:review --tier`:
   - Clean → advance the tier.
   - Blocked and cycle < 2 → another fix wave.
   - Blocked and cycle == 2 → emit `ADVANCE_WITH_FINDINGS`, log unresolved items to `.cavekit/history/backprop-log.md` as candidate kit amendments, advance.

This matches the existing `bp_review_fix_cycle` guard in `scripts/codex-gate.sh`.

## Critical rules

- Read actual diff hunks before citing findings. Never cite a file you didn't read.
- Every finding cites `file:line` and a kit R-ID.
- This command reports only — fixes are a follow-up.
- `--codex` falls back gracefully when Codex is unavailable.

Next: if BLOCKED and not in tier mode, fix the findings and re-run `/ck:review`. If verdict recommends kit amendments, run `/ck:revise --trace`.
