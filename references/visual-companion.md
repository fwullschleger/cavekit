# Visual Companion Guide

Browser-based visual companion for showing mockups, diagrams, and options during the Draft phase. Available as a tool — not a mode. Accepting the companion means it's available for questions that benefit from visual treatment; it does NOT mean every question goes through the browser.

## When to Use

Decide **per-question**, not per-session. The test: **would the user understand this better by seeing it than reading it?**

**Use the browser** when the content itself is visual:
- **Architecture diagrams** — system components, data flow, domain boundaries
- **UI mockups** — wireframes, layouts, navigation structures
- **Side-by-side visual comparisons** — comparing domain decomposition options visually
- **Dependency graphs** — rendered as interactive diagrams
- **Data flow diagrams** — how data moves between domains

**Use the terminal** when the content is text or tabular:
- **Requirements and scope questions** — "what does X mean?", "which features are in scope?"
- **Conceptual A/B/C choices** — picking between approaches described in words
- **Tradeoff lists** — pros/cons, comparison tables
- **Technical decisions** — architectural approach selection
- **Clarifying questions** — anything where the answer is words, not a visual preference

A question *about* a UI topic is not automatically a visual question. "What kind of dashboard do you want?" is conceptual — use the terminal. "Which of these dashboard layouts feels right?" is visual — use the browser.

## How It Works

The server watches a directory for HTML files and serves the newest one to the browser. You write HTML content, the user sees it in their browser and can click to select options. Selections are recorded to a `.events` file that you read on your next turn.

**Content fragments vs full documents:** If your HTML file starts with `<!DOCTYPE` or `<html`, the server serves it as-is. Otherwise, the server wraps your content in a frame template automatically — adding header, CSS theme, selection indicator, and interactive infrastructure. **Write content fragments by default.**

## Starting a Session

The visual companion server lives in `scripts/visual-companion/`. It's a zero-dependency Node.js server that watches a directory for HTML files and serves them with WebSocket live-reload.

```bash
# Start with project persistence (mockups saved to .blueprint/companion/)
scripts/visual-companion/start-server.sh --project-dir $(pwd)

# Returns JSON: {"type":"server-started","port":52341,"url":"http://localhost:52341","screen_dir":"/path/to/.blueprint/companion/12345-1706000000"}
```

Save `screen_dir` from the response. Tell the user to open the URL.

**Finding connection info:** The server writes startup JSON to `$SCREEN_DIR/.server-info`. If you launched in the background, read that file to get the URL and port.

**Platform notes:**
- **macOS/Linux:** Default mode works — the script backgrounds the server itself
- **Windows/Git Bash:** Auto-detects and uses foreground mode. Set `run_in_background: true` on the Bash tool call
- **Codex:** Auto-detects `CODEX_CI` and switches to foreground mode

**Stopping:**
```bash
scripts/visual-companion/stop-server.sh $SCREEN_DIR
```

Persistent directories (`.blueprint/companion/`) are kept for later reference. Only `/tmp` sessions get cleaned up.

## The Loop

1. **Write HTML** to a new file in `screen_dir` (or `.blueprint/brainstorm/`):
   - Use semantic filenames: `architecture.html`, `domain-boundaries.html`, `data-flow.html`
   - Never reuse filenames — each screen gets a fresh file
   - Use the Write tool — never cat/heredoc

2. **Tell user what to expect and end your turn:**
   - Remind them of the URL
   - Brief text summary of what's on screen
   - Ask them to respond in terminal

3. **On your next turn:**
   - Read `.events` if it exists for browser interactions
   - Merge with terminal text for full picture

4. **Iterate or advance** — revise current screen if needed, only move on when validated

5. **Unload when returning to terminal** — push a waiting screen when switching back to text-only questions

## CSS Classes Available

### Options (A/B/C choices)
```html
<div class="options">
  <div class="option" data-choice="a" onclick="toggleSelect(this)">
    <div class="letter">A</div>
    <div class="content">
      <h3>Title</h3>
      <p>Description</p>
    </div>
  </div>
</div>
```

### Cards (visual designs)
```html
<div class="cards">
  <div class="card" data-choice="design1" onclick="toggleSelect(this)">
    <div class="card-body">
      <h3>Name</h3>
      <p>Description</p>
    </div>
  </div>
</div>
```

### Mockup container
```html
<div class="mockup">
  <div class="mockup-header">Preview: Architecture Overview</div>
  <div class="mockup-body"><!-- your diagram HTML --></div>
</div>
```

### Split view (side-by-side)
```html
<div class="split">
  <div class="mockup"><!-- left --></div>
  <div class="mockup"><!-- right --></div>
</div>
```

### Pros/Cons
```html
<div class="pros-cons">
  <div class="pros"><h4>Pros</h4><ul><li>Benefit</li></ul></div>
  <div class="cons"><h4>Cons</h4><ul><li>Drawback</li></ul></div>
</div>
```

## Design Tips

- **Scale fidelity to the question** — boxes and arrows for architecture, wireframes for UI
- **Explain the question on each page** — "Which domain boundary makes more sense?" not just "Pick one"
- **Iterate before advancing** — if feedback changes current screen, write a new version
- **2-4 options max** per screen
- **Keep diagrams simple** — focus on relationships and boundaries, not visual polish
