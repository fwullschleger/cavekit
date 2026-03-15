#!/bin/bash

# sdd-status-poller — Background process that updates tmux pane/window titles
# with per-frontier progress. Runs until the sdd session is gone.

set -uo pipefail

SESSION_NAME="sdd"
POLL_INTERVAL=5

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# Wait for session to exist
for _ in {1..10}; do
  tmux has-session -t "$SESSION_NAME" 2>/dev/null && break
  sleep 1
done

tmux has-session -t "$SESSION_NAME" 2>/dev/null || exit 0

count_frontier_progress() {
  local worktree="$1"
  local total=0 done=0

  # Find frontier file in worktree
  local frontier=""
  for f in "$worktree"/context/frontiers/*frontier*.md; do
    [[ -f "$f" ]] && frontier="$f" && break
  done
  [[ -z "$frontier" ]] && echo "?/?" && return

  # Count total tasks
  total=$(grep -cE '^\s*\|\s*T-[0-9]+' "$frontier" 2>/dev/null || echo 0)

  # Count done tasks from impl files
  local done_ids=""
  for impl in "$worktree"/context/impl/impl-*.md; do
    [[ -f "$impl" ]] || continue
    done_ids+=$(grep -iE 'T-[0-9]+.*DONE' "$impl" 2>/dev/null | grep -oE 'T-[0-9]+' || true)
    done_ids+=$'\n'
  done
  done=$(echo "$done_ids" | sort -u | grep -c 'T-' 2>/dev/null || echo 0)

  echo "${done}/${total}"
}

get_status_icon() {
  local worktree="$1"
  local done="$2"
  local total="$3"

  if [[ "$total" -gt 0 && "$done" -ge "$total" ]]; then
    echo "✓"
    return
  fi

  if [[ -f "$worktree/.claude/ralph-loop.local.md" ]]; then
    echo "⟳"
  else
    echo "·"
  fi
}

while tmux has-session -t "$SESSION_NAME" 2>/dev/null; do
  # Build status string for tmux status bar
  STATUS_PARTS=()

  # Find all sdd worktrees
  for wt in "${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-"*; do
    [[ -d "$wt" ]] || continue
    name=$(basename "$wt" | sed "s/^${PROJECT_NAME}-sdd-//")
    progress=$(count_frontier_progress "$wt")
    done_count="${progress%/*}"
    total_count="${progress#*/}"
    icon=$(get_status_icon "$wt" "$done_count" "$total_count")
    STATUS_PARTS+=("${icon} ${name} ${progress}")
  done

  if [[ ${#STATUS_PARTS[@]} -gt 0 ]]; then
    STATUS_LINE="${STATUS_PARTS[*]}"
    # Pad separators
    STATUS_LINE=$(printf '%s' "${STATUS_PARTS[@]/#/  │  }" | sed 's/^  │  //')
    tmux set-option -t "$SESSION_NAME" status-right "$STATUS_LINE " 2>/dev/null || true
    tmux set-option -t "$SESSION_NAME" status-right-length 120 2>/dev/null || true
  fi

  sleep "$POLL_INTERVAL"
done
