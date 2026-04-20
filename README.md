<h1 align="center">cavekit</h1>

<p align="center">
  <strong>compressed spec-driven development for claude code</strong><br/>
  <sub>one file · three commands · zero sub-agents</sub>
</p>

---

## what this is

Plan-then-execute forgets. SDD remembers — but most SDD frameworks bury
that value under agent swarms, dashboards, and ceremony that costs more
tokens than it saves.

Cavekit 4 is a rewrite from the ground up. It keeps only what earns its
place:

- **durable spec** — `SPEC.md` at repo root survives context resets.
- **caveman encoding** — ~75% fewer tokens than prose. Symbols, fragments,
  pipe tables for repeating records.
- **backprop reflex** — every test failure becomes a `§B` entry; classes
  of bug become `§V` invariants the spec never forgets.

That's the whole pitch.

## commands

| cmd | job |
|---|---|
| `/ck:spec` | create / amend / backprop `SPEC.md`. Sole mutator. |
| `/ck:build` | native plan → execute against spec. Auto-backprops on failure. |
| `/ck:check` | read-only drift report. Lists §V / §I / §T violations. |

## install

One line, via the `skills` CLI — installs commands and skills together:

```bash
npx skills add JuliusBrussee/cavekit
```

Drops `/ck:spec`, `/ck:build`, `/ck:check` into `~/.claude/commands/` and
the `caveman` + `backprop` skills into `~/.claude/skills/`. Claude Code
picks them up on next launch.

Or via the Claude Code marketplace:

```bash
/plugin marketplace add juliusbrussee/cavekit
/plugin install ck@cavekit
```

Or clone directly:

```bash
git clone https://github.com/juliusbrussee/cavekit.git ~/.claude/plugins/cavekit
```

## format

See [`FORMAT.md`](./FORMAT.md). Fixed sections: §G goal, §C constraints,
§I interfaces, §V invariants, §T tasks (pipe table), §B bugs (pipe table).

## files

```
FORMAT.md             spec schema + caveman encoding rules
commands/             three markdown command prompts
skills/caveman        encoding skill
skills/backprop       bug → spec protocol (six steps)
```

## non-goals

- no sub-agents. Main Claude does the work.
- no dashboards. `cat SPEC.md` is the dashboard.
- no parallel workers. One thread, one spec, one diff.
- no JSON / YAML spec bodies. Markdown + pipe tables.
- no hooks, no orchestration binaries, no TypeScript helpers.

---

## older cavekit (the Hunt lifecycle, v3.1.0 and earlier)

The previous generation is **not deprecated** — it is frozen at tag
[`v3.1.0`](https://github.com/juliusbrussee/cavekit/tree/v3.1.0) and
remains a fully working plugin.

**What it is**:

> Spec-driven AI development with an autonomous execution loop. Four-command
> Hunt lifecycle (`/ck:sketch` → `/ck:map` → `/ck:make` → `/ck:check`),
> plus `/ck:ship`, `/ck:review`, `/ck:revise`, `/ck:status`, `/ck:design`,
> `/ck:research`, `/ck:init`, `/ck:config`, `/ck:resume`, `/ck:help` — 16
> slash commands total. 12 named sub-agents. Per-task token budgets,
> stop-hook state machine, model-tier routing, auto-backpropagation from
> test failures, tool-result caching, Codex peer review, Karpathy
> behavioral guardrails, caveman token compression, knowledge-graph
> integration, and design-system enforcement. Parallel wave execution and
> team mode.

**Pick v3.1.0** if you want the full autonomous loop, parallel agents,
peer review, or design-system workflow. **Pick v4** if you want the
distilled core — one spec, three commands, no orchestration.

### install the older version

Marketplace:

```bash
/plugin marketplace add juliusbrussee/cavekit@v3.1.0
/plugin install ck@cavekit
```

Git:

```bash
git clone -b v3.1.0 https://github.com/juliusbrussee/cavekit.git
```

Full docs live at the tag — `git checkout v3.1.0` and read the README
there for command reference, skill catalog, and the Hunt lifecycle guide.

### choosing, or moving

See [`UPGRADE.md`](./UPGRADE.md). Honest framing:
- Stay on v3.1.0 if your project has active `context/kits/` investment.
- Move to v4 if you want fewer moving parts and smaller token bills.
- It is a **two-way door** — `SPEC.md` is plain markdown; nothing traps
  you in either direction.

## philosophy

> The spec is the only artifact that earns its tokens. Everything else
> that costs tokens must either save more tokens later, or the user's
> attention, or it gets cut.

See [`CHANGELOG.md`](./CHANGELOG.md) for the full v3 → v4 break.

## license

MIT.
