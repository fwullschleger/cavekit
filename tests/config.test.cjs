"use strict";
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { loadConfig, getConfig, deepMerge, DEFAULT_CONFIG } =
  require("../scripts/cavekit-tools.cjs");
const { cavekitDir, rmrf } = require("./helpers.cjs");

function default_config_is_sane() {
  assert.ok(DEFAULT_CONFIG.session_budget > 0);
  assert.ok(DEFAULT_CONFIG.task_budgets.quick < DEFAULT_CONFIG.task_budgets.standard);
  assert.ok(DEFAULT_CONFIG.task_budgets.standard < DEFAULT_CONFIG.task_budgets.thorough);
  assert.strictEqual(typeof DEFAULT_CONFIG.auto_backprop, "boolean");
}

function deepmerge_overrides_leaves() {
  const merged = deepMerge({ a: 1, b: { c: 2, d: 3 } }, { b: { c: 99 } });
  assert.strictEqual(merged.a, 1);
  assert.strictEqual(merged.b.c, 99);
  assert.strictEqual(merged.b.d, 3);
}

function load_config_merges_user_over_defaults() {
  const ck = cavekitDir("cfg-merge");
  fs.writeFileSync(path.join(ck, "config.json"),
    JSON.stringify({ session_budget: 1_000_000, task_budgets: { quick: 9999 } }));
  const cfg = loadConfig(ck);
  assert.strictEqual(cfg.session_budget, 1_000_000);
  assert.strictEqual(cfg.task_budgets.quick, 9999);
  assert.strictEqual(cfg.task_budgets.standard, DEFAULT_CONFIG.task_budgets.standard);
  assert.strictEqual(getConfig(ck, "task_budgets.thorough"), DEFAULT_CONFIG.task_budgets.thorough);
  rmrf(path.dirname(ck));
}

module.exports = {
  default_config_is_sane,
  deepmerge_overrides_leaves,
  load_config_merges_user_over_defaults,
};
