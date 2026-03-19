---
created: "2026-03-17T00:00:00Z"
last_edited: "2026-03-17T00:00:00Z"
---
# Implementation Tracking: Frontier

| Task | Status | Notes |
|------|--------|-------|
| T-005 | DONE | Frontier discovery in context/sites/ and context/frontiers/. Canonical name derivation matching bash sed chain. |
| T-006 | DONE | Frontier markdown parsing: task IDs, tier structure, table rows with blockedBy/effort. internal/frontier/parser.go. |
| T-014 | DONE | Task status tracking from impl-*.md files with word boundary matching. ComputeProgress for aggregates. internal/frontier/tracking.go. |
| T-015 | DONE | Frontier status classification: done/in-progress/available with Ralph Loop detection. internal/frontier/status.go. |
| T-017 | DONE | Progress summary string: "{icon} {name} {done}/{total} [{currentTask}]". internal/frontier/progress.go. |
| T-016 | DONE | Multi-candidate ranking: score 3 (active loop) > 2 (worktree/incomplete) > 1. Filter fail-fast, alphabetical tie-break. internal/frontier/ranking.go. |
