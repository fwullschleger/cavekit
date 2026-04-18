#!/usr/bin/env bash
# token-monitor.sh — per-task token budget enforcement.
#
# PostToolUse hook. Estimates tokens consumed by this tool call
# (rough payload_length / 4 heuristic), records them against the
# current task in .cavekit/token-ledger.json, warns at 80% of the
# task budget, and marks the state phase `budget_exhausted` at 100%.

set -u
set -o pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CAVEKIT_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CAVEKIT_DIR="${PROJECT_ROOT}/.cavekit"
STATE_FILE="${CAVEKIT_DIR}/state.md"

# Only run if a loop is active.
[[ -f "${CAVEKIT_DIR}/.loop.json" ]] || exit 0
[[ -f "$STATE_FILE" ]] || exit 0

PAYLOAD="$(cat)"
PAYLOAD_LEN=${#PAYLOAD}
EST_TOKENS=$(( PAYLOAD_LEN / 4 ))

# Cheap YAML frontmatter read — first 25 lines only, no jq required.
CURRENT_TASK="$(sed -n '1,25p' "$STATE_FILE" | grep -E '^current_task:' | head -1 | awk -F': *' '{print $2}' | tr -d '"' | tr -d "'" )"

if [[ -z "${CURRENT_TASK:-}" || "$CURRENT_TASK" == "null" || "$CURRENT_TASK" == "none" ]]; then
  exit 0
fi

RESULT="$(node "${PLUGIN_ROOT}/scripts/cavekit-tools.cjs" record-task-tokens \
            --cavekit-dir "$CAVEKIT_DIR" \
            --task "$CURRENT_TASK" \
            --delta "$EST_TOKENS" 2>/dev/null || echo "")"

# Result format: "used/budget status" — status ∈ {ok, warn, exhausted}
case "$RESULT" in
  *" exhausted")
    printf '[cavekit] Task %s token budget exhausted (%s). Phase set to budget_exhausted.\n' \
      "$CURRENT_TASK" "${RESULT% *}" >&2
    ;;
  *" warn")
    printf '[cavekit] Task %s at 80%% of token budget (%s).\n' \
      "$CURRENT_TASK" "${RESULT% *}" >&2
    ;;
esac

exit 0
