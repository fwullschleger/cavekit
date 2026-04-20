---
name: ck-spec
description: "Write an agent-optimized feature specification — guided interview, business-facing, kit-style density with Mermaid diagrams"
argument-hint: "<topic> [<REFS_PATH>] [--wiki]"
---

# Cavekit Spec — Feature Specification

Write an agent-optimized feature specification through a guided interview. Terse output, structured, token-efficient. All diagrams are Mermaid. Output goes to `context/specs/` by default, or the sanetics wiki with `--wiki`.

This is a **pre-sketch** step. The spec captures business intent (WHAT and WHY) and informs the design conversation in `/ck:sketch`.

**HARD GATE:** Do NOT write the spec file until the framing and every section have been walked through with the user and approved. This applies to every spec regardless of perceived simplicity. A small feature, a single-actor flow, a config change — all of them go through the guided interview. The interview can be short for simple topics, but you MUST present framings and walk sections before writing.

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

If `WORKSPACE_ROOT` is set, determine the **target sub-repo** before Step 0:

1. **Detect invocation location:** compare CWD to `WORKSPACE_ROOT`.
   - If CWD is inside a sub-repo (CWD is a descendant of `WORKSPACE_ROOT`), the enclosing sub-repo is the target automatically — do not prompt.
   - If CWD equals `WORKSPACE_ROOT`, you are at the workspace level (handled in step 2).
2. **Workspace-root invocation:** when CWD is the workspace root, check whether a target sub-repo was passed as an argument.
   - If a sub-repo name was passed (e.g. `saneticscode`, `saniloop-aggregate/saniloop`), resolve it as `<WORKSPACE_ROOT>/<name>` and use it as the target.
   - If no sub-repo argument was passed, list the sibling sub-repos under `WORKSPACE_ROOT` and prompt the user to pick one.
   - After selection, operate as if invoked from within the chosen sub-repo — read its codebase and read/write its `context/` directory.
3. **Cross-reference another sub-repo:** accept an optional reference to another sub-repo whose context should also be read. The reference is given by directory name relative to `WORKSPACE_ROOT`. When provided, resolve it as `<WORKSPACE_ROOT>/<reference>` and read `context/specs/` and `context/kits/` from **both** the target sub-repo and the referenced sub-repo.

If `WORKSPACE_ROOT` is unset, skip this section: the target is simply the CWD.

## Step 0: Resolve Execution Profile

Before doing any substantive work:

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" summary` and print that exact line once.
2. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" model exploration` and store it as `EXPLORATION_MODEL`.
3. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" model reasoning` and store it as `REASONING_MODEL`.
4. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" caveman-active draft` and treat the result as `CAVEMAN_ACTIVE` (true/false). Spec phase is NOT in the default caveman_phases, so this will typically be false. If true, apply caveman-speak to research agent prompts and internal summaries only — never to spec content, user-facing questions, or stakeholder-visible output.

Keep the user Q&A in the parent thread. Use `EXPLORATION_MODEL` for helper exploration/research and `REASONING_MODEL` for spec review.

## Step 0b: Wiki Routing

Parse `$ARGUMENTS` for the `--wiki` flag.

- **If `--wiki` is NOT present** → **local mode**. Use `context/` paths under the target sub-repo (or CWD if `WORKSPACE_ROOT` is unset). Do not read any wiki routing document.
- **If `--wiki` IS present** → read and follow the wiki routing document. Do not inline any routing procedure details here — the document is the source of truth for project discovery, PR sync, Grav front matter, and auto-commit.
  - If `WORKSPACE_ROOT` is set, prefer `<WORKSPACE_ROOT>/.claude/wiki-routing.md` (accessible from any sub-repo via the `.claude` symlink as `.claude/wiki-routing.md`).
  - Otherwise, fall back to `"${CLAUDE_PLUGIN_ROOT}/references/wiki-routing.md"`.

Store the resolved mode and project path for use in later steps.

## Determine Mode

Parse `$ARGUMENTS`:
- If a path is given (not a flag) → **Refs mode** (use reference material at that path — customer interviews, PRD drafts, market notes, existing overview docs — as source material for the interview)
- Otherwise → **Interactive mode** (collaborative interview, the default)

There is no `--from-code` mode. A spec describes business intent, not current system state; use `/ck:overview` to document existing code.

## Step 1: Ensure Directories Exist

**Wiki mode:** The spec subfolder will be created later under the resolved wiki project (`<wiki-project>/01.YYYY-MM-DD-HHmm-spec-<slug>/`). Ensure the project folder exists per the wiki routing document.

**Local mode:** Create `context/specs/` if missing.

## Step 2: Explore Project Context

Before asking ANY questions, understand what already exists. **Do NOT explore the codebase by default** — a spec captures intent, not current-state reverse-engineering. Light context only:

1. **Existing specs** — list `context/specs/` (local) or the wiki spec subfolders for this project and scan titles. Note any specs on overlapping topics.
2. **Existing overviews and kits** — a prior `/ck:overview` or `/ck:sketch` gives domain vocabulary you should reuse. Scan titles, read only if clearly relevant.
3. **Diagram guidance** — before producing any diagrams later, read the diagram type catalog, selection criteria, Mermaid format conventions:
   - If `WORKSPACE_ROOT` is set, read `<WORKSPACE_ROOT>/.claude/diagram-guidance.md`.
   - Otherwise, use Mermaid conventions already described in this command.
4. **(If `WORKSPACE_ROOT` is set)** Skim the full sanetics wiki for context relevant to the spec topic — all eight top-level sections under `<WORKSPACE_ROOT>/sanetics-wiki/pages/` (`01.home` through `08.projects`). See the "Wiki sections" table in the wiki routing reference (section 6) for each section's contents and when it matters. Read titles and lead paragraphs first; open in full only the pages topically relevant to the current spec topic — typically that will include pages from `02.domain` (vocabulary), `04.decisions` (constraints), and `08.projects` (overlap with prior work), but do not restrict yourself to those up front.
5. **(If `WORKSPACE_ROOT` is set)** Check for an existing project folder that matches the target sub-repo's current branch (see wiki routing document for the discovery heuristic). If one exists, its `chapter.md` and any prior specs/overviews inform the interview.
6. **Refs mode only:** read all files at the given path (or all files in the directory if a directory was given). These are the source of truth for the interview — do not ignore them.
7. **Opt-in codebase context:** If the spec concerns an existing system and the user explicitly indicates technical context would help, dispatch one helper exploration subagent with `model: "{EXPLORATION_MODEL}"` to produce a short summary. Do NOT do this by default.

## Step 3: Guided Interview

This is a **collaborative interview**. Follow these steps in order.

### 3a: Offer Visual Companion

Before substantive questions, offer the visual companion. This MUST be its own message — do not combine it with any other content:

> "Some of what we're working on might be easier to see than read — mockups, flow diagrams, side-by-side comparisons, state charts. I can put these together in a local web browser as we go. Want to try it? (Opens a local URL)"

Wait for the user's response. If they decline, proceed text-only. If they accept, read `"${CLAUDE_PLUGIN_ROOT}/references/visual-companion.md"` (or the workspace equivalent) for the detailed guide. The server lives in `scripts/visual-companion/`.

**Per-question decision:** Even after the user accepts, decide FOR EACH QUESTION whether to use the browser or the terminal. The test: **would the user understand this better by seeing it than reading it?**
- **Use the browser** for: user-flow mockups, state charts, domain-model sketches, before/after visual comparisons, multi-actor sequence diagrams
- **Use the terminal** for: requirements questions, conceptual choices, tradeoff lists, scope decisions

### 3b: Scoping Questions

Ask **1–2 initial questions** to understand the feature's purpose and scope. These are high-level.

- Prefer **multiple choice** when possible
- Focus on: **what** this feature is, **who** it's for, **why now**
- Open-ended is fine when the topic needs exploration

**Scope check:** If the request describes multiple independent features (e.g., "patient intake, medication plan editor, and reporting dashboard"), flag this immediately. Help the user split into separate specs — one topic per spec. Each gets its own interview.

### 3c: Check for Existing Research Brief

After scoping, check for an existing research brief:

1. Look in `context/refs/` for `research-brief-*.md` files relevant to this topic.
2. If a **fresh brief exists** (check the `Generated:` date): `Found research brief: research-brief-{topic}.md ({age} ago). Use it? [Y/n/rerun]`
   - **Y**: Load the brief, skip to 3e
   - **n**: Ignore the brief, skip to 3e
   - **rerun**: Run fresh research (3d)
3. If no brief exists, assess whether research is warranted. Research is **opt-in** for specs — most specs don't need it:
   - Research IS worth offering when: the topic involves regulatory/compliance specifics the user may not fully know, competitive landscape is relevant, or there's a significant unknowns on the domain side.
   - Research is NOT worth offering when: the topic is well-defined by the user, is a small change, or the user has provided comprehensive reference materials.
4. If research is warranted, prompt: `This spec touches {topics} that could benefit from a quick research pass. Run it? [y/N]` — default to **N**. If Y, proceed to 3d.

### 3d: Research Phase (opt-in)

If research was triggered, run the deep research pipeline. Generate a topic slug (kebab-case, 2–4 words).

Follow the same research pipeline used by `/ck:sketch` (wave 1 codebase + web; wave 2 best-practices + pitfalls; synthesizer). **Exception:** the synthesizer is told to produce a **business-facing** brief — no library choices, no architecture recommendations, no implementation suggestions. Findings should be about the *domain*, *regulations*, *competitive landscape*, and *user expectations*.

Write the brief to `context/refs/research-brief-{topic}.md` and present a 3–5 bullet summary.

### 3e: Clarifying Questions — One at a Time

Continue asking questions **one at a time** to fill in the spec picture. Do NOT dump multiple questions in a single message.

- Prefer **multiple choice** when possible
- Focus sequentially on: **Actors** (who) → **Triggers and Use Cases** (when and what flows) → **Business Rules** (invariants and constraints) → **Data** (what information must be captured or produced) → **Success criteria** (how we know it works) → **Known decisions** (choices already made, with rationale) → **Open questions** (what's still unresolved, with owner)

**If research was done**, use findings to inform questions — open questions from the brief become clarifying questions; findings inform multiple-choice options; don't re-ask what research already answered.

Continue until you have a clear picture of:
- Who the actors are and what each one does
- The key use cases (trigger → flow → target state)
- The business rules that must hold
- What data is created, read, or changed (entities and attributes)
- What success looks like
- What's out of scope

### 3f: Propose 2–3 Framings

Before drafting the spec, propose **2–3 framings** of the feature with tradeoffs — this is intent-level, not architecture:

- Lead with your **recommended** framing and explain why
- Express tradeoffs in **business terms**: stakeholder reach, effort, time-to-value, risk, compliance burden — not technical terms like coupling or performance
- Be ready to combine elements from different framings based on feedback

Typical framings:

> **Minimal (recommended?):** The smallest version that delivers value. One actor, one flow, the narrowest business-rule set.
>
> **Core:** The default version most stakeholders picture. Primary actors, main happy-path flows, clear invariants.
>
> **Ambitious:** Broader reach, secondary actors, edge-case flows, additional reporting or admin surfaces.

Adapt the framings to the specific topic. The labels are a starting point, not a template — if Minimal/Core/Ambitious doesn't fit, propose better ones.

### 3g: Present Spec Section by Section

Once the user picks a framing, walk the spec **section by section**, building content and diagrams live to confirm understanding. Scale each section to its complexity.

Order:
1. **Actors** — present the table; ask "Does this cover everyone who interacts with this feature?"
2. **Domain Concepts** — table of terms and definitions; reuse wiki vocabulary where present.
3. **Use Cases** — one subsection per use case: trigger, target states, rules. For each use case, render a **live Mermaid flowchart or sequence diagram** during the discussion. Ask after each: "Does this look right?"
4. **Business Rules** — table; confirm each is an invariant/constraint, not an action.
5. **Requirements** — propose S-numbered bullets derived from actors × use cases × business rules. Ask the user to confirm coverage.
6. **Decisions** — table with rationale; surface any decisions made implicitly during 3e and ask for rationale.
7. **Data Requirements** — only if schema-level changes are implied; table of entity / attributes / type (business-term types — "email address", "date of birth" — not SQL types).
8. **Open Questions** — table with owner; confirm each blocker has a named owner.
9. **Out of Scope** — bullet list; confirm this is what the user wants excluded.

Only move to the next section when the current one is approved. Be ready to revise.

**Diagram building rules during 3g:**
- Build diagrams live, not as a post-hoc dump
- Pick the best type for the concern:
  - State transitions → `stateDiagram-v2`
  - User flow or decision logic → `flowchart TD`
  - Domain model → `classDiagram`
  - Multi-actor interaction → `sequenceDiagram`
- Multiple diagrams for the same area are encouraged when each adds a different angle
- All diagrams use ` ```mermaid ` fenced code blocks — the diagram type keyword is the first line *inside* the block, not the language tag

**YAGNI ruthlessly:** Remove requirements, use cases, and actors the user didn't ask for. If you're tempted to add "nice to have" items, don't. Smaller specs are better specs.

## Step 4: Write Spec

**Only after the user approves the framing AND every section walked in 3g**, write the spec file.

Write the spec in **kit-style format** — terse, no prose paragraphs, no narrative transitions.

### Required sections (in order):

1. **Context** — 1–2 sentences. What and why. Include task/ticket references if applicable.
2. **Domain Concepts** — table: Term, Definition. Reference wiki domain section if concepts already documented there.
3. **Actors** — table: Actor, Action.
4. **Diagrams** — required, not optional. All diagrams from the 3g walkthrough land here. All diagrams use ` ```mermaid ` fenced code blocks — the diagram type keyword is the first line *inside* the block, not the language tag. Follow diagram rules in wiki routing reference section 7 (wiki mode).
5. **Use Cases** — one subsection per use case. Each with: trigger (1 line), target states table, rules as bullet list.
6. **Requirements** — S-numbered bullet list (S1, S2, S3…).
7. **Business Rules** — table: #, Rule.
8. **Decisions** — table: #, Decision, Rationale (1 clause).
9. **Data Requirements** — table: Entity, Attributes, Type. Only if schema changes are involved.
10. **Open Questions** — table: #, Question, Owner.
11. **Out of Scope** — bullet list.

Omit sections that don't apply, but always include **Out of Scope**. Don't force empty sections.

### Front matter

**Wiki mode:**
```yaml
---
title: '<Topic> (Specification)'
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

### Write Path

**Wiki mode:**
- Create subfolder: `<wiki-project>/01.YYYY-MM-DD-HHmm-spec-<topic-slug>/`
- Write file inside: `spec-<topic-slug>.md`
- If the subfolder already exists, append `-2`, `-3`, etc.

**Local mode:**
- Write to `context/specs/YYYY-MM-DD-spec-<topic-slug>.md`
- Create the directory if needed

## Step 5: Spec Review Loop

After writing the spec, dispatch a **spec-reviewer** subagent to verify quality:

```
Agent tool (subagent_type: "ck:spec-reviewer", model: "{REASONING_MODEL}"):
  description: "Review feature specification"
  prompt: |
    You are a spec reviewer. Verify this specification is complete, unambiguous,
    and ready to hand off to a technical colleague who will run /ck:sketch against it.

    **Spec to review:** {resolved spec file path}

    See your agent instructions for the full review criteria and output format.
```

**Review loop rules:**
- If **Approved**: proceed to Step 6
- If **Issues Found**: fix the issues, re-dispatch the reviewer
- Maximum **3 iterations** — if still not passing, present remaining issues to the user for guidance

## Step 6: User Review Gate

After the review loop passes, ask the user to review the spec:

> "Spec written and reviewed. File is at `{resolved spec path}`. Please review it and let me know if you want any changes before we finalize."

Wait for the user's response. If they request changes, make them and re-run Step 5. Only proceed once the user approves.

**Auto-commit (wiki mode only):** After the user approves, follow the auto-commit procedure in wiki routing reference section 5. Stage the new spec subfolder (and `chapter.md` if a new project was created).

## Step 7: Finalize

Print the file path(s) on completion.

## Step 8: Spec Report and Transition

Present a report:

```markdown
## Spec Report

### Actors: {count}
### Use Cases: {count}
### Requirements: {count} (S1–S{N})
### Business Rules: {count}
### Decisions: {count}
### Open Questions: {count} (blockers: {count})
### Diagrams: {count}

### Open Questions / Owners
- #{N}: {question} — owner: {owner}

### Next Step
Hand off to a technical colleague. They can run `/ck:sketch {resolved spec path}` (refs mode) to translate this intent into domain kits.
```

Present the report. When the user is ready, they can transition to `/ck:sketch`.

---

## Key Principles

- **One question at a time** — do not overwhelm with multiple questions
- **Multiple choice preferred** — easier to answer than open-ended when possible
- **Business voice** — vocabulary the stakeholder uses; no implementation leakage
- **YAGNI ruthlessly** — remove unrequested actors, use cases, and requirements
- **Explore framings** — always propose 2–3 intent-level framings before drafting
- **Incremental validation** — walk sections one by one, get approval before moving on
- **Diagrams live** — build diagrams during the interview, not as a post-hoc dump
- **No spec writing before section-by-section approval** — the interview IS the value

## What a spec is NOT

- Not a technical plan — use `/ck:sketch` → `/ck:map` for that
- Not an implementation guide — no file paths, no framework choices, no library names
- Not an overview of current state — use `/ck:overview` for that
- Not a multi-feature umbrella — one topic per spec; split if scope is too broad

## Topic

$ARGUMENTS
