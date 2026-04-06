package tui

import (
	"context"

	"github.com/JuliusBrussee/cavekit/internal/tmux"
)

// TerminalTab manages a separate tmux session for shell access in the worktree.
type TerminalTab struct {
	tmuxMgr  *tmux.Manager
	sessions map[string]string // instance title → terminal session name
	content  string
}

// NewTerminalTab creates a terminal tab.
func NewTerminalTab(tmuxMgr *tmux.Manager) *TerminalTab {
	return &TerminalTab{
		tmuxMgr:  tmuxMgr,
		sessions: make(map[string]string),
	}
}

// EnsureSession creates a terminal session for the instance if it doesn't exist.
func (t *TerminalTab) EnsureSession(ctx context.Context, instanceTitle, worktreePath string) string {
	sessionName := "bp_term_" + instanceTitle

	if _, exists := t.sessions[instanceTitle]; !exists {
		// Create the terminal session
		err := t.tmuxMgr.CreateSession(ctx, "term_"+instanceTitle, worktreePath, "zsh")
		if err == nil {
			t.sessions[instanceTitle] = sessionName
		}
	}

	return sessionName
}

// Capture updates the terminal pane content.
func (t *TerminalTab) Capture(ctx context.Context, instanceTitle string) {
	sessionName, exists := t.sessions[instanceTitle]
	if !exists {
		t.content = "Press Enter to open terminal."
		return
	}

	content, err := t.tmuxMgr.CapturePane(ctx, sessionName)
	if err != nil {
		t.content = "Terminal session error: " + err.Error()
		return
	}
	t.content = content
}

// Content returns the current terminal content.
func (t *TerminalTab) Content() string {
	if t.content == "" {
		return "Press Enter to open terminal."
	}
	return t.content
}

// HasSession returns true if a terminal session exists for the instance.
func (t *TerminalTab) HasSession(instanceTitle string) bool {
	_, exists := t.sessions[instanceTitle]
	return exists
}

// SessionName returns the tmux session name for the instance's terminal.
func (t *TerminalTab) SessionName(instanceTitle string) string {
	return t.sessions[instanceTitle]
}
