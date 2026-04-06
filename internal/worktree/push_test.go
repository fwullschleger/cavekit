package worktree

import (
	"context"
	"strings"
	"testing"

	"github.com/JuliusBrussee/cavekit/internal/exec"
)

func TestManager_Push(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("git", func(c exec.Call) (exec.Result, error) {
		return exec.Result{ExitCode: 0}, nil
	})

	mgr := NewManager(mock)
	err := mgr.Push(context.Background(), "/tmp/wt", "test commit")
	if err != nil {
		t.Fatalf("Push: %v", err)
	}

	// Should have: add -A, commit, push
	if len(mock.Calls) != 3 {
		t.Fatalf("got %d calls, want 3", len(mock.Calls))
	}

	// Verify push includes --set-upstream
	pushArgs := strings.Join(mock.Calls[2].Args, " ")
	if !strings.Contains(pushArgs, "--set-upstream") {
		t.Errorf("push should include --set-upstream: %s", pushArgs)
	}
}

func TestManager_Push_NothingToCommit(t *testing.T) {
	mock := exec.NewMockExecutor()
	callIdx := 0
	mock.OnCommand("git", func(c exec.Call) (exec.Result, error) {
		callIdx++
		if callIdx == 2 { // commit
			return exec.Result{ExitCode: 1, Stdout: "nothing to commit"}, nil
		}
		return exec.Result{ExitCode: 0}, nil
	})

	mgr := NewManager(mock)
	err := mgr.Push(context.Background(), "/tmp/wt", "test")
	if err != nil {
		t.Fatalf("Push should not error on nothing to commit: %v", err)
	}
}
