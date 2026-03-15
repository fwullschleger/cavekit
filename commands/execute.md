---
name: sdd-execute
description: "Start a Ralph Loop that implements the feature frontier — builds, validates, commits, repeats"
argument-hint: "[--filter PATTERN] [--adversarial] [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-execute.sh:*)", "Bash(cd *)"]
---

# SDD Execute — Run the Implementation Loop

This is the third phase of SDD. Execute the setup script:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-execute.sh" $ARGUMENTS
```

## IMPORTANT: Switch to worktree

The setup script creates a git worktree for isolation. Look for the `SDD_WORKTREE_PATH=` line in the output. If present, you MUST `cd` into that path before doing any work:

```
cd <SDD_WORKTREE_PATH value>
```

If no `SDD_WORKTREE_PATH` line appears, you're already in a worktree — stay where you are.

## How This Works

1. Creates a git worktree for isolated execution
2. Archives any previous loop cycle automatically
3. Reads the feature frontier to find unblocked tasks
4. Each iteration: pick task → read spec → implement → validate → commit
5. With `--adversarial`: alternates build iterations with Codex (GPT-5.4) review
6. Exits when all tasks are done

You are now in a Ralph Loop implementing the feature frontier. Follow the prompt instructions exactly.

## Critical Rules

- NEVER output the completion promise unless ALL tasks are genuinely DONE
- ONE task per iteration — stay focused
- If stuck 2+ iterations, document as dead end and move on
- Always run validation gates before committing
