"use strict";
const assert = require("assert");
const path = require("path");
const {
  registerTask, recordTaskTokens, checkTaskBudget, readLedger,
  readState,
} = require("../scripts/cavekit-tools.cjs");
const { cavekitDir, rmrf } = require("./helpers.cjs");

function registers_task_with_depth_budget() {
  const ck = cavekitDir("budget-reg");
  const t = registerTask(ck, "T-001", "quick");
  assert.strictEqual(t.budget, 8000);
  assert.strictEqual(t.depth, "quick");
  assert.strictEqual(t.used, 0);
  rmrf(path.dirname(ck));
}

function accumulates_tokens_and_warns_at_80() {
  const ck = cavekitDir("budget-warn");
  registerTask(ck, "T-001", "quick"); // 8000
  let r = recordTaskTokens(ck, "T-001", 3000);
  assert.strictEqual(r.status, "ok");
  r = recordTaskTokens(ck, "T-001", 3800); // 6800 total (85%)
  assert.strictEqual(r.status, "warn");
  rmrf(path.dirname(ck));
}

function marks_exhausted_and_flips_phase() {
  const ck = cavekitDir("budget-exhaust");
  registerTask(ck, "T-001", "quick");
  recordTaskTokens(ck, "T-001", 10_000);
  const c = checkTaskBudget(ck, "T-001");
  assert.strictEqual(c.status, "exhausted");
  const s = readState(ck);
  assert.strictEqual(s.meta.phase, "budget_exhausted");
  rmrf(path.dirname(ck));
}

function session_ledger_sums_all_tasks() {
  const ck = cavekitDir("budget-session");
  registerTask(ck, "T-001", "standard");
  registerTask(ck, "T-002", "thorough");
  recordTaskTokens(ck, "T-001", 5000);
  recordTaskTokens(ck, "T-002", 2000);
  const led = readLedger(ck);
  assert.strictEqual(led.session_used, 7000);
  rmrf(path.dirname(ck));
}

module.exports = {
  registers_task_with_depth_budget,
  accumulates_tokens_and_warns_at_80,
  marks_exhausted_and_flips_phase,
  session_ledger_sums_all_tasks,
};
