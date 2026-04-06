#!/usr/bin/env bash
# codex-detect.sh — Codex binary and plugin detection utilities
# Source this file from other scripts: source "$(dirname "$0")/codex-detect.sh"
#
# Provides:
#   CODEX_BINARY_AVAILABLE  (true/false) — codex binary on PATH and responsive
#   CODEX_PLUGIN_PRESENT    (true/false) — Codex Claude Code plugin installed
#   codex_available         (true/false) — both binary AND plugin present
#   bp_codex_nudge          — one-time install suggestion (no-op if already shown)

# Guard against double-sourcing
if [[ -n "${_BP_CODEX_DETECT_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_BP_CODEX_DETECT_LOADED=1

# ── Binary detection (T-001) ───────────────────────────────────────────

CODEX_BINARY_AVAILABLE=false
if command -v codex &>/dev/null; then
  if codex --version &>/dev/null; then
    CODEX_BINARY_AVAILABLE=true
  fi
fi

# ── Plugin presence check (T-002) ──────────────────────────────────────

CODEX_PLUGIN_PRESENT=false

# Check standard Claude Code plugin locations
_bp_check_codex_plugin() {
  local claude_dir="${HOME}/.claude"

  # Check plugins cache (marketplace installs)
  if [[ -d "${claude_dir}/plugins" ]]; then
    for d in "${claude_dir}/plugins/"*/; do
      [[ -d "$d" ]] || continue
      if [[ -d "${d}codex" ]] || [[ -d "${d}openai-codex" ]] || \
         find "$d" -maxdepth 2 -name "plugin.json" -exec grep -ql "codex" {} + 2>/dev/null | grep -q .; then
        return 0
      fi
    done
  fi

  # Check local plugin links
  if [[ -d "${claude_dir}/plugins/local" ]]; then
    for d in "${claude_dir}/plugins/local/"*/; do
      [[ -d "$d" ]] || continue
      if find "$d" -maxdepth 2 -name "*.json" -exec grep -ql "codex" {} + 2>/dev/null | grep -q .; then
        return 0
      fi
    done
  fi

  # Check Codex's own config directory
  [[ -d "${HOME}/.codex" ]] && return 0

  return 1
}

if _bp_check_codex_plugin; then
  CODEX_PLUGIN_PRESENT=true
fi

# ── Combined availability ──────────────────────────────────────────────

codex_available=false
if [[ "$CODEX_BINARY_AVAILABLE" == "true" && "$CODEX_PLUGIN_PRESENT" == "true" ]]; then
  codex_available=true
elif [[ "$CODEX_BINARY_AVAILABLE" == "true" ]]; then
  # Binary exists but no plugin — still usable for reviews
  codex_available=true
fi

# ── One-time install nudge ─────────────────────────────────────────────

_BP_NUDGE_FILE="${BP_PROJECT_ROOT:-.}/.cavekit/.codex-nudge-shown"

bp_codex_nudge() {
  if [[ "$codex_available" == "true" ]]; then
    return 0
  fi
  if [[ -f "$_BP_NUDGE_FILE" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$_BP_NUDGE_FILE")"

  if [[ "$CODEX_BINARY_AVAILABLE" != "true" ]]; then
    echo "Tip: Install Codex for adversarial code review: npm install -g @openai/codex" >&2
  fi
  if [[ "$CODEX_PLUGIN_PRESENT" != "true" && "$CODEX_BINARY_AVAILABLE" == "true" ]]; then
    echo "Tip: Codex binary found but plugin not detected. Run: codex setup" >&2
  fi

  touch "$_BP_NUDGE_FILE"
}

# ── CLI mode ───────────────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  echo "CODEX_BINARY_AVAILABLE=$CODEX_BINARY_AVAILABLE"
  echo "CODEX_PLUGIN_PRESENT=$CODEX_PLUGIN_PRESENT"
  echo "codex_available=$codex_available"
fi
