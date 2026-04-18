---
name: ck-resume
description: "Resume a Cavekit loop after a crash, lock conflict, or manual interrupt. Rebuilds context from .cavekit/ and picks up at the first unblocked task."
argument-hint: "[--force] [--from-iteration N]"
allowed-tools: ["Bash(node ${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs:*)", "Bash(git *)", "Read(*)", "Write(*)", "Edit(*)"]
---

# Cavekit Resume

Recover from an interrupted loop without losing progress. The state is already
on disk — this command just re-validates it and re-enters the loop.

## Pre-flight

1. Check `.cavekit/state.md` exists. If not, tell the user to run `/ck:make`
   instead — there is nothing to resume.

2. Read the current state:
   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs" status
   ```

3. Inspect the lock:
   ```bash
   cat .cavekit/.loop.lock 2>/dev/null || echo "(no lock)"
   ```

   - **Fresh lock, different owner** → another session is running. Abort.
     Ask the user to stop that session first.
   - **Stale lock (> 5 min old)** → safe to steal. Continue.
   - **No lock** → already released. Continue.

   With `--force`, skip the conflict check and overwrite any lock.

## Restore and route

4. Release the old lock if it is ours / stale:
   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs" release-lock
   ```

5. Optionally rewind iteration counter:
   - If the caller passed `--from-iteration N`, set `iteration = N` in
     `state.md`'s frontmatter. Otherwise keep the current count.

6. Re-summarize progress for the user:
   - `done / total` tasks
   - current phase
   - session tokens used vs. budget
   - next unblocked task

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs" next-task
   ```

7. Ask the user to confirm the resume plan:
   > About to resume at task T-042 ("Implement rate-limit middleware"), tier 2.
   > Session tokens: 182 000 / 500 000. Continue? [y/n]

8. On confirmation, re-enter the loop by emitting the "next step" prompt
   (same shape as the stop-hook route output) so the autonomous loop picks
   it up. The stop hook will take over from there.

## Recovery edge cases

- **Task half-done** — if the task registry shows a task as `implementing` or
  `testing` and there are uncommitted changes, ask the user whether to roll
  back (`git stash`) or keep going. Do not silently discard work.
- **Backprop flag pending** — if `.cavekit/.auto-backprop-pending.json` exists
  from the previous run, honour it on the first iteration (the stop hook will
  prepend the directive automatically).
- **Budget near cap** — if session tokens ≥ 90 %, prompt the user to raise
  `session_budget` before resuming, or start a fresh session via `/ck:check`.

## Critical rules

- Resume is a read-then-route operation. Never mutate `.cavekit/` state before
  the user confirms the plan.
- If the registry is empty or fully `complete`, exit with "nothing to resume".
- Never emit the completion sentinel from `/ck:resume` — only the loop itself
  may end itself.
