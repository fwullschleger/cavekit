#!/usr/bin/env node
// Minimal zero-dep test runner. Uses node:assert. Discovers *.test.cjs
// files in this directory, runs them sequentially, and reports counts.

"use strict";

const fs = require("fs");
const path = require("path");

const here = __dirname;
const entries = fs.readdirSync(here).filter(f => f.endsWith(".test.cjs")).sort();

let passed = 0;
let failed = 0;
let total = 0;
const failures = [];

for (const file of entries) {
  const abs = path.join(here, file);
  process.stdout.write(`\n── ${file} ─────────────\n`);
  let mod;
  try { mod = require(abs); }
  catch (e) {
    failed++; total++;
    failures.push({ file, name: "<load>", error: e });
    process.stdout.write(`  FAIL <load>: ${e.message}\n`);
    continue;
  }
  for (const [name, fn] of Object.entries(mod || {})) {
    if (typeof fn !== "function") continue;
    total++;
    try {
      const maybe = fn();
      if (maybe && typeof maybe.then === "function") {
        throw new Error(`${name}: async tests not supported in this runner`);
      }
      passed++;
      process.stdout.write(`  ok   ${name}\n`);
    } catch (e) {
      failed++;
      failures.push({ file, name, error: e });
      process.stdout.write(`  FAIL ${name}: ${e.message}\n`);
    }
  }
}

process.stdout.write(`\n════════════════════════════════════════\n`);
process.stdout.write(` ${passed}/${total} passed  (${failed} failed)\n`);
process.stdout.write(`════════════════════════════════════════\n`);

if (failures.length) {
  process.stdout.write("\nFailure details:\n");
  for (const f of failures) {
    process.stdout.write(`\n  ${f.file} :: ${f.name}\n`);
    process.stdout.write((f.error.stack || f.error.message).split("\n").map(l => "    " + l).join("\n") + "\n");
  }
  process.exit(1);
}

process.exit(0);
