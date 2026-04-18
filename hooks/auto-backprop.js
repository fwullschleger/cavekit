#!/usr/bin/env node
// auto-backprop.js — on test failure, write a flag file. The stop-hook
// reads the flag on the next iteration and prepends a backpropagation
// directive to the next prompt so Cavekit traces the bug back to the kit
// before trying a fix.

"use strict";

const fs = require("fs");
const path = require("path");

const TEST_COMMAND = [
  /\bvitest\b/, /\bjest\b/, /\bpytest\b/, /\bcargo\s+test\b/,
  /\bgo\s+test\b/, /\bnpm\s+(?:run\s+)?test\b/, /\bnpx\s+test\b/,
  /\bmocha\b/, /\bnode\s+--test\b/, /\bpnpm\s+(?:run\s+)?test\b/,
  /\byarn\s+(?:run\s+)?test\b/,
];
const FAILURE = [
  /\bFAIL\b/, /\bFAILED\b/, /AssertionError/i, /Error: expect/i,
  /^\s*not ok\s+\d+/m, /\d+ failing\b/i, /\d+ failed\b/i,
  /Tests:\s+\d+\s+failed/i, /panicked/i,
];
const SUCCESS = [
  /\b0 failing\b/i, /\b0 failed\b/i, /Tests:\s+0\s+failed/i,
];
const MAX_EXCERPT = 4000;

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

(async () => {
  try {
    const ckDir = path.join(projectRoot(), ".cavekit");
    if (!fs.existsSync(path.join(ckDir, ".loop.json"))) process.exit(0);

    // Respect config: auto_backprop=off disables this hook.
    try {
      const cfgPath = path.join(ckDir, "config.json");
      if (fs.existsSync(cfgPath)) {
        const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8") || "{}");
        if (cfg.auto_backprop === false) process.exit(0);
      }
    } catch {}

    const raw = await readStdin();
    if (!raw) process.exit(0);
    let payload;
    try { payload = JSON.parse(raw); } catch { process.exit(0); }

    if ((payload.tool_name || payload.toolName) !== "Bash") process.exit(0);
    const cmd = String((payload.tool_input || {}).command || "");
    if (!TEST_COMMAND.some(r => r.test(cmd))) process.exit(0);

    const resp = payload.tool_response || payload.toolResponse;
    const text = typeof resp === "string" ? resp : (resp && resp.stdout) || "";
    if (!text) process.exit(0);

    if (SUCCESS.some(r => r.test(text))) process.exit(0);
    if (!FAILURE.some(r => r.test(text))) process.exit(0);

    const flagPath = path.join(ckDir, ".auto-backprop-pending.json");
    if (fs.existsSync(flagPath)) process.exit(0); // idempotent

    const failureLines = [];
    for (const line of text.split("\n")) {
      if (FAILURE.some(r => r.test(line))) failureLines.push(line);
      if (failureLines.join("\n").length > MAX_EXCERPT) break;
    }
    const excerpt = (failureLines.join("\n") || text.slice(-MAX_EXCERPT)).slice(0, MAX_EXCERPT);

    const flag = {
      triggered_at: new Date().toISOString(),
      command: cmd.slice(0, 500),
      failure_excerpt: excerpt,
    };
    fs.mkdirSync(ckDir, { recursive: true });
    fs.writeFileSync(flagPath, JSON.stringify(flag, null, 2));
    process.exit(0);
  } catch {
    process.exit(0);
  }
})();
