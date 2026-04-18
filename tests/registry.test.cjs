"use strict";
const assert = require("assert");
const path = require("path");
const {
  initTaskRegistry, findNextUnblockedTask, findAllUnblockedTasks,
  markTaskComplete,
} = require("../scripts/cavekit-tools.cjs");
const { cavekitDir, rmrf } = require("./helpers.cjs");

const sample = [
  { id: "T-001", title: "Auth scaffold", tier: 1, depends_on: [] },
  { id: "T-002", title: "Redis client",  tier: 1, depends_on: [] },
  { id: "T-003", title: "Middleware",    tier: 2, depends_on: ["T-001", "T-002"] },
];

function next_task_is_tier_1() {
  const ck = cavekitDir("reg-next");
  initTaskRegistry(ck, sample);
  const t = findNextUnblockedTask(ck);
  assert.strictEqual(t.id, "T-001");
  rmrf(path.dirname(ck));
}

function parallel_returns_all_tier_1_initially() {
  const ck = cavekitDir("reg-par");
  initTaskRegistry(ck, sample);
  const ts = findAllUnblockedTasks(ck);
  assert.strictEqual(ts.length, 2);
  assert.deepStrictEqual(ts.map(t => t.id).sort(), ["T-001", "T-002"]);
  rmrf(path.dirname(ck));
}

function tier_2_unblocks_after_deps_complete() {
  const ck = cavekitDir("reg-unblock");
  initTaskRegistry(ck, sample);
  markTaskComplete(ck, "T-001");
  markTaskComplete(ck, "T-002");
  const t = findNextUnblockedTask(ck);
  assert.strictEqual(t.id, "T-003");
  rmrf(path.dirname(ck));
}

function all_complete_returns_null() {
  const ck = cavekitDir("reg-done");
  initTaskRegistry(ck, sample);
  markTaskComplete(ck, "T-001");
  markTaskComplete(ck, "T-002");
  markTaskComplete(ck, "T-003");
  const t = findNextUnblockedTask(ck);
  assert.strictEqual(t, null);
  rmrf(path.dirname(ck));
}

module.exports = {
  next_task_is_tier_1,
  parallel_returns_all_tier_1_initially,
  tier_2_unblocks_after_deps_complete,
  all_complete_returns_null,
};
