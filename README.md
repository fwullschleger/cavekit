<p align="center">

```
    ____  __    __  __ __________  ____  _____   ________
   / __ )/ /   / / / // ____/ __ \/ __ \/  _/ | / /_  __/
  / __  / /   / / / // __/ / /_/ / /_/ // //  |/ / / /
 / /_/ / /___/ /_/ // /___/ ____/ _, _// // /|  / / /
/_____/_____/\____//_____/_/   /_/ |_/___/_/ |_/ /_/
```

</p>

<h3 align="center">Specification-driven development for AI coding agents</h3>

<p align="center">
  A Claude Code plugin that turns natural language into blueprints,<br>
  blueprints into parallel build plans, and build plans into working software —<br>
  with automated iteration, validation, and cross-model peer review.
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/Claude_Code-plugin-blueviolet" alt="Claude Code Plugin"></a>
  <img src="https://img.shields.io/badge/version-2.0.0-green" alt="Version 2.0.0">
</p>

<p align="center">
  <a href="#install">Install</a> &middot;
  <a href="#how-it-works">How It Works</a> &middot;
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="#parallel-agents">Parallel Agents</a> &middot;
  <a href="#commands">Commands</a> &middot;
  <a href="#methodology">Methodology</a> &middot;
  <a href="example.md">Examples</a>
</p>

---

## The Problem

AI coding agents are powerful, but they fail in predictable ways:

- **They lose context.** Ask an agent to build a full-stack feature and it forgets what it said three steps ago.
- **They skip validation.** Code gets written but never verified against the original intent.
- **They can't parallelize.** One agent, one task, one branch — even when the work is independent.
- **They don't iterate.** A single pass produces a rough draft, not production code.

Blueprint fixes all of this.

---

## The Idea

Instead of prompting an agent and hoping for the best, Blueprint introduces a **specification layer** between your intent and the code. You describe what you want. The system decomposes it into domain blueprints with numbered requirements and testable acceptance criteria. Then it builds from those blueprints — not from memory, not from vibes — in an automated loop that validates every step.

```
                        ┌─── blueprint/auth ──── Agent 1 ───┐
                        │                                    │
You ── /bp:draft ──► Blueprints ── /bp:architect ──► Build Site ──┤─── blueprint/tasks ─── Agent 2 ───┤──► /bp:merge ──► main
                        │                                    │
                        └─── blueprint/api ───── Agent 3 ───┘
```

The blueprints are the source of truth. Agents read them, build from them, and validate against them. When something breaks, the system traces the failure back to the blueprint — not the code.

---

## Without Blueprint vs. With Blueprint

<table>
<tr><th width="50%">Without Blueprint</th><th width="50%">With Blueprint</th></tr>
<tr>
<td>

```
> Build me a task management API

  (agent writes 2000 lines)
  (no tests)
  (forgot the auth middleware)
  (wrong database schema)
  (you spend 3 hours fixing it)
```

One shot. No validation. No traceability.
The agent guessed what you wanted.

</td>
<td>

```
> /bp:draft
  4 blueprints, 22 requirements, 69 criteria

> /bp:architect
  34 tasks across 5 dependency tiers

> /bp:build
  18 iterations — each validated against
  the blueprint before committing

  BLUEPRINT COMPLETE
```

Every line of code traces to a requirement.
Every requirement has acceptance criteria.

</td>
</tr>
</table>

---

## Install

```bash
git clone https://github.com/JuliusBrussee/blueprint.git ~/.blueprint
cd ~/.blueprint && ./install.sh
```

This registers the Blueprint plugin with Claude Code and installs the `blueprint` CLI. Restart Claude Code after installing.

**Requirements:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), git, macOS/Linux. Optional: tmux (for parallel agents).

---

## How It Works

Blueprint follows four phases — **Draft, Architect, Build, Inspect** — each driven by a slash command inside Claude Code.

```
  DRAFT            ARCHITECT           BUILD              INSPECT           MERGE
  ─────            ─────────           ─────              ───────           ─────
  "What are we     Break into tasks,   The Ralph Loop:    Gap analysis:     Integrate
   building?"      map dependencies,   implement →        built vs.         branches in
                   organize into       validate →         intended.         dependency
  Produces:        tiered build site   commit → repeat    Peer review.      order.
  blueprints                                              Trace to specs.
  with R-numbered  Produces:           Produces:                            Produces:
  requirements     task graph          working software   Produces:         unified main
                                       + atomic commits   findings report
```

### 1. Draft — define the what

```
/bp:draft
```

You describe what you're building in natural language. Blueprint decomposes it into **domain blueprints** — structured documents with numbered requirements (R1, R2, ...) and testable acceptance criteria. Each blueprint is stack-independent and human-readable.

For existing codebases, `/bp:draft --from-code` reverse-engineers blueprints from your code and identifies gaps.

### 2. Architect — plan the order

```
/bp:architect
```

Reads all blueprints, breaks requirements into tasks, maps dependencies, and organizes everything into a **tiered build site** — a dependency graph where Tier 0 has no dependencies, Tier 1 depends only on Tier 0, and so on. This is what the build loop consumes.

### 3. Build — run the loop

```
/bp:build
```

The Ralph Loop. Each iteration:

```
  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │  Read build site → Find next unblocked task              │
  │       │                                                  │
  │       ▼                                                  │
  │  Load relevant blueprint + acceptance criteria           │
  │       │                                                  │
  │       ▼                                                  │
  │  Implement the task                                      │
  │       │                                                  │
  │       ▼                                                  │
  │  Validate (build + tests + acceptance criteria)          │
  │       │                                                  │
  │       ├── PASS → commit → mark done → next task ──┐     │
  │       │                                            │     │
  │       └── FAIL → diagnose → fix → revalidate      │     │
  │                                                    │     │
  │  ◄─────────────────────────────────────────────────┘     │
  │                                                          │
  │  Loop until: all tasks done OR iteration limit reached   │
  └──────────────────────────────────────────────────────────┘
```

With `--peer-review`, a second model (GPT-5.4 via Codex) reviews every implementation. The builder and reviewer alternate until both agree.

### 4. Inspect — verify the result

```
/bp:inspect
```

Gap analysis compares what was built against what was specified. Peer review checks for bugs, security issues, and missed requirements. Everything traced back to blueprint requirements.

### 5. Merge — integrate parallel work

```
/bp:merge
```

After parallel agents finish on separate branches, `/bp:merge` integrates them in dependency order — infrastructure first, then features, then UI. Conflicts are resolved using blueprint context, not line-by-line guessing.

---

## Quick Start

**Greenfield project:**

```
> /bp:draft
What are you building?

> A REST API for task management. Users, projects, tasks with priorities
  and due dates, assignments. PostgreSQL.

Created 4 blueprints (22 requirements, 69 acceptance criteria)
Next: /bp:architect

> /bp:architect
Generated build site: 34 tasks, 5 tiers
Next: /bp:build

> /bp:build
Loop activated — 34 tasks, 20 max iterations.
...
All tasks done. Build passes. Tests pass.
BLUEPRINT COMPLETE — 34 tasks in 18 iterations.
```

**Existing codebase:**

```
> /bp:draft --from-code
Exploring codebase... Next.js 14, Prisma, NextAuth.
Created 6 blueprints — 4 requirements are gaps (not yet implemented).

> /bp:architect --filter collaboration
Generated build site: 8 tasks, 3 tiers

> /bp:build
Loop activated — 8 tasks.
...
BLUEPRINT COMPLETE — 8 tasks in 8 iterations.
```

See [example.md](example.md) for full annotated conversations.

---

## Parallel Agents

The `blueprint` CLI launches multiple Claude Code agents in parallel — each on its own git worktree, each building a different part of the build site simultaneously.

```bash
blueprint --monitor              # interactive picker → agents in tmux
blueprint --monitor --expanded   # one tmux window per agent with dashboards
blueprint --status               # check progress from any terminal
blueprint --analytics            # iteration trends across cycles
blueprint --kill                 # stop everything, clean up worktrees
```

### How it works

The interactive picker shows all build sites grouped by status. Select the ones you want to launch. Each gets:

- Its own **git worktree** (branch: `blueprint/<site-name>`)
- A **tmux pane** running Claude Code with `/bp:build`
- Live status tracking with progress bars and commit feeds
- Staggered launch (5s between agents) to avoid API rate limits

### Expanded mode

In expanded mode (`--expanded`), each agent gets a full tmux window with three panes:

```
┌─────────────────────────────────┬──────────────────────┐
│                                 │  PROGRESS            │
│                                 │                      │
│   Claude Code                   │  Tasks: 12/34 (35%)  │
│   running /bp:build             │  Tier:  2 of 5       │
│                                 │  ████████░░░░░░ 35%  │
│                                 ├──────────────────────┤
│                                 │  ACTIVITY            │
│                                 │                      │
│                70%              │  [12:03] T-012 done  │
│                                 │  [12:01] T-011 done  │
│                                 │  [11:58] T-010 done  │
│                                 │          30%         │
└─────────────────────────────────┴──────────────────────┘
```

Switch between agents with `Ctrl-b <number>`.

### Analytics

`blueprint --analytics` parses loop logs across all cycles and worktrees:

- Iterations to convergence per cycle
- Task outcomes (done / partial / blocked)
- Failure patterns and dead ends
- Tier distribution and completion velocity

---

## Commands

### Claude Code slash commands

| Command | Phase | Description |
|---------|-------|-------------|
| `/bp:draft` | Draft | Decompose requirements into domain blueprints |
| `/bp:architect` | Architect | Generate a tiered build site from blueprints |
| `/bp:build` | Build | Run the Ralph Loop — implement, validate, commit, repeat |
| `/bp:inspect` | Inspect | Gap analysis + peer review against blueprints |
| `/bp:merge` | Ship | Blueprint-aware branch integration |
| `/bp:progress` | — | Check build site progress |
| `/bp:gap-analysis` | — | Compare built vs. intended |
| `/bp:revise` | — | Trace manual fixes back into blueprints |
| `/bp:help` | — | Show usage guide |

### CLI commands

| Command | Description |
|---------|-------------|
| `blueprint --monitor` | Interactive picker → parallel agents in tmux |
| `blueprint --monitor --expanded` | One window per agent with dashboards |
| `blueprint --status` | Check build site progress |
| `blueprint --analytics` | Iteration trends across cycles |
| `blueprint --kill` | Stop all agents, clean up worktrees |

---

## File Structure

```
context/
├── blueprints/           # Domain blueprints (persist across cycles)
│   ├── blueprint-overview.md
│   └── blueprint-{domain}.md
├── sites/                # Build sites (one per plan)
│   ├── build-site-*.md
│   └── archive/          # Completed sites
├── impl/                 # Implementation tracking
│   ├── impl-{domain}.md
│   ├── loop-log.md
│   └── archive/
└── refs/                 # Reference materials (PRDs, API docs)
```

---

## Methodology

Blueprint is built on a simple observation: LLMs are non-deterministic, but software engineering doesn't have to be. By applying the **scientific method** — hypothesize, test, observe, refine — we extract reliable outcomes from a stochastic process.

| Concept | Role |
|---------|------|
| **Blueprints** | The hypothesis — what you expect the software to do |
| **Validation gates** | Controlled conditions — build, tests, acceptance criteria |
| **Convergence loops** | Repeated trials — iterate until stable |
| **Implementation tracking** | Lab notebook — what was tried, what worked, what failed |
| **Revision** | Update the hypothesis — trace bugs back to blueprints |

The plugin ships with 13 deep-dive skills covering the full methodology:

<details>
<summary><strong>View all skills</strong></summary>

- **[Blueprint Writing](skills/blueprint-writing)** — how to write blueprints agents can consume
- **[Convergence Monitoring](skills/convergence-monitoring)** — detecting when iterations plateau
- **[Peer Review](skills/peer-review)** — six modes for cross-model review
- **[Validation-First Design](skills/validation-first)** — every requirement must be verifiable
- **[Context Architecture](skills/context-architecture)** — progressive disclosure for agent context
- **[Revision](skills/revision)** — tracing bugs upstream to blueprints
- **[Brownfield Adoption](skills/brownfield-adoption)** — adding Blueprint to an existing codebase
- **[Speculative Pipeline](skills/speculative-pipeline)** — overlapping phases for faster builds
- **[Prompt Pipeline](skills/prompt-pipeline)** — designing the prompts that drive each phase
- **[Implementation Tracking](skills/impl-tracking)** — living records of build progress
- **[Documentation Inversion](skills/documentation-inversion)** — docs for agents, not just humans
- **[Peer Review Loop](skills/peer-review-loop)** — combining Ralph Loop with cross-model review
- **[Core Methodology](skills/methodology)** — the full DABI lifecycle

</details>

---

## Why "Blueprint"

Most AI coding tools treat the agent as a black box — you prompt, it generates, you hope. Blueprint inverts this. **The specification is the product. The code is a derivative.** When the spec is clear, the code follows. When the code is wrong, the spec tells you why.

This matters because AI agents are getting better every month, but the fundamental problem remains: without a specification, there's nothing to validate against. Blueprint gives every agent — current and future — a contract to build from and a standard to meet.

---

## License

MIT
