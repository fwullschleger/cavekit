---
name: ck-research
description: "Deep research for grounding kits in evidence — current best practices, library landscape, and codebase analysis"
argument-hint: "<description> [--depth quick|standard|deep] [--web-only] [--codebase-only] [--wiki-only] [--skip-wiki]"
---

> **Note:** `/bp:research` is deprecated and will be removed in a future version. Use `/ck:research` instead.

# Cavekit Research — Deep Multi-Agent Research

Run parallel multi-agent research to ground cavekit design in real evidence. Produces a named research brief in `context/refs/` that feeds into cavekit design.

**Core insight:** Kits designed without research are kits designed on vibes. Research turns the design conversation from "what do you want?" into "here's what we know — what do you want?"

## Parse Arguments

Extract from `$ARGUMENTS`:
- `description` — what you're building (everything that isn't a flag). **Required.**
- `--depth` — `quick`, `standard` (default), or `deep`
- `--web-only` — run only web research (skip codebase + wiki)
- `--codebase-only` — run only codebase research (skip web + wiki)
- `--wiki-only` — run only wiki research (skip codebase + web)
- `--skip-wiki` — include codebase and web, skip wiki (useful when deliberately ignoring prior internal art)

Flag precedence: the `-only` flags are mutually exclusive; if the user passes more than one, stop and ask which source they want. Otherwise, all three sources run by default when available. The wiki source is automatically unavailable (and silently skipped) if the workspace root can't be resolved — see Step 0b.

If no description is provided, ask: "What are you building? (One sentence is enough)" and wait.

Generate a **topic slug** from the description — kebab-case, 2-4 words. Example: "Build a Verse compiler targeting WASM" → `verse-compiler`. "Add real-time collaboration" → `realtime-collab`.

## Step 0: Resolve Execution Profile

Before dispatching any research agents:

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" summary` and print that exact line once.
2. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" model exploration` and treat the result as `EXPLORATION_MODEL`.
3. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/bp-config.sh" model reasoning` and treat the result as `REASONING_MODEL`.

Use `EXPLORATION_MODEL` for codebase/web/wiki researchers and `REASONING_MODEL` for the synthesizer.

## Step 0b: Resolve Wiki Availability

Before planning waves, decide whether the wiki source is available.

1. Starting from CWD, walk upward through parent directories looking for a single ancestor that contains **all** of these markers:
   - A `sanetics-wiki/` directory
   - A `setup.sh` file
   - A `.claude/` directory
2. If found, store its absolute path as `WORKSPACE_ROOT` and set `WIKI_AVAILABLE=true`. The wiki lives at `<WORKSPACE_ROOT>/sanetics-wiki/`.
3. If not found, set `WIKI_AVAILABLE=false` and silently skip all wiki-wave steps. Do **not** error — research proceeds with codebase + web only. If the user explicitly passed `--wiki-only`, stop and report: "Wiki source requested but no sanetics-workspace ancestor detected — run from inside a sanetics-workspace checkout."
4. If the user passed `--skip-wiki`, set `WIKI_AVAILABLE=false` regardless of detection.

Do not use environment variables or hardcoded paths. Resolution is always dynamic from CWD.

## Step 1: Assess Project Size

Quickly count source files (exclude `node_modules`, `.git`, `dist`, `build`, `vendor`, `__pycache__`, `.next`, `.nuxt`):

```bash
find . -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.rs' -o -name '*.go' -o -name '*.java' -o -name '*.rb' -o -name '*.swift' -o -name '*.kt' \) -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/vendor/*' -not -path '*/__pycache__/*' -not -path '*/.next/*' | wc -l
```

Map to project category:

| File count | Category | Codebase agents (standard) |
|-----------|----------|---------------------------|
| 0 (or `--web-only`) | Greenfield | 0 |
| 1–20 | Small | 1 (covers all categories) |
| 21–200 | Medium | 2 |
| 201+ | Large | 3–4 |

### Depth Adjustments

| Depth | Codebase agents | Web agents | Searches per question |
|-------|----------------|------------|----------------------|
| `quick` | min(1, adaptive) | 2 | 1 |
| `standard` | adaptive (table above) | 3 | 2–3 |
| `deep` | max(4, or 0 if greenfield) | 4 | exhaustive, follow cross-references |

## Step 2: Generate Research Plan

### Fixed Categories

**Codebase categories** (skip if greenfield or `--web-only`):

| Category | What to investigate |
|----------|-------------------|
| Architecture | Directory structure, module boundaries, entry points, build system, framework versions |
| Patterns | Coding conventions, error handling, naming, state management, abstractions in use |
| Dependencies | Package manifests, external APIs, integration points, version constraints |
| Test infrastructure | Test framework, coverage setup, fixtures, CI config, tested vs. untested areas |

**Web categories** (skip if `--codebase-only`, `--wiki-only`):

| Category | What to investigate |
|----------|-------------------|
| Library landscape | Libraries/tools for the core problem domain |
| Best practices | Current architectural patterns, security, performance |
| Existing art | How others solved similar problems, reference implementations |
| Pitfalls | Known issues, common mistakes, deprecated approaches |

**Wiki categories** (skip if `WIKI_AVAILABLE=false`, `--codebase-only`, or `--web-only`):

The wiki has eight top-level sections under `<WORKSPACE_ROOT>/sanetics-wiki/pages/`. Consider **all** of them — relevance depends on the research topic, not a fixed shortlist.

| Category | What to investigate | Source paths |
|----------|---------------------|--------------|
| Home / orientation | Workspace entry points, high-level context a newcomer would need | `01.home/**/*.md` |
| Domain precedent | Ubiquitous language, domain models, business concepts already defined | `02.domain/**/*.md` |
| Architecture | ERDs, system design, target state, component boundaries | `03.architecture/**/*.md` |
| Decisions | ADRs and prior decisions with rationale — cite them when they constrain the current design | `04.decisions/**/*.md` |
| Playbook | Conventions, coding guides, testing patterns, established practices | `05.playbook/**/*.md` |
| Guides | How-tos, operational runbooks, onboarding walkthroughs | `06.guides/**/*.md` |
| Resources | Reference material — wiki-page-components, glossaries, shared primitives | `07.resources/**/*.md` |
| Prior projects | Specs, overviews, scopes, and plans from past/in-flight branches on overlapping topics | `08.projects/*/` (scan titles, read only what's topically relevant) |

All paths are relative to `<WORKSPACE_ROOT>/sanetics-wiki/pages/`. Agents should enumerate titles across all eight sections first, then open full content only for pages that match the research topic.

### Project-Specific Sub-Questions

Based on the description, generate **2–6 additional sub-questions** that target the specific technology decisions and domain knowledge needed. Assign each to the most relevant category agent.

Examples:
- "Build a Verse compiler targeting WASM" → "How do existing effect systems handle type inference in compilation?" → assigned to existing-art
- "Add real-time collaboration to our editor" → "What CRDT libraries exist for TypeScript in 2026?" → assigned to library-landscape

### Agent Assignment

Consolidate categories based on available agent count:

| Depth | Web agents | Assignment |
|-------|-----------|------------|
| `quick` | 2 | A: library-landscape + existing-art, B: best-practices + pitfalls |
| `standard` | 3 | A: library-landscape, B: best-practices + existing-art, C: pitfalls |
| `deep` | 4 | One agent per category |

For codebase agents with count < 4, consolidate: 1 agent = all categories, 2 agents = architecture+dependencies / patterns+tests, 3 agents = architecture / patterns+dependencies / tests.

**Wiki agent count** (when `WIKI_AVAILABLE=true`):

| Depth | Wiki agents | Assignment |
|-------|-------------|------------|
| `quick` | 1 | A: all eight sections (skim titles, open only topically relevant pages) |
| `standard` | 2 | A: `01.home` + `02.domain` + `03.architecture` + `04.decisions`, B: `05.playbook` + `06.guides` + `07.resources` + `08.projects` |
| `deep` | 3 | A: `02.domain` + `03.architecture` + `04.decisions` (core design context), B: `05.playbook` + `06.guides` + `07.resources` (conventions & references), C: `01.home` + `08.projects` (orientation & prior-project deep scan) |

### Wave Assignment

- **Wave 1** (foundation): library-landscape, existing-art (+ all codebase agents, + all wiki agents)
- **Wave 2** (builds on wave 1): best-practices, pitfalls

Wiki agents run in wave 1 because their findings (prior decisions, established conventions, prior project scope) shape wave-2 best-practices and pitfalls research — later agents should know what's already been decided internally before recommending external best practices.

For `quick` depth: all web agents run in wave 1, no wave 2.

## Step 3: Initialize Research Directory

Create the directory and initial files:

```
context/refs/research-{topic}/findings-board.md
```

Write the initial findings board:

```markdown
# Findings Board: {description}

> Shared coordination state for research agents.
> Later agents read this before searching to avoid duplicates and build on earlier work.

(No findings yet — agents will populate this.)
```

Also ensure `context/refs/` exists.

## Step 4: Dispatch Research Agents

### Wave 1: Codebase Agents + Foundation Web Agents

Dispatch all of these **in parallel** (multiple Agent calls in one message):

**Each codebase agent** (subagent_type: `Explore`, model: `EXPLORATION_MODEL`):

```
Agent(
  subagent_type: "Explore",
  model: "{EXPLORATION_MODEL}",
  description: "Research codebase {categories}",
  prompt: "ROLE: Codebase researcher ({categories}) for: {description}

RESEARCH QUESTIONS:
{list of fixed-category questions + project-specific sub-questions assigned to this agent}

INSTRUCTIONS:
1. Explore the codebase focused on: {categories}
2. Answer each research question with specific evidence (file paths, code snippets)
3. Note patterns, conventions, and constraints that affect design decisions
4. Flag anything surprising or concerning
5. Be thorough — 'medium' level exploration

OUTPUT FORMAT:
## Agent: codebase-{categories}

For each finding:
- Finding: {what you found}
- Evidence: {file:line references or code snippets}
- Implication: {how this affects the design}
- Confidence: HIGH/MEDIUM/LOW"
)
```

**Each wave 1 web agent** (subagent_type: `general-purpose`, model: `EXPLORATION_MODEL`):

```
Agent(
  subagent_type: "general-purpose",
  model: "{EXPLORATION_MODEL}",
  description: "Research web {categories}",
  prompt: "ROLE: Web researcher ({categories}) for: {description}

RESEARCH QUESTIONS:
{list of fixed-category questions + project-specific sub-questions assigned to this agent}

INSTRUCTIONS:
1. Search the web for each research question ({searches_per_question} searches per question)
2. Fetch and read the most relevant results (prefer official docs, not summaries)
3. Extract specific, actionable findings — not vague advice
4. Flag contradictions between sources

QUALITY RULES:
- Prefer official docs, GitHub repos with stars, and engineering blogs over SEO content farms
- Include publication dates — findings from 2024+ only unless it's foundational knowledge
- Note when a library/practice is deprecated or superseded
- Always include source URLs
- If a library comparison exists, include adoption metrics (npm downloads, GitHub stars)

OUTPUT FORMAT:
## Agent: {categories}
- Found: {specific finding} [source: URL]
- Found: {specific finding} [source: URL]
- Confidence: HIGH/MEDIUM/LOW

Repeat for each research question."
)
```

**Each wiki agent** (subagent_type: `general-purpose`, model: `EXPLORATION_MODEL`) — dispatch only if `WIKI_AVAILABLE=true`:

```
Agent(
  subagent_type: "general-purpose",
  model: "{EXPLORATION_MODEL}",
  description: "Research wiki {sections}",
  prompt: "ROLE: Wiki researcher ({sections}) for: {description}

RESEARCH QUESTIONS:
{list of fixed-category questions + project-specific sub-questions assigned to this agent}

ASSIGNED WIKI SECTIONS (read-only — never write):
Root: <WORKSPACE_ROOT>/sanetics-wiki/pages/
{subset of the eight section paths assigned to this agent, each with its category label from the Wiki categories table}

The wiki has eight top-level sections (01.home through 08.projects). Your assigned subset is listed above. Another agent may be covering the rest — do not duplicate their coverage.

INSTRUCTIONS:
1. Use Glob to enumerate `.md` files under your assigned sections
2. Read titles and front matter first; open full content only for pages topically relevant to: {description}
3. Section-specific handling:
   - `01.home/`: look for orientation pages that frame the workspace — often useful for greenfield topics
   - `02.domain/`: extract established vocabulary and domain-model invariants; flag if the topic introduces a term already defined differently
   - `03.architecture/`: note component boundaries, ERDs, target-state diagrams relevant to the topic
   - `04.decisions/` (ADRs): when a decision constrains the current design, quote the rationale verbatim — don't paraphrase
   - `05.playbook/`: extract established conventions that must be reused rather than reinvented
   - `06.guides/`: flag existing runbooks or how-tos whose procedures would need updating if the topic changes related behavior
   - `07.resources/`: check for shared primitives (wiki-page-components, glossaries) that the topic should reuse rather than re-create
   - `08.projects/`: scan `chapter.md` titles and any `spec-*`, `overview-*`, `scope-*`, `plan-*` files; cite specific documents, not the project folder at large
4. Flag contradictions between wiki pages using 'Conflict:' prefix
5. Flag when a wiki page is stale (last-modified > 12 months) and the claim it makes is load-bearing

QUALITY RULES:
- Reference wiki pages by breadcrumb path (e.g., 'Medication Dosage Concepts (Domain > SaniGuide > Medication Dosage Concepts)'), not filesystem path or URL
- Include the last-edited date when citing (from front matter `last_edited` field if present)
- Prefer ADR citations over unstated assumptions
- When a prior project already specced an overlapping feature, surface it with its breadcrumb and one-line summary

OUTPUT FORMAT:
## Agent: wiki-{sections}
- Found: {specific finding} [breadcrumb: Domain > SaniGuide > X] [last-edited: YYYY-MM-DD]
- Decision precedent: {ADR title} — {rationale quote} [breadcrumb: Decisions > SaniLoop > X]
- Convention: {playbook or guide rule} — {how the topic should apply it} [breadcrumb: Playbook > X]
- Shared resource: {component/glossary entry} — {how to reuse} [breadcrumb: Resources > X]
- Prior project: {project title} — {spec/overview one-liner} [breadcrumb: Projects > X]
- Conflict: {describe contradictory wiki pages}
- Confidence: HIGH/MEDIUM/LOW

Repeat for each research question."
)
```

### Collect Wave 1 Results

After all wave 1 agents complete:

1. Write each agent's output to `context/refs/research-{topic}/raw-{category-slug}.md`
2. Compile all findings into the findings board — append each agent's output under its agent header
3. Write the updated `context/refs/research-{topic}/findings-board.md`

### Wave 2: Dependent Web Agents

Skip this step for `quick` depth.

Dispatch remaining web agents **in parallel** (subagent_type: `general-purpose`, model: `EXPLORATION_MODEL`):

```
Agent(
  subagent_type: "general-purpose",
  model: "{EXPLORATION_MODEL}",
  description: "Research web {categories}",
  prompt: "ROLE: Web researcher ({categories}) for: {description}

RESEARCH QUESTIONS:
{list of fixed-category questions + project-specific sub-questions assigned to this agent}

SHARED FINDINGS FROM EARLIER AGENTS (read first — skip questions already answered, go deeper on gaps):
---
{full contents of findings-board.md}
---

INSTRUCTIONS:
1. Read the shared findings above carefully — these may include wiki (internal prior art) findings
2. Skip questions already well-answered — go deeper on gaps and unanswered questions
3. Build on earlier findings — add nuance, find counterpoints, verify claims
4. If a wiki ADR or prior project already decided something, do not recommend a contradicting best practice silently — surface the tension with 'Conflict with internal precedent:'
5. Search the web ({searches_per_question} searches per question)
6. Flag contradictions with earlier agents' findings using 'Conflict:' prefix

QUALITY RULES:
- Prefer official docs, GitHub repos with stars, and engineering blogs over SEO content farms
- Include publication dates — findings from 2024+ only unless foundational
- Note when a library/practice is deprecated or superseded
- Always include source URLs

OUTPUT FORMAT:
## Agent: {categories}
- Found: {specific finding} [source: URL]
- Conflict: {if contradicts an earlier finding — explain both sides}
- Confidence: HIGH/MEDIUM/LOW"
)
```

### Collect Wave 2 Results

1. Write each agent's output to `context/refs/research-{topic}/raw-{category-slug}.md`
2. Append to the findings board

## Step 5: Two-Pass Synthesis

### Pass 1: Synthesizer Agent

Read all raw findings files and the findings board. Dispatch the synthesizer:

```
Agent(
  subagent_type: "general-purpose",
  model: "{REASONING_MODEL}",
  description: "Synthesize research findings",
  prompt: "ROLE: Research synthesizer for: {description}

You have raw findings from {N} research agents. Produce a single coherent research brief.

RAW FINDINGS:
---
{concatenated contents of all raw-*.md files from context/refs/research-{topic}/}
---

FINDINGS BOARD:
---
{contents of findings-board.md}
---

INSTRUCTIONS:
1. Cross-validate: findings confirmed by multiple agents independently = HIGH confidence
2. Resolve contradictions: when agents disagree, read both sides carefully. Pick one with reasoning, or preserve both if genuinely debatable
3. Filter: remove tangential findings that don't affect design decisions
4. Structure: organize into the research brief format below
5. Flag unknowns: areas where research was inconclusive or sources disagreed → 'Open Questions'
6. Extract implications: what design decisions does this research inform?

OUTPUT — follow this format exactly:

# Research Brief: {topic title}

**Generated:** {current date}
**Agents:** {N} codebase, {N} web, {N} wiki
**Sources consulted:** {count unique URLs/repos/wiki-pages referenced}

## Summary
{2-3 sentence executive summary of key findings that affect design decisions — call out where internal precedent constrains the design vs. where we're in greenfield territory}

## Key Findings

### Architecture & Patterns
{only if codebase research was done}
- {finding} [confidence: HIGH/MEDIUM/LOW] [sources: N]

### Library Landscape
- Recommended: {library X} — {why, with metrics if available} [confidence: HIGH]
- Alternative: {library Y} — {tradeoff} [confidence: MEDIUM]
- Avoid: {library Z} — {why} [confidence: HIGH]

### Best Practices
- {finding with source attribution}

### Existing Art
- {reference implementation/project} — {what we can learn from it}

### Pitfalls to Avoid
- {common mistake} — {why it matters, how to prevent}

### Prior Art (Internal)
{only if wiki research was done}
- Decision precedent: {ADR title} — {rationale} [breadcrumb: Decisions > X] [last-edited: YYYY-MM-DD]
- Domain vocabulary: {term} — {definition} [breadcrumb: Domain > X]
- Playbook: {convention} — {how it's applied} [breadcrumb: Playbook > X]
- Prior project overlap: {project title} — {one-line summary of overlap} [breadcrumb: Projects > X]

## Contradictions & Open Questions
- {topic}: Source A says X, Source B says Y. Assessment: {your reasoned take or 'needs user input'}
- Internal vs. external: {wiki precedent} conflicts with {external best practice}. Assessment: {reasoned take — usually wiki precedent wins unless it's stale or explicitly superseded}

## Codebase Context
{only include if codebase research was done}
- Architecture: {summary of structure, boundaries, entry points}
- Key patterns: {conventions, frameworks, abstractions in use}
- Dependencies: {notable version constraints, external integrations}
- Test coverage: {state of testing infrastructure}

## Implications for Design
- {design decision this research informs}
- {constraint this research reveals — call out internal constraints from wiki ADRs explicitly}
- {opportunity this research surfaces}

## Sources
- [Title](URL) — {one-line what it contributed} (external)
- {Breadcrumb path} — {one-line what it contributed} [last-edited: YYYY-MM-DD] (wiki)"
)
```

### Write Research Brief

Write the synthesizer's output to:

```
context/refs/research-brief-{topic}.md
```

## Step 6: Present Summary

Read the research brief and present a condensed summary:

```
Research complete ({N} agents across {codebase|web|wiki|combination}). Key findings:
- {3-5 most important bullet points from Summary and Key Findings}

Internal precedent: {1-2 bullets from Prior Art — ADR titles or prior projects that constrain this design, or "none"}
Open questions: {list from Contradictions & Open Questions, or "none"}

Full brief: context/refs/research-brief-{topic}.md
Raw findings: context/refs/research-{topic}/
```

---

## Error Handling

- If a web agent fails to find relevant results, note the gap — do not fabricate findings
- If the codebase is empty and `--codebase-only` was set, warn: "No source files found. Nothing to research."
- If `WIKI_AVAILABLE=false` and `--wiki-only` was set, stop and report the workspace-detection failure — do not silently no-op.
- If the wiki is available but no wiki pages match the topic, write a single wiki raw-findings file that states "no internal prior art surfaced for this topic" and continue. This is a real finding — an empty internal landscape is worth knowing.
- If ALL agents return empty results, tell the user: "Research didn't surface actionable findings for this topic. Proceeding without a research brief."
- If the synthesizer output is malformed, write what you have and note the issue in the summary
