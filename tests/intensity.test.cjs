"use strict";
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const {
  resolveIntensity, registerTask, recordTaskTokens, writeState, readLedger,
} = require("../scripts/cavekit-tools.cjs");
const { cavekitDir, rmrf } = require("./helpers.cjs");

function lite_when_everything_is_cheap() {
  const ck = cavekitDir("int-lite");
  writeState(ck, { phase: "building", current_task: "T-001" });
  registerTask(ck, "T-001", "standard");
  recordTaskTokens(ck, "T-001", 1000); // well under 50%
  assert.strictEqual(resolveIntensity(ck), "lite");
  rmrf(path.dirname(ck));
}

function thorough_depth_always_clamps_to_lite() {
  const ck = cavekitDir("int-thorough");
  writeState(ck, { phase: "building", current_task: "T-001" });
  registerTask(ck, "T-001", "thorough");
  // burn through session budget
  const led = readLedger(ck);
  led.session_used = led.session_budget * 0.95;
  fs.writeFileSync(path.join(ck, "token-ledger.json"), JSON.stringify(led));
  assert.strictEqual(resolveIntensity(ck), "lite");
  rmrf(path.dirname(ck));
}

function inspecting_phase_clamps_to_lite() {
  const ck = cavekitDir("int-inspect");
  writeState(ck, { phase: "inspecting", current_task: "T-002" });
  registerTask(ck, "T-002", "quick");
  const led = readLedger(ck);
  led.session_used = led.session_budget * 0.95;
  fs.writeFileSync(path.join(ck, "token-ledger.json"), JSON.stringify(led));
  assert.strictEqual(resolveIntensity(ck), "lite");
  rmrf(path.dirname(ck));
}

function ultra_when_session_hot_and_depth_quick() {
  const ck = cavekitDir("int-ultra");
  writeState(ck, { phase: "building", current_task: "T-003" });
  registerTask(ck, "T-003", "quick");
  const led = readLedger(ck);
  led.session_used = led.session_budget * 0.9;
  fs.writeFileSync(path.join(ck, "token-ledger.json"), JSON.stringify(led));
  assert.strictEqual(resolveIntensity(ck), "ultra");
  rmrf(path.dirname(ck));
}

function full_when_session_moderate_task_quiet() {
  const ck = cavekitDir("int-full");
  writeState(ck, { phase: "building", current_task: "T-004" });
  registerTask(ck, "T-004", "standard");
  const led = readLedger(ck);
  led.session_used = led.session_budget * 0.6;
  fs.writeFileSync(path.join(ck, "token-ledger.json"), JSON.stringify(led));
  recordTaskTokens(ck, "T-004", 1000); // low
  assert.strictEqual(resolveIntensity(ck), "full");
  rmrf(path.dirname(ck));
}

function explicit_override_wins() {
  const ck = cavekitDir("int-explicit");
  writeState(ck, { phase: "inspecting" });
  assert.strictEqual(resolveIntensity(ck, { explicit: "ultra" }), "ultra");
  rmrf(path.dirname(ck));
}

module.exports = {
  lite_when_everything_is_cheap,
  thorough_depth_always_clamps_to_lite,
  inspecting_phase_clamps_to_lite,
  ultra_when_session_hot_and_depth_quick,
  full_when_session_moderate_task_quiet,
  explicit_override_wins,
};
