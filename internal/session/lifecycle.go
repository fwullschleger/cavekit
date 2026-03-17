package session

import (
	"context"
	"fmt"
	"time"

	"github.com/julb/blueprint-monitor/internal/tmux"
	"github.com/julb/blueprint-monitor/internal/worktree"
)

// Manager orchestrates instance lifecycle operations.
type Manager struct {
	tmux     *tmux.Manager
	worktree *worktree.Manager
}

// NewManager creates a session manager.
func NewManager(tmuxMgr *tmux.Manager, wtMgr *worktree.Manager) *Manager {
	return &Manager{
		tmux:     tmuxMgr,
		worktree: wtMgr,
	}
}

// Create allocates a new instance with the given title and frontier info.
func (m *Manager) Create(title, frontierPath, frontierName, program string) *Instance {
	inst := NewInstance(title, frontierPath, program)
	inst.TmuxSession = tmux.SessionName(frontierName)
	return inst
}

// Start creates the worktree and tmux session, then sends the build command.
func (m *Manager) Start(ctx context.Context, inst *Instance, projectRoot, frontierName string, startupDelay time.Duration) error {
	inst.Status = StatusLoading

	// Create worktree
	wtPath, err := m.worktree.Create(ctx, projectRoot, frontierName)
	if err != nil {
		return fmt.Errorf("create worktree: %w", err)
	}
	inst.WorktreePath = wtPath

	// Create tmux session
	err = m.tmux.CreateSession(ctx, frontierName, wtPath, inst.Program)
	if err != nil {
		return fmt.Errorf("create tmux session: %w", err)
	}
	inst.TmuxSession = tmux.SessionName(frontierName)
	inst.Status = StatusRunning

	// Wait for startup, then send the build command
	if startupDelay > 0 {
		go func() {
			time.Sleep(startupDelay)
			cmd := fmt.Sprintf("/bp:build --filter %s", frontierName)
			m.tmux.SendCommand(ctx, frontierName, cmd)
		}()
	} else {
		cmd := fmt.Sprintf("/bp:build --filter %s", frontierName)
		m.tmux.SendCommand(ctx, frontierName, cmd)
	}

	return nil
}

// Pause detaches an instance from TUI tracking (session keeps running).
func (m *Manager) Pause(inst *Instance) {
	inst.Status = StatusPaused
}

// Resume re-attaches an instance to TUI tracking.
func (m *Manager) Resume(ctx context.Context, inst *Instance) {
	if m.tmux.Exists(ctx, inst.TmuxSession) {
		inst.Status = StatusRunning
	}
}

// Kill destroys the tmux session and optionally removes the worktree.
func (m *Manager) Kill(ctx context.Context, inst *Instance, projectRoot string, removeWorktree bool) error {
	// Kill tmux session
	if err := m.tmux.Kill(ctx, inst.TmuxSession); err != nil {
		// Non-fatal: session might already be gone
	}

	if removeWorktree && inst.WorktreePath != "" {
		// Derive frontier name from worktree path
		frontierName := deriveFrontierNameFromWorktree(inst.WorktreePath, projectRoot)
		if frontierName != "" {
			m.worktree.Remove(ctx, projectRoot, frontierName)
		}
	}

	inst.Status = StatusDone
	return nil
}

func deriveFrontierNameFromWorktree(wtPath, projectRoot string) string {
	// WorktreePath format: {root}/../{name}-blueprint-{frontier}
	// We need to extract the frontier name
	prefix := worktree.WorktreePath(projectRoot, "")
	if len(wtPath) > len(prefix) {
		return wtPath[len(prefix):]
	}
	return ""
}
