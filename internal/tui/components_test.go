package tui

import (
	"strings"
	"testing"

	"github.com/JuliusBrussee/cavekit/internal/session"
)

func TestInstanceList_Empty(t *testing.T) {
	list := NewInstanceList()
	list.SetSize(40, 20)
	view := list.View()
	if !strings.Contains(view, "No agents yet") {
		t.Errorf("empty list should say no agents: %q", view)
	}
}

func TestInstanceList_WithInstances(t *testing.T) {
	list := NewInstanceList()
	list.SetSize(40, 20)
	list.SetInstances([]*session.Instance{
		{Title: "auth", Status: session.StatusRunning, TasksDone: 3, TasksTotal: 12},
		{Title: "payments", Status: session.StatusReady, TasksDone: 0, TasksTotal: 8},
	})
	list.SetSelected(0)

	view := list.View()
	if !strings.Contains(view, "auth") {
		t.Error("should contain auth")
	}
	if !strings.Contains(view, "payments") {
		t.Error("should contain payments")
	}
	if !strings.Contains(view, "3/12") {
		t.Error("should show progress 3/12")
	}
}

func TestInstanceList_Selected(t *testing.T) {
	list := NewInstanceList()
	list.SetInstances([]*session.Instance{
		{Title: "a"},
		{Title: "b"},
	})
	list.SetSelected(1)
	sel := list.Selected()
	if sel == nil || sel.Title != "b" {
		t.Error("should select b")
	}
}

func TestInstanceList_SelectedBounds(t *testing.T) {
	list := NewInstanceList()
	list.SetInstances([]*session.Instance{{Title: "a"}})
	list.SetSelected(5) // out of bounds
	if list.SelectedIndex() != 0 {
		t.Errorf("should clamp to 0, got %d", list.SelectedIndex())
	}
	list.SetSelected(-1)
	if list.SelectedIndex() != 0 {
		t.Errorf("should clamp to 0, got %d", list.SelectedIndex())
	}
}

func TestTabContent_View(t *testing.T) {
	tc := NewTabContent()
	tc.SetSize(80, 25)
	tc.SetActiveTab(TabPreview)
	tc.SetPreview("Hello from tmux\nLine 2")

	view := tc.View()
	if !strings.Contains(view, "Preview") {
		t.Error("should show Preview tab")
	}
	if !strings.Contains(view, "Hello from tmux") {
		t.Error("should show preview content")
	}
}

func TestTabContent_EmptyContent(t *testing.T) {
	tc := NewTabContent()
	tc.SetSize(80, 25)
	tc.SetActiveTab(TabDiff)

	view := tc.View()
	if !strings.Contains(view, "No changes yet") {
		t.Error("should show default diff message")
	}
}

func TestBottomMenu_View(t *testing.T) {
	menu := NewBottomMenu()
	menu.SetWidth(100)
	view := menu.View()
	if !strings.Contains(view, "quit") {
		t.Error("menu should contain quit")
	}
	if !strings.Contains(view, "new") {
		t.Error("menu should contain new")
	}
}

func TestOverlay_Inactive(t *testing.T) {
	o := NewOverlay()
	if o.IsActive() {
		t.Error("should be inactive by default")
	}
	if o.View() != "" {
		t.Error("inactive overlay should render empty")
	}
}

func TestOverlay_Help(t *testing.T) {
	o := NewOverlay()
	o.SetSize(100, 40)
	o.Show(OverlayHelp, "", "")

	if !o.IsActive() {
		t.Error("should be active")
	}
	view := o.View()
	if !strings.Contains(view, "Navigation") {
		t.Error("help overlay should contain Navigation")
	}
}

func TestOverlay_Confirmation(t *testing.T) {
	o := NewOverlay()
	o.SetSize(100, 40)
	o.Show(OverlayConfirmation, "Kill instance?", "This will destroy the tmux session.")

	view := o.View()
	if !strings.Contains(view, "Kill instance?") {
		t.Error("should contain title")
	}
	if !strings.Contains(view, "yes") {
		t.Error("should contain yes option")
	}
}

func TestOverlay_Hide(t *testing.T) {
	o := NewOverlay()
	o.Show(OverlayHelp, "", "")
	o.Hide()
	if o.IsActive() {
		t.Error("should be inactive after hide")
	}
}
