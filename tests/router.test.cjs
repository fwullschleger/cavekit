"use strict";
const assert = require("assert");
const { scoreTask, tierForScore, pickModel, presetModel, clampTier, ROLE_BASELINES } =
  require("../scripts/cavekit-router.cjs");

function score_axes_additive() {
  const s = scoreTask({ files: 3, type: "feature", judgment: "medium", cross_component: 1, novelty: "rare" });
  // files:3→1, type:feature→2, judgment:medium→2, cross:1, novelty:rare→1 = 7
  assert.strictEqual(s, 7);
}

function tier_bands() {
  assert.strictEqual(tierForScore(0), "haiku");
  assert.strictEqual(tierForScore(6), "haiku");
  assert.strictEqual(tierForScore(7), "sonnet");
  assert.strictEqual(tierForScore(13), "sonnet");
  assert.strictEqual(tierForScore(14), "opus");
}

function role_baseline_clamps() {
  // complexity role must be haiku always.
  const t = pickModel("ck:complexity", 18);
  assert.strictEqual(t, "haiku");
  // architect floor is sonnet.
  const t2 = pickModel("ck:architect", 0);
  assert.strictEqual(t2, "sonnet");
}

function budget_pressure_demotes() {
  const t = pickModel("ck:task-builder", 14, { budget_pressure: 0.95 });
  assert.strictEqual(t, "haiku");
  const t2 = pickModel("ck:task-builder", 14, { budget_pressure: 0.75 });
  assert.strictEqual(t2, "sonnet");
}

function preset_matrix() {
  assert.strictEqual(presetModel("expensive", "execution"), "opus");
  assert.strictEqual(presetModel("quality", "exploration"), "sonnet");
  assert.strictEqual(presetModel("balanced", "execution"), "sonnet");
  assert.strictEqual(presetModel("fast", "reasoning"), "sonnet");
}

function clamp_respects_band() {
  const band = ROLE_BASELINES["ck:task-builder"];
  assert.strictEqual(clampTier("opus", band), "opus");
  assert.strictEqual(clampTier("haiku", band), "haiku");
}

module.exports = {
  score_axes_additive,
  tier_bands,
  role_baseline_clamps,
  budget_pressure_demotes,
  preset_matrix,
  clamp_respects_band,
};
