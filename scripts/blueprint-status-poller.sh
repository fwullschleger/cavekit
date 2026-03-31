#!/bin/bash

# blueprint-status-poller — Background process that updates tmux pane/window titles
# with per-frontier progress. Runs until the blueprint session is gone.

set -uo pipefail

SESSION_NAME="blueprint"
POLL_INTERVAL=5
TASK_ID_PATTERN='T-([A-Za-z0-9]+-)*[A-Za-z0-9]+'

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Wait for session to exist
for _ in {1..10}; do
  tmux has-session -t "$SESSION_NAME" 2>/dev/null && break
  sleep 1
done

tmux has-session -t "$SESSION_NAME" 2>/dev/null || exit 0

count_frontier_progress() {
  local project_dir="$1"
  local total=0 done=0

  # Find frontier file in project directory
  local frontier=""
  for f in "$project_dir"/context/sites/*site*.md; do
    [[ -f "$f" ]] && frontier="$f" && break
  done
  [[ -z "$frontier" ]] && echo "?/?" && return

  # Count total tasks
  total=$(
    grep -E "^[[:space:]]*\\|[[:space:]]*${TASK_ID_PATTERN}[[:space:]]*\\||^[[:space:]]*-[[:space:]]+${TASK_ID_PATTERN}([[:space:]]|$)" "$frontier" 2>/dev/null \
      | grep -oE "$TASK_ID_PATTERN" \
      | sort -u \
      | wc -l \
      | tr -d ' '
  )

  # Count done tasks from impl files
  local done_ids=""
  for impl in "$project_dir"/context/impl/impl-*.md; do
    [[ -f "$impl" ]] || continue
    done_ids+=$(grep -iE 'DONE' "$impl" 2>/dev/null | grep -oE "$TASK_ID_PATTERN" || true)
    done_ids+=$'\n'
  done
  done=$(echo "$done_ids" | sort -u | grep -c 'T-' 2>/dev/null || true)

  echo "${done}/${total}"
}

get_status_icon() {
  local project_dir="$1"
  local done="$2"
  local total="$3"

  if [[ "$total" -gt 0 && "$done" -ge "$total" ]]; then
    echo "■"
    return
  fi

  if [[ -f "$project_dir/.claude/ralph-loop.local.md" ]]; then
    echo "⟳"
  else
    echo "○"
  fi
}

while tmux has-session -t "$SESSION_NAME" 2>/dev/null; do
  # Build status string for tmux status bar
  progress=$(count_frontier_progress "$PROJECT_ROOT")
  done_count="${progress%/*}"
  total_count="${progress#*/}"
  icon=$(get_status_icon "$PROJECT_ROOT" "$done_count" "$total_count")
  STATUS_LINE="${icon} ${progress}"

  tmux set-option -t "$SESSION_NAME" status-right "$STATUS_LINE " 2>/dev/null || true
  tmux set-option -t "$SESSION_NAME" status-right-length 120 2>/dev/null || true

  sleep "$POLL_INTERVAL"
done
