package tmux

import (
	"context"
	"testing"

	"github.com/JuliusBrussee/cavekit/internal/exec"
)

func TestSanitizeName(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"auth", "bp_auth"},
		{"my session", "bp_my_session"},
		{"build.site", "bp_build_site"},
		{"bp_already", "bp_already"},
		{"host:port", "bp_host_port"},
	}
	for _, tt := range tests {
		if got := SanitizeName(tt.input); got != tt.want {
			t.Errorf("SanitizeName(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestManager_CreateSession(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		return exec.Result{ExitCode: 0}, nil
	})

	mgr := NewManager(mock)
	err := mgr.CreateSession(context.Background(), "test", "/tmp", "claude")
	if err != nil {
		t.Fatalf("CreateSession: %v", err)
	}

	// Should have called: new-session, set-option (history), set-option (mouse)
	if len(mock.Calls) != 3 {
		t.Fatalf("got %d calls, want 3", len(mock.Calls))
	}

	// Verify new-session call
	c := mock.Calls[0]
	if c.Args[0] != "new-session" {
		t.Errorf("first call should be new-session, got %v", c.Args)
	}
	// Verify session name is sanitized
	found := false
	for _, arg := range c.Args {
		if arg == "bp_test" {
			found = true
		}
	}
	if !found {
		t.Errorf("session name should be bp_test, args: %v", c.Args)
	}
}

func TestManager_Exists(t *testing.T) {
	mock := exec.NewMockExecutor()

	mgr := NewManager(mock)

	// Default mock returns exit code 0 → session exists
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		if len(c.Args) > 0 && c.Args[0] == "has-session" {
			return exec.Result{ExitCode: 0}, nil
		}
		return exec.Result{}, nil
	})
	if !mgr.Exists(context.Background(), "test") {
		t.Error("Exists should return true when has-session succeeds")
	}

	// Non-zero exit → doesn't exist
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		return exec.Result{ExitCode: 1}, nil
	})
	if mgr.Exists(context.Background(), "missing") {
		t.Error("Exists should return false when has-session fails")
	}
}

func TestManager_Kill(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		return exec.Result{ExitCode: 0}, nil
	})

	mgr := NewManager(mock)
	err := mgr.Kill(context.Background(), "test")
	if err != nil {
		t.Fatalf("Kill: %v", err)
	}

	last := mock.Calls[len(mock.Calls)-1]
	if last.Args[0] != "kill-session" {
		t.Errorf("expected kill-session, got %v", last.Args)
	}
}

func TestManager_ListSessions(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		return exec.Result{
			Stdout:   "bp_auth\nbp_build\nother_session\n",
			ExitCode: 0,
		}, nil
	})

	mgr := NewManager(mock)
	sessions, err := mgr.ListSessions(context.Background())
	if err != nil {
		t.Fatalf("ListSessions: %v", err)
	}
	if len(sessions) != 2 {
		t.Fatalf("got %d sessions, want 2", len(sessions))
	}
	if sessions[0] != "bp_auth" || sessions[1] != "bp_build" {
		t.Errorf("sessions = %v, want [bp_auth bp_build]", sessions)
	}
}

func TestManager_Kill_FailsOnError(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("tmux", func(c exec.Call) (exec.Result, error) {
		return exec.Result{ExitCode: 1, Stderr: "no such session"}, nil
	})

	mgr := NewManager(mock)
	err := mgr.Kill(context.Background(), "missing")
	if err == nil {
		t.Error("Kill should fail when tmux returns non-zero")
	}
}
