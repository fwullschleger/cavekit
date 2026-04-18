---
phase: idle
current_task: null
iteration: 0
updated_at: null
auto_backprop_pending: false
---

# Cavekit State

The autonomous loop driver writes this file. Do not edit by hand while a loop
is active — the stop hook is the only authorized writer of the `phase` field.

## Phase reference

| Phase              | When it fires                                                      |
|--------------------|--------------------------------------------------------------------|
| `idle`             | No loop active.                                                    |
| `drafting`         | `/ck:sketch` is gathering kit input.                               |
| `mapping`          | `/ck:map` is producing a build site.                               |
| `building`         | `/ck:make` loop is executing wave-by-wave.                         |
| `reviewing`        | Tier gate / Codex peer review in progress.                         |
| `inspecting`       | `/ck:check` is running gap analysis.                               |
| `verifying`        | `forge:verifier` is running goal-backward checks.                  |
| `recovering`       | Backpropagation is patching a spec before retrying the task.       |
| `budget_exhausted` | Session or task budget tripped. Hook returns a terminal prompt.    |
| `lock_conflict`    | Another session owns the lock.                                     |
| `complete`         | Loop torn down after the completion sentinel was emitted.          |

## Caveman fallbacks

When an internal agent cannot reconstruct compressed context, it must regenerate
the affected artifact in verbose form and log a one-liner below.

<!-- append entries like:
- 2026-04-17T12:34Z T-017 verifier fallback: artifact summary re-expanded
-->
