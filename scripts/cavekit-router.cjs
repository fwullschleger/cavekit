#!/usr/bin/env node
// cavekit-router.cjs — Model tier routing.
//
// Scores a task against five axes (files, type, judgment, cross-component,
// novelty) to pick a tier (haiku | sonnet | opus) within the role's allowed
// band. Degrades under session budget pressure.
//
// CLI:
//   cavekit-router.cjs classify --role ck:task-builder --score 11
//   cavekit-router.cjs classify-task --role ck:task-builder \
//     --files 3 --type feature --judgment medium --cross-component 1 --novelty 1
//
// The router is consulted by commands that dispatch subagents; the emitted
// tier maps 1:1 to a Claude Code model id (haiku|sonnet|opus).

"use strict";

const fs = require("fs");
const path = require("path");

const TIERS = ["haiku", "sonnet", "opus"];
const COST = { haiku: 1, sonnet: 5, opus: 25 };

const ROLE_BASELINES = {
  "ck:complexity":   { min: "haiku",  preferred: "haiku",  max: "haiku"  },
  "ck:researcher":   { min: "haiku",  preferred: "sonnet", max: "sonnet" },
  "ck:task-builder": { min: "haiku",  preferred: "sonnet", max: "opus"   },
  "ck:builder":      { min: "sonnet", preferred: "sonnet", max: "opus"   },
  "ck:inspector":    { min: "sonnet", preferred: "sonnet", max: "opus"   },
  "ck:drafter":      { min: "sonnet", preferred: "opus",   max: "opus"   },
  "ck:architect":    { min: "sonnet", preferred: "opus",   max: "opus"   },
  "ck:design-reviewer": { min: "sonnet", preferred: "sonnet", max: "opus" },
};

function clampTier(tier, band) {
  const order = TIERS;
  const i = order.indexOf(tier);
  const minI = order.indexOf(band.min);
  const maxI = order.indexOf(band.max);
  if (i < minI) return band.min;
  if (i > maxI) return band.max;
  return tier;
}

function tierForScore(score) {
  if (score <= 6)  return "haiku";
  if (score <= 13) return "sonnet";
  return "opus";
}

function scoreTask(parts) {
  // Each axis is 0..4. Sum is 0..20.
  const files = Math.min(4, Math.max(0, Number(parts.files || 0) <= 2 ? 0 :
                Number(parts.files) <= 5 ? 1 :
                Number(parts.files) <= 10 ? 2 :
                Number(parts.files) <= 20 ? 3 : 4));
  const typeMap = { chore: 0, refactor: 1, feature: 2, cross_cutting: 3, arch: 4 };
  const type = typeMap[parts.type] ?? 2;
  const judgmentMap = { low: 0, medium: 2, high: 3, critical: 4 };
  const judgment = judgmentMap[parts.judgment] ?? 2;
  const crossComponent = Math.min(4, Math.max(0, Number(parts.cross_component || 0)));
  const noveltyMap = { known: 0, rare: 1, novel: 2, research: 3, unknown: 4 };
  const novelty = typeof parts.novelty === "number"
    ? Math.min(4, Math.max(0, parts.novelty))
    : (noveltyMap[parts.novelty] ?? 1);
  return files + type + judgment + crossComponent + novelty;
}

function pickModel(role, score, opts = {}) {
  const baseline = ROLE_BASELINES[role] || { min: "sonnet", preferred: "sonnet", max: "opus" };
  let tier = tierForScore(score);
  tier = clampTier(tier, baseline);

  const pressure = Number(opts.budget_pressure || 0);
  if (pressure >= 0.9) tier = baseline.min;
  else if (pressure >= 0.7) {
    const i = TIERS.indexOf(tier);
    const next = Math.max(TIERS.indexOf(baseline.min), i - 1);
    tier = TIERS[next];
  }
  return tier;
}

function presetModel(preset, taskType) {
  // Back-compat bridge to the existing bp_model_preset logic so commands
  // can ask for "reasoning|execution|exploration" without knowing scores.
  const matrix = {
    expensive: { reasoning: "opus",   execution: "opus",   exploration: "opus"   },
    quality:   { reasoning: "opus",   execution: "opus",   exploration: "sonnet" },
    balanced:  { reasoning: "opus",   execution: "sonnet", exploration: "haiku"  },
    fast:      { reasoning: "sonnet", execution: "sonnet", exploration: "haiku"  },
  };
  const row = matrix[preset] || matrix.quality;
  return row[taskType] || row.execution;
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2).replace(/-/g, "_");
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) out[key] = true;
      else { out[key] = next; i++; }
    }
  }
  return out;
}

function cli(argv) {
  const [sub, ...rest] = argv;
  const args = parseArgs(rest);

  switch (sub) {
    case "classify": {
      const role = String(args.role || "ck:task-builder");
      const score = Number(args.score);
      if (!Number.isFinite(score)) { process.stderr.write("classify: --score N required\n"); process.exit(1); }
      const tier = pickModel(role, score, { budget_pressure: Number(args.budget_pressure || 0) });
      process.stdout.write(tier + "\n");
      return 0;
    }
    case "classify-task": {
      const role = String(args.role || "ck:task-builder");
      const score = scoreTask({
        files: args.files,
        type: args.type,
        judgment: args.judgment,
        cross_component: args.cross_component,
        novelty: args.novelty,
      });
      const tier = pickModel(role, score, { budget_pressure: Number(args.budget_pressure || 0) });
      process.stdout.write(JSON.stringify({ score, tier }) + "\n");
      return 0;
    }
    case "preset": {
      const preset = String(args.preset || "quality");
      const taskType = String(args.task_type || "execution");
      process.stdout.write(presetModel(preset, taskType) + "\n");
      return 0;
    }
    case "baselines": {
      process.stdout.write(JSON.stringify(ROLE_BASELINES, null, 2) + "\n");
      return 0;
    }
    case "help":
    case undefined:
      process.stdout.write([
        "cavekit-router.cjs — model tier routing",
        "",
        "Subcommands:",
        "  classify --role ROLE --score N [--budget-pressure 0..1]",
        "  classify-task --role ROLE [--files N] [--type T] [--judgment J] [--cross-component N] [--novelty V]",
        "  preset --preset P --task-type T",
        "  baselines",
        "",
      ].join("\n"));
      return 0;
    default:
      process.stderr.write(`cavekit-router: unknown subcommand '${sub}'\n`);
      process.exit(1);
  }
}

if (require.main === module) {
  try { cli(process.argv.slice(2)); }
  catch (e) { process.stderr.write(`cavekit-router: ${e.stack || e.message}\n`); process.exit(1); }
}

module.exports = {
  TIERS, COST, ROLE_BASELINES,
  clampTier, tierForScore, scoreTask, pickModel, presetModel,
};
