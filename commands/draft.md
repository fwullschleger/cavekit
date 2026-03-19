---
name: bp-draft
description: "Write blueprints: decompose what you're building into domains with testable requirements"
argument-hint: "[REFS_PATH | --from-code] [--filter PATTERN]"
---

# Blueprint Draft — Write Blueprints

This is the first phase of Blueprint. You are writing implementation-agnostic blueprints that define WHAT to build through collaborative design with the user.

**HARD GATE:** Do NOT generate blueprint files until you have presented the design and the user has approved it. This applies to EVERY project regardless of perceived simplicity. A todo app, a config change, a single-domain project — all of them go through the design process. The design can be short for simple projects, but you MUST present it and get approval.

## Determine Mode

Parse `$ARGUMENTS`:
- If `--from-code` → **Brownfield mode** (reverse-engineer blueprints from existing code)
- If a path is given → **Refs mode** (generate blueprints from reference materials at that path)
- If no arguments → **Interactive mode** (collaborative design with the user)

## Step 1: Ensure Directories Exist

Create these if missing (no separate init needed):
- `context/blueprints/`
- `context/sites/`
- `context/impl/`
- `context/impl/archive/`
- `context/refs/`

## Step 2: Explore Project Context

Before asking ANY questions, understand what already exists:

1. Check for existing `context/blueprints/` — are there prior blueprints?
2. Read project docs, README, CLAUDE.md if present
3. Check recent git commits to understand current momentum
4. Scan the codebase structure (directory layout, key files)
5. Check `context/refs/` for reference materials already provided

This gives you grounding before engaging the user. Do NOT skip this even if the user has already described what they want.

## Step 3: Gather Input

### Interactive mode (no arguments)

This is a **collaborative design process**. Follow these steps in order:

#### 3a: Offer Visual Companion (if applicable)

If upcoming questions will involve visual content (UI layouts, architecture diagrams, data flow), offer the visual companion. This MUST be its own message — do not combine it with any other content:

> "Some of what we're working on might be easier to explain if I can show it to you in a web browser. I can put together mockups, diagrams, comparisons, and other visuals as we go. Want to try it? (Requires opening a local URL)"

Wait for the user's response. If they decline, proceed with text-only. If they accept, read `references/visual-companion.md` for the detailed guide. The server lives in `scripts/visual-companion/`.

**Per-question decision:** Even after the user accepts, decide FOR EACH QUESTION whether to use the browser or the terminal. The test: **would the user understand this better by seeing it than reading it?**
- **Use the browser** for: mockups, wireframes, architecture diagrams, side-by-side visual comparisons
- **Use the terminal** for: requirements questions, conceptual choices, tradeoff lists, scope decisions

#### 3b: Clarifying Questions — One at a Time

Ask questions **one at a time** to understand what the user is building. Do NOT dump multiple questions in a single message.

- Prefer **multiple choice** when possible — easier to answer than open-ended
- Focus on understanding: **purpose**, **constraints**, **success criteria**
- Open-ended questions are fine when the topic needs exploration

**Scope check:** Before going deep on details, assess scope. If the request describes multiple independent subsystems (e.g., "build a platform with chat, file storage, billing, and analytics"), flag this immediately. Help the user decompose into sub-projects first. Each sub-project gets its own draft cycle.

Continue asking questions until you have a clear picture of:
- What the system must do (core requirements)
- What it must NOT do (scope boundaries)
- Who uses it and how (user journeys / entry points)
- What constraints exist (technical, organizational, timeline)
- What success looks like (how do we know it works?)

#### 3c: Propose 2-3 Approaches

Before settling on a design, propose **2-3 different domain decomposition approaches** with tradeoffs:

- Lead with your **recommended** approach and explain why
- Present alternatives with honest pros/cons
- Consider: coupling, complexity, parallelizability, testability
- Be ready to combine elements from different approaches based on feedback

Example:
> **Approach A (recommended): Three domains — Auth, API, Storage**
> Pros: Clean boundaries, independent testing. Cons: More cross-references.
>
> **Approach B: Two domains — Backend, Frontend**
> Pros: Simpler. Cons: Backend domain is too broad, harder to parallelize.
>
> **Approach C: Five fine-grained domains**
> Pros: Maximum parallelism. Cons: Over-decomposed, too many cross-references for this scope.

#### 3d: Present Design Incrementally

Once the user picks an approach, present the design **section by section**. Scale each section to its complexity — a few sentences if straightforward, more detail if nuanced.

For each proposed domain:
1. Present scope and boundaries
2. Present key requirements with acceptance criteria
3. Present cross-references and dependencies
4. Ask: "Does this look right so far?"

Only move to the next domain when the current one is approved. Be ready to revise.

**Design for isolation:** Each domain should:
- Have one clear purpose
- Communicate through well-defined interfaces
- Be understandable and testable independently
- Be small enough to reason about in a single context window

**YAGNI ruthlessly:** Remove features the user didn't ask for. If you're tempted to add "nice to have" requirements, don't. Smaller blueprints are better blueprints.

### Refs mode (path given)

Read all files at the given path (or `context/refs/` if the path is a directory). Catalog what you find: PRDs, API docs, design blueprints, research, architecture docs. Use these as the source of truth for blueprint generation.

After reading, still present a brief design summary to the user before generating files:
- "Here's what I found and how I plan to decompose it into domains: ..."
- Get approval before proceeding to file generation.

### Brownfield mode (`--from-code`)

Explore the existing codebase:
1. Read directory structure to understand architecture
2. Identify logical domains from code organization
3. For each domain, identify: entry points, data models, external dependencies, existing tests
4. Treat existing code as the reference material

After exploration, present your proposed decomposition to the user before generating files.

## Step 4: Decompose into Domains

Analyze the input and decompose into logical domains. Each domain should be:
- **Cohesive** — covers one area of functionality
- **Loosely coupled** — minimal dependencies on other domains
- **Independently specifiable** — can be described without implementation details of other domains
- **Right-sized** — small enough to hold in context, large enough to be meaningful

## Step 5: Generate Blueprints

**Only after user approves the design**, generate blueprint files.

For each domain, create `context/blueprints/blueprint-{domain}.md`:

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Blueprint: {Domain Name}

## Scope
{What this domain covers}

## Requirements

### R1: {Requirement Name}
**Description:** {What must be true}
**Acceptance Criteria:**
- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}
**Dependencies:** {Other blueprints/requirements this depends on, or "none"}

### R2: ...

## Out of Scope
{Explicit exclusions — what this domain does NOT cover}

## Cross-References
- See also: blueprint-{related-domain}.md
```

If `--filter` is set, only generate blueprints for domains matching the filter pattern.

### Quality Rules — These Are Non-Negotiable

- Every file MUST have YAML frontmatter with `created` and `last_edited` dates (ISO 8601 UTC)
- Blueprints are **implementation-agnostic** — describe WHAT, never HOW
- Every requirement MUST have testable acceptance criteria
- If a requirement cannot be automatically validated, flag it as needing human review
- Cross-reference blueprints where domains interact
- Explicitly state what is out of scope
- Use R-numbered requirements (R1, R2, R3...)
- **YAGNI** — do not add requirements the user did not ask for

### Brownfield-Specific Rules

- Describe what the code DOES, not how it's implemented
- For each acceptance criterion, verify the existing code satisfies it
- If code does NOT satisfy a criterion, mark it as `[GAP]`
- Note source files that informed each blueprint in a Source Traceability section

## Step 6: Create blueprint-overview.md

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Blueprint Overview

## Project
{Project name and description}

## Domain Index
| Domain | Blueprint File | Requirements | Status | Description |
|--------|-----------|-------------|--------|-------------|
| {domain} | blueprint-{domain}.md | {count} | DRAFT | {one-line} |

## Cross-Reference Map
| Domain A | Interacts With | Interaction Type |
|----------|---------------|-----------------|
| {domain} | {other domain} | {data flow / dependency / event} |

## Dependency Graph
{Which domains must be implemented before others}
```

## Step 7: Validate

1. Verify every cross-reference points to an existing blueprint
2. Verify no domain is referenced but missing a blueprint
3. Verify the dependency graph has no circular dependencies
4. Verify acceptance criteria across blueprints are consistent (no contradictions)
5. Verify no implementation details leaked into blueprints (no framework names, file paths, API choices)
6. (Brownfield only) Verify acceptance criteria against existing code

## Step 8: Blueprint Review Loop

After writing blueprints, dispatch a **blueprint-reviewer** subagent to verify quality:

```
Agent tool (subagent_type: "bp:inspector"):
  description: "Review blueprint documents"
  prompt: |
    You are a blueprint reviewer. Verify these blueprints are complete and ready for the Architect phase.

    **Blueprints to review:** context/blueprints/

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, "TBD", incomplete sections, missing Out of Scope |
    | Consistency | Internal contradictions, conflicting requirements across domains |
    | Clarity | Requirements ambiguous enough to cause an agent to build the wrong thing |
    | Scope | Each domain focused enough — not covering multiple independent subsystems |
    | YAGNI | Unrequested features, over-engineering, gold-plating |
    | Implementation leakage | Framework names, file paths, API choices in requirements |
    | Cross-references | Missing bidirectional links, dangling references |
    | Acceptance criteria | Vague, untestable, or subjective criteria |

    ## Calibration

    Only flag issues that would cause real problems during the Architect phase.
    A missing section, a contradiction, or a requirement so ambiguous it could be
    interpreted two different ways — those are issues. Minor wording improvements
    and stylistic preferences are not.

    Approve unless there are serious gaps that would lead to a flawed build site.

    ## Output Format

    ## Blueprint Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Blueprint X, RN]: [specific issue] - [why it matters]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

**Review loop rules:**
- If **Approved**: proceed to Step 9
- If **Issues Found**: fix the issues, re-dispatch the reviewer
- Maximum **3 iterations** — if still not passing, present remaining issues to the user for guidance

## Step 9: User Review Gate

After the review loop passes, ask the user to review the written blueprints:

> "Blueprints written and validated. Files are in `context/blueprints/`. Please review them and let me know if you want to make any changes before we move to the Architect phase."

Wait for the user's response. If they request changes, make them and re-run Step 8. Only proceed once the user approves.

## Step 10: Report and Transition

```markdown
## Draft Report

### Domains: {count}
### Requirements: {count}
### Acceptance Criteria: {count}

### Dependency Order
1. {domain} — no dependencies (implement first)
2. {domain} — depends on {domain}

### Gaps / Open Questions
- {anything that couldn't be fully specified}

### Next Step
Run `/bp:architect` to generate the build site from these blueprints.
```

Present the report. When the user is ready, transition to `/bp:architect`.

---

## Key Principles

- **One question at a time** — do not overwhelm with multiple questions
- **Multiple choice preferred** — easier to answer than open-ended when possible
- **YAGNI ruthlessly** — remove unnecessary features from all blueprints
- **Explore alternatives** — always propose 2-3 approaches before settling
- **Incremental validation** — present design section by section, get approval before moving on
- **Design for isolation** — each domain has one purpose, clear interfaces, independently testable
- **No blueprint generation before design approval** — the design conversation IS the value
