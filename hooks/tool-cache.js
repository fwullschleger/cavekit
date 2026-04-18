#!/usr/bin/env node
// tool-cache.js — PreToolUse cache for read-only commands.
//
// On cache hit, returns { hookSpecificOutput: { permissionDecision: "deny" },
// systemMessage: "[Cached result ...]" } so Claude Code skips the tool call
// and surfaces the cached output as if it were fresh.

"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const DEFAULT_TTL_MS = 120_000;
const CACHEABLE_BASH = [
  /^git\s+(status|log|diff|branch|ls-files|show|config|remote|stash\s+list|rev-parse)\b/,
  /^(ls|find|which|wc|head|tail|cat|pwd|whoami|uname|file)\b/,
  /^node\s+--version\b/,
  /^npm\s+--version\b/,
  /^go\s+version\b/,
];
const MUTATING_BASH = [
  /^git\s+(add|commit|push|checkout|merge|reset|rebase|cherry-pick|clean|reflog)\b/,
  /^(rm|mv|cp|mkdir|touch|chmod|chown|ln)\b/,
  /^(npm|yarn|pnpm)\s+(install|add|remove|run\s+\S+|exec)\b/,
  /^(go\s+(build|install|test|run|get|mod)|cargo\s+(build|test|run|install))\b/,
];

function projectRoot() {
  if (process.env.CAVEKIT_PROJECT_ROOT) return process.env.CAVEKIT_PROJECT_ROOT;
  return process.cwd();
}
function cacheDir() {
  const d = path.join(projectRoot(), ".cavekit", "tool-cache");
  try { fs.mkdirSync(d, { recursive: true }); } catch (_) {}
  return d;
}

function readStdin() {
  return new Promise((resolve) => {
    let data = "";
    process.stdin.on("data", (c) => (data += c));
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", () => resolve(""));
  });
}

function keyFor(toolName, toolInput) {
  const h = crypto.createHash("sha256");
  h.update(toolName + "\x00" + JSON.stringify(toolInput ?? {}));
  return h.digest("hex").slice(0, 32);
}

function isCacheable(toolName, toolInput) {
  if (!toolInput || typeof toolInput !== "object") return false;
  switch (toolName) {
    case "Read":
    case "Grep":
    case "Glob":
      return true;
    case "Bash": {
      const cmd = String(toolInput.command || "");
      if (!cmd) return false;
      if (MUTATING_BASH.some((r) => r.test(cmd))) return false;
      return CACHEABLE_BASH.some((r) => r.test(cmd));
    }
    default:
      return false;
  }
}

(async () => {
  try {
    // Respect disable flag.
    const loopFile = path.join(projectRoot(), ".cavekit", ".loop.json");
    if (!fs.existsSync(loopFile)) process.exit(0);
    const raw = await readStdin();
    if (!raw) process.exit(0);

    let payload;
    try { payload = JSON.parse(raw); } catch { process.exit(0); }

    const toolName = payload.tool_name || payload.toolName;
    const toolInput = payload.tool_input || payload.toolInput || {};
    if (!isCacheable(toolName, toolInput)) process.exit(0);

    const k = keyFor(toolName, toolInput);
    const entry = path.join(cacheDir(), `${k}.json`);
    if (!fs.existsSync(entry)) process.exit(0);

    const cached = JSON.parse(fs.readFileSync(entry, "utf8"));
    const ttl = Number(cached.ttl_ms) || DEFAULT_TTL_MS;
    const age = Date.now() - Number(cached.stored_at || 0);
    if (age > ttl) {
      try { fs.unlinkSync(entry); } catch (_) {}
      process.exit(0);
    }

    const ageS = Math.round(age / 1000);
    const out = {
      hookSpecificOutput: { permissionDecision: "deny" },
      systemMessage: `[cavekit cache hit — ${ageS}s ago]\n\n${cached.response ?? ""}`,
    };
    process.stdout.write(JSON.stringify(out));
    process.exit(0);
  } catch {
    process.exit(0);
  }
})();
