"use strict";
const assert = require("assert");
const path = require("path");
const fs = require("fs");
const { acquireLock, heartbeat, releaseLock, detectStaleLock } = require("../scripts/cavekit-tools.cjs");
const { cavekitDir, rmrf } = require("./helpers.cjs");

function acquires_lock_when_free() {
  const ck = cavekitDir("lock-free");
  const r = acquireLock(ck, "session:alpha");
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.lock.owner, "session:alpha");
  rmrf(path.dirname(ck));
}

function refuses_same_lock_to_other_owner() {
  const ck = cavekitDir("lock-conflict");
  const a = acquireLock(ck, "session:alpha");
  assert.strictEqual(a.ok, true);
  const b = acquireLock(ck, "session:beta");
  assert.strictEqual(b.ok, false);
  assert.strictEqual(b.reason, "held");
  rmrf(path.dirname(ck));
}

function heartbeat_refreshes_owner_lock() {
  const ck = cavekitDir("lock-hb");
  acquireLock(ck, "session:alpha");
  const before = JSON.parse(fs.readFileSync(path.join(ck, ".loop.lock"), "utf8"));
  // Force a later timestamp.
  const sleepUntil = Date.now() + 20;
  while (Date.now() < sleepUntil) { /* spin briefly */ }
  const r = heartbeat(ck, "session:alpha");
  assert.strictEqual(r.ok, true);
  const after = JSON.parse(fs.readFileSync(path.join(ck, ".loop.lock"), "utf8"));
  assert.ok(after.heartbeat_at >= before.heartbeat_at);
  rmrf(path.dirname(ck));
}

function steals_stale_lock() {
  const ck = cavekitDir("lock-steal");
  acquireLock(ck, "session:alpha");
  // Force stale.
  const file = path.join(ck, ".loop.lock");
  const existing = JSON.parse(fs.readFileSync(file, "utf8"));
  existing.heartbeat_at = Date.now() - 10 * 60_000;
  fs.writeFileSync(file, JSON.stringify(existing));
  assert.strictEqual(detectStaleLock(ck), true);
  const r = heartbeat(ck, "session:beta");
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.lock.owner, "session:beta");
  rmrf(path.dirname(ck));
}

function release_removes_file() {
  const ck = cavekitDir("lock-rel");
  acquireLock(ck, "session:alpha");
  const r = releaseLock(ck, "session:alpha");
  assert.strictEqual(r.ok, true);
  assert.strictEqual(fs.existsSync(path.join(ck, ".loop.lock")), false);
  rmrf(path.dirname(ck));
}

module.exports = {
  acquires_lock_when_free,
  refuses_same_lock_to_other_owner,
  heartbeat_refreshes_owner_lock,
  steals_stale_lock,
  release_removes_file,
};
