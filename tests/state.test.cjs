"use strict";
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { readState, writeState } = require("../scripts/cavekit-tools.cjs");
const { cavekitDir, rmrf } = require("./helpers.cjs");

function writes_and_reads_state() {
  const ck = cavekitDir("state-basic");
  writeState(ck, { phase: "building", current_task: "T-001", iteration: 1 }, "body");
  const s = readState(ck);
  assert.strictEqual(s.meta.phase, "building");
  assert.strictEqual(s.meta.current_task, "T-001");
  assert.strictEqual(s.meta.iteration, 1);
  assert.ok(s.meta.updated_at);
  rmrf(path.dirname(ck));
}

function writeState_merges_meta() {
  const ck = cavekitDir("state-merge");
  writeState(ck, { phase: "building", iteration: 1, current_task: "T-001" });
  writeState(ck, { iteration: 2 });
  const s = readState(ck);
  assert.strictEqual(s.meta.phase, "building");          // preserved
  assert.strictEqual(s.meta.current_task, "T-001");      // preserved
  assert.strictEqual(s.meta.iteration, 2);               // updated
  rmrf(path.dirname(ck));
}

function readState_defaults_when_missing() {
  const ck = cavekitDir("state-missing");
  fs.unlinkSync.bind(null); // no state.md yet
  const s = readState(ck);
  assert.strictEqual(s.meta.phase, "idle");
  assert.strictEqual(s.meta.current_task, null);
  rmrf(path.dirname(ck));
}

module.exports = {
  writes_and_reads_state,
  writeState_merges_meta,
  readState_defaults_when_missing,
};
