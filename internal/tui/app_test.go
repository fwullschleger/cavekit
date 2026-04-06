package tui

import (
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

func newTestApp() App {
	// Use empty project root and program for unit tests
	return NewApp("", "", false)
}

func TestNewApp(t *testing.T) {
	app := newTestApp()
	if app.activeTab != TabPreview {
		t.Errorf("default tab should be Preview, got %v", app.activeTab)
	}
	if app.quitting {
		t.Error("should not be quitting on init")
	}
	if app.previewTab == nil {
		t.Error("previewTab should be initialized")
	}
	if app.diffTab == nil {
		t.Error("diffTab should be initialized")
	}
	if app.terminalTab == nil {
		t.Error("terminalTab should be initialized")
	}
	if app.sessionMgr == nil {
		t.Error("sessionMgr should be initialized")
	}
	if app.autoYes == nil {
		t.Error("autoYes should be initialized")
	}
	if app.statusDetector == nil {
		t.Error("statusDetector should be initialized")
	}
}

func TestApp_Update_Quit(t *testing.T) {
	app := newTestApp()
	model, cmd := app.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("q")})
	updated := model.(App)
	if !updated.quitting {
		t.Error("should be quitting after 'q'")
	}
	if cmd == nil {
		t.Error("should return tea.Quit command")
	}
}

func TestApp_Update_TabSwitch(t *testing.T) {
	app := newTestApp()
	if app.activeTab != TabPreview {
		t.Fatal("should start on Preview")
	}

	model, _ := app.Update(tea.KeyMsg{Type: tea.KeyTab})
	updated := model.(App)
	if updated.activeTab != TabDiff {
		t.Errorf("after tab, should be Diff, got %v", updated.activeTab)
	}

	model, _ = updated.Update(tea.KeyMsg{Type: tea.KeyTab})
	updated = model.(App)
	if updated.activeTab != TabTerminal {
		t.Errorf("after tab, should be Terminal, got %v", updated.activeTab)
	}

	model, _ = updated.Update(tea.KeyMsg{Type: tea.KeyTab})
	updated = model.(App)
	if updated.activeTab != TabPreview {
		t.Errorf("after tab, should wrap to Preview, got %v", updated.activeTab)
	}
}

func TestApp_Update_Navigate(t *testing.T) {
	app := newTestApp()
	model, _ := app.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("j")})
	updated := model.(App)
	// With no instances, selectedIndex clamps to 0
	if updated.selectedIndex < 0 {
		t.Errorf("j should not go negative, got %d", updated.selectedIndex)
	}

	model, _ = updated.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("k")})
	updated = model.(App)
	if updated.selectedIndex != 0 {
		t.Errorf("k should not go below 0, got %d", updated.selectedIndex)
	}
}

func TestApp_Update_Resize(t *testing.T) {
	app := newTestApp()
	model, _ := app.Update(tea.WindowSizeMsg{Width: 120, Height: 40})
	updated := model.(App)
	if updated.width != 120 || updated.height != 40 {
		t.Errorf("size should be 120x40, got %dx%d", updated.width, updated.height)
	}
}

func TestApp_View_BeforeResize(t *testing.T) {
	app := newTestApp()
	view := app.View()
	if view != "Initializing..." {
		t.Errorf("before resize, should show initializing, got %q", view)
	}
}

func TestApp_View_AfterResize(t *testing.T) {
	app := newTestApp()
	model, _ := app.Update(tea.WindowSizeMsg{Width: 100, Height: 30})
	updated := model.(App)
	view := updated.View()

	// With no instances selected, the right panel shows the dashboard
	if !strings.Contains(view, "Cavekit") {
		t.Error("view should contain Cavekit header or dashboard title")
	}
	if !strings.Contains(view, "quit") {
		t.Error("view should contain menu with quit")
	}
}

func TestApp_Update_Tick_SchedulesNext(t *testing.T) {
	app := newTestApp()
	_, cmd := app.Update(tickMsg(time.Now()))
	if cmd == nil {
		t.Error("tick should schedule next tick")
	}
}

func TestApp_Update_NewOverlay(t *testing.T) {
	app := newTestApp()
	model, _ := app.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("n")})
	updated := model.(App)
	if !updated.overlay.IsActive() {
		t.Error("'n' should show overlay")
	}
	if updated.overlay.Active != OverlayTextInput {
		t.Errorf("overlay should be TextInput, got %v", updated.overlay.Active)
	}
}

func TestApp_Update_ScrollActions(t *testing.T) {
	app := newTestApp()
	// Scroll down should not panic with empty diff
	model, _ := app.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("J")})
	updated := model.(App)
	_ = updated // No panic = pass

	// Scroll up should not panic
	model, _ = updated.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("K")})
	_ = model // No panic = pass
}

func TestTab_String(t *testing.T) {
	if TabPreview.String() != "Preview" {
		t.Errorf("TabPreview.String() = %q", TabPreview.String())
	}
	if TabDiff.String() != "Diff" {
		t.Errorf("TabDiff.String() = %q", TabDiff.String())
	}
	if TabTerminal.String() != "Terminal" {
		t.Errorf("TabTerminal.String() = %q", TabTerminal.String())
	}
}
