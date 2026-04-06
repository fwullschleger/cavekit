package session

import (
	"context"

	"github.com/JuliusBrussee/cavekit/internal/tmux"
)

// AutoYes monitors pane content and auto-approves permission prompts.
type AutoYes struct {
	tmuxMgr  *tmux.Manager
	detector *tmux.StatusDetector
	enabled  bool
}

// NewAutoYes creates an auto-yes handler.
func NewAutoYes(tmuxMgr *tmux.Manager, enabled bool) *AutoYes {
	return &AutoYes{
		tmuxMgr:  tmuxMgr,
		detector: tmux.NewStatusDetector(tmuxMgr),
		enabled:  enabled,
	}
}

// Check examines pane status and auto-approves if enabled.
// Returns true if an approval was sent.
func (a *AutoYes) Check(ctx context.Context, name string) bool {
	if !a.enabled {
		return false
	}

	status, err := a.detector.Detect(ctx, name)
	if err != nil {
		return false
	}

	switch status {
	case tmux.PanePrompt:
		// Send Enter to approve the permission prompt
		a.tmuxMgr.SendEnter(ctx, name)
		return true
	case tmux.PaneTrust:
		// Send Enter to dismiss trust prompt
		a.tmuxMgr.SendEnter(ctx, name)
		return true
	}

	return false
}

// SetEnabled toggles auto-yes mode.
func (a *AutoYes) SetEnabled(enabled bool) {
	a.enabled = enabled
}

// IsEnabled returns the current state.
func (a *AutoYes) IsEnabled() bool {
	return a.enabled
}
