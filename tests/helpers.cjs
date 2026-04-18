"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");

function tmpDir(prefix) {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), `cavekit-test-${prefix}-`));
  return base;
}

function cavekitDir(prefix = "generic") {
  const root = tmpDir(prefix);
  const ck = path.join(root, ".cavekit");
  fs.mkdirSync(ck, { recursive: true });
  return ck;
}

function rmrf(p) {
  try { fs.rmSync(p, { recursive: true, force: true }); } catch (_) {}
}

module.exports = { tmpDir, cavekitDir, rmrf };
