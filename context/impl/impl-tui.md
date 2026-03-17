---
created: "2026-03-17T12:00:00Z"
last_edited: "2026-03-17T12:00:00Z"
---
# Implementation Tracking: TUI

| Task | Status | Notes |
|------|--------|-------|
| T-043 | DONE | Wired tick loop: onTick captures preview, refreshes diff, updates progress, runs auto-yes, detects status. Added PreviewTab/DiffTab/TerminalTab to App struct. Added session management (sessionMgr, store, autoYes, statusDetector). Added createInstanceCmd, removeInstance, saveState. Added text input overlay handling (ActionTextInput, ActionBackspace). Added ActionScrollUp/Down handling. Added mouse click handling. Added instanceCreatedMsg flow. |
| T-044 | DONE | Implicitly covered by T-043 — PreviewTab, DiffTab, TerminalTab instantiated in NewApp and piped to TabContent in onTick. |
| T-045 | DONE | ActionOpen handled: tea.ExecProcess suspends TUI, runs tmux attach-session, resumes on detach. |
| T-046 | DONE | ActionPush: confirmation overlay, then worktree.Push with --set-upstream. Uses pendingAction to distinguish kill vs push confirms. |
| T-047 | DONE | ActionCheckout: switches to terminal tab and ensures session in worktree. ActionResume: calls sessionMgr.Resume for paused instances. |
| T-054 | DONE | DiffTab.Content() now applies scrollPos to slice output lines. |
