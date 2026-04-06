package worktree

import (
	"context"
	"strings"
	"testing"

	"github.com/JuliusBrussee/cavekit/internal/exec"
)

func TestParseDiffStat(t *testing.T) {
	tests := []struct {
		input string
		want  DiffStats
	}{
		{
			" 5 files changed, 120 insertions(+), 30 deletions(-)",
			DiffStats{FilesChanged: 5, Insertions: 120, Deletions: 30},
		},
		{
			" 1 file changed, 10 insertions(+)",
			DiffStats{FilesChanged: 1, Insertions: 10},
		},
		{
			" file1.go | 10 ++++\n file2.go | 5 ++--\n 2 files changed, 12 insertions(+), 3 deletions(-)",
			DiffStats{FilesChanged: 2, Insertions: 12, Deletions: 3},
		},
		{"", DiffStats{}},
	}
	for _, tt := range tests {
		got := parseDiffStat(tt.input)
		if got != tt.want {
			t.Errorf("parseDiffStat(%q) = %+v, want %+v", tt.input, got, tt.want)
		}
	}
}

func TestDiffStats_String(t *testing.T) {
	s := DiffStats{FilesChanged: 3, Insertions: 50, Deletions: 10}
	if got := s.String(); got != "3 files, +50/-10" {
		t.Errorf("String() = %q", got)
	}
}

func TestManager_DiffStat(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("git", func(c exec.Call) (exec.Result, error) {
		return exec.Result{
			Stdout:   " 3 files changed, 42 insertions(+), 7 deletions(-)\n",
			ExitCode: 0,
		}, nil
	})

	mgr := NewManager(mock)
	stats, err := mgr.DiffStat(context.Background(), "/tmp/wt")
	if err != nil {
		t.Fatalf("DiffStat: %v", err)
	}
	if stats.FilesChanged != 3 || stats.Insertions != 42 || stats.Deletions != 7 {
		t.Errorf("stats = %+v", stats)
	}
}

func TestManager_Diff(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("git", func(c exec.Call) (exec.Result, error) {
		return exec.Result{
			Stdout:   "diff --git a/file.go b/file.go\n+new line\n",
			ExitCode: 0,
		}, nil
	})

	mgr := NewManager(mock)
	diff, err := mgr.Diff(context.Background(), "/tmp/wt")
	if err != nil {
		t.Fatalf("Diff: %v", err)
	}
	if !strings.Contains(diff, "+new line") {
		t.Errorf("diff should contain +new line, got %q", diff)
	}
}

func TestManager_DiffStat_NoMain(t *testing.T) {
	mock := exec.NewMockExecutor()
	mock.OnCommand("git", func(c exec.Call) (exec.Result, error) {
		return exec.Result{ExitCode: 128, Stderr: "unknown revision"}, nil
	})

	mgr := NewManager(mock)
	stats, err := mgr.DiffStat(context.Background(), "/tmp/wt")
	if err != nil {
		t.Fatalf("DiffStat should not error on missing main: %v", err)
	}
	if stats.FilesChanged != 0 {
		t.Errorf("should return empty stats, got %+v", stats)
	}
}
