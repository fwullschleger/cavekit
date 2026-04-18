"use strict";
const assert = require("assert");
const path = require("path");
const {
  setupLoop, routeDecision, initTaskRegistry, markTaskComplete,
  readLedger, writeState, teardownLoop,
} = require("../scripts/cavekit-tools.cjs");
const { cavekitDir, rmrf } = require("./helpers.cjs");

const sample = [
  { id: "T-001", title: "First",  tier: 1, depends_on: [] },
  { id: "T-002", title: "Second", tier: 2, depends_on: ["T-001"] },
];

function route_returns_next_task_prompt() {
  const ck = cavekitDir("route-next");
  setupLoop(ck, { maxIterations: 10 });
  initTaskRegistry(ck, sample);
  const out = routeDecision(ck);
  assert.ok(out.includes("T-001"));
  assert.ok(out.includes("Wave"));
  rmrf(path.dirname(ck));
}

function route_returns_done_sentinel_when_empty() {
  const ck = cavekitDir("route-done");
  setupLoop(ck, { maxIterations: 10 });
  initTaskRegistry(ck, sample);
  markTaskComplete(ck, "T-001");
  markTaskComplete(ck, "T-002");
  const out = routeDecision(ck);
  assert.strictEqual(out, "CAVEKIT_LOOP_DONE");
  rmrf(path.dirname(ck));
}

function route_returns_max_iterations_sentinel() {
  const ck = cavekitDir("route-max");
  setupLoop(ck, { maxIterations: 0 });
  initTaskRegistry(ck, sample);
  const out = routeDecision(ck);
  assert.strictEqual(out, "CAVEKIT_MAX_ITERATIONS");
  rmrf(path.dirname(ck));
}

function route_returns_budget_exhausted_sentinel() {
  const ck = cavekitDir("route-budget");
  setupLoop(ck, { maxIterations: 10 });
  initTaskRegistry(ck, sample);
  // Manually exhaust session.
  const led = readLedger(ck);
  led.session_used = led.session_budget + 1;
  const fs = require("fs");
  fs.writeFileSync(path.join(ck, "token-ledger.json"), JSON.stringify(led));
  const out = routeDecision(ck);
  assert.strictEqual(out, "CAVEKIT_BUDGET_EXHAUSTED");
  rmrf(path.dirname(ck));
}

function teardown_clears_loop_and_lock() {
  const ck = cavekitDir("route-tear");
  setupLoop(ck, { maxIterations: 10 });
  teardownLoop(ck);
  const fs = require("fs");
  assert.strictEqual(fs.existsSync(path.join(ck, ".loop.json")), false);
  rmrf(path.dirname(ck));
}

module.exports = {
  route_returns_next_task_prompt,
  route_returns_done_sentinel_when_empty,
  route_returns_max_iterations_sentinel,
  route_returns_budget_exhausted_sentinel,
  teardown_clears_loop_and_lock,
};
