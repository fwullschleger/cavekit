---
name: ck-ingest
description: "Pull reference material from external systems into context/refs/ — pluggable sources, first class ClickUp"
argument-hint: "<source> <identifier> [--as <slug>] [--dry-run]"
---

# Cavekit Ingest — External Reference Acquisition

Pull material from external systems (ClickUp tasks, wiki pages, URLs, local files) into `context/refs/` so `/ck:sketch`, `/ck:spec`, and `/ck:research` have source-of-truth to read from. One normalized markdown file per ingested item.

This is the **acquisition** step. It does not analyze — it only fetches, normalizes, and writes. Analysis happens downstream (`/ck:research` for synthesis, `/ck:sketch` and `/ck:spec` for consumption).

## Workspace root resolution

Before any substantive work, attempt to resolve the **workspace root**:

1. Start from the current working directory.
2. Walk upward through parent directories until you find one that contains **all** of these markers:
   - A `sanetics-wiki/` directory
   - A `setup.sh` file
   - A `.claude/` directory
3. If such an ancestor is found, remember its absolute path as `WORKSPACE_ROOT`.
4. If no ancestor contains all three markers, `WORKSPACE_ROOT` is **unset** — ingest still works, it just writes to the CWD's `context/refs/` without workspace awareness.

Do not use environment variables or hardcoded absolute paths.

## Context selection

If `WORKSPACE_ROOT` is set and CWD is the workspace root (not a sub-repo), ask the user which sub-repo should receive the ingested ref. Otherwise, the enclosing sub-repo (or plain CWD) is the target.

## Step 0: Parse Arguments

Extract from `$ARGUMENTS`:
- `<source>` — required. One of the registered sources in the table below. If not given or unrecognized, list available sources and ask.
- `<identifier>` — required. Source-specific identifier (ClickUp task ID, wiki breadcrumb, URL, file path, etc.).
- `--as <slug>` — optional. Override the derived filename slug (kebab-case). Useful when the default slug from title/id is awkward.
- `--dry-run` — optional. Resolve and fetch, print the would-be filename and first 30 lines of content, **do not write**.

Generate a **target filename** as `context/refs/<source>-<slug>.md` where `<slug>` is:
1. The `--as` override if given, else
2. The source-specific slug derived in that source's subsection (see Sources below).

If the target file already exists, ask: `Ref already exists: <path>. Overwrite? [y/N]`. Default N.

## Step 1: Ensure Directory

Create `context/refs/` under the target sub-repo if it doesn't exist. (Does not require `/ck:init` to have been run — we're additive.)

## Step 2: Dispatch to Source Handler

Look up `<source>` in the Sources table below and run the matching subsection. Each source handler is responsible for:

1. Fetching the raw material from the external system
2. Normalizing it into the **Common Output Format** (below)
3. Returning the final markdown content and derived slug

If the source lookup fails, stop and list available sources.

## Sources

| Source | Identifier | Handler section |
|--------|-----------|----------------|
| `clickup` | Task ID (e.g. `86a12b3cd`) or task URL | §A |
| _(future)_ `wiki` | Wiki breadcrumb or relative path | §B — not yet implemented, stub only |
| _(future)_ `url` | Any HTTP(S) URL | §C — not yet implemented, stub only |
| _(future)_ `file` | Local filesystem path | §D — not yet implemented, stub only |

When adding a new source: (1) add a row to this table, (2) add a numbered subsection below with the handler, (3) nothing else — the rest of the command is source-agnostic.

### §A — ClickUp

**Prerequisites:** The `mcp__claude_ai_ClickUp__*` MCP tools must be available in the session. If they aren't, stop and tell the user: "ClickUp MCP tools not loaded — ensure the ClickUp MCP server is configured for this session."

**Accepts:** task ID (e.g. `86a12b3cd`), or a full ClickUp task URL (extract the task ID from the URL).

**Steps:**

1. **Fetch task**: call `mcp__claude_ai_ClickUp__clickup_get_task` with the task ID. Extract: title, status, list name, assignee(s), due date, description, URL, tags, custom fields.
2. **Fetch comments**: call `mcp__claude_ai_ClickUp__clickup_get_task_comments`. Preserve chronological order.
3. **Fetch threaded replies**: for any comment that has replies, call `mcp__claude_ai_ClickUp__clickup_get_threaded_comments`. Nest under the parent comment.
4. **Fetch subtasks** (if any): the task payload includes subtasks — list them with status.
5. **Fetch linked docs** (if any): the task may include document attachments. Call `mcp__claude_ai_ClickUp__clickup_get_document_pages` for each linked doc and include page content.
6. **Derive slug**: `<task-id>-<kebab-title-truncated-to-40-chars>`. Example: `86a12b3cd-subjobgroup-responsibilities`.

**Content template:**

```markdown
---
source: clickup
source_id: <task-id>
source_url: <task-url>
ingested: "<ISO 8601 UTC>"
ingestor: ck-ingest
---

# ClickUp: <task title>

| | |
|---|---|
| **Status** | <status> |
| **List** | <list name> |
| **Assignee(s)** | <comma-separated names> |
| **Due** | <date or "—"> |
| **Tags** | <comma-separated or "—"> |
| **URL** | <task url> |

## Description

<task description — preserve markdown as-is>

## Custom Fields

<only include if task has custom fields populated>

| Field | Value |
|-------|-------|
| <name> | <value> |

## Subtasks

<only include if subtasks exist>

- [x] <title> — <status> (<id>)
- [ ] <title> — <status> (<id>)

## Comments

<comments in chronological order, oldest first>

### <commenter name> — <ISO 8601 timestamp>

<comment text>

<if comment has threaded replies, nest them below at H4>

#### <reply author> — <timestamp>

<reply text>

## Linked Docs

<only include if the task has document attachments — one subsection per doc>

### <doc title>

<concatenated page content from clickup_get_document_pages>
```

If any step fails (task not found, permission denied, rate-limited), stop and report the failure verbatim — do not fabricate content.

### §B — Wiki (stub)

Not yet implemented. When invoked, report: "Wiki ingestion not yet implemented. Use wiki content directly via `/ck:research` (wiki wave) for now."

When implementing: accept a breadcrumb (e.g. `domain/saniguide/medication-dosage-concepts`) or a relative path from `sanetics-wiki/pages/`, read the matching page (handle Grav's one-folder-per-page layout), strip Grav front matter, write as `context/refs/wiki-<slug>.md` preserving the page title and last-edited metadata.

### §C — URL (stub)

Not yet implemented. When invoked, report: "URL ingestion not yet implemented."

When implementing: use `WebFetch` to retrieve and markdownify the page, write as `context/refs/url-<domain-and-slug>.md`.

### §D — File (stub)

Not yet implemented. When invoked, report: "File ingestion not yet implemented — copy the file manually into context/refs/ for now."

When implementing: copy the file, preserve its extension if it's markdown/text, convert other formats where feasible.

## Step 3: Write

Unless `--dry-run` was passed:

1. Write the composed markdown to the resolved target path.
2. Print the path on completion.
3. **Dry-run:** print the path and first 30 lines of the would-be content. Do not write.

Do not auto-commit. Ingested refs are source material that the user will often edit, reorganize, or discard — commits happen when downstream artifacts (specs, kits, briefs) are created.

## Step 4: Report

Present a brief report:

```
Ingested: <source> <identifier>
→ <resolved path>

Size: <line count> lines
Next step: use this ref in /ck:spec, /ck:sketch, or /ck:research.
```

If `--dry-run`: replace "Ingested" with "Dry run — would ingest".

---

## Key Principles

- **Acquisition, not analysis** — this command only fetches and normalizes. Downstream commands synthesize.
- **One ref, one file** — every ingestion produces exactly one markdown file. No multi-file dumps.
- **Source-specific slug, global flat layout** — all refs live directly in `context/refs/`. The `<source>-` filename prefix keeps them grouped alphabetically.
- **Extensible by addition** — new sources are a row in the Sources table plus a handler subsection. Everything else is source-agnostic.
- **Never auto-commit** — refs are working material, not deliverables.

## What ingest is NOT

- Not research — use `/ck:research` to synthesize across refs.
- Not a kit generator — use `/ck:sketch` to turn refs into kits.
- Not a wiki publisher — refs stay local in `context/refs/`; wiki publishing happens via `--wiki` on other commands.

## Examples

```bash
/ck:ingest clickup 86a12b3cd                         # ingest a ClickUp task by ID
/ck:ingest clickup https://app.clickup.com/t/abc123  # same, via URL
/ck:ingest clickup 86a12b3cd --as auth-requirements  # override the slug
/ck:ingest clickup 86a12b3cd --dry-run               # preview without writing
```

## Topic

$ARGUMENTS
