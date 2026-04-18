#!/usr/bin/env node
// cavekit-tools.cjs — Cavekit orchestration engine.
//
// Non-LLM workhorse for the autonomous loop. Exposes a small CLI (invoked
// by hooks and commands) plus a programmatic module interface (for tests).
//
// Design constraints:
//   - Zero runtime deps (node:fs, node:path, node:crypto only).
//   - Deterministic, side-effect-isolated functions.
//   - All state lives under <project>/.cavekit/*.
//
// CLI contract:
//   cavekit-tools.cjs <subcommand> [--flag value...]
//   Subcommands: init, status, route, setup-loop, teardown-loop, heartbeat,
//     release-lock, record-task-tokens, backprop-directive, status-block,
//     discover, next-task, register-task, mark-complete.

"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const os = require("os");

// ────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────

const DEFAULT_CONFIG = Object.freeze({
  session_budget: 500_000,
  max_iterations: 60,
  task_budgets: { quick: 8_000, standard: 20_000, thorough: 45_000 },
  default_depth: "standard",
  auto_backprop: true,
  caveman: { enabled: true, default_intensity: "full" },
  parallelism: { max_concurrent_agents: 3, max_concurrent_per_repo: 2 },
  hooks_config: { test_filter: true, tool_cache: true, tool_cache_ttl_ms: 120_000, progress_tracker: true },
  model_routing: {
    enabled: true,
    cost_weights: { haiku: 1, sonnet: 5, opus: 25 },
    role_baselines: {
      "ck:complexity":  { min: "haiku",  preferred: "haiku",  max: "haiku"  },
      "ck:researcher":  { min: "haiku",  preferred: "sonnet", max: "sonnet" },
      "ck:task-builder":{ min: "haiku",  preferred: "sonnet", max: "opus"   },
      "ck:builder":     { min: "sonnet", preferred: "sonnet", max: "opus"   },
      "ck:inspector":   { min: "sonnet", preferred: "sonnet", max: "opus"   },
      "ck:drafter":     { min: "sonnet", preferred: "opus",   max: "opus"   },
      "ck:architect":   { min: "sonnet", preferred: "opus",   max: "opus"   },
    },
  },
  verification: { enabled: true, min_depth: "standard" },
  review: { enabled: true, min_depth: "standard" },
});

const PHASES = Object.freeze([
  "idle", "drafting", "mapping", "building", "reviewing", "inspecting",
  "verifying", "recovering", "budget_exhausted", "lock_conflict", "complete",
]);

const LOCK_STALE_MS = 5 * 60_000;
const HEARTBEAT_INTERVAL_MS = 60_000;

// ────────────────────────────────────────────────────────────────────
// YAML frontmatter (strict enough for our own shape)
// ────────────────────────────────────────────────────────────────────

function parseFrontmatter(text) {
  const meta = {};
  let body = text || "";
  if (!body.startsWith("---")) return { meta, body };
  const end = body.indexOf("\n---", 3);
  if (end === -1) return { meta, body };
  const header = body.slice(3, end).replace(/^\n/, "");
  body = body.slice(end + 4).replace(/^\n/, "");
  for (const raw of header.split("\n")) {
    const m = /^([A-Za-z0-9_\-]+)\s*:\s*(.*)$/.exec(raw);
    if (!m) continue;
    const key = m[1];
    let val = m[2].trim();
    if (val === "") { meta[key] = ""; continue; }
    if ((val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))) {
      meta[key] = val.slice(1, -1);
    } else if (/^-?\d+$/.test(val)) {
      meta[key] = Number(val);
    } else if (val === "true" || val === "false") {
      meta[key] = val === "true";
    } else if (val === "null" || val === "~") {
      meta[key] = null;
    } else if (val.startsWith("[") && val.endsWith("]")) {
      const inner = val.slice(1, -1).trim();
      meta[key] = inner ? inner.split(",").map(s => s.trim().replace(/^["']|["']$/g, "")) : [];
    } else {
      meta[key] = val;
    }
  }
  return { meta, body };
}

function serializeFrontmatter(meta, body = "") {
  const keys = Object.keys(meta);
  const lines = keys.map(k => {
    const v = meta[k];
    if (v === null || v === undefined) return `${k}: null`;
    if (typeof v === "string") {
      const needsQuote = /[:#>]/.test(v) || /^(true|false|null|yes|no)$/i.test(v) || /^-?\d+$/.test(v);
      return needsQuote ? `${k}: "${v.replace(/"/g, '\\"')}"` : `${k}: ${v}`;
    }
    if (Array.isArray(v)) {
      return `${k}: [${v.map(x => JSON.stringify(x)).join(", ")}]`;
    }
    return `${k}: ${v}`;
  });
  return `---\n${lines.join("\n")}\n---\n${body}`;
}

// ────────────────────────────────────────────────────────────────────
// Paths + filesystem helpers
// ────────────────────────────────────────────────────────────────────

function resolveCavekitDir(opts) {
  if (opts && opts.cavekitDir) return opts.cavekitDir;
  if (process.env.CAVEKIT_DIR) return process.env.CAVEKIT_DIR;
  const root = process.env.CAVEKIT_PROJECT_ROOT || process.cwd();
  return path.join(root, ".cavekit");
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function atomicWrite(filePath, content) {
  const tmp = `${filePath}.tmp.${process.pid}.${Date.now()}`;
  fs.writeFileSync(tmp, content);
  fs.renameSync(tmp, filePath);
}

function readJsonSafe(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, "utf8") || "null") ?? fallback; }
  catch { return fallback; }
}

function writeJson(file, value) {
  atomicWrite(file, JSON.stringify(value, null, 2) + "\n");
}

// ────────────────────────────────────────────────────────────────────
// Config
// ────────────────────────────────────────────────────────────────────

function deepMerge(a, b) {
  if (!a || typeof a !== "object" || Array.isArray(a)) return b ?? a;
  if (!b || typeof b !== "object" || Array.isArray(b)) return b ?? a;
  const out = { ...a };
  for (const k of Object.keys(b)) out[k] = deepMerge(a[k], b[k]);
  return out;
}

function loadConfig(cavekitDir) {
  const file = path.join(cavekitDir, "config.json");
  const user = readJsonSafe(file, {}) || {};
  return deepMerge(DEFAULT_CONFIG, user);
}

function getConfig(cavekitDir, keyPath) {
  const cfg = loadConfig(cavekitDir);
  return keyPath.split(".").reduce((o, k) => (o == null ? o : o[k]), cfg);
}

// ────────────────────────────────────────────────────────────────────
// State
// ────────────────────────────────────────────────────────────────────

function readState(cavekitDir) {
  const file = path.join(cavekitDir, "state.md");
  if (!fs.existsSync(file)) {
    return {
      meta: { phase: "idle", current_task: null, iteration: 0, updated_at: null },
      body: "",
    };
  }
  return parseFrontmatter(fs.readFileSync(file, "utf8"));
}

function writeState(cavekitDir, meta, body) {
  ensureDir(cavekitDir);
  const file = path.join(cavekitDir, "state.md");
  const prev = fs.existsSync(file) ? parseFrontmatter(fs.readFileSync(file, "utf8")) : { meta: {}, body: "" };
  const merged = { ...prev.meta, ...meta, updated_at: new Date().toISOString() };
  const out = serializeFrontmatter(merged, body ?? prev.body ?? "");
  atomicWrite(file, out);
  return merged;
}

// ────────────────────────────────────────────────────────────────────
// Locks (single-writer per loop)
// ────────────────────────────────────────────────────────────────────

function lockPath(cavekitDir) { return path.join(cavekitDir, ".loop.lock"); }

function readLock(cavekitDir) {
  const file = lockPath(cavekitDir);
  if (!fs.existsSync(file)) return null;
  return readJsonSafe(file, null);
}

function detectStaleLock(cavekitDir) {
  const lock = readLock(cavekitDir);
  if (!lock) return false;
  const age = Date.now() - Number(lock.heartbeat_at || 0);
  return age > LOCK_STALE_MS;
}

function acquireLock(cavekitDir, owner) {
  ensureDir(cavekitDir);
  const file = lockPath(cavekitDir);
  const existing = readLock(cavekitDir);
  const now = Date.now();
  if (existing && existing.owner !== owner) {
    const fresh = now - Number(existing.heartbeat_at || 0) <= LOCK_STALE_MS;
    if (fresh) return { ok: false, reason: "held", lock: existing };
  }
  const lock = { owner, pid: process.pid, host: os.hostname(), acquired_at: now, heartbeat_at: now };
  writeJson(file, lock);
  return { ok: true, lock };
}

function heartbeat(cavekitDir, owner) {
  const existing = readLock(cavekitDir);
  const now = Date.now();
  if (!existing) return acquireLock(cavekitDir, owner);
  if (existing.owner !== owner) {
    if (now - Number(existing.heartbeat_at || 0) > LOCK_STALE_MS) {
      return acquireLock(cavekitDir, owner);
    }
    return { ok: false, reason: "held", lock: existing };
  }
  existing.heartbeat_at = now;
  writeJson(lockPath(cavekitDir), existing);
  return { ok: true, lock: existing };
}

function releaseLock(cavekitDir, owner) {
  const existing = readLock(cavekitDir);
  if (!existing) return { ok: true };
  if (owner && existing.owner !== owner) return { ok: false, reason: "owner-mismatch" };
  try { fs.unlinkSync(lockPath(cavekitDir)); } catch (_) {}
  return { ok: true };
}

// ────────────────────────────────────────────────────────────────────
// Loop lifecycle
// ────────────────────────────────────────────────────────────────────

function loopFile(cavekitDir) { return path.join(cavekitDir, ".loop.json"); }

function setupLoop(cavekitDir, opts = {}) {
  ensureDir(cavekitDir);
  const cfg = loadConfig(cavekitDir);
  const maxIt = Number.isFinite(Number(opts.maxIterations))
    ? Number(opts.maxIterations)
    : cfg.max_iterations;
  const loop = {
    started_at: new Date().toISOString(),
    iteration: 0,
    max_iterations: maxIt,
    completion_promise: opts.completionPromise || "<promise>CAVEKIT COMPLETE</promise>",
    site: opts.site || null,
  };
  writeJson(loopFile(cavekitDir), loop);
  writeState(cavekitDir, { phase: opts.phase || "building", iteration: 0 }, "");
  return loop;
}

function readLoop(cavekitDir) {
  return readJsonSafe(loopFile(cavekitDir), null);
}

function bumpIteration(cavekitDir) {
  const loop = readLoop(cavekitDir);
  if (!loop) return null;
  loop.iteration = Number(loop.iteration || 0) + 1;
  writeJson(loopFile(cavekitDir), loop);
  writeState(cavekitDir, { iteration: loop.iteration });
  return loop;
}

function teardownLoop(cavekitDir) {
  try { fs.unlinkSync(loopFile(cavekitDir)); } catch (_) {}
  try { fs.unlinkSync(lockPath(cavekitDir)); } catch (_) {}
  writeState(cavekitDir, { phase: "complete" });
  return true;
}

// ────────────────────────────────────────────────────────────────────
// Token ledger
// ────────────────────────────────────────────────────────────────────

function ledgerPath(cavekitDir) { return path.join(cavekitDir, "token-ledger.json"); }

function readLedger(cavekitDir) {
  const cfg = loadConfig(cavekitDir);
  const fallback = {
    session_used: 0,
    session_budget: cfg.session_budget,
    task_budgets: { ...cfg.task_budgets },
    tasks: {},
  };
  return readJsonSafe(ledgerPath(cavekitDir), fallback);
}

function writeLedger(cavekitDir, ledger) {
  writeJson(ledgerPath(cavekitDir), ledger);
}

function registerTask(cavekitDir, taskId, depth = "standard") {
  const ledger = readLedger(cavekitDir);
  const budget = ledger.task_budgets[depth] || ledger.task_budgets.standard || 20_000;
  if (!ledger.tasks[taskId]) {
    ledger.tasks[taskId] = { depth, budget, used: 0, status: "ok" };
    writeLedger(cavekitDir, ledger);
  }
  return ledger.tasks[taskId];
}

function recordTaskTokens(cavekitDir, taskId, delta) {
  const ledger = readLedger(cavekitDir);
  if (!ledger.tasks[taskId]) registerTask(cavekitDir, taskId);
  const freshLedger = readLedger(cavekitDir);
  const task = freshLedger.tasks[taskId];
  const n = Math.max(0, Number(delta) || 0);
  task.used = Number(task.used || 0) + n;
  freshLedger.session_used = Number(freshLedger.session_used || 0) + n;
  const pct = task.used / (task.budget || 1);
  const prev = task.status;
  if (pct >= 1) task.status = "exhausted";
  else if (pct >= 0.8) task.status = "warn";
  else task.status = "ok";
  writeLedger(cavekitDir, freshLedger);
  if (task.status === "exhausted" && prev !== "exhausted") {
    writeState(cavekitDir, { phase: "budget_exhausted" });
  }
  return { used: task.used, budget: task.budget, status: task.status };
}

function checkTaskBudget(cavekitDir, taskId) {
  const ledger = readLedger(cavekitDir);
  const t = ledger.tasks[taskId];
  if (!t) return null;
  return { used: t.used, budget: t.budget, status: t.status, depth: t.depth };
}

function sessionBudgetPressure(cavekitDir) {
  const ledger = readLedger(cavekitDir);
  const used = Number(ledger.session_used || 0);
  const budget = Number(ledger.session_budget || 0);
  if (!budget) return 0;
  return used / budget;
}

// ────────────────────────────────────────────────────────────────────
// Caveman-internal intensity resolver
// ────────────────────────────────────────────────────────────────────

// Returns "lite" | "full" | "ultra" based on budget pressure, current task
// depth, and current phase. See skills/caveman-internal/references/
// budget-thresholds.md for the canonical decision table.
function resolveIntensity(cavekitDir, opts = {}) {
  const explicit = opts.explicit;
  if (explicit && ["lite", "full", "ultra"].includes(explicit)) return explicit;

  const sessionPressure = sessionBudgetPressure(cavekitDir);
  const state = readState(cavekitDir);
  const phase = opts.phase || state.meta.phase || "idle";

  // Clamps: thorough depth and inspecting phase prefer lite.
  let depth = opts.depth;
  if (!depth && state.meta.current_task) {
    const tb = checkTaskBudget(cavekitDir, state.meta.current_task);
    depth = tb && tb.depth;
  }
  if (depth === "thorough") return "lite";
  if (phase === "inspecting") return "lite";

  // Per-task pressure fallback.
  let taskPressure = 0;
  if (state.meta.current_task) {
    const tb = checkTaskBudget(cavekitDir, state.meta.current_task);
    if (tb && tb.budget) taskPressure = tb.used / tb.budget;
  }

  if (sessionPressure < 0.5 && taskPressure < 0.5) return "lite";
  if (sessionPressure < 0.5) return "full";
  if (sessionPressure < 0.8) {
    if (taskPressure >= 0.8) return "ultra";
    return depth === "thorough" ? "lite" : "full";
  }
  // >= 0.8 session pressure
  return depth === "thorough" ? "lite" : "ultra";
}

// ────────────────────────────────────────────────────────────────────
// Task registry (authoritative per-task status)
// ────────────────────────────────────────────────────────────────────

function taskRegistryPath(cavekitDir) { return path.join(cavekitDir, "task-status.json"); }

function readTaskRegistry(cavekitDir) {
  return readJsonSafe(taskRegistryPath(cavekitDir), { tasks: [], updated_at: null });
}

function writeTaskRegistry(cavekitDir, reg) {
  reg.updated_at = new Date().toISOString();
  writeJson(taskRegistryPath(cavekitDir), reg);
}

function initTaskRegistry(cavekitDir, tasks) {
  const reg = { tasks: tasks.map(t => ({
    id: t.id,
    title: t.title || "",
    tier: Number(t.tier || 1),
    depends_on: Array.isArray(t.depends_on) ? t.depends_on : [],
    status: t.status || "pending",
    depth: t.depth || "standard",
    repo: t.repo || null,
  })) };
  writeTaskRegistry(cavekitDir, reg);
  return reg;
}

function markTaskComplete(cavekitDir, taskId) {
  const reg = readTaskRegistry(cavekitDir);
  const t = reg.tasks.find(x => x.id === taskId);
  if (!t) return false;
  t.status = "complete";
  writeTaskRegistry(cavekitDir, reg);
  return true;
}

function findNextUnblockedTask(cavekitDir) {
  const reg = readTaskRegistry(cavekitDir);
  const done = new Set(reg.tasks.filter(t => t.status === "complete").map(t => t.id));
  const candidates = reg.tasks
    .filter(t => t.status !== "complete" && t.status !== "blocked")
    .filter(t => (t.depends_on || []).every(d => done.has(d)))
    .sort((a, b) => (a.tier - b.tier) || a.id.localeCompare(b.id));
  return candidates[0] || null;
}

function findAllUnblockedTasks(cavekitDir) {
  const reg = readTaskRegistry(cavekitDir);
  const done = new Set(reg.tasks.filter(t => t.status === "complete").map(t => t.id));
  return reg.tasks
    .filter(t => t.status !== "complete" && t.status !== "blocked")
    .filter(t => (t.depends_on || []).every(d => done.has(d)));
}

// ────────────────────────────────────────────────────────────────────
// Capability discovery
// ────────────────────────────────────────────────────────────────────

function which(cmd) {
  const paths = (process.env.PATH || "").split(path.delimiter);
  for (const p of paths) {
    const full = path.join(p, cmd);
    try {
      const st = fs.statSync(full);
      if (st.isFile() && (st.mode & 0o111)) return full;
    } catch (_) {}
  }
  return null;
}

function discoverCapabilities(cavekitDir) {
  const caps = {
    discovered_at: new Date().toISOString(),
    cli_tools: {},
    mcp_servers: [],
    plugins: [],
    codex: { available: false },
  };
  const probes = ["gh", "git", "node", "go", "rustc", "cargo", "python3", "pip", "docker", "vercel", "supabase", "firebase", "wrangler", "ffmpeg", "playwright", "codex"];
  for (const c of probes) caps.cli_tools[c] = Boolean(which(c));
  caps.codex.available = Boolean(caps.cli_tools.codex);

  // MCP discovery (.mcp.json)
  const mcpFile = path.join(path.dirname(cavekitDir), ".mcp.json");
  if (fs.existsSync(mcpFile)) {
    const j = readJsonSafe(mcpFile, {});
    caps.mcp_servers = Object.keys(j.mcpServers || {});
  }

  writeJson(path.join(cavekitDir, "capabilities.json"), caps);
  return caps;
}

// ────────────────────────────────────────────────────────────────────
// Routing — decide the next prompt
// ────────────────────────────────────────────────────────────────────

function routeDecision(cavekitDir, ctx = {}) {
  const loop = readLoop(cavekitDir);
  if (!loop) return null;

  // Iteration cap.
  const maxIt = Number.isFinite(Number(loop.max_iterations))
    ? Number(loop.max_iterations)
    : DEFAULT_CONFIG.max_iterations;
  if (Number(loop.iteration || 0) >= maxIt) {
    return "CAVEKIT_MAX_ITERATIONS";
  }

  // Session budget.
  if (sessionBudgetPressure(cavekitDir) >= 1) {
    writeState(cavekitDir, { phase: "budget_exhausted" });
    return "CAVEKIT_BUDGET_EXHAUSTED";
  }

  const state = readState(cavekitDir);
  const phase = state.meta.phase || "idle";

  if (phase === "budget_exhausted") return "CAVEKIT_BUDGET_EXHAUSTED";
  if (phase === "complete") return "CAVEKIT_LOOP_DONE";

  bumpIteration(cavekitDir);

  const next = findNextUnblockedTask(cavekitDir);
  if (!next) {
    const reg = readTaskRegistry(cavekitDir);
    const anyPending = reg.tasks.some(t => t.status !== "complete");
    if (!anyPending) return "CAVEKIT_LOOP_DONE";
    return [
      "[cavekit] No unblocked tasks ready, but the registry still has pending work.",
      "Inspect `.cavekit/task-status.json` — likely a dependency cycle or a blocked task.",
      "Resolve the blockage, mark status `blocked` if intentional, then resume.",
    ].join("\n");
  }

  const parallel = findAllUnblockedTasks(cavekitDir);
  registerTask(cavekitDir, next.id, next.depth);
  writeState(cavekitDir, { current_task: next.id, phase: "building" });

  const waveHeader = [
    `═══ Wave ${loop.iteration + 1} — Tier ${next.tier} ═══`,
    `${parallel.length} task(s) ready: ${parallel.map(t => t.id).join(", ")}`,
    `Current: ${next.id} — ${next.title || "(no title)"}`,
  ].join("\n");

  const body = [
    waveHeader,
    "",
    "Read the task from `.cavekit/task-status.json`, implement a coherent slice,",
    "run validation (tests if present), then mark the task complete with:",
    "",
    "    node \"${CLAUDE_PLUGIN_ROOT}/scripts/cavekit-tools.cjs\" mark-complete --task " + next.id,
    "",
    "When the entire registry is `complete`, emit the line `<promise>CAVEKIT COMPLETE</promise>`",
    "to end the loop. If you hit a blocker, set the task's status to `blocked` and explain why.",
  ].join("\n");

  return body;
}

// ────────────────────────────────────────────────────────────────────
// Backprop directive (prepended when a test-failure flag is pending)
// ────────────────────────────────────────────────────────────────────

function backpropDirective(cavekitDir) {
  const flag = readJsonSafe(path.join(cavekitDir, ".auto-backprop-pending.json"), null);
  if (!flag) return "";
  return [
    "═══ Auto-Backpropagation Triggered ═══",
    `Failing command: ${flag.command || "(unknown)"}`,
    `Triggered at: ${flag.triggered_at || "(unknown)"}`,
    "",
    "Before patching code, invoke the `revision` skill (automated-trace subsection) and run these steps:",
    "  1. TRACE — map the failure to a specific kit requirement (R-ID).",
    "  2. ANALYZE — classify: missing_criterion | incomplete_criterion | missing_requirement.",
    "  3. PROPOSE — if the spec needs a change, draft it and ask the user to approve.",
    "  4. GENERATE — write a regression test that currently fails.",
    "  5. VERIFY — run the test suite to confirm the fix resolves the failure.",
    "",
    "Failure excerpt:",
    "```",
    (flag.failure_excerpt || "").slice(0, 2000),
    "```",
    "",
    "After backprop, resume normal task execution below.",
    "",
  ].join("\n");
}

// ────────────────────────────────────────────────────────────────────
// Status block (in-session ASCII dashboard)
// ────────────────────────────────────────────────────────────────────

function statusBlock(cavekitDir) {
  const state = readState(cavekitDir);
  const ledger = readLedger(cavekitDir);
  const reg = readTaskRegistry(cavekitDir);
  const loop = readLoop(cavekitDir) || {};
  const total = reg.tasks.length;
  const done = reg.tasks.filter(t => t.status === "complete").length;
  const pct = ledger.session_budget ? Math.min(100, Math.round(100 * ledger.session_used / ledger.session_budget)) : 0;
  const lines = [
    "┌─ Cavekit Status ─────────────────────────",
    `│ Phase:     ${state.meta.phase || "idle"}`,
    `│ Task:      ${state.meta.current_task || "-"}`,
    `│ Tasks:     ${done}/${total} complete`,
    `│ Iter:      ${loop.iteration || 0} / ${loop.max_iterations || DEFAULT_CONFIG.max_iterations}`,
    `│ Session:   ${ledger.session_used || 0} / ${ledger.session_budget || 0} tokens (${pct}%)`,
    "└──────────────────────────────────────────",
  ];
  return lines.join("\n");
}

// ────────────────────────────────────────────────────────────────────
// CLI
// ────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2).replace(/-/g, "_");
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) { args[key] = true; }
      else { args[key] = next; i++; }
    } else {
      args._ ??= [];
      args._.push(a);
    }
  }
  return args;
}

function cli(argv) {
  const [sub, ...rest] = argv;
  const args = parseArgs(rest);
  const dir = args.cavekit_dir || resolveCavekitDir();

  switch (sub) {
    case "init": {
      ensureDir(dir);
      const cfgFile = path.join(dir, "config.json");
      if (!fs.existsSync(cfgFile)) writeJson(cfgFile, DEFAULT_CONFIG);
      writeState(dir, { phase: "idle", current_task: null, iteration: 0 }, "");
      writeLedger(dir, readLedger(dir));
      process.stdout.write(`cavekit initialized at ${dir}\n`);
      return 0;
    }
    case "status": {
      process.stdout.write(statusBlock(dir) + "\n");
      return 0;
    }
    case "setup-loop": {
      const loop = setupLoop(dir, {
        maxIterations: args.max_iterations && Number(args.max_iterations),
        completionPromise: args.completion_promise,
        site: args.site,
        phase: args.phase,
      });
      process.stdout.write(JSON.stringify(loop) + "\n");
      return 0;
    }
    case "teardown-loop": { teardownLoop(dir); return 0; }
    case "heartbeat": {
      const r = heartbeat(dir, String(args.owner || "unknown"));
      if (!r.ok) { process.exit(1); }
      process.stdout.write(JSON.stringify(r.lock) + "\n");
      return 0;
    }
    case "release-lock": {
      const r = releaseLock(dir, args.owner);
      if (!r.ok) { process.exit(1); }
      return 0;
    }
    case "route": {
      const out = routeDecision(dir, { transcript: args.transcript });
      if (out != null) process.stdout.write(String(out));
      return 0;
    }
    case "record-task-tokens": {
      const r = recordTaskTokens(dir, String(args.task), Number(args.delta || 0));
      process.stdout.write(`${r.used}/${r.budget} ${r.status}\n`);
      return 0;
    }
    case "backprop-directive": {
      process.stdout.write(backpropDirective(dir));
      return 0;
    }
    case "status-block": {
      process.stdout.write(statusBlock(dir));
      return 0;
    }
    case "discover": {
      const caps = discoverCapabilities(dir);
      process.stdout.write(JSON.stringify(caps, null, 2) + "\n");
      return 0;
    }
    case "intensity": {
      const out = resolveIntensity(dir, {
        depth: args.depth,
        phase: args.phase,
        explicit: args.explicit,
      });
      process.stdout.write(out + "\n");
      return 0;
    }
    case "next-task": {
      const t = findNextUnblockedTask(dir);
      process.stdout.write(t ? JSON.stringify(t) + "\n" : "");
      return 0;
    }
    case "register-task": {
      const r = registerTask(dir, String(args.task), args.depth || "standard");
      process.stdout.write(JSON.stringify(r) + "\n");
      return 0;
    }
    case "mark-complete": {
      const ok = markTaskComplete(dir, String(args.task));
      process.exit(ok ? 0 : 1);
    }
    case "init-registry": {
      const file = args.from;
      if (!file || !fs.existsSync(file)) { process.stderr.write("init-registry: --from <json> required\n"); process.exit(1); }
      const tasks = readJsonSafe(file, []);
      initTaskRegistry(dir, tasks);
      return 0;
    }
    case "help":
    case undefined:
      process.stdout.write([
        "cavekit-tools.cjs — Cavekit orchestration engine",
        "",
        "Subcommands:",
        "  init                         Create .cavekit/ with defaults",
        "  status                       Print status block",
        "  setup-loop [--max-iterations N] [--completion-promise STR] [--site PATH]",
        "  teardown-loop",
        "  heartbeat --owner TAG",
        "  release-lock [--owner TAG]",
        "  route [--transcript PATH]    Return next prompt (or sentinel)",
        "  record-task-tokens --task ID --delta N",
        "  register-task --task ID [--depth quick|standard|thorough]",
        "  mark-complete --task ID",
        "  init-registry --from FILE    Populate task-status.json from JSON array",
        "  backprop-directive",
        "  status-block",
        "  discover                     Write capabilities.json",
        "  intensity [--depth D] [--phase P] [--explicit I]  Resolve caveman-internal intensity",
        "",
      ].join("\n"));
      return 0;
    default:
      process.stderr.write(`cavekit-tools: unknown subcommand '${sub}'\n`);
      process.exit(1);
  }
}

if (require.main === module) {
  try { cli(process.argv.slice(2)); }
  catch (e) {
    process.stderr.write(`cavekit-tools: ${e.stack || e.message}\n`);
    process.exit(1);
  }
}

module.exports = {
  DEFAULT_CONFIG,
  PHASES,
  parseFrontmatter,
  serializeFrontmatter,
  deepMerge,
  loadConfig,
  getConfig,
  readState,
  writeState,
  acquireLock,
  heartbeat,
  releaseLock,
  detectStaleLock,
  setupLoop,
  teardownLoop,
  bumpIteration,
  readLedger,
  registerTask,
  recordTaskTokens,
  checkTaskBudget,
  sessionBudgetPressure,
  initTaskRegistry,
  readTaskRegistry,
  writeTaskRegistry,
  markTaskComplete,
  findNextUnblockedTask,
  findAllUnblockedTasks,
  discoverCapabilities,
  routeDecision,
  backpropDirective,
  statusBlock,
  resolveCavekitDir,
  resolveIntensity,
};
