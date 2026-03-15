---
name: sdd-merge
description: "Merge completed SDD branches into main — resolves conflicts intelligently using specs and implementation context"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
---

# SDD Merge — Spec-Aware Branch Integration

You are merging completed SDD execution branches back into the main branch. Your job is to merge each `sdd/*` branch one at a time, resolving any conflicts by understanding what each frontier's spec intended and preserving ALL features from ALL branches.

## Step 1: Survey Branches

Run:
```bash
git branch --list 'sdd/*'
```

For each branch, examine:
1. The commits: `git log --oneline main..<branch>`
2. The files changed: `git diff --name-only main...<branch>`
3. The frontier spec it implemented — read `context/frontiers/` and `context/specs/` in the worktree or branch

Build a mental model of what each branch built and which files overlap.

## Step 2: Determine Merge Order

Merge branches in this order:
1. **Foundation/infrastructure branches first** (data models, types, utilities)
2. **Feature branches next** (things that build on infrastructure)
3. **UI branches last** (most likely to conflict, benefit from having backend merged first)

If unsure, merge the branch with the fewest file overlaps first.

## Step 3: Merge Each Branch

For each branch:

### 3a. Read the specs
Before merging, read the specs and impl tracking for this branch to understand what it built and why. Check the worktree if it exists:
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
BRANCH_NAME="<branch>"
WT_NAME="${BRANCH_NAME#sdd/}"
WT_PATH="${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-${WT_NAME}"
```

Read frontier and impl files from the worktree or from the branch directly:
```bash
git show <branch>:context/frontiers/<frontier-file>
```

### 3b. Attempt the merge
```bash
git checkout main
git merge <branch> --no-ff -m "Merge <branch>: <brief description of what was built>"
```

### 3c. If conflicts occur
1. List conflicting files: `git diff --name-only --diff-filter=U`
2. For each conflicting file:
   - Read the file to see the conflict markers
   - Read the relevant specs from BOTH branches to understand intent
   - Resolve by **keeping ALL functionality from both sides**
   - The merge result must satisfy the acceptance criteria from both specs
3. Stage resolved files: `git add <file>`
4. Commit: `git commit -m "Merge <branch>: resolve conflicts preserving all features"`

### 3d. Validate after merge
- Run build: ensure it compiles/passes
- Run tests on changed files
- Verify no spec requirements were lost

### 3e. Clean up
```bash
# Remove worktree if it exists
WT_PATH="${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-${WT_NAME}"
rm -f "$WT_PATH/.claude/ralph-loop.local.md" 2>/dev/null
git worktree remove "$WT_PATH" --force 2>/dev/null

# Delete the branch
git branch -d <branch>
```

## Step 4: Final Validation

After all branches are merged:
1. Run full build
2. Run full test suite
3. Read each frontier's spec and verify key requirements are still met
4. Report what was merged and any concerns

## Conflict Resolution Rules

- **NEVER drop functionality** — both branches' features must survive
- **Imports**: combine all imports from both sides
- **Types/interfaces**: merge fields from both, use union types if needed
- **Functions**: keep both, rename if signatures conflict
- **Config/routes**: include entries from both branches
- **Tests**: keep all tests from both sides
- **If truly incompatible**: implement an adapter that satisfies both specs, explain the trade-off
