package tmux

import (
	"context"
	"fmt"
)

// CapturePane captures the visible content of a tmux pane with ANSI escape sequences.
func (m *Manager) CapturePane(ctx context.Context, name string) (string, error) {
	sessionName := SanitizeName(name)
	res, err := m.exec.Run(ctx, "tmux", "capture-pane", "-p", "-e", "-J", "-t", sessionName)
	if err != nil {
		return "", fmt.Errorf("tmux capture-pane: %w", err)
	}
	if res.ExitCode != 0 {
		return "", fmt.Errorf("tmux capture-pane failed (exit %d): %s", res.ExitCode, res.Stderr)
	}
	return res.Stdout, nil
}

// CaptureScrollback captures full scrollback history of a tmux pane.
func (m *Manager) CaptureScrollback(ctx context.Context, name string) (string, error) {
	sessionName := SanitizeName(name)
	res, err := m.exec.Run(ctx, "tmux", "capture-pane", "-p", "-e", "-J",
		"-S", "-", "-E", "-", "-t", sessionName)
	if err != nil {
		return "", fmt.Errorf("tmux capture-pane scrollback: %w", err)
	}
	if res.ExitCode != 0 {
		return "", fmt.Errorf("tmux capture-pane scrollback failed (exit %d): %s", res.ExitCode, res.Stderr)
	}
	return res.Stdout, nil
}
