### Iteration 1 — 2026-03-17
- **Task:** T-043 — Wire tick loop: capture, diff, progress, auto-yes, status + T-044 (implicit) + T-054 (DiffTab scroll) + T-048 (scroll actions) + T-051 (--autoyes flag) + T-052 (status progress) + T-056 (program preflight)
- **Tier:** 6
- **Status:** DONE
- **Files:** internal/tui/app.go (rewritten), internal/tui/app_test.go (updated), internal/tui/keyhandler.go (added ActionTextInput, ActionBackspace, text input overlay support), internal/tui/difftab.go (scroll position applied), cmd/blueprint/main.go (rewritten with --autoyes, progress, preflight)
- **Validation:** Build P, Tests all P, Acceptance: tick captures content P, tick refreshes diff P, tick updates progress P, tick runs auto-yes P, tick detects status P, tabs instantiated and piped P, scroll handling P, --autoyes flag P, status progress P, program preflight P
- **Note:** T-043, T-044, T-048, T-051, T-052, T-054, T-056 all implemented in single iteration because they are tightly coupled (can't wire tick without tab instances; scroll actions need diff tab wiring; CLI needs to pass autoyes to Run)
- **Next:** T-045 — Handle ActionOpen (tmux attach/detach)

### Iteration 2 — 2026-03-17
- **Task:** T-045 — Handle ActionOpen: tmux attach/detach with TUI suspend
- **Tier:** 6
- **Status:** DONE
- **Files:** internal/tui/app.go (attachCmd, attachFinishedMsg, ActionOpen handler)
- **Validation:** Build P, Tests P, Acceptance: Enter attaches to tmux P, tea.ExecProcess suspends TUI P, resume on detach P
- **Next:** T-046 — Handle ActionPush

### Iteration 3 — 2026-03-17
- **Task:** T-046 — Handle ActionPush + T-047 — Handle ActionCheckout/ActionResume
- **Tier:** 6
- **Status:** DONE
- **Files:** internal/tui/app.go (pendingAction field, ActionPush/Checkout/Resume handlers, push dispatch in ActionConfirmYes)
- **Validation:** Build P, Tests P, Acceptance: push with confirmation P, checkout switches to terminal tab P, resume calls sessionMgr.Resume P
- **Next:** T-049 — Integrate FrontierPicker into new-instance flow
