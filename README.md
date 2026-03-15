# SDD — Spec-Driven Development

Claude Code plugin + parallel agent launcher for spec-driven development with automated iteration loops.

## Install

```bash
git clone https://github.com/JuliusBrussee/sdd-os.git ~/.sdd
cd ~/.sdd
./install.sh
```

This will:
1. Register the SDD plugin with Claude Code
2. Install the `sdd` CLI command globally
3. Make all scripts executable

## Terminal: parallel agent launcher

```bash
sdd --monitor                     # interactive picker → launch agents in tmux
sdd --monitor --expanded          # one tmux window per agent with dashboards
sdd --status                      # check progress from any terminal
sdd --analytics                   # trends across cycles
sdd --kill                        # stop everything, clean up worktrees
```

### Default mode (`--monitor`)

Interactive multi-select picker shows all frontiers:
- **Available** — ready to launch (pre-selected)
- **In Progress** — select to resume from existing worktree
- **Done** — struck through (archived frontiers)

Selected frontiers each get:
- Their own **git worktree** (branch: `sdd/<frontier-name>`)
- A **tmux pane** running Claude Code with `/sdd:execute`
- Auto-layout: horizontal for 2-3 agents, tiled for 4+
- Live status bar showing per-frontier progress

Staggered launch (5s between agents) to avoid API rate limits.

### Expanded mode (`--monitor --expanded`)

One tmux window per frontier with the full 3-pane layout:
- **Left (70%)** — Claude Code running `/sdd:execute`
- **Top-right** — live progress: tasks done, tiers, progress bar
- **Bottom-right** — live activity: iteration log, git commits

Switch between windows with `Ctrl-b <number>`.

### Analytics (`--analytics`)

Parses loop logs across all cycles and worktrees:
- Iterations to convergence per cycle
- Task outcomes (done/partial/blocked)
- Failure patterns and dead ends
- Tier distribution
- Completion velocity (tasks/iteration, success rate)

## Claude: slash commands

```
/sdd:brainstorm    →  write specs (the WHAT)
/sdd:plan          →  generate frontier (the ORDER)
/sdd:execute       →  ralph loop (the BUILD)
/sdd:review        →  gap analysis + adversarial review (the CHECK)
/sdd:merge         →  spec-aware branch integration (the SHIP)
```

### 1. Brainstorm — write specs

```bash
/sdd:brainstorm                    # interactive — asks what to build
/sdd:brainstorm context/refs/      # from PRDs, API docs, research
/sdd:brainstorm --from-code        # from existing codebase
```

Decomposes your project into domains. Each domain gets a spec with R-numbered requirements and testable acceptance criteria.

### 2. Plan — generate frontier

```bash
/sdd:plan                          # all specs
/sdd:plan --filter v2              # only v2 specs
```

Reads specs, breaks requirements into tasks, maps dependencies, organizes into tiers.

### 3. Execute — run the loop

```bash
/sdd:execute                       # implement everything
/sdd:execute --adversarial         # add Codex (GPT-5.4) review
/sdd:execute --max-iterations 30
```

Each iteration: read frontier → find next unblocked task → read spec → implement → validate → commit → loop.

### 4. Review — post-loop check

```bash
/sdd:review                        # gap analysis + adversarial review
```

### 5. Merge — spec-aware branch integration

```bash
/sdd:merge                         # merge all sdd/* branches into main
```

After parallel execution, each frontier lives on its own `sdd/<name>` branch. `/sdd:merge` integrates them back into main:

1. Surveys all branches — commits, file overlaps, dependency order
2. Reads the **specs and impl tracking** for each branch
3. Merges in order: infrastructure → features → UI
4. Resolves conflicts by understanding what each spec intended — **keeps all features from all branches**
5. Validates after each merge (build, tests, spec requirements)
6. Cleans up worktrees and branches

## File structure

```
context/
├── specs/              # Specs (persist across cycles)
│   ├── spec-overview.md
│   └── spec-{domain}.md
├── frontiers/          # Feature frontiers (one per plan)
│   ├── feature-frontier-ui-v2.md
│   ├── plan-connector-port-frontier.md
│   └── archive/        # Completed frontiers
├── impl/               # Progress (archived between cycles)
│   ├── impl-{domain}.md
│   ├── loop-log.md
│   └── archive/
└── refs/               # Reference materials
```

## All commands

| Command | Description |
|---------|-------------|
| **`/sdd:brainstorm`** | Write specs |
| **`/sdd:plan`** | Generate feature frontier |
| **`/sdd:execute`** | Ralph Loop implementation |
| **`/sdd:review`** | Gap analysis + adversarial review |
| **`/sdd:merge`** | Spec-aware branch integration |
| `/sdd:progress` | Check frontier progress |
| `/sdd:gap-analysis` | Compare built vs intended |
| `/sdd:back-propagate` | Trace manual fixes to specs |
| `/sdd:help` | Show usage |

| CLI | Description |
|-----|-------------|
| `sdd --monitor` | Interactive picker → parallel agents in tmux |
| `sdd --monitor --expanded` | One window per agent with dashboards |
| `sdd --status` | Check frontier progress |
| `sdd --analytics` | Trends across cycles |
| `sdd --merge` | Shows branches ready to merge (use `/sdd:merge` in Claude) |
| `sdd --kill` | Stop all agents, clean worktrees |

## Example

See [example.md](example.md) for full sample conversations.

## License

MIT
