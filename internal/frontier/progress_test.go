package frontier

import "testing"

func TestProgressString_InProgress(t *testing.T) {
	got := ProgressString("auth", FrontierInProgress, ProgressSummary{Done: 3, Total: 12}, "T-004")
	want := "⟳ auth 3/12 [T-004]"
	if got != want {
		t.Errorf("ProgressString = %q, want %q", got, want)
	}
}

func TestProgressString_Done(t *testing.T) {
	got := ProgressString("auth", FrontierDone, ProgressSummary{Done: 12, Total: 12}, "")
	want := "✓ auth 12/12"
	if got != want {
		t.Errorf("ProgressString = %q, want %q", got, want)
	}
}

func TestProgressString_Available(t *testing.T) {
	got := ProgressString("payments", FrontierAvailable, ProgressSummary{Done: 0, Total: 8}, "")
	want := "· payments 0/8"
	if got != want {
		t.Errorf("ProgressString = %q, want %q", got, want)
	}
}

func TestProgressString_NoCurrentTask(t *testing.T) {
	got := ProgressString("auth", FrontierInProgress, ProgressSummary{Done: 3, Total: 12}, "")
	want := "⟳ auth 3/12"
	if got != want {
		t.Errorf("ProgressString = %q, want %q", got, want)
	}
}
