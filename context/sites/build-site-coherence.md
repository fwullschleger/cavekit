---
created: "2026-03-20T00:00:00Z"
last_edited: "2026-03-20T00:00:00Z"
---

# Build Site — Spec Sync & Build Lifecycle

18 tasks across 3 tiers from 2 blueprints.

---

## Tier 0 — No Dependencies (Start Here)

| Task | Title | Blueprint | Requirement | Effort |
|------|-------|-----------|-------------|--------|
| T-001 | Add changelog section to blueprint format | blueprint-spec-sync.md | R2 | S |
| T-002 | Ensure /bp:draft generates blueprints with empty changelog | blueprint-spec-sync.md | R2 | S |
| T-003 | Implement changelog append logic | blueprint-spec-sync.md | R2 | M |
| T-004 | Merge main into existing worktree branch on build start | blueprint-build-lifecycle.md | R1 | M |
| T-005 | Handle merge conflicts with user notification and options | blueprint-build-lifecycle.md | R1 | M |
| T-006 | Log merge results for user visibility | blueprint-build-lifecycle.md | R1 | S |
| T-007 | Forward .env* files from project root to worktree on creation | blueprint-build-lifecycle.md | R2 | M |
| T-008 | Verify and restore env file availability on resume | blueprint-build-lifecycle.md | R2 | S |

---

## Tier 1 — Depends on Tier 0

| Task | Title | Blueprint | Requirement | blockedBy | Effort |
|------|-------|-----------|-------------|-----------|--------|
| T-009 | Scan commits since last revision and identify affected requirements | blueprint-spec-sync.md | R1 | T-003 | L |
| T-010 | Update blueprint requirements to reflect current implementation | blueprint-spec-sync.md | R1 | T-003 | L |
| T-011 | Present recovery options on build failure (resume/abandon/merge) | blueprint-build-lifecycle.md | R3 | T-004, T-007 | M |
| T-012 | Clean up abandoned worktrees (remove worktree and branch) | blueprint-build-lifecycle.md | R3 | T-004 | S |
| T-013 | Resume flow: re-run merge and env verification before restart | blueprint-build-lifecycle.md | R3 | T-004, T-007 | M |

---

## Tier 2 — Depends on Tier 1

| Task | Title | Blueprint | Requirement | blockedBy | Effort |
|------|-------|-----------|-------------|-----------|--------|
| T-014 | Update blueprint-overview.md after revision (counts, scope, cross-refs) | blueprint-spec-sync.md | R3 | T-010 | M |
| T-015 | Detect build site drift after revision (stale, orphaned, out-of-date tasks) | blueprint-spec-sync.md | R4 | T-010 | M |
| T-016 | Worktree health check before build operations | blueprint-build-lifecycle.md | R4 | T-004, T-007 | M |
| T-017 | Surface health check and recovery state in TUI | blueprint-build-lifecycle.md | R3, R4 | T-011, T-016 | M |
| T-018 | Archive impl state on build stop (loop log, impl files, progress summary) | blueprint-build-lifecycle.md | R5 | T-011 | M |

---

## Summary

| Tier | Tasks | Effort |
|------|-------|--------|
| 0 | 8 | 3S, 4M, 1L |
| 1 | 5 | 1S, 2M, 2L |
| 2 | 5 | 0S, 5M, 0L |

**Total: 18 tasks, 3 tiers**
