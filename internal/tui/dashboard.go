package tui

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
	"github.com/JuliusBrussee/cavekit/internal/session"
)

// Dashboard renders aggregate information when no instance is selected.
type Dashboard struct {
	instances []*session.Instance
	width     int
	height    int
}

// NewDashboard creates a dashboard component.
func NewDashboard() *Dashboard {
	return &Dashboard{}
}

// SetInstances updates the instance data.
func (d *Dashboard) SetInstances(instances []*session.Instance) {
	d.instances = instances
}

// SetSize updates the available dimensions.
func (d *Dashboard) SetSize(w, h int) {
	d.width = w
	d.height = h
}

// View renders the dashboard.
func (d *Dashboard) View() string {
	if len(d.instances) == 0 {
		content := DashboardTitleStyle.Render("Cavekit Monitor") + "\n\n" +
			lipgloss.NewStyle().Foreground(ColorMuted).Render("No agents running") + "\n\n" +
			lipgloss.NewStyle().Foreground(ColorSecondary).Render("Press ") +
			MenuKeyStyle.Render("n") +
			lipgloss.NewStyle().Foreground(ColorSecondary).Render(" to launch an agent")
		return lipgloss.Place(d.width, d.height, lipgloss.Center, lipgloss.Center, content)
	}

	// Count by status
	var running, ready, paused, total int
	var tasksDone, tasksTotal int
	for _, inst := range d.instances {
		total++
		switch inst.Status {
		case session.StatusRunning:
			running++
		case session.StatusReady:
			ready++
		case session.StatusPaused:
			paused++
		}
		tasksDone += inst.TasksDone
		tasksTotal += inst.TasksTotal
	}

	lines := []string{
		DashboardTitleStyle.Render("Overview"),
		"",
		fmt.Sprintf("  Agents: %d total", total),
	}

	if running > 0 {
		lines = append(lines, fmt.Sprintf("  %s %d running", StatusRunning.String(), running))
	}
	if ready > 0 {
		lines = append(lines, fmt.Sprintf("  %s %d ready", StatusReady.String(), ready))
	}
	if paused > 0 {
		lines = append(lines, fmt.Sprintf("  %s %d paused", StatusPaused.String(), paused))
	}

	if tasksTotal > 0 {
		lines = append(lines, "")
		barWidth := min(30, d.width-6)
		bar := RenderProgressBar(tasksDone, tasksTotal, barWidth)
		lines = append(lines,
			fmt.Sprintf("  Tasks: %d/%d", tasksDone, tasksTotal),
			"  "+bar,
		)
	}

	lines = append(lines, "",
		DashboardHintStyle.Render("  n new │ ? help │ q quit"),
	)

	content := ""
	for i, l := range lines {
		if i > 0 {
			content += "\n"
		}
		content += l
	}

	return lipgloss.Place(d.width, d.height, lipgloss.Center, lipgloss.Center, content)
}
