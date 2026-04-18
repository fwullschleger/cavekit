#!/usr/bin/env bash
# stop-hook.sh — Cavekit autonomous loop driver.
#
# Fires on Claude Code's Stop event. If a Cavekit loop is active
# (.cavekit/.loop.json exists), this hook routes the next prompt
# and blocks exit to drive iterative execution until the session
# emits <promise>CAVEKIT COMPLETE</promise> or a budget is hit.
#
# Contract (from Claude Code hook protocol):
#   stdin:  JSON { session_id, transcript_path, ... }
#   stdout: JSON { decision: "block", reason: "<next prompt>" } to continue
#           or no output to let the session stop normally.

set -u
set -o pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${CAVEKIT_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CAVEKIT_DIR="${PROJECT_ROOT}/.cavekit"
LOOP_FILE="${CAVEKIT_DIR}/.loop.json"
LOCK_FILE="${CAVEKIT_DIR}/.loop.lock"
DEBUG_LOG="${CAVEKIT_DIR}/.debug.log"
BACKPROP_FLAG="${CAVEKIT_DIR}/.auto-backprop-pending.json"

log_debug() {
  if [[ -n "${CAVEKIT_DEBUG:-}" ]]; then
    mkdir -p "$CAVEKIT_DIR" 2>/dev/null || true
    printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$DEBUG_LOG" 2>/dev/null || true
  fi
}

emit_json() {
  # $1 = JSON payload to stdout. Claude Code consumes this and blocks.
  printf '%s\n' "$1"
}

exit_silent() {
  log_debug "exit_silent: $*"
  exit 0
}

# No loop active — nothing to do.
if [[ ! -f "$LOOP_FILE" ]]; then
  exit_silent "no loop file"
fi

# Read stdin (session context from Claude Code)
STDIN_PAYLOAD="$(cat)"
SESSION_ID="$(printf '%s' "$STDIN_PAYLOAD" | node -e 'let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{try{const j=JSON.parse(d);process.stdout.write(j.session_id||"")}catch(e){process.stdout.write("")}})' 2>/dev/null || echo "")"
TRANSCRIPT_PATH="$(printf '%s' "$STDIN_PAYLOAD" | node -e 'let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{try{const j=JSON.parse(d);process.stdout.write(j.transcript_path||"")}catch(e){process.stdout.write("")}})' 2>/dev/null || echo "")"

log_debug "stop-hook session=$SESSION_ID transcript=$TRANSCRIPT_PATH"

# Lock management — single writer per loop.
LOCK_OWNER_TAG="session:${SESSION_ID:-unknown}"
if ! node "${PLUGIN_ROOT}/scripts/cavekit-tools.cjs" heartbeat \
        --cavekit-dir "$CAVEKIT_DIR" \
        --owner "$LOCK_OWNER_TAG" >/dev/null 2>&1; then
  log_debug "lock conflict — another session owns the loop"
  emit_json '{"decision":"block","reason":"[cavekit] Another session owns the loop. Run `/ck:resume` after the other session ends, or delete `.cavekit/.loop.lock` if it is stale."}'
  exit 0
fi

# Check for completion sentinel in recent transcript.
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  if tail -n 20 "$TRANSCRIPT_PATH" 2>/dev/null | grep -qF '<promise>CAVEKIT COMPLETE</promise>'; then
    log_debug "completion sentinel found — tearing down loop"
    node "${PLUGIN_ROOT}/scripts/cavekit-tools.cjs" teardown-loop \
      --cavekit-dir "$CAVEKIT_DIR" >/dev/null 2>&1 || true
    exit_silent "completion sentinel"
  fi
fi

# Ask the router for the next prompt.
NEXT_PROMPT="$(node "${PLUGIN_ROOT}/scripts/cavekit-tools.cjs" route \
                --cavekit-dir "$CAVEKIT_DIR" \
                --transcript "${TRANSCRIPT_PATH:-/dev/null}" 2>/dev/null || echo "")"

if [[ -z "$NEXT_PROMPT" ]]; then
  log_debug "router returned empty — letting session stop"
  exit_silent "no next prompt"
fi

# Terminal phases — router may return a sentinel string instead of a prompt.
case "$NEXT_PROMPT" in
  CAVEKIT_BUDGET_EXHAUSTED*)
    REASON="[cavekit] Session budget exhausted. Run \`/ck:check\` to review progress, or raise \`session_budget\` in \`.cavekit/config\`."
    emit_json "{\"decision\":\"block\",\"reason\":$(printf '%s' "$REASON" | node -e 'let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>process.stdout.write(JSON.stringify(d)))')}"
    exit 0
    ;;
  CAVEKIT_MAX_ITERATIONS*)
    REASON="[cavekit] Reached max iterations. Loop halted. Review \`.cavekit/state.md\` and resume with \`/ck:resume\` when ready."
    emit_json "{\"decision\":\"block\",\"reason\":$(printf '%s' "$REASON" | node -e 'let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>process.stdout.write(JSON.stringify(d)))')}"
    exit 0
    ;;
  CAVEKIT_LOOP_DONE*)
    log_debug "router reports loop done"
    exit_silent "router done"
    ;;
esac

# Prepend auto-backprop directive if a test failure flag is pending.
if [[ -f "$BACKPROP_FLAG" ]]; then
  log_debug "auto-backprop flag present — prepending directive"
  BACKPROP_NOTE="$(node "${PLUGIN_ROOT}/scripts/cavekit-tools.cjs" backprop-directive \
                    --cavekit-dir "$CAVEKIT_DIR" 2>/dev/null || echo "")"
  if [[ -n "$BACKPROP_NOTE" ]]; then
    NEXT_PROMPT="${BACKPROP_NOTE}

${NEXT_PROMPT}"
    rm -f "$BACKPROP_FLAG" 2>/dev/null || true
  fi
fi

# Status block (ASCII dashboard, injected once per iteration).
STATUS_BLOCK="$(node "${PLUGIN_ROOT}/scripts/cavekit-tools.cjs" status-block \
                --cavekit-dir "$CAVEKIT_DIR" 2>/dev/null || echo "")"

FULL_REASON="${STATUS_BLOCK}

${NEXT_PROMPT}"

# Emit JSON blocking decision.
printf '%s' "$FULL_REASON" | node -e '
let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{
  process.stdout.write(JSON.stringify({decision:"block",reason:d}));
});
'

exit 0
