// Package tmux manages detached tmux sessions as the execution backend
// for Claude Code instances.
package tmux

import (
	"context"
	"fmt"
	"strings"

	"github.com/JuliusBrussee/cavekit/internal/exec"
)

const (
	// SessionPrefix is prepended to all Cavekit tmux session names.
	SessionPrefix = "bp_"
	historyLimit  = "10000"
)

// Manager handles tmux session lifecycle operations.
type Manager struct {
	exec exec.Executor
}

// NewManager creates a tmux manager with the given executor.
func NewManager(executor exec.Executor) *Manager {
	return &Manager{exec: executor}
}

// SanitizeName converts a raw name into a valid tmux session name.
// Replaces whitespace and dots with underscores, adds prefix.
func SanitizeName(name string) string {
	s := strings.ReplaceAll(name, " ", "_")
	s = strings.ReplaceAll(s, ".", "_")
	s = strings.ReplaceAll(s, ":", "_")
	if !strings.HasPrefix(s, SessionPrefix) {
		s = SessionPrefix + s
	}
	return s
}

// CreateSession creates a new detached tmux session running the given program.
func (m *Manager) CreateSession(ctx context.Context, name, workDir, program string) error {
	sessionName := SanitizeName(name)

	// Create detached session with the specified program
	res, err := m.exec.Run(ctx, "tmux", "new-session", "-d",
		"-s", sessionName,
		"-c", workDir,
		program)
	if err != nil {
		return fmt.Errorf("tmux new-session: %w", err)
	}
	if res.ExitCode != 0 {
		return fmt.Errorf("tmux new-session failed (exit %d): %s", res.ExitCode, res.Stderr)
	}

	// Set history limit
	m.exec.Run(ctx, "tmux", "set-option", "-t", sessionName, "history-limit", historyLimit)

	// Enable mouse
	m.exec.Run(ctx, "tmux", "set-option", "-t", sessionName, "mouse", "on")

	return nil
}

// Exists checks if a tmux session with the given name exists.
func (m *Manager) Exists(ctx context.Context, name string) bool {
	sessionName := SanitizeName(name)
	res, err := m.exec.Run(ctx, "tmux", "has-session", "-t", sessionName)
	return err == nil && res.ExitCode == 0
}

// Kill destroys a tmux session.
func (m *Manager) Kill(ctx context.Context, name string) error {
	sessionName := SanitizeName(name)
	res, err := m.exec.Run(ctx, "tmux", "kill-session", "-t", sessionName)
	if err != nil {
		return fmt.Errorf("tmux kill-session: %w", err)
	}
	if res.ExitCode != 0 {
		return fmt.Errorf("tmux kill-session failed (exit %d): %s", res.ExitCode, res.Stderr)
	}
	return nil
}

// ListSessions returns all Cavekit tmux sessions (those with the bp_ prefix).
func (m *Manager) ListSessions(ctx context.Context) ([]string, error) {
	res, err := m.exec.Run(ctx, "tmux", "list-sessions", "-F", "#{session_name}")
	if err != nil {
		return nil, fmt.Errorf("tmux list-sessions: %w", err)
	}
	if res.ExitCode != 0 {
		// No server running = no sessions
		return nil, nil
	}

	var sessions []string
	for _, line := range strings.Split(strings.TrimSpace(res.Stdout), "\n") {
		if line != "" && strings.HasPrefix(line, SessionPrefix) {
			sessions = append(sessions, line)
		}
	}
	return sessions, nil
}

// SessionName returns the sanitized tmux session name for a given raw name.
func SessionName(name string) string {
	return SanitizeName(name)
}
