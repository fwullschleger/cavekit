#!/usr/bin/env node
// progress-tracker.js — writes a compact progress snapshot to
// .cavekit/.progress.json after every tool call. Zero stdout output so
// the hook does not consume prompt tokens.

"use strict";

const fs = require("fs");
const path = require("path");

function projectRoot() {
  return process.env.CAVEKIT_PROJECT_ROOT || process.cwd();
}
function readStdin() {
  return new Promise((resolve) => {
    let d = ""; process.stdin.on("data", c => d += c);
    process.stdin.on("end", () => resolve(d));
    process.stdin.on("error", () => resolve(""));
  });
}

function parseFrontmatter(text) {
  if (!text.startsWith("---")) return {};
  const end = text.indexOf("\n---", 3);
  if (end === -1) return {};
  const body = text.slice(3, end).trim();
  const out = {};
  for (const line of body.split("\n")) {
    const m = /^([A-Za-z0-9_\-]+)\s*:\s*(.*)$/.exec(line);
    if (m) out[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  return out;
}

(async () => {
  try {
    const ckDir = path.join(projectRoot(), ".cavekit");
    if (!fs.existsSync(path.join(ckDir, ".loop.json"))) process.exit(0);

    const raw = await readStdin();
    let payload = {};
    try { payload = JSON.parse(raw || "{}"); } catch {}

    const stateFile = path.join(ckDir, "state.md");
    let fm = {};
    if (fs.existsSync(stateFile)) {
      try { fm = parseFrontmatter(fs.readFileSync(stateFile, "utf8")); } catch {}
    }

    const ledgerFile = path.join(ckDir, "token-ledger.json");
    let tokens = {};
    if (fs.existsSync(ledgerFile)) {
      try { tokens = JSON.parse(fs.readFileSync(ledgerFile, "utf8") || "{}"); } catch {}
    }

    const snap = {
      updated_at: new Date().toISOString(),
      phase: fm.phase || "idle",
      current_task: fm.current_task || null,
      last_tool: payload.tool_name || payload.toolName || null,
      session_tokens_used: tokens.session_used || 0,
      session_budget: tokens.session_budget || 0,
    };

    fs.mkdirSync(ckDir, { recursive: true });
    fs.writeFileSync(path.join(ckDir, ".progress.json"), JSON.stringify(snap, null, 2));
    // Intentionally no stdout.
    process.exit(0);
  } catch {
    process.exit(0);
  }
})();
