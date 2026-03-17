// Package tui implements the bubbletea-based terminal user interface.
package tui

import (
	"context"
	osexec "os/exec"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/julb/blueprint-monitor/internal/exec"
	"github.com/julb/blueprint-monitor/internal/session"
	"github.com/julb/blueprint-monitor/internal/tmux"
	"github.com/julb/blueprint-monitor/internal/worktree"
)

// Tab represents the active content tab.
type Tab int

const (
	TabPreview Tab = iota
	TabDiff
	TabTerminal
)

func (t Tab) String() string {
	switch t {
	case TabPreview:
		return "Preview"
	case TabDiff:
		return "Diff"
	case TabTerminal:
		return "Terminal"
	default:
		return "Unknown"
	}
}

// tickMsg triggers periodic updates (metadata, capture).
type tickMsg time.Time

// instanceCreatedMsg is sent when a new instance has been started in the background.
type instanceCreatedMsg struct {
	inst *session.Instance
	err  error
}

// attachFinishedMsg is sent when tmux attach returns.
type attachFinishedMsg struct{ err error }

// App is the main bubbletea model.
type App struct {
	width  int
	height int

	activeTab     Tab
	selectedIndex int

	// Components
	instanceList *InstanceList
	tabContent   *TabContent
	bottomMenu   *BottomMenu
	overlay      *Overlay

	// Tab data sources
	previewTab  *PreviewTab
	diffTab     *DiffTab
	terminalTab *TerminalTab

	// Pending confirmation action (to distinguish kill vs push)
	pendingAction KeyAction

	// Data
	instances []*session.Instance

	// Session management
	sessionMgr     *session.Manager
	store          *session.Store
	autoYes        *session.AutoYes
	statusDetector *tmux.StatusDetector
	projectRoot    string
	program        string

	// Set to true when we need to quit
	quitting bool
}

// NewApp creates a new TUI application model.
func NewApp(projectRoot, program string, autoYesEnabled bool) App {
	executor := exec.NewRealExecutor()
	tmuxMgr := tmux.NewManager(executor)
	wtMgr := worktree.NewManager(executor)
	sessMgr := session.NewManager(tmuxMgr, wtMgr)
	store := session.NewStore("")

	return App{
		activeTab:    TabPreview,
		instanceList: NewInstanceList(),
		tabContent:   NewTabContent(),
		bottomMenu:   NewBottomMenu(),
		overlay:      NewOverlay(),

		// Tab data sources
		previewTab:  NewPreviewTab(tmuxMgr),
		diffTab:     NewDiffTab(wtMgr),
		terminalTab: NewTerminalTab(tmuxMgr),

		// Session management
		sessionMgr:     sessMgr,
		store:          store,
		autoYes:        session.NewAutoYes(tmuxMgr, autoYesEnabled),
		statusDetector: tmux.NewStatusDetector(tmuxMgr),
		projectRoot:    projectRoot,
		program:        program,
	}
}

// Init implements tea.Model.
func (a App) Init() tea.Cmd {
	return tea.Batch(
		tickCmd(),
	)
}

func tickCmd() tea.Cmd {
	return tea.Tick(500*time.Millisecond, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

// Update implements tea.Model.
func (a App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		key := msg.String()
		action := MapKey(key, a.overlay.IsActive(), a.overlay.Active)

		switch action {
		case ActionQuit:
			a.quitting = true
			a.saveState()
			return a, tea.Quit
		case ActionSwitchTab:
			a.activeTab = (a.activeTab + 1) % 3
			a.tabContent.SetActiveTab(a.activeTab)
		case ActionNavigateDown:
			a.selectedIndex++
			a.instanceList.SetSelected(a.selectedIndex)
			a.selectedIndex = a.instanceList.SelectedIndex()
		case ActionNavigateUp:
			if a.selectedIndex > 0 {
				a.selectedIndex--
			}
			a.instanceList.SetSelected(a.selectedIndex)
			a.selectedIndex = a.instanceList.SelectedIndex()
		case ActionHelp:
			if a.overlay.Active == OverlayHelp {
				a.overlay.Hide()
			} else {
				a.overlay.Show(OverlayHelp, "", "")
			}
		case ActionCancel:
			a.overlay.Hide()
		case ActionNew:
			a.overlay.Show(OverlayTextInput, "New Instance", "Enter frontier name:")
		case ActionKill:
			if sel := a.instanceList.Selected(); sel != nil {
				a.pendingAction = ActionKill
				a.overlay.Show(OverlayConfirmation, "Kill Instance", "Kill '"+sel.Title+"'?")
			}
		case ActionTextInput:
			if a.overlay.Active == OverlayTextInput {
				r := msg.Runes
				if len(r) > 0 {
					a.overlay.InputValue += string(r)
				}
			}
		case ActionBackspace:
			if a.overlay.Active == OverlayTextInput && len(a.overlay.InputValue) > 0 {
				a.overlay.InputValue = a.overlay.InputValue[:len(a.overlay.InputValue)-1]
			}
		case ActionConfirmYes:
			switch a.overlay.Active {
			case OverlayTextInput:
				name := a.overlay.InputValue
				if name != "" && len(name) <= 32 {
					a.overlay.Hide()
					return a, a.createInstanceCmd(name)
				}
			case OverlayConfirmation:
				if sel := a.instanceList.Selected(); sel != nil {
					a.overlay.Hide()
					switch a.pendingAction {
					case ActionKill:
						a.sessionMgr.Kill(context.Background(), sel, a.projectRoot, true)
						a.removeInstance(sel)
					case ActionPush:
						wtMgr := worktree.NewManager(exec.NewRealExecutor())
						wtMgr.Push(context.Background(), sel.WorktreePath, "Blueprint: push from monitor")
					}
					a.pendingAction = ActionNone
				}
			}
		case ActionConfirmNo:
			a.overlay.Hide()
		case ActionOpen:
			if sel := a.instanceList.Selected(); sel != nil && sel.TmuxSession != "" {
				return a, a.attachCmd(sel.TmuxSession)
			}
		case ActionPush:
			if sel := a.instanceList.Selected(); sel != nil && sel.WorktreePath != "" {
				a.pendingAction = ActionPush
				a.overlay.Show(OverlayConfirmation, "Push Branch", "Push '"+sel.Title+"' branch to remote?")
			}
		case ActionCheckout:
			if sel := a.instanceList.Selected(); sel != nil && sel.WorktreePath != "" {
				// Open a shell in the worktree via terminal tab
				a.terminalTab.EnsureSession(context.Background(), sel.Title, sel.WorktreePath)
				a.activeTab = TabTerminal
				a.tabContent.SetActiveTab(TabTerminal)
			}
		case ActionResume:
			if sel := a.instanceList.Selected(); sel != nil && sel.Status == session.StatusPaused {
				a.sessionMgr.Resume(context.Background(), sel)
				a.instanceList.SetInstances(a.instances)
			}
		case ActionScrollUp:
			a.diffTab.ScrollUp(3)
			a.tabContent.SetDiff(a.diffTab.Content())
		case ActionScrollDown:
			a.diffTab.ScrollDown(3)
			a.tabContent.SetDiff(a.diffTab.Content())
		}

	case tea.MouseMsg:
		if !a.overlay.IsActive() {
			leftWidth := max(int(float64(a.width)*LeftPanelRatio), MinLeftWidth)
			if msg.X < leftWidth {
				row := msg.Y - 1
				if row >= 0 && row < len(a.instances) {
					a.selectedIndex = row
					a.instanceList.SetSelected(a.selectedIndex)
					a.selectedIndex = a.instanceList.SelectedIndex()
				}
			}
		}

	case attachFinishedMsg:
		// TUI resumes after tmux detach — nothing special to do

	case instanceCreatedMsg:
		if msg.err == nil && msg.inst != nil {
			a.instances = append(a.instances, msg.inst)
			a.instanceList.SetInstances(a.instances)
			a.selectedIndex = len(a.instances) - 1
			a.instanceList.SetSelected(a.selectedIndex)
			a.saveState()
		}

	case tea.WindowSizeMsg:
		a.width = msg.Width
		a.height = msg.Height
		a.updateLayout()

	case tickMsg:
		a.onTick()
		return a, tickCmd()
	}

	return a, nil
}

// onTick performs all periodic updates on each 500ms tick.
func (a *App) onTick() {
	ctx := context.Background()

	// Update progress for all active instances
	for _, inst := range a.instances {
		if inst.IsActive() {
			session.UpdateProgress(inst)

			// Update instance status from tmux status detection
			if inst.TmuxSession != "" {
				paneStatus, err := a.statusDetector.Detect(ctx, inst.TmuxSession)
				if err == nil {
					switch paneStatus {
					case tmux.PaneActive:
						inst.Status = session.StatusRunning
					case tmux.PaneIdle, tmux.PanePrompt:
						inst.Status = session.StatusReady
					}
				}

				// Auto-yes: approve permission prompts
				a.autoYes.Check(ctx, inst.TmuxSession)
			}
		}
	}

	// Update instance list display
	a.instanceList.SetInstances(a.instances)

	// Update tab content for selected instance
	sel := a.instanceList.Selected()
	if sel != nil {
		switch a.activeTab {
		case TabPreview:
			a.previewTab.Capture(ctx, sel.TmuxSession)
			a.tabContent.SetPreview(a.previewTab.Content())
		case TabDiff:
			a.diffTab.Refresh(ctx, sel.WorktreePath)
			a.tabContent.SetDiff(a.diffTab.Content())
		case TabTerminal:
			a.terminalTab.Capture(ctx, sel.Title)
			a.tabContent.SetTerminal(a.terminalTab.Content())
		}
	} else {
		a.tabContent.SetPreview("")
		a.tabContent.SetDiff("")
		a.tabContent.SetTerminal("")
	}
}

func (a *App) updateLayout() {
	leftWidth := max(int(float64(a.width)*LeftPanelRatio), MinLeftWidth)
	rightWidth := a.width - leftWidth - 2
	contentHeight := a.height - MenuHeight - 2

	a.instanceList.SetSize(leftWidth-2, contentHeight-2)
	a.tabContent.SetSize(rightWidth-2, contentHeight-2)
	a.bottomMenu.SetWidth(a.width)
	a.overlay.SetSize(a.width, a.height)
}

// View implements tea.Model.
func (a App) View() string {
	if a.quitting {
		return ""
	}
	if a.width == 0 || a.height == 0 {
		return "Initializing..."
	}

	leftWidth := max(int(float64(a.width)*LeftPanelRatio), MinLeftWidth)
	rightWidth := a.width - leftWidth - 2
	contentHeight := a.height - MenuHeight - 2

	// Render panels
	left := LeftPanelStyle.
		Width(leftWidth).
		Height(contentHeight).
		Render(a.instanceList.View())

	right := RightPanelStyle.
		Width(rightWidth).
		Height(contentHeight).
		Render(a.tabContent.View())

	menu := a.bottomMenu.View()

	// Compose layout
	panels := lipgloss.JoinHorizontal(lipgloss.Top, left, right)
	base := lipgloss.JoinVertical(lipgloss.Left, panels, menu)

	// Overlay on top
	if a.overlay.IsActive() {
		return a.overlay.View()
	}

	return base
}

// SetInstances updates the displayed instances.
func (a *App) SetInstances(instances []*session.Instance) {
	a.instances = instances
	a.instanceList.SetInstances(instances)
}

// attachCmd suspends the TUI and attaches to a tmux session.
// Uses tea.Exec to hand control to tmux, then resumes the TUI on detach.
func (a *App) attachCmd(sessionName string) tea.Cmd {
	c := osexec.Command("tmux", "attach-session", "-t", sessionName)
	return tea.ExecProcess(c, func(err error) tea.Msg {
		return attachFinishedMsg{err: err}
	})
}

func (a *App) createInstanceCmd(name string) tea.Cmd {
	return func() tea.Msg {
		prog := a.program
		if prog == "" {
			prog = "claude"
		}
		inst := a.sessionMgr.Create(name, "", name, prog)
		err := a.sessionMgr.Start(context.Background(), inst, a.projectRoot, name, 3*time.Second)
		return instanceCreatedMsg{inst: inst, err: err}
	}
}

func (a *App) removeInstance(inst *session.Instance) {
	for i, ins := range a.instances {
		if ins == inst {
			a.instances = append(a.instances[:i], a.instances[i+1:]...)
			break
		}
	}
	a.instanceList.SetInstances(a.instances)
	if a.selectedIndex >= len(a.instances) && a.selectedIndex > 0 {
		a.selectedIndex = len(a.instances) - 1
	}
	a.instanceList.SetSelected(a.selectedIndex)
	a.saveState()
}

func (a *App) saveState() {
	if a.store != nil {
		a.store.Save(a.instances)
	}
}

// Run starts the TUI application.
func Run(projectRoot, program string, autoYes bool) error {
	app := NewApp(projectRoot, program, autoYes)

	// Load persisted instances and validate
	instances, _ := app.store.Load()
	if len(instances) > 0 {
		ctx := context.Background()
		tmuxMgr := tmux.NewManager(exec.NewRealExecutor())
		for _, inst := range instances {
			// Validate tmux session still exists
			if inst.TmuxSession != "" && !tmuxMgr.Exists(ctx, inst.TmuxSession) {
				inst.Status = session.StatusDone
			}
		}
		// Filter out Done instances from previous sessions
		var active []*session.Instance
		for _, inst := range instances {
			if inst.Status != session.StatusDone {
				active = append(active, inst)
			}
		}
		app.instances = active
		app.instanceList.SetInstances(active)
	}

	p := tea.NewProgram(
		app,
		tea.WithAltScreen(),
		tea.WithMouseCellMotion(),
	)
	_, err := p.Run()
	return err
}
