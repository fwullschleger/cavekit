---
name: sdd-progress
description: "Show progress against the feature frontier — tasks done, in progress, blocked, remaining"
argument-hint: "[--filter PATTERN]"
---

# SDD Progress

Show the user a progress report by comparing the feature frontier against implementation tracking.

## Step 1: Find Frontier

Look in `context/frontiers/` then `context/plans/` for `*frontier*` files. If `--filter` is set (parse from `$ARGUMENTS`), match against it.

If no frontier found: "No frontier found. Run `/sdd:plan` first."

## Step 2: Read State

1. Read the frontier file — catalog every task (T-number), its tier, spec requirement, and blockedBy
2. Read all `context/impl/impl-*.md` files — extract task statuses (DONE, IN_PROGRESS, BLOCKED)
3. Read `context/impl/loop-log.md` if it exists — get the latest iteration number and last task completed

## Step 3: Classify Tasks

For each task in the frontier:
- **DONE** — marked done in impl tracking
- **IN_PROGRESS** — marked in progress
- **BLOCKED** — has unfinished blockedBy dependencies
- **READY** — all dependencies done, not started yet (next up)
- **WAITING** — dependencies not yet done, not directly blocked

## Step 4: Display Report

```markdown
## SDD Progress

### Summary
| Status | Count | % |
|--------|-------|---|
| DONE | {n} | {%} |
| IN_PROGRESS | {n} | {%} |
| READY | {n} | {%} |
| BLOCKED | {n} | {%} |
| WAITING | {n} | {%} |

### Progress Bar
[████████████░░░░░░░░] 58% (20/34 tasks)

### Current Tier: {n}
{tier name if any}

### Ready to Implement (next up)
| Task | Title | Spec | Requirement |
|------|-------|------|------------|
| T-{id} | {title} | spec-{domain}.md | R{n} |

### Recently Completed
| Task | Title | Iteration |
|------|-------|-----------|
| T-{id} | {title} | {n} |

### Blocked
| Task | Title | Waiting On |
|------|-------|-----------|
| T-{id} | {title} | T-{id} (status) |

### Dead Ends (if any)
| Task | Approach | Why Failed |
|------|----------|-----------|
| T-{id} | {what was tried} | {why it failed} |

### Loop Status
- Iterations completed: {n}
- Last iteration: {timestamp}
- Active: {yes/no — .claude/ralph-loop.local.md exists?}
```

Display this to the user.
