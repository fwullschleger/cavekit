---
name: sdd-help
description: Show SDD commands and usage
---

# SDD — Spec-Driven Development

## The Workflow

```
/sdd:brainstorm    →  write specs (the WHAT)
/sdd:plan          →  generate frontier (the ORDER)
/sdd:execute       →  ralph loop (the BUILD)
/sdd:review        →  gap analysis + adversarial review (the CHECK)
```

## Commands

### `/sdd:brainstorm` — Write Specs

```bash
/sdd:brainstorm                        # interactive — asks what to build
/sdd:brainstorm context/refs/          # from reference materials (PRDs, docs)
/sdd:brainstorm --from-code            # from existing codebase (brownfield)
/sdd:brainstorm --filter v2            # only generate v2 specs
```

Decomposes your project into domains, writes `context/specs/spec-{domain}.md` files with R-numbered requirements and testable acceptance criteria.

### `/sdd:plan` — Generate Frontier

```bash
/sdd:plan                              # generates frontier from all specs
/sdd:plan --filter v2                  # only v2 specs
```

Reads specs, decomposes requirements into tasks, organizes into dependency tiers. Writes `context/frontiers/feature-frontier.md`. No domain plans — just tasks and dependencies.

### `/sdd:execute` — Run the Loop

```bash
/sdd:execute                           # ralph loop from frontier
/sdd:execute --filter v2               # scope to v2
/sdd:execute --adversarial             # add Codex (GPT-5.4) review
/sdd:execute --max-iterations 30       # iteration limit
/sdd:execute --adversarial --codex-model gpt-5.4-mini
```

Auto-archives any previous cycle, then starts a Ralph Loop. Each iteration: pick unblocked task → read spec → implement → validate → commit.

With `--adversarial`: alternates build and review iterations, calling Codex via MCP.

### `/sdd:review` — Post-Loop Review

```bash
/sdd:review                            # review everything from last loop
/sdd:review --filter v2                # only v2
```

Runs after execute completes. Does two things:
1. **Gap analysis** — compares built code against every spec requirement and acceptance criterion
2. **Adversarial review** — finds bugs, security issues, performance problems, quality gaps

Produces a verdict: APPROVE / REVISE / REJECT with prioritized findings.

### `/sdd:progress` — Check Progress

```bash
/sdd:progress                          # show frontier progress
/sdd:progress --filter v2
```

Shows tasks done/ready/blocked, progress bar, current tier, and next tasks.

### Maintenance (optional)

| Command | When |
|---------|------|
| `/sdd:gap-analysis` | After a loop — compare built vs intended |
| `/sdd:back-propagate` | After manual code fixes — trace back to specs |
| `/sdd:compact-specs` | When impl tracking files exceed ~500 lines |
| `/sdd:archive-loop` | Manually archive a loop cycle (execute does this automatically) |
| `/sdd:next-session` | Generate a handoff document for next session |

### Legacy (advanced)

These still work but are superseded by the three main commands:

| Command | Replaced by |
|---------|-------------|
| `/sdd init` | `/sdd:brainstorm` creates directories automatically |
| `/sdd spec-from-refs` | `/sdd:brainstorm context/refs/` |
| `/sdd spec-from-code` | `/sdd:brainstorm --from-code` |
| `/sdd plan-from-specs` | `/sdd:plan` (generates frontier directly, no domain plans) |
| `/sdd implement` | `/sdd:execute` (one task at a time vs full loop) |
| `/sdd spec-loop` | `/sdd:execute` |
| `/sdd adversarial-loop` | `/sdd:execute --adversarial` |
| `/sdd quick` | `/sdd:brainstorm` + `/sdd:plan` + `/sdd:execute` |

## Skills (reference docs)

| Skill | Topic |
|-------|-------|
| `sdd:sdd-methodology` | Core BPER lifecycle |
| `sdd:spec-writing` | How to write specs with testable criteria |
| `sdd:adversarial-review` | Cross-model review patterns |
| `sdd:adversarial-loop` | Ralph Loop + Codex architecture |
| `sdd:validation-first` | Every requirement must be auto-testable |
| `sdd:convergence-monitoring` | Detecting if loop is converging or stuck |
| `sdd:backpropagation` | Tracing bugs back to specs |
| `sdd:context-architecture` | Organizing context/ for AI agents |
| `sdd:impl-tracking` | Progress tracking and dead ends |
| `sdd:brownfield-adoption` | Adopting SDD on existing codebases |
| `sdd:prompt-pipeline` | Designing prompt sequences |
| `sdd:speculative-pipeline` | Staggered pipeline execution |
| `sdd:documentation-inversion` | Agent-first documentation |
