#!/usr/bin/env node
// tool-cache-store.js — PostToolUse companion that writes cache entries.

"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const DEFAULT_TTL_MS = 120_000;
const CACHEABLE_BASH = [
  /^git\s+(status|log|diff|branch|ls-files|show|config|remote|stash\s+list|rev-parse)\b/,
  /^(ls|find|which|wc|head|tail|cat|pwd|whoami|uname|file)\b/,
];

function projectRoot() {
  return process.env.CAVEKIT_PROJECT_ROOT || process.cwd();
}
function cacheDir() {
  const d = path.join(projectRoot(), ".cavekit", "tool-cache");
  try { fs.mkdirSync(d, { recursive: true }); } catch (_) {}
  return d;
}
function keyFor(toolName, toolInput) {
  const h = crypto.createHash("sha256");
  h.update(toolName + "\x00" + JSON.stringify(toolInput ?? {}));
  return h.digest("hex").slice(0, 32);
}
function readStdin() {
  return new Promise((resolve) => {
    let data = "";
    process.stdin.on("data", (c) => (data += c));
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", () => resolve(""));
  });
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
      return !!cmd && CACHEABLE_BASH.some((r) => r.test(cmd));
    }
    default:
      return false;
  }
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
    const toolInput = payload.tool_input || payload.toolInput || {};
    const toolResponse = payload.tool_response || payload.toolResponse || "";
    if (!isCacheable(toolName, toolInput)) process.exit(0);

    const responseStr = typeof toolResponse === "string"
      ? toolResponse
      : JSON.stringify(toolResponse);
    if (responseStr.length > 200_000) process.exit(0); // don't cache huge blobs

    const k = keyFor(toolName, toolInput);
    const entry = path.join(cacheDir(), `${k}.json`);
    const body = {
      tool: toolName,
      stored_at: Date.now(),
      ttl_ms: DEFAULT_TTL_MS,
      response: responseStr,
    };
    fs.writeFileSync(entry, JSON.stringify(body));
    process.exit(0);
  } catch {
    process.exit(0);
  }
})();
