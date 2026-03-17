package frontier

import "fmt"

// ProgressString generates a compact progress display for a frontier.
// Format: {icon} {name} {done}/{total} (e.g., "⟳ auth 3/12")
// Includes current task ID if in-progress.
func ProgressString(name string, status FrontierStatus, summary ProgressSummary, currentTaskID string) string {
	base := fmt.Sprintf("%s %s %d/%d", status.Icon(), name, summary.Done, summary.Total)
	if status == FrontierInProgress && currentTaskID != "" {
		base += " [" + currentTaskID + "]"
	}
	return base
}
