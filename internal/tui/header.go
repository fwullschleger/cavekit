package tui

import (
	"fmt"
	"path/filepath"

	"github.com/charmbracelet/lipgloss"
)

// Header renders the top bar with app name, project root, and aggregate stats.
type Header struct {
	projectRoot string
	total       int
	running     int
	done        int
	totalTasks  int
	doneTasks   int
	width       int
}

// NewHeader creates a header component.
func NewHeader(projectRoot string) *Header {
	return &Header{projectRoot: projectRoot}
}

// SetStats updates aggregate instance statistics.
func (h *Header) SetStats(total, running, done, doneTasks, totalTasks int) {
	h.total = total
	h.running = running
	h.done = done
	h.totalTasks = totalTasks
	h.doneTasks = doneTasks
}

// SetWidth updates the available width.
func (h *Header) SetWidth(w int) {
	h.width = w
}

// Height returns the rendered height of the header.
func (h *Header) Height() int {
	return 1
}

// View renders the header bar.
func (h *Header) View() string {
	if h.width <= 0 {
		return ""
	}

	title := HeaderTitleStyle.Render("Cavekit")

	project := ""
	if h.projectRoot != "" {
		project = HeaderProjectStyle.Render(filepath.Base(h.projectRoot))
	}

	stats := ""
	if h.total > 0 {
		stats = HeaderStatsStyle.Render(
			fmt.Sprintf("%d agents │ %d running │ %d/%d tasks", h.total, h.running, h.doneTasks, h.totalTasks),
		)
	}

	// Calculate spacing
	titleW := lipgloss.Width(title)
	projectW := lipgloss.Width(project)
	statsW := lipgloss.Width(stats)

	gap1 := max((h.width-titleW-projectW-statsW)/2, 1)
	gap2 := max(h.width-titleW-gap1-projectW-statsW, 0)

	return HeaderStyle.Width(h.width).Render(
		title + spaces(gap1) + project + spaces(gap2) + stats,
	)
}

func spaces(n int) string {
	if n <= 0 {
		return ""
	}
	b := make([]byte, n)
	for i := range b {
		b[i] = ' '
	}
	return string(b)
}
