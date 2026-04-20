---
name: ck-overview
description: "Document the current state of a codebase area — agent-optimized with Mermaid diagrams"
argument-hint: "<area or feature> [--wiki]"
---

# Cavekit Overview — Current State Documentation

Explore the codebase and produce an agent-optimized overview of the current implementation. Terse, structured, diagram-heavy. Output goes to `context/specs/` by default, or the sanetics wiki with `--wiki`.

This is a **pre-sketch** step. The overview provides context for the design conversation in `/ck:sketch`.

## Workspace root resolution

Before any substantive work, attempt to resolve the **workspace root**:

1. Start from the current working directory.
2. Walk upward through parent directories until you find one that contains all of these markers:
   - A `sanetics-wiki/` directory
   - A `setup.sh` file
   - A `.claude/` directory
3. If such an ancestor is found, remember its absolute path as `WORKSPACE_ROOT`. From the workspace root the wiki directory lives at `<WORKSPACE_ROOT>/sanetics-wiki/` and each sub-repo is a sibling (for example `<WORKSPACE_ROOT>/saneticscode/`, `<WORKSPACE_ROOT>/saniloop-aggregate/saniloop/`, `<WORKSPACE_ROOT>/claude-code/cavekit/`).
4. If no ancestor contains all three markers, `WORKSPACE_ROOT` is **unset** — the command was invoked outside a sanetics-workspace. Fall back to plain CWD behavior (no workspace-aware features).

Do not use environment variables or hardcoded absolute paths for workspace resolution. The workspace root is always discovered dynamically from the current working directory.

## Context selection

If `WORKSPACE_ROOT` is set, determine the **target sub-repo** before Step 1:

1. **Detect invocation location:** compare CWD to `WORKSPACE_ROOT`.
   - If CWD is inside a sub-repo (CWD is a descendant of `WORKSPACE_ROOT`), the enclosing sub-repo is the target automatically — do not prompt.
   - If CWD equals `WORKSPACE_ROOT`, you are at the workspace level (handled in step 2).
2. **Workspace-root invocation:** when CWD is the workspace root, check whether a target sub-repo was passed as an argument.
   - If a sub-repo name was passed (e.g. `saneticscode`, `saniloop-aggregate/saniloop`), resolve it as `<WORKSPACE_ROOT>/<name>` and use it as the target.
   - If no sub-repo argument was passed, list the sibling sub-repos under `WORKSPACE_ROOT` and prompt the user to pick one.
   - After selection, operate as if invoked from within the chosen sub-repo — read its codebase and read/write its `context/` directory.
3. **Cross-reference another sub-repo:** accept an optional reference to another sub-repo whose context should also be read. The reference is given by directory name relative to `WORKSPACE_ROOT`. When provided, resolve it as `<WORKSPACE_ROOT>/<reference>` and read `context/kits/`, `context/plans/`, `context/impl/` from **both** the target sub-repo and the referenced sub-repo.

If `WORKSPACE_ROOT` is unset, skip this section: the target is simply the CWD.

## Step 1: Wiki Routing

Parse `$ARGUMENTS` for the `--wiki` flag.

- **If `--wiki` is NOT present** → **local mode**. Use `context/` paths under the target sub-repo (or CWD if `WORKSPACE_ROOT` is unset). Do not read any wiki routing document.
- **If `--wiki` IS present** → read and follow the wiki routing document. Do not inline any routing procedure details here — the document is the source of truth for project discovery, PR sync, Grav front matter, and auto-commit.
  - If `WORKSPACE_ROOT` is set, prefer `<WORKSPACE_ROOT>/.claude/wiki-routing.md` (accessible from any sub-repo via the `.claude` symlink as `.claude/wiki-routing.md`).
  - Otherwise, fall back to `"${CLAUDE_PLUGIN_ROOT}/references/wiki-routing.md"`.

## Step 2: Explore

1. Read and explore relevant files — do not make assumptions about the architecture
2. **Related docs** (wiki mode): list subfolders in the project folder and read existing specs. Also skim the full sanetics wiki — all eight top-level sections (`01.home` through `08.projects`) — for pages relevant to the area being documented. See the "Wiki sections" table in wiki routing reference section 6.
3. Trace architecture: identify components, layers, data flow, domain model
4. Check for existing specs in the project folder that inform the overview

## Step 3: Write Overview

Write the overview in **kit-style format** — terse, no prose paragraphs, no narrative transitions. Diagrams come early and often.

### Required sections (in order):

1. **Context** — 1-2 sentences. What area this covers and why.
2. **Architecture** — **required** Mermaid diagram(s). Start with a component/flowchart showing layers and relationships. Follow diagram rules in wiki routing reference section 7. All diagrams use ` ```mermaid ` fenced code blocks — the diagram type keyword (`flowchart`, `classDiagram`, `sequenceDiagram`, etc.) is the first line *inside* the block, not the language tag:
   - Component/architecture → `flowchart TD/LR` inside the block
   - Domain model → `classDiagram` inside the block (always include if entities/aggregates are involved)
   - Runtime flow → `sequenceDiagram` inside the block
   - Branching logic → `flowchart TD` inside the block
   - Multiple diagrams per section encouraged — each adds a different angle
3. **Domain Concepts** — table: Term, Current meaning, Change (or "unchanged"). Cross-reference wiki domain section if it exists.
4. **Key Files** — table: Layer, File, Role. Real files from the codebase.
5. **Data Flow** — Mermaid sequence diagram for the critical path. Omit if trivial.
6. **Business Rules** — table: #, Rule. As currently implemented.
7. **Before / After** — table: Aspect, Current, After. Only when a change is planned and a spec exists. Pair with Before/After Mermaid diagrams — same type, same scope, visually comparable.
8. **Affected Files** — table: File, Change. Only when a change is planned.
9. **Design Decisions** — table: #, Decision, Rationale (1 clause). Decisions already made about this area.
10. **Open Questions** — table: #, Question, Context.

Omit sections that don't apply. Don't force empty sections.

### Front matter

**Wiki mode:**
```yaml
---
title: '<Topic> (Overview)'
template: doc
taxonomy:
    product: [<product from project chapter.md>]
    category: [project]
published: true
visible: true
created: "<ISO 8601 UTC>"
last_edited: "<ISO 8601 UTC>"
---
```

**Local mode:**
```yaml
---
created: "<ISO 8601 UTC>"
last_edited: "<ISO 8601 UTC>"
---
```

## Step 4: Write Path

**Wiki mode:**
- Create subfolder: `<wiki-project>/02.YYYY-MM-DD-HHmm-overview-<topic-slug>/`
- Write file inside: `overview-<topic-slug>.md`
- If subfolder already exists, append `-2`, `-3`, etc.

**Local mode:**
- Write to `context/specs/YYYY-MM-DD-overview-<topic-slug>.md`
- Create directory if needed

## Step 5: Finalize

1. Print the file path on completion
2. **Auto-commit** (wiki mode only): follow auto-commit procedure in wiki routing reference section 5

## What an overview covers

- The current state of the relevant area — structure, components, data flow, domain model
- The before/after impact of a planned change, when applicable

## What an overview is NOT

- Not a feature specification — use `/ck:spec` for that
- Not an effort estimate — use `/ck:scope` for that
- Not a technical plan — use `/ck:sketch` → `/ck:map` for that

## Area / Feature to Document

$ARGUMENTS
