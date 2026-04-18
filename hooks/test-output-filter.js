#!/usr/bin/env node
// test-output-filter.js — condense test-runner output to failure context + summary.

"use strict";

const fs = require("fs");
const path = require("path");

const TEST_COMMAND = [
  /\bvitest\b/, /\bjest\b/, /\bpytest\b/, /\bcargo\s+test\b/,
  /\bgo\s+test\b/, /\bnpm\s+(?:run\s+)?test\b/, /\bnpx\s+test\b/,
  /\bmocha\b/, /\bnode\s+--test\b/, /\bpnpm\s+(?:run\s+)?test\b/,
  /\byarn\s+(?:run\s+)?test\b/,
];
const FAILURE_LINE = [
  /\bFAIL\b/, /\bFAILED\b/, /AssertionError/i, /Error: expect/i,
  /^\s*not ok\s+\d+/m, /\bfailed\b/, /\btest failed\b/i, /panicked/i,
];
const MIN_BYTES = 2000;
const CONTEXT_LINES = 8;
const TAIL_LINES = 10;

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
    const loopFile = path.join(projectRoot(), ".cavekit", ".loop.json");
    if (!fs.existsSync(loopFile)) process.exit(0);
    const raw = await readStdin();
    if (!raw) process.exit(0);
    let payload;
    try { payload = JSON.parse(raw); } catch { process.exit(0); }

    const toolName = payload.tool_name || payload.toolName;
    if (toolName !== "Bash") process.exit(0);

    const cmd = String((payload.tool_input || {}).command || "");
    if (!TEST_COMMAND.some(r => r.test(cmd))) process.exit(0);

    const resp = payload.tool_response || payload.toolResponse;
    const text = typeof resp === "string" ? resp : (resp && resp.stdout) || "";
    if (!text || text.length < MIN_BYTES) process.exit(0);

    const lines = text.split("\n");
    const keep = new Set();
    lines.forEach((line, i) => {
      if (FAILURE_LINE.some(r => r.test(line))) {
        for (let j = Math.max(0, i - CONTEXT_LINES); j <= Math.min(lines.length - 1, i + CONTEXT_LINES); j++) {
          keep.add(j);
        }
      }
    });
    for (let i = Math.max(0, lines.length - TAIL_LINES); i < lines.length; i++) keep.add(i);

    if (keep.size === 0 || keep.size >= lines.length * 0.8) process.exit(0);

    const sorted = [...keep].sort((a, b) => a - b);
    const out = [];
    let prev = -2;
    for (const i of sorted) {
      if (i > prev + 1) out.push(`... (${i - prev - 1} lines elided)`);
      out.push(lines[i]);
      prev = i;
    }
    const condensed =
      `[cavekit test-output filter — ${lines.length} → ${sorted.length} lines]\n` +
      out.join("\n");

    const hookOut = {
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: condensed,
      },
    };
    process.stdout.write(JSON.stringify(hookOut));
    process.exit(0);
  } catch {
    process.exit(0);
  }
})();
