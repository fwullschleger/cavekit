package tmux

import (
	"context"
	"strings"
	"testing"

	"github.com/julb/blueprint-monitor/internal/exec"
)

func TestManager_CapturePane(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		if len(c.Args) > 0 && c.Args[0] == "capture-pane" {
			// Verify flags include -p -e -J
			args := strings.Join(c.Args, " ")
			if !strings.Contains(args, "-p") || !strings.Contains(args, "-e") || !strings.Contains(args, "-J") {
				t.Errorf("capture-pane missing flags, got: %s", args)
			}
			return exec.Result{Stdout: "$ claude\nThinking...\n", ExitCode: 0}, nil
		}
		return exec.Result{ExitCode: 0}, nil
	})

	mgr := NewManager(mock)
	content, err := mgr.CapturePane(context.Background(), "test")
	if err != nil {
		t.Fatalf("CapturePane: %v", err)
	}
	if content != "$ claude\nThinking...\n" {
		t.Errorf("content = %q, unexpected", content)
	}
}

func TestManager_CaptureScrollback(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		args := strings.Join(c.Args, " ")
		// Verify scrollback flags -S - -E -
		if strings.Contains(args, "-S -") && strings.Contains(args, "-E -") {
			return exec.Result{Stdout: "line1\nline2\nline3\n", ExitCode: 0}, nil
		}
		return exec.Result{ExitCode: 0}, nil
	})

	mgr := NewManager(mock)
	content, err := mgr.CaptureScrollback(context.Background(), "test")
	if err != nil {
		t.Fatalf("CaptureScrollback: %v", err)
	}
	if !strings.Contains(content, "line1") {
		t.Errorf("scrollback should contain line1, got %q", content)
	}
}

func TestManager_CapturePane_Error(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		return exec.Result{ExitCode: 1, Stderr: "session not found"}, nil
	})

	mgr := NewManager(mock)
	_, err := mgr.CapturePane(context.Background(), "missing")
	if err == nil {
		t.Error("CapturePane should fail on non-zero exit")
	}
}
