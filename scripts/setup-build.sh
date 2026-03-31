#!/bin/bash

# Blueprint Build Setup Script
# Archives old cycle, reads build site, starts Ralph Loop.
# Optionally configures Codex MCP for peer review.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FILTER=""
PEER_REVIEW=false
MAX_ITERATIONS=20
COMPLETION_PROMISE="BLUEPRINT COMPLETE"
CODEX_MODEL="gpt-5.4"
REVIEW_INTERVAL=2

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Blueprint Build — Run the implementation loop

USAGE:
  /blueprint build [OPTIONS]

OPTIONS:
  --filter <pattern>             Scope to blueprints/build site matching pattern
  --peer-review                  Add Codex (GPT-5.4) peer review
  --codex-model <model>          Codex model (default: gpt-5.4)
  --review-interval <n>          Review every Nth iteration (default: 2)
  --max-iterations <n>           Max iterations (default: 20)
  --completion-promise '<text>'  Completion phrase (default: "BLUEPRINT COMPLETE")
  -h, --help                     Show this help

EXAMPLES:
  /blueprint build
  /blueprint build --filter v2
  /blueprint build --peer-review
  /blueprint build --peer-review --max-iterations 30
HELP_EOF
      exit 0
      ;;
    --filter)
      [[ -z "${2:-}" ]] && { echo "❌ --filter requires a pattern" >&2; exit 1; }
      FILTER="$2"
      shift 2
      ;;
    --peer-review)
      PEER_REVIEW=true
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

# ─── Clean stale state ──────────────────────────────────────────────────────

rm -f .claude/ralph-loop.local.md

# ─── Find build site ────────────────────────────────────────────────────────
#
# Strategy:
#   1. Only search context/sites/ (not context/plans/ — false positives)
#   2. Exclude archive/ subdirectory (completed builds)
#   3. If --filter is set, match filter anywhere in filename
#   4. If multiple candidates, list them for user selection
#   5. If exactly one, auto-select it

FRONTIER_FILE=""
ALL_CANDIDATES=()

if [[ -d "context/sites" ]]; then
  while IFS= read -r -d '' f; do
    # Skip archive directory
    [[ "$f" == *"/archive/"* ]] && continue
    # Skip non-site files (must have "site" in name)
    [[ "$(basename "$f")" != *site* ]] && continue
    ALL_CANDIDATES+=("$f")
  done < <(find "context/sites" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null | sort -z)
fi

# Apply filter if set — match filter anywhere in filename
CANDIDATES=()
if [[ ${#ALL_CANDIDATES[@]} -gt 0 ]]; then
  if [[ -n "$FILTER" ]]; then
    for f in "${ALL_CANDIDATES[@]}"; do
      bn="$(basename "$f")"
      if [[ "$bn" == *"$FILTER"* ]]; then
        CANDIDATES+=("$f")
      fi
    done
    # If filter matched nothing, fall back to all candidates
    if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
      echo "⚠️  Filter '$FILTER' matched no build sites, searching all" >&2
      CANDIDATES=("${ALL_CANDIDATES[@]}")
    fi
  else
    CANDIDATES=("${ALL_CANDIDATES[@]}")
  fi
fi

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "❌ No build site found in context/sites/" >&2
  echo "   Run /bp:architect first to generate one." >&2
  if [[ -d "context/plans" ]] && find "context/plans" -name "*site*" -type f 2>/dev/null | grep -q .; then
    echo "   (Found frontier files in context/plans/ — move them to context/sites/)" >&2
  fi
  exit 1
fi

# If exactly one candidate, use it directly
if [[ ${#CANDIDATES[@]} -eq 1 ]]; then
  FRONTIER_FILE="${CANDIDATES[0]}"
else
  # Multiple candidates — list them with task counts for user selection
  echo ""
  echo "📋 Multiple build sites found:"
  echo ""
  IDX=1
  for f in "${CANDIDATES[@]}"; do
    task_count=$(grep -cE '\|\s*T-([A-Za-z0-9]+-)*[0-9]+\s*\|' "$f" 2>/dev/null || echo "?")
    done_count=0
    if [[ -d "context/impl" ]]; then
      for task_id in $(grep -oE 'T-([A-Za-z0-9]+-)*[0-9]+' "$f" 2>/dev/null | sort -u); do
        if grep -rlq "$task_id.*DONE\|DONE.*$task_id" context/impl/ 2>/dev/null; then
          done_count=$((done_count + 1))
        fi
      done
    fi
    echo "  ${IDX}. $(basename "$f") — ${done_count}/${task_count} tasks done"
    IDX=$((IDX + 1))
  done
  echo ""
  echo "BLUEPRINT_SITE_SELECTION_REQUIRED=true"
  echo "BLUEPRINT_SITE_CANDIDATES=${CANDIDATES[*]}"
  exit 0
fi

echo "📋 Build site: $FRONTIER_FILE"

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

    for f in context/impl/loop-log.md context/impl/peer-review-findings.md context/peer-review-findings.md; do
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

# ─── Discover specs and refs ────────────────────────────────────────────────

SPEC_FILES=()
if [[ -d "context/blueprints" ]]; then
  while IFS= read -r -d '' f; do
    [[ "$(basename "$f")" == "CLAUDE.md" ]] && continue
    if [[ -n "$FILTER" ]] && [[ "$f" != *"$FILTER"* ]]; then continue; fi
    SPEC_FILES+=("$f")
  done < <(find context/blueprints -name "*.md" -type f -print0 2>/dev/null | sort -z)
fi

SPEC_LISTING=""
for f in "${SPEC_FILES[@]+"${SPEC_FILES[@]}"}"; do
  SPEC_LISTING="${SPEC_LISTING}\n- \`$f\`"
done

# ─── Configure Codex peer review ────────────────────────────────────────────
# Primary path: Codex CLI delegation via codex-review.sh (no MCP overhead).
# Legacy fallback: Codex as MCP server when CLI delegation is unavailable.

CODEX_CLI_REVIEW=false

if [[ ""$PEER_REVIEW"" == "true" ]]; then
  # Try primary path: source codex-review.sh for bp_codex_review function
  if [[ -f "$SCRIPT_DIR/codex-review.sh" ]]; then
    source "$SCRIPT_DIR/codex-review.sh"
    if [[ "${codex_available:-false}" == "true" ]]; then
      CODEX_CLI_REVIEW=true
      echo "📡 Codex CLI review enabled (model: $(bp_config_get codex_model o4-mini))"
    fi
  fi

  # Legacy fallback: configure Codex as MCP server
  if [[ "$CODEX_CLI_REVIEW" == "false" ]]; then
    MCP_FILE=".mcp.json"
    NEEDS_MCP=false

    if [[ ! -f "$MCP_FILE" ]]; then
      NEEDS_MCP=true
    elif ! python3 -c "
import json, sys
with open('$MCP_FILE') as f:
    d = json.load(f)
sys.exit(0 if 'codex-reviewer' in d.get('mcpServers', {}) else 1)
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
d.setdefault('mcpServers', {})['codex-reviewer'] = {
    'command': 'codex',
    'args': ['mcp-server', '-c', 'model=\"$CODEX_MODEL\"']
}
with open('$MCP_FILE', 'w') as f:
    json.dump(d, f, indent=2)
"
      else
        python3 -c "
import json
d = {'mcpServers': {'codex-reviewer': {'command': 'codex', 'args': ['mcp-server', '-c', 'model=\"$CODEX_MODEL\"']}}}
with open('$MCP_FILE', 'w') as f:
    json.dump(d, f, indent=2)
"
      fi
      echo "📡 Configured Codex ($CODEX_MODEL) as MCP peer reviewer (legacy fallback)"
    fi
  fi
fi

# ─── Build prompt ───────────────────────────────────────────────────────────

PEER_REVIEW_SECTION=""
if [[ ""$PEER_REVIEW"" == "true" ]]; then
  if [[ "$CODEX_CLI_REVIEW" == "true" ]]; then
    PEER_REVIEW_SECTION="
## Peer Review (every ${REVIEW_INTERVAL}th iteration)

Check the iteration number from the Ralph system message.
If iteration % $REVIEW_INTERVAL == 0, this is a REVIEW iteration:

1. Run the Codex CLI review:
   \`\`\`bash
   source scripts/codex-review.sh && bp_codex_review --base main
   \`\`\`
   This sends the diff to Codex for adversarial review and writes parsed findings
   to \`context/impl/impl-review-findings.md\` automatically.

2. Read the findings output and fix all P0 (critical) and P1 (high) findings immediately
3. Mark fixed findings as FIXED in the findings file

Completion requires: no P0/P1 findings remain unfixed."
  else
    PEER_REVIEW_SECTION="
## Peer Review (every ${REVIEW_INTERVAL}th iteration) — MCP Legacy

Check the iteration number from the Ralph system message.
If iteration % $REVIEW_INTERVAL == 0, this is a REVIEW iteration:

1. Run \`git diff main...HEAD\` to get all changes
2. Call the \`codex-reviewer\` MCP server with this prompt:

   > You are a senior engineer performing peer review code review.
   > Your job is to find what the builder MISSED — not to agree.
   > SPEC REQUIREMENTS: [include relevant spec content]
   > CODE CHANGES: [include diff]
   > For each issue: Severity (CRITICAL/HIGH/MEDIUM/LOW), File, Issue, Suggestion.
   > If you find zero issues, explain what you checked and why it's correct.

3. Write findings to \`context/impl/peer-review-findings.md\`
4. Fix all CRITICAL and HIGH findings immediately
5. Mark fixed findings as FIXED

Completion requires: no CRITICAL/HIGH findings remain unfixed."
  fi
fi

RALPH_PROMPT="# Blueprint Build

## Your Role
You are implementing tasks from a build site. Each iteration: find the next
unblocked task, read its blueprint, implement it, validate, commit.

## Read These First (every iteration)
1. \`context/impl/loop-log.md\` — your iteration history (if exists)
2. \`$FRONTIER_FILE\` — the task dependency graph
3. Any \`context/impl/impl-*.md\` files — per-domain progress

## Blueprints (read when implementing a specific requirement)
$(echo -e "$SPEC_LISTING")
"$PEER_REVIEW"_SECTION
## Each Iteration

### 1. Orient
- Read loop-log.md and impl tracking to know what's done
- Read the build site to find the lowest tier with incomplete tasks

### 2. Pick Task
- Find the next unblocked task (all blockedBy tasks are DONE)
- Among equals, pick the one that unblocks the most downstream work

### 3. Implement
- Read the task's blueprint requirement and acceptance criteria
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
Descriptive message with task ID and blueprint requirement. Do NOT push.

### 7. Done?
All tasks across all tiers DONE + build passes + tests pass?
→ output: <promise>$COMPLETION_PROMISE</promise>

Otherwise → next iteration.

## CRITICAL: Do NOT falsely mark tasks as DONE

**NEVER mark a task DONE because 'existing code already handles this'.**
A task is DONE only when you have:
1. Written or modified code specifically for this task's acceptance criteria
2. Verified EACH acceptance criterion individually (not 'it looks like it works')
3. Written or run tests that prove the criteria are met

If existing code partially covers a requirement, implement the MISSING parts.
If it fully covers every criterion, write a test proving it and document exactly
which existing code satisfies which criterion — with file paths and line numbers.

## Rules
1. NEVER output completion promise unless ALL tasks are genuinely DONE
2. ONE task per iteration
3. Stuck 2+ iterations → dead end, move on
4. Re-read build site and tracking every iteration
5. Commit after each task
6. NEVER skip implementation because code 'looks related'"

# ─── Write Ralph Loop state ─────────────────────────────────────────────────

mkdir -p .claude

cat > .claude/ralph-loop.local.md <<EOF
---
active: true
iteration: 1
session_id: ${CLAUDE_CODE_SESSION_ID:-$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "blueprint-$$-$(date +%s)")}
max_iterations: $MAX_ITERATIONS
completion_promise: "$COMPLETION_PROMISE"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$RALPH_PROMPT
EOF

# ─── Output ─────────────────────────────────────────────────────────────────

cat <<EOF
🔄 Blueprint Build — Loop activated!

Build site: $FRONTIER_FILE
Specs: ${#SPEC_FILES[@]} found
$(if [[ -n "$FILTER" ]]; then echo "Filter: $FILTER"; fi)
$(if [[ ""$PEER_REVIEW"" == "true" ]]; then echo "Peer reviewer: Codex ($CODEX_MODEL) every ${REVIEW_INTERVAL} iterations"; fi)
$(if [[ $ARCHIVE_COUNT -gt 0 ]]; then echo "Archived: $ARCHIVE_COUNT files from previous cycle"; fi)
Max iterations: $MAX_ITERATIONS

Each iteration: build site → blueprint → implement → validate → commit

═══════════════════════════════════════════════════════════════════════
COMPLETION: <promise>$COMPLETION_PROMISE</promise>
Only when ALL tasks are done.
═══════════════════════════════════════════════════════════════════════

$RALPH_PROMPT
EOF
