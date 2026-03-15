#!/bin/bash

# SDD Installer
#
# Usage:
#   git clone https://github.com/JuliusBrussee/sdd-os.git ~/.sdd && ~/.sdd/install.sh

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BIN_DIR="/usr/local/bin"
MARKETPLACE_NAME="sdd-os"

# ─── Colors ─────────────────────────────────────────────────────────────────

R=$'\033[0m' B=$'\033[1m' GR=$'\033[32m' YL=$'\033[33m' CY=$'\033[36m' RD=$'\033[31m'

info()  { printf "${CY}→${R} %s\n" "$1"; }
ok()    { printf "${GR}✓${R} %s\n" "$1"; }
warn()  { printf "${YL}!${R} %s\n" "$1"; }
fail()  { printf "${RD}✗${R} %s\n" "$1" >&2; exit 1; }

# ─── Header ─────────────────────────────────────────────────────────────────

printf "\n${B}${CY}SDD — Spec-Driven Development${R}\n"
printf "${B}Installer${R}\n\n"

# ─── Preflight ──────────────────────────────────────────────────────────────

command -v git &>/dev/null || fail "git not found."
command -v claude &>/dev/null || warn "claude CLI not found. Install Claude Code to use /sdd:... commands."
command -v tmux &>/dev/null || warn "tmux not found. Install for the parallel launcher: brew install tmux"

# ─── Register Claude Code plugin ───────────────────────────────────────────

info "Configuring Claude Code plugin..."

mkdir -p "$CLAUDE_DIR"

# The marketplace path is the parent of the install dir (plugin.json is at repo root)
MARKETPLACE_PATH="$(dirname "$INSTALL_DIR")"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  cat > "$SETTINGS_FILE" <<EOF
{
  "extraKnownMarketplaces": {
    "${MARKETPLACE_NAME}": {
      "source": { "source": "directory", "path": "${MARKETPLACE_PATH}" }
    }
  },
  "enabledPlugins": {
    "sdd@${MARKETPLACE_NAME}": true
  }
}
EOF
  ok "Created $SETTINGS_FILE"
else
  if grep -q "$MARKETPLACE_NAME" "$SETTINGS_FILE" 2>/dev/null; then
    ok "Plugin already registered"
  else
    if command -v python3 &>/dev/null; then
      python3 - "$SETTINGS_FILE" "$MARKETPLACE_NAME" "$MARKETPLACE_PATH" <<'PYEOF'
import json, sys
path, name, mpath = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    d = json.load(f)
d.setdefault("extraKnownMarketplaces", {})[name] = {"source": {"source": "directory", "path": mpath}}
d.setdefault("enabledPlugins", {})[f"sdd@{name}"] = True
with open(path, "w") as f:
    json.dump(d, f, indent=2)
PYEOF
      ok "Updated $SETTINGS_FILE"
    else
      warn "Could not auto-update settings. Add manually to $SETTINGS_FILE:"
      printf "\n"
      printf '  "extraKnownMarketplaces": { "%s": { "source": { "source": "directory", "path": "%s" } } }\n' "$MARKETPLACE_NAME" "$MARKETPLACE_PATH"
      printf '  "enabledPlugins": { "sdd@%s": true }\n\n' "$MARKETPLACE_NAME"
    fi
  fi
fi

# ─── Install sdd CLI ───────────────────────────────────────────────────────

info "Installing sdd command..."

chmod +x "$INSTALL_DIR/scripts/sdd"
chmod +x "$INSTALL_DIR/scripts/sdd-launch-session.sh"
chmod +x "$INSTALL_DIR/scripts/sdd-status-poller.sh"
chmod +x "$INSTALL_DIR/scripts/sdd-analytics.sh"
chmod +x "$INSTALL_DIR/scripts/dashboard-progress.sh"
chmod +x "$INSTALL_DIR/scripts/dashboard-activity.sh"
chmod +x "$INSTALL_DIR/scripts/setup-execute.sh"

if [[ -w "$BIN_DIR" ]]; then
  ln -sf "$INSTALL_DIR/scripts/sdd" "$BIN_DIR/sdd"
  ok "Installed sdd to $BIN_DIR/sdd"
else
  info "Need sudo to install sdd to $BIN_DIR"
  sudo ln -sf "$INSTALL_DIR/scripts/sdd" "$BIN_DIR/sdd"
  ok "Installed sdd to $BIN_DIR/sdd"
fi

# ─── Done ───────────────────────────────────────────────────────────────────

printf "\n${B}${GR}Installed!${R}\n\n"

printf "  ${B}Terminal:${R}\n"
printf "    sdd --monitor                 Pick frontiers and launch agents\n"
printf "    sdd --monitor --expanded      One tmux window per frontier\n"
printf "    sdd --status                  Show frontier progress\n"
printf "    sdd --analytics               Show loop trends\n"
printf "    sdd --kill                    Stop sessions and clean worktrees\n"
printf "\n"
printf "  ${B}Claude:${R}\n"
printf "    /sdd:brainstorm               Write specs\n"
printf "    /sdd:plan                     Generate frontier\n"
printf "    /sdd:execute                  Run the build loop\n"
printf "    /sdd:review                   Post-loop review\n"
printf "    /sdd:merge                    Merge completed SDD branches\n"
printf "\n"
printf "  Restart Claude Code to load the plugin.\n\n"
