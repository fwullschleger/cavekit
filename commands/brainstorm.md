---
name: sdd-brainstorm
description: "Write specs: decompose what you're building into domains with testable requirements"
argument-hint: "[REFS_PATH | --from-code] [--filter PATTERN]"
---

# SDD Brainstorm — Write Specs

This is the first phase of SDD. You are writing implementation-agnostic specifications that define WHAT to build.

## Determine Mode

Parse `$ARGUMENTS`:
- If `--from-code` → **Brownfield mode** (reverse-engineer specs from existing code)
- If a path is given → **Refs mode** (generate specs from reference materials at that path)
- If no arguments → **Interactive mode** (ask the user what to build)

## Step 1: Ensure Directories Exist

Create these if missing (no separate init needed):
- `context/specs/`
- `context/frontiers/`
- `context/impl/`
- `context/impl/archive/`
- `context/refs/`

## Step 2: Gather Input

### Interactive mode (no arguments)

Ask the user:
1. "What are you building?" — get a description
2. "Do you have reference materials? (PRDs, API docs, design specs, research)" — if yes, ask where they are and read them
3. "Is there existing code to build on?" — if yes, explore the codebase

Use the answers to decompose into domains.

### Refs mode (path given)

Read all files at the given path (or `context/refs/` if the path is a directory). Catalog what you find: PRDs, API docs, design specs, research, architecture docs. Use these as the source of truth for spec generation.

### Brownfield mode (`--from-code`)

Explore the existing codebase:
1. Read directory structure to understand architecture
2. Identify logical domains from code organization
3. For each domain, identify: entry points, data models, external dependencies, existing tests
4. Treat existing code as the reference material

## Step 3: Decompose into Domains

Analyze the input and decompose into logical domains. Each domain should be:
- **Cohesive** — covers one area of functionality
- **Loosely coupled** — minimal dependencies on other domains
- **Independently specifiable** — can be described without implementation details of other domains

## Step 4: Generate Specs

For each domain, create `context/specs/spec-{domain}.md`:

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Spec: {Domain Name}

## Scope
{What this domain covers}

## Requirements

### R1: {Requirement Name}
**Description:** {What must be true}
**Acceptance Criteria:**
- [ ] {Testable criterion 1}
- [ ] {Testable criterion 2}
**Dependencies:** {Other specs/requirements this depends on, or "none"}

### R2: ...

## Out of Scope
{Explicit exclusions — what this domain does NOT cover}

## Cross-References
- See also: spec-{related-domain}.md
```

If `--filter` is set, only generate specs for domains matching the filter pattern.

### Quality Rules — These Are Non-Negotiable

- Every file MUST have YAML frontmatter with `created` and `last_edited` dates (ISO 8601 UTC)
- Specs are **implementation-agnostic** — describe WHAT, never HOW
- Every requirement MUST have testable acceptance criteria
- If a requirement cannot be automatically validated, flag it as needing human review
- Cross-reference specs where domains interact
- Explicitly state what is out of scope
- Use R-numbered requirements (R1, R2, R3...)

### Brownfield-Specific Rules

- Describe what the code DOES, not how it's implemented
- For each acceptance criterion, verify the existing code satisfies it
- If code does NOT satisfy a criterion, mark it as `[GAP]`
- Note source files that informed each spec in a Source Traceability section

## Step 5: Create spec-overview.md

```markdown
---
created: "{CURRENT_DATE_UTC}"
last_edited: "{CURRENT_DATE_UTC}"
---

# Spec Overview

## Project
{Project name and description}

## Domain Index
| Domain | Spec File | Requirements | Status | Description |
|--------|-----------|-------------|--------|-------------|
| {domain} | spec-{domain}.md | {count} | DRAFT | {one-line} |

## Cross-Reference Map
| Domain A | Interacts With | Interaction Type |
|----------|---------------|-----------------|
| {domain} | {other domain} | {data flow / dependency / event} |

## Dependency Graph
{Which domains must be implemented before others}
```

## Step 6: Validate

1. Verify every cross-reference points to an existing spec
2. Verify no domain is referenced but missing a spec
3. Verify the dependency graph has no circular dependencies
4. Verify acceptance criteria across specs are consistent (no contradictions)
5. (Brownfield only) Verify acceptance criteria against existing code

## Step 7: Report

```markdown
## Brainstorm Report

### Domains: {count}
### Requirements: {count}
### Acceptance Criteria: {count}

### Dependency Order
1. {domain} — no dependencies (implement first)
2. {domain} — depends on {domain}

### Gaps / Open Questions
- {anything that couldn't be fully specified}

### Next Step
Run `/sdd:plan` to generate the feature frontier.
```

Present the report to the user.
