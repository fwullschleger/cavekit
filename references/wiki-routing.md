# Wiki Routing Reference

Shared routing logic for all CaveKit commands that read or write documents. Commands reference this file instead of duplicating routing steps.

---

## 1. Mode Detection

Wiki mode is **opt-in**, not auto-detected. Commands check for the `--wiki` flag in `$ARGUMENTS`:

- If `--wiki` is present → **wiki mode** (proceed to section 2 for project discovery)
- Otherwise → **local mode** (use `context/` paths, skip project discovery and PR sync)

**Commands that support `--wiki`:** `/ck:spec`, `/ck:overview`, `/ck:scope`, `/ck:sketch`, `/ck:map`

**Commands that are always local:** `/ck:make`, `/ck:check`, `/ck:init`

---

## 2. Project Discovery (wiki mode only)

Find or create the wiki project folder for the current branch.

**Steps:**

1. Get current branch: `git branch --show-current`
2. Get remote URL: `git remote get-url origin`
3. Glob `~/workspaces/sanetics/sanetics-wiki/pages/08.projects/*/chapter.md`
4. Read each `chapter.md`, match by `source` (remote URL) **AND** `branch`
5. If match found → use that project folder, proceed to step 7
6. If no match → create new project:
   a. Derive **folder name** from branch: strip prefixes (`feature/`, `bugfix/`, `hotfix/`, `release/`), convert to kebab-case
   b. Derive **title** from branch: human-readable form (e.g., `feature/oauth2-login` → `OAuth2 Login`)
   c. Ask the user for **product** taxonomy (`saniguide`, `saniloop`, or `system`)
   d. Check for PR: `gh pr list --head <branch> --json number,url --limit 1`. If found, append `-pr<N>` to folder name and `(PR #<N>)` to title
   e. Create folder `08.projects/<folder-name>/`
   f. Write `chapter.md` using the template in section 8

7. **PR sync** (on every command invocation):
   - Check if the project's `chapter.md` already has a PR row in its metadata table
   - If no PR row, check: `gh pr list --head <branch> --json number,url --limit 1`
   - If a PR is found:
     a. Rename folder to append `-pr<N>` (e.g., `oauth2-login/` → `oauth2-login-pr42/`)
     b. Update `title` in `chapter.md` to append `(PR #<N>)`
     c. Add `| **PR** | ... |` row to the metadata table
     d. Grep the wiki for cross-references to the old folder name and update them

---

## 3. Path Resolution

Commands resolve read/write paths based on mode:

| Artifact | Wiki mode path | Local mode path |
|----------|---------------|-----------------|
| Specs | `<wiki-project>/01.YYYY-MM-DD-HHmm-spec-<topic>/spec-<topic>.md` | `context/specs/YYYY-MM-DD-spec-<topic>.md` |
| Overviews | `<wiki-project>/02.YYYY-MM-DD-HHmm-overview-<topic>/overview-<topic>.md` | `context/specs/YYYY-MM-DD-overview-<topic>.md` |
| Scopes | `<wiki-project>/03.YYYY-MM-DD-HHmm-scope-<topic>/scope-<topic>.md` | `context/specs/YYYY-MM-DD-scope-<topic>.md` |
| Kits | `<wiki-project>/10.kits/` | `context/kits/` |
| Build site | `<wiki-project>/11.build-site/` | `context/plans/` |
| Impl tracking | `<wiki-project>/12.impl/` | `context/impl/` |

Where `<wiki-project>` = `~/workspaces/sanetics/sanetics-wiki/pages/08.projects/<project>/`

**Subfolder collision handling:** If the target subfolder already exists, append `-2`, `-3`, etc.

---

## 4. Grav Front Matter

Every wiki-mode document must include this front matter:

```yaml
---
title: '<Topic> (<Type>)'
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

**Title conventions:**

| Type | Title format |
|------|-------------|
| Specification | `<Topic> (Specification)` |
| Overview | `<Topic> (Overview)` |
| Scope | `<Topic> (Scope)` |
| Kit | `<Domain> (Kit)` |
| Build Site | `<Project> (Build Site)` |

Content starts at `##` — Grav renders the `title` field as `<h1>`.

**Local mode:** use the existing CaveKit frontmatter (`created`, `last_edited` only).

---

## 5. Auto-Commit (wiki mode only)

After writing any document to the wiki:

1. Stage **only** the specific files written (the document subfolder, and `chapter.md` if a new project was created)
2. Commit with structured message:
   - **Title:** `wiki(<project-folder>): <add|update> <type> — <topic-slug>`
   - **Body:** 3-5 bullet points summarizing key content (new docs) or what changed (updates)
3. Do **NOT** push — pushing is a manual decision
4. If the commit fails, report the error but do not abort the command

---

## 6. Related Docs Lookup

When writing or referencing documentation, search these locations:

**Project docs (wiki mode):** List subfolders in the project folder and read the `.md` file in each to find existing specs, overviews, scopes, kits.

**Wiki sections (consider all eight when gathering context in wiki mode):**

- `~/workspaces/sanetics/sanetics-wiki/pages/01.home/**/*.md` — landing, orientation
- `~/workspaces/sanetics/sanetics-wiki/pages/02.domain/**/*.md` — domain models, ubiquitous language
- `~/workspaces/sanetics/sanetics-wiki/pages/03.architecture/**/*.md` — ERDs, system design, target state
- `~/workspaces/sanetics/sanetics-wiki/pages/04.decisions/**/*.md` — ADRs, design decisions with rationale
- `~/workspaces/sanetics/sanetics-wiki/pages/05.playbook/**/*.md` — coding guides, testing patterns, conventions
- `~/workspaces/sanetics/sanetics-wiki/pages/06.guides/**/*.md` — how-tos, runbooks, onboarding
- `~/workspaces/sanetics/sanetics-wiki/pages/07.resources/**/*.md` — reference material (components, glossaries)
- `~/workspaces/sanetics/sanetics-wiki/pages/08.projects/**/*.md` — prior project specs/overviews/scopes/plans

Skim titles and front matter first; open only what's topically relevant. Reference pages via breadcrumb paths, not file paths.

**Wiki page components:** Consult `~/workspaces/sanetics/sanetics-wiki/pages/07.resources/wiki-page-components/` for available content components (callouts, code blocks, tables, cards, steps, tabs, accordions, etc.) before using non-standard formatting.

---

## 7. Diagram Rules

All diagrams are **Mermaid diagrams** — fenced code blocks with the `mermaid` language tag. The Grav wiki with the Helios theme renders them natively. No image files, no external tools.

Diagrams are **first-class citizens**, not decorations. Every spec and overview must include diagrams. The agent selects the best Mermaid diagram type(s) for each concern — multiple diagrams covering the same area from different angles are explicitly encouraged.

### Diagram type selection guide

| Concern | Preferred type(s) |
|---------|------------------|
| Component relationships, system boundaries, layer structure | **Component/flowchart** (`flowchart TD/LR`) |
| Domain model, entity structure, class hierarchy, aggregate roots | **Class diagram** (`classDiagram`) |
| State transitions, lifecycle | **State diagram** (`stateDiagram-v2`) |
| Multi-actor interaction, API calls, event sequences | **Sequence diagram** (`sequenceDiagram`) |
| Decision branching, conditional logic flow | **Flowchart** (`flowchart TD`) |
| Before/After structural change | **Two paired diagrams** (one per state) |

### Rules

1. **Required at minimum:** every spec must have ≥1 diagram; every overview must have ≥1 architecture/component diagram
2. **Multiple diagrams for the same area** are explicitly encouraged when each adds a different angle (e.g., a class diagram for structure + a sequence diagram for runtime behavior of the same component)
3. **Best type for the job:** don't default to flowchart when a class diagram communicates structure better
4. **Before/After pairs:** when an overview documents a planned change, include both a current-state and future-state diagram — same type, same scope, visually comparable
5. **No forced diagrams:** if a section genuinely has nothing structural to show, omit — but this should be rare
6. **Token-efficient:** diagram nodes use short labels (`<br/>` for line breaks); avoid verbosity in node text

---

## 8. Project chapter.md Template

```yaml
---
title: '<Human-Readable Branch Title>'
template: chapter
taxonomy:
    product: [<product>]
    category: [project]
source: '<git remote URL>'
branch: '<branch name>'
published: true
visible: true
---

| | |
|---|---|
| **Branch** | `<branch name>` |

Working project folder for <brief description derived from branch name>.
```

When a PR exists, add `(PR #<N>)` to the title and a PR row to the table:

```markdown
| **PR** | [#<N>](<PR URL>) |
```

---

## 9. Sub-project chapter.md Templates

### 10.kits/chapter.md

```yaml
---
title: 'Kits'
template: chapter
taxonomy:
    product: [<product>]
    category: [project]
published: true
visible: true
---

Domain kits for this project. Implementation-agnostic requirements with testable acceptance criteria.
```

### 11.build-site/chapter.md

```yaml
---
title: 'Build Site'
template: chapter
taxonomy:
    product: [<product>]
    category: [project]
published: true
visible: true
---

Task dependency graphs generated from kits.
```

### 12.impl/chapter.md

```yaml
---
title: 'Implementation'
template: chapter
taxonomy:
    product: [<product>]
    category: [project]
published: true
visible: true
---

Implementation tracking, progress, and dead ends.
```

---

## 10. Wiki Project Folder Structure

```
<project>/
├── chapter.md                                    ← project metadata
├── 01.YYYY-MM-DD-HHmm-spec-<topic>/
│   └── spec-<topic>.md                           ← /ck:spec
├── 02.YYYY-MM-DD-HHmm-overview-<topic>/
│   └── overview-<topic>.md                       ← /ck:overview
├── 03.YYYY-MM-DD-HHmm-scope-<topic>/
│   └── scope-<topic>.md                          ← /ck:scope
├── 10.kits/
│   ├── chapter.md
│   ├── cavekit-overview.md
│   └── cavekit-<domain>.md                       ← /ck:sketch
├── 11.build-site/
│   ├── chapter.md
│   └── build-site.md                             ← /ck:map
└── 12.impl/
    ├── chapter.md
    ├── impl-overview.md
    ├── impl-<domain>.md                          ← /ck:make tracking
    └── dead-ends.md
```

- Prefixes 01-03: human-facing docs (Grav numbered folder convention)
- Prefixes 10-12: machine artifacts as sub-projects (Grav sub-project convention)
