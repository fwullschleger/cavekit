---
name: bp-help
description: Show Cavekit commands and usage
---

# Cavekit

## The Workflow

```
/bp:init        →  bootstrap context hierarchy (optional, /bp:draft does this too)
/bp:design      →  create or update DESIGN.md (the LOOK) — import, extract, or design interactively
/bp:research    →  deep multi-agent research (standalone, or integrated into /bp:draft)
/bp:draft       →  write kits (the WHAT) — offers research if warranted, references DESIGN.md
/bp:architect   →  generate site (the ORDER) — includes design refs for UI tasks
/bp:build       →  ralph loop (the BUILD) — task builders read DESIGN.md for UI work
/bp:inspect     →  gap analysis + peer review + design compliance (the CHECK)
/bp:config      →  show or change execution model presets
```

### Quick Mode

```bash
/bp:quick <describe your feature>   # runs all 4 phases end-to-end, no stops
/bp:quick add JWT auth --skip-inspect
/bp:quick refactor the API layer --peer-review
```

Streamlined draft + architect (no interactive Q&A, no user gates) followed by the full build and inspect. Best for small-to-medium features where you trust the decomposition.

### Model Presets

```bash
/bp:config                         # show effective preset + resolved models
/bp:config list                    # show built-in presets
/bp:config preset balanced         # set repo override
/bp:config preset fast --global    # set your default for all repos
```

Built-in presets:

| Preset | Reasoning | Execution | Exploration |
|--------|-----------|-----------|-------------|
| `expensive` | `opus` | `opus` | `opus` |
| `quality` | `opus` | `opus` | `sonnet` |
| `balanced` | `opus` | `sonnet` | `haiku` |
| `fast` | `sonnet` | `sonnet` | `haiku` |

Precedence: `.cavekit/config` overrides `~/.cavekit/config`, which overrides the built-in default (`quality`).

## Commands

### `/bp:init` — Bootstrap Context Hierarchy

```bash
/bp:init                         # create all context dirs, CLAUDE.md files, index files
```

Creates the full context hierarchy for a Cavekit project. Idempotent — only creates what's missing. Detects legacy `context/sites/` layout and offers migration to `context/plans/`.

### `/bp:research` — Deep Research

```bash
/bp:research "build a Verse compiler targeting WASM"           # standard depth
/bp:research "add real-time collab" --depth deep               # exhaustive
/bp:research "refactor auth layer" --depth quick               # fast scan
/bp:research "new React dashboard" --web-only                  # greenfield, skip codebase
/bp:research "optimize DB queries" --codebase-only             # air-gapped, skip web
```

Runs parallel multi-agent research (codebase exploration + web search) and produces a research brief in `context/refs/research-brief-{topic}.md`. Dispatches 2-8 agents depending on project size and depth. Two-pass synthesis cross-validates findings and resolves contradictions.

Also integrated into `/bp:draft` — when the draft phase detects a project that would benefit from research, it offers to run the pipeline inline before design Q&A.

### `/bp:design` — Create or Update DESIGN.md

```bash
/bp:design                        # interactive — collaborative design system creation
/bp:design --import claude        # import from awesome-design-md collection
/bp:design --import vercel        # import Vercel's design system as starting point
/bp:design --from-site https://...  # extract design system from a live site
/bp:design --audit                # quality check existing DESIGN.md
/bp:design --section 2            # update just Section 2 (Color Palette)
```

Creates the project's visual design system document following the 9-section Google Stitch format. DESIGN.md becomes the authoritative visual reference that all agents consult when building UI.

### `/bp:draft` — Write Kits

```bash
/bp:draft                        # interactive — asks what to build
/bp:draft context/refs/          # from reference materials (PRDs, docs)
/bp:draft --from-code            # from existing codebase (brownfield)
/bp:draft --filter v2            # only generate v2 kits
```

Decomposes your project into domains, writes `context/kits/cavekit-{domain}.md` files with R-numbered requirements and testable acceptance criteria.

### `/bp:architect` — Generate Site

```bash
/bp:architect                    # generates site from all kits
/bp:architect --filter v2        # only v2 kits
```

Reads kits, decomposes requirements into tasks, organizes into dependency tiers. Writes `context/plans/build-site.md`. No domain plans — just tasks and dependencies.

### `/bp:build` — Run the Loop

```bash
/bp:build                       # auto-parallel build from site
/bp:build --filter v2           # scope to v2
/bp:build --peer-review         # add Codex (GPT-5.4) review
/bp:build --max-iterations 30   # iteration limit
/bp:build --peer-review --codex-model gpt-5.4-mini
```

Auto-archives any previous cycle, then builds the site. Automatically parallelizes by grouping ready tasks into a few coherent work packets based on shared files, subsystem, and complexity. Progresses through tiers autonomously without manual intervention. If multiple build sites exist, asks which one to implement.

With `--peer-review`: alternates build and review iterations, calling Codex via MCP.

### `/bp:inspect` — Post-Loop Inspection

```bash
/bp:inspect                     # inspect everything from last loop
/bp:inspect --filter v2         # only v2
```

Runs after build completes. Does two things:
1. **Gap analysis** — compares built code against every cavekit requirement and acceptance criterion
2. **Peer review** — finds bugs, security issues, performance problems, quality gaps

Produces a verdict: APPROVE / REVISE / REJECT with prioritized findings.

### `/bp:config` — Execution Presets

```bash
/bp:config
/bp:config list
/bp:config preset quality
/bp:config preset fast --global
```

Shows or updates the active Cavekit execution preset. Presets map three task buckets:
`reasoning` for draft/architect/inspect-style work, `execution` for build/task-builder work, and `exploration` for research and codebase scanning helpers.

### `/bp:progress` — Check Progress

```bash
/bp:progress                    # show site progress
/bp:progress --filter v2
```

Shows tasks done/ready/blocked, progress bar, current tier, and next tasks.

### `/bp:codex-review` — On-Demand Codex Review

```bash
/bp:codex-review                  # review current tier diff
/bp:codex-review --base v1.0     # review diff against a specific ref
```

Sends the current diff to Codex for adversarial review. Outputs findings in Cavekit format and appends them to `context/impl/impl-review-findings.md`. Requires Codex CLI to be installed.

### Maintenance (optional)

| Command | When |
|---------|------|
| `/bp:codex-review` | On-demand Codex adversarial review of current diff |
| `/bp:gap-analysis` | After a loop — compare built vs intended |
| `/bp:revise` | After manual code fixes — trace back to kits |
| `/bp:compact-specs` | When impl tracking files exceed ~500 lines |
| `/bp:archive-loop` | Manually archive a loop cycle (build does this automatically) |
| `/bp:next-session` | Generate a handoff document for next session |

### Legacy (advanced)

These still work but are superseded by the three main commands:

| Command | Replaced by |
|---------|-------------|
| `/cavekit init` | `/bp:init` (or `/bp:draft` creates directories automatically) |
| `/cavekit spec-from-refs` | `/bp:draft context/refs/` |
| `/cavekit spec-from-code` | `/bp:draft --from-code` |
| `/cavekit plan-from-specs` | `/bp:architect` (generates site directly, no domain plans) |
| `/cavekit implement` | `/bp:build` (one task at a time vs full loop) |
| `/cavekit spec-loop` | `/bp:build` |
| `/cavekit peer-review-loop` | `/bp:build --peer-review` |
| `/cavekit quick` | `/bp:quick` (end-to-end with no stops) |

## Skills (reference docs)

| Skill | Topic |
|-------|-------|
| `bp:methodology` | Core DABI lifecycle |
| `bp:design-system` | How to write and maintain DESIGN.md (9-section Stitch format) |
| `bp:cavekit-writing` | How to write kits with testable criteria |
| `bp:peer-review` | Cross-model review patterns |
| `bp:peer-review-loop` | Ralph Loop + Codex architecture |
| `bp:validation-first` | Every requirement must be auto-testable |
| `bp:convergence-monitoring` | Detecting if loop is converging or stuck |
| `bp:revision` | Tracing bugs back to kits |
| `bp:context-architecture` | Organizing context/ for AI agents |
| `bp:impl-tracking` | Progress tracking and dead ends |
| `cavekit:brownfield-adoption` | Adopting Cavekit on existing codebases |
| `bp:prompt-pipeline` | Designing prompt sequences |
| `cavekit:speculative-pipeline` | Staggered pipeline execution |
| `cavekit:documentation-inversion` | Agent-first documentation |
