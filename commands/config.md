---
name: ck-config
description: Show or update Cavekit execution model presets and runtime-layer keys (budgets, parallelism, hooks)
argument-hint: "[list | preset <expensive|quality|balanced|fast> [--global] | get <key> | set <key> <value> [--global]]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh:*)", "Bash(cat .cavekit/config.json)", "Read(.cavekit/config.json)"]
---

**What this does:** Shows or updates the active Cavekit execution preset (reasoning/execution/exploration model assignments) and autonomous-runtime keys (token budgets, parallelism, hook toggles).
**When to use it:** At any time. `--global` writes to `~/.cavekit/config`; default writes to `.cavekit/config` for the current repo.

# Cavekit Config — Execution Presets + Runtime Keys

Inspect or change two kinds of Cavekit config:

1. **Model presets** — maps task types to `opus` / `sonnet` / `haiku` (stored in flat `.cavekit/config` via `bp-config.sh`).
2. **Runtime keys** — budgets, parallelism, hook toggles, auto-backprop (stored in structured `.cavekit/config.json`, managed by `cavekit-tools.cjs` with defaults).

## Supported Usage

- `/ck:config`
  Show the effective preset, resolved models, where the value came from, **and the active runtime-layer keys**.
- `/ck:config list`
  Show the built-in presets and their model mappings.
- `/ck:config preset <name>`
  Set the project override in `.cavekit/config`.
- `/ck:config preset <name> --global`
  Set the user-level default in `~/.cavekit/config`.
- `/ck:config get <key>`
  Read any `bp-config.sh` key (preset or runtime — e.g., `session_budget`, `auto_backprop`).
- `/ck:config set <key> <value> [--global]`
  Write any `bp-config.sh` key. Validation runs automatically; invalid values are rejected.

If the arguments do not match one of those forms, show this usage summary and stop.

## No Arguments: Show Effective Configuration

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" show`
2. Present:
   - Effective preset
   - Reasoning / execution / exploration models
   - Value source: project, global, or built-in default
   - Source path
3. **Also** read `.cavekit/config.json` (if present) and surface the runtime keys:
   - `session_budget` (tokens)
   - `max_iterations`
   - `task_budgets.{quick,standard,thorough}`
   - `auto_backprop`
   - `hooks_config.{tool_cache, tool_cache_ttl_ms, test_filter, progress_tracker}`
   - `parallelism.{max_concurrent_agents, max_concurrent_per_repo}`
   - `model_routing.enabled`
   - `graphify.enabled`

   If `.cavekit/config.json` is absent, note "Runtime config not initialized — run `/ck:init` to create it."

## `list`: Show Built-In Presets

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" presets`
2. Present the preset table to the user

## `preset <name>`: Write Configuration

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" init`
2. If `--global` is present, run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" set bp_model_preset {parsed preset name} --global`
3. Otherwise run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" set bp_model_preset {parsed preset name} --project`
4. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" show`
5. Confirm the new effective preset and the file that was updated

## `get <key>` / `set <key> <value>`: Direct key access

1. For `get`: run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" get <key>`. Print the resolved value and the source (project / global / default).
2. For `set`: run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" set <key> <value> [--global|--project]`. Let `bp-config.sh` perform validation. On success, re-run `show` to confirm the new value.

Valid keys (non-exhaustive — see `bp-config.sh` for the full list):

| Key | Values | Purpose |
|-----|--------|---------|
| `bp_model_preset` | expensive / quality / balanced / fast | Preset above |
| `session_budget` | positive integer | Cap on total loop tokens |
| `max_iterations` | positive integer | Stop-hook iteration cap per loop |
| `task_budget_quick` / `_standard` / `_thorough` | positive integer | Per-task token budgets |
| `auto_backprop` | on / off | Backprop on test failure |
| `tool_cache` | on / off | Cache read-only tool results |
| `tool_cache_ttl_ms` | positive integer | Cache TTL |
| `test_filter` | on / off | Condense test output around failures |
| `progress_tracker` | on / off | Write `.cavekit/.progress.json` |
| `parallelism_max_agents` / `_max_per_repo` | positive integer | Subagent concurrency caps |
| `model_routing` | on / off | Score-based tier routing |
| `graphify_enabled` | on / off | Knowledge-graph queries |

## Rules

- Do not edit config files manually in this command; always go through `bp-config.sh`
- Let `bp-config.sh` reject invalid preset names / values with its own validation error
- After a successful write, always show the new effective configuration
