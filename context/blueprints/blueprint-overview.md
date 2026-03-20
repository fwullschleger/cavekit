---
created: "2026-03-17T00:00:00Z"
last_edited: "2026-03-20T00:00:00Z"
---

# Spec Overview

## Project
**blueprint-monitor** — A Go TUI application for managing multiple parallel Claude Code agents executing Blueprint sites. Replaces the current bash/tmux launcher with a flicker-free, claude-squad-style interface that adds Blueprint-specific progress tracking.

## Domain Index
| Domain | Spec File | Requirements | Status | Description |
|--------|-----------|-------------|--------|-------------|
| tmux | blueprint-tmux.md | 5 | DRAFT | Detached tmux session lifecycle, capture, attach/detach |
| worktree | blueprint-worktree.md | 4 | DRAFT | Git worktree creation, diff stats, discovery |
| site | blueprint-site.md | 5 | DRAFT | Site file discovery, parsing, task status tracking |
| session | blueprint-session.md | 6 | DRAFT | Instance model, lifecycle, persistence, progress |
| tui | blueprint-tui.md | 11 | DRAFT | Bubbletea TUI with list, tabs, overlays, Blueprint progress |
| cli | blueprint-cli.md | 5 | DRAFT | Binary, subcommands, config |
| spec-sync | blueprint-spec-sync.md | 4 | DRAFT | Living specs — bidirectional revision, changelog, drift detection |
| build-lifecycle | blueprint-build-lifecycle.md | 5 | DRAFT | Worktree freshness, env forwarding, failure recovery, archive on stop |

## Cross-Reference Map
| Domain A | Interacts With | Interaction Type |
|----------|---------------|-----------------|
| session | tmux | session creates and controls tmux sessions |
| session | worktree | session creates worktrees for isolation |
| session | site | session reads site for progress data |
| tui | session | TUI displays and controls sessions |
| tui | tmux | TUI captures pane content for preview |
| tui | site | TUI displays site progress |
| tui | worktree | TUI displays diff stats |
| cli | tui | CLI launches TUI |
| cli | session | CLI loads/saves session state |
| cli | tmux | kill command cleans up tmux sessions |
| cli | worktree | kill/status commands interact with worktrees |
| spec-sync | site | drift detection reads task-to-requirement mappings |
| spec-sync | build-lifecycle | worktree changes must be on main before revise scans |
| build-lifecycle | worktree | builds on existing worktree creation primitives |
| build-lifecycle | session | instance lifecycle triggers build lifecycle operations |

## Dependency Graph
```
Tier 0 (no dependencies):    tmux, worktree, site
Tier 1 (depends on Tier 0):  session (depends on tmux, worktree, site)
Tier 2 (depends on Tier 1):  tui (depends on session, tmux, site, worktree)
Tier 3 (depends on Tier 2):  cli (depends on tui, session)

Tier 0 (no dependencies):    spec-sync R2 (changelog format), build-lifecycle R1/R2 (rebase, env vars)
Tier 1 (depends on Tier 0):  spec-sync R1 (revision, depends on R2), build-lifecycle R3 (recovery, depends on R1/R2)
Tier 2 (depends on Tier 1):  spec-sync R3 (overview consistency), spec-sync R4 (drift detection), build-lifecycle R4 (health check)
```

## Technology Stack
- **Language:** Go 1.22+
- **TUI framework:** charmbracelet/bubbletea
- **Styling:** charmbracelet/lipgloss
- **Components:** charmbracelet/bubbles (spinner, viewport, textinput)
- **PTY:** creack/pty
- **Tmux:** exec.Command wrapping tmux CLI
- **Git:** exec.Command wrapping git CLI
