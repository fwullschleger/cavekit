package tui

import (
	"fmt"

	"github.com/JuliusBrussee/cavekit/internal/session"
)

// StatusLine renders contextual information about the selected instance.
type StatusLine struct {
	instance *session.Instance
	width    int
}

// NewStatusLine creates a status line component.
func NewStatusLine() *StatusLine {
	return &StatusLine{}
}

// SetInstance updates the displayed instance.
func (s *StatusLine) SetInstance(inst *session.Instance) {
	s.instance = inst
}

// SetWidth updates the available width.
func (s *StatusLine) SetWidth(w int) {
	s.width = w
}

// Height returns the rendered height.
func (s *StatusLine) Height() int {
	return 1
}

// View renders the status line.
func (s *StatusLine) View() string {
	if s.width <= 0 {
		return ""
	}

	content := " No instance selected"
	if s.instance != nil {
		inst := s.instance
		parts := inst.Title

		parts += " │ " + inst.Status.String()

		if inst.CurrentTier > 0 {
			parts += fmt.Sprintf(" │ Tier %d", inst.CurrentTier)
		}

		if inst.TasksTotal > 0 {
			parts += fmt.Sprintf(" │ %d/%d tasks", inst.TasksDone, inst.TasksTotal)
		}

		if inst.DiffAdded > 0 || inst.DiffRemoved > 0 {
			parts += fmt.Sprintf(" │ +%d/-%d", inst.DiffAdded, inst.DiffRemoved)
		}

		if inst.BranchName != "" {
			parts += " │ " + inst.BranchName
		}

		content = " " + parts
	}

	return StatusLineStyle.Width(s.width).Render(content)
}
