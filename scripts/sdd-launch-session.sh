#!/bin/bash

# sdd-launch-session — Creates a tmux session with one pane per frontier.
# Each pane runs Claude in its own git worktree with /sdd:execute.
#
# Usage: sdd-launch-session.sh [--expanded] <frontier-path> [<frontier-path> ...]
#
# Default: all panes in one window (horizontal for 2-3, tiled for 4+)
# --expanded: one window per frontier with progress+activity dashboard panes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_NAME="sdd"
EXPANDED=false
STAGGER_DELAY=5

# ─── Parse args ───────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--expanded" ]]; then
  EXPANDED=true
  shift
fi

FRONTIERS=("$@")

if [[ ${#FRONTIERS[@]} -eq 0 ]]; then
  echo "Usage: sdd-launch-session.sh [--expanded] <frontier-path> ..." >&2
  exit 1
fi

# ─── Preflight ────────────────────────────────────────────────────────────────

command -v tmux &>/dev/null || { echo "tmux not found. Install: brew install tmux" >&2; exit 1; }
command -v claude &>/dev/null || { echo "claude not found." >&2; exit 1; }

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# Kill existing session if running
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Existing '$SESSION_NAME' session found. Killing it..."
  tmux kill-session -t "$SESSION_NAME"
fi

# ─── Derive frontier names ───────────────────────────────────────────────────

derive_name() {
  basename "$1" .md | sed -E 's/^(plan-|feature-frontier-|feature-)//' | sed 's/-frontier$//'
}

# ─── Create worktrees ────────────────────────────────────────────────────────

WORKTREES=()
NAMES=()
RESUMING=()  # "true" or "false" per frontier

for frontier in "${FRONTIERS[@]}"; do
  name=$(derive_name "$frontier")
  NAMES+=("$name")
  worktree_path="${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-${name}"
  branch_name="sdd/${name}"

  if [[ -d "$worktree_path" ]]; then
    echo "  Worktree exists: $worktree_path"
    # Check if this is a resumable session (has ralph-loop state or impl progress)
    if [[ -f "$worktree_path/.claude/ralph-loop.local.md" ]] || \
       ls "$worktree_path/context/impl/impl-"*.md &>/dev/null 2>&1; then
      RESUMING+=("true")
      echo "    → Will resume existing session"
    else
      RESUMING+=("false")
    fi
  else
    # Create branch if it doesn't exist
    if ! git rev-parse --verify "$branch_name" &>/dev/null; then
      git branch "$branch_name" HEAD 2>/dev/null || true
    fi
    git worktree add "$worktree_path" "$branch_name" 2>/dev/null || {
      echo "  Failed to create worktree for $name, using existing branch" >&2
      git worktree add --force "$worktree_path" "$branch_name" 2>/dev/null || true
    }
    echo "  Created worktree: $worktree_path (branch: $branch_name)"
    RESUMING+=("false")
  fi

  WORKTREES+=("$worktree_path")
done

# ─── Resolve frontier file path relative to worktree ─────────────────────────

resolve_frontier_in_worktree() {
  local original_path="$1"
  local worktree="$2"
  # The frontier path is relative to project root — just swap the prefix
  local rel_path="${original_path#$PROJECT_ROOT/}"
  echo "${worktree}/${rel_path}"
}

# ─── Write launcher script for each pane ─────────────────────────────────────

write_launcher() {
  local worktree="$1"
  local frontier_path="$2"
  local name="$3"
  local resuming="$4"
  local launcher
  launcher=$(mktemp /tmp/sdd-launch-${name}-XXXXXX.sh)

  local frontier_basename
  frontier_basename=$(basename "$frontier_path")

  local claude_cmd="claude"
  local mode_label="NEW"
  if [[ "$resuming" == "true" ]]; then
    claude_cmd="claude --resume"
    mode_label="RESUME"
  fi

  cat > "$launcher" <<LAUNCHER_EOF
#!/bin/bash
rm -f "$launcher"
cd "$worktree"
echo "SDD Agent: $name [$mode_label]"
echo "Worktree: $worktree"
echo "Frontier: $frontier_basename"
echo ""
$claude_cmd
LAUNCHER_EOF
  chmod +x "$launcher"
  echo "$launcher"
}

# ─── Build tmux session ─────────────────────────────────────────────────────

if [[ "$EXPANDED" == "true" ]]; then
  # ── Expanded mode: one window per frontier with 3-pane layout ──

  FIRST=true
  WIN_IDX=0

  for i in "${!FRONTIERS[@]}"; do
    name="${NAMES[$i]}"
    worktree="${WORKTREES[$i]}"
    frontier="${FRONTIERS[$i]}"
    wt_frontier=$(resolve_frontier_in_worktree "$frontier" "$worktree")
    launcher=$(write_launcher "$worktree" "$wt_frontier" "$name" "${RESUMING[$i]}")

    if [[ "$FIRST" == "true" ]]; then
      # Create session with first window
      tmux new-session -d -s "$SESSION_NAME" -n "$name" -c "$worktree" \
        "bash $launcher; exec bash"
      FIRST=false
    else
      # Add new window
      tmux new-window -t "$SESSION_NAME" -n "$name" -c "$worktree" \
        "bash $launcher; exec bash"
    fi

    # Add dashboard panes (right side)
    RIGHT_WIDTH=$(( $(tmux display-message -t "$SESSION_NAME:${WIN_IDX}" -p '#{window_width}') * 30 / 100 ))
    [[ "$RIGHT_WIDTH" -lt 35 ]] && RIGHT_WIDTH=35

    tmux split-window -h -t "$SESSION_NAME:${WIN_IDX}" -l "$RIGHT_WIDTH" -c "$worktree" \
      "exec bash \"$SCRIPT_DIR/dashboard-progress.sh\""
    tmux select-pane -T "sdd-progress"

    tmux split-window -v -t "$SESSION_NAME:${WIN_IDX}" -c "$worktree" \
      "exec bash \"$SCRIPT_DIR/dashboard-activity.sh\""
    tmux select-pane -T "sdd-activity"

    # Focus main pane
    tmux select-pane -t "$SESSION_NAME:${WIN_IDX}.0"

    WIN_IDX=$((WIN_IDX + 1))
  done

  # Select first window
  tmux select-window -t "$SESSION_NAME:0"

else
  # ── Default mode: all panes in one window ──

  FIRST=true
  PANE_IDX=0

  for i in "${!FRONTIERS[@]}"; do
    name="${NAMES[$i]}"
    worktree="${WORKTREES[$i]}"
    frontier="${FRONTIERS[$i]}"
    wt_frontier=$(resolve_frontier_in_worktree "$frontier" "$worktree")
    launcher=$(write_launcher "$worktree" "$wt_frontier" "$name" "${RESUMING[$i]}")

    if [[ "$FIRST" == "true" ]]; then
      tmux new-session -d -s "$SESSION_NAME" -n "sdd-agents" -c "$worktree" \
        "bash $launcher; exec bash"
      FIRST=false
    else
      # Split from the first pane to add more
      tmux split-window -t "$SESSION_NAME:0" -c "$worktree" \
        "bash $launcher; exec bash"
    fi

    PANE_IDX=$((PANE_IDX + 1))
  done

  # Apply layout based on pane count
  if [[ $PANE_IDX -le 3 ]]; then
    tmux select-layout -t "$SESSION_NAME:0" even-horizontal
  else
    tmux select-layout -t "$SESSION_NAME:0" tiled
  fi

  # Select first pane
  tmux select-pane -t "$SESSION_NAME:0.0"
fi

# ─── Staggered /sdd:execute launch ──────────────────────────────────────────

# Background process that sends /sdd:execute to NEW panes (resumed ones already have context)
(
  sleep 3  # Wait for Claude instances to start

  for i in "${!NAMES[@]}"; do
    name="${NAMES[$i]}"

    # Resumed sessions already have their loop — skip sending /sdd:execute
    if [[ "${RESUMING[$i]}" == "true" ]]; then
      continue
    fi

    if [[ "$EXPANDED" == "true" ]]; then
      target="$SESSION_NAME:${i}.0"
    else
      target="$SESSION_NAME:0.${i}"
    fi

    tmux send-keys -t "$target" "/sdd:execute --filter ${name}" Enter

    # Stagger between launches (skip delay after last one)
    sleep "$STAGGER_DELAY"
  done
) &

# ─── Start status poller ────────────────────────────────────────────────────

if [[ -x "$SCRIPT_DIR/sdd-status-poller.sh" ]]; then
  "$SCRIPT_DIR/sdd-status-poller.sh" &
fi

# ─── Enable mouse mode ───────────────────────────────────────────────────────

tmux set-option -t "$SESSION_NAME" mouse on 2>/dev/null || true

# ─── Report & attach ────────────────────────────────────────────────────────

echo ""
echo "Launched ${#FRONTIERS[@]} SDD agents:"
for i in "${!NAMES[@]}"; do
  echo "  ${NAMES[$i]} → ${WORKTREES[$i]}"
done
echo ""
echo "Attaching to tmux session '$SESSION_NAME'..."
echo "  Switch panes: Ctrl-b + arrow keys"
if [[ "$EXPANDED" == "true" ]]; then
  echo "  Switch windows: Ctrl-b + number"
fi
echo "  Detach: Ctrl-b d"
echo "  Kill all: sdd --kill"
echo ""

exec tmux attach-session -t "$SESSION_NAME"
