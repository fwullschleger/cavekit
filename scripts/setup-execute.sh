#!/bin/bash

# SDD Execute Setup Script
# Archives old cycle, reads frontier, starts Ralph Loop.
# Optionally configures Codex MCP for adversarial review.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FILTER=""
ADVERSARIAL=false
MAX_ITERATIONS=20
COMPLETION_PROMISE="SPEC COMPLETE"
CODEX_MODEL="gpt-5.4"
REVIEW_INTERVAL=2

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
SDD Execute — Run the implementation loop

USAGE:
  /sdd execute [OPTIONS]

OPTIONS:
  --filter <pattern>             Scope to specs/frontier matching pattern
  --adversarial                  Add Codex (GPT-5.4) adversarial review
  --codex-model <model>          Codex model (default: gpt-5.4)
  --review-interval <n>          Review every Nth iteration (default: 2)
  --max-iterations <n>           Max iterations (default: 20)
  --completion-promise '<text>'  Completion phrase (default: "SPEC COMPLETE")
  -h, --help                     Show this help

EXAMPLES:
  /sdd execute
  /sdd execute --filter v2
  /sdd execute --adversarial
  /sdd execute --adversarial --max-iterations 30
HELP_EOF
      exit 0
      ;;
    --filter)
      [[ -z "${2:-}" ]] && { echo "❌ --filter requires a pattern" >&2; exit 1; }
      FILTER="$2"
      shift 2
      ;;
    --adversarial)
      ADVERSARIAL=true
      shift
      ;;
    --codex-model)
      [[ -z "${2:-}" ]] && { echo "❌ --codex-model requires a model name" >&2; exit 1; }
      CODEX_MODEL="$2"
      shift 2
      ;;
    --review-interval)
      [[ -z "${2:-}" ]] && { echo "❌ --review-interval requires a number" >&2; exit 1; }
      REVIEW_INTERVAL="$2"
      shift 2
      ;;
    --max-iterations)
      [[ -z "${2:-}" ]] && { echo "❌ --max-iterations requires a number" >&2; exit 1; }
      [[ ! "$2" =~ ^[0-9]+$ ]] && { echo "❌ --max-iterations must be a positive integer" >&2; exit 1; }
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      [[ -z "${2:-}" ]] && { echo "❌ --completion-promise requires text" >&2; exit 1; }
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      echo "❌ Unexpected argument: $1" >&2
      exit 1
      ;;
  esac
done

# ─── Create worktree if not already in one ──────────────────────────────────

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# Detect if we're already in a worktree (sdd --monitor creates these)
IS_WORKTREE=false
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || true)"
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
if [[ -n "$GIT_COMMON_DIR" && -n "$GIT_DIR" && "$GIT_COMMON_DIR" != "$GIT_DIR" ]]; then
  IS_WORKTREE=true
fi

if [[ "$IS_WORKTREE" == "false" ]]; then
  # Clean any stale ralph-loop state from the main project dir
  # This prevents the stop hook from hijacking non-SDD conversations
  rm -f "$PROJECT_ROOT/.claude/ralph-loop.local.md"

  # Derive worktree name from filter or frontier
  WT_NAME="${FILTER:-execute}"
  WT_PATH="${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-${WT_NAME}"
  BRANCH_NAME="sdd/${WT_NAME}"

  if [[ -d "$WT_PATH" ]]; then
    echo "📂 Using existing worktree: $WT_PATH"
  else
    # Create branch if needed
    if ! git rev-parse --verify "$BRANCH_NAME" &>/dev/null; then
      git branch "$BRANCH_NAME" HEAD 2>/dev/null || true
    fi
    git worktree add "$WT_PATH" "$BRANCH_NAME" 2>/dev/null || {
      git worktree add --force "$WT_PATH" "$BRANCH_NAME" 2>/dev/null || true
    }
    echo "📂 Created worktree: $WT_PATH (branch: $BRANCH_NAME)"
  fi

  # Switch to the worktree
  cd "$WT_PATH"
  echo "📂 Working in: $(pwd)"
  echo "SDD_WORKTREE_PATH=$WT_PATH"
fi

# ─── Find frontier ──────────────────────────────────────────────────────────

FRONTIER_FILE=""
SEARCH_DIRS=()
[[ -d "context/frontiers" ]] && SEARCH_DIRS+=("context/frontiers")
[[ -d "context/plans" ]] && SEARCH_DIRS+=("context/plans")

for sdir in "${SEARCH_DIRS[@]+"${SEARCH_DIRS[@]}"}"; do
  if [[ -n "$FILTER" ]]; then
    while IFS= read -r -d '' f; do
      [[ -z "$FRONTIER_FILE" ]] && FRONTIER_FILE="$f"
    done < <(find "$sdir" -name "*${FILTER}*frontier*" -type f -print0 2>/dev/null | sort -z)
  fi
  if [[ -z "$FRONTIER_FILE" ]]; then
    while IFS= read -r -d '' f; do
      [[ -z "$FRONTIER_FILE" ]] && FRONTIER_FILE="$f"
    done < <(find "$sdir" -name "*frontier*" -type f -print0 2>/dev/null | sort -z)
  fi
done

if [[ -z "$FRONTIER_FILE" ]]; then
  echo "❌ No feature frontier found." >&2
  echo "   Run /sdd plan first to generate one." >&2
  exit 1
fi

echo "📋 Frontier: $FRONTIER_FILE"

# ─── Auto-archive previous cycle ────────────────────────────────────────────

ARCHIVE_COUNT=0
if [[ -d "context/impl" ]]; then
  HAS_OLD=false
  [[ -f "context/impl/loop-log.md" ]] && HAS_OLD=true
  for f in context/impl/impl-*.md; do
    [[ -f "$f" ]] && HAS_OLD=true && break
  done

  if [[ "$HAS_OLD" == "true" ]]; then
    ARCHIVE_DIR="context/impl/archive/$(date -u +%Y%m%d-%H%M%S)"
    mkdir -p "$ARCHIVE_DIR"

    for f in context/impl/loop-log.md context/impl/adversarial-findings.md context/adversarial-findings.md; do
      [[ -f "$f" ]] && mv "$f" "$ARCHIVE_DIR/" && ARCHIVE_COUNT=$((ARCHIVE_COUNT + 1))
    done
    for f in context/impl/impl-*.md; do
      [[ -f "$f" ]] && [[ "$(basename "$f")" != "CLAUDE.md" ]] && mv "$f" "$ARCHIVE_DIR/" && ARCHIVE_COUNT=$((ARCHIVE_COUNT + 1))
    done

    if [[ $ARCHIVE_COUNT -gt 0 ]]; then
      echo "📦 Archived $ARCHIVE_COUNT files from previous cycle → $ARCHIVE_DIR/"
    fi
  fi
fi

# Remove old ralph state
rm -f .claude/ralph-loop.local.md

# ─── Discover specs and refs ────────────────────────────────────────────────

SPEC_FILES=()
if [[ -d "context/specs" ]]; then
  while IFS= read -r -d '' f; do
    [[ "$(basename "$f")" == "CLAUDE.md" ]] && continue
    if [[ -n "$FILTER" ]] && [[ "$f" != *"$FILTER"* ]]; then continue; fi
    SPEC_FILES+=("$f")
  done < <(find context/specs -name "*.md" -type f -print0 2>/dev/null | sort -z)
fi

SPEC_LISTING=""
for f in "${SPEC_FILES[@]}"; do
  SPEC_LISTING="${SPEC_LISTING}\n- \`$f\`"
done

# ─── Configure Codex MCP if adversarial ─────────────────────────────────────

if [[ "$ADVERSARIAL" == "true" ]]; then
  MCP_FILE=".mcp.json"
  NEEDS_MCP=false

  if [[ ! -f "$MCP_FILE" ]]; then
    NEEDS_MCP=true
  elif ! python3 -c "
import json, sys
with open('$MCP_FILE') as f:
    d = json.load(f)
sys.exit(0 if 'codex-adversary' in d.get('mcpServers', {}) else 1)
" 2>/dev/null; then
    NEEDS_MCP=true
  fi

  if [[ "$NEEDS_MCP" == "true" ]]; then
    if ! command -v codex &>/dev/null; then
      echo "❌ Codex CLI not found. Install: npm install -g @openai/codex" >&2
      exit 1
    fi
    if [[ -f "$MCP_FILE" ]]; then
      python3 -c "
import json
with open('$MCP_FILE') as f:
    d = json.load(f)
d.setdefault('mcpServers', {})['codex-adversary'] = {
    'command': 'codex',
    'args': ['mcp-server', '-c', 'model=\"$CODEX_MODEL\"']
}
with open('$MCP_FILE', 'w') as f:
    json.dump(d, f, indent=2)
"
    else
      python3 -c "
import json
d = {'mcpServers': {'codex-adversary': {'command': 'codex', 'args': ['mcp-server', '-c', 'model=\"$CODEX_MODEL\"']}}}
with open('$MCP_FILE', 'w') as f:
    json.dump(d, f, indent=2)
"
    fi
    echo "📡 Configured Codex ($CODEX_MODEL) as MCP adversary"
  fi
fi

# ─── Build prompt ───────────────────────────────────────────────────────────

ADVERSARIAL_SECTION=""
if [[ "$ADVERSARIAL" == "true" ]]; then
  ADVERSARIAL_SECTION="
## Adversarial Review (every ${REVIEW_INTERVAL}th iteration)

Check the iteration number from the Ralph system message.
If iteration % $REVIEW_INTERVAL == 0, this is a REVIEW iteration:

1. Run \`git diff main...HEAD\` to get all changes
2. Call the \`codex-adversary\` MCP server with this prompt:

   > You are a senior engineer performing adversarial code review.
   > Your job is to find what the builder MISSED — not to agree.
   > SPEC REQUIREMENTS: [include relevant spec content]
   > CODE CHANGES: [include diff]
   > For each issue: Severity (CRITICAL/HIGH/MEDIUM/LOW), File, Issue, Suggestion.
   > If you find zero issues, explain what you checked and why it's correct.

3. Write findings to \`context/impl/adversarial-findings.md\`
4. Fix all CRITICAL and HIGH findings immediately
5. Mark fixed findings as FIXED

Completion requires: no CRITICAL/HIGH findings remain unfixed."
fi

RALPH_PROMPT="# SDD Execute

## Your Role
You are implementing tasks from a feature frontier. Each iteration: find the next
unblocked task, read its spec, implement it, validate, commit.

## Read These First (every iteration)
1. \`context/impl/loop-log.md\` — your iteration history (if exists)
2. \`$FRONTIER_FILE\` — the task dependency graph
3. Any \`context/impl/impl-*.md\` files — per-domain progress

## Specs (read when implementing a specific requirement)
$(echo -e "$SPEC_LISTING")
$ADVERSARIAL_SECTION
## Each Iteration

### 1. Orient
- Read loop-log.md and impl tracking to know what's done
- Read the frontier to find the lowest tier with incomplete tasks

### 2. Pick Task
- Find the next unblocked task (all blockedBy tasks are DONE)
- Among equals, pick the one that unblocks the most downstream work

### 3. Implement
- Read the task's spec requirement and acceptance criteria
- Implement it, following existing codebase patterns
- One task per iteration

### 4. Validate
1. **Build** — must compile/pass
2. **Tests** — on changed files, must pass
3. **Acceptance criteria** — each criterion from the spec must be met

If stuck 2+ attempts → document as dead end, move on.

### 5. Track
Update \`context/impl/impl-{domain}.md\` (create if missing):

\`\`\`markdown
---
created: \"{CURRENT_DATE_UTC}\"
last_edited: \"{CURRENT_DATE_UTC}\"
---
# Implementation Tracking: {domain}
| Task | Status | Notes |
|------|--------|-------|
| T-001 | DONE | what was done |
\`\`\`

Append to \`context/impl/loop-log.md\` (create if missing):

\`\`\`markdown
### Iteration N — {timestamp}
- **Task:** T-{id} — {title}
- **Tier:** {n}
- **Status:** DONE / PARTIAL / BLOCKED
- **Files:** {changed files}
- **Validation:** Build {P/F}, Tests {P/F}, Acceptance {n/n}
- **Next:** T-{id} — {next task}
\`\`\`

### 6. Commit
Descriptive message with task ID and spec requirement. Do NOT push.

### 7. Done?
All tasks across all tiers DONE + build passes + tests pass?
→ output: <promise>$COMPLETION_PROMISE</promise>

Otherwise → next iteration.

## Rules
1. NEVER output completion promise unless ALL tasks are genuinely DONE
2. ONE task per iteration
3. Stuck 2+ iterations → dead end, move on
4. Re-read frontier and tracking every iteration
5. Commit after each task"

# ─── Write Ralph Loop state ─────────────────────────────────────────────────

mkdir -p .claude

cat > .claude/ralph-loop.local.md <<EOF
---
active: true
iteration: 1
session_id: ${CLAUDE_CODE_SESSION_ID:-$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "sdd-$$-$(date +%s)")}
max_iterations: $MAX_ITERATIONS
completion_promise: "$COMPLETION_PROMISE"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$RALPH_PROMPT
EOF

# ─── Output ─────────────────────────────────────────────────────────────────

cat <<EOF
🔄 SDD Execute — Loop activated!

Frontier: $FRONTIER_FILE
Specs: ${#SPEC_FILES[@]} found
$(if [[ -n "$FILTER" ]]; then echo "Filter: $FILTER"; fi)
$(if [[ "$ADVERSARIAL" == "true" ]]; then echo "Adversary: Codex ($CODEX_MODEL) every ${REVIEW_INTERVAL} iterations"; fi)
$(if [[ $ARCHIVE_COUNT -gt 0 ]]; then echo "Archived: $ARCHIVE_COUNT files from previous cycle"; fi)
Max iterations: $MAX_ITERATIONS

Each iteration: frontier → spec → implement → validate → commit

═══════════════════════════════════════════════════════════════════════
COMPLETION: <promise>$COMPLETION_PROMISE</promise>
Only when ALL tasks are done.
═══════════════════════════════════════════════════════════════════════

$RALPH_PROMPT
EOF
