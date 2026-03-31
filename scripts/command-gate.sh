#!/usr/bin/env bash
# command-gate.sh — Command Safety Gate
# PreToolUse hook that classifies Bash command safety via static rules + Codex.
#
# T-101: PreToolUse hook scaffold
# T-102: Built-in allowlist and blocklist
# T-103: Configuration schema and defaults
# T-104: Fast-path classifier
# T-105: Claude permission integration
# T-106: Command normalizer
# T-107: Codex safety classification
# T-108: Pattern-based verdict cache
# T-109: Graceful degradation
# T-110: User-extensible config
#
# Source this file to get bp_command_gate_* functions.
# Execute directly as a PreToolUse hook (reads JSON from stdin).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ -f "$SCRIPT_DIR/codex-detect.sh" ]]; then
  source "$SCRIPT_DIR/codex-detect.sh"
else
  codex_available=false
fi

if [[ -f "$SCRIPT_DIR/codex-config.sh" ]]; then
  source "$SCRIPT_DIR/codex-config.sh"
else
  bp_config_get() { echo "${2:-}"; }
fi

# Guard against double-sourcing
[[ -n "${_BP_COMMAND_GATE_LOADED:-}" ]] && { return 0 2>/dev/null || true; }
_BP_COMMAND_GATE_LOADED=1

# ── T-103: Configuration Schema and Defaults ──────────────────────────

bp_gate_config_get() {
  local key="$1"
  case "$key" in
    command_gate)
      bp_config_get command_gate "all"
      ;;
    command_gate_model)
      bp_config_get command_gate_model "o4-mini"
      ;;
    command_gate_timeout)
      bp_config_get command_gate_timeout "3000"
      ;;
    command_gate_allowlist)
      bp_config_get command_gate_allowlist ""
      ;;
    command_gate_blocklist)
      bp_config_get command_gate_blocklist ""
      ;;
    *)
      bp_config_get "$@"
      ;;
  esac
}

# ── T-102: Built-in Allowlist and Blocklist ───────────────────────────

# Allowlist: base executables that are always safe (read-only, standard build)
_BP_GATE_ALLOWLIST_EXECUTABLES=(
  ls cat head tail less more wc file stat du df
  pwd whoami id uname hostname date
  echo printf true false
  grep rg ag ack find fd locate which where type
  git  # git itself is safe; dangerous subcommands checked separately
  node npm npx yarn pnpm bun deno tsx ts-node
  python python3 pip pip3 uv
  go cargo rustc rustup
  make cmake
  docker  # base docker safe; dangerous subcommands checked separately
  kubectl helm
  jq yq sed awk sort uniq tr cut paste
  curl wget  # safe for reads; piping to shell checked separately
  ssh scp
  tar gzip gunzip zip unzip
  diff patch
  test "[" "[["
  tput clear reset
  codex
)

# Allowlist: git subcommands that are always safe
_BP_GATE_ALLOWLIST_GIT=(
  status log diff show branch tag remote stash
  fetch pull  # pull can merge but is standard workflow
  add commit  # staging and committing is normal workflow
  checkout switch  # switching branches is normal
  rebase merge  # can be destructive but standard workflow
  cherry-pick
  bisect blame annotate shortlog describe
  ls-files ls-tree rev-parse rev-list name-rev
  config  # reading config
)

# Blocklist: patterns that are always dangerous
# Format: regex patterns matched against the full command
_BP_GATE_BLOCKLIST_PATTERNS=(
  'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\b.*--force|-[a-zA-Z]*f[a-zA-Z]*r)\b.*(/|\*|\.\.|~)'  # rm -rf with broad paths
  'git\s+push\s+.*--force\b.*\b(main|master)\b'  # force push to main
  'git\s+push\s+.*-f\b.*\b(main|master)\b'
  'git\s+reset\s+--hard'  # destructive reset
  'git\s+clean\s+-[a-zA-Z]*f'  # destructive clean
  '\b(DROP|TRUNCATE|DELETE\s+FROM)\b.*\b(TABLE|DATABASE)\b'  # destructive DB ops
  'curl\b.*\|\s*(bash|sh|zsh)\b'  # curl piped to shell
  'wget\b.*\|\s*(bash|sh|zsh)\b'
  'chmod\s+777\b'  # world-writable permissions
  'chmod\s+-R\s+777\b'
  ':\(\)\s*\{\s*:\|:\s*&\s*\}\s*;'  # fork bomb
  'mkfs\b'  # format filesystem
  'dd\s+.*of=/dev/'  # write to raw device
  '\bsudo\s+rm\b'  # sudo rm
)

# Blocklist: specific git subcommands that need caution
_BP_GATE_BLOCKLIST_GIT=(
  'push.*--force'
  'push.*-f\b'
  'reset\s+--hard'
  'clean\s+-[a-zA-Z]*f'
  'branch\s+-D'
)

# ── T-106: Command Normalizer ─────────────────────────────────────────
# Strip variable arguments (file paths, commit messages, branch names)
# while preserving command structure and flags for cache keying.

bp_gate_normalize_command() {
  local cmd="$1"

  # Strip quoted strings (file paths, commit messages)
  local normalized
  normalized="$(echo "$cmd" | sed -E \
    -e 's/"[^"]*"/<STR>/g' \
    -e "s/'[^']*'/<STR>/g" \
    -e 's/\$\([^)]*\)/<SUBST>/g' \
    -e 's/\$\{[^}]*\}/<VAR>/g')"

  # Normalize file paths (anything starting with /, ./, ../)
  normalized="$(echo "$normalized" | sed -E \
    -e 's|(/[a-zA-Z0-9_./-]+)|<PATH>|g' \
    -e 's|\./[a-zA-Z0-9_./-]+|<PATH>|g')"

  # Normalize hex strings (commit hashes)
  normalized="$(echo "$normalized" | sed -E 's/\b[0-9a-f]{7,40}\b/<HASH>/g')"

  # Collapse multiple spaces
  normalized="$(echo "$normalized" | tr -s ' ')"

  echo "$normalized"
}

# ── T-104: Fast-Path Classifier ───────────────────────────────────────
# Classify command using static allowlist/blocklist without calling Codex.
#
# Returns via stdout:
#   APPROVE — command is on allowlist
#   BLOCK|<reason> — command is on blocklist
#   UNKNOWN — needs Codex classification

bp_gate_fast_classify() {
  local cmd="$1"

  # Extract base executable
  local base_exec
  base_exec="$(echo "$cmd" | awk '{print $1}' | sed 's|.*/||')"

  # Check blocklist patterns first (blocklist takes priority)
  local pattern
  for pattern in "${_BP_GATE_BLOCKLIST_PATTERNS[@]}"; do
    if echo "$cmd" | grep -qE "$pattern"; then
      echo "BLOCK|Matches blocklist pattern: $pattern"
      return 0
    fi
  done

  # Check user-configured blocklist
  local user_blocklist
  user_blocklist="$(bp_gate_config_get command_gate_blocklist)"
  if [[ -n "$user_blocklist" ]]; then
    local entry
    for entry in $user_blocklist; do
      if echo "$cmd" | grep -qE "$entry"; then
        echo "BLOCK|Matches user blocklist: $entry"
        return 0
      fi
    done
  fi

  # Check git-specific rules
  if [[ "$base_exec" == "git" ]]; then
    local git_subcmd
    git_subcmd="$(echo "$cmd" | awk '{print $2}')"

    # Check git blocklist
    for pattern in "${_BP_GATE_BLOCKLIST_GIT[@]}"; do
      if echo "$cmd" | grep -qE "git\s+$pattern"; then
        echo "BLOCK|Dangerous git operation: $pattern"
        return 0
      fi
    done

    # Check git allowlist
    local allowed_sub
    for allowed_sub in "${_BP_GATE_ALLOWLIST_GIT[@]}"; do
      if [[ "$git_subcmd" == "$allowed_sub" ]]; then
        echo "APPROVE"
        return 0
      fi
    done
  fi

  # Check general allowlist
  local allowed_exec
  for allowed_exec in "${_BP_GATE_ALLOWLIST_EXECUTABLES[@]}"; do
    if [[ "$base_exec" == "$allowed_exec" ]]; then
      echo "APPROVE"
      return 0
    fi
  done

  # Check user-configured allowlist
  local user_allowlist
  user_allowlist="$(bp_gate_config_get command_gate_allowlist)"
  if [[ -n "$user_allowlist" ]]; then
    local entry
    for entry in $user_allowlist; do
      if [[ "$base_exec" == "$entry" ]] || echo "$cmd" | grep -qE "$entry"; then
        echo "APPROVE"
        return 0
      fi
    done
  fi

  echo "UNKNOWN"
}

# ── T-108: Pattern-Based Verdict Cache ────────────────────────────────
# Session-scoped, in-memory cache keyed on normalized command pattern.

declare -A _BP_GATE_CACHE 2>/dev/null || true
# Fallback for bash 3 (macOS default): use a temp file
_BP_GATE_CACHE_FILE="${TMPDIR:-/tmp}/bp-gate-cache-$$"

_bp_gate_cache_get() {
  local key="$1"
  if [[ -f "$_BP_GATE_CACHE_FILE" ]]; then
    grep "^${key}|" "$_BP_GATE_CACHE_FILE" | tail -1 | cut -d'|' -f2-
  fi
}

_bp_gate_cache_set() {
  local key="$1" value="$2"
  echo "${key}|${value}" >> "$_BP_GATE_CACHE_FILE"
}

bp_gate_cache_clear() {
  rm -f "$_BP_GATE_CACHE_FILE" 2>/dev/null || true
}

# ── T-107: Codex Safety Classification ────────────────────────────────

_BP_GATE_CODEX_PROMPT='You are a command safety classifier. Given a bash command and its working directory context, classify whether it is safe to execute autonomously. Output exactly one JSON object with these fields:
- safe: boolean (true if the command is safe)
- reason: string (brief explanation)
- severity: "info" | "warn" | "block"

Rules:
- "info": safe to run silently
- "warn": probably safe but worth logging (e.g., writes to important files)
- "block": potentially destructive or dangerous (data loss, credential exposure, network exfiltration)

Be conservative: if unsure, classify as "warn" not "info".
Do NOT block standard development commands (test runners, build tools, linters, formatters).
DO block commands that delete data, expose secrets, or modify system configuration.

Command: '

bp_gate_codex_classify() {
  local cmd="$1"
  local workdir="${2:-$(pwd)}"

  if [[ "$codex_available" != "true" ]]; then
    # T-109: Graceful degradation — passthrough when Codex unavailable
    echo "PASSTHROUGH|Codex unavailable"
    return 0
  fi

  local timeout_ms
  timeout_ms="$(bp_gate_config_get command_gate_timeout)"
  local timeout_s=$(( (timeout_ms + 999) / 1000 ))

  local model
  model="$(bp_gate_config_get command_gate_model)"

  local full_prompt="${_BP_GATE_CODEX_PROMPT}${cmd}
Working directory: ${workdir}"

  local raw_output
  if ! raw_output="$(timeout "$timeout_s" codex --approval-mode full-auto --model "$model" --quiet -p "$full_prompt" 2>&1)"; then
    # T-109: Timeout or error — passthrough with warning
    echo "PASSTHROUGH|Codex call failed or timed out" >&2
    echo "PASSTHROUGH|Codex classification failed"
    return 0
  fi

  # Parse JSON response
  local safe severity reason
  safe="$(echo "$raw_output" | grep -oE '"safe"\s*:\s*(true|false)' | head -1 | grep -oE '(true|false)')"
  severity="$(echo "$raw_output" | grep -oE '"severity"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"/\1/')"
  reason="$(echo "$raw_output" | grep -oE '"reason"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"/\1/')"

  if [[ -z "$safe" ]]; then
    # Could not parse — passthrough
    echo "PASSTHROUGH|Could not parse Codex response"
    return 0
  fi

  case "$severity" in
    info)
      echo "APPROVE|$reason"
      ;;
    warn)
      echo "APPROVE|WARNING: $reason" >&2
      echo "APPROVE|$reason"
      ;;
    block)
      echo "BLOCK|$reason"
      ;;
    *)
      if [[ "$safe" == "true" ]]; then
        echo "APPROVE|$reason"
      else
        echo "BLOCK|$reason"
      fi
      ;;
  esac
}

# ── T-105: Claude Permission Integration ──────────────────────────────
# Check if the command is already handled by Claude's permission system.
# This is signaled via environment variables set by the hook framework.
#
# BP_HOOK_ALREADY_ALLOWED=1  — command pre-approved in settings
# BP_HOOK_ALREADY_BLOCKED=1  — command pre-blocked in settings

bp_gate_check_claude_permissions() {
  if [[ "${BP_HOOK_ALREADY_ALLOWED:-}" == "1" ]]; then
    echo "SKIP|Already allowed by Claude permission system"
    return 0
  fi
  if [[ "${BP_HOOK_ALREADY_BLOCKED:-}" == "1" ]]; then
    echo "SKIP|Already blocked by Claude permission system"
    return 0
  fi
  echo "EVALUATE"
}

# ── T-101: PreToolUse Hook Main Entry ─────────────────────────────────
# Called as a PreToolUse hook. Reads tool call context, classifies command.
#
# Input (from Claude Code hook framework):
#   $1 — tool name (should be "Bash")
#   $2 — command string
# Or reads JSON from stdin with tool_name and input.command
#
# Output (hook protocol):
#   Exit 0 + JSON: {"decision": "approve"} or {"decision": "block", "reason": "..."}
#   No output = passthrough to default behavior

bp_command_gate() {
  local tool_name="${1:-}"
  local command="${2:-}"

  # Read from stdin if not provided as args (hook JSON format)
  if [[ -z "$command" ]]; then
    local stdin_data
    stdin_data="$(cat)"
    if [[ -n "$stdin_data" ]]; then
      tool_name="$(echo "$stdin_data" | grep -oE '"tool_name"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"/\1/')"
      command="$(echo "$stdin_data" | grep -oE '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"/\1/')"
    fi
  fi

  # Only gate Bash commands
  if [[ "$tool_name" != "Bash" && "$tool_name" != "bash" ]]; then
    return 0
  fi

  if [[ -z "$command" ]]; then
    return 0
  fi

  # Check if gate is enabled
  local gate_mode
  gate_mode="$(bp_gate_config_get command_gate)"
  if [[ "$gate_mode" == "off" ]]; then
    return 0
  fi

  # T-105: Check Claude's permission system first
  local perm_check
  perm_check="$(bp_gate_check_claude_permissions)"
  if [[ "$perm_check" == SKIP* ]]; then
    return 0
  fi

  # T-104: Try fast-path classification
  local fast_result
  fast_result="$(bp_gate_fast_classify "$command")"

  case "$fast_result" in
    APPROVE)
      return 0
      ;;
    BLOCK*)
      local reason="${fast_result#BLOCK|}"
      echo "{\"decision\": \"block\", \"reason\": \"${reason}\"}"
      return 0
      ;;
  esac

  # T-108: Check verdict cache
  local normalized
  normalized="$(bp_gate_normalize_command "$command")"
  local cached
  cached="$(_bp_gate_cache_get "$normalized")"

  if [[ -n "$cached" ]]; then
    case "$cached" in
      APPROVE*) return 0 ;;
      BLOCK*)
        local reason="${cached#BLOCK|}"
        echo "{\"decision\": \"block\", \"reason\": \"${reason}\"}"
        return 0
        ;;
      PASSTHROUGH*) return 0 ;;
    esac
  fi

  # T-107: Call Codex for classification
  local codex_result
  codex_result="$(bp_gate_codex_classify "$command")"

  # Cache the result
  _bp_gate_cache_set "$normalized" "$codex_result"

  case "$codex_result" in
    APPROVE*)
      return 0
      ;;
    BLOCK*)
      local reason="${codex_result#BLOCK|}"
      echo "{\"decision\": \"block\", \"reason\": \"${reason}\"}"
      return 0
      ;;
    PASSTHROUGH*)
      # T-109: Graceful degradation — don't block
      return 0
      ;;
  esac
}

# ── CLI mode ──────────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  cmd="${1:-hook}"
  shift || true
  case "$cmd" in
    hook) bp_command_gate "$@" ;;
    classify) bp_gate_fast_classify "$@" ;;
    normalize) bp_gate_normalize_command "$@" ;;
    codex) bp_gate_codex_classify "$@" ;;
    cache-clear) bp_gate_cache_clear ;;
    help|--help|-h)
      echo "Usage: command-gate.sh {hook|classify|normalize|codex|cache-clear}"
      echo "  hook [tool cmd]   Run as PreToolUse hook (or reads JSON stdin)"
      echo "  classify <cmd>    Fast-path classify a command"
      echo "  normalize <cmd>   Normalize command for caching"
      echo "  codex <cmd>       Send to Codex for classification"
      echo "  cache-clear       Clear the verdict cache"
      ;;
    *) echo "Unknown: $cmd" >&2; exit 1 ;;
  esac
fi
